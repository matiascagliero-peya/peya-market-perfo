DECLARE query_name STRING DEFAULT 'Glosario-67-New Users - PeYa';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Nombre:     New Users - PeYa
-- Chapter:    Usuarios
-- Query bajada en: 4 - Users (Users Type Count)
-- Sheets Name: 1. ET - Users Type Count (4 - Users)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1X0bnsCoDszeSlq5TT1uw20GWtcfu1iBpshXXI1QIv7M
-- Tablas de origen: `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(users_count) WHERE business = 'AAA' AND l1 = 'New User'
-- Definición: Estado L1 = New User (Plataforma). Desglose L2: App Adoption (adopción general en app), DY Adoption (primer pedido vía Double Ya), Dmart Adoption (adopción por Darkstores) y AAA Adoption (adopción por supermercados terceros).
-- ====================================================================================

SELECT
  CASE country 
    WHEN 'Panama' THEN 'Panamá'
    WHEN 'Peru' THEN 'Perú'
    WHEN 'Dominican Republic' THEN 'República Dominicana'
    ELSE country 
  END AS country,
  Mes AS month,
  SUM(users_count) AS new_users_peya
FROM `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
WHERE Mes = '2026-09-01'
  AND country NOT IN ('Venezuela', 'Costa Rica')
  AND business = 'AAA' AND l1 = 'New User'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------+----------------+
-- | country              | month | new_users_peya |
-- +----------------------+-------+----------------+
-- | Argentina            | 2.026 |         91.047 |
-- | Bolivia              | 2.026 |          2.669 |
-- | Chile                | 2.026 |          3.295 |
-- | Ecuador              | 2.026 |         13.110 |
-- | Guatemala            | 2.026 |          6.955 |
-- | Honduras             | 2.026 |          5.319 |
-- | Nicaragua            | 2.026 |          6.205 |
-- | Panam�               | 2.026 |          7.681 |
-- | Paraguay             | 2.026 |          5.348 |
-- | Per�                 | 2.026 |         12.562 |
-- | Rep�blica Dominicana | 2.026 |         11.891 |
-- | Uruguay              | 2.026 |          6.704 |
-- +----------------------+-------+----------------+
