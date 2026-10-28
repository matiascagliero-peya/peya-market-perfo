DECLARE query_name STRING DEFAULT 'Glosario-226-Order late 10 min %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 226
-- Nombre:     Order late 10 min %
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-bi-tools-pro.il_logistics.fact_logistic_orders`
-- Tipo:       Ratio Calculado
-- Fórmula:    SUM(is_order_late_10) / Total Orders Logistics
-- Definición: Porcentaje de pedidos entregados con más de 10 minutos de retraso respecto a la hora estimada de entrega prometida.
-- ====================================================================================

SELECT
  country_code AS country,
  DATE_TRUNC(DATE(created_date_local), MONTH) AS month,
  SUM(is_order_late_10) AS order_late_10_count,
  COUNT(DISTINCT peya_order_id) AS total_orders,
  SAFE_DIVIDE(SUM(is_order_late_10), NULLIF(COUNT(DISTINCT peya_order_id), 0)) AS order_late_10_pct
FROM `peya-bi-tools-pro.il_logistics.fact_logistic_orders`
WHERE DATE(created_date_local) BETWEEN '2026-09-01' AND '2026-09-30'
  AND order_cancelled != 1
  AND vendor.vertical_type = 'darkstores'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +---------+-------+---------------------+-------------------+--------------+
-- | country | month | order_late_10_count | order_late_10_pct | total_orders |
-- +---------+-------+---------------------+-------------------+--------------+
-- | ar      | 2.026 |             379.317 |            14,38% |    2.637.142 |
-- | bo      | 2.026 |              16.218 |            11,34% |      143.031 |
-- | cl      | 2.026 |              52.881 |            15,48% |      341.588 |
-- | do      | 2.026 |              16.995 |             9,90% |      171.687 |
-- | ec      | 2.026 |              15.762 |            16,27% |       96.883 |
-- | gt      | 2.026 |              16.998 |            17,85% |       95.251 |
-- | hn      | 2.026 |               7.942 |            15,72% |       50.536 |
-- | ni      | 2.026 |               6.948 |            12,26% |       56.668 |
-- | pa      | 2.026 |               8.773 |             9,43% |       93.030 |
-- | pe      | 2.026 |              23.780 |             8,72% |      272.594 |
-- | py      | 2.026 |              18.163 |            13,36% |      135.928 |
-- | sv      | 2.026 |              12.006 |            14,06% |       85.413 |
-- | uy      | 2.026 |              24.330 |             8,61% |      282.486 |
-- +---------+-------+---------------------+-------------------+--------------+
