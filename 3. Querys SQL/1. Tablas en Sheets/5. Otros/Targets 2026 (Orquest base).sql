-- Targets 2026 - Orquest base
-- Nivel de agregación: PAÍS y LATAM (Consolidado nacional y regional diario)
-- Ventana de fechas: A partir del primer día del mes anterior al actual

WITH
-- 1. Identificación del partner principal (top vendor) por warehouse
top_vendors AS (
  SELECT
    CAST(warehouse_id AS STRING) AS warehouse_id,
    CAST(vendor_id AS STRING) AS vendor_id
  FROM (
    SELECT
      warehouse_id,
      vendor_id,
      RANK() OVER (PARTITION BY warehouse_id ORDER BY MAX(order_date) DESC, COUNT(DISTINCT order_id) DESC) AS rnk
    FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
    WHERE order_date >= '2025-01-01'
      AND STATE = 'CONFIRMED'
    GROUP BY 1, 2
  )
  WHERE rnk = 1
),

-- 2. Fechas operativas reales (apertura y última orden) por warehouse físico
whs_fechas_operativas AS (
  SELECT
    CAST(par.warehouse_id AS STRING) AS warehouse_id,
    MIN(DATE(fo.registered_date)) AS fecha_apertura,
    MAX(DATE(fo.registered_date)) AS fecha_ultima_orden
  FROM `peya-bi-tools-pro.il_core.fact_orders` AS fo
  INNER JOIN `peya-bi-tools-pro.il_core.dim_partner` AS par 
    ON fo.restaurant.id = par.partner_id
  WHERE fo.order_status = 'CONFIRMED'
    AND fo.registered_date >= '2020-01-01'
    AND par.warehouse_id IS NOT NULL
  GROUP BY 1
),

-- 3. Histórico de estado online para detectar último día activo de tiendas cerradas
partner_online_status AS (
  SELECT
    tv.warehouse_id,
    ARRAY_AGG(hp.is_online ORDER BY SAFE_CAST(hp.yyyymmdd AS DATE) DESC LIMIT 1)[OFFSET(0)] AS is_online_actual,
    MAX(CASE WHEN hp.is_online IS TRUE THEN SAFE_CAST(hp.yyyymmdd AS DATE) END) AS fecha_ultimo_dia_online
  FROM top_vendors AS tv
  INNER JOIN `peya-bi-tools-pro.il_core.dim_historical_partners` AS hp
    ON CAST(hp.restaurant_id AS STRING) = tv.vendor_id
  WHERE hp.is_darkstore IS TRUE
  GROUP BY 1
),

-- 4. Maestro de darkstores con ventana operativa válida (apertura y cierre definitivo)
master_warehouses AS (
  SELECT
    CAST(dp.warehouse_id AS STRING)     AS warehouse_id,
    MAX(dp.warehouse_name)              AS warehouse_name,
    LOWER(MAX(dp.country.country_code)) AS country_code,
    MAX(dp.country.country_name)        AS country,
    MIN(fo.fecha_apertura)              AS fecha_apertura,
    -- Si vende en los últimos 3 días sigue abierto (NULL). Si cerró, corta en su último día activo / orden.
    CASE 
      WHEN MAX(fo.fecha_ultima_orden) >= CURRENT_DATE() - 3 THEN NULL
      ELSE LEAST(
        MAX(fo.fecha_ultima_orden),
        COALESCE(MAX(pos.fecha_ultimo_dia_online), MAX(fo.fecha_ultima_orden))
      )
    END AS fecha_cierre_definitiva
  FROM `peya-bi-tools-pro.il_core.dim_partner` AS dp
  LEFT JOIN whs_fechas_operativas AS fo
    ON CAST(dp.warehouse_id AS STRING) = fo.warehouse_id
  LEFT JOIN partner_online_status AS pos
    ON CAST(dp.warehouse_id AS STRING) = pos.warehouse_id
  WHERE dp.is_darkstore IS TRUE
    AND dp.warehouse_id IS NOT NULL
    AND dp.business_type.business_type_name NOT IN ('Courier', 'Courier Business')
  GROUP BY 1
  HAVING LOGICAL_OR(COALESCE(dp.is_active, TRUE))
),

-- 5. Forecast manual por hora filtrado desde el mes anterior y por ciclo de vida
forecast_manual AS (
  SELECT
    DATE(fcst.from_ls) AS fecha,
    CAST(fcst.service_id AS STRING) AS service_id,
    fcst.business_id,
    mw.warehouse_name,
    mw.country_code,
    mw.country,
    fcst.measure,
    EXTRACT(HOUR FROM fcst.from_ls) AS hora,
    SUM(fcst.value) AS total_value
  FROM `peya-data-origins-pro.cl_orquest.measure_projections` AS fcst
  INNER JOIN master_warehouses AS mw
    ON CAST(fcst.service_id AS STRING) = mw.warehouse_id
  WHERE fcst.measure IN ('units_out', 'tickets')
    AND DATE(fcst.from_ls) >= DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 1 MONTH)
    AND DATE(fcst.from_ls) >= COALESCE(mw.fecha_apertura, DATE(fcst.from_ls))
    AND DATE(fcst.from_ls) <= COALESCE(mw.fecha_cierre_definitiva, DATE(fcst.from_ls))
  GROUP BY 1, 2, 3, 4, 5, 6, 7, 8
),

-- 6. Forecast de Orquest por hora filtrado desde el mes anterior y por ciclo de vida
forecast_orquest AS (
  SELECT
    DATE(fcst.from_ls) AS fecha,
    CAST(fcst.service_id AS STRING) AS service_id,
    fcst.business_id,
    mw.warehouse_name,
    mw.country_code,
    mw.country,
    fcst.measure,
    EXTRACT(HOUR FROM fcst.from_ls) AS hora,
    SUM(fcst.value) AS total_value
  FROM `peya-data-origins-pro.cl_orquest.measure_forecast` AS fcst
  INNER JOIN master_warehouses AS mw
    ON CAST(fcst.service_id AS STRING) = mw.warehouse_id
  WHERE fcst.measure IN ('units_out', 'tickets')
    AND DATE(fcst.from_ls) >= DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 1 MONTH)
    AND DATE(fcst.from_ls) >= COALESCE(mw.fecha_apertura, DATE(fcst.from_ls))
    AND DATE(fcst.from_ls) <= COALESCE(mw.fecha_cierre_definitiva, DATE(fcst.from_ls))
  GROUP BY 1, 2, 3, 4, 5, 6, 7, 8
),

-- 7. Consolidación diaria a nivel tienda eligiendo el mejor forecast local
base_store_agg AS (
  SELECT
    fcst.fecha,
    fcst.service_id,
    fcst.country_code,
    fcst.country,
    fcst.measure,
    SUM(manual.total_value) AS forecast_manual,
    SUM(fcst.total_value)   AS forecast_orquest,
    CASE
      WHEN SUM(manual.total_value) IS NOT NULL AND SUM(fcst.total_value) IS NOT NULL 
        THEN GREATEST(SUM(manual.total_value), SUM(fcst.total_value))
      ELSE COALESCE(SUM(manual.total_value), SUM(fcst.total_value))
    END AS forecast
  FROM forecast_orquest AS fcst
  LEFT JOIN forecast_manual AS manual
    ON fcst.service_id = manual.service_id
    AND fcst.measure = manual.measure
    AND fcst.fecha = manual.fecha
    AND fcst.hora = manual.hora
  GROUP BY 1, 2, 3, 4, 5
),

-- 8. Totales diarios consolidados por país (para tickets y units_out)
base_country_totals AS (
  SELECT
    fecha,
    UPPER(country_code) AS pais,
    country,
    measure,
    SUM(forecast_manual)  AS forecast_manual,
    SUM(forecast_orquest) AS forecast_orquest,
    SUM(forecast)         AS forecast
  FROM base_store_agg
  GROUP BY 1, 2, 3, 4
),

-- 9. Consolidado regional diario para toda la entidad 'LATAM' (tickets y units_out)
base_latam_totals AS (
  SELECT
    fecha,
    'LATAM' AS pais,
    'LATAM' AS country,
    measure,
    SUM(forecast_manual)  AS forecast_manual,
    SUM(forecast_orquest) AS forecast_orquest,
    SUM(forecast)         AS forecast
  FROM base_country_totals
  GROUP BY 1, 2, 3, 4
),

-- 10. Unión de totales por país y LATAM (para métricas base)
base_totals_combined AS (
  SELECT * FROM base_country_totals
  UNION ALL
  SELECT * FROM base_latam_totals
),

-- 11. Unión de métricas base con cálculo de basket size nacional y regional LATAM (units / tickets)
base_consolidada AS (
  SELECT
    fecha,
    pais,
    country,
    measure,
    forecast_manual,
    forecast_orquest,
    forecast
  FROM base_totals_combined

  UNION ALL

  SELECT
    fecha,
    pais,
    country,
    'basket_size' AS measure,
    SAFE_DIVIDE(
      SUM(CASE WHEN measure = 'units_out' THEN forecast_manual END),
      SUM(CASE WHEN measure = 'tickets' THEN forecast_manual END)
    ) AS forecast_manual,
    SAFE_DIVIDE(
      SUM(CASE WHEN measure = 'units_out' THEN forecast_orquest END),
      SUM(CASE WHEN measure = 'tickets' THEN forecast_orquest END)
    ) AS forecast_orquest,
    SAFE_DIVIDE(
      SUM(CASE WHEN measure = 'units_out' THEN forecast END),
      SUM(CASE WHEN measure = 'tickets' THEN forecast END)
    ) AS forecast
  FROM base_totals_combined
  GROUP BY 1, 2, 3
)

-- 12. Salida consolidada por país y LATAM con ponderación mensual diaria
SELECT
  fecha,
  pais,
  country,
  measure,
  forecast_manual,
  forecast_orquest,
  forecast,
  -- Ponderación del día respecto al total del mes por país/región y métrica
  SAFE_DIVIDE(
    forecast,
    SUM(forecast) OVER (PARTITION BY pais, measure, DATE_TRUNC(fecha, MONTH))
  ) AS ponderancia
FROM base_consolidada
WHERE fecha >= DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 1 MONTH)
ORDER BY fecha ASC, pais ASC, measure ASC;
