DECLARE query_name STRING DEFAULT 'Glosario-242-Picker working hours';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 242
-- Nombre:     Picker working hours
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Owner:       Juan Pablo Pinori Diaz (juan.pinori@pedidosya.com)
-- Slack Link:  https://deliveryhero.enterprise.slack.com/archives/D093J9QN9CK
-- Tablas de origen: `peya-delivery-and-support.automated_tables_reports.dmarts_productividad`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(picker_working_hours) horas operativas de pickers
-- Definición: Horas de trabajo efectivas registradas por el personal de tienda dedicado a las tareas de preparación y recolección de pedidos.
-- ====================================================================================

SELECT
  LOWER(country_name) AS country,
  DATE_TRUNC(date, MONTH) AS month,
  SUM(picker_working_hours) AS picker_working_hours
FROM `peya-delivery-and-support.automated_tables_reports.dmarts_productividad`
WHERE date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +---------+-------+----------------------+
-- | country | month | picker_working_hours |
-- +---------+-------+----------------------+
-- | ar      | 2.026 |           477.353,01 |
-- | bo      | 2.026 |            21.344,06 |
-- | cl      | 2.026 |            68.295,61 |
-- | do      | 2.026 |            21.384,89 |
-- | ec      | 2.026 |            11.399,10 |
-- | gt      | 2.026 |            16.056,06 |
-- | hn      | 2.026 |             5.160,83 |
-- | ni      | 2.026 |             8.677,28 |
-- | pa      | 2.026 |            16.565,88 |
-- | pe      | 2.026 |            33.209,92 |
-- | py      | 2.026 |            18.182,20 |
-- | sv      | 2.026 |            13.326,36 |
-- | uy      | 2.026 |            50.433,32 |
-- +---------+-------+----------------------+
