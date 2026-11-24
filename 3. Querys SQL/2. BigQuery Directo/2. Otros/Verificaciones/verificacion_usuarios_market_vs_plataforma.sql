DECLARE query_name STRING DEFAULT 'verificacion_usuarios_market_vs_plataforma';

-- ==============================================================================
-- VERIFICACIÓN: ¿"usuarios totales" de Plataforma y de Market se calculan igual?
--
-- Esta query pone lado a lado, por período, los conteos de usuarios únicos bajo
-- las DOS definiciones de Market que hoy conviven en tus reportes:
--   (A) Darkstore  -> fact_orders + dim_partner_darkstore   (lógica de la Query 2)
--   (B) SKU-table  -> customer_orders_sku_level             (lógica de tu Query 1)
-- y la plataforma global, para que cuantifiques el GAP.
--
-- GRANO: por defecto MONTH (mes). Para reconciliar EXACTAMENTE contra el reporte
--        semanal (Query 2), reemplazá los 2 'MONTH' por 'ISOWEEK'.
--        Ojo: el conteo mensual de únicos NO es la suma de los semanales
--        (un usuario activo en 2 semanas cuenta 1 vez en el mes), por eso la
--        comparación con el semanal solo cierra usando ISOWEEK.
-- ==============================================================================

WITH
darkstore_partners AS (
    SELECT DISTINCT dim_partner.partner_id
    FROM `peya-bi-tools-pro.il_core.dim_partner` dim_partner
    INNER JOIN `peya-datamarts-pro.dm_dmarts.dim_partner_darkstore` pd
        ON pd.partner_id = dim_partner.partner_id
),

-- (A) Universo fact_orders -> Plataforma + Market(darkstore). Misma lógica/filtros que la Query 2.
fo_metrics AS (
    SELECT
        DATE_TRUNC(DATE(o.registered_date), MONTH) AS period,   -- <-- cambiar a ISOWEEK para el semanal
        COUNT(DISTINCT o.customer_id) AS platform_users,
        COUNT(DISTINCT IF(dp.partner_id IS NOT NULL, o.customer_id, NULL)) AS market_users_darkstore
    FROM `peya-bi-tools-pro.il_core.fact_orders` o
    INNER JOIN `peya-bi-tools-pro.il_core.dim_country` c
        ON c.country_id = o.country_id AND c.active = TRUE
    LEFT JOIN darkstore_partners dp
        ON dp.partner_id = o.restaurant.id
    WHERE o.order_status = 'CONFIRMED'
      AND DATE(o.registered_date) >= '2020-01-01'
      AND c.country_name NOT IN ('Venezuela','Costa Rica')
    GROUP BY 1
),

-- (B) Universo SKU-table -> Market segun tu Query 1 original.
sku_metrics AS (
    SELECT
        DATE_TRUNC(order_date, MONTH) AS period,                -- <-- cambiar a ISOWEEK para el semanal
        COUNT(DISTINCT CAST(customer_id AS STRING)) AS market_users_sku
    FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
    WHERE state = 'CONFIRMED'
      AND order_date >= '2020-01-01'
    GROUP BY 1
)

SELECT
    f.period,
    f.platform_users,
    f.market_users_darkstore,                                   -- definición Query 2
    s.market_users_sku,                                         -- definición Query 1 (actual)
    s.market_users_sku - f.market_users_darkstore                       AS market_gap_abs,
    SAFE_DIVIDE(s.market_users_sku - f.market_users_darkstore,
                f.market_users_darkstore)                               AS market_gap_pct
FROM fo_metrics f
LEFT JOIN sku_metrics s USING (period)
ORDER BY f.period;

-- ------------------------------------------------------------------------------
-- LECTURA DEL RESULTADO:
--  * market_gap_abs / market_gap_pct ~ 0  -> las dos definiciones de Market coinciden.
--  * gap > 0 (lo esperable): la SKU-table incluye más partners (super externos,
--    otras verticales de groceries) que solo los darkstores PeYa.
--
-- CAVEAT: market_users_sku no aplica el filtro de países/active (la tabla SKU usa
--   otra nomenclatura de país). Parte del gap puede venir de Venezuela/Costa Rica
--   y de países inactivos incluidos en la SKU-table. Si querés aislar SOLO el
--   efecto "darkstore vs SKU", sacá temporalmente esos 3 filtros de fo_metrics.
-- ------------------------------------------------------------------------------
