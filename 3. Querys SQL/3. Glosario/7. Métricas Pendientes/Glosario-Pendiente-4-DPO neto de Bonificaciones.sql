DECLARE query_name STRING DEFAULT 'Glosario-Pendiente-4-DPO neto de Bonificaciones';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET (PENDIENTE DE AUTOMATIZACIÓN)
-- ====================================================================================
-- Métrica Nº:      P-4
-- Nombre:          DPO neto de Bonificaciones
-- Chapter:         Sustainability
-- Estado:          PENDIENTE (No calculada en Apps Script)
-- Sheets Name: 1. TD - OKRs Mensual (0 - Orders)
-- Sheets Link: https://docs.google.com/spreadsheets/d/13yTO_kFzIvISmbSz6p93BFUub1HODpuiGhB3yElZ2fw
-- Motivo:          Esta métrica figura en la grilla mensual/reporte pero no está automatizada en Apps Script.
-- Descripción:     Días de pago a proveedores ajustado por bonificaciones (reporte manual).
-- ====================================================================================

-- QUERY PENDIENTE DE DEFINICIÓN / DESARROLLO EN BIGQUERY
SELECT
  'PENDIENTE' AS estado_metrica,
  'DPO neto de Bonificaciones' AS metrica,
  'Sustainability' AS chapter,
  'Esta métrica no cuenta con cálculo en Apps Script (Code.gs). Requiere definición de query SQL.' AS observacion,
  DATE('2026-09-01') AS mes_objetivo;
