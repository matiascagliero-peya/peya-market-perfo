DECLARE query_name STRING DEFAULT 'Glosario-10-Confirmed Orders share %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 10
-- Nombre:     Confirmed Orders share %
-- Chapter:   Demand Stimulation
-- Query bajada en: 0 - Orders
-- Sheets Name: 1. TD - OKRs Mensual (0 - Orders)
-- Sheets Link: https://docs.google.com/spreadsheets/d/13yTO_kFzIvISmbSz6p93BFUub1HODpuiGhB3yElZ2fw
-- Tablas de origen: `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` + `peya-bi-tools-pro.il_core.fact_orders` + `peya-bi-tools-pro.il_core.dim_partner`
-- Tipo:       Ratio Calculado
-- Fórmula:    Confirmed Orders / Total Platform Confirmed Orders
-- Definición: Participación porcentual de órdenes de PeYa Market sobre el total de PedidosYa.
-- ====================================================================================

SELECT
  o.country.country_name AS country,
  DATE_TRUNC(DATE(o.registered_date), MONTH) AS month,
  COUNT(DISTINCT CASE WHEN dp.is_darkstore = TRUE THEN o.order_id END) AS dmart_confirmed_orders,
  COUNT(DISTINCT o.order_id) AS platform_confirmed_orders,
  SAFE_DIVIDE(
    COUNT(DISTINCT CASE WHEN dp.is_darkstore = TRUE THEN o.order_id END),
    NULLIF(COUNT(DISTINCT o.order_id), 0)
  ) AS confirmed_orders_share_pct
FROM `peya-bi-tools-pro.il_core.fact_orders` o
LEFT JOIN `peya-bi-tools-pro.il_core.dim_partner` dp ON o.restaurant.id = dp.partner_id
WHERE o.order_status = 'CONFIRMED'
  AND DATE(o.registered_date) BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------------+----------------------+------------------------+-------+---------------------------+
-- | confirmed_orders_share_pct | country              | dmart_confirmed_orders | month | platform_confirmed_orders |
-- +----------------------------+----------------------+------------------------+-------+---------------------------+
-- |                     18,98% | Argentina            |              2.652.678 | 2.026 |                13.973.664 |
-- |                      9,35% | Bolivia              |                142.934 | 2.026 |                 1.529.376 |
-- |                      9,95% | Chile                |                342.270 | 2.026 |                 3.440.534 |
-- |                      0,00% | Costa Rica           |                      0 | 2.026 |                   264.160 |
-- |                      6,15% | Ecuador              |                 97.415 | 2.026 |                 1.582.791 |
-- |                      5,66% | El Salvador          |                 86.285 | 2.026 |                 1.523.382 |
-- |                      6,72% | Guatemala            |                 95.705 | 2.026 |                 1.423.209 |
-- |                      3,91% | Honduras             |                 50.718 | 2.026 |                 1.296.102 |
-- |                      5,94% | Nicaragua            |                 56.437 | 2.026 |                   950.679 |
-- |                      6,14% | Panam�               |                 92.999 | 2.026 |                 1.515.070 |
-- |                     13,07% | Paraguay             |                135.799 | 2.026 |                 1.038.798 |
-- |                      8,75% | Per�                 |                273.381 | 2.026 |                 3.123.983 |
-- |                      8,76% | Rep�blica Dominicana |                171.348 | 2.026 |                 1.955.402 |
-- |                     16,67% | Uruguay              |                287.095 | 2.026 |                 1.722.153 |
-- |                      0,00% | Venezuela            |                      0 | 2.026 |                   236.146 |
-- +----------------------------+----------------------+------------------------+-------+---------------------------+
