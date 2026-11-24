DECLARE query_name STRING DEFAULT 'Glosario-238-Picking units';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 238
-- Nombre:     Picking units
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Owner:       Juan Pablo Pinori Diaz (juan.pinori@pedidosya.com)
-- Slack Link:  https://deliveryhero.enterprise.slack.com/archives/D093J9QN9CK
-- Tablas de origen: `peya-delivery-and-support.automated_tables_reports.dmarts_productividad`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(picking_units)
-- Definición: Total de unidades físicas recolectadas de estanterías por los operarios pickers durante la preparación de pedidos.
-- ====================================================================================

SELECT
  LOWER(country_name) AS country,
  DATE_TRUNC(date, MONTH) AS month,
  SUM(picking_units) AS picking_units
FROM `peya-delivery-and-support.automated_tables_reports.dmarts_productividad`
WHERE date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +---------+-------+---------------+
-- | country | month | picking_units |
-- +---------+-------+---------------+
-- | ar      | 2.026 | 22.534.869,11 |
-- | bo      | 2.026 |  1.032.879,38 |
-- | cl      | 2.026 |  2.824.859,59 |
-- | do      | 2.026 |  1.007.081,98 |
-- | ec      | 2.026 |    598.488,74 |
-- | gt      | 2.026 |       593.143 |
-- | hn      | 2.026 |       234.762 |
-- | ni      | 2.026 |    345.844,05 |
-- | pa      | 2.026 |    682.223,75 |
-- | pe      | 2.026 |  1.503.812,17 |
-- | py      | 2.026 |    829.480,15 |
-- | sv      | 2.026 |       543.400 |
-- | uy      | 2.026 |  2.284.663,92 |
-- +---------+-------+---------------+
