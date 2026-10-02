DECLARE query_name STRING DEFAULT '3. Open Time - Base - Ops (Mensual)';

-- Rango de fechas: desde 2026-01-01 hasta ayer (D-1)
DECLARE inicio DATE DEFAULT DATE("2025-01-01");
DECLARE fin    DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);

WITH
-- 1. Agrupamos a nivel mensual por cada País
monthly_by_country AS (
  SELECT
    DATE_TRUNC(fecha, MONTH)                                             AS month,
    pais                                                                 AS country_name,
    SUM(minutos_programados)                                             AS minutes_scheduled,
    SUM(minutos_cerrados_efectivos)                                      AS minutes_closed,
    SUM(disponibilidad_ponderada_hora)                                   AS disponibilidad_ponderada_mensual,
    SUM(peso_trafico_hora)                                               AS peso_trafico_mensual
  FROM `peya-food-and-groceries.automated_tables_reports.wot_hour_by_whs`
  WHERE fecha BETWEEN inicio AND fin
  GROUP BY 1, 2
),

-- 2. Consolidado regional para toda la entidad 'LATAM'
monthly_latam AS (
  SELECT
    month,
    'LATAM'                                                              AS country_name,
    SUM(minutes_scheduled)                                               AS minutes_scheduled,
    SUM(minutes_closed)                                                  AS minutes_closed,
    SUM(disponibilidad_ponderada_mensual)                                AS disponibilidad_ponderada_mensual,
    SUM(peso_trafico_mensual)                                            AS peso_trafico_mensual
  FROM monthly_by_country
  GROUP BY 1
),

-- 3. Unión de países individuales + consolidado LATAM
combined AS (
  SELECT * FROM monthly_by_country
  UNION ALL
  SELECT * FROM monthly_latam
)

-- 4. Consulta final con métricas y ratios consolidados (6 índices exactos)
SELECT
  month,
  country_name,

  minutes_scheduled,
  minutes_closed,

  -- Open Time Simple Mensual
  SAFE_DIVIDE(
    minutes_scheduled - minutes_closed,
    minutes_scheduled
  )                                                                      AS open_time_simple_monthly,

  -- Weighted Open Time (WOT) Mensual
  SAFE_DIVIDE(
    disponibilidad_ponderada_mensual,
    peso_trafico_mensual
  )                                                                      AS weighted_open_time_monthly

FROM combined
ORDER BY month DESC, (CASE WHEN country_name = 'LATAM' THEN 0 ELSE 1 END), country_name ASC;
