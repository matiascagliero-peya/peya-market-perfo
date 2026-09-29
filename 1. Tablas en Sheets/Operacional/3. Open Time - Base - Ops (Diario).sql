DECLARE query_name STRING DEFAULT '3. Open Time - Base - Ops (Diario)';

-- ====================================================================================
-- PROPÓSITO: Cálculo de Open Time y Weighted Open Time (WOT) a nivel DIARIO
--            por WAREHOUSE y PAÍS desde 2026, partiendo de 'wot_hour_by_whs'.
--
-- VENTAJAS:
--   1. Ejecución ultra rápida en Google Sheets / Looker (segundos).
--   2. Respeta el particionamiento de la tabla intermedia y asegura 100% de consistencia.
-- ====================================================================================

-- Rango de fechas: desde 2026-01-01 hasta el último día cerrado (D-1)
DECLARE inicio DATE DEFAULT DATE("2026-01-01");
DECLARE fin    DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);

WITH
-- 1. Agrupamos a nivel diario por cada Warehouse
daily_by_whs AS (
  SELECT
    fecha,
    pais,
    warehouse_id,
    warehouse_name,
    SUM(minutos_programados)               AS minutos_programados,
    SUM(minutos_cerrados_efectivos)        AS minutos_cerrados_efectivos,
    SUM(disponibilidad_ponderada_hora)     AS disponibilidad_ponderada_diaria,
    SUM(peso_trafico_hora)                 AS peso_trafico_diario
  FROM `peya-food-and-groceries.automated_tables_reports.wot_hour_by_whs`
  WHERE fecha BETWEEN inicio AND fin
  GROUP BY 1, 2, 3, 4
)

-- 2. Consulta final con cálculo de métricas simples y ponderadas
SELECT
  fecha,
  pais,
  warehouse_id,
  warehouse_name,

  minutos_programados,
  minutos_cerrados_efectivos,

  -- Open Time Simple Diario
  SAFE_DIVIDE(
    minutos_programados - minutos_cerrados_efectivos,
    minutos_programados
  )                                        AS open_time_simple_diario,

  disponibilidad_ponderada_diaria,
  peso_trafico_diario,

  -- Weighted Open Time (WOT) Diario
  SAFE_DIVIDE(
    disponibilidad_ponderada_diaria,
    peso_trafico_diario
  )                                        AS weighted_open_time_diario

FROM daily_by_whs
ORDER BY fecha DESC, pais, warehouse_name;
