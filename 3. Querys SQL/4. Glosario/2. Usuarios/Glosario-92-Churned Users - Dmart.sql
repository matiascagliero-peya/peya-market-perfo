DECLARE query_name STRING DEFAULT 'Glosario-92-Churned Users - Dmart';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Nombre:     Churned Users - Dmart
-- Chapter:    Usuarios
-- Query bajada en: 4 - Users (Users Type Count)
-- Sheets Name: 1. ET - Users Type Count (4 - Users)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1X0bnsCoDszeSlq5TT1uw20GWtcfu1iBpshXXI1QIv7M
-- Tablas de origen: `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(users_count) WHERE business = 'Market' AND l1 = 'Churned'
-- Definición: Estado L1 = Churned (PeYa Market). Clientes activos en Darkstores en el mes M-1 sin compras en Market en el mes M. Desglose L2: Recently Churn (inactivos 1 a 2 meses), Churn > 3 Months (inactivos 3 a 5 meses) y Churn > 6 Months (inactivos 6 meses o más).
-- ====================================================================================

SELECT
  CASE country 
    WHEN 'Panama' THEN 'Panamá'
    WHEN 'Peru' THEN 'Perú'
    WHEN 'Dominican Republic' THEN 'República Dominicana'
    ELSE country 
  END AS country,
  Mes AS month,
  SUM(users_count) AS churned_users_dmart
FROM `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
WHERE Mes = '2026-09-01'
  AND country NOT IN ('Venezuela', 'Costa Rica')
  AND business = 'Market' AND l1 = 'Churned'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +---------------------+----------------------+-------+
-- | churned_users_dmart | country              | month |
-- +---------------------+----------------------+-------+
-- |           3.275.983 | Argentina            | 2.026 |
-- |             380.564 | Bolivia              | 2.026 |
-- |           1.218.044 | Chile                | 2.026 |
-- |             347.241 | Ecuador              | 2.026 |
-- |             141.763 | El Salvador          | 2.026 |
-- |             179.313 | Guatemala            | 2.026 |
-- |              95.475 | Honduras             | 2.026 |
-- |             115.192 | Nicaragua            | 2.026 |
-- |             246.978 | Panam�               | 2.026 |
-- |             223.589 | Paraguay             | 2.026 |
-- |             889.047 | Per�                 | 2.026 |
-- |             318.510 | Rep�blica Dominicana | 2.026 |
-- |             414.663 | Uruguay              | 2.026 |
-- +---------------------+----------------------+-------+
