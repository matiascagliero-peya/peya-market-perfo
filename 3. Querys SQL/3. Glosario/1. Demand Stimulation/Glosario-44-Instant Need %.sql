DECLARE query_name STRING DEFAULT 'Glosario-44-Instant Need %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 44
-- Nombre:     Instant Need %
-- Chapter:   Demand Stimulation
-- Query bajada en: 13 - Fill In
-- Sheets Name: 1. ET - Fill In (13 - Fill In)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1VfL2mU3HpUZgFqCxTjtWeoqZ5lupjqpeKK8b0y96JB0
-- Tablas de origen: `peya-bi-tools-pro.il_qcommerce.fact_groceries_shopping_missions`
-- Tipo:       Ratio Calculado
-- Fórmula:    Instant Need Orders / Total Orders
-- Definición: Misión Instant Need: conveniencia inmediata de 1 a 5 ítems.
-- ====================================================================================

SELECT
  country_name AS country,
  DATE_TRUNC(registered_date, MONTH) AS month,
  COUNT(DISTINCT CASE WHEN LOWER(mission_type) = 'instant need' THEN order_id END) AS orders_instant_need,
  COUNT(DISTINCT order_id) AS total_orders,
  SAFE_DIVIDE(
    COUNT(DISTINCT CASE WHEN LOWER(mission_type) = 'instant need' THEN order_id END),
    NULLIF(COUNT(DISTINCT order_id), 0)
  ) AS instant_need_pct
FROM `peya-bi-tools-pro.il_qcommerce.fact_groceries_shopping_missions`
WHERE registered_date BETWEEN '2026-09-01' AND '2026-09-30'
  AND is_darkstore = TRUE
  AND order_status = 'CONFIRMED'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+------------------+-------+---------------------+--------------+
-- | country              | instant_need_pct | month | orders_instant_need | total_orders |
-- +----------------------+------------------+-------+---------------------+--------------+
-- | Argentina            |           41,67% | 2.026 |           1.099.530 |    2.638.443 |
-- | Bolivia              |           55,81% | 2.026 |              79.771 |      142.935 |
-- | Chile                |           42,81% | 2.026 |             145.650 |      340.224 |
-- | Ecuador              |           60,22% | 2.026 |              58.388 |       96.964 |
-- | El Salvador          |           60,12% | 2.026 |              51.772 |       86.119 |
-- | Guatemala            |           60,76% | 2.026 |              57.922 |       95.325 |
-- | Honduras             |           73,93% | 2.026 |              37.472 |       50.683 |
-- | Nicaragua            |           64,22% | 2.026 |              36.242 |       56.437 |
-- | Panam�               |           51,86% | 2.026 |              47.798 |       92.166 |
-- | Paraguay             |           62,51% | 2.026 |              84.894 |      135.799 |
-- | Per�                 |           65,14% | 2.026 |             178.072 |      273.381 |
-- | Rep�blica Dominicana |           65,83% | 2.026 |             111.432 |      169.270 |
-- | Uruguay              |           43,26% | 2.026 |             123.852 |      286.306 |
-- +----------------------+------------------+-------+---------------------+--------------+
