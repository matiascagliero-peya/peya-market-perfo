DECLARE query_name STRING DEFAULT '4. New users in 60 days - Base - Performance';

-- Sheets Name: 1. ET - New user>60 (23 - New user>60)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1P3DswnPrt7VF3DM1jC-IhtoOKmI6CRWx_Hbf-5qYaDk


-- 4. New users in 60 days - Base - Performance
-- Fuente oficial: frank_user_type_monthly (Frank Matias)
-- Mide cohortes de nuevos usuarios desde 2025 y su retención a 60 días (meses 2 y 3)
-- en Plataforma (PeYa) vs PeYa Market (Dmart)
-- ==============================================================================

WITH peya_base AS (
    -- 1. Buscamos a cada usuario y su FECHA DE NACIMIENTO en Plataforma (PeYa)
    SELECT 
        customer_id,
        MAX(CASE WHEN Platform_user_adoption_tenure = 1 THEN Mes END) AS mes_nacimiento,
        
        -- Homologamos el país para mitigar problemas de tildes o códigos ISO
        MAX(CASE WHEN Platform_user_adoption_tenure = 1 THEN 
            CASE 
                WHEN LOWER(country) IN ('peru', 'perú', 'pe') THEN 'Perú'
                WHEN LOWER(country) IN ('panama', 'panamá', 'pa') THEN 'Panamá'
                WHEN LOWER(country) IN ('dominican republic', 'república dominicana', 'republica dominicana', 'do', 'dominicana') THEN 'República Dominicana'
                ELSE country 
            END
        END) AS country,
        
        -- ¿Nació como New User en Plataforma?
        MAX(CASE WHEN Platform_user_adoption_tenure = 1 AND Platform_Actual_Type = 'New User' THEN 1 ELSE 0 END) AS is_new_peya,
        
        -- ¿Compró en su mes 2 o 3? (Ventana de 60 días activa en Plataforma)
        MAX(CASE WHEN Platform_user_adoption_tenure IN (2, 3) 
                  AND Platform_Actual_Type NOT IN ('Churned', 'Never Active') 
             THEN 1 ELSE 0 END) AS return_peya_ventana2m
             
    FROM `peya-food-and-groceries.automated_tables_reports.frank_user_type_monthly`
    WHERE Mes >= '2025-01-01'
      AND Platform_adoption_date >= '2025-01-01'
      AND Platform_user_adoption_tenure IN (1, 2, 3)
      AND country NOT IN ('Venezuela', 'Costa Rica')
    GROUP BY customer_id
),
peya_metrics AS (
    -- 2. Agrupamos por mes de nacimiento y país en Plataforma
    SELECT 
        mes_nacimiento AS month, 
        country,
        SUM(is_new_peya) AS new_users_peya,
        SUM(CASE WHEN is_new_peya = 1 AND return_peya_ventana2m = 1 THEN 1 ELSE 0 END) AS m1_return_peya_ventana2m
    FROM peya_base
    WHERE mes_nacimiento IS NOT NULL
    GROUP BY 1, 2
),

dmart_base AS (
    -- 1. Buscamos a cada usuario y su FECHA DE NACIMIENTO en PeYa Market (Dmart)
    SELECT 
        customer_id,
        MAX(CASE WHEN Market_user_adoption_tenure = 1 THEN Mes END) AS mes_nacimiento,
        
        -- Homologamos el país también para Market
        MAX(CASE WHEN Market_user_adoption_tenure = 1 THEN 
            CASE 
                WHEN LOWER(country) IN ('peru', 'perú', 'pe') THEN 'Perú'
                WHEN LOWER(country) IN ('panama', 'panamá', 'pa') THEN 'Panamá'
                WHEN LOWER(country) IN ('dominican republic', 'república dominicana', 'republica dominicana', 'do', 'dominicana') THEN 'República Dominicana'
                ELSE country 
            END
        END) AS country,
        
        -- ¿Nació como New User en Market?
        MAX(CASE WHEN Market_user_adoption_tenure = 1 AND Market_Actual_Type = 'New User' THEN 1 ELSE 0 END) AS is_new_dmart,
        
        -- ¿Compró en su mes 2 o 3? (Ventana de 60 días activa en Market)
        MAX(CASE WHEN Market_user_adoption_tenure IN (2, 3) 
                  AND Market_Actual_Type NOT IN ('Churned', 'Never Active') 
             THEN 1 ELSE 0 END) AS return_dmart_ventana2m
             
    FROM `peya-food-and-groceries.automated_tables_reports.frank_user_type_monthly`
    WHERE Mes >= '2025-01-01'
      AND Market_adoption_date >= '2025-01-01'
      AND Market_user_adoption_tenure IN (1, 2, 3)
      AND country NOT IN ('Venezuela', 'Costa Rica')
    GROUP BY customer_id
),
dmart_metrics AS (
    -- 2. Agrupamos por nacimiento en Dmart
    SELECT 
        mes_nacimiento AS month, 
        country,
        SUM(is_new_dmart) AS new_users_dmart,
        SUM(CASE WHEN is_new_dmart = 1 AND return_dmart_ventana2m = 1 THEN 1 ELSE 0 END) AS m1_return_dmart_ventana2m
    FROM dmart_base
    WHERE mes_nacimiento IS NOT NULL
    GROUP BY 1, 2
)

-- 3. UNIÓN FINAL
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