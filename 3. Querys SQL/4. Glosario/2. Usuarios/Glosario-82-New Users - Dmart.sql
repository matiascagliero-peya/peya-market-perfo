DECLARE query_name STRING DEFAULT 'Glosario-82-New Users - Dmart';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Nombre:     New Users - Dmart
-- Chapter:    Usuarios
-- Query bajada en: 4 - Users (Users Type Count)
-- Sheets Name: 1. ET - Users Type Count (4 - Users)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1X0bnsCoDszeSlq5TT1uw20GWtcfu1iBpshXXI1QIv7M
-- Tablas de origen: `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(users_count) WHERE business = 'Market' AND l1 = 'New User'
-- Definición: Estado L1 = New User (PeYa Market). Desglose L2: App Adoption (adopción inicial simultánea con app), DY Adoption (primer pedido en Market vía Double Ya), Dmart Adoption (adopción directa de tienda) y AAA Adoption (adopción de Market habiendo comprado previamente en supermercados tradicionales).
-- ====================================================================================

SELECT
  CASE country 
    WHEN 'Panama' THEN 'Panamá'
    WHEN 'Peru' THEN 'Perú'
    WHEN 'Dominican Republic' THEN 'República Dominicana'
    ELSE country 
  END AS country,
  Mes AS month,
  SUM(users_count) AS new_users_dmart
FROM `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
WHERE Mes = '2026-09-01'
  AND country NOT IN ('Venezuela', 'Costa Rica')
  AND business = 'Market' AND l1 = 'New User'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------+-----------------+
-- | country              | month | new_users_dmart |
-- +----------------------+-------+-----------------+
-- | Argentina            | 2.026 |         123.917 |
-- | Bolivia              | 2.026 |          12.517 |
-- | Chile                | 2.026 |          20.796 |
-- | Ecuador              | 2.026 |           9.567 |
-- | El Salvador          | 2.026 |           5.110 |
-- | Guatemala            | 2.026 |           5.792 |
-- | Honduras             | 2.026 |           7.138 |
-- | Nicaragua            | 2.026 |           4.361 |
-- | Panam�               | 2.026 |           4.345 |
-- | Paraguay             | 2.026 |           6.340 |
-- | Per�                 | 2.026 |          21.289 |
-- | Rep�blica Dominicana | 2.026 |          11.369 |
-- | Uruguay              | 2.026 |           6.034 |
-- +----------------------+-------+-----------------+
