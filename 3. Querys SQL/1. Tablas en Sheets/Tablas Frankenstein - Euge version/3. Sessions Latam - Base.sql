DECLARE query_name STRING DEFAULT '3. Sessions Latam - Base';

-- Sheets Name: 1. TD - Sessions Latam (2 - Sessions Type)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1uHtKswKM8TkGATjcP7IcNkQxUhIYyzhJ0HeseJk3RpA


-- 3. Sessions Latam - Base
SELECT
session_month as month,
country,
dmart_growth_stage,
sum(sessions_shop_details) as sessions,

FROM `peya-food-and-groceries.automated_tables_reports.dmarts_latam_sessions`

WHERE store_sub_category = 'Dmarts'

group by 1,2,3