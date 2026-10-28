DECLARE query_name STRING DEFAULT 'Glosario-178-WLT Lvl3 - Peya Issues %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 178
-- Nombre:     WLT Lvl3 - Peya Issues %
-- Chapter:   Assortment, Pricing & Promo
-- Query bajada en: 5 - Supply Chain
-- Sheets Name: A. TI - SC Data - Monthly (5 - Supply Chain)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1aCrgEjh6qT5T8ayT2H22r3iNc55nAR1O9vaOCW6pRBs
-- Tablas de origen: `peya-delivery-and-support.automated_tables_reports.dmarts_loss_tree` + `peya-bi-tools-pro.il_core.dim_country`
-- Tipo:       Ratio Calculado
-- Fórmula:    SUM(perdida_peya) / SUM(sales_forecast)
-- Definición: Pérdida de disponibilidad atribuible a procesos internos de PeYa sobre el pronóstico total.
-- ====================================================================================

WITH base AS (
  SELECT
    date AS fecha,
    LOWER(country_code) AS country_code,
    sales_forecast,
    level_one IN ('Produce','Meat / Seafood','Ready To Consume') AS es_uf,
    IF(loss_tree_lvl0 = 'Peya Issues', sales_forecast * (1 - availability_horario), 0) AS perdida_peya,
    IF(loss_tree_lvl0 = 'Supplier + P&N Issues', sales_forecast * (1 - availability_horario), 0) AS perdida_supplier
  FROM `peya-delivery-and-support.automated_tables_reports.dmarts_loss_tree`
  WHERE date BETWEEN '2026-09-01' AND '2026-09-30'
    AND status_final IN ('Activo directa', 'Activo centralizado')
    AND filter_looker = 'Filter'
)
SELECT
  c.country_name_en AS country,
  DATE_TRUNC(b.fecha, MONTH) AS month,
  SUM(b.perdida_peya) AS peya_issues_numerador,
  SUM(b.sales_forecast) AS peya_issues_denominador,
  SAFE_DIVIDE(
    SUM(b.perdida_peya),
    NULLIF(SUM(b.sales_forecast), 0)
  ) AS peya_issues_pct
FROM base b
LEFT JOIN (
  SELECT LOWER(country_code) AS cc, ANY_VALUE(country_name_en) AS country_name_en
  FROM `peya-bi-tools-pro.il_core.dim_country`
  GROUP BY 1
) c ON b.country_code = c.cc
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------+-------------------------+-----------------------+-----------------+
-- | country              | month | peya_issues_denominador | peya_issues_numerador | peya_issues_pct |
-- +----------------------+-------+-------------------------+-----------------------+-----------------+
-- | Argentina            | 2.026 |           31.839.304,74 |          4.316.616,13 |          13,56% |
-- | Bolivia              | 2.026 |            1.222.878,29 |             54.542,83 |           4,46% |
-- | Chile                | 2.026 |            3.284.308,22 |            181.797,14 |           5,54% |
-- | República Dominicana | 2.026 |            1.182.328,73 |             52.984,73 |           4,48% |
-- | Ecuador              | 2.026 |              717.777,91 |             25.790,80 |           3,59% |
-- | El Salvador          | 2.026 |              617.346,12 |             29.768,99 |           4,82% |
-- | Guatemala            | 2.026 |              735.960,11 |             39.046,10 |           5,31% |
-- | Honduras             | 2.026 |              279.810,48 |             13.901,65 |           4,97% |
-- | Nicaragua            | 2.026 |              385.857,23 |              8.732,77 |           2,26% |
-- | Panamá               | 2.026 |              847.700,09 |             25.245,90 |           2,98% |
-- | Paraguay             | 2.026 |              946.538,77 |             23.657,53 |           2,50% |
-- | Perú                 | 2.026 |            1.769.073,70 |             73.068,00 |           4,13% |
-- | Uruguay              | 2.026 |            2.826.852,73 |            153.628,00 |           5,43% |
-- +----------------------+-------+-------------------------+-----------------------+-----------------+
