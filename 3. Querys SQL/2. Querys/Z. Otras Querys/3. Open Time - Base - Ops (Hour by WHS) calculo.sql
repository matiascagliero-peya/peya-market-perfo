DECLARE query_name STRING DEFAULT '3. Open Time - Base - Ops (Hour by WHS)';

DECLARE inicio DATE DEFAULT DATE("2026-08-01");
DECLARE fin    DATE DEFAULT DATE("2026-08-31");

WITH
-- 1. Identificamos los partners con órdenes confirmadas por cada warehouse desde 2025
best_partners AS (
  SELECT
    warehouse_id,
    vendor_id,
    COUNT(DISTINCT order_id) AS orders,
    MAX(order_date) AS max_order_date,
    RANK() OVER (PARTITION BY warehouse_id ORDER BY MAX(order_date) DESC, COUNT(DISTINCT order_id) DESC) AS rnk
  FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
  WHERE order_date >= '2025-01-01'
    AND STATE = 'CONFIRMED'
  GROUP BY 1, 2
),

-- 2. Filtramos el partner número 1 (principal) de cada almacén físico asegurando tipo STRING para evitar problemas de tipos en el JOIN
top_vendors AS (
  SELECT
    CAST(warehouse_id AS STRING) AS warehouse_id,
    CAST(vendor_id AS STRING) AS vendor_id
  FROM best_partners
  WHERE rnk = 1
),

hourly_traffic_weight AS (
  SELECT 
    s.country_id, 
    s.city.city_id AS city_id, 
    s.partition_date,
    EXTRACT(HOUR FROM s.session_start_timestamp_local) AS hour_of_day,

    SAFE_DIVIDE(
      COUNT(DISTINCT CASE WHEN UPPER(sv.businessType) = 'MARKET' THEN s.session_id END),
      SUM(COUNT(DISTINCT CASE WHEN UPPER(sv.businessType) = 'MARKET' THEN s.session_id END)) OVER (PARTITION BY s.country_id, s.city.city_id, s.partition_date)
    ) AS hourly_weight_market

  FROM `peya-bi-tools-pro.il_sessions.fact_perseus_sessions` s
  LEFT JOIN `peya-bi-tools-pro.il_sessions.perseus_fact_sessions_funnel_by_verticals` sv
    ON s.session_sk = sv.session_sk 
   AND s.partition_date = sv.partition_date
  
  WHERE s.partition_date BETWEEN inicio AND fin 
    AND s.country_id IS NOT NULL
    AND NOT EXISTS (
      SELECT 1 
      FROM `peya-bi-tools-pro.il_qcommerce.fact_sessions_double_ya` dy
      WHERE s.session_id = dy.session_id
        AND dy.date = s.partition_date
        AND dy.dy_loaded IS TRUE
    )
  GROUP BY 1, 2, 3, 4
),

partner_schedule AS (
  SELECT
    fpt.partner_id,
    fpt.partner_time_date AS date_val,
    fpt.partner_time_hour AS hour_val,
    SUM(fpt.times) AS minutes_scheduled,
    SUM(CASE WHEN fpt.state = 'CLOSED' THEN fpt.times ELSE 0 END) AS minutes_closed_total
  FROM `peya-bi-tools-pro.il_core.agg_fact_partner_times` fpt
  WHERE fpt.partner_time_date BETWEEN inicio AND fin
  GROUP BY 1, 2, 3
),

-- Calculamos las fechas operativas reales (primera orden y última orden confirmada) a nivel de Warehouse Físico (WHS)
whs_fechas_operativas AS (
  SELECT
    par.warehouse_id AS warehouse_id,
    MIN(DATE(fo.registered_date)) AS fecha_apertura,
    MAX(DATE(fo.registered_date)) AS fecha_ultima_orden
  FROM `peya-bi-tools-pro.il_core.fact_orders` fo
  INNER JOIN `peya-bi-tools-pro.il_core.dim_partner` par 
    ON fo.restaurant.id = par.partner_id
  WHERE fo.order_status = 'CONFIRMED'
    AND fo.registered_date >= '2020-01-01'
    AND par.warehouse_id IS NOT NULL
  GROUP BY 1
),

-- Determinamos el estado definitivo de 'is_online' actual y el último día online por partner principal
partner_online_status AS (
  SELECT
    tv.warehouse_id,
    tv.vendor_id,
    -- Estado en el último snapshot diario registrado para este partner
    ARRAY_AGG(hp.is_online ORDER BY SAFE_CAST(hp.yyyymmdd AS DATE) DESC LIMIT 1)[OFFSET(0)] AS is_online_actual,
    -- Último día en el que el local estuvo ONLINE (abierto al público)
    MAX(CASE WHEN hp.is_online IS TRUE THEN SAFE_CAST(hp.yyyymmdd AS DATE) END) AS fecha_ultimo_dia_online
  FROM top_vendors tv
  INNER JOIN `peya-bi-tools-pro.il_core.dim_historical_partners` hp
    ON CAST(hp.restaurant_id AS STRING) = tv.vendor_id
  WHERE hp.is_darkstore IS TRUE
  GROUP BY 1, 2
),

-- Agrupamos la planificación horaria directamente a nivel del almacén físico (WHS)
warehouse_hourly_schedule AS (
  SELECT
    sch.date_val                          AS fecha,
    sch.hour_val                          AS hora,
    par.warehouse_id                      AS warehouse_id,
    MAX(par.warehouse_name)               AS warehouse_name,
    MAX(par.country.country_name)         AS pais,
    MAX(par.city.name)                    AS ciudad,
    MAX(par.country_id)                   AS country_id,
    MAX(par.city.id)                      AS city_id,

    -- Minutos programados y cerrados del partner principal del warehouse (simplificado para un único partner)
    MAX(sch.minutes_scheduled)            AS minutos_programados,
    MAX(COALESCE(sch.minutes_closed_total, 0)) AS minutos_cerrados_efectivos,

    -- Fecha de apertura real del almacén (mínima fecha de apertura a nivel de WHS)
    MIN(fo_dates.fecha_apertura)          AS fecha_apertura,

    -- Fecha de cierre definitiva:
    -- Si el almacén sigue vendiendo (órdenes en los últimos 3 días o posteriores al fin del período consultado), sigue abierto (NULL).
    -- Si ya no registra órdenes (cese de ventas por cierre), corta exactamente el día en que ya no hubo órdenes / online.
    CASE 
      WHEN MAX(fo_dates.fecha_ultima_orden) >= CURRENT_DATE() - 3 
        OR MAX(fo_dates.fecha_ultima_orden) >= fin THEN NULL
      ELSE LEAST(
        MAX(fo_dates.fecha_ultima_orden),
        COALESCE(MAX(pos.fecha_ultimo_dia_online), MAX(fo_dates.fecha_ultima_orden))
      )
    END                                   AS fecha_cierre_definitiva

  FROM partner_schedule sch
  JOIN `peya-bi-tools-pro.il_core.dim_partner` par
    ON sch.partner_id = par.partner_id
  INNER JOIN `peya-datamarts-pro.dm_dmarts.dim_partner_darkstore` pd
    ON par.partner_id = pd.partner_id
  -- =========================================================================
  -- UNIÓN CLAVE: Filtramos para que solo entren los horarios del partner principal (top vendor)
  -- =========================================================================
  INNER JOIN top_vendors tv 
    ON CAST(par.partner_id AS STRING) = tv.vendor_id 
   AND CAST(par.warehouse_id AS STRING) = tv.warehouse_id
  LEFT JOIN whs_fechas_operativas fo_dates
    ON par.warehouse_id = fo_dates.warehouse_id
  LEFT JOIN partner_online_status pos
    ON tv.warehouse_id = pos.warehouse_id
   AND tv.vendor_id = pos.vendor_id

  WHERE par.is_darkstore IS TRUE
    AND par.business_type.business_type_name = "Market"
    AND par.business_type.business_type_name NOT IN ('Courier', 'Courier Business')
    AND par.warehouse_id IS NOT NULL
    AND SAFE_CAST(REGEXP_EXTRACT(CAST(par.warehouse_id AS STRING), r'\d+') AS INT64) IS NOT NULL
  GROUP BY 1, 2, 3
)

SELECT
  whs.fecha                             AS fecha,
  whs.hora                              AS hora,
  whs.warehouse_id                      AS warehouse_id,
  whs.warehouse_name                    AS warehouse_name,
  whs.pais                              AS pais,
  whs.ciudad                            AS ciudad,

  whs.minutos_programados               AS minutos_programados,
  whs.minutos_cerrados_efectivos        AS minutos_cerrados_efectivos,

  SAFE_DIVIDE(
    whs.minutos_programados - whs.minutos_cerrados_efectivos,
    whs.minutos_programados
  )                                     AS share_disponibilidad_hora,

  COALESCE(trf.hourly_weight_market, 0) AS peso_trafico_hora,

  SAFE_DIVIDE(
    whs.minutos_programados - whs.minutos_cerrados_efectivos,
    whs.minutos_programados
  ) * COALESCE(trf.hourly_weight_market, 0) AS disponibilidad_ponderada_hora

FROM warehouse_hourly_schedule whs
LEFT JOIN hourly_traffic_weight trf
  ON whs.country_id = trf.country_id
 AND whs.city_id = trf.city_id
 AND whs.fecha  = trf.partition_date
 AND whs.hora  = trf.hour_of_day

WHERE whs.minutos_programados > 0
  AND whs.fecha >= COALESCE(whs.fecha_apertura, whs.fecha)
  -- Corta exactamente el día que ya no está activo / no hay órdenes (excluye cualquier minuto posterior al cierre)
  AND whs.fecha <= COALESCE(whs.fecha_cierre_definitiva, whs.fecha)
ORDER BY fecha, warehouse_id, hora;
