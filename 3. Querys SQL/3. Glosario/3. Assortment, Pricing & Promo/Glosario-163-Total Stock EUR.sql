DECLARE query_name STRING DEFAULT 'Glosario-163-Total Stock EUR';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 163
-- Nombre:     Total Stock EUR
-- Chapter:   Assortment, Pricing & Promo
-- Query bajada en: 5 - Supply Chain / AQS
-- Sheets Name: A. TI - SC Data - Monthly (5 - Supply Chain)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1aCrgEjh6qT5T8ayT2H22r3iNc55nAR1O9vaOCW6pRBs
-- Tablas de origen: `peya-delivery-and-support.automated_tables_reports.dmarts_clearence_crusader_monitor`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(month_end_stock_value_eur) en inventario total
-- Definición: Métrica comercial de surtido/precios: Total Stock EUR.
-- ====================================================================================

SELECT
  LOWER(country_code) AS country,
  month,
  SUM(month_end_stock_value_eur) AS total_stock_eur
FROM `peya-delivery-and-support.automated_tables_reports.dmarts_clearence_crusader_monitor`
WHERE month = '2026-09-01'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +---------+-------+-----------------+
-- | country | month | total_stock_eur |
-- +---------+-------+-----------------+
-- | ar      | 2.026 | 31.766.176,81 € |
-- | bo      | 2.026 |    668.280,94 € |
-- | cl      | 2.026 |  3.521.078,76 € |
-- | cr      | 2.026 |        856,43 € |
-- | do      | 2.026 |    956.536,13 € |
-- | ec      | 2.026 |    728.147,91 € |
-- | gt      | 2.026 |    648.529,69 € |
-- | hn      | 2.026 |    256.352,96 € |
-- | ni      | 2.026 |    160.260,09 € |
-- | pa      | 2.026 |  1.019.134,33 € |
-- | pe      | 2.026 |  2.129.096,50 € |
-- | py      | 2.026 |    506.014,22 € |
-- | sv      | 2.026 |    478.310,82 € |
-- | uy      | 2.026 |  2.822.523,92 € |
-- +---------+-------+-----------------+
