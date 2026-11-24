DECLARE query_name STRING DEFAULT 'Glosario-220-Item Picking Time Total';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 220
-- Nombre:     Item Picking Time Total
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-delivery-and-support.automated_tables_reports.dmarts_timings`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(picking_time_s) segundos totales de picking
-- Definición: Suma total de segundos dedicados a la recolección física de productos de órdenes en tienda.
-- ====================================================================================

SELECT
  country_code AS country,
  DATE_TRUNC(DATE(created_date), MONTH) AS month,
  SUM(picking_time_s) AS total_picking_time_seconds
FROM `peya-delivery-and-support.automated_tables_reports.dmarts_timings`
WHERE DATE(created_date) BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +---------+-------+----------------------------+
-- | country | month | total_picking_time_seconds |
-- +---------+-------+----------------------------+
-- | ar      | 2.026 |             386.062.054,70 |
-- | bo      | 2.026 |              19.695.655,37 |
-- | cl      | 2.026 |              59.770.423,87 |
-- | do      | 2.026 |              15.521.089,67 |
-- | ec      | 2.026 |               9.346.307,07 |
-- | gt      | 2.026 |               7.410.391,86 |
-- | hn      | 2.026 |               5.408.793,62 |
-- | ni      | 2.026 |               6.912.053,50 |
-- | pa      | 2.026 |              15.413.196,01 |
-- | pe      | 2.026 |              19.878.847,64 |
-- | py      | 2.026 |              18.344.308,38 |
-- | sv      | 2.026 |              10.557.441,24 |
-- | uy      | 2.026 |              50.018.554,65 |
-- +---------+-------+----------------------------+
