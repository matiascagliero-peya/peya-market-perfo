DECLARE query_name STRING DEFAULT 'Glosario-43-Fill In %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 43
-- Nombre:     Fill In %
-- Chapter:   Demand Stimulation
-- Query bajada en: 13 - Fill In
-- Sheets Name: 1. ET - Fill In (13 - Fill In)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1VfL2mU3HpUZgFqCxTjtWeoqZ5lupjqpeKK8b0y96JB0
-- Tablas de origen: `peya-bi-tools-pro.il_qcommerce.fact_groceries_shopping_missions`
-- Tipo:       Ratio Calculado
-- Fórmula:    Fill In Orders / Total Orders
-- Definición: Misión Fill In: reposición media de 6 a 12 ítems.
-- ====================================================================================

SELECT
  country_name AS country,
  DATE_TRUNC(registered_date, MONTH) AS month,
  COUNT(DISTINCT CASE WHEN LOWER(mission_type) = 'fill in' THEN order_id END) AS orders_fill_in,
  COUNT(DISTINCT order_id) AS total_orders,
  SAFE_DIVIDE(
    COUNT(DISTINCT CASE WHEN LOWER(mission_type) = 'fill in' THEN order_id END),
    NULLIF(COUNT(DISTINCT order_id), 0)
  ) AS fill_in_pct
FROM `peya-bi-tools-pro.il_qcommerce.fact_groceries_shopping_missions`
WHERE registered_date BETWEEN '2026-09-01' AND '2026-09-30'
  AND is_darkstore = TRUE
  AND order_status = 'CONFIRMED'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------------+-------+----------------+--------------+
-- | country              | fill_in_pct | month | orders_fill_in | total_orders |
-- +----------------------+-------------+-------+----------------+--------------+
-- | Argentina            |      48,29% | 2.026 |      1.274.197 |    2.638.443 |
-- | Bolivia              |      37,94% | 2.026 |         54.236 |      142.935 |
-- | Chile                |      48,30% | 2.026 |        164.337 |      340.224 |
-- | Ecuador              |      33,95% | 2.026 |         32.922 |       96.964 |
-- | El Salvador          |      35,01% | 2.026 |         30.151 |       86.119 |
-- | Guatemala            |      34,38% | 2.026 |         32.770 |       95.325 |
-- | Honduras             |      23,76% | 2.026 |         12.044 |       50.683 |
-- | Nicaragua            |      30,33% | 2.026 |         17.115 |       56.437 |
-- | Panam�               |      40,95% | 2.026 |         37.738 |       92.166 |
-- | Paraguay             |      32,64% | 2.026 |         44.331 |      135.799 |
-- | Per�                 |      31,93% | 2.026 |         87.279 |      273.381 |
-- | Rep�blica Dominicana |      29,62% | 2.026 |         50.133 |      169.270 |
-- | Uruguay              |      47,85% | 2.026 |        137.004 |      286.306 |
-- +----------------------+-------------+-------+----------------+--------------+
