DECLARE query_name STRING DEFAULT '1. Frank - User Type.sql';

CREATE OR REPLACE TABLE `peya-food-and-groceries.automated_tables_reports.frank_user_type` AS

WITH 

-- ==============================================================================
-- SECCIÓN 1: PEYA GLOBAL (Ciclo de Vida de toda la plataforma)
-- ==============================================================================

-- Paso 1.1: Extracción limpia de órdenes confirmadas agrupadas por mes
peya_raw AS (
    SELECT
        fact_orders.customer_id AS customer_id, -- ID Unificado (algoritmo de DH), ya viene como STRING
        fact_orders.country.country_name AS country,
        DATE_TRUNC(fact_orders.registered_date, MONTH) AS month
    FROM `peya-bi-tools-pro.il_core.fact_orders` fact_orders
    INNER JOIN `peya-bi-tools-pro.il_core.dim_partner` dim_partner 
        ON dim_partner.partner_id = fact_orders.restaurant.id
    WHERE fact_orders.registered_date >= "2020-01-01" 
      AND fact_orders.order_status = "CONFIRMED"
    GROUP BY 1, 2, 3 -- Consolida compras múltiples en un mismo mes a una sola fila
),

-- Paso 1.2: Identificación del mes de adopción (Cohort):
--           1) Por cliente y país (Adopción en ese país específico)
--           2) Por cliente global (Adopción histórica en toda la app)
peya_activity AS (
    SELECT
        customer_id,
        country,
        month,
        -- Adopción por País: primer mes de compra en este país específico
        MIN(month) OVER (PARTITION BY customer_id, country) AS cohort_country,
        -- Adopción de Usuario Global: primer mes de compra en cualquier país de PeYa
        MIN(month) OVER (PARTITION BY customer_id) AS cohort_user
    FROM peya_raw 
),

-- Paso 1.3: Construcción de ventanas temporales (Mirar meses pasados y futuros) y cálculo de tenures
peya_window AS (
    SELECT 
        customer_id,
        country,
        month,
        cohort_country,
        cohort_user,
        
        -- 1. Tenure por País: antigüedad del cliente dentro de este país
        DATE_DIFF(month, cohort_country, MONTH) + 1 AS tenure_country,
        
        -- 2. Tenure del Usuario: antigüedad global del cliente en la plataforma PeYa
        DATE_DIFF(month, cohort_user, MONTH) + 1 AS tenure_user,
        
        LAG(month) OVER (PARTITION BY customer_id, country ORDER BY month) AS prev_m,
        LAG(month, 2) OVER (PARTITION BY customer_id, country ORDER BY month) AS prev_m_2,
        LEAD(month) OVER (PARTITION BY customer_id, country ORDER BY month) AS next_m
    FROM peya_activity
),

-- Paso 1.4: Clasificación de activos y generación de filas fantasma (Inactivos)
peya_final_raw AS (
    -- C1. Usuarios Reales (Meses donde sí hubo compra)
    SELECT
        month,
        customer_id,
        country,
        cohort_country,
        cohort_user,
        tenure_country,
        tenure_user,
        CASE 
            WHEN tenure_country = 1 THEN "New User"
            WHEN DATE_DIFF(month, prev_m_2, MONTH) = 2 THEN "Recurring Return" -- Racha de 3 meses seguidos
            WHEN tenure_country = 2 AND DATE_DIFF(month, prev_m, MONTH) = 1 THEN "M1 Return"  -- Retención mes 2
            WHEN DATE_DIFF(month, prev_m, MONTH) = 1 THEN "Reorder"           -- Racha de 2 meses seguidos
            ELSE "Re-Activation"                                              -- Regresa de una inactividad
        END AS Type_Peya,
        TRUE AS is_active_peya
    FROM peya_window
    
    UNION ALL
    
    -- C2. Generador de Fantasmas (Meses donde el usuario estuvo inactivo)
    SELECT 
        DATE_ADD(month, INTERVAL gap MONTH) AS month,
        customer_id,
        country,
        cohort_country,
        cohort_user,
        DATE_DIFF(DATE_ADD(month, INTERVAL gap MONTH), cohort_country, MONTH) + 1 AS tenure_country,
        DATE_DIFF(DATE_ADD(month, INTERVAL gap MONTH), cohort_user, MONTH) + 1 AS tenure_user,
        CASE 
            WHEN gap = 1 THEN "Churned"
            WHEN gap BETWEEN 2 AND 5 THEN "Inactive < 6 month"
            WHEN gap >= 6 THEN "Inactive > 6 month"
        END AS Type_Peya,
        FALSE AS is_active_peya
    FROM peya_window, UNNEST(GENERATE_ARRAY(1, 60)) AS gap -- Límite de seguridad de 5 años para performance
    WHERE (next_m IS NULL OR DATE_DIFF(next_m, month, MONTH) > gap) -- Solo rellena el espacio vacío hasta su próxima compra
      AND DATE_ADD(month, INTERVAL gap MONTH) < DATE_TRUNC(CURRENT_DATE(), MONTH) -- Freno para no pasarse del mes actual
),

-- Paso 1.5: Detección de cambios de tipo de usuario (Islands & Gaps)
peya_type_change AS (
    SELECT
        *,
        LAG(Type_Peya) OVER (PARTITION BY customer_id, country ORDER BY month) AS previous_type_peya,
        -- Marca 1 si el tipo actual es distinto al del mes anterior o si es el primer mes
        IF(LAG(Type_Peya) OVER (PARTITION BY customer_id, country ORDER BY month) = Type_Peya, 0, 1) AS is_type_change
    FROM peya_final_raw
),

-- Paso 1.6: Creación del identificador de racha/isla por cada cambio de tipo de usuario
peya_type_groups AS (
    SELECT
        *,
        SUM(is_type_change) OVER (
            PARTITION BY customer_id, country 
            ORDER BY month 
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS type_group_id
    FROM peya_type_change
),

-- Paso 1.7: Cálculo del Tenure del Tipo de Usuario actual y racha de Recurring Return
peya_final AS (
    SELECT
        month,
        customer_id,
        country,
        cohort_country,
        cohort_user,
        tenure_country,
        tenure_user,
        Type_Peya,
        previous_type_peya,
        is_active_peya,

        -- Mes exacto en que comenzó a tener el tipo de usuario actual
        MIN(month) OVER (
            PARTITION BY customer_id, country, type_group_id
        ) AS type_peya_start_month,

        -- 3. Tenure del Tipo de Usuario: meses consecutivos en el tipo actual desde el último cambio
        ROW_NUMBER() OVER (
            PARTITION BY customer_id, country, type_group_id 
            ORDER BY month
        ) AS tenure_user_type_peya,

        -- Racha específica de Recurring Return: meses acumulados como RR desde que arrancó a serlo (0 si no es RR)
        CASE 
            WHEN Type_Peya = 'Recurring Return' THEN 
                ROW_NUMBER() OVER (PARTITION BY customer_id, country, type_group_id ORDER BY month)
            ELSE 0 
        END AS tenure_rr_streak_peya

    FROM peya_type_groups
),

-- ==============================================================================
-- SECCIÓN 2: DMARTS (Ciclo de Vida exclusivo de Supermercados / Darkstores)
-- ==============================================================================

-- Paso 2.1: Extracción limpia agrupada por mes
dmart_raw AS (
    SELECT
        CAST(customer_id AS STRING) AS customer_id,
        country_name AS country,
        DATE_TRUNC(order_date, MONTH) AS month
    FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
    WHERE state = 'CONFIRMED'
      AND order_date >= '2020-01-01'
    GROUP BY 1, 2, 3
),

-- Paso 2.2: Identificación del mes de adopción en Dmarts (por país y global)
dmart_activity AS (
    SELECT
        customer_id,
        country,
        month,
        -- Adopción en Dmart por País
        MIN(month) OVER (PARTITION BY customer_id, country) AS cohort_country,
        -- Adopción en Dmart de Usuario Global
        MIN(month) OVER (PARTITION BY customer_id) AS cohort_user
    FROM dmart_raw
),

-- Paso 2.3: Construcción de ventanas temporales para Dmarts y tenures
dmart_window AS (
    SELECT 
        customer_id,
        country,
        month,
        cohort_country,
        cohort_user,
        
        -- 1. Tenure por País en Dmarts
        DATE_DIFF(month, cohort_country, MONTH) + 1 AS tenure_country,
        
        -- 2. Tenure del Usuario Global en Dmarts
        DATE_DIFF(month, cohort_user, MONTH) + 1 AS tenure_user,
        
        LAG(month) OVER (PARTITION BY customer_id, country ORDER BY month) AS prev_m,
        LAG(month, 2) OVER (PARTITION BY customer_id, country ORDER BY month) AS prev_m_2,
        LEAD(month) OVER (PARTITION BY customer_id, country ORDER BY month) AS next_m
    FROM dmart_activity
),

-- Paso 2.4: Clasificación de activos y generación de fantasmas para Dmarts
dmart_final_raw AS (
    -- C1. Usuarios Reales
    SELECT
        month,
        customer_id,
        country,
        cohort_country,
        cohort_user,
        tenure_country,
        tenure_user,
        CASE 
            WHEN tenure_country = 1 THEN "New User"
            WHEN DATE_DIFF(month, prev_m_2, MONTH) = 2 THEN "Recurring Return"
            WHEN tenure_country = 2 AND DATE_DIFF(month, prev_m, MONTH) = 1 THEN "M1 Return"
            WHEN DATE_DIFF(month, prev_m, MONTH) = 1 THEN "Reorder"
            ELSE "Re-Activation" 
        END AS Type_dmart,
        TRUE AS is_active_dmart
    FROM dmart_window
    
    UNION ALL
    
    -- C2. Generador de Fantasmas
    SELECT 
        DATE_ADD(month, INTERVAL gap MONTH) AS month,
        customer_id,
        country,
        cohort_country,
        cohort_user,
        DATE_DIFF(DATE_ADD(month, INTERVAL gap MONTH), cohort_country, MONTH) + 1 AS tenure_country,
        DATE_DIFF(DATE_ADD(month, INTERVAL gap MONTH), cohort_user, MONTH) + 1 AS tenure_user,
        CASE 
            WHEN gap = 1 THEN "Churned"
            WHEN gap BETWEEN 2 AND 5 THEN "Inactive < 6 month"
            WHEN gap >= 6 THEN "Inactive > 6 month"
        END AS Type_dmart,
        FALSE AS is_active_dmart
    FROM dmart_window, UNNEST(GENERATE_ARRAY(1, 60)) AS gap
    WHERE (next_m IS NULL OR DATE_DIFF(next_m, month, MONTH) > gap)
      AND DATE_ADD(month, INTERVAL gap MONTH) < DATE_TRUNC(CURRENT_DATE(), MONTH)
),

-- Paso 2.5: Detección de cambios de tipo de usuario en Dmarts
dmart_type_change AS (
    SELECT
        *,
        LAG(Type_dmart) OVER (PARTITION BY customer_id, country ORDER BY month) AS previous_type_dmart,
        IF(LAG(Type_dmart) OVER (PARTITION BY customer_id, country ORDER BY month) = Type_dmart, 0, 1) AS is_type_change
    FROM dmart_final_raw
),

-- Paso 2.6: Creación del identificador de racha/isla en Dmarts
dmart_type_groups AS (
    SELECT
        *,
        SUM(is_type_change) OVER (
            PARTITION BY customer_id, country 
            ORDER BY month 
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS type_group_id
    FROM dmart_type_change
),

-- Paso 2.7: Cálculo del Tenure del Tipo de Usuario actual y racha de Recurring Return en Dmarts
dmart_final AS (
    SELECT
        month,
        customer_id,
        country,
        cohort_country,
        cohort_user,
        tenure_country,
        tenure_user,
        Type_dmart,
        previous_type_dmart,
        is_active_dmart,

        -- Mes exacto en que comenzó a tener el tipo de usuario actual en Dmart
        MIN(month) OVER (
            PARTITION BY customer_id, country, type_group_id
        ) AS type_dmart_start_month,

        -- 3. Tenure del Tipo de Usuario: meses consecutivos en el tipo actual desde el último cambio
        ROW_NUMBER() OVER (
            PARTITION BY customer_id, country, type_group_id 
            ORDER BY month
        ) AS tenure_user_type_dmart,

        -- Racha específica de Recurring Return: meses acumulados como RR desde que arrancó a serlo (0 si no es RR)
        CASE 
            WHEN Type_dmart = 'Recurring Return' THEN 
                ROW_NUMBER() OVER (PARTITION BY customer_id, country, type_group_id ORDER BY month)
            ELSE 0 
        END AS tenure_rr_streak_dmart

    FROM dmart_type_groups
)

-- ==============================================================================
-- SECCIÓN 3: UNIÓN FINAL DE AMBOS MUNDOS (PEYA & DMARTS)
-- ==============================================================================
SELECT 
    COALESCE(p.month, d.month) AS month,
    COALESCE(p.customer_id, d.customer_id) AS customer_id,
    COALESCE(p.country, d.country) AS country,

    -- ==========================================================================
    -- MÉTRICAS E HISTORIA DE LA PLATAFORMA GLOBAL (PEYA)
    -- ==========================================================================
    DATE_TRUNC(p.cohort_country, MONTH) AS platform_country_adoption_date,
    DATE_TRUNC(p.cohort_user, MONTH)    AS platform_user_adoption_date,
    
    -- 1. Tenure por País: antigüedad del cliente dentro del país
    p.tenure_country                    AS country_tenure_months_peya,
    
    -- 2. Tenure del Usuario: antigüedad global del cliente en PeYa
    p.tenure_user                       AS user_tenure_months_peya,
    
    p.previous_type_peya,
    p.Type_Peya,
    p.type_peya_start_month,
    
    -- 3. Tenure del Tipo de Usuario: meses continuos en su tipo actual desde su último cambio
    p.tenure_user_type_peya             AS tenure_user_type_peya,
    
    -- Racha de Recurring Return: meses continuos como RR desde que arrancó a serlo
    p.tenure_rr_streak_peya             AS tenure_rr_streak_peya,
    
    COALESCE(p.is_active_peya, FALSE)   AS is_active_peya,
    
    -- ==========================================================================
    -- MÉTRICAS E HISTORIA DE DMARTS
    -- ==========================================================================
    DATE_TRUNC(d.cohort_country, MONTH) AS dmart_country_adoption_date,
    DATE_TRUNC(d.cohort_user, MONTH)    AS dmart_user_adoption_date,
    
    -- 1. Tenure por País: antigüedad del cliente en Dmarts dentro del país
    d.tenure_country                    AS country_tenure_months_dmart,
    
    -- 2. Tenure del Usuario: antigüedad global del cliente en Dmarts
    d.tenure_user                       AS user_tenure_months_dmart,
    
    d.previous_type_dmart,
    d.Type_dmart,
    d.type_dmart_start_month,
    
    -- 3. Tenure del Tipo de Usuario: meses continuos en su tipo actual desde su último cambio
    d.tenure_user_type_dmart            AS tenure_user_type_dmart,
    
    -- Racha de Recurring Return: meses continuos como RR desde que arrancó a serlo
    d.tenure_rr_streak_dmart            AS tenure_rr_streak_dmart,
    
    COALESCE(d.is_active_dmart, FALSE)  AS is_active_dmart

FROM peya_final p
FULL OUTER JOIN dmart_final d 
    ON p.customer_id = d.customer_id 
   AND p.month = d.month
   AND p.country = d.country -- Evita duplicados si el usuario transaccionó en múltiples países

ORDER BY customer_id, month;
