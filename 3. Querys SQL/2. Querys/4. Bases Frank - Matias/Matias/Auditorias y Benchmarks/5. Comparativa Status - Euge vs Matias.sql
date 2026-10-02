-- ==============================================================================
-- QUERY DE COMPARACIÓN: Euge (latam_dmart_growth_tracker) vs Matias (frank_user_type_monthly)
-- ==============================================================================

SELECT
    COALESCE(e.month, m.Mes) AS month,
    COALESCE(e.country, m.country) AS country,
    COALESCE(e.status, m.status)   AS user_type,

    e.users_euge,
    m.users_matias,
    
    (m.users_matias - e.users_euge) AS diff_absoluta,
    ROUND(SAFE_DIVIDE(m.users_matias - e.users_euge, e.users_euge) * 100, 2) AS diff_porcentual

FROM (
    -- 1. BASE DE EUGE (Normalizando nombres de etiquetas)
    SELECT
        DATE_TRUNC(month, MONTH) AS month,
        country_name AS country,
        CASE
            WHEN dmart_growth_status_fixed = 'Adoption'    THEN 'New User'
            WHEN dmart_growth_status_fixed = 'Reactivated' THEN 'Reactivation'
            WHEN dmart_growth_status_fixed = 'Reorder'     THEN 'Re-Order'
            ELSE dmart_growth_status_fixed
        END AS status,
        COUNT(DISTINCT customer_id) AS users_euge
    FROM `peya-food-and-groceries.automated_tables_reports.latam_dmart_growth_tracker`
    WHERE month >= '2026-07-01' 
      AND country_name IN ('Argentina', 'Chile', 'Uruguay')
    GROUP BY 1, 2, 3
) e

FULL OUTER JOIN (
    -- 2. BASE NUESTRA MODERNIZADA
    SELECT
        Mes,
        country,
        Market_Actual_Type AS status,
        COUNT(DISTINCT customer_id) AS users_matias
    FROM `peya-food-and-groceries.automated_tables_reports.frank_user_type_monthly`
    WHERE Mes >= '2026-07-01' 
      AND country IN ('Argentina', 'Chile', 'Uruguay')
    GROUP BY 1, 2, 3
) m
ON  e.month   = m.Mes 
AND e.country = m.country 
AND e.status  = m.status

WHERE COALESCE(e.status, m.status) NOT IN ('Never Active')
ORDER BY month DESC, country, users_matias DESC;
