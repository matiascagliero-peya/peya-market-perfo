DECLARE query_name STRING DEFAULT 'Auditoría - Frank User Type Monthly';

-- ==============================================================================
-- QUERY DE AUDITORÍA: Verificación y Control de Calidad de Tabla 2
--
-- Tabla evaluada: peya-food-and-groceries.automated_tables_reports.frank_user_type_monthly
--
-- Objetivos:
--   1. Sanity Checks: Nulos, duplicados y consistencia de tenures.
--   2. Coherencia Matemática L1 vs Rachas: New User=1, M1=2, Re-Order=2, RR>=3.
--   3. Coherencia L1 vs L2: Que cada L2 pertenezca estrictamente a su L1.
--   4. Foto de Distribución Mensual: Volúmenes por L1 y L2 en los últimos meses.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- CHEQUEO 1: Sanity Checks de Integridad y Lógica Matemática (Todos deben dar 0)
-- ------------------------------------------------------------------------------
SELECT
    '1. Control de Integridad y Reglas de Ciclo de Vida' AS control_tipo,

    -- A. Nulos y duplicados
    COUNTIF(customer_id IS NULL) AS err_null_customer_id,
    COUNTIF(Mes IS NULL)         AS err_null_month,
    COUNTIF(country IS NULL)     AS err_null_country,
    COUNT(*) - COUNT(DISTINCT CONCAT(CAST(Mes AS STRING), '-', country, '-', customer_id)) AS err_duplicated_rows,

    -- B. Nulos en Tipos
    COUNTIF(Platform_Actual_Type IS NULL) AS err_null_platform_type,
    COUNTIF(Market_Actual_Type IS NULL)   AS err_null_market_type,
    COUNTIF(AAA_Actual_Type IS NULL)      AS err_null_aaa_type,
    COUNTIF(L2_Actual_Type IS NULL)       AS err_null_l2_type,
    COUNTIF(L2_Actual_Type = '-')         AS err_l2_sin_clasificar,

    -- C. Consistencia de Tenures en Market
    COUNTIF(Market_Actual_Type = 'New User'         AND Market_Actual_type_ternure != 1) AS err_new_user_tenure_no_1,
    COUNTIF(Market_Actual_Type = 'M1 Return'        AND Market_Actual_type_ternure != 2) AS err_m1_return_tenure_no_2,
    COUNTIF(Market_Actual_Type = 'Re-Order'         AND Market_Actual_type_ternure != 2) AS err_reorder_tenure_no_2,
    COUNTIF(Market_Actual_Type = 'Recurring Return' AND Market_Actual_type_ternure < 3)  AS err_rr_tenure_menor_3,
    COUNTIF(Market_Actual_Type = 'Reactivation'     AND Market_Actual_type_ternure != 1) AS err_reactivation_tenure_no_1,
    COUNTIF(Market_Actual_Type = 'Never Active'     AND Market_user_adoption_tenure IS NOT NULL) AS err_never_active_con_adopcion,

    -- D. Consistencia L1 vs L2
    COUNTIF(Market_Actual_Type = 'Never Active'     AND L2_Actual_Type != 'Never Active') AS err_l2_incoherente_never_active,
    COUNTIF(Market_Actual_Type = 'New User'         AND NOT STARTS_WITH(L2_Actual_Type, 'Acquired by')) AS err_l2_incoherente_new_user,
    COUNTIF(Market_Actual_Type = 'M1 Return'        AND NOT STARTS_WITH(L2_Actual_Type, 'M1 ')) AS err_l2_incoherente_m1,
    COUNTIF(Market_Actual_Type = 'Reactivation'     AND NOT ENDS_WITH(L2_Actual_Type, 'Reactivation')) AS err_l2_incoherente_reactivation,
    COUNTIF(Market_Actual_Type = 'Re-Order'         AND NOT STARTS_WITH(L2_Actual_Type, 'Re-Order')) AS err_l2_incoherente_reorder,
    COUNTIF(Market_Actual_Type = 'Recurring Return' AND NOT ENDS_WITH(L2_Actual_Type, 'Recurring Return')) AS err_l2_incoherente_rr,
    COUNTIF(Market_Actual_Type = 'Churned'          AND NOT (STARTS_WITH(L2_Actual_Type, 'Recently Churn') OR STARTS_WITH(L2_Actual_Type, 'Churn >'))) AS err_l2_incoherente_churned

FROM `peya-food-and-groceries.automated_tables_reports.frank_user_type_monthly`;


-- ------------------------------------------------------------------------------
-- CHEQUEO 2: Distribución de Usuarios por Estado L1 de Market (Últimos 2 Meses)
-- ------------------------------------------------------------------------------
SELECT
    Mes,
    country,
    Market_Actual_Type,
    COUNT(DISTINCT customer_id) AS total_users,
    ROUND(AVG(Market_Actual_type_ternure), 2) AS avg_actual_tenure,
    ROUND(AVG(Market_user_adoption_tenure), 2) AS avg_adoption_tenure,
    COUNTIF(DY_order IN ('Solo DY', 'DY y No DY')) AS users_with_dy,
    COUNTIF(UF_order IN ('Solo UF', 'UF y No UF')) AS users_with_uf
FROM `peya-food-and-groceries.automated_tables_reports.frank_user_type_monthly`
WHERE Mes >= DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 2 MONTH), MONTH)
  AND country IN ('Argentina', 'Chile', 'Uruguay')
GROUP BY 1, 2, 3
ORDER BY 1 DESC, 2, total_users DESC;


-- ------------------------------------------------------------------------------
-- CHEQUEO 3: Distribución Detallada por L2_Actual_Type en Market (Último Mes)
-- ------------------------------------------------------------------------------
SELECT
    Mes,
    country,
    Market_Actual_Type,
    L2_Actual_Type,
    COUNT(DISTINCT customer_id) AS users_count,
    ROUND(AVG(Market_Actual_type_ternure), 2) AS avg_tenure
FROM `peya-food-and-groceries.automated_tables_reports.frank_user_type_monthly`
WHERE Mes = DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)
  AND country = 'Argentina'
GROUP BY 1, 2, 3, 4
ORDER BY Market_Actual_Type, users_count DESC;
