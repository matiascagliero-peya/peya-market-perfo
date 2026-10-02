DECLARE target_month DATE DEFAULT DATE '2026-05-01';

-- CREATE TABLE IF NOT EXISTS `peya-food-and-groceries.user_eugenio_irigoin.datamart_city_penetration`
-- PARTITION BY month_date
-- CLUSTER BY city_name_lz AS (

-- DELETE FROM `peya-food-and-groceries.user_eugenio_irigoin.datamart_city_penetration` WHERE month_date = target_month;
-- INSERT INTO `peya-food-and-groceries.user_eugenio_irigoin.datamart_city_penetration`

WITH customer_with_coverage AS (
  SELECT
    cl.customer_id,
    cl.month_date,
    cl.country_id,
    cl.country_name,
    cl.country_code,
    cl.city_name_lz,
    cl.zone_name,
    ANY_VALUE(cl.customer_geogpoint) AS customer_geogpoint
  FROM `peya-food-and-groceries.automated_tables_reports.qc_coverage_customer_location` cl
  WHERE cl.month_date = target_month
  GROUP BY 1, 2, 3, 4, 5, 6, 7
),

city_centroids AS (
  SELECT
    city_name_lz,
    AVG(ST_Y(customer_geogpoint)) AS lat_centro,
    AVG(ST_X(customer_geogpoint)) AS lon_centro
  FROM customer_with_coverage
  GROUP BY city_name_lz
),

dmart_coverage_MAUs AS (
  SELECT
    co.month_date,
    co.country_id,
    co.country_name,
    co.city_name_lz,
    customers_cubiertos
  FROM `peya-food-and-groceries.automated_tables_reports.qc_dmart_coverage_city_MAUs` co
  WHERE co.month_date = target_month
),

customer_sessions AS (
  SELECT
    DATE_TRUNC(DATE(ps.date), MONTH) AS month_date,
    du.customer_id,
    ps.country_id,
    SUM(funnel_shop_details)     AS sessions,
    SUM(funnel_shop_transaction) AS transaction
  FROM `peya-bi-tools-pro.il_sessions.perseus_fact_partner_funnel` ps
  LEFT JOIN `peya-bi-tools-pro.il_core.dim_user` du
    ON CAST(CAST(userid AS FLOAT64) AS INT64) = du.user_id
  WHERE DATE_TRUNC(DATE(ps.date), MONTH) = target_month
    AND funnel_shop_double_ya = 0
  GROUP BY 1, 2, 3
),

user_profile AS (
  SELECT
    du.customer_id,
    lc.country_id,
    MAX(CASE WHEN lc.user_income = 'High' THEN 1 ELSE 0 END) AS is_high_income_user,
    MAX(CASE WHEN lc.subsegment = 'Core' THEN 1 ELSE 0 END)  AS is_core_user
  FROM `peya-bi-tools-pro.il_qcommerce.user_lifecycle` lc
  LEFT JOIN `peya-bi-tools-pro.il_core.dim_user` du
    ON lc.user_id = du.user_id AND lc.country_id = du.country_id
  GROUP BY 1, 2
),

dmart_metrics AS (
  SELECT
    du.customer_id,
    DATE_TRUNC(order_date, MONTH) AS month,
    du.country_id,
    COUNT(DISTINCT order_id)                   AS dmart_orders,
    SUM(total_amount_net_with_discount_eur)     AS dmart_net_sales,
    SUM(fulfilled_quantity)                     AS dmart_units,
    COUNT(DISTINCT CASE WHEN master_category_parent_english IN ("Produce", "Meat / Seafood", "Ready To Consume") THEN order_id END) AS ultra_fresh_orders,
    SUM(co.pcm_discount_amount_net_lc) as discounts
  FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` co
  LEFT JOIN `peya-bi-tools-pro.il_core.dim_user` du
    ON co.customer_id = du.customer_id AND CAST(co.country_id AS INT64) = du.country_id
  WHERE DATE_TRUNC(order_date, MONTH) = target_month
    AND state = 'CONFIRMED'
  GROUP BY 1, 2, 3
),

fact_orders_aggregated AS (
  SELECT
    o.user.customer_id,
    DATE_TRUNC(o.registered_date, MONTH)                                                     AS month_date,
    o.country_id,
    SUM(o.gmv.gmv_user / monthly_rate_eu)                                                    AS customer_value,
    COUNT(DISTINCT o.order_id)                                                               AS orders,
    COUNT(DISTINCT CASE WHEN o.partner.vertical_type = 'Market' THEN o.order_id END)         AS market_orders,
    MAX(CASE WHEN o.user.is_user_plus THEN 1 ELSE 0 END)                                     AS is_user_plus_flag,
    SUM(gpo.gpo/ monthly_rate_eu)                                                                             AS gpo,
    SUM(rider_cost.rider_cost/ monthly_rate_eu)                                                               AS rider_cost,
    SUM(delivery.distance_meters) as meters,
    COUNT(DISTINCT CASE WHEN delivery.is_stacked then order_id end) as stacked_orders
  FROM `peya-datamarts-pro.dm_order_profitability.fact_order_profitability` o
  WHERE DATE_TRUNC(o.registered_date, MONTH) = target_month
    AND o.order_status = 'CONFIRMED'
  GROUP BY 1, 2, 3
),

maus_perfo AS (
  SELECT
    cl.customer_id,
    cl.month_date,
    cl.country_id,
    cl.country_name,
    cl.country_code,
    cl.city_name_lz,
    cl.zone_name,
    foa.is_user_plus_flag                                        AS is_user_plus,
    MAX(CASE WHEN foa.market_orders > 0 THEN 1 ELSE 0 END)      AS market_user,
    MAX(CASE WHEN lc.is_high_income_user = 1 THEN 1 ELSE 0 END) AS high_users,
    MAX(CASE WHEN lc.is_core_user = 1 THEN 1 ELSE 0 END)        AS core_users,
    MAX(CASE WHEN co.ultra_fresh_orders > 0 THEN 1 ELSE 0 END)  AS ultra_fresh_user,
    SUM(foa.customer_value)        AS customer_value,
    SUM(foa.orders)                AS orders,
    SUM(foa.market_orders)         AS market_orders,
    SUM(co.dmart_orders)           AS dmart_orders,
    SUM(co.dmart_net_sales)        AS dmart_net_sales,
    SUM(co.dmart_units)            AS dmart_units,
    SUM(co.ultra_fresh_orders)     AS ultra_fresh_orders,
    SUM(co.discounts)              AS discounts,
    COUNT(DISTINCT co.customer_id) AS dmart_user,
    SUM(sessions)                  AS sessions,
    SUM(transaction)               AS transaction,
    SUM(gpo)                       AS gpo,
    SUM(rider_cost)                AS rider_cost,
    SUM(foa.meters)                AS meters,
    SUM(foa.stacked_orders)        AS stacked_orders
  FROM customer_with_coverage cl
  LEFT JOIN fact_orders_aggregated foa
    ON cl.customer_id = foa.customer_id
    AND cl.month_date = foa.month_date
    AND cl.country_id = foa.country_id
  LEFT JOIN user_profile lc
    ON cl.customer_id = lc.customer_id AND cl.country_id = lc.country_id
  LEFT JOIN dmart_metrics co
    ON cl.customer_id = co.customer_id
    AND cl.month_date = co.month
    AND cl.country_id = co.country_id
  LEFT JOIN customer_sessions cs
    ON cl.customer_id = cs.customer_id
    AND cl.month_date = cs.month_date
    AND cl.country_id = cs.country_id
  GROUP BY 1, 2, 3, 4, 5, 6, 7, 8
),

final_aggregation AS (
  SELECT
    mp.month_date,
    mp.country_id,
    mp.country_name,
    mp.country_code,
    mp.city_name_lz,
    mp.zone_name,
    MAX(customers_cubiertos)                                                        AS dmart_covered_maus,
    COUNT(DISTINCT customer_id)                                                     AS peya_users,
    SUM(customer_value)                                                             AS customer_value,
    SUM(orders)                                                                     AS orders,
    SUM(market_orders)                                                              AS market_orders,
    SUM(is_user_plus)                                                               AS plus_maus,
    SUM(market_user)                                                                AS market_users,
    SUM(core_users)                                                                 AS core_users,
    SUM(high_users)                                                                 AS high_users,
    SUM(ultra_fresh_user)                                                           AS uf_users,
    SUM(dmart_orders)                                                               AS dmart_orders,
    SUM(dmart_net_sales)                                                            AS dmart_net_sales,
    SUM(dmart_units)                                                                AS dmart_units,
    SUM(ultra_fresh_orders)                                                         AS ultra_fresh_orders,
    SUM(discounts)                                                                  AS discounts,
    COUNT(DISTINCT CASE WHEN dmart_orders IS NOT NULL THEN customer_id END)         AS dmart_users,
    SUM(CASE WHEN dmart_user = 1 AND high_users = 1 THEN 1 ELSE 0 END)              AS dmart_high_users,
    SUM(sessions)                                                                   AS sessions,
    SUM(transaction)                                                                AS transactions,
    SUM(gpo)                                                                        AS gpo,
    SUM(rider_cost)                                                                 AS rider_cost,
    SUM(meters)                                                                     AS meters,
    SUM(stacked_orders)                                                             AS stacked_orders
  FROM maus_perfo mp
  LEFT JOIN dmart_coverage_MAUs dm
    ON mp.month_date = dm.month_date
    AND mp.country_id = dm.country_id
    AND mp.city_name_lz = dm.city_name_lz
  GROUP BY 1, 2, 3, 4, 5, 6
),

city_level_aggregated AS (
  SELECT
    fa.month_date,
    fa.country_id,
    fa.country_name,
    fa.country_code,
    fa.city_name_lz,
    MAX(fa.dmart_covered_maus) AS dmart_covered_maus,
    SUM(fa.peya_users) AS users,
    SUM(fa.customer_value) AS customer_value,
    SUM(fa.orders) AS orders,
    SUM(fa.market_orders) AS market_orders,
    SUM(fa.plus_maus) AS plus_maus,
    SUM(fa.market_users) AS market_users,
    SUM(fa.core_users) AS core_users,
    SUM(fa.high_users) AS high_users,
    SUM(fa.uf_users) AS uf_users,
    SUM(fa.dmart_orders) AS dmart_orders,
    SUM(fa.dmart_net_sales) AS dmart_net_sales,
    SUM(fa.dmart_units) AS dmart_units,
    SUM(fa.ultra_fresh_orders) AS ultra_fresh_orders,
    SUM(fa.discounts) AS discounts,
    SUM(fa.dmart_users) AS dmart_users,
    SUM(fa.dmart_high_users) AS dmart_high_users,
    SUM(fa.sessions) AS sessions,
    SUM(fa.transactions) AS transactions,
    SUM(fa.gpo) AS gpo,
    SUM(fa.rider_cost) AS rider_cost,
    SUM(fa.meters) AS meters,
    SUM(fa.stacked_orders) AS stacked_orders
  FROM final_aggregation fa
  GROUP BY 1, 2, 3, 4, 5
),

city_timings AS (
  SELECT
    DATE_TRUNC(t.created_date, MONTH) AS month_date,
    LOWER(dp.city.name) AS city_name_lz,
    COUNT(DISTINCT t.order_id) AS total_orders_timings,
    SUM(t.actual_dt_min) AS avg_delivery_time,
    SUM(CASE WHEN SAFE_CAST(t.is_order_late_10 AS INT64) = 1 THEN 1 ELSE 0 END) AS is_order_late_10,
    SUM(CASE WHEN SAFE_CAST(t.is_vendor_late_10 AS INT64) = 1 THEN 1 ELSE 0 END) AS is_vendor_late_10,
    COUNTIF(t.actual_dt_min > 35) AS is_dt_35min
  FROM `peya-delivery-and-support.automated_tables_reports.dmarts_timings` t
  LEFT JOIN `peya-bi-tools-pro.il_core.dim_partner` dp ON t.warehouse_id = dp.warehouse_id
  WHERE DATE_TRUNC(t.created_date, MONTH) = target_month
  GROUP BY 1, 2
)


SELECT
  c.*,
  cc.lat_centro,
  cc.lon_centro,
  ct.total_orders_timings,
  ct.avg_delivery_time AS delivery_time,
  ct.is_order_late_10 AS order_late,
  ct.is_vendor_late_10 AS vendor_late,
  ct.is_dt_35min,


  -- Calculated Columns
  SAFE_DIVIDE(c.dmart_users, c.users) * 100 AS penetration_pct,
  SAFE_DIVIDE(c.core_users, c.users) * 100 AS core_users_pct,
  SAFE_DIVIDE(c.high_users, c.users) * 100 AS high_users_pct,
  SAFE_DIVIDE(c.plus_maus, c.users) * 100 AS plus_maus_pct,
  SAFE_DIVIDE(c.transactions, c.sessions) * 100 AS cvr3_pct,
  SAFE_DIVIDE(c.meters, c.orders) / 1000 AS avg_delivery_distance_km,
  SAFE_DIVIDE(c.customer_value, c.orders) AS aov,
  SAFE_DIVIDE(c.dmart_net_sales, c.dmart_orders) AS afv_wo_vat,
  SAFE_DIVIDE(c.dmart_orders, c.orders) * 100 AS dmart_orders_share_pct,
  SAFE_DIVIDE(c.dmart_units, c.dmart_orders) AS basket_size,
  SAFE_DIVIDE(ct.avg_delivery_time, ct.total_orders_timings) AS avg_delivery_time_min,
  SAFE_DIVIDE(ct.is_order_late_10, ct.total_orders_timings) * 100 AS order_late_pct,
  SAFE_DIVIDE(ct.is_vendor_late_10, ct.total_orders_timings) * 100 AS vendor_late_pct,

  SAFE_DIVIDE(c.ultra_fresh_orders, c.dmart_orders) * 100 AS uf_basket_penetration_pct,
  SAFE_DIVIDE(c.dmart_orders, c.dmart_users) AS dmart_freq,
  SAFE_DIVIDE(c.discounts, c.dmart_net_sales) * 100 AS discount_intensity_pct

FROM city_level_aggregated c
LEFT JOIN city_centroids cc 
  ON c.city_name_lz = cc.city_name_lz
LEFT JOIN city_timings ct
  ON LOWER(c.city_name_lz) = ct.city_name_lz AND c.month_date = ct.month_date


-- )
