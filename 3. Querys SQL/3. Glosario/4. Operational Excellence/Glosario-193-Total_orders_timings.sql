DECLARE query_name STRING DEFAULT 'Glosario-193-Total_orders_timings';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 193
-- Nombre:     Total_orders_timings
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-delivery-and-support.automated_tables_reports.dmarts_timings`
-- Tipo:       Dato Directo
-- Fórmula:    COUNT(DISTINCT order_id) en dmarts_timings
-- Definición: Total de órdenes registradas en la fuente de monitoreo de tiempos operativos (dmarts_timings). Utilizado como denominador para ratios de tiempos (ej. DT > 35 min).
-- ====================================================================================

SELECT
  country_code AS country,
  DATE_TRUNC(DATE(created_date), MONTH) AS month,
  COUNT(DISTINCT order_id) AS total_orders_timings
FROM `peya-delivery-and-support.automated_tables_reports.dmarts_timings`
WHERE DATE(created_date) BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +---------+-------+----------------------+
-- | country | month | total_orders_timings |
-- +---------+-------+----------------------+
-- | ar      | 2.026 |            2.647.093 |
-- | bo      | 2.026 |              142.396 |
-- | cl      | 2.026 |              341.336 |
-- | do      | 2.026 |              171.341 |
-- | ec      | 2.026 |               97.133 |
-- | gt      | 2.026 |               95.703 |
-- | hn      | 2.026 |               50.713 |
-- | ni      | 2.026 |               56.402 |
-- | pa      | 2.026 |               92.784 |
-- | pe      | 2.026 |              273.037 |
-- | py      | 2.026 |              135.574 |
-- | sv      | 2.026 |               86.216 |
-- | uy      | 2.026 |              286.923 |
-- +---------+-------+----------------------+
