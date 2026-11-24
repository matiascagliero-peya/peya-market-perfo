DECLARE query_name STRING DEFAULT '4. New users in 60 days - Base - Performance';

-- Sheets Name: 1. ET - New user>60 (23 - New user>60)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1P3DswnPrt7VF3DM1jC-IhtoOKmI6CRWx_Hbf-5qYaDk

-- ==============================================================================
-- 4. New users in 60 days - Base - Performance
-- Fuente oficial: frank_user_type_monthly (Frank Matias)
-- Mide cohortes de nuevos usuarios desde 2025 y su retención a 60 días (meses 2 y 3)
-- en Plataforma (PeYa) vs PeYa Market (Dmart)
-- Grain: (month, country)
-- ==============================================================================

WITH user_agg AS (
    -- 1. Unificación en una sola pasada: detección de cohorte de nacimiento y retorno en meses 2 y 3
    SELECT
        customer_id,
        country,
        -- Plataforma (PeYa)
        MAX(CASE WHEN Platform_user_adoption_tenure = 1 THEN Mes END) AS mes_nacimiento_peya,
        MAX(CASE WHEN Platform_user_adoption_tenure = 1 AND Platform_Actual_Type = 'New User' THEN 1 ELSE 0 END) AS is_new_peya,
        MAX(CASE WHEN Platform_user_adoption_tenure IN (2, 3) 
                  AND Platform_Actual_Type NOT IN ('Churned', 'Never Active') THEN 1 ELSE 0 END) AS return_peya,
        -- PeYa Market (Dmart)
        MAX(CASE WHEN Market_user_adoption_tenure = 1 THEN Mes END) AS mes_nacimiento_dmart,
        MAX(CASE WHEN Market_user_adoption_tenure = 1 AND Market_Actual_Type = 'New User' THEN 1 ELSE 0 END) AS is_new_dmart,
        MAX(CASE WHEN Market_user_adoption_tenure IN (2, 3) 
                  AND Market_Actual_Type NOT IN ('Churned', 'Never Active') THEN 1 ELSE 0 END) AS return_dmart
    FROM `peya-food-and-groceries.automated_tables_reports.frank_user_type_monthly`
    WHERE Mes >= '2025-01-01'
      AND country NOT IN ('Venezuela', 'Costa Rica')
      AND (
          (Platform_adoption_date >= '2025-01-01' AND Platform_user_adoption_tenure IN (1, 2, 3))
       OR (Market_adoption_date >= '2025-01-01' AND Market_user_adoption_tenure IN (1, 2, 3))
      )
    GROUP BY customer_id, country
),

peya_metrics AS (
    -- 2. Métricas de Plataforma agregadas por cohorte y país
    SELECT
        mes_nacimiento_peya AS month,
        country,
        SUM(is_new_peya) AS new_users_peya,
        SUM(IF(is_new_peya = 1 AND return_peya = 1, 1, 0)) AS m1_return_peya_ventana2m
    FROM user_agg
    WHERE mes_nacimiento_peya IS NOT NULL
    GROUP BY 1, 2
),

dmart_metrics AS (
    -- 3. Métricas de Dmart agregadas por cohorte y país
    SELECT
        mes_nacimiento_dmart AS month,
        country,
        SUM(is_new_dmart) AS new_users_dmart,
        SUM(IF(is_new_dmart = 1 AND return_dmart = 1, 1, 0)) AS m1_return_dmart_ventana2m
    FROM user_agg
    WHERE mes_nacimiento_dmart IS NOT NULL
    GROUP BY 1, 2
)

-- 4. Consolidado final alineado con las columnas que consume Apps Script (Hoja 23)
SELECT 
    COALESCE(p.month, d.month) AS month,
    COALESCE(p.country, d.country) AS country,
    
    COALESCE(p.new_users_peya, 0) AS new_users_peya,
    COALESCE(p.m1_return_peya_ventana2m, 0) AS m1_return_peya_ventana2m,
    SAFE_DIVIDE(p.m1_return_peya_ventana2m, p.new_users_peya) AS retention_rate_peya,
    
    COALESCE(d.new_users_dmart, 0) AS new_users_dmart,
    COALESCE(d.m1_return_dmart_ventana2m, 0) AS m1_return_dmart_ventana2m,
    SAFE_DIVIDE(d.m1_return_dmart_ventana2m, d.new_users_dmart) AS retention_rate_dmart

FROM peya_metrics p
FULL OUTER JOIN dmart_metrics d 
    ON p.month = d.month AND p.country = d.country
ORDER BY 1 DESC, 2 ASC;
