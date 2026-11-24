DECLARE query_name STRING DEFAULT 'Glosario-230-Avg. AWT';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 230
-- Nombre:     Avg. AWT
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-bi-tools-pro.il_logistics.fact_logistic_orders`
-- Tipo:       Ratio Calculado
-- Fórmula:    SUM(avoidable_wait_time) / Total Orders Logistics
-- Definición: Tiempo promedio de espera evitable del repartidor en tienda (Avoidable Wait Time) en minutos hasta que el pedido está listo para retiro.
-- ====================================================================================

SELECT
  country_code AS country,
  DATE_TRUNC(DATE(created_date_local), MONTH) AS month,
  SAFE_DIVIDE(SUM(timings.avoidable_wait_time), NULLIF(COUNT(DISTINCT peya_order_id), 0)) AS avg_awt_seconds
FROM `peya-bi-tools-pro.il_logistics.fact_logistic_orders`
WHERE DATE(created_date_local) BETWEEN '2026-09-01' AND '2026-09-30'
  AND order_cancelled != 1
  AND vendor.vertical_type = 'darkstores'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +-----------------+---------+-------+
-- | avg_awt_seconds | country | month |
-- +-----------------+---------+-------+
-- |          162,20 | ar      | 2.026 |
-- |          143,56 | bo      | 2.026 |
-- |          230,93 | cl      | 2.026 |
-- |          134,44 | do      | 2.026 |
-- |          132,83 | ec      | 2.026 |
-- |          118,86 | gt      | 2.026 |
-- |          131,06 | hn      | 2.026 |
-- |          155,85 | ni      | 2.026 |
-- |          204,90 | pa      | 2.026 |
-- |          143,46 | pe      | 2.026 |
-- |          150,93 | py      | 2.026 |
-- |          125,73 | sv      | 2.026 |
-- |          162,03 | uy      | 2.026 |
-- +-----------------+---------+-------+
