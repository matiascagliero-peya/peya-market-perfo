DECLARE query_name STRING DEFAULT 'Glosario-160-Nielsen Market Share %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 160
-- Nombre:     Nielsen Market Share %
-- Chapter:   Assortment, Pricing & Promo
-- Query bajada en: 5 - Supply Chain / AQS
-- Sheets Name: A. TI - SC Data - Monthly (5 - Supply Chain)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1aCrgEjh6qT5T8ayT2H22r3iNc55nAR1O9vaOCW6pRBs
-- Tablas de origen: `peya-food-and-groceries.automated_tables_reports.base_market_assortment_coverage`
-- Tipo:       Ratio Calculado
-- Fórmula:    SUM(net_sales_peya) / SUM(net_sales_market)
-- Definición: Métrica comercial de surtido/precios: Nielsen Market Share %.
-- ====================================================================================

SELECT
  LOWER(country_code) AS country,
  month,
  SAFE_DIVIDE(
    SUM(net_sales_peya),
    NULLIF(SUM(net_sales_market), 0)
  ) AS nielsen_market_share_pct
FROM `peya-food-and-groceries.automated_tables_reports.base_market_assortment_coverage`
WHERE month = '2026-09-01'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +---------+-------+--------------------------+
-- | country | month | nielsen_market_share_pct |
-- +---------+-------+--------------------------+
-- | ar      | 2.026 |                    3,95% |
-- | cl      | 2.026 |                    0,38% |
-- | do      | 2.026 |                    2,41% |
-- | gt      | 2.026 |                    0,50% |
-- | hn      | 2.026 |                    0,31% |
-- | ni      | 2.026 |                    0,53% |
-- | pa      | 2.026 |                    1,80% |
-- | pe      | 2.026 |                    0,71% |
-- | py      | 2.026 |                    2,22% |
-- | sv      | 2.026 |                   21,48% |
-- | uy      | 2.026 |                    3,96% |
-- +---------+-------+--------------------------+
