DECLARE query_name STRING DEFAULT 'Glosario-182-WLT UF Lvl3 - Supplier Issues %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 182
-- Nombre:     WLT UF Lvl3 - Supplier Issues %
-- Chapter:   Assortment, Pricing & Promo
-- Query bajada en: 5 - Supply Chain
-- Sheets Name: A. TI - SC Data - Monthly (5 - Supply Chain)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1aCrgEjh6qT5T8ayT2H22r3iNc55nAR1O9vaOCW6pRBs
-- Tablas de origen: `peya-delivery-and-support.automated_tables_reports.dmarts_loss_tree` + `peya-bi-tools-pro.il_core.dim_country`
-- Tipo:       Ratio Calculado
-- Fórmula:    SUM(perdida_supplier_uf) / SUM(sales_forecast_uf)
-- Definición: Pérdida de disponibilidad atribuible a proveedores en Ultra Fresh.
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
  SUM(IF(b.es_uf, b.perdida_supplier, 0)) AS supplier_issues_uf_numerador,
  SUM(IF(b.es_uf, b.sales_forecast, 0)) AS supplier_issues_uf_denominador,
  SAFE_DIVIDE(
    SUM(IF(b.es_uf, b.perdida_supplier, 0)),
    NULLIF(SUM(IF(b.es_uf, b.sales_forecast, 0)), 0)
  ) AS supplier_issues_uf_pct
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
-- +----------------------+-------+--------------------------------+------------------------------+------------------------+
-- | country              | month | supplier_issues_uf_denominador | supplier_issues_uf_numerador | supplier_issues_uf_pct |
-- +----------------------+-------+--------------------------------+------------------------------+------------------------+
-- | Argentina            | 2.026 |                   5.678.343,50 |                   273.061,96 |                  4,81% |
-- | Bolivia              | 2.026 |                     270.044,45 |                    14.061,75 |                  5,21% |
-- | Chile                | 2.026 |                     547.726,50 |                    30.344,96 |                  5,54% |
-- | República Dominicana | 2.026 |                     316.125,29 |                     7.541,65 |                  2,39% |
-- | Ecuador              | 2.026 |                     138.740,05 |                     9.095,94 |                  6,56% |
-- | El Salvador          | 2.026 |                     132.984,34 |                     9.336,86 |                  7,02% |
-- | Guatemala            | 2.026 |                     177.740,40 |                    10.486,38 |                  5,90% |
-- | Honduras             | 2.026 |                      47.830,85 |                     4.387,19 |                  9,17% |
-- | Nicaragua            | 2.026 |                     120.480,86 |                     4.341,09 |                  3,60% |
-- | Panamá               | 2.026 |                     164.790,10 |                     6.313,74 |                  3,83% |
-- | Paraguay             | 2.026 |                     194.507,87 |                     7.584,22 |                  3,90% |
-- | Perú                 | 2.026 |                     426.891,60 |                    17.920,20 |                  4,20% |
-- | Uruguay              | 2.026 |                     531.183,98 |                    26.945,56 |                  5,07% |
-- +----------------------+-------+--------------------------------+------------------------------+------------------------+
