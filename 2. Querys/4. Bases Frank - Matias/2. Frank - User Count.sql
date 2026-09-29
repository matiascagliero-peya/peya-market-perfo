DECLARE query_name STRING DEFAULT '2. Frank - User Count';

CREATE OR REPLACE TABLE `peya-food-and-groceries.automated_tables_reports.frank_user_type_summary` AS

SELECT
    month,
    country,
    business,
    user_type,
    COUNT(DISTINCT customer_id) AS total_users
FROM `peya-food-and-groceries.automated_tables_reports.frank_user_type`,

UNNEST([
    STRUCT('PeYa' AS business, COALESCE(Type_Peya, 'Never Active') AS user_type),
    STRUCT('Dmart' AS business, COALESCE(Type_dmart, 'Never Active') AS user_type)
])

GROUP BY 1, 2, 3, 4
ORDER BY month DESC, country, business, total_users DESC