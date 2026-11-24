DECLARE query_name STRING DEFAULT 'Glosario-66-PeYa MAUs';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Nombre:     PeYa MAUs
-- Chapter:    Usuarios
-- Query bajada en: 4 - Users (Users Type Count)
-- Sheets Name: 1. ET - Users Type Count (4 - Users)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1X0bnsCoDszeSlq5TT1uw20GWtcfu1iBpshXXI1QIv7M
-- Tablas de origen: `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(users_count) WHERE business = 'AAA'
-- Definición: Total de usuarios activos únicos mensuales en la plataforma PedidosYa con al menos una orden confirmada en el mes.
-- ====================================================================================

SELECT
  CASE country 
    WHEN 'Panama' THEN 'Panamá'
    WHEN 'Peru' THEN 'Perú'
    WHEN 'Dominican Republic' THEN 'República Dominicana'
    ELSE country 
  END AS country,
  Mes AS month,
  SUM(users_count) AS peya_maus
FROM `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
WHERE Mes = '2026-09-01'
  AND country NOT IN ('Venezuela', 'Costa Rica')
  AND business = 'AAA'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------+------------+
-- | country              | month | peya_maus  |
-- +----------------------+-------+------------+
-- | Argentina            | 2.026 | 12.843.552 |
-- | Bolivia              | 2.026 |  2.028.221 |
-- | Chile                | 2.026 |  6.480.956 |
-- | Ecuador              | 2.026 |  2.537.614 |
-- | El Salvador          | 2.026 |  1.318.553 |
-- | Guatemala            | 2.026 |  1.590.273 |
-- | Honduras             | 2.026 |    867.508 |
-- | Nicaragua            | 2.026 |    850.293 |
-- | Panam�               | 2.026 |  1.462.693 |
-- | Paraguay             | 2.026 |  1.189.722 |
-- | Per�                 | 2.026 |  4.540.752 |
-- | Rep�blica Dominicana | 2.026 |  1.988.765 |
-- | Uruguay              | 2.026 |  1.144.622 |
-- +----------------------+-------+------------+
