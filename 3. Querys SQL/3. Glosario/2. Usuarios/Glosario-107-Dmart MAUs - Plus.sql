DECLARE query_name STRING DEFAULT 'Glosario-107-Dmart MAUs - Plus';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 107
-- Nombre:     Dmart MAUs - Plus
-- Chapter:   Usuarios
-- Query bajada en: 4 - Users / Growth Tracker
-- Sheets Name: 1. ET - Users Type Count (4 - Users)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1X0bnsCoDszeSlq5TT1uw20GWtcfu1iBpshXXI1QIv7M
-- Tablas de origen: `peya-bi-tools-pro.il_core.fact_orders` (RAW) + `peya-bi-tools-pro.il_core.dim_partner`
-- Tipo:       Dato Directo
-- Fórmula:    COUNT(DISTINCT customer_id) activos en Market con suscripción Plus activa
-- Definición: Usuarios activos mensuales de PeYa Market que poseen una suscripción activa al programa PedidosYa Plus.
-- ====================================================================================

SELECT
  o.country.country_name AS country,
  DATE_TRUNC(DATE(o.registered_date), MONTH) AS month,
  COUNT(DISTINCT o.customer_id) AS dmart_maus_plus
FROM `peya-bi-tools-pro.il_core.fact_orders` o
INNER JOIN `peya-bi-tools-pro.il_core.dim_partner` p ON o.restaurant.id = p.partner_id
WHERE o.order_status = 'CONFIRMED'
  AND p.is_darkstore = TRUE
  AND (o.is_user_plus = 1 OR o.is_user_plus = 1)
  AND DATE(o.registered_date) BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-----------------+-------+
-- | country              | dmart_maus_plus | month |
-- +----------------------+-----------------+-------+
-- | Argentina            |         489.116 | 2.026 |
-- | Bolivia              |          19.504 | 2.026 |
-- | Chile                |          60.498 | 2.026 |
-- | Ecuador              |          20.530 | 2.026 |
-- | El Salvador          |          19.329 | 2.026 |
-- | Guatemala            |          18.412 | 2.026 |
-- | Honduras             |          10.813 | 2.026 |
-- | Nicaragua            |           8.211 | 2.026 |
-- | Panam�               |          15.040 | 2.026 |
-- | Paraguay             |          23.578 | 2.026 |
-- | Per�                 |          53.600 | 2.026 |
-- | Rep�blica Dominicana |          27.664 | 2.026 |
-- | Uruguay              |          31.546 | 2.026 |
-- +----------------------+-----------------+-------+
