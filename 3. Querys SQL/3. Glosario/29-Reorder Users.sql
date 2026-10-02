DECLARE query_name STRING DEFAULT '29-Reorder Users';

-- Query de prueba para calcular la métrica Reorder Users (Argentina)
-- 1. Obtener la cantidad total de usuarios únicos que retornan (reordenan) en Argentina por mes.
-- Métrica: Reorder Users (Argentina) = Cantidad de customer_id únicos que NO están en 'Adoption' (M1, Recurring o Reactivated) en Argentina, en un periodo de tiempo X.

SELECT
  t.month AS month, -- Mes de la actividad (agrupado por mes)
  COUNT(DISTINCT t.customer_id) AS reorder_users_argentina -- Total de usuarios que reordenan en Argentina
FROM
  `peya-food-and-groceries.automated_tables_reports.latam_first_dmart_order_date_users` t -- Tabla con usuarios clasificados por mes
WHERE
  -- Filtra por todos los tipos que representan un retorno
  t.Type IN ('M1 Return', 'Recurring Return', 'Reactivated')
  
  -- Filtra solo para Argentina
  AND t.country = 'Argentina'
  
  -- Filtramos para un rango de tiempo relevante, ej. los últimos 3 meses completos más el actual
  AND t.month BETWEEN DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY), MONTH) 
                  AND DATE_TRUNC(CURRENT_DATE(), MONTH) -- Últimos 90 días (redondeado a meses)
GROUP BY
  1 -- Agrupar solo por mes
ORDER BY
  1 DESC; -- Ordenar por mes descendente