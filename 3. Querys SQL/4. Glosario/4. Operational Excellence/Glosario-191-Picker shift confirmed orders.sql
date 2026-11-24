DECLARE query_name STRING DEFAULT 'Glosario-191-Picker shift confirmed orders';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 191
-- Nombre:     Picker shift confirmed orders
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-data-origins-pro.cl_dmarts.qc_picker_shift_orders` + `peya-bi-tools-pro.il_core.fact_orders`
-- Tipo:       Dato Directo
-- Fórmula:    COUNT(DISTINCT order_id) confirmadas en turnos de picker
-- Definición: Total de órdenes confirmadas que vienen de la fuente de turnos de pickers (qc_picker_shift_orders). Utilizado como denominador para métricas de tiempos de asignación.
-- ====================================================================================

SELECT
  fo.country.country_name AS country,
  DATE_TRUNC(DATE(fo.registered_date), MONTH) AS month,
  COUNT(DISTINCT fo.order_id) AS picker_shift_confirmed_orders
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
-- | country              | month      | picker_shift_confirmed_orders |
-- +----------------------+------------+-------------------------------+
-- | Argentina            | 2026-09-01 |                     3.872.735 |
-- | Bolivia              | 2026-09-01 |                       214.020 |
-- | Chile                | 2026-09-01 |                       454.171 |
-- | Ecuador              | 2026-09-01 |                       225.904 |
-- | El Salvador          | 2026-09-01 |                       158.368 |
-- | Guatemala            | 2026-09-01 |                       193.995 |
-- | Honduras             | 2026-09-01 |                       140.706 |
-- | Nicaragua            | 2026-09-01 |                       181.475 |
-- | Panam�               | 2026-09-01 |                       219.347 |
-- | Paraguay             | 2026-09-01 |                       184.067 |
-- | Per�                 | 2026-09-01 |                       391.016 |
-- | Rep�blica Dominicana | 2026-09-01 |                       402.190 |
-- | Uruguay              | 2026-09-01 |                       484.660 |
-- +----------------------+------------+-------------------------------+
