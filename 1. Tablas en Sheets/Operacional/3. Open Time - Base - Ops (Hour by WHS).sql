DECLARE query_name STRING DEFAULT '3. Open Time - Base - Ops (Hour by WHS)';

-- ====================================================================================
-- PROPÓSITO: Consulta directa sobre la tabla automatizada 'wot_hour_by_whs'
--            filtrada de manera 100% dinámica para el ÚLTIMO MES CERRADO.
-- APROVECHA: Particionamiento por 'fecha' (pruning de particiones) y clustering.
-- ====================================================================================

-- 1. Determinación dinámica del primer y último día del mes cerrado previo
DECLARE inicio DATE DEFAULT DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH);
DECLARE fin    DATE DEFAULT LAST_DAY(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH));

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