DECLARE query_name STRING DEFAULT '14. Mapster (WHS orders)';

-- ==============================================================================
-- TABLA EN SHEETS: 14. Mapster (WHS orders) - PERFORMANCE 360° POR WHS
--
-- Principios de Arquitectura:
--   1. BASES 100% OFICIALES: Exclusivamente tablas de producción (il_core,
--      automated_tables_reports, cl_dmarts, dm_fulfillment, il_logistics).
--      Cero dependencia de tablas personales o sandboxes (e.g. user_eugenio_irigoin).
--   2. PRIORIDAD A FACT_ORDERS: fact_orders es la fuente de verdad primaria
--      para volumen de órdenes, validación de estados y conteo de clientes/usuarios.
--      customer_orders_sku_level se limita estrictamente a métricas a nivel SKU
--      (unidades físicas, categorización Ultra Fresh y descuentos).
--   3. TYPE-SAFETY RIGUROSO: Todos los IDs en cruces (order_id, partner_id,
--      warehouse_id, country_id, user_id) homogeneizados a STRING para evitar
--      errores de tipo INT64 vs STRING en BigQuery.
--   4. CLASIFICACIÓN EN 3 BLOQUES:
--      - Bloque 1: Transaccionales (Ventas, Órdenes, Unidades, Ticket, Descuentos, Frescos)
--      - Bloque 2: Usuarios (PeYa Users, DMart Users, Penetración %, Frecuencia, Core, High)
--      - Bloque 3: Operativas (Seamless, Fail Rate, Pickers, Tiempos Logísticos, Reclamos)
--
-- Grano: 1 fila por (month_date, warehouse_id)
-- ==============================================================================

DECLARE start_month DATE DEFAULT DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 MONTH), MONTH);
DECLARE end_month   DATE DEFAULT DATE_TRUNC(CURRENT_DATE(), MONTH);

WITH

-- 1. Maestros de Almacenes (Darkstores) desde dim_partner
dmart_partners AS (
  SELECT DISTINCT
    CAST(dp.warehouse_id AS STRING) AS warehouse_id,
    dp.warehouse_name,
    CAST(dp.partner_id AS STRING)   AS partner_id,
    dp.country.country_name         AS country,
    dp.city.name                    AS city
  FROM `peya-bi-tools-pro.il_core.dim_partner` dp
  WHERE dp.is_darkstore = TRUE
    AND dp.warehouse_id IS NOT NULL
),

-- 2. Universo de Órdenes desde fact_orders (Fuente de verdad primaria)
orders_base AS (
  SELECT
    fo.order_id,
    CAST(fo.order_id AS STRING)                 AS order_id_str,
    CAST(fo.customer_id AS STRING)              AS customer_id,
    dp.warehouse_id,
    dp.warehouse_name,
    dp.country,
    dp.city,
    CAST(fo.restaurant.id AS STRING)            AS partner_id,
    DATE_TRUNC(DATE(fo.registered_date), MONTH) AS month_date,
    fo.order_status,
    fo.total_amount                             AS gross_amount
  FROM `peya-bi-tools-pro.il_core.fact_orders` fo
  INNER JOIN dmart_partners dp
    ON CAST(fo.restaurant.id AS STRING) = dp.partner_id
  WHERE fo.registered_date >= start_month
    AND fo.registered_date < DATE_ADD(end_month, INTERVAL 1 MONTH)
),

-- 3. Identificación del Partner Principal por WHS/Mes desde fact_orders
warehouse_top_partner AS (
  SELECT
    warehouse_id,
    month_date,
    partner_id AS main_partner_id
  FROM (
    SELECT
      warehouse_id,
      month_date,
      partner_id,
      ROW_NUMBER() OVER (
        PARTITION BY warehouse_id, month_date
        ORDER BY COUNT(DISTINCT order_id) DESC, partner_id ASC
      ) AS rn
    FROM orders_base
    WHERE order_status = 'CONFIRMED'
    GROUP BY warehouse_id, month_date, partner_id
  )
  WHERE rn = 1
),

-- 4. Polígonos de Cobertura Oficiales del Almacén (qc_coverage_partner_shapes)
warehouse_shapes AS (
  SELECT
    wtp.month_date,
    wtp.warehouse_id,
    CAST(ps.country_id AS STRING) AS country_id,
    ps.partner_shape
  FROM warehouse_top_partner wtp
  INNER JOIN `peya-food-and-groceries.automated_tables_reports.qc_coverage_partner_shapes` ps
    ON  wtp.main_partner_id = CAST(ps.partner_id AS STRING)
    AND wtp.month_date      = ps.month_date
  WHERE ps.partner_shape IS NOT NULL
),

-- 5. Demografía de Usuarios PeYa cubiertos dentro de la huella (qc_coverage_customer_location)
peya_coverage_users AS (
  SELECT
    ws.month_date,
    ws.warehouse_id,
    COUNT(DISTINCT CAST(cl.customer_id AS STRING)) AS peya_users
  FROM `peya-food-and-groceries.automated_tables_reports.qc_coverage_customer_location` cl
  INNER JOIN warehouse_shapes ws
    ON  cl.month_date                 = ws.month_date
    AND CAST(cl.country_id AS STRING) = ws.country_id
    AND ST_WITHIN(cl.customer_geogpoint, ws.partner_shape)
  WHERE cl.month_date >= start_month
    AND cl.month_date < DATE_ADD(end_month, INTERVAL 1 MONTH)
    AND cl.customer_geogpoint IS NOT NULL
  GROUP BY 1, 2
),

-- 6. Métricas de Artículos, Unidades y Ultra Fresh desde SKU level (Solo lo que no está en fact_orders)
orders_sku AS (
  SELECT
    CAST(co.order_id AS STRING)                AS order_id_str,
    SUM(co.fulfilled_quantity)                 AS units_sold,
    SUM(co.total_amount_net_with_discount_eur) AS net_sales_eur,
    SUM(co.pcm_discount_amount_net_lc)         AS discounts_amount,
    MAX(CASE WHEN co.master_category_parent_english IN ('Produce', 'Meat / Seafood', 'Ready To Consume') THEN 1 ELSE 0 END) AS has_ultra_fresh
  FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` co
  WHERE co.order_date >= start_month
    AND co.order_date < DATE_ADD(end_month, INTERVAL 1 MONTH)
    AND co.state = 'CONFIRMED'
  GROUP BY 1
),

-- 7. Segmentación Oficial del Usuario (Core & High Income)
user_profiles AS (
  SELECT
    CAST(du.customer_id AS STRING)                                  AS customer_id,
    MAX(CASE WHEN UPPER(lc.subsegment) = 'CORE' THEN 1 ELSE 0 END)   AS is_core_user,
    MAX(CASE WHEN UPPER(lc.user_income) = 'HIGH' THEN 1 ELSE 0 END)  AS is_high_income_user
  FROM `peya-bi-tools-pro.il_qcommerce.user_lifecycle` lc
  INNER JOIN `peya-bi-tools-pro.il_core.dim_user` du
    ON  CAST(lc.user_id AS STRING)    = CAST(du.user_id AS STRING)
    AND CAST(lc.country_id AS STRING) = CAST(du.country_id AS STRING)
  GROUP BY 1
),

-- 8. Consolidación Transaccional y de Usuarios a Nivel Warehouse / Mes
whs_transaccional_y_usuarios AS (
  SELECT
    ob.month_date,
    ob.warehouse_id,
    ANY_VALUE(ob.warehouse_name) AS warehouse_name,
    ANY_VALUE(ob.country)        AS country,
    ANY_VALUE(ob.city)           AS city,

    -- Transaccionales (Prioridad fact_orders)
    COUNT(DISTINCT CASE WHEN ob.order_status = 'CONFIRMED' THEN ob.order_id END) AS total_orders,
    COUNT(DISTINCT ob.order_id)                                                  AS total_orders_fact_orders_all_status,
    SUM(CASE WHEN ob.order_status = 'CONFIRMED' THEN COALESCE(sku.units_sold, 0) ELSE 0 END) AS total_units_sold,
    ROUND(SUM(CASE WHEN ob.order_status = 'CONFIRMED' THEN COALESCE(sku.net_sales_eur, ob.gross_amount) ELSE 0 END), 2) AS total_net_sales,
    ROUND(SAFE_DIVIDE(
      SUM(CASE WHEN ob.order_status = 'CONFIRMED' THEN COALESCE(sku.net_sales_eur, ob.gross_amount) ELSE 0 END),
      COUNT(DISTINCT CASE WHEN ob.order_status = 'CONFIRMED' THEN ob.order_id END)
    ), 2) AS afv_aov_amount,
    ROUND(SAFE_DIVIDE(
      SUM(CASE WHEN ob.order_status = 'CONFIRMED' THEN COALESCE(sku.units_sold, 0) ELSE 0 END),
      COUNT(DISTINCT CASE WHEN ob.order_status = 'CONFIRMED' THEN ob.order_id END)
    ), 1) AS basket_size_units,
    ROUND(SUM(CASE WHEN ob.order_status = 'CONFIRMED' THEN COALESCE(sku.discounts_amount, 0) ELSE 0 END), 2) AS total_discounts,
    ROUND(SAFE_DIVIDE(
      SUM(CASE WHEN ob.order_status = 'CONFIRMED' THEN COALESCE(sku.discounts_amount, 0) ELSE 0 END),
      NULLIF(SUM(CASE WHEN ob.order_status = 'CONFIRMED' THEN COALESCE(sku.net_sales_eur, ob.gross_amount) + COALESCE(sku.discounts_amount, 0) ELSE 0 END), 0)
    ) * 100, 1) AS discount_intensity_pct,
    COUNT(DISTINCT CASE WHEN ob.order_status = 'CONFIRMED' AND sku.has_ultra_fresh = 1 THEN ob.order_id END) AS uf_orders,
    ROUND(SAFE_DIVIDE(
      COUNT(DISTINCT CASE WHEN ob.order_status = 'CONFIRMED' AND sku.has_ultra_fresh = 1 THEN ob.order_id END),
      COUNT(DISTINCT CASE WHEN ob.order_status = 'CONFIRMED' THEN ob.order_id END)
    ) * 100, 1) AS uf_orders_share_pct,

    -- Usuarios DMart (Compradores únicos de fact_orders)
    COUNT(DISTINCT CASE WHEN ob.order_status = 'CONFIRMED' THEN ob.customer_id END) AS dmart_users,
    ROUND(SAFE_DIVIDE(
      COUNT(DISTINCT CASE WHEN ob.order_status = 'CONFIRMED' THEN ob.order_id END),
      COUNT(DISTINCT CASE WHEN ob.order_status = 'CONFIRMED' THEN ob.customer_id END)
    ), 2) AS monthly_frequency,
    COUNT(DISTINCT CASE WHEN ob.order_status = 'CONFIRMED' AND sku.has_ultra_fresh = 1 THEN ob.customer_id END) AS uf_users,
    ROUND(SAFE_DIVIDE(
      COUNT(DISTINCT CASE WHEN ob.order_status = 'CONFIRMED' AND sku.has_ultra_fresh = 1 THEN ob.customer_id END),
      COUNT(DISTINCT CASE WHEN ob.order_status = 'CONFIRMED' THEN ob.customer_id END)
    ) * 100, 1) AS uf_users_penetration_pct,
    COUNT(DISTINCT CASE WHEN ob.order_status = 'CONFIRMED' AND up.is_core_user = 1 THEN ob.customer_id END) AS core_users,
    ROUND(SAFE_DIVIDE(
      COUNT(DISTINCT CASE WHEN ob.order_status = 'CONFIRMED' AND up.is_core_user = 1 THEN ob.customer_id END),
      COUNT(DISTINCT CASE WHEN ob.order_status = 'CONFIRMED' THEN ob.customer_id END)
    ) * 100, 1) AS core_users_pct,
    COUNT(DISTINCT CASE WHEN ob.order_status = 'CONFIRMED' AND up.is_high_income_user = 1 THEN ob.customer_id END) AS high_income_users,
    ROUND(SAFE_DIVIDE(
      COUNT(DISTINCT CASE WHEN ob.order_status = 'CONFIRMED' AND up.is_high_income_user = 1 THEN ob.customer_id END),
      COUNT(DISTINCT CASE WHEN ob.order_status = 'CONFIRMED' THEN ob.customer_id END)
    ) * 100, 1) AS high_income_users_pct

  FROM orders_base ob
  LEFT JOIN orders_sku sku
    ON ob.order_id_str = sku.order_id_str
  LEFT JOIN user_profiles up
    ON ob.customer_id = up.customer_id
  GROUP BY 1, 2
),

-- 9. Integración de Seamless Delivery (non_seamless_delivery_order_level)
seamless_orders_new AS (
  SELECT
    CAST(platform_order_code AS STRING) AS order_id,
    non_seamless_order,
    is_slow_order,
    is_modified_order,
    is_rejected_order,
    is_session_order,
    is_forced_preorder,
    is_late_order
  FROM `peya-datamarts-pro.dm_fulfillment.non_seamless_delivery_order_level`
  WHERE created_date_local >= start_month
    AND created_date_local < DATE_ADD(end_month, INTERVAL 1 MONTH)
),

seamless_data_monthly AS (
  SELECT
    ods.month_date,
    ods.warehouse_id,
    COUNT(DISTINCT CASE WHEN so.non_seamless_order IS FALSE OR so.non_seamless_order IS NULL THEN ods.order_id_str END) AS seamless_delivery,
    COUNT(DISTINCT CASE WHEN CAST(so.is_rejected_order AS STRING) IN ('1','true','TRUE') THEN ods.order_id_str END)   AS rejected_orders,
    COUNT(DISTINCT CASE WHEN CAST(so.is_forced_preorder AS STRING) IN ('1','true','TRUE') THEN ods.order_id_str END)  AS forced_pre_orders,
    COUNT(DISTINCT CASE WHEN CAST(so.is_modified_order AS STRING) IN ('1','true','TRUE') THEN ods.order_id_str END)   AS modified_orders,
    COUNT(DISTINCT CASE WHEN CAST(so.is_session_order AS STRING) IN ('1','true','TRUE') THEN ods.order_id_str END)    AS session_orders,
    COUNT(DISTINCT CASE WHEN CAST(so.is_slow_order AS STRING) IN ('1','true','TRUE') THEN ods.order_id_str END)       AS slow_orders,
    COUNT(DISTINCT CASE WHEN CAST(so.is_late_order AS STRING) IN ('1','true','TRUE') THEN ods.order_id_str END)       AS order_late
  FROM orders_base ods
  LEFT JOIN seamless_orders_new so
    ON ods.order_id_str = so.order_id
  GROUP BY 1, 2
),

-- 10. Métricas de Pickers y Turnos (qc_picker_shift_orders)
pickers_orders AS (
  SELECT
    ods.month_date,
    ods.warehouse_id,
    COUNT(DISTINCT ods.order_id)                                                                               AS picker_shift_confirmed_orders,
    ROUND(SUM(order_events.order_available_to_start_duration_sec / 60), 1)                                   AS assignment_time,
    ROUND(SUM(order_events.order_picking_duration_sec / 60), 1)                                              AS picking_time,
    COUNT(DISTINCT CASE WHEN (order_events.order_available_to_start_duration_sec / 60) > 6 THEN ods.order_id END) AS assignment_time_over_6min
  FROM `peya-data-origins-pro.cl_dmarts.qc_picker_shift_orders` picko,
    UNNEST(picko.shifts) AS shifts,
    UNNEST(shifts.order_events) AS order_events
  INNER JOIN orders_base ods
    ON ods.order_id_str = CAST(order_events.order_id AS STRING)
  WHERE DATETIME(shifts.shift_start_at_utc, shifts.timezone) >= CAST(start_month AS DATETIME)
    AND DATETIME(shifts.shift_start_at_utc, shifts.timezone) < CAST(DATE_ADD(end_month, INTERVAL 1 MONTH) AS DATETIME)
    AND shift_start_date_utc >= start_month
    AND shift_start_date_utc < DATE_ADD(end_month, INTERVAL 1 MONTH)
    AND ods.order_status = 'CONFIRMED'
  GROUP BY 1, 2
),

-- 11. Operaciones: Logística y Tiempos de Entrega (fact_logistic_orders)
ops_logistics AS (
  SELECT
    ob.month_date,
    ob.warehouse_id,
    ROUND(AVG(l.timings.actual_delivery_time / 60), 1)      AS avg_delivery_time_min,
    ROUND(SUM(l.timings.avoidable_wait_time / 60), 1)       AS total_awt_rider_minutes,
    SUM(l.is_order_late_10)                                 AS order_late_10_count
  FROM orders_base ob
  INNER JOIN `peya-bi-tools-pro.il_logistics.fact_logistic_orders` l
    ON ob.order_id_str = CAST(l.peya_order_id AS STRING)
  WHERE l.order_cancelled != 1
    AND ob.order_status = 'CONFIRMED'
  GROUP BY 1, 2
),

-- 12. Operaciones: Inexactitud y Reclamos de Calidad (dmarts_inaccuracy)
ops_inaccuracy AS (
  SELECT
    DATE_TRUNC(order_date, MONTH) AS month_date,
    CAST(warehouse_id AS STRING)  AS warehouse_id,
    SUM(total_orders)             AS total_orders_inaccuracy,
    SUM(total_complaint_orders)   AS complaint_orders
  FROM `peya-delivery-and-support.automated_tables_reports.dmarts_inaccuracy`
  WHERE order_date >= start_month
    AND order_date < DATE_ADD(end_month, INTERVAL 1 MONTH)
  GROUP BY 1, 2
)

-- ==============================================================================
-- SELECT FINAL: 14. Mapster (WHS orders) - CLASIFICACIÓN RIGUROSA EN 3 BLOQUES
-- ==============================================================================
SELECT
  -- ----------------------------------------------------------------------------
  -- CLAVES PRIMARIAS E IDENTIFICACIÓN
  -- ----------------------------------------------------------------------------
  u.month_date,
  u.warehouse_id,
  u.warehouse_name,
  u.country,
  u.city,

  -- ----------------------------------------------------------------------------
  -- 1. BLOQUE DE MÉTRICAS TRANSACCIONALES
  -- ----------------------------------------------------------------------------
  u.total_orders,
  u.total_orders_fact_orders_all_status,
  u.total_units_sold,
  u.total_net_sales,
  u.afv_aov_amount,
  u.basket_size_units,
  u.total_discounts,
  u.discount_intensity_pct,
  u.uf_orders,
  u.uf_orders_share_pct,

  -- ----------------------------------------------------------------------------
  -- 2. BLOQUE DE MÉTRICAS DE USUARIOS (Demografía y Penetración de Mercado)
  -- ----------------------------------------------------------------------------
  COALESCE(pu.peya_users, 0)                                                    AS peya_users,
  u.dmart_users                                                                 AS dmart_users,
  ROUND(SAFE_DIVIDE(u.dmart_users, NULLIF(COALESCE(pu.peya_users, 0), 0)) * 100, 2) AS penetration_pct,
  u.monthly_frequency,
  u.uf_users,
  u.uf_users_penetration_pct,
  u.core_users,
  u.core_users_pct,
  u.high_income_users,
  u.high_income_users_pct,

  -- ----------------------------------------------------------------------------
  -- 3. BLOQUE DE MÉTRICAS OPERATIVAS
  -- ----------------------------------------------------------------------------

  -- ===== 3.1) Seamless Delivery & Fallas (divididas por total_orders_fact_orders_all_status) =====
  COALESCE(sdm.seamless_delivery, 0)                                            AS seamless_orders,
  ROUND(SAFE_DIVIDE(COALESCE(sdm.seamless_delivery, 0), u.total_orders_fact_orders_all_status) * 100, 2) AS seamless_delivery_pct,

  COALESCE(sdm.rejected_orders, 0)                                              AS Fail_Rate,
  ROUND(SAFE_DIVIDE(COALESCE(sdm.rejected_orders, 0), u.total_orders_fact_orders_all_status) * 100, 2)   AS fail_rate_pct,

  COALESCE(sdm.forced_pre_orders, 0)                                            AS forced_pre_orders,
  ROUND(SAFE_DIVIDE(COALESCE(sdm.forced_pre_orders, 0), u.total_orders_fact_orders_all_status) * 100, 2) AS forced_pre_orders_pct,

  COALESCE(sdm.modified_orders, 0)                                              AS modified_orders,
  ROUND(SAFE_DIVIDE(COALESCE(sdm.modified_orders, 0), u.total_orders_fact_orders_all_status) * 100, 2)   AS modified_orders_pct,

  COALESCE(sdm.session_orders, 0)                                               AS session_orders,
  ROUND(SAFE_DIVIDE(COALESCE(sdm.session_orders, 0), u.total_orders_fact_orders_all_status) * 100, 2)    AS session_orders_pct,

  COALESCE(sdm.slow_orders, 0)                                                  AS slow_orders,
  ROUND(SAFE_DIVIDE(COALESCE(sdm.slow_orders, 0), u.total_orders_fact_orders_all_status) * 100, 2)       AS slow_orders_pct,

  COALESCE(sdm.order_late, 0)                                                   AS order_late,
  ROUND(SAFE_DIVIDE(COALESCE(sdm.order_late, 0), u.total_orders_fact_orders_all_status) * 100, 2)        AS order_late_pct,

  -- ===== 3.2) Pickers, Preparación y Asignación (qc_picker_shift_orders) =====
  COALESCE(picko.assignment_time, 0)                                            AS assignment_time,
  COALESCE(picko.picking_time, 0)                                               AS picking_time,
  COALESCE(picko.picker_shift_confirmed_orders, 0)                              AS picker_shift_confirmed_orders,
  COALESCE(picko.assignment_time_over_6min, 0)                                  AS assignment_time_over_6min,
  ROUND(SAFE_DIVIDE(COALESCE(picko.assignment_time_over_6min, 0), NULLIF(picko.picker_shift_confirmed_orders, 0)) * 100, 2) AS assignment_time_over_6min_pct,

  -- ===== 3.3) Logística y Calidad =====
  COALESCE(ld.avg_delivery_time_min, 0)                                         AS avg_delivery_time_min,
  COALESCE(ld.order_late_10_count, 0)                                           AS order_late_10_count,
  ROUND(SAFE_DIVIDE(COALESCE(ld.order_late_10_count, 0), u.total_orders) * 100, 1) AS pct_late_10,
  COALESCE(ld.total_awt_rider_minutes, 0)                                       AS total_awt_rider_minutes,
  COALESCE(id.complaint_orders, 0)                                              AS complaint_orders,
  ROUND(SAFE_DIVIDE(COALESCE(id.complaint_orders, 0), NULLIF(COALESCE(id.total_orders_inaccuracy, u.total_orders), 0)) * 100, 2) AS inaccuracy_rate_pct

FROM whs_transaccional_y_usuarios u

LEFT JOIN peya_coverage_users pu
  ON  u.warehouse_id = pu.warehouse_id
  AND u.month_date   = pu.month_date

LEFT JOIN seamless_data_monthly sdm
  ON  u.warehouse_id = sdm.warehouse_id
  AND u.month_date   = sdm.month_date

LEFT JOIN pickers_orders picko
  ON  u.warehouse_id = picko.warehouse_id
  AND u.month_date   = picko.month_date

LEFT JOIN ops_logistics ld
  ON  u.warehouse_id = ld.warehouse_id
  AND u.month_date   = ld.month_date

LEFT JOIN ops_inaccuracy id
  ON  u.warehouse_id = id.warehouse_id
  AND u.month_date   = id.month_date

ORDER BY
  u.month_date DESC,
  u.country,
  u.city,
  u.total_orders DESC;
