DECLARE query_name STRING DEFAULT 'Glosario-84-Re-Activation Users - Dmart';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Nombre:     Re-Activation Users - Dmart
-- Chapter:    Usuarios
-- Query bajada en: 4 - Users (Users Type Count)
-- Sheets Name: 1. ET - Users Type Count (4 - Users)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1X0bnsCoDszeSlq5TT1uw20GWtcfu1iBpshXXI1QIv7M
-- Tablas de origen: `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(users_count) WHERE business = 'Market' AND l1 = 'Reactivation'
-- Definición: Estado L1 = Reactivation (PeYa Market). Clientes que volvieron a comprar en Darkstores tras un periodo de inactividad. Desglose L2: Occasional Reactivation (inactivo 1 mes), Warm Reactivation (inactivo 2 a 4 meses), True Reactivation (inactivo 5 meses o más) y DY Reactivation (reactivado exclusivamente vía Double Ya).
-- ====================================================================================

SELECT
  CASE country 
    WHEN 'Panama' THEN 'Panamá'
    WHEN 'Peru' THEN 'Perú'
    WHEN 'Dominican Republic' THEN 'República Dominicana'
    ELSE country 
  END AS country,
  Mes AS month,
  SUM(users_count) AS reactivation_users_dmart
FROM `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
WHERE Mes = '2026-09-01'
  AND country NOT IN ('Venezuela', 'Costa Rica')
  AND business = 'Market' AND l1 = 'Reactivation'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------+--------------------------+
-- | country              | month | reactivation_users_dmart |
-- +----------------------+-------+--------------------------+
-- | Argentina            | 2.026 |                  287.645 |
-- | Bolivia              | 2.026 |                   19.210 |
-- | Chile                | 2.026 |                   50.498 |
-- | Ecuador              | 2.026 |                   15.626 |
-- | El Salvador          | 2.026 |                    9.849 |
-- | Guatemala            | 2.026 |                   12.013 |
-- | Honduras             | 2.026 |                    7.234 |
-- | Nicaragua            | 2.026 |                    7.301 |
-- | Panam�               | 2.026 |                   13.035 |
-- | Paraguay             | 2.026 |                   15.514 |
-- | Per�                 | 2.026 |                   36.152 |
-- | Rep�blica Dominicana | 2.026 |                   21.778 |
-- | Uruguay              | 2.026 |                   26.519 |
-- +----------------------+-------+--------------------------+
