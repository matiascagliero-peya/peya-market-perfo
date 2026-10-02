-- ====================================================================================
-- PROPÓSITO: Obtener y verificar las sesiones de D-Marts para la semana del
--            14 al 20 de Septiembre de 2026 (del 2026-09-14 al 2026-09-20).
--            Se incluyen dos enfoques de filtrado para comparar consistencia:
--            1) Método Glosario (business_type_name = 'Market')
--            2) Método OKRs Daily (dim_partner_darkstore), detallando sesiones totales, 
--               sin Double Ya, y con Double Ya.
-- UBICACIÓN: C:\Users\matias.cagliero\Desktop\Cloude\0. Pruebas\sesiones_semana_14_septiembre_2026.sql
-- ====================================================================================

-- Declaración de variables para el rango de la semana del 14 al 20 de Septiembre de 2026
DECLARE from_date DATE DEFAULT '2026-09-14';
DECLARE to_date   DATE DEFAULT '2026-09-20';

WITH 
-- 1. Identificación de darkstores según dim_partner_darkstore (Método de OKRs_daily_data)
partners_darkstore AS (
  SELECT
    p.country_id,
    p.partner_id,
    pd.warehouse_id,
    TRUE AS darkstore
  FROM `peya-bi-tools-pro.il_core.dim_partner` p
  INNER JOIN `peya-datamarts-pro.dm_dmarts.dim_partner_darkstore` AS pd
    ON p.partner_id = pd.partner_id
),

-- 2. Sesiones calculadas con el Método Glosario (business_type_name = 'Market')
sessions_glosario AS (
  SELECT
    DATE(fp.date) AS day,
    fp.country_id,
    SUM(fp.funnel_shop_details) AS total_sessions,
    SUM(fp.funnel_shop_transaction) AS total_transactions
  FROM `peya-bi-tools-pro.il_sessions.perseus_fact_partner_funnel` fp
  INNER JOIN `peya-bi-tools-pro.il_core.dim_partner` dp ON fp.partner_id = dp.partner_id
  WHERE dp.business_type.business_type_name = 'Market'
    AND DATE(fp.date) BETWEEN from_date AND to_date
  GROUP BY 1, 2
),

-- 3. Sesiones calculadas con el Método OKRs Daily (dim_partner_darkstore con desglose Double Ya)
sessions_okrs AS (
  SELECT
    DATE(fp.date) AS day,
    fp.country_id,
    -- Sesiones totales
    SUM(fp.funnel_shop_details) AS total_sessions,
    -- Sin Double Ya
    SUM(CASE WHEN (fp.funnel_shop_double_ya = 0 OR fp.funnel_shop_double_ya IS NULL) 
        THEN fp.funnel_shop_details ELSE 0 END) AS sessions_non_dy,
    -- Con Double Ya
    SUM(CASE WHEN fp.funnel_shop_double_ya > 0 
        THEN fp.funnel_shop_details ELSE 0 END) AS sessions_dy
  FROM `peya-bi-tools-pro.il_sessions.perseus_fact_partner_funnel` fp
  INNER JOIN partners_darkstore p ON fp.partner_id = p.partner_id
  WHERE DATE(fp.date) BETWEEN from_date AND to_date
  GROUP BY 1, 2
)

-- Consolidación de resultados para comparación por Día y País
SELECT
  COALESCE(g.day, o.day) AS day,
  c.country_name,
  
  -- Métricas Método Glosario (dim_partner.business_type_name = 'Market')
  g.total_sessions AS sessions_glosario_total,
  g.total_transactions AS transactions_glosario_total,
  
  -- Métricas Método OKRs Daily (dim_partner_darkstore)
  o.total_sessions AS sessions_okrs_total,
  o.sessions_non_dy AS sessions_okrs_non_double_ya,
  o.sessions_dy AS sessions_okrs_double_ya_only

FROM sessions_glosario g
FULL OUTER JOIN sessions_okrs o 
  ON g.day = o.day AND g.country_id = o.country_id
INNER JOIN `peya-bi-tools-pro.il_core.dim_country` AS c
  ON c.country_id = COALESCE(g.country_id, o.country_id) AND c.active = TRUE
ORDER BY day ASC, country_name ASC;
