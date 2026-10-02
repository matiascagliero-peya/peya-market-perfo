DECLARE query_name STRING DEFAULT '11. Daily Alerts - Peya Market (WHS all Data)';

-- Verificación diaria del estado de carga de la tabla de seamless.
-- Cuando la tabla de seamless se actualiza tarde, el LEFT JOIN de la base diaria
-- genera que seamless_delivery sea igual a total_orders_all_status (100% seamless artificial y 0 defectos).
-- Si para un día el 50% o más de los almacenes tienen seamless_delivery = total_orders_all_status,
-- anulamos (NULL) únicamente las métricas provenientes de esa tabla para esa fecha (dejando total_orders_all_status intacto).

WITH daily_seamless_check AS (
  SELECT
    fecha,
    (
      SAFE_DIVIDE(
        COUNTIF(seamless_delivery = total_orders_all_status AND total_orders_all_status > 0),
        COUNTIF(total_orders_all_status > 0)
      ) >= 0.5
    ) AS is_seamless_not_updated
  FROM `peya-food-and-groceries.automated_tables_reports.dmart_metrics_by_whs_daily`
  GROUP BY fecha
)

SELECT 
  d.* REPLACE (
    IF(COALESCE(c.is_seamless_not_updated, FALSE), CAST(NULL AS INT64), d.seamless_delivery) AS seamless_delivery,
    IF(COALESCE(c.is_seamless_not_updated, FALSE), CAST(NULL AS INT64), d.late_orders)       AS late_orders,
    IF(COALESCE(c.is_seamless_not_updated, FALSE), CAST(NULL AS INT64), d.slow_orders)       AS slow_orders,
    IF(COALESCE(c.is_seamless_not_updated, FALSE), CAST(NULL AS INT64), d.rejected_orders)   AS rejected_orders,
    IF(COALESCE(c.is_seamless_not_updated, FALSE), CAST(NULL AS INT64), d.session_orders)    AS session_orders,
    IF(COALESCE(c.is_seamless_not_updated, FALSE), CAST(NULL AS INT64), d.forced_preorders)  AS forced_preorders,
    IF(COALESCE(c.is_seamless_not_updated, FALSE), CAST(NULL AS INT64), d.modified_orders)   AS modified_orders
  )
FROM `peya-food-and-groceries.automated_tables_reports.dmart_metrics_by_whs_daily` d
LEFT JOIN daily_seamless_check c
  ON d.fecha = c.fecha
ORDER BY 
  d.fecha DESC, 
  d.country_code ASC, 
  d.warehouse_name ASC;