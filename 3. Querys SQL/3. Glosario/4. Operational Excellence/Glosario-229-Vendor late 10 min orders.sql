DECLARE query_name STRING DEFAULT 'Glosario-229-Vendor late 10 min orders';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 229
-- Nombre:     Vendor late 10 min orders
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-bi-tools-pro.il_logistics.fact_logistic_orders`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(is_vendor_late_10)
-- Definición: Cantidad de órdenes entregadas con más de 10 minutos de atraso por parte de la tienda hacia el rider.
-- ====================================================================================

SELECT
  country_code AS country,
  DATE_TRUNC(DATE(created_date_local), MONTH) AS month,
  SUM(is_vendor_late_10) AS vendor_late_10_count
FROM `peya-bi-tools-pro.il_logistics.fact_logistic_orders`
WHERE DATE(created_date_local) BETWEEN '2026-09-01' AND '2026-09-30'
  AND order_cancelled != 1
  AND vendor.vertical_type = 'darkstores'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +---------+-------+----------------------+
-- | country | month | vendor_late_10_count |
-- +---------+-------+----------------------+
-- | ar      | 2.026 |              321.581 |
-- | bo      | 2.026 |               24.427 |
-- | cl      | 2.026 |               67.826 |
-- | do      | 2.026 |               18.599 |
-- | ec      | 2.026 |               11.754 |
-- | gt      | 2.026 |               10.445 |
-- | hn      | 2.026 |                5.209 |
-- | ni      | 2.026 |                8.101 |
-- | pa      | 2.026 |               12.997 |
-- | pe      | 2.026 |               24.437 |
-- | py      | 2.026 |               20.374 |
-- | sv      | 2.026 |               10.517 |
-- | uy      | 2.026 |               34.712 |
-- +---------+-------+----------------------+
