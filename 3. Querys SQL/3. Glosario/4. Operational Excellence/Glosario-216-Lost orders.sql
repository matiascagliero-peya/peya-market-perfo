DECLARE query_name STRING DEFAULT 'Glosario-216-Lost orders';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 216
-- Nombre:     Lost orders
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-delivery-and-support.automated_tables_reports.dmarts_ops_daily_new`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(lost_sessions) sesiones con pérdida de compra por stock
-- Definición: Volumen total de pedidos perdidos atribuibles a quiebres de stock en tienda.
-- ====================================================================================

SELECT
  country_name AS country,
  DATE_TRUNC(DATE(date), MONTH) AS month,
  SUM(lost_sessions) AS lost_orders
FROM `peya-delivery-and-support.automated_tables_reports.dmarts_ops_daily_new`
WHERE DATE(date) BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +---------+-------------+-------+
-- | country | lost_orders | month |
-- +---------+-------------+-------+
-- | LATAM   |       8.951 | 2.026 |
-- | ar      |       7.401 | 2.026 |
-- | bo      |         112 | 2.026 |
-- | cl      |           0 | 2.026 |
-- | do      |           0 | 2.026 |
-- | ec      |           0 | 2.026 |
-- | gt      |         108 | 2.026 |
-- | hn      |           0 | 2.026 |
-- | ni      |           0 | 2.026 |
-- | pa      |           0 | 2.026 |
-- | pe      |          37 | 2.026 |
-- | py      |           0 | 2.026 |
-- | sv      |           0 | 2.026 |
-- | uy      |       1.293 | 2.026 |
-- +---------+-------------+-------+
