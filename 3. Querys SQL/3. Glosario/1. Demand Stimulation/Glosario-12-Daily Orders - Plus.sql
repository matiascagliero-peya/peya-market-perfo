DECLARE query_name STRING DEFAULT 'Glosario-12-Daily Orders - Plus';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 12
-- Nombre:     Daily Orders - Plus
-- Chapter:   Demand Stimulation
-- Query bajada en: 0 - Orders
-- Sheets Name: 1. TD - OKRs Mensual (0 - Orders)
-- Sheets Link: https://docs.google.com/spreadsheets/d/13yTO_kFzIvISmbSz6p93BFUub1HODpuiGhB3yElZ2fw
-- Tablas de origen: `peya-bi-tools-pro.il_core.fact_orders` (RAW) + `peya-bi-tools-pro.il_core.dim_partner`
-- Tipo:       Ratio Calculado
-- Fórmula:    Confirmed Orders - Plus / Días del Mes
-- Definición: Promedio diario de órdenes generadas por usuarios Plus.
-- ====================================================================================

SELECT
  o.country.country_name AS country,
  DATE_TRUNC(DATE(o.registered_date), MONTH) AS month,
  SAFE_DIVIDE(
    COUNT(DISTINCT CASE WHEN dp.is_darkstore = TRUE AND o.is_user_plus = 1 THEN o.order_id END),
    30
  ) AS daily_orders_plus
FROM `peya-bi-tools-pro.il_core.fact_orders` o
INNER JOIN `peya-bi-tools-pro.il_core.dim_partner` dp ON o.restaurant.id = dp.partner_id
WHERE o.order_status = 'CONFIRMED'
  AND dp.is_darkstore = TRUE
  AND DATE(o.registered_date) BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------------------+-------+
-- | country              | daily_orders_plus | month |
-- +----------------------+-------------------+-------+
-- | Argentina            |         56.622,33 | 2.026 |
-- | Bolivia              |          2.276,77 | 2.026 |
-- | Chile                |          5.643,33 | 2.026 |
-- | Ecuador              |          1.793,23 | 2.026 |
-- | El Salvador          |          1.912,33 | 2.026 |
-- | Guatemala            |          1.934,07 | 2.026 |
-- | Honduras             |            887,40 | 2.026 |
-- | Nicaragua            |            878,30 | 2.026 |
-- | Panam�               |          1.565,30 | 2.026 |
-- | Paraguay             |          2.705,50 | 2.026 |
-- | Per�                 |          5.684,60 | 2.026 |
-- | Rep�blica Dominicana |          2.984,23 | 2.026 |
-- | Uruguay              |             4.483 | 2.026 |
-- +----------------------+-------------------+-------+
