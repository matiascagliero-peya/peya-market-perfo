DECLARE query_name STRING DEFAULT '9. Ultra Fresh Data - Base - Performance';

-- Sheets Name: 1. ET - UF Data (14 - UF Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/15-zHA4HDBopwhCBjwhIeHr-mLpVuYCe5I0G4bd8X-4s


-- 9. Ultra Fresh Data - Base - Performance
WITH config AS (
    SELECT ['Produce', 'Meat / Seafood', 'Ready To Consume'] AS uf_categories
),

-- 1. DATA DE GROWTH (Simplificada y con fechas normalizadas)
user_growth AS (
    SELECT
        customer_id,
        dmart_growth_status_fixed AS growth_status,
        COALESCE(plus_user, 0) AS plus_user,
        DATE_TRUNC(DATE(MONTH), MONTH) AS snapshot_month
    FROM
        `peya-food-and-groceries.automated_tables_reports.latam_dmart_growth_tracker`
    WHERE MONTH >= '2025-01-01'
      AND dmart_growth_status_fixed <> 'Churned'
),

-- 2. BASE SKU (Transaccional Pura)
base_sku AS (
    SELECT
        DATE_TRUNC(o.order_date, MONTH) AS month,
        IF(dc.country_name_en = 'Dominican Republic', 'Republica Dominicana', dc.country_name_en) AS country_name,
        o.customer_id,
        o.order_id,

        -- Métricas Monetarias
        o.total_amount_net_with_discount_eur,
        o.total_amount_sold_net_eur,
        o.total_cogs_sold_net_eur,
        o.fulfilled_quantity,
        o.pcm_discount_amount_net_eur,

        -- Flag Ultra Fresh
        IF(o.master_category_parent_english IN UNNEST((SELECT uf_categories FROM config)), 1, 0) AS is_uf_sku

    FROM
        `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` o
    LEFT JOIN `peya-bi-tools-pro.il_core.dim_country` dc
        ON o.country_id = dc.country_id
    WHERE o.order_date >= '2025-01-01'
      AND o.state = 'CONFIRMED'
),

-- 3. NIVEL ORDEN + CRUCE CON GROWTH (Cruce seguro por customer_id y month)
order_level AS (
    SELECT
        b.month,
        b.country_name,
        b.customer_id,
        b.order_id,
        COALESCE(g.growth_status, 'No Info') AS growth_status,
        COALESCE(g.plus_user, 0) AS plus_user,

        -- Métricas Basket Total
        SUM(b.total_amount_net_with_discount_eur) AS total_order_ns_eur,
        SUM(b.total_cogs_sold_net_eur) AS total_order_cogs_eur,
        SUM(b.fulfilled_quantity) AS total_order_units,
        SUM(b.pcm_discount_amount_net_eur) AS total_discounts,

        -- Métricas Ultra Fresh
        SUM(IF(b.is_uf_sku = 1, b.total_amount_net_with_discount_eur, 0)) AS uf_ns_eur,
        SUM(IF(b.is_uf_sku = 1, b.total_amount_sold_net_eur, 0)) AS uf_sales_eur,
        SUM(IF(b.is_uf_sku = 1, b.total_cogs_sold_net_eur, 0)) AS uf_cogs_eur,
        SUM(IF(b.is_uf_sku = 1, b.fulfilled_quantity, 0)) AS uf_units,
        SUM(IF(b.is_uf_sku = 1, b.pcm_discount_amount_net_eur, 0)) AS uf_discounts_eur,

        -- Flag: 1 si la orden tiene al menos un item UF
        MAX(b.is_uf_sku) AS has_uf_item

    FROM base_sku b
    LEFT JOIN user_growth g
        ON b.customer_id = g.customer_id
       AND b.month = g.snapshot_month
    GROUP BY 1, 2, 3, 4, 5, 6
)

-- 4. AGREGACIÓN FINAL (Select altamente limpio y optimizado)
SELECT
    month,
    country_name,
    growth_status,

    ---------------------------------------------------
    -- A. USUARIOS Y FRECUENCIA
    ---------------------------------------------------
    COUNT(DISTINCT customer_id) AS total_active_users,
    COUNT(DISTINCT IF(has_uf_item = 1, customer_id, NULL)) AS uf_buyers,
    ROUND(SAFE_DIVIDE(COUNT(DISTINCT IF(has_uf_item = 1, customer_id, NULL)), COUNT(DISTINCT customer_id)), 3) AS uf_user_penetration,
    ROUND(SAFE_DIVIDE(COUNT(DISTINCT IF(has_uf_item = 1, order_id, NULL)), COUNT(DISTINCT IF(has_uf_item = 1, customer_id, NULL))), 2) AS uf_frequency,

    ---------------------------------------------------
    -- B. ORDENES
    ---------------------------------------------------
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT IF(has_uf_item = 1, order_id, NULL)) AS uf_orders,
    ROUND(SAFE_DIVIDE(COUNT(DISTINCT IF(has_uf_item = 1, order_id, NULL)), COUNT(DISTINCT order_id)), 3) AS uf_attach_rate,

    ---------------------------------------------------
    -- C. METRICAS PLUS
    ---------------------------------------------------
    COUNT(DISTINCT IF(has_uf_item = 1 AND plus_user = 1, order_id, NULL)) AS uf_orders_plus,
    COUNT(DISTINCT IF(has_uf_item = 1 AND plus_user = 1, customer_id, NULL)) AS uf_users_plus,
    COUNT(DISTINCT IF(plus_user = 1, customer_id, NULL)) AS users_plus,
    SUM(IF(plus_user = 1, uf_units, 0)) AS units_uf_plus,
    SUM(IF(has_uf_item = 1 AND plus_user = 1, total_order_units, 0)) AS units_in_uf_orders_plus,
    SUM(IF(plus_user = 1, uf_ns_eur, 0)) AS uf_ns_eur_plus,
    SUM(IF(plus_user = 1 AND has_uf_item = 1, total_order_ns_eur, 0)) AS uf_plus_orders_ns,

    ---------------------------------------------------
    -- D. VENTAS Y TICKET (AFV GENERAL)
    ---------------------------------------------------
    SUM(uf_ns_eur) AS net_sales_uf_eur,
    SUM(IF(has_uf_item = 1, total_order_ns_eur, 0)) AS net_sales_total_basket_with_uf_eur,
    ROUND(SAFE_DIVIDE(SUM(uf_ns_eur), COUNT(DISTINCT IF(has_uf_item = 1, order_id, NULL))), 2) AS afv_uf_eur,
    ROUND(SAFE_DIVIDE(SUM(IF(has_uf_item = 1, total_order_ns_eur, 0)), COUNT(DISTINCT IF(has_uf_item = 1, order_id, NULL))), 2) AS afv_total_basket_with_uf,
    ROUND(SAFE_DIVIDE(SUM(IF(has_uf_item = 0, total_order_ns_eur, 0)), COUNT(DISTINCT IF(has_uf_item = 0, order_id, NULL))), 2) AS afv_total_basket_without_uf,

    ---------------------------------------------------
    -- E. BASKET SIZE (GENERAL)
    ---------------------------------------------------
    SUM(uf_units) AS total_units_uf,
    SUM(IF(has_uf_item = 1, total_order_units, 0)) AS total_units_in_orders_with_uf,
    ROUND(SAFE_DIVIDE(SUM(uf_units), COUNT(DISTINCT IF(has_uf_item = 1, order_id, NULL))), 2) AS avg_units_uf_per_order,

    ---------------------------------------------------
    -- F. RENTABILIDAD
    ---------------------------------------------------
    SUM(uf_sales_eur) AS uf_sales_wur,
    SUM(uf_sales_eur) - SUM(uf_cogs_eur) AS tm_uf_eur,
    SUM(uf_ns_eur) - SUM(uf_cogs_eur) AS fm_uf_eur,
    SUM(IF(has_uf_item = 1, total_order_ns_eur - total_order_cogs_eur, 0)) AS fm_uf_orders,
    SUM(uf_discounts_eur) AS uf_discounts_eur

FROM order_level
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3;