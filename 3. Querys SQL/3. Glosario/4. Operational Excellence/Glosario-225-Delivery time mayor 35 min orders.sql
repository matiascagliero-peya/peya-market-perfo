DECLARE query_name STRING DEFAULT 'Glosario-225-Delivery time > 35 min orders';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 225
-- Nombre:     Delivery time > 35 min orders
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-delivery-and-support.automated_tables_reports.dmarts_timings`
-- Tipo:       Dato Directo
-- Fórmula:    COUNTIF(actual_dt_min > 35)
-- Definición: Cantidad total de pedidos con tiempos de entrega excesivamente prolongados (> 35 minutos).
-- ====================================================================================

SELECT
  country_code AS country,
  DATE_TRUNC(DATE(created_date), MONTH) AS month,
  COUNTIF(actual_dt_min > 35) AS dt_over_35min_orders
FROM `peya-delivery-and-support.automated_tables_reports.dmarts_timings`
WHERE DATE(created_date) BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +---------+----------------------+-------+
-- | country | dt_over_35min_orders | month |
-- +---------+----------------------+-------+
-- | ar      |              626.735 | 2.026 |
-- | bo      |               41.113 | 2.026 |
-- | cl      |               88.455 | 2.026 |
-- | do      |               24.026 | 2.026 |
-- | ec      |               25.137 | 2.026 |
-- | gt      |               34.767 | 2.026 |
-- | hn      |               14.824 | 2.026 |
-- | ni      |               20.101 | 2.026 |
-- | pa      |               12.351 | 2.026 |
-- | pe      |               34.732 | 2.026 |
-- | py      |               40.822 | 2.026 |
-- | sv      |               27.656 | 2.026 |
-- | uy      |               75.400 | 2.026 |
-- +---------+----------------------+-------+
