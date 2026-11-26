
DECLARE query_name STRING DEFAULT '11. Daily Alerts - Peya Market (Daily Data)';

WITH

-- ============================================================
-- FECHAS DE REFERENCIA
-- ============================================================
dates AS (
    SELECT
        DATE_SUB(CURRENT_DATE(), INTERVAL 1  DAY) AS d_minus_1,
        DATE_SUB(CURRENT_DATE(), INTERVAL 8  DAY) AS d_minus_8,
        DATE_SUB(CURRENT_DATE(), INTERVAL 15 DAY) AS d_minus_15,
        DATE_SUB(CURRENT_DATE(), INTERVAL 22 DAY) AS d_minus_22
),

-- FECHA DE ACTUALIZACIÓN (La más reciente de fact_orders)
-- ============================================================
max_fact_orders_date AS (
    SELECT MAX(registered_date) AS max_date 
    FROM `peya-bi-tools-pro.il_core.fact_orders` 
    WHERE registered_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 3 DAY)
),


-- ORDERS (CONFIRMED)
-- ============================================================
orders_data AS (
    SELECT DISTINCT
        DATE(fo.registered_date)        AS order_date,
        lower(par.country.country_code) as country_code,
        par.warehouse_id,
        par.warehouse_name,
        CAST(fo.order_id AS STRING)     AS order_id,
        fo.order_status,
        fo.user.id                      AS customer_id
    FROM `peya-bi-tools-pro.il_core.fact_orders` fo
    LEFT JOIN `peya-bi-tools-pro.il_core.dim_partner` par
        ON fo.restaurant.id = par.partner_id
    WHERE DATE(fo.registered_date) IN (
            DATE_SUB(CURRENT_DATE(), INTERVAL 1  DAY),
            DATE_SUB(CURRENT_DATE(), INTERVAL 8  DAY),
            DATE_SUB(CURRENT_DATE(), INTERVAL 15 DAY),
            DATE_SUB(CURRENT_DATE(), INTERVAL 22 DAY)
          )
      AND par.is_darkstore
),

orders_agg AS (
    SELECT
        order_date,
        country_code,
        warehouse_id,
        warehouse_name,
        COUNT(DISTINCT CASE WHEN order_status = 'CONFIRMED' THEN order_id END) AS orders
    FROM orders_data
    GROUP BY 1, 2, 3, 4
),

-- SUPPLY METRICS
-- ============================================================
supply_metrics AS (
   with wis as (
 SELECT
        period_day,
        ad.country_code, 
        ad.warehouse_id, 
        ad.warehouse_name,
        ad.sku,
        max(sales_forecast_quantity) as sales_forecast_quantity,  
        SUM(available_hourly * hourly_events_weightage)/SUM(hourly_events_weightage) AS hours_ponderado,
       

        max(case when level_zero_category = 'Ultra Fresh' THEN sales_forecast_quantity END) AS sales_forecast_quantity_UF,
       SAFE_DIVIDE(SUM(case when level_zero_category = 'Ultra Fresh' THEN available_hourly * hourly_events_weightage END),SUM(case when level_zero_category = 'Ultra Fresh' THEN hourly_events_weightage END)) as hours_ponderado_uf,
        
   
    FROM 
      `fulfillment-dwh-production.curated_data_shared_dmart.availability_data` ad
      LEFT JOIN `peya-delivery-and-support.automated_tables_reports.reple_flag_supplier_portal_historical` sp ON ad.warehouse_id = sp.warehouse_id and period_day = date and ad.sku = sp.sku
      CROSS JOIN DATES
    WHERE (
            (period_day >= DATE(status_implementation_date) AND sku_status IN ('ACTIVE') AND is_stale IS FALSE)
            OR
            (((period_day < DATE(status_implementation_date)) OR (status_implementation_date IS NULL)) AND is_active AND is_stale IS FALSE)
          )
      AND store_open = 1
      AND period_day IN (d_minus_1, d_minus_8, d_minus_15, d_minus_22)
      AND is_active
      AND management_entity = 'Pedidosya'
      AND status_final <> 'No activo'
      --AND country_code='ar'
    GROUP BY 1,2,3,4,5)

    SELECT
        period_day,
        country_code, 
        warehouse_id, 
        warehouse_name,
        SUM(hours_ponderado * sales_forecast_quantity) AS wis_numerador,
        SUM(sales_forecast_quantity) as wis_denominador,
        SUM(sales_forecast_quantity_UF*hours_ponderado_uf) as wis_uf_numerador,
        SUM(sales_forecast_quantity_UF) AS wis_uf_denominador,
       
       -- SUM(hours_ponderado * sales_forecast_quantity)/SUM(sales_forecast_quantity) as wis
    from wis 
    GROUP BY
      1,2,3,4   
),


-- ORDERS PARA SEAMLESS (sin filtro de order_status) — replica el universo de new_seamless_unified_qc
-- ============================================================
orders_data_seamless AS (
    SELECT
        DATE(fo.registered_date)        AS order_date,
        lower(par.country.country_code) as country_code,
        par.warehouse_id,
        par.warehouse_name,
        CAST(fo.order_id AS STRING)     AS order_id,
        fo.order_status
    FROM `peya-bi-tools-pro.il_core.fact_orders` fo
    LEFT JOIN `peya-bi-tools-pro.il_core.dim_partner` par
        ON fo.restaurant.id = par.partner_id
    WHERE fo.registered_date IN (
            DATE_SUB(CURRENT_DATE(), INTERVAL 1  DAY),
            DATE_SUB(CURRENT_DATE(), INTERVAL 8  DAY),
            DATE_SUB(CURRENT_DATE(), INTERVAL 15 DAY),
            DATE_SUB(CURRENT_DATE(), INTERVAL 22 DAY)
          )
      AND par.is_logistic
      AND par.is_darkstore
      AND par.business_type.business_type_name NOT IN ('Courier', 'Courier Business')
),

-- NEW USERS
-- ============================================================
new_users AS (
    SELECT
        fo.user.id                      AS customer_id,
        MIN(DATE(fo.registered_date))   AS first_order_date
    FROM `peya-bi-tools-pro.il_core.fact_orders` fo
    LEFT JOIN `peya-bi-tools-pro.il_core.dim_partner` par
        ON fo.restaurant.id = par.partner_id
    WHERE fo.order_status = 'CONFIRMED'
      AND par.is_logistic
      AND par.is_darkstore
      AND fo.registered_date >= '2020-04-01'
      AND par.business_type.business_type_name NOT IN ('Courier', 'Courier Business')
    GROUP BY 1
),

new_users_agg AS (
    SELECT
        od.order_date,
        od.country_code,
        od.warehouse_id,
        od.warehouse_name,
        COUNT(DISTINCT od.customer_id) AS new_users
    FROM orders_data od
    INNER JOIN new_users nu
        ON od.customer_id      = nu.customer_id
       AND nu.first_order_date = od.order_date
    WHERE od.order_status = 'CONFIRMED'
    GROUP BY 1, 2, 3, 4
),


-- FX
-- ============================================================
fx AS (
    SELECT
        fx_source.month,
        fx_source.currency_iso,
        c.country_id,
        AVG(fx_source.rate_eur) AS rate_eur
    FROM `peya-fraud-and-fintech.group_finance_data.fact_sap_fx` AS fx_source
    LEFT JOIN `peya-bi-tools-pro.il_core.dim_country` AS c
        ON fx_source.currency_iso = c.currency_price
    WHERE c.country_name_en NOT IN ('Venezuela', 'Puerto Rico')
    GROUP BY 1, 2, 3
),

-- GMV
-- ============================================================
gmv AS (
    SELECT
        DATE(fo.registered_date)                                                    AS day,
        lower(par.country.country_code) as country_code,
        par.warehouse_id,
        par.warehouse_name,
        SUM(fo.total_amount             / fx.rate_eur)
          + SUM(fo.shipping_amount      / fx.rate_eur)
          + SUM(fo.serviceFee.service_fee_amount / fx.rate_eur)                    AS gmv
    FROM `peya-bi-tools-pro.il_core.fact_orders` fo
    LEFT JOIN `peya-bi-tools-pro.il_core.dim_partner` par
        ON fo.restaurant.id = par.partner_id
    LEFT JOIN fx
        ON DATE_TRUNC(DATE(fo.registered_date), MONTH) = fx.month
       AND fo.country_id = fx.country_id
    WHERE fo.registered_date IN (
            DATE_SUB(CURRENT_DATE(), INTERVAL 1  DAY),
            DATE_SUB(CURRENT_DATE(), INTERVAL 8  DAY),
            DATE_SUB(CURRENT_DATE(), INTERVAL 15 DAY),
            DATE_SUB(CURRENT_DATE(), INTERVAL 22 DAY)
          )
      AND fo.order_status = 'CONFIRMED'
      AND par.is_logistic
      AND par.is_darkstore
      AND par.business_type.business_type_name NOT IN ('Courier', 'Courier Business')
    GROUP BY 1, 2, 3, 4
),

-- PICKERS (assignment_time)
-- ============================================================
pickers_agg AS (
    SELECT
        od.order_date,
        od.country_code,
        od.warehouse_id,
        od.warehouse_name,
        SUM(order_events.order_available_to_start_duration_sec / 60) AS assignment_time_sum,
        COUNT(DISTINCT od.order_id)                                  AS assignment_time_confirmed_orders,
        COUNT(DISTINCT CASE WHEN (order_events.order_available_to_start_duration_sec / 60) > 6 THEN od.order_id END) AS orders_over_6min
    FROM `peya-data-origins-pro.cl_dmarts.qc_picker_shift_orders` AS p
    CROSS JOIN UNNEST(p.shifts) AS shifts
    CROSS JOIN UNNEST(shifts.order_events) AS order_events
    INNER JOIN orders_data AS od
        ON od.order_id = CAST(order_events.order_id AS STRING)
    WHERE p.shift_start_date_utc >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
      AND DATETIME(shifts.shift_start_at_utc, shifts.timezone) >= CAST(DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY) AS DATETIME)
      AND od.order_status = 'CONFIRMED'
    GROUP BY 1, 2, 3, 4
),

-- SEAMLESS
-- ============================================================
seamless_orders AS (
    SELECT
        platform_order_code                 AS order_id,
        non_seamless_order,
        is_late_order,
        is_slow_order,
        is_rejected_order,
        is_session_order,
        is_forced_preorder,
        is_modified_order,
        non_seamless_type,
        actual_delivery_time
    FROM `peya-datamarts-pro.dm_fulfillment.non_seamless_delivery_order_level`
    CROSS JOIN dates
    WHERE created_date_local IN (d_minus_1, d_minus_8, d_minus_15, d_minus_22)
),

-- Seamless / OPS sobre el universo SIN filtro de order_status
seamless_agg AS (
    SELECT
        ods.order_date,
        ods.country_code,
        ods.warehouse_id,
        ods.warehouse_name,
        COUNT(DISTINCT ods.order_id)                                                AS total_orders,
        SUM(CASE WHEN so.non_seamless_order = TRUE THEN 0 ELSE 1 END)              AS seamless_numerador,
        COUNT(DISTINCT CASE WHEN CAST(so.is_late_order     AS STRING) IN ('1','true','TRUE') THEN ods.order_id END) AS late_orders,
        COUNT(DISTINCT CASE WHEN CAST(so.is_slow_order     AS STRING) IN ('1','true','TRUE') THEN ods.order_id END) AS slow_orders,
        COUNT(DISTINCT CASE WHEN CAST(so.is_rejected_order AS STRING) IN ('1','true','TRUE') THEN ods.order_id END) AS rejected_orders,
        COUNT(DISTINCT CASE WHEN CAST(so.is_session_order  AS STRING) IN ('1','true','TRUE') THEN ods.order_id END) AS session_orders,
        COUNT(DISTINCT CASE WHEN CAST(so.is_forced_preorder AS STRING) IN ('1','true','TRUE') THEN ods.order_id END) AS forced_preorders,
        COUNT(DISTINCT CASE WHEN CAST(so.is_modified_order AS STRING) IN ('1','true','TRUE') THEN ods.order_id END) AS modified_orders
    FROM orders_data_seamless ods
    LEFT JOIN seamless_orders so
        ON CAST(ods.order_id AS STRING) = CAST(so.order_id AS STRING)
    GROUP BY 1, 2, 3, 4
),

-- DELIVERY TIME sobre CONFIRMED
delivery_time_agg AS (
    SELECT
        od.order_date,
        od.country_code,
        od.warehouse_id,
        od.warehouse_name,
        SUM(so.actual_delivery_time)                                                AS delivery_time_sum,
        COUNT(DISTINCT CASE WHEN so.actual_delivery_time IS NOT NULL THEN od.order_id END) AS delivery_time_order_count
    FROM orders_data od
    LEFT JOIN seamless_orders so
        ON CAST(od.order_id AS STRING) = CAST(so.order_id AS STRING)
    WHERE od.order_status = 'CONFIRMED'
    GROUP BY 1, 2, 3, 4
),


-- SKELETON: unión de claves (period_day, country_code, warehouse_id, warehouse_name)
-- de TODAS las fuentes. Así no perdemos warehouses ausentes en supply_metrics.
-- ============================================================
skeleton AS (
    SELECT period_day, country_code, warehouse_id, warehouse_name FROM supply_metrics
    UNION DISTINCT
    SELECT order_date,  country_code, warehouse_id, warehouse_name FROM orders_agg
    UNION DISTINCT
    SELECT order_date,  country_code, warehouse_id, warehouse_name FROM seamless_agg
    UNION DISTINCT
    SELECT order_date,  country_code, warehouse_id, warehouse_name FROM new_users_agg
    UNION DISTINCT
    SELECT day,         country_code, warehouse_id, warehouse_name FROM gmv
    UNION DISTINCT
    SELECT order_date,  country_code, warehouse_id, warehouse_name FROM delivery_time_agg
    UNION DISTINCT
    SELECT order_date,  country_code, warehouse_id, warehouse_name FROM pickers_agg
),

-- *** CAMBIO ***
-- ============================================================
-- BASE DIARIA — ahora arranca desde skeleton (unión), no desde supply_metrics
-- ============================================================
daily_base AS (
    SELECT
        sk.period_day,
        sk.country_code,
        sk.warehouse_id,
        sk.warehouse_name,
        sm.wis_numerador,
        sm.wis_denominador,
        sm.wis_uf_numerador,
        sm.wis_uf_denominador,
        oa.orders,
        nu.new_users,
        g.gmv,
        sa.total_orders,
        sa.seamless_numerador,
        sa.late_orders,
        sa.slow_orders,
        sa.rejected_orders,
        sa.session_orders,
        sa.forced_preorders,
        sa.modified_orders,
        dta.delivery_time_sum,
        dta.delivery_time_order_count,
        pa.assignment_time_sum,
        pa.assignment_time_confirmed_orders,
        pa.orders_over_6min
    FROM skeleton sk
    LEFT JOIN supply_metrics    sm  ON sk.period_day = sm.period_day  AND sk.warehouse_id = sm.warehouse_id
    LEFT JOIN orders_agg        oa  ON sk.period_day = oa.order_date  AND sk.warehouse_id = oa.warehouse_id
    LEFT JOIN new_users_agg     nu  ON sk.period_day = nu.order_date  AND sk.warehouse_id = nu.warehouse_id
    LEFT JOIN gmv               g   ON sk.period_day = g.day          AND sk.warehouse_id = g.warehouse_id
    LEFT JOIN seamless_agg      sa  ON sk.period_day = sa.order_date  AND sk.warehouse_id = sa.warehouse_id
    LEFT JOIN delivery_time_agg dta ON sk.period_day = dta.order_date AND sk.warehouse_id = dta.warehouse_id
    LEFT JOIN pickers_agg       pa  ON sk.period_day = pa.order_date  AND sk.warehouse_id = pa.warehouse_id
),

-- ============================================================
-- PIVOTEO FINAL
-- ============================================================
final AS (
    SELECT
        warehouse_id,
        warehouse_name,
        lower(country_code) as country_code,

        -- D-1
        MAX(CASE WHEN period_day = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) THEN wis_numerador              END) AS d1_wis_numerador,
        MAX(CASE WHEN period_day = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) THEN wis_denominador            END) AS d1_wis_denominador,
        MAX(CASE WHEN period_day = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) THEN wis_uf_numerador           END) AS d1_wis_uf_numerador,
        MAX(CASE WHEN period_day = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) THEN wis_uf_denominador         END) AS d1_wis_uf_denominador,
        MAX(CASE WHEN period_day = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) THEN orders                     END) AS d1_orders,
        MAX(CASE WHEN period_day = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) THEN new_users                  END) AS d1_new_users,
        MAX(CASE WHEN period_day = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) THEN gmv                        END) AS d1_gmv,
        MAX(CASE WHEN period_day = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) THEN total_orders               END) AS d1_total_orders,
        MAX(CASE WHEN period_day = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) THEN seamless_numerador         END) AS d1_seamless_numerador,
        MAX(CASE WHEN period_day = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) THEN late_orders                END) AS d1_late_orders,
        MAX(CASE WHEN period_day = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) THEN slow_orders                END) AS d1_slow_orders,
        MAX(CASE WHEN period_day = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) THEN rejected_orders            END) AS d1_rejected_orders,
        MAX(CASE WHEN period_day = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) THEN session_orders             END) AS d1_session_orders,
        MAX(CASE WHEN period_day = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) THEN forced_preorders           END) AS d1_forced_preorders,
        MAX(CASE WHEN period_day = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) THEN modified_orders            END) AS d1_modified_orders,
        MAX(CASE WHEN period_day = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) THEN delivery_time_sum          END) AS d1_delivery_time_sum,
        MAX(CASE WHEN period_day = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) THEN delivery_time_order_count  END) AS d1_delivery_time_order_count,
        MAX(CASE WHEN period_day = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) THEN assignment_time_sum        END) AS d1_assignment_time_sum,
        MAX(CASE WHEN period_day = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) THEN assignment_time_confirmed_orders END) AS d1_assignment_time_confirmed_orders,
        MAX(CASE WHEN period_day = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) THEN orders_over_6min END) AS d1_orders_over_6min,

        -- D-8
        MAX(CASE WHEN period_day = DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY) THEN wis_numerador              END) AS d8_wis_numerador,
        MAX(CASE WHEN period_day = DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY) THEN wis_denominador            END) AS d8_wis_denominador,
        MAX(CASE WHEN period_day = DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY) THEN wis_uf_numerador           END) AS d8_wis_uf_numerador,
        MAX(CASE WHEN period_day = DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY) THEN wis_uf_denominador         END) AS d8_wis_uf_denominador,
        MAX(CASE WHEN period_day = DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY) THEN orders                     END) AS d8_orders,
        MAX(CASE WHEN period_day = DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY) THEN new_users                  END) AS d8_new_users,
        MAX(CASE WHEN period_day = DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY) THEN gmv                        END) AS d8_gmv,
        MAX(CASE WHEN period_day = DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY) THEN total_orders               END) AS d8_total_orders,
        MAX(CASE WHEN period_day = DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY) THEN seamless_numerador         END) AS d8_seamless_numerador,
        MAX(CASE WHEN period_day = DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY) THEN late_orders                END) AS d8_late_orders,
        MAX(CASE WHEN period_day = DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY) THEN slow_orders                END) AS d8_slow_orders,
        MAX(CASE WHEN period_day = DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY) THEN rejected_orders            END) AS d8_rejected_orders,
        MAX(CASE WHEN period_day = DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY) THEN session_orders             END) AS d8_session_orders,
        MAX(CASE WHEN period_day = DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY) THEN forced_preorders           END) AS d8_forced_preorders,
        MAX(CASE WHEN period_day = DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY) THEN modified_orders            END) AS d8_modified_orders,
        MAX(CASE WHEN period_day = DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY) THEN delivery_time_sum          END) AS d8_delivery_time_sum,
        MAX(CASE WHEN period_day = DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY) THEN delivery_time_order_count  END) AS d8_delivery_time_order_count,
        MAX(CASE WHEN period_day = DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY) THEN assignment_time_sum        END) AS d8_assignment_time_sum,
        MAX(CASE WHEN period_day = DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY) THEN assignment_time_confirmed_orders END) AS d8_assignment_time_confirmed_orders,
        MAX(CASE WHEN period_day = DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY) THEN orders_over_6min END) AS d8_orders_over_6min,

        -- LW: suma D-8 + D-15 + D-22
        SUM(CASE WHEN period_day IN (DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY), DATE_SUB(CURRENT_DATE(), INTERVAL 15 DAY), DATE_SUB(CURRENT_DATE(), INTERVAL 22 DAY)) THEN wis_numerador              ELSE 0 END) AS lw_wis_numerador,
        SUM(CASE WHEN period_day IN (DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY), DATE_SUB(CURRENT_DATE(), INTERVAL 15 DAY), DATE_SUB(CURRENT_DATE(), INTERVAL 22 DAY)) THEN wis_denominador            ELSE 0 END) AS lw_wis_denominador,
        SUM(CASE WHEN period_day IN (DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY), DATE_SUB(CURRENT_DATE(), INTERVAL 15 DAY), DATE_SUB(CURRENT_DATE(), INTERVAL 22 DAY)) THEN wis_uf_numerador           ELSE 0 END) AS lw_wis_uf_numerador,
        SUM(CASE WHEN period_day IN (DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY), DATE_SUB(CURRENT_DATE(), INTERVAL 15 DAY), DATE_SUB(CURRENT_DATE(), INTERVAL 22 DAY)) THEN wis_uf_denominador         ELSE 0 END) AS lw_wis_uf_denominador,
        SUM(CASE WHEN period_day IN (DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY), DATE_SUB(CURRENT_DATE(), INTERVAL 15 DAY), DATE_SUB(CURRENT_DATE(), INTERVAL 22 DAY)) THEN orders                     ELSE 0 END) AS lw_orders,
        SUM(CASE WHEN period_day IN (DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY), DATE_SUB(CURRENT_DATE(), INTERVAL 15 DAY), DATE_SUB(CURRENT_DATE(), INTERVAL 22 DAY)) THEN new_users                  ELSE 0 END) AS lw_new_users,
        SUM(CASE WHEN period_day IN (DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY), DATE_SUB(CURRENT_DATE(), INTERVAL 15 DAY), DATE_SUB(CURRENT_DATE(), INTERVAL 22 DAY)) THEN gmv                        ELSE 0 END) AS lw_gmv,
        SUM(CASE WHEN period_day IN (DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY), DATE_SUB(CURRENT_DATE(), INTERVAL 15 DAY), DATE_SUB(CURRENT_DATE(), INTERVAL 22 DAY)) THEN total_orders               ELSE 0 END) AS lw_total_orders,
        SUM(CASE WHEN period_day IN (DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY), DATE_SUB(CURRENT_DATE(), INTERVAL 15 DAY), DATE_SUB(CURRENT_DATE(), INTERVAL 22 DAY)) THEN seamless_numerador         ELSE 0 END) AS lw_seamless_numerador,
        SUM(CASE WHEN period_day IN (DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY), DATE_SUB(CURRENT_DATE(), INTERVAL 15 DAY), DATE_SUB(CURRENT_DATE(), INTERVAL 22 DAY)) THEN late_orders                ELSE 0 END) AS lw_late_orders,
        SUM(CASE WHEN period_day IN (DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY), DATE_SUB(CURRENT_DATE(), INTERVAL 15 DAY), DATE_SUB(CURRENT_DATE(), INTERVAL 22 DAY)) THEN slow_orders                ELSE 0 END) AS lw_slow_orders,
        SUM(CASE WHEN period_day IN (DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY), DATE_SUB(CURRENT_DATE(), INTERVAL 15 DAY), DATE_SUB(CURRENT_DATE(), INTERVAL 22 DAY)) THEN rejected_orders            ELSE 0 END) AS lw_rejected_orders,
        SUM(CASE WHEN period_day IN (DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY), DATE_SUB(CURRENT_DATE(), INTERVAL 15 DAY), DATE_SUB(CURRENT_DATE(), INTERVAL 22 DAY)) THEN session_orders             ELSE 0 END) AS lw_session_orders,
        SUM(CASE WHEN period_day IN (DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY), DATE_SUB(CURRENT_DATE(), INTERVAL 15 DAY), DATE_SUB(CURRENT_DATE(), INTERVAL 22 DAY)) THEN forced_preorders           ELSE 0 END) AS lw_forced_preorders,
        SUM(CASE WHEN period_day IN (DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY), DATE_SUB(CURRENT_DATE(), INTERVAL 15 DAY), DATE_SUB(CURRENT_DATE(), INTERVAL 22 DAY)) THEN modified_orders            ELSE 0 END) AS lw_modified_orders,
        SUM(CASE WHEN period_day IN (DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY), DATE_SUB(CURRENT_DATE(), INTERVAL 15 DAY), DATE_SUB(CURRENT_DATE(), INTERVAL 22 DAY)) THEN delivery_time_sum          ELSE 0 END) AS lw_delivery_time_sum,
        SUM(CASE WHEN period_day IN (DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY), DATE_SUB(CURRENT_DATE(), INTERVAL 15 DAY), DATE_SUB(CURRENT_DATE(), INTERVAL 22 DAY)) THEN delivery_time_order_count  ELSE 0 END) AS lw_delivery_time_order_count,
        SUM(CASE WHEN period_day IN (DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY), DATE_SUB(CURRENT_DATE(), INTERVAL 15 DAY), DATE_SUB(CURRENT_DATE(), INTERVAL 22 DAY)) THEN assignment_time_sum        ELSE 0 END) AS lw_assignment_time_sum,
        SUM(CASE WHEN period_day IN (DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY), DATE_SUB(CURRENT_DATE(), INTERVAL 15 DAY), DATE_SUB(CURRENT_DATE(), INTERVAL 22 DAY)) THEN assignment_time_confirmed_orders ELSE 0 END) AS lw_assignment_time_confirmed_orders,
        SUM(CASE WHEN period_day IN (DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY), DATE_SUB(CURRENT_DATE(), INTERVAL 15 DAY), DATE_SUB(CURRENT_DATE(), INTERVAL 22 DAY)) THEN orders_over_6min ELSE 0 END) AS lw_orders_over_6min

    FROM daily_base
    GROUP BY 1, 2, 3
)

SELECT 
    f.*,
    (SELECT max_date FROM max_fact_orders_date) AS max_fact_orders_date
FROM final f
ORDER BY country_code, warehouse_id