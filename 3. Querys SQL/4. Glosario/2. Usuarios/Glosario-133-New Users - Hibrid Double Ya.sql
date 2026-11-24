DECLARE query_name STRING DEFAULT 'Glosario-133-New Users - Hibrid Double Ya';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Nombre:     New Users - Hibrid Double Ya
-- Chapter:    Usuarios
-- Query bajada en: 4 - Users (Users Type Count)
-- Sheets Name: 1. ET - Users Type Count (4 - Users)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1X0bnsCoDszeSlq5TT1uw20GWtcfu1iBpshXXI1QIv7M
-- Tablas de origen: `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(users_count) WHERE business = 'Market' AND l1 = 'New User' AND DY = 'DY y No DY'
-- Definición: Estado L1 = New User Híbrido: Nuevos clientes que en su primer mes de adopción realizaron compras combinadas con y sin Double Ya.
-- ====================================================================================

SELECT
  CASE country 
    WHEN 'Panama' THEN 'Panamá'
    WHEN 'Peru' THEN 'Perú'
    WHEN 'Dominican Republic' THEN 'República Dominicana'
    ELSE country 
  END AS country,
  Mes AS month,
  SUM(users_count) AS new_users_hibrid_dy
FROM `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
WHERE Mes = '2026-09-01'
  AND country NOT IN ('Venezuela', 'Costa Rica')
  AND business = 'Market' AND l1 = 'New User' AND DY = 'DY y No DY'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------+---------------------+
-- | country              | month | new_users_hibrid_dy |
-- +----------------------+-------+---------------------+
-- | Argentina            | 2.026 |               1.778 |
-- | Chile                | 2.026 |                 135 |
-- | Ecuador              | 2.026 |                 214 |
-- | El Salvador          | 2.026 |                 150 |
-- | Guatemala            | 2.026 |                 131 |
-- | Honduras             | 2.026 |                 270 |
-- | Nicaragua            | 2.026 |                 102 |
-- | Paraguay             | 2.026 |                 253 |
-- | Rep�blica Dominicana | 2.026 |                 291 |
-- | Uruguay              | 2.026 |                  91 |
-- +----------------------+-------+---------------------+
