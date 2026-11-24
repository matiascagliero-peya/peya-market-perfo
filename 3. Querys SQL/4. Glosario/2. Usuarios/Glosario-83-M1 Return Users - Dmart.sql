DECLARE query_name STRING DEFAULT 'Glosario-83-M1 Return Users - Dmart';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Nombre:     M1 Return Users - Dmart
-- Chapter:    Usuarios
-- Query bajada en: 4 - Users (Users Type Count)
-- Sheets Name: 1. ET - Users Type Count (4 - Users)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1X0bnsCoDszeSlq5TT1uw20GWtcfu1iBpshXXI1QIv7M
-- Tablas de origen: `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(users_count) WHERE business = 'Market' AND l1 = 'M1 Return'
-- Definición: Estado L1 = M1 Return (PeYa Market). Retención orgánica de primer mes en Darkstores (compra en M-1 y compra en M). Desglose L2: M1 Return Users - Dmart (retención directa), M1 Dmart DY (repite con DY) y M1 Dmart DY Converted (convierte a compra completa sin DY).
-- ====================================================================================

SELECT
  CASE country 
    WHEN 'Panama' THEN 'Panamá'
    WHEN 'Peru' THEN 'Perú'
    WHEN 'Dominican Republic' THEN 'República Dominicana'
    ELSE country 
  END AS country,
  Mes AS month,
  SUM(users_count) AS m1_return_users_dmart
FROM `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
WHERE Mes = '2026-09-01'
  AND country NOT IN ('Venezuela', 'Costa Rica')
  AND business = 'Market' AND l1 = 'M1 Return'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-----------------------+-------+
-- | country              | m1_return_users_dmart | month |
-- +----------------------+-----------------------+-------+
-- | Argentina            |                29.161 | 2.026 |
-- | Bolivia              |                 2.385 | 2.026 |
-- | Chile                |                 4.551 | 2.026 |
-- | Ecuador              |                 1.859 | 2.026 |
-- | El Salvador          |                 1.043 | 2.026 |
-- | Guatemala            |                   936 | 2.026 |
-- | Honduras             |                 1.668 | 2.026 |
-- | Nicaragua            |                   781 | 2.026 |
-- | Panam�               |                   861 | 2.026 |
-- | Paraguay             |                 1.504 | 2.026 |
-- | Per�                 |                 3.496 | 2.026 |
-- | Rep�blica Dominicana |                 2.211 | 2.026 |
-- | Uruguay              |                 1.355 | 2.026 |
-- +----------------------+-----------------------+-------+
