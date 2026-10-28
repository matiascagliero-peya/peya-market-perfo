DECLARE query_name STRING DEFAULT 'Glosario-210-Partial orders';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 210
-- Nombre:     Partial orders
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-delivery-and-support.automated_tables_reports.dmarts_ops_daily_new`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(partial_orders) órdenes con faltantes parciales
-- Definición: Cantidad total de órdenes entregadas de forma incompleta debido a quiebres de inventario durante el picking.
-- ====================================================================================

SELECT
  country_name AS country,
  DATE_TRUNC(DATE(date), MONTH) AS month,
  SUM(partial_orders) AS partial_orders
FROM `peya-delivery-and-support.automated_tables_reports.dmarts_ops_daily_new`
WHERE DATE(date) BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +---------+-------+----------------+
-- | country | month | partial_orders |
-- +---------+-------+----------------+
-- | LATAM   | 2.026 |         24.790 |
-- | ar      | 2.026 |         16.877 |
-- | bo      | 2.026 |            361 |
-- | cl      | 2.026 |          2.026 |
-- | do      | 2.026 |            694 |
-- | ec      | 2.026 |             88 |
-- | gt      | 2.026 |            140 |
-- | hn      | 2.026 |            191 |
-- | ni      | 2.026 |             71 |
-- | pa      | 2.026 |          1.045 |
-- | pe      | 2.026 |            697 |
-- | py      | 2.026 |            403 |
-- | sv      | 2.026 |            440 |
-- | uy      | 2.026 |          1.757 |
-- +---------+-------+----------------+
