DECLARE query_name STRING DEFAULT 'Glosario-224-Delivery time > 35 min %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 224
-- Nombre:     Delivery time > 35 min %
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-delivery-and-support.automated_tables_reports.dmarts_timings`
-- Tipo:       Ratio Calculado
-- Fórmula:    COUNTIF(actual_dt_min > 35) / Total Orders Timings
-- Definición: Porcentaje de pedidos cuyo tiempo total de entrega demoró más de 35 minutos desde su confirmación.
-- ====================================================================================

SELECT
  country_code AS country,
  DATE_TRUNC(DATE(created_date), MONTH) AS month,
  COUNTIF(actual_dt_min > 35) AS dt_over_35min_orders,
  COUNT(DISTINCT order_id) AS total_orders,
  SAFE_DIVIDE(COUNTIF(actual_dt_min > 35), NULLIF(COUNT(DISTINCT order_id), 0)) AS dt_over_35min_pct
FROM `peya-delivery-and-support.automated_tables_reports.dmarts_timings`
WHERE DATE(created_date) BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +---------+----------------------+-------------------+-------+--------------+
-- | country | dt_over_35min_orders | dt_over_35min_pct | month | total_orders |
-- +---------+----------------------+-------------------+-------+--------------+
-- | ar      |              626.735 |            23,68% | 2.026 |    2.647.093 |
-- | bo      |               41.113 |            28,87% | 2.026 |      142.396 |
-- | cl      |               88.455 |            25,91% | 2.026 |      341.336 |
-- | do      |               24.026 |            14,02% | 2.026 |      171.341 |
-- | ec      |               25.137 |            25,88% | 2.026 |       97.133 |
-- | gt      |               34.767 |            36,33% | 2.026 |       95.703 |
-- | hn      |               14.824 |            29,23% | 2.026 |       50.713 |
-- | ni      |               20.101 |            35,64% | 2.026 |       56.402 |
-- | pa      |               12.351 |            13,31% | 2.026 |       92.784 |
-- | pe      |               34.732 |            12,72% | 2.026 |      273.037 |
-- | py      |               40.822 |            30,11% | 2.026 |      135.574 |
-- | sv      |               27.656 |            32,08% | 2.026 |       86.216 |
-- | uy      |               75.400 |            26,28% | 2.026 |      286.923 |
-- +---------+----------------------+-------------------+-------+--------------+
