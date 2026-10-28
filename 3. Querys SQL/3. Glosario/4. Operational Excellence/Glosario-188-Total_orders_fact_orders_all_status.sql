DECLARE query_name STRING DEFAULT 'Glosario-188-Total_orders_fact_orders_all_status';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 188
-- Nombre:     Total_orders_fact_orders_all_status
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-bi-tools-pro.il_core.fact_orders` + `peya-bi-tools-pro.il_core.dim_partner`
-- Tipo:       Dato Directo
-- Fórmula:    COUNT(DISTINCT order_id) en fact_orders (todos los estados)
-- Definición: Total de órdenes de Darkstores en fact_orders considerando todos los estados (confirmadas, canceladas y rechazadas). Denominador base de la familia Seamless Delivery.
-- ====================================================================================

SELECT
  o.country.country_name AS country,
  DATE_TRUNC(DATE(o.registered_date), MONTH) AS month,
  COUNT(DISTINCT o.order_id) AS total_orders_fact_orders_all_status
FROM `peya-bi-tools-pro.il_core.fact_orders` o
INNER JOIN `peya-bi-tools-pro.il_core.dim_partner` p ON o.restaurant.id = p.partner_id
WHERE p.is_darkstore = TRUE
  AND DATE(o.registered_date) BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------+-------------------------------------+
-- | country              | month | total_orders_fact_orders_all_status |
-- +----------------------+-------+-------------------------------------+
-- | Argentina            | 2.026 |                           2.689.254 |
-- | Bolivia              | 2.026 |                             144.397 |
-- | Chile                | 2.026 |                             346.919 |
-- | Ecuador              | 2.026 |                              98.848 |
-- | El Salvador          | 2.026 |                              87.268 |
-- | Guatemala            | 2.026 |                              97.654 |
-- | Honduras             | 2.026 |                              51.377 |
-- | Nicaragua            | 2.026 |                              56.933 |
-- | Panam�               | 2.026 |                              94.071 |
-- | Paraguay             | 2.026 |                             137.201 |
-- | Per�                 | 2.026 |                             277.278 |
-- | Rep�blica Dominicana | 2.026 |                             173.094 |
-- | Uruguay              | 2.026 |                             290.698 |
-- +----------------------+-------+-------------------------------------+
