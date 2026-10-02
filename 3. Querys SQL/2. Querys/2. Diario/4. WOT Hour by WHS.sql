DECLARE query_name STRING DEFAULT '4. WOT Hour by WHS.sql';

-- ====================================================================================
-- wot_hour_by_whs (INCREMENTAL AUTO-REPARABLE · 2026 BACKFILL & RECOVERY)
--   • No existe (o vacía) -> backfill histórico completo desde 2026-01-01 hasta ayer (D-1).
--   • Existe              -> recupera automáticamente desde la última fecha con datos
--                            (max_fecha) hasta ayer (D-1), evitando cualquier hueco si
--                            no se corre a diario.
-- ====================================================================================

DECLARE inicio       DATE;
DECLARE fin          DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);
DECLARE table_exists BOOL DEFAULT FALSE;
DECLARE max_fecha    DATE;

-- 1. Verificamos si la tabla ya existe físicamente en el dataset
SET table_exists = (
  SELECT COUNT(1) > 0
  FROM `peya-food-and-groceries.automated_tables_reports`.INFORMATION_SCHEMA.TABLES
  WHERE table_name = 'wot_hour_by_whs'
);

IF table_exists THEN
  -- Obtenemos la última fecha registrada en la tabla
  SET max_fecha = (
    SELECT MAX(fecha)
    FROM `peya-food-and-groceries.automated_tables_reports.wot_hour_by_whs`
  );

  -- Si la tabla existe pero no tiene registros, la tratamos como inexistente para hacer backfill
  IF max_fecha IS NULL THEN
    SET table_exists = FALSE;
  END IF;
END IF;

-- 2. Determinación dinámica de la ventana de fechas (Auto-Healing):
--    • Si NO existe (o vacía) -> desde 2026-01-01 hasta ayer (D-1).
--    • Si SÍ existe          -> desde la última fecha registrada (max_fecha) hasta ayer (D-1).
--      - Si se corre a diario: max_fecha = D-1, por lo que solo recarga el último día.
--      - Si no se corrió por varios días: arranca desde max_fecha y recupera todos los días sin perder datos.
IF NOT table_exists THEN
  SET inicio = DATE '2026-01-01';
ELSE
  SET inicio = GREATEST(DATE '2026-01-01', LEAST(max_fecha, fin));
END IF;

-- ====================================================================================
-- 3. CREACIÓN DE LA TABLA (SI NO EXISTE) CON SCHEMA, PARTICIÓN Y CLUSTER
-- ====================================================================================
CREATE TABLE IF NOT EXISTS `peya-food-and-groceries.automated_tables_reports.wot_hour_by_whs` (
  fecha                          DATE     OPTIONS(description="Fecha operativa del registro."),
  hora                           INT64    OPTIONS(description="Hora del día (0 a 23)."),
  warehouse_id                   STRING   OPTIONS(description="Identificador del Warehouse físico."),
  warehouse_name                 STRING   OPTIONS(description="Nombre descriptivo del Warehouse físico."),
  pais                           STRING   OPTIONS(description="Nombre del país."),
  ciudad                         STRING   OPTIONS(description="Nombre de la ciudad del warehouse."),
  minutos_programados            INT64    OPTIONS(description="Minutos programados u operativos en la hora."),
  minutos_cerrados_efectivos     INT64    OPTIONS(description="Minutos cerrados efectivos durante la hora."),
  share_disponibilidad_hora      FLOAT64  OPTIONS(description="Share de disponibilidad simple: (programados - cerrados) / programados."),
  peso_trafico_hora              FLOAT64  OPTIONS(description="Peso de tráfico de sesiones Market de la ciudad/país en esa hora."),
  disponibilidad_ponderada_hora  FLOAT64  OPTIONS(description="Disponibilidad ponderada: disponibilidad horaria * peso de tráfico.")
)
PARTITION BY fecha
CLUSTER BY pais, warehouse_id, hora;

-- ====================================================================================
-- 4. LIMPIEZA DE LOS DÍAS A REFRESCAR (REFRESCO INCREMENTAL O BACKFILL)
-- ====================================================================================
DELETE FROM `peya-food-and-groceries.automated_tables_reports.wot_hour_by_whs`
WHERE fecha BETWEEN inicio AND fin;

-- ====================================================================================
-- 5. INSERCIÓN DEL CÁLCULO HORARIO POR WAREHOUSE ACTUALIZADO
-- ====================================================================================
INSERT INTO `peya-food-and-groceries.automated_tables_reports.wot_hour_by_whs` (
  fecha,
  hora,
  warehouse_id,
  warehouse_name,
  pais,
  ciudad,
  minutos_programados,
  minutos_cerrados_efectivos,
  share_disponibilidad_hora,
  peso_trafico_hora,
  disponibilidad_ponderada_hora
)
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

-- 2. Filtramos el partner número 1 (principal) de cada almacén físico asegurando tipo STRING
top_vendors AS (
  SELECT
    CAST(warehouse_id AS STRING) AS warehouse_id,
    CAST(vendor_id AS STRING) AS vendor_id
  FROM best_partners
  WHERE rnk = 1
),

-- 3. Pesos de tráfico horario de mercado por ciudad/país
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

-- 4. Minutos planificados y cerrados de agg_fact_partner_times
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

-- 5. Calculamos las fechas operativas reales (primera orden y última orden confirmada) a nivel de Warehouse Físico (WHS)
whs_fechas_operativas AS (
  SELECT
    CAST(par.warehouse_id AS STRING) AS warehouse_id,
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

-- 6. Determinamos el estado definitivo de 'is_online' actual y el último día online por partner principal
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

-- 7. Agrupamos la planificación horaria directamente a nivel del almacén físico (WHS)
warehouse_hourly_schedule AS (
  SELECT
    sch.date_val                          AS fecha,
    sch.hour_val                          AS hora,
    CAST(par.warehouse_id AS STRING)      AS warehouse_id,
    MAX(par.warehouse_name)               AS warehouse_name,
    MAX(
      CASE 
        WHEN par.country.country_name IN ('República Dominicana', 'Republic Dominican', 'Dominican Republic') THEN 'Republica Dominicana'
        ELSE par.country.country_name 
      END
    )                                     AS pais,
    MAX(par.city.name)                    AS ciudad,
    MAX(par.country_id)                   AS country_id,
    MAX(par.city.id)                      AS city_id,

    -- Minutos programados y cerrados del partner principal del warehouse
    MAX(sch.minutes_scheduled)            AS minutos_programados,
    LEAST(MAX(sch.minutes_scheduled), MAX(COALESCE(sch.minutes_closed_total, 0))) AS minutos_cerrados_efectivos,

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
    ON CAST(par.warehouse_id AS STRING) = fo_dates.warehouse_id
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
  AND whs.fecha <= COALESCE(whs.fecha_cierre_definitiva, whs.fecha);
