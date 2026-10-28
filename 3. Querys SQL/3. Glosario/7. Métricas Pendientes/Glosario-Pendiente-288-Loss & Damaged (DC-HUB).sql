DECLARE query_name STRING DEFAULT 'Glosario-Pendiente-288-Loss & Damaged (DC/HUB)';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET (PENDIENTE DE AUTOMATIZACIÓN)
-- ====================================================================================
-- Métrica Nº:      P-288
-- Nombre:          Loss & Damaged (DC/HUB)
-- Chapter:         Sustainability
-- Estado:          PENDIENTE (Fuente 16 - Analitycs)
-- Sheets Name:     1. IT - Analitycs (16 - Analitycs)
-- Sheets Link:     https://docs.google.com/spreadsheets/d/1MeXHCeDGOkS7WIztOeWAD1WkwvuFOW_Mr-d1zdnoYww
-- Motivo:          Métrica financiera proveniente de hoja 16 - Analitycs / P&L Forecast trasladada a Pendientes.
-- Fórmula:    Pérdidas y daños en centros de distribución / hubs en EUR
-- Definición: Pérdidas y roturas de mercadería originadas en centros de distribución y depósitos centrales antes de llegar a las tiendas en euros.
-- ====================================================================================

-- QUERY PENDIENTE DE DEFINICIÓN / DESARROLLO EN BIGQUERY
SELECT
  'PENDIENTE' AS estado_metrica,
  'Loss & Damaged (DC/HUB)' AS metrica,
  'Sustainability' AS chapter,
  'Métrica proveniente de 1. IT - Analitycs (16 - Analitycs) trasladada a pendientes.' AS observacion,
  DATE('2026-09-01') AS mes_objetivo;
