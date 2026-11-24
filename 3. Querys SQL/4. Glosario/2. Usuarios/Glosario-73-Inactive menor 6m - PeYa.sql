DECLARE query_name STRING DEFAULT 'Glosario-73-Inactive menor 6m - PeYa';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Nombre:     Inactive < 6m - PeYa
-- Chapter:    Usuarios
-- Query bajada en: 4 - Users (Users Type Count)
-- Sheets Name: 1. ET - Users Type Count (4 - Users)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1X0bnsCoDszeSlq5TT1uw20GWtcfu1iBpshXXI1QIv7M
-- Tablas de origen: `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(users_count) WHERE business = 'AAA' AND l2 = 'Churn > 3 Months'
-- Definición: Estado L2 = Churn > 3 Months (Plataforma): Subsegmento de fuga media, clientes con inactividad de 3 a 5 meses sin compras en la plataforma.
-- ====================================================================================

SELECT
  CASE country 
    WHEN 'Panama' THEN 'Panamá'
    WHEN 'Peru' THEN 'Perú'
    WHEN 'Dominican Republic' THEN 'República Dominicana'
    ELSE country 
  END AS country,
  Mes AS month,
  SUM(users_count) AS inactive_lt_6m_peya
FROM `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
WHERE Mes = '2026-09-01'
  AND country NOT IN ('Venezuela', 'Costa Rica')
  AND business = 'AAA' AND l2 = 'Churn > 3 Months'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+---------------------+-------+
-- | country              | inactive_lt_6m_peya | month |
-- +----------------------+---------------------+-------+
-- | Argentina            |             317.653 | 2.026 |
-- | Bolivia              |               5.903 | 2.026 |
-- | Chile                |               6.875 | 2.026 |
-- | Ecuador              |              40.562 | 2.026 |
-- | El Salvador          |                 899 | 2.026 |
-- | Guatemala            |              23.918 | 2.026 |
-- | Honduras             |              12.793 | 2.026 |
-- | Nicaragua            |               9.411 | 2.026 |
-- | Panam�               |              30.609 | 2.026 |
-- | Paraguay             |              16.789 | 2.026 |
-- | Per�                 |              18.910 | 2.026 |
-- | Rep�blica Dominicana |              44.763 | 2.026 |
-- | Uruguay              |              17.057 | 2.026 |
-- +----------------------+---------------------+-------+
