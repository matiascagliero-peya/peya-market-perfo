-- Query de prueba para calcular la métrica Re-Activation Users (Argentina)
-- 1. Obtener la cantidad total de usuarios únicos reactivados en Argentina específicamente para el mes pasado.
-- Métrica: Re-Activation Users (Argentina) = Cantidad de customer_id únicos clasificados como 'Reactivated' en Argentina, en el mes anterior.

SELECT
  DATE_TRUNC(DATE(gt.month), MONTH) AS month, -- Mes de la actividad (agrupado por mes)
  COUNT(DISTINCT gt.customer_id) AS reactivated_users_argentina -- Total de usuarios únicos reactivados en Argentina
FROM
  `peya-food-and-groceries.automated_tables_reports.latam_dmart_growth_tracker` gt -- Tabla con usuarios clasificados por mes (Growth Tracker)
WHERE
  -- Filtra solo por el tipo de usuario 'Reactivated'
  gt.dmart_growth_status_fixed = 'Reactivated'
  
  -- Filtra solo para Argentina
  AND gt.country_name_es = 'Argentina'
  
  -- Filtramos específicamente para el mes pasado completo
  AND DATE_TRUNC(DATE(gt.month), MONTH) = DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)
GROUP BY
  1 -- Agrupar solo por mes
ORDER BY
  1 DESC; -- Ordenar por mes descendente