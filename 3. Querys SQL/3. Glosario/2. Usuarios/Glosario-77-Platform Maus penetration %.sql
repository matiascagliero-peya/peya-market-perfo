DECLARE query_name STRING DEFAULT 'Glosario-77-Platform Maus penetration %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 77
-- Nombre:     Platform Maus penetration %
-- Chapter:   Usuarios
-- Query bajada en: 4 - Users / Growth Tracker
-- Sheets Name: 1. ET - Users Type Count (4 - Users)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1X0bnsCoDszeSlq5TT1uw20GWtcfu1iBpshXXI1QIv7M
-- Tablas de origen: `peya-bi-tools-pro.il_core.fact_orders` (RAW) + `peya-bi-tools-pro.il_core.dim_partner`
-- Tipo:       Ratio Calculado
-- Fórmula:    Dmart MAUs / PeYa MAUs
-- Definición: Tasa de penetración de clientes activos de PeYa Market sobre el universo total de usuarios activos de la plataforma (Dmart MAUs / PeYa MAUs).
-- ====================================================================================

SELECT
  o.country.country_name AS country,
  DATE_TRUNC(DATE(o.registered_date), MONTH) AS month,
  -- Pedidos de toda la plataforma:
  COUNT(DISTINCT o.order_id) AS total_platform_confirmed_orders,
  -- Pedidos exclusivos de PeYa Market (Darkstores):
  COUNT(DISTINCT CASE WHEN dp.is_darkstore = TRUE THEN o.order_id END) AS dmart_confirmed_orders,
  -- Pedidos con suscripción Plus activa:
  COUNT(DISTINCT CASE WHEN dp.is_darkstore = TRUE AND (o.is_user_plus = 1 OR o.user.is_user_plus = TRUE) THEN o.order_id END) AS dmart_plus_orders,
  -- Share de órdenes Plus en Market:
  SAFE_DIVIDE(
    COUNT(DISTINCT CASE WHEN dp.is_darkstore = TRUE AND (o.is_user_plus = 1 OR o.user.is_user_plus = TRUE) THEN o.order_id END),
    NULLIF(COUNT(DISTINCT CASE WHEN dp.is_darkstore = TRUE THEN o.order_id END), 0)
  ) AS plus_orders_share,
  -- Share de órdenes Market sobre la plataforma:
  SAFE_DIVIDE(
    COUNT(DISTINCT CASE WHEN dp.is_darkstore = TRUE THEN o.order_id END),
    NULLIF(COUNT(DISTINCT o.order_id), 0)
  ) AS dmart_orders_share_platform
FROM `peya-bi-tools-pro.il_core.fact_orders` o
LEFT JOIN `peya-bi-tools-pro.il_core.dim_partner` dp
  ON o.restaurant.id = dp.partner_id
WHERE o.order_status = 'CONFIRMED'
  AND DATE(o.registered_date) BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+------------+-------------------------------+
-- | country              | month      | platform_maus_penetration_pct |
-- +----------------------+------------+-------------------------------+
-- | Argentina            | 2026-09-01 |                       100,00% |
-- | Bolivia              | 2026-09-01 |                       100,00% |
-- | Chile                | 2026-09-01 |                       100,00% |
-- | Ecuador              | 2026-09-01 |                       100,00% |
-- | El Salvador          | 2026-09-01 |                       100,00% |
-- | Guatemala            | 2026-09-01 |                       100,00% |
-- | Honduras             | 2026-09-01 |                       100,00% |
-- | Nicaragua            | 2026-09-01 |                       100,00% |
-- | Panam�               | 2026-09-01 |                       100,00% |
-- | Paraguay             | 2026-09-01 |                       100,00% |
-- | Per�                 | 2026-09-01 |                       100,00% |
-- | Rep�blica Dominicana | 2026-09-01 |                       100,00% |
-- | Uruguay              | 2026-09-01 |                       100,00% |
-- +----------------------+------------+-------------------------------+
