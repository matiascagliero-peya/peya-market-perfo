DECLARE query_name STRING DEFAULT 'Glosario-172-Promo Attractiveness';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 172
-- Nombre:     Promo Attractiveness
-- Chapter:   Assortment, Pricing & Promo
-- Query bajada en: 5 - Supply Chain / AQS
-- Sheets Name: A. TI - SC Data - Monthly (5 - Supply Chain)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1aCrgEjh6qT5T8ayT2H22r3iNc55nAR1O9vaOCW6pRBs
-- Tablas de origen: `fulfillment-dwh-production.curated_data_shared_dmart.tableau_promo_quality_score_v3`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(w_promo_attractiveness) / SUM(dd_gpv_eur)
-- Definición: Métrica comercial de surtido/precios: Promo Attractiveness.
-- ====================================================================================

SELECT
  country_name AS country,
  date_month AS month,
  SAFE_DIVIDE(SUM(w_promo_attractiveness), NULLIF(SUM(dd_gpv_eur), 0)) AS promo_attractiveness
FROM `fulfillment-dwh-production.curated_data_shared_dmart.tableau_promo_quality_score_v3`
WHERE date_month = '2026-09-01'
  AND management_entity_grouped = 'Pedidosya'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------+----------------------+
-- | country              | month | promo_attractiveness |
-- +----------------------+-------+----------------------+
-- | Argentina            | 2.026 |                 0,52 |
-- | Bolivia              | 2.026 |                 0,65 |
-- | Chile                | 2.026 |                 0,61 |
-- | República Dominicana | 2.026 |                 0,83 |
-- | Ecuador              | 2.026 |                 0,69 |
-- | El Salvador          | 2.026 |                 0,76 |
-- | Guatemala            | 2.026 |                 0,77 |
-- | Honduras             | 2.026 |                 0,84 |
-- | Nicaragua            | 2.026 |                 0,73 |
-- | Panamá               | 2.026 |                 0,65 |
-- | Paraguay             | 2.026 |                 0,58 |
-- | Perú                 | 2.026 |                 0,78 |
-- | Uruguay              | 2.026 |                 0,58 |
-- +----------------------+-------+----------------------+
