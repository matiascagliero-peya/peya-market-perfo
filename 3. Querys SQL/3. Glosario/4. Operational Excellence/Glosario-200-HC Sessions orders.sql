DECLARE query_name STRING DEFAULT 'Glosario-200-HC Sessions orders';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 200
-- Nombre:     HC Sessions orders
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-bi-tools-pro.il_sessions.perseus_fact_partner_funnel` + `peya-bi-tools-pro.il_core.dim_partner` + `peya-bi-tools-pro.il_core.fact_orders` + `peya-datamarts-pro.dm_fulfillment.non_seamless_delivery_order_level`
-- Tipo:       Dato Directo
-- Fórmula:    COUNT(DISTINCT order_id) con sesiones de Help Center / contacto de soporte
-- Definición: Cantidad total de pedidos que generaron al menos una sesión de contacto o reclamo en el centro de soporte.
-- ====================================================================================

SELECT
  o.country.country_name AS country,
  DATE_TRUNC(DATE(o.registered_date), MONTH) AS month,
  COUNT(DISTINCT CASE WHEN CAST(ns.is_session_order AS STRING) IN ('1','true','TRUE') THEN o.order_id END) AS hc_session_orders
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
-- | country              | hc_session_orders | month |
-- +----------------------+-------------------+-------+
-- | Argentina            |           171.730 | 2.026 |
-- | Bolivia              |             9.042 | 2.026 |
-- | Chile                |            20.948 | 2.026 |
-- | Ecuador              |             6.325 | 2.026 |
-- | El Salvador          |             4.061 | 2.026 |
-- | Guatemala            |             4.577 | 2.026 |
-- | Honduras             |             2.871 | 2.026 |
-- | Nicaragua            |             2.939 | 2.026 |
-- | Panam�               |             5.267 | 2.026 |
-- | Paraguay             |             6.312 | 2.026 |
-- | Per�                 |            15.509 | 2.026 |
-- | Rep�blica Dominicana |             9.246 | 2.026 |
-- | Uruguay              |            13.655 | 2.026 |
-- +----------------------+-------------------+-------+
