DECLARE query_name STRING DEFAULT 'GLOSARIO_MASTER_CONSOLIDADO_METRICAS_SEP_2026';

WITH 
-- 1. Demand Stimulation
demand_metrics AS (
  SELECT
    CASE d.country_name 
      WHEN 'Panama' THEN 'Panamá'
      WHEN 'Peru' THEN 'Perú'
      WHEN 'Dominican Republic' THEN 'República Dominicana'
      ELSE d.country_name 
    END AS country,
    DATE_TRUNC(d.order_date, MONTH) AS month,
    COUNT(DISTINCT d.warehouse_id) AS active_warehouses,
    COUNT(DISTINCT d.order_id) AS confirmed_orders,
    SAFE_DIVIDE(COUNT(DISTINCT d.order_id), 30) AS daily_orders,
    SUM(d.total_amount_sold_eur) AS gmv_user_eur,
    SAFE_DIVIDE(SUM(d.total_amount_sold_eur), 30) AS daily_gmv_user_eur,
    SUM(d.delivered_quantity) AS units_sold,
    SAFE_DIVIDE(SUM(d.delivered_quantity), 30) AS daily_units_sold,
    SUM(d.total_amount_sold_net_eur) AS net_sales_eur,
    SAFE_DIVIDE(SUM(d.total_amount_sold_eur), NULLIF(COUNT(DISTINCT d.order_id), 0)) AS avg_basket_size,
    SUM(COALESCE(d.pcm_discount_amount_net_eur, 0)) AS discounts_eur
  FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` d
  WHERE UPPER(d.state) = 'CONFIRMED'
    AND d.order_date BETWEEN '2026-09-01' AND '2026-09-30'
  GROUP BY 1, 2
),

-- 2. Usuarios & Lifecycle (desde frank_user_metrics_summary)
users_summary AS (
  SELECT
    CASE country 
      WHEN 'Panama' THEN 'Panamá'
      WHEN 'Peru' THEN 'Perú'
      WHEN 'Dominican Republic' THEN 'República Dominicana'
      ELSE country 
    END AS country,
    Mes AS month,
    SUM(IF(business = 'Market', users_count, 0)) AS dmart_maus,
    SUM(IF(business = 'Market' AND l1 = 'New User', users_count, 0)) AS new_users_dmart,
    SUM(IF(business = 'Market' AND l1 = 'M1 Return', users_count, 0)) AS m1_return_users_dmart,
    SUM(IF(business = 'Market' AND l1 = 'Reactivation', users_count, 0)) AS reactivation_users_dmart,
    SUM(IF(business = 'Market' AND l1 = 'Reorder', users_count, 0)) AS reorder_users_dmart,
    SUM(IF(business = 'Market' AND l1 = 'Recurring Return', users_count, 0)) AS recurring_return_users_dmart,
    SUM(IF(business = 'AAA', users_count, 0)) AS peya_maus,
    SUM(IF(business = 'AAA' AND l1 = 'New User', users_count, 0)) AS new_users_peya
  FROM `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
  WHERE Mes = '2026-09-01'
    AND country NOT IN ('Venezuela', 'Costa Rica')
  GROUP BY 1, 2
),

-- 3. Coverage
coverage_summary AS (
  SELECT
    CASE dc.country_name_en 
      WHEN 'Panama' THEN 'Panamá'
      WHEN 'Peru' THEN 'Perú'
      WHEN 'Dominican Republic' THEN 'República Dominicana'
      ELSE dc.country_name_en 
    END AS country,
    cm.month_date AS month,
    SUM(cm.MAUs) AS platform_maus_coverage,
    SUM(dm.CUSTOMERS_CUBIERTOS) AS covered_maus,
    SAFE_DIVIDE(SUM(dm.CUSTOMERS_CUBIERTOS), NULLIF(SUM(cm.MAUs), 0)) AS covered_maus_pct
  FROM `peya-food-and-groceries.automated_tables_reports.qc_coverage_city_MAUs` cm
  LEFT JOIN `peya-food-and-groceries.automated_tables_reports.qc_dmart_coverage_city_MAUs` dm
    ON cm.country_id = dm.country_id 
    AND cm.month_date = dm.month_date 
    AND cm.city_name_lz = dm.city_name_lz
  LEFT JOIN `peya-bi-tools-pro.il_core.dim_country` dc
    ON cm.country_id = dc.country_id
  WHERE cm.month_date = '2026-09-01'
  GROUP BY 1, 2
),

-- 4. Picking & Asignación
picker_ops_summary AS (
  SELECT
    CASE fo.country.country_name 
      WHEN 'Panama' THEN 'Panamá'
      WHEN 'Peru' THEN 'Perú'
      WHEN 'Dominican Republic' THEN 'República Dominicana'
      ELSE fo.country.country_name 
    END AS country,
    DATE_TRUNC(DATE(fo.registered_date), MONTH) AS month,
    COUNT(DISTINCT fo.order_id) AS picker_shift_confirmed_orders,
    SUM(order_events.order_available_to_start_duration_sec / 60) AS assignment_time_total_min,
    COUNT(DISTINCT CASE WHEN (order_events.order_available_to_start_duration_sec / 60) > 6 THEN fo.order_id END) AS assignment_over_6min_orders,
    SUM(order_events.order_picking_duration_sec / 60) AS picking_time_total_min
  FROM `peya-data-origins-pro.cl_dmarts.qc_picker_shift_orders` picko,
    UNNEST(picko.shifts) AS shifts,
    UNNEST(shifts.order_events) AS order_events
  INNER JOIN `peya-bi-tools-pro.il_core.fact_orders` fo
    ON CAST(fo.order_id AS STRING) = CAST(order_events.order_id AS STRING)
  WHERE fo.order_status = 'CONFIRMED'
    AND picko.shift_start_date_utc BETWEEN '2026-09-01' AND '2026-09-30'
    AND DATE(fo.registered_date) BETWEEN '2026-09-01' AND '2026-09-30'
  GROUP BY 1, 2
),

-- 5. Calidad & Inaccuracy
inaccuracy_summary AS (
  SELECT
    CASE country 
      WHEN 'Panama' THEN 'Panamá'
      WHEN 'Peru' THEN 'Perú'
      WHEN 'Dominican Republic' THEN 'República Dominicana'
      ELSE country 
    END AS country,
    DATE_TRUNC(order_date, MONTH) AS month,
    SUM(total_orders) AS total_orders_inaccuracy,
    SUM(total_complaint_orders) AS inaccuracy_orders,
    SUM(food_issue_orders) AS food_issue_orders,
    SUM(wrong_missing_item_orders) AS item_issue_orders,
    SAFE_DIVIDE(SUM(total_complaint_orders), NULLIF(SUM(total_orders), 0)) AS inaccuracy_pct
  FROM `peya-delivery-and-support.automated_tables_reports.dmarts_inaccuracy`
  WHERE order_date BETWEEN '2026-09-01' AND '2026-09-30'
  GROUP BY 1, 2
),

-- 6. Productividad & UTR
utr_summary AS (
  SELECT
    CASE LOWER(country_name)
      WHEN 'ar' THEN 'Argentina'
      WHEN 'bo' THEN 'Bolivia'
      WHEN 'cl' THEN 'Chile'
      WHEN 'do' THEN 'República Dominicana'
      WHEN 'ec' THEN 'Ecuador'
      WHEN 'gt' THEN 'Guatemala'
      WHEN 'hn' THEN 'Honduras'
      WHEN 'ni' THEN 'Nicaragua'
      WHEN 'pa' THEN 'Panamá'
      WHEN 'pe' THEN 'Perú'
      WHEN 'py' THEN 'Paraguay'
      WHEN 'sv' THEN 'El Salvador'
      WHEN 'uy' THEN 'Uruguay'
      ELSE country_name
    END AS country,
    DATE_TRUNC(date, MONTH) AS month,
    SUM(picking_units) AS picking_units,
    SUM(receiving_units) AS receiving_units,
    SUM(received_bags) AS received_bags,
    SUM(picker_working_hours) AS picker_working_hours,
    SAFE_DIVIDE(SUM(picking_units), NULLIF(SUM(picker_working_hours), 0)) AS utr_picking,
    SAFE_DIVIDE(SUM(picking_units) + SUM(receiving_units) + SUM(ajuste) - SUM(received_bags), NULLIF(SUM(picker_working_hours), 0)) AS utr_plus
  FROM `peya-delivery-and-support.automated_tables_reports.dmarts_productividad`
  WHERE date BETWEEN '2026-09-01' AND '2026-09-30'
  GROUP BY 1, 2
)

SELECT
  d.country,
  d.month,
  
  -- Demand Stimulation
  d.active_warehouses,
  d.confirmed_orders,
  d.daily_orders,
  d.gmv_user_eur,
  d.units_sold,
  d.net_sales_eur,
  d.avg_basket_size,
  d.discounts_eur,
  
  -- Usuarios
  u.dmart_maus,
  u.new_users_dmart,
  u.m1_return_users_dmart,
  u.reactivation_users_dmart,
  u.reorder_users_dmart,
  u.recurring_return_users_dmart,
  u.peya_maus,
  SAFE_DIVIDE(u.dmart_maus, NULLIF(u.peya_maus, 0)) AS platform_maus_penetration_pct,
  
  -- Coverage
  c.covered_maus,
  c.platform_maus_coverage,
  c.covered_maus_pct,
  SAFE_DIVIDE(u.dmart_maus, NULLIF(c.covered_maus, 0)) AS covered_maus_penetration_pct,
  
  -- Excelencia Operacional
  p.picker_shift_confirmed_orders,
  SAFE_DIVIDE(p.assignment_time_total_min, NULLIF(p.picker_shift_confirmed_orders, 0)) AS assignment_time_avg_min,
  SAFE_DIVIDE(p.assignment_over_6min_orders, NULLIF(p.picker_shift_confirmed_orders, 0)) AS assignment_over_6min_pct,
  
  -- Inaccuracy & Calidad
  i.total_orders_inaccuracy,
  i.inaccuracy_orders,
  i.inaccuracy_pct,
  
  -- UTR / Productividad
  ut.picking_units,
  ut.picker_working_hours,
  ut.utr_picking,
  ut.utr_plus

FROM demand_metrics d
LEFT JOIN users_summary u ON d.country = u.country AND d.month = u.month
LEFT JOIN coverage_summary c ON d.country = c.country AND d.month = c.month
LEFT JOIN picker_ops_summary p ON d.country = p.country AND d.month = p.month
LEFT JOIN inaccuracy_summary i ON d.country = i.country AND d.month = i.month
LEFT JOIN utr_summary ut ON d.country = ut.country AND d.month = ut.month
WHERE d.country IS NOT NULL
ORDER BY d.country ASC;
