DECLARE query_name STRING DEFAULT 'Glosario-202-Rejected orders';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 202
-- Nombre:     Rejected orders
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-datamarts-pro.dm_fulfillment.non_seamless_delivery_order_level` + `peya-bi-tools-pro.il_core.fact_orders` + `peya-bi-tools-pro.il_core.dim_partner`
-- Tipo:       Dato Directo
-- Fórmula:    COUNT(DISTINCT order_id) canceladas o rechazadas operacionalmente
-- Definición: Cantidad absoluta de órdenes rechazadas operativamente en tiendas PeYa Market.
-- ====================================================================================

SELECT
  o.country.country_name AS country,
  DATE_TRUNC(DATE(o.registered_date), MONTH) AS month,
  COUNT(DISTINCT CASE WHEN ns.is_rejected_order = 1 THEN o.order_id END) AS rejected_orders
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
-- +----------------------+-------+-----------------+
-- | country              | month | rejected_orders |
-- +----------------------+-------+-----------------+
-- | Argentina            | 2.026 |          32.852 |
-- | Bolivia              | 2.026 |           1.409 |
-- | Chile                | 2.026 |           3.792 |
-- | Ecuador              | 2.026 |           1.358 |
-- | El Salvador          | 2.026 |             931 |
-- | Guatemala            | 2.026 |           1.881 |
-- | Honduras             | 2.026 |             618 |
-- | Nicaragua            | 2.026 |             468 |
-- | Panam�               | 2.026 |           1.014 |
-- | Paraguay             | 2.026 |           1.353 |
-- | Per�                 | 2.026 |           3.445 |
-- | Rep�blica Dominicana | 2.026 |           1.693 |
-- | Uruguay              | 2.026 |           2.269 |
-- +----------------------+-------+-----------------+
