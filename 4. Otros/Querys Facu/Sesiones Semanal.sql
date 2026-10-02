DECLARE query_name STRING DEFAULT 'Sesiones Semanal.sql';

-- ====================================================================================
-- PROPÓSITO: Cálculo de Sesiones y Transacciones de D-Marts a nivel SEMANAL
--            por PAÍS y total consolidado LATAM (Total, Sin Double Ya, y Con Double Ya).
--
-- APOYADO EN: '0. Pruebas\sesiones_semana_14_septiembre_2026.sql' y '1. OKRs_daily_data.sql'
-- CAMPOS EXPORTADOS:
--   • fecha: Fecha de inicio de la semana (Lunes).
--   • dia_fin_semana: Fecha de cierre de la semana (Domingo).
--   • pais: Nombre del país (o 'LATAM' para el consolidado regional).
--   • total_sessions: Sesiones totales de funnel en D-Marts.
--   • total_transactions: Transacciones totales de funnel en D-Marts.
--   • conversion_rate_pct: Ratio de conversión total (Transacciones / Sesiones * 100).
--   • sessions_non_double_ya: Sesiones orgánicas/directas sin Double Ya.
--   • transactions_non_double_ya: Transacciones sin Double Ya.
--   • conversion_rate_non_dy_pct: Conversión sin Double Ya.
--   • sessions_double_ya: Sesiones provenientes de la vertical Double Ya.
--   • transactions_double_ya: Transacciones provenientes de Double Ya.
-- ====================================================================================

-- Rango de fechas: por defecto últimas 8 semanas completas hasta ayer (Lunes a Domingo)
DECLARE inicio DATE DEFAULT DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 8 WEEK), WEEK(MONDAY));
DECLARE fin    DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);

WITH
-- 1. Identificación de darkstores según dim_partner_darkstore (Método oficial de OKRs)
partners AS (
  SELECT
    p.country_id,
    p.partner_id,
    pd.warehouse_id,
    TRUE AS darkstore
  FROM `peya-bi-tools-pro.il_core.dim_partner` p
  INNER JOIN `peya-datamarts-pro.dm_dmarts.dim_partner_darkstore` AS pd
    ON p.partner_id = pd.partner_id
  WHERE p.is_darkstore IS TRUE
    AND p.partner_name NOT IN (
      "RD_12_Torre OV", "PA_9_Midtown", "SV_6_Torre Futura",
      "EC_17_TiendaPick-Up Oficina", "PE_3_PuntaHermosa", "BO_19_Truck",
      "UY_15_Eventos", "PE_24_FILO", "EC_6_Oficina"
    )
),

-- 2. Agregación semanal de sesiones por país
sessions_by_country AS (
  SELECT
    DATE_TRUNC(DATE(fp.date), WEEK(MONDAY))                            AS fecha,
    DATE_ADD(DATE_TRUNC(DATE(fp.date), WEEK(MONDAY)), INTERVAL 6 DAY)    AS dia_fin_semana,
    c.country_name                                                     AS pais,

    -- 1. Total general
    SUM(fp.funnel_shop_details)                                        AS total_sessions,
    SUM(fp.funnel_shop_transaction)                                    AS total_transactions,

    -- 2. Sin Double Ya (Tráfico directo de Market)
    SUM(CASE WHEN (fp.funnel_shop_double_ya = 0 OR fp.funnel_shop_double_ya IS NULL) 
        THEN fp.funnel_shop_details ELSE 0 END)                        AS sessions_non_double_ya,
    SUM(CASE WHEN (fp.funnel_shop_double_ya = 0 OR fp.funnel_shop_double_ya IS NULL) 
        THEN fp.funnel_shop_transaction ELSE 0 END)                    AS transactions_non_double_ya,

    -- 3. Con Double Ya
    SUM(CASE WHEN fp.funnel_shop_double_ya > 0 
        THEN fp.funnel_shop_details ELSE 0 END)                        AS sessions_double_ya,
    SUM(CASE WHEN fp.funnel_shop_double_ya > 0 
        THEN fp.funnel_shop_transaction ELSE 0 END)                    AS transactions_double_ya

  FROM `peya-bi-tools-pro.il_sessions.perseus_fact_partner_funnel` fp
  INNER JOIN partners p ON fp.partner_id = p.partner_id
  INNER JOIN `peya-bi-tools-pro.il_core.dim_country` c 
    ON p.country_id = c.country_id AND c.active = TRUE
  WHERE DATE(fp.date) BETWEEN inicio AND fin
  GROUP BY 1, 2, 3
),

-- 3. Consolidado regional para toda la entidad 'LATAM'
sessions_latam AS (
  SELECT
    fecha,
    dia_fin_semana,
    'LATAM' AS pais,
    SUM(total_sessions)             AS total_sessions,
    SUM(total_transactions)         AS total_transactions,
    SUM(sessions_non_double_ya)     AS sessions_non_double_ya,
    SUM(transactions_non_double_ya) AS transactions_non_double_ya,
    SUM(sessions_double_ya)         AS sessions_double_ya,
    SUM(transactions_double_ya)     AS transactions_double_ya
  FROM sessions_by_country
  GROUP BY 1, 2
),

-- 4. Unión de países individuales + consolidado LATAM
combined AS (
  SELECT * FROM sessions_by_country
  UNION ALL
  SELECT * FROM sessions_latam
)

-- Consulta final con métricas y tasas de conversión
SELECT
  fecha,
  dia_fin_semana,
  pais,

  -- Métricas Totales
  total_sessions,
  total_transactions,
  ROUND(SAFE_DIVIDE(total_transactions, total_sessions) * 100, 2) AS conversion_rate_pct,

  -- Métricas Sin Double Ya
  sessions_non_double_ya,
  transactions_non_double_ya,
  ROUND(SAFE_DIVIDE(transactions_non_double_ya, sessions_non_double_ya) * 100, 2) AS conversion_rate_non_dy_pct,

  -- Métricas Con Double Ya
  sessions_double_ya,
  transactions_double_ya

FROM combined
ORDER BY 
  fecha DESC, 
  (CASE WHEN pais = 'LATAM' THEN 0 ELSE 1 END), 
  pais ASC;
