DECLARE query_name STRING DEFAULT 'Glosario-Pendiente-271-Front Margin %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET (PENDIENTE DE AUTOMATIZACIÓN)
-- ====================================================================================
-- Métrica Nº:      P-271
-- Nombre:          Front Margin %
-- Chapter:         Sustainability
-- Estado:          PENDIENTE (Fuente 16 - Analitycs)
-- Sheets Name:     1. IT - Analitycs (16 - Analitycs)
-- Sheets Link:     https://docs.google.com/spreadsheets/d/1MeXHCeDGOkS7WIztOeWAD1WkwvuFOW_Mr-d1zdnoYww
-- Motivo:          Métrica financiera proveniente de hoja 16 - Analitycs / P&L Forecast trasladada a Pendientes.
-- Fórmula:    Front Margin / Net Sales
-- Definición: Porcentaje de margen frontal directo sobre las ventas netas de PeYa Market.
-- ====================================================================================

-- QUERY PENDIENTE DE DEFINICIÓN / DESARROLLO EN BIGQUERY
SELECT
  'PENDIENTE' AS estado_metrica,
  'Front Margin %' AS metrica,
  'Sustainability' AS chapter,
  'Métrica proveniente de 1. IT - Analitycs (16 - Analitycs) trasladada a pendientes.' AS observacion,
  DATE('2026-09-01') AS mes_objetivo;
