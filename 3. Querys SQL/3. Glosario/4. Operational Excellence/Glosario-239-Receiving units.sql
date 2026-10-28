DECLARE query_name STRING DEFAULT 'Glosario-239-Receiving units';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 239
-- Nombre:     Receiving units
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Owner:       Juan Pablo Pinori Diaz (juan.pinori@pedidosya.com)
-- Slack Link:  https://deliveryhero.enterprise.slack.com/archives/D093J9QN9CK
-- Tablas de origen: `peya-delivery-and-support.automated_tables_reports.dmarts_productividad`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(receiving_units)
-- Definición: Total de unidades físicas ingresadas, controladas y ubicadas en almacén durante los procesos de abastecimiento de proveedores.
-- ====================================================================================

SELECT
  LOWER(country_name) AS country,
  DATE_TRUNC(date, MONTH) AS month,
  SUM(receiving_units) AS receiving_units
FROM `peya-delivery-and-support.automated_tables_reports.dmarts_productividad`
WHERE date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +---------+-------+-----------------+
-- | country | month | receiving_units |
-- +---------+-------+-----------------+
-- | ar      | 2.026 |   25.823.413,12 |
-- | bo      | 2.026 |    1.244.468,22 |
-- | cl      | 2.026 |    3.731.576,26 |
-- | do      | 2.026 |    1.617.806,90 |
-- | ec      | 2.026 |      832.208,95 |
-- | gt      | 2.026 |       1.137.977 |
-- | hn      | 2.026 |         428.964 |
-- | ni      | 2.026 |      378.425,80 |
-- | pa      | 2.026 |      842.684,70 |
-- | pe      | 2.026 |    2.071.726,53 |
-- | py      | 2.026 |      979.958,53 |
-- | sv      | 2.026 |         606.748 |
-- | uy      | 2.026 |    2.974.476,51 |
-- +---------+-------+-----------------+
