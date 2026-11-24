DECLARE query_name STRING DEFAULT '1. OPS Data - Base - OPS (Diario)';


-- ====================================================================================
-- TABLA CONECTADA: OPS Data Diario (Nivel País)
-- Fuente: `peya-food-and-groceries.automated_tables_reports.absolute_okrs_operaciones`
-- Destino / Uso:
--   - Google Sheets 'Update - OKRs Weekly 26 - Peya Market'
--   - Hoja origen: '2. TD - OPS Data - Diario'
--   - Hoja destino: '2 - OPS Data'
--   - Grain: (date, Country_en)
--   - Estructura 100% idéntica a ops_daily_data (41 columnas exactas)
-- ====================================================================================

SELECT
  -- ===== 0 y 1: Claves de dimensión =====
  date,
  Country_en,

  -- ===== 2 y 3: orders_data_agg (Cols 2-3 en Apps Script) =====
  SUM(total_orders_fact_orders)                AS total_orders_fact_orders,
  SUM(total_orders_fact_orders_all_status)     AS total_orders_fact_orders_all_status,

  -- ===== 4 al 10: seamless_data_daily (Cols 4-10 en Apps Script) =====
  SUM(seamless_orders)                         AS seamless_orders,
  SUM(Fail_Rate)                               AS Fail_Rate,
  SUM(forced_pre_orders)                       AS forced_pre_orders,
  SUM(modified_orders)                         AS modified_orders,
  SUM(session_orders)                          AS session_orders,
  SUM(slow_orders)                             AS slow_orders,
  SUM(order_late_ops)                          AS order_late_ops,

  -- ===== 11 al 14: pickers_orders (Cols 11-14 en Apps Script) =====
  SUM(picker_shift_confirmed_orders)           AS picker_shift_confirmed_orders,
  SUM(assignment_time)                         AS assignment_time,
  SUM(Saturation_orders_over_6min)             AS Saturation_orders_over_6min,
  SUM(picking_time)                            AS picking_time,

  -- ===== 15 al 20: delivery_time_agg (Cols 15-20 en Apps Script) =====
  SUM(non_forced_completed_orders_logistics)   AS non_forced_completed_orders_logistics,
  SUM(sum_delivery_time_min)                   AS sum_delivery_time_min,
  SUM(logistics_stacked_0)                     AS logistics_stacked_0,
  SUM(logistics_stacked_1)                     AS logistics_stacked_1,
  SUM(logistics_stacked_2)                     AS logistics_stacked_2,
  SUM(logistics_stacked_3_mas)                 AS logistics_stacked_3_mas,

  -- ===== 21 al 27: timings_data y logística (Cols 21-27 en Apps Script) =====
  SUM(Total_orders_timings)                    AS Total_orders_timings,
  SUM(Picked_items)                            AS Picked_items,
  SUM(total_picking_time_seconds)              AS total_picking_time_seconds,
  SUM(order_late_10_count)                     AS order_late_10_count,
  SUM(dt_35min_count)                          AS dt_35min_count,
  SUM(vendor_late_10_count)                    AS vendor_late_count,
  SUM(total_orders_logistics)                  AS vendor_late_deno,

  -- ===== 28 al 31: inaccuracy (Cols 28-31 en Apps Script) =====
  SUM(total_orders_inaccuracy)                 AS total_orders_inaccuracy,
  SUM(inaccuracy_orders)                       AS inaccuracy_orders,
  SUM(food_issue_orders)                       AS food_issue_orders,
  SUM(wrong_missing_item_orders)               AS wrong_missing_item_orders,

  -- ===== 32 al 37: productividad_data (Cols 32-37 en Apps Script) =====
  SUM(Helper_Total_Units)                      AS Helper_Total_Units,
  SUM(receiving_units)                         AS receiving_units,
  SUM(ajuste_utr)                              AS ajuste_utr,
  SUM(picker_working_hours)                    AS picker_working_hours,
  CAST(NULL AS FLOAT64)                        AS manager_working_hours,
  SUM(received_bags)                           AS received_bags,

  -- ===== 38 al 40: original_by_ops_diario (Cols 38-40 en Apps Script) =====
  SUM(Total_orders_ops)                        AS Total_orders_ops,
  SUM(partial_orders)                          AS partial_orders,
  SUM(lost_sessions)                           AS lost_sessions

FROM `peya-food-and-groceries.automated_tables_reports.absolute_okrs_operaciones`
WHERE Country_en IS NOT NULL
GROUP BY date, Country_en
ORDER BY date DESC, Country_en ASC;
