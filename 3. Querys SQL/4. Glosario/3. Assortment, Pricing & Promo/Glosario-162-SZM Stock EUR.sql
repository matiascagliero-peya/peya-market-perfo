DECLARE query_name STRING DEFAULT 'Glosario-162-SZM Stock EUR';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 162
-- Nombre:     SZM Stock EUR
-- Chapter:   Assortment, Pricing & Promo
-- Query bajada en: 5 - Supply Chain / AQS
-- Sheets Name: A. TI - SC Data - Monthly (5 - Supply Chain)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1aCrgEjh6qT5T8ayT2H22r3iNc55nAR1O9vaOCW6pRBs
-- Tablas de origen: `peya-delivery-and-support.automated_tables_reports.dmarts_clearence_crusader_monitor`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(month_end_stock_value_eur) para Slow Movers y Zero Movers
-- Definición: Métrica comercial de surtido/precios: SZM Stock EUR.
-- ====================================================================================

SELECT
  LOWER(country_code) AS country,
  month,
  SUM(CASE WHEN sku_efficiency != 'Other' THEN month_end_stock_value_eur ELSE 0 END) AS szm_stock_eur
FROM `peya-delivery-and-support.automated_tables_reports.dmarts_clearence_crusader_monitor`
WHERE month = '2026-09-01'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +---------+-------+----------------+
-- | country | month | szm_stock_eur  |
-- +---------+-------+----------------+
-- | ar      | 2.026 | 1.347.353,46 € |
-- | bo      | 2.026 |   142.109,54 € |
-- | cl      | 2.026 | 1.093.275,30 € |
-- | cr      | 2.026 |         0,00 € |
-- | do      | 2.026 |   169.122,51 € |
-- | ec      | 2.026 |   159.855,58 € |
-- | gt      | 2.026 |   139.071,83 € |
-- | hn      | 2.026 |    62.835,13 € |
-- | ni      | 2.026 |    23.722,03 € |
-- | pa      | 2.026 |   298.325,16 € |
-- | pe      | 2.026 |   313.152,13 € |
-- | py      | 2.026 |   119.211,15 € |
-- | sv      | 2.026 |    80.501,12 € |
-- | uy      | 2.026 |   176.609,90 € |
-- +---------+-------+----------------+
