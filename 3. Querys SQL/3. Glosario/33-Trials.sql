DECLARE query_name STRING DEFAULT '33-Trials';

-- Query de prueba para calcular la métrica Trials (Dos enfoques de negocio comunes)
-- Enfoque A: Usuarios que realizan su primera orden en Peya Market (Dmart Trialists / Adoption).
-- Enfoque B: Usuarios con una suscripción de prueba activa (Peya Plus Trials).
-- Frecuencia de actualización: la tabla customer_orders_sku_level y latam_first_dmart_order_date_users se actualizan de forma diaria/mensual.

-- ====================================================================================
-- ENFOQUE A: D-Marts Trialists (Nuevos usuarios que realizan su primer pedido)
-- ====================================================================================
WITH dmart_first_orders AS (
  SELECT
    country,
    month,
    COUNT(DISTINCT customer_id) AS dmart_trialists -- Cantidad de usuarios en periodo de 'Adoption' (Primer pedido)
  FROM
    `peya-food-and-groceries.automated_tables_reports.latam_first_dmart_order_date_users`
  WHERE
    Type = 'Adoption'
    AND month BETWEEN DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 MONTH), MONTH) AND CURRENT_DATE()
  GROUP BY 1, 2
),

-- ====================================================================================
-- ENFOQUE B: Peya Plus Trials (Usuarios que realizan pedidos usando una prueba de Plus)
-- ====================================================================================
plus_trials_orders AS (
  SELECT
    dc.country_name AS country,
    DATE_TRUNC(o.order_date, MONTH) AS month,
    
    -- Órdenes realizadas usando Peya Plus Trial (si existe el flag is_plus_trial o similar)
    -- COUNT(DISTINCT CASE WHEN o.is_plus_trial = 1 THEN o.order_id END) AS plus_trial_orders,
    
    -- Alternativamente, total de órdenes que son Plus (como referencia)
    COUNT(DISTINCT CASE WHEN o.is_user_plus = 1 THEN o.order_id END) AS total_plus_orders

  FROM
    `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` o
  LEFT JOIN `peya-bi-tools-pro.il_core.dim_country` dc
    ON o.country_id = dc.country_id
  WHERE
    UPPER(o.state) = 'CONFIRMED'
    AND o.order_date BETWEEN DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 MONTH), MONTH) AND CURRENT_DATE()
  GROUP BY 1, 2
)

SELECT
  df.country,
  df.month,
  df.dmart_trialists AS first_time_buyers_dmart,
  COALESCE(pt.total_plus_orders, 0) AS reference_plus_orders
FROM
  dmart_first_orders df
LEFT JOIN
  plus_trials_orders pt ON df.country = pt.country AND df.month = pt.month
ORDER BY
  1 ASC, 2 DESC;
