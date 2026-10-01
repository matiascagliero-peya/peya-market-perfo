-- Targets 2026 - Orquest Detalle Diario por WHS
-- Ventana de fechas: A partir del primer día del mes anterior al actual
-- Granularidad: 1 fila por (fecha, warehouse_id) y total LATAM con métricas en columnas

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
    MAX(dp.city.name)                   AS city,
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
    mw.city,
    mw.fecha_apertura,
    mw.fecha_cierre_definitiva,
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
  GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
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
    mw.city,
    mw.fecha_apertura,
    mw.fecha_cierre_definitiva,
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
  GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
),

-- 7. Consolidación diaria de métricas base
base_agg AS (
  SELECT
    fcst.fecha,
    fcst.service_id AS warehouse_id,
    fcst.warehouse_name,
    fcst.country_code,
    fcst.country AS pais,
    fcst.city AS ciudad,
    fcst.fecha_apertura,
    fcst.fecha_cierre_definitiva,
    fcst.measure,
    SUM(manual.total_value) AS forecast_manual,
    SUM(fcst.total_value)   AS forecast_orquest
  FROM forecast_orquest AS fcst
  LEFT JOIN forecast_manual AS manual
    ON fcst.service_id = manual.service_id
    AND fcst.measure = manual.measure
    AND fcst.fecha = manual.fecha
    AND fcst.hora = manual.hora
  GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9
),

-- 8. Detalle diario por WHS con métricas pivoteadas a columnas
whs_daily_pivot AS (
  SELECT
    fecha,
    country_code,
    pais,
    ciudad,
    warehouse_id,
    warehouse_name,
    fecha_apertura,
    fecha_cierre_definitiva,

    -- Tickets (Órdenes)
    SUM(CASE WHEN measure = 'tickets' THEN forecast_manual END)  AS tickets_manual,
    SUM(CASE WHEN measure = 'tickets' THEN forecast_orquest END) AS tickets_orquest,
    CASE
      WHEN SUM(CASE WHEN measure = 'tickets' THEN forecast_manual END) IS NOT NULL 
       AND SUM(CASE WHEN measure = 'tickets' THEN forecast_orquest END) IS NOT NULL 
        THEN GREATEST(
          SUM(CASE WHEN measure = 'tickets' THEN forecast_manual END), 
          SUM(CASE WHEN measure = 'tickets' THEN forecast_orquest END)
        )
      ELSE COALESCE(
        SUM(CASE WHEN measure = 'tickets' THEN forecast_manual END), 
        SUM(CASE WHEN measure = 'tickets' THEN forecast_orquest END)
      )
    END AS tickets_forecast,

    -- Unidades (Units Out)
    SUM(CASE WHEN measure = 'units_out' THEN forecast_manual END)  AS units_manual,
    SUM(CASE WHEN measure = 'units_out' THEN forecast_orquest END) AS units_orquest,
    CASE
      WHEN SUM(CASE WHEN measure = 'units_out' THEN forecast_manual END) IS NOT NULL 
       AND SUM(CASE WHEN measure = 'units_out' THEN forecast_orquest END) IS NOT NULL 
        THEN GREATEST(
          SUM(CASE WHEN measure = 'units_out' THEN forecast_manual END), 
          SUM(CASE WHEN measure = 'units_out' THEN forecast_orquest END)
        )
      ELSE COALESCE(
        SUM(CASE WHEN measure = 'units_out' THEN forecast_manual END), 
        SUM(CASE WHEN measure = 'units_out' THEN forecast_orquest END)
      )
    END AS units_forecast,

    -- Basket Size Manual y Orquest (Units / Tickets)
    SAFE_DIVIDE(
      SUM(CASE WHEN measure = 'units_out' THEN forecast_manual END),
      SUM(CASE WHEN measure = 'tickets' THEN forecast_manual END)
    ) AS basket_size_manual,

    SAFE_DIVIDE(
      SUM(CASE WHEN measure = 'units_out' THEN forecast_orquest END),
      SUM(CASE WHEN measure = 'tickets' THEN forecast_orquest END)
    ) AS basket_size_orquest

  FROM base_agg
  GROUP BY 1, 2, 3, 4, 5, 6, 7, 8
),

-- 9. Consolidado regional diario para toda la entidad 'LATAM'
latam_daily_pivot AS (
  SELECT
    fecha,
    'LATAM' AS country_code,
    'LATAM' AS pais,
    'LATAM' AS ciudad,
    'LATAM' AS warehouse_id,
    'LATAM' AS warehouse_name,
    CAST(NULL AS DATE) AS fecha_apertura,
    CAST(NULL AS DATE) AS fecha_cierre_definitiva,

    -- Tickets (Órdenes)
    SUM(tickets_manual)   AS tickets_manual,
    SUM(tickets_orquest)  AS tickets_orquest,
    SUM(tickets_forecast) AS tickets_forecast,

    -- Unidades (Units Out)
    SUM(units_manual)   AS units_manual,
    SUM(units_orquest)  AS units_orquest,
    SUM(units_forecast) AS units_forecast,

    -- Basket Size Manual y Orquest (Units / Tickets)
    SAFE_DIVIDE(SUM(units_manual), SUM(tickets_manual))   AS basket_size_manual,
    SAFE_DIVIDE(SUM(units_orquest), SUM(tickets_orquest)) AS basket_size_orquest

  FROM whs_daily_pivot
  GROUP BY 1
),

-- 10. Unión de detalle diario por tienda y consolidado LATAM
whs_daily_combined AS (
  SELECT * FROM whs_daily_pivot
  UNION ALL
  SELECT * FROM latam_daily_pivot
)

-- 11. Salida final con cálculo de basket size del forecast consolidado
SELECT
  fecha,
  UPPER(country_code) AS pais_codigo,
  pais,
  ciudad,
  warehouse_id,
  warehouse_name,
  fecha_apertura,
  fecha_cierre_definitiva,

  -- Tickets
  tickets_manual,
  tickets_orquest,
  tickets_forecast,

  -- Unidades
  units_manual,
  units_orquest,
  units_forecast,

  -- Basket Size (Units / Tickets)
  basket_size_manual,
  basket_size_orquest,
  SAFE_DIVIDE(units_forecast, tickets_forecast) AS basket_size_forecast

FROM whs_daily_combined
WHERE fecha >= DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 1 MONTH)
ORDER BY fecha ASC, pais_codigo ASC, warehouse_name ASC;
