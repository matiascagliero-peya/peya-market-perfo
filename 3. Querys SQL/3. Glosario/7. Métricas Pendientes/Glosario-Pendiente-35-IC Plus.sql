DECLARE query_name STRING DEFAULT 'Glosario-Pendiente-35-IC Plus';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET (PENDIENTE DE AUTOMATIZACIÓN)
-- ====================================================================================
-- Métrica Nº:      P-35
-- Nombre:          IC Plus
-- Chapter:         Otros
-- Estado:          PENDIENTE (No calculada en Apps Script)
-- Sheets Name: 1. TD - OKRs Mensual (0 - Orders)
-- Sheets Link: https://docs.google.com/spreadsheets/d/13yTO_kFzIvISmbSz6p93BFUub1HODpuiGhB3yElZ2fw
-- Motivo:          Esta métrica figura en la grilla mensual/reporte pero no está automatizada en Apps Script.
-- Descripción:     Beneficio intercompany o costo marginal de usuarios Plus.
-- ====================================================================================

-- QUERY PENDIENTE DE DEFINICIÓN / DESARROLLO EN BIGQUERY
SELECT
  'PENDIENTE' AS estado_metrica,
  'IC Plus' AS metrica,
  'Otros' AS chapter,
  'Esta métrica no cuenta con cálculo en Apps Script (Code.gs). Requiere definición de query SQL.' AS observacion,
  DATE('2026-09-01') AS mes_objetivo;
