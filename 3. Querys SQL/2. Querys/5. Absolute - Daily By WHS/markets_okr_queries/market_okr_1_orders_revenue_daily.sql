DECLARE query_name STRING DEFAULT 'market_okr_1_orders_revenue_daily';

-- ============================================================
-- markets_orders_revenue_daily
-- Responsable: Orders + Finance
-- Grain: fecha_completa + country_name + warehouse_id
-- ============================================================

DECLARE table_exists BOOL;
SET table_exists = EXISTS (
  SELECT 1
  FROM `peya-food-and-groceries.automated_tables_reports.markets_orders_revenue_daily`
);

DECLARE from_date DATE;
DECLARE to_date DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);
IF NOT table_exists THEN
  SET from_date = DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 10 WEEK), WEEK(MONDAY));
ELSE
  SET from_date = DATE_SUB(CURRENT_DATE(), INTERVAL 3 DAY);
END IF;

DECLARE date_from_cupons DATE DEFAULT '2022-08-01';

-- CREACIÓN DE TABLA
IF NOT table_exists THEN
  CREATE TABLE `peya-food-and-groceries.automated_tables_reports.markets_orders_revenue_daily` (
    fecha_completa              DATE,
    country_name                STRING,
    warehouse_id                STRING,
    warehouse_name              STRING,
    -- Orders
    confirmed_orders            INT64,
    failed_orders               INT64,
    units_sold                  FLOAT64,
    plus_orders                 INT64,
    total_platform_confirmed_orders INT64,
    dmart_new_users             INT64,
    uf_orders                   INT64,
    double_ya_orders            INT64,
    small_order_fee_orders      INT64,
    -- GMV
    gmv_vendor_dmarts           FLOAT64,
    gmv_vendor_total            FLOAT64,
    gmv_user_dmarts             FLOAT64,
    gmv_user_total              FLOAT64,
    -- Revenue / Fees
    discount_amount_eu          FLOAT64,
    df_revenue_eu               FLOAT64,
    sf_revenue_eu               FLOAT64,
    revenue_fee_eu              FLOAT64,
    df_net_eu                   FLOAT64,
    sf_net_eu                   FLOAT64,
    rf_net_eu                   FLOAT64,
    discount_plus_net_eu        FLOAT64,
    -- Vouchers / Discounts
    df0_orders                  INT64,
    voucher_orders              INT64,
    incentivized_orders         INT64,
    voucher_amount              FLOAT64,
    -- Net Sales
    net_sales_eu                FLOAT64,
    discounts_eu                FLOAT64,
    units_excl_dy_sof           FLOAT64,
    net_sales_excl_dy_sof_eu    FLOAT64
  )
  PARTITION BY fecha_completa
  CLUSTER BY country_name, warehouse_id;
END IF;

-- LIMPIEZA INCREMENTAL
IF table_exists THEN
  DELETE FROM `peya-food-and-groceries.automated_tables_reports.markets_orders_revenue_daily`
  WHERE fecha_completa BETWEEN from_date AND to_date;
END IF;

-- INSERCIÓN
INSERT INTO `peya-food-and-groceries.automated_tables_reports.markets_orders_revenue_daily`

WITH

partners AS (
  SELECT p.country_id, p.partner_id, pd.warehouse_id, pd.warehouse_name, TRUE AS darkstore
  FROM `peya-bi-tools-pro.il_core.dim_partner` p
  INNER JOIN `peya-datamarts-pro.dm_dmarts.dim_partner_darkstore` pd ON p.partner_id = pd.partner_id
),

coupon_data AS (
  SELECT DISTINCT cou.order_id, SUM(cou.coupon_used_amount) AS coupon_used_amount
  FROM `peya-bi-tools-pro.il_growth.fact_talon_coupons` cou
  WHERE DATE(cou.coupon_created_at) >= date_from_cupons
    AND DATE(cou.order_registered_date) BETWEEN from_date AND to_date
    AND cou.order_state_id = 1
  GROUP BY 1
),

new_users AS (
  -- REFORMA: primera orden histórica en darkstore desde fact_orders (ya NO usa customer_orders_sku_level).
  --  * Usa o.user.id para que matchee con el user_id de la CTE `orders` (antes se cruzaba el
  --    customer_id de la SKU-table contra fact_orders.user.id -> ids distintos, join roto).
  --  * Floor en 2020-01-01 (las darkstores no existían antes); el '2020-04-01' previo marcaba
  --    como "nuevo" a usuarios cuya 1ra orden real fue anterior a esa fecha.
  SELECT
    o.user.id                       AS user_id,
    o.country_id,
    MIN(DATE(o.registered_date))    AS first_order_date
  FROM `peya-bi-tools-pro.il_core.fact_orders` o
  INNER JOIN partners p ON CAST(p.partner_id AS STRING) = CAST(o.restaurant.id AS STRING)
  WHERE o.order_status = 'CONFIRMED'
    AND o.registered_date >= '2020-01-01'
  GROUP BY 1, 2
),

country_platform_baseline AS (
  SELECT DATE(registered_date) AS day, country_id,
    COUNT(DISTINCT CASE WHEN order_status = 'CONFIRMED' THEN order_id END) AS total_platform_confirmed_orders
  FROM `peya-bi-tools-pro.il_core.fact_orders`
  WHERE registered_date BETWEEN from_date AND to_date
  GROUP BY 1, 2
),

gmv_data_warehouse AS (
  SELECT DATE(registered_date) AS date_day, fop.country_id, p.warehouse_id,
    SAFE_DIVIDE(SUM(gmv.gmv_vendor), fop.monthly_rate_eu) AS gmv_vendor_dmarts,
    SAFE_DIVIDE(SUM(gmv.gmv_user),   fop.monthly_rate_eu) AS gmv_user_dmarts
  FROM `peya-datamarts-pro.dm_order_profitability.fact_order_profitability` fop
  INNER JOIN partners p ON CAST(p.partner_id AS STRING) = CAST(fop.partner.partner_id AS STRING)
  WHERE registered_date BETWEEN from_date AND to_date
  GROUP BY 1, 2, 3, fop.monthly_rate_eu
),

gmv_data_country AS (
  SELECT DATE(registered_date) AS date_day, fop.country_id,
    SAFE_DIVIDE(SUM(gmv.gmv_vendor), fop.monthly_rate_eu) AS gmv_vendor_total,
    SAFE_DIVIDE(SUM(gmv.gmv_user),   fop.monthly_rate_eu) AS gmv_user_total
  FROM `peya-datamarts-pro.dm_order_profitability.fact_order_profitability` fop
  WHERE registered_date BETWEEN from_date AND to_date
  GROUP BY 1, 2, fop.monthly_rate_eu
),

orders AS (
  SELECT
    o.order_id,
    o.registered_date                   AS order_placed_local,
    o.country.country_name,
    o.country_id,
    o.user.id                           AS user_id,
    o.country.country_code,
    o.restaurant.id                     AS restaurant_id,
    o.order_status,
    o.pickup,
    o.is_user_plus,
    dco_agg.units_dco                   AS units_sold,
    dco_agg.net_sales,
    dco_agg.discounts,
    dco_agg.uf_order,
    o.shipping_amount_no_discount       AS delivery_fee_no_discount,
    o.serviceFee.service_fee_no_discount AS service_fee_no_discount,
    CASE WHEN o.country.country_name = 'Bolivia'
      THEN o.shipping_amount_no_discount * (1 - co.percentage_tax_logistics)
      ELSE o.shipping_amount_no_discount / (1 + co.percentage_tax_logistics)
    END AS delivery_fee_paid_net,
    CASE WHEN o.country.country_name = 'Bolivia'
      THEN o.serviceFee.service_fee_no_discount * (1 - co.percentage_tax_logistics)
      ELSE o.serviceFee.service_fee_no_discount / (1 + co.percentage_tax_logistics)
    END AS service_fee_paid_net,
    o.discount_amount,
    o.plus_shipping_cost_discount_amount / (1 + co.percentage_effective_tax) AS discount_plus_net,
    DY.order_details.id.secondary       AS double_ya_order_id,
    CASE WHEN fees_v2.small_order_fee_amount > 0 THEN 'small_order_fee' END AS sof
  FROM `peya-bi-tools-pro.il_core.fact_orders` AS o
  INNER JOIN `peya-data-origins-pro.cl_core.country_details` co ON o.country_id = co.country_id AND co.active
  LEFT JOIN (
    SELECT order_id,
      SUM(fulfilled_quantity)                     AS units_dco,
      SUM(total_amount_net_with_discount_eur)     AS net_sales,
      SUM(pcm_discount_amount_net_eur)            AS discounts,
      MAX(CASE WHEN master_category_parent_english IN ('Produce', 'Meat / Seafood', 'Ready To Consume') THEN 1 ELSE 0 END) AS uf_order
    FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
    WHERE order_date BETWEEN from_date AND to_date
    GROUP BY 1
  ) dco_agg ON CAST(o.order_id AS STRING) = dco_agg.order_id
  LEFT JOIN `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya` DY
    ON CAST(o.order_id AS STRING) = CAST(DY.order_details.id.secondary AS STRING)
    AND DY.order_type = 'DOUBLE_YA'
  WHERE o.registered_date BETWEEN from_date AND to_date
  GROUP BY ALL
)

SELECT
  DATE(o.order_placed_local)                      AS fecha_completa,
  o.country_name,
  hp.warehouse_id,
  hp.warehouse_name,

  -- Orders
  COUNT(DISTINCT CASE WHEN o.order_status = 'CONFIRMED' THEN o.order_id END)                                        AS confirmed_orders,
  COUNT(DISTINCT CASE WHEN o.order_status <> 'CONFIRMED' THEN o.order_id END)                                       AS failed_orders,
  SUM(CASE WHEN o.order_status = 'CONFIRMED' THEN units_sold ELSE 0 END)                                            AS units_sold,
  COUNT(DISTINCT CASE WHEN o.order_status = 'CONFIRMED' AND o.is_user_plus = 1 THEN o.order_id END)                 AS plus_orders,
  MAX(cb.total_platform_confirmed_orders)                                                                             AS total_platform_confirmed_orders,
  COUNT(DISTINCT CASE WHEN o.order_status = 'CONFIRMED' AND CAST(nu.first_order_date AS DATE) = DATE(o.order_placed_local) THEN o.order_id END) AS dmart_new_users,
  COUNT(DISTINCT CASE WHEN o.order_status = 'CONFIRMED' AND o.uf_order = 1 THEN o.order_id END)                     AS uf_orders,
  COUNT(DISTINCT CASE WHEN o.order_status = 'CONFIRMED' AND o.double_ya_order_id IS NOT NULL THEN o.order_id END)   AS double_ya_orders,
  COUNT(DISTINCT CASE WHEN o.order_status = 'CONFIRMED' AND o.sof IS NOT NULL THEN o.order_id END)                  AS small_order_fee_orders,

  -- GMV
  MAX(gmvw.gmv_vendor_dmarts)     AS gmv_vendor_dmarts,
  MAX(gmvc.gmv_vendor_total)      AS gmv_vendor_total,
  MAX(gmvw.gmv_user_dmarts)       AS gmv_user_dmarts,
  MAX(gmvc.gmv_user_total)        AS gmv_user_total,

  -- Revenue / Fees
  SUM(CASE WHEN o.order_status = 'CONFIRMED' THEN o.discount_amount / ce.rate_eu ELSE 0 END)                                                                                AS discount_amount_eu,
  SUM(CASE WHEN o.order_status = 'CONFIRMED' THEN o.delivery_fee_no_discount / ce.rate_eu ELSE 0 END)                                                                       AS df_revenue_eu,
  SUM(CASE WHEN o.order_status = 'CONFIRMED' THEN o.service_fee_no_discount / ce.rate_eu ELSE 0 END)                                                                        AS sf_revenue_eu,
  SUM(CASE WHEN o.order_status = 'CONFIRMED' THEN (COALESCE(o.delivery_fee_no_discount,0) + COALESCE(o.service_fee_no_discount,0)) / ce.rate_eu ELSE 0 END)                 AS revenue_fee_eu,
  SUM(CASE WHEN o.order_status = 'CONFIRMED' THEN o.delivery_fee_paid_net / ce.rate_eu ELSE 0 END)                                                                          AS df_net_eu,
  SUM(CASE WHEN o.order_status = 'CONFIRMED' THEN o.service_fee_paid_net / ce.rate_eu ELSE 0 END)                                                                           AS sf_net_eu,
  SUM(CASE WHEN o.order_status = 'CONFIRMED' THEN (COALESCE(o.delivery_fee_paid_net,0) + COALESCE(o.service_fee_paid_net,0)) / ce.rate_eu ELSE 0 END)                       AS rf_net_eu,
  SUM(CASE WHEN o.order_status = 'CONFIRMED' THEN o.discount_plus_net / ce.rate_eu ELSE 0 END)                                                                              AS discount_plus_net_eu,

  -- Vouchers / Incentivos
  COUNT(DISTINCT CASE WHEN o.order_status = 'CONFIRMED' AND o.delivery_fee_no_discount = 0 AND o.pickup = FALSE THEN o.order_id END)                                                                                AS df0_orders,
  COUNT(DISTINCT CASE WHEN o.order_status = 'CONFIRMED' AND cd.coupon_used_amount > 0 THEN o.order_id END)                                                                                                          AS voucher_orders,
  COUNT(DISTINCT CASE WHEN o.order_status = 'CONFIRMED' AND (cd.coupon_used_amount > 0 OR (o.delivery_fee_no_discount = 0 AND o.pickup = FALSE)) THEN o.order_id END)                                               AS incentivized_orders,
  SUM(CASE WHEN o.order_status = 'CONFIRMED' THEN cd.coupon_used_amount / (1 + co.percentage_effective_tax) ELSE 0 END)                                                                                             AS voucher_amount,

  -- Net Sales
  SUM(CASE WHEN o.order_status = 'CONFIRMED' THEN COALESCE(o.net_sales, 0) ELSE 0 END)                                                                                     AS net_sales_eu,
  SUM(CASE WHEN o.order_status = 'CONFIRMED' THEN COALESCE(o.discounts, 0) ELSE 0 END)                                                                                     AS discounts_eu,
  SUM(CASE WHEN o.order_status = 'CONFIRMED' AND o.double_ya_order_id IS NULL AND o.sof IS NULL THEN COALESCE(o.units_sold, 0) ELSE 0 END)                                  AS units_excl_dy_sof,
  SUM(CASE WHEN o.order_status = 'CONFIRMED' AND o.double_ya_order_id IS NULL AND o.sof IS NULL THEN COALESCE(o.net_sales, 0) ELSE 0 END)                                   AS net_sales_excl_dy_sof_eu

FROM orders o
INNER JOIN `peya-bi-tools-pro.il_core.dim_country` c          ON c.country_id = o.country_id AND c.active = TRUE
INNER JOIN partners hp                                          ON CAST(hp.partner_id AS STRING) = CAST(o.restaurant_id AS STRING)
LEFT JOIN `peya-bi-tools-pro.il_core.dim_currency_exchange` ce ON ce.currency_id = c.currency_id
                                                                AND ce.currency_exchange_date = DATE_TRUNC(DATE(o.order_placed_local), MONTH)
LEFT JOIN `peya-data-origins-pro.cl_core.country_details` co   ON o.country_id = co.country_id AND co.active
LEFT JOIN coupon_data cd                                        ON CAST(cd.order_id AS STRING) = CAST(o.order_id AS STRING)
LEFT JOIN new_users nu                                          ON CAST(nu.user_id AS STRING) = CAST(o.user_id AS STRING) AND nu.country_id = o.country_id
LEFT JOIN country_platform_baseline cb                          ON cb.day = DATE(o.order_placed_local) AND cb.country_id = o.country_id
LEFT JOIN gmv_data_warehouse gmvw                               ON gmvw.date_day = DATE(o.order_placed_local) AND gmvw.warehouse_id = hp.warehouse_id AND gmvw.country_id = o.country_id
LEFT JOIN gmv_data_country gmvc                                 ON gmvc.date_day = DATE(o.order_placed_local) AND gmvc.country_id = o.country_id
WHERE DATE(o.order_placed_local) BETWEEN from_date AND to_date
GROUP BY 1, 2, 3, 4;
