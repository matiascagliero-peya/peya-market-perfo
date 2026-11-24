DECLARE query_name STRING DEFAULT 'Glosario-187-Total_orders_fact_orders';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 187
-- Nombre:     Total_orders_fact_orders
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-bi-tools-pro.il_core.fact_orders` + `peya-bi-tools-pro.il_core.dim_partner`
-- Tipo:       Dato Directo
-- Fórmula:    COUNT(DISTINCT order_id) WHERE order_status = "CONFIRMED"
-- Definición: Total de órdenes de Darkstores registradas en estado CONFIRMED en la fuente transaccional fact_orders.
-- ====================================================================================

SELECT
  o.country.country_name AS country,
  DATE_TRUNC(DATE(o.registered_date), MONTH) AS month,
  COUNT(DISTINCT CASE WHEN o.order_status = 'CONFIRMED' THEN o.order_id END) AS total_orders_fact_orders
FROM `peya-bi-tools-pro.il_core.fact_orders` o
INNER JOIN `peya-bi-tools-pro.il_core.dim_partner` p ON o.restaurant.id = p.partner_id
WHERE p.is_darkstore = TRUE
  AND DATE(o.registered_date) BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------+--------------------------+
-- | country              | month | total_orders_fact_orders |
-- +----------------------+-------+--------------------------+
-- | Argentina            | 2.026 |                2.652.678 |
-- | Bolivia              | 2.026 |                  142.934 |
-- | Chile                | 2.026 |                  342.270 |
-- | Ecuador              | 2.026 |                   97.415 |
-- | El Salvador          | 2.026 |                   86.285 |
-- | Guatemala            | 2.026 |                   95.705 |
-- | Honduras             | 2.026 |                   50.718 |
-- | Nicaragua            | 2.026 |                   56.437 |
-- | Panam�               | 2.026 |                   92.999 |
-- | Paraguay             | 2.026 |                  135.799 |
-- | Per�                 | 2.026 |                  273.381 |
-- | Rep�blica Dominicana | 2.026 |                  171.348 |
-- | Uruguay              | 2.026 |                  287.095 |
-- +----------------------+-------+--------------------------+
