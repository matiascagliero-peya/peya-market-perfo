DECLARE target_month DATE DEFAULT DATE '2026-05-01';

-- CREATE TABLE IF NOT EXISTS `peya-food-and-groceries.user_eugenio_irigoin.datamart_market_penetration`
-- PARTITION BY month_date
-- CLUSTER BY warehouse_id AS (

-- DELETE FROM `peya-food-and-groceries.user_eugenio_irigoin.datamart_market_penetration` WHERE month_date = target_month;
-- INSERT INTO `peya-food-and-groceries.user_eugenio_irigoin.datamart_market_penetration`

WITH warehouse_top_partner AS (
  SELECT
    warehouse_id,
    vendor_id,
    orders
  FROM (
    SELECT
      warehouse_id,
      vendor_id,
      COUNT(DISTINCT order_id) AS orders,
      ROW_NUMBER() OVER (
        PARTITION BY warehouse_id
        ORDER BY COUNT(DISTINCT order_id) DESC
      ) AS rn
    FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
    WHERE DATE_TRUNC(order_date, MONTH) = target_month
      AND state = 'CONFIRMED'
    GROUP BY warehouse_id, vendor_id
  )
  WHERE rn = 1
),

dmart_partners_raw AS (
  SELECT DISTINCT
    dp.warehouse_id,
    CAST(dp.partner_id AS STRING) AS partner_id,
    dp.partner_name,
    dp.warehouse_name,
    dp.address.latitude  AS store_lat,
    dp.address.longitude AS store_lng
  FROM `peya-bi-tools-pro.il_core.dim_partner` dp
  INNER JOIN warehouse_top_partner wtp
    ON CAST(dp.partner_id AS STRING) = CAST(wtp.vendor_id AS STRING)
  WHERE dp.is_darkstore
),

dmart_partners AS (
  SELECT
    *,
    ST_GEOGPOINT(store_lng, store_lat) AS store_geopoint
  FROM dmart_partners_raw
),

dmart_shapes AS (
  SELECT
    ps.*,
    dp.warehouse_id,
    dp.warehouse_name,
    dp.store_lat,
    dp.store_lng,
    dp.store_geopoint,
    ST_ASGEOJSON(ps.partner_shape) AS shape_geojson
  FROM `peya-food-and-groceries.automated_tables_reports.qc_coverage_partner_shapes` ps
  INNER JOIN dmart_partners dp
    ON CAST(ps.partner_id AS STRING) = dp.partner_id
  WHERE ps.month_date = target_month
),

-- All customer-store coverage matches (can be 1:many)
dmart_cover_all AS (
  SELECT
    CAST(cl.customer_id AS STRING) AS customer_id,
    cl.month_date,
    cl.country_id,
    cs.country_name,
    cs.country_code,
    cs.city_name_lz,
    cs.city_id_lz,
    cs.partner_name,
    cs.warehouse_name,
    cs.warehouse_id,
    cs.store_lat,
    cs.store_lng,
    cs.shape_geojson,
    cs.store_geopoint,
    cl.customer_geogpoint,
    COUNT(*) OVER (
      PARTITION BY CAST(cl.customer_id AS STRING), cl.month_date, cl.country_id
    ) AS num_covering_stores
  FROM `peya-food-and-groceries.automated_tables_reports.qc_coverage_customer_location` cl
  JOIN dmart_shapes cs
    ON cl.month_date = cs.month_date
    AND cl.country_id = cs.country_id
  WHERE ST_WITHIN(cl.customer_geogpoint, cs.partner_shape)
    AND cl.month_date = target_month
),

-- Single-store customers: keep as-is. Multi-store: pick nearest by distance.
dmart_cover_maus AS (
  SELECT
    customer_id,
    month_date,
    country_id,
    country_name,
    country_code,
    city_name_lz,
    city_id_lz,
    warehouse_name,
    warehouse_id,
    partner_name,
    store_lat,
    store_lng,
    shape_geojson
  FROM (
    SELECT
      *,
      CASE
        WHEN num_covering_stores = 1 THEN 1
        ELSE ROW_NUMBER() OVER (
          PARTITION BY customer_id, month_date, country_id
          ORDER BY ST_DISTANCE(customer_geogpoint, store_geopoint) ASC
        )
      END AS store_rank
    FROM dmart_cover_all
  )
  WHERE store_rank = 1
),

-- User profile flags: high income & core
user_profile AS (
  SELECT
    CAST(du.customer_id AS STRING) AS customer_id,
    lc.country_id,
    MAX(CASE WHEN lc.user_income = 'High' THEN 1 ELSE 0 END) AS is_high_income_user,
    MAX(CASE WHEN lc.subsegment = 'Core' THEN 1 ELSE 0 END) AS is_core_user
  FROM `peya-bi-tools-pro.il_qcommerce.user_lifecycle` lc
   LEFT JOIN `peya-bi-tools-pro.il_core.dim_user` du
    ON lc.user_id = du.user_id AND CAST(lc.country_id AS INT64) = du.country_id
  GROUP BY 1, 2
),

timings_data AS (
  SELECT
    DATE_TRUNC(created_date, MONTH) AS month,
    warehouse_id,
    COUNT(DISTINCT order_id) AS total_orders_timings,
    SUM(picking_time_s) AS item_picking_time,
    SUM(items) AS picked_items,
    SUM(actual_dt_min) AS avg_delivery_time,
    SUM(CASE WHEN SAFE_CAST(is_order_late_10 AS INT64) = 1 THEN 1 ELSE 0 END) AS is_order_late_10,
    SUM(CASE WHEN SAFE_CAST(is_vendor_late_10 AS INT64) = 1 THEN 1 ELSE 0 END) AS is_vendor_late_10,
    COUNTIF(actual_dt_min > 35) AS is_dt_35min
  FROM `peya-delivery-and-support.automated_tables_reports.dmarts_timings` t
  LEFT JOIN `peya-bi-tools-pro.il_core.dim_country` dc 
    ON LOWER(t.country_code) = LOWER(dc.country_code)
  WHERE DATE_TRUNC(created_date, MONTH) = target_month
  GROUP BY 1, 2
),

inaccuracy as (
  SELECT 
    date_trunc(order_date, month) as month, 
    warehouse_id,
    sum(total_orders) as orders,
    sum(total_complaint_orders) as total_complaint_orders, 
    sum(food_issue_orders) as food_issue_orders, 
    sum(wrong_missing_item_orders) as wrong_missing_item
  FROM `peya-delivery-and-support.automated_tables_reports.dmarts_inaccuracy`
  WHERE date_trunc(order_date, month) = target_month
  group by 1,2
),

-- Dmart order metrics at customer_id / month / country level
dmart_metrics AS (
  SELECT
    CAST(co.customer_id AS STRING) AS customer_id,
    DATE_TRUNC(co.order_date, MONTH) AS month_date,
    co.country_id,
    COUNT(DISTINCT co.order_id) AS dmart_orders,
    SUM(co.total_amount_net_with_discount_eur) AS dmart_net_sales,
    SUM(co.fulfilled_quantity) AS dmart_units,
    COUNT(DISTINCT CASE WHEN master_category_parent_english IN ("Produce", "Meat / Seafood", "Ready To Consume") THEN order_id END) AS ultra_fresh_orders,
    SUM(co.pcm_discount_amount_net_lc) as discounts
  FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` co
  WHERE DATE_TRUNC(co.order_date, MONTH) = target_month
    AND co.state = 'CONFIRMED'
  GROUP BY 1, 2, 3
),
  
fact_orders_aggregated AS (
  SELECT
    cast(o.user.customer_id as string) as customer_id,
    DATE_TRUNC(o.registered_date, month) as month_date,
    o.country_id,
    SUM(o.gmv.gmv_user / monthly_rate_eu) as customer_value,
    COUNT(DISTINCT o.order_id) as orders,
    COUNT(DISTINCT CASE WHEN o.partner.vertical_type = 'Market' THEN o.order_id END) as market_orders,
    MAX(CASE WHEN o.user.is_user_plus THEN 1 ELSE 0 END) as is_user_plus_flag,
    sum(gpo.gpo/ monthly_rate_eu) as gpo, 
    SUM(rider_cost.rider_cost/ monthly_rate_eu) as rider_cost,
    SUM(delivery.distance_meters) as meters,
    COUNT(DISTINCT CASE WHEN delivery.is_stacked then order_id end) as stacked_orders
  FROM `peya-datamarts-pro.dm_order_profitability.fact_order_profitability` o
  WHERE DATE_TRUNC(o.registered_Date, MONTH) = target_month 
  AND o.order_status = 'CONFIRMED'
  GROUP BY 1,2,3
),

customer_sessions as(
  select
    DATE_TRUNC(DATE(date),MONTH) AS month_date, 
    customer_id as customer_id,
    ps.country_id,
    SUM(funnel_shop_details) as sessions, 
    SUM(funnel_shop_transaction) as transaction
  from `peya-bi-tools-pro.il_sessions.perseus_fact_partner_funnel` ps
   LEFT JOIN `peya-bi-tools-pro.il_core.dim_user` du
    ON ps.userid = cast(du.user_id as string) AND CAST(ps.country_id AS INT64) = du.country_id
  where DATE_TRUNC(date(date), MONTH)= target_month 
  AND funnel_shop_double_ya = 0
  group by 1,2,3
),

-- Combine coverage (1 store per customer) with performance metrics
dmart_maus_perfo AS (
  SELECT
    cl.customer_id,
    cl.month_date,
    cl.country_id,
    cl.country_name,
    cl.country_code,
    cl.city_name_lz,
    cl.city_id_lz,
    cl.warehouse_name,
    cl.warehouse_id,
    cl.partner_name,
    cl.store_lat,
    cl.store_lng,
    cl.shape_geojson,

    -- Flags
    MAX(COALESCE(foa.is_user_plus_flag, 0)) AS is_user_plus,
    MAX(CASE WHEN COALESCE(foa.market_orders, 0) > 0 THEN 1 ELSE 0 END) AS market_user,
    MAX(CASE WHEN COALESCE(dm.ultra_fresh_orders,0)>0 then 1 else 0 end) as ultra_fresh_user,
    MAX(COALESCE(up.is_high_income_user, 0)) AS high_users,
    MAX(COALESCE(up.is_core_user, 0)) AS core_users,

    -- Platform metrics
    SUM(COALESCE(foa.customer_value, 0)) AS customer_value,
    SUM(COALESCE(foa.orders, 0)) AS orders,
    SUM(COALESCE(foa.market_orders, 0)) AS market_orders,
    SUM(COALESCE(foa.GPO, 0)) AS GPO,
    SUM(COALESCE(foa.rider_cost, 0)) AS rider_cost,
    SUM(COALESCE(foa.meters, 0)) as meters,
    SUM(COALESCE(foa.stacked_orders, 0)) as stacked_orders,

    -- Dmart metrics
    SUM(COALESCE(dm.dmart_orders, 0)) AS dmart_orders,
    SUM(COALESCE(dm.dmart_net_sales, 0)) AS dmart_net_sales,
    SUM(COALESCE(dm.dmart_units, 0)) AS dmart_units,
    SUM(COALESCE(dm.ultra_fresh_orders, 0)) as ultra_fresh_orders,
    SUM(COALESCE(dm.discounts, 0)) as discounts,

    --SESSIONS
    SUM(COALESCE(cs.sessions, 0)) as sessions,
    SUM(COALESCE(cs.transaction, 0)) as transactions,

    -- Dmart user flag
    MAX(CASE WHEN dm.customer_id IS NOT NULL THEN 1 ELSE 0 END) AS is_dmart_user

  FROM dmart_cover_maus cl
  LEFT JOIN fact_orders_aggregated foa
    ON cl.customer_id = foa.customer_id
    AND cl.month_date = foa.month_date
    AND cl.country_id = foa.country_id
  LEFT JOIN user_profile up
    ON cl.customer_id = up.customer_id
    AND cl.country_id = up.country_id
  LEFT JOIN dmart_metrics dm
    ON cl.customer_id = dm.customer_id
    AND cl.month_date = dm.month_date
    AND cl.country_id = dm.country_id
  LEFT JOIN customer_sessions cs
  ON cl.customer_id = cs.customer_id
  AND cl.month_date = cs.month_date
  AND cl.country_id = cs.country_id
  GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13
),

-- =============================================================================
-- FINAL OUTPUT
-- =============================================================================
final AS (
  SELECT
    month_date,
    country_id,
    country_name,
    country_code,
    city_name_lz,
    city_id_lz,
    partner_name,
    warehouse_name,
    warehouse_id,
    store_lat,
    store_lng,
    shape_geojson,

    -- User counts
    COUNT(DISTINCT customer_id) AS users,
    COUNT(DISTINCT CASE WHEN is_dmart_user = 1 THEN customer_id END) AS dmart_users,
    COUNT(DISTINCT CASE WHEN is_dmart_user = 1 AND high_users = 1 THEN customer_id END) AS dmart_high_users,

    -- Platform metrics
    SUM(customer_value) AS customer_value,
    SUM(orders) AS orders,
    SUM(market_orders) AS market_orders,
    SUM(GPO) AS GPO,
    SUM(RIDER_COST) AS RIDER_COST,
    SUM(METERS) AS METERS,
    SUM(STACKED_ORDERS) AS STACKED,

    -- User segment counts
    SUM(is_user_plus) AS plus_maus,
    SUM(market_user) AS market_users,
    SUM(core_users) AS core_users,
    SUM(high_users) AS high_users,
    SUM(ultra_fresh_user) as uf_users,

    -- Dmart metrics
    SUM(dmart_orders) AS dmart_orders,
    SUM(dmart_net_sales) AS dmart_net_sales,
    SUM(dmart_units) AS dmart_units,
    SUM(ultra_fresh_orders) as ultra_fresh_orders,
    sum(discounts) as discounts,

    --sessions
    SUM(SESSIONS) AS sessions,
    sum(transactions) as transactions

  FROM dmart_maus_perfo
  GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12
)

SELECT 
  dmp.*,
  td.total_orders_timings,
  --ops
  SUM(td.avg_delivery_time) as delivery_time,
  SUM(td.is_order_late_10) as order_late,
  SUM(td.is_vendor_late_10) AS vendor_late,
  SUM(td.is_dt_35min) AS is_dt_35min,
  sum(i.total_complaint_orders) as total_complaint_orders, 
  sum(i.food_issue_orders) as food_issue_orders, 
  sum(i.wrong_missing_item) as wrong_missing_item,
  
  -- Calculated Columns
  SAFE_DIVIDE(dmp.dmart_users, dmp.users) * 100 AS penetration_pct,
  SAFE_DIVIDE(dmp.core_users, dmp.users) * 100 AS core_users_pct,
  SAFE_DIVIDE(dmp.high_users, dmp.users) * 100 AS high_users_pct,
  SAFE_DIVIDE(dmp.plus_maus, dmp.users) * 100 AS plus_maus_pct,
  SAFE_DIVIDE(dmp.transactions, dmp.sessions) * 100 AS cvr3_pct,
  SAFE_DIVIDE(dmp.METERS, dmp.orders) / 1000 AS avg_delivery_distance_km,
  SAFE_DIVIDE(dmp.customer_value, dmp.orders) AS aov,
  SAFE_DIVIDE(dmp.dmart_net_sales, dmp.dmart_orders) AS afv_wo_vat,
  SAFE_DIVIDE(dmp.dmart_orders, dmp.orders) * 100 AS dmart_orders_share_pct,
  SAFE_DIVIDE(dmp.dmart_units, dmp.dmart_orders) AS basket_size,
  SAFE_DIVIDE(SUM(td.avg_delivery_time), SUM(td.total_orders_timings)) AS avg_delivery_time_min,
  SAFE_DIVIDE(SUM(td.is_order_late_10), SUM(td.total_orders_timings)) * 100 AS order_late_pct,
  SAFE_DIVIDE(SUM(td.is_vendor_late_10), SUM(td.total_orders_timings)) * 100 AS vendor_late_pct,
  SAFE_DIVIDE(sum(i.food_issue_orders), dmp.dmart_orders) * 100 AS food_issue_pct,
  SAFE_DIVIDE(sum(i.wrong_missing_item), dmp.dmart_orders) * 100 AS wrong_missing_item_pct,
  SAFE_DIVIDE(dmp.ultra_fresh_orders, dmp.dmart_orders) * 100 AS uf_basket_penetration_pct,
  SAFE_DIVIDE(dmp.dmart_orders, dmp.dmart_users) AS dmart_freq,
  SAFE_DIVIDE(dmp.discounts, dmp.dmart_net_sales) * 100 AS discount_intensity_pct

FROM final dmp
LEFT JOIN timings_data td 
  ON dmp.warehouse_id = td.warehouse_id 
  AND dmp.month_date = td.month
LEFT JOIN inaccuracy i
  ON dmp.warehouse_id = i.warehouse_id 
  AND dmp.month_date = i.month
GROUP BY 
  dmp.month_date, dmp.country_id, dmp.country_name, dmp.country_code, dmp.city_name_lz, dmp.city_id_lz, 
  dmp.partner_name, dmp.warehouse_name, dmp.warehouse_id, dmp.store_lat, dmp.store_lng, dmp.shape_geojson, 
  dmp.users, dmp.dmart_users, dmp.dmart_high_users, dmp.customer_value, dmp.orders, dmp.market_orders, 
  dmp.GPO, dmp.RIDER_COST, dmp.METERS, dmp.STACKED, dmp.plus_maus, dmp.market_users, dmp.core_users, 
  dmp.high_users, dmp.uf_users, dmp.dmart_orders, dmp.dmart_net_sales, dmp.dmart_units, 
  dmp.ultra_fresh_orders, dmp.discounts, dmp.sessions, dmp.transactions,
  td.total_orders_timings
ORDER BY dmp.month_date, dmp.country_name, dmp.city_name_lz, dmp.partner_name
-- )
