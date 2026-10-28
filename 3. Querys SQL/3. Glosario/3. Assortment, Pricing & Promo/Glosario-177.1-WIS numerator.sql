DECLARE query_name STRING DEFAULT 'Glosario-177.1-WIS numerator';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 177.1
-- Nombre:     WIS numerator
-- Chapter:   Assortment, Pricing & Promo
-- Query bajada en: 5 - Supply Chain
-- Sheets Name: A. TI - SC Data - Monthly (5 - Supply Chain)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1aCrgEjh6qT5T8ayT2H22r3iNc55nAR1O9vaOCW6pRBs
-- Tablas de origen: `fulfillment-dwh-production.curated_data_shared_dmart.availability_data` + `peya-delivery-and-support.automated_tables_reports.reple_flag_supplier_portal_historical` + `peya-bi-tools-pro.il_core.dim_country`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(hours_ponderado * sales_forecast_quantity)
-- Definición: Numerador de WIS: horas ponderadas por pronóstico de ventas.
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
  SUM(w.hours_ponderado * w.sales_forecast_quantity) AS wis_numerador
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
-- +----------------------+-------+---------------+
-- | country              | month | wis_numerador |
-- +----------------------+-------+---------------+
-- | Argentina            | 2.026 | 25.189.650,72 |
-- | Bolivia              | 2.026 |  1.046.309,78 |
-- | Chile                | 2.026 |  2.905.127,88 |
-- | República Dominicana | 2.026 |  1.024.794,23 |
-- | Ecuador              | 2.026 |    647.386,04 |
-- | El Salvador          | 2.026 |    540.471,45 |
-- | Guatemala            | 2.026 |    635.579,99 |
-- | Honduras             | 2.026 |    228.201,59 |
-- | Nicaragua            | 2.026 |    351.325,54 |
-- | Panamá               | 2.026 |    778.622,76 |
-- | Paraguay             | 2.026 |    886.399,88 |
-- | Perú                 | 2.026 |  1.631.259,21 |
-- | Uruguay              | 2.026 |  2.519.128,69 |
-- +----------------------+-------+---------------+
