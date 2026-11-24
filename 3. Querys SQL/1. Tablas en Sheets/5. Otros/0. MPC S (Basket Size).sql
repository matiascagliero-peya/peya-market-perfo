WITH orders AS (
    SELECT
        CAST(order_id AS STRING) AS order_id,
        CASE WHEN small_order_fee > 0 THEN 1 ELSE 0 END AS is_sof_order,
        user.is_user_plus AS is_plus_user,
        DATE_TRUNC(registered_date, MONTH) AS month,
        COALESCE(gpo.gpo_harmony / monthly_rate_eu, 0) AS gpo_value
    FROM `peya-datamarts-pro.dm_order_profitability.fact_order_profitability`
    WHERE registered_date >= DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 13 MONTH), MONTH)
      AND order_status = 'CONFIRMED'
      AND partner.vertical_group = 'D-Mart'
),

sku_orders AS (
    SELECT
        CAST(order_id AS STRING) AS order_id,
        customer_id,
        SUM(fulfilled_quantity) AS units_in_order,
        COUNT(DISTINCT sku_id) AS sku_count,
        MAX(CASE WHEN master_category_parent_english IN ('Produce', 'Meat / Seafood', 'Ready To Consume') THEN 1 ELSE 0 END) AS is_uf_order
    FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
    WHERE state = 'CONFIRMED'
    GROUP BY 1, 2
)

SELECT
    o.month,
    COUNT(*) AS total_orders,
    COUNT(DISTINCT s.customer_id) AS users,
    -----------------------------------------------------
    --  BASKET SIZE
    -----------------------------------------------------
    SUM(COALESCE(s.units_in_order, 0)) AS total_units_month,
    SAFE_DIVIDE(SUM(COALESCE(s.units_in_order, 0)), COUNT(*)) AS basket_units_per_order,
    -----------------------------------------------------
    --  CUSTOMER UNITS (NUEVO)
    -----------------------------------------------------
    SAFE_DIVIDE(SUM(COALESCE(s.units_in_order, 0)), COUNT(DISTINCT s.customer_id)) AS customer_units,
    -----------------------------------------------------
    --  SKU VARIETY
    -----------------------------------------------------
    SUM(COALESCE(s.sku_count, 0)) AS total_sku_variety_month,
    SAFE_DIVIDE(SUM(COALESCE(s.sku_count, 0)), COUNT(*)) AS sku_variety_per_order,
    -----------------------------------------------------
    --  SOF
    -----------------------------------------------------
    SUM(CASE WHEN o.is_sof_order = 1 THEN COALESCE(s.units_in_order, 0) ELSE 0 END) AS sof_units,
    SUM(CASE WHEN o.is_sof_order = 1 THEN 1 ELSE 0 END) AS sof_orders,
    SAFE_DIVIDE(
        SUM(CASE WHEN o.is_sof_order = 1 THEN COALESCE(s.units_in_order, 0) ELSE 0 END),
        NULLIF(SUM(CASE WHEN o.is_sof_order = 1 THEN 1 ELSE 0 END), 0)
    ) AS sof_basket_units_per_order,

    -----------------------------------------------------
    --  NON SOF
    -----------------------------------------------------
    SUM(CASE WHEN o.is_sof_order = 0 THEN COALESCE(s.units_in_order, 0) ELSE 0 END) AS non_sof_units,
    SUM(CASE WHEN o.is_sof_order = 0 THEN 1 ELSE 0 END) AS non_sof_orders,
    SAFE_DIVIDE(
        SUM(CASE WHEN o.is_sof_order = 0 THEN COALESCE(s.units_in_order, 0) ELSE 0 END),
        NULLIF(SUM(CASE WHEN o.is_sof_order = 0 THEN 1 ELSE 0 END), 0)
    ) AS non_sof_basket_units_per_order,

    -----------------------------------------------------
    --  PLUS
    -----------------------------------------------------
    SUM(CASE WHEN o.is_plus_user = TRUE THEN COALESCE(s.units_in_order, 0) ELSE 0 END) AS plus_units,
    SUM(CASE WHEN o.is_plus_user = TRUE THEN 1 ELSE 0 END) AS plus_orders,
    SAFE_DIVIDE(
        SUM(CASE WHEN o.is_plus_user = TRUE THEN COALESCE(s.units_in_order, 0) ELSE 0 END),
        NULLIF(SUM(CASE WHEN o.is_plus_user = TRUE THEN 1 ELSE 0 END), 0)
    ) AS plus_basket_units_per_order,
    SAFE_DIVIDE(
        SUM(CASE WHEN o.is_plus_user = TRUE THEN COALESCE(s.units_in_order, 0) ELSE 0 END),
        NULLIF(COUNT(DISTINCT CASE WHEN o.is_plus_user = TRUE THEN s.customer_id END), 0)
    ) AS plus_customer_units,
    -----------------------------------------------------
    --  NON PLUS
    -----------------------------------------------------
    SUM(CASE WHEN o.is_plus_user = FALSE THEN COALESCE(s.units_in_order, 0) ELSE 0 END) AS non_plus_units,
    SUM(CASE WHEN o.is_plus_user = FALSE THEN 1 ELSE 0 END) AS non_plus_orders,
    SAFE_DIVIDE(
        SUM(CASE WHEN o.is_plus_user = FALSE THEN COALESCE(s.units_in_order, 0) ELSE 0 END),
        NULLIF(SUM(CASE WHEN o.is_plus_user = FALSE THEN 1 ELSE 0 END), 0)
    ) AS non_plus_basket_units_per_order,
    SAFE_DIVIDE(
        SUM(CASE WHEN o.is_plus_user = FALSE THEN COALESCE(s.units_in_order, 0) ELSE 0 END),
        NULLIF(COUNT(DISTINCT CASE WHEN o.is_plus_user = FALSE THEN s.customer_id END), 0)
    ) AS non_plus_customer_units,
    -----------------------------------------------------
    --  UF
    -----------------------------------------------------
    SUM(CASE WHEN s.is_uf_order = 1 THEN COALESCE(s.units_in_order, 0) ELSE 0 END) AS uf_units,
    SUM(CASE WHEN s.is_uf_order = 1 THEN 1 ELSE 0 END) AS uf_orders,
    SAFE_DIVIDE(
        SUM(CASE WHEN s.is_uf_order = 1 THEN COALESCE(s.units_in_order, 0) ELSE 0 END),
        NULLIF(SUM(CASE WHEN s.is_uf_order = 1 THEN 1 ELSE 0 END), 0)
    ) AS uf_basket_units_per_order,
    -----------------------------------------------------
    --  NON UF
    -----------------------------------------------------
    SUM(CASE WHEN s.is_uf_order = 0 THEN COALESCE(s.units_in_order, 0) ELSE 0 END) AS non_uf_units,
    SUM(CASE WHEN s.is_uf_order = 0 THEN 1 ELSE 0 END) AS non_uf_orders,
    SAFE_DIVIDE(
        SUM(CASE WHEN s.is_uf_order = 0 THEN COALESCE(s.units_in_order, 0) ELSE 0 END),
        NULLIF(SUM(CASE WHEN s.is_uf_order = 0 THEN 1 ELSE 0 END), 0)
    ) AS non_uf_basket_units_per_order,

    -----------------------------------------------------
    --  GPO
    -----------------------------------------------------
    SUM(o.gpo_value) AS total_gpo,
    SAFE_DIVIDE(SUM(o.gpo_value), COUNT(*)) AS gpo_per_order,
    SUM(CASE WHEN o.is_sof_order = 1 THEN o.gpo_value ELSE 0 END) AS sof_gpo,
    SAFE_DIVIDE(
        SUM(CASE WHEN o.is_sof_order = 1 THEN o.gpo_value ELSE 0 END),
        NULLIF(SUM(CASE WHEN o.is_sof_order = 1 THEN 1 ELSE 0 END), 0)
    ) AS sof_gpo_per_order,
    SUM(CASE WHEN o.is_sof_order = 0 THEN o.gpo_value ELSE 0 END) AS non_sof_gpo,
    SAFE_DIVIDE(
        SUM(CASE WHEN o.is_sof_order = 0 THEN o.gpo_value ELSE 0 END),
        NULLIF(SUM(CASE WHEN o.is_sof_order = 0 THEN 1 ELSE 0 END), 0)
    ) AS non_sof_gpo_per_order,
    SUM(CASE WHEN o.is_plus_user = TRUE THEN o.gpo_value ELSE 0 END) AS plus_gpo,
    SAFE_DIVIDE(
        SUM(CASE WHEN o.is_plus_user = TRUE THEN o.gpo_value ELSE 0 END),
        NULLIF(SUM(CASE WHEN o.is_plus_user = TRUE THEN 1 ELSE 0 END), 0)
    ) AS plus_gpo_per_order,
    SUM(CASE WHEN o.is_plus_user = FALSE THEN o.gpo_value ELSE 0 END) AS non_plus_gpo,
    SAFE_DIVIDE(
        SUM(CASE WHEN o.is_plus_user = FALSE THEN o.gpo_value ELSE 0 END),
        NULLIF(SUM(CASE WHEN o.is_plus_user = FALSE THEN 1 ELSE 0 END), 0)
    ) AS non_plus_gpo_per_order,
    SUM(CASE WHEN s.is_uf_order = 1 THEN o.gpo_value ELSE 0 END) AS uf_gpo,
    SAFE_DIVIDE(
        SUM(CASE WHEN s.is_uf_order = 1 THEN o.gpo_value ELSE 0 END),
        NULLIF(SUM(CASE WHEN s.is_uf_order = 1 THEN 1 ELSE 0 END), 0)
    ) AS uf_gpo_per_order,
    SUM(CASE WHEN s.is_uf_order = 0 THEN o.gpo_value ELSE 0 END) AS non_uf_gpo,
    SAFE_DIVIDE(
        SUM(CASE WHEN s.is_uf_order = 0 THEN o.gpo_value ELSE 0 END),
        NULLIF(SUM(CASE WHEN s.is_uf_order = 0 THEN 1 ELSE 0 END), 0)
    ) AS non_uf_gpo_per_order

FROM orders o
LEFT JOIN sku_orders s
  ON o.order_id = s.order_id
GROUP BY o.month
ORDER BY o.month;
