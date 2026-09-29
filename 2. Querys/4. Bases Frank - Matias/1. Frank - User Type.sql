DECLARE query_name STRING DEFAULT '1. Frank - User Type';

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

-- Paso 1.2: Identificación del mes de adopción (Cohort) por cliente y país
peya_activity AS (
    SELECT
      customer_id,
      country,
      month,
      MIN(month) OVER (PARTITION BY customer_id, country) as cohort 
    FROM peya_raw 
),

-- Paso 1.3: Construcción de ventanas temporales (Mirar meses pasados y futuros)
peya_window AS (
    SELECT *, 
        DATE_DIFF(month, cohort, MONTH) + 1 as tenure, -- Meses de vida del cliente
        LAG(month) OVER (PARTITION BY customer_id, country ORDER BY month) as prev_m,
        LAG(month, 2) OVER (PARTITION BY customer_id, country ORDER BY month) as prev_m_2,
        LEAD(month) OVER (PARTITION BY customer_id, country ORDER BY month) as next_m
    FROM peya_activity
),

-- Paso 1.4: Clasificación de activos y generación de filas fantasma (Inactivos)
peya_final_raw AS (
    -- C1. Usuarios Reales (Meses donde sí hubo compra)
    SELECT
      month, customer_id, country, cohort, tenure, 
       CASE 
           WHEN tenure = 1 THEN "New User"
           WHEN DATE_DIFF(month, prev_m_2, MONTH) = 2 THEN "Recurring Return" -- Racha de 3 meses seguidos
           WHEN tenure = 2 AND DATE_DIFF(month, prev_m, MONTH) = 1 THEN "M1 Return"  -- Retención mes 2
           WHEN DATE_DIFF(month, prev_m, MONTH) = 1 THEN "Reorder"           -- Racha de 2 meses seguidos
           ELSE "Re-Activation"                                              -- Regresa de una inactividad
       END as Type_Peya
    FROM peya_window
    
    UNION ALL
    
    -- C2. Generador de Fantasmas (Meses donde el usuario estuvo inactivo)
    SELECT 
        DATE_ADD(month, INTERVAL gap MONTH) as month,
        customer_id, country, cohort,
        DATE_DIFF(DATE_ADD(month, INTERVAL gap MONTH), cohort, MONTH) + 1 as tenure,
        CASE 
            WHEN gap = 1 THEN "Churned"
            WHEN gap BETWEEN 2 AND 5 THEN "Inactive < 6 month"
            WHEN gap >= 6 THEN "Inactive > 6 month"
        END as Type_Peya
    FROM peya_window, UNNEST(GENERATE_ARRAY(1, 60)) as gap -- Límite de seguridad de 5 años para performance
    WHERE (next_m IS NULL OR DATE_DIFF(next_m, month, MONTH) > gap) -- Solo rellena el espacio vacío hasta su próxima compra
      AND DATE_ADD(month, INTERVAL gap MONTH) < DATE_TRUNC(CURRENT_DATE(), MONTH) -- Freno para no pasarse del mes actual
),

-- Paso 1.5: Calcular el estado del mes anterior de manera aislada
peya_final AS (
    SELECT *,
        LAG(Type_Peya) OVER (PARTITION BY customer_id, country ORDER BY month) AS previous_type_peya
    FROM peya_final_raw
),

-- ==============================================================================
-- SECCIÓN 2: DMARTS (Ciclo de Vida exclusivo de Supermercados / Darkstores)
-- ==============================================================================

-- Paso 2.1: Extracción limpia agrupada por mes (Previene errores de list expression en BigQuery)
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

-- Paso 2.2: Identificación del mes de adopción en Dmarts
dmart_activity AS (
    SELECT
        customer_id,
        country,
        month,
        MIN(month) OVER (PARTITION BY customer_id, country) AS cohort
    FROM dmart_raw
),

-- Paso 2.3: Construcción de ventanas temporales para Dmarts
dmart_window AS (
    SELECT *, 
        DATE_DIFF(month, cohort, MONTH) + 1 as tenure,
        LAG(month) OVER (PARTITION BY customer_id, country ORDER BY month) as prev_m,
        LAG(month, 2) OVER (PARTITION BY customer_id, country ORDER BY month) as prev_m_2,
        LEAD(month) OVER (PARTITION BY customer_id, country ORDER BY month) as next_m
    FROM dmart_activity
),

-- Paso 2.4: Clasificación de activos y generación de fantasmas para Dmarts
dmart_final_raw AS (
    -- C1. Usuarios Reales
    SELECT
      month, customer_id, country, cohort, tenure, 
       CASE 
           WHEN tenure = 1 THEN "New User"
           WHEN DATE_DIFF(month, prev_m_2, MONTH) = 2 THEN "Recurring Return"
           WHEN tenure = 2 AND DATE_DIFF(month, prev_m, MONTH) = 1 THEN "M1 Return"
           WHEN DATE_DIFF(month, prev_m, MONTH) = 1 THEN "Reorder"
           ELSE "Re-Activation" 
       END as Type_dmart
    FROM dmart_window
    
    UNION ALL
    
    -- C2. Generador de Fantasmas
    SELECT 
        DATE_ADD(month, INTERVAL gap MONTH) as month,
        customer_id, country, cohort,
        DATE_DIFF(DATE_ADD(month, INTERVAL gap MONTH), cohort, MONTH) + 1 as tenure,
        CASE 
            WHEN gap = 1 THEN "Churned"
            WHEN gap BETWEEN 2 AND 5 THEN "Inactive < 6 month"
            WHEN gap >= 6 THEN "Inactive > 6 month"
        END as Type_dmart
    FROM dmart_window, UNNEST(GENERATE_ARRAY(1, 60)) as gap
    WHERE (next_m IS NULL OR DATE_DIFF(next_m, month, MONTH) > gap)
      AND DATE_ADD(month, INTERVAL gap MONTH) < DATE_TRUNC(CURRENT_DATE(), MONTH)
),

-- Paso 2.5: Calcular el estado del mes anterior aislado para Dmarts
dmart_final AS (
    SELECT *,
        LAG(Type_dmart) OVER (PARTITION BY customer_id, country ORDER BY month) AS previous_type_dmart
    FROM dmart_final_raw
)

-- ==============================================================================
-- SECCIÓN 3: UNIÓN FINAL DE AMBOS MUNDOS
-- ==============================================================================
SELECT 
    COALESCE(p.month, d.month) AS month,
    COALESCE(p.customer_id, d.customer_id) AS customer_id,
    COALESCE(p.country, d.country) AS country,

    -- Métricas e historia de la Plataforma Global
    DATE_TRUNC(p.cohort, MONTH) AS platform_adoption_date,
    p.tenure AS user_tenure_months_peya,
    p.previous_type_peya,
    p.Type_Peya,
    
    -- Métricas e historia de Dmarts
    DATE_TRUNC(d.cohort, MONTH) AS dmart_adoption_date,
    d.tenure AS user_tenure_months_dmart,
    d.previous_type_dmart,
    d.Type_dmart

FROM peya_final p
FULL OUTER JOIN dmart_final d 
    ON p.customer_id = d.customer_id 
   AND p.month = d.month
   AND p.country = d.country -- Evita duplicados si el usuario transaccionó en múltiples países

ORDER BY customer_id, month;