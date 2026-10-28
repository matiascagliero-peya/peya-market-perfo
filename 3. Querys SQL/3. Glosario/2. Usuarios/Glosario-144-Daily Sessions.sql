DECLARE query_name STRING DEFAULT 'Glosario-144-Daily Sessions';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 144
-- Nombre:     Daily Sessions
-- Chapter:   Usuarios
-- Query bajada en: 4 - Users / Growth Tracker
-- Sheets Name: 1. ET - Users Type Count (4 - Users)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1X0bnsCoDszeSlq5TT1uw20GWtcfu1iBpshXXI1QIv7M
-- Tablas de origen: `peya-bi-tools-pro.il_sessions.perseus_fact_partner_funnel` + `peya-bi-tools-pro.il_core.dim_partner` + `peya-bi-tools-pro.il_core.dim_country`
-- Tipo:       Dato Directo
-- Fórmula:    Sessions / Días del Mes
-- Definición: Promedio diario de sesiones de navegación registradas en tiendas PeYa Market durante el mes.
-- ====================================================================================

SELECT
  dc.country_name_en AS country,
  DATE_TRUNC(DATE(fp.date), MONTH) AS month,
  SAFE_DIVIDE(SUM(fp.funnel_shop_details), 30) AS daily_sessions
FROM `peya-bi-tools-pro.il_sessions.perseus_fact_partner_funnel` fp
INNER JOIN `peya-bi-tools-pro.il_core.dim_partner` dp
  ON CAST(fp.partner_id AS INT64) = dp.partner_id
LEFT JOIN `peya-bi-tools-pro.il_core.dim_country` dc
  ON fp.country_id = dc.country_id
WHERE dp.is_darkstore = TRUE
  AND DATE(fp.date) BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+----------------+-------+
-- | country              | daily_sessions | month |
-- +----------------------+----------------+-------+
-- | Argentina            |     398.151,63 | 2.026 |
-- | Bolivia              |      15.728,20 | 2.026 |
-- | Chile                |      45.520,03 | 2.026 |
-- | Costa Rica           |          23,50 | 2.026 |
-- | República Dominicana |      39.469,37 | 2.026 |
-- | Ecuador              |      22.458,77 | 2.026 |
-- | El Salvador          |      21.028,50 | 2.026 |
-- | Guatemala            |      19.597,70 | 2.026 |
-- | Honduras             |      15.675,90 | 2.026 |
-- | Nicaragua            |      10.706,97 | 2.026 |
-- | Panamá               |       8.289,03 | 2.026 |
-- | Paraguay             |      20.172,37 | 2.026 |
-- | Perú                 |      30.311,03 | 2.026 |
-- | Uruguay              |      28.670,73 | 2.026 |
-- | Venezuela            |           7,80 | 2.026 |
-- +----------------------+----------------+-------+
