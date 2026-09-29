DECLARE query_name STRING DEFAULT '27-Recurring Return User';

-- Query de prueba para calcular la métrica Recurring Return Users (Argentina)
-- 1. Obtener la cantidad total de usuarios únicos recurrentes en Argentina por mes.
-- Métrica: Recurring Return Users (Argentina) = Cantidad de customer_id únicos clasificados como 'Recurring Return' en Argentina, en un periodo de tiempo X.

SELECT
  t.month AS month, -- Mes de la actividad (agrupado por mes)
  COUNT(DISTINCT t.customer_id) AS recurring_return_users_argentina -- Total de usuarios únicos recurrentes en Argentina
FROM
  `peya-food-and-groceries.automated_tables_reports.latam_first_dmart_order_date_users` t -- Tabla con usuarios clasificados por mes
WHERE
  -- Filtra solo por el tipo de usuario 'Recurring Return'
  t.Type = 'Recurring Return'
  
  -- Filtra solo para Argentina
  AND t.country = 'Argentina'
  
  -- Filtramos para un rango de tiempo relevante, ej. los últimos 3 meses completos más el actual
  AND t.month BETWEEN DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY), MONTH) 
                  AND DATE_TRUNC(CURRENT_DATE(), MONTH) -- Últimos 90 días (redondeado a meses)
GROUP BY
  1 -- Agrupar solo por mes
ORDER BY
  1 DESC; -- Ordenar por mes descendente