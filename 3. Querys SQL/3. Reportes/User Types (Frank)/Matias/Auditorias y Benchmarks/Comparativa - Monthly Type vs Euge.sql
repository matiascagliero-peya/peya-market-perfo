-- 3. COMPARATIVA DIRECTA: Monthly Type (Matias) vs Growth Tracker (Euge)

WITH

-- 1. BASE MONTHLY TYPE (Tu tabla de usuarios sin Never Active ni Churned)
monthly_type AS (
    SELECT
        DATE_TRUNC(Mes, MONTH) AS Mes,
        country                AS Pais,
        Market_Actual_Type     AS Status,
        COUNT(DISTINCT customer_id) AS Usuarios_Monthly_Type
    FROM `peya-food-and-groceries.automated_tables_reports.frank_user_type_monthly`
    WHERE Mes >= '2025-01-01'
      AND Mes <= '2026-09-01'
      AND country NOT IN ('Venezuela', 'Costa Rica')
      AND Market_Actual_Type NOT IN ('Never Active', 'Churned')
    GROUP BY 1, 2, 3
),

-- 2. BASE EUGE (Growth Tracker sin Churned)
euge_growth_tracker AS (
    SELECT
        DATE_TRUNC(month, MONTH) AS Mes,
        COALESCE(country_name_es, country_name) AS Pais,
        CASE
            WHEN dmart_growth_status_fixed = 'Adoption'    THEN 'New User'
            WHEN dmart_growth_status_fixed = 'Reactivated' THEN 'Reactivation'
            WHEN dmart_growth_status_fixed = 'Reorder'     THEN 'Re-Order'
            ELSE dmart_growth_status_fixed
        END AS Status,
        COUNT(DISTINCT customer_id) AS Usuarios_Euge
    FROM `peya-food-and-groceries.automated_tables_reports.latam_dmart_growth_tracker`
    WHERE month >= '2025-01-01'
      AND month <= '2026-09-01'
      AND COALESCE(country_name_es, country_name) NOT IN ('Venezuela', 'Costa Rica')
      AND dmart_growth_status_fixed != 'Churned'
    GROUP BY 1, 2, 3
)

-- 3. COMPARATIVA DIRECTA Y DIFERENCIAS
SELECT
    COALESCE(m.Mes,    e.Mes)    AS Mes,
    COALESCE(m.Pais,   e.Pais)   AS Pais,
    COALESCE(m.Status, e.Status) AS Status,

    COALESCE(m.Usuarios_Monthly_Type, 0) AS Usuarios_Monthly_Type,
    COALESCE(e.Usuarios_Euge, 0)         AS Usuarios_Euge,

    (COALESCE(m.Usuarios_Monthly_Type, 0) - COALESCE(e.Usuarios_Euge, 0)) AS Diff_Usuarios,

FROM monthly_type m
FULL OUTER JOIN euge_growth_tracker e
    ON  m.Mes    = e.Mes
    AND m.Pais   = e.Pais
    AND m.Status = e.Status

ORDER BY Mes DESC, Pais, Usuarios_Monthly_Type DESC;
