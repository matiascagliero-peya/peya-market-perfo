DECLARE query_name STRING DEFAULT 'Glosario-194-Total orders logistics';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 194
-- Nombre:     Total orders logistics
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-bi-tools-pro.il_logistics.fact_logistic_orders`
-- Tipo:       Dato Directo
-- Fórmula:    COUNT(DISTINCT peya_order_id) en fact_logistic_orders
-- Definición: Total de órdenes gestionadas en la fuente logística (fact_logistic_orders). Utilizado como denominador para ratios logísticos (Vendor Late > 10 min, Order Late > 10 min, AWT, EPT-APT).
-- ====================================================================================

SELECT
  country_code AS country,
  DATE_TRUNC(DATE(created_date_local), MONTH) AS month,
  COUNT(DISTINCT peya_order_id) AS total_orders_logistics
FROM `peya-bi-tools-pro.il_logistics.fact_logistic_orders`
WHERE DATE(created_date_local) BETWEEN '2026-09-01' AND '2026-09-30'
  AND order_cancelled != 1
  AND vendor.vertical_type = 'darkstores'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +---------+-------+------------------------+
-- | country | month | total_orders_logistics |
-- +---------+-------+------------------------+
-- | ar      | 2.026 |              2.637.142 |
-- | bo      | 2.026 |                143.031 |
-- | cl      | 2.026 |                341.588 |
-- | do      | 2.026 |                171.687 |
-- | ec      | 2.026 |                 96.883 |
-- | gt      | 2.026 |                 95.251 |
-- | hn      | 2.026 |                 50.536 |
-- | ni      | 2.026 |                 56.668 |
-- | pa      | 2.026 |                 93.030 |
-- | pe      | 2.026 |                272.594 |
-- | py      | 2.026 |                135.928 |
-- | sv      | 2.026 |                 85.413 |
-- | uy      | 2.026 |                282.486 |
-- +---------+-------+------------------------+
