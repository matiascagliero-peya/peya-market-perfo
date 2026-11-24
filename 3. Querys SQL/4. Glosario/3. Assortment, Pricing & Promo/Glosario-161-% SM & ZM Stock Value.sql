DECLARE query_name STRING DEFAULT 'Glosario-161-% SM & ZM Stock Value';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 161
-- Nombre:     % SM & ZM Stock Value
-- Chapter:   Assortment, Pricing & Promo
-- Query bajada en: 5 - Supply Chain / AQS
-- Sheets Name: A. TI - SC Data - Monthly (5 - Supply Chain)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1aCrgEjh6qT5T8ayT2H22r3iNc55nAR1O9vaOCW6pRBs
-- Tablas de origen: `peya-delivery-and-support.automated_tables_reports.dmarts_clearence_crusader_monitor`
-- Tipo:       Ratio Calculado
-- Fórmula:    SUM(szm_stock_value_eur) / SUM(total_stock_value_eur)
-- Definición: Métrica comercial de surtido/precios: % SM & ZM Stock Value.
-- ====================================================================================

SELECT
  LOWER(country_code) AS country,
  month,
  SAFE_DIVIDE(
    SUM(CASE WHEN sku_efficiency != 'Other' THEN month_end_stock_value_eur ELSE 0 END),
    NULLIF(SUM(month_end_stock_value_eur), 0)
  ) AS perc_sm_and_zm_stock_value
FROM `peya-delivery-and-support.automated_tables_reports.dmarts_clearence_crusader_monitor`
WHERE month = '2026-09-01'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +---------+-------+----------------------------+
-- | country | month | perc_sm_and_zm_stock_value |
-- +---------+-------+----------------------------+
-- | ar      | 2.026 |                       0,04 |
-- | bo      | 2.026 |                       0,21 |
-- | cl      | 2.026 |                       0,31 |
-- | cr      | 2.026 |                          0 |
-- | do      | 2.026 |                       0,18 |
-- | ec      | 2.026 |                       0,22 |
-- | gt      | 2.026 |                       0,21 |
-- | hn      | 2.026 |                       0,25 |
-- | ni      | 2.026 |                       0,15 |
-- | pa      | 2.026 |                       0,29 |
-- | pe      | 2.026 |                       0,15 |
-- | py      | 2.026 |                       0,24 |
-- | sv      | 2.026 |                       0,17 |
-- | uy      | 2.026 |                       0,06 |
-- +---------+-------+----------------------------+
