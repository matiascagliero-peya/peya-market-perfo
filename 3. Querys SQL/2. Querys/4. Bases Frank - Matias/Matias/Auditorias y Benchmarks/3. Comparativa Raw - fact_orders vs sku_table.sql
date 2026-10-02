DECLARE query_name STRING DEFAULT 'Comparativa Raw: fact_orders vs customer_orders_sku_level';

-- ==============================================================================
-- BENCHMARK RAW: fact_orders (Core) vs customer_orders_sku_level (Datamart)
--
-- Propósito:
--   Comparar directamente las dos tablas fuente crudas sin procesos intermedios
--   para demostrar al equipo que `fact_orders` captura con mayor integridad las
--   órdenes confirmadas y los usuarios activos (MAUs) de Peya Market.
-- ==============================================================================

WITH

-- 1. Darkstores oficiales
darkstores AS (
    SELECT DISTINCT partner_id
    FROM `peya-datamarts-pro.dm_dmarts.dim_partner_darkstore`
),

-- 2. UNIVERSO A: fact_orders (Core Transaccional de PeYa con dim_user)
fact_orders_data AS (
    SELECT
        DATE_TRUNC(fo.registered_date, MONTH) AS Mes,
        fo.country.country_name               AS Pais,

        -- MAUs y Órdenes de Peya Market usando estrictamente customer_id unificado
        COUNT(DISTINCT COALESCE(CAST(du.customer_id AS STRING), fo.customer_id)) AS MAUs_fact_orders,
        COUNT(DISTINCT fo.order_id) AS Orders_fact_orders

    FROM `peya-bi-tools-pro.il_core.fact_orders` fo
    INNER JOIN darkstores ds
        ON fo.restaurant.id = ds.partner_id
    LEFT JOIN `peya-bi-tools-pro.il_core.dim_user` du
        ON fo.user.id = du.user_id
    WHERE fo.registered_date >= '2026-01-01'
      AND fo.order_status = 'CONFIRMED'
      AND fo.country.country_name NOT IN ('Venezuela', 'Costa Rica')
      AND fo.country.country_name IS NOT NULL
      AND COALESCE(CAST(du.customer_id AS STRING), fo.customer_id) IS NOT NULL
    GROUP BY 1, 2
),

-- 3. UNIVERSO B: customer_orders_sku_level (Datamart secundario a nivel ítems)
sku_table_data AS (
    SELECT
        DATE_TRUNC(co.order_date, MONTH) AS Mes,
        co.country_name                  AS Pais,

        -- MAUs y Órdenes según la SKU-table
        COUNT(DISTINCT CAST(co.customer_id AS STRING)) AS MAUs_sku_table,
        COUNT(DISTINCT co.order_id)                    AS Orders_sku_table

    FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` co
    WHERE co.order_date >= '2026-01-01'
      AND UPPER(co.state) = 'CONFIRMED'
      AND co.country_name NOT IN ('Venezuela', 'Costa Rica')
      AND co.country_name IS NOT NULL
    GROUP BY 1, 2
)

-- 4. COMPARATIVA DIRECTA RAW
SELECT
    COALESCE(f.Mes,  s.Mes)  AS Mes,
    COALESCE(f.Pais, s.Pais) AS Pais,

    -- Comparativa de MAUs (Usuarios Únicos)
    f.MAUs_fact_orders,
    s.MAUs_sku_table,
    (f.MAUs_fact_orders - s.MAUs_sku_table) AS Diff_Usuarios,
    ROUND(SAFE_DIVIDE(f.MAUs_fact_orders - s.MAUs_sku_table, s.MAUs_sku_table) * 100, 2) AS Gap_MAUs_Pct,

    -- Comparativa de Órdenes Confirmadas
    f.Orders_fact_orders,
    s.Orders_sku_table,
    (f.Orders_fact_orders - s.Orders_sku_table) AS Diff_Orders,
    ROUND(SAFE_DIVIDE(f.Orders_fact_orders - s.Orders_sku_table, s.Orders_sku_table) * 100, 2) AS Gap_Orders_Pct

FROM fact_orders_data f
FULL OUTER JOIN sku_table_data s
    ON  f.Mes  = s.Mes
    AND f.Pais = s.Pais

ORDER BY Mes DESC, f.MAUs_fact_orders DESC;
