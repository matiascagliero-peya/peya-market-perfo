DECLARE query_name STRING DEFAULT '2. Dmart Users Type (churned users) - Base';

-- 2. Dmart Users Type (churned users) - Base
SELECT 
  month,
  country_name,
  dmart_growth_status_last_month_fixed,
  COUNT(DISTINCT customer_id) AS users,
  COUNT(DISTINCT CASE WHEN dmart_growth_status_fixed = 'Churned' THEN customer_id END) AS churned_users
FROM `peya-food-and-groceries.automated_tables_reports.latam_dmart_growth_tracker` gt 
WHERE month >= '2024-01-01'
  AND dmart_growth_status_last_month_fixed <> 'Churned'
GROUP BY 1, 2, 3
ORDER BY month DESC;