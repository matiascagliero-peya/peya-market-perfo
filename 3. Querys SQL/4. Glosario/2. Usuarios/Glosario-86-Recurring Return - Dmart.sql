DECLARE query_name STRING DEFAULT 'Glosario-86-Recurring Return - Dmart';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Nombre:     Recurring Return - Dmart
-- Chapter:    Usuarios
-- Query bajada en: 4 - Users (Users Type Count)
-- Sheets Name: 1. ET - Users Type Count (4 - Users)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1X0bnsCoDszeSlq5TT1uw20GWtcfu1iBpshXXI1QIv7M
-- Tablas de origen: `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(users_count) WHERE business = 'Market' AND l1 = 'Recurring Return'
-- Definición: Estado L1 = Recurring Return (PeYa Market). Clientes altamente fidelizados con compras continuas en tienda. Desglose L2: Recent Recurring Return (racha ininterrumpida de 3 meses seguidos), Old Recurring Return (racha de 4 a 12 meses) y Royal Recurring Return (racha de 13 meses o más / VIP de Darkstores).
-- ====================================================================================

SELECT
  CASE country 
    WHEN 'Panama' THEN 'Panamá'
    WHEN 'Peru' THEN 'Perú'
    WHEN 'Dominican Republic' THEN 'República Dominicana'
    ELSE country 
  END AS country,
  Mes AS month,
  SUM(users_count) AS recurring_return_dmart
FROM `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
WHERE Mes = '2026-09-01'
  AND country NOT IN ('Venezuela', 'Costa Rica')
  AND business = 'Market' AND l1 = 'Recurring Return'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------+------------------------+
-- | country              | month | recurring_return_dmart |
-- +----------------------+-------+------------------------+
-- | Argentina            | 2.026 |                429.814 |
-- | Bolivia              | 2.026 |                 18.150 |
-- | Chile                | 2.026 |                 56.679 |
-- | Ecuador              | 2.026 |                 13.843 |
-- | El Salvador          | 2.026 |                 13.904 |
-- | Guatemala            | 2.026 |                 15.126 |
-- | Honduras             | 2.026 |                  6.414 |
-- | Nicaragua            | 2.026 |                  7.926 |
-- | Panam�               | 2.026 |                 15.063 |
-- | Paraguay             | 2.026 |                 20.393 |
-- | Per�                 | 2.026 |                 38.606 |
-- | Rep�blica Dominicana | 2.026 |                 24.520 |
-- | Uruguay              | 2.026 |                 48.255 |
-- +----------------------+-------+------------------------+
