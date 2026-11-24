DECLARE query_name STRING DEFAULT 'Glosario-211-Assignment Time';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 211
-- Nombre:     Assignment Time
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-data-origins-pro.cl_dmarts.qc_picker_shift_orders` + `peya-bi-tools-pro.il_core.fact_orders`
-- Tipo:       Dato Directo
-- Fórmula:    Assignment Time total / Picker shift confirmed orders = SUM(order_available_to_start_duration_sec / 60) / COUNT(DISTINCT fo.order_id)
-- Definición: Tiempo promedio de asignación en minutos por orden en tienda. Mide la demora media desde que el pedido queda disponible en el sistema hasta que el picker efectivamente inicia la preparación (evento order_available_to_start_duration_sec convertido a minutos). Se calcula dividiendo el tiempo total de asignación sobre las órdenes confirmadas de los turnos de picker.
-- ====================================================================================

SELECT
  fo.country.country_name AS country,
  DATE_TRUNC(DATE(fo.registered_date), MONTH) AS month,
  SUM(order_events.order_available_to_start_duration_sec / 60) AS assignment_time_total_min,
  COUNT(DISTINCT fo.order_id) AS picker_shift_confirmed_orders,
  SAFE_DIVIDE(
    SUM(order_events.order_available_to_start_duration_sec / 60),
    NULLIF(COUNT(DISTINCT fo.order_id), 0)
  ) AS assignment_time_avg_min
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
-- +----------------------+------------+-------------------------+
-- | country              | month      | assignment_time_avg_min |
-- +----------------------+------------+-------------------------+
-- | Argentina            | 2026-09-01 |                    2,72 |
-- | Bolivia              | 2026-09-01 |                    4,53 |
-- | Chile                | 2026-09-01 |                    3,66 |
-- | Ecuador              | 2026-09-01 |                    4,06 |
-- | El Salvador          | 2026-09-01 |                    2,93 |
-- | Guatemala            | 2026-09-01 |                    3,16 |
-- | Honduras             | 2026-09-01 |                    3,19 |
-- | Nicaragua            | 2026-09-01 |                    2,00 |
-- | Panam�               | 2026-09-01 |                    5,69 |
-- | Paraguay             | 2026-09-01 |                    3,76 |
-- | Per�                 | 2026-09-01 |                    2,99 |
-- | Rep�blica Dominicana | 2026-09-01 |                    4,01 |
-- | Uruguay              | 2026-09-01 |                    5,32 |
-- +----------------------+------------+-------------------------+
