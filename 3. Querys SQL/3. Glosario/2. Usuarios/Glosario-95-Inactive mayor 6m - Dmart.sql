DECLARE query_name STRING DEFAULT 'Glosario-95-Inactive mayor 6m - Dmart';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Nombre:     Inactive > 6m - Dmart
-- Chapter:    Usuarios
-- Query bajada en: 4 - Users (Users Type Count)
-- Sheets Name: 1. ET - Users Type Count (4 - Users)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1X0bnsCoDszeSlq5TT1uw20GWtcfu1iBpshXXI1QIv7M
-- Tablas de origen: `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(users_count) WHERE business = 'Market' AND l2 = 'Churn > 6 Months'
-- Definición: Estado L2 = Churn > 6 Months (Market): Subsegmento de fuga profunda en Darkstores, clientes dormidos sin compras en tienda hace 6 meses o más.
-- ====================================================================================

SELECT
  CASE country 
    WHEN 'Panama' THEN 'Panamá'
    WHEN 'Peru' THEN 'Perú'
    WHEN 'Dominican Republic' THEN 'República Dominicana'
    ELSE country 
  END AS country,
  Mes AS month,
  SUM(users_count) AS inactive_gt_6m_dmart
FROM `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
WHERE Mes = '2026-09-01'
  AND country NOT IN ('Venezuela', 'Costa Rica')
  AND business = 'Market' AND l2 = 'Churn > 6 Months'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+----------------------+-------+
-- | country              | inactive_gt_6m_dmart | month |
-- +----------------------+----------------------+-------+
-- | Argentina            |            2.020.712 | 2.026 |
-- | Bolivia              |              293.770 | 2.026 |
-- | Chile                |              928.046 | 2.026 |
-- | Ecuador              |              257.751 | 2.026 |
-- | El Salvador          |               93.226 | 2.026 |
-- | Guatemala            |              123.700 | 2.026 |
-- | Honduras             |               55.448 | 2.026 |
-- | Nicaragua            |               81.063 | 2.026 |
-- | Panam�               |              187.734 | 2.026 |
-- | Paraguay             |              160.296 | 2.026 |
-- | Per�                 |              711.485 | 2.026 |
-- | Rep�blica Dominicana |              220.562 | 2.026 |
-- | Uruguay              |              293.367 | 2.026 |
-- +----------------------+----------------------+-------+
