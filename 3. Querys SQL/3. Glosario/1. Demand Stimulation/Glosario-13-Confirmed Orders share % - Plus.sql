DECLARE query_name STRING DEFAULT 'Glosario-13-Confirmed Orders share % - Plus';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 13
-- Nombre:     Confirmed Orders share % - Plus
-- Chapter:   Demand Stimulation
-- Query bajada en: 0 - Orders
-- Sheets Name: 1. TD - OKRs Mensual (0 - Orders)
-- Sheets Link: https://docs.google.com/spreadsheets/d/13yTO_kFzIvISmbSz6p93BFUub1HODpuiGhB3yElZ2fw
-- Tablas de origen: `peya-bi-tools-pro.il_core.fact_orders` (RAW) + `peya-bi-tools-pro.il_core.dim_partner`
-- Tipo:       Ratio Calculado
-- Fórmula:    Confirmed Orders - Plus / Confirmed Orders
-- Definición: Porcentaje de órdenes Plus sobre el total de órdenes de Market.
-- ====================================================================================

SELECT
  o.country.country_name AS country,
  DATE_TRUNC(DATE(o.registered_date), MONTH) AS month,
  COUNT(DISTINCT CASE WHEN dp.is_darkstore = TRUE AND o.is_user_plus = 1 THEN o.order_id END) AS dmart_plus_orders,
  COUNT(DISTINCT CASE WHEN dp.is_darkstore = TRUE THEN o.order_id END) AS dmart_total_orders,
  SAFE_DIVIDE(
    COUNT(DISTINCT CASE WHEN dp.is_darkstore = TRUE AND o.is_user_plus = 1 THEN o.order_id END),
    NULLIF(COUNT(DISTINCT CASE WHEN dp.is_darkstore = TRUE THEN o.order_id END), 0)
  ) AS confirmed_orders_share_plus_pct
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
-- +---------------------------------+----------------------+-------------------+--------------------+-------+
-- | confirmed_orders_share_plus_pct | country              | dmart_plus_orders | dmart_total_orders | month |
-- +---------------------------------+----------------------+-------------------+--------------------+-------+
-- |                          64,04% | Argentina            |         1.698.670 |          2.652.678 | 2.026 |
-- |                          47,79% | Bolivia              |            68.303 |            142.934 | 2.026 |
-- |                          49,46% | Chile                |           169.300 |            342.270 | 2.026 |
-- |                          55,22% | Ecuador              |            53.797 |             97.415 | 2.026 |
-- |                          66,49% | El Salvador          |            57.370 |             86.285 | 2.026 |
-- |                          60,63% | Guatemala            |            58.022 |             95.705 | 2.026 |
-- |                          52,49% | Honduras             |            26.622 |             50.718 | 2.026 |
-- |                          46,69% | Nicaragua            |            26.349 |             56.437 | 2.026 |
-- |                          50,49% | Panam�               |            46.959 |             92.999 | 2.026 |
-- |                          59,77% | Paraguay             |            81.165 |            135.799 | 2.026 |
-- |                          62,38% | Per�                 |           170.538 |            273.381 | 2.026 |
-- |                          52,25% | Rep�blica Dominicana |            89.527 |            171.348 | 2.026 |
-- |                          46,85% | Uruguay              |           134.490 |            287.095 | 2.026 |
-- +---------------------------------+----------------------+-------------------+--------------------+-------+
