DECLARE query_name STRING DEFAULT 'WIS UF %.sql';

-- ====================================================================================
-- PROPÓSITO: Cálculo de WIS ULTRA FRESH (Weighted In-Stock) a nivel SEMANAL
--            por PAÍS y total consolidado LATAM.
--
-- DERIVADO DE: '2. Absolute Supply OKRs.sql'
-- ====================================================================================

-- Rango de fechas: por defecto últimas 8 semanas completas hasta ayer (Lunes a Domingo)
DECLARE inicio DATE DEFAULT DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 8 WEEK), WEEK(MONDAY));
DECLARE fin    DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);

WITH
-- 1. Disponibilidad horaria y forecast diario a nivel SKU/Warehouse para Ultra Fresh
wis_raw_uf AS (
  SELECT
    DATE_TRUNC(ad.period_day, WEEK(MONDAY))                            AS dia_inicio_semana,
    DATE_ADD(DATE_TRUNC(ad.period_day, WEEK(MONDAY)), INTERVAL 6 DAY)    AS dia_fin_semana,
    LOWER(ad.country_code)                                             AS country_code,
    ad.warehouse_id,
    ad.sku,
    ad.period_day,
    MAX(ad.sales_forecast_quantity)                                    AS sales_forecast_quantity_uf,
    SAFE_DIVIDE(
      SUM(ad.available_hourly * ad.hourly_events_weightage),
      SUM(ad.hourly_events_weightage)
    )                                                                  AS hours_ponderado_uf
  FROM `fulfillment-dwh-production.curated_data_shared_dmart.availability_data` ad
  LEFT JOIN `peya-delivery-and-support.automated_tables_reports.reple_flag_supplier_portal_historical` sp 
    ON ad.warehouse_id = sp.warehouse_id 
   AND ad.period_day = sp.date 
   AND ad.sku = sp.sku
  WHERE ad.level_zero_category = 'Ultra Fresh'
    AND (
      (ad.period_day >= DATE(ad.status_implementation_date) AND ad.sku_status IN ('ACTIVE') AND ad.is_stale IS FALSE)
      OR
      (((ad.period_day < DATE(ad.status_implementation_date)) OR (ad.status_implementation_date IS NULL)) AND ad.is_active AND ad.is_stale IS FALSE)
    )
    AND ad.store_open = 1
    AND ad.period_day BETWEEN inicio AND fin
    AND ad.is_active
    AND ad.management_entity = 'Pedidosya'
    AND ad.status_final <> 'No activo'
  GROUP BY 1, 2, 3, 4, 5, 6
),

-- 2. Agregación semanal de WIS Ultra Fresh por País
wis_weekly_by_country AS (
  SELECT
    dia_inicio_semana,
    dia_fin_semana,
    country_code,
    SUM(sales_forecast_quantity_uf * hours_ponderado_uf) AS wis_uf_numerador,
    SUM(sales_forecast_quantity_uf)                      AS wis_uf_denominador
  FROM wis_raw_uf
  GROUP BY 1, 2, 3
),

-- 3. Consolidado regional para toda la entidad 'LATAM'
wis_weekly_latam AS (
  SELECT
    dia_inicio_semana,
    dia_fin_semana,
    'latam'                                              AS country_code,
    SUM(wis_uf_numerador)                                AS wis_uf_numerador,
    SUM(wis_uf_denominador)                              AS wis_uf_denominador
  FROM wis_weekly_by_country
  GROUP BY 1, 2
),

-- 4. Unión de países individuales + consolidado LATAM
combined AS (
  SELECT * FROM wis_weekly_by_country
  UNION ALL
  SELECT * FROM wis_weekly_latam
),

-- 5. Dimensión de países para enriquecer con nombre completo
dim_countries AS (
  SELECT 
    LOWER(country_code) AS cc, 
    ANY_VALUE(country_name_en) AS country_name
  FROM `peya-bi-tools-pro.il_core.dim_country`
  GROUP BY 1
)

-- Resultado final: WIS Ultra Fresh Semanal por País y LATAM
SELECT
  c.dia_inicio_semana,
  c.dia_fin_semana,
  UPPER(c.country_code) AS country_code,
  IF(c.country_code = 'latam', 'LATAM', COALESCE(dc.country_name, UPPER(c.country_code))) AS country_name,

  c.wis_uf_numerador,
  c.wis_uf_denominador,

  -- Porcentaje WIS Ultra Fresh Semanal
  SAFE_DIVIDE(c.wis_uf_numerador, c.wis_uf_denominador) AS wis_ultra_fresh

FROM combined c
LEFT JOIN dim_countries dc
  ON c.country_code = dc.cc
ORDER BY 
  c.dia_inicio_semana DESC, 
  (CASE WHEN c.country_code = 'latam' THEN 0 ELSE 1 END), 
  country_name ASC;
