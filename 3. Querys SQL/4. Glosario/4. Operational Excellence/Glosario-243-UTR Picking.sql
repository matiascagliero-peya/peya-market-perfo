DECLARE query_name STRING DEFAULT 'Glosario-243-UTR Picking';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 243
-- Nombre:     UTR Picking
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Owner:       Juan Pablo Pinori Diaz (juan.pinori@pedidosya.com)
-- Slack Link:  https://deliveryhero.enterprise.slack.com/archives/D093J9QN9CK
-- Tablas de origen: `peya-delivery-and-support.automated_tables_reports.dmarts_productividad`
-- Tipo:       Ratio Calculado
-- Fórmula:    SUM(picking_units) / SUM(picker_working_hours)
-- Definición: Productividad horaria de recolección: cantidad de unidades recolectadas por cada hora de trabajo de picker (Picking Units / Working Hours).
-- ====================================================================================

SELECT
  LOWER(country_name) AS country,
  DATE_TRUNC(date, MONTH) AS month,
  SAFE_DIVIDE(SUM(picking_units), NULLIF(SUM(picker_working_hours), 0)) AS utr_picking
FROM `peya-delivery-and-support.automated_tables_reports.dmarts_productividad`
WHERE date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +---------+-------+-------------+
-- | country | month | utr_picking |
-- +---------+-------+-------------+
-- | ar      | 2.026 |       47,21 |
-- | bo      | 2.026 |       48,39 |
-- | cl      | 2.026 |       41,36 |
-- | do      | 2.026 |       47,09 |
-- | ec      | 2.026 |       52,50 |
-- | gt      | 2.026 |       36,94 |
-- | hn      | 2.026 |       45,49 |
-- | ni      | 2.026 |       39,86 |
-- | pa      | 2.026 |       41,18 |
-- | pe      | 2.026 |       45,28 |
-- | py      | 2.026 |       45,62 |
-- | sv      | 2.026 |       40,78 |
-- | uy      | 2.026 |       45,30 |
-- +---------+-------+-------------+
