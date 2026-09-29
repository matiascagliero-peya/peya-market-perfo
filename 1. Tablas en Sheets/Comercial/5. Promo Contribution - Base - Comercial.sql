DECLARE query_name STRING DEFAULT '5. Promo Contribution - Base - Comercial';

SELECT 
  month,
 -- EXTRACT(MONTH FROM month) AS month_number,
  country_name,

  SUM(total_amount_net_with_discount_eur) AS net_sales, 
  SUM(CASE 
        WHEN pcm_discount_amount_net_eur > 0 
        THEN total_amount_net_with_discount_eur 
      END) AS promo_gpv,
  SUM(total_amount_sold_net_eur) AS gross_gpv,
  SUM(total_cogs_sold_net_eur) AS total_cogs_eur,
  SUM(fulfilled_quantity) AS total_quantity_sold,
  SUM(pcm_qty_products_applied_discount) AS total_quantity_sold_with_promos,
  SUM(pcm_discount_amount_net_eur) AS discount_amount_net_eur,
  COUNT(DISTINCT CASE 
        WHEN pcm_discount_amount_eur > 0 THEN sku_id 
      END) AS skus_with_promo,
  COUNT(DISTINCT sku_id) AS total_skus_sold

FROM (
  SELECT
    DATE_TRUNC(order_date, MONTH) AS month,
    country_name,
    total_amount_net_with_discount_eur,
    total_amount_sold_net_eur,
    total_cogs_sold_net_eur,
    fulfilled_quantity,
    pcm_qty_products_applied_discount,
    pcm_discount_amount_net_eur,
    pcm_discount_amount_eur,
    sku_id
  FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
  WHERE order_date >= "2025-01-01"
    AND state = "CONFIRMED"
)

group by 1,2
ORDER BY month, country_name;