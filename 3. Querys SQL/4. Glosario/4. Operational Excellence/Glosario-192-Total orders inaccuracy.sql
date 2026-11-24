DECLARE query_name STRING DEFAULT 'Glosario-192-Total orders inaccuracy';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 192
-- Nombre:     Total orders inaccuracy
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-delivery-and-support.automated_tables_reports.dmarts_inaccuracy`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(total_orders) en dmarts_inaccuracy
-- Definición: Total de órdenes evaluadas en la fuente de reclamos e incidencias de tienda (dmarts_inaccuracy). Utilizado como denominador para el ratio de Inaccuracy %.
-- ====================================================================================

SELECT
  country,
  DATE_TRUNC(order_date, MONTH) AS month,
  SUM(total_orders) AS total_orders_inaccuracy
FROM `peya-delivery-and-support.automated_tables_reports.dmarts_inaccuracy`
WHERE order_date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+------------+-------------------------+
-- | country              | month      | total_orders_inaccuracy |
-- +----------------------+------------+-------------------------+
-- | Argentina            | 2026-09-01 |               2.652.523 |
-- | Bolivia              | 2026-09-01 |                 142.931 |
-- | Chile                | 2026-09-01 |                 342.264 |
-- | Ecuador              | 2026-09-01 |                  97.408 |
-- | El Salvador          | 2026-09-01 |                  86.286 |
-- | Guatemala            | 2026-09-01 |                  95.703 |
-- | Honduras             | 2026-09-01 |                  50.717 |
-- | Nicaragua            | 2026-09-01 |                  56.433 |
-- | Panam�               | 2026-09-01 |                  92.940 |
-- | Paraguay             | 2026-09-01 |                 135.798 |
-- | Per�                 | 2026-09-01 |                 273.369 |
-- | Rep�blica Dominicana | 2026-09-01 |                 171.345 |
-- | Uruguay              | 2026-09-01 |                 287.067 |
-- +----------------------+------------+-------------------------+
