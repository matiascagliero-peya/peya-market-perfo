DECLARE query_name STRING DEFAULT 'Glosario-71-Recurring Return - PeYa';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Nombre:     Recurring Return - PeYa
-- Chapter:    Usuarios
-- Query bajada en: 4 - Users (Users Type Count)
-- Sheets Name: 1. ET - Users Type Count (4 - Users)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1X0bnsCoDszeSlq5TT1uw20GWtcfu1iBpshXXI1QIv7M
-- Tablas de origen: `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(users_count) WHERE business = 'AAA' AND l1 = 'Recurring Return'
-- Definición: Estado L1 = Recurring Return (Plataforma). Clientes fidelizados con racha continua de compras. Desglose L2: Recent Recurring Return (racha de 3 meses seguidos), Old Recurring Return (racha de 4 a 12 meses) y Royal Recurring Return (racha de 13 meses o más / Heavy User VIP).
-- ====================================================================================

SELECT
  CASE country 
    WHEN 'Panama' THEN 'Panamá'
    WHEN 'Peru' THEN 'Perú'
    WHEN 'Dominican Republic' THEN 'República Dominicana'
    ELSE country 
  END AS country,
  Mes AS month,
  SUM(users_count) AS recurring_return_peya
FROM `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
WHERE Mes = '2026-09-01'
  AND country NOT IN ('Venezuela', 'Costa Rica')
  AND business = 'AAA' AND l1 = 'Recurring Return'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------+-----------------------+
-- | country              | month | recurring_return_peya |
-- +----------------------+-------+-----------------------+
-- | Argentina            | 2.026 |               115.437 |
-- | Bolivia              | 2.026 |                   582 |
-- | Chile                | 2.026 |                   625 |
-- | Ecuador              | 2.026 |                 8.776 |
-- | Guatemala            | 2.026 |                10.552 |
-- | Honduras             | 2.026 |                 4.466 |
-- | Nicaragua            | 2.026 |                 4.008 |
-- | Panam�               | 2.026 |                11.680 |
-- | Paraguay             | 2.026 |                 3.302 |
-- | Per�                 | 2.026 |                 2.989 |
-- | Rep�blica Dominicana | 2.026 |                18.090 |
-- | Uruguay              | 2.026 |                 7.995 |
-- +----------------------+-------+-----------------------+
