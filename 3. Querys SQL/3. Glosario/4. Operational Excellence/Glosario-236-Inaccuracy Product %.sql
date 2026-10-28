DECLARE query_name STRING DEFAULT 'Glosario-236-Inaccuracy Product %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 236
-- Nombre:     Inaccuracy Product %
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-delivery-and-support.automated_tables_reports.dmarts_inaccuracy`
-- Tipo:       Ratio Calculado
-- Fórmula:    (Food Issue Orders + Item Issue Orders) / Inaccuracy Orders
-- Definición: Porcentaje de artículos con incidencias de calidad respecto al total de unidades físicas despachadas.
-- ====================================================================================

SELECT
  country,
  DATE_TRUNC(order_date, MONTH) AS month,
  SUM(COALESCE(food_issue_orders, 0) + COALESCE(wrong_missing_item_orders, 0)) AS inaccuracy_product_orders,
  SUM(total_complaint_orders) AS total_inaccuracy_orders,
  SAFE_DIVIDE(
    SUM(COALESCE(food_issue_orders, 0) + COALESCE(wrong_missing_item_orders, 0)),
    NULLIF(SUM(total_complaint_orders), 0)
  ) AS inaccuracy_product_pct
FROM `peya-delivery-and-support.automated_tables_reports.dmarts_inaccuracy`
WHERE order_date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+---------------------------+------------------------+-------+-------------------------+
-- | country              | inaccuracy_product_orders | inaccuracy_product_pct | month | total_inaccuracy_orders |
-- +----------------------+---------------------------+------------------------+-------+-------------------------+
-- | Argentina            |                    65.489 |                 95,94% | 2.026 |                  68.262 |
-- | Bolivia              |                     3.858 |                 97,15% | 2.026 |                   3.971 |
-- | Chile                |                     8.816 |                 94,53% | 2.026 |                   9.326 |
-- | Ecuador              |                     2.135 |                 96,83% | 2.026 |                   2.205 |
-- | El Salvador          |                     1.372 |                 96,42% | 2.026 |                   1.423 |
-- | Guatemala            |                     1.145 |                 94,94% | 2.026 |                   1.206 |
-- | Honduras             |                       844 |                 93,36% | 2.026 |                     904 |
-- | Nicaragua            |                       994 |                 95,85% | 2.026 |                   1.037 |
-- | Panam�               |                     2.375 |                 97,10% | 2.026 |                   2.446 |
-- | Paraguay             |                     1.973 |                 96,24% | 2.026 |                   2.050 |
-- | Per�                 |                     5.430 |                 96,43% | 2.026 |                   5.631 |
-- | Rep�blica Dominicana |                     3.544 |                 93,68% | 2.026 |                   3.783 |
-- | Uruguay              |                     6.352 |                 92,68% | 2.026 |                   6.854 |
-- +----------------------+---------------------------+------------------------+-------+-------------------------+
