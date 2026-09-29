DECLARE query_name STRING DEFAULT '38-Reactivated';

-- Query de prueba para calcular la métrica Reactivated Users
-- 1. Obtener la cantidad total de usuarios únicos reactivados por país y por mes.
-- Métrica: Reactivated Users = Cantidad de customer_id únicos clasificados como 'Reactivated' en un periodo de tiempo X.
-- Frecuencia de actualización: la tabla latam_first_dmart_order_date_users se actualiza de forma mensual/diaria.

SELECT
  t.country AS country, -- País de la actividad
  t.month AS month, -- Mes de la actividad (agrupado por mes)
  COUNT(DISTINCT t.customer_id) AS reactivated_users -- Total de usuarios únicos reactivados
FROM
  `peya-food-and-groceries.automated_tables_reports.latam_first_dmart_order_date_users` t -- Tabla con usuarios clasificados por mes
WHERE
  -- Filtra solo por el tipo de usuario 'Reactivated'
  t.Type = 'Reactivated'
  
  -- Filtramos para un rango de tiempo relevante, ej. los últimos 3 meses completos más el actual
  AND t.month BETWEEN DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY), MONTH) 
                  AND DATE_TRUNC(CURRENT_DATE(), MONTH) -- Últimos 90 días (redondeado a meses)
GROUP BY
  1, 2 -- Agrupar por país y mes
ORDER BY
  1 ASC, 2 DESC; -- Ordenar por país y luego mes descendente
