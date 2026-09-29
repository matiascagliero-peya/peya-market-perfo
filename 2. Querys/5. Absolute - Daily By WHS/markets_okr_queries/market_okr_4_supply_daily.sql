DECLARE query_name STRING DEFAULT 'market_okr_4_supply_daily';

-- ============================================================
-- markets_supply_daily
-- Responsable: Supply / Assortment
-- Grain: fecha_completa + country_name + warehouse_id
-- Los porcentajes (wis_pct, wis_uf_pct) se calculan en la vista
-- ============================================================

DECLARE table_exists BOOL;
SET table_exists = EXISTS (
  SELECT 1
  FROM `peya-food-and-groceries.automated_tables_reports.markets_supply_daily`
);

DECLARE from_date DATE;
DECLARE to_date DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);
IF NOT table_exists THEN
  SET from_date = DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 10 WEEK), WEEK(MONDAY));
ELSE
  SET from_date = DATE_SUB(CURRENT_DATE(), INTERVAL 3 DAY);
END IF;

-- CREACIÓN DE TABLA
IF NOT table_exists THEN
  CREATE TABLE `peya-food-and-groceries.automated_tables_reports.markets_supply_daily` (
    fecha_completa          DATE,
    country_name            STRING,
    warehouse_id            STRING,
    warehouse_name          STRING,
    wis_numerador           FLOAT64,
    wis_denominador         FLOAT64,
    wis_uf_numerador        FLOAT64,
    wis_uf_denominador      FLOAT64
  )
  PARTITION BY fecha_completa
  CLUSTER BY country_name, warehouse_id;
END IF;

-- LIMPIEZA INCREMENTAL
IF table_exists THEN
  DELETE FROM `peya-food-and-groceries.automated_tables_reports.markets_supply_daily`
  WHERE fecha_completa BETWEEN from_date AND to_date;
END IF;

-- INSERCIÓN
INSERT INTO `peya-food-and-groceries.automated_tables_reports.markets_supply_daily`

WITH

partners AS (
  SELECT p.country_id, p.partner_id, pd.warehouse_id, pd.warehouse_name
  FROM `peya-bi-tools-pro.il_core.dim_partner` p
  INNER JOIN `peya-datamarts-pro.dm_dmarts.dim_partner_darkstore` pd ON p.partner_id = pd.partner_id
),

supply_metrics AS (
  SELECT period_day AS day, warehouse_id,
    SUM(hours_ponderado * sales_forecast_quantity)              AS wis_numerador,
    SUM(sales_forecast_quantity)                                AS wis_denominador,
    SUM(sales_forecast_quantity_UF * hours_ponderado_uf)        AS wis_uf_numerador,
    SUM(sales_forecast_quantity_UF)                             AS wis_uf_denominador
  FROM (
    SELECT
      period_day,
      warehouse_id,
      sku,
      level_zero_category,
      MAX(sales_forecast_quantity)                                                                        AS sales_forecast_quantity,
      SUM(available_hourly * hourly_events_weightage) / NULLIF(SUM(hourly_events_weightage), 0)          AS hours_ponderado,
      MAX(CASE WHEN level_zero_category = 'Ultra Fresh' THEN sales_forecast_quantity END)                AS sales_forecast_quantity_UF,
      SAFE_DIVIDE(
        SUM(CASE WHEN level_zero_category = 'Ultra Fresh' THEN available_hourly * hourly_events_weightage END),
        SUM(CASE WHEN level_zero_category = 'Ultra Fresh' THEN hourly_events_weightage END)
      )                                                                                                   AS hours_ponderado_uf
    FROM `fulfillment-dwh-production.curated_data_shared_dmart.availability_data`
    WHERE period_day BETWEEN from_date AND to_date
      AND (
        (period_day >= DATE(status_implementation_date) AND sku_status IN ('ACTIVE') AND is_stale IS FALSE)
        OR (((period_day < DATE(status_implementation_date)) OR (status_implementation_date IS NULL)) AND is_active AND is_stale IS FALSE)
      )
      AND store_open = 1
      AND is_active
      AND management_entity = 'Pedidosya'
    GROUP BY 1, 2, 3, 4
  )
  GROUP BY 1, 2
)

SELECT
  sm.day              AS fecha_completa,
  c.country_name,
  sm.warehouse_id,
  p.warehouse_name,
  sm.wis_numerador,
  sm.wis_denominador,
  sm.wis_uf_numerador,
  sm.wis_uf_denominador

FROM supply_metrics sm
INNER JOIN partners p ON p.warehouse_id = sm.warehouse_id
INNER JOIN `peya-bi-tools-pro.il_core.dim_country` c ON c.country_id = p.country_id AND c.active = TRUE
WHERE sm.day BETWEEN from_date AND to_date;
