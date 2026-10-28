DECLARE query_name STRING DEFAULT 'Glosario-214-Assignment Time > 6 min orders';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 214
-- Nombre:     Assignment Time > 6 min orders
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-data-origins-pro.cl_dmarts.qc_picker_shift_orders` + `peya-bi-tools-pro.il_core.fact_orders`
-- Tipo:       Dato Directo
-- Fórmula:    COUNT(DISTINCT CASE WHEN (order_events.order_available_to_start_duration_sec / 60) > 6 THEN fo.order_id END)
-- Definición: Cantidad total de órdenes confirmadas en tienda cuyo tiempo de asignación (desde disponibilidad hasta inicio de picking) superó los 6 minutos (order_available_to_start_duration_sec / 60 > 6).
-- ====================================================================================

SELECT
  fo.country.country_name AS country,
  DATE_TRUNC(DATE(fo.registered_date), MONTH) AS month,
  COUNT(DISTINCT CASE WHEN (order_events.order_available_to_start_duration_sec / 60) > 6 THEN fo.order_id END) AS assignment_time_over_6min_orders
FROM `peya-data-origins-pro.cl_dmarts.qc_picker_shift_orders` picko,
  UNNEST(picko.shifts) AS shifts,
  UNNEST(shifts.order_events) AS order_events
INNER JOIN `peya-bi-tools-pro.il_core.fact_orders` fo
  ON CAST(fo.order_id AS STRING) = CAST(order_events.order_id AS STRING)
WHERE fo.order_status = 'CONFIRMED'
  AND DATE(fo.registered_date) BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;
