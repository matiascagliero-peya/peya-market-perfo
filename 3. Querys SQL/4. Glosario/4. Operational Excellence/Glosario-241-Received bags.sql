DECLARE query_name STRING DEFAULT 'Glosario-241-Received bags';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 241
-- Nombre:     Received bags
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Owner:       Juan Pablo Pinori Diaz (juan.pinori@pedidosya.com)
-- Slack Link:  https://deliveryhero.enterprise.slack.com/archives/D093J9QN9CK
-- Tablas de origen: `peya-delivery-and-support.automated_tables_reports.dmarts_productividad`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(received_bags) bolsas recibidas
-- Definición: Cantidad total de bultos y bolsas consolidadas recibidas en tienda en los envíos de reposición de centros de distribución.
-- ====================================================================================

SELECT
  LOWER(country_name) AS country,
  DATE_TRUNC(date, MONTH) AS month,
  SUM(received_bags) AS received_bags
FROM `peya-delivery-and-support.automated_tables_reports.dmarts_productividad`
WHERE date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +---------+-------+---------------+
-- | country | month | received_bags |
-- +---------+-------+---------------+
-- | ar      | 2.026 |     2.890.519 |
-- | bo      | 2.026 |        89.380 |
-- | cl      | 2.026 |       891.080 |
-- | do      | 2.026 |       534.800 |
-- | ec      | 2.026 |       212.098 |
-- | gt      | 2.026 |       499.000 |
-- | hn      | 2.026 |       153.000 |
-- | ni      | 2.026 |             0 |
-- | pa      | 2.026 |       125.400 |
-- | pe      | 2.026 |       475.940 |
-- | py      | 2.026 |       143.590 |
-- | sv      | 2.026 |        40.500 |
-- | uy      | 2.026 |       636.542 |
-- +---------+-------+---------------+
