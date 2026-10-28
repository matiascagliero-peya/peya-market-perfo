DECLARE query_name STRING DEFAULT 'Glosario-121-Dmart MAUs - Plus - UF';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 121
-- Nombre:     Dmart MAUs - Plus - UF
-- Chapter:   Usuarios
-- Query bajada en: 4 - Users / Growth Tracker
-- Sheets Name: 1. ET - Users Type Count (4 - Users)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1X0bnsCoDszeSlq5TT1uw20GWtcfu1iBpshXXI1QIv7M
-- Tablas de origen: `peya-bi-tools-pro.il_core.fact_orders` (RAW) + `peya-bi-tools-pro.il_core.dim_partner`
-- Tipo:       Dato Directo
-- Fórmula:    COUNT(DISTINCT customer_id) activos con Plus que compraron Ultra Fresh
-- Definición: Cantidad de usuarios activos de PeYa Market que combinan suscripción PedidosYa Plus y compra de productos Ultra Fresh.
-- ====================================================================================

SELECT
  o.country.country_name AS country,
  DATE_TRUNC(DATE(o.registered_date), MONTH) AS month,
  -- Pedidos de toda la plataforma:
  COUNT(DISTINCT o.order_id) AS total_platform_confirmed_orders,
  -- Pedidos exclusivos de PeYa Market (Darkstores):
  COUNT(DISTINCT CASE WHEN dp.is_darkstore = TRUE THEN o.order_id END) AS dmart_confirmed_orders,
  -- Pedidos con suscripción Plus activa:
  COUNT(DISTINCT CASE WHEN dp.is_darkstore = TRUE AND (o.is_user_plus = 1 OR o.is_user_plus = 1) THEN o.order_id END) AS dmart_plus_orders,
  -- Share de órdenes Plus en Market:
  SAFE_DIVIDE(
    COUNT(DISTINCT CASE WHEN dp.is_darkstore = TRUE AND (o.is_user_plus = 1 OR o.is_user_plus = 1) THEN o.order_id END),
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
-- +----------------------+------------------------+-----------------------------+-------------------+-------+-------------------+---------------------------------+
-- | country              | dmart_confirmed_orders | dmart_orders_share_platform | dmart_plus_orders | month | plus_orders_share | total_platform_confirmed_orders |
-- +----------------------+------------------------+-----------------------------+-------------------+-------+-------------------+---------------------------------+
-- | Argentina            |              2.652.678 |                      18,98% |         1.698.670 | 2.026 |            64,04% |                      13.973.664 |
-- | Bolivia              |                142.934 |                       9,35% |            68.303 | 2.026 |            47,79% |                       1.529.376 |
-- | Chile                |                342.270 |                       9,95% |           169.300 | 2.026 |            49,46% |                       3.440.534 |
-- | Costa Rica           |                      0 |                       0,00% |                 0 | 2.026 | -                 |                         264.160 |
-- | Ecuador              |                 97.415 |                       6,15% |            53.797 | 2.026 |            55,22% |                       1.582.791 |
-- | El Salvador          |                 86.285 |                       5,66% |            57.370 | 2.026 |            66,49% |                       1.523.382 |
-- | Guatemala            |                 95.705 |                       6,72% |            58.022 | 2.026 |            60,63% |                       1.423.209 |
-- | Honduras             |                 50.718 |                       3,91% |            26.622 | 2.026 |            52,49% |                       1.296.102 |
-- | Nicaragua            |                 56.437 |                       5,94% |            26.349 | 2.026 |            46,69% |                         950.679 |
-- | Panam�               |                 92.999 |                       6,14% |            46.959 | 2.026 |            50,49% |                       1.515.070 |
-- | Paraguay             |                135.799 |                      13,07% |            81.165 | 2.026 |            59,77% |                       1.038.798 |
-- | Per�                 |                273.381 |                       8,75% |           170.538 | 2.026 |            62,38% |                       3.123.983 |
-- | Rep�blica Dominicana |                171.348 |                       8,76% |            89.527 | 2.026 |            52,25% |                       1.955.402 |
-- | Uruguay              |                287.095 |                      16,67% |           134.490 | 2.026 |            46,85% |                       1.722.153 |
-- | Venezuela            |                      0 |                       0,00% |                 0 | 2.026 | -                 |                         236.146 |
-- +----------------------+------------------------+-----------------------------+-------------------+-------+-------------------+---------------------------------+
