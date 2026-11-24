DECLARE query_name STRING DEFAULT 'Glosario-218-Delivery Time total';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 218
-- Nombre:     Delivery Time total
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-bi-tools-pro.il_logistics.fact_logistic_orders`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(actual_delivery_time / 60)
-- Definición: Suma acumulada de minutos de entrega de todos los pedidos completados durante el mes.
-- ====================================================================================

SELECT
  country_code AS country,
  DATE_TRUNC(DATE(created_date), MONTH) AS month,
  SUM(timings.actual_delivery_time / 60) AS sum_delivery_time_min
FROM `peya-bi-tools-pro.il_logistics.fact_logistic_orders`
WHERE DATE(created_date) BETWEEN '2026-09-01' AND '2026-09-30'
  AND UPPER(order_status) = 'COMPLETED'
  AND is_preorder IS FALSE
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +---------+-------+-----------------------+
-- | country | month | sum_delivery_time_min |
-- +---------+-------+-----------------------+
-- | ar      | 2.026 |        349.188.276,45 |
-- | bo      | 2.026 |         43.342.929,58 |
-- | cl      | 2.026 |        103.183.973,40 |
-- | cr      | 2.026 |          8.396.052,40 |
-- | do      | 2.026 |         51.301.933,97 |
-- | ec      | 2.026 |         48.282.950,07 |
-- | gt      | 2.026 |         49.045.280,92 |
-- | hn      | 2.026 |         38.246.185,40 |
-- | ni      | 2.026 |         27.299.269,48 |
-- | pa      | 2.026 |         42.333.650,18 |
-- | pe      | 2.026 |         92.934.557,87 |
-- | py      | 2.026 |         29.018.111,38 |
-- | sv      | 2.026 |         46.261.307,00 |
-- | uy      | 2.026 |         42.026.312,50 |
-- | ve      | 2.026 |          7.100.506,48 |
-- +---------+-------+-----------------------+
