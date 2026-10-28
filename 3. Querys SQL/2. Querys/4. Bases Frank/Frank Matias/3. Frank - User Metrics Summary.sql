-- ==============================================================================
-- TABLA 3: Frank - User Metrics Summary (Cubo Aditivo Multi-Negocio: 13 Columnas)
-- Destino: peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary
-- Granularidad: Mes, country, business, DY, UF, l1, l2
-- Negocios incluidos: Market (Darkstores), AAA (Supermercados Terceros), Platform (Toda la app)
-- ==============================================================================

DROP TABLE IF EXISTS `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`;

CREATE OR REPLACE TABLE `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
PARTITION BY Mes
CLUSTER BY country, business, l1, l2 AS

WITH

-- 1. Unificación multi-negocio por usuario con comportamiento de canasta (DY y UF)
user_business_raw AS (
    -- A. PEYA MARKET (Darkstores)
    SELECT
        t2.Mes,
        t2.country,
        'Market'                       AS business,
        t2.DY_order                    AS DY,
        t2.UF_order                    AS UF,
        t2.Market_Actual_Type          AS l1,
        t2.L2_Market_Actual_Type       AS l2,
        t2.customer_id,
        t2.Market_Actual_type_ternure  AS actual_tenure,
        t2.Market_user_adoption_tenure AS adoption_tenure,

        COALESCE(t1.orders_dmart, 0)        AS confirmed_orders,
        COALESCE(t1.net_sales_dmart_eur, 0) AS net_sales_eur,
        COALESCE(t1.units_sold_dmart, 0)    AS units_sold

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
        'AAA'                          AS business,
        t2.DY_order                    AS DY,
        t2.UF_order                    AS UF,
        t2.AAA_Actual_Type             AS l1,
        t2.L2_AAA_Actual_Type          AS l2,
        t2.customer_id,
        t2.AAA_Actual_type_ternure     AS actual_tenure,
        t2.AAA_user_adoption_tenure    AS adoption_tenure,

        0                              AS confirmed_orders,
        0.0                            AS net_sales_eur,
        0                              AS units_sold

    FROM `peya-food-and-groceries.automated_tables_reports.frank_user_type_monthly` t2
    LEFT JOIN `peya-food-and-groceries.automated_tables_reports.frank_user_monthly_activity` t1
        ON  t2.Mes = t1.month
        AND t2.customer_id = t1.customer_id
        AND t2.country = t1.country

    UNION ALL

    -- C. PLATAFORMA (PLATFORM)
    SELECT
        t2.Mes,
        t2.country,
        'Platform'                     AS business,
        t2.DY_order                    AS DY,
        t2.UF_order                    AS UF,
        t2.Platform_Actual_Type        AS l1,
        t2.Platform_Actual_Type        AS l2,
        t2.customer_id,
        t2.Platform_Actual_type_ternure  AS actual_tenure,
        t2.Platform_user_adoption_tenure AS adoption_tenure,

        COALESCE(t1.orders_platform, 0) AS confirmed_orders,
        0.0                             AS net_sales_eur,
        0                               AS units_sold

    FROM `peya-food-and-groceries.automated_tables_reports.frank_user_type_monthly` t2
    LEFT JOIN `peya-food-and-groceries.automated_tables_reports.frank_user_monthly_activity` t1
        ON  t2.Mes = t1.month
        AND t2.customer_id = t1.customer_id
        AND t2.country = t1.country
)

-- 2. Agregación Aditiva Pura a nivel (Mes, country, business, DY, UF, l1, l2)
SELECT
    Mes,
    country,
    business,
    DY,
    UF,
    l1,
    l2,

    COUNT(DISTINCT customer_id)  AS users_count,
    SUM(confirmed_orders)        AS confirmed_orders,
    ROUND(SUM(net_sales_eur), 2) AS net_sales_eur,
    SUM(units_sold)              AS units_sold,
    SUM(actual_tenure)           AS total_actual_tenure,
    SUM(adoption_tenure)         AS total_adoption_tenure

FROM user_business_raw
GROUP BY
    Mes,
    country,
    business,
    DY,
    UF,
    l1,
    l2;
