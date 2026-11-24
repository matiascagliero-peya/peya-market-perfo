DECLARE query_name STRING DEFAULT 'Glosario-228-Vendor Late > 10 min %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 228
-- Nombre:     Vendor Late > 10 min %
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-bi-tools-pro.il_logistics.fact_logistic_orders`
-- Tipo:       Ratio Calculado
-- Fórmula:    SUM(is_vendor_late_10) / Total Orders Logistics
-- Definición: Porcentaje de pedidos donde la tienda demoró más de 10 minutos adicionales en entregar el paquete al repartidor respecto a lo pautado.
-- ====================================================================================

SELECT
  country_code AS country,
  DATE_TRUNC(DATE(created_date_local), MONTH) AS month,
  SUM(is_vendor_late_10) AS vendor_late_10_count,
  COUNT(DISTINCT peya_order_id) AS total_orders,
  SAFE_DIVIDE(SUM(is_vendor_late_10), NULLIF(COUNT(DISTINCT peya_order_id), 0)) AS vendor_late_10_pct
FROM `peya-bi-tools-pro.il_logistics.fact_logistic_orders`
WHERE DATE(created_date_local) BETWEEN '2026-09-01' AND '2026-09-30'
  AND order_cancelled != 1
  AND vendor.vertical_type = 'darkstores'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +---------+-------+--------------+----------------------+--------------------+
-- | country | month | total_orders | vendor_late_10_count | vendor_late_10_pct |
-- +---------+-------+--------------+----------------------+--------------------+
-- | ar      | 2.026 |    2.637.142 |              321.581 |             12,19% |
-- | bo      | 2.026 |      143.031 |               24.427 |             17,08% |
-- | cl      | 2.026 |      341.588 |               67.826 |             19,86% |
-- | do      | 2.026 |      171.687 |               18.599 |             10,83% |
-- | ec      | 2.026 |       96.883 |               11.754 |             12,13% |
-- | gt      | 2.026 |       95.251 |               10.445 |             10,97% |
-- | hn      | 2.026 |       50.536 |                5.209 |             10,31% |
-- | ni      | 2.026 |       56.668 |                8.101 |             14,30% |
-- | pa      | 2.026 |       93.030 |               12.997 |             13,97% |
-- | pe      | 2.026 |      272.594 |               24.437 |              8,96% |
-- | py      | 2.026 |      135.928 |               20.374 |             14,99% |
-- | sv      | 2.026 |       85.413 |               10.517 |             12,31% |
-- | uy      | 2.026 |      282.486 |               34.712 |             12,29% |
-- +---------+-------+--------------+----------------------+--------------------+
