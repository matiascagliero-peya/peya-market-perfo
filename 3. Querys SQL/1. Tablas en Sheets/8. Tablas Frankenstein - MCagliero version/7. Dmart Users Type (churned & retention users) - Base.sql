DECLARE query_name STRING DEFAULT '7. Dmart Users Type (churned & retention users) - Base';

-- Sheets Name: 1. TD - Churned Users (22 - Churned Users)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1MqB23kt7VUaunpVheYPi-Yef2u_jtnW7FPtxN6ILj34
-- Origen: peya-food-and-groceries.automated_tables_reports.frank_user_type_monthly

SELECT 
  Mes AS month,
  country AS country_name,
  CASE
    WHEN Market_previous_type = 'New User'     THEN 'Adoption'
    WHEN Market_previous_type = 'Re-Order'     THEN 'Reorder'
    WHEN Market_previous_type = 'Reactivation' THEN 'Reactivated'
    ELSE Market_previous_type
  END AS dmart_growth_status_last_month_fixed,
  COUNT(DISTINCT customer_id) AS users,
  COUNT(DISTINCT CASE WHEN Market_Actual_Type = 'Churned' THEN customer_id END) AS churned_users
FROM `peya-food-and-groceries.automated_tables_reports.frank_user_type_monthly`
WHERE Mes >= '2025-01-01'
  AND country NOT IN ('Venezuela', 'Costa Rica')
  AND Market_previous_type NOT IN ('Never Active', 'Churned', '-')
  AND Market_previous_type IS NOT NULL
GROUP BY 1, 2, 3
ORDER BY month DESC, country_name ASC, users DESC;
