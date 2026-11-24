DECLARE query_name STRING DEFAULT 'Glosario-235-Item Issue Orders';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 235
-- Nombre:     Item Issue Orders
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-delivery-and-support.automated_tables_reports.dmarts_inaccuracy`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(wrong_missing_item_orders)
-- Definición: Cantidad de pedidos con reclamos por productos equivocados, cambiados o faltantes en la bolsa entregada.
-- ====================================================================================

SELECT
  country,
  DATE_TRUNC(order_date, MONTH) AS month,
  SUM(wrong_missing_item_orders) AS wrong_missing_item_orders
FROM `peya-delivery-and-support.automated_tables_reports.dmarts_inaccuracy`
WHERE order_date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------+---------------------------+
-- | country              | month | wrong_missing_item_orders |
-- +----------------------+-------+---------------------------+
-- | Argentina            | 2.026 |                    39.292 |
-- | Bolivia              | 2.026 |                     2.617 |
-- | Chile                | 2.026 |                     5.500 |
-- | Ecuador              | 2.026 |                     1.285 |
-- | El Salvador          | 2.026 |                       828 |
-- | Guatemala            | 2.026 |                       572 |
-- | Honduras             | 2.026 |                       505 |
-- | Nicaragua            | 2.026 |                       618 |
-- | Panam�               | 2.026 |                     1.553 |
-- | Paraguay             | 2.026 |                     1.311 |
-- | Per�                 | 2.026 |                     3.045 |
-- | Rep�blica Dominicana | 2.026 |                     2.456 |
-- | Uruguay              | 2.026 |                     4.352 |
-- +----------------------+-------+---------------------------+
