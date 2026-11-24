DECLARE query_name STRING DEFAULT 'Glosario-Pendiente-183-F&UF Net Sales Participation';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET (PENDIENTE DE AUTOMATIZACIÓN)
-- ====================================================================================
-- Métrica Nº:      P-183
-- Nombre:          F&UF Net Sales Participation
-- Chapter:         Assortment, Pricing & Promo
-- Estado:          PENDIENTE (Fuente externa sin query directa)
-- Sheets Name:     A. TI - SC Data - Monthly / Price Index
-- Sheets Link:     https://docs.google.com/spreadsheets/d/1aCrgEjh6qT5T8ayT2H22r3iNc55nAR1O9vaOCW6pRBs
-- Motivo:          Métrica proveniente de hojas de carga manual / TI de Supply trasladada a Pendientes por directiva de usuario.
-- ====================================================================================

-- QUERY PENDIENTE DE DEFINICIÓN / DESARROLLO EN BIGQUERY
SELECT
  'PENDIENTE' AS estado_metrica,
  'F&UF Net Sales Participation' AS metrica,
  'Assortment, Pricing & Promo' AS chapter,
  'Métrica proveniente de fuente externa de Supply Chain / Price Index trasladada a pendientes.' AS observacion,
  DATE('2026-09-01') AS mes_objetivo;
