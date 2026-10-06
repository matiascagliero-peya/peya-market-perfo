-- ==============================================================================
-- Comparativa Raw: fact_orders (dim_partner) vs customer_orders_sku_level
-- Sin dim_user (usando directamente fo.customer_id)
-- ==============================================================================

WITH

fact_orders_data AS (
    SELECT
        DATE_TRUNC(fo.registered_date, MONTH) AS Mes,
        fo.country.country_name               AS Pais,
        COUNT(DISTINCT CAST(fo.customer_id AS STRING)) AS MAUs_fact_orders,
        COUNT(DISTINCT fo.order_id)                    AS Orders_fact_orders
    FROM `peya-bi-tools-pro.il_core.fact_orders` fo
    INNER JOIN `peya-bi-tools-pro.il_core.dim_partner` dp
        ON fo.restaurant.id = dp.partner_id
    WHERE dp.is_darkstore = TRUE
      AND fo.registered_date >= '2026-01-01'
      AND fo.order_status = 'CONFIRMED'
    GROUP BY 1, 2
),

sku_table_data AS (
    SELECT
        DATE_TRUNC(order_date, MONTH) AS Mes,
        country_name                  AS Pais,
        COUNT(DISTINCT CAST(customer_id AS STRING)) AS MAUs_sku_table,
        COUNT(DISTINCT order_id)                    AS Orders_sku_table
    FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
    WHERE order_date >= '2026-01-01'
      AND UPPER(state) = 'CONFIRMED'
    GROUP BY 1, 2
)

SELECT
    Mes,
    Pais,
    f.MAUs_fact_orders,
    s.MAUs_sku_table,
    (f.MAUs_fact_orders - s.MAUs_sku_table) AS Diff_MAUs,
    ROUND(SAFE_DIVIDE(f.MAUs_fact_orders - s.MAUs_sku_table, s.MAUs_sku_table) * 100, 2) AS Gap_MAUs_Pct,
    f.Orders_fact_orders,
    s.Orders_sku_table,
    (f.Orders_fact_orders - s.Orders_sku_table) AS Diff_Orders,
    ROUND(SAFE_DIVIDE(f.Orders_fact_orders - s.Orders_sku_table, s.Orders_sku_table) * 100, 2) AS Gap_Orders_Pct
FROM fact_orders_data f
FULL OUTER JOIN sku_table_data s
    USING (Mes, Pais)
ORDER BY Mes DESC, f.MAUs_fact_orders DESC;
