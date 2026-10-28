DECLARE query_name STRING DEFAULT 'Glosario-131-New Users - non Double Ya';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Nombre:     New Users - non Double Ya
-- Chapter:    Usuarios
-- Query bajada en: 4 - Users (Users Type Count)
-- Sheets Name: 1. ET - Users Type Count (4 - Users)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1X0bnsCoDszeSlq5TT1uw20GWtcfu1iBpshXXI1QIv7M
-- Tablas de origen: `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(users_count) WHERE business = 'Market' AND l1 = 'New User' AND DY = 'No DY'
-- Definición: Estado L1 = New User / L2 = Dmart Adoption: Nuevos clientes adquiridos en PeYa Market mediante compra directa en tienda sin Double Ya.
-- ====================================================================================

SELECT
  CASE country 
    WHEN 'Panama' THEN 'Panamá'
    WHEN 'Peru' THEN 'Perú'
    WHEN 'Dominican Republic' THEN 'República Dominicana'
    ELSE country 
  END AS country,
  Mes AS month,
  SUM(users_count) AS new_users_non_dy
FROM `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
WHERE Mes = '2026-09-01'
  AND country NOT IN ('Venezuela', 'Costa Rica')
  AND business = 'Market' AND l1 = 'New User' AND DY = 'No DY'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------+------------------+
-- | country              | month | new_users_non_dy |
-- +----------------------+-------+------------------+
-- | Argentina            | 2.026 |          108.325 |
-- | Bolivia              | 2.026 |           12.517 |
-- | Chile                | 2.026 |           18.890 |
-- | Ecuador              | 2.026 |            7.298 |
-- | El Salvador          | 2.026 |            3.738 |
-- | Guatemala            | 2.026 |            4.047 |
-- | Honduras             | 2.026 |            4.123 |
-- | Nicaragua            | 2.026 |            3.183 |
-- | Panam�               | 2.026 |            4.345 |
-- | Paraguay             | 2.026 |            4.236 |
-- | Per�                 | 2.026 |           21.289 |
-- | Rep�blica Dominicana | 2.026 |            8.480 |
-- | Uruguay              | 2.026 |            5.207 |
-- +----------------------+-------+------------------+
