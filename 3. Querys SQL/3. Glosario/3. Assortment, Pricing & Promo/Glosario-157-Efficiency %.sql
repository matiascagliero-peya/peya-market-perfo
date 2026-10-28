DECLARE query_name STRING DEFAULT 'Glosario-157-Efficiency %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 157
-- Nombre:     Efficiency %
-- Chapter:   Assortment, Pricing & Promo
-- Query bajada en: 5 - Supply Chain / AQS
-- Sheets Name: A. TI - SC Data - Monthly (5 - Supply Chain)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1aCrgEjh6qT5T8ayT2H22r3iNc55nAR1O9vaOCW6pRBs
-- Tablas de origen: `fulfillment-dwh-production.curated_data_shared_dmart.assortment_quality_scorecard_v7`
-- Tipo:       Ratio Calculado
-- Fórmula:    AVG(check_efficiency)
-- Definición: Métrica comercial de surtido/precios: Efficiency %.
-- ====================================================================================

SELECT
  IFNULL(country_code, 'LATAM') AS country,
  DATE_TRUNC(DATE(date_month), MONTH) AS month,
  AVG(final_score) AS aqs,
  AVG(avg_listed_skus_check) AS listed_skus,
  AVG(perc_listed_target_completion) AS listed_skus_achievement_pct,
  AVG(check_efficiency) AS efficiency_pct,
  AVG(ultrafresh_bp) AS uf_basket_penetration_pct,
  AVG(check_newness) AS newness_pct,
  AVG(check_perc_availability) AS weighted_availability_pct,
  AVG(check_book_value) AS discontinued_book_value_pct
FROM `fulfillment-dwh-production.curated_data_shared_dmart.assortment_quality_scorecard_v7`
WHERE region = 'Pedidosya'
  AND granularity = 'Country'
  AND DATE(date_month) = '2026-09-01'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +-------+----------------------+-----------------------------+----------------+-------------+-----------------------------+-------+-------------+---------------------------+---------------------------+
-- | aqs   | country              | discontinued_book_value_pct | efficiency_pct | listed_skus | listed_skus_achievement_pct | month | newness_pct | uf_basket_penetration_pct | weighted_availability_pct |
-- +-------+----------------------+-----------------------------+----------------+-------------+-----------------------------+-------+-------------+---------------------------+---------------------------+
-- | 72,16 | Argentina            |                       1,50% |         89,37% |    5.470,19 |                      74,54% | 2.026 |      16,75% |                    42,00% |                    77,95% |
-- | 50,21 | Bolivia              |                      10,17% |         67,80% |    5.224,66 |                      81,84% | 2.026 |       9,81% |                    33,00% |                    83,90% |
-- | 59,80 | Chile                |                       4,25% |         61,18% |    5.042,40 |                      91,11% | 2.026 |      10,60% |                    42,00% |                    88,24% |
-- | 52,75 | República Dominicana |                       2,64% |         74,09% |    4.493,04 |                      78,11% | 2.026 |      10,06% |                    32,00% |                    86,18% |
-- | 53,71 | Ecuador              |                       3,70% |         52,36% |    5.879,00 |                       1,14% | 2.026 |      10,79% |                    34,00% |                    89,70% |
-- | 64,49 | El Salvador          |                       4,80% |         77,85% |    4.345,63 |                      79,01% | 2.026 |      10,82% |                    36,00% |                    87,15% |
-- | 69,19 | Guatemala            |                       3,25% |         67,97% |    5.238,00 |                      95,24% | 2.026 |       5,69% |                    39,00% |                    86,08% |
-- | 34,52 | Honduras             |                       4,56% |         68,85% |    3.659,35 |                      66,53% | 2.026 |      13,84% |                    22,00% |                    81,52% |
-- | 67,94 | Nicaragua            |                       3,32% |         84,18% |       5.002 |                      76,95% | 2.026 |       8,88% |                    38,00% |                    90,97% |
-- | 71,84 | Panamá               |                       9,83% |         67,32% |    5.803,39 |                       1,10% | 2.026 |       7,05% |                    41,00% |                    91,75% |
-- | 62,81 | Paraguay             |                       6,27% |         76,17% |    4.991,04 |                      89,67% | 2.026 |      10,29% |                    34,00% |                    93,62% |
-- | 60,46 | Perú                 |                       4,28% |         62,93% |    5.839,19 |                       1,09% | 2.026 |      12,09% |                    36,00% |                    91,94% |
-- | 78,03 | Uruguay              |                       1,56% |         81,71% |    5.881,38 |                      86,39% | 2.026 |       6,90% |                    43,00% |                    89,00% |
-- +-------+----------------------+-----------------------------+----------------+-------------+-----------------------------+-------+-------------+---------------------------+---------------------------+
