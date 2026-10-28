DECLARE query_name STRING DEFAULT 'Glosario-110-New Users - UF - Dmart';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Nombre:     New Users - UF - Dmart
-- Chapter:    Usuarios
-- Query bajada en: 4 - Users (Users Type Count)
-- Sheets Name: 1. ET - Users Type Count (4 - Users)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1X0bnsCoDszeSlq5TT1uw20GWtcfu1iBpshXXI1QIv7M
-- Tablas de origen: `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(users_count) WHERE business = 'Market' AND l1 = 'New User' AND UF = 'Solo UF'
-- Definición: Estado L1 = New User en Ultra Fresh: Nuevos clientes de PeYa Market cuya primera orden incluyó productos de categorías frescas (Produce, Carnes, Listo para Consumir).
-- ====================================================================================

SELECT
  CASE country 
    WHEN 'Panama' THEN 'Panamá'
    WHEN 'Peru' THEN 'Perú'
    WHEN 'Dominican Republic' THEN 'República Dominicana'
    ELSE country 
  END AS country,
  Mes AS month,
  SUM(users_count) AS new_users_uf_dmart
FROM `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
WHERE Mes = '2026-09-01'
  AND country NOT IN ('Venezuela', 'Costa Rica')
  AND business = 'Market' AND l1 = 'New User' AND UF = 'Solo UF'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------+--------------------+
-- | country              | month | new_users_uf_dmart |
-- +----------------------+-------+--------------------+
-- | Argentina            | 2.026 |             36.946 |
-- | Bolivia              | 2.026 |              3.122 |
-- | Chile                | 2.026 |              5.122 |
-- | Ecuador              | 2.026 |              2.157 |
-- | El Salvador          | 2.026 |                964 |
-- | Guatemala            | 2.026 |              1.055 |
-- | Honduras             | 2.026 |              1.010 |
-- | Nicaragua            | 2.026 |                929 |
-- | Panam�               | 2.026 |              1.185 |
-- | Paraguay             | 2.026 |                879 |
-- | Per�                 | 2.026 |              5.000 |
-- | Rep�blica Dominicana | 2.026 |              3.162 |
-- | Uruguay              | 2.026 |              1.115 |
-- +----------------------+-------+--------------------+
