DECLARE query_name STRING DEFAULT '26-New Users';

-- Query de prueba para calcular la métrica New Users (Argentina)
-- 1. Obtener la cantidad total de usuarios nuevos (Adoption) en Argentina por mes.
-- Métrica: New Users (Argentina) = Cantidad de customer_id únicos clasificados como 'Adoption' en Argentina, en un periodo de tiempo X.

SELECT
  t.month AS month, -- Mes de la actividad (agrupado por mes)
  COUNT(DISTINCT t.customer_id) AS new_users_argentina -- Total de usuarios nuevos en Argentina
FROM
  `peya-food-and-groceries.automated_tables_reports.latam_first_dmart_order_date_users` t -- Tabla con usuarios clasificados por mes
WHERE
  -- Filtra solo por el tipo de usuario 'Adoption'
  t.Type = 'Adoption'
  
  -- Filtra solo para Argentina
  AND t.country = 'Argentina'
  
  -- Filtramos para un rango de tiempo relevante, ej. los últimos 3 meses completos más el actual
  AND t.month BETWEEN DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY), MONTH) 
                  AND DATE_TRUNC(CURRENT_DATE(), MONTH) -- Últimos 90 días (redondeado a meses)
GROUP BY
  1 -- Agrupar solo por mes
ORDER BY
  1 DESC; -- Ordenar por mes descendente