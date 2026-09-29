DECLARE query_name STRING DEFAULT '31-Retention Rate (M1) Users';

-- Query de prueba para calcular la métrica Retention Rate (M1) (Argentina) - (Método JOIN)
-- 1. Obtener la tasa de retención M1 (mes 1) para Argentina, calculada por mes.
-- Métrica: Retention Rate (M1) (Argentina) = [Usuarios 'M1 Return' del Mes N] / [Usuarios 'Adoption' (nuevos) del Mes N-1]

WITH
  -- Paso 1: Contar los usuarios 'M1 Return' de cada mes (el Numerador)
  m1_return_counts AS (
    SELECT
      t.month,
      COUNT(DISTINCT t.customer_id) AS m1_return_users
    FROM
      `peya-food-and-groceries.automated_tables_reports.latam_first_dmart_order_date_users` t
    WHERE
      t.country = 'Argentina'
      AND t.Type = 'M1 Return'
    GROUP BY
      1
  ),

  -- Paso 2: Contar los usuarios 'Adoption' de cada mes (el Denominador)
  adoption_counts AS (
    SELECT
      t.month,
      COUNT(DISTINCT t.customer_id) AS new_users_adoption
    FROM
      `peya-food-and-groceries.automated_tables_reports.latam_first_dmart_order_date_users` t
    WHERE
      t.country = 'Argentina'
      AND t.Type = 'Adoption'
    GROUP BY
      1
  )

-- Paso 3: Unir las dos tablas y calcular la tasa
-- Unimos el Mes N (m1) con el Mes N-1 (adoption)
SELECT
  m1.month, -- Mes de la medición (Mes N)
  m1.m1_return_users AS m1_return_users_mes_n, -- (Numerador)
  adp.new_users_adoption AS new_users_mes_n_minus_1, -- (Denominador)
  
  -- Usamos SAFE_DIVIDE para evitar errores de división por cero
  SAFE_DIVIDE(m1.m1_return_users, adp.new_users_adoption) AS m1_retention_rate
FROM
  m1_return_counts AS m1
  
-- Usamos LEFT JOIN por si un mes tiene M1 Return pero el mes anterior no tuvo nuevos usuarios
LEFT JOIN
  adoption_counts AS adp
  -- Esta es la clave: unimos el mes actual de M1 con el mes anterior de Adoption
  ON m1.month = DATE_ADD(adp.month, INTERVAL 1 MONTH)

WHERE
  -- Filtramos para un rango de tiempo relevante, ej. los últimos 3 meses completos más el actual
  m1.month BETWEEN DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY), MONTH) 
               AND DATE_TRUNC(CURRENT_DATE(), MONTH) -- Últimos 90 días (redondeado a meses)
ORDER BY
  1 DESC; -- Ordenar por mes descendente