DECLARE query_name STRING DEFAULT 'Glosario-114-Recurring Return - UF - Dmart';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Nombre:     Recurring Return - UF - Dmart
-- Chapter:    Usuarios
-- Query bajada en: 4 - Users (Users Type Count)
-- Sheets Name: 1. ET - Users Type Count (4 - Users)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1X0bnsCoDszeSlq5TT1uw20GWtcfu1iBpshXXI1QIv7M
-- Tablas de origen: `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(users_count) WHERE business = 'Market' AND l1 = 'Recurring Return' AND UF = 'Solo UF'
-- Definición: Estado L1 = Recurring Return en Ultra Fresh: Clientes leales recurrentes (>2 meses de racha) que compran Ultra Fresh.
-- ====================================================================================

SELECT
  CASE country 
    WHEN 'Panama' THEN 'Panamá'
    WHEN 'Peru' THEN 'Perú'
    WHEN 'Dominican Republic' THEN 'República Dominicana'
    ELSE country 
  END AS country,
  Mes AS month,
  SUM(users_count) AS recurring_return_uf_dmart
FROM `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
WHERE Mes = '2026-09-01'
  AND country NOT IN ('Venezuela', 'Costa Rica')
  AND business = 'Market' AND l1 = 'Recurring Return' AND UF = 'Solo UF'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------+---------------------------+
-- | country              | month | recurring_return_uf_dmart |
-- +----------------------+-------+---------------------------+
-- | Argentina            | 2.026 |                    84.408 |
-- | Bolivia              | 2.026 |                     2.518 |
-- | Chile                | 2.026 |                    12.378 |
-- | Ecuador              | 2.026 |                     2.408 |
-- | El Salvador          | 2.026 |                     2.370 |
-- | Guatemala            | 2.026 |                     2.708 |
-- | Honduras             | 2.026 |                       652 |
-- | Nicaragua            | 2.026 |                     1.568 |
-- | Panam�               | 2.026 |                     3.220 |
-- | Paraguay             | 2.026 |                     2.734 |
-- | Per�                 | 2.026 |                     6.418 |
-- | Rep�blica Dominicana | 2.026 |                     3.207 |
-- | Uruguay              | 2.026 |                     9.488 |
-- +----------------------+-------+---------------------------+
