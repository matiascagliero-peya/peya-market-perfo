-- ==============================================================================
-- Frank - User Type (Consulta Directa para BigQuery / Connected Sheets)
--
-- Granularidad: Mes (DATE_TRUNC primer día de mes), customer_id, country
--
-- Cobertura:
--   1. PLATFORM: Ciclo de vida y tenures en toda la plataforma PeYa.
--   2. AAA: Ciclo de vida y tenures en Supermercados de Terceros (partners AAA no darkstores).
--   3. MARKET: Ciclo de vida y tenures en Peya Market (Darkstores).
--   4. FLAGS: DY_order (Double Ya) y UF_order (Ultra Fresh).
--   5. L2_Actual_Type: Sub-tipo de ciclo de vida de Market y comportamiento cross-negocio.
-- ==============================================================================

WITH

-- ==============================================================================
-- 1. IDENTIFICACIÓN DE NEGOCIOS Y CATEGORÍAS
-- ==============================================================================

-- 1.1 Darkstores (Peya Market)
darkstores AS (
    SELECT DISTINCT partner_id
    FROM `peya-datamarts-pro.dm_dmarts.dim_partner_darkstore`
),

-- 1.2 Supermercados de Terceros (Partners AAA)
partners_aaa AS (
    SELECT DISTINCT
        COALESCE(cp.partner_id, t.partner_id) AS partner_id
    FROM `peya-data-origins-pro.cl_qcommerce.partners_aaa` cp
    FULL JOIN `peya-food-and-groceries.automated_tables_reports.partners_aaa_temporary` t
        ON t.partner_ID = cp.partner_id
),

-- 1.3 Órdenes con productos Ultra Fresh
uf_orders AS (
    SELECT DISTINCT CAST(order_id AS STRING) AS order_id
    FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
    WHERE state = 'CONFIRMED'
      AND order_date >= '2020-01-01'
      AND master_category_parent_english IN ('Produce', 'Meat / Seafood', 'Ready To Consume')
),

-- 1.4 Órdenes Double Ya
dy_orders AS (
    SELECT DISTINCT dy.order_details.id.secondary AS order_id
    FROM `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya` dy
    WHERE dy.order_type = 'DOUBLE_YA'
),

-- 1.5 Canal de Adquisición de la primera orden histórica en PeYa
customer_first_orders AS (
    SELECT
        fo.customer_id,
        MIN(fo.registered_date) AS first_order_timestamp
    FROM `peya-bi-tools-pro.il_core.fact_orders` fo
    WHERE fo.registered_date >= '2020-01-01'
      AND fo.order_status = 'CONFIRMED'
    GROUP BY 1
),

customer_acquisition AS (
    SELECT
        fo.customer_id,
        CASE
            WHEN LOGICAL_OR(dy.order_id IS NOT NULL) THEN 'Acquired by Food + DY'
            WHEN LOGICAL_OR(ds.partner_id IS NOT NULL) THEN 'Acquired by Dmart'
            WHEN LOGICAL_OR(aaa.partner_id IS NOT NULL AND ds.partner_id IS NULL) THEN 'Acquired by AAA'
            WHEN LOGICAL_OR(fo.business_type.business_type_name = 'Restaurant') THEN 'Acquired by Food'
            ELSE 'Acquired by Other'
        END AS first_order_acquisition_channel
    FROM `peya-bi-tools-pro.il_core.fact_orders` fo
    INNER JOIN customer_first_orders cfo
        ON fo.customer_id = cfo.customer_id
       AND fo.registered_date = cfo.first_order_timestamp
    LEFT JOIN darkstores ds ON fo.restaurant.id = ds.partner_id
    LEFT JOIN partners_aaa aaa ON fo.restaurant.id = aaa.partner_id
    LEFT JOIN dy_orders dy ON fo.order_id = dy.order_id
    WHERE fo.order_status = 'CONFIRMED'
    GROUP BY 1
),

-- ==============================================================================
-- 2. ACTIVIDAD MENSUAL CONSOLIDADA POR USUARIO Y PAÍS
-- ==============================================================================

monthly_orders AS (
    SELECT
        fo.customer_id,
        fo.country.country_name AS country,
        DATE_TRUNC(fo.registered_date, MONTH) AS month,

        -- Actividad mensual por negocio
        TRUE AS is_active_platform,
        LOGICAL_OR(ds.partner_id IS NOT NULL) AS is_active_market,
        LOGICAL_OR(aaa.partner_id IS NOT NULL AND ds.partner_id IS NULL) AS is_active_aaa,
        LOGICAL_OR(fo.business_type.business_type_name = 'Restaurant' AND ds.partner_id IS NULL AND aaa.partner_id IS NULL) AS is_active_food,

        -- Composición de órdenes en Market
        LOGICAL_OR(ds.partner_id IS NOT NULL AND dy.order_id IS NOT NULL) AS has_dy_order,
        LOGICAL_OR(ds.partner_id IS NOT NULL AND dy.order_id IS NULL)     AS has_non_dy_order,
        LOGICAL_OR(ds.partner_id IS NOT NULL AND uf.order_id IS NOT NULL) AS has_uf_order,
        LOGICAL_OR(ds.partner_id IS NOT NULL AND uf.order_id IS NULL)     AS has_non_uf_order

    FROM `peya-bi-tools-pro.il_core.fact_orders` fo
    LEFT JOIN darkstores ds
        ON fo.restaurant.id = ds.partner_id
    LEFT JOIN partners_aaa aaa
        ON fo.restaurant.id = aaa.partner_id
    LEFT JOIN dy_orders dy
        ON fo.order_id = dy.order_id
    LEFT JOIN uf_orders uf
        ON CAST(fo.order_id AS STRING) = uf.order_id
    WHERE fo.registered_date >= '2020-01-01'
      AND fo.order_status = 'CONFIRMED'
    GROUP BY 1, 2, 3
),

-- ==============================================================================
-- 3. ADOPCIÓN (COHORTS) GLOBAL Y POR NEGOCIO
-- ==============================================================================

customer_adoptions AS (
    SELECT
        customer_id,
        country,
        month,
        is_active_platform,
        is_active_market,
        is_active_aaa,
        is_active_food,
        has_dy_order,
        has_non_dy_order,
        has_uf_order,
        has_non_uf_order,

        -- Adopciones globales e históricas
        MIN(month) OVER (PARTITION BY customer_id) AS platform_adoption_date_global,
        MIN(month) OVER (PARTITION BY customer_id, country) AS platform_adoption_date_country,
        MIN(IF(is_active_aaa, month, NULL)) OVER (PARTITION BY customer_id) AS aaa_adoption_date,
        MIN(IF(is_active_market, month, NULL)) OVER (PARTITION BY customer_id) AS market_adoption_date,

        LEAD(month) OVER (PARTITION BY customer_id, country ORDER BY month) AS next_month
    FROM monthly_orders
),

-- ==============================================================================
-- 4. TIMELINE CONTINUO MENSUAL POR USUARIO (Meses Activos + Fantasmas)
-- ==============================================================================

user_timeline AS (
    -- Meses reales con compra
    SELECT
        customer_id,
        country,
        month,
        platform_adoption_date_global,
        platform_adoption_date_country,
        aaa_adoption_date,
        market_adoption_date,
        is_active_platform,
        is_active_aaa,
        is_active_market,
        is_active_food,
        has_dy_order,
        has_non_dy_order,
        has_uf_order,
        has_non_uf_order
    FROM customer_adoptions

    UNION ALL

    -- Meses fantasma (inactivos en plataforma)
    SELECT
        customer_id,
        country,
        DATE_ADD(month, INTERVAL gap MONTH) AS month,
        platform_adoption_date_global,
        platform_adoption_date_country,
        aaa_adoption_date,
        market_adoption_date,
        FALSE AS is_active_platform,
        FALSE AS is_active_aaa,
        FALSE AS is_active_market,
        FALSE AS is_active_food,
        FALSE AS has_dy_order,
        FALSE AS has_non_dy_order,
        FALSE AS has_uf_order,
        FALSE AS has_non_uf_order
    FROM customer_adoptions,
         UNNEST(GENERATE_ARRAY(1, 60)) AS gap
    WHERE (next_month IS NULL OR DATE_DIFF(next_month, month, MONTH) > gap)
      AND DATE_ADD(month, INTERVAL gap MONTH) <= DATE_TRUNC(CURRENT_DATE(), MONTH)
),

-- ==============================================================================
-- 5. CÁLCULO DE RACHAS CONSECUTIVAS (COMPRA E INACTIVIDAD)
-- ==============================================================================

streaks_calc AS (
    SELECT
        *,
        -- Reinicios de racha activa
        SUM(IF(NOT is_active_platform, 1, 0)) OVER (
            PARTITION BY customer_id, country ORDER BY month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS grp_active_peya,

        SUM(IF(NOT is_active_aaa, 1, 0)) OVER (
            PARTITION BY customer_id, country ORDER BY month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS grp_active_aaa,

        SUM(IF(NOT is_active_market, 1, 0)) OVER (
            PARTITION BY customer_id, country ORDER BY month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS grp_active_market,

        -- Reinicios de racha inactiva
        SUM(IF(is_active_platform, 1, 0)) OVER (
            PARTITION BY customer_id, country ORDER BY month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS grp_inactive_peya,

        SUM(IF(is_active_aaa, 1, 0)) OVER (
            PARTITION BY customer_id, country ORDER BY month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS grp_inactive_aaa,

        SUM(IF(is_active_market, 1, 0)) OVER (
            PARTITION BY customer_id, country ORDER BY month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS grp_inactive_market
    FROM user_timeline
),

streaks_counted AS (
    SELECT
        *,
        -- Racha activa
        IF(is_active_platform, ROW_NUMBER() OVER (PARTITION BY customer_id, country, is_active_platform, grp_active_peya ORDER BY month), 0) AS active_streak_peya,
        IF(is_active_aaa, ROW_NUMBER() OVER (PARTITION BY customer_id, country, is_active_aaa, grp_active_aaa ORDER BY month), 0) AS active_streak_aaa,
        IF(is_active_market, ROW_NUMBER() OVER (PARTITION BY customer_id, country, is_active_market, grp_active_market ORDER BY month), 0) AS active_streak_market,

        -- Racha inactiva
        IF(NOT is_active_platform, ROW_NUMBER() OVER (PARTITION BY customer_id, country, is_active_platform, grp_inactive_peya ORDER BY month), 0) AS inactive_streak_peya,
        IF(NOT is_active_aaa, ROW_NUMBER() OVER (PARTITION BY customer_id, country, is_active_aaa, grp_inactive_aaa ORDER BY month), 0) AS inactive_streak_aaa,
        IF(NOT is_active_market, ROW_NUMBER() OVER (PARTITION BY customer_id, country, is_active_market, grp_inactive_market ORDER BY month), 0) AS inactive_streak_market
    FROM streaks_calc
),

-- ==============================================================================
-- 6. ASIGNACIÓN DE TIPOS Y TENURES L1 + FLAGS
-- ==============================================================================

types_assigned AS (
    SELECT
        month,
        customer_id,
        country,
        is_active_food,
        is_active_aaa,
        is_active_market,

        -- Flags de Market
        CASE
            WHEN NOT is_active_market THEN 'Sin compras'
            WHEN has_dy_order AND has_non_dy_order THEN 'DY y No DY'
            WHEN has_dy_order THEN 'Solo DY'
            WHEN has_non_dy_order THEN 'No DY'
            ELSE 'Sin compras'
        END AS DY_order,

        CASE
            WHEN NOT is_active_market THEN 'Sin compras'
            WHEN has_uf_order AND has_non_uf_order THEN 'UF y No UF'
            WHEN has_uf_order THEN 'Solo UF'
            WHEN has_non_uf_order THEN 'No UF'
            ELSE 'Sin compras'
        END AS UF_order,

        -- Platform
        platform_adoption_date_global AS Platform_adoption_date,
        DATE_DIFF(month, platform_adoption_date_global, MONTH) + 1 AS Platform_user_adoption_tenure,

        CASE
            WHEN is_active_platform AND month = platform_adoption_date_country THEN 'New User'
            WHEN is_active_platform AND active_streak_peya = 1 THEN 'Reactivation'
            WHEN is_active_platform AND active_streak_peya = 2 AND DATE_DIFF(month, platform_adoption_date_country, MONTH) = 1 THEN 'M1 Return'
            WHEN is_active_platform AND active_streak_peya = 2 THEN 'Re-Order'
            WHEN is_active_platform AND active_streak_peya >= 3 THEN 'Recurring Return'
            ELSE 'Churned'
        END AS Platform_Actual_Type,

        IF(is_active_platform, active_streak_peya, inactive_streak_peya) AS Platform_Actual_type_ternure,

        -- AAA
        aaa_adoption_date AS AAA_adoption_date,
        IF(aaa_adoption_date IS NOT NULL AND month >= aaa_adoption_date,
           DATE_DIFF(month, aaa_adoption_date, MONTH) + 1,
           NULL
        ) AS AAA_user_adoption_tenure,

        CASE
            WHEN aaa_adoption_date IS NULL OR month < aaa_adoption_date THEN 'Never Active'
            WHEN is_active_aaa AND month = aaa_adoption_date THEN 'New User'
            WHEN is_active_aaa AND active_streak_aaa = 1 THEN 'Reactivation'
            WHEN is_active_aaa AND active_streak_aaa = 2 AND DATE_DIFF(month, aaa_adoption_date, MONTH) = 1 THEN 'M1 Return'
            WHEN is_active_aaa AND active_streak_aaa = 2 THEN 'Re-Order'
            WHEN is_active_aaa AND active_streak_aaa >= 3 THEN 'Recurring Return'
            ELSE 'Churned'
        END AS AAA_Actual_Type,

        CASE
            WHEN aaa_adoption_date IS NULL OR month < aaa_adoption_date THEN DATE_DIFF(month, platform_adoption_date_global, MONTH) + 1
            WHEN is_active_aaa THEN active_streak_aaa
            ELSE inactive_streak_aaa
        END AS AAA_Actual_type_ternure,

        -- Market
        market_adoption_date AS Market_adoption_date,
        IF(market_adoption_date IS NOT NULL AND month >= market_adoption_date,
           DATE_DIFF(month, market_adoption_date, MONTH) + 1,
           NULL
        ) AS Market_user_adoption_tenure,

        CASE
            WHEN market_adoption_date IS NULL OR month < market_adoption_date THEN 'Never Active'
            WHEN is_active_market AND month = market_adoption_date THEN 'New User'
            WHEN is_active_market AND active_streak_market = 1 THEN 'Reactivation'
            WHEN is_active_market AND active_streak_market = 2 AND DATE_DIFF(month, market_adoption_date, MONTH) = 1 THEN 'M1 Return'
            WHEN is_active_market AND active_streak_market = 2 THEN 'Re-Order'
            WHEN is_active_market AND active_streak_market >= 3 THEN 'Recurring Return'
            ELSE 'Churned'
        END AS Market_Actual_Type,

        CASE
            WHEN market_adoption_date IS NULL OR month < market_adoption_date THEN DATE_DIFF(month, platform_adoption_date_global, MONTH) + 1
            WHEN is_active_market THEN active_streak_market
            ELSE inactive_streak_market
        END AS Market_Actual_type_ternure

    FROM streaks_counted
),

-- ==============================================================================
-- 7. CLASIFICACIÓN DETALLADA L2_Actual_Type (MARKET Y CROSS-NEGOCIO)
-- ==============================================================================

l2_context AS (
    SELECT
        t.*,
        LAG(t.Market_Actual_type_ternure) OVER (PARTITION BY t.customer_id, t.country ORDER BY t.month) AS prev_market_tenure,
        LAG(t.Market_Actual_type_ternure, 2) OVER (PARTITION BY t.customer_id, t.country ORDER BY t.month) AS prev_prev_market_tenure,
        LAG(t.DY_order) OVER (PARTITION BY t.customer_id, t.country ORDER BY t.month) AS prev_dy_order,
        acq.first_order_acquisition_channel
    FROM types_assigned t
    LEFT JOIN customer_acquisition acq
        ON t.customer_id = acq.customer_id
),

l2_assigned AS (
    SELECT
        *,
        CASE
            -- 1. NEVER ACTIVE
            WHEN Market_Actual_Type = 'Never Active' THEN 'Never Active'

            -- 2. NEW USER (Origen al entrar a la app)
            WHEN Market_Actual_Type = 'New User' THEN
                COALESCE(first_order_acquisition_channel, 'Acquired by Food')

            -- 3. M1 RETURN (Mes 2 en Market)
            WHEN Market_Actual_Type = 'M1 Return' THEN
                CASE
                    WHEN is_active_food AND (is_active_market OR is_active_aaa) THEN 'M1 Multi-Vertical'
                    WHEN DY_order = 'Solo DY' THEN 'M1 Dmart DY'
                    WHEN DY_order IN ('No DY', 'DY y No DY') THEN 'M1 Dmart Full'
                    WHEN is_active_aaa THEN 'M1 AAA'
                    ELSE 'M1 Food Only'
                END

            -- 4. REACTIVATION (Regreso tras inactividad)
            WHEN Market_Actual_Type = 'Reactivation' THEN
                CASE
                    WHEN DY_order = 'Solo DY' THEN 'DY Reactivation'
                    WHEN prev_market_tenure = 1 THEN 'Occasional Reactivation'
                    WHEN prev_market_tenure BETWEEN 2 AND 4 THEN 'Warm Reactivation'
                    WHEN prev_market_tenure >= 5 THEN 'True Reactivation'
                    ELSE 'Occasional Reactivation'
                END

            -- 5. RE-ORDER (Mes 2 post-reactivación)
            WHEN Market_Actual_Type = 'Re-Order' THEN
                CASE
                    WHEN prev_dy_order = 'Solo DY' AND DY_order = 'Solo DY' THEN 'Re-Order DY'
                    WHEN prev_dy_order = 'Solo DY' THEN 'Re-Order DY Converted'
                    WHEN prev_prev_market_tenure = 1 THEN 'Re-Order Occasional'
                    WHEN prev_prev_market_tenure BETWEEN 2 AND 4 THEN 'Re-Order Warm'
                    WHEN prev_prev_market_tenure >= 5 THEN 'Re-Order True'
                    ELSE 'Re-Order Occasional'
                END

            -- 6. RECURRING RETURN (Racha ininterrumpida)
            WHEN Market_Actual_Type = 'Recurring Return' THEN
                CASE
                    WHEN Market_Actual_type_ternure = 3 THEN 'Recent Recurring Return'
                    WHEN Market_Actual_type_ternure BETWEEN 4 AND 12 THEN 'Old Recurring Return'
                    ELSE 'Royal Recurring Return'
                END

            -- 7. CHURNED (Inactividad en Market)
            WHEN Market_Actual_Type = 'Churned' THEN
                CASE
                    WHEN Market_Actual_type_ternure IN (1, 2) THEN 'Recently Churn'
                    WHEN Market_Actual_type_ternure BETWEEN 3 AND 5 THEN 'Churn > 3 Months'
                    ELSE 'Churn > 6 Months'
                END

            ELSE '-'
        END AS L2_Actual_Type
    FROM l2_context
)

-- ==============================================================================
-- 8. OUTPUT FINAL
-- ==============================================================================

SELECT
    month AS Fecha,
    month AS Mes,
    customer_id,
    country,

    -- PLATFORM
    Platform_adoption_date,
    Platform_user_adoption_tenure,
    LAG(Platform_Actual_type_ternure) OVER (PARTITION BY customer_id, country ORDER BY month) AS Platform_previous_type_ternure,
    LAG(Platform_Actual_Type) OVER (PARTITION BY customer_id, country ORDER BY month) AS Platform_previous_type,
    Platform_Actual_type_ternure,
    Platform_Actual_Type,

    -- AAA
    AAA_adoption_date,
    AAA_user_adoption_tenure,
    LAG(AAA_Actual_type_ternure) OVER (PARTITION BY customer_id, country ORDER BY month) AS AAA_previous_type_ternure,
    LAG(AAA_Actual_Type) OVER (PARTITION BY customer_id, country ORDER BY month) AS AAA_previous_type,
    AAA_Actual_type_ternure,
    AAA_Actual_Type,

    -- MARKET
    Market_adoption_date,
    Market_user_adoption_tenure,
    LAG(Market_Actual_type_ternure) OVER (PARTITION BY customer_id, country ORDER BY month) AS Market_previous_type_ternure,
    LAG(Market_Actual_Type) OVER (PARTITION BY customer_id, country ORDER BY month) AS Market_previous_type,
    Market_Actual_type_ternure,
    Market_Actual_Type,
    DY_order,
    UF_order,

    -- L2 (Apertura y comportamiento en Market)
    L2_Actual_Type

FROM l2_assigned
ORDER BY customer_id, Mes;
