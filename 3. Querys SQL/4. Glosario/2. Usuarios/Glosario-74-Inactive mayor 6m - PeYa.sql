DECLARE query_name STRING DEFAULT 'Glosario-74-Inactive mayor 6m - PeYa';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Nombre:     Inactive > 6m - PeYa
-- Chapter:    Usuarios
-- Query bajada en: 4 - Users (Users Type Count)
-- Sheets Name: 1. ET - Users Type Count (4 - Users)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1X0bnsCoDszeSlq5TT1uw20GWtcfu1iBpshXXI1QIv7M
-- Tablas de origen: `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(users_count) WHERE business = 'AAA' AND l2 = 'Churn > 6 Months'
-- Definición: Estado L2 = Churn > 6 Months (Plataforma): Subsegmento de fuga profunda, clientes dormidos sin compras en la plataforma desde hace 6 meses o más.
-- ====================================================================================

SELECT
  CASE country 
    WHEN 'Panama' THEN 'Panamá'
    WHEN 'Peru' THEN 'Perú'
    WHEN 'Dominican Republic' THEN 'República Dominicana'
    ELSE country 
  END AS country,
  Mes AS month,
  SUM(users_count) AS inactive_gt_6m_peya
FROM `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
WHERE Mes = '2026-09-01'
  AND country NOT IN ('Venezuela', 'Costa Rica')
  AND business = 'AAA' AND l2 = 'Churn > 6 Months'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+---------------------+-------+
-- | country              | inactive_gt_6m_peya | month |
-- +----------------------+---------------------+-------+
-- | Argentina            |           1.261.368 | 2.026 |
-- | Bolivia              |              44.779 | 2.026 |
-- | Chile                |             306.569 | 2.026 |
-- | Ecuador              |             227.459 | 2.026 |
-- | El Salvador          |              14.059 | 2.026 |
-- | Guatemala            |             120.150 | 2.026 |
-- | Honduras             |              47.418 | 2.026 |
-- | Nicaragua            |               9.714 | 2.026 |
-- | Panam�               |             128.448 | 2.026 |
-- | Paraguay             |              86.029 | 2.026 |
-- | Per�                 |             117.849 | 2.026 |
-- | Rep�blica Dominicana |             185.357 | 2.026 |
-- | Uruguay              |              69.672 | 2.026 |
-- +----------------------+---------------------+-------+
