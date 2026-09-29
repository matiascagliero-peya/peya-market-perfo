DECLARE query_name STRING DEFAULT '5. Weekly & MTD Users - Base - Performance (Weekly users)';

-- VARIABLES DE FECHA
DECLARE from_date DATE DEFAULT DATE_TRUNC(DATE '2025-01-01', ISOWEEK);
DECLARE to_date   DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);

WITH
-- 1. PARTNERS: Identifica los darkstores
partners AS (
  SELECT
    p.country_id,
    p.partner_id,
    TRUE AS darkstore
  FROM `peya-bi-tools-pro.il_core.dim_partner` p
  INNER JOIN `peya-datamarts-pro.dm_dmarts.dim_partner_darkstore` AS pd
    ON p.partner_id = pd.partner_id
),

-- 2. NEW USERS: Fecha de la primera orden por usuario en la plataforma
new_users AS (
  SELECT
    customer_id,
    co.country_id,
    MIN(DATE(registered_date)) AS first_order_date
  FROM `peya-bi-tools-pro.il_core.fact_orders` co
  INNER JOIN partners p ON co.restaurant.id = p.partner_id
  WHERE registered_date >= '2020-04-01'
    AND order_status = 'CONFIRMED'
  GROUP BY 1, 2
)

-- 3. CÁLCULO DE MÉTRICAS SEMANALES DE USUARIOS
SELECT
  EXTRACT(ISOYEAR FROM DATE(o.registered_date)) AS Iso_Year,
  DATE_TRUNC(DATE(o.registered_date), ISOWEEK) AS Week,
  EXTRACT(ISOWEEK FROM DATE(o.registered_date)) AS Week_Number,
  IF(c.country_name_en = 'Dominican Republic', 'Republica Dominicana', c.country_name_en) AS country_name,

  COUNT(DISTINCT o.customer_id) AS Users_Peya_Weekly,

  COUNT(DISTINCT CASE
    WHEN p.darkstore = TRUE
    THEN o.customer_id
  END) AS Users_dmart_weekly,

  COUNT(DISTINCT CASE
    WHEN p.darkstore = TRUE AND o.is_user_plus = 1
    THEN o.customer_id
  END) AS Users_dmart_plus_weekly,

  COUNT(DISTINCT CASE
    WHEN p.darkstore = TRUE
     AND DATE_TRUNC(nu.first_order_date, ISOWEEK) = DATE_TRUNC(DATE(o.registered_date), ISOWEEK)
    THEN o.customer_id
  END) AS Dmart_New_Users

FROM `peya-bi-tools-pro.il_core.fact_orders` AS o
INNER JOIN `peya-bi-tools-pro.il_core.dim_country` AS c
  ON c.country_id = o.country_id AND c.active = TRUE
LEFT JOIN partners p
  ON p.partner_id = o.restaurant.id
LEFT JOIN new_users nu
  ON nu.customer_id = o.customer_id AND nu.country_id = o.country_id
WHERE 
  DATE(o.registered_date) BETWEEN from_date AND to_date
  AND o.order_status = 'CONFIRMED'
  AND c.country_name NOT IN ('Venezuela','Costa Rica')

GROUP BY 1, 2, 3, 4
ORDER BY Week DESC, country_name ASC;