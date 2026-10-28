DECLARE query_name STRING DEFAULT 'Glosario-11-Confirmed Orders - Plus';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 11
-- Nombre:     Confirmed Orders - Plus
-- Chapter:   Demand Stimulation
-- Query bajada en: 0 - Orders
-- Sheets Name: 1. TD - OKRs Mensual (0 - Orders)
-- Sheets Link: https://docs.google.com/spreadsheets/d/13yTO_kFzIvISmbSz6p93BFUub1HODpuiGhB3yElZ2fw
-- Tablas de origen: `peya-bi-tools-pro.il_core.fact_orders` (RAW) + `peya-bi-tools-pro.il_core.dim_partner`
-- Tipo:       Dato Directo (Col 11)
-- Fórmula:    COUNT(DISTINCT order_id) WHERE is_plus_user = TRUE
-- Definición: Órdenes confirmadas realizadas por clientes con suscripción PedidosYa Plus.
-- ====================================================================================

SELECT
  o.country.country_name AS country,
  DATE_TRUNC(DATE(o.registered_date), MONTH) AS month,
  COUNT(DISTINCT CASE WHEN dp.is_darkstore = TRUE AND o.is_user_plus = 1 THEN o.order_id END) AS confirmed_orders_plus
FROM `peya-bi-tools-pro.il_core.fact_orders` o
INNER JOIN `peya-bi-tools-pro.il_core.dim_partner` dp ON o.restaurant.id = dp.partner_id
WHERE o.order_status = 'CONFIRMED'
  AND dp.is_darkstore = TRUE
  AND DATE(o.registered_date) BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +-----------------------+----------------------+-------+
-- | confirmed_orders_plus | country              | month |
-- +-----------------------+----------------------+-------+
-- |             1.698.670 | Argentina            | 2.026 |
-- |                68.303 | Bolivia              | 2.026 |
-- |               169.300 | Chile                | 2.026 |
-- |                53.797 | Ecuador              | 2.026 |
-- |                57.370 | El Salvador          | 2.026 |
-- |                58.022 | Guatemala            | 2.026 |
-- |                26.622 | Honduras             | 2.026 |
-- |                26.349 | Nicaragua            | 2.026 |
-- |                46.959 | Panam�               | 2.026 |
-- |                81.165 | Paraguay             | 2.026 |
-- |               170.538 | Per�                 | 2.026 |
-- |                89.527 | Rep�blica Dominicana | 2.026 |
-- |               134.490 | Uruguay              | 2.026 |
-- +-----------------------+----------------------+-------+
