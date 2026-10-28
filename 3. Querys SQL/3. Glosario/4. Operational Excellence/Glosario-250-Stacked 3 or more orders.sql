DECLARE query_name STRING DEFAULT 'Glosario-250-Stacked 3 or more orders';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 250
-- Nombre:     Stacked 3 or more orders
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-bi-tools-pro.il_logistics.fact_logistic_orders`
-- Tipo:       Dato Directo
-- Fórmula:    COUNT(DISTINCT CASE WHEN stacked_deliveries >= 3 THEN delivery_id END)
-- Definición: Pedidos entregados dentro de circuitos de alta densidad logística con 4 o más pedidos agrupados.
-- ====================================================================================

SELECT
  country_code AS country,
  DATE_TRUNC(DATE(created_date), MONTH) AS month,
  COUNT(DISTINCT CASE WHEN UPPER(del.delivery_status) = 'COMPLETED' AND del.stacked_deliveries >= 3 THEN del.delivery_id END) AS logistics_stacked_3_mas
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
-- +---------+-------------------------+-------+
-- | country | logistics_stacked_3_mas | month |
-- +---------+-------------------------+-------+
-- | ar      |                  32.027 | 2.026 |
-- | bo      |                     292 | 2.026 |
-- | cl      |                  47.167 | 2.026 |
-- | cr      |                       4 | 2.026 |
-- | do      |                     138 | 2.026 |
-- | ec      |                   1.779 | 2.026 |
-- | gt      |                   1.887 | 2.026 |
-- | hn      |                   1.413 | 2.026 |
-- | ni      |                     141 | 2.026 |
-- | pa      |                     223 | 2.026 |
-- | pe      |                      40 | 2.026 |
-- | py      |                   3.355 | 2.026 |
-- | sv      |                   1.880 | 2.026 |
-- | uy      |                   1.043 | 2.026 |
-- | ve      |                      89 | 2.026 |
-- +---------+-------------------------+-------+
