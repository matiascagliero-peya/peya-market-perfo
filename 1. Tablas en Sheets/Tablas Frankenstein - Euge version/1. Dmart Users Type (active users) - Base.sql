DECLARE query_name STRING DEFAULT '1. Dmart Users Type (active users) - Base';

-- 1. Dmart Users Type (active users) - Base

SELECT
month,
country_name,
dmart_growth_status_fixed,
count(distinct customer_id) as customer,

FROM `peya-food-and-groceries.automated_tables_reports.latam_dmart_growth_tracker` gt

where month >= '2025-01-01'

group by 1,2 , 3