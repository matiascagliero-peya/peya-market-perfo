DECLARE query_name       STRING DEFAULT '1. OKRs_daily_data (Recarga 2025 a 2026-09-12).sql';
DECLARE from_date        DATE DEFAULT DATE '2025-01-01';
DECLARE to_date          DATE DEFAULT DATE '2026-09-12';
DECLARE date_from_cupons DATE DEFAULT '2022-08-01';

-- ====================================================================================
-- 1. CREACION DE LA TABLA SI NO EXISTE
-- ====================================================================================
CREATE TABLE IF NOT EXISTS `peya-food-and-groceries.automated_tables_reports.dmart_okrs_daily` (
  day DATE OPTIONS(description="Fecha del dia de los pedidos (local). Grain: Dia."),
  country_name STRING OPTIONS(description="Nombre del pais al que pertenece el pedido."),
  active_warehouses_count INT64 OPTIONS(description="Cantidad de almacenes (darkstores) distintos activos con pedidos confirmados."),
  confirmed_orders_count INT64 OPTIONS(description="Cantidad de pedidos confirmados en D-Marts (darkstores)."),
  total_platform_confirmed_orders_count INT64 OPTIONS(description="Cantidad de pedidos confirmados de toda la plataforma (Peya)."),
  failed_orders_count INT64 OPTIONS(description="Cantidad de pedidos fallidos o cancelados de D-Marts."),
  units_sold_qty INT64 OPTIONS(description="Cantidad total de unidades de productos SKU vendidas en pedidos confirmados de D-Marts."),
  plus_confirmed_orders_count INT64 OPTIONS(description="Cantidad de pedidos confirmados de D-Marts de usuarios Plus (Peya+)."),
  discount_amount_eur FLOAT64 OPTIONS(description="Monto total de descuentos aplicados en D-Marts, convertido a Euros por SAP FX."),
  delivery_fee_revenue_gross_eur FLOAT64 OPTIONS(description="Ingreso bruto por envio cobrado en pedidos confirmados de D-Marts, en Euros."),
  service_fee_revenue_gross_eur FLOAT64 OPTIONS(description="Ingreso bruto por tarifa de servicio cobrada en pedidos confirmados de D-Marts, en Euros."),
  total_fee_revenue_gross_eur FLOAT64 OPTIONS(description="Suma de ingresos brutos por tarifas de envio y servicio en D-Marts, en Euros."),
  delivery_fee_revenue_net_eur FLOAT64 OPTIONS(description="Ingreso neto por envio cobrado en D-Marts (deduciendo impuestos), en Euros."),
  service_fee_revenue_net_eur FLOAT64 OPTIONS(description="Ingreso neto por servicio cobrado en D-Marts (deduciendo impuestos), en Euros."),
  total_fee_revenue_net_eur FLOAT64 OPTIONS(description="Suma de ingresos netos por envio y servicio en D-Marts, en Euros."),
  plus_discount_amount_net_eur FLOAT64 OPTIONS(description="Monto neto de descuento en envios para usuarios Plus en D-Marts, en Euros."),
  free_delivery_orders_count INT64 OPTIONS(description="Cantidad de pedidos confirmados de D-Marts a domicilio con costo de envio $0."),
  ultra_fast_orders_count INT64 OPTIONS(description="Cantidad de pedidos de D-Marts de categorias ultra-rapidas (Produce/Meat/Ready)."),
  net_sales_eur FLOAT64 OPTIONS(description="Monto de ventas netas (excluyendo IVA/impuestos y descuentos de marcas) en Euros."),
  order_discounts_amount_eur FLOAT64 OPTIONS(description="Monto neto de descuentos asumidos por la plataforma (PCM) en Euros."),
  double_ya_orders_count INT64 OPTIONS(description="Cantidad de pedidos confirmados de D-Marts que provinieron de la vertical 'Double Ya'."),
  small_order_fee_orders_count INT64 OPTIONS(description="Cantidad de pedidos de D-Marts donde se cobro tarifa por pedido minimo (SOF)."),
  units_sold_excl_dy_sof_qty INT64 OPTIONS(description="Cantidad de unidades vendidas en D-Marts excluyendo pedidos Double Ya y SOF."),
  net_sales_excl_dy_sof_eur FLOAT64 OPTIONS(description="Ventas netas en Euros de pedidos en D-Marts excluyendo Double Ya y SOF."),
  instant_need_orders_count INT64 OPTIONS(description="Cantidad de pedidos de D-Marts asociados a la mision de compra 'Instant Need'."),
  fill_in_orders_count INT64 OPTIONS(description="Cantidad de pedidos de D-Marts asociados a la mision de compra 'Fill In'."),
  stock_up_orders_count INT64 OPTIONS(description="Cantidad de pedidos de D-Marts asociados a la mision de compra 'Stock Up'."),
  gmv_user_dmarts_eur FLOAT64 OPTIONS(description="GMV metodo usuario de D-Marts en Euros (Total + Shipping + Service Fee) via SAP FX."),
  gmv_user_total_eur FLOAT64 OPTIONS(description="GMV metodo usuario total de toda la plataforma en Euros via SAP FX."),
  gmv_vendor_dmarts_eur FLOAT64 OPTIONS(description="GMV metodo comercio (Vendor) de D-Marts en Euros via fact_order_profitability."),
  gmv_vendor_total_eur FLOAT64 OPTIONS(description="GMV metodo comercio (Vendor) total de toda la plataforma en Euros."),
  total_sessions INT64 OPTIONS(description="Cantidad total de sesiones de funnel iniciadas en D-Marts."),
  total_transactions INT64 OPTIONS(description="Cantidad total de transacciones de funnel concretadas en D-Marts."),
  non_double_ya_sessions INT64 OPTIONS(description="Cantidad de sesiones de funnel que no provinieron de Double Ya."),
  non_double_ya_transactions INT64 OPTIONS(description="Cantidad de transacciones de funnel que no provinieron de Double Ya."),
  double_ya_sessions INT64 OPTIONS(description="Cantidad de sesiones de funnel de trafico exclusivo proveniente de Double Ya."),
  double_ya_transactions INT64 OPTIONS(description="Cantidad de transacciones de funnel de trafico exclusivo proveniente de Double Ya."),
  voucher_orders_count INT64 OPTIONS(description="Cantidad de pedidos de D-Marts que usaron cupon de descuento."),
  incentivized_orders_count INT64 OPTIONS(description="Cantidad de pedidos de D-Marts incentivados (usaron cupon O tuvieron envio $0)."),
  voucher_discount_amount_net_eur FLOAT64 OPTIONS(description="Monto total neto de descuento por cupones aplicados en D-Marts, en Euros."),
  dmart_cpo_eur FLOAT64 OPTIONS(description="Costo neto de entrega de rider por pedido (CPO) promedio en Euros para D-Marts (OD)."),
  platform_cpo_eur FLOAT64 OPTIONS(description="Costo neto de entrega de rider por pedido (CPO) promedio en Euros para Platform (OD)."),
  courier_cpo_eur FLOAT64 OPTIONS(description="Costo neto de entrega de rider por pedido (CPO) promedio en Euros para Courier (OD)."),
  platform_orders_excl_dmarts_count INT64 OPTIONS(description="Cantidad total de pedidos confirmados a domicilio (OD) de plataforma, excluyendo D-Marts."),
  dmart_orders_cpo_count INT64 OPTIONS(description="Cantidad de pedidos confirmados de D-Marts a domicilio (OD) usados para el CPO.")
);

-- ====================================================================================
-- 2. LIMPIEZA EXCLUSIVA DE LA VENTANA (2025-01-01 A 2026-09-12)
-- ====================================================================================
DELETE FROM `peya-food-and-groceries.automated_tables_reports.dmart_okrs_daily`
WHERE day BETWEEN from_date AND to_date;

-- ====================================================================================
-- 3. CALCULO E INSERCION DE DATOS
-- ====================================================================================
INSERT INTO `peya-food-and-groceries.automated_tables_reports.dmart_okrs_daily` (
  day,
  country_name,
  active_warehouses_count,
  confirmed_orders_count,
  total_platform_confirmed_orders_count,
  failed_orders_count,
  units_sold_qty,
  plus_confirmed_orders_count,
  discount_amount_eur,
  delivery_fee_revenue_gross_eur,
  service_fee_revenue_gross_eur,
  total_fee_revenue_gross_eur,
  delivery_fee_revenue_net_eur,
  service_fee_revenue_net_eur,
  total_fee_revenue_net_eur,
  plus_discount_amount_net_eur,
  free_delivery_orders_count,
  ultra_fast_orders_count,
  net_sales_eur,
  order_discounts_amount_eur,
  double_ya_orders_count,
  small_order_fee_orders_count,
  units_sold_excl_dy_sof_qty,
  net_sales_excl_dy_sof_eur,
  instant_need_orders_count,
  fill_in_orders_count,
  stock_up_orders_count,
  gmv_user_dmarts_eur,
  gmv_user_total_eur,
  gmv_vendor_dmarts_eur,
  gmv_vendor_total_eur,
  total_sessions,
  total_transactions,
  non_double_ya_sessions,
  non_double_ya_transactions,
  double_ya_sessions,
  double_ya_transactions,
  voucher_orders_count,
  incentivized_orders_count,
  voucher_discount_amount_net_eur,
  dmart_cpo_eur,
  platform_cpo_eur,
  courier_cpo_eur,
  platform_orders_excl_dmarts_count,
  dmart_orders_cpo_count
)
WITH

partners AS (
  SELECT
    p.country_id,
    p.partner_id,
    pd.warehouse_id,
    TRUE AS darkstore
  FROM `peya-bi-tools-pro.il_core.dim_partner` p
  INNER JOIN `peya-datamarts-pro.dm_dmarts.dim_partner_darkstore` AS pd
    ON p.partner_id = pd.partner_id
),

active_stores AS (
  SELECT
    order_date                          AS day,
    country_code,
    COUNT(DISTINCT warehouse_id)        AS active_warehouses
  FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
  WHERE order_date BETWEEN from_date AND to_date
    AND state = "CONFIRMED"
    AND store_name NOT IN (
      "RD_12_Torre OV", "PA_9_Midtown", "SV_6_Torre Futura",
      "EC_17_TiendaPick-Up Oficina", "PE_3_PuntaHermosa", "BO_19_Truck",
      "UY_15_Eventos", "PE_24_FILO", "EC_6_Oficina"
    )
  GROUP BY 1, 2
),

orders AS (
  SELECT
    o.order_id,
    o.registered_date                                        AS order_placed_local,
    o.country.country_name,
    o.country_id,
    o.customer_id                                            AS customer_id,
    o.country.country_code,
    o.restaurant.id                                          AS restaurant_id,
    o.order_status,
    o.pickup,
    o.is_user_plus,
    dco_agg.units_dco                                        AS units_sold,
    dco_agg.net_sales,
    dco_agg.discounts,
    dco_agg.uf_order,
    o.shipping_amount_no_discount                            AS delivery_fee_no_discount,
    o.serviceFee.service_fee_no_discount                     AS service_fee_no_discount,
    CASE
      WHEN o.country.country_name = "Bolivia"
        THEN o.shipping_amount_no_discount * (1 - co.percentage_tax_logistics)
        ELSE o.shipping_amount_no_discount / (1 + co.percentage_tax_logistics)
    END AS delivery_fee_paid_net,
    CASE
      WHEN o.country.country_name = "Bolivia"
        THEN o.serviceFee.service_fee_no_discount * (1 - co.percentage_tax_logistics)
        ELSE o.serviceFee.service_fee_no_discount / (1 + co.percentage_tax_logistics)
    END AS service_fee_paid_net,
    o.discount_amount,
    o.plus_shipping_cost_discount_amount / (1 + co.percentage_effective_tax) AS discount_plus_net,
    DY.order_details.id.secondary                            AS double_ya_order_id,
    CASE WHEN o.fees_v2.small_order_fee_amount > 0 THEN 'small_order_fee' END AS sof
  FROM `peya-bi-tools-pro.il_core.fact_orders` AS o
  INNER JOIN `peya-data-origins-pro.cl_core.country_details` co
    ON o.country_id = co.country_id AND co.active
  LEFT JOIN (
    SELECT
      order_id,
      SUM(fulfilled_quantity) AS units_dco,
      SUM(total_amount_net_with_discount_eur) AS net_sales,
      SUM(pcm_discount_amount_net_eur) AS discounts,
      MAX(CASE WHEN master_category_parent_english IN ('Produce', 'Meat / Seafood', 'Ready To Consume') THEN 1 ELSE 0 END) AS uf_order
    FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
    WHERE order_date BETWEEN from_date AND to_date
    GROUP BY 1
  ) dco_agg ON CAST(o.order_id AS STRING) = dco_agg.order_id
  LEFT JOIN `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya` DY
    ON o.order_id = dy.order_details.id.secondary AND order_type = 'DOUBLE_YA'
  WHERE DATE(o.registered_date) BETWEEN from_date AND to_date
  GROUP BY ALL
),

shopping_missions AS (
  SELECT
    DATE(registered_date)                                                                AS day,
    country_name,
    COUNT(DISTINCT CASE WHEN sm.mission_type = 'instant need' THEN sm.order_id END)     AS orders_instant_need,
    COUNT(DISTINCT CASE WHEN sm.mission_type = 'fill in'     THEN sm.order_id END)     AS orders_fill_in,
    COUNT(DISTINCT CASE WHEN sm.mission_type = 'stock up'     THEN sm.order_id END)     AS orders_stock_up
  FROM `peya-bi-tools-pro.il_qcommerce.fact_groceries_shopping_missions` sm
  WHERE DATE(registered_date) BETWEEN from_date AND to_date
  GROUP BY 1, 2
),

fx AS (
  SELECT
    fx_source.month,
    fx_source.currency_iso,
    c.country_id,
    AVG(fx_source.rate_eur) AS rate_eur
  FROM `peya-fraud-and-fintech.group_finance_data.fact_sap_fx` AS fx_source
  LEFT JOIN `peya-bi-tools-pro.il_core.dim_country` AS c
    ON fx_source.currency_iso = c.currency_price
  WHERE c.country_name_en NOT IN ('Venezuela', 'Puerto Rico')
  GROUP BY 1, 2, 3
),

gmv_user_data AS (
  SELECT
    DATE(fo.registered_date) AS date_day,
    fo.country_id,
    SUM(CASE WHEN p.darkstore = TRUE THEN
            COALESCE(fo.total_amount, 0)                  / fx.rate_eur
          + COALESCE(fo.shipping_amount, 0)               / fx.rate_eur
          + COALESCE(fo.serviceFee.service_fee_amount, 0) / fx.rate_eur END) AS gmv_user_dmarts,
    SUM(    COALESCE(fo.total_amount, 0)                  / fx.rate_eur
          + COALESCE(fo.shipping_amount, 0)               / fx.rate_eur
          + COALESCE(fo.serviceFee.service_fee_amount, 0) / fx.rate_eur )    AS gmv_user_total
  FROM `peya-bi-tools-pro.il_core.fact_orders` fo
  LEFT JOIN partners p ON p.partner_id = fo.restaurant.id
  LEFT JOIN fx
    ON DATE_TRUNC(DATE(fo.registered_date), MONTH) = fx.month
   AND fo.country_id = fx.country_id
  WHERE DATE(fo.registered_date) BETWEEN from_date AND to_date
    AND fo.order_status = 'CONFIRMED'
  GROUP BY 1, 2
),

gmv_data AS (
  SELECT
    DATE(registered_date)                                                                    AS date_day,
    fop.country_id,
    SAFE_DIVIDE(SUM(CASE WHEN p.darkstore = TRUE THEN gmv.gmv_vendor END), monthly_rate_eu)   AS gmv_vendor_dmarts,
    SAFE_DIVIDE(SUM(gmv.gmv_vendor), monthly_rate_eu)                                         AS gmv_vendor_total
  FROM `peya-datamarts-pro.dm_order_profitability.fact_order_profitability` fop
  LEFT JOIN partners p ON p.partner_id = fop.partner.partner_id
  WHERE DATE(registered_date) BETWEEN from_date AND to_date
  GROUP BY 1, 2, fop.monthly_rate_eu
),

sessions_perseus AS (
  SELECT
    DATE(fp.date) AS day,
    fp.country_id,
    SUM(fp.funnel_shop_details) AS sessions,
    SUM(fp.funnel_shop_transaction) AS transactions,
    SUM(CASE WHEN (fp.funnel_shop_double_ya = 0 OR fp.funnel_shop_double_ya IS NULL) 
        THEN fp.funnel_shop_details ELSE 0 END) AS sessions_non_dy,
    SUM(CASE WHEN (fp.funnel_shop_double_ya = 0 OR fp.funnel_shop_double_ya IS NULL) 
        THEN fp.funnel_shop_transaction ELSE 0 END) AS transactions_non_dy,
    SUM(CASE WHEN fp.funnel_shop_double_ya > 0 
        THEN fp.funnel_shop_details ELSE 0 END) AS sessions_dy,
    SUM(CASE WHEN fp.funnel_shop_double_ya > 0 
        THEN fp.funnel_shop_transaction ELSE 0 END) AS transactions_dy
  FROM `peya-bi-tools-pro.il_sessions.perseus_fact_partner_funnel` fp
  INNER JOIN partners ON fp.partner_id = partners.partner_id
  WHERE DATE(fp.date) BETWEEN from_date AND to_date
  GROUP BY ALL
),

coupon_data AS (
  SELECT DISTINCT
    cou.order_id,
    SUM(cou.coupon_used_amount) AS coupon_used_amount
  FROM `peya-bi-tools-pro.il_growth.fact_talon_coupons` cou
  WHERE DATE(cou.coupon_created_at) >= date_from_cupons
    AND DATE(cou.order_registered_date) BETWEEN from_date AND to_date
    AND cou.order_state_id = 1 
  GROUP BY 1
),

cost_per_order_raw AS (
  SELECT
    DATE(registered_date)  AS day,
    country_id,
    CASE
      WHEN partner.vertical_group = 'D-Mart'                          THEN 'D-Mart'
      WHEN partner.vertical_group IN ('Courier Business', 'Courier')  THEN 'Courier'
      ELSE 'Platform'
    END                    AS vertical,
    delivery.delivery_type,
    COUNT(DISTINCT CASE WHEN order_status = 'CONFIRMED' THEN order_id END) AS confirmed_orders,
    SUM(rider_cost.rider_cost / monthly_rate_eu)                           AS rider_cost_eur
  FROM `peya-datamarts-pro.dm_order_profitability.fact_order_profitability`
  WHERE DATE(registered_date) BETWEEN from_date AND to_date
  GROUP BY 1, 2, 3, 4
),

cost_per_order AS (
  SELECT
    day,
    country_id,
    SUM(CASE WHEN vertical = 'D-Mart'   AND delivery_type = 'OD' THEN SAFE_DIVIDE(rider_cost_eur, confirmed_orders) END) AS dmarts_cpo,
    SUM(CASE WHEN vertical = 'Platform' AND delivery_type = 'OD' THEN SAFE_DIVIDE(rider_cost_eur, confirmed_orders) END) AS platform_cpo,
    SUM(CASE WHEN vertical = 'Courier'  AND delivery_type = 'OD' THEN SAFE_DIVIDE(rider_cost_eur, confirmed_orders) END) AS courier_cpo,
    SUM(CASE WHEN vertical = 'Platform' AND delivery_type = 'OD' THEN confirmed_orders END)                               AS platform_orders_excl_dmarts,
    SUM(CASE WHEN vertical = 'D-Mart'   AND delivery_type = 'OD' THEN confirmed_orders END)                               AS dmart_orders_cpo
  FROM cost_per_order_raw
  GROUP BY 1, 2
),

final_data AS (
  SELECT
    DATE(o.order_placed_local)   AS Day,
    o.country_name               AS Country_name,
    a.active_warehouses,

    COUNT(DISTINCT CASE WHEN o.order_status = 'CONFIRMED' AND hp.darkstore = TRUE                       THEN o.order_id END) AS Confirmed_orders,
    COUNT(DISTINCT CASE WHEN o.order_status = 'CONFIRMED'                                               THEN o.order_id END) AS total_platform_confirmed_orders,
    COUNT(DISTINCT CASE WHEN o.order_status <> 'CONFIRMED' AND hp.darkstore = TRUE                      THEN o.order_id END) AS failed_orders,
    SUM(CASE WHEN o.order_status = 'CONFIRMED' AND hp.darkstore = TRUE THEN o.units_sold ELSE 0 END)                         AS units_sold,
    COUNT(DISTINCT CASE WHEN o.order_status = 'CONFIRMED' AND hp.darkstore = TRUE AND o.is_user_plus = 1 THEN o.order_id END) AS Plus_orders,
    SUM(CASE WHEN o.order_status = 'CONFIRMED' AND hp.darkstore = TRUE THEN COALESCE(o.discounts, 0)                          ELSE 0 END) AS discount_amount_EU,
    SUM(CASE WHEN o.order_status = 'CONFIRMED' AND hp.darkstore = TRUE THEN o.delivery_fee_no_discount / ce.rate_eu           ELSE 0 END) AS DF_revenue_EU,
    SUM(CASE WHEN o.order_status = 'CONFIRMED' AND hp.darkstore = TRUE THEN o.service_fee_no_discount / ce.rate_eu            ELSE 0 END) AS SF_revenue_EU,
    SUM(CASE WHEN o.order_status = 'CONFIRMED' AND hp.darkstore = TRUE THEN (COALESCE(o.delivery_fee_no_discount,0) + COALESCE(o.service_fee_no_discount,0)) / ce.rate_eu ELSE 0 END) AS revenue_fee_EU,
    SUM(CASE WHEN o.order_status = 'CONFIRMED' AND hp.darkstore = TRUE THEN o.delivery_fee_paid_net / ce.rate_eu              ELSE 0 END) AS DF_net_EU,
    SUM(CASE WHEN o.order_status = 'CONFIRMED' AND hp.darkstore = TRUE THEN o.service_fee_paid_net / ce.rate_eu               ELSE 0 END) AS SF_net_EU,
    SUM(CASE WHEN o.order_status = 'CONFIRMED' AND hp.darkstore = TRUE THEN (COALESCE(o.delivery_fee_paid_net,0) + COALESCE(o.service_fee_paid_net,0)) / ce.rate_eu    ELSE 0 END) AS RF_net_EU,
    SUM(CASE WHEN o.order_status = 'CONFIRMED' AND hp.darkstore = TRUE THEN o.discount_plus_net / ce.rate_eu                  ELSE 0 END) AS discount_plus_net_EU,
    COUNT(DISTINCT CASE WHEN o.order_status = 'CONFIRMED' AND hp.darkstore = TRUE AND o.delivery_fee_no_discount = 0 AND o.pickup = FALSE                                                THEN o.order_id END) AS DF0_orders,
    COUNT(DISTINCT CASE WHEN o.order_status = 'CONFIRMED' AND hp.darkstore = TRUE AND o.uf_order = 1       THEN o.order_id END) AS UF_orders,
    SUM(CASE WHEN o.order_status = 'CONFIRMED' AND hp.darkstore = TRUE THEN COALESCE(o.net_sales, 0)       ELSE 0 END)          AS net_sales_EU,
    SUM(CASE WHEN o.order_status = 'CONFIRMED' AND hp.darkstore = TRUE THEN COALESCE(o.discounts, 0)       ELSE 0 END)          AS discounts_EU,
    COUNT(DISTINCT CASE WHEN o.order_status = 'CONFIRMED' AND hp.darkstore = TRUE AND o.double_ya_order_id IS NOT NULL THEN o.order_id END) AS double_ya_orders,
    COUNT(DISTINCT CASE WHEN o.order_status = 'CONFIRMED' AND hp.darkstore = TRUE AND o.sof IS NOT NULL    THEN o.order_id END) AS small_order_fee_orders,
    SUM(CASE WHEN o.order_status = 'CONFIRMED' AND hp.darkstore = TRUE AND o.double_ya_order_id IS NULL AND o.sof IS NULL THEN COALESCE(o.units_sold, 0) ELSE 0 END)                 AS units_excl_dy_sof,
    SUM(CASE WHEN o.order_status = 'CONFIRMED' AND hp.darkstore = TRUE AND o.double_ya_order_id IS NULL AND o.sof IS NULL THEN COALESCE(o.net_sales, 0)  ELSE 0 END)                 AS net_sales_excl_dy_sof_EU,

    sm.orders_instant_need,
    sm.orders_fill_in,
    sm.orders_stock_up,

    gmvu.gmv_user_dmarts,
    gmvu.gmv_user_total,

    gmv.gmv_vendor_dmarts,
    gmv.gmv_vendor_total,

    sp.sessions,
    sp.transactions,
    sp.sessions_non_dy,
    sp.transactions_non_dy,
    sp.sessions_dy,
    sp.transactions_dy,

    COUNT(DISTINCT CASE WHEN o.order_status = 'CONFIRMED' AND hp.darkstore = TRUE AND cd.coupon_used_amount > 0                                                                          THEN o.order_id END) AS Voucher_Orders,
    COUNT(DISTINCT CASE WHEN o.order_status = 'CONFIRMED' AND hp.darkstore = TRUE AND (cd.coupon_used_amount > 0 OR (o.delivery_fee_no_discount = 0 AND o.pickup = FALSE))               THEN o.order_id END) AS Incentivized_Orders,
    SUM(CASE WHEN o.order_status = 'CONFIRMED' AND hp.darkstore = TRUE THEN (cd.coupon_used_amount / (1 + co.percentage_effective_tax)) ELSE 0 END)                                          AS Voucher_amount,

    cpo.dmarts_cpo,
    cpo.platform_cpo,
    cpo.courier_cpo,
    cpo.platform_orders_excl_dmarts,
    cpo.dmart_orders_cpo

  FROM orders o
  INNER JOIN `peya-bi-tools-pro.il_core.dim_country` AS c
    ON c.country_id = o.country_id AND c.active = TRUE
  LEFT JOIN partners hp
    ON hp.partner_id = o.restaurant_id
  LEFT JOIN `peya-bi-tools-pro.il_core.dim_currency_exchange` ce
    ON ce.currency_id = c.currency_id
    AND ce.currency_exchange_date = DATE_TRUNC(DATE(o.order_placed_local), MONTH)
  LEFT JOIN active_stores a
    ON a.day = DATE(o.order_placed_local)
    AND UPPER(a.country_code) = UPPER(o.country_code)
  LEFT JOIN `peya-data-origins-pro.cl_core.country_details` co
    ON o.country_id = co.country_id AND co.active
  LEFT JOIN coupon_data cd
    ON cd.order_id = o.order_id
  LEFT JOIN cost_per_order AS cpo
    ON o.country_id = cpo.country_id
    AND cpo.day = DATE(o.order_placed_local)
  LEFT JOIN sessions_perseus AS sp
    ON o.country_id = sp.country_id
    AND sp.day = DATE(o.order_placed_local)
  LEFT JOIN gmv_data gmv
    ON gmv.date_day = DATE(o.order_placed_local)
    AND o.country_id = gmv.country_id
  LEFT JOIN gmv_user_data gmvu
    ON gmvu.date_day = DATE(o.order_placed_local)
    AND o.country_id = gmvu.country_id
  LEFT JOIN shopping_missions sm
    ON sm.day = DATE(o.order_placed_local)
    AND sm.country_name = o.country_name
  WHERE DATE(o.order_placed_local) BETWEEN from_date AND to_date
  GROUP BY
    Day, Country_name, a.active_warehouses,
    gmv.gmv_vendor_dmarts, gmv.gmv_vendor_total, gmvu.gmv_user_dmarts, gmvu.gmv_user_total,
    cpo.dmarts_cpo, cpo.platform_cpo, cpo.courier_cpo,
    cpo.platform_orders_excl_dmarts, cpo.dmart_orders_cpo, sp.sessions,
    sp.transactions,
    sp.sessions_non_dy,
    sp.transactions_non_dy,
    sp.sessions_dy,
    sp.transactions_dy,
    sm.orders_instant_need, sm.orders_fill_in, sm.orders_stock_up
)

SELECT
  Day                         AS day,
  Country_name                AS country_name,
  active_warehouses           AS active_warehouses_count,
  Confirmed_orders            AS confirmed_orders_count,
  total_platform_confirmed_orders AS total_platform_confirmed_orders_count,
  failed_orders               AS failed_orders_count,
  CAST(units_sold AS INT64)   AS units_sold_qty,
  Plus_orders                 AS plus_confirmed_orders_count,
  discount_amount_EU          AS discount_amount_eur,
  DF_revenue_EU               AS delivery_fee_revenue_gross_eur,
  SF_revenue_EU               AS service_fee_revenue_gross_eur,
  revenue_fee_EU              AS total_fee_revenue_gross_eur,
  DF_net_EU                   AS delivery_fee_revenue_net_eur,
  SF_net_EU                   AS service_fee_revenue_net_eur,
  RF_net_EU                   AS total_fee_revenue_net_eur,
  discount_plus_net_EU        AS plus_discount_amount_net_eur,
  DF0_orders                  AS free_delivery_orders_count,
  UF_orders                   AS ultra_fast_orders_count,
  net_sales_EU                AS net_sales_eur,
  discounts_EU                AS order_discounts_amount_eur,
  double_ya_orders            AS double_ya_orders_count,
  small_order_fee_orders      AS small_order_fee_orders_count,
  CAST(units_excl_dy_sof AS INT64) AS units_sold_excl_dy_sof_qty,
  net_sales_excl_dy_sof_EU    AS net_sales_excl_dy_sof_eur,
  orders_instant_need         AS instant_need_orders_count,
  orders_fill_in              AS fill_in_orders_count,
  orders_stock_up             AS stock_up_orders_count,
  gmv_user_dmarts             AS gmv_user_dmarts_eur,
  gmv_user_total              AS gmv_user_total_eur,
  gmv_vendor_dmarts           AS gmv_vendor_dmarts_eur,
  gmv_vendor_total            AS gmv_vendor_total_eur,
  sessions                    AS total_sessions,
  transactions                AS total_transactions,
  sessions_non_dy             AS non_double_ya_sessions,
  transactions_non_dy         AS non_double_ya_transactions,
  sessions_dy                 AS double_ya_sessions,
  transactions_dy             AS double_ya_transactions,
  Voucher_Orders              AS voucher_orders_count,
  Incentivized_Orders         AS incentivized_orders_count,
  Voucher_amount              AS voucher_discount_amount_net_eur,
  dmarts_cpo                  AS dmart_cpo_eur,
  platform_cpo                AS platform_cpo_eur,
  courier_cpo                 AS courier_cpo_eur,
  platform_orders_excl_dmarts AS platform_orders_excl_dmarts_count,
  dmart_orders_cpo            AS dmart_orders_cpo_count
FROM final_data
ORDER BY day DESC, country_name ASC;
