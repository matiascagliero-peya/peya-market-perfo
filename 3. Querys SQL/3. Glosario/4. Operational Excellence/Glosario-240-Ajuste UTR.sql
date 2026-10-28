DECLARE query_name STRING DEFAULT 'Glosario-240-Ajuste UTR';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 240
-- Nombre:     Ajuste UTR
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Owner:       Juan Pablo Pinori Diaz (juan.pinori@pedidosya.com)
-- Slack Link:  https://deliveryhero.enterprise.slack.com/archives/D093J9QN9CK
-- Tablas de origen: `peya-delivery-and-support.automated_tables_reports.dmarts_productividad`
-- Tipo:       Ratio Calculado
-- Fórmula:    SUM(ajuste) unidades de ajuste inventario/UTR
-- Definición: Unidades de ajuste aplicadas al indicador de productividad operativa para reflejar mermas, inventarios cíclicos o correcciones.
-- ====================================================================================

SELECT
  LOWER(country_name) AS country,
  DATE_TRUNC(date, MONTH) AS month,
  SUM(ajuste) AS ajuste_utr
FROM `peya-delivery-and-support.automated_tables_reports.dmarts_productividad`
WHERE date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +------------+---------+-------+
-- | ajuste_utr | country | month |
-- +------------+---------+-------+
-- | 642.023,52 | ar      | 2.026 |
-- |        -49 | bo      | 2.026 |
-- |  20.449,26 | cl      | 2.026 |
-- |      5.131 | do      | 2.026 |
-- |          3 | ec      | 2.026 |
-- |       -219 | gt      | 2.026 |
-- | -          | hn      | 2.026 |
-- |         -1 | ni      | 2.026 |
-- |        -17 | pa      | 2.026 |
-- |   5.986,47 | pe      | 2.026 |
-- |         35 | py      | 2.026 |
-- |        -25 | sv      | 2.026 |
-- |   8.515,36 | uy      | 2.026 |
-- +------------+---------+-------+
