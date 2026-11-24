DECLARE query_name STRING DEFAULT 'Glosario-208-Slow orders';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 208
-- Nombre:     Slow orders
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-datamarts-pro.dm_fulfillment.non_seamless_delivery_order_level` + `peya-bi-tools-pro.il_core.fact_orders` + `peya-bi-tools-pro.il_core.dim_partner`
-- Tipo:       Dato Directo
-- Fórmula:    COUNT(DISTINCT order_id) lentas en preparación/picking
-- Definición: Cantidad total de pedidos con tiempos de preparación excesivamente lentos en tienda.
-- ====================================================================================

SELECT
  o.country.country_name AS country,
  DATE_TRUNC(DATE(o.registered_date), MONTH) AS month,
  COUNT(DISTINCT CASE WHEN ns.is_slow_order = 1 THEN o.order_id END) AS slow_orders
FROM `peya-bi-tools-pro.il_core.fact_orders` o
INNER JOIN `peya-bi-tools-pro.il_core.dim_partner` p ON o.restaurant.id = p.partner_id
LEFT JOIN `peya-datamarts-pro.dm_fulfillment.non_seamless_delivery_order_level` ns
  ON CAST(o.order_id AS STRING) = CAST(ns.platform_order_code AS STRING)
WHERE p.is_darkstore = TRUE
  AND DATE(o.registered_date) BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------+-------------+
-- | country              | month | slow_orders |
-- +----------------------+-------+-------------+
-- | Argentina            | 2.026 |     216.346 |
-- | Bolivia              | 2.026 |      17.979 |
-- | Chile                | 2.026 |      32.757 |
-- | Ecuador              | 2.026 |      11.466 |
-- | El Salvador          | 2.026 |      13.208 |
-- | Guatemala            | 2.026 |      20.310 |
-- | Honduras             | 2.026 |       8.517 |
-- | Nicaragua            | 2.026 |      10.363 |
-- | Panam�               | 2.026 |       3.500 |
-- | Paraguay             | 2.026 |      18.701 |
-- | Per�                 | 2.026 |      14.585 |
-- | Rep�blica Dominicana | 2.026 |       8.903 |
-- | Uruguay              | 2.026 |      21.970 |
-- +----------------------+-------+-------------+
