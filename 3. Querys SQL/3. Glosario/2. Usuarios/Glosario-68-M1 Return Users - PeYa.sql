DECLARE query_name STRING DEFAULT 'Glosario-68-M1 Return Users - PeYa';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Nombre:     M1 Return Users - PeYa
-- Chapter:    Usuarios
-- Query bajada en: 4 - Users (Users Type Count)
-- Sheets Name: 1. ET - Users Type Count (4 - Users)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1X0bnsCoDszeSlq5TT1uw20GWtcfu1iBpshXXI1QIv7M
-- Tablas de origen: `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(users_count) WHERE business = 'AAA' AND l1 = 'M1 Return'
-- Definición: Estado L1 = M1 Return (Plataforma). Retención orgánica de primer mes (compra en M-1 y compra en M). Desglose L2: M1 Return Users, M1 DY (repite con DY) y M1 DY Converted (convierte a compra regular sin DY).
-- ====================================================================================

SELECT
  CASE country 
    WHEN 'Panama' THEN 'Panamá'
    WHEN 'Peru' THEN 'Perú'
    WHEN 'Dominican Republic' THEN 'República Dominicana'
    ELSE country 
  END AS country,
  Mes AS month,
  SUM(users_count) AS m1_return_users_peya
FROM `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
WHERE Mes = '2026-09-01'
  AND country NOT IN ('Venezuela', 'Costa Rica')
  AND business = 'AAA' AND l1 = 'M1 Return'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+----------------------+-------+
-- | country              | m1_return_users_peya | month |
-- +----------------------+----------------------+-------+
-- | Argentina            |               17.740 | 2.026 |
-- | Bolivia              |                  306 | 2.026 |
-- | Chile                |                  228 | 2.026 |
-- | Ecuador              |                2.288 | 2.026 |
-- | Guatemala            |                1.280 | 2.026 |
-- | Honduras             |                1.118 | 2.026 |
-- | Nicaragua            |                1.579 | 2.026 |
-- | Panam�               |                1.662 | 2.026 |
-- | Paraguay             |                  777 | 2.026 |
-- | Per�                 |                1.305 | 2.026 |
-- | Rep�blica Dominicana |                3.572 | 2.026 |
-- | Uruguay              |                1.986 | 2.026 |
-- +----------------------+----------------------+-------+
