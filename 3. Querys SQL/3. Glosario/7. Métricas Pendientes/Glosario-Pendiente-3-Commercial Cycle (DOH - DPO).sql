DECLARE query_name STRING DEFAULT 'Glosario-Pendiente-3-Commercial Cycle (DOH - DPO)';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET (PENDIENTE DE AUTOMATIZACIÓN)
-- ====================================================================================
-- Métrica Nº:      P-3
-- Nombre:          Commercial Cycle (DOH - DPO)
-- Chapter:         Sustainability
-- Estado:          PENDIENTE (No calculada en Apps Script)
-- Sheets Name: 1. TD - OKRs Mensual (0 - Orders)
-- Sheets Link: https://docs.google.com/spreadsheets/d/13yTO_kFzIvISmbSz6p93BFUub1HODpuiGhB3yElZ2fw
-- Motivo:          Esta métrica figura en la grilla mensual/reporte pero no está automatizada en Apps Script.
-- Descripción:     Ciclo comercial de días de stock menos días de pago (métrica estructural).
-- ====================================================================================

-- QUERY PENDIENTE DE DEFINICIÓN / DESARROLLO EN BIGQUERY
SELECT
  'PENDIENTE' AS estado_metrica,
  'Commercial Cycle (DOH - DPO)' AS metrica,
  'Sustainability' AS chapter,
  'Esta métrica no cuenta con cálculo en Apps Script (Code.gs). Requiere definición de query SQL.' AS observacion,
  DATE('2026-09-01') AS mes_objetivo;
