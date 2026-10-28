DECLARE query_name STRING DEFAULT 'Glosario-247-Stacked 0 orders';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 247
-- Nombre:     Stacked 0 orders
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-bi-tools-pro.il_logistics.fact_logistic_orders`
-- Tipo:       Dato Directo
-- Fórmula:    COUNT(DISTINCT CASE WHEN stacked_deliveries = 0 THEN delivery_id END)
-- Definición: Pedidos entregados de forma exclusiva e individual (repartidor asignado a 1 solo pedido en el viaje).
-- ====================================================================================

SELECT
  country_code AS country,
  DATE_TRUNC(DATE(created_date), MONTH) AS month,
  COUNT(DISTINCT CASE WHEN UPPER(del.delivery_status) = 'COMPLETED' AND COALESCE(del.stacked_deliveries, 0) = 0 THEN del.delivery_id END) AS logistics_stacked_0
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
-- | country | logistics_stacked_0 | month |
-- +---------+---------------------+-------+
-- | ar      |           7.771.173 | 2.026 |
-- | bo      |             931.829 | 2.026 |
-- | cl      |           2.066.597 | 2.026 |
-- | cr      |             201.945 | 2.026 |
-- | do      |           1.187.535 | 2.026 |
-- | ec      |           1.079.722 | 2.026 |
-- | gt      |             817.968 | 2.026 |
-- | hn      |             771.598 | 2.026 |
-- | ni      |             601.571 | 2.026 |
-- | pa      |           1.095.396 | 2.026 |
-- | pe      |           2.070.900 | 2.026 |
-- | py      |             587.109 | 2.026 |
-- | sv      |             893.849 | 2.026 |
-- | uy      |             913.800 | 2.026 |
-- | ve      |             168.041 | 2.026 |
-- +---------+---------------------+-------+
