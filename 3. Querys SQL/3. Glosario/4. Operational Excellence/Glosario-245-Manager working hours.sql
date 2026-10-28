DECLARE query_name STRING DEFAULT 'Glosario-245-Manager working hours';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 245
-- Nombre:     Manager working hours
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Owner:       Juan Pablo Pinori Diaz (juan.pinori@pedidosya.com)
-- Slack Link:  https://deliveryhero.enterprise.slack.com/archives/D093J9QN9CK
-- Tablas de origen: `peya-delivery-and-support.automated_tables_reports.dmarts_productividad`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(manager_working_hours) horas de store managers
-- Definición: Horas de trabajo dedicadas por supervisores y Store Managers a la administración, auditoría y control de tienda.
-- ====================================================================================

SELECT
  LOWER(country_name) AS country,
  DATE_TRUNC(date, MONTH) AS month,
  SUM(manager_working_hours) AS manager_working_hours
FROM `peya-delivery-and-support.automated_tables_reports.dmarts_productividad`
WHERE date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +---------+-----------------------+-------+
-- | country | manager_working_hours | month |
-- +---------+-----------------------+-------+
-- | ar      |             19.706,78 | 2.026 |
-- | bo      |                606,97 | 2.026 |
-- | cl      |              3.453,82 | 2.026 |
-- | do      |                577,39 | 2.026 |
-- | ec      |                256,52 | 2.026 |
-- | gt      |                548,89 | 2.026 |
-- | hn      |                 82,14 | 2.026 |
-- | ni      | -                     | 2.026 |
-- | pa      |                225,11 | 2.026 |
-- | pe      |                681,10 | 2.026 |
-- | py      | -                     | 2.026 |
-- | sv      |                486,89 | 2.026 |
-- | uy      |              1.524,05 | 2.026 |
-- +---------+-----------------------+-------+
