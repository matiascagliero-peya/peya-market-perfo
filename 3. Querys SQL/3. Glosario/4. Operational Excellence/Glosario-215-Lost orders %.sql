DECLARE query_name STRING DEFAULT 'Glosario-215-Lost orders %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 215
-- Nombre:     Lost orders %
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-delivery-and-support.automated_tables_reports.dmarts_ops_daily_new` + `peya-bi-tools-pro.il_core.fact_orders` + `peya-bi-tools-pro.il_core.dim_partner`
-- Tipo:       Ratio Calculado
-- Fórmula:    Lost Orders / Total Orders All Status
-- Definición: Porcentaje estimado de ventas o sesiones de compra frustradas por indisponibilidad de productos críticos en catálogo.
-- ====================================================================================

SELECT
  o.country.country_name AS country,
  DATE_TRUNC(DATE(o.registered_date), MONTH) AS month,
  SUM(ops.lost_sessions) AS lost_orders,
  COUNT(DISTINCT o.order_id) AS total_orders_all_status,
  SAFE_DIVIDE(
    SUM(ops.lost_sessions),
    NULLIF(COUNT(DISTINCT o.order_id), 0)
  ) AS lost_orders_pct
FROM `peya-bi-tools-pro.il_core.fact_orders` o
INNER JOIN `peya-bi-tools-pro.il_core.dim_partner` p ON o.restaurant.id = p.partner_id
LEFT JOIN (
  SELECT
    country_name,
    DATE_TRUNC(DATE(date), MONTH) AS month,
    SUM(lost_sessions) AS lost_sessions
  FROM `peya-delivery-and-support.automated_tables_reports.dmarts_ops_daily_new`
  WHERE DATE(date) BETWEEN '2026-09-01' AND '2026-09-30'
  GROUP BY 1, 2
) ops ON LOWER(o.country.country_name) = LOWER(ops.country_name) AND DATE_TRUNC(DATE(o.registered_date), MONTH) = ops.month
WHERE p.is_darkstore = TRUE
  AND DATE(o.registered_date) BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------------+-----------------+-------+-------------------------+
-- | country              | lost_orders | lost_orders_pct | month | total_orders_all_status |
-- +----------------------+-------------+-----------------+-------+-------------------------+
-- | Argentina            | -           | -               | 2.026 |               2.689.254 |
-- | Bolivia              | -           | -               | 2.026 |                 144.397 |
-- | Chile                | -           | -               | 2.026 |                 346.919 |
-- | Ecuador              | -           | -               | 2.026 |                  98.848 |
-- | El Salvador          | -           | -               | 2.026 |                  87.268 |
-- | Guatemala            | -           | -               | 2.026 |                  97.654 |
-- | Honduras             | -           | -               | 2.026 |                  51.377 |
-- | Nicaragua            | -           | -               | 2.026 |                  56.933 |
-- | Panam�               | -           | -               | 2.026 |                  94.071 |
-- | Paraguay             | -           | -               | 2.026 |                 137.201 |
-- | Per�                 | -           | -               | 2.026 |                 277.278 |
-- | Rep�blica Dominicana | -           | -               | 2.026 |                 173.094 |
-- | Uruguay              | -           | -               | 2.026 |                 290.698 |
-- +----------------------+-------------+-----------------+-------+-------------------------+
