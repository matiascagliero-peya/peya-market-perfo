DECLARE query_name STRING DEFAULT 'Glosario-196-Seamless Delivery orders';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 196
-- Nombre:     Seamless Delivery orders
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-datamarts-pro.dm_fulfillment.non_seamless_delivery_order_level` + `peya-bi-tools-pro.il_core.fact_orders` + `peya-bi-tools-pro.il_core.dim_partner`
-- Tipo:       Dato Directo
-- Fórmula:    COUNT(DISTINCT order_id) sin fricciones operacionales
-- Definición: Cantidad absoluta de pedidos completados con experiencia de entrega perfecta sin incidentes operativos.
-- ====================================================================================

SELECT
  o.country.country_name AS country,
  DATE_TRUNC(DATE(o.registered_date), MONTH) AS month,
  COUNT(DISTINCT CASE WHEN ns.order_id IS NULL OR ns.non_seamless_order = 0 THEN o.order_id END) AS seamless_delivery_orders
FROM `peya-bi-tools-pro.il_core.fact_orders` o
INNER JOIN `peya-bi-tools-pro.il_core.dim_partner` p ON o.restaurant.id = p.partner_id
LEFT JOIN `peya-datamarts-pro.dm_fulfillment.non_seamless_delivery_order_level` ns
  ON CAST(o.order_id AS STRING) = CAST(ns.platform_order_code AS STRING)
WHERE p.is_darkstore = TRUE
  AND DATE(o.registered_date) BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;
