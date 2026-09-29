DECLARE query_name STRING DEFAULT '3. Sessions Latam - Base';

-- 3. Sessions Latam - Base
SELECT
session_month as month,
country,
dmart_growth_stage,
sum(sessions_shop_details) as sessions,

FROM `peya-food-and-groceries.automated_tables_reports.dmarts_latam_sessions`

WHERE store_sub_category = 'Dmarts'

group by 1,2,3