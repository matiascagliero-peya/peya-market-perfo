DECLARE query_name STRING DEFAULT 'Glosario-197-Modified orders %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 197
-- Nombre:     Modified orders %
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-datamarts-pro.dm_fulfillment.non_seamless_delivery_order_level` + `peya-bi-tools-pro.il_core.fact_orders` + `peya-bi-tools-pro.il_core.dim_partner`
-- Tipo:       Ratio Calculado
-- Fórmula:    Modified Orders / Total Orders All Status
-- Definición: Porcentaje de órdenes que sufrieron modificaciones en sus productos (sustituciones, faltantes o ajustes de cantidad) durante el picking.
-- ====================================================================================

SELECT
  o.country.country_name AS country,
  DATE_TRUNC(DATE(o.registered_date), MONTH) AS month,
  COUNT(DISTINCT CASE WHEN ns.is_modified_order = 1 THEN o.order_id END) AS modified_orders,
  COUNT(DISTINCT o.order_id) AS total_orders_all_status,
  SAFE_DIVIDE(
    COUNT(DISTINCT CASE WHEN ns.is_modified_order = 1 THEN o.order_id END),
    NULLIF(COUNT(DISTINCT o.order_id), 0)
  ) AS modified_orders_pct
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
-- +----------------------+-----------------+---------------------+-------+-------------------------+
-- | country              | modified_orders | modified_orders_pct | month | total_orders_all_status |
-- +----------------------+-----------------+---------------------+-------+-------------------------+
-- | Argentina            |          36.503 |               1,36% | 2.026 |               2.689.254 |
-- | Bolivia              |           1.024 |               0,71% | 2.026 |                 144.397 |
-- | Chile                |           4.130 |               1,19% | 2.026 |                 346.919 |
-- | Ecuador              |             400 |               0,40% | 2.026 |                  98.848 |
-- | El Salvador          |             467 |               0,54% | 2.026 |                  87.268 |
-- | Guatemala            |             146 |               0,15% | 2.026 |                  97.654 |
-- | Honduras             |             208 |               0,40% | 2.026 |                  51.377 |
-- | Nicaragua            |             225 |               0,40% | 2.026 |                  56.933 |
-- | Panam�               |           1.067 |               1,13% | 2.026 |                  94.071 |
-- | Paraguay             |           1.833 |               1,34% | 2.026 |                 137.201 |
-- | Per�                 |           1.652 |               0,60% | 2.026 |                 277.278 |
-- | Rep�blica Dominicana |           1.270 |               0,73% | 2.026 |                 173.094 |
-- | Uruguay              |           6.489 |               2,23% | 2.026 |                 290.698 |
-- +----------------------+-----------------+---------------------+-------+-------------------------+
