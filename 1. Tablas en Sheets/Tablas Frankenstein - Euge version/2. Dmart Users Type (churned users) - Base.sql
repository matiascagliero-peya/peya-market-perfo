DECLARE query_name STRING DEFAULT '2. Dmart Users Type (churned users) - Base';

-- 2. Dmart Users Type (churned users) - Base
SELECT 

month,
country_name,
dmart_growth_status_last_month_fixed,
count(distinct customer_id) as users,
COUNT(distinct case when dmart_growth_status_fixed = 'Churned' then customer_id end) as churned_users


FROM `peya-food-and-groceries.automated_tables_reports.latam_dmart_growth_tracker` gt 
WHERE month>= '2024-01-01'
and dmart_growth_status_last_month_fixed<> 'Churned'

group by 1,2,3