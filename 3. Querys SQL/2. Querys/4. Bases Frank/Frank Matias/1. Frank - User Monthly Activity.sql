-- ==============================================================================
-- TABLA 1: Frank - User Monthly Activity (Pipeline Incremental DELETE + INSERT)
-- Destino: peya-food-and-groceries.automated_tables_reports.frank_user_monthly_activity
-- ==============================================================================

DECLARE v_reload_start_date DATE;

-- 1. Crear tabla con partición y clusters si aún no existe (idempotente)
CREATE TABLE IF NOT EXISTS `peya-food-and-groceries.automated_tables_reports.frank_user_monthly_activity` (
    month DATE OPTIONS(description = 'Primer día del mes de actividad analizado (grano temporal y clave de partición)'),
    customer_id STRING OPTIONS(description = 'Identificador único del usuario (cliente)'),
    country STRING OPTIONS(description = 'País donde se ejecutaron las transacciones en el mes'),
    is_active_platform BOOL OPTIONS(description = 'Flag: TRUE si realizó al menos 1 orden confirmada en la aplicación en el mes'),
    is_active_food BOOL OPTIONS(description = 'Flag: TRUE si compró en Restaurantes (excluye Peya Market y Supermercados AAA)'),
    is_active_aaa BOOL OPTIONS(description = 'Flag: TRUE si compró en Supermercados retail de terceros (partners AAA)'),
    is_active_dmart BOOL OPTIONS(description = 'Flag: TRUE si compró en Peya Market (Darkstores propios)'),
    orders_platform INT64 OPTIONS(description = 'Cantidad total de órdenes confirmadas en toda la app en el mes'),
    orders_dmart INT64 OPTIONS(description = 'Cantidad total de órdenes confirmadas en Peya Market en el mes'),
    orders_uf_dmart INT64 OPTIONS(description = 'Cantidad de órdenes confirmadas en Peya Market con al menos 1 ítem Ultra Fresh (Produce, Carnes, Pescados o Ready to Eat)'),
    orders_dy_dmart INT64 OPTIONS(description = 'Cantidad de órdenes confirmadas en Peya Market realizadas a través de Double Ya (DY)'),
    units_sold_dmart INT64 OPTIONS(description = 'Cantidad total de unidades de productos compradas en Peya Market en el mes'),
    net_sales_dmart_eur FLOAT64 OPTIONS(description = 'Venta neta total con descuentos en euros generada en Peya Market en el mes'),
    DY_order STRING OPTIONS(description = 'Segmentación mensual del uso de Double Ya en Market: Sin compras, Solo DY, No DY, DY y No DY'),
    UF_order STRING OPTIONS(description = 'Segmentación mensual de compra Ultra Fresh en Market: Sin compras, Solo UF, No UF, UF y No UF')
)
PARTITION BY month
CLUSTER BY country, customer_id;

-- 2. Ventana de recarga: últimos 2 meses si hay datos, o histórico desde 2020 si está vacía
SET v_reload_start_date = (
    SELECT DATE_SUB(MAX(month), INTERVAL 1 MONTH)
    FROM `peya-food-and-groceries.automated_tables_reports.frank_user_monthly_activity`
);

IF v_reload_start_date IS NULL THEN
    SET v_reload_start_date = DATE '2020-01-01';
END IF;

-- 3. Limpiar la ventana de recarga para evitar duplicados
DELETE FROM `peya-food-and-groceries.automated_tables_reports.frank_user_monthly_activity`
WHERE month >= v_reload_start_date;

-- 4. Inserción incremental calculada
INSERT INTO `peya-food-and-groceries.automated_tables_reports.frank_user_monthly_activity`
WITH

-- A. Darkstores oficiales (Peya Market)
darkstores AS (
    SELECT DISTINCT partner_id
    FROM `peya-bi-tools-pro.il_core.dim_partner`
    WHERE is_darkstore = TRUE
),

-- B. Supermercados retail de terceros (AAA)
partners_aaa AS (
    SELECT DISTINCT
        COALESCE(cp.partner_id, t.partner_id) AS partner_id
    FROM `peya-data-origins-pro.cl_qcommerce.partners_aaa` cp
    FULL JOIN `peya-food-and-groceries.automated_tables_reports.partners_aaa_temporary` t
        ON t.partner_ID = cp.partner_id
),

-- C. Agregación a nivel SKU de Peya Market (Venta neta, unidades y Ultra Fresh)
market_orders_agg AS (
    SELECT
        CAST(order_id AS STRING) AS order_id,
        LOGICAL_OR(master_category_parent_english IN ('Produce', 'Meat / Seafood', 'Ready To Consume')) AS is_uf,
        SUM(fulfilled_quantity) AS units_sold,
        SUM(total_amount_net_with_discount_eur) AS net_sales_eur
    FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
    WHERE state = 'CONFIRMED'
      AND order_date >= v_reload_start_date
    GROUP BY 1
),

-- D. Órdenes Double Ya
dy_orders AS (
    SELECT DISTINCT dy.order_details.id.secondary AS order_id
    FROM `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya` dy
    WHERE dy.order_type = 'DOUBLE_YA'
),

-- E. Consolidación mensual de órdenes, actividad, ventas y unidades por usuario
monthly_raw AS (
    SELECT
        CAST(fo.customer_id AS STRING) AS customer_id,
        fo.country.country_name AS country,
        DATE_TRUNC(fo.registered_date, MONTH) AS month,

        -- Actividad (Platform -> Food -> AAA -> Dmart)
        TRUE AS is_active_platform,
        LOGICAL_OR(fo.business_type.business_type_name = 'Restaurant' AND ds.partner_id IS NULL AND aaa.partner_id IS NULL) AS is_active_food,
        LOGICAL_OR(aaa.partner_id IS NOT NULL AND ds.partner_id IS NULL) AS is_active_aaa,
        LOGICAL_OR(ds.partner_id IS NOT NULL) AS is_active_dmart,

        -- 2. Órdenes
        COUNT(DISTINCT fo.order_id) AS orders_platform,
        COUNT(DISTINCT IF(ds.partner_id IS NOT NULL, fo.order_id, NULL)) AS orders_dmart,
        COUNT(DISTINCT IF(ds.partner_id IS NOT NULL AND mo.is_uf, fo.order_id, NULL)) AS orders_uf_dmart,
        COUNT(DISTINCT IF(ds.partner_id IS NOT NULL AND dy.order_id IS NOT NULL, fo.order_id, NULL)) AS orders_dy_dmart,

        -- Unidades y Venta Neta (Dmart)
        SUM(IF(ds.partner_id IS NOT NULL, COALESCE(CAST(mo.units_sold AS INT64), 0), 0)) AS units_sold_dmart,
        ROUND(SUM(IF(ds.partner_id IS NOT NULL, COALESCE(mo.net_sales_eur, 0), 0)), 2) AS net_sales_dmart_eur,

        -- Atributos de canasta
        LOGICAL_OR(ds.partner_id IS NOT NULL AND dy.order_id IS NOT NULL) AS has_dy_order,
        LOGICAL_OR(ds.partner_id IS NOT NULL AND dy.order_id IS NULL)     AS has_non_dy_order,
        LOGICAL_OR(ds.partner_id IS NOT NULL AND mo.is_uf)                AS has_uf_order,
        LOGICAL_OR(ds.partner_id IS NOT NULL AND (mo.is_uf IS NULL OR NOT mo.is_uf)) AS has_non_uf_order

    FROM `peya-bi-tools-pro.il_core.fact_orders` fo
    LEFT JOIN darkstores ds ON fo.restaurant.id = ds.partner_id
    LEFT JOIN partners_aaa aaa ON fo.restaurant.id = aaa.partner_id
    LEFT JOIN dy_orders dy ON fo.order_id = dy.order_id
    LEFT JOIN market_orders_agg mo ON CAST(fo.order_id AS STRING) = mo.order_id
    WHERE fo.registered_date >= v_reload_start_date
      AND fo.order_status = 'CONFIRMED'
      AND fo.customer_id IS NOT NULL
      AND fo.country.country_name IS NOT NULL
    GROUP BY 1, 2, 3
)

-- F. Selección final estructurada
SELECT
    month,                  -- Primer día del mes analizado
    customer_id,            -- ID único del cliente
    country,                -- País de las transacciones
    is_active_platform,     -- Activo en la plataforma (>= 1 orden en cualquier vertical)
    is_active_food,         -- Activo en Restaurantes
    is_active_aaa,          -- Activo en Supermercados AAA de terceros
    is_active_dmart,        -- Activo en Peya Market (Darkstores)
    orders_platform,        -- Total de órdenes en toda la app
    orders_dmart,           -- Total de órdenes en Peya Market
    orders_uf_dmart,        -- Órdenes en Peya Market con ítems Ultra Fresh
    orders_dy_dmart,        -- Órdenes en Peya Market originadas por Double Ya
    units_sold_dmart,       -- Unidades totales de producto vendidas en Peya Market
    net_sales_dmart_eur,    -- Venta neta con descuentos en EUR en Peya Market

    -- Segmentación Double Ya
    CASE
        WHEN has_dy_order AND has_non_dy_order THEN 'DY y No DY'
        WHEN has_dy_order THEN 'Solo DY'
        ELSE 'No DY'
    END AS DY_order,

    -- Segmentación Ultra Fresh
    CASE
        WHEN has_uf_order AND has_non_uf_order THEN 'UF y No UF'
        WHEN has_uf_order THEN 'Solo UF'
        ELSE 'No UF'
    END AS UF_order

FROM monthly_raw;
