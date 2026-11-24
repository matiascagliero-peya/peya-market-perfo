DECLARE query_name STRING DEFAULT 'Glosario-201-Rejected orders %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 201
-- Nombre:     Rejected orders %
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-datamarts-pro.dm_fulfillment.non_seamless_delivery_order_level` + `peya-bi-tools-pro.il_core.fact_orders` + `peya-bi-tools-pro.il_core.dim_partner`
-- Tipo:       Ratio Calculado
-- Fórmula:    Rejected Orders / Total Orders All Status
-- Definición: Porcentaje de órdenes canceladas o rechazadas por la tienda o por la plataforma antes o durante su preparación.
-- ====================================================================================

SELECT
  o.country.country_name AS country,
  DATE_TRUNC(DATE(o.registered_date), MONTH) AS month,
  COUNT(DISTINCT CASE WHEN ns.is_rejected_order = 1 THEN o.order_id END) AS rejected_orders,
  COUNT(DISTINCT o.order_id) AS total_orders_all_status,
  SAFE_DIVIDE(
    COUNT(DISTINCT CASE WHEN ns.is_rejected_order = 1 THEN o.order_id END),
    NULLIF(COUNT(DISTINCT o.order_id), 0)
  ) AS rejected_orders_pct
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
-- +----------------------+-------+-----------------+---------------------+-------------------------+
-- | country              | month | rejected_orders | rejected_orders_pct | total_orders_all_status |
-- +----------------------+-------+-----------------+---------------------+-------------------------+
-- | Argentina            | 2.026 |          32.852 |               1,22% |               2.689.254 |
-- | Bolivia              | 2.026 |           1.409 |               0,98% |                 144.397 |
-- | Chile                | 2.026 |           3.792 |               1,09% |                 346.919 |
-- | Ecuador              | 2.026 |           1.358 |               1,37% |                  98.848 |
-- | El Salvador          | 2.026 |             931 |               1,07% |                  87.268 |
-- | Guatemala            | 2.026 |           1.881 |               1,93% |                  97.654 |
-- | Honduras             | 2.026 |             618 |               1,20% |                  51.377 |
-- | Nicaragua            | 2.026 |             468 |               0,82% |                  56.933 |
-- | Panam�               | 2.026 |           1.014 |               1,08% |                  94.071 |
-- | Paraguay             | 2.026 |           1.353 |               0,99% |                 137.201 |
-- | Per�                 | 2.026 |           3.445 |               1,24% |                 277.278 |
-- | Rep�blica Dominicana | 2.026 |           1.693 |               0,98% |                 173.094 |
-- | Uruguay              | 2.026 |           2.269 |               0,78% |                 290.698 |
-- +----------------------+-------+-----------------+---------------------+-------------------------+
