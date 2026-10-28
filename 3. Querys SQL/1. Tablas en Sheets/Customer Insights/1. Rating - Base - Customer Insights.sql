DECLARE query_name STRING DEFAULT '1. Rating - Base - Customer Insights';

-- Sheets Name: 1. ET - Rating (11 - Rating)
-- Sheets Link: https://docs.google.com/spreadsheets/d/11QqrvD_M--OnZZWvGt-MNi17ixPqIToIe5ca-wrRn3k


WITH orders AS (
  SELECT 
    o.country.country_code,
    o.country.country_name,
    DATE(o.registered_date) AS order_date,
    o.order_id
  FROM `peya-bi-tools-pro.il_core.fact_orders` AS o
  WHERE o.order_status = 'CONFIRMED'
    AND DATE(o.registered_date) >= '2025-01-01'
)

SELECT 
  o.country_name,
  DATE_TRUNC(o.order_date, MONTH) AS month,
  COUNT(DISTINCT o.order_id) AS total_orders,
  SUM(r.partner.partner_rating) AS sum_ratings,
  COUNT(r.partner.partner_rating) AS count_ratings

FROM orders AS o
-- fact_orders ya maneja el order_id como INT64, por lo que el join puede ser directo
LEFT JOIN `peya-bi-tools-pro.il_core.fact_partner_survey_reviews` r 
  ON r.order_id = o.order_id
WHERE r.review.survey_name IN ('Restaurant Dish Survey', 'New Vertical Survey', 'Coffee Survey')

GROUP BY 1, 2
ORDER BY 1, 2;