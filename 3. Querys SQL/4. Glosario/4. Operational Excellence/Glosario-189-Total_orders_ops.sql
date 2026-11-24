DECLARE query_name STRING DEFAULT 'Glosario-189-Total_orders_ops';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 189
-- Nombre:     Total_orders_ops
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-delivery-and-support.automated_tables_reports.dmarts_ops_daily_new`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(orders) en dmarts_ops_daily_new
-- Definición: Total de órdenes operativas de tienda registradas en el monitor diario de operaciones (dmarts_ops_daily_new). Utilizado como denominador para órdenes parciales.
-- ====================================================================================

SELECT
  country_name AS country,
  DATE_TRUNC(DATE(date), MONTH) AS month,
  SUM(orders) AS total_orders_ops
FROM `peya-delivery-and-support.automated_tables_reports.dmarts_ops_daily_new`
WHERE DATE(date) BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +---------+-------+------------------+
-- | country | month | total_orders_ops |
-- +---------+-------+------------------+
-- | LATAM   | 2.026 |        4.544.981 |
-- | ar      | 2.026 |        2.689.254 |
-- | bo      | 2.026 |          144.397 |
-- | cl      | 2.026 |          346.919 |
-- | do      | 2.026 |          173.092 |
-- | ec      | 2.026 |           98.841 |
-- | gt      | 2.026 |           97.654 |
-- | hn      | 2.026 |           51.377 |
-- | ni      | 2.026 |           56.933 |
-- | pa      | 2.026 |           94.069 |
-- | pe      | 2.026 |          277.278 |
-- | py      | 2.026 |          137.201 |
-- | sv      | 2.026 |           87.268 |
-- | uy      | 2.026 |          290.698 |
-- +---------+-------+------------------+
