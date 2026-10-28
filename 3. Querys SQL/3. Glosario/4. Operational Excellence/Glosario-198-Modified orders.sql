DECLARE query_name STRING DEFAULT 'Glosario-198-Modified orders';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 198
-- Nombre:     Modified orders
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-datamarts-pro.dm_fulfillment.non_seamless_delivery_order_level` + `peya-bi-tools-pro.il_core.fact_orders` + `peya-bi-tools-pro.il_core.dim_partner`
-- Tipo:       Dato Directo
-- Fórmula:    COUNT(DISTINCT order_id) con modificaciones/sustituciones
-- Definición: Cantidad total de pedidos confirmados que debieron ser modificados en tienda por falta o sustitución de ítems.
-- ====================================================================================

SELECT
  o.country.country_name AS country,
  DATE_TRUNC(DATE(o.registered_date), MONTH) AS month,
  COUNT(DISTINCT CASE WHEN ns.is_modified_order = 1 THEN o.order_id END) AS modified_orders
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
-- +----------------------+-----------------+-------+
-- | country              | modified_orders | month |
-- +----------------------+-----------------+-------+
-- | Argentina            |          36.503 | 2.026 |
-- | Bolivia              |           1.024 | 2.026 |
-- | Chile                |           4.130 | 2.026 |
-- | Ecuador              |             400 | 2.026 |
-- | El Salvador          |             467 | 2.026 |
-- | Guatemala            |             146 | 2.026 |
-- | Honduras             |             208 | 2.026 |
-- | Nicaragua            |             225 | 2.026 |
-- | Panam�               |           1.067 | 2.026 |
-- | Paraguay             |           1.833 | 2.026 |
-- | Per�                 |           1.652 | 2.026 |
-- | Rep�blica Dominicana |           1.270 | 2.026 |
-- | Uruguay              |           6.489 | 2.026 |
-- +----------------------+-----------------+-------+
