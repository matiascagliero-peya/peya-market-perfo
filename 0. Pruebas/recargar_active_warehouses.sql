-- ====================================================================================
-- PROPÓSITO: Recargar / Actualizar masivamente el conteo de almacenes activos 
--            (active_warehouses_count) en dmart_okrs_daily usando ÚNICAMENTE 
--            la tabla de órdenes (fact_orders) y su dimensión nativa (dim_partner).
-- TABLA DESTINO: peya-food-and-groceries.automated_tables_reports.dmart_okrs_daily
-- RANGO: 2025-01-01 hasta ayer (particionado).
-- GRAIN: (day, country_name)
-- ====================================================================================

-- 1. Declaración de ventana temporal
DECLARE from_date DATE DEFAULT '2025-01-01';
DECLARE to_date   DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);

-- 2. Actualización directa desde fact_orders
UPDATE `peya-food-and-groceries.automated_tables_reports.dmart_okrs_daily` target
SET target.active_warehouses_count = COALESCE(source.active_warehouses, 0)
FROM (
  SELECT
    DATE(fo.registered_date)        AS day,
    fo.country.country_name         AS country_name,
    COUNT(DISTINCT dp.warehouse_id) AS active_warehouses
  FROM `peya-bi-tools-pro.il_core.fact_orders` fo
  INNER JOIN `peya-bi-tools-pro.il_core.dim_partner` dp
    ON fo.restaurant.id = dp.partner_id
  WHERE DATE(fo.registered_date) BETWEEN from_date AND to_date
    AND fo.order_status = 'CONFIRMED'
    AND dp.is_darkstore = TRUE
    AND dp.warehouse_id IS NOT NULL
    AND dp.partner_name NOT IN (
      'RD_12_Torre OV', 'PA_9_Midtown', 'SV_6_Torre Futura',
      'EC_17_TiendaPick-Up Oficina', 'PE_3_PuntaHermosa', 'BO_19_Truck',
      'UY_15_Eventos', 'PE_24_FILO', 'EC_6_Oficina'
    )
  GROUP BY 1, 2
) source
WHERE target.day BETWEEN from_date AND to_date
  AND target.day = source.day
  AND target.country_name = source.country_name;
