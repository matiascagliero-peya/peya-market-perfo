DECLARE query_name STRING DEFAULT '3. Frank - User Metrics Summary';

-- ==============================================================================
-- TABLA 3: Frank - User Metrics Summary (Pipeline Auto-Incremental)
--
-- Destino: peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary
-- Granularidad: Mes, country, Market_Actual_Type (L1), L2_Actual_Type (L2)
--
-- Lógica Auto-Incremental:
--   1. Si la tabla NO existe:
--      -> Se crea completa desde el inicio de la Tabla 2.
--   2. Si la tabla SÍ existe:
--      -> Detecta el último mes cargado y recarga ese mes y el anterior (últimos 2 meses).
--      -> Borra e inserta solo esa ventana para ejecutarse en 2 segundos.
-- ==============================================================================

DECLARE v_table_exists BOOL DEFAULT FALSE;
DECLARE v_reload_start_date DATE;

-- 1. Verificar si la tabla ya existe en el dataset
SET v_table_exists = (
    SELECT COUNT(1) > 0 
    FROM `peya-food-and-groceries.automated_tables_reports.INFORMATION_SCHEMA.TABLES` 
    WHERE table_name = 'frank_user_metrics_summary'
);

IF NOT v_table_exists THEN

    -- ==========================================================================
    -- CASO A: LA TABLA NO EXISTE -> CREACIÓN COMPLETA
    -- ==========================================================================
    CREATE TABLE `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
    PARTITION BY Mes
    CLUSTER BY country, Market_Actual_Type, L2_Actual_Type AS

    WITH

    user_base AS (
        SELECT
            t2.Mes,
            t2.country,
            t2.customer_id,
            t2.Market_Actual_Type,
            t2.L2_Actual_Type,
            t2.Market_Actual_type_ternure,
            t2.Market_user_adoption_tenure,

            COALESCE(t1.orders_market, 0)         AS orders_market,
            COALESCE(t1.orders_uf_market, 0)      AS orders_uf_market,
            COALESCE(t1.orders_dy_market, 0)      AS orders_dy_market,
            COALESCE(t1.net_sales_market_eur, 0)  AS net_sales_market_eur,
            COALESCE(t1.units_sold_market, 0)     AS units_sold_market,
            COALESCE(t1.orders_platform, 0)       AS orders_platform,
            IF(t1.orders_uf_market > 0, 1, 0)     AS is_uf_buyer

        FROM `peya-food-and-groceries.automated_tables_reports.frank_user_type_monthly` t2
        LEFT JOIN `peya-food-and-groceries.automated_tables_reports.frank_user_monthly_activity` t1
            ON  t2.Mes = t1.month
            AND t2.customer_id = t1.customer_id
            AND t2.country = t1.country
    ),

    monthly_totals AS (
        SELECT
            Mes,
            country,
            COUNT(DISTINCT IF(Market_Actual_Type NOT IN ('Never Active', 'Churned'), customer_id, NULL)) AS total_market_active_users
        FROM user_base
        GROUP BY 1, 2
    )

    SELECT
        u.Mes,
        u.country,
        u.Market_Actual_Type,
        u.L2_Actual_Type,

        COUNT(DISTINCT u.customer_id) AS users_count,

        ROUND(SAFE_DIVIDE(
            COUNT(DISTINCT IF(u.Market_Actual_Type NOT IN ('Never Active', 'Churned'), u.customer_id, NULL)),
            m.total_market_active_users
        ) * 100, 2) AS users_share_pct,

        SUM(u.orders_market) AS confirmed_orders,
        SUM(u.orders_uf_market) AS confirmed_orders_uf,
        SUM(u.orders_dy_market) AS confirmed_orders_dy,
        ROUND(SUM(u.net_sales_market_eur), 2) AS net_sales_eur,
        SUM(u.units_sold_market) AS units_sold,

        ROUND(SAFE_DIVIDE(SUM(u.units_sold_market), SUM(u.orders_market)), 2) AS basket_size,
        ROUND(SAFE_DIVIDE(SUM(u.net_sales_market_eur), SUM(u.orders_market)), 2) AS afv,
        ROUND(SAFE_DIVIDE(SUM(u.orders_market), COUNT(DISTINCT IF(u.orders_market > 0, u.customer_id, NULL))), 2) AS frequency,
        ROUND(SAFE_DIVIDE(SUM(u.units_sold_market), COUNT(DISTINCT IF(u.orders_market > 0, u.customer_id, NULL))), 2) AS monthly_customer_units,

        ROUND(SAFE_DIVIDE(
            COUNT(DISTINCT IF(u.is_uf_buyer = 1, u.customer_id, NULL)),
            COUNT(DISTINCT IF(u.orders_market > 0, u.customer_id, NULL))
        ) * 100, 2) AS uf_user_penetration_pct,

        ROUND(AVG(u.Market_Actual_type_ternure), 2) AS avg_actual_tenure,
        ROUND(AVG(u.Market_user_adoption_tenure), 2) AS avg_adoption_tenure

    FROM user_base u
    LEFT JOIN monthly_totals m
        ON  u.Mes = m.Mes
        AND u.country = m.country
    GROUP BY 1, 2, 3, 4, m.total_market_active_users;

ELSE

    -- ==========================================================================
    -- CASO B: LA TABLA YA EXISTE -> RECARGA INCREMENTAL (ÚLTIMOS 2 MESES)
    -- ==========================================================================
    SET v_reload_start_date = (
        SELECT DATE_SUB(MAX(Mes), INTERVAL 1 MONTH)
        FROM `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
    );

    IF v_reload_start_date IS NULL THEN
        SET v_reload_start_date = DATE '2020-01-01';
    END IF;

    -- B.1 Borrar la ventana de meses a refrescar
    DELETE FROM `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
    WHERE Mes >= v_reload_start_date;

    -- B.2 Insertar los datos frescos
    INSERT INTO `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
    WITH

    user_base AS (
        SELECT
            t2.Mes,
            t2.country,
            t2.customer_id,
            t2.Market_Actual_Type,
            t2.L2_Actual_Type,
            t2.Market_Actual_type_ternure,
            t2.Market_user_adoption_tenure,

            COALESCE(t1.orders_market, 0)         AS orders_market,
            COALESCE(t1.orders_uf_market, 0)      AS orders_uf_market,
            COALESCE(t1.orders_dy_market, 0)      AS orders_dy_market,
            COALESCE(t1.net_sales_market_eur, 0)  AS net_sales_market_eur,
            COALESCE(t1.units_sold_market, 0)     AS units_sold_market,
            COALESCE(t1.orders_platform, 0)       AS orders_platform,
            IF(t1.orders_uf_market > 0, 1, 0)     AS is_uf_buyer

        FROM `peya-food-and-groceries.automated_tables_reports.frank_user_type_monthly` t2
        LEFT JOIN `peya-food-and-groceries.automated_tables_reports.frank_user_monthly_activity` t1
            ON  t2.Mes = t1.month
            AND t2.customer_id = t1.customer_id
            AND t2.country = t1.country
        WHERE t2.Mes >= v_reload_start_date
    ),

    monthly_totals AS (
        SELECT
            Mes,
            country,
            COUNT(DISTINCT IF(Market_Actual_Type NOT IN ('Never Active', 'Churned'), customer_id, NULL)) AS total_market_active_users
        FROM user_base
        GROUP BY 1, 2
    )

    SELECT
        u.Mes,
        u.country,
        u.Market_Actual_Type,
        u.L2_Actual_Type,

        COUNT(DISTINCT u.customer_id) AS users_count,

        ROUND(SAFE_DIVIDE(
            COUNT(DISTINCT IF(u.Market_Actual_Type NOT IN ('Never Active', 'Churned'), u.customer_id, NULL)),
            m.total_market_active_users
        ) * 100, 2) AS users_share_pct,

        SUM(u.orders_market) AS confirmed_orders,
        SUM(u.orders_uf_market) AS confirmed_orders_uf,
        SUM(u.orders_dy_market) AS confirmed_orders_dy,
        ROUND(SUM(u.net_sales_market_eur), 2) AS net_sales_eur,
        SUM(u.units_sold_market) AS units_sold,

        ROUND(SAFE_DIVIDE(SUM(u.units_sold_market), SUM(u.orders_market)), 2) AS basket_size,
        ROUND(SAFE_DIVIDE(SUM(u.net_sales_market_eur), SUM(u.orders_market)), 2) AS afv,
        ROUND(SAFE_DIVIDE(SUM(u.orders_market), COUNT(DISTINCT IF(u.orders_market > 0, u.customer_id, NULL))), 2) AS frequency,
        ROUND(SAFE_DIVIDE(SUM(u.units_sold_market), COUNT(DISTINCT IF(u.orders_market > 0, u.customer_id, NULL))), 2) AS monthly_customer_units,

        ROUND(SAFE_DIVIDE(
            COUNT(DISTINCT IF(u.is_uf_buyer = 1, u.customer_id, NULL)),
            COUNT(DISTINCT IF(u.orders_market > 0, u.customer_id, NULL))
        ) * 100, 2) AS uf_user_penetration_pct,

        ROUND(AVG(u.Market_Actual_type_ternure), 2) AS avg_actual_tenure,
        ROUND(AVG(u.Market_user_adoption_tenure), 2) AS avg_adoption_tenure

    FROM user_base u
    LEFT JOIN monthly_totals m
        ON  u.Mes = m.Mes
        AND u.country = m.country
    GROUP BY 1, 2, 3, 4, m.total_market_active_users;

END IF;
