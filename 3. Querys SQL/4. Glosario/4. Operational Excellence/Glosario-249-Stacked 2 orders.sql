DECLARE query_name STRING DEFAULT 'Glosario-249-Stacked 2 orders';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 249
-- Nombre:     Stacked 2 orders
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-bi-tools-pro.il_logistics.fact_logistic_orders`
-- Tipo:       Dato Directo
-- Fórmula:    COUNT(DISTINCT CASE WHEN stacked_deliveries = 2 THEN delivery_id END)
-- Definición: Pedidos entregados dentro de un circuito agrupado de 3 pedidos en total.
-- ====================================================================================

SELECT
  country_code AS country,
  DATE_TRUNC(DATE(created_date), MONTH) AS month,
  COUNT(DISTINCT CASE WHEN UPPER(del.delivery_status) = 'COMPLETED' AND del.stacked_deliveries = 2 THEN del.delivery_id END) AS logistics_stacked_2
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
-- | country | logistics_stacked_2 | month |
-- +---------+---------------------+-------+
-- | ar      |           2.033.018 | 2.026 |
-- | bo      |              15.187 | 2.026 |
-- | cl      |             192.971 | 2.026 |
-- | cr      |                 477 | 2.026 |
-- | do      |              11.780 | 2.026 |
-- | ec      |              76.123 | 2.026 |
-- | gt      |              16.319 | 2.026 |
-- | hn      |              58.636 | 2.026 |
-- | ni      |              18.446 | 2.026 |
-- | pa      |              13.961 | 2.026 |
-- | pe      |               7.702 | 2.026 |
-- | py      |             109.531 | 2.026 |
-- | sv      |              74.609 | 2.026 |
-- | uy      |              68.646 | 2.026 |
-- | ve      |               5.516 | 2.026 |
-- +---------+---------------------+-------+
