DECLARE query_name STRING DEFAULT 'Glosario-168-Back Margin';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 168
-- Nombre:     Back Margin
-- Chapter:   Assortment, Pricing & Promo
-- Query bajada en: 5 - Supply Chain / AQS
-- Sheets Name: A. TI - SC Data - Monthly (5 - Supply Chain)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1aCrgEjh6qT5T8ayT2H22r3iNc55nAR1O9vaOCW6pRBs
-- Tablas de origen: `peya-fraud-and-fintech.group_finance_data.fact_dmart_forecast_america` (RAW)
-- Tipo:       Dato Directo
-- Fórmula:    SUM(back_margin_eur) de acuerdos con proveedores
-- Definición: Métrica comercial de surtido/precios: Back Margin.
-- ====================================================================================

SELECT
  country_name AS country,
  f_month_date AS month,
  SUM(net_sales_eur) AS net_sales_eur,
  SUM(front_margin_eur) AS front_margin_eur,
  SUM(back_margin_eur) AS back_margin_eur,
  SUM(front_margin_eur + back_margin_eur) AS commercial_margin_eur,
  SUM(shrinkage_eur) AS shrinkage_eur,
  SUM(labor_cost_eur) AS labor_cost_eur,
  SUM(packaging_cost_eur) AS packaging_cost_eur,
  SUM(warehouse_net_cost_eur) AS wdc_net_cost_eur,
  SUM(ebitda_eur) AS ebitda_eur,
  SUM(retail_gp_eur) AS retail_gp_eur,
  SUM(retail_ebitda_eur) AS retail_ebitda_eur,
  SAFE_DIVIDE(SUM(front_margin_eur + back_margin_eur), NULLIF(SUM(net_sales_eur), 0)) AS commercial_margin_pct,
  SAFE_DIVIDE(SUM(ebitda_eur), NULLIF(SUM(net_sales_eur), 0)) AS ebitda_pct
FROM `peya-fraud-and-fintech.group_finance_data.fact_dmart_forecast_america`
WHERE f_month_date = '2026-09-01'
  AND scenario LIKE '%BE08%'
GROUP BY 1, 2
ORDER BY 1 ASC;
