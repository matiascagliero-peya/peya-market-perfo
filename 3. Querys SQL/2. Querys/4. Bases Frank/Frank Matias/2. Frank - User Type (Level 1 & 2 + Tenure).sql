-- ==============================================================================
-- TABLA 2: Frank - User Type (Motor de Ciclo de Vida L1 y L2: Market + AAA)
-- Destino: peya-food-and-groceries.automated_tables_reports.frank_user_type_monthly
-- ==============================================================================

DROP TABLE IF EXISTS `peya-food-and-groceries.automated_tables_reports.frank_user_type_monthly`;

CREATE OR REPLACE TABLE `peya-food-and-groceries.automated_tables_reports.frank_user_type_monthly`
PARTITION BY Mes
CLUSTER BY country, customer_id AS

WITH

-- 1. Base consolidada desde la tabla de actividad previa
base_activity AS (
    SELECT
        month,
        customer_id,
        country,
        is_active_platform,
        is_active_food,
        is_active_aaa,
        is_active_dmart AS is_active_market,
        DY_order,
        UF_order
    FROM `peya-food-and-groceries.automated_tables_reports.frank_user_monthly_activity`
    WHERE country IS NOT NULL
),

-- 2. Detección de fechas de adopción y próxima compra por negocio
customer_adoptions AS (
    SELECT
        *,
        MIN(month) OVER (PARTITION BY customer_id) AS platform_adoption_date_global,
        MIN(month) OVER (PARTITION BY customer_id, country) AS platform_adoption_date_country,
        MIN(IF(is_active_aaa, month, NULL)) OVER (PARTITION BY customer_id) AS aaa_adoption_date,
        MIN(IF(is_active_market, month, NULL)) OVER (PARTITION BY customer_id) AS market_adoption_date,
        LEAD(month) OVER (PARTITION BY customer_id, country ORDER BY month) AS next_month
    FROM base_activity
),

-- 3. Timeline continuo y generación de meses fantasma para usuarios inactivos
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
        DY_order,
        UF_order
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
        'No DY' AS DY_order,
        'No UF' AS UF_order
    FROM customer_adoptions,
         UNNEST(GENERATE_ARRAY(1, 60)) AS gap
    WHERE (next_month IS NULL OR DATE_DIFF(next_month, month, MONTH) > gap)
      AND DATE_ADD(month, INTERVAL gap MONTH) <= DATE_TRUNC(CURRENT_DATE(), MONTH)
),

-- 4. Cálculo de grupos de racha (Islands & Gaps)
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

-- 5. Enumeración de meses consecutivos activos e inactivos
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

-- 6. Asignación de macro estados L1 y tenures
types_assigned AS (
    SELECT
        month,
        customer_id,
        country,
        is_active_food,
        is_active_aaa,
        is_active_market,
        DY_order,
        UF_order,

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

-- 7. Contexto de estados y tenures previos (LAG)
l2_context AS (
    SELECT
        t.*,
        -- Contexto Market
        LAG(t.Market_Actual_type_ternure) OVER (PARTITION BY t.customer_id, t.country ORDER BY t.month) AS prev_market_tenure,
        LAG(t.Market_Actual_type_ternure, 2) OVER (PARTITION BY t.customer_id, t.country ORDER BY t.month) AS prev_prev_market_tenure,
        LAG(t.DY_order) OVER (PARTITION BY t.customer_id, t.country ORDER BY t.month) AS prev_dy_order,
        MIN(IF(t.is_active_market AND t.month = t.Market_adoption_date, t.DY_order, NULL)) OVER (PARTITION BY t.customer_id) AS market_adoption_dy,

        -- Contexto AAA
        LAG(t.AAA_Actual_type_ternure) OVER (PARTITION BY t.customer_id, t.country ORDER BY t.month) AS prev_aaa_tenure,
        LAG(t.AAA_Actual_type_ternure, 2) OVER (PARTITION BY t.customer_id, t.country ORDER BY t.month) AS prev_prev_aaa_tenure,
        MIN(IF(t.is_active_aaa AND t.month = t.AAA_adoption_date, t.DY_order, NULL)) OVER (PARTITION BY t.customer_id) AS aaa_adoption_dy
    FROM types_assigned t
),

-- 8. Clasificación de Level 2 (Market y AAA)
l2_assigned AS (
    SELECT
        *,

        -- L2 PeYa Market
        CASE
            -- 1. Never Active
            WHEN Market_Actual_Type = 'Never Active' THEN '-'

            -- 2. New User
            WHEN Market_Actual_Type = 'New User' THEN
                CASE
                    WHEN DY_order = 'Solo DY' THEN 'DY Adoption'
                    WHEN month = Platform_adoption_date THEN 'App Adoption'
                    WHEN AAA_adoption_date IS NOT NULL AND AAA_adoption_date < Market_adoption_date THEN 'AAA Adoption'
                    ELSE 'Dmart Adoption'
                END

            -- 3. M1 Return
            WHEN Market_Actual_Type = 'M1 Return' THEN
                CASE
                    WHEN market_adoption_dy = 'Solo DY' AND DY_order = 'Solo DY' THEN 'M1 Dmart DY'
                    WHEN market_adoption_dy = 'Solo DY' THEN 'M1 Dmart DY Converted'
                    ELSE 'M1 Return Users - Dmart'
                END

            -- 4. Reactivation
            WHEN Market_Actual_Type = 'Reactivation' THEN
                CASE
                    WHEN DY_order = 'Solo DY' THEN 'DY Reactivation'
                    WHEN prev_market_tenure = 1 THEN 'Occasional Reactivation'
                    WHEN prev_market_tenure BETWEEN 2 AND 4 THEN 'Warm Reactivation'
                    WHEN prev_market_tenure >= 5 THEN 'True Reactivation'
                    ELSE 'Occasional Reactivation'
                END

            -- 5. Re-Order
            WHEN Market_Actual_Type = 'Re-Order' THEN
                CASE
                    WHEN prev_dy_order = 'Solo DY' AND DY_order = 'Solo DY' THEN 'Re-Order DY'
                    WHEN prev_dy_order = 'Solo DY' THEN 'Re-Order DY Converted'
                    WHEN prev_prev_market_tenure = 1 THEN 'Re-Order Occasional'
                    WHEN prev_prev_market_tenure BETWEEN 2 AND 4 THEN 'Re-Order Warm'
                    WHEN prev_prev_market_tenure >= 5 THEN 'Re-Order True'
                    ELSE 'Re-Order Occasional'
                END

            -- 6. Recurring Return
            WHEN Market_Actual_Type = 'Recurring Return' THEN
                CASE
                    WHEN Market_Actual_type_ternure = 3 THEN 'Recent Recurring Return'
                    WHEN Market_Actual_type_ternure BETWEEN 4 AND 12 THEN 'Old Recurring Return'
                    ELSE 'Royal Recurring Return'
                END

            -- 7. Churned
            WHEN Market_Actual_Type = 'Churned' THEN
                CASE
                    WHEN Market_Actual_type_ternure IN (1, 2) THEN 'Recently Churn'
                    WHEN Market_Actual_type_ternure BETWEEN 3 AND 5 THEN 'Churn > 3 Months'
                    ELSE 'Churn > 6 Months'
                END

            ELSE '-'
        END AS L2_Market_Actual_Type,

        -- L2 AAA
        CASE
            -- 1. Never Active
            WHEN AAA_Actual_Type = 'Never Active' THEN '-'

            -- 2. New User
            WHEN AAA_Actual_Type = 'New User' THEN
                CASE
                    WHEN DY_order = 'Solo DY' THEN 'DY Adoption'
                    WHEN month = Platform_adoption_date THEN 'App Adoption'
                    WHEN Market_adoption_date IS NOT NULL AND Market_adoption_date < AAA_adoption_date THEN 'Dmart Adoption'
                    ELSE 'AAA Adoption'
                END

            -- 3. M1 Return
            WHEN AAA_Actual_Type = 'M1 Return' THEN
                CASE
                    WHEN aaa_adoption_dy = 'Solo DY' AND DY_order = 'Solo DY' THEN 'M1 AAA DY'
                    WHEN aaa_adoption_dy = 'Solo DY' THEN 'M1 AAA DY Converted'
                    ELSE 'M1 Return Users - AAA'
                END

            -- 4. Reactivation
            WHEN AAA_Actual_Type = 'Reactivation' THEN
                CASE
                    WHEN DY_order = 'Solo DY' THEN 'DY Reactivation'
                    WHEN prev_aaa_tenure = 1 THEN 'Occasional Reactivation'
                    WHEN prev_aaa_tenure BETWEEN 2 AND 4 THEN 'Warm Reactivation'
                    WHEN prev_aaa_tenure >= 5 THEN 'True Reactivation'
                    ELSE 'Occasional Reactivation'
                END

            -- 5. Re-Order
            WHEN AAA_Actual_Type = 'Re-Order' THEN
                CASE
                    WHEN prev_dy_order = 'Solo DY' AND DY_order = 'Solo DY' THEN 'Re-Order DY'
                    WHEN prev_dy_order = 'Solo DY' THEN 'Re-Order DY Converted'
                    WHEN prev_prev_aaa_tenure = 1 THEN 'Re-Order Occasional'
                    WHEN prev_prev_aaa_tenure BETWEEN 2 AND 4 THEN 'Re-Order Warm'
                    WHEN prev_prev_aaa_tenure >= 5 THEN 'Re-Order True'
                    ELSE 'Re-Order Occasional'
                END

            -- 6. Recurring Return
            WHEN AAA_Actual_Type = 'Recurring Return' THEN
                CASE
                    WHEN AAA_Actual_type_ternure = 3 THEN 'Recent Recurring Return'
                    WHEN AAA_Actual_type_ternure BETWEEN 4 AND 12 THEN 'Old Recurring Return'
                    ELSE 'Royal Recurring Return'
                END

            -- 7. Churned
            WHEN AAA_Actual_Type = 'Churned' THEN
                CASE
                    WHEN AAA_Actual_type_ternure IN (1, 2) THEN 'Recently Churn'
                    WHEN AAA_Actual_type_ternure BETWEEN 3 AND 5 THEN 'Churn > 3 Months'
                    ELSE 'Churn > 6 Months'
                END

            ELSE '-'
        END AS L2_AAA_Actual_Type

    FROM l2_context
)

-- 9. Salida final estructurada (26 columnas)
SELECT
    month AS Fecha,
    month AS Mes,
    customer_id,
    country,

    -- Platform
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
    L2_AAA_Actual_Type,

    -- Market
    Market_adoption_date,
    Market_user_adoption_tenure,
    LAG(Market_Actual_type_ternure) OVER (PARTITION BY customer_id, country ORDER BY month) AS Market_previous_type_ternure,
    LAG(Market_Actual_Type) OVER (PARTITION BY customer_id, country ORDER BY month) AS Market_previous_type,
    Market_Actual_type_ternure,
    Market_Actual_Type,
    L2_Market_Actual_Type,
    DY_order,
    UF_order

FROM l2_assigned;
