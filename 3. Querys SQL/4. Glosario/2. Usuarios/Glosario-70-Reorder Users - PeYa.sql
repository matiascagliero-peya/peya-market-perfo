DECLARE query_name STRING DEFAULT 'Glosario-70-Reorder Users - PeYa';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Nombre:     Reorder Users - PeYa
-- Chapter:    Usuarios
-- Query bajada en: 4 - Users (Users Type Count)
-- Sheets Name: 1. ET - Users Type Count (4 - Users)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1X0bnsCoDszeSlq5TT1uw20GWtcfu1iBpshXXI1QIv7M
-- Tablas de origen: `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(users_count) WHERE business = 'AAA' AND l1 = 'Re-Order'
-- Definición: Estado L1 = Re-Order (Plataforma). Consolidación de hábito: usuarios que realizan su segundo mes de compra tras haberse reactivado. Desglose L2: Re-Order Occasional, Re-Order Warm, Re-Order True, Re-Order DY y Re-Order DY Converted.
-- ====================================================================================

SELECT
  CASE country 
    WHEN 'Panama' THEN 'Panamá'
    WHEN 'Peru' THEN 'Perú'
    WHEN 'Dominican Republic' THEN 'República Dominicana'
    ELSE country 
  END AS country,
  Mes AS month,
  SUM(users_count) AS reorder_users_peya
FROM `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
WHERE Mes = '2026-09-01'
  AND country NOT IN ('Venezuela', 'Costa Rica')
  AND business = 'AAA' AND l1 = 'Re-Order'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------+--------------------+
-- | country              | month | reorder_users_peya |
-- +----------------------+-------+--------------------+
-- | Argentina            | 2.026 |             46.810 |
-- | Bolivia              | 2.026 |                691 |
-- | Chile                | 2.026 |                458 |
-- | Ecuador              | 2.026 |              3.448 |
-- | Guatemala            | 2.026 |              3.970 |
-- | Honduras             | 2.026 |              1.794 |
-- | Nicaragua            | 2.026 |              1.111 |
-- | Panam�               | 2.026 |              4.712 |
-- | Paraguay             | 2.026 |              1.810 |
-- | Per�                 | 2.026 |              2.021 |
-- | Rep�blica Dominicana | 2.026 |              6.798 |
-- | Uruguay              | 2.026 |              2.843 |
-- +----------------------+-------+--------------------+
