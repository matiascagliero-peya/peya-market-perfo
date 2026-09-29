DECLARE query_name STRING DEFAULT '4. Frank - User Count (Level 1 & 2 + Tenure)';

-- ==============================================================================
-- FRANK USER SUMMARY V2 (RESUMEN AGRUPADO LEVEL 1, LEVEL 2 Y MÉTRICAS DE TENURE)
-- ==============================================================================
-- Tabla de destino: `peya-food-and-groceries.automated_tables_reports.frank_user_type_summary`
-- Fuente:           `peya-food-and-groceries.automated_tables_reports.frank_user_type`
--
-- PROPÓSITO:
-- Consolida los conteos mensuales de usuarios por país y negocio (Dmart y PeYa)
-- desglosando la taxonomía completa (Level 1 y Level 2), junto con las métricas
-- de Tenure promedio (antigüedad en el negocio, antigüedad en la app, racha
-- ininterrumpida de compras y tiempo transcurrido desde que fueron Recurring Return).
-- ==============================================================================

CREATE OR REPLACE TABLE `peya-food-and-groceries.automated_tables_reports.frank_user_type_summary` AS

WITH unnested_data AS (
    SELECT
        month,
        country,
        business,
        customer_id,
        user_type_l1,
        user_type_l2,
        legacy_user_type,
        is_active,
        tenure_business_months,
        user_tenure_months_peya,
        consecutive_active_months,
        tenure_rr_streak_months,
        last_rr_month,
        months_since_last_rr
    FROM `peya-food-and-groceries.automated_tables_reports.frank_user_type`,
    UNNEST([
        STRUCT(
            'Dmart' AS business,
            COALESCE(user_type_l1_dmart, 'Never Active') AS user_type_l1,
            COALESCE(user_type_l2_dmart, 'Never Active') AS user_type_l2,
            COALESCE(Type_dmart, 'Never Active') AS legacy_user_type,
            COALESCE(is_active_dmart, FALSE) AS is_active,
            user_tenure_months_dmart AS tenure_business_months,
            user_tenure_months_peya AS user_tenure_months_peya,
            consecutive_active_months_dmart AS consecutive_active_months,
            tenure_rr_streak_months_dmart AS tenure_rr_streak_months,
            last_rr_month_dmart AS last_rr_month,
            months_since_last_rr_dmart AS months_since_last_rr
        ),
        STRUCT(
            'PeYa' AS business,
            COALESCE(user_type_l1_peya, 'Never Active') AS user_type_l1,
            COALESCE(user_type_l2_peya, 'Never Active') AS user_type_l2,
            COALESCE(Type_Peya, 'Never Active') AS legacy_user_type,
            COALESCE(is_active_peya, FALSE) AS is_active,
            user_tenure_months_peya AS tenure_business_months,
            user_tenure_months_peya AS user_tenure_months_peya,
            consecutive_active_months_peya AS consecutive_active_months,
            tenure_rr_streak_months_peya AS tenure_rr_streak_months,
            last_rr_month_peya AS last_rr_month,
            months_since_last_rr_peya AS months_since_last_rr
        )
    ])
)

SELECT
    month,
    country,
    business,
    user_type_l1,
    user_type_l2,
    legacy_user_type,

    -- Conteo de Usuarios Únicos
    COUNT(DISTINCT customer_id) AS total_users,

    -- Antigüedad promedio en el negocio analizado (Dmart o PeYa)
    ROUND(AVG(tenure_business_months), 2) AS avg_tenure_business_months,

    -- Antigüedad promedio en la plataforma global PeYa
    ROUND(AVG(user_tenure_months_peya), 2) AS avg_tenure_peya_months,

    -- Racha ininterrumpida promedio de meses activos (solo para usuarios activos ese mes)
    ROUND(AVG(IF(is_active, consecutive_active_months, NULL)), 2) AS avg_consecutive_active_months,

    -- Antigüedad acumulada promedio dentro de la racha RR (solo para usuarios en Recurring Return)
    ROUND(AVG(IF(user_type_l1 = 'Recurring Return', tenure_rr_streak_months, NULL)), 2) AS avg_tenure_rr_streak_months,

    -- Meses promedio transcurridos desde que el usuario fue Recurring Return por última vez
    ROUND(AVG(months_since_last_rr), 2) AS avg_months_since_last_rr,

    -- Cantidad y proporción de usuarios en este segmento que alguna vez fueron Recurring Return
    COUNT(DISTINCT IF(last_rr_month IS NOT NULL, customer_id, NULL)) AS users_ever_rr,
    ROUND(SAFE_DIVIDE(COUNT(DISTINCT IF(last_rr_month IS NOT NULL, customer_id, NULL)), COUNT(DISTINCT customer_id)), 4) AS pct_users_ever_rr

FROM unnested_data

GROUP BY 1, 2, 3, 4, 5, 6
ORDER BY month DESC, country, business, total_users DESC;