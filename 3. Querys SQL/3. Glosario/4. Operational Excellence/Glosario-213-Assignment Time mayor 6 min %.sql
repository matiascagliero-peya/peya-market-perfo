DECLARE query_name STRING DEFAULT 'Glosario-213-Assignment Time > 6 min %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 213
-- Nombre:     Assignment Time > 6 min %
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-data-origins-pro.cl_dmarts.qc_picker_shift_orders` + `peya-bi-tools-pro.il_core.fact_orders`
-- Tipo:       Ratio Calculado
-- Fórmula:    Assignment Time > 6 min orders / Picker shift confirmed orders = COUNT(DISTINCT CASE WHEN (order_available_to_start_duration_sec / 60) > 6 THEN fo.order_id END) / COUNT(DISTINCT fo.order_id)
-- Definición: Porcentaje de órdenes confirmadas con demora crítica en la asignación (> 6 minutos). Mide la severidad de los cuellos de botella en la tienda sobre el total de órdenes gestionadas en turnos de picker.
-- ====================================================================================

SELECT
  fo.country.country_name AS country,
  DATE_TRUNC(DATE(fo.registered_date), MONTH) AS month,
  COUNT(DISTINCT CASE WHEN (order_events.order_available_to_start_duration_sec / 60) > 6 THEN fo.order_id END) AS assignment_time_over_6min_orders,
  COUNT(DISTINCT fo.order_id) AS picker_shift_confirmed_orders,
  SAFE_DIVIDE(
    COUNT(DISTINCT CASE WHEN (order_events.order_available_to_start_duration_sec / 60) > 6 THEN fo.order_id END),
    NULLIF(COUNT(DISTINCT fo.order_id), 0)
  ) AS assignment_time_over_6min_pct
FROM `peya-data-origins-pro.cl_dmarts.qc_picker_shift_orders` picko,
  UNNEST(picko.shifts) AS shifts,
  UNNEST(shifts.order_events) AS order_events
INNER JOIN `peya-bi-tools-pro.il_core.fact_orders` fo
  ON CAST(fo.order_id AS STRING) = CAST(order_events.order_id AS STRING)
WHERE fo.order_status = 'CONFIRMED'
  AND DATE(fo.registered_date) BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+------------+-------------------------------+
-- | country              | month      | assignment_time_over_6min_pct |
-- +----------------------+------------+-------------------------------+
-- | Argentina            | 2026-09-01 |                        11,86% |
-- | Bolivia              | 2026-09-01 |                        23,36% |
-- | Chile                | 2026-09-01 |                        16,89% |
-- | Ecuador              | 2026-09-01 |                        19,46% |
-- | El Salvador          | 2026-09-01 |                        14,40% |
-- | Guatemala            | 2026-09-01 |                        13,26% |
-- | Honduras             | 2026-09-01 |                        15,43% |
-- | Nicaragua            | 2026-09-01 |                         8,58% |
-- | Panam�               | 2026-09-01 |                        25,04% |
-- | Paraguay             | 2026-09-01 |                        18,44% |
-- | Per�                 | 2026-09-01 |                        12,22% |
-- | Rep�blica Dominicana | 2026-09-01 |                        19,63% |
-- | Uruguay              | 2026-09-01 |                        24,70% |
-- +----------------------+------------+-------------------------------+
