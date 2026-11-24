DECLARE query_name STRING DEFAULT '1. Unprofitable orders';

-- Ultima actualización: 13/04/2026
-- Unprofitable orders (13/04/2026)
--  Rango de fechas para la tabla
DECLARE cantidad_filas INT64;
DECLARE start_date DATE;
DECLARE end_date DATE DEFAULT CURRENT_DATE();

-- ¿Cuantas filas tiene la tabla? (NULL/0 => backfill completo)
SET cantidad_filas = (
    SELECT row_count
    FROM `peya-food-and-groceries.automated_tables_reports.__TABLES__`
    WHERE table_id = 'dmarts_unprofitable_orders'
);

-- Backfill => desde 2025-01-01 ; Incremental => reprocesa el mes actual + los 2 anteriores
SET start_date = IF(
    cantidad_filas IS NULL OR cantidad_filas = 0,
    DATE '2025-01-01',
    DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 2 MONTH), MONTH)
);

-- ============================================================
-- 1) Calcula el slice nuevo (tu query, sin cambios) en una temp
-- ============================================================
CREATE TEMP TABLE nuevos AS

WITH

--- Customer_orders_sku_level
--- Calcula unidades vendidas, tax y descuentos
discounts AS (
  SELECT
    order_id,
    store_name,

    sum(pcm_discount_amount_lc) as discounts,
    sum(fulfilled_quantity) as units_sold,
    SAFE_DIVIDE(SUM(total_amount_sold_eur), SUM(total_amount_sold_net_eur)) AS vat_tax_aprox

  FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
  WHERE order_date BETWEEN start_date AND end_date
    --AND pcm_discount_amount_lc > 0
  GROUP BY 1,2

),

--- Fact_order_profitability
--- Resumen: Calcula la suma de Gross Profit per Order por usuario (Ganancia Bruta por Pedido). Lo clasifica como unprofitable o profitable.
 profit_users AS (
  SELECT
    user.user_id,

    SUM(gpo.gpo) AS gpo_user,
    CASE 
      WHEN SUM(gpo.gpo) < 0 THEN 'unprofitable'
      ELSE 'profitable'
    END AS user_profitability

  FROM `peya-datamarts-pro.dm_order_profitability.fact_order_profitability` AS f
  WHERE 
    registered_date BETWEEN start_date AND end_date
    AND order_status = 'CONFIRMED'
    -- AND partner.vertical_group = 'D-Mart' -- Descomentar si es necesario filtrar por vertical
  GROUP BY 1
),

--- ORDERS: Consolidación de métricas financieras y operativas normalizadas en EUR
orders AS (
  SELECT
    user.user_id,
    f.order_id,
    d.store_name,
    
    registered_date,
    location.country_name_en as country_name,
    partner.vertical_group,
    partner.vertical_type,
    user.is_user_plus,
    user_profitability,

    delivery.distance_range,
    COALESCE(delivery.distance_meters,0) AS distance_meters,

    -- BANDERAS Y MÉTRICAS DE DESCUENTOS / ENVÍO ==========================================

    -- Evalúa si el pedido tiene algún descuento aplicado (1 = Sí, 0 = No)
    CASE WHEN (d.discounts > 0 OR d.discounts IS NULL) THEN 1 ELSE 0 END AS has_promo_discounts, 
    
    -- Evalúa si el usuario tuvo envío gratis (Delivery Fee = 0)
    CASE WHEN delivery_fee_user = 0 THEN 1 ELSE 0 END AS is_df0, 
    
    -- Evalúa si tuvo envío gratis por ser suscriptor del programa Plus
    CASE WHEN delivery_fee_user = 0 AND user.is_user_plus = TRUE THEN 1 ELSE 0 END AS is_df0_plus,
    
    -- Evalúa si tuvo envío gratis SIN ser Plus (campañas o promociones de envío)
    CASE WHEN delivery_fee_user = 0 AND user.is_user_plus = FALSE THEN 1 ELSE 0 END AS is_df0_campaign,

    -- CONVERSIONES A EUROS (Dividido por monthly_rate_eu) ==========================================

    -- Costo de envío después de los descuentos de Plus, convertido a Euros
    gmv.shipping_amount_after_plus_discounts / monthly_rate_eu AS shipping_amount_no_discount, 
    
    -- Costo de envío neto (sin IVA/tax), convertido a Euros
    SAFE_DIVIDE(gmv.shipping_amount_after_plus_discounts / monthly_rate_eu, vat_tax_aprox) AS shipping_amount_no_discount_net,

    -- Valor bruto de la comida/productos (Gross Food Value), convertido a Euros
    SAFE_DIVIDE(gmv.gfv_vendor, monthly_rate_eu) AS afv_gross,
    
    -- Ventas retail (al por menor) de D-Mart, en Euros
    SAFE_DIVIDE(dmart.retail_sales, monthly_rate_eu) AS retail_sales,
    
    -- Impacto neto de los descuentos (Descuentos otorgados restando lo que se recupera por back margin de proveedores)
    SAFE_DIVIDE(-d.discounts + dmart.back_margin, monthly_rate_eu) AS net_discounts_impact,
    
    -- Costo intercompañía (IC) del envío Plus para D-Mart, en Euros
    SAFE_DIVIDE(ic_dmart.ic_dmart_df_plus, monthly_rate_eu) AS ic_dmart_df_plus,
    
    -- Reembolsos a usuarios de D-Mart (si es nulo, devuelve 0), en Euros
    COALESCE(SAFE_DIVIDE(fda.user_refund_dmart, monthly_rate_eu), 0) AS user_refund_dmart,
    
    -- Ganancia Bruta por Pedido (Gross Profit per Order), en Euros
    SAFE_DIVIDE(gpo.gpo, monthly_rate_eu) AS total_gpo,

    -- COSTOS OPERATIVOS DE D-MART (DARKSTORES) ==========================================

    -- Costo de los "shoppers" (armadores de pedidos dentro del Darkstore), en Euros
    SAFE_DIVIDE(dmart.shopper_cost_dmart, monthly_rate_eu) AS shopper_cost,
    
    -- Cantidad de unidades físicas vendidas en el pedido (No requiere conversión)
    d.units_sold AS unit_sold,
    
    -- Costo de los Bienes Vendidos (Cost of Goods Sold - lo que costó la mercadería), en Euros
    SAFE_DIVIDE(dmart.cogs, monthly_rate_eu) AS cogs,
    
    -- Margen trasero (dinero recuperado de proveedores por acuerdos comerciales), en Euros
    SAFE_DIVIDE(dmart.back_margin, monthly_rate_eu) AS back_margin,
    
    -- Ingresos/Permisos comerciales del centro de distribución (Warehouse/Darkstore), en Euros
    SAFE_DIVIDE(dmart.wdc_allowance, monthly_rate_eu) AS wdc_allowance,
    
    -- Costos generales del centro de distribución, en Euros
    SAFE_DIVIDE(dmart.wdc_cost, monthly_rate_eu) AS wdc_cost,
    
    -- Costo de personal del centro de distribución, en Euros
    SAFE_DIVIDE(dmart.wdc_personnel_cost, monthly_rate_eu) AS wdc_personnel_cost,
    
    -- Impuestos sobre los ingresos brutos (ej. Ingresos Brutos), en Euros
    SAFE_DIVIDE(dmart.gross_income_tax, monthly_rate_eu) AS gross_income_tax,
    
    -- Mermas (pérdida de inventario por robo, vencimiento, rotura), en Euros
    SAFE_DIVIDE(dmart.shrinkage, monthly_rate_eu) AS shrinkage,
    
    -- Costo de las bolsas y empaques utilizados para el pedido, en Euros
    SAFE_DIVIDE(dmart.packaging, monthly_rate_eu) AS packaging,
    
    -- Otros costos variables no categorizados, en Euros
    SAFE_DIVIDE(dmart.others_variable_costs, monthly_rate_eu) AS other_variable_costs,

--- ==========================================
    -- LOGÍSTICA, PAGOS Y ATENCIÓN AL CLIENTE 

    -- Costo del repartidor (rider), aplica solo si el envío es logística propia (OD = Own Delivery)
    CASE WHEN delivery.delivery_type = 'OD' THEN rider_cost.rider_cost / monthly_rate_eu ELSE 0 END AS rider_cost,
    
    -- Tarifa de envío cobrada al usuario, aplica solo si es logística propia (OD)
    CASE WHEN delivery.delivery_type = 'OD' THEN delivery_fee_user / monthly_rate_eu ELSE 0 END AS delivery_fee,
    
    -- FDA (Fallas de Desempeño/Reembolsos). Es igual al refund calculado arriba pero sin COALESCE
    SAFE_DIVIDE(fda.user_refund_dmart, monthly_rate_eu) AS fda,
    
    -- Costos del centro de atención al cliente (soporte por chats/llamadas), en Euros
    SAFE_DIVIDE(contact_center.contact_center, monthly_rate_eu) AS contact_center,
    
    -- Costos totales de medios de pago (procesamiento online, manejo de efectivo, contracargos y deudas incobrables)
    SAFE_DIVIDE(online_payment_fee.online_payment_fee + cash_collections + chargebacks + bad_debt_vendors, monthly_rate_eu) AS payments,
    
    -- Otros ingresos directos del usuario (Tarifa de envío + Tarifa de prioridad + Tarifa de servicio + Cargo por pedido pequeño)
    SAFE_DIVIDE(delivery_fee_user + priority_fee + service_fee + small_order_fee, monthly_rate_eu) AS other_take_in,
    
    -- Costos semivariables por pedido de logística (CPO = Cost Per Order), en Euros
    SAFE_DIVIDE(SEMIVARIABLE_DELIVERY_CPO, monthly_rate_eu) AS semivariable_cpo,

  CASE 
    WHEN COALESCE(
      SAFE_DIVIDE(
        (
          dmart.retail_sales 
          + dmart.cogs 
          + dmart.back_margin 
          + dmart.wdc_allowance 
          + dmart.wdc_cost
          + dmart.wdc_personnel_cost 
          + dmart.gross_income_tax 
          + dmart.shrinkage 
          + dmart.packaging 
          + dmart.others_variable_costs
        ),
        dmart.retail_sales
      ), 0
    ) <= 0.15 THEN 1 
    ELSE 0 
  END AS low_contr_margin,

  -- Ganancia Bruta por Pedido (Gross Profit per Order), en Euros
  SAFE_DIVIDE(gpo.gpo, monthly_rate_eu) AS gpo,
  
  -- Ganancia Bruta por Pedido First Line (GPO FL), en Euros
  SAFE_DIVIDE(gpo.gpo_fl, monthly_rate_eu) AS gpo_fl,

  -- Bandera: ¿El pedido generó pérdida a nivel GPO? (1 = Sí, 0 = No)
  CASE 
    WHEN gpo.gpo < 0 THEN 1 
    ELSE 0 
  END AS is_unprofitable_gpo,

  -- Bandera: ¿El pedido generó pérdida a nivel GPO First Line? (1 = Sí, 0 = No)
  CASE 
    WHEN gpo.gpo_fl < 0 THEN 1 
    ELSE 0 
  END AS is_unprofitable_gpoFL

FROM `peya-datamarts-pro.dm_order_profitability.fact_order_profitability` AS f
  
  
  -- JOINS Y FILTROS FINALES
  LEFT JOIN discounts AS d
    ON CAST(f.order_id AS STRING) = d.order_id

  LEFT JOIN profit_users
    ON f.user.user_id = profit_users.user_id

  WHERE 
    -- Filtro de rango temporal dinámico
    registered_date BETWEEN start_date AND end_date
    
    -- Filtro de estado: solo pedidos finalizados con éxito
    AND order_status = 'CONFIRMED'
    
    -- AND partner.vertical_group = 'D-Mart'

)

SELECT
  DATE_TRUNC(registered_date, MONTH) AS month,
  vertical_group,
  vertical_type,
  is_user_plus,
  user_profitability,
  o.country_name,

  -- ==========================================
  -- AGRUPACIONES (BUCKETS)
  
  -- Clasificación del pedido según la distancia de entrega (en kilómetros)
  -- Se usan letras al principio (a., b., etc.) para que los BI tools ordenen alfabéticamente bien
  CASE 
    WHEN distance_meters < 500   THEN 'a.[0-0.5 km]'
    WHEN distance_meters < 1000  THEN 'b.[0.5-1 km]'
    WHEN distance_meters < 2000  THEN 'c.[1-2 km]'
    WHEN distance_meters < 3000  THEN 'd.[2-3 km]'
    WHEN distance_meters < 4000  THEN 'e.[3-4 km]'
    WHEN distance_meters < 5000  THEN 'f.[4-5 km]'
    WHEN distance_meters < 6000  THEN 'g.[5-6 km]'
    WHEN distance_meters < 8000  THEN 'h.[6-8 km]'
    WHEN distance_meters < 10000 THEN 'i.[8-10 km]'
    ELSE 'j.[>10 km]'
  END AS distance_range,

  -- Clasificación del pedido según el valor bruto de los productos (en Euros)
  CASE 
    WHEN afv_gross < 3  THEN 'a.[0-3 EUR]'
    WHEN afv_gross < 4  THEN 'b.[3-4 EUR]'
    WHEN afv_gross < 5  THEN 'c.[4-5 EUR]'
    WHEN afv_gross < 6  THEN 'd.[5-6 EUR]'
    WHEN afv_gross < 7  THEN 'e.[6-7 EUR]'
    WHEN afv_gross < 8  THEN 'f.[7-8 EUR]'
    WHEN afv_gross < 9  THEN 'g.[8-9 EUR]'
    WHEN afv_gross < 10 THEN 'h.[9-10 EUR]'
    WHEN afv_gross < 15 THEN 'i.[10-15 EUR]'
    WHEN afv_gross < 20 THEN 'j.[15-20 EUR]'
    ELSE 'k.[>20 EUR]'
  END AS afv_range,

  
  store_name,

  -- ==========================================
  -- MÉTRICAS AGREGADAS (CONTEOS Y SUMAS)

  -- Volumen general de usuarios y órdenes
  COUNT(DISTINCT order_id) AS confirmed_orders,
  COUNT(DISTINCT user_id)  AS confirmed_users,

  -- Volumen de órdenes separadas por rentabilidad (GPO)
  COUNT(DISTINCT CASE WHEN is_unprofitable_gpo = 0 THEN order_id ELSE NULL END) AS profitable_orders_gpo, 
  COUNT(DISTINCT CASE WHEN is_unprofitable_gpo = 1 THEN order_id ELSE NULL END) AS unprofitable_orders_gpo,

  -- Suma del Gross Profit per Order (GPO) separado por rentabilidad
  SUM(CASE WHEN is_unprofitable_gpo = 1 THEN total_gpo ELSE 0 END) AS total_unprofitable_gpo1,
  SUM(CASE WHEN is_unprofitable_gpo = 0 THEN total_gpo ELSE 0 END) AS total_profitable_gpo1,
  
  -- Suma de GPO total y costos operativos
  SUM(shopper_cost) AS shoppers_cost,
  SUM(gpo)          AS gpo,
  
  -- Volumen de unidades físicas vendidas, totales y separadas por rentabilidad
  SUM(CASE WHEN is_unprofitable_gpo = 1 THEN unit_sold ELSE NULL END) AS unprofitable_units,
  SUM(CASE WHEN is_unprofitable_gpo = 0 THEN unit_sold ELSE NULL END) AS profitable_units,
  SUM(unit_sold)    AS units,

-- ==========================================
  -- DESGLOSE DE ÓRDENES NO RENTABLES (CONTEO)

  -- ------------------------------------------
  -- USUARIOS PLUS: Cantidad de Órdenes
  -- ------------------------------------------
  
  -- Total órdenes no rentables de usuarios Plus
  COUNT(DISTINCT CASE 
    WHEN is_unprofitable_gpo = 1 AND is_user_plus = TRUE 
    THEN order_id ELSE NULL END) AS unprofitable_total_plus,
    
  -- Causa 1: Pérdida generada por Reembolsos (Refunds)
  COUNT(DISTINCT CASE 
    WHEN is_unprofitable_gpo = 1 AND is_user_plus = TRUE 
     AND user_refund_dmart < 0 
    THEN order_id ELSE NULL END) AS unprofitable_plus_refunds,
    
  -- Causa 2: Pérdida por el costo del Envío Gratis Plus (IC D-Mart DF Plus)
  COUNT(DISTINCT CASE 
    WHEN is_unprofitable_gpo = 1 AND is_user_plus = TRUE 
     AND user_refund_dmart >= 0 
     AND (gpo - ic_dmart_df_plus) >= 0 
    THEN order_id ELSE NULL END) AS unprofitable_plus_df,   
    
  -- Causa 3: Pérdida por Promociones (impacto neto de descuentos)
  COUNT(DISTINCT CASE 
    WHEN is_unprofitable_gpo = 1 AND is_user_plus = TRUE 
     AND user_refund_dmart >= 0 
     AND (gpo - ic_dmart_df_plus) < 0 
     AND (gpo - ic_dmart_df_plus - net_discounts_impact) >= 0 
    THEN order_id ELSE NULL END) AS unprofitable_plus_promo,
    
  -- Causa 4: Pérdida por Márgenes de Contribución bajos (Darkstore P&L)
  COUNT(DISTINCT CASE 
    WHEN is_unprofitable_gpo = 1 AND is_user_plus = TRUE 
     AND user_refund_dmart >= 0 
     AND (gpo - ic_dmart_df_plus) < 0 
     AND ((gpo - ic_dmart_df_plus - net_discounts_impact) < 0 OR (gpo - ic_dmart_df_plus - net_discounts_impact) IS NULL) 
     AND low_contr_margin = 1 
    THEN order_id ELSE NULL END) AS unprofitable_plus_low_margins,
    
  -- Causa 5: Otros motivos no capturados arriba
  COUNT(DISTINCT CASE 
    WHEN is_unprofitable_gpo = 1 AND is_user_plus = TRUE 
     AND user_refund_dmart >= 0 
     AND (gpo - ic_dmart_df_plus) < 0 
     AND ((gpo - ic_dmart_df_plus - net_discounts_impact) < 0 OR (gpo - ic_dmart_df_plus - net_discounts_impact) IS NULL) 
     AND low_contr_margin = 0 
    THEN order_id ELSE NULL END) AS unprofitable_plus_others,

  -- ------------------------------------------
  -- USUARIOS REGULARES (NO PLUS): Cantidad de Órdenes
  -- ------------------------------------------
  
  -- Total órdenes no rentables de usuarios No Plus
  COUNT(DISTINCT CASE 
    WHEN is_unprofitable_gpo = 1 AND is_user_plus = FALSE 
    THEN order_id ELSE NULL END) AS unprofitable_total_no_plus,
    
  COUNT(DISTINCT CASE 
    WHEN is_unprofitable_gpo = 1 AND is_user_plus = FALSE 
     AND user_refund_dmart < 0 
    THEN order_id ELSE NULL END) AS unprofitable_total_no_plus_refunds,

  -- Envío Gratis (DF0) y combinaciones para No Plus
  COUNT(DISTINCT CASE 
    WHEN is_unprofitable_gpo = 1 AND is_user_plus = FALSE 
     AND user_refund_dmart >= 0 
     AND is_df0 = 1 
     AND (gpo + shipping_amount_no_discount_net) >= 0 
    THEN order_id ELSE NULL END) AS unprofitable_df0_noplus,  
    
  COUNT(DISTINCT CASE 
    WHEN is_unprofitable_gpo = 1 AND is_user_plus = FALSE 
     AND user_refund_dmart >= 0 
     AND is_df0 = 1 
     AND ((gpo + shipping_amount_no_discount_net) < 0 OR (gpo + shipping_amount_no_discount_net) IS NULL) 
     AND (gpo + shipping_amount_no_discount_net - net_discounts_impact) >= 0 
    THEN order_id ELSE NULL END) AS unprofitable_df0_and_promo_noplus,
    
  COUNT(DISTINCT CASE 
    WHEN is_unprofitable_gpo = 1 AND is_user_plus = FALSE 
     AND user_refund_dmart >= 0 
     AND is_df0 = 1 
     AND ((gpo + shipping_amount_no_discount_net) < 0 OR (gpo + shipping_amount_no_discount_net) IS NULL) 
     AND ((gpo + shipping_amount_no_discount_net - net_discounts_impact) < 0 OR (gpo + shipping_amount_no_discount_net - net_discounts_impact) IS NULL) 
     AND low_contr_margin = 1 
    THEN order_id ELSE NULL END) AS unprofitable_df0_low_margins_noplus,
    
  COUNT(DISTINCT CASE 
    WHEN is_unprofitable_gpo = 1 AND is_user_plus = FALSE 
     AND user_refund_dmart >= 0 
     AND is_df0 = 1 
     AND ((gpo + shipping_amount_no_discount_net) < 0 OR (gpo + shipping_amount_no_discount_net) IS NULL) 
     AND ((gpo + shipping_amount_no_discount_net - net_discounts_impact) < 0 OR (gpo + shipping_amount_no_discount_net - net_discounts_impact) IS NULL) 
     AND low_contr_margin = 0 
    THEN order_id ELSE NULL END) AS unprofitable_df0_noplus_others,

  -- Sin Envío Gratis (No DF0) y combinaciones para No Plus
  COUNT(DISTINCT CASE 
    WHEN is_unprofitable_gpo = 1 AND is_user_plus = FALSE 
     AND user_refund_dmart >= 0 
     AND is_df0 = 0 
     AND (gpo - net_discounts_impact) >= 0 
    THEN order_id ELSE NULL END) AS unprofitable_promotions_no_df0,
    
  COUNT(DISTINCT CASE 
    WHEN is_unprofitable_gpo = 1 AND is_user_plus = FALSE 
     AND user_refund_dmart >= 0 
     AND is_df0 = 0 
     AND has_promo_discounts = 1 
     AND ((gpo - net_discounts_impact) <= 0 OR (gpo - net_discounts_impact) IS NULL) 
     AND low_contr_margin = 1 
    THEN order_id ELSE NULL END) AS unprofitable_promo_low_margins_no_df0,
    
  COUNT(DISTINCT CASE 
    WHEN is_unprofitable_gpo = 1 AND is_user_plus = FALSE 
     AND user_refund_dmart >= 0 
     AND is_df0 = 0 
     AND has_promo_discounts = 1 
     AND ((gpo - net_discounts_impact) <= 0 OR (gpo - net_discounts_impact) IS NULL) 
     AND low_contr_margin = 0 
    THEN order_id ELSE NULL END) AS unprofitable_promo_others_no_df0,

  COUNT(DISTINCT CASE 
    WHEN is_unprofitable_gpo = 1 AND is_user_plus = FALSE 
     AND user_refund_dmart >= 0 
     AND is_df0 = 0 
     AND has_promo_discounts = 0 
     AND ((gpo - net_discounts_impact) <= 0 OR (gpo - net_discounts_impact) IS NULL) 
     AND low_contr_margin = 1 
    THEN order_id ELSE NULL END) AS unprofitable_low_margins_no_df0_no_promo,

  COUNT(DISTINCT CASE 
    WHEN is_unprofitable_gpo = 1 AND is_user_plus = FALSE 
     AND user_refund_dmart >= 0 
     AND is_df0 = 0 
     AND has_promo_discounts = 0 
     AND ((gpo - net_discounts_impact) <= 0 OR (gpo - net_discounts_impact) IS NULL) 
     AND low_contr_margin = 0 
    THEN order_id ELSE NULL END) AS unprofitable_others_no_df0_no_promo,
    
  -- ==========================================
  -- DESGLOSE DE ÓRDENES NO RENTABLES (IMPACTO GPO)

  -- ------------------------------------------
  -- USUARIOS PLUS: Suma de GPO
  -- ------------------------------------------
  SUM(CASE WHEN is_unprofitable_gpo = 1 AND is_user_plus = TRUE  AND user_refund_dmart < 0 THEN gpo ELSE 0 END) AS sum_unprofitable_plus_refunds,
  SUM(CASE WHEN is_unprofitable_gpo = 1 AND is_user_plus = TRUE  AND user_refund_dmart >= 0 AND (gpo - ic_dmart_df_plus) >= 0 THEN gpo ELSE 0 END) AS sum_unprofitable_plus_df,
  SUM(CASE WHEN is_unprofitable_gpo = 1 AND is_user_plus = TRUE  AND user_refund_dmart >= 0 AND (gpo - ic_dmart_df_plus) < 0 AND (gpo - ic_dmart_df_plus - net_discounts_impact) >= 0 THEN gpo ELSE 0 END) AS sum_unprofitable_plus_promo,
  SUM(CASE WHEN is_unprofitable_gpo = 1 AND is_user_plus = TRUE  AND user_refund_dmart >= 0 AND (gpo - ic_dmart_df_plus) < 0 AND ((gpo - ic_dmart_df_plus - net_discounts_impact) < 0 OR (gpo - ic_dmart_df_plus - net_discounts_impact) IS NULL) AND low_contr_margin = 1 THEN gpo ELSE 0 END) AS sum_unprofitable_plus_low_margins,
  SUM(CASE WHEN is_unprofitable_gpo = 1 AND is_user_plus = TRUE  AND user_refund_dmart >= 0 AND (gpo - ic_dmart_df_plus) < 0 AND ((gpo - ic_dmart_df_plus - net_discounts_impact) < 0 OR (gpo - ic_dmart_df_plus - net_discounts_impact) IS NULL) AND low_contr_margin = 0 THEN gpo ELSE 0 END) AS sum_unprofitable_plus_others,

  -- ------------------------------------------
  -- USUARIOS REGULARES (NO PLUS): Suma de GPO
  -- ------------------------------------------
  SUM(CASE WHEN is_unprofitable_gpo = 1 AND is_user_plus = FALSE AND user_refund_dmart < 0 THEN gpo ELSE 0 END) AS sum_unprofitable_total_no_plus_refunds,
  SUM(CASE WHEN is_unprofitable_gpo = 1 AND is_user_plus = FALSE AND user_refund_dmart >= 0 AND is_df0 = 1 AND (gpo + shipping_amount_no_discount_net) >= 0 THEN gpo ELSE 0 END) AS sum_unprofitable_df0_noplus,
  SUM(CASE WHEN is_unprofitable_gpo = 1 AND is_user_plus = FALSE AND user_refund_dmart >= 0 AND is_df0 = 1 AND ((gpo + shipping_amount_no_discount_net) < 0 OR (gpo + shipping_amount_no_discount_net) IS NULL) AND (gpo + shipping_amount_no_discount_net - net_discounts_impact) >= 0 THEN gpo ELSE 0 END) AS sum_unprofitable_df0_and_promo_noplus,
  SUM(CASE WHEN is_unprofitable_gpo = 1 AND is_user_plus = FALSE AND user_refund_dmart >= 0 AND is_df0 = 1 AND ((gpo + shipping_amount_no_discount_net) < 0 OR (gpo + shipping_amount_no_discount_net) IS NULL) AND ((gpo + shipping_amount_no_discount_net - net_discounts_impact) < 0 OR (gpo + shipping_amount_no_discount_net - net_discounts_impact) IS NULL) AND low_contr_margin = 1 THEN gpo ELSE 0 END) AS sum_unprofitable_df0_low_margins_noplus,
  SUM(CASE WHEN is_unprofitable_gpo = 1 AND is_user_plus = FALSE AND user_refund_dmart >= 0 AND is_df0 = 1 AND ((gpo + shipping_amount_no_discount_net) < 0 OR (gpo + shipping_amount_no_discount_net) IS NULL) AND ((gpo + shipping_amount_no_discount_net - net_discounts_impact) < 0 OR (gpo + shipping_amount_no_discount_net - net_discounts_impact) IS NULL) AND low_contr_margin = 0 THEN gpo ELSE 0 END) AS sum_unprofitable_df0_noplus_others,
  SUM(CASE WHEN is_unprofitable_gpo = 1 AND is_user_plus = FALSE AND user_refund_dmart >= 0 AND is_df0 = 0 AND (gpo - net_discounts_impact) >= 0 THEN gpo ELSE 0 END) AS sum_unprofitable_promotions_no_df0,
  SUM(CASE WHEN is_unprofitable_gpo = 1 AND is_user_plus = FALSE AND user_refund_dmart >= 0 AND is_df0 = 0 AND has_promo_discounts = 1 AND ((gpo - net_discounts_impact) <= 0 OR (gpo - net_discounts_impact) IS NULL) AND low_contr_margin = 1 THEN gpo ELSE 0 END) AS sum_unprofitable_promo_low_margins_no_df0,
  SUM(CASE WHEN is_unprofitable_gpo = 1 AND is_user_plus = FALSE AND user_refund_dmart >= 0 AND is_df0 = 0 AND has_promo_discounts = 1 AND ((gpo - net_discounts_impact) <= 0 OR (gpo - net_discounts_impact) IS NULL) AND low_contr_margin = 0 THEN gpo ELSE 0 END) AS sum_unprofitable_promo_others_no_df0,
  SUM(CASE WHEN is_unprofitable_gpo = 1 AND is_user_plus = FALSE AND user_refund_dmart >= 0 AND is_df0 = 0 AND has_promo_discounts = 0 AND ((gpo - net_discounts_impact) <= 0 OR (gpo - net_discounts_impact) IS NULL) AND low_contr_margin = 1 THEN gpo ELSE 0 END) AS sum_unprofitable_low_margins_no_df0_no_promo,
  SUM(CASE WHEN is_unprofitable_gpo = 1 AND is_user_plus = FALSE AND user_refund_dmart >= 0 AND is_df0 = 0 AND has_promo_discounts = 0 AND ((gpo - net_discounts_impact) <= 0 OR (gpo - net_discounts_impact) IS NULL) AND low_contr_margin = 0 THEN gpo ELSE 0 END) AS sum_unprofitable_others_no_df0_no_promo,

  -- ==========================================
  -- P&L SPLIT: RENTABLE VS NO RENTABLE (GPO)

  SUM(CASE WHEN is_unprofitable_gpo = 1 THEN retail_sales         ELSE 0 END) AS retail_sales_unprofitable,
  SUM(CASE WHEN is_unprofitable_gpo = 0 THEN retail_sales         ELSE 0 END) AS retail_sales_profitable,

  SUM(CASE WHEN is_unprofitable_gpo = 1 THEN cogs                 ELSE 0 END) AS cogs_unprofitable,
  SUM(CASE WHEN is_unprofitable_gpo = 0 THEN cogs                 ELSE 0 END) AS cogs_profitable,

  SUM(CASE WHEN is_unprofitable_gpo = 1 THEN back_margin          ELSE 0 END) AS back_margin_unprofitable,
  SUM(CASE WHEN is_unprofitable_gpo = 0 THEN back_margin          ELSE 0 END) AS back_margin_profitable,

  SUM(CASE WHEN is_unprofitable_gpo = 1 THEN wdc_allowance        ELSE 0 END) AS wdc_allowance_unprofitable,
  SUM(CASE WHEN is_unprofitable_gpo = 0 THEN wdc_allowance        ELSE 0 END) AS wdc_allowance_profitable,

  SUM(CASE WHEN is_unprofitable_gpo = 1 THEN wdc_cost             ELSE 0 END) AS wdc_cost_unprofitable,
  SUM(CASE WHEN is_unprofitable_gpo = 0 THEN wdc_cost             ELSE 0 END) AS wdc_cost_profitable,

  SUM(CASE WHEN is_unprofitable_gpo = 1 THEN wdc_personnel_cost   ELSE 0 END) AS wdc_personnel_cost_unprofitable,
  SUM(CASE WHEN is_unprofitable_gpo = 0 THEN wdc_personnel_cost   ELSE 0 END) AS wdc_personnel_cost_profitable,

  SUM(CASE WHEN is_unprofitable_gpo = 1 THEN gross_income_tax     ELSE 0 END) AS gross_income_tax_unprofitable,
  SUM(CASE WHEN is_unprofitable_gpo = 0 THEN gross_income_tax     ELSE 0 END) AS gross_income_tax_profitable,

  SUM(CASE WHEN is_unprofitable_gpo = 1 THEN shrinkage            ELSE 0 END) AS shrinkage_unprofitable,
  SUM(CASE WHEN is_unprofitable_gpo = 0 THEN shrinkage            ELSE 0 END) AS shrinkage_profitable,

  SUM(CASE WHEN is_unprofitable_gpo = 1 THEN packaging            ELSE 0 END) AS packaging_unprofitable,
  SUM(CASE WHEN is_unprofitable_gpo = 0 THEN packaging            ELSE 0 END) AS packaging_profitable,

  SUM(CASE WHEN is_unprofitable_gpo = 1 THEN other_variable_costs ELSE 0 END) AS other_variable_costs_unprofitable,
  SUM(CASE WHEN is_unprofitable_gpo = 0 THEN other_variable_costs ELSE 0 END) AS other_variable_costs_profitable,

  SUM(CASE WHEN is_unprofitable_gpo = 1 THEN rider_cost           ELSE 0 END) AS rider_cost_unprofitable,
  SUM(CASE WHEN is_unprofitable_gpo = 0 THEN rider_cost           ELSE 0 END) AS rider_cost_profitable,

  SUM(CASE WHEN is_unprofitable_gpo = 1 THEN fda                  ELSE 0 END) AS fda_unprofitable,
  SUM(CASE WHEN is_unprofitable_gpo = 0 THEN fda                  ELSE 0 END) AS fda_profitable,

  SUM(CASE WHEN is_unprofitable_gpo = 1 THEN contact_center       ELSE 0 END) AS contact_center_unprofitable,
  SUM(CASE WHEN is_unprofitable_gpo = 0 THEN contact_center       ELSE 0 END) AS contact_center_profitable,

  SUM(CASE WHEN is_unprofitable_gpo = 1 THEN payments             ELSE 0 END) AS payments_unprofitable,
  SUM(CASE WHEN is_unprofitable_gpo = 0 THEN payments             ELSE 0 END) AS payments_profitable,

  SUM(CASE WHEN is_unprofitable_gpo = 1 THEN other_take_in        ELSE 0 END) AS other_take_in_unprofitable,
  SUM(CASE WHEN is_unprofitable_gpo = 0 THEN other_take_in        ELSE 0 END) AS other_take_in_profitable,

  SUM(CASE WHEN is_unprofitable_gpo = 1 THEN semivariable_cpo     ELSE 0 END) AS semivariable_cpo_unprofitable,
  SUM(CASE WHEN is_unprofitable_gpo = 0 THEN semivariable_cpo     ELSE 0 END) AS semivariable_cpo_profitable,

  SUM(CASE WHEN is_unprofitable_gpo = 1 THEN delivery_fee         ELSE 0 END) AS delivery_fee_unprofitable,
  SUM(CASE WHEN is_unprofitable_gpo = 0 THEN delivery_fee         ELSE 0 END) AS delivery_fee_profitable

FROM orders AS o
  
WHERE 
  vertical_type NOT IN ('Restaurant', 'Coffee')
  -- WHERE vertical_type = 'Market'

GROUP BY 
  month, 
  vertical_group, 
  vertical_type, 
  is_user_plus, 
  user_profitability, 
  country_name, 
  distance_range, 
  afv_range, 
  store_name

ORDER BY 
  month DESC, 
  confirmed_orders DESC;

-- ============================================================
-- 2) Crea la tabla (schema + particion) SOLO si no existe
-- ============================================================
CREATE TABLE IF NOT EXISTS `peya-food-and-groceries.automated_tables_reports.dmarts_unprofitable_orders`
PARTITION BY month
CLUSTER BY vertical_type, country_name
AS SELECT * FROM nuevos WHERE FALSE;

-- ============================================================
-- 3) Reemplaza solo los meses reprocesados (idempotente)
-- ============================================================
BEGIN TRANSACTION;

  DELETE FROM `peya-food-and-groceries.automated_tables_reports.dmarts_unprofitable_orders`
  WHERE month >= start_date;

  INSERT INTO `peya-food-and-groceries.automated_tables_reports.dmarts_unprofitable_orders`
  SELECT * FROM nuevos;

COMMIT TRANSACTION;