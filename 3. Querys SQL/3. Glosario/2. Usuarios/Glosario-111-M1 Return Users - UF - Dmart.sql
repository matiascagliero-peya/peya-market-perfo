DECLARE query_name STRING DEFAULT 'Glosario-111-M1 Return Users - UF - Dmart';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Nombre:     M1 Return Users - UF - Dmart
-- Chapter:    Usuarios
-- Query bajada en: 4 - Users (Users Type Count)
-- Sheets Name: 1. ET - Users Type Count (4 - Users)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1X0bnsCoDszeSlq5TT1uw20GWtcfu1iBpshXXI1QIv7M
-- Tablas de origen: `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(users_count) WHERE business = 'Market' AND l1 = 'M1 Return' AND UF = 'Solo UF'
-- Definición: Estado L1 = M1 Return en Ultra Fresh: Clientes retenidos de primer mes cuya compra incluyó productos Ultra Fresh.
-- ====================================================================================

SELECT
  CASE country 
    WHEN 'Panama' THEN 'Panamá'
    WHEN 'Peru' THEN 'Perú'
    WHEN 'Dominican Republic' THEN 'República Dominicana'
    ELSE country 
  END AS country,
  Mes AS month,
  SUM(users_count) AS m1_return_uf_dmart
FROM `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
WHERE Mes = '2026-09-01'
  AND country NOT IN ('Venezuela', 'Costa Rica')
  AND business = 'Market' AND l1 = 'M1 Return' AND UF = 'Solo UF'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+--------------------+-------+
-- | country              | m1_return_uf_dmart | month |
-- +----------------------+--------------------+-------+
-- | Argentina            |              6.198 | 2.026 |
-- | Bolivia              |                573 | 2.026 |
-- | Chile                |              1.106 | 2.026 |
-- | Ecuador              |                420 | 2.026 |
-- | El Salvador          |                177 | 2.026 |
-- | Guatemala            |                163 | 2.026 |
-- | Honduras             |                224 | 2.026 |
-- | Nicaragua            |                146 | 2.026 |
-- | Panam�               |                237 | 2.026 |
-- | Paraguay             |                178 | 2.026 |
-- | Per�                 |                731 | 2.026 |
-- | Rep�blica Dominicana |                477 | 2.026 |
-- | Uruguay              |                256 | 2.026 |
-- +----------------------+--------------------+-------+
