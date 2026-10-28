DECLARE query_name STRING DEFAULT 'Glosario-199-HC Sessions orders %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 199
-- Nombre:     HC Sessions orders %
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-bi-tools-pro.il_sessions.perseus_fact_partner_funnel` + `peya-bi-tools-pro.il_core.dim_partner` + `peya-bi-tools-pro.il_core.fact_orders` + `peya-datamarts-pro.dm_fulfillment.non_seamless_delivery_order_level`
-- Tipo:       Ratio Calculado
-- Fórmula:    HC Sessions Orders / Total Orders All Status
-- Definición: Porcentaje de pedidos que motivaron al cliente a contactar al centro de ayuda y soporte (Help Center) por dudas o quejas.
-- ====================================================================================

SELECT
  o.country.country_name AS country,
  DATE_TRUNC(DATE(o.registered_date), MONTH) AS month,
  COUNT(DISTINCT CASE WHEN CAST(ns.is_session_order AS STRING) IN ('1','true','TRUE') THEN o.order_id END) AS hc_session_orders,
  COUNT(DISTINCT o.order_id) AS total_orders_all_status,
  SAFE_DIVIDE(
    COUNT(DISTINCT CASE WHEN CAST(ns.is_session_order AS STRING) IN ('1','true','TRUE') THEN o.order_id END),
    NULLIF(COUNT(DISTINCT o.order_id), 0)
  ) AS hc_session_orders_pct
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
-- +----------------------+-------------------+-----------------------+-------+-------------------------+
-- | country              | hc_session_orders | hc_session_orders_pct | month | total_orders_all_status |
-- +----------------------+-------------------+-----------------------+-------+-------------------------+
-- | Argentina            |           171.730 |                 6,39% | 2.026 |               2.689.254 |
-- | Bolivia              |             9.042 |                 6,26% | 2.026 |                 144.397 |
-- | Chile                |            20.948 |                 6,04% | 2.026 |                 346.919 |
-- | Ecuador              |             6.325 |                 6,40% | 2.026 |                  98.848 |
-- | El Salvador          |             4.061 |                 4,65% | 2.026 |                  87.268 |
-- | Guatemala            |             4.577 |                 4,69% | 2.026 |                  97.654 |
-- | Honduras             |             2.871 |                 5,59% | 2.026 |                  51.377 |
-- | Nicaragua            |             2.939 |                 5,16% | 2.026 |                  56.933 |
-- | Panam�               |             5.267 |                 5,60% | 2.026 |                  94.071 |
-- | Paraguay             |             6.312 |                 4,60% | 2.026 |                 137.201 |
-- | Per�                 |            15.509 |                 5,59% | 2.026 |                 277.278 |
-- | Rep�blica Dominicana |             9.246 |                 5,34% | 2.026 |                 173.094 |
-- | Uruguay              |            13.655 |                 4,70% | 2.026 |                 290.698 |
-- +----------------------+-------------------+-----------------------+-------+-------------------------+
