DECLARE query_name STRING DEFAULT 'Glosario-227-Order late 10 min orders';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 227
-- Nombre:     Order late 10 min orders
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-bi-tools-pro.il_logistics.fact_logistic_orders`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(is_order_late_10)
-- Definición: Cantidad total de pedidos con retraso crítico superior a 10 minutos frente a la promesa al cliente.
-- ====================================================================================

SELECT
  country_code AS country,
  DATE_TRUNC(DATE(created_date_local), MONTH) AS month,
  SUM(is_order_late_10) AS order_late_10_count
FROM `peya-bi-tools-pro.il_logistics.fact_logistic_orders`
WHERE DATE(created_date_local) BETWEEN '2026-09-01' AND '2026-09-30'
  AND order_cancelled != 1
  AND vendor.vertical_type = 'darkstores'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +---------+-------+---------------------+
-- | country | month | order_late_10_count |
-- +---------+-------+---------------------+
-- | ar      | 2.026 |             379.317 |
-- | bo      | 2.026 |              16.218 |
-- | cl      | 2.026 |              52.881 |
-- | do      | 2.026 |              16.995 |
-- | ec      | 2.026 |              15.762 |
-- | gt      | 2.026 |              16.998 |
-- | hn      | 2.026 |               7.942 |
-- | ni      | 2.026 |               6.948 |
-- | pa      | 2.026 |               8.773 |
-- | pe      | 2.026 |              23.780 |
-- | py      | 2.026 |              18.163 |
-- | sv      | 2.026 |              12.006 |
-- | uy      | 2.026 |              24.330 |
-- +---------+-------+---------------------+
