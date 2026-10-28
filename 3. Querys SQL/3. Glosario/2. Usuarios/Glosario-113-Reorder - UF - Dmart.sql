DECLARE query_name STRING DEFAULT 'Glosario-113-Reorder - UF - Dmart';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Nombre:     Reorder - UF - Dmart
-- Chapter:    Usuarios
-- Query bajada en: 4 - Users (Users Type Count)
-- Sheets Name: 1. ET - Users Type Count (4 - Users)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1X0bnsCoDszeSlq5TT1uw20GWtcfu1iBpshXXI1QIv7M
-- Tablas de origen: `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(users_count) WHERE business = 'Market' AND l1 = 'Re-Order' AND UF = 'Solo UF'
-- Definición: Estado L1 = Re-Order en Ultra Fresh: Clientes con 2 o más pedidos en el mes que compraron productos Ultra Fresh.
-- ====================================================================================

SELECT
  CASE country 
    WHEN 'Panama' THEN 'Panamá'
    WHEN 'Peru' THEN 'Perú'
    WHEN 'Dominican Republic' THEN 'República Dominicana'
    ELSE country 
  END AS country,
  Mes AS month,
  SUM(users_count) AS reorder_uf_dmart
FROM `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
WHERE Mes = '2026-09-01'
  AND country NOT IN ('Venezuela', 'Costa Rica')
  AND business = 'Market' AND l1 = 'Re-Order' AND UF = 'Solo UF'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------+------------------+
-- | country              | month | reorder_uf_dmart |
-- +----------------------+-------+------------------+
-- | Argentina            | 2.026 |           28.021 |
-- | Bolivia              | 2.026 |            1.274 |
-- | Chile                | 2.026 |            4.797 |
-- | Ecuador              | 2.026 |            1.175 |
-- | El Salvador          | 2.026 |              844 |
-- | Guatemala            | 2.026 |              992 |
-- | Honduras             | 2.026 |              364 |
-- | Nicaragua            | 2.026 |              668 |
-- | Panam�               | 2.026 |            1.452 |
-- | Paraguay             | 2.026 |            1.096 |
-- | Per�                 | 2.026 |            2.794 |
-- | Rep�blica Dominicana | 2.026 |            1.808 |
-- | Uruguay              | 2.026 |            2.492 |
-- +----------------------+-------+------------------+
