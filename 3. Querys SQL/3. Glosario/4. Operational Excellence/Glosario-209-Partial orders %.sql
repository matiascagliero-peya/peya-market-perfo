DECLARE query_name STRING DEFAULT 'Glosario-209-Partial orders %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 209
-- Nombre:     Partial orders %
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-delivery-and-support.automated_tables_reports.dmarts_ops_daily_new`
-- Tipo:       Ratio Calculado
-- Fórmula:    SUM(partial_orders) / SUM(orders)
-- Definición: Porcentaje de órdenes despachadas con faltantes parciales de productos sobre el total de pedidos preparados.
-- ====================================================================================

SELECT
  country_name AS country,
  DATE_TRUNC(DATE(date), MONTH) AS month,
  SUM(partial_orders) AS partial_orders,
  SUM(orders) AS total_orders,
  SAFE_DIVIDE(SUM(partial_orders), NULLIF(SUM(orders), 0)) AS partial_orders_pct
FROM `peya-delivery-and-support.automated_tables_reports.dmarts_ops_daily_new`
WHERE DATE(date) BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +---------+-------+----------------+--------------------+--------------+
-- | country | month | partial_orders | partial_orders_pct | total_orders |
-- +---------+-------+----------------+--------------------+--------------+
-- | LATAM   | 2.026 |         24.790 |              0,55% |    4.544.981 |
-- | ar      | 2.026 |         16.877 |              0,63% |    2.689.254 |
-- | bo      | 2.026 |            361 |              0,25% |      144.397 |
-- | cl      | 2.026 |          2.026 |              0,58% |      346.919 |
-- | do      | 2.026 |            694 |              0,40% |      173.092 |
-- | ec      | 2.026 |             88 |              0,09% |       98.841 |
-- | gt      | 2.026 |            140 |              0,14% |       97.654 |
-- | hn      | 2.026 |            191 |              0,37% |       51.377 |
-- | ni      | 2.026 |             71 |              0,12% |       56.933 |
-- | pa      | 2.026 |          1.045 |              1,11% |       94.069 |
-- | pe      | 2.026 |            697 |              0,25% |      277.278 |
-- | py      | 2.026 |            403 |              0,29% |      137.201 |
-- | sv      | 2.026 |            440 |              0,50% |       87.268 |
-- | uy      | 2.026 |          1.757 |              0,60% |      290.698 |
-- +---------+-------+----------------+--------------------+--------------+
