-- ============================================================
-- DIAGNÓSTICO DE CAMBIOS (latam_first_dmart_order_date_users):
-- 1. [LÓGICA]    adoption_since ahora calculado desde customer_orders_sku_level
--               (fuente de verdad del customer_id real); se elimina la derivación
--               via fact_orders + is_darkstore que usaba user.id como proxy
-- 2. [LÓGICA]    acquisition_since (primera orden Peya) obtenido via dim_user bridge
--               para no cruzar fact_orders con customer_orders_sku_level en forma directa
-- 3. [LÓGICA]    monthly_users ahora basado en customer_orders_sku_level directamente
--               (ya no usa fact_orders para las filas de actividad mensual)
-- 4. [DUPLICADOS] ANY_VALUE(user_id) para trazabilidad sin producir cartesiano
-- 5. [COSTO]     PARTITION BY adoption_since + CLUSTER BY customer_id, country
-- 6. [COSTO]     Filtros tempranos en cada CTE base antes de JOINs
-- 7. [HISTÓRICO] sku_normalized resuelve el split pre/post-2025 en customer_orders_sku_level:
--               Pre-2025: co.user_id IS NULL → co.customer_id ERA user.id → bridge dim_user
--               Post-2025: co.user_id IS NOT NULL → co.customer_id ya es el ID real
-- ============================================================

CREATE OR REPLACE TABLE `peya-food-and-groceries.automated_tables_reports.latam_first_dmart_order_date_users_new`
-- REFACTOR: PARTITION BY + CLUSTER BY para acelerar joins downstream
PARTITION BY adoption_since
CLUSTER BY customer_id, country
AS (

WITH
-- REFACTOR [HISTÓRICO]: normaliza customer_id para datos pre y post-2025.
--   Pre-2025 (co.user_id IS NULL): co.customer_id contenía user.id → se bridgea con dim_user.
--   Post-2025 (co.user_id IS NOT NULL): co.customer_id ya es el customer_id real.
--   COALESCE en el caso pre-2025 preserva el viejo valor como fallback si el user no está en dim_user.
sku_normalized AS (
  SELECT
    CASE
      WHEN cast(co.user_id as string) IS NOT NULL THEN co.customer_id
      ELSE COALESCE(du.customer_id, co.customer_id)
    END AS customer_id,
    CASE
      WHEN cast(co.user_id as string) IS NOT NULL THEN cast(co.user_id as string)
      ELSE co.customer_id
    END AS user_id,
    co.order_date,
    co.state,
    dc.country_name AS country
  FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` co
  LEFT JOIN `peya-bi-tools-pro.il_core.dim_country` dc
    ON co.country_id = dc.country_id
  -- Solo aplica el bridge para filas pre-2025 donde user_id aún no existía
  LEFT JOIN `peya-bi-tools-pro.il_core.dim_user` du
    ON  co.user_id IS NULL
    AND CAST(co.customer_id AS STRING) = CAST(du.user_id AS STRING)
  WHERE co.order_date >= '2020-04-01'
),

dmart_adoptions AS (
  SELECT
    customer_id,
    ANY_VALUE(user_id) AS user_id,
    country,
    MIN(order_date)    AS first_dmart_order_date
  FROM sku_normalized
  WHERE state = 'CONFIRMED'
  GROUP BY customer_id, country
),

-- REFACTOR: acquisition_since via dim_user — evita JOIN directo fact_orders × customer_orders
peya_first_orders AS (
  SELECT
    du.customer_id,
    MIN(o.registered_date) AS peya_first_purchase
  FROM `peya-bi-tools-pro.il_core.fact_orders` o
  INNER JOIN `peya-bi-tools-pro.il_core.dim_user` du
    ON o.user.id = du.user_id
  -- REFACTOR: filtro temprano
  WHERE o.registered_date >= '2020-01-01'
    AND o.order_status = 'CONFIRMED'
  GROUP BY du.customer_id
),

data_users AS (
  SELECT
    d.customer_id,
    d.user_id,
    d.country,
    pf.peya_first_purchase,
    d.first_dmart_order_date                                                                AS dmarts_first_purchase,
    DATE_TRUNC(DATE(pf.peya_first_purchase), MONTH)                                        AS acquisition_since,
    DATE_TRUNC(DATE(pf.peya_first_purchase), MONTH) + INTERVAL 1 MONTH - INTERVAL 1 DAY   AS acquisition_until,
    DATE_TRUNC(DATE(d.first_dmart_order_date), MONTH)                                      AS adoption_since,
    DATE_TRUNC(DATE(d.first_dmart_order_date), MONTH) + INTERVAL 1 MONTH - INTERVAL 1 DAY AS adoption_until
  FROM dmart_adoptions d
  LEFT JOIN peya_first_orders pf
    ON d.customer_id = pf.customer_id
),

-- REFACTOR: monthly_users ahora lee sku_normalized (ya normalizado pre/post-2025)
monthly_users AS (
  SELECT
    DATE_TRUNC(sn.order_date, MONTH) AS month,
    sn.customer_id,
    d.user_id,
    d.country,
    d.peya_first_purchase,
    d.dmarts_first_purchase,
    d.acquisition_since,
    d.acquisition_until,
    d.adoption_since,
    d.adoption_until,
    CASE
      WHEN EXTRACT(YEAR  FROM d.adoption_since) = EXTRACT(YEAR  FROM sn.order_date)
       AND EXTRACT(MONTH FROM d.adoption_since) = EXTRACT(MONTH FROM sn.order_date) THEN 1
      ELSE (EXTRACT(YEAR FROM sn.order_date) - EXTRACT(YEAR FROM d.adoption_since)) * 12
           + EXTRACT(MONTH FROM sn.order_date) - EXTRACT(MONTH FROM d.adoption_since) + 1
    END AS mes_en_curso
  FROM sku_normalized sn
  INNER JOIN data_users d
    ON  sn.customer_id = d.customer_id
    AND sn.country     = d.country
  WHERE sn.state = 'CONFIRMED'
    AND sn.order_date >= '2021-01-01'
  GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
),

cleaned AS (
  SELECT
    *,
    IFNULL(
      mes_en_curso - LAG(mes_en_curso) OVER (PARTITION BY customer_id, country ORDER BY month),
      NULL
    ) AS consecutivo
  FROM monthly_users
)

SELECT
  *,
  CASE
    WHEN mes_en_curso = 1 AND consecutivo IS NULL THEN 'Adoption'
    WHEN mes_en_curso = 2 AND consecutivo = 1     THEN 'M1 Return'
    WHEN mes_en_curso > 2 AND consecutivo = 1     THEN 'Recurring Return'
    WHEN consecutivo > 1                          THEN 'Reactivated'
  END AS Type
FROM cleaned
--ORDER BY customer_id ASC, month ASC
)
