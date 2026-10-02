-- ============================================================
-- DIAGNÓSTICO DE CAMBIOS (latam_dmart_user_data):
-- 1. [LÓGICA]    Bug principal eliminado: el original cruzaba fact_orders.user.id
--               con customer_orders_sku_level.customer_id asumiendo que eran iguales.
--               Ahora customer_id de customer_orders_sku_level es el pivot principal.
-- 2. [LÓGICA]    acquisition_since derivado via dim_user bridge para no generar cartesiano
--               entre fact_orders y customer_orders_sku_level
-- 3. [DUPLICADOS] ANY_VALUE(user_id) para trazabilidad sin duplicar filas
-- 4. [COSTO]     PARTITION BY adoption_since + CLUSTER BY customer_id, country_name
-- 5. [COSTO]     Monthly activity desde customer_orders_sku_level directamente (sin fact_orders)
-- 6. [COSTO]     Filtros tempranos en todas las CTEs base
-- 7. [COSTO]     Columnas explícitas en lugar de SELECT * para reducir shuffle
-- 8. [HISTÓRICO] sku_normalized resuelve el split pre/post-2025 en customer_orders_sku_level:
--               Pre-2025: co.user_id IS NULL → co.customer_id ERA user.id → bridge dim_user
--               Post-2025: co.user_id IS NOT NULL → co.customer_id ya es el ID real
-- ============================================================

CREATE OR REPLACE TABLE `peya-food-and-groceries.automated_tables_reports.latam_dmart_user_data_new`
-- REFACTOR: PARTITION BY + CLUSTER BY
PARTITION BY adoption_since
CLUSTER BY customer_id, country_name
AS (

WITH
-- REFACTOR [HISTÓRICO]: normaliza customer_id para datos pre y post-2025.
--   Pre-2025 (co.user_id IS NULL): co.customer_id contenía user.id → bridge con dim_user.
--   Post-2025 (co.user_id IS NOT NULL): co.customer_id ya es el customer_id real.
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
    dc.country_name AS country_name_es,
    dc.country_name_en as country_name,
    dc.country_id,
  FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` co
  LEFT JOIN `peya-bi-tools-pro.il_core.dim_country` dc
    ON co.country_id = dc.country_id
  -- Solo aplica el bridge para filas pre-2025 donde user_id aún no existía
  LEFT JOIN `peya-bi-tools-pro.il_core.dim_user` du
    ON  co.user_id IS NULL
    AND CAST(co.customer_id AS STRING) = CAST(du.user_id AS STRING)
  WHERE co.order_date >= '2020-04-01'
),

dmart_base AS (
  SELECT
    customer_id,
    ANY_VALUE(user_id) AS user_id,
    country_name,
    country_name_es,
    country_id,
    MIN(order_date)    AS adoption_since_raw
  FROM sku_normalized
  WHERE state = 'CONFIRMED'
  GROUP BY customer_id, country_name, country_name_es, country_id
),

-- REFACTOR: acquisition_since (primera orden Peya) via dim_user bridge
--           Agrega a nivel customer_id antes del JOIN para evitar fan-out
peya_first AS (
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
    d.country_name,
    d.country_id,
    d.country_name_es,
    DATE_TRUNC(d.adoption_since_raw, MONTH)                                               AS adoption_since,
    DATE_TRUNC(d.adoption_since_raw, MONTH) + INTERVAL 1 MONTH - INTERVAL 1 DAY          AS adoption_until,
    d.adoption_since_raw                                                                  AS dmarts_first_purchase,
    p.peya_first_purchase,
    DATE_TRUNC(DATE(p.peya_first_purchase), MONTH)                                        AS acquisition_since,
    DATE_TRUNC(DATE(p.peya_first_purchase), MONTH) + INTERVAL 1 MONTH - INTERVAL 1 DAY   AS acquisition_until
  FROM dmart_base d
  LEFT JOIN peya_first p ON d.customer_id = p.customer_id
),

-- REFACTOR: monthly_users desde customer_orders_sku_level directamente (no desde fact_orders)
--           El original cruzaba customer_orders.customer_id con data_users.id (= user.id) — roto
monthly_users AS (
  SELECT
    months.month,
    d.customer_id,
    d.user_id,
    d.country_name,
    d.country_name_es,
    d.country_id,
    d.adoption_since,
    d.adoption_until,
    d.dmarts_first_purchase,
    d.peya_first_purchase,
    d.acquisition_since,
    d.acquisition_until
  FROM (
    -- REFACTOR [HISTÓRICO]: usa sku_normalized para obtener customer_id correcto pre/post-2025
    SELECT
      DATE_TRUNC(order_date, MONTH) AS month,
      customer_id,
      country_id,
      country_name
    FROM sku_normalized
    WHERE state = 'CONFIRMED'
    GROUP BY 1, 2, 3,4
  ) months
  INNER JOIN data_users d
    ON  months.customer_id  = d.customer_id
    AND months.country_id = d.country_id
  GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,12
  ORDER BY 1 ASC
),

cleaned AS (
  SELECT
    *,
    CASE
      WHEN adoption_since IS NOT NULL
      THEN DATE_DIFF(month, adoption_since, MONTH) + 1
    END AS mes_en_curso
  FROM monthly_users
),

cleaned_2 AS (
  SELECT
    *,
    IFNULL(
      mes_en_curso - LAG(mes_en_curso) OVER (PARTITION BY customer_id, country_name ORDER BY month),
      NULL
    ) AS consecutivo
  FROM cleaned
)

SELECT
  *,
  CASE
    WHEN mes_en_curso = 1 AND consecutivo IS NULL THEN 'Adoption'
    WHEN mes_en_curso = 2 AND consecutivo = 1     THEN 'M1 Return'
    WHEN mes_en_curso > 2 AND consecutivo = 1     THEN 'Recurring Return'
    WHEN consecutivo > 1                          THEN 'Reactivated'
  END AS Type
FROM cleaned_2
)
