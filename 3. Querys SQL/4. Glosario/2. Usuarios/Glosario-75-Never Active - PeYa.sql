DECLARE query_name STRING DEFAULT 'Glosario-75-Never Active - PeYa';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Nombre:     Never Active - PeYa
-- Chapter:    Usuarios
-- Query bajada en: 4 - Users (Users Type Count)
-- Sheets Name: 1. ET - Users Type Count (4 - Users)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1X0bnsCoDszeSlq5TT1uw20GWtcfu1iBpshXXI1QIv7M
-- Tablas de origen: `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(users_count) WHERE business = 'AAA' AND l1 = 'Never Active'
-- Definición: Estado L1 = Never Active (Plataforma). Subtipo L2 = "-": Usuarios registrados en la aplicación que nunca en su historia han realizado una orden confirmada.
-- ====================================================================================

SELECT
  CASE country 
    WHEN 'Panama' THEN 'Panamá'
    WHEN 'Peru' THEN 'Perú'
    WHEN 'Dominican Republic' THEN 'República Dominicana'
    ELSE country 
  END AS country,
  Mes AS month,
  SUM(users_count) AS never_active_peya
FROM `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
WHERE Mes = '2026-09-01'
  AND country NOT IN ('Venezuela', 'Costa Rica')
  AND business = 'AAA' AND l1 = 'Never Active'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------+-------------------+
-- | country              | month | never_active_peya |
-- +----------------------+-------+-------------------+
-- | Argentina            | 2.026 |        10.488.840 |
-- | Bolivia              | 2.026 |         1.965.726 |
-- | Chile                | 2.026 |         6.153.428 |
-- | Ecuador              | 2.026 |         2.187.282 |
-- | El Salvador          | 2.026 |         1.303.112 |
-- | Guatemala            | 2.026 |         1.383.334 |
-- | Honduras             | 2.026 |           774.805 |
-- | Nicaragua            | 2.026 |           803.478 |
-- | Panam�               | 2.026 |         1.230.652 |
-- | Paraguay             | 2.026 |         1.054.457 |
-- | Per�                 | 2.026 |         4.359.453 |
-- | Rep�blica Dominicana | 2.026 |         1.647.851 |
-- | Uruguay              | 2.026 |         1.010.639 |
-- +----------------------+-------+-------------------+
