DECLARE query_name STRING DEFAULT 'Glosario-233-Inaccuracy Orders';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 233
-- Nombre:     Inaccuracy Orders
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-delivery-and-support.automated_tables_reports.dmarts_inaccuracy`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(total_complaint_orders)
-- Definición: Cantidad total de pedidos que generaron reclamos directos de clientes por problemas de calidad o exactitud en el envío.
-- ====================================================================================

SELECT
  country,
  DATE_TRUNC(order_date, MONTH) AS month,
  SUM(total_complaint_orders) AS inaccuracy_orders
FROM `peya-delivery-and-support.automated_tables_reports.dmarts_inaccuracy`
WHERE order_date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+------------+-------------------+
-- | country              | month      | inaccuracy_orders |
-- +----------------------+------------+-------------------+
-- | Argentina            | 2026-09-01 |            68.262 |
-- | Bolivia              | 2026-09-01 |             3.971 |
-- | Chile                | 2026-09-01 |             9.326 |
-- | Ecuador              | 2026-09-01 |             2.205 |
-- | El Salvador          | 2026-09-01 |             1.423 |
-- | Guatemala            | 2026-09-01 |             1.206 |
-- | Honduras             | 2026-09-01 |               904 |
-- | Nicaragua            | 2026-09-01 |             1.037 |
-- | Panam�               | 2026-09-01 |             2.446 |
-- | Paraguay             | 2026-09-01 |             2.050 |
-- | Per�                 | 2026-09-01 |             5.631 |
-- | Rep�blica Dominicana | 2026-09-01 |             3.783 |
-- | Uruguay              | 2026-09-01 |             6.854 |
-- +----------------------+------------+-------------------+
