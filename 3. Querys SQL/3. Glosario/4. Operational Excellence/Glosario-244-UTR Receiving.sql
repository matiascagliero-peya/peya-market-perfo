DECLARE query_name STRING DEFAULT 'Glosario-244-UTR Receiving';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 244
-- Nombre:     UTR Receiving
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Owner:       Juan Pablo Pinori Diaz (juan.pinori@pedidosya.com)
-- Slack Link:  https://deliveryhero.enterprise.slack.com/archives/D093J9QN9CK
-- Tablas de origen: `peya-delivery-and-support.automated_tables_reports.dmarts_productividad`
-- Tipo:       Ratio Calculado
-- Fórmula:    (Receiving units - Received bags) / Picker working hours
-- Definición: Productividad en recepción de mercadería neta de bolsas por hora de picker.
-- ====================================================================================

SELECT
  LOWER(country_name) AS country,
  DATE_TRUNC(date, MONTH) AS month,
  SUM(receiving_units) AS receiving_units,
  SUM(received_bags) AS received_bags,
  SUM(picker_working_hours) AS picker_working_hours,
  SAFE_DIVIDE(
    SUM(receiving_units) - SUM(received_bags),
    NULLIF(SUM(picker_working_hours), 0)
  ) AS utr_receiving
FROM `peya-delivery-and-support.automated_tables_reports.dmarts_productividad`
WHERE date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +---------+-------+----------------------+---------------+-----------------+---------------+
-- | country | month | picker_working_hours | received_bags | receiving_units | utr_receiving |
-- +---------+-------+----------------------+---------------+-----------------+---------------+
-- | ar      | 2.026 |           477.353,01 |     2.890.519 |   25.823.413,12 |         48,04 |
-- | bo      | 2.026 |            21.344,06 |        89.380 |    1.244.468,22 |         54,12 |
-- | cl      | 2.026 |            68.295,61 |       891.080 |    3.731.576,26 |         41,59 |
-- | do      | 2.026 |            21.384,89 |       534.800 |    1.617.806,90 |         50,64 |
-- | ec      | 2.026 |            11.399,10 |       212.098 |      832.208,95 |         54,40 |
-- | gt      | 2.026 |            16.056,06 |       499.000 |       1.137.977 |         39,80 |
-- | hn      | 2.026 |             5.160,83 |       153.000 |         428.964 |         53,47 |
-- | ni      | 2.026 |             8.677,28 |             0 |      378.425,80 |         43,61 |
-- | pa      | 2.026 |            16.565,88 |       125.400 |      842.684,70 |         43,30 |
-- | pe      | 2.026 |            33.209,92 |       475.940 |    2.071.726,53 |         48,05 |
-- | py      | 2.026 |            18.182,20 |       143.590 |      979.958,53 |         46,00 |
-- | sv      | 2.026 |            13.326,36 |        40.500 |         606.748 |         42,49 |
-- | uy      | 2.026 |            50.433,32 |       636.542 |    2.974.476,51 |         46,36 |
-- +---------+-------+----------------------+---------------+-----------------+---------------+
