DECLARE query_name STRING DEFAULT '3. Frank - User Type (Level 1 & 2 + Tenure)';

-- ==============================================================================
-- FRANK USER LIFECYCLE V2 (TAXONOMÍA LEVEL 1 Y LEVEL 2 + TENURE)
-- ==============================================================================
-- Tabla de destino: `peya-food-and-groceries.automated_tables_reports.frank_user_type`
--
-- DESCRIPCIÓN DE TAXONOMÍA (DMART / DARKSTORES):
-- ------------------------------------------------------------------------------
-- 1. Adoption (Nuevos usuarios en Dmart):
--    • App Adoption: Primera compra en Dmart es la 1ra orden de toda su historia en la app.
--    • Double Ya Adoption: Primera orden en Dmart ocurre vía Double Ya (flag en orden).
--    • AAA Adoption: Primera orden en Dmart en M0, con órdenes previas en AAA (Supermercados).
--    • Dmart Adoption: Primera orden en Dmart en M0, con órdenes previas en app no AAA (Restaurantes, etc.).
--
-- 2. M1 Return (Retención mes posterior a la adopción):
--    • M1 App Adoption: Adquirido como App Adoption en M-1 y compró en M0.
--    • M1 Double Ya Adoption: Volvió en M0 comprando exclusivamente con Double Ya.
--    • M1 Double Ya Converted: Volvió en M0 con al menos una compra Full Dmarts (regular).
--    • M1 AAA Adoption: Adquirido como AAA Adoption en M-1 y compró en M0.
--    • M1 Dmart Adoption: Adquirido como Dmart Adoption en M-1 y compró en M0.
--
-- 3. Reactivation (Rescatados de inactividad, >= 1 mes sin comprar en Dmart):
--    • DY Reactivation: Reactivado en M0 comprando exclusivamente con Double Ya.
--    • Occasional Reactivation: Última compra en M-2 (compró en 2 de los últimos 3 meses).
--    • Warm Reactivation: Última compra previa hace 3 a 5 meses (M-3 a M-5).
--    • True Reactivation: Última compra previa hace 6 meses o más (>= M-6).
--
-- 4. Re-Order (Retención post-rescate: compró en M0 y M-1, inactivo en M-2):
--    • Re-Order DY Reactivation: Retenido comprando exclusivamente con Double Ya.
--    • Re-Order DY Full Dmarts: Retenido con orden Full Dmart habiendo reactivado por DY.
--    • Re-Order Occasional Reactivation: Reactivado ocasional retenido en M0.
--    • Re-Order Warm Reactivation: Reactivado cálido retenido en M0.
--    • Re-Order True Reactivation: Reactivado puro retenido en M0.
--
-- 5. Recurring Return (Hábito y lealtad sólida, compras consecutivas ininterrumpidas):
--    • Recent Recurring Return: 3 meses consecutivos ininterrumpidos (M0, M-1, M-2).
--    • Old Recurring Return: 4 a 12 meses consecutivos ininterrumpidos.
--    • Royal Recurring Return: 12 meses o más consecutivos ininterrumpidos (>= 13 meses).
--
-- 6. Churned (Base inactiva con historial de compra previo, no compró en M0):
--    • Recently Churn: Inactivo hace 1 o 2 meses (M-1 o M-2).
--    • Churn > 3 Months: Inactivo hace 3 a 5 meses (M-3 a M-5).
--    • Churn > 6 Months: Inactivo hace 6 meses o más (>= M-6).
--
-- 7. Never Active (Sin compras en la historia del negocio):
--    • Never Active: Registrado / activo en la app que jamás ha completado compra en dicho negocio.
--
-- MÉTRICAS DE TENURE (ANTIGÜEDAD Y RACHAS):
-- ------------------------------------------------------------------------------
--  • user_tenure_months_dmart: Antigüedad histórica en Dmarts (meses desde 1ra compra).
--  • user_tenure_months_peya: Antigüedad histórica en PeYa global (meses desde 1ra compra).
--  • consecutive_active_months_dmart: Racha actual ininterrumpida de meses activos.
--  • tenure_rr_streak_months_dmart: Meses dentro de la racha continua como RR (1, 2, 3...).
--  • last_rr_month_dmart: Último mes en que el usuario estuvo en estado Recurring Return.
--  • months_since_last_rr_dmart: Meses transcurridos desde que fue RR por última vez.
-- ==============================================================================

CREATE OR REPLACE TABLE `peya-food-and-groceries.automated_tables_reports.frank_user_type` AS

WITH

-- ==============================================================================
-- PASO 0: TABLAS DE DIMENSIONES Y MAESTROS
-- ==============================================================================

-- 0.1 Partners Darkstore (Definición oficial de D-Mart)
darkstore_partners AS (
    SELECT DISTINCT dim_partner.partner_id
    FROM `peya-bi-tools-pro.il_core.dim_partner` dim_partner
    INNER JOIN `peya-datamarts-pro.dm_dmarts.dim_partner_darkstore` pd
        ON pd.partner_id = dim_partner.partner_id
),

-- 0.2 Partners AAA (Supermercados de Terceros)
aaa_partners AS (
    SELECT DISTINCT
        COALESCE(cp.partner_id, t.partner_id) AS partner_id
    FROM `peya-data-origins-pro.cl_qcommerce.partners_aaa` cp
    FULL JOIN `peya-food-and-groceries.automated_tables_reports.partners_aaa_temporary` t 
        ON t.partner_id = cp.partner_id
    WHERE COALESCE(cp.clasificacion, t.clasificacion) IN ('Small Supermarket', 'Supermarket')
),

-- 0.3 Órdenes Double Ya
double_ya_orders AS (
    SELECT DISTINCT
        CAST(order_details.id.secondary AS INT64) AS order_id
    FROM `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya`
    WHERE order_type = 'DOUBLE_YA'
),

-- ==============================================================================
-- PASO 1: EXTRACCIÓN Y TIPIFICACIÓN A NIVEL ORDEN (DESDE 2020)
-- ==============================================================================
base_orders AS (
    SELECT
        fact_orders.customer_id,
        fact_orders.country.country_name AS country,
        fact_orders.order_id,
        fact_orders.registered_date,
        DATE_TRUNC(DATE(fact_orders.registered_date), MONTH) AS order_month,
        
        -- Flags de negocio
        IF(dp.partner_id IS NOT NULL, 1, 0) AS is_dmart,
        IF(dp.partner_id IS NOT NULL AND dy.order_id IS NOT NULL, 1, 0) AS is_dmart_dy,
        IF(dp.partner_id IS NOT NULL AND dy.order_id IS NULL, 1, 0) AS is_dmart_regular,
        IF(dp.partner_id IS NULL AND aaa.partner_id IS NOT NULL, 1, 0) AS is_aaa

    FROM `peya-bi-tools-pro.il_core.fact_orders` fact_orders
    LEFT JOIN darkstore_partners dp 
        ON dp.partner_id = fact_orders.restaurant.id
    LEFT JOIN aaa_partners aaa 
        ON aaa.partner_id = fact_orders.restaurant.id
    LEFT JOIN double_ya_orders dy 
        ON fact_orders.order_id = dy.order_id
    WHERE fact_orders.registered_date >= "2020-01-01"
      AND fact_orders.order_status = "CONFIRMED"
),

-- ==============================================================================
-- PASO 2: PERFIL HISTÓRICO Y ORIGEN DE ADOPCIÓN POR CLIENTE
-- ==============================================================================

-- 2.1 Primeras fechas globales por cliente
customer_first_orders AS (
    SELECT
        customer_id,
        country,
        MIN(registered_date) AS first_peya_order_date,
        MIN(IF(is_dmart = 1, registered_date, NULL)) AS first_dmart_order_date,
        MIN(IF(is_aaa = 1, registered_date, NULL)) AS first_aaa_order_date
    FROM base_orders
    GROUP BY 1, 2
),

-- 2.2 Primera orden exacta de Dmart (para identificar si ingresó por Double Ya)
first_dmart_order_flag AS (
    SELECT
        customer_id,
        country,
        is_dmart_dy AS first_dmart_is_dy
    FROM base_orders
    WHERE is_dmart = 1
    QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id, country ORDER BY registered_date ASC, order_id ASC) = 1
),

-- 2.3 Clasificación definitiva del perfil de adopción en Dmart (Level 2)
customer_adoption_profile AS (
    SELECT
        c.customer_id,
        c.country,
        DATE_TRUNC(DATE(c.first_peya_order_date), MONTH) AS cohort_peya,
        DATE_TRUNC(DATE(c.first_dmart_order_date), MONTH) AS cohort_dmart,
        c.first_peya_order_date,
        c.first_dmart_order_date,
        COALESCE(fd.first_dmart_is_dy, 0) AS first_dmart_is_dy,
        
        -- Clasificación de Adquisición / Adopción (Level 2)
        CASE 
            WHEN COALESCE(fd.first_dmart_is_dy, 0) = 1 THEN 'Double Ya Adoption'
            WHEN c.first_peya_order_date >= c.first_dmart_order_date THEN 'App Adoption'
            WHEN c.first_aaa_order_date IS NOT NULL AND c.first_aaa_order_date < c.first_dmart_order_date THEN 'AAA Adoption'
            ELSE 'Dmart Adoption'
        END AS adoption_l2

    FROM customer_first_orders c
    LEFT JOIN first_dmart_order_flag fd
        ON fd.customer_id = c.customer_id AND fd.country = c.country
),

-- ==============================================================================
-- SECCIÓN A: CICLO DE VIDA DMARTS (DARKSTORES)
-- ==============================================================================

-- A.1 Actividad mensual agrupada en Dmarts
dmart_monthly_activity AS (
    SELECT
        customer_id,
        country,
        order_month AS month,
        COUNT(DISTINCT order_id) AS orders_dmart,
        COUNT(DISTINCT IF(is_dmart_dy = 1, order_id, NULL)) AS orders_dmart_dy,
        COUNT(DISTINCT IF(is_dmart_regular = 1, order_id, NULL)) AS orders_dmart_regular
    FROM base_orders
    WHERE is_dmart = 1
    GROUP BY 1, 2, 3
),

-- A.2 Ventanas temporales y cálculo de rachas consecutivas (Islands & Gaps)
dmart_active_window AS (
    SELECT
        a.customer_id,
        a.country,
        a.month,
        a.orders_dmart,
        a.orders_dmart_dy,
        a.orders_dmart_regular,
        (a.orders_dmart_regular = 0 AND a.orders_dmart_dy > 0) AS is_dy_only,
        (a.orders_dmart_regular > 0) AS has_regular_dmart,
        p.cohort_dmart,
        p.cohort_peya,
        p.adoption_l2,
        
        -- Antigüedad en meses
        DATE_DIFF(a.month, p.cohort_dmart, MONTH) + 1 AS tenure_dmart,
        DATE_DIFF(a.month, p.cohort_peya, MONTH) + 1 AS tenure_peya,
        
        -- Navegación temporal
        LAG(a.month) OVER (PARTITION BY a.customer_id, a.country ORDER BY a.month) AS prev_m,
        LAG(a.month, 2) OVER (PARTITION BY a.customer_id, a.country ORDER BY a.month) AS prev_m_2,
        LEAD(a.month) OVER (PARTITION BY a.customer_id, a.country ORDER BY a.month) AS next_m,
        
        -- Racha ininterrumpida de meses activos comprando
        ROW_NUMBER() OVER (
            PARTITION BY a.customer_id, a.country, 
                         DATE_SUB(a.month, INTERVAL ROW_NUMBER() OVER (PARTITION BY a.customer_id, a.country ORDER BY a.month) MONTH) 
            ORDER BY a.month
        ) AS consecutive_active_months,

        -- Comportamiento del mes anterior
        LAG(a.orders_dmart_regular = 0 AND a.orders_dmart_dy > 0) OVER (PARTITION BY a.customer_id, a.country ORDER BY a.month) AS prev_is_dy_only

    FROM dmart_monthly_activity a
    INNER JOIN customer_adoption_profile p
        ON p.customer_id = a.customer_id AND p.country = a.country
),

-- A.3 Clasificación de usuarios en meses ACTIVOS de Dmart (Level 1 y Level 2)
dmart_classified_active AS (
    SELECT
        *,
        -- ----------------------------------------------------------------------
        -- LEVEL 1 (DMART)
        -- ----------------------------------------------------------------------
        CASE 
            WHEN tenure_dmart = 1 THEN 'Adoption'
            WHEN consecutive_active_months >= 3 THEN 'Recurring Return'
            WHEN tenure_dmart = 2 AND DATE_DIFF(month, prev_m, MONTH) = 1 THEN 'M1 Return'
            WHEN DATE_DIFF(month, prev_m, MONTH) = 1 AND (DATE_DIFF(prev_m, prev_m_2, MONTH) >= 2 OR prev_m_2 IS NULL) THEN 'Re-Order'
            WHEN DATE_DIFF(month, prev_m, MONTH) >= 2 THEN 'Reactivation'
            WHEN consecutive_active_months = 2 THEN 'Re-Order'
            ELSE 'Recurring Return'
        END AS user_type_l1_dmart,

        -- ----------------------------------------------------------------------
        -- LEVEL 2 (DMART)
        -- ----------------------------------------------------------------------
        CASE
            -- 1. ADOPTION
            WHEN tenure_dmart = 1 THEN adoption_l2

            -- 2. M1 RETURN (Mide principalmente la retención)
            WHEN tenure_dmart = 2 AND DATE_DIFF(month, prev_m, MONTH) = 1 THEN
                CASE 
                    WHEN adoption_l2 = 'Double Ya Adoption' AND has_regular_dmart THEN 'M1 Double Ya Converted'
                    WHEN adoption_l2 = 'Double Ya Adoption' AND is_dy_only THEN 'M1 Double Ya Adoption'
                    WHEN is_dy_only THEN 'M1 Double Ya Adoption'
                    WHEN adoption_l2 = 'App Adoption' THEN 'M1 App Adoption'
                    WHEN adoption_l2 = 'AAA Adoption' THEN 'M1 AAA Adoption'
                    WHEN adoption_l2 = 'Dmart Adoption' THEN 'M1 Dmart Adoption'
                    ELSE 'M1 Dmart Adoption'
                END

            -- 3. RE-ORDER (Retención post-rescate: compró en M0 y M-1, inactivo en M-2)
            WHEN DATE_DIFF(month, prev_m, MONTH) = 1 AND (DATE_DIFF(prev_m, prev_m_2, MONTH) >= 2 OR prev_m_2 IS NULL) THEN
                CASE 
                    WHEN prev_is_dy_only = TRUE AND has_regular_dmart THEN 'Re-Order DY Full Dmarts'
                    WHEN prev_is_dy_only = TRUE AND is_dy_only THEN 'Re-Order DY Reactivation'
                    WHEN is_dy_only THEN 'Re-Order DY Reactivation'
                    WHEN DATE_DIFF(prev_m, prev_m_2, MONTH) = 2 THEN 'Re-Order Occasional Reactivation'
                    WHEN DATE_DIFF(prev_m, prev_m_2, MONTH) BETWEEN 3 AND 5 THEN 'Re-Order Warm Reactivation'
                    WHEN DATE_DIFF(prev_m, prev_m_2, MONTH) >= 6 THEN 'Re-Order True Reactivation'
                    ELSE 'Re-Order Occasional Reactivation'
                END

            -- 4. REACTIVATION (Usuarios rescatados tras inactividad previa >= 1 mes)
            WHEN DATE_DIFF(month, prev_m, MONTH) >= 2 THEN
                CASE 
                    WHEN is_dy_only THEN 'DY Reactivation'
                    WHEN DATE_DIFF(month, prev_m, MONTH) = 2 THEN 'Occasional Reactivation'
                    WHEN DATE_DIFF(month, prev_m, MONTH) BETWEEN 3 AND 5 THEN 'Warm Reactivation'
                    WHEN DATE_DIFF(month, prev_m, MONTH) >= 6 THEN 'True Reactivation'
                    ELSE 'True Reactivation'
                END

            -- 5. RECURRING RETURN (Hábito ininterrumpido de 3+ meses)
            WHEN consecutive_active_months = 3 THEN 'Recent Recurring Return'
            WHEN consecutive_active_months BETWEEN 4 AND 12 THEN 'Old Recurring Return'
            WHEN consecutive_active_months >= 13 THEN 'Royal Recurring Return'

            ELSE 'Recent Recurring Return'
        END AS user_type_l2_dmart

    FROM dmart_active_window
),

-- A.4 Unión de Activos + Generador de Fantasmas (Meses inactivos / Churned)
dmart_full_timeline AS (
    -- C1: Meses Reales con Compra
    SELECT
        month,
        customer_id,
        country,
        cohort_dmart,
        cohort_peya,
        tenure_dmart AS user_tenure_months_dmart,
        tenure_peya AS user_tenure_months_peya,
        consecutive_active_months,
        user_type_l1_dmart,
        user_type_l2_dmart,
        0 AS inactivity_gap_months,
        TRUE AS is_active_dmart
    FROM dmart_classified_active

    UNION ALL

    -- C2: Generador de Fantasmas (Meses Inactivos / Churned)
    SELECT
        DATE_ADD(month, INTERVAL gap MONTH) AS month,
        customer_id,
        country,
        cohort_dmart,
        cohort_peya,
        DATE_DIFF(DATE_ADD(month, INTERVAL gap MONTH), cohort_dmart, MONTH) + 1 AS user_tenure_months_dmart,
        DATE_DIFF(DATE_ADD(month, INTERVAL gap MONTH), cohort_peya, MONTH) + 1 AS user_tenure_months_peya,
        0 AS consecutive_active_months,
        'Churned' AS user_type_l1_dmart,
        CASE 
            WHEN gap IN (1, 2) THEN 'Recently Churn'
            WHEN gap BETWEEN 3 AND 5 THEN 'Churn > 3 Months'
            WHEN gap >= 6 THEN 'Churn > 6 Months'
        END AS user_type_l2_dmart,
        gap AS inactivity_gap_months,
        FALSE AS is_active_dmart
    FROM dmart_active_window, UNNEST(GENERATE_ARRAY(1, 60)) AS gap
    WHERE (next_m IS NULL OR DATE_DIFF(next_m, month, MONTH) > gap)
      AND DATE_ADD(month, INTERVAL gap MONTH) < DATE_TRUNC(CURRENT_DATE(), MONTH)
),

-- A.5 Cálculo de métricas avanzadas de Recurring Return y Tenure en Dmart
dmart_final AS (
    SELECT
        *,
        -- Último mes en que el usuario estuvo en condición de Recurring Return
        MAX(CASE WHEN user_type_l1_dmart = 'Recurring Return' THEN month END) 
            OVER (PARTITION BY customer_id, country ORDER BY month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS last_rr_month_dmart,
        
        -- Meses transcurridos desde que fue RR por última vez (0 si es RR actualmente)
        DATE_DIFF(
            month, 
            MAX(CASE WHEN user_type_l1_dmart = 'Recurring Return' THEN month END) 
                OVER (PARTITION BY customer_id, country ORDER BY month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW),
            MONTH
        ) AS months_since_last_rr_dmart,

        -- Antigüedad en meses de la racha actual como Recurring Return
        CASE 
            WHEN user_type_l1_dmart = 'Recurring Return' THEN consecutive_active_months - 2
            ELSE 0 
        END AS tenure_rr_streak_months_dmart,

        -- Estados del mes anterior para trazabilidad
        LAG(user_type_l1_dmart) OVER (PARTITION BY customer_id, country ORDER BY month) AS previous_type_l1_dmart,
        LAG(user_type_l2_dmart) OVER (PARTITION BY customer_id, country ORDER BY month) AS previous_type_l2_dmart,

        -- Compatibilidad retroactiva con reportes existentes (Type_dmart legacy)
        CASE 
            WHEN user_type_l1_dmart = 'Adoption' THEN 'New User'
            WHEN user_type_l1_dmart = 'M1 Return' THEN 'M1 Return'
            WHEN user_type_l1_dmart = 'Recurring Return' THEN 'Recurring Return'
            WHEN user_type_l1_dmart = 'Re-Order' THEN 'Reorder'
            WHEN user_type_l1_dmart = 'Reactivation' THEN 'Re-Activation'
            WHEN user_type_l2_dmart = 'Recently Churn' AND inactivity_gap_months = 1 THEN 'Churned'
            WHEN user_type_l2_dmart IN ('Recently Churn', 'Churn > 3 Months') THEN 'Inactive < 6 month'
            WHEN user_type_l2_dmart = 'Churn > 6 Months' THEN 'Inactive > 6 month'
            ELSE 'Never Active'
        END AS Type_dmart

    FROM dmart_full_timeline
),

-- ==============================================================================
-- SECCIÓN B: CICLO DE VIDA PEYA GLOBAL (TODA LA PLATAFORMA)
-- ==============================================================================

-- B.1 Actividad mensual agrupada en PeYa
peya_monthly_activity AS (
    SELECT
        customer_id,
        country,
        order_month AS month,
        COUNT(DISTINCT order_id) AS orders_peya
    FROM base_orders
    GROUP BY 1, 2, 3
),

-- B.2 Ventanas temporales y rachas consecutivas en PeYa
peya_active_window AS (
    SELECT
        a.customer_id,
        a.country,
        a.month,
        a.orders_peya,
        p.cohort_peya,
        DATE_DIFF(a.month, p.cohort_peya, MONTH) + 1 AS tenure_peya,
        LAG(a.month) OVER (PARTITION BY a.customer_id, a.country ORDER BY a.month) AS prev_m,
        LAG(a.month, 2) OVER (PARTITION BY a.customer_id, a.country ORDER BY a.month) AS prev_m_2,
        LEAD(a.month) OVER (PARTITION BY a.customer_id, a.country ORDER BY a.month) AS next_m,
        
        ROW_NUMBER() OVER (
            PARTITION BY a.customer_id, a.country, 
                         DATE_SUB(a.month, INTERVAL ROW_NUMBER() OVER (PARTITION BY a.customer_id, a.country ORDER BY a.month) MONTH) 
            ORDER BY a.month
        ) AS consecutive_active_months

    FROM peya_monthly_activity a
    INNER JOIN customer_adoption_profile p
        ON p.customer_id = a.customer_id AND p.country = a.country
),

-- B.3 Clasificación en meses activos de PeYa
peya_classified_active AS (
    SELECT
        *,
        CASE 
            WHEN tenure_peya = 1 THEN 'Adoption'
            WHEN consecutive_active_months >= 3 THEN 'Recurring Return'
            WHEN tenure_peya = 2 AND DATE_DIFF(month, prev_m, MONTH) = 1 THEN 'M1 Return'
            WHEN DATE_DIFF(month, prev_m, MONTH) = 1 AND (DATE_DIFF(prev_m, prev_m_2, MONTH) >= 2 OR prev_m_2 IS NULL) THEN 'Re-Order'
            WHEN DATE_DIFF(month, prev_m, MONTH) >= 2 THEN 'Reactivation'
            WHEN consecutive_active_months = 2 THEN 'Re-Order'
            ELSE 'Recurring Return'
        END AS user_type_l1_peya,

        CASE
            WHEN tenure_peya = 1 THEN 'App Adoption'
            WHEN tenure_peya = 2 AND DATE_DIFF(month, prev_m, MONTH) = 1 THEN 'M1 App Adoption'
            WHEN DATE_DIFF(month, prev_m, MONTH) = 1 AND (DATE_DIFF(prev_m, prev_m_2, MONTH) >= 2 OR prev_m_2 IS NULL) THEN 
                CASE 
                    WHEN DATE_DIFF(prev_m, prev_m_2, MONTH) = 2 THEN 'Re-Order Occasional Reactivation'
                    WHEN DATE_DIFF(prev_m, prev_m_2, MONTH) BETWEEN 3 AND 5 THEN 'Re-Order Warm Reactivation'
                    ELSE 'Re-Order True Reactivation'
                END
            WHEN DATE_DIFF(month, prev_m, MONTH) >= 2 THEN
                CASE 
                    WHEN DATE_DIFF(month, prev_m, MONTH) = 2 THEN 'Occasional Reactivation'
                    WHEN DATE_DIFF(month, prev_m, MONTH) BETWEEN 3 AND 5 THEN 'Warm Reactivation'
                    ELSE 'True Reactivation'
                END
            WHEN consecutive_active_months = 3 THEN 'Recent Recurring Return'
            WHEN consecutive_active_months BETWEEN 4 AND 12 THEN 'Old Recurring Return'
            WHEN consecutive_active_months >= 13 THEN 'Royal Recurring Return'
            ELSE 'Recent Recurring Return'
        END AS user_type_l2_peya

    FROM peya_active_window
),

-- B.4 Unión de Activos + Fantasmas en PeYa
peya_full_timeline AS (
    SELECT
        month,
        customer_id,
        country,
        cohort_peya,
        tenure_peya AS user_tenure_months_peya,
        consecutive_active_months,
        user_type_l1_peya,
        user_type_l2_peya,
        0 AS inactivity_gap_months,
        TRUE AS is_active_peya
    FROM peya_classified_active

    UNION ALL

    SELECT
        DATE_ADD(month, INTERVAL gap MONTH) AS month,
        customer_id,
        country,
        cohort_peya,
        DATE_DIFF(DATE_ADD(month, INTERVAL gap MONTH), cohort_peya, MONTH) + 1 AS user_tenure_months_peya,
        0 AS consecutive_active_months,
        'Churned' AS user_type_l1_peya,
        CASE 
            WHEN gap IN (1, 2) THEN 'Recently Churn'
            WHEN gap BETWEEN 3 AND 5 THEN 'Churn > 3 Months'
            WHEN gap >= 6 THEN 'Churn > 6 Months'
        END AS user_type_l2_peya,
        gap AS inactivity_gap_months,
        FALSE AS is_active_peya
    FROM peya_active_window, UNNEST(GENERATE_ARRAY(1, 60)) AS gap
    WHERE (next_m IS NULL OR DATE_DIFF(next_m, month, MONTH) > gap)
      AND DATE_ADD(month, INTERVAL gap MONTH) < DATE_TRUNC(CURRENT_DATE(), MONTH)
),

-- B.5 Métricas de RR y Tenure en PeYa
peya_final AS (
    SELECT
        *,
        MAX(CASE WHEN user_type_l1_peya = 'Recurring Return' THEN month END) 
            OVER (PARTITION BY customer_id, country ORDER BY month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS last_rr_month_peya,
        
        DATE_DIFF(
            month, 
            MAX(CASE WHEN user_type_l1_peya = 'Recurring Return' THEN month END) 
                OVER (PARTITION BY customer_id, country ORDER BY month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW),
            MONTH
        ) AS months_since_last_rr_peya,

        CASE 
            WHEN user_type_l1_peya = 'Recurring Return' THEN consecutive_active_months - 2
            ELSE 0 
        END AS tenure_rr_streak_months_peya,

        LAG(user_type_l1_peya) OVER (PARTITION BY customer_id, country ORDER BY month) AS previous_type_l1_peya,
        LAG(user_type_l2_peya) OVER (PARTITION BY customer_id, country ORDER BY month) AS previous_type_l2_peya,

        CASE 
            WHEN user_type_l1_peya = 'Adoption' THEN 'New User'
            WHEN user_type_l1_peya = 'M1 Return' THEN 'M1 Return'
            WHEN user_type_l1_peya = 'Recurring Return' THEN 'Recurring Return'
            WHEN user_type_l1_peya = 'Re-Order' THEN 'Reorder'
            WHEN user_type_l1_peya = 'Reactivation' THEN 'Re-Activation'
            WHEN user_type_l2_peya = 'Recently Churn' AND inactivity_gap_months = 1 THEN 'Churned'
            WHEN user_type_l2_peya IN ('Recently Churn', 'Churn > 3 Months') THEN 'Inactive < 6 month'
            WHEN user_type_l2_peya = 'Churn > 6 Months' THEN 'Inactive > 6 month'
            ELSE 'Never Active'
        END AS Type_Peya

    FROM peya_full_timeline
)

-- ==============================================================================
-- SECCIÓN FINAL: CONSOLIDACIÓN DE AMBOS MUNDOS (PEYA & DMARTS)
-- ==============================================================================
SELECT 
    COALESCE(p.month, d.month) AS month,
    COALESCE(p.customer_id, d.customer_id) AS customer_id,
    COALESCE(p.country, d.country) AS country,

    -- Fechas de Adopción (Cohorts)
    p.cohort_peya AS platform_adoption_date,
    d.cohort_dmart AS dmart_adoption_date,

    -- --------------------------------------------------------------------------
    -- CICLO DE VIDA DMART (LEVEL 1 Y LEVEL 2)
    -- --------------------------------------------------------------------------
    COALESCE(d.user_type_l1_dmart, 'Never Active') AS user_type_l1_dmart,
    COALESCE(d.user_type_l2_dmart, 'Never Active') AS user_type_l2_dmart,
    d.previous_type_l1_dmart,
    d.previous_type_l2_dmart,
    COALESCE(d.Type_dmart, 'Never Active') AS Type_dmart, -- Legacy

    -- Métricas de Tenure y Rachas en Dmarts
    d.user_tenure_months_dmart,                          -- Antigüedad total desde 1ra compra en Dmart
    d.consecutive_active_months AS consecutive_active_months_dmart, -- Racha actual ininterrumpida
    d.tenure_rr_streak_months_dmart,                     -- Meses consecutivos como Recurring Return
    d.last_rr_month_dmart,                               -- Último mes en que fue Recurring Return
    d.months_since_last_rr_dmart,                        -- Meses transcurridos desde su último estado RR
    d.inactivity_gap_months AS inactivity_gap_months_dmart,
    COALESCE(d.is_active_dmart, FALSE) AS is_active_dmart,

    -- --------------------------------------------------------------------------
    -- CICLO DE VIDA PEYA GLOBAL (LEVEL 1 Y LEVEL 2)
    -- --------------------------------------------------------------------------
    COALESCE(p.user_type_l1_peya, 'Never Active') AS user_type_l1_peya,
    COALESCE(p.user_type_l2_peya, 'Never Active') AS user_type_l2_peya,
    p.previous_type_l1_peya,
    p.previous_type_l2_peya,
    COALESCE(p.Type_Peya, 'Never Active') AS Type_Peya,   -- Legacy

    -- Métricas de Tenure y Rachas en PeYa Global
    p.user_tenure_months_peya,                           -- Antigüedad total desde 1ra compra en PeYa
    p.consecutive_active_months AS consecutive_active_months_peya,
    p.tenure_rr_streak_months_peya,
    p.last_rr_month_peya,
    p.months_since_last_rr_peya,
    p.inactivity_gap_months AS inactivity_gap_months_peya,
    COALESCE(p.is_active_peya, FALSE) AS is_active_peya

FROM peya_final p
FULL OUTER JOIN dmart_final d 
    ON p.customer_id = d.customer_id 
   AND p.month = d.month
   AND p.country = d.country;