DECLARE query_name STRING DEFAULT 'Glosario-221-Picked_items';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 221
-- Nombre:     Picked_items
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-delivery-and-support.automated_tables_reports.dmarts_timings`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(items) artículos recolectados
-- Definición: Cantidad total absoluta de unidades y artículos recolectados por el equipo de pickers en tienda.
-- ====================================================================================

SELECT
  country_code AS country,
  DATE_TRUNC(DATE(created_date), MONTH) AS month,
  SUM(items) AS picked_items
FROM `peya-delivery-and-support.automated_tables_reports.dmarts_timings`
WHERE DATE(created_date) BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +---------+-------+---------------+
-- | country | month | picked_items  |
-- +---------+-------+---------------+
-- | ar      | 2.026 | 22.513.419,25 |
-- | bo      | 2.026 |  1.030.270,72 |
-- | cl      | 2.026 |  2.820.679,91 |
-- | do      | 2.026 |  1.007.951,69 |
-- | ec      | 2.026 |    597.731,74 |
-- | gt      | 2.026 |       593.488 |
-- | hn      | 2.026 |       234.747 |
-- | ni      | 2.026 |    345.610,05 |
-- | pa      | 2.026 |    681.533,75 |
-- | pe      | 2.026 |  1.502.744,38 |
-- | py      | 2.026 |    828.841,33 |
-- | sv      | 2.026 |       542.889 |
-- | uy      | 2.026 |  2.285.833,17 |
-- +---------+-------+---------------+
