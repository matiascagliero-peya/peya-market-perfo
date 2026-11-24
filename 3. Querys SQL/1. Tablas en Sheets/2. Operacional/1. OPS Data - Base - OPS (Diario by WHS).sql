DECLARE query_name STRING DEFAULT '1. OPS Data - Base - OPS (Diario by WHS)';

-- ====================================================================================
-- TABLA CONECTADA: OPS Data Diario (Nivel Warehouse)
-- Fuente: `peya-food-and-groceries.automated_tables_reports.absolute_okrs_operaciones`
-- Destino / Uso:
--   - Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo/edit?gid=732052340#gid=732052340
--   - Hoja / Pestaña: 3. ET - Ops Data - Diario by WHS
--   - Grain: (date, warehouse_id)
--   - Rango: 2026 a la fecha (Consumo ultra bajo: ~19.7 MB)
-- ====================================================================================

SELECT *
FROM `peya-food-and-groceries.automated_tables_reports.absolute_okrs_operaciones`
WHERE date >= '2026-01-01'
ORDER BY date DESC, Country_en ASC, warehouse_name ASC;
