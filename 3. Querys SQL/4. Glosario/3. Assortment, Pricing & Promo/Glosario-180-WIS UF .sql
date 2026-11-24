DECLARE query_name STRING DEFAULT 'Glosario-180-WIS UF %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 180
-- Nombre:     WIS UF %
-- Chapter:   Assortment, Pricing & Promo
-- Query bajada en: 5 - Supply Chain
-- Sheets Name: A. TI - SC Data - Monthly (5 - Supply Chain)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1aCrgEjh6qT5T8ayT2H22r3iNc55nAR1O9vaOCW6pRBs
-- Tablas de origen: `fulfillment-dwh-production.curated_data_shared_dmart.availability_data` + `peya-delivery-and-support.automated_tables_reports.reple_flag_supplier_portal_historical` + `peya-bi-tools-pro.il_core.dim_country`
-- Tipo:       Ratio Calculado
-- Fórmula:    SUM(sales_forecast_quantity_uf * hours_ponderado_uf) / SUM(sales_forecast_quantity_uf)
-- Definición: Weighted In Stock Ultra Fresh: disponibilidad horaria ponderada en categorías Ultra Fresh.
-- ====================================================================================

WITH wis_raw AS (
  SELECT
    period_day,
    LOWER(ad.country_code) AS country_code,
    ad.warehouse_id,
    ad.sku,
    MAX(sales_forecast_quantity) AS sales_forecast_quantity,  
    SUM(available_hourly * hourly_events_weightage) / NULLIF(SUM(hourly_events_weightage), 0) AS hours_ponderado,
    MAX(CASE WHEN level_zero_category = 'Ultra Fresh' THEN sales_forecast_quantity END) AS sales_forecast_quantity_uf,
    SAFE_DIVIDE(
      SUM(CASE WHEN level_zero_category = 'Ultra Fresh' THEN available_hourly * hourly_events_weightage END),
      NULLIF(SUM(CASE WHEN level_zero_category = 'Ultra Fresh' THEN hourly_events_weightage END), 0)
    ) AS hours_ponderado_uf
  FROM `fulfillment-dwh-production.curated_data_shared_dmart.availability_data` ad
  LEFT JOIN `peya-delivery-and-support.automated_tables_reports.reple_flag_supplier_portal_historical` sp 
    ON ad.warehouse_id = sp.warehouse_id AND period_day = date AND ad.sku = sp.sku
  WHERE (
      (period_day >= DATE(status_implementation_date) AND sku_status IN ('ACTIVE') AND is_stale IS FALSE)
      OR
      (((period_day < DATE(status_implementation_date)) OR (status_implementation_date IS NULL)) AND is_active AND is_stale IS FALSE)
  )
    AND store_open = 1
    AND period_day BETWEEN '2026-09-01' AND '2026-09-30'
    AND is_active
    AND management_entity = 'Pedidosya'
    AND status_final <> 'No activo'
  GROUP BY 1, 2, 3, 4
)
SELECT
  c.country_name_en AS country,
  DATE_TRUNC(w.period_day, MONTH) AS month,
  SUM(w.sales_forecast_quantity_uf * w.hours_ponderado_uf) AS wis_uf_numerador,
  SUM(w.sales_forecast_quantity_uf) AS wis_uf_denominador,
  SAFE_DIVIDE(
    SUM(w.sales_forecast_quantity_uf * w.hours_ponderado_uf),
    NULLIF(SUM(w.sales_forecast_quantity_uf), 0)
  ) AS wis_ultra_fresh_pct
FROM wis_raw w
LEFT JOIN (
  SELECT LOWER(country_code) AS cc, ANY_VALUE(country_name_en) AS country_name_en
  FROM `peya-bi-tools-pro.il_core.dim_country`
  GROUP BY 1
) c ON w.country_code = c.cc
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------+--------------------+------------------+---------------------+
-- | country              | month | wis_uf_denominador | wis_uf_numerador | wis_ultra_fresh_pct |
-- +----------------------+-------+--------------------+------------------+---------------------+
-- | Argentina            | 2.026 |       5.677.947,68 |     4.870.827,73 |              85,79% |
-- | Bolivia              | 2.026 |         270.044,46 |       239.459,40 |              88,67% |
-- | Chile                | 2.026 |         547.726,51 |       451.622,62 |              82,45% |
-- | República Dominicana | 2.026 |         317.451,37 |       286.480,65 |              90,24% |
-- | Ecuador              | 2.026 |         138.740,06 |       121.278,80 |              87,41% |
-- | El Salvador          | 2.026 |         132.984,35 |       114.986,17 |              86,47% |
-- | Guatemala            | 2.026 |         177.740,39 |       148.934,81 |              83,79% |
-- | Honduras             | 2.026 |          47.830,85 |        38.563,57 |              80,62% |
-- | Nicaragua            | 2.026 |         120.480,86 |       113.901,05 |              94,54% |
-- | Panamá               | 2.026 |         163.987,42 |       148.909,92 |              90,81% |
-- | Paraguay             | 2.026 |         194.507,88 |       180.315,36 |              92,70% |
-- | Perú                 | 2.026 |         427.091,86 |       373.246,73 |              87,39% |
-- | Uruguay              | 2.026 |         531.506,74 |       464.489,88 |              87,39% |
-- +----------------------+-------+--------------------+------------------+---------------------+
