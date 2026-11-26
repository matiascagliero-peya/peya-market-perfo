DECLARE query_name STRING DEFAULT '6. Users details - Base - Performance';

-- Sheets Name: 1. ET - Users details (24 - Users details)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1yoIkjCi3mwaXQOwpPpvbxcVE5IEFHXY7uRSytN9WaTo


-- 6. Users details - Base - Performance
SELECT

date_trunc(order_Date, month) as month,
co.country_name as country,

dmart_growth_status_fixed as growth_status,
count(distinct co.customer_id) as users,

SUM(total_amount_net_with_discount_eur) as net_sales,
SUM(fulfilled_quantity) AS units,
count(distinct order_id) as orders,

safe_divide(SUM(fulfilled_quantity),count(distinct order_id)) as basket_size,

safe_divide(count(distinct order_id),count(distinct co.customer_id) ) as freq,
safe_divide(SUM(total_amount_net_with_discount_eur),count(distinct order_id)) as afv,

count(distinct case when  master_category_parent_english IN ("Produce", "Meat / Seafood", "Ready To Consume") then order_id end) as uf_orders,

count(distinct case when  master_category_parent_english IN ("Produce", "Meat / Seafood", "Ready To Consume") then co.customer_id end) as uf_users,

AVG(mes_en_curso) AS ternure

FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` co
LEFT JOIN `peya-food-and-groceries.automated_tables_reports.latam_dmart_growth_tracker` gt
ON co.country_name = gt.country_name_es and co.customer_id = gt.customer_id and DATE_TRUNC(co.order_date, MONTH) = DATE_TRUNC(gt.month, MONTH)

where co.order_date>= '2025-01-01'
AND gt.dmart_growth_status_fixed <> 'Churned'
AND STATE = 'CONFIRMED'

group by 1,2,3
order by 2,1 desc