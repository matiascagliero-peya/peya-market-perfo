-- =========================================================================
-- CONTROL DEFINITIVO DE APERTURAS Y CIERRES DE WAREHOUSES (WHS)
-- DETERMINACIÓN DEFINITIVA DE CIERRE/APERTURA MEDIANTE 'is_online'
-- DEL PARTNER PRINCIPAL EN dim_historical_partners
-- =========================================================================
DECLARE query_name STRING DEFAULT 'Aperturas y cierres whs.sql';

WITH
-- 1. Identificamos el partner principal (top_vendor) de cada almacén por órdenes confirmadas
best_partners AS (
  SELECT
    warehouse_id,
    vendor_id,
    COUNT(DISTINCT order_id) AS orders,
    MAX(order_date) AS max_order_date,
    RANK() OVER (PARTITION BY warehouse_id ORDER BY COUNT(DISTINCT order_id) DESC, MAX(order_date) DESC) AS rnk
  FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
  WHERE order_date >= '2025-01-01'
    AND STATE = 'CONFIRMED'
    -- Descomentar la siguiente línea si deseas filtrar solo por Maschwitz para pruebas:
    -- AND (CAST(warehouse_id AS STRING) = '94a0020a-1fff-4a3e-b636-ea65d86995d9' OR CAST(vendor_id AS STRING) = '276152')
  GROUP BY 1, 2
),

top_vendors AS (
  SELECT
    CAST(warehouse_id AS STRING) AS warehouse_id,
    CAST(vendor_id AS STRING) AS vendor_id
  FROM best_partners
  WHERE rnk = 1
),

-- 2. CTE idéntico al de la query '3. Open Time - Base - Ops' para calcular la fecha de apertura real (primer pedido)
whs_apertura AS (
  SELECT
    par.warehouse_id AS warehouse_id,
    MIN(DATE(fo.registered_date)) AS fecha_apertura
  FROM `peya-bi-tools-pro.il_core.fact_orders` fo
  INNER JOIN `peya-bi-tools-pro.il_core.dim_partner` par 
    ON fo.restaurant.id = par.partner_id
  WHERE fo.order_status = 'CONFIRMED'
    AND fo.registered_date >= '2020-01-01'
    AND par.warehouse_id IS NOT NULL
  GROUP BY 1
),

-- 3. Última venta confirmada del partner principal
whs_ultima_orden AS (
  SELECT
    tv.warehouse_id,
    MAX(DATE(fo.registered_date)) AS fecha_ultima_orden
  FROM `peya-bi-tools-pro.il_core.fact_orders` fo
  INNER JOIN top_vendors tv
    ON CAST(fo.restaurant.id AS STRING) = tv.vendor_id
  WHERE fo.order_status = 'CONFIRMED'
    AND fo.registered_date >= '2020-01-01'
  GROUP BY 1
),

-- 4. CRITERIO DEFINITIVO: Historial de 'is_online' e 'is_active' en dim_historical_partners
partner_online_history AS (
  SELECT
    tv.warehouse_id,
    tv.vendor_id,
    
    -- Estado en el último snapshot diario registrado para este partner
    ARRAY_AGG(hp.is_online ORDER BY SAFE_CAST(hp.yyyymmdd AS DATE) DESC LIMIT 1)[OFFSET(0)] AS is_online_actual,
    ARRAY_AGG(hp.is_active ORDER BY SAFE_CAST(hp.yyyymmdd AS DATE) DESC LIMIT 1)[OFFSET(0)] AS is_active_actual,
    
    -- Último día en el que el local estuvo ONLINE (abierto al público)
    MAX(CASE WHEN hp.is_online IS TRUE THEN SAFE_CAST(hp.yyyymmdd AS DATE) END) AS fecha_ultimo_dia_online,
    
    -- Último día en que figuró activo administrativamente
    MAX(CASE WHEN hp.is_active IS TRUE THEN SAFE_CAST(hp.yyyymmdd AS DATE) END) AS fecha_ultimo_dia_activo
    
  FROM top_vendors tv
  INNER JOIN `peya-bi-tools-pro.il_core.dim_historical_partners` hp
    ON CAST(hp.restaurant_id AS STRING) = tv.vendor_id
  WHERE hp.is_darkstore IS TRUE
    AND hp.yyyymmdd >= '2023-01-01'
  GROUP BY 1, 2
),

-- 5. Catálogo maestro de WHS
whs_catalog AS (
  SELECT
    tv.warehouse_id                       AS warehouse_id,
    MAX(par.warehouse_name)               AS warehouse_name,
    MAX(par.country.country_name)         AS pais,
    MAX(par.city.name)                    AS ciudad,
    MAX(par.partner_name)                 AS partner_principal_name,
    MAX(tv.vendor_id)                     AS partner_principal_id,
    
    MIN(ap.fecha_apertura)                AS fecha_apertura_open_time,
    MIN(uo.fecha_ultima_orden)            AS fecha_ultimo_pedido_real,
    
    MAX(poh.is_online_actual)             AS is_online_actual,
    MAX(poh.is_active_actual)             AS is_active_actual,
    MAX(poh.fecha_ultimo_dia_online)      AS fecha_ultimo_dia_online,
    MAX(poh.fecha_ultimo_dia_activo)      AS fecha_ultimo_dia_activo

  FROM top_vendors tv
  INNER JOIN `peya-bi-tools-pro.il_core.dim_partner` par
    ON CAST(par.partner_id AS STRING) = tv.vendor_id 
   AND CAST(par.warehouse_id AS STRING) = tv.warehouse_id
  INNER JOIN `peya-datamarts-pro.dm_dmarts.dim_partner_darkstore` pd
    ON par.partner_id = pd.partner_id
  LEFT JOIN whs_apertura ap
    ON tv.warehouse_id = ap.warehouse_id
  LEFT JOIN whs_ultima_orden uo
    ON tv.warehouse_id = uo.warehouse_id
  LEFT JOIN partner_online_history poh
    ON tv.warehouse_id = poh.warehouse_id
   AND tv.vendor_id = poh.vendor_id

  WHERE par.is_darkstore IS TRUE
    AND par.business_type.business_type_name = "Market"
    AND par.business_type.business_type_name NOT IN ('Courier', 'Courier Business')
    AND par.warehouse_id IS NOT NULL
    AND SAFE_CAST(REGEXP_EXTRACT(CAST(par.warehouse_id AS STRING), r'\d+') AS INT64) IS NOT NULL
  GROUP BY 1
)

SELECT
  warehouse_id,
  warehouse_name,
  pais,
  ciudad,
  partner_principal_id,
  partner_principal_name,
  
  -- ESTADO DEFINITIVO ACTUAL:
  -- Si is_online_actual es TRUE -> El WHS está ABIERTO hoy.
  -- Si is_online_actual es FALSE -> El WHS está CERRADO.
  COALESCE(is_online_actual, FALSE) AS esta_abierto_actualmente,
  COALESCE(is_active_actual, FALSE) AS is_active_sistema_actual,
  
  -- APERTURA (100% fiel a Open Time)
  fecha_apertura_open_time,
  
  -- CIERRE OPERATIVO DEFINITIVO:
  -- Si hoy no está online (cerrado), la fecha de cierre es el último día en que estuvo ONLINE.
  -- Si hoy está abierto (online = true), no tiene fecha de cierre (NULL).
  CASE 
    WHEN NOT COALESCE(is_online_actual, FALSE) THEN fecha_ultimo_dia_online
    ELSE NULL 
  END AS fecha_cierre_definitiva,
  
  -- Datos de validación y control:
  fecha_ultimo_pedido_real,
  fecha_ultimo_dia_online,
  fecha_ultimo_dia_activo AS fecha_ultimo_dia_activo_administrativo

FROM whs_catalog
ORDER BY pais, ciudad, warehouse_name;
