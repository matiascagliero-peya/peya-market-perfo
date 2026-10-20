-- ==============================================================================
-- TABLA 1: Frank - User Monthly Activity (Pipeline Auto-Incremental)
-- Destino: peya-food-and-groceries.automated_tables_reports.frank_user_monthly_activity
-- ==============================================================================

DECLARE v_table_exists BOOL DEFAULT FALSE;
DECLARE v_reload_start_date DATE;

-- 0. Detección de existencia de tabla previa
SET v_table_exists = (
    SELECT COUNT(1) > 0 
    FROM `peya-food-and-groceries.automated_tables_reports.INFORMATION_SCHEMA.TABLES` 
    WHERE table_name = 'frank_user_monthly_activity'
);

IF NOT v_table_exists THEN

    -- ==========================================================================
    -- CREACIÓN COMPLETA (Desde 2020)
    -- ==========================================================================
    SET v_reload_start_date = DATE '2020-01-01';

    CREATE TABLE `peya-food-and-groceries.automated_tables_reports.frank_user_monthly_activity`
    PARTITION BY month
    CLUSTER BY country, customer_id AS

    WITH

    -- 1. Darkstores oficiales (Peya Market)
    darkstores AS (
        SELECT DISTINCT partner_id
        FROM `peya-bi-tools-pro.il_core.dim_partner`
        WHERE is_darkstore = TRUE
    ),

    -- 2. Supermercados retail de terceros (AAA)
    partners_aaa AS (
        SELECT DISTINCT
            COALESCE(cp.partner_id, t.partner_id) AS partner_id
        FROM `peya-data-origins-pro.cl_qcommerce.partners_aaa` cp
        FULL JOIN `peya-food-and-groceries.automated_tables_reports.partners_aaa_temporary` t
            ON t.partner_ID = cp.partner_id
    ),

    -- 3. Agregación a nivel SKU de Peya Market (Venta neta, unidades y Ultra Fresh)
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

    -- 4. Órdenes Double Ya
    dy_orders AS (
        SELECT DISTINCT dy.order_details.id.secondary AS order_id
        FROM `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya` dy
        WHERE dy.order_type = 'DOUBLE_YA'
    ),

    -- 5. Consolidación mensual de órdenes, actividad, ventas y unidades por usuario
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

    -- 6. Selección final estructurada
    SELECT
        month,
        customer_id,
        country,
        is_active_platform,
        is_active_food,
        is_active_aaa,
        is_active_dmart,
        orders_platform,
        orders_dmart,
        orders_uf_dmart,
        orders_dy_dmart,
        units_sold_dmart,
        net_sales_dmart_eur,

        CASE
            WHEN NOT is_active_dmart THEN 'Sin compras'
            WHEN has_dy_order AND has_non_dy_order THEN 'DY y No DY'
            WHEN has_dy_order THEN 'Solo DY'
            WHEN has_non_dy_order THEN 'No DY'
            ELSE 'Sin compras'
        END AS DY_order,

        CASE
            WHEN NOT is_active_dmart THEN 'Sin compras'
            WHEN has_uf_order AND has_non_uf_order THEN 'UF y No UF'
            WHEN has_uf_order THEN 'Solo UF'
            WHEN has_non_uf_order THEN 'No UF'
            ELSE 'Sin compras'
        END AS UF_order

    FROM monthly_raw;

ELSE

    -- ==========================================================================
    -- RECARGA INCREMENTAL (Últimos dos meses)
    -- ==========================================================================
    SET v_reload_start_date = (
        SELECT DATE_SUB(MAX(month), INTERVAL 1 MONTH)
        FROM `peya-food-and-groceries.automated_tables_reports.frank_user_monthly_activity`
    );

    IF v_reload_start_date IS NULL THEN
        SET v_reload_start_date = DATE '2020-01-01';
    END IF;

    DELETE FROM `peya-food-and-groceries.automated_tables_reports.frank_user_monthly_activity`
    WHERE month >= v_reload_start_date;

    INSERT INTO `peya-food-and-groceries.automated_tables_reports.frank_user_monthly_activity`
    WITH

    -- 1. Darkstores oficiales (Peya Market)
    darkstores AS (
        SELECT DISTINCT partner_id
        FROM `peya-bi-tools-pro.il_core.dim_partner`
        WHERE is_darkstore = TRUE
    ),

    -- 2. Supermercados retail de terceros (AAA)
    partners_aaa AS (
        SELECT DISTINCT
            COALESCE(cp.partner_id, t.partner_id) AS partner_id
        FROM `peya-data-origins-pro.cl_qcommerce.partners_aaa` cp
        FULL JOIN `peya-food-and-groceries.automated_tables_reports.partners_aaa_temporary` t
            ON t.partner_ID = cp.partner_id
    ),

    -- 3. Agregación a nivel SKU de Peya Market (Venta neta, unidades y Ultra Fresh)
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

    -- 4. Órdenes Double Ya
    dy_orders AS (
        SELECT DISTINCT dy.order_details.id.secondary AS order_id
        FROM `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya` dy
        WHERE dy.order_type = 'DOUBLE_YA'
    ),

    -- 5. Consolidación mensual de órdenes, actividad, ventas y unidades por usuario
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

    -- 6. Selección final estructurada
    SELECT
        month,
        customer_id,
        country,
        is_active_platform,
        is_active_food,
        is_active_aaa,
        is_active_dmart,
        orders_platform,
        orders_dmart,
        orders_uf_dmart,
        orders_dy_dmart,
        units_sold_dmart,
        net_sales_dmart_eur,

        CASE
            WHEN NOT is_active_dmart THEN 'Sin compras'
            WHEN has_dy_order AND has_non_dy_order THEN 'DY y No DY'
            WHEN has_dy_order THEN 'Solo DY'
            WHEN has_non_dy_order THEN 'No DY'
            ELSE 'Sin compras'
        END AS DY_order,

        CASE
            WHEN NOT is_active_dmart THEN 'Sin compras'
            WHEN has_uf_order AND has_non_uf_order THEN 'UF y No UF'
            WHEN has_uf_order THEN 'Solo UF'
            WHEN has_non_uf_order THEN 'No UF'
            ELSE 'Sin compras'
        END AS UF_order

    FROM monthly_raw;

END IF;
