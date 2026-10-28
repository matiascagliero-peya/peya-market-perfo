DECLARE query_name STRING DEFAULT 'Glosario-174-Share of Effective Promotions %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 174
-- Nombre:     Share of Effective Promotions %
-- Chapter:   Assortment, Pricing & Promo
-- Query bajada en: 5 - Supply Chain / AQS
-- Sheets Name: A. TI - SC Data - Monthly (5 - Supply Chain)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1aCrgEjh6qT5T8ayT2H22r3iNc55nAR1O9vaOCW6pRBs
-- Tablas de origen: `fulfillment-dwh-production.curated_data_shared_dmart.tableau_promo_quality_score_v3`
-- Tipo:       Ratio Calculado
-- Fórmula:    SUM(w_share_effective_promos) / SUM(dd_gpv_eur)
-- Definición: Métrica comercial de surtido/precios: Share of Effective Promotions %.
-- ====================================================================================

SELECT
  country_name AS country,
  date_month AS month,
  SAFE_DIVIDE(SUM(w_share_effective_promos), NULLIF(SUM(dd_gpv_eur), 0)) AS share_of_effective_promotions_pct
FROM `fulfillment-dwh-production.curated_data_shared_dmart.tableau_promo_quality_score_v3`
WHERE date_month = '2026-09-01'
  AND management_entity_grouped = 'Pedidosya'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------+-----------------------------------+
-- | country              | month | share_of_effective_promotions_pct |
-- +----------------------+-------+-----------------------------------+
-- | Argentina            | 2.026 |                            95,75% |
-- | Bolivia              | 2.026 |                            89,22% |
-- | Chile                | 2.026 |                            87,66% |
-- | República Dominicana | 2.026 |                            66,59% |
-- | Ecuador              | 2.026 |                            90,95% |
-- | El Salvador          | 2.026 |                            70,20% |
-- | Guatemala            | 2.026 |                            84,39% |
-- | Honduras             | 2.026 |                            75,07% |
-- | Nicaragua            | 2.026 |                            80,58% |
-- | Panamá               | 2.026 |                            60,69% |
-- | Paraguay             | 2.026 |                            79,32% |
-- | Perú                 | 2.026 |                            76,93% |
-- | Uruguay              | 2.026 |                            61,42% |
-- +----------------------+-------+-----------------------------------+
