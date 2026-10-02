-- ==============================================================================
-- PARTE 1: DATOS DE USUARIOS (Demografía, Segmentación y Perfil de Clientes)
-- Nombre: warehouse_users_performance
--
-- Objetivo: Medir exclusivamente la base de clientes de cada WHS:
--   - Universo de compradores únicos en el mes.
--   - Clientes Core vs casuales (% de usuarios Core).
--   - Nivel socioeconómico (% de usuarios High Income).
--   - Antigüedad / Tenure promedio del cliente en meses.
--   - Adopción de categorías frescas (Ultra Fresh Users).
--
-- Grano: 1 fila por (month_date, warehouse_id)
-- ==============================================================================

DECLARE start_month DATE DEFAULT DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 MONTH), MONTH);
DECLARE end_month   DATE DEFAULT DATE_TRUNC(CURRENT_DATE(), MONTH);

WITH

-- 1. Darkstores desde dim_partner
dmart_partners AS (
  SELECT DISTINCT
    dp.warehouse_id,
    dp.warehouse_name,
    CAST(dp.partner_id AS STRING) AS partner_id
  FROM `peya-bi-tools-pro.il_core.dim_partner` dp
  WHERE dp.is_darkstore = TRUE
    AND dp.warehouse_id IS NOT NULL
),

-- 2. Clientes con compras confirmadas en el mes desde fact_orders
users_base AS (
  SELECT DISTINCT
    dp.warehouse_id,
    dp.warehouse_name,
    CAST(fo.customer_id AS STRING)              AS customer_id,
    DATE_TRUNC(DATE(fo.registered_date), MONTH) AS month_date
  FROM `peya-bi-tools-pro.il_core.fact_orders` fo
  INNER JOIN dmart_partners dp
    ON fo.restaurant.id = dp.partner_id
  WHERE fo.registered_date >= start_month
    AND fo.registered_date <= end_month
    AND fo.order_status = 'CONFIRMED'
),

-- 3. Segmentación del Usuario (Core & High Income) desde user_lifecycle
user_segments AS (
  SELECT
    CAST(du.customer_id AS STRING)                           AS customer_id,
    MAX(CASE WHEN UPPER(lc.subsegment) = 'CORE' THEN 1 ELSE 0 END) AS is_core_user,
    MAX(CASE WHEN UPPER(lc.user_income) = 'HIGH' THEN 1 ELSE 0 END) AS is_high_income_user
  FROM `peya-bi-tools-pro.il_qcommerce.user_lifecycle` lc
  INNER JOIN `peya-bi-tools-pro.il_core.dim_user` du
    ON lc.user_id = du.user_id AND lc.country_id = du.country_id
  GROUP BY 1
),

-- 4. Antigüedad promedio del usuario desde latam_dmart_growth_tracker
user_tenure AS (
  SELECT
    CAST(customer_id AS STRING)  AS customer_id,
    DATE_TRUNC(month, MONTH)     AS month_date,
    AVG(mes_en_curso)            AS user_tenure_months
  FROM `peya-food-and-groceries.automated_tables_reports.latam_dmart_growth_tracker`
  WHERE month >= start_month
    AND dmart_growth_status_fixed != 'Churned'
  GROUP BY 1, 2
),

-- 5. Clientes que compraron Ultra Fresh en el mes
users_ultra_fresh AS (
  SELECT DISTINCT
    co.warehouse_id,
    CAST(co.customer_id AS STRING)             AS customer_id,
    DATE_TRUNC(co.order_date, MONTH)           AS month_date
  FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` co
  WHERE co.order_date >= start_month
    AND co.order_date <= end_month
    AND co.state = 'CONFIRMED'
    AND co.master_category_parent_english IN ('Produce', 'Meat / Seafood', 'Ready To Consume')
)

-- ==============================================================================
-- SELECT FINAL: PARTE 1 - USUARIOS
-- ==============================================================================
SELECT
  -- Claves
  ub.month_date,
  ub.warehouse_id,
  ub.warehouse_name,

  -- Métricas de Usuarios
  COUNT(DISTINCT ub.customer_id)                                    AS total_users,
  
  -- Segmento Core
  COUNT(DISTINCT CASE WHEN seg.is_core_user = 1 THEN ub.customer_id END) AS core_users,
  ROUND(SAFE_DIVIDE(COUNT(DISTINCT CASE WHEN seg.is_core_user = 1 THEN ub.customer_id END), COUNT(DISTINCT ub.customer_id)) * 100, 1) AS core_users_pct,

  -- Segmento High Income
  COUNT(DISTINCT CASE WHEN seg.is_high_income_user = 1 THEN ub.customer_id END) AS high_income_users,
  ROUND(SAFE_DIVIDE(COUNT(DISTINCT CASE WHEN seg.is_high_income_user = 1 THEN ub.customer_id END), COUNT(DISTINCT ub.customer_id)) * 100, 1) AS high_income_users_pct,

  -- Antigüedad / Madurez de la base de clientes
  ROUND(AVG(ten.user_tenure_months), 1)                             AS avg_tenure_months,

  -- Adopción de Frescos (Ultra Fresh)
  COUNT(DISTINCT uf.customer_id)                                    AS uf_users,
  ROUND(SAFE_DIVIDE(COUNT(DISTINCT uf.customer_id), COUNT(DISTINCT ub.customer_id)) * 100, 1) AS uf_users_penetration_pct

FROM users_base ub

LEFT JOIN user_segments seg
  ON ub.customer_id = seg.customer_id

LEFT JOIN user_tenure ten
  ON  ub.customer_id = ten.customer_id
  AND ub.month_date   = ten.month_date

LEFT JOIN users_ultra_fresh uf
  ON  ub.warehouse_id = uf.warehouse_id
  AND ub.customer_id  = uf.customer_id
  AND ub.month_date   = uf.month_date

GROUP BY
  ub.month_date,
  ub.warehouse_id,
  ub.warehouse_name
ORDER BY
  ub.month_date DESC,
  total_users DESC;
