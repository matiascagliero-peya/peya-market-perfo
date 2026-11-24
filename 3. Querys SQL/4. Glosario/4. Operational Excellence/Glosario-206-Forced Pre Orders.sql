DECLARE query_name STRING DEFAULT 'Glosario-206-Forced Pre Orders';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 206
-- Nombre:     Forced Pre Orders
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-datamarts-pro.dm_fulfillment.non_seamless_delivery_order_level` + `peya-bi-tools-pro.il_core.fact_orders` + `peya-bi-tools-pro.il_core.dim_partner`
-- Tipo:       Dato Directo
-- Fórmula:    COUNT(DISTINCT order_id) forzadas como pre-orden
-- Definición: Cantidad total de pedidos convertidos forzadamente a pre-órdenes por cuellos de botella en tienda.
-- ====================================================================================

SELECT
  o.country.country_name AS country,
  DATE_TRUNC(DATE(o.registered_date), MONTH) AS month,
  COUNT(DISTINCT CASE WHEN CAST(ns.is_forced_preorder AS STRING) IN ('1','true','TRUE') THEN o.order_id END) AS forced_pre_orders
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
-- +----------------------+-------------------+-------+
-- | country              | forced_pre_orders | month |
-- +----------------------+-------------------+-------+
-- | Argentina            |             5.024 | 2.026 |
-- | Bolivia              |                65 | 2.026 |
-- | Chile                |                 0 | 2.026 |
-- | Ecuador              |                 0 | 2.026 |
-- | El Salvador          |                 0 | 2.026 |
-- | Guatemala            |                31 | 2.026 |
-- | Honduras             |                 0 | 2.026 |
-- | Nicaragua            |                 0 | 2.026 |
-- | Panam�               |                 0 | 2.026 |
-- | Paraguay             |                 0 | 2.026 |
-- | Per�                 |                24 | 2.026 |
-- | Rep�blica Dominicana |                 0 | 2.026 |
-- | Uruguay              |               943 | 2.026 |
-- +----------------------+-------------------+-------+
