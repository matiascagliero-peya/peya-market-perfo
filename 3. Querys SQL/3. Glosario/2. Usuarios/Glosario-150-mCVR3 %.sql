DECLARE query_name STRING DEFAULT 'Glosario-150-mCVR3 %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 150
-- Nombre:     mCVR3 %
-- Chapter:   Usuarios
-- Query bajada en: 4 - Users / Growth Tracker
-- Sheets Name: 1. ET - Users Type Count (4 - Users)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1X0bnsCoDszeSlq5TT1uw20GWtcfu1iBpshXXI1QIv7M
-- Tablas de origen: `peya-bi-tools-pro.il_sessions.perseus_fact_partner_funnel` + `peya-bi-tools-pro.il_core.dim_partner` + `peya-bi-tools-pro.il_core.dim_country`
-- Tipo:       Ratio Calculado
-- Fórmula:    Shop Transactions / Cart Added Sessions
-- Definición: Micro-conversión de carrito: porcentaje de sesiones con intención de compra (agregaron al carrito) que completaron la orden.
-- ====================================================================================

SELECT
  dc.country_name_en AS country,
  DATE_TRUNC(DATE(fp.date), MONTH) AS month,
  SUM(fp.funnel_shop_transaction) AS shop_transactions,
  SUM(fp.funnel_shop_add_cart) AS cart_added_sessions,
  SAFE_DIVIDE(SUM(fp.funnel_shop_transaction), NULLIF(SUM(fp.funnel_shop_add_cart), 0)) AS mcvr3_pct
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
-- +---------------------+----------------------+-----------+-------+-------------------+
-- | cart_added_sessions | country              | mcvr3_pct | month | shop_transactions |
-- +---------------------+----------------------+-----------+-------+-------------------+
-- |           4.341.041 | Argentina            |    55,33% | 2.026 |         2.401.816 |
-- |             200.492 | Bolivia              |    57,44% | 2.026 |           115.167 |
-- |             526.274 | Chile                |    58,96% | 2.026 |           310.276 |
-- |                  58 | Costa Rica           |    32,76% | 2.026 |                19 |
-- |             243.695 | República Dominicana |    59,37% | 2.026 |           144.689 |
-- |             152.300 | Ecuador              |    52,93% | 2.026 |            80.615 |
-- |             113.881 | El Salvador          |    63,13% | 2.026 |            71.890 |
-- |             126.530 | Guatemala            |    64,62% | 2.026 |            81.767 |
-- |              71.937 | Honduras             |    51,23% | 2.026 |            36.850 |
-- |              76.365 | Nicaragua            |    61,77% | 2.026 |            47.173 |
-- |             127.553 | Panamá               |    68,14% | 2.026 |            86.909 |
-- |             175.160 | Paraguay             |    65,00% | 2.026 |           113.860 |
-- |             397.653 | Perú                 |    62,38% | 2.026 |           248.060 |
-- |             376.620 | Uruguay              |    69,84% | 2.026 |           263.024 |
-- |                  68 | Venezuela            |    32,35% | 2.026 |                22 |
-- +---------------------+----------------------+-----------+-------+-------------------+
