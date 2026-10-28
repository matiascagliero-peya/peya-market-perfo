DECLARE query_name STRING DEFAULT 'Glosario-115-MAUs penetration % - UF';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 115
-- Nombre:     MAUs penetration % - UF
-- Chapter:   Usuarios
-- Query bajada en: 4 - Users / Growth Tracker
-- Sheets Name: 1. ET - Users Type Count (4 - Users)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1X0bnsCoDszeSlq5TT1uw20GWtcfu1iBpshXXI1QIv7M
-- Tablas de origen: `peya-bi-tools-pro.il_core.fact_orders` (RAW) + `peya-bi-tools-pro.il_core.dim_partner`
-- Tipo:       Ratio Calculado
-- Fórmula:    Dmart MAUs Ultra Fresh / Dmart MAUs
-- Definición: Tasa de penetración de categorías frescas: porcentaje de usuarios activos de PeYa Market que compran Ultra Fresh.
-- ====================================================================================

WITH dmart_first_order AS (
  -- Fecha de adopción / primer pedido histórico en PeYa Market
  SELECT
    o.customer_id,
    MIN(DATE(o.registered_date)) AS first_dmart_order_date
  FROM `peya-bi-tools-pro.il_core.fact_orders` o
  INNER JOIN `peya-bi-tools-pro.il_core.dim_partner` p ON o.restaurant.id = p.partner_id
  WHERE o.order_status = 'CONFIRMED'
    AND p.is_darkstore = TRUE
  GROUP BY 1
),
monthly_user_orders AS (
  SELECT
    o.country.country_name AS country,
    DATE_TRUNC(DATE(o.registered_date), MONTH) AS month,
    o.customer_id,
    COUNT(DISTINCT o.order_id) AS orders_in_month,
    IF(DATE_TRUNC(f.first_dmart_order_date, MONTH) = DATE_TRUNC(DATE(o.registered_date), MONTH), 1, 0) AS is_new_user
  FROM `peya-bi-tools-pro.il_core.fact_orders` o
  INNER JOIN `peya-bi-tools-pro.il_core.dim_partner` p ON o.restaurant.id = p.partner_id
  LEFT JOIN dmart_first_order f ON o.customer_id = f.customer_id
  WHERE o.order_status = 'CONFIRMED'
    AND p.is_darkstore = TRUE
    AND DATE(o.registered_date) BETWEEN '2026-09-01' AND '2026-09-30'
  GROUP BY 1, 2, 3, 5
)
SELECT
  country,
  month,
  -- Usuarios activos mensuales en PeYa Market:
  COUNT(DISTINCT customer_id) AS dmart_maus,
  -- Nuevos usuarios (primera orden histórica en el mes):
  COUNT(DISTINCT CASE WHEN is_new_user = 1 THEN customer_id END) AS new_users_dmart,
  -- Usuarios recurrentes en el mes:
  COUNT(DISTINCT CASE WHEN orders_in_month > 1 THEN customer_id END) AS reorder_users_dmart,
  -- Share de nuevos usuarios:
  SAFE_DIVIDE(
    COUNT(DISTINCT CASE WHEN is_new_user = 1 THEN customer_id END),
    NULLIF(COUNT(DISTINCT customer_id), 0)
  ) AS new_users_share_pct
FROM monthly_user_orders
GROUP BY 1, 2
ORDER BY 1 ASC;
