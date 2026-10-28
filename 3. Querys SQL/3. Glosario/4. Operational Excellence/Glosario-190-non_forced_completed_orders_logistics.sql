DECLARE query_name STRING DEFAULT 'Glosario-190-non_forced_completed_orders_logistics';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 190
-- Nombre:     non_forced_completed_orders_logistics
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-bi-tools-pro.il_logistics.fact_logistic_orders`
-- Tipo:       Dato Directo
-- Fórmula:    COUNT(DISTINCT peya_order_id) WHERE order_status = "COMPLETED" AND is_preorder IS FALSE
-- Definición: Total de órdenes logísticas completadas de forma regular, excluyendo pre-órdenes forzadas y cancelaciones.
-- ====================================================================================

SELECT
  country_code AS country,
  DATE_TRUNC(DATE(created_date), MONTH) AS month,
  COUNT(DISTINCT peya_order_id) AS non_forced_completed_orders_logistics
FROM `peya-bi-tools-pro.il_logistics.fact_logistic_orders`
WHERE DATE(created_date) BETWEEN '2026-09-01' AND '2026-09-30'
  AND UPPER(order_status) = 'COMPLETED'
  AND is_preorder IS FALSE
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +---------+-------+---------------------------------------+
-- | country | month | non_forced_completed_orders_logistics |
-- +---------+-------+---------------------------------------+
-- | ar      | 2.026 |                            13.516.893 |
-- | bo      | 2.026 |                             1.516.674 |
-- | cl      | 2.026 |                             3.339.046 |
-- | cr      | 2.026 |                               258.404 |
-- | do      | 2.026 |                             1.937.552 |
-- | ec      | 2.026 |                             1.562.310 |
-- | gt      | 2.026 |                             1.408.136 |
-- | hn      | 2.026 |                             1.269.246 |
-- | ni      | 2.026 |                               945.396 |
-- | pa      | 2.026 |                             1.470.307 |
-- | pe      | 2.026 |                             3.097.239 |
-- | py      | 2.026 |                             1.017.579 |
-- | sv      | 2.026 |                             1.503.856 |
-- | uy      | 2.026 |                             1.657.864 |
-- | ve      | 2.026 |                               228.948 |
-- +---------+-------+---------------------------------------+
