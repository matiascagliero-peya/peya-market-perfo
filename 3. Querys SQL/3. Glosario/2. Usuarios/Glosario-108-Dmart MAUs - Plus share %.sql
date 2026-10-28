DECLARE query_name STRING DEFAULT 'Glosario-108-Dmart MAUs - Plus share %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 108
-- Nombre:     Dmart MAUs - Plus share %
-- Chapter:   Usuarios
-- Query bajada en: 4 - Users / Growth Tracker
-- Sheets Name: 1. ET - Users Type Count (4 - Users)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1X0bnsCoDszeSlq5TT1uw20GWtcfu1iBpshXXI1QIv7M
-- Tablas de origen: `peya-bi-tools-pro.il_core.fact_orders` (RAW) + `peya-bi-tools-pro.il_core.dim_partner`
-- Tipo:       Ratio Calculado
-- Fórmula:    Dmart MAUs Plus / Dmart MAUs
-- Definición: Porcentaje de usuarios de PeYa Market con suscripción activa a PedidosYa Plus sobre el total de MAUs de tienda.
-- ====================================================================================

SELECT
  o.country.country_name AS country,
  DATE_TRUNC(DATE(o.registered_date), MONTH) AS month,
  COUNT(DISTINCT CASE WHEN (o.is_user_plus = 1 OR o.is_user_plus = 1) THEN o.customer_id END) AS dmart_maus_plus,
  COUNT(DISTINCT o.customer_id) AS dmart_maus_total,
  SAFE_DIVIDE(
    COUNT(DISTINCT CASE WHEN (o.is_user_plus = 1 OR o.is_user_plus = 1) THEN o.customer_id END),
    NULLIF(COUNT(DISTINCT o.customer_id), 0)
  ) AS dmart_maus_plus_share_pct
FROM `peya-bi-tools-pro.il_core.fact_orders` o
INNER JOIN `peya-bi-tools-pro.il_core.dim_partner` p ON o.restaurant.id = p.partner_id
WHERE o.order_status = 'CONFIRMED'
  AND p.is_darkstore = TRUE
  AND DATE(o.registered_date) BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-----------------+---------------------------+------------------+-------+
-- | country              | dmart_maus_plus | dmart_maus_plus_share_pct | dmart_maus_total | month |
-- +----------------------+-----------------+---------------------------+------------------+-------+
-- | Argentina            |         489.116 |                    49,64% |          985.345 | 2.026 |
-- | Bolivia              |          19.504 |                    33,17% |           58.807 | 2.026 |
-- | Chile                |          60.498 |                    40,39% |          149.793 | 2.026 |
-- | Ecuador              |          20.530 |                    44,36% |           46.278 | 2.026 |
-- | El Salvador          |          19.329 |                    56,65% |           34.118 | 2.026 |
-- | Guatemala            |          18.412 |                    48,06% |           38.307 | 2.026 |
-- | Honduras             |          10.813 |                    43,10% |           25.088 | 2.026 |
-- | Nicaragua            |           8.211 |                    35,42% |           23.179 | 2.026 |
-- | Panam�               |          15.040 |                    39,06% |           38.505 | 2.026 |
-- | Paraguay             |          23.578 |                    47,39% |           49.755 | 2.026 |
-- | Per�                 |          53.600 |                    48,07% |          111.513 | 2.026 |
-- | Rep�blica Dominicana |          27.664 |                    40,35% |           68.562 | 2.026 |
-- | Uruguay              |          31.546 |                    34,15% |           92.375 | 2.026 |
-- +----------------------+-----------------+---------------------------+------------------+-------+
