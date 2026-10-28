a-- ============================================================
-- DIAGNÓSTICO DE CAMBIOS (dmart_fact_orders_latam):
-- 1. [LÓGICA]    dmart_data: "dr.customer_id as user_id" renombrado a customer_id.
--               Era el alias erróneo que propagaba la confusión a todos los CTEs.
-- 2. [LÓGICA]    latam_dmarts_orders: se invierte la asignación de campos:
--               ANTES → o1.user_id as customer_id / s.customer_id as sku_level_customer_id
--               AHORA → s.customer_id as customer_id / o1.user_id as user_id
-- 3. [LÓGICA]    JOIN a united_users migrado de o1.user_id a s.customer_id (el real)
-- 4. [DUPLICADOS] JOIN a agg_user_lifecycle y user_income PAUSADOS — estas tablas tienen
--               user_id como llave y un JOIN directo sobre customer_id genera cartesiano.
--               Campos reemplazados por NULL con cast de tipo para mantener schema.
-- 5. [DUPLICADOS] JOIN a monthly_user_info en user_data PAUSADO por mismo motivo.
-- 6. [COSTO]     data temp table: SELECT * reemplazado por columnas explícitas
-- 7. [COSTO]     date_range: agrega PARTITION BY order_date en CREATE OR REPLACE final
-- 8. [COSTO]     Filtros de fecha (current_month) ya están aplicados en subqueries base
-- ============================================================

DECLARE current_month DATE DEFAULT "2026-05-01";
--DATE_TRUNC(CURRENT_DATE(), MONTH);

-- REFACTOR: CREATE OR REPLACE TABLE con PARTITION + CLUSTER para producción
-- Descomentar para rebuild completo:
/*
CREATE OR REPLACE TABLE `peya-food-and-groceries.automated_tables_reports.dmart_fact_orders_latam_new`
PARTITION BY order_date
CLUSTER BY country_name, customer_id, order_id
AS (
*/

-- REFACTOR: columnas explícitas en temp table (no SELECT *)
CREATE TEMP TABLE date_range
CLUSTER BY customer_id, country 
--with date_range 
AS (
  WITH dr AS (
    SELECT
      customer_id,
      country,
      
      DATE_ADD(DATE(adoption_since), INTERVAL num DAY) AS month
    FROM `peya-food-and-groceries.automated_tables_reports.latam_first_dmart_order_date_users_new`
    CROSS JOIN UNNEST(GENERATE_ARRAY(0, DATE_DIFF(CURRENT_DATE(), DATE(adoption_since), DAY))) AS num
  )
  SELECT DISTINCT
    customer_id,
    country,
    DATE_TRUNC(month, MONTH) AS month
  FROM dr
);

-- REFACTOR: columnas explícitas; CLUSTER BY customer_id (el campo 'id' no existe en v2)
CREATE TEMP TABLE data
CLUSTER BY country, customer_id 
--data
 AS (
  SELECT
    customer_id,
    user_id,
    country,
    adoption_since,
    acquisition_since,
    adoption_until,
    acquisition_until,
    mes_en_curso,
    Type,
    month
  FROM `peya-food-and-groceries.automated_tables_reports.latam_first_dmart_order_date_users_new`
);

--CREATE OR REPLACE TABLE `peya-food-and-groceries.automated_tables_reports.dmart_fact_orders_latam`
--PARTITION BY order_date
--CLUSTER BY country_name, customer_id, order_id
--AS (
INSERT INTO `peya-food-and-groceries.automated_tables_reports.dmart_fact_orders_latam`
-- Nota: este script se corre desde 2025 en adelante. Para esa era, customer_orders_sku_level
-- ya tiene customer_id correcto y user_id populado → no se necesita sku_normalized bridge.
-- sku_normalized fue removido; se leen las tablas directamente.
WITH
dmart_data AS (
  SELECT
    dr.country,
    -- REFACTOR: eliminado alias erróneo "as user_id" — este campo ES el customer_id real
    dr.customer_id,
    CASE WHEN data.Type IS NULL THEN 'Churned' ELSE data.Type END AS dmart_growth_status,
    data.Type                      AS type,
    data.mes_en_curso,
    data_2.adoption_since,
    data_2.acquisition_since,
    data_2.adoption_until,
    data_2.acquisition_until,
    DATE_TRUNC(dr.month, MONTH)    AS month,
    COUNT(DISTINCT o.order_id)     AS dm_current_frequency,
    SAFE_DIVIDE(SUM(o.fulfilled_quantity), COUNT(DISTINCT o.order_id)) AS basket_size,
    COUNT(DISTINCT o.master_category_parent_english)                   AS categories,
    SAFE_DIVIDE(SUM(o.total_amount_net_with_discount_eur), COUNT(DISTINCT o.order_id)) AS afv
  FROM date_range dr
  LEFT JOIN (
    -- post-2025: customer_id en customer_orders_sku_level ya es el ID real, lectura directa
    SELECT
      co.customer_id,
      co.order_id,
      co.order_date,
      co.order_status,
      co.fulfilled_quantity,
      co.total_amount_net_with_discount_eur,
      co.master_category_parent_english,
      co.country_name  -- campo nativo de la tabla (nombre en español), coincide con dr.country
    FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` co
    WHERE co.order_status = 'sent'
      AND co.order_date > '2020-04-01'
  ) o
    ON  CAST(dr.customer_id AS STRING) = CAST(o.customer_id  AS STRING)
    AND DATE_TRUNC(dr.month, MONTH)    = DATE_TRUNC(o.order_date, MONTH)
    AND dr.country                     = o.country_name  -- Fix: alias correcto (no country_name_es)
  LEFT JOIN data
    ON  DATE_TRUNC(dr.month, MONTH)        = data.month
    AND CAST(dr.customer_id AS STRING)     = CAST(data.customer_id AS STRING)  -- REFACTOR: data.id → data.customer_id
    AND dr.country                         = data.country
  LEFT JOIN (
    SELECT DISTINCT
      customer_id,     -- REFACTOR: id → customer_id
      country,
      adoption_since,
      acquisition_since,
      adoption_until,
      acquisition_until
    FROM data
  ) data_2
    ON  CAST(dr.customer_id AS STRING) = CAST(data_2.customer_id AS STRING)  -- REFACTOR: data_2.id → data_2.customer_id
    AND dr.country                     = data_2.country
  GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
  ORDER BY 3 ASC
),

user_data AS (
  SELECT
    dd.*,
    -- PAUSADO POR MIGRACIÓN A CUSTOMER_ID
    -- monthly_user_info solo tiene user_id; JOIN directo sobre customer_id generaría cartesiano.
    -- Reactivar usando bridge: dim_user.customer_id → monthly_user_info.user_id
    CAST(NULL AS STRING)  AS platform_status,
    CAST(NULL AS STRING)  AS platform_prior_status,
    /*
    m.present_month_status_user AS platform_status,
    m.past_month_status_user    AS platform_prior_status,
    */
    -- REFACTOR: PARTITION BY ahora usa customer_id (corregido desde el alias erróneo user_id)
    LAG(dmart_growth_status) OVER (PARTITION BY dd.country, dd.customer_id ORDER BY month)  AS dmart_growth_status_past_month,
    LAG(mes_en_curso)        OVER (PARTITION BY dd.country, dd.customer_id ORDER BY month)  AS previous_mes_en_curso,
    CASE
      WHEN dmart_growth_status = 'Adoption'   THEN 'adoption'
      WHEN dmart_growth_status = 'Churned'    THEN 'churned'
      WHEN dmart_growth_status = 'Reactivated' THEN 'reactivated'
      WHEN dm_current_frequency > LAG(dm_current_frequency) OVER (PARTITION BY dd.country, dd.customer_id ORDER BY dd.month)
        AND afv > LAG(afv) OVER (PARTITION BY dd.country, dd.customer_id ORDER BY dd.month)
        THEN 'increased_afv_frec'
      WHEN afv > LAG(afv) OVER (PARTITION BY dd.country, dd.customer_id ORDER BY dd.month)
        THEN 'increased_afv'
      WHEN afv < LAG(afv) OVER (PARTITION BY dd.country, dd.customer_id ORDER BY dd.month)
        THEN 'decreased_afv'
      ELSE 'steady performance'
    END AS dmart_afv_performance,
    CASE
      WHEN dmart_growth_status = 'Adoption'   THEN 'adoption'
      WHEN dmart_growth_status = 'Churned'    THEN 'churned'
      WHEN dmart_growth_status = 'Reactivated' THEN 'reactivated'
      WHEN dm_current_frequency > LAG(dm_current_frequency) OVER (PARTITION BY dd.country, dd.customer_id ORDER BY dd.month)
        THEN 'increased_frec'
      WHEN dm_current_frequency < LAG(dm_current_frequency) OVER (PARTITION BY dd.country, dd.customer_id ORDER BY dd.month)
        THEN 'decreased_frec'
      ELSE 'steady performance'
    END AS dmart_frec_performance,
    -- PAUSADO POR MIGRACIÓN A CUSTOMER_ID
    CAST(NULL AS FLOAT64) AS dm_prior_frequency,
    CAST(NULL AS FLOAT64) AS platform_current_frequency,
    CAST(NULL AS FLOAT64) AS platform_prior_frequency,
    CAST(NULL AS FLOAT64) AS ls_current_frequency,
    CAST(NULL AS FLOAT64) AS ls_prior_frequency,
    /*
    SUM(dm_past_month_orders)                                                                    AS dm_prior_frequency,
    SUM(f_present_month_orders)+SUM(ls_present_month_orders)+SUM(c_present_month_orders)        AS platform_current_frequency,
    SUM(f_past_month_orders)+SUM(ls_past_month_orders)+SUM(c_past_month_orders)                 AS platform_prior_frequency,
    SUM(ls_present_month_orders)+SUM(c_present_month_orders)                                    AS ls_current_frequency,
    SUM(ls_past_month_orders)+SUM(c_past_month_orders)                                          AS ls_prior_frequency,
    */
    MAX(CASE WHEN dm_current_frequency > 0 THEN month ELSE NULL END)
      OVER (PARTITION BY dd.country, dd.customer_id ORDER BY month
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS last_month_active
  FROM dmart_data dd
  -- PAUSADO POR MIGRACIÓN A CUSTOMER_ID
  -- monthly_user_info tiene user_id como clave; cruzar con customer_id produce cartesiano.
  -- Para reactivar: unir via dim_user → monthly_user_info.user_id
  /*
  LEFT JOIN (
    SELECT * FROM `peya-peru.automated_tables_reports.monthly_user_info`
  ) m
    ON  CAST(dd.customer_id AS STRING) = CAST(m.user_id AS STRING)
    AND DATE_TRUNC(dd.month, MONTH)    = DATE_TRUNC(m.mes, MONTH)
    AND m.country_name                 = dd.country
  */
  GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16
  ORDER BY 3 ASC
),

united_users AS (
  SELECT
    u.*,
    CASE
      WHEN dmart_growth_status_past_month = 'Reactivated' AND dmart_growth_status = 'Recurring Return'
        THEN 'Reorder'
      ELSE dmart_growth_status
    END AS dmart_growth_status_fixed,
    CASE
      WHEN dmart_growth_status <> 'Churned'                                                           THEN dmart_growth_status
      WHEN dmart_growth_status_past_month IN ('Adoption','M1 Return') AND dmart_growth_status = 'Churned' THEN 'dmart_early_churn'
      WHEN dmart_growth_status = 'Churned' AND dmart_growth_status_past_month = 'Churned'             THEN 'dmart_recurring_churn'
      WHEN dmart_growth_status = 'Churned' AND dmart_growth_status_past_month = 'Reactivated'        THEN 'dmart_strong_churn'
      ELSE 'regular churn'
    END AS dmart_churn_type,
    CASE
      WHEN platform_status = 'Churned'         THEN 'churned'
      WHEN dmart_growth_status = 'Reactivated' THEN 'reactivated'
      WHEN platform_current_frequency > platform_prior_frequency THEN 'increased_frec'
      WHEN platform_current_frequency < platform_prior_frequency THEN 'decreased_frec'
      ELSE 'steady performance'
    END AS platform_performance,
    IFNULL(DATE_DIFF(month, last_month_active, MONTH), 0) AS activation_period
  FROM user_data u
  ORDER BY month ASC
),

fact_logistic_orders AS (
  SELECT DISTINCT
    UPPER(ord.country_code)                                                                         AS country,
    ord.city.city_name                                                                              AS city,
    ord.zone.zone_name                                                                              AS zone,
    EXTRACT(YEAR    FROM DATETIME(ord.created_at, ord.timezone))                                   AS year,
    EXTRACT(ISOWEEK FROM DATETIME(ord.created_at, ord.timezone))                                   AS week,
    EXTRACT(MONTH   FROM DATETIME(ord.created_at, ord.timezone))                                   AS month,
    ord.created_date_local                                                                          AS Fecha,
    EXTRACT(DAYOFWEEK FROM DATE_SUB(DATE(ord.created_at, ord.timezone), INTERVAL 1 DAY))          AS day_of_week,
    EXTRACT(HOUR FROM DATETIME(ord.created_at, ord.timezone))                                      AS hour,
    CASE
      WHEN EXTRACT(HOUR FROM DATETIME(ord.created_at, ord.timezone)) IN (12,13,14) THEN 'lunch'
      WHEN EXTRACT(HOUR FROM DATETIME(ord.created_at, ord.timezone)) IN (19,20,21,22) THEN 'dinner'
      ELSE 'off_pick'
    END                                                                                            AS day_bucket,
    pr.business_type.business_type_name                                                            AS vertical,
    ord.peya_partner_id                                                                            AS partner_id,
    ord.vendor.name                                                                                AS partner_name,
    ord.peya_order_id                                                                              AS order_id,
    ord.order_status,
    d.delivery_status,
    CASE WHEN ord.is_preorder = TRUE  THEN 'Pre_order'   ELSE 'Not_preorder' END                  AS Is_Preorder,
    CASE WHEN d.stacked_deliveries > 0 THEN 'Stacked'    ELSE 'Non_stacked'  END                  AS stacked_orders,
    CASE
      WHEN d.stacked_deliveries = 0 THEN '0 Stacking'
      WHEN d.stacked_deliveries = 1 THEN '1 Stacking'
      WHEN d.stacked_deliveries = 2 THEN '2 Stacking'
      WHEN d.stacked_deliveries = 3 THEN '3 Stacking'
      ELSE '+4 Stacking'
    END                                                                                            AS Stacking,
    CASE WHEN ord.cod_collect_at_dropoff > 0 THEN 'Yes' ELSE 'No' END                             AS cash_orders,
    d.dropoff_distance_manhattan,
    d.pickup_distance_manhattan,
    ord.timings.promised_delivery_time,
    ord.timings.actual_delivery_time,
    to_dispatch_time,
    ord.timings.dispatching_time,
    ord.timings.rider_reaction_time,
    ord.timings.to_vendor_time,
    ord.timings.at_vendor_time,
    ord.timings.to_customer_time,
    ord.timings.hold_back_time,
    ord.timings.vendor_reaction_time,
    ord.timings.rider_late                                                                         AS rider_late_time,
    ord.timings.at_customer_time,
    ord.timings.order_delay,
    u.user.id                                                                                      AS user_id,
    CASE
      WHEN DATETIME_DIFF(d.rider_picked_up_at_local, ord.original_scheduled_pickup_at_local, SECOND) > 0
       AND ord.timings.rider_late <= 600
        THEN DATETIME_DIFF(ord.original_scheduled_pickup_at_local, ord.vendor_accepted_at_local, SECOND)
      ELSE DATETIME_DIFF(d.rider_picked_up_at_local, ord.vendor_accepted_at_local, SECOND)
    END AS EPTfinal,
    CASE
      WHEN DATETIME_DIFF(d.rider_picked_up_at_local, ord.original_scheduled_pickup_at_local, SECOND) > 0
       AND ord.timings.rider_late <= 600
        THEN DATETIME_DIFF(d.rider_picked_up_at_local, ord.original_scheduled_pickup_at_local, SECOND)
      ELSE 0
    END AS AVTcfinal
  FROM `peya-bi-tools-pro.il_logistics.fact_logistic_orders` ord
  , UNNEST(ord.deliveries) d
  LEFT JOIN `peya-bi-tools-pro.il_core.dim_partner` pr
    ON pr.partner_id = ord.peya_partner_id
  LEFT JOIN `peya-bi-tools-pro.il_core.fact_orders` u
    ON ord.peya_order_id = u.order_id
  WHERE d.is_primary
    AND ord.zone.zone_name IS NOT NULL
    AND d.delivery_status  = 'completed'
    AND ord.created_date_local >= current_month
    AND ord.is_preorder    = FALSE
    AND u.registered_date  >= current_month
    AND pr.is_darkstore IS TRUE
  ORDER BY ord.created_date_local DESC
),

latam_dmarts_orders AS (
  SELECT
    -- basics
    s.order_date,
    s.order_timestamp,
    EXTRACT(HOUR FROM s.order_timestamp)           AS hour,
    DATE_TRUNC(s.order_date, YEAR)                 AS year,
    DATE_TRUNC(s.order_date, MONTH)                AS month,
    FORMAT_DATE('%U', DATE_TRUNC(s.order_date, WEEK(MONDAY))) AS week_of_year,
    s.country_name,
    s.country_code,
    s.store_name,
    s.vendor_id,
    -- REFACTOR: customer_id ahora es s.customer_id (el real de customer_orders_sku_level)
    --           ANTES: o1.user_id as customer_id  (era fact_orders.user.id — incorrecto)
    s.customer_id                                  AS customer_id,
    -- REFACTOR: user_id para trazabilidad — ANTES era s.customer_id as sku_level_customer_id
    o1.user_id                                     AS user_id,

    -- dmart adoption/acquisition state
    CASE WHEN s.order_date >= adoption_since AND s.order_date <= adoption_until
         THEN 'adoption' ELSE 'active' END         AS adoption_type,
    CASE WHEN s.order_date >= acquisition_since AND s.order_date <= acquisition_until
         THEN 'acquisition' ELSE 'active' END      AS acquisition_type,

    -- dmart growth information
    adoption_since                                 AS cohort_date,
    mes_en_curso,
    d.type                                         AS type_user,
    d.platform_performance,
    d.platform_status,
    d.platform_prior_status,
    d.dmart_churn_type_prior_month,
    dmart_frec_performance,
    dmart_afv_performance,
    dmart_growth_status_past_month,
    dmart_growth_status,
    dmart_growth_status_fixed                      AS dmart_growth_stage,
    d.last_month_active                            AS dmart_last_month_active,
    d.activation_period                            AS dmart_activation_period,

    -- complaints data
    comp.ccr1                                      AS comp_ccr1,
    comp.ccr2                                      AS comp_ccr2,
    comp.ccr3                                      AS comp_ccr3,
    comp.user_fraud                                AS comp_user_fraud,
    comp.case_origin                               AS comp_case_origin,

    -- discounts by peya
    db.descuento                                   AS d_descuento,
    db.aporte_peya                                 AS d_aporte_peya,
    db.aporte_banco                                AS d_aporte_banco,
    db.aporte_partner                              AS d_aporte_partner,
    db.inv_peya_en_lcy                             AS d_inv_peya,
    db.inv_bancos_en_lcy                           AS d_inv_bancos,
    db.inv_partner_en_lcy                          AS d_inv_partner,
    CASE WHEN db.descuento = 'Plus en PedidosYa Market' THEN 1 ELSE 0 END AS sunday_plus,
    CASE WHEN db.descuento LIKE '%%Fija%%'             THEN 1 ELSE 0 END AS fija_plus,
    CASE WHEN db.descuento LIKE '%%Plus%%'             THEN 1 ELSE 0 END AS plus_benefit_orders,

    -- user general metadata
    -- PAUSADO POR MIGRACIÓN A CUSTOMER_ID
    -- agg_user_lifecycle y user_income tienen user_id como llave.
    -- Un JOIN directo sobre customer_id genera cartesiano.
    -- Para reactivar: usar bridge dim_user.customer_id → agg_user_lifecycle.user_id
    CAST(NULL AS STRING)  AS health_status,
    CAST(NULL AS STRING)  AS h_int_type,
    CAST(NULL AS STRING)  AS h_funnel,
    CAST(NULL AS STRING)  AS h_lifecycle_stage,
    CAST(NULL AS INT64)   AS u_age,
    CAST(NULL AS STRING)  AS u_cell_segment,
    CAST(NULL AS STRING)  AS u_income,
    CAST(NULL AS STRING)  AS u_segmemnt,
    CAST(NULL AS STRING)  AS u_user_demographic_group,
    /*
    h.health_status,
    h.intermittency_type  AS h_int_type,
    h.funnel              AS h_funnel,
    h.lifecycle_stage     AS h_lifecycle_stage,
    u.age                 AS u_age,
    u.cell_segment        AS u_cell_segment,
    u.income              AS u_income,
    u.segment             AS u_segmemnt,
    u.user_demographic_group AS u_user_demographic_group,
    */

    -- order_id
    s.order_id,

    -- payments
    pay.bank,
    pay.operation_type,
    pay.payment_name,

    -- delivery time
    fo.promised_delivery_time,
    fo.actual_delivery_time,
    CASE WHEN fo.actual_delivery_time > (fo.promised_delivery_time + 60) THEN 1 ELSE 0 END AS late_order,
    fo.dropoff_distance_manhattan AS fo_dropoff_distance_manhattan,

    -- delivery revenue
    o1.delivery_fee_revenue,
    o1.total_amount,
    o1.shipping_amount,
    o1.shipping_amount_no_discount,
    o1.shipping_amount_visualized,
    o1.maxMinutes,
    o1.minMinutes,
    v.Business                                     AS Coupon_Business,
    v.Acq_CRM                                      AS Coupon_Acq_CRM,
    CASE
      WHEN o1.plus_order > 0                THEN 'Plus'
      WHEN vouchers.coupon_used_amount >= 0 THEN v.Type
      ELSE 'Organic'
    END                                            AS Coupon_Type,
    v.Segment                                      AS Coupon_Segment,
    v.Nivel                                        AS Coupon_Nivel,
    v.Funnel                                       AS Coupon_Funnel,
    v.Purpose                                      AS Coupon_Purpose,
    v.Campaign                                     AS Coupon_Campaign,
    v.Campaign_id                                  AS Coupon_Campaign_id,
    v.CRM_Vertical,
    v.CRM_Lifecycle,
    min_amount                                     AS Coupon_min_amount,
    b.discount_amount                              AS Coupon_discount_amount,
    b.max_discount_type                            AS Coupon_discount_type,
    b.max_amount                                   AS Coupon_max_amount,
    b.voucher_copy                                 AS Coupon_voucher_copy,
    b.Campaign                                     AS Coupon_Campaign_Barter,
    b.cupon_value                                  AS Coupon_Value_Barter,
    CASE
      WHEN o1.plus_order > 0                THEN 'Plus'
      WHEN vouchers.coupon_used_amount >= 0 THEN b.type
      ELSE 'Organic'
    END                                            AS coupon_type_barter,
    CASE
      WHEN o1.plus_order > 0                         THEN 'Plus'
      WHEN v.CRM_Vertical = 'DMART'                  THEN 'Dmart RMO'
      WHEN vouchers.coupon_used_amount >= 0 AND v.Type IS NULL  THEN 'Other Vouchers'
      WHEN vouchers.coupon_used_amount >= 0 AND v.Type IS NOT NULL THEN v.Type
      ELSE 'Organic'
    END                                            AS order_source,

    -- DPS
    dps.to_customer_time                           AS DPS_to_customer_time,
    dps.to_vendor_time                             AS DPS_to_vendor_time,
    dps.delivery_distance                          AS DPS_delivery_distance,
    dps.delivery_distance_m                        AS DPS_delivery_distance_meters,
    dps.dropoff_distance_manhattan_m               AS DPS_dropoff_distance_manhattan_meters,
    dps.pickup_distance_manhattan_m                AS DPS_pickup_distance_manhattan_meters,
    dps.actual_delivery_time                       AS DPS_actual_dt,
    dps.order_delay_mins                           AS DPS_order_delay_mins,
    dps.travel_time                                AS DPS_travel_time,
    scheme_id                                      AS DPS_scheme_id,
    dps_minimum_order_value_local                  AS DPS_mov_lc,
    dps_delivery_fee_local                         AS DPS_df_applied,
    dps.dps_basket_value_fee_next_threshold        AS DPS_basket_value,
    dps.is_df_discount_basket_value_deal           AS flag_basket_value,
    shop.mission_type,

    CASE WHEN fo.stacked_orders = 'Stacked' THEN 1 ELSE 0 END  AS flag_stacked,
    CASE WHEN o1.plus_order > 0             THEN 1 ELSE 0 END  AS flag_plus,
    CASE WHEN o1.plus_order > 0 THEN 'PeYa Plus Order' ELSE 'Regular Order' END AS peyaplus,
    vouchers.coupon_used_amount / 1.18                          AS voucher_amount_net,
    CASE WHEN vouchers.coupon_used_amount >= 0 THEN 1 ELSE 0 END AS flag_vc,
    CASE WHEN o1.delivery_fee_revenue > 0.5 THEN 'Inc. Delivery Fee' ELSE 'No Inc. DF' END AS flag_df,
    CASE WHEN vouchers.coupon_used_amount >= 0 THEN 'Voucher' ELSE 'No Voucher' END AS flag_voucher,
    CASE WHEN o1.delivery_fee_revenue > 0.5  THEN 0 ELSE 1 END AS flag_delivery_free,
    CASE WHEN vouchers.coupon_used_amount >= 0
      THEN (CASE WHEN o1.delivery_fee_revenue <= 0.5 THEN 'Voucher & Free Delivery' ELSE 'Voucher' END)
      ELSE (CASE WHEN o1.delivery_fee_revenue <= 0.5 THEN 'Free Delivery' ELSE 'Organic Order' END)
    END                                                         AS order_sub_nature,
    -- REFACTOR: PARTITION BY usa s.customer_id (el real) — ya estaba correcto en el original
    ROW_NUMBER() OVER (PARTITION BY s.customer_id ORDER BY s.order_timestamp ASC)                               AS order_number,
    ROW_NUMBER() OVER (PARTITION BY s.customer_id, DATE_TRUNC(s.order_date, MONTH) ORDER BY s.order_timestamp) AS order_num_month,

    SUM(s.venta_neta)                              AS GFV,
    SUM(s.venta)                                   AS GMV,
    SUM(s.cost)                                    AS Cost,
    SUM(s.venta) - SUM(s.cost)                     AS Theoric_Margin,
    SUM(s.venta_neta) - SUM(s.cost)                AS Front_Margin,
    SUM(s.discount)                                AS Discounts,
    SUM(s.fulfilled)                               AS Basket_Sz,
    COUNT(DISTINCT s.Level_2)                      AS Categories,
    CASE
      WHEN SUM(s.fulfilled) > 19              THEN 'Outliers'
      WHEN SUM(s.fulfilled) >= 15             THEN 'Supermarket Family Size'
      WHEN SUM(s.fulfilled) >= 7              THEN 'Supermarket Orders'
      WHEN SUM(s.fulfilled) >= 5              THEN 'Healthy Convenience'
      WHEN SUM(s.fulfilled) >= 3              THEN 'Convenience Orders'
      WHEN SUM(s.fulfilled) >= 1              THEN 'Impulse Orders'
      ELSE 'Invalid Basket Size'
    END                                            AS Basket_Segment,
    CASE
      WHEN SUM(s.venta) >= 99 THEN '[99,+]'
      WHEN SUM(s.venta) >= 90 THEN '[90,99]'
      WHEN SUM(s.venta) >= 80 THEN '[80,89]'
      WHEN SUM(s.venta) >= 70 THEN '[70,79]'
      WHEN SUM(s.venta) >= 60 THEN '[60,69]'
      WHEN SUM(s.venta) >= 50 THEN '[50,59]'
      WHEN SUM(s.venta) >= 40 THEN '[40,49]'
      WHEN SUM(s.venta) >= 30 THEN '[30,39]'
      WHEN SUM(s.venta) >= 20 THEN '[20,29]'
      WHEN SUM(s.venta) >= 10 THEN '[10,19]'
      ELSE '[00,09]'
    END                                            AS AFV_Segment,
    CASE WHEN SUM(CASE WHEN s.Level_0 IN ('Fresh','Ultra Fresh') THEN s.fulfilled END) > 0 THEN 1 ELSE 0 END AS fresh_order,
    CASE WHEN SUM(CASE WHEN s.Level_0 = 'Ultra Fresh'            THEN s.fulfilled END) > 0 THEN 1 ELSE 0 END AS ultra_fresh_order,
    CASE WHEN SUM(s.discount) > 0                                            THEN 1 ELSE 0 END AS discount_order,
    CASE WHEN MAX(s.discount_rate) >= 0.25                                   THEN 1 ELSE 0 END AS discount_incentivized,
    CASE WHEN SAFE_DIVIDE(SUM(s.discount), SUM(s.venta)) < 0.17             THEN 1 ELSE 0 END AS low_discounts,
    CASE WHEN SAFE_DIVIDE(SUM(s.discount), SUM(s.venta)) >= 0.17
          AND SAFE_DIVIDE(SUM(s.discount), SUM(s.venta)) < 0.3              THEN 1 ELSE 0 END AS moderate_discounts,
    CASE WHEN SAFE_DIVIDE(SUM(s.discount), SUM(s.venta)) >= 0.3             THEN 1 ELSE 0 END AS high_discounts,
    CASE WHEN MIN(s.paid_unit_price_eur) <= 0.1                              THEN 1 ELSE 0 END AS flash_deal,
    CASE WHEN SUM(CASE WHEN s.target_audience = 'SUBSCRIBED_USER' THEN s.fulfilled END) > 0 THEN 1 ELSE 0 END AS plus_discount,
    CASE WHEN SUM(CASE WHEN s.target_audience = 'SEGMENT_USER'    THEN s.fulfilled END) > 0 THEN 1 ELSE 0 END AS ild_discount,
    CASE WHEN SUM(CASE WHEN s.pcm_discount_subtype = 'multi-buy'  THEN s.fulfilled END) > 0 THEN 1 ELSE 0 END AS multibuy_order,
    CASE WHEN SUM(fo.hold_back_time) > 0 THEN TRUE ELSE FALSE END AS has_hold_back,
    SUM(fo.hold_back_time) AS hold_back_time

  FROM (
    -- REFACTOR [HISTÓRICO]: usa sku_normalized — customer_id correcto para pre y post-2025
    --           La taxonomía PIM (Level_0-4) se sigue uniendo aquí ya que es independiente del ID
    SELECT
      o.store_name,
      o.vendor_id,
      o.order_date,
      o.order_timestamp,
      o.customer_id,
      o.order_id,
      o.sku_id,
      o.country_code,
      o.country_name,
      o.pcm_discount_subtype,
      o.target_audience,
      e.Level_0,
      e.Level_1,
      e.Level_2,
      e.Level_3,
      e.Level_4,
      e.product_name,
      SUM(o.listed_unit_price_eur)                                                              AS listed_unit_price_eur,
      SUM(o.ordered_quantity)                                                                   AS ordered,
      SUM(o.fulfilled_quantity)                                                                 AS fulfilled,
      SUM(o.total_amount_sold_net_eur)                                                         AS venta,
      SUM(o.total_amount_net_with_discount_eur)                                                AS venta_neta,
      SUM(o.total_cogs_sold_net_eur)                                                           AS cost,
      SUM(o.pcm_discount_amount_net_eur)                                                       AS discount,
      SAFE_DIVIDE(SUM(o.total_amount_net_with_discount_eur) + SUM(o.vat_amount_eur),
                  SUM(o.fulfilled_quantity))                                                   AS paid_unit_price_eur,
      SAFE_DIVIDE(SUM(o.pcm_discount_amount_net_eur), SUM(o.total_amount_sold_net_eur))       AS discount_rate
    FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` o
    LEFT JOIN (
      SELECT DISTINCT
        sku,
        piece_barcode,
        P.Level_0,
        k.Level_1,
        k.Level_2,
        k.Level_3,
        k.Level_4,
        k.country_code,
        k.title as product_name,
      FROM `peya-food-and-groceries.automated_tables_reports.skus_PIM_Dmart` k
      LEFT JOIN `peya-argentina.automated_tables_reports.PIM_Level_0_Bis` P
        ON p.Level_1 = k.Level_1
    ) e ON o.sku_id = e.sku
    -- REFACTOR: filtro temprano
    WHERE o.order_date >= '2021-01-01'
      AND o.state = 'CONFIRMED'
    GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17
  ) AS s

  -- join para delivery fee
  LEFT JOIN (
    SELECT
      CAST(o.order_id AS STRING)              AS order_id,
      o.user.id                               AS user_id,
      o.promisedDeliveryTime.maxMinutes,
      o.promisedDeliveryTime.minMinutes,
      delivery_fee_revenue,
      shipping_amount_no_discount / 1.18      AS shipping_amount_no_discount,
      shipping_amount_no_discount             AS shipping_amount_visualized,
      shipping_amount,
      is_user_plus                            AS plus_order,
      o.total_amount
    FROM `peya-bi-tools-pro.il_core.fact_orders` o
    -- REFACTOR: filtro temprano
    WHERE o.registered_date >= current_month
  ) o1 ON s.order_id = o1.order_id

  -- join vouchers
  LEFT JOIN `peya-bi-tools-pro.il_growth.fact_talon_coupons` AS vouchers
    ON CAST(s.order_id AS STRING) = CAST(vouchers.order_id AS STRING)

  -- PAUSADO POR MIGRACIÓN A CUSTOMER_ID
  -- agg_user_lifecycle y user_income tienen user_id como llave.
  -- JOIN directo sobre customer_id (nuevo) genera cartesiano 1:N.
  -- Para reactivar: bridge dim_user.customer_id → h.user_id
  /*
  LEFT JOIN `peya-bi-tools-pro.il_growth.agg_user_lifecycle` h
    ON CAST(s.customer_id AS STRING) = CAST(h.user_id AS STRING)
  LEFT JOIN `peya-bi-tools-pro.il_growth.user_income` u
    ON CAST(s.customer_id AS STRING) = CAST(u.user_id AS STRING)
  */

  -- join tipo de pago
  LEFT JOIN (
    SELECT
      order_id,
      STRING_AGG(DISTINCT IFNULL(issuer,              ''), ', ') AS bank,
      STRING_AGG(DISTINCT IFNULL(card_operation_type, ''), ', ') AS operation_type,
      STRING_AGG(DISTINCT IFNULL(provider,            ''), ', ') AS payment_name
    FROM `peya-bi-tools-pro.il_payments.fact_payments_transaction`
    WHERE payment_state = 'ACCEPTED'
      AND DATE(date_created) >= current_month
    GROUP BY 1
  ) pay ON CAST(pay.order_id AS STRING) = CAST(s.order_id AS STRING)

  -- join vouchers ejecutados
  LEFT JOIN `peya-food-and-groceries.automated_tables_reports.latam_dim_coupon_crm_attributes` v
    ON CAST(v.order_id AS STRING) = s.order_id

  -- join DPS
  LEFT JOIN (
    SELECT * FROM `peya-data-origins-pro.cl_hurrier.dps_sessions_mapped_to_orders`
    -- REFACTOR: filtro temprano
    WHERE created_date >= current_month
  ) dps ON CAST(s.order_id AS STRING) = CAST(dps.platform_order_code AS STRING)

  -- join growth data
  -- REFACTOR: JOIN ahora en s.customer_id (real) vs d.customer_id
  --           ANTES: o1.user_id = d.user_id  (user_id era en realidad customer_id erróneo)
  LEFT JOIN (
    SELECT
      *,
      LAG(dmart_churn_type) OVER (PARTITION BY country, customer_id ORDER BY month) AS dmart_churn_type_prior_month
    FROM united_users
  ) d
    ON  CAST(s.customer_id AS STRING) = CAST(d.customer_id AS STRING)  -- REFACTOR: clave correcta
    AND DATETIME_TRUNC(s.order_date, MONTH) = d.month
    AND s.country_name = d.country

  LEFT JOIN `peya-food-and-groceries.automated_tables_reports.latam_discounts_bines` db
    ON CAST(s.order_id AS STRING) = CAST(db.order_id AS STRING)

  LEFT JOIN `peya-peru.automated_tables_reports.dim_barter_created_latam` b
    ON CAST(s.order_id AS STRING) = CAST(b.order_id AS STRING)

  LEFT JOIN (
    SELECT
      order_number,
      du.customer_id,
      user_fraud,
      STRING_AGG(DISTINCT IFNULL(ccr1,        ''), ', ') AS ccr1,
      STRING_AGG(DISTINCT IFNULL(ccr2,        ''), ', ') AS ccr2,
      STRING_AGG(DISTINCT IFNULL(ccr3,        ''), ', ') AS ccr3,
      STRING_AGG(DISTINCT IFNULL(case_origin, ''), ', ') AS case_origin,
      SUM(amount),
      SUM(euros),
      COUNT(DISTINCT order_number) AS cases
    FROM `peya-delivery-and-support.automated_tables_reports.dmarts_customer_compliant` cc
    left join `peya-bi-tools-pro.il_core.dim_user` du
    ON cc.customer_id = du.user_id
    -- REFACTOR: filtro temprano
    WHERE order_date >= current_month
    GROUP BY 1, 2, 3
  ) comp ON CAST(s.order_id AS STRING) = CAST(comp.order_number AS STRING)

  LEFT JOIN fact_logistic_orders fo
    ON CAST(s.order_id AS STRING) = CAST(fo.order_id AS STRING)

  LEFT JOIN `peya-bi-tools-pro.il_qcommerce.fact_groceries_shopping_missions` shop
    ON CAST(s.order_id AS STRING) = CAST(shop.order_id AS STRING)
    AND shop.registered_date > '2020-04-01'

  WHERE s.order_date >= current_month
  GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,
           30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,
           56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,
           82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100,101,102,103,104,105,106,107,108,109,110,111
),

latam_dmarts_adoption_type AS (
  SELECT
    country_name,
    customer_id,
    cohort_date,
    CASE
      WHEN acquisition_type = 'acquisition' THEN 'acquisition'
      WHEN acquisition_type = 'active'      THEN 'adoption'
    END AS adoption_origin,
    CASE
      WHEN flag_plus = 1 AND flag_vc = 1 AND order_number = 1 THEN 'Plus & Voucher Incentivized'
      WHEN flag_plus = 1 AND flag_vc = 0 AND order_number = 1 THEN 'Plus Incentivized'
      WHEN flag_plus = 0 AND flag_vc = 1 AND order_number = 1 THEN 'Voucher Incentivized'
      WHEN flag_plus = 0 AND flag_vc = 0 AND order_number = 1 THEN 'Organic'
    END AS adoption_class,
    CASE
      WHEN flag_vc = 1 AND order_number = 1 THEN 'Voucher Incentivized'
      WHEN flag_vc = 0 AND order_number = 1 THEN 'Organic'
    END AS adoption_class_test,
    CASE WHEN flag_vc = 1 AND order_number = 1 THEN Coupon_Campaign END AS adoption_coupon_used,
    CASE WHEN flag_vc = 1 AND order_number = 1 THEN Coupon_Funnel   END AS adoption_funnel_used,
    CASE WHEN flag_vc = 1 AND order_number = 1 THEN CRM_Vertical    END AS adoption_vertical_attributed,
    COUNT(DISTINCT customer_id) AS users
  FROM latam_dmarts_orders
  WHERE order_number = 1
  GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9
),

orders_with_week AS (
  SELECT
    order_date,
    customer_id,
    FORMAT_DATE('%U', DATE_TRUNC(order_date, WEEK(MONDAY))) AS week_of_year,
    MOD(EXTRACT(DAYOFWEEK FROM order_date) + 5, 7) + 1     AS day_of_week
  FROM latam_dmarts_orders
),

week_start_day AS (
  SELECT
    customer_id,
    week_of_year,
    MIN(day_of_week) AS start_day
  FROM orders_with_week
  GROUP BY 1, 2
),

activation_source AS (
  SELECT
    customer_id,
    month,
    order_num_month,
    flag_vc,
    flag_plus,
    CASE
      WHEN flag_vc = 1                         THEN 'CRM'
      WHEN flag_vc = 0 AND flag_plus = 1       THEN 'Plus'
      WHEN flag_vc = 0 AND flag_plus = 0       THEN 'Organic'
    END AS activation_source,
    CASE
      WHEN flag_vc = 1                         THEN CRM_Vertical
      WHEN flag_vc = 0 AND flag_plus = 1       THEN 'Plus'
      WHEN flag_vc = 0 AND flag_plus = 0       THEN 'Organic'
    END AS activation_funnel,
    CASE
      WHEN flash_deal = 1                                                               THEN 'Flash Deal'
      WHEN flag_vc = 1 AND flash_deal = 0                                               THEN 'Voucher'
      WHEN flag_vc = 0 AND ild_discount = 1 AND flash_deal = 0                         THEN 'ild'
      WHEN flag_vc = 0 AND flag_plus = 0 AND flash_deal = 0 AND ild_discount = 0
        AND flag_delivery_free = 1                                                      THEN 'Free Delivery'
      WHEN flag_vc = 0 AND flag_delivery_free = 0 AND flash_deal = 0 AND ild_discount = 0
        AND flag_plus = 1 AND plus_discount = 1                                         THEN 'Promo plus'
      WHEN flag_vc = 0 AND plus_discount = 0 AND flash_deal = 0 AND ild_discount = 0
        AND flag_plus = 1                                                               THEN 'Plus'
      WHEN flag_vc = 0 AND flag_delivery_free = 0 AND flag_plus = 0 AND flash_deal = 0
        AND ild_discount = 0 AND low_discounts = 1                                     THEN 'Low Discounts'
      WHEN flag_vc = 0 AND flag_delivery_free = 0 AND flag_plus = 0 AND flash_deal = 0
        AND ild_discount = 0 AND moderate_discounts = 1                                THEN 'Moderate Discounts'
      WHEN flag_vc = 0 AND flag_delivery_free = 0 AND flag_plus = 0 AND flash_deal = 0
        AND ild_discount = 0 AND high_discounts = 1                                    THEN 'High Discounts'
      ELSE 'Others'
    END AS loss_orders
  FROM latam_dmarts_orders
  WHERE order_num_month = 1
),

dmart_fact_orders AS (
  SELECT
    pd.*,
    CASE WHEN comp_ccr1 IS NOT NULL THEN 1 ELSE 0 END                                      AS flag_inaccuracy,
    CASE WHEN comp_ccr1 IS NOT NULL AND late_order = 1 THEN 1 ELSE 0 END                   AS inaccuracy_late,
    act.activation_source                                                                  AS month_activation_source,
    act.activation_funnel                                                                  AS month_activation_funnel_source,
    act.loss_orders                                                                        AS month_activation_loss_orders,
    adopt.adoption_origin,
    adopt.adoption_class,
    adopt.adoption_class_test,
    adopt.adoption_coupon_used,
    adopt.adoption_funnel_used,
    adopt.adoption_vertical_attributed,
    CONCAT('W', CAST(pd.week_of_year AS STRING), '-', CAST(wsd.start_day AS STRING))      AS wsd_week_and_day,
    wsd.start_day                                                                          AS wsd_start_day,
    CASE
      WHEN Basket_Sz BETWEEN 1 AND 5 OR Categories BETWEEN 1 AND 2 THEN 'Instant Need'
      ELSE (
        CASE WHEN Basket_Sz BETWEEN 6 AND 15 AND Categories BETWEEN 3 AND 4 THEN 'Fill In'
          ELSE (
            CASE WHEN Basket_Sz > 15 AND Categories >= 5 THEN 'Stock Up'
              ELSE (CASE WHEN Basket_Sz > 5 THEN 'Fill In' ELSE NULL END)
            END
          )
        END
      )
    END AS DH_Shopping_Mission
  FROM latam_dmarts_orders pd
  LEFT JOIN latam_dmarts_adoption_type adopt
    ON pd.customer_id = adopt.customer_id
  LEFT JOIN week_start_day wsd
    ON pd.week_of_year = wsd.week_of_year AND pd.customer_id = wsd.customer_id
  LEFT JOIN activation_source act
    ON pd.month = act.month AND pd.customer_id = act.customer_id
),

monthly_user AS (
  SELECT
    fo.month,
    fo.customer_id,
    CASE
      WHEN COUNT(DISTINCT CASE WHEN mission_type      = 'Stock Up' THEN order_id END) >= 1 THEN 'Stock Up'
      WHEN COUNT(DISTINCT CASE WHEN mission_type      = 'Fill In'  THEN order_id END) >= 1 THEN 'Fill In'
      ELSE 'Instant Need'
    END AS dh_shopping_mission_user,
    CASE
      WHEN COUNT(DISTINCT CASE WHEN DH_Shopping_Mission = 'Stock Up' THEN order_id END) >= 1 THEN 'Stock Up'
      WHEN COUNT(DISTINCT CASE WHEN DH_Shopping_Mission = 'Fill In'  THEN order_id END) >= 1 THEN 'Fill In'
      ELSE 'Instant Need'
    END AS dh_shopping_mission_user_v2
  FROM dmart_fact_orders fo
  GROUP BY 1, 2
)

SELECT
  k.*,
  dh_shopping_mission_user,
  dh_shopping_mission_user_v2,
  CASE
    WHEN flag_plus = 1                   THEN 'Plus'
    WHEN CRM_Vertical = 'DMART'          THEN 'Dmart RMO'
    WHEN flag_vc = 1                     THEN order_source
    WHEN multibuy_order = 1              THEN 'Organic Multibuy'
    WHEN discount_order = 1              THEN 'Organic Discount'
    ELSE 'Organic'
  END AS order_sub_source,
  CASE
    WHEN flag_plus = 1 AND d_descuento IS NULL     THEN 'Plus'
    WHEN flag_plus = 1 AND d_descuento IS NOT NULL THEN 'Plus Benefit'
    WHEN CRM_Vertical = 'DMART'                    THEN 'Dmart RMO'
    WHEN flag_vc = 1                               THEN order_source
    WHEN multibuy_order = 1                        THEN 'Organic Multibuy'
    WHEN discount_order = 1                        THEN 'Organic Discount'
    ELSE 'Organic'
  END AS order_micro_source
FROM dmart_fact_orders k
LEFT JOIN monthly_user m
  ON k.month = m.month AND k.customer_id = m.customer_id--)
