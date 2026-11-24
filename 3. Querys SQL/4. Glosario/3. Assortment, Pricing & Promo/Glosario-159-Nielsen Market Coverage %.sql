DECLARE query_name STRING DEFAULT 'Glosario-159-Nielsen Market Coverage %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 159
-- Nombre:     Nielsen Market Coverage %
-- Chapter:   Assortment, Pricing & Promo
-- Query bajada en: 5 - Supply Chain / AQS
-- Sheets Name: A. TI - SC Data - Monthly (5 - Supply Chain)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1aCrgEjh6qT5T8ayT2H22r3iNc55nAR1O9vaOCW6pRBs
-- Tablas de origen: `peya-food-and-groceries.automated_tables_reports.base_market_assortment_coverage`
-- Tipo:       Ratio Calculado
-- Fórmula:    SUM(IF(activos_con_stock = 1, net_sales_market, 0)) / SUM(net_sales_market)
-- Definición: Métrica comercial de surtido/precios: Nielsen Market Coverage %.
-- ====================================================================================

SELECT
  LOWER(country_code) AS country,
  month,
  SAFE_DIVIDE(
    SUM(IF(activos_por_tienda_con_stock = 1, net_sales_market, 0)),
    NULLIF(SUM(net_sales_market), 0)
  ) AS nielsen_market_coverage_pct
FROM `peya-food-and-groceries.automated_tables_reports.base_market_assortment_coverage`
WHERE month = '2026-09-01'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +---------+-------+-----------------------------+
-- | country | month | nielsen_market_coverage_pct |
-- +---------+-------+-----------------------------+
-- | ar      | 2.026 |                      73,53% |
-- | cl      | 2.026 |                      57,74% |
-- | do      | 2.026 |                      61,23% |
-- | gt      | 2.026 |                      48,87% |
-- | hn      | 2.026 |                      49,42% |
-- | ni      | 2.026 |                      61,41% |
-- | pa      | 2.026 |                      52,88% |
-- | pe      | 2.026 |                      59,96% |
-- | py      | 2.026 |                      61,70% |
-- | sv      | 2.026 |                      74,82% |
-- | uy      | 2.026 |                      67,03% |
-- +---------+-------+-----------------------------+
