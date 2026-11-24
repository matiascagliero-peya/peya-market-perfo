DECLARE query_name STRING DEFAULT 'Glosario-149-CVR3 %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 149
-- Nombre:     CVR3 %
-- Chapter:   Usuarios
-- Query bajada en: 4 - Users / Growth Tracker
-- Sheets Name: 1. ET - Users Type Count (4 - Users)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1X0bnsCoDszeSlq5TT1uw20GWtcfu1iBpshXXI1QIv7M
-- Tablas de origen: `peya-bi-tools-pro.il_sessions.perseus_fact_partner_funnel` + `peya-bi-tools-pro.il_core.dim_partner` + `peya-bi-tools-pro.il_core.dim_country`
-- Tipo:       Ratio Calculado
-- Fórmula:    Shop Transactions / Shop Sessions
-- Definición: Tasa de conversión de tienda: porcentaje de sesiones de visita que se convirtieron en pedidos confirmados (Orders / Sessions).
-- ====================================================================================

SELECT
  dc.country_name_en AS country,
  DATE_TRUNC(DATE(fp.date), MONTH) AS month,
  SUM(fp.funnel_shop_transaction) AS shop_transactions,
  SUM(fp.funnel_shop_details) AS shop_sessions,
  SAFE_DIVIDE(SUM(fp.funnel_shop_transaction), NULLIF(SUM(fp.funnel_shop_details), 0)) AS cvr3_pct
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
-- +----------------------+----------+-------+---------------+-------------------+
-- | country              | cvr3_pct | month | shop_sessions | shop_transactions |
-- +----------------------+----------+-------+---------------+-------------------+
-- | Argentina            |   20,11% | 2.026 |    11.944.549 |         2.401.816 |
-- | Bolivia              |   24,41% | 2.026 |       471.846 |           115.167 |
-- | Chile                |   22,72% | 2.026 |     1.365.601 |           310.276 |
-- | Costa Rica           |    2,70% | 2.026 |           705 |                19 |
-- | República Dominicana |   12,22% | 2.026 |     1.184.081 |           144.689 |
-- | Ecuador              |   11,96% | 2.026 |       673.763 |            80.615 |
-- | El Salvador          |   11,40% | 2.026 |       630.855 |            71.890 |
-- | Guatemala            |   13,91% | 2.026 |       587.931 |            81.767 |
-- | Honduras             |    7,84% | 2.026 |       470.277 |            36.850 |
-- | Nicaragua            |   14,69% | 2.026 |       321.209 |            47.173 |
-- | Panamá               |   34,95% | 2.026 |       248.671 |            86.909 |
-- | Paraguay             |   18,81% | 2.026 |       605.171 |           113.860 |
-- | Perú                 |   27,28% | 2.026 |       909.331 |           248.060 |
-- | Uruguay              |   30,58% | 2.026 |       860.122 |           263.024 |
-- | Venezuela            |    9,40% | 2.026 |           234 |                22 |
-- +----------------------+----------+-------+---------------+-------------------+
