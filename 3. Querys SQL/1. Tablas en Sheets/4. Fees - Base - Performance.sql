DECLARE query_name STRING DEFAULT '4. Fees - Base - Performance';

-- 4. Fees - Base - Performance
SELECT
  DATE_TRUNC(o.registered_date, MONTH) AS mes,
  o.country.country_name_en AS country,
  o.business_type.business_type_name AS business_type,
  -- Simplificado: ya estás filtrando por 'CONFIRMED' en el WHERE
  COUNT(DISTINCT o.order_id) AS orders,
  SUM(dps.dps_minimum_order_value_local) AS mov,
  SUM(dps.dps_small_order_fee_local) AS small_order_fee,
  SUM(dps.dps_basket_value_fee_local) AS basket_value_fee,
  SAFE_DIVIDE(
    SUM(o.total_amount + o.discount_paid_by_company + o.shipping_amount - o.shipping_amount_no_discount),
    SUM(o.qty_total_products)
  ) AS avg_price_per_item
FROM `peya-bi-tools-pro.il_core.fact_orders` AS o
LEFT JOIN `peya-data-origins-pro.cl_hurrier.dps_sessions_mapped_to_orders` AS dps 
  ON CAST(o.order_id AS STRING) = dps.platform_order_code
LEFT JOIN `peya-bi-tools-pro.il_core.dim_partner` AS dp 
  ON dp.partner_id = o.restaurant.id
WHERE o.registered_date BETWEEN '2025-01-01' AND CURRENT_DATE() - 1
  AND dp.is_darkstore = TRUE
  AND o.pickup = FALSE
  AND o.order_status = 'CONFIRMED'
  AND o.with_logistics = TRUE
GROUP BY 1, 2, 3