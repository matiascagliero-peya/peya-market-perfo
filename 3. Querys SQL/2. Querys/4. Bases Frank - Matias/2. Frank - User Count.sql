DECLARE query_name STRING DEFAULT '2. Frank - User Count';

CREATE OR REPLACE TABLE `peya-food-and-groceries.automated_tables_reports.frank_user_type_summary` AS

WITH unnested_data AS (
    SELECT
        month,
        country,
        business,
        customer_id,
        user_type,
        previous_user_type,
        is_active,
        country_tenure_months,
        user_tenure_months,
        tenure_user_type,
        tenure_rr_streak
    FROM `peya-food-and-groceries.automated_tables_reports.frank_user_type`,
    UNNEST([
        STRUCT(
            'Dmart' AS business,
            COALESCE(Type_dmart, 'Never Active') AS user_type,
            previous_type_dmart AS previous_user_type,
            COALESCE(is_active_dmart, FALSE) AS is_active,
            country_tenure_months_dmart AS country_tenure_months,
            user_tenure_months_dmart AS user_tenure_months,
            tenure_user_type_dmart AS tenure_user_type,
            tenure_rr_streak_dmart AS tenure_rr_streak
        ),
        STRUCT(
            'PeYa' AS business,
            COALESCE(Type_Peya, 'Never Active') AS user_type,
            previous_type_peya AS previous_user_type,
            COALESCE(is_active_peya, FALSE) AS is_active,
            country_tenure_months_peya AS country_tenure_months,
            user_tenure_months_peya AS user_tenure_months,
            tenure_user_type_peya AS tenure_user_type,
            tenure_rr_streak_peya AS tenure_rr_streak
        )
    ])
)

SELECT
    month,
    country,
    business,
    user_type,

    -- Conteo de Usuarios Únicos
    COUNT(DISTINCT customer_id) AS total_users,

    -- 1. Tenure promedio por País (meses de vida en ese país)
    ROUND(AVG(country_tenure_months), 2) AS avg_country_tenure_months,

    -- 2. Tenure promedio de los Usuarios (meses de vida global del cliente)
    ROUND(AVG(user_tenure_months), 2) AS avg_user_tenure_months,

    -- 3. Tenure promedio en el Tipo de Usuario actual (meses continuos en el estado desde último cambio)
    ROUND(AVG(tenure_user_type), 2) AS avg_tenure_user_type,

    -- Racha acumulada promedio como Recurring Return (solo para usuarios actualmente en RR)
    ROUND(AVG(IF(user_type = 'Recurring Return', tenure_rr_streak, NULL)), 2) AS avg_tenure_rr_streak

FROM unnested_data

GROUP BY 1, 2, 3, 4
ORDER BY month DESC, country, business, total_users DESC;
