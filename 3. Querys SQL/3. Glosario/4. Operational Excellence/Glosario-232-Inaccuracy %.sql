DECLARE query_name STRING DEFAULT 'Glosario-232-Inaccuracy %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 232
-- Nombre:     Inaccuracy %
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-delivery-and-support.automated_tables_reports.dmarts_inaccuracy`
-- Tipo:       Ratio Calculado
-- Fórmula:    SUM(total_complaint_orders) / Total Orders Inaccuracy
-- Definición: Tasa de quejas e incidencias por pedidos incorrectos, faltantes o dañados sobre el total de órdenes despachadas.
-- ====================================================================================

SELECT
  country,
  DATE_TRUNC(order_date, MONTH) AS month,
  SUM(total_complaint_orders) AS inaccuracy_orders,
  SUM(total_orders) AS total_orders,
  SAFE_DIVIDE(SUM(total_complaint_orders), NULLIF(SUM(total_orders), 0)) AS inaccuracy_pct
FROM `peya-delivery-and-support.automated_tables_reports.dmarts_inaccuracy`
WHERE order_date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+------------+----------------+
-- | country              | month      | inaccuracy_pct |
-- +----------------------+------------+----------------+
-- | Argentina            | 2026-09-01 |          2,57% |
-- | Bolivia              | 2026-09-01 |          2,78% |
-- | Chile                | 2026-09-01 |          2,72% |
-- | Ecuador              | 2026-09-01 |          2,26% |
-- | El Salvador          | 2026-09-01 |          1,65% |
-- | Guatemala            | 2026-09-01 |          1,26% |
-- | Honduras             | 2026-09-01 |          1,78% |
-- | Nicaragua            | 2026-09-01 |          1,84% |
-- | Panam�               | 2026-09-01 |          2,63% |
-- | Paraguay             | 2026-09-01 |          1,51% |
-- | Per�                 | 2026-09-01 |          2,06% |
-- | Rep�blica Dominicana | 2026-09-01 |          2,21% |
-- | Uruguay              | 2026-09-01 |          2,39% |
-- +----------------------+------------+----------------+
