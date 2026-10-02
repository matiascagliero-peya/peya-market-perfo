DECLARE query_name STRING DEFAULT 'Customer Orders 2 - Base - Performance';

-- Customer Orders 2 - Base - Performance
WITH ordenes AS (

  WITH PIM AS (
     SELECT DISTINCT
    sku,
    country_code,
    FIRST_VALUE(product_name IGNORE NULLS) OVER (PARTITION BY sku, country_code ORDER BY master_product_created_at_utc DESC ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS product_name,
    FIRST_VALUE(barcodes IGNORE NULLS) OVER (PARTITION BY sku, country_code ORDER BY master_product_created_at_utc DESC ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS barcodes,
    CASE WHEN master_category_names.level_one IN ("Snacks", "Beverages") THEN "Impulse"
              WHEN master_category_names.level_one IN ("Bread / Bakery", "Dairy / Chilled / Eggs") THEN "Fresh"
              WHEN master_category_names.level_one IN ("Produce", "Meat / Seafood", "Ready To Consume") THEN "Ultra Fresh"
              WHEN master_category_names.level_one IN ("Home / Pet", "Personal Care / Baby / Health", "Smoking / Tobacco") THEN "Non-Food Grocery"
              WHEN master_category_names.level_one IN ("Frozen", "Packaged Foods") THEN "Packaged Food"
              WHEN master_category_names.level_one IN ("General Merchandise") THEN "General Merchandise"
              WHEN master_category_names.level_one IN ("BWS") THEN "BWS"
              END as Level_0,
    FIRST_VALUE(master_category_names.level_one IGNORE NULLS) OVER (PARTITION BY sku, country_code ORDER BY master_product_created_at_utc DESC ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS master_category_parent_english,
    FIRST_VALUE(master_category_names.level_two IGNORE NULLS) OVER (PARTITION BY sku, country_code ORDER BY master_product_created_at_utc DESC ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS category_level_two,
    FIRST_VALUE(master_category_names.level_three IGNORE NULLS) OVER (PARTITION BY sku, country_code ORDER BY master_product_created_at_utc DESC ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS category_level_three,
   
  FROM `peya-bi-tools-pro.il_qcommerce.dim_vendor_product` VP
 
  WHERE is_dmart
        
    )

  SELECT

    DATE_TRUNC(order_date, MONTH) AS month,
    order_id,
    customer_id,
    s.country_code,
    --COUNT (DISTINCT order_id) AS total_orders, 
    SUM (fulfilled_quantity) AS fulfilled_quantity,
    SUM (IF(Level_0 IN ('Fresh', 'Ultra Fresh'), fulfilled_quantity, 0)) AS units_uf_fresh,
    SUM (IF(Level_0 IN ('Impulse', 'BWS'), fulfilled_quantity, 0)) AS units_bws_impulse,
    SUM (IF(Level_0 IN ('Non-Food Grocery', 'General Merchandise'), fulfilled_quantity, 0)) AS units_gm_non_food,
    SUM (IF(Level_0 IN ('Packaged Food'), fulfilled_quantity, 0)) AS units_packaged_food,
    SUM (IF(Level_0 IS NULL, fulfilled_quantity, 0)) AS units_null_level,
    SUM (total_amount_net_with_discount_eur) AS net_sales,
    SUM (IF(Level_0 IN ('Fresh', 'Ultra Fresh'), total_amount_net_with_discount_eur, 0)) AS sales_uf_fresh,
     SUM (IF(Level_0 = 'Ultra Fresh', total_amount_net_with_discount_eur, 0)) AS sales_uf,
    SUM (IF(Level_0 IN ('Impulse', 'BWS'), total_amount_net_with_discount_eur, 0)) AS sales_bws_impulse,
    SUM (IF(Level_0 IN ('Non-Food Grocery', 'General Merchandise'), total_amount_net_with_discount_eur, 0)) AS sales_gm_non_food,
    SUM (IF(Level_0 IN ('Packaged Food'), total_amount_net_with_discount_eur, 0)) AS sales_packaged_food,
    SUM (IF(Level_0 IS NULL, total_amount_net_with_discount_eur, 0)) AS sales_null_level,
    SUM(ordered_quantity) as ordered_qty,
    SUM(pcm_discount_amount_net_eur) as discounts

  FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` s

  LEFT JOIN PIM p
    ON p.country_code = s.country_code
    AND p.sku = s.sku_id

  WHERE order_date >= "2024-01-01"
  --AND country_code = 'ar'
  AND state = 'CONFIRMED'

  GROUP BY 1,2,3,4, is_partial
  ORDER BY 4 DESC, 1 DESC

) 

SELECT 
  
  CAST ('LATAM' AS string) AS region,
  country_code ,
   CASE 
  WHEN country_code ="ar" THEN "Argentina" 
  WHEN country_code ="bo" THEN  "Bolivia" 
  WHEN country_code ="cl" THEN "Chile" 
  WHEN country_code ="cr" THEN "Costa Rica"
  WHEN country_code ="do" THEN "Republica Dominicana"
  WHEN country_code ="ec" THEN "Ecuador"
  WHEN country_code ="sv" THEN "El Salvador"
  WHEN country_code ="gt" THEN "Guatemala" 
  WHEN country_code ="hn" THEN "Honduras" 
  WHEN country_code ="ni" THEN "Nicaragua" 
  WHEN country_code ="pa" THEN "Panama" 
  WHEN country_code ="py" THEN "Paraguay" 
  WHEN country_code ="pe" THEN "Peru"
  WHEN country_code ="uy" THEN "Uruguay" 
  WHEN country_code ="ve" THEN "Venezuela" 
  END as country_name,
  month, 
  /*CASE  
    WHEN fulfilled_quantity <= 5 THEN '1-5'
    WHEN fulfilled_quantity BETWEEN 6 AND 15 THEN '6-15' --<= 15 
    WHEN fulfilled_quantity BETWEEN 11 AND 30 THEN  '16-30' --<= 20 THEN
    ELSE '>31' 
    END AS basket_size,*/
  COUNT (DISTINCT order_id) AS total_orders, 
  COUNT (DISTINCT customer_id) AS total_customers, 
  SUM(net_sales) AS net_sales,
  SUM(fulfilled_quantity) AS fulfilled_quantity,
  SUM(sales_uf_fresh) AS sales_uf_fresh,
  SUM(sales_bws_impulse) AS sales_bws_impulse,
  SUM(sales_gm_non_food) AS sales_gm_non_food,
  SUM(sales_packaged_food) AS sales_packaged_food,
  SUM(sales_null_level) AS sales_null_level,
  COUNT(IF(sales_uf_fresh > 0, order_id, NULL)) AS orders_uf_fresh,
  COUNT(IF(sales_bws_impulse > 0, order_id, NULL)) AS orders_bws_impulse,
  COUNT(IF(sales_gm_non_food > 0, order_id, NULL)) AS orders_gm_non_food,
  COUNT(IF(sales_packaged_food > 0, order_id, NULL)) AS orders_packaged_food,
  COUNT(IF(sales_null_level > 0, order_id, NULL)) AS orders_null_level,
  SUM(units_uf_fresh) AS units_uf_fresh,
  SUM(units_bws_impulse) AS units_bws_impulse,
  SUM(units_gm_non_food) AS units_gm_non_food,
  SUM(units_packaged_food) AS units_packaged_food,
  SUM(units_null_level) AS units_null_level,
  count(distinct case when ordered_qty > fulfilled_quantity then order_id else null end) as partial_orders,
  sum(discounts) as discounts_net_eur,
  COUNT(IF(sales_uf > 0, order_id, NULL)) AS orders_uf,
  


FROM ordenes
GROUP BY 1,2,3,4
ORDER BY 2,3 DESC,5 DESC  --, 2 DESC