DECLARE query_name STRING DEFAULT 'Glosario-234-Food Issue Orders';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 234
-- Nombre:     Food Issue Orders
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-delivery-and-support.automated_tables_reports.dmarts_inaccuracy`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(food_issue_orders)
-- Definición: Cantidad de pedidos con reclamos específicos por productos frescos vencidos, en mal estado o con problemas de refrigeración.
-- ====================================================================================

SELECT
  country,
  DATE_TRUNC(order_date, MONTH) AS month,
  SUM(food_issue_orders) AS food_issue_orders
FROM `peya-delivery-and-support.automated_tables_reports.dmarts_inaccuracy`
WHERE order_date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------------------+-------+
-- | country              | food_issue_orders | month |
-- +----------------------+-------------------+-------+
-- | Argentina            |            26.197 | 2.026 |
-- | Bolivia              |             1.241 | 2.026 |
-- | Chile                |             3.316 | 2.026 |
-- | Ecuador              |               850 | 2.026 |
-- | El Salvador          |               544 | 2.026 |
-- | Guatemala            |               573 | 2.026 |
-- | Honduras             |               339 | 2.026 |
-- | Nicaragua            |               376 | 2.026 |
-- | Panam�               |               822 | 2.026 |
-- | Paraguay             |               662 | 2.026 |
-- | Per�                 |             2.385 | 2.026 |
-- | Rep�blica Dominicana |             1.088 | 2.026 |
-- | Uruguay              |             2.000 | 2.026 |
-- +----------------------+-------------------+-------+
