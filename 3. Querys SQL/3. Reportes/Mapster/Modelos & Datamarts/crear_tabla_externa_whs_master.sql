-- ==============================================================================
-- DDL: CREACIÓN DE TABLA EXTERNA CONECTADA A GOOGLE SHEETS
--
-- Objetivo: Conectar BigQuery en tiempo real a la pestaña "1. WHS data"
--           del spreadsheet maestro de Darkstores / Warehouses.
--
-- Spreadsheet URL: 
--   https://docs.google.com/spreadsheets/d/1DXcZswpGQsbXcj5RXBALAogLrs32d_rtcxpRb17nROk/edit?gid=1805962870#gid=1805962870
-- Pestaña: "1. WHS data"
-- Generada desde: dim_warehouse_all_partners_master.sql
-- ==============================================================================

CREATE OR REPLACE EXTERNAL TABLE `peya-food-and-groceries.automated_tables_reports.ext_dim_warehouse_master`
OPTIONS (
  format = 'GOOGLE_SHEETS',
  uris = ['https://docs.google.com/spreadsheets/d/1DXcZswpGQsbXcj5RXBALAogLrs32d_rtcxpRb17nROk/edit'],
  sheet_range = '1. WHS data',
  skip_leading_rows = 1
);

-- ==============================================================================
-- VERIFICACIÓN: Consulta de prueba para comprobar la conexión con Google Sheets
-- ==============================================================================
SELECT 
  month_date,
  warehouse_id,
  warehouse_name,
  country,
  country_code,
  city,
  is_active,
  main_partner_id,
  main_partner_name,
  store_lat,
  store_lng
FROM `peya-food-and-groceries.automated_tables_reports.ext_dim_warehouse_master`
WHERE warehouse_id IS NOT NULL
ORDER BY country, city, warehouse_name;
