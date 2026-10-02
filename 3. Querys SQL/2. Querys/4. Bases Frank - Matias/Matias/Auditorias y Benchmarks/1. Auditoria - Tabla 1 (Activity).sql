DECLARE query_name STRING DEFAULT 'Auditoría - Frank User Monthly Activity';

-- ==============================================================================
-- QUERY DE AUDITORÍA: Verificación y Control de Calidad de Tabla 1
--
-- Tabla evaluada: peya-food-and-groceries.automated_tables_reports.frank_user_monthly_activity
--
-- Objetivos:
--   1. Sanity Checks: Validar que no existan IDs nulos, duplicados ni inconsistencias.
--   2. Foto de Negocio: Validar volúmenes agregados (órdenes, usuarios, net sales, afv).
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- CHEQUEO 1: Sanity Checks de Integridad (Todos los campos err_* deben dar 0)
-- ------------------------------------------------------------------------------
SELECT
    '1. Control de Nulos e Integridad' AS control_tipo,
    
    -- No debe haber ningún ID ni fecha nula
    COUNTIF(customer_id IS NULL) AS err_null_customer_id,
    COUNTIF(month IS NULL)       AS err_null_month,
    COUNTIF(country IS NULL)     AS err_null_country,

    -- No debe haber duplicados por usuario, país y mes
    COUNT(*) - COUNT(DISTINCT CONCAT(CAST(month AS STRING), '-', country, '-', customer_id)) AS err_duplicated_rows,

    -- Inconsistencias lógicas de negocio
    COUNTIF(is_active_market = TRUE AND orders_market = 0) AS err_market_activo_sin_ordenes,
    COUNTIF(orders_uf_market > orders_market)              AS err_mas_uf_que_ordenes_totales,
    COUNTIF(orders_dy_market > orders_market)              AS err_mas_dy_que_ordenes_totales,
    COUNTIF(units_sold_market > 0 AND orders_market = 0)   AS err_unidades_sin_ordenes,
    COUNTIF(first_order_acquisition_channel IS NULL)       AS err_canal_adquisicion_nulo

FROM `peya-food-and-groceries.automated_tables_reports.frank_user_monthly_activity`;


-- ------------------------------------------------------------------------------
-- CHEQUEO 2: Foto de Volúmenes de los Últimos 3 Meses por País
-- (Para validar que los números coincidan con tus reportes habituales)
-- ------------------------------------------------------------------------------
SELECT
    month,
    country,

    -- Usuarios
    COUNT(DISTINCT customer_id) AS total_users_platform,
    COUNT(DISTINCT IF(is_active_market, customer_id, NULL)) AS active_users_market,
    ROUND(SAFE_DIVIDE(COUNT(DISTINCT IF(is_active_market, customer_id, NULL)), 
                      COUNT(DISTINCT customer_id)) * 100, 2) AS market_penetration_pct,

    -- Órdenes
    SUM(orders_market) AS confirmed_orders_market,
    SUM(orders_uf_market) AS orders_uf,
    SUM(orders_dy_market) AS orders_dy,

    -- Ventas y Unidades
    ROUND(SUM(net_sales_market_eur), 2) AS net_sales_market_eur,
    SUM(units_sold_market) AS units_sold_market,

    -- Ratios clave
    ROUND(SAFE_DIVIDE(SUM(net_sales_market_eur), SUM(orders_market)), 2) AS afv_eur,
    ROUND(SAFE_DIVIDE(SUM(units_sold_market), SUM(orders_market)), 2) AS basket_size

FROM `peya-food-and-groceries.automated_tables_reports.frank_user_monthly_activity`
WHERE month >= DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 MONTH), MONTH)
GROUP BY 1, 2
ORDER BY 1 DESC, confirmed_orders_market DESC;
