DECLARE query_name STRING DEFAULT 'Glosario-45-Stock Up %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 45
-- Nombre:     Stock Up %
-- Chapter:   Demand Stimulation
-- Query bajada en: 13 - Fill In
-- Sheets Name: 1. ET - Fill In (13 - Fill In)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1VfL2mU3HpUZgFqCxTjtWeoqZ5lupjqpeKK8b0y96JB0
-- Tablas de origen: `peya-bi-tools-pro.il_qcommerce.fact_groceries_shopping_missions`
-- Tipo:       Ratio Calculado
-- Fórmula:    Stock Up Orders / Total Orders
-- Definición: Misión Stock Up: abastecimiento mayor a 12 ítems.
-- ====================================================================================

SELECT
  country_name AS country,
  DATE_TRUNC(registered_date, MONTH) AS month,
  COUNT(DISTINCT CASE WHEN LOWER(mission_type) = 'stock up' THEN order_id END) AS orders_stock_up,
  COUNT(DISTINCT order_id) AS total_orders,
  SAFE_DIVIDE(
    COUNT(DISTINCT CASE WHEN LOWER(mission_type) = 'stock up' THEN order_id END),
    NULLIF(COUNT(DISTINCT order_id), 0)
  ) AS stock_up_pct
FROM `peya-bi-tools-pro.il_qcommerce.fact_groceries_shopping_missions`
WHERE registered_date BETWEEN '2026-09-01' AND '2026-09-30'
  AND is_darkstore = TRUE
  AND order_status = 'CONFIRMED'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------+-----------------+--------------+--------------+
-- | country              | month | orders_stock_up | stock_up_pct | total_orders |
-- +----------------------+-------+-----------------+--------------+--------------+
-- | Argentina            | 2.026 |         264.716 |       10,03% |    2.638.443 |
-- | Bolivia              | 2.026 |           8.928 |        6,25% |      142.935 |
-- | Chile                | 2.026 |          30.237 |        8,89% |      340.224 |
-- | Ecuador              | 2.026 |           5.654 |        5,83% |       96.964 |
-- | El Salvador          | 2.026 |           4.196 |        4,87% |       86.119 |
-- | Guatemala            | 2.026 |           4.633 |        4,86% |       95.325 |
-- | Honduras             | 2.026 |           1.167 |        2,30% |       50.683 |
-- | Nicaragua            | 2.026 |           3.080 |        5,46% |       56.437 |
-- | Panam�               | 2.026 |           6.630 |        7,19% |       92.166 |
-- | Paraguay             | 2.026 |           6.574 |        4,84% |      135.799 |
-- | Per�                 | 2.026 |           8.030 |        2,94% |      273.381 |
-- | Rep�blica Dominicana | 2.026 |           7.705 |        4,55% |      169.270 |
-- | Uruguay              | 2.026 |          25.450 |        8,89% |      286.306 |
-- +----------------------+-------+-----------------+--------------+--------------+
