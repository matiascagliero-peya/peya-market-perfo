DECLARE query_name STRING DEFAULT '34-Sessions';

-- Query de prueba para calcular la métrica Sessions (Visitas totales de Dmart)
-- 1. Obtener el número de sesiones (visitas totales) a locales de Peya Market (Darkstores) por país y mes.
-- Métrica: Sessions = Suma de funnel_shop_details de la tabla de funnels de sesiones para locales de tipo 'Market'.
-- Frecuencia de actualización: la tabla perseus_fact_partner_funnel se actualiza de forma diaria.

WITH sessions_data AS (
  SELECT
    DATE_TRUNC(DATE(fp.date), MONTH) AS month, -- Agrupar por mes
    fp.country_id,
    
    -- Sesiones en la vista del local (Shop Details)
    SUM(fp.funnel_shop_details) AS sessions,
    
    -- Sesiones con transacciones (para cálculo de conversión CVR3 si es necesario)
    SUM(fp.funnel_shop_transaction) AS sessions_with_transactions
  FROM `peya-bi-tools-pro.il_sessions.perseus_fact_partner_funnel` fp
  INNER JOIN `peya-bi-tools-pro.il_core.dim_partner` dp 
    ON fp.partner_id = dp.partner_id
  WHERE dp.business_type.business_type_name = 'Market' -- Solo locales de Peya Market (Darkstores)
    AND DATE(fp.date) BETWEEN DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 MONTH), MONTH) 
                          AND CURRENT_DATE() -- Últimos 3 meses
  GROUP BY 1, 2
)

SELECT
  c.country_name AS country,
  s.month,
  
  -- Sesiones totales
  SUM(s.sessions) AS total_sessions,
  
  -- Sesiones transaccionadas (para referencia)
  SUM(s.sessions_with_transactions) AS total_sessions_transacted

FROM sessions_data s
INNER JOIN `peya-bi-tools-pro.il_core.dim_country` AS c
  ON c.country_id = s.country_id AND c.active = TRUE
GROUP BY 1, 2
ORDER BY country ASC, month DESC;
