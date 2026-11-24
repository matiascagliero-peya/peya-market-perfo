DECLARE query_name STRING DEFAULT 'Glosario-76-Total Churned Users';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Nombre:     Total Churned Users
-- Chapter:    Usuarios
-- Query bajada en: 4 - Users (Users Type Count)
-- Sheets Name: 1. ET - Users Type Count (4 - Users)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1X0bnsCoDszeSlq5TT1uw20GWtcfu1iBpshXXI1QIv7M
-- Tablas de origen: `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(users_count) WHERE business = 'AAA' AND (l1 = 'Churned' OR l1 = 'Never Active')
-- Definición: Total consolidado de usuarios inactivos o perdidos en la plataforma (suma de Churned L1 + Never Active L1).
-- ====================================================================================

SELECT
  CASE country 
    WHEN 'Panama' THEN 'Panamá'
    WHEN 'Peru' THEN 'Perú'
    WHEN 'Dominican Republic' THEN 'República Dominicana'
    ELSE country 
  END AS country,
  Mes AS month,
  SUM(users_count) AS total_churned_users
FROM `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
WHERE Mes = '2026-09-01'
  AND country NOT IN ('Venezuela', 'Costa Rica')
  AND business = 'AAA' AND (l1 = 'Churned' OR l1 = 'Never Active')
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------+---------------------+
-- | country              | month | total_churned_users |
-- +----------------------+-------+---------------------+
-- | Argentina            | 2.026 |          12.441.792 |
-- | Bolivia              | 2.026 |           2.022.052 |
-- | Chile                | 2.026 |           6.473.518 |
-- | Ecuador              | 2.026 |           2.497.602 |
-- | El Salvador          | 2.026 |           1.318.553 |
-- | Guatemala            | 2.026 |           1.556.281 |
-- | Honduras             | 2.026 |             849.865 |
-- | Nicaragua            | 2.026 |             834.679 |
-- | Panam�               | 2.026 |           1.424.673 |
-- | Paraguay             | 2.026 |           1.172.386 |
-- | Per�                 | 2.026 |           4.515.840 |
-- | Rep�blica Dominicana | 2.026 |           1.930.779 |
-- | Uruguay              | 2.026 |           1.118.301 |
-- +----------------------+-------+---------------------+
