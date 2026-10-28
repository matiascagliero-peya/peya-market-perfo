DECLARE query_name STRING DEFAULT 'Glosario-179-WLT Lvl3 - Supplier Issues %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 179
-- Nombre:     WLT Lvl3 - Supplier Issues %
-- Chapter:   Assortment, Pricing & Promo
-- Query bajada en: 5 - Supply Chain
-- Sheets Name: A. TI - SC Data - Monthly (5 - Supply Chain)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1aCrgEjh6qT5T8ayT2H22r3iNc55nAR1O9vaOCW6pRBs
-- Tablas de origen: `peya-delivery-and-support.automated_tables_reports.dmarts_loss_tree` + `peya-bi-tools-pro.il_core.dim_country`
-- Tipo:       Ratio Calculado
-- Fórmula:    SUM(perdida_supplier) / SUM(sales_forecast)
-- Definición: Pérdida de disponibilidad atribuible a proveedores y roturas de stock.
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
  SUM(b.perdida_supplier) AS supplier_issues_numerador,
  SUM(b.sales_forecast) AS supplier_issues_denominador,
  SAFE_DIVIDE(
    SUM(b.perdida_supplier),
    NULLIF(SUM(b.sales_forecast), 0)
  ) AS supplier_issues_pct
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
-- +----------------------+-------+-----------------------------+---------------------------+---------------------+
-- | country              | month | supplier_issues_denominador | supplier_issues_numerador | supplier_issues_pct |
-- +----------------------+-------+-----------------------------+---------------------------+---------------------+
-- | Argentina            | 2.026 |               31.839.304,74 |              2.055.687,12 |               6,46% |
-- | Bolivia              | 2.026 |                1.222.878,29 |                113.222,27 |               9,26% |
-- | Chile                | 2.026 |                3.284.308,22 |                172.491,44 |               5,25% |
-- | República Dominicana | 2.026 |                1.182.328,73 |                 91.516,03 |               7,74% |
-- | Ecuador              | 2.026 |                  717.777,91 |                 41.168,78 |               5,74% |
-- | El Salvador          | 2.026 |                  617.346,12 |                 43.182,45 |               6,99% |
-- | Guatemala            | 2.026 |                  735.960,11 |                 56.177,68 |               7,63% |
-- | Honduras             | 2.026 |                  279.810,48 |                 35.628,99 |              12,73% |
-- | Nicaragua            | 2.026 |                  385.857,23 |                 24.800,77 |               6,43% |
-- | Panamá               | 2.026 |                  847.700,09 |                 41.348,60 |               4,88% |
-- | Paraguay             | 2.026 |                  946.538,77 |                 34.833,17 |               3,68% |
-- | Perú                 | 2.026 |                1.769.073,70 |                 53.035,91 |               3,00% |
-- | Uruguay              | 2.026 |                2.826.852,73 |                139.180,39 |               4,92% |
-- +----------------------+-------+-----------------------------+---------------------------+---------------------+
