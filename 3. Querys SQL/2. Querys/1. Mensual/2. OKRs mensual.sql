-- ═══════════════════════════════════════════════════════════════════════════
-- OKRs_data — Métricas Mensuales D-Marts (DELETE + INSERT)
-- Tabla vacía     -> Carga histórica (desde from_date_historic)
-- Tabla con datos -> Recarga último mes (desde from_date_incremental)
-- ═══════════════════════════════════════════════════════════════════════════

-- ── PASO 0: Variables de Fecha ─────────────────────────────────────────────
DECLARE query_name            STRING DEFAULT '2. OKRs mensual.sql';

-- Sheets Name: 1. TD - OKRs Mensual (0 - Orders)
-- Sheets Link: https://docs.google.com/spreadsheets/d/13yTO_kFzIvISmbSz6p93BFUub1HODpuiGhB3yElZ2fw

DECLARE from_date_historic    DATE DEFAULT '2020-01-01';
DECLARE from_date_incremental DATE DEFAULT DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH);
DECLARE to_date               DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);
DECLARE date_from_cupons      DATE DEFAULT '2022-08-01';
DECLARE from_date             DATE;   -- Ventana efectiva (se resuelve en el PASO 2)

-- ── PASO 1: Crear la Tabla si no existe (con descripciones) ────────────────
--    NO usar CREATE OR REPLACE: borraría el histórico en cada corrida.
CREATE TABLE IF NOT EXISTS `peya-food-and-groceries.automated_tables_reports.dmart_orders_okrs`
(
  Month                           DATE     OPTIONS(description="Mes de la métrica (primer día del mes)."),
  Country_name                    STRING   OPTIONS(description="País."),
  active_warehouses               INT64    OPTIONS(description="Darkstores activos en el mes (excluye tiendas de eventos/oficinas)."),
  days                            INT64    OPTIONS(description="Días distintos con pedidos en el mes."),
  Users_Peya_month                INT64    OPTIONS(description="Usuarios únicos que compraron en toda la plataforma en el mes."),
  Users_DMart_month               INT64    OPTIONS(description="Usuarios únicos que compraron en darkstores (D-Mart) en el mes."),
  Users_DMart_Plus_month          INT64    OPTIONS(description="Usuarios únicos Plus que compraron en darkstores en el mes."),
  Confirmed_orders                INT64    OPTIONS(description="Pedidos confirmados de darkstores."),
  total_platform_confirmed_orders INT64    OPTIONS(description="Pedidos confirmados de toda la plataforma (todos los verticales)."),
  failed_orders                   INT64    OPTIONS(description="Pedidos de darkstores no confirmados (fallidos/cancelados)."),
  units_sold                      NUMERIC  OPTIONS(description="Unidades (SKUs) vendidas en pedidos confirmados de darkstores."),
  Plus_orders                     INT64    OPTIONS(description="Pedidos confirmados de darkstores de usuarios Plus."),
  discount_amount_EU              FLOAT64  OPTIONS(description="Descuentos totales en pedidos confirmados de darkstores (EUR)."),
  gmv_vendor_dmarts               FLOAT64  OPTIONS(description="GMV a precio vendor de darkstores (EUR)."),
  gmv_vendor_total                FLOAT64  OPTIONS(description="GMV a precio vendor de toda la plataforma (EUR)."),
  gmv_user_dmarts                 FLOAT64  OPTIONS(description="GMV a precio usuario de darkstores (EUR)."),
  gmv_user_total                  FLOAT64  OPTIONS(description="GMV a precio usuario de toda la plataforma (EUR)."),
  DF_revenue_EU                   FLOAT64  OPTIONS(description="Ingreso bruto por Delivery Fee (sin descuento) de darkstores (EUR)."),
  SF_revenue_EU                   FLOAT64  OPTIONS(description="Ingreso bruto por Service Fee (sin descuento) de darkstores (EUR)."),
  revenue_fee_EU                  FLOAT64  OPTIONS(description="Ingreso bruto por fees (Delivery + Service) de darkstores (EUR)."),
  DF_net_EU                       FLOAT64  OPTIONS(description="Delivery Fee neto de impuestos de darkstores (EUR)."),
  SF_net_EU                       FLOAT64  OPTIONS(description="Service Fee neto de impuestos de darkstores (EUR)."),
  RF_net_EU                       FLOAT64  OPTIONS(description="Fees netos de impuestos (Delivery + Service) de darkstores (EUR)."),
  discount_plus_net_EU            FLOAT64  OPTIONS(description="Descuento de envío por Plus, neto de impuestos (EUR)."),
  DF0_orders                      INT64    OPTIONS(description="Pedidos confirmados de darkstores con delivery fee = 0 (envío gratis, sin pickup)."),
  Voucher_Orders                  INT64    OPTIONS(description="Pedidos confirmados de darkstores que usaron cupón."),
  Incentivized_Orders             INT64    OPTIONS(description="Pedidos confirmados de darkstores incentivados: con cupón, o con envío gratis (fee=0, sin pickup) EXCLUYENDO el envío gratis de usuarios Plus (beneficio de suscripción, no incentivo promocional)."),
  Voucher_amount                  FLOAT64  OPTIONS(description="Monto de cupones usado, neto de impuestos, en pedidos confirmados de darkstores (EUR)."),
  dmarts_cpo                      FLOAT64  OPTIONS(description="Costo por pedido (rider cost) de D-Mart con delivery propio/OD (EUR)."),
  platform_cpo                    FLOAT64  OPTIONS(description="Costo por pedido de la plataforma con delivery propio/OD (EUR)."),
  courier_cpo                     FLOAT64  OPTIONS(description="Costo por pedido de Courier con delivery propio/OD (EUR)."),
  platform_orders_excl_dmarts     INT64    OPTIONS(description="Pedidos confirmados de Platform (OD), denominador del CPO de plataforma."),
  dmart_orders_cpo                INT64    OPTIONS(description="Pedidos confirmados de D-Mart (OD), denominador del CPO de D-Mart.")
)
PARTITION BY Month
CLUSTER BY Country_name;

-- ── PASO 2: ¿Carga Histórica o Incremental? ─────────────────────────────────
SET from_date = IF(
  (SELECT COUNT(*) FROM `peya-food-and-groceries.automated_tables_reports.dmart_orders_okrs`) = 0,
  from_date_historic,       -- Tabla vacía -> Histórico
  from_date_incremental     -- Con datos   -> Último mes
);

-- ── PASO 3: Transacción - Borrado e Inserción de Datos ──────────────────────
--   (En transacción -> atómico). Todo el procesamiento se realiza mediante CTEs.
BEGIN TRANSACTION;

DELETE FROM `peya-food-and-groceries.automated_tables_reports.dmart_orders_okrs`
WHERE Month >= from_date;   -- from_date siempre cae en el 1er día del mes

INSERT INTO `peya-food-and-groceries.automated_tables_reports.dmart_orders_okrs`
(
  Month, Country_name, active_warehouses, days,
  Users_Peya_month, Users_DMart_month, Users_DMart_Plus_month,
  Confirmed_orders, total_platform_confirmed_orders, failed_orders, units_sold, Plus_orders,
  gmv_vendor_dmarts, gmv_vendor_total, gmv_user_dmarts, gmv_user_total,
  discount_amount_EU, DF_revenue_EU, SF_revenue_EU, revenue_fee_EU,
  DF_net_EU, SF_net_EU, RF_net_EU, discount_plus_net_EU,
  DF0_orders, Voucher_Orders, Incentivized_Orders, Voucher_amount,
  dmarts_cpo, platform_cpo, courier_cpo, platform_orders_excl_dmarts, dmart_orders_cpo
)
WITH 
  -- 3.1 Partners que son Darkstores
  partners AS (
    SELECT 
      p.country_id, 
      p.partner_id, 
      pd.warehouse_id, 
      TRUE AS darkstore
    FROM `peya-bi-tools-pro.il_core.dim_partner` AS p
    INNER JOIN `peya-datamarts-pro.dm_dmarts.dim_partner_darkstore` AS pd
      ON p.partner_id = pd.partner_id
  ),

  -- 3.2 Almacenes activos por mes y país
  active_stores AS (
    SELECT
      DATE_TRUNC(order_date, MONTH) AS month_year,
      country_code,
      COUNT(DISTINCT warehouse_id) AS active_warehouses
    FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
    WHERE order_date BETWEEN from_date AND to_date
      AND store_name NOT IN (
        'RD_12_Torre OV', 'PA_9_Midtown', 'SV_6_Torre Futura',
        'EC_17_TiendaPick-Up Oficina', 'PE_3_PuntaHermosa', 'BO_19_Truck',
        'UY_15_Eventos', 'PE_24_FILO', 'EC_6_Oficina'
      )
      AND state = 'CONFIRMED'
    GROUP BY 1, 2
  ),

  -- 3.3 Cupones por pedido
  coupon_data AS (
    SELECT 
      cou.order_id, 
      SUM(cou.coupon_used_amount) AS coupon_used_amount
    FROM `peya-bi-tools-pro.il_growth.fact_talon_coupons` AS cou
    WHERE DATE(cou.coupon_created_at) >= date_from_cupons
      AND DATE(cou.order_registered_date) BETWEEN from_date AND to_date
      AND cou.order_state_id = 1   -- Pedido confirmado
    GROUP BY 1
  ),

  -- 3.4 Usuarios activos mensuales (total, D-Mart, D-Mart Plus)
  active_cust_monthly AS (
    SELECT
      DATE_TRUNC(o.registered_date, MONTH) AS registered_date_month,
      o.country_id,
      COUNT(DISTINCT o.customer_id) AS Users_Peya_month,
      COUNT(DISTINCT CASE WHEN p.darkstore = TRUE THEN o.customer_id END) AS Users_DMart_month,
      COUNT(DISTINCT CASE WHEN p.darkstore = TRUE AND o.is_user_plus = 1 THEN o.customer_id END) AS Users_DMart_Plus_month
    FROM `peya-bi-tools-pro.il_core.fact_orders` AS o
    LEFT JOIN partners AS p 
      ON p.partner_id = o.restaurant.id
    WHERE o.registered_date BETWEEN from_date AND to_date
      AND o.order_status = 'CONFIRMED'
    GROUP BY 1, 2
  ),

  -- 3.5 Costo por pedido (CPO) por vertical (Detalle e intermedio)
  cost_per_order_raw AS (
    SELECT
      DATE_TRUNC(registered_date, MONTH) AS month,
      country_id,
      CASE
        WHEN partner.vertical_group = 'D-Mart' THEN 'D-Mart'
        WHEN partner.vertical_group IN ('Courier Business', 'Courier') THEN 'Courier'
        ELSE 'Platform'
      END AS vertical,
      delivery.delivery_type,
      COUNT(DISTINCT CASE WHEN order_status = 'CONFIRMED' THEN order_id END) AS confirmed_orders,
      SUM(rider_cost.rider_cost / monthly_rate_eu) AS rider_cost_eur
    FROM `peya-datamarts-pro.dm_order_profitability.fact_order_profitability`
    WHERE registered_date BETWEEN from_date AND to_date
    GROUP BY 1, 2, 3, 4
  ),

  cost_per_order AS (
    SELECT
      month,
      country_id,
      SUM(CASE WHEN vertical = 'D-Mart'   AND delivery_type = 'OD' THEN SAFE_DIVIDE(rider_cost_eur, confirmed_orders) END) AS dmarts_cpo,
      SUM(CASE WHEN vertical = 'Platform' AND delivery_type = 'OD' THEN SAFE_DIVIDE(rider_cost_eur, confirmed_orders) END) AS platform_cpo,
      SUM(CASE WHEN vertical = 'Courier'  AND delivery_type = 'OD' THEN SAFE_DIVIDE(rider_cost_eur, confirmed_orders) END) AS courier_cpo,
      SUM(CASE WHEN vertical = 'Platform' AND delivery_type = 'OD' THEN confirmed_orders END) AS platform_orders_excl_dmarts,
      SUM(CASE WHEN vertical = 'D-Mart'   AND delivery_type = 'OD' THEN confirmed_orders END) AS dmart_orders_cpo
    FROM cost_per_order_raw
    GROUP BY 1, 2
  ),

  -- 3.6 Unidades vendidas y descuentos por pedido (desde SKU level)
  sku_level_by_order AS (
    SELECT 
      order_id, 
      SUM(fulfilled_quantity) AS units_dco,
      SUM(pcm_discount_amount_net_eur) AS discount_dco_eur
    FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
    WHERE order_date BETWEEN from_date AND to_date
    GROUP BY 1
  ),

  -- 3.7 Pedidos a nivel detalle (ingresos, descuentos, impuestos)
  orders AS (
    SELECT
      o.order_id,
      o.registered_date AS order_placed_local,
      o.country.country_name,
      o.country_id,
      o.country.country_code,
      o.restaurant.id AS restaurant_id,
      o.order_status,
      o.pickup,
      o.is_user_plus,
      dco_agg.units_dco AS units_sold,
      dco_agg.discount_dco_eur,
      o.shipping_amount_no_discount AS delivery_fee_no_discount,
      o.serviceFee.service_fee_no_discount AS service_fee_no_discount,
      -- Ingresos netos, ajustando por impuestos de cada país
      CASE 
        WHEN o.country.country_name = 'Bolivia' THEN o.shipping_amount_no_discount * (1 - co.percentage_tax_logistics)
        ELSE o.shipping_amount_no_discount / (1 + co.percentage_tax_logistics) 
      END AS delivery_fee_paid_net,
      CASE 
        WHEN o.country.country_name = 'Bolivia' THEN o.serviceFee.service_fee_no_discount * (1 - co.percentage_tax_logistics)
        ELSE o.serviceFee.service_fee_no_discount / (1 + co.percentage_tax_logistics) 
      END AS service_fee_paid_net,
      o.discount_amount,
      o.plus_shipping_cost_discount_amount / (1 + co.percentage_effective_tax) AS discount_plus_net
    FROM `peya-bi-tools-pro.il_core.fact_orders` AS o
    INNER JOIN `peya-data-origins-pro.cl_core.country_details` AS co
      ON o.country_id = co.country_id AND co.active
    LEFT JOIN sku_level_by_order AS dco_agg 
      ON CAST(o.order_id AS STRING) = dco_agg.order_id
    WHERE o.registered_date BETWEEN from_date AND to_date
    GROUP BY ALL
  ),

  -- 3.8 GMV total y de D-Marts
  gmv_data AS (
    SELECT
      DATE_TRUNC(registered_date, MONTH) AS date_month,
      fop.country_id,
      SAFE_DIVIDE(SUM(CASE WHEN p.darkstore = TRUE THEN gmv.gmv_vendor END), monthly_rate_eu) AS gmv_vendor_dmarts,
      SAFE_DIVIDE(SUM(CASE WHEN p.darkstore = TRUE THEN gmv.gmv_user   END), monthly_rate_eu) AS gmv_user_dmarts,
      SAFE_DIVIDE(SUM(gmv.gmv_vendor), monthly_rate_eu) AS gmv_vendor_total,
      SAFE_DIVIDE(SUM(gmv.gmv_user),   monthly_rate_eu) AS gmv_user_total
    FROM `peya-datamarts-pro.dm_order_profitability.fact_order_profitability` AS fop
    LEFT JOIN partners AS p 
      ON p.partner_id = fop.partner.partner_id
    WHERE registered_date BETWEEN from_date AND to_date
    GROUP BY 1, 2, fop.monthly_rate_eu
  ),

  -- 3.9 Ensamblado final — Toda la lógica de cálculo agrupada por mes/país
  final_data AS (
    SELECT
      DATE_TRUNC(o.order_placed_local, MONTH) AS Month,
      o.country_name AS Country_name,
      a.active_warehouses,
      COUNT(DISTINCT o.order_placed_local) AS days,
      acm.Users_Peya_month,
      acm.Users_DMart_month,
      acm.Users_DMart_Plus_month,

      -- Pedidos
      COUNT(DISTINCT CASE WHEN o.order_status = 'CONFIRMED' AND hp.darkstore = TRUE THEN o.order_id END) AS Confirmed_orders,
      COUNT(DISTINCT CASE WHEN o.order_status = 'CONFIRMED' THEN o.order_id END) AS total_platform_confirmed_orders,
      COUNT(DISTINCT CASE WHEN o.order_status <> 'CONFIRMED' AND hp.darkstore = TRUE THEN o.order_id END) AS failed_orders,
      SUM(CASE WHEN o.order_status = 'CONFIRMED' AND hp.darkstore = TRUE THEN o.units_sold ELSE 0 END) AS units_sold,
      COUNT(DISTINCT CASE WHEN o.order_status = 'CONFIRMED' AND hp.darkstore = TRUE AND o.is_user_plus = 1 THEN o.order_id END) AS Plus_orders,

      -- GMV (EUR)
      gmv.gmv_vendor_dmarts,
      gmv.gmv_vendor_total,
      gmv.gmv_user_dmarts,
      gmv.gmv_user_total,

      -- Descuentos e ingresos (EUR)
      SUM(CASE WHEN o.order_status = 'CONFIRMED' AND hp.darkstore = TRUE THEN COALESCE(o.discount_dco_eur, 0) ELSE 0 END) AS discount_amount_EU,
      SUM(CASE WHEN o.order_status = 'CONFIRMED' AND hp.darkstore = TRUE THEN o.delivery_fee_no_discount / ce.rate_eu ELSE 0 END) AS DF_revenue_EU,
      SUM(CASE WHEN o.order_status = 'CONFIRMED' AND hp.darkstore = TRUE THEN o.service_fee_no_discount / ce.rate_eu ELSE 0 END) AS SF_revenue_EU,
      SUM(CASE WHEN o.order_status = 'CONFIRMED' AND hp.darkstore = TRUE THEN (COALESCE(o.delivery_fee_no_discount, 0) + COALESCE(o.service_fee_no_discount, 0)) / ce.rate_eu ELSE 0 END) AS revenue_fee_EU,
      SUM(CASE WHEN o.order_status = 'CONFIRMED' AND hp.darkstore = TRUE THEN o.delivery_fee_paid_net / ce.rate_eu ELSE 0 END) AS DF_net_EU,
      SUM(CASE WHEN o.order_status = 'CONFIRMED' AND hp.darkstore = TRUE THEN o.service_fee_paid_net / ce.rate_eu ELSE 0 END) AS SF_net_EU,
      SUM(CASE WHEN o.order_status = 'CONFIRMED' AND hp.darkstore = TRUE THEN (COALESCE(o.delivery_fee_paid_net, 0) + COALESCE(o.service_fee_paid_net, 0)) / ce.rate_eu ELSE 0 END) AS RF_net_EU,
      SUM(CASE WHEN o.order_status = 'CONFIRMED' AND hp.darkstore = TRUE THEN o.discount_plus_net / ce.rate_eu ELSE 0 END) AS discount_plus_net_EU,

      -- Pedidos incentivados
      COUNT(DISTINCT CASE WHEN o.order_status = 'CONFIRMED' AND hp.darkstore = TRUE AND o.delivery_fee_no_discount = 0 AND o.pickup = FALSE THEN o.order_id END) AS DF0_orders,
      COUNT(DISTINCT CASE WHEN cd.coupon_used_amount > 0 AND o.order_status = 'CONFIRMED' AND hp.darkstore = TRUE THEN o.order_id END) AS Voucher_Orders,
      -- Incentivado = cupón, o envío gratis (fee=0, sin pickup) pero NO por ser Plus
      COUNT(DISTINCT CASE
              WHEN o.order_status = 'CONFIRMED' AND hp.darkstore = TRUE
               AND ( cd.coupon_used_amount > 0
                     OR (o.delivery_fee_no_discount = 0 AND o.pickup = FALSE AND COALESCE(o.is_user_plus, 0) <> 1) )
              THEN o.order_id END) AS Incentivized_Orders,
      SUM(CASE WHEN o.order_status = 'CONFIRMED' AND hp.darkstore = TRUE THEN cd.coupon_used_amount / (1 + co.percentage_effective_tax) ELSE 0 END) AS Voucher_amount,

      -- CPO
      cpo.dmarts_cpo,
      cpo.platform_cpo,
      cpo.courier_cpo,
      cpo.platform_orders_excl_dmarts,
      cpo.dmart_orders_cpo
    FROM orders AS o
    INNER JOIN `peya-bi-tools-pro.il_core.dim_country` AS c
      ON c.country_id = o.country_id AND c.active = TRUE
    LEFT JOIN partners AS hp
      ON hp.partner_id = o.restaurant_id
    LEFT JOIN `peya-bi-tools-pro.il_core.dim_currency_exchange` AS ce
      ON ce.currency_id = c.currency_id AND ce.currency_exchange_date = DATE_TRUNC(o.order_placed_local, MONTH)
    LEFT JOIN active_stores AS a
      ON a.month_year = DATE_TRUNC(o.order_placed_local, MONTH) AND UPPER(a.country_code) = UPPER(o.country_code)
    LEFT JOIN `peya-data-origins-pro.cl_core.country_details` AS co
      ON o.country_id = co.country_id AND co.active
    LEFT JOIN coupon_data AS cd
      ON cd.order_id = o.order_id
    LEFT JOIN active_cust_monthly AS acm
      ON DATE(acm.registered_date_month) = DATE_TRUNC(o.order_placed_local, MONTH) AND acm.country_id = o.country_id
    LEFT JOIN cost_per_order AS cpo
      ON o.country_id = cpo.country_id AND cpo.month = DATE_TRUNC(o.order_placed_local, MONTH)
    LEFT JOIN gmv_data AS gmv
      ON gmv.date_month = DATE_TRUNC(o.order_placed_local, MONTH) AND o.country_id = gmv.country_id
    WHERE DATE_TRUNC(o.order_placed_local, MONTH) BETWEEN from_date AND to_date
    GROUP BY
      Month, Country_name, a.active_warehouses, acm.Users_Peya_month,
      acm.Users_DMart_month, acm.Users_DMart_Plus_month, gmv.gmv_vendor_dmarts, gmv.gmv_vendor_total,
      gmv.gmv_user_dmarts, gmv.gmv_user_total, cpo.dmarts_cpo, cpo.platform_cpo,
      cpo.courier_cpo, cpo.platform_orders_excl_dmarts, cpo.dmart_orders_cpo
  )

SELECT
  Month,
  Country_name,
  active_warehouses,
  days,
  Users_Peya_month,
  Users_DMart_month,
  Users_DMart_Plus_month,
  Confirmed_orders,
  total_platform_confirmed_orders,
  failed_orders,
  units_sold,
  Plus_orders,
  gmv_vendor_dmarts,
  gmv_vendor_total,
  gmv_user_dmarts,
  gmv_user_total,
  discount_amount_EU,
  DF_revenue_EU,
  SF_revenue_EU,
  revenue_fee_EU,
  DF_net_EU,
  SF_net_EU,
  RF_net_EU,
  discount_plus_net_EU,
  DF0_orders,
  Voucher_Orders,
  Incentivized_Orders,
  Voucher_amount,
  dmarts_cpo,
  platform_cpo,
  courier_cpo,
  platform_orders_excl_dmarts,
  dmart_orders_cpo
FROM final_data;

COMMIT TRANSACTION;
