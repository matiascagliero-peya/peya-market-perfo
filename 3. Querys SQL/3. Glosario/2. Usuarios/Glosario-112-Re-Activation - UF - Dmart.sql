DECLARE query_name STRING DEFAULT 'Glosario-112-Re-Activation - UF - Dmart';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Nombre:     Re-Activation - UF - Dmart
-- Chapter:    Usuarios
-- Query bajada en: 4 - Users (Users Type Count)
-- Sheets Name: 1. ET - Users Type Count (4 - Users)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1X0bnsCoDszeSlq5TT1uw20GWtcfu1iBpshXXI1QIv7M
-- Tablas de origen: `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(users_count) WHERE business = 'Market' AND l1 = 'Reactivation' AND UF = 'Solo UF'
-- Definición: Estado L1 = Reactivation en Ultra Fresh: Clientes reactivados tras inactividad que compraron productos Ultra Fresh.
-- ====================================================================================

SELECT
  CASE country 
    WHEN 'Panama' THEN 'Panamá'
    WHEN 'Peru' THEN 'Perú'
    WHEN 'Dominican Republic' THEN 'República Dominicana'
    ELSE country 
  END AS country,
  Mes AS month,
  SUM(users_count) AS reactivation_uf_dmart
FROM `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
WHERE Mes = '2026-09-01'
  AND country NOT IN ('Venezuela', 'Costa Rica')
  AND business = 'Market' AND l1 = 'Reactivation' AND UF = 'Solo UF'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------+-----------------------+
-- | country              | month | reactivation_uf_dmart |
-- +----------------------+-------+-----------------------+
-- | Argentina            | 2.026 |                80.977 |
-- | Bolivia              | 2.026 |                 4.432 |
-- | Chile                | 2.026 |                15.620 |
-- | Ecuador              | 2.026 |                 4.147 |
-- | El Salvador          | 2.026 |                 2.092 |
-- | Guatemala            | 2.026 |                 2.736 |
-- | Honduras             | 2.026 |                 1.130 |
-- | Nicaragua            | 2.026 |                 1.919 |
-- | Panam�               | 2.026 |                 3.632 |
-- | Paraguay             | 2.026 |                 3.123 |
-- | Per�                 | 2.026 |                 8.959 |
-- | Rep�blica Dominicana | 2.026 |                 5.340 |
-- | Uruguay              | 2.026 |                 6.406 |
-- +----------------------+-------+-----------------------+
