DECLARE query_name STRING DEFAULT 'Glosario-248-Stacked 1 orders';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 248
-- Nombre:     Stacked 1 orders
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-bi-tools-pro.il_logistics.fact_logistic_orders`
-- Tipo:       Dato Directo
-- Fórmula:    COUNT(DISTINCT CASE WHEN stacked_deliveries = 1 THEN delivery_id END)
-- Definición: Pedidos entregados dentro de un circuito agrupado de 2 pedidos en total.
-- ====================================================================================

SELECT
  country_code AS country,
  DATE_TRUNC(DATE(created_date), MONTH) AS month,
  COUNT(DISTINCT CASE WHEN UPPER(del.delivery_status) = 'COMPLETED' AND del.stacked_deliveries = 1 THEN del.delivery_id END) AS logistics_stacked_1
FROM `peya-bi-tools-pro.il_logistics.fact_logistic_orders` lo
CROSS JOIN UNNEST(lo.deliveries) del
WHERE DATE(lo.created_date) BETWEEN '2026-09-01' AND '2026-09-30'
  AND UPPER(lo.order_status) = 'COMPLETED'
  AND lo.is_preorder IS FALSE
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +---------+---------------------+-------+
-- | country | logistics_stacked_1 | month |
-- +---------+---------------------+-------+
-- | ar      |           3.720.171 | 2.026 |
-- | bo      |             572.107 | 2.026 |
-- | cl      |           1.036.790 | 2.026 |
-- | cr      |              56.583 | 2.026 |
-- | do      |             743.178 | 2.026 |
-- | ec      |             409.597 | 2.026 |
-- | gt      |             574.953 | 2.026 |
-- | hn      |             439.792 | 2.026 |
-- | ni      |             327.390 | 2.026 |
-- | pa      |             366.114 | 2.026 |
-- | pe      |           1.026.019 | 2.026 |
-- | py      |             318.567 | 2.026 |
-- | sv      |             536.007 | 2.026 |
-- | uy      |             682.762 | 2.026 |
-- | ve      |              55.962 | 2.026 |
-- +---------+---------------------+-------+
