DECLARE query_name STRING DEFAULT 'Glosario-217-Avg. Delivery Time';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 217
-- Nombre:     Avg. Delivery Time
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-bi-tools-pro.il_logistics.fact_logistic_orders`
-- Tipo:       Ratio Calculado
-- Fórmula:    SUM(actual_delivery_time / 60) / COUNT(DISTINCT peya_order_id)
-- Definición: Tiempo promedio total de entrega en minutos desde la confirmación de la orden hasta la entrega efectiva en el domicilio del cliente.
-- ====================================================================================

SELECT
  country_code AS country,
  DATE_TRUNC(DATE(created_date), MONTH) AS month,
  SAFE_DIVIDE(SUM(timings.actual_delivery_time / 60), NULLIF(COUNT(DISTINCT peya_order_id), 0)) AS avg_delivery_time_min
FROM `peya-bi-tools-pro.il_logistics.fact_logistic_orders`
WHERE DATE(created_date) BETWEEN '2026-09-01' AND '2026-09-30'
  AND UPPER(order_status) = 'COMPLETED'
  AND is_preorder IS FALSE
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +-----------------------+---------+-------+
-- | avg_delivery_time_min | country | month |
-- +-----------------------+---------+-------+
-- |                 25,83 | ar      | 2.026 |
-- |                 28,58 | bo      | 2.026 |
-- |                 30,90 | cl      | 2.026 |
-- |                 32,49 | cr      | 2.026 |
-- |                 26,48 | do      | 2.026 |
-- |                 30,90 | ec      | 2.026 |
-- |                 34,83 | gt      | 2.026 |
-- |                 30,13 | hn      | 2.026 |
-- |                 28,88 | ni      | 2.026 |
-- |                 28,79 | pa      | 2.026 |
-- |                 30,01 | pe      | 2.026 |
-- |                 28,52 | py      | 2.026 |
-- |                 30,76 | sv      | 2.026 |
-- |                 25,35 | uy      | 2.026 |
-- |                 31,01 | ve      | 2.026 |
-- +-----------------------+---------+-------+
