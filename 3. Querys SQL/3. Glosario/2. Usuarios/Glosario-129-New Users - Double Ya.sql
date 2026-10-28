DECLARE query_name STRING DEFAULT 'Glosario-129-New Users - Double Ya';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Nombre:     New Users - Double Ya
-- Chapter:    Usuarios
-- Query bajada en: 4 - Users (Users Type Count)
-- Sheets Name: 1. ET - Users Type Count (4 - Users)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1X0bnsCoDszeSlq5TT1uw20GWtcfu1iBpshXXI1QIv7M
-- Tablas de origen: `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(users_count) WHERE business = 'Market' AND l1 = 'New User' AND DY = 'Solo DY'
-- Definición: Estado L1 = New User / L2 = DY Adoption: Nuevos clientes adquiridos en PeYa Market cuyo primer pedido se realizó exclusivamente mediante el flujo complementario Double Ya.
-- ====================================================================================

SELECT
  CASE country 
    WHEN 'Panama' THEN 'Panamá'
    WHEN 'Peru' THEN 'Perú'
    WHEN 'Dominican Republic' THEN 'República Dominicana'
    ELSE country 
  END AS country,
  Mes AS month,
  SUM(users_count) AS new_users_dy
FROM `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
WHERE Mes = '2026-09-01'
  AND country NOT IN ('Venezuela', 'Costa Rica')
  AND business = 'Market' AND l1 = 'New User' AND DY = 'Solo DY'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------+--------------+
-- | country              | month | new_users_dy |
-- +----------------------+-------+--------------+
-- | Argentina            | 2.026 |       13.814 |
-- | Chile                | 2.026 |        1.771 |
-- | Ecuador              | 2.026 |        2.055 |
-- | El Salvador          | 2.026 |        1.222 |
-- | Guatemala            | 2.026 |        1.614 |
-- | Honduras             | 2.026 |        2.745 |
-- | Nicaragua            | 2.026 |        1.076 |
-- | Paraguay             | 2.026 |        1.851 |
-- | Rep�blica Dominicana | 2.026 |        2.598 |
-- | Uruguay              | 2.026 |          736 |
-- +----------------------+-------+--------------+
