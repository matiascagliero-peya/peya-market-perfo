DECLARE query_name STRING DEFAULT 'market_okr_6_okrs_daily_view';

-- ============================================================
-- markets_okrs_daily_view
-- Vista consolidada que une las 5 tablas y calcula métricas derivadas
-- Grain: fecha_completa + country_name + warehouse_id
-- ============================================================

CREATE OR REPLACE VIEW `peya-food-and-groceries.automated_tables_reports.markets_okrs_daily_view` AS

SELECT
  -- Clave
  ord.fecha_completa,
  ord.country_name,
  ord.warehouse_id,
  ord.warehouse_name,

  -- ── Orders & Revenue (markets_orders_revenue_daily) ──────────────────────
  ord.confirmed_orders,
  ord.failed_orders,
  ord.units_sold,
  ord.plus_orders,
  ord.total_platform_confirmed_orders,
  ord.dmart_new_users,
  ord.uf_orders,
  ord.double_ya_orders,
  ord.small_order_fee_orders,

  -- GMV
  ord.gmv_vendor_dmarts,
  ord.gmv_vendor_total,
  ord.gmv_user_dmarts,
  ord.gmv_user_total,

  -- Revenue / Fees
  ord.discount_amount_eu,
  ord.df_revenue_eu,
  ord.sf_revenue_eu,
  ord.revenue_fee_eu,
  ord.df_net_eu,
  ord.sf_net_eu,
  ord.rf_net_eu,
  ord.discount_plus_net_eu,

  -- Vouchers
  ord.df0_orders,
  ord.voucher_orders,
  ord.incentivized_orders,
  ord.voucher_amount,

  -- Net Sales
  ord.net_sales_eu,
  ord.discounts_eu,
  ord.units_excl_dy_sof,
  ord.net_sales_excl_dy_sof_eu,

  -- Métricas derivadas de Orders
  SAFE_DIVIDE(ord.net_sales_eu, ord.confirmed_orders)                             AS basket_size,
  SAFE_DIVIDE(ord.net_sales_excl_dy_sof_eu, ord.units_excl_dy_sof)               AS basket_size_excl_dy_sof,

  -- ── Users (markets_users_daily) ──────────────────────────────────────────
  usr.active_warehouses,
  usr.dau_peya,
  usr.dau_dmart,
  usr.dau_dmart_plus,
  usr.wau_peya,
  usr.wau_dmart,
  usr.wau_dmart_plus,
  usr.mau_peya,
  usr.mau_dmart,
  usr.mau_dmart_plus,

  -- ── Sessions (markets_sessions_daily) ────────────────────────────────────
  ses.sessions,
  ses.transactions,
  ses.sessions_non_dy,
  ses.transactions_non_dy,
  ses.uf_orders       AS uf_orders_sessions,
  ses.double_ya_orders AS double_ya_orders_sessions,

  -- Conversión
  SAFE_DIVIDE(ses.transactions, ses.sessions)             AS conversion_rate,
  SAFE_DIVIDE(ses.transactions_non_dy, ses.sessions_non_dy) AS conversion_rate_non_dy,

  -- ── Supply (markets_supply_daily) ────────────────────────────────────────
  sup.wis_numerador,
  sup.wis_denominador,
  sup.wis_uf_numerador,
  sup.wis_uf_denominador,
  SAFE_DIVIDE(sup.wis_numerador,    sup.wis_denominador)    AS wis_pct,
  SAFE_DIVIDE(sup.wis_uf_numerador, sup.wis_uf_denominador) AS wis_uf_pct,

  -- ── Ops (markets_ops_daily) ──────────────────────────────────────────────
  ops.dmarts_cpo,
  ops.dmart_orders_cpo,
  ops.platform_cpo,
  ops.courier_cpo,
  ops.platform_orders_excl_dmarts,

  -- Seamless
  ops.seamless_numerador,
  ops.total_seamless_base_orders,
  SAFE_DIVIDE(ops.seamless_numerador, ops.total_seamless_base_orders) AS seamless_delivery_pct,

  -- Fulfillment
  ops.late_orders,
  ops.slow_orders,
  ops.session_orders,
  ops.forced_preorders,
  ops.modified_orders,

  -- Tiempos (sums para posibles re-agregaciones + promedios listos para consumo)
  ops.delivery_time_sum,
  ops.delivery_time_order_count,
  SAFE_DIVIDE(ops.delivery_time_sum,    ops.delivery_time_order_count)    AS delivery_time_avg,
  ops.assignment_time_sum,
  ops.assignment_time_order_count,
  SAFE_DIVIDE(ops.assignment_time_sum,  ops.assignment_time_order_count)  AS assignment_time_avg

FROM `peya-food-and-groceries.automated_tables_reports.markets_orders_revenue_daily` ord

-- Users: join country-level (sin warehouse_id)
LEFT JOIN `peya-food-and-groceries.automated_tables_reports.markets_users_daily` usr
  ON  usr.fecha_completa = ord.fecha_completa
  AND usr.country_name   = ord.country_name

-- Sessions: join warehouse-level
LEFT JOIN `peya-food-and-groceries.automated_tables_reports.markets_sessions_daily` ses
  ON  ses.fecha_completa = ord.fecha_completa
  AND ses.country_name   = ord.country_name
  AND ses.warehouse_id   = ord.warehouse_id

-- Supply: join warehouse-level (la tabla supply no tiene country, se resuelve por warehouse)
LEFT JOIN `peya-food-and-groceries.automated_tables_reports.markets_supply_daily` sup
  ON  sup.fecha_completa = ord.fecha_completa
  AND sup.warehouse_id   = ord.warehouse_id

-- Ops: join warehouse + country level
LEFT JOIN `peya-food-and-groceries.automated_tables_reports.markets_ops_daily` ops
  ON  ops.fecha_completa = ord.fecha_completa
  AND ops.country_name   = ord.country_name
  AND ops.warehouse_id   = ord.warehouse_id;


-- ============================================================
-- markets_okrs_vertical_view  (UNPIVOT — solo cambia el FROM)
-- Reemplazar en la vista existente:
--   FROM `...markets_orders_okrs_daily`
--   → FROM `...markets_okrs_daily_view`
-- El resto del UNPIVOT se mantiene igual.
-- ============================================================
