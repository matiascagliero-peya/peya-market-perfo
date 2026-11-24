DECLARE query_name STRING DEFAULT 'Glosario-207-Slow orders %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 207
-- Nombre:     Slow orders %
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-datamarts-pro.dm_fulfillment.non_seamless_delivery_order_level` + `peya-bi-tools-pro.il_core.fact_orders` + `peya-bi-tools-pro.il_core.dim_partner`
-- Tipo:       Ratio Calculado
-- Fórmula:    Slow Orders / Total Orders All Status
-- Definición: Porcentaje de pedidos cuyo tiempo de preparación y despacho en tienda fue anormalmente lento frente a los estándares de Darkstores.
-- ====================================================================================

SELECT
  o.country.country_name AS country,
  DATE_TRUNC(DATE(o.registered_date), MONTH) AS month,
  COUNT(DISTINCT CASE WHEN ns.is_slow_order = 1 THEN o.order_id END) AS slow_orders,
  COUNT(DISTINCT o.order_id) AS total_orders_all_status,
  SAFE_DIVIDE(
    COUNT(DISTINCT CASE WHEN ns.is_slow_order = 1 THEN o.order_id END),
    NULLIF(COUNT(DISTINCT o.order_id), 0)
  ) AS slow_orders_pct
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
-- +----------------------+-------+-------------+-----------------+-------------------------+
-- | country              | month | slow_orders | slow_orders_pct | total_orders_all_status |
-- +----------------------+-------+-------------+-----------------+-------------------------+
-- | Argentina            | 2.026 |     216.346 |           8,04% |               2.689.254 |
-- | Bolivia              | 2.026 |      17.979 |          12,45% |                 144.397 |
-- | Chile                | 2.026 |      32.757 |           9,44% |                 346.919 |
-- | Ecuador              | 2.026 |      11.466 |          11,60% |                  98.848 |
-- | El Salvador          | 2.026 |      13.208 |          15,13% |                  87.268 |
-- | Guatemala            | 2.026 |      20.310 |          20,80% |                  97.654 |
-- | Honduras             | 2.026 |       8.517 |          16,58% |                  51.377 |
-- | Nicaragua            | 2.026 |      10.363 |          18,20% |                  56.933 |
-- | Panam�               | 2.026 |       3.500 |           3,72% |                  94.071 |
-- | Paraguay             | 2.026 |      18.701 |          13,63% |                 137.201 |
-- | Per�                 | 2.026 |      14.585 |           5,26% |                 277.278 |
-- | Rep�blica Dominicana | 2.026 |       8.903 |           5,14% |                 173.094 |
-- | Uruguay              | 2.026 |      21.970 |           7,56% |                 290.698 |
-- +----------------------+-------+-------------+-----------------+-------------------------+
