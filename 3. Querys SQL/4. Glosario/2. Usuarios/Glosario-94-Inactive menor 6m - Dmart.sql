DECLARE query_name STRING DEFAULT 'Glosario-94-Inactive menor 6m - Dmart';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Nombre:     Inactive < 6m - Dmart
-- Chapter:    Usuarios
-- Query bajada en: 4 - Users (Users Type Count)
-- Sheets Name: 1. ET - Users Type Count (4 - Users)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1X0bnsCoDszeSlq5TT1uw20GWtcfu1iBpshXXI1QIv7M
-- Tablas de origen: `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(users_count) WHERE business = 'Market' AND l2 = 'Churn > 3 Months'
-- Definición: Estado L2 = Churn > 3 Months (Market): Subsegmento de fuga media en Darkstores, clientes con inactividad entre 3 y 5 meses desde su última compra en tienda.
-- ====================================================================================

SELECT
  CASE country 
    WHEN 'Panama' THEN 'Panamá'
    WHEN 'Peru' THEN 'Perú'
    WHEN 'Dominican Republic' THEN 'República Dominicana'
    ELSE country 
  END AS country,
  Mes AS month,
  SUM(users_count) AS inactive_lt_6m_dmart
FROM `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
WHERE Mes = '2026-09-01'
  AND country NOT IN ('Venezuela', 'Costa Rica')
  AND business = 'Market' AND l2 = 'Churn > 3 Months'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+----------------------+-------+
-- | country              | inactive_lt_6m_dmart | month |
-- +----------------------+----------------------+-------+
-- | Argentina            |              536.956 | 2.026 |
-- | Bolivia              |               39.379 | 2.026 |
-- | Chile                |              144.423 | 2.026 |
-- | Ecuador              |               42.465 | 2.026 |
-- | El Salvador          |               21.915 | 2.026 |
-- | Guatemala            |               25.980 | 2.026 |
-- | Honduras             |               17.483 | 2.026 |
-- | Nicaragua            |               15.148 | 2.026 |
-- | Panam�               |               26.523 | 2.026 |
-- | Paraguay             |               27.758 | 2.026 |
-- | Per�                 |               82.850 | 2.026 |
-- | Rep�blica Dominicana |               43.285 | 2.026 |
-- | Uruguay              |               56.197 | 2.026 |
-- +----------------------+----------------------+-------+
