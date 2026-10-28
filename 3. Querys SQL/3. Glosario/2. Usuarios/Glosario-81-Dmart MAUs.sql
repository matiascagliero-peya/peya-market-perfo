DECLARE query_name STRING DEFAULT 'Glosario-81-Dmart MAUs';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Nombre:     Dmart MAUs
-- Chapter:    Usuarios
-- Query bajada en: 4 - Users (Users Type Count)
-- Sheets Name: 1. ET - Users Type Count (4 - Users)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1X0bnsCoDszeSlq5TT1uw20GWtcfu1iBpshXXI1QIv7M
-- Tablas de origen: `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(users_count) WHERE business = 'Market'
-- Definición: Total de usuarios activos únicos mensuales en PeYa Market (Darkstores) con al menos una orden confirmada en el mes.
-- ====================================================================================

SELECT
  CASE country 
    WHEN 'Panama' THEN 'Panamá'
    WHEN 'Peru' THEN 'Perú'
    WHEN 'Dominican Republic' THEN 'República Dominicana'
    ELSE country 
  END AS country,
  Mes AS month,
  SUM(users_count) AS dmart_maus
FROM `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
WHERE Mes = '2026-09-01'
  AND country NOT IN ('Venezuela', 'Costa Rica')
  AND business = 'Market'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+------------+-------+
-- | country              | dmart_maus | month |
-- +----------------------+------------+-------+
-- | Argentina            | 12.843.552 | 2.026 |
-- | Bolivia              |  2.028.221 | 2.026 |
-- | Chile                |  6.480.956 | 2.026 |
-- | Ecuador              |  2.537.614 | 2.026 |
-- | El Salvador          |  1.318.553 | 2.026 |
-- | Guatemala            |  1.590.273 | 2.026 |
-- | Honduras             |    867.508 | 2.026 |
-- | Nicaragua            |    850.293 | 2.026 |
-- | Panam�               |  1.462.693 | 2.026 |
-- | Paraguay             |  1.189.722 | 2.026 |
-- | Per�                 |  4.540.752 | 2.026 |
-- | Rep�blica Dominicana |  1.988.765 | 2.026 |
-- | Uruguay              |  1.144.622 | 2.026 |
-- +----------------------+------------+-------+
