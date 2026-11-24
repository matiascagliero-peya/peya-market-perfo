DECLARE query_name STRING DEFAULT 'Glosario-72-Churned Users - PeYa';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Nombre:     Churned Users - PeYa
-- Chapter:    Usuarios
-- Query bajada en: 4 - Users (Users Type Count)
-- Sheets Name: 1. ET - Users Type Count (4 - Users)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1X0bnsCoDszeSlq5TT1uw20GWtcfu1iBpshXXI1QIv7M
-- Tablas de origen: `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(users_count) WHERE business = 'AAA' AND l1 = 'Churned'
-- Definición: Estado L1 = Churned (Plataforma). Usuarios activos en meses previos que no compraron en el mes M. Desglose L2 según tiempo de fuga: Recently Churn (inactivo hace 1 o 2 meses), Churn > 3 Months (inactivo 3 a 5 meses) y Churn > 6 Months (inactivo 6 meses o más).
-- ====================================================================================

SELECT
  CASE country 
    WHEN 'Panama' THEN 'Panamá'
    WHEN 'Peru' THEN 'Perú'
    WHEN 'Dominican Republic' THEN 'República Dominicana'
    ELSE country 
  END AS country,
  Mes AS month,
  SUM(users_count) AS churned_users_peya
FROM `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
WHERE Mes = '2026-09-01'
  AND country NOT IN ('Venezuela', 'Costa Rica')
  AND business = 'AAA' AND l1 = 'Churned'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +--------------------+----------------------+-------+
-- | churned_users_peya | country              | month |
-- +--------------------+----------------------+-------+
-- |          1.952.952 | Argentina            | 2.026 |
-- |             56.326 | Bolivia              | 2.026 |
-- |            320.090 | Chile                | 2.026 |
-- |            310.320 | Ecuador              | 2.026 |
-- |             15.441 | El Salvador          | 2.026 |
-- |            172.947 | Guatemala            | 2.026 |
-- |             75.060 | Honduras             | 2.026 |
-- |             31.201 | Nicaragua            | 2.026 |
-- |            194.021 | Panam�               | 2.026 |
-- |            117.929 | Paraguay             | 2.026 |
-- |            156.387 | Per�                 | 2.026 |
-- |            282.928 | Rep�blica Dominicana | 2.026 |
-- |            107.662 | Uruguay              | 2.026 |
-- +--------------------+----------------------+-------+
