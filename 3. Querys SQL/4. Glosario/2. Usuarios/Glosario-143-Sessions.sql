DECLARE query_name STRING DEFAULT 'Glosario-143-Sessions';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 143
-- Nombre:     Sessions
-- Chapter:   Usuarios
-- Query bajada en: 4 - Users / Growth Tracker
-- Sheets Name: 1. ET - Users Type Count (4 - Users)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1X0bnsCoDszeSlq5TT1uw20GWtcfu1iBpshXXI1QIv7M
-- Tablas de origen: `peya-bi-tools-pro.il_sessions.perseus_fact_partner_funnel` + `peya-bi-tools-pro.il_core.dim_partner` + `peya-bi-tools-pro.il_core.dim_country`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(funnel_shop_details) en tiendas Dmart
-- Definición: Volumen total de sesiones de navegación en tiendas PeYa Market registradas en la aplicación (visitas a la tienda).
-- ====================================================================================

SELECT
  dc.country_name_en AS country,
  DATE_TRUNC(DATE(fp.date), MONTH) AS month,
  SUM(fp.funnel_shop_details) AS sessions
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
-- +----------------------+-------+------------+
-- | country              | month | sessions   |
-- +----------------------+-------+------------+
-- | Argentina            | 2.026 | 11.944.549 |
-- | Bolivia              | 2.026 |    471.846 |
-- | Chile                | 2.026 |  1.365.601 |
-- | Costa Rica           | 2.026 |        705 |
-- | República Dominicana | 2.026 |  1.184.081 |
-- | Ecuador              | 2.026 |    673.763 |
-- | El Salvador          | 2.026 |    630.855 |
-- | Guatemala            | 2.026 |    587.931 |
-- | Honduras             | 2.026 |    470.277 |
-- | Nicaragua            | 2.026 |    321.209 |
-- | Panamá               | 2.026 |    248.671 |
-- | Paraguay             | 2.026 |    605.171 |
-- | Perú                 | 2.026 |    909.331 |
-- | Uruguay              | 2.026 |    860.122 |
-- | Venezuela            | 2.026 |        234 |
-- +----------------------+-------+------------+
