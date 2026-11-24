DECLARE query_name STRING DEFAULT 'Glosario-231-AWT total';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 231
-- Nombre:     AWT total
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-bi-tools-pro.il_logistics.fact_logistic_orders`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(avoidable_wait_time) segundos de espera evitable del rider
-- Definición: Suma total de minutos de espera evitable de repartidores acumulados en las tiendas durante el mes.
-- ====================================================================================

SELECT
  country_code AS country,
  DATE_TRUNC(DATE(created_date_local), MONTH) AS month,
  SUM(timings.avoidable_wait_time) AS awt_total_seconds
FROM `peya-bi-tools-pro.il_logistics.fact_logistic_orders`
WHERE DATE(created_date_local) BETWEEN '2026-09-01' AND '2026-09-30'
  AND order_cancelled != 1
  AND vendor.vertical_type = 'darkstores'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +-------------------+---------+-------+
-- | awt_total_seconds | country | month |
-- +-------------------+---------+-------+
-- |       427.750.215 | ar      | 2.026 |
-- |        20.532.827 | bo      | 2.026 |
-- |        78.882.854 | cl      | 2.026 |
-- |        23.082.436 | do      | 2.026 |
-- |        12.868.607 | ec      | 2.026 |
-- |        11.321.532 | gt      | 2.026 |
-- |         6.623.159 | hn      | 2.026 |
-- |         8.831.887 | ni      | 2.026 |
-- |        19.062.240 | pa      | 2.026 |
-- |        39.107.528 | pe      | 2.026 |
-- |        20.515.863 | py      | 2.026 |
-- |        10.739.011 | sv      | 2.026 |
-- |        45.770.661 | uy      | 2.026 |
-- +-------------------+---------+-------+
