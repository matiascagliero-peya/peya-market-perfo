DECLARE query_name STRING DEFAULT 'Glosario-85-Reorder Users - Dmart';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Nombre:     Reorder Users - Dmart
-- Chapter:    Usuarios
-- Query bajada en: 4 - Users (Users Type Count)
-- Sheets Name: 1. ET - Users Type Count (4 - Users)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1X0bnsCoDszeSlq5TT1uw20GWtcfu1iBpshXXI1QIv7M
-- Tablas de origen: `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(users_count) WHERE business = 'Market' AND l1 = 'Re-Order'
-- Definición: Estado L1 = Re-Order (PeYa Market). Consolidación de frecuencia: clientes en su segundo mes consecutivo de compra tras reactivarse. Desglose L2: Re-Order Occasional, Re-Order Warm, Re-Order True, Re-Order DY y Re-Order DY Converted.
-- ====================================================================================

SELECT
  CASE country 
    WHEN 'Panama' THEN 'Panamá'
    WHEN 'Peru' THEN 'Perú'
    WHEN 'Dominican Republic' THEN 'República Dominicana'
    ELSE country 
  END AS country,
  Mes AS month,
  SUM(users_count) AS reorder_users_dmart
FROM `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
WHERE Mes = '2026-09-01'
  AND country NOT IN ('Venezuela', 'Costa Rica')
  AND business = 'Market' AND l1 = 'Re-Order'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------+---------------------+
-- | country              | month | reorder_users_dmart |
-- +----------------------+-------+---------------------+
-- | Argentina            | 2.026 |             115.586 |
-- | Bolivia              | 2.026 |               6.629 |
-- | Chile                | 2.026 |              17.364 |
-- | Ecuador              | 2.026 |               5.418 |
-- | El Salvador          | 2.026 |               4.244 |
-- | Guatemala            | 2.026 |               4.470 |
-- | Honduras             | 2.026 |               2.665 |
-- | Nicaragua            | 2.026 |               2.839 |
-- | Panam�               | 2.026 |               5.229 |
-- | Paraguay             | 2.026 |               6.047 |
-- | Per�                 | 2.026 |              12.056 |
-- | Rep�blica Dominicana | 2.026 |               8.750 |
-- | Uruguay              | 2.026 |              10.311 |
-- +----------------------+-------+---------------------+
