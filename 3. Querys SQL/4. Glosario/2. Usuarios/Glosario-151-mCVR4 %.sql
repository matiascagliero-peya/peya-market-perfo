DECLARE query_name STRING DEFAULT 'Glosario-151-mCVR4 %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 151
-- Nombre:     mCVR4 %
-- Chapter:   Usuarios
-- Query bajada en: 4 - Users / Growth Tracker
-- Sheets Name: 1. ET - Users Type Count (4 - Users)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1X0bnsCoDszeSlq5TT1uw20GWtcfu1iBpshXXI1QIv7M
-- Tablas de origen: `peya-bi-tools-pro.il_sessions.perseus_fact_partner_funnel` + `peya-bi-tools-pro.il_core.dim_partner` + `peya-bi-tools-pro.il_core.dim_country`
-- Tipo:       Ratio Calculado
-- Fórmula:    Shop Transactions / Checkout Sessions
-- Definición: Micro-conversión de checkout: porcentaje de sesiones que llegaron a la pantalla de pago y confirmaron exitosamente la orden.
-- ====================================================================================

SELECT
  dc.country_name_en AS country,
  DATE_TRUNC(DATE(fp.date), MONTH) AS month,
  SUM(fp.funnel_shop_transaction) AS shop_transactions,
  SUM(fp.funnel_shop_checkout) AS checkout_sessions,
  SAFE_DIVIDE(SUM(fp.funnel_shop_transaction), NULLIF(SUM(fp.funnel_shop_checkout), 0)) AS mcvr4_pct
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
-- +-------------------+----------------------+-----------+-------+-------------------+
-- | checkout_sessions | country              | mcvr4_pct | month | shop_transactions |
-- +-------------------+----------------------+-----------+-------+-------------------+
-- |         2.692.641 | Argentina            |    89,20% | 2.026 |         2.401.816 |
-- |           143.532 | Bolivia              |    80,24% | 2.026 |           115.167 |
-- |           374.053 | Chile                |    82,95% | 2.026 |           310.276 |
-- |                38 | Costa Rica           |    50,00% | 2.026 |                19 |
-- |           168.903 | República Dominicana |    85,66% | 2.026 |           144.689 |
-- |           100.455 | Ecuador              |    80,25% | 2.026 |            80.615 |
-- |            80.093 | El Salvador          |    89,76% | 2.026 |            71.890 |
-- |            90.757 | Guatemala            |    90,09% | 2.026 |            81.767 |
-- |            42.299 | Honduras             |    87,12% | 2.026 |            36.850 |
-- |            52.533 | Nicaragua            |    89,80% | 2.026 |            47.173 |
-- |            95.989 | Panamá               |    90,54% | 2.026 |            86.909 |
-- |           125.131 | Paraguay             |    90,99% | 2.026 |           113.860 |
-- |           294.923 | Perú                 |    84,11% | 2.026 |           248.060 |
-- |           284.025 | Uruguay              |    92,61% | 2.026 |           263.024 |
-- |                36 | Venezuela            |    61,11% | 2.026 |                22 |
-- +-------------------+----------------------+-----------+-------+-------------------+
