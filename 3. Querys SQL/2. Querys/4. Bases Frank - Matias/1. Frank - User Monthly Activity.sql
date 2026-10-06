DECLARE query_name STRING DEFAULT '1. Frank - User Monthly Activity';

-- ==============================================================================
-- TABLA 1: Frank - User Monthly Activity (Pipeline Auto-Incremental)
--
-- Destino: peya-food-and-groceries.automated_tables_reports.frank_user_monthly_activity
-- Granularidad: Mes (DATE_TRUNC), customer_id, country (solo meses con compra real)
--
-- Lógica Auto-Incremental:
--   1. Si la tabla NO existe:
--      -> Se crea completa desde '2020-01-01' hasta la actualidad.
--   2. Si la tabla SÍ existe:
--      -> Detecta el último mes cargado y recarga ese mes y el anterior (últimos 2 meses).
--      -> Borra e inserta solo esa ventana para ser ultra liviana y económica.
-- ==============================================================================

DECLARE v_table_exists BOOL DEFAULT FALSE;
DECLARE v_reload_start_date DATE;

-- 1. Verificar si la tabla ya existe en el dataset
SET v_table_exists = (
    SELECT COUNT(1) > 0 
    FROM `peya-food-and-groceries.automated_tables_reports.INFORMATION_SCHEMA.TABLES` 
    WHERE table_name = 'frank_user_monthly_activity'
);

IF NOT v_table_exists THEN

    -- ==========================================================================
    -- CASO A: LA TABLA NO EXISTE -> CREACIÓN HISTÓRICA COMPLETA DESDE 2020
    -- ==========================================================================
    SET v_reload_start_date = DATE '2020-01-01';

    CREATE TABLE `peya-food-and-groceries.automated_tables_reports.frank_user_monthly_activity`
    PARTITION BY month
    CLUSTER BY country, customer_id AS

    WITH

    darkstores AS (
        SELECT DISTINCT partner_id
        FROM `peya-datamarts-pro.dm_dmarts.dim_partner_darkstore`
    ),

    partners_aaa AS (
        SELECT DISTINCT
            COALESCE(cp.partner_id, t.partner_id) AS partner_id
        FROM `peya-data-origins-pro.cl_qcommerce.partners_aaa` cp
        FULL JOIN `peya-food-and-groceries.automated_tables_reports.partners_aaa_temporary` t
            ON t.partner_ID = cp.partner_id
    ),

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

    dy_orders AS (
        SELECT DISTINCT dy.order_details.id.secondary AS order_id
        FROM `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya` dy
        WHERE dy.order_type = 'DOUBLE_YA'
    ),

    customer_acquisition AS (
        SELECT
            customer_id,
            CASE
                WHEN LOGICAL_OR(is_dy) THEN 'Acquired by Food + DY'
                WHEN LOGICAL_OR(is_darkstore) THEN 'Acquired by Dmart'
                WHEN LOGICAL_OR(is_aaa) THEN 'Acquired by AAA'
                WHEN LOGICAL_OR(business_type_name = 'Restaurant') THEN 'Acquired by Food'
                ELSE 'Acquired by Other'
            END AS first_order_acquisition_channel
        FROM (
            SELECT
                CAST(fo.customer_id AS STRING) AS customer_id,
                (ds.partner_id IS NOT NULL) AS is_darkstore,
                (aaa.partner_id IS NOT NULL AND ds.partner_id IS NULL) AS is_aaa,
                (dy.order_id IS NOT NULL) AS is_dy,
                fo.business_type.business_type_name,
                DENSE_RANK() OVER (
                    PARTITION BY CAST(fo.customer_id AS STRING) 
                    ORDER BY fo.registered_date ASC
                ) AS rank_order
            FROM `peya-bi-tools-pro.il_core.fact_orders` fo
            LEFT JOIN darkstores ds ON fo.restaurant.id = ds.partner_id
            LEFT JOIN partners_aaa aaa ON fo.restaurant.id = aaa.partner_id
            LEFT JOIN dy_orders dy ON fo.order_id = dy.order_id
            WHERE fo.registered_date >= v_reload_start_date
              AND fo.order_status = 'CONFIRMED'
              AND fo.customer_id IS NOT NULL
              AND fo.country.country_name IS NOT NULL
        )
        WHERE rank_order = 1
        GROUP BY 1
    ),

    monthly_raw AS (
        SELECT
            CAST(fo.customer_id AS STRING) AS customer_id,
            fo.country.country_name AS country,
            DATE_TRUNC(fo.registered_date, MONTH) AS month,

            TRUE AS is_active_platform,
            LOGICAL_OR(ds.partner_id IS NOT NULL) AS is_active_market,
            LOGICAL_OR(aaa.partner_id IS NOT NULL AND ds.partner_id IS NULL) AS is_active_aaa,
            LOGICAL_OR(fo.business_type.business_type_name = 'Restaurant' AND ds.partner_id IS NULL AND aaa.partner_id IS NULL) AS is_active_food,

            COUNT(DISTINCT fo.order_id) AS orders_platform,
            COUNT(DISTINCT IF(ds.partner_id IS NOT NULL, fo.order_id, NULL)) AS orders_market,
            COUNT(DISTINCT IF(ds.partner_id IS NOT NULL AND mo.is_uf, fo.order_id, NULL)) AS orders_uf_market,
            COUNT(DISTINCT IF(ds.partner_id IS NOT NULL AND dy.order_id IS NOT NULL, fo.order_id, NULL)) AS orders_dy_market,

            ROUND(SUM(IF(ds.partner_id IS NOT NULL, COALESCE(mo.net_sales_eur, 0), 0)), 2) AS net_sales_market_eur,
            SUM(IF(ds.partner_id IS NOT NULL, COALESCE(CAST(mo.units_sold AS INT64), 0), 0)) AS units_sold_market,

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

    SELECT
        m.month,
        m.customer_id,
        m.country,
        m.is_active_platform,
        m.is_active_market,
        m.is_active_aaa,
        m.is_active_food,
        m.orders_platform,
        m.orders_market,
        m.orders_uf_market,
        m.orders_dy_market,
        m.net_sales_market_eur,
        m.units_sold_market,

        CASE
            WHEN NOT m.is_active_market THEN 'Sin compras'
            WHEN m.has_dy_order AND m.has_non_dy_order THEN 'DY y No DY'
            WHEN m.has_dy_order THEN 'Solo DY'
            WHEN m.has_non_dy_order THEN 'No DY'
            ELSE 'Sin compras'
        END AS DY_order,

        CASE
            WHEN NOT m.is_active_market THEN 'Sin compras'
            WHEN m.has_uf_order AND m.has_non_uf_order THEN 'UF y No UF'
            WHEN m.has_uf_order THEN 'Solo UF'
            WHEN m.has_non_uf_order THEN 'No UF'
            ELSE 'Sin compras'
        END AS UF_order,

        acq.first_order_acquisition_channel

    FROM monthly_raw m
    LEFT JOIN customer_acquisition acq
        ON m.customer_id = acq.customer_id;

ELSE

    -- ==========================================================================
    -- CASO B: LA TABLA YA EXISTE -> RECARGA INCREMENTAL (ÚLTIMOS 2 MESES)
    -- ==========================================================================
    SET v_reload_start_date = (
        SELECT DATE_SUB(MAX(month), INTERVAL 1 MONTH)
        FROM `peya-food-and-groceries.automated_tables_reports.frank_user_monthly_activity`
    );

    -- Si la tabla estaba vacía o nula, recarga completa desde 2020
    IF v_reload_start_date IS NULL THEN
        SET v_reload_start_date = DATE '2020-01-01';
    END IF;

    -- B.1 Eliminar los últimos dos meses para sobreescribirlos limpios
    DELETE FROM `peya-food-and-groceries.automated_tables_reports.frank_user_monthly_activity`
    WHERE month >= v_reload_start_date;

    -- B.2 Insertar los datos frescos de esos dos meses
    INSERT INTO `peya-food-and-groceries.automated_tables_reports.frank_user_monthly_activity`
    WITH

    darkstores AS (
        SELECT DISTINCT partner_id
        FROM `peya-datamarts-pro.dm_dmarts.dim_partner_darkstore`
    ),

    partners_aaa AS (
        SELECT DISTINCT
            COALESCE(cp.partner_id, t.partner_id) AS partner_id
        FROM `peya-data-origins-pro.cl_qcommerce.partners_aaa` cp
        FULL JOIN `peya-food-and-groceries.automated_tables_reports.partners_aaa_temporary` t
            ON t.partner_ID = cp.partner_id
    ),

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

    dy_orders AS (
        SELECT DISTINCT dy.order_details.id.secondary AS order_id
        FROM `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya` dy
        WHERE dy.order_type = 'DOUBLE_YA'
    ),

    -- Reutiliza el canal histórico ya conocido de la base, o evalúa solo a usuarios nuevos
    existing_acquisition AS (
        SELECT
            customer_id,
            ANY_VALUE(first_order_acquisition_channel) AS first_order_acquisition_channel
        FROM `peya-food-and-groceries.automated_tables_reports.frank_user_monthly_activity`
        WHERE month < v_reload_start_date
        GROUP BY 1
    ),

    new_users_acquisition AS (
        SELECT
            customer_id,
            CASE
                WHEN LOGICAL_OR(is_dy) THEN 'Acquired by Food + DY'
                WHEN LOGICAL_OR(is_darkstore) THEN 'Acquired by Dmart'
                WHEN LOGICAL_OR(is_aaa) THEN 'Acquired by AAA'
                WHEN LOGICAL_OR(business_type_name = 'Restaurant') THEN 'Acquired by Food'
                ELSE 'Acquired by Other'
            END AS first_order_acquisition_channel
        FROM (
            SELECT
                CAST(fo.customer_id AS STRING) AS customer_id,
                (ds.partner_id IS NOT NULL) AS is_darkstore,
                (aaa.partner_id IS NOT NULL AND ds.partner_id IS NULL) AS is_aaa,
                (dy.order_id IS NOT NULL) AS is_dy,
                fo.business_type.business_type_name,
                DENSE_RANK() OVER (
                    PARTITION BY CAST(fo.customer_id AS STRING) 
                    ORDER BY fo.registered_date ASC
                ) AS rank_order
            FROM `peya-bi-tools-pro.il_core.fact_orders` fo
            LEFT JOIN darkstores ds ON fo.restaurant.id = ds.partner_id
            LEFT JOIN partners_aaa aaa ON fo.restaurant.id = aaa.partner_id
            LEFT JOIN dy_orders dy ON fo.order_id = dy.order_id
            WHERE fo.registered_date >= v_reload_start_date
              AND fo.order_status = 'CONFIRMED'
              AND fo.customer_id IS NOT NULL
              AND fo.country.country_name IS NOT NULL
        )
        WHERE rank_order = 1
        GROUP BY 1
    ),

    customer_acquisition AS (
        SELECT customer_id, first_order_acquisition_channel FROM existing_acquisition
        UNION ALL
        SELECT n.customer_id, n.first_order_acquisition_channel 
        FROM new_users_acquisition n
        WHERE n.customer_id NOT IN (SELECT customer_id FROM existing_acquisition)
    ),

    monthly_raw AS (
        SELECT
            CAST(fo.customer_id AS STRING) AS customer_id,
            fo.country.country_name AS country,
            DATE_TRUNC(fo.registered_date, MONTH) AS month,

            TRUE AS is_active_platform,
            LOGICAL_OR(ds.partner_id IS NOT NULL) AS is_active_market,
            LOGICAL_OR(aaa.partner_id IS NOT NULL AND ds.partner_id IS NULL) AS is_active_aaa,
            LOGICAL_OR(fo.business_type.business_type_name = 'Restaurant' AND ds.partner_id IS NULL AND aaa.partner_id IS NULL) AS is_active_food,

            COUNT(DISTINCT fo.order_id) AS orders_platform,
            COUNT(DISTINCT IF(ds.partner_id IS NOT NULL, fo.order_id, NULL)) AS orders_market,
            COUNT(DISTINCT IF(ds.partner_id IS NOT NULL AND mo.is_uf, fo.order_id, NULL)) AS orders_uf_market,
            COUNT(DISTINCT IF(ds.partner_id IS NOT NULL AND dy.order_id IS NOT NULL, fo.order_id, NULL)) AS orders_dy_market,

            ROUND(SUM(IF(ds.partner_id IS NOT NULL, COALESCE(mo.net_sales_eur, 0), 0)), 2) AS net_sales_market_eur,
            SUM(IF(ds.partner_id IS NOT NULL, COALESCE(CAST(mo.units_sold AS INT64), 0), 0)) AS units_sold_market,

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

    SELECT
        m.month,
        m.customer_id,
        m.country,
        m.is_active_platform,
        m.is_active_market,
        m.is_active_aaa,
        m.is_active_food,
        m.orders_platform,
        m.orders_market,
        m.orders_uf_market,
        m.orders_dy_market,
        m.net_sales_market_eur,
        m.units_sold_market,

        CASE
            WHEN NOT m.is_active_market THEN 'Sin compras'
            WHEN m.has_dy_order AND m.has_non_dy_order THEN 'DY y No DY'
            WHEN m.has_dy_order THEN 'Solo DY'
            WHEN m.has_non_dy_order THEN 'No DY'
            ELSE 'Sin compras'
        END AS DY_order,

        CASE
            WHEN NOT m.is_active_market THEN 'Sin compras'
            WHEN m.has_uf_order AND m.has_non_uf_order THEN 'UF y No UF'
            WHEN m.has_uf_order THEN 'Solo UF'
            WHEN m.has_non_uf_order THEN 'No UF'
            ELSE 'Sin compras'
        END AS UF_order,

        acq.first_order_acquisition_channel

    FROM monthly_raw m
    LEFT JOIN customer_acquisition acq
        ON m.customer_id = acq.customer_id;

END IF;
