DECLARE query_name STRING DEFAULT '5. Fill In - Base - Performance';

-- 5. Fill In - Base - Performance
WITH todo AS (
SELECT
  DATE_TRUNC(registered_date,MONTH) as date_month,
  country_name,
  -- business_type_name,
  -- partner_id,
  COUNT(DISTINCT order_id) as total_orders,
  COUNT(DISTINCT CASE WHEN mission_type = "instant need" THEN order_id END) as orders_instant_need,
  COUNT(DISTINCT CASE WHEN mission_type = "fill in" THEN order_id END) as orders_fill_in,
  COUNT(DISTINCT CASE WHEN mission_type = "stock up" THEN order_id END) as orders_stock_up,
  COUNT(DISTINCT user_id) as total_users,
  COUNT(DISTINCT customer_id) as total_customer,
  SUM(products_qty) as units,
  SUM(CASE WHEN mission_type = "instant need" THEN products_qty END) as units_instant_need,
  SUM(CASE WHEN mission_type = "fill in" THEN products_qty END) as units_fill_in,
  SUM(CASE WHEN mission_type = "stock up" THEN products_qty END) as units_stock_up,
  -- SAFE_DIVIDE(SUM(products_qty),COUNT(DISTINCT order_id)) as basket_size,
 
FROM `peya-bi-tools-pro.il_qcommerce.fact_groceries_shopping_missions` 
WHERE registered_date >= "2024-01-01"
  AND is_darkstore
  AND order_status = "CONFIRMED"
  -- AND country_name = 'Argentina' -- Nombres en español
GROUP BY 1,2
ORDER BY 1,2,3 desc
-- GROUP BY 1,2,3,4
-- ORDER BY 1,2,3,4,5 desc
)
SELECT *
FROM todo