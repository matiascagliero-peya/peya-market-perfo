DECLARE query_name STRING DEFAULT '3. Open Time - Base - Ops (Hour by WHS)';

-- ====================================================================================
-- PROPÓSITO: Consulta directa sobre la tabla automatizada 'wot_hour_by_whs'

-- 1. Fechas fijadas para todo Septiembre 2026
DECLARE inicio DATE DEFAULT DATE '2026-09-01';
DECLARE fin    DATE DEFAULT DATE '2026-09-30';

-- 2. Consulta de los registros horarios por warehouse
SELECT
  fecha,
  hora,
  warehouse_id,
  warehouse_name,
  pais,
  ciudad,
  minutos_programados,
  minutos_cerrados_efectivos,
  share_disponibilidad_hora,
  peso_trafico_hora,
  disponibilidad_ponderada_hora
FROM `peya-food-and-groceries.automated_tables_reports.wot_hour_by_whs`
WHERE fecha BETWEEN inicio AND fin
ORDER BY fecha DESC, warehouse_id, hora;