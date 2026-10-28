DECLARE query_name STRING DEFAULT '10. Double Ya Data - Base - Performance.sql';

-- Sheets Name: 1. ET - DY Data (21 - Double Ya Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/18cUpQbzQXxAMcDix675p1zscuc_SmvXS_bYaVtEkUUU


DECLARE start_date DATE DEFAULT '2025-01-01';

WITH

-- 1) Órdenes identificadas como Double Ya
dy_orders AS (
  SELECT DISTINCT
    CAST(dy.order_details.id.secondary AS STRING) AS order_id
  FROM `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya` dy
  WHERE dy.order_type = 'DOUBLE_YA'
),

-- 2) Partners en scope oficiales (alineado a OKRs y Glosario Métrica 143)
partners_scope AS (
  SELECT DISTINCT
    p.partner_id,
    p.country_id,
    CASE
      WHEN c.country_name IN ('República Dominicana', 'Republic Dominican', 'Dominican Republic') THEN 'Republica Dominicana'
      ELSE c.country_name
    END AS country
  FROM `peya-bi-tools-pro.il_core.dim_partner` p
  INNER JOIN `peya-datamarts-pro.dm_dmarts.dim_partner_darkstore` pd
    ON p.partner_id = pd.partner_id
  INNER JOIN `peya-bi-tools-pro.il_core.dim_country` c
    ON p.country_id = c.country_id
  WHERE p.partner_name NOT IN (
    'RD_12_Torre OV', 'PA_9_Midtown', 'SV_6_Torre Futura',
    'EC_17_TiendaPick-Up Oficina', 'PE_3_PuntaHermosa', 'BO_19_Truck',
    'UY_15_Eventos', 'PE_24_FILO', 'EC_6_Oficina'
  )
),

-- 3) Sesiones de navegación y transacciones desde perseus_fact_partner_funnel (Cruce por partner y country_id)
sessions_data AS (
  SELECT
    DATE_TRUNC(DATE(fp.date), MONTH) AS month,
    ps.country,
    
    SUM(fp.funnel_shop_details)     AS total_sessions_details,
    SUM(fp.funnel_shop_transaction) AS total_sessions_transaction,

    -- Double Ya (Flag > 0)
    SUM(IF(IFNULL(fp.funnel_shop_double_ya, 0) > 0, fp.funnel_shop_details, 0))     AS sessions_details_dy,
    SUM(IF(IFNULL(fp.funnel_shop_double_ya, 0) > 0, fp.funnel_shop_transaction, 0)) AS sessions_transaction_dy,

    -- Direct / Non Double Ya (Flag = 0 o NULL)
    SUM(IF(IFNULL(fp.funnel_shop_double_ya, 0) = 0, fp.funnel_shop_details, 0))     AS sessions_details_direct,
    SUM(IF(IFNULL(fp.funnel_shop_double_ya, 0) = 0, fp.funnel_shop_transaction, 0)) AS sessions_transaction_direct

  FROM `peya-bi-tools-pro.il_sessions.perseus_fact_partner_funnel` fp
  INNER JOIN partners_scope ps
    ON fp.partner_id = ps.partner_id
   AND (
     fp.country_id = ps.country_id
     OR fp.country_id IS NULL
     OR fp.country_id = 0
   )
  WHERE DATE(fp.date) >= start_date
  GROUP BY 1, 2
),

-- 4) Primera orden histórica de cada usuario en D-Marts (identifica mes de nacimiento como New User)
first_dmart_orders AS (
  SELECT
    CAST(fo.customer_id AS STRING) AS customer_id,
    MIN(DATE(fo.registered_date))   AS first_order_date
  FROM `peya-bi-tools-pro.il_core.fact_orders` fo
  INNER JOIN `peya-bi-tools-pro.il_core.dim_partner` dp
    ON fo.restaurant.id = dp.partner_id
  WHERE fo.order_status = 'CONFIRMED'
    AND dp.is_darkstore = TRUE
    AND fo.registered_date >= '2020-04-01'
    AND fo.customer_id IS NOT NULL
  GROUP BY 1
),

-- 5) Órdenes a nivel orden desde customer_orders_sku_level agregando SKUs
--    Se procesa desde (start_date - 1 mes) para que la cohorte del mes más antiguo tenga su mes M-1
orders_base AS (
  SELECT
    DATE_TRUNC(ord.order_date, MONTH) AS month,
    CASE
      WHEN ord.country_name IN ('República Dominicana', 'Republic Dominican', 'Dominican Republic') THEN 'Republica Dominicana'
      ELSE ord.country_name
    END AS country,
    CAST(ord.customer_id AS STRING)             AS customer_id,
    CAST(ord.order_id AS STRING)                AS order_id,
    SUM(ord.fulfilled_quantity)                 AS fulfilled_quantity,
    SUM(ord.total_amount_net_with_discount_eur) AS total_amount_net_with_discount_eur,
    SUM(ord.total_cogs_sold_net_eur)            AS total_cogs_sold_net_eur,
    IF(dy.order_id IS NOT NULL, TRUE, FALSE)    AS is_dy
  FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` ord
  LEFT JOIN dy_orders dy
    ON CAST(ord.order_id AS STRING) = dy.order_id
  WHERE ord.order_date >= DATE_SUB(start_date, INTERVAL 1 MONTH)
    AND UPPER(ord.state) = 'CONFIRMED'
    AND ord.customer_id IS NOT NULL
  GROUP BY 1, 2, 3, 4, 8
),

-- 6) Perfil mensual de compra por usuario y país (DY, Direct, Hybrid) con agregación individual
user_monthly_activity AS (
  SELECT
    month,
    country,
    customer_id,
    COUNT(DISTINCT order_id)                    AS total_orders,
    SUM(fulfilled_quantity)                     AS user_units_sold,
    SUM(total_amount_net_with_discount_eur)     AS user_net_sales_eur,
    SUM(total_cogs_sold_net_eur)                AS user_cogs,

    -- Desglose absoluto por tipo de orden a nivel transacción
    COUNTIF(is_dy)                              AS dy_orders,
    COUNTIF(NOT is_dy)                          AS direct_orders,
    SUM(IF(is_dy, fulfilled_quantity, 0))       AS units_sold_dy_abs,
    SUM(IF(NOT is_dy, fulfilled_quantity, 0))   AS units_sold_direct_abs,
    SUM(IF(is_dy, total_amount_net_with_discount_eur, 0))     AS net_sales_eur_dy_abs,
    SUM(IF(NOT is_dy, total_amount_net_with_discount_eur, 0)) AS net_sales_eur_direct_abs,
    SUM(IF(is_dy, total_cogs_sold_net_eur, 0))                AS cogs_dy_abs,
    SUM(IF(NOT is_dy, total_cogs_sold_net_eur, 0))            AS cogs_direct_abs,

    -- Perfil mensual del usuario según su comportamiento global
    CASE
      WHEN COUNTIF(is_dy) > 0 AND COUNTIF(NOT is_dy) = 0 THEN 'DY'
      WHEN COUNTIF(is_dy) = 0 AND COUNTIF(NOT is_dy) > 0 THEN 'DIRECT'
      WHEN COUNTIF(is_dy) > 0 AND COUNTIF(NOT is_dy) > 0 THEN 'HYBRID'
    END AS user_profile
  FROM orders_base
  GROUP BY 1, 2, 3
),

-- 7) Métricas comerciales y volumétricas por mes y país segmentadas por perfil de usuario y absolutas por orden (Últimos 13 meses)
commercial_metrics AS (
  SELECT
    month,
    country,

    -- Totales D-Marts
    SUM(total_orders)                                                              AS total_orders,
    SUM(user_units_sold)                                                           AS total_units_sold,
    SUM(user_net_sales_eur)                                                        AS total_net_sales_eur,
    SUM(user_cogs)                                                                 AS total_cogs,
    COUNT(DISTINCT customer_id)                                                    AS total_active_users,

    -- Totales Absolutos por Canal a Nivel Orden (Todas las órdenes DY vs Direct)
    SUM(dy_orders)                                                                 AS orders_dy_abs,
    SUM(units_sold_dy_abs)                                                         AS units_sold_dy_abs,
    SUM(net_sales_eur_dy_abs)                                                      AS net_sales_eur_dy_abs,
    SUM(cogs_dy_abs)                                                               AS cogs_dy_abs,

    SUM(direct_orders)                                                             AS orders_direct_abs,
    SUM(units_sold_direct_abs)                                                     AS units_sold_direct_abs,
    SUM(net_sales_eur_direct_abs)                                                  AS net_sales_eur_direct_abs,
    SUM(cogs_direct_abs)                                                           AS cogs_direct_abs,

    -- Solo Double Ya (DY)
    SUM(CASE WHEN user_profile = 'DY' THEN total_orders ELSE 0 END)                AS orders_dy,
    SUM(CASE WHEN user_profile = 'DY' THEN user_units_sold ELSE 0 END)             AS units_sold_dy,
    SUM(CASE WHEN user_profile = 'DY' THEN user_net_sales_eur ELSE 0 END)          AS net_sales_eur_dy,
    SUM(CASE WHEN user_profile = 'DY' THEN user_cogs ELSE 0 END)                   AS cogs_dy,
    COUNT(DISTINCT CASE WHEN user_profile = 'DY' THEN customer_id END)             AS active_users_dy,

    -- Solo Direct (No Double Ya)
    SUM(CASE WHEN user_profile = 'DIRECT' THEN total_orders ELSE 0 END)            AS orders_direct,
    SUM(CASE WHEN user_profile = 'DIRECT' THEN user_units_sold ELSE 0 END)         AS units_sold_direct,
    SUM(CASE WHEN user_profile = 'DIRECT' THEN user_net_sales_eur ELSE 0 END)      AS net_sales_eur_direct,
    SUM(CASE WHEN user_profile = 'DIRECT' THEN user_cogs ELSE 0 END)               AS cogs_direct,
    COUNT(DISTINCT CASE WHEN user_profile = 'DIRECT' THEN customer_id END)         AS active_users_direct,

    -- Híbridos (Compraron por ambos canales en el mes)
    SUM(CASE WHEN user_profile = 'HYBRID' THEN total_orders ELSE 0 END)            AS orders_hybrid,
    SUM(CASE WHEN user_profile = 'HYBRID' THEN user_units_sold ELSE 0 END)         AS units_sold_hybrid,
    SUM(CASE WHEN user_profile = 'HYBRID' THEN user_net_sales_eur ELSE 0 END)      AS net_sales_eur_hybrid,
    SUM(CASE WHEN user_profile = 'HYBRID' THEN user_cogs ELSE 0 END)               AS cogs_hybrid,
    COUNT(DISTINCT CASE WHEN user_profile = 'HYBRID' THEN customer_id END)         AS active_users_hybrid

  FROM user_monthly_activity
  WHERE month >= start_date
  GROUP BY 1, 2
),

-- 8) Cohorte histórica de New Users (mes en que hicieron su primera compra D-Mart)
new_users_cohort AS (
  SELECT
    uma.month        AS cohort_month,
    uma.country,
    uma.customer_id,
    uma.user_profile AS new_user_type  -- 'DY', 'DIRECT', 'HYBRID'
  FROM user_monthly_activity uma
  INNER JOIN first_dmart_orders fdo
    ON uma.customer_id = fdo.customer_id
   AND uma.month = DATE_TRUNC(fdo.first_order_date, MONTH)
),

-- 8.1) New Users nacidos en el mes M (Últimos 13 meses)
new_users_monthly AS (
  SELECT
    cohort_month AS month,
    country,
    COUNT(DISTINCT customer_id)                                                 AS total_new_users,
    COUNT(DISTINCT CASE WHEN new_user_type = 'DY'     THEN customer_id END)   AS new_users_dy,
    COUNT(DISTINCT CASE WHEN new_user_type = 'DIRECT' THEN customer_id END)   AS new_users_direct,
    COUNT(DISTINCT CASE WHEN new_user_type = 'HYBRID' THEN customer_id END)   AS new_users_hybrid
  FROM new_users_cohort
  WHERE cohort_month >= start_date
  GROUP BY 1, 2
),

-- 9) M1 Return Users que retornaron a comprar en el mes M (habiendo nacido en M-1) (Últimos 13 meses)
m1_retention_monthly AS (
  SELECT
    r.month,
    r.country,

    -- Cohorte 1: New Users DY en M-1 -> Retornaron en M
    COUNT(DISTINCT CASE WHEN n.new_user_type = 'DY' AND r.user_profile = 'DY'     THEN r.customer_id END) AS ret_dy_to_dy,
    COUNT(DISTINCT CASE WHEN n.new_user_type = 'DY' AND r.user_profile = 'DIRECT' THEN r.customer_id END) AS ret_dy_to_direct,
    COUNT(DISTINCT CASE WHEN n.new_user_type = 'DY' AND r.user_profile = 'HYBRID' THEN r.customer_id END) AS ret_dy_to_hybrid,

    -- Cohorte 2: New Users DIRECT en M-1 -> Retornaron en M
    COUNT(DISTINCT CASE WHEN n.new_user_type = 'DIRECT' AND r.user_profile = 'DY'     THEN r.customer_id END) AS ret_direct_to_dy,
    COUNT(DISTINCT CASE WHEN n.new_user_type = 'DIRECT' AND r.user_profile = 'DIRECT' THEN r.customer_id END) AS ret_direct_to_direct,
    COUNT(DISTINCT CASE WHEN n.new_user_type = 'DIRECT' AND r.user_profile = 'HYBRID' THEN r.customer_id END) AS ret_direct_to_hybrid,

    -- Cohorte 3: New Users HYBRID en M-1 -> Retornaron en M
    COUNT(DISTINCT CASE WHEN n.new_user_type = 'HYBRID' AND r.user_profile = 'DY'     THEN r.customer_id END) AS ret_hybrid_to_dy,
    COUNT(DISTINCT CASE WHEN n.new_user_type = 'HYBRID' AND r.user_profile = 'DIRECT' THEN r.customer_id END) AS ret_hybrid_to_direct,
    COUNT(DISTINCT CASE WHEN n.new_user_type = 'HYBRID' AND r.user_profile = 'HYBRID' THEN r.customer_id END) AS ret_hybrid_to_hybrid

  FROM user_monthly_activity r
  INNER JOIN new_users_cohort n
    ON  r.customer_id = n.customer_id
    AND r.country     = n.country
    AND n.cohort_month = DATE_SUB(r.month, INTERVAL 1 MONTH)
  WHERE r.month >= start_date
  GROUP BY 1, 2
)

-- SELECT FINAL: Todas las métricas alineadas al MES M (Desde 2025-01-01)
SELECT
  -- ===== 0) Dimensiones =====
  cm.month,
  cm.country,

  -- ===== 1) Métricas Totales D-Marts del Mes M =====
  cm.total_orders,
  cm.total_units_sold,
  ROUND(cm.total_net_sales_eur, 2)                                              AS total_net_sales_eur,
  ROUND(cm.total_cogs, 2)                                                       AS total_cogs,
  cm.total_active_users,
  COALESCE(s.total_sessions_details, 0)                                         AS total_sessions_details,
  COALESCE(s.total_sessions_transaction, 0)                                     AS total_sessions_transaction,

  -- ===== 2) Métricas Double Ya (Solo DY) del Mes M =====
  cm.orders_dy,
  cm.units_sold_dy,
  ROUND(cm.net_sales_eur_dy, 2)                                                 AS net_sales_eur_dy,
  ROUND(cm.cogs_dy, 2)                                                          AS cogs_dy,
  cm.active_users_dy,
  COALESCE(s.sessions_details_dy, 0)                                            AS sessions_details_dy,
  COALESCE(s.sessions_transaction_dy, 0)                                        AS sessions_transaction_dy,

  -- ===== 3) Métricas Direct (Solo No Double Ya) del Mes M =====
  cm.orders_direct,
  cm.units_sold_direct,
  ROUND(cm.net_sales_eur_direct, 2)                                             AS net_sales_eur_direct,
  ROUND(cm.cogs_direct, 2)                                                      AS cogs_direct,
  cm.active_users_direct,
  COALESCE(s.sessions_details_direct, 0)                                         AS sessions_details_direct,
  COALESCE(s.sessions_transaction_direct, 0)                                     AS sessions_transaction_direct,

  -- ===== 4) Métricas Híbridos (Ambos canales) del Mes M =====
  cm.orders_hybrid,
  cm.units_sold_hybrid,
  ROUND(cm.net_sales_eur_hybrid, 2)                                             AS net_sales_eur_hybrid,
  ROUND(cm.cogs_hybrid, 2)                                                      AS cogs_hybrid,
  cm.active_users_hybrid,

  -- ===== 5) New Users nacidos en el Mes M =====
  COALESCE(num.total_new_users, 0)                                              AS total_new_users,
  COALESCE(num.new_users_dy, 0)                                                 AS new_users_dy,
  COALESCE(num.new_users_direct, 0)                                             AS new_users_direct,
  COALESCE(num.new_users_hybrid, 0)                                             AS new_users_hybrid,

  -- ===== 6) M1 Return Users que volvieron en el Mes M (Nacidos en M-1) (9 Casos) =====
  -- De New Users DY en M-1 que retornaron en M:
  COALESCE(ret.ret_dy_to_dy, 0)                                                 AS ret_dy_to_dy,
  COALESCE(ret.ret_dy_to_direct, 0)                                             AS ret_dy_to_direct,
  COALESCE(ret.ret_dy_to_hybrid, 0)                                             AS ret_dy_to_hybrid,

  -- De New Users Direct en M-1 que retornaron en M:
  COALESCE(ret.ret_direct_to_dy, 0)                                             AS ret_direct_to_dy,
  COALESCE(ret.ret_direct_to_direct, 0)                                         AS ret_direct_to_direct,
  COALESCE(ret.ret_direct_to_hybrid, 0)                                         AS ret_direct_to_hybrid,

  -- De New Users Hybrid en M-1 que retornaron en M:
  COALESCE(ret.ret_hybrid_to_dy, 0)                                             AS ret_hybrid_to_dy,
  COALESCE(ret.ret_hybrid_to_direct, 0)                                         AS ret_hybrid_to_direct,
  COALESCE(ret.ret_hybrid_to_hybrid, 0)                                         AS ret_hybrid_to_hybrid,

  -- ===== 7) Métricas Absolutas por Canal a Nivel Orden (Todas las órdenes DY vs Direct) =====
  -- Double Ya Absoluto (Todas las órdenes DY)
  cm.orders_dy_abs,
  cm.units_sold_dy_abs,
  ROUND(cm.net_sales_eur_dy_abs, 2)                                             AS net_sales_eur_dy_abs,
  ROUND(cm.cogs_dy_abs, 2)                                                      AS cogs_dy_abs,

  -- Direct / Non Double Ya Absoluto (Todas las órdenes Directas)
  cm.orders_direct_abs,
  cm.units_sold_direct_abs,
  ROUND(cm.net_sales_eur_direct_abs, 2)                                         AS net_sales_eur_direct_abs,
  ROUND(cm.cogs_direct_abs, 2)                                                  AS cogs_direct_abs

FROM commercial_metrics cm
LEFT JOIN sessions_data s
  ON  cm.month   = s.month
  AND cm.country = s.country
LEFT JOIN new_users_monthly num
  ON  cm.month   = num.month
  AND cm.country = num.country
LEFT JOIN m1_retention_monthly ret
  ON  cm.month   = ret.month
  AND cm.country = ret.country
ORDER BY month DESC, country ASC;
