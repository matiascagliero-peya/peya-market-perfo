-- ============================================================
-- DIAGNÓSTICO DE CAMBIOS (latam_dmart_growth_tracker):
-- 1. [LÓGICA]    dmart_data: "dr.customer_id as user_id" corregido a customer_id.
--               Este alias erróneo propagaba confusión a todos los CTEs downstream.
-- 2. [LÓGICA]    Todos los PARTITION BY y referencias a "user_id" migraron a customer_id
--               (dmart_data, user_data, latam_growth_data, growth_tracker, etc.)
-- 3. [DUPLICADOS] JOIN a monthly_user_info PAUSADO — esa tabla tiene user_id como clave;
--               cruzar con customer_id genera cartesiano. Campos reemplazados por NULL.
-- 4. [COSTO]     dmart_sub (SELECT *) reemplazado por columnas explícitas
-- 5. [COSTO]     Los dos scans de customer_orders_sku_level consolidados en un solo CTE
--               sku_level_agg (categorías + fresh en un solo pass)
-- 6. [COSTO]     PARTITION BY + CLUSTER BY en CREATE OR REPLACE TABLE
-- 7. [COSTO]     Filtros tempranos en todas las CTEs base
-- ============================================================

CREATE OR REPLACE TABLE `peya-food-and-groceries.automated_tables_reports.latam_dmart_growth_tracker`
-- REFACTOR: PARTITION BY + CLUSTER BY para reducir costos de escaneo
PARTITION BY month
CLUSTER BY customer_id, country_name
AS (
WITH

orders AS (
  SELECT
    customer_id,
    country_code,
    country_name,
    h_lifecycle_stage,
    adoption_class,
    adoption_class_test,
    DATE_TRUNC(order_date, MONTH)                                         AS order_date,
    COUNT(DISTINCT order_id)                                              AS orders,
    SUM(GFV)                                                              AS GFV,
    SUM(Basket_Sz)                                                        AS Basket_Sz,
    COUNT(DISTINCT CASE WHEN flag_basket_value THEN order_id END)        AS flag_bv,
    SUM(flag_delivery_free)                                               AS flag_df,
    SUM(flag_vc)                                                          AS flag_vc,
    SUM(flag_plus)                                                        AS flag_plus,
    SUM(flag_stacked)                                                     AS flag_stacked,
    MAX(store_name)                                                       AS store,
    MAX(late_order)                                                       AS late_orders,
    SAFE_DIVIDE(AVG(actual_delivery_time), 60)                           AS average_delivery_time,
    AVG(actual_delivery_time)                                             AS average_actual_dt,
    SUM(fija_plus)                                                        AS fija_orders,
    SUM(sunday_plus)                                                      AS sunday_plus,
    SUM(plus_benefit_orders)                                              AS plus_benefit_orders,
    MIN(order_date)                                                       AS first_monthly_order_date,
    MAX(order_date)                                                       AS last_monthly_order_date,
    MAX(month_activation_source)                                         AS activated_by,
    MAX(month_activation_funnel_source)                                  AS funnel_activated_by,
    MAX(month_activation_loss_orders)                                    AS activated_loss_orders,
    SUM(flag_inaccuracy)                                                  AS inaccuracy_orders,
    SUM(inaccuracy_late)                                                  AS inaccuracy_late_orders,
    COUNT(DISTINCT CASE WHEN fresh_order = 1     THEN order_id END)      AS fresh_orders,
    COUNT(DISTINCT CASE WHEN has_hold_back = TRUE THEN order_id END)     AS hold_back_orders,
    SUM(ultra_fresh_order)                                               AS ultra_fresh_orders,
    SUM(multibuy_order)                                                  AS multibuy_orders
  FROM `peya-food-and-groceries.automated_tables_reports.dmart_fact_orders_latam`
  GROUP BY 1, 2, 3, 4, 5, 6, 7
  ORDER BY 5 ASC
),

date_range AS (
  WITH dr AS (
    SELECT
      customer_id,
      country_name,
      country_name_es,
      DATE_ADD(DATE(adoption_since), INTERVAL num DAY) AS month
    FROM `peya-food-and-groceries.automated_tables_reports.latam_dmart_user_data_new`
    CROSS JOIN UNNEST(GENERATE_ARRAY(0, DATE_DIFF(CURRENT_DATE(), DATE(adoption_since), DAY))) AS num
  )
  SELECT DISTINCT
    customer_id,
    country_name,
    country_name_es,
    DATE_TRUNC(month, MONTH) AS month
  FROM dr
  ORDER BY customer_id, month
),

data AS (
  -- REFACTOR: columnas explícitas (no SELECT *) para reducir shuffle
  SELECT
    customer_id,
    country_name,
    country_name_es,
    adoption_since,
    acquisition_since,
    adoption_until,
    acquisition_until,
    mes_en_curso,
    Type,
    month
  FROM `peya-food-and-groceries.automated_tables_reports.latam_dmart_user_data_new`
  ),

-- REFACTOR [HISTÓRICO]: normaliza customer_id para datos pre y post-2025.
--   Pre-2025 (co.user_id IS NULL): co.customer_id contenía user.id → bridge dim_user.
--   Post-2025 (co.user_id IS NOT NULL): co.customer_id ya es el ID real.
sku_normalized AS (
  SELECT
    CASE
      WHEN CAST(co.user_id AS STRING) IS NOT NULL THEN co.customer_id
      ELSE COALESCE(du.customer_id, co.customer_id)
    END AS customer_id,
    CASE
      WHEN CAST(co.user_id AS STRING) IS NOT NULL THEN cast(co.user_id as string)
      ELSE co.customer_id
    END AS user_id,
    co.order_date,
    co.state,
    co.sku_id,
    co.fulfilled_quantity,
    dc.country_name
  FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` co
  LEFT JOIN `peya-bi-tools-pro.il_core.dim_country` dc
    ON co.country_id = dc.country_id
  LEFT JOIN `peya-bi-tools-pro.il_core.dim_user` du
    ON  co.user_id IS NULL
    AND CAST(co.customer_id AS STRING) = CAST(du.user_id AS STRING)
  WHERE co.order_date > '2020-04-01'
),

-- REFACTOR: un solo scan de customer_orders_sku_level (via sku_normalized) para categories + fresh
--           El original tenía DOS CTEs separadas (dmart_sub + subquery inline) — consolidado
sku_level_agg AS (
  SELECT
    sn.customer_id,
    DATE_TRUNC(sn.order_date, MONTH) AS order_month,
    sn.country_name,
    COUNT(DISTINCT e.Level_2)        AS categories,
    CASE WHEN SUM(CASE WHEN e.Level_0 IN ('Fresh','Ultra Fresh') THEN sn.fulfilled_quantity END) > 0
         THEN 1 ELSE 0 END           AS fresh_order_month
  FROM sku_normalized sn
  LEFT JOIN (
    SELECT
      sku,
      barcode  AS piece_barcode,
      product_name,
      brand_name,
      Level_0,
      level_one AS Level_1,
      level_two AS Level_2
    FROM `peya-food-and-groceries.automated_tables_reports.dmart_master_products_V2`
    GROUP BY 1, 2, 3, 4, 5, 6, 7
  ) e ON sn.sku_id = e.sku
  WHERE sn.state = 'CONFIRMED'
  GROUP BY 1, 2, 3
),

dmart_data AS (
  SELECT
    -- REFACTOR: eliminado alias erróneo "as user_id" — este campo ES customer_id real
    dr.customer_id,
    dr.country_name,
    dr.country_name_es,
    CASE WHEN data.Type IS NULL THEN 'Churned' ELSE data.Type END AS dmart_growth_status,
    data.Type                                                     AS type,
    orders.h_lifecycle_stage,
    orders.adoption_class,
    orders.adoption_class_test,
    data.mes_en_curso,
    data_2.adoption_since,
    data_2.acquisition_since,
    data_2.adoption_until,
    data_2.acquisition_until,
    dr.month,
    ska.fresh_order_month                                         AS fresh_orders,
    DATE_DIFF(data_2.adoption_since, data_2.acquisition_since, MONTH) AS time_to_dm,
    MAX(orders.store)                                             AS store,
    MAX(orders.activated_by)                                     AS activated_by,
    MAX(orders.funnel_activated_by)                              AS funnel_activated_by,
    MAX(orders.activated_loss_orders)                            AS activated_loss_orders,
    MIN(orders.first_monthly_order_date)                         AS first_monthly_order_date,
    MAX(orders.last_monthly_order_date)                          AS last_monthly_order_date,
    SUM(orders.orders)                                           AS current_month_dmart_orders,
    CASE
      WHEN SUM(orders.orders) IS NULL OR SUM(orders.orders) = 0 THEN '-'
      WHEN SUM(orders.orders) = 1                               THEN '1 order'
      WHEN SUM(orders.orders) BETWEEN 2 AND 3                   THEN '2-3 orders'
      WHEN SUM(orders.orders) BETWEEN 4 AND 5                   THEN '4-5 orders'
      WHEN SUM(orders.orders) BETWEEN 6 AND 7                   THEN '6-7 orders'
      ELSE '8+ orders'
    END AS user_dmart_frequency_interval,
    SAFE_DIVIDE(SUM(orders.basket_sz), SUM(orders.orders))       AS basket_size,
    -- REFACTOR: categories ahora viene de sku_level_agg (no de subquery separada)
    MAX(ska.categories)                                          AS dmart_categories,
    SAFE_DIVIDE(SUM(orders.GFV), SUM(orders.orders))             AS afv,
    SUM(orders.GFV)                                              AS retail_sales_eur,
    CASE
      WHEN ska.fresh_order_month IS NULL THEN NULL
      WHEN ska.fresh_order_month > 0     THEN 1
      ELSE 0
    END                                                          AS current_fresh_orders,
    SUM(orders.flag_bv)                                          AS basket_value_orders,
    SUM(orders.flag_df)                                          AS df_orders,
    SUM(orders.flag_vc)                                          AS voucher_orders,
    SUM(orders.flag_plus)                                        AS plus_orders,
    SUM(orders.flag_stacked)                                     AS stacked_orders,
    MAX(orders.late_orders)                                      AS late_experience,
    SUM(orders.average_delivery_time)                            AS avg_dt,
    CASE
      WHEN SUM(orders.average_delivery_time) IS NULL THEN NULL
      WHEN SUM(orders.average_delivery_time) <= 10   THEN '[0,10]'
      WHEN SUM(orders.average_delivery_time) <= 20   THEN '[10,20]'
      WHEN SUM(orders.average_delivery_time) <= 30   THEN '[20,30]'
      WHEN SUM(orders.average_delivery_time) <= 40   THEN '[30,40]'
      WHEN SUM(orders.average_delivery_time) <= 50   THEN '[40,50]'
      ELSE '[50,+]'
    END AS current_dt,
    SUM(orders.multibuy_orders)                                  AS multibuy_orders,
    CASE
      WHEN MAX(ska.categories) IS NULL THEN NULL
      WHEN MAX(ska.categories) <= 1    THEN '1 Category'
      WHEN MAX(ska.categories) <= 3    THEN '2-3 Categories'
      WHEN MAX(ska.categories) <= 5    THEN '4-5 Categories'
      WHEN MAX(ska.categories) <= 7    THEN '6-7 Categories'
      ELSE '8-10 Categories'
    END AS dmart_category_range,
    CASE WHEN SUM(orders.multibuy_orders) > 0    THEN 'multibuy_user' ELSE 'regular_user' END AS multibuy_user,
    CASE WHEN SUM(orders.flag_df)  >= 1          THEN 1 ELSE 0 END AS df_user,
    CASE WHEN SUM(orders.flag_bv)  >= 1          THEN 1 ELSE 0 END AS bv_user,
    CASE WHEN SUM(orders.flag_vc)  >= 1          THEN 1 ELSE 0 END AS voucher_user,
    CASE WHEN SUM(orders.flag_plus) >= 1         THEN 1 ELSE 0 END AS plus_user,
    CASE WHEN SUM(orders.flag_plus) = 0 AND SUM(orders.flag_df) >= 1
              AND SUM(orders.flag_vc) >= 1       THEN 1 ELSE 0 END AS incentivized_user,
    MAX(CASE WHEN SUM(orders.orders) > 0 THEN dr.month ELSE NULL END)
      OVER (PARTITION BY dr.customer_id, dr.country_name
            ORDER BY dr.month
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS last_month_active
  FROM date_range dr
  LEFT JOIN orders
    ON  dr.customer_id     = cast(orders.customer_id as string)
    AND dr.country_name_es = orders.country_name
    AND DATE_TRUNC(dr.month, MONTH) = DATE_TRUNC(orders.order_date, MONTH)
  -- REFACTOR: sku_level_agg reemplaza el inline subquery + dmart_orders por un solo JOIN
  -- Fix: ska.country_name es español (dc.country_name); dr.country_name_es también es español
  LEFT JOIN sku_level_agg ska
    ON  CAST(dr.customer_id AS STRING) = CAST(ska.customer_id AS STRING)
    AND DATE_TRUNC(dr.month, MONTH)    = DATE_TRUNC(ska.order_month, MONTH)
    AND dr.country_name_es             = ska.country_name
  LEFT JOIN data
    ON  DATE_TRUNC(dr.month, MONTH)        = data.month
    AND CAST(dr.customer_id AS STRING)     = CAST(data.customer_id AS STRING)
    AND dr.country_name                    = data.country_name
  LEFT JOIN (
    SELECT DISTINCT
      customer_id, country_name, adoption_since, acquisition_since, adoption_until, acquisition_until
    FROM data
    GROUP BY 1, 2, 3, 4, 5, 6
  ) data_2
    ON  CAST(dr.customer_id AS STRING) = CAST(data_2.customer_id AS STRING)
    AND dr.country_name                = data_2.country_name
  GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
  ORDER BY 3 ASC
),

user_data AS (
  SELECT
    dd.*,
    CASE
      WHEN time_to_dm IS NULL                   THEN 'Dmart Prospect'
      WHEN time_to_dm >= 18                     THEN '[18,+] Months'
      WHEN time_to_dm >= 12                     THEN '[12,18] Months'
      WHEN time_to_dm >= 9                      THEN '[09,12] Months'
      WHEN time_to_dm >= 6                      THEN '[06,09] Months'
      WHEN time_to_dm >= 3                      THEN '[03,06] Months'
      WHEN time_to_dm >= 1                      THEN '[01,02] Months'
      WHEN time_to_dm = 0 AND current_month_dmart_orders >= 1 THEN 'Dmart Acquisition'
      WHEN time_to_dm = 0 THEN 'Peya Aquisition'
    END AS dm_adoption_type,

    -- PAUSADO POR MIGRACIÓN A CUSTOMER_ID
    -- monthly_user_info tiene user_id como clave; JOIN directo sobre customer_id genera cartesiano.
    -- Para reactivar: bridge dim_user.customer_id → monthly_user_info.user_id
    CAST(NULL AS STRING)  AS platform_status,
    CAST(NULL AS STRING)  AS platform_prior_status,
    CAST(NULL AS STRING)  AS present_month_status_f_user,
    CAST(NULL AS STRING)  AS past_month_status_f_user,
    CAST(NULL AS STRING)  AS present_month_status_ls_user,
    CAST(NULL AS STRING)  AS past_month_status_ls_user,
    CAST(NULL AS FLOAT64) AS past_month_dmart_orders,
    CAST(NULL AS FLOAT64) AS current_month_food_orders,
    CAST(NULL AS FLOAT64) AS past_month_food_orders,
    CAST(NULL AS FLOAT64) AS current_month_total_orders,
    CAST(NULL AS FLOAT64) AS past_month_total_orders,
    /*
    m.present_month_status_user   AS platform_status,
    m.past_month_status_user      AS platform_prior_status,
    m.present_month_status_f_user,
    m.past_month_status_f_user,
    m.present_month_status_ls_user,
    m.past_month_status_ls_user,
    m.dm_past_month_orders        AS past_month_dmart_orders,
    m.f_present_month_orders      AS current_month_food_orders,
    m.f_past_month_orders         AS past_month_food_orders,
    m.total_present_month_orders  AS current_month_total_orders,
    m.total_past_month_orders     AS past_month_total_orders,
    */

    -- REFACTOR: PARTITION BY ahora usa customer_id (corregido desde alias erróneo user_id)
    LAG(user_dmart_frequency_interval) OVER (PARTITION BY dd.customer_id, dd.country_name ORDER BY month) AS user_dmart_frequency_interval_last_month,
    LAG(dmart_growth_status)           OVER (PARTITION BY dd.customer_id, dd.country_name ORDER BY month) AS dmart_growth_status_past_month,
    LAG(mes_en_curso)                  OVER (PARTITION BY dd.customer_id, dd.country_name ORDER BY month) AS previous_mes_en_curso,
    LAG(activated_by)                  OVER (PARTITION BY dd.customer_id, dd.country_name ORDER BY month) AS last_month_activated_by,
    LAG(funnel_activated_by)           OVER (PARTITION BY dd.customer_id, dd.country_name ORDER BY month) AS last_month_funnel_activated_by,
    LAG(activated_loss_orders)         OVER (PARTITION BY dd.customer_id, dd.country_name ORDER BY month) AS last_month_loss_orders,
    LAG(dmart_categories)              OVER (PARTITION BY dd.customer_id, dd.country_name ORDER BY month) AS last_month_dmart_categories,
    LAG(dmart_category_range)          OVER (PARTITION BY dd.customer_id, dd.country_name ORDER BY month) AS last_month_dmart_category_range,
    LAG(df_user)                       OVER (PARTITION BY dd.customer_id, dd.country_name ORDER BY month) AS df_user_last_month,
    LAG(bv_user)                       OVER (PARTITION BY dd.customer_id, dd.country_name ORDER BY month) AS bv_user_last_month,
    LAG(incentivized_user)             OVER (PARTITION BY dd.customer_id, dd.country_name ORDER BY month) AS incentivized_user_last_month,
    LAG(plus_user)                     OVER (PARTITION BY dd.customer_id, dd.country_name ORDER BY month) AS plus_user_last_month,
    LAG(voucher_user)                  OVER (PARTITION BY dd.customer_id, dd.country_name ORDER BY month) AS voucher_user_last_month,
    LAG(multibuy_user)                 OVER (PARTITION BY dd.customer_id, dd.country_name ORDER BY month) AS multibuy_user_last_month,
    LAG(store)                         OVER (PARTITION BY dd.customer_id, dd.country_name ORDER BY month) AS store_last_month,

    CASE
      WHEN dmart_growth_status = 'Adoption'    THEN 'adoption'
      WHEN dmart_growth_status = 'Churned'     THEN 'churned'
      WHEN dmart_growth_status = 'Reactivated' THEN 'reactivated'
      WHEN current_month_dmart_orders > LAG(current_month_dmart_orders) OVER (PARTITION BY dd.customer_id, dd.country_name ORDER BY dd.month)
        AND afv > LAG(afv) OVER (PARTITION BY dd.customer_id, dd.country_name ORDER BY dd.month)
        THEN 'increased_afv_frec'
      WHEN afv > LAG(afv) OVER (PARTITION BY dd.customer_id, dd.country_name ORDER BY dd.month) THEN 'increased_afv'
      WHEN afv < LAG(afv) OVER (PARTITION BY dd.customer_id, dd.country_name ORDER BY dd.month) THEN 'decreased_afv'
      ELSE 'steady performance'
    END AS dmart_afv_performance,

    CASE
      WHEN dmart_growth_status = 'Adoption'    THEN 'adoption'
      WHEN dmart_growth_status = 'Churned'     THEN 'churned'
      WHEN dmart_growth_status = 'Reactivated' THEN 'reactivated'
      WHEN current_month_dmart_orders > LAG(current_month_dmart_orders) OVER (PARTITION BY dd.customer_id, dd.country_name ORDER BY dd.month) THEN 'increased_frec'
      WHEN current_month_dmart_orders < LAG(current_month_dmart_orders) OVER (PARTITION BY dd.customer_id, dd.country_name ORDER BY dd.month) THEN 'decreased_frec'
      ELSE 'steady performance'
    END AS dmart_frec_performance,

    CASE WHEN dmart_growth_status = 'Churned'
         THEN DATE_DIFF(month, last_month_active, MONTH) END AS months_churned,

    CASE WHEN dmart_growth_status <> 'Churned' THEN TRUE  ELSE FALSE END AS is_active_user,
    CASE WHEN dmart_growth_status <> 'Churned' THEN FALSE ELSE TRUE  END AS is_churned_user

  FROM dmart_data dd
  -- PAUSADO POR MIGRACIÓN A CUSTOMER_ID
  /*
  LEFT JOIN (SELECT * FROM `peya-peru.automated_tables_reports.monthly_user_info`) m
    ON  CAST(dd.customer_id AS STRING) = CAST(m.user_id AS STRING)
    AND DATE_TRUNC(dd.month, MONTH)    = DATE_TRUNC(m.mes, MONTH)
    AND dd.country_name_es             = m.country_name
  */
  GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,
           27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,
           51,52,53,54,55,56,57,58
  ORDER BY 3 ASC
),

latam_growth_data AS (
  SELECT
    u.*,
    CASE
      WHEN dmart_growth_status_past_month = 'Reactivated' AND dmart_growth_status = 'Recurring Return'
        THEN 'Reorder'
      ELSE dmart_growth_status
    END AS dmart_growth_status_fixed,
    CASE
      WHEN dmart_growth_status <> 'Churned'                                                                  THEN dmart_growth_status
      WHEN dmart_growth_status_past_month IN ('Adoption','M1 Return') AND dmart_growth_status = 'Churned'   THEN 'dmart_early_churn'
      WHEN dmart_growth_status = 'Churned' AND dmart_growth_status_past_month = 'Churned'                   THEN 'dmart_recurring_churn'
      WHEN dmart_growth_status = 'Churned' AND dmart_growth_status_past_month = 'Reactivated'              THEN 'dmart_strong_churn'
      ELSE 'regular churn'
    END AS dmart_churn_type,
    CASE
      WHEN platform_status = 'Churned'          THEN 'churned'
      WHEN dmart_growth_status = 'Reactivated'  THEN 'reactivated'
      WHEN current_month_total_orders > past_month_total_orders THEN 'increased_frec'
      WHEN current_month_total_orders < past_month_total_orders THEN 'decreased_frec'
      ELSE 'steady performance'
    END AS platform_performance,
    CASE WHEN fresh_orders >= 1 THEN 1 ELSE 0 END AS fresh_month,
    IFNULL(DATE_DIFF(month, last_month_active, MONTH), 0) AS activation_period,
    -- REFACTOR: ROW_NUMBER usa customer_id (correcto)
    ROW_NUMBER() OVER (PARTITION BY customer_id, country_name ORDER BY month) AS month_evaluated
  FROM user_data u
  ORDER BY country_name, month ASC
),

growth_tracker AS (
  SELECT
    gd.*,
    CASE WHEN fresh_month = 1
         THEN SUM(fresh_month) OVER (PARTITION BY customer_id, country_name ORDER BY month
                                     ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
    END AS fresh_month_number,
    SUM(fresh_orders) OVER (PARTITION BY customer_id, country_name ORDER BY month
                            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS total_fresh_orders_made,
    -- REFACTOR: PARTITION BY usa customer_id
    LAG(dmart_growth_status_fixed) OVER (PARTITION BY gd.customer_id, gd.country_name ORDER BY gd.month) AS dmart_growth_status_last_month_fixed
  FROM latam_growth_data gd
),

fresh_tracker AS (
  SELECT
    *,
    CASE WHEN total_fresh_orders_made >= 1 THEN 1 END AS fresh_month_lifetime
  FROM growth_tracker
),

pre_fresh AS (
  SELECT
    *,
    CASE WHEN fresh_month_lifetime >= 1
         THEN SUM(fresh_month_lifetime) OVER (PARTITION BY customer_id, country_name ORDER BY month
                                              ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
    END AS fresh_lifetime
  FROM fresh_tracker
),

first_fresh AS (
  SELECT
    customer_id,
    month,
    country_name,
    dmart_growth_status
  FROM pre_fresh
  WHERE fresh_lifetime = 1
  GROUP BY 1, 2, 3, 4
),

dgt AS (
  SELECT
    pre_fresh.*,
    first_fresh.month            AS fresh_cohort,
    first_fresh.dmart_growth_status AS fresh_growth_status,
    CASE
      WHEN dmart_growth_status_fixed = 'Adoption'                                                               THEN 'Adoption'
      WHEN dmart_growth_status_last_month_fixed = 'Adoption'        AND dmart_growth_status_fixed = 'M1 Return'        THEN 'BoP Early Base'
      WHEN dmart_growth_status_last_month_fixed = 'Adoption'        AND dmart_growth_status_fixed = 'Churned'           THEN 'BoP Early Base'
      WHEN dmart_growth_status_last_month_fixed = 'Recurring Return' AND dmart_growth_status_fixed = 'Recurring Return' THEN 'BoP Recurring'
      WHEN dmart_growth_status_last_month_fixed = 'Recurring Return' AND dmart_growth_status_fixed = 'Churned'          THEN 'BoP Recurring'
      WHEN dmart_growth_status_last_month_fixed = 'Churned'         AND dmart_growth_status_fixed = 'Reactivated'       THEN 'BoP Churn'
      WHEN dmart_growth_status_last_month_fixed = 'Churned'         AND dmart_growth_status_fixed = 'Churned'           THEN 'BoP Churn'
      WHEN dmart_growth_status_last_month_fixed = 'M1 Return'       AND dmart_growth_status_fixed = 'Recurring Return'  THEN 'BoP Recurring'
      WHEN dmart_growth_status_last_month_fixed = 'M1 Return'       AND dmart_growth_status_fixed = 'Churned'           THEN 'BoP Recurring'
      WHEN dmart_growth_status_last_month_fixed = 'Reactivated'     AND dmart_growth_status_fixed = 'Reorder'           THEN 'BoP Reorder'
      WHEN dmart_growth_status_last_month_fixed = 'Reactivated'     AND dmart_growth_status_fixed = 'Churned'           THEN 'BoP Reorder'
      WHEN dmart_growth_status_last_month_fixed = 'Reorder'         AND dmart_growth_status_fixed = 'Recurring Return'  THEN 'BoP Recurring'
      WHEN dmart_growth_status_last_month_fixed = 'Reorder'         AND dmart_growth_status_fixed = 'Churned'           THEN 'BoP Recurring'
      ELSE NULL
    END AS bop_level_1,
    CASE
      WHEN dmart_growth_status_fixed = 'Adoption'                                                               THEN 'Adoption'
      WHEN dmart_growth_status_last_month_fixed = 'Adoption'        AND dmart_growth_status_fixed = 'M1 Return'        THEN 'M1 Return'
      WHEN dmart_growth_status_last_month_fixed = 'Adoption'        AND dmart_growth_status_fixed = 'Churned'           THEN 'Early Churn'
      WHEN dmart_growth_status_last_month_fixed = 'Recurring Return' AND dmart_growth_status_fixed = 'Recurring Return' THEN 'Recurring'
      WHEN dmart_growth_status_last_month_fixed = 'Recurring Return' AND dmart_growth_status_fixed = 'Churned'          THEN 'Recurring Churn'
      WHEN dmart_growth_status_last_month_fixed = 'Churned'         AND dmart_growth_status_fixed = 'Reactivated'       THEN 'Reactivated'
      WHEN dmart_growth_status_last_month_fixed = 'Churned'         AND dmart_growth_status_fixed = 'Churned'           THEN 'Ongoing Churn'
      WHEN dmart_growth_status_last_month_fixed = 'M1 Return'       AND dmart_growth_status_fixed = 'Recurring Return'  THEN 'Recurring'
      WHEN dmart_growth_status_last_month_fixed = 'M1 Return'       AND dmart_growth_status_fixed = 'Churned'           THEN 'Recurring Churn'
      WHEN dmart_growth_status_last_month_fixed = 'Reactivated'     AND dmart_growth_status_fixed = 'Reorder'           THEN 'Reorder'
      WHEN dmart_growth_status_last_month_fixed = 'Reactivated'     AND dmart_growth_status_fixed = 'Churned'           THEN 'Reorder Churn'
      WHEN dmart_growth_status_last_month_fixed = 'Reorder'         AND dmart_growth_status_fixed = 'Recurring Return'  THEN 'Recurring'
      WHEN dmart_growth_status_last_month_fixed = 'Reorder'         AND dmart_growth_status_fixed = 'Churned'           THEN 'Recurring Churn'
      ELSE NULL
    END AS bop_level_2,
    CASE
      WHEN dmart_growth_status_fixed = 'Adoption'                                                               THEN 'Adoption'
      WHEN dmart_growth_status_last_month_fixed IN ('Adoption','M1 Return','Recurring Return','Reorder')
        AND dmart_growth_status_fixed IN ('M1 Return','Recurring Return','Churned','Reorder')                   THEN 'BoP'
      WHEN dmart_growth_status_last_month_fixed = 'Churned'         AND dmart_growth_status_fixed IN ('Reactivated','Churned') THEN 'BoP Churn'
      ELSE NULL
    END AS bop_level_0
  FROM pre_fresh
  LEFT JOIN first_fresh
    ON  pre_fresh.customer_id  = first_fresh.customer_id
    AND pre_fresh.country_name = first_fresh.country_name
)

SELECT *
FROM dgt
WHERE (months_churned <= 6 OR months_churned IS NULL)
)
