DECLARE query_name STRING DEFAULT 'Glosario-219-Item Picking Time';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 219
-- Nombre:     Item Picking Time
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-delivery-and-support.automated_tables_reports.dmarts_timings`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(picking_time_s) / SUM(items)
-- Definición: Tiempo promedio en segundos que demora un operario picker en localizar y recolectar cada unidad de producto en tienda.
-- ====================================================================================

SELECT
  country_code AS country,
  DATE_TRUNC(DATE(created_date), MONTH) AS month,
  SAFE_DIVIDE(SUM(picking_time_s), NULLIF(SUM(items), 0)) AS item_picking_time_seconds
FROM `peya-delivery-and-support.automated_tables_reports.dmarts_timings`
WHERE DATE(created_date) BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +---------+---------------------------+-------+
-- | country | item_picking_time_seconds | month |
-- +---------+---------------------------+-------+
-- | ar      |                     17,15 | 2.026 |
-- | bo      |                     19,12 | 2.026 |
-- | cl      |                     21,19 | 2.026 |
-- | do      |                     15,40 | 2.026 |
-- | ec      |                     15,64 | 2.026 |
-- | gt      |                     12,49 | 2.026 |
-- | hn      |                     23,04 | 2.026 |
-- | ni      |                     20,00 | 2.026 |
-- | pa      |                     22,62 | 2.026 |
-- | pe      |                     13,23 | 2.026 |
-- | py      |                     22,13 | 2.026 |
-- | sv      |                     19,45 | 2.026 |
-- | uy      |                     21,88 | 2.026 |
-- +---------+---------------------------+-------+
