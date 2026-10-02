DECLARE query_name STRING DEFAULT '3. Open Time - Base - Ops (Semanal)';

-- ====================================================================================
-- PROPÓSITO: Cálculo de Open Time y Weighted Open Time (WOT) a nivel SEMANAL
--            por PAÍS y total LATAM, partiendo de la tabla intermedia 'wot_hour_by_whs'.
--
-- VENTAJAS:
--   1. Consume 99% menos cuota y tarda segundos (evita reprocesar Perseus y fact_partner_times).
--   2. Respeta el particionamiento por 'fecha' en la tabla origen.
-- ====================================================================================

-- Rango de fechas: por defecto últimas 8 semanas completas hasta ayer (arrancando siempre en Lunes)
DECLARE inicio DATE DEFAULT DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 15 WEEK), WEEK(MONDAY));
DECLARE fin    DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);

WITH
-- 1. Agrupamos a nivel semanal por cada País
weekly_by_country AS (
  SELECT
    DATE_TRUNC(fecha, WEEK(MONDAY))                                      AS dia_inicio_semana,
    DATE_ADD(DATE_TRUNC(fecha, WEEK(MONDAY)), INTERVAL 6 DAY)            AS dia_fin_semana,
    pais,
    SUM(minutos_programados)                                             AS minutos_programados,
    SUM(minutos_cerrados_efectivos)                                      AS minutos_cerrados_efectivos,
    SUM(disponibilidad_ponderada_hora)                                   AS disponibilidad_ponderada_semanal,
    SUM(peso_trafico_hora)                                               AS peso_trafico_semanal
  FROM `peya-food-and-groceries.automated_tables_reports.wot_hour_by_whs`
  WHERE fecha BETWEEN inicio AND fin
  GROUP BY 1, 2, 3
),

-- 2. Consolidado regional para toda la entidad 'LATAM'
weekly_latam AS (
  SELECT
    dia_inicio_semana,
    dia_fin_semana,
    'LATAM'                                                              AS pais,
    SUM(minutos_programados)                                             AS minutos_programados,
    SUM(minutos_cerrados_efectivos)                                      AS minutos_cerrados_efectivos,
    SUM(disponibilidad_ponderada_semanal)                                AS disponibilidad_ponderada_semanal,
    SUM(peso_trafico_semanal)                                            AS peso_trafico_semanal
  FROM weekly_by_country
  GROUP BY 1, 2
),

-- 3. Unión de países individuales + consolidado LATAM
combined AS (
  SELECT * FROM weekly_by_country
  UNION ALL
  SELECT * FROM weekly_latam
)

-- Consulta final con métricas y ratios consolidados
SELECT
  dia_inicio_semana,
  dia_fin_semana,
  pais,

  minutos_programados,
  minutos_cerrados_efectivos,

  SAFE_DIVIDE(
    minutos_programados - minutos_cerrados_efectivos,
    minutos_programados
  )                                                                      AS open_time_simple_semanal,

  disponibilidad_ponderada_semanal,
  peso_trafico_semanal,

  SAFE_DIVIDE(
    disponibilidad_ponderada_semanal,
    peso_trafico_semanal
  )                                                                      AS weighted_open_time_semanal

FROM combined
ORDER BY dia_inicio_semana DESC, (CASE WHEN pais = 'LATAM' THEN 0 ELSE 1 END), pais;
