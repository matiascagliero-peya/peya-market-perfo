-- ==============================================================================
-- TABLA 3: Frank - User Metrics Summary (Datamart Agregado Multi-Negocio)
-- Destino: peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary
-- Granularidad: Mes, country, business (Market, AAA, Platform), level_1, level_2
-- ==============================================================================

DROP TABLE IF EXISTS `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`;

CREATE OR REPLACE TABLE `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
PARTITION BY Mes
CLUSTER BY country, business, level_1, level_2 AS

WITH

-- 1. Unificación multi-negocio por usuario (Market, AAA, Platform)
user_business_raw AS (
    -- A. PEYA MARKET (Darkstores)
    SELECT
        t2.Mes,
        t2.country,
        'Market'                    AS business,
        t2.Market_Actual_Type       AS level_1,
        t2.L2_Market_Actual_Type    AS level_2,
        t2.customer_id,
        t2.Market_Actual_type_ternure  AS actual_tenure,
        t2.Market_user_adoption_tenure AS adoption_tenure,
        IF(t2.Market_Actual_Type NOT IN ('Never Active', 'Churned'), t2.customer_id, NULL) AS active_customer_id,

        COALESCE(t1.orders_dmart, 0)        AS confirmed_orders,
        COALESCE(t1.orders_uf_dmart, 0)     AS confirmed_orders_uf,
        COALESCE(t1.orders_dy_dmart, 0)     AS confirmed_orders_dy,
        COALESCE(t1.net_sales_dmart_eur, 0) AS net_sales_eur,
        COALESCE(t1.units_sold_dmart, 0)    AS units_sold,
        IF(COALESCE(t1.orders_uf_dmart, 0) > 0, 1, 0) AS is_uf_buyer

    FROM `peya-food-and-groceries.automated_tables_reports.frank_user_type_monthly` t2
    LEFT JOIN `peya-food-and-groceries.automated_tables_reports.frank_user_monthly_activity` t1
        ON  t2.Mes = t1.month
        AND t2.customer_id = t1.customer_id
        AND t2.country = t1.country

    UNION ALL

    -- B. SUPERMERCADOS TERCEROS (AAA)
    SELECT
        t2.Mes,
        t2.country,
        'AAA'                       AS business,
        t2.AAA_Actual_Type          AS level_1,
        t2.L2_AAA_Actual_Type       AS level_2,
        t2.customer_id,
        t2.AAA_Actual_type_ternure  AS actual_tenure,
        t2.AAA_user_adoption_tenure AS adoption_tenure,
        IF(t2.AAA_Actual_Type NOT IN ('Never Active', 'Churned'), t2.customer_id, NULL) AS active_customer_id,

        0 AS confirmed_orders,
        0 AS confirmed_orders_uf,
        0 AS confirmed_orders_dy,
        0.0 AS net_sales_eur,
        0 AS units_sold,
        0 AS is_uf_buyer

    FROM `peya-food-and-groceries.automated_tables_reports.frank_user_type_monthly` t2

    UNION ALL

    -- C. PLATAFORMA (PLATFORM)
    SELECT
        t2.Mes,
        t2.country,
        'Platform'                     AS business,
        t2.Platform_Actual_Type        AS level_1,
        t2.Platform_Actual_Type        AS level_2,
        t2.customer_id,
        t2.Platform_Actual_type_ternure  AS actual_tenure,
        t2.Platform_user_adoption_tenure AS adoption_tenure,
        IF(t2.Platform_Actual_Type NOT IN ('Never Active', 'Churned'), t2.customer_id, NULL) AS active_customer_id,

        COALESCE(t1.orders_platform, 0) AS confirmed_orders,
        0 AS confirmed_orders_uf,
        0 AS confirmed_orders_dy,
        0.0 AS net_sales_eur,
        0 AS units_sold,
        0 AS is_uf_buyer

    FROM `peya-food-and-groceries.automated_tables_reports.frank_user_type_monthly` t2
    LEFT JOIN `peya-food-and-groceries.automated_tables_reports.frank_user_monthly_activity` t1
        ON  t2.Mes = t1.month
        AND t2.customer_id = t1.customer_id
        AND t2.country = t1.country
),

-- 2. Totales mensuales de usuarios activos por negocio para cálculo de share %
monthly_business_totals AS (
    SELECT
        Mes,
        country,
        business,
        COUNT(DISTINCT active_customer_id) AS total_active_users
    FROM user_business_raw
    GROUP BY 1, 2, 3
)

-- 3. Agregación de métricas y unit economics por Negocio, L1 y L2
SELECT
    u.Mes,
    u.country,
    u.business,
    u.level_1,
    u.level_2,

    -- Alias de compatibilidad
    u.level_1 AS Market_Actual_Type,
    u.level_2 AS L2_Market_Actual_Type,

    COUNT(DISTINCT u.customer_id) AS users_count,

    ROUND(SAFE_DIVIDE(
        COUNT(DISTINCT u.active_customer_id),
        m.total_active_users
    ) * 100, 2) AS users_share_pct,

    SUM(u.confirmed_orders)    AS confirmed_orders,
    SUM(u.confirmed_orders_uf) AS confirmed_orders_uf,
    SUM(u.confirmed_orders_dy) AS confirmed_orders_dy,
    ROUND(SUM(u.net_sales_eur), 2) AS net_sales_eur,
    SUM(u.units_sold)          AS units_sold,

    ROUND(SAFE_DIVIDE(SUM(u.units_sold), SUM(u.confirmed_orders)), 2) AS basket_size,
    ROUND(SAFE_DIVIDE(SUM(u.net_sales_eur), SUM(u.confirmed_orders)), 2) AS afv,
    ROUND(SAFE_DIVIDE(SUM(u.confirmed_orders), COUNT(DISTINCT IF(u.confirmed_orders > 0, u.customer_id, NULL))), 2) AS frequency,
    ROUND(SAFE_DIVIDE(SUM(u.units_sold), COUNT(DISTINCT IF(u.confirmed_orders > 0, u.customer_id, NULL))), 2) AS monthly_customer_units,

    ROUND(SAFE_DIVIDE(
        COUNT(DISTINCT IF(u.is_uf_buyer = 1, u.customer_id, NULL)),
        COUNT(DISTINCT IF(u.confirmed_orders > 0, u.customer_id, NULL))
    ) * 100, 2) AS uf_user_penetration_pct,

    ROUND(AVG(u.actual_tenure), 2)   AS avg_actual_tenure,
    ROUND(AVG(u.adoption_tenure), 2) AS avg_adoption_tenure,
    SUM(u.actual_tenure)             AS total_actual_tenure,
    SUM(u.adoption_tenure)           AS total_adoption_tenure

FROM user_business_raw u
LEFT JOIN monthly_business_totals m
    ON  u.Mes = m.Mes
    AND u.country = m.country
    AND u.business = m.business
GROUP BY 1, 2, 3, 4, 5, m.total_active_users;
