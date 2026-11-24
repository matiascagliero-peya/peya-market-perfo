DECLARE query_name STRING DEFAULT 'Glosario-177-WIS %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 177
-- Nombre:     WIS %
-- Chapter:   Assortment, Pricing & Promo
-- Query bajada en: 5 - Supply Chain
-- Sheets Name: A. TI - SC Data - Monthly (5 - Supply Chain)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1aCrgEjh6qT5T8ayT2H22r3iNc55nAR1O9vaOCW6pRBs
-- Tablas de origen: `fulfillment-dwh-production.curated_data_shared_dmart.availability_data` + `peya-delivery-and-support.automated_tables_reports.reple_flag_supplier_portal_historical` + `peya-bi-tools-pro.il_core.dim_country`
-- Tipo:       Ratio Calculado
-- Fórmula:    SUM(hours_ponderado * sales_forecast_quantity) / SUM(sales_forecast_quantity)
-- Definición: Weighted In Stock: disponibilidad horaria ponderada por pronóstico de ventas.
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
  SUM(w.hours_ponderado * w.sales_forecast_quantity) AS wis_numerador,
  SUM(w.sales_forecast_quantity) AS wis_denominador,
  SAFE_DIVIDE(
    SUM(w.hours_ponderado * w.sales_forecast_quantity),
    NULLIF(SUM(w.sales_forecast_quantity), 0)
  ) AS wis_pct
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
-- +----------------------+-------+-----------------+---------------+---------+
-- | country              | month | wis_denominador | wis_numerador | wis_pct |
-- +----------------------+-------+-----------------+---------------+---------+
-- | Argentina            | 2.026 |   31.839.284,25 | 25.189.650,72 |  79,12% |
-- | Bolivia              | 2.026 |    1.222.878,12 |  1.046.309,78 |  85,56% |
-- | Chile                | 2.026 |    3.284.307,18 |  2.905.127,88 |  88,45% |
-- | República Dominicana | 2.026 |    1.182.328,48 |  1.024.794,23 |  86,68% |
-- | Ecuador              | 2.026 |      717.777,64 |    647.386,04 |  90,19% |
-- | El Salvador          | 2.026 |      617.339,14 |    540.471,45 |  87,55% |
-- | Guatemala            | 2.026 |      735.850,24 |    635.579,99 |  86,37% |
-- | Honduras             | 2.026 |      279.810,43 |    228.201,59 |  81,56% |
-- | Nicaragua            | 2.026 |      385.855,73 |    351.325,54 |  91,05% |
-- | Panamá               | 2.026 |      847.699,96 |    778.622,76 |  91,85% |
-- | Paraguay             | 2.026 |      946.538,74 |    886.399,88 |  93,65% |
-- | Perú                 | 2.026 |    1.769.073,27 |  1.631.259,21 |  92,21% |
-- | Uruguay              | 2.026 |    2.826.852,74 |  2.519.128,69 |  89,11% |
-- +----------------------+-------+-----------------+---------------+---------+
