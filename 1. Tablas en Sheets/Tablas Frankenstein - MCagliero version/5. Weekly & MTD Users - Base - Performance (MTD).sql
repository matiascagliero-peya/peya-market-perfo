DECLARE query_name STRING DEFAULT '5. Weekly & MTD Users - Base - Performance (MTD)';

DECLARE query_source STRING DEFAULT '5. MTD Users - Base - Performance';

-- VARIABLES DE FECHA
DECLARE from_date DATE DEFAULT DATE_TRUNC(DATE '2025-01-01', MONTH);
DECLARE to_date   DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);

WITH
-- 1. PARTNERS & NEW USERS (Bases históricas)
partners AS (
  SELECT p.country_id, p.partner_id, TRUE AS darkstore
  FROM `peya-bi-tools-pro.il_core.dim_partner` p
  INNER JOIN `peya-datamarts-pro.dm_dmarts.dim_partner_darkstore` AS pd
    ON p.partner_id = pd.partner_id
),

new_users AS (
  SELECT customer_id, co.country_id, MIN(DATE(registered_date)) AS first_order_date
  FROM `peya-bi-tools-pro.il_core.fact_orders` co
  INNER JOIN partners p ON co.restaurant.id = p.partner_id
  WHERE DATE(registered_date) >= '2020-04-01'
    AND order_status = 'CONFIRMED'
  GROUP BY 1, 2
),

-- 2. EL DEBUT MENSUAL DEL USUARIO
user_monthly_firsts AS (
  SELECT
    IF(c.country_name_en = 'Dominican Republic', 'Republica Dominicana', c.country_name_en) AS country_name,
    DATE_TRUNC(DATE(o.registered_date), MONTH) AS month,
    o.customer_id,
    
    -- Primer día del mes que compró en PeYa (cualquier negocio)
    MIN(DATE(o.registered_date)) AS first_peya_date,
    
    -- Primer día del mes que compró en Dmart
    MIN(CASE WHEN p.darkstore = TRUE THEN DATE(o.registered_date) END) AS first_dmart_date,
    
    -- Primer día del mes que compró en Dmart siendo Plus
    MIN(CASE WHEN p.darkstore = TRUE AND o.is_user_plus = 1 THEN DATE(o.registered_date) END) AS first_dmart_plus_date,
    
    -- Primer día del mes que compró en Dmart siendo un Nuevo Usuario histórico
    MIN(CASE 
          WHEN p.darkstore = TRUE 
           AND DATE_TRUNC(nu.first_order_date, MONTH) = DATE_TRUNC(DATE(o.registered_date), MONTH) 
          THEN DATE(o.registered_date) 
        END) AS first_new_dmart_date

  FROM `peya-bi-tools-pro.il_core.fact_orders` AS o
  INNER JOIN `peya-bi-tools-pro.il_core.dim_country` AS c
    ON c.country_id = o.country_id AND c.active = TRUE
  LEFT JOIN partners p ON p.partner_id = o.restaurant.id
  LEFT JOIN new_users nu ON nu.customer_id = o.customer_id AND nu.country_id = o.country_id
  WHERE DATE(o.registered_date) BETWEEN from_date AND to_date
    AND o.order_status = 'CONFIRMED'
    AND c.country_name NOT IN ('Venezuela', 'Costa Rica')
  GROUP BY 1, 2, 3
),

-- 3. CALENDARIO Y CONTEOS DIARIOS
calendar AS (
  SELECT DISTINCT 
    IF(c.country_name_en = 'Dominican Republic', 'Republica Dominicana', c.country_name_en) AS country_name, 
    day_date AS date, 
    DATE_TRUNC(day_date, MONTH) AS month
  FROM `peya-bi-tools-pro.il_core.dim_country` c
  CROSS JOIN UNNEST(GENERATE_DATE_ARRAY(from_date, to_date)) AS day_date
  WHERE c.active = TRUE AND c.country_name NOT IN ('Venezuela', 'Costa Rica')
),

peya_inc AS (
  SELECT country_name, first_peya_date AS date, COUNT(customer_id) AS qty 
  FROM user_monthly_firsts WHERE first_peya_date IS NOT NULL GROUP BY 1, 2
),
dmart_inc AS (
  SELECT country_name, first_dmart_date AS date, COUNT(customer_id) AS qty 
  FROM user_monthly_firsts WHERE first_dmart_date IS NOT NULL GROUP BY 1, 2
),
plus_inc AS (
  SELECT country_name, first_dmart_plus_date AS date, COUNT(customer_id) AS qty 
  FROM user_monthly_firsts WHERE first_dmart_plus_date IS NOT NULL GROUP BY 1, 2
),
new_inc AS (
  SELECT country_name, first_new_dmart_date AS date, COUNT(customer_id) AS qty 
  FROM user_monthly_firsts WHERE first_new_dmart_date IS NOT NULL GROUP BY 1, 2
)

-- 4. SUMA ACUMULATIVA (MTD)
SELECT 
  c.date,
  c.month,
  c.country_name,
  
  SUM(COALESCE(p.qty, 0)) OVER (PARTITION BY c.country_name, c.month ORDER BY c.date) AS Users_Peya_MTD,
  SUM(COALESCE(d.qty, 0)) OVER (PARTITION BY c.country_name, c.month ORDER BY c.date) AS Users_dmart_MTD,
  SUM(COALESCE(pl.qty, 0)) OVER (PARTITION BY c.country_name, c.month ORDER BY c.date) AS Users_dmart_plus_MTD,
  SUM(COALESCE(n.qty, 0)) OVER (PARTITION BY c.country_name, c.month ORDER BY c.date) AS Dmart_New_Users_MTD

FROM calendar c
LEFT JOIN peya_inc p ON c.country_name = p.country_name AND c.date = p.date
LEFT JOIN dmart_inc d ON c.country_name = d.country_name AND c.date = d.date
LEFT JOIN plus_inc pl ON c.country_name = pl.country_name AND c.date = pl.date
LEFT JOIN new_inc n ON c.country_name = n.country_name AND c.date = n.date

ORDER BY c.date DESC, c.country_name ASC;