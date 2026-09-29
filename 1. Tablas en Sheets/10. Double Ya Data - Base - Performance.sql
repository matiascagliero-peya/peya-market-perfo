DECLARE query_name STRING DEFAULT '10. Double Ya Data - Base - Performance';

-- 10. Double Ya Data - Base - Performance
-- ============================================================
-- PARÁMETRO GLOBAL DE FECHA
-- ============================================================
DECLARE start_date DATE DEFAULT '2026-01-01';

WITH 
-- NEW USERS (07/8/2026)
-- ============================================================
new_users AS (
    SELECT
        fo.user.id                      AS customer_id,
        MIN(DATE(fo.registered_date))   AS first_order_date
    FROM `peya-bi-tools-pro.il_core.fact_orders` fo
    WHERE fo.order_status = 'CONFIRMED'
      AND par.is_logistic
      AND par.is_darkstore
      AND fo.registered_date >= '2020-04-01'
      AND par.business_type.business_type_name NOT IN ('Courier', 'Courier Business')
    GROUP BY 1
),


-- Retencion (07/8/2026)
-- ============================================================
retention_calc AS (
    WITH new_users AS (
        SELECT DISTINCT customer_id, month, country, scope
        FROM base_data
        WHERE is_new_user = 1
    ),
    organic_next_month AS (
        SELECT DISTINCT customer_id, month, country
        FROM base_data
        WHERE scope = 'No Double Ya'
    )
    SELECT
        n.month,
        n.country,
        n.scope,
        COUNT(DISTINCT n.customer_id) AS retained_new_users_as_organic
    FROM new_users n
    INNER JOIN organic_next_month o
        ON  n.customer_id = o.customer_id
        AND n.country     = o.country
        AND o.month       = DATE_ADD(n.month, INTERVAL 1 MONTH)
    GROUP BY 1, 2, 3
),

-- Métricas generales
-- ============================================================
base_data AS (
    SELECT
        DATE_TRUNC(ord.order_date, MONTH)               AS month,
        ord.country_name                                AS country,
        ord.customer_id,
        ord.order_id,
        ord.fulfilled_quantity,
        ord.total_amount_net_with_discount_eur,
        ord.total_cogs_sold_net_eur,

        CASE 
            WHEN dy.order_type = 'DOUBLE_YA' THEN 'Double Ya' 
            ELSE 'No Double Ya' 
        END AS scope,

        CASE 
            WHEN ord.order_id = ufo.first_order_id THEN 1 
            ELSE 0 
        END AS is_new_user

    FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` ord

    LEFT JOIN `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya` dy
        ON ord.order_id = CAST(dy.order_details.id.secondary AS STRING)

    LEFT JOIN new_users ufo 
        ON ord.customer_id = ufo.customer_id

    WHERE ord.order_date >= start_date    -- << PARÁMETRO
      AND ord.state = 'CONFIRMED'
),
-- 3. Agregación de métricas por mes / país / scope
metrics_agg AS (
    SELECT
        month,
        country,
        scope,
        COUNT(DISTINCT order_id)                                        AS total_orders,
        SUM(fulfilled_quantity)                                         AS units_sold,
        SUM(total_amount_net_with_discount_eur)                         AS net_sales_eur,
        SUM(total_cogs_sold_net_eur)                                    AS cogs,
        COUNT(DISTINCT customer_id)                                     AS active_users,
        COUNT(DISTINCT CASE WHEN is_new_user = 1 THEN customer_id END)  AS new_users_dy
    FROM base_data
    GROUP BY 1, 2, 3
),

-- 5. Partners en scope (para cruzar con sesiones)
--    Usa start_date para ser consistente con el resto del análisis
partners_scope AS (
    SELECT DISTINCT 
        vendor_id, 
        country_name AS country
    FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
    WHERE order_date >= start_date    -- << PARÁMETRO
),

-- Sesiones
-- ============================================================
sessions AS (
    SELECT
        DATE_TRUNC(DATE(fp.date), MONTH) AS month,
        ps.country,
        CASE 
            WHEN fp.funnel_shop_double_ya = 1 THEN 'Double Ya' 
            ELSE 'No Double Ya' 
        END AS scope,
        SUM(fp.funnel_shop_details)     AS sessions_shop_details,
        SUM(fp.funnel_shop_transaction) AS sessions_shop_transaction
    FROM `peya-bi-tools-pro.il_sessions.perseus_fact_partner_funnel` fp
    INNER JOIN partners_scope ps 
        ON CAST(fp.partner_id AS STRING) = ps.vendor_id
    WHERE DATE(fp.date) >= start_date    -- << PARÁMETRO
    GROUP BY 1, 2, 3
)

-- 7. Output final
SELECT
    COALESCE(m.month,   s.month)   AS month,
    COALESCE(m.country, s.country) AS country,
    COALESCE(m.scope,   s.scope)   AS scope,

    m.active_users,
    m.new_users_dy,

    m.total_orders,
    m.units_sold,
    m.net_sales_eur,
    m.cogs,

    s.sessions_shop_details,
    s.sessions_shop_transaction,

    r.retained_new_users_as_organic,

    SAFE_DIVIDE(m.total_orders,                  m.active_users) AS frequency,
    SAFE_DIVIDE(r.retained_new_users_as_organic, m.new_users_dy) AS pct_retention_as_organic

FROM metrics_agg m
LEFT JOIN retention_calc r 
    ON  m.month   = r.month 
    AND m.scope   = r.scope 
    AND m.country = r.country
FULL OUTER JOIN sessions s 
    ON  m.month   = s.month 
    AND m.scope   = s.scope 
    AND m.country = s.country

ORDER BY 1 DESC, 2, 3;