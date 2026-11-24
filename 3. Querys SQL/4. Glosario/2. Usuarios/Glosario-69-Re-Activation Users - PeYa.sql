DECLARE query_name STRING DEFAULT 'Glosario-69-Re-Activation Users - PeYa';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Nombre:     Re-Activation Users - PeYa
-- Chapter:    Usuarios
-- Query bajada en: 4 - Users (Users Type Count)
-- Sheets Name: 1. ET - Users Type Count (4 - Users)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1X0bnsCoDszeSlq5TT1uw20GWtcfu1iBpshXXI1QIv7M
-- Tablas de origen: `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(users_count) WHERE business = 'AAA' AND l1 = 'Reactivation'
-- Definición: Estado L1 = Reactivation (Plataforma). Retorno tras inactividad previa. Desglose L2 según tenure de inactividad: Occasional Reactivation (gap de 1 mes), Warm Reactivation (gap de 2 a 4 meses), True Reactivation (gap de 5 meses o más) y DY Reactivation (reactivado exclusivamente vía Double Ya).
-- ====================================================================================

SELECT
  CASE country 
    WHEN 'Panama' THEN 'Panamá'
    WHEN 'Peru' THEN 'Perú'
    WHEN 'Dominican Republic' THEN 'República Dominicana'
    ELSE country 
  END AS country,
  Mes AS month,
  SUM(users_count) AS reactivation_users_peya
FROM `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
WHERE Mes = '2026-09-01'
  AND country NOT IN ('Venezuela', 'Costa Rica')
  AND business = 'AAA' AND l1 = 'Reactivation'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------+-------------------------+
-- | country              | month | reactivation_users_peya |
-- +----------------------+-------+-------------------------+
-- | Argentina            | 2.026 |                 130.726 |
-- | Bolivia              | 2.026 |                   1.921 |
-- | Chile                | 2.026 |                   2.832 |
-- | Ecuador              | 2.026 |                  12.390 |
-- | Guatemala            | 2.026 |                  11.235 |
-- | Honduras             | 2.026 |                   4.946 |
-- | Nicaragua            | 2.026 |                   2.711 |
-- | Panam�               | 2.026 |                  12.285 |
-- | Paraguay             | 2.026 |                   6.099 |
-- | Per�                 | 2.026 |                   6.035 |
-- | Rep�blica Dominicana | 2.026 |                  17.635 |
-- | Uruguay              | 2.026 |                   6.793 |
-- +----------------------+-------+-------------------------+
