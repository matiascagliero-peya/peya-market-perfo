DECLARE query_name STRING DEFAULT 'Glosario-181-WLT UF Lvl3 - Peya Issues %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 181
-- Nombre:     WLT UF Lvl3 - Peya Issues %
-- Chapter:   Assortment, Pricing & Promo
-- Query bajada en: 5 - Supply Chain
-- Sheets Name: A. TI - SC Data - Monthly (5 - Supply Chain)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1aCrgEjh6qT5T8ayT2H22r3iNc55nAR1O9vaOCW6pRBs
-- Tablas de origen: `peya-delivery-and-support.automated_tables_reports.dmarts_loss_tree` + `peya-bi-tools-pro.il_core.dim_country`
-- Tipo:       Ratio Calculado
-- Fórmula:    SUM(perdida_peya_uf) / SUM(sales_forecast_uf)
-- Definición: Pérdida de disponibilidad atribuible a PeYa en categorías Ultra Fresh.
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
  SUM(IF(b.es_uf, b.perdida_peya, 0)) AS peya_issues_uf_numerador,
  SUM(IF(b.es_uf, b.sales_forecast, 0)) AS peya_issues_uf_denominador,
  SAFE_DIVIDE(
    SUM(IF(b.es_uf, b.perdida_peya, 0)),
    NULLIF(SUM(IF(b.es_uf, b.sales_forecast, 0)), 0)
  ) AS peya_issues_uf_pct
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
-- +----------------------+-------+----------------------------+--------------------------+--------------------+
-- | country              | month | peya_issues_uf_denominador | peya_issues_uf_numerador | peya_issues_uf_pct |
-- +----------------------+-------+----------------------------+--------------------------+--------------------+
-- | Argentina            | 2.026 |               5.678.343,50 |               438.435,34 |              7,72% |
-- | Bolivia              | 2.026 |                 270.044,45 |                14.326,16 |              5,31% |
-- | Chile                | 2.026 |                 547.726,50 |                60.041,00 |             10,96% |
-- | República Dominicana | 2.026 |                 316.125,29 |                19.548,57 |              6,18% |
-- | Ecuador              | 2.026 |                 138.740,05 |                 7.140,94 |              5,15% |
-- | El Salvador          | 2.026 |                 132.984,34 |                 7.578,72 |              5,70% |
-- | Guatemala            | 2.026 |                 177.740,40 |                16.362,89 |              9,21% |
-- | Honduras             | 2.026 |                  47.830,85 |                 4.251,51 |              8,89% |
-- | Nicaragua            | 2.026 |                 120.480,86 |                 1.985,01 |              1,65% |
-- | Panamá               | 2.026 |                 164.790,10 |                 7.647,76 |              4,64% |
-- | Paraguay             | 2.026 |                 194.507,87 |                 5.860,76 |              3,01% |
-- | Perú                 | 2.026 |                 426.891,60 |                29.597,62 |              6,93% |
-- | Uruguay              | 2.026 |                 531.183,98 |                36.192,91 |              6,81% |
-- +----------------------+-------+----------------------------+--------------------------+--------------------+
