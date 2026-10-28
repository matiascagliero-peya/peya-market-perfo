DECLARE query_name STRING DEFAULT 'Glosario-203-Late Orders %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 203
-- Nombre:     Late Orders %
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-datamarts-pro.dm_fulfillment.non_seamless_delivery_order_level` + `peya-bi-tools-pro.il_core.fact_orders` + `peya-bi-tools-pro.il_core.dim_partner`
-- Tipo:       Ratio Calculado
-- Fórmula:    Late Orders / Total Orders All Status
-- Definición: Porcentaje de pedidos cuya entrega al cliente superó el tiempo estimado de llegada prometido (ETA).
-- ====================================================================================

SELECT
  o.country.country_name AS country,
  DATE_TRUNC(DATE(o.registered_date), MONTH) AS month,
  COUNT(DISTINCT CASE WHEN ns.is_late_order = 1 THEN o.order_id END) AS late_orders,
  COUNT(DISTINCT o.order_id) AS total_orders_all_status,
  SAFE_DIVIDE(
    COUNT(DISTINCT CASE WHEN ns.is_late_order = 1 THEN o.order_id END),
    NULLIF(COUNT(DISTINCT o.order_id), 0)
  ) AS late_orders_pct
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
-- +----------------------+-------------+-----------------+-------+-------------------------+
-- | country              | late_orders | late_orders_pct | month | total_orders_all_status |
-- +----------------------+-------------+-----------------+-------+-------------------------+
-- | Argentina            |     102.945 |           3,83% | 2.026 |               2.689.254 |
-- | Bolivia              |       4.639 |           3,21% | 2.026 |                 144.397 |
-- | Chile                |      15.654 |           4,51% | 2.026 |                 346.919 |
-- | Ecuador              |       4.087 |           4,13% | 2.026 |                  98.848 |
-- | El Salvador          |       3.513 |           4,03% | 2.026 |                  87.268 |
-- | Guatemala            |       4.560 |           4,67% | 2.026 |                  97.654 |
-- | Honduras             |       1.938 |           3,77% | 2.026 |                  51.377 |
-- | Nicaragua            |       1.644 |           2,89% | 2.026 |                  56.933 |
-- | Panam�               |       2.024 |           2,15% | 2.026 |                  94.071 |
-- | Paraguay             |       4.426 |           3,23% | 2.026 |                 137.201 |
-- | Per�                 |       9.320 |           3,36% | 2.026 |                 277.278 |
-- | Rep�blica Dominicana |       3.943 |           2,28% | 2.026 |                 173.094 |
-- | Uruguay              |       8.445 |           2,91% | 2.026 |                 290.698 |
-- +----------------------+-------------+-----------------+-------+-------------------------+
