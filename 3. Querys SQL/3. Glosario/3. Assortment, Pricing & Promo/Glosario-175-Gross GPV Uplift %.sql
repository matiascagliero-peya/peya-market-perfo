DECLARE query_name STRING DEFAULT 'Glosario-175-Gross GPV Uplift %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 175
-- Nombre:     Gross GPV Uplift %
-- Chapter:   Assortment, Pricing & Promo
-- Query bajada en: 5 - Supply Chain / AQS
-- Sheets Name: A. TI - SC Data - Monthly (5 - Supply Chain)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1aCrgEjh6qT5T8ayT2H22r3iNc55nAR1O9vaOCW6pRBs
-- Tablas de origen: `fulfillment-dwh-production.curated_data_shared_dmart.tableau_promo_quality_score_v3`
-- Tipo:       Ratio Calculado
-- Fórmula:    SUM(w_net_gpv_uplift) / SUM(dd_gpv_eur)
-- Definición: Métrica comercial de surtido/precios: Gross GPV Uplift %.
-- ====================================================================================

SELECT
  country_name AS country,
  date_month AS month,
  SAFE_DIVIDE(SUM(w_net_gpv_uplift), NULLIF(SUM(dd_gpv_eur), 0)) AS gross_gpv_uplift_pct
FROM `fulfillment-dwh-production.curated_data_shared_dmart.tableau_promo_quality_score_v3`
WHERE date_month = '2026-09-01'
  AND management_entity_grouped = 'Pedidosya'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+----------------------+-------+
-- | country              | gross_gpv_uplift_pct | month |
-- +----------------------+----------------------+-------+
-- | Argentina            |               73,15% | 2.026 |
-- | Bolivia              |               55,94% | 2.026 |
-- | Chile                |               37,48% | 2.026 |
-- | República Dominicana |               30,50% | 2.026 |
-- | Ecuador              |               70,74% | 2.026 |
-- | El Salvador          |               60,73% | 2.026 |
-- | Guatemala            |               67,28% | 2.026 |
-- | Honduras             |               52,31% | 2.026 |
-- | Nicaragua            |               39,76% | 2.026 |
-- | Panamá               |               47,76% | 2.026 |
-- | Paraguay             |               54,03% | 2.026 |
-- | Perú                 |               34,37% | 2.026 |
-- | Uruguay              |               34,31% | 2.026 |
-- +----------------------+----------------------+-------+
