DECLARE query_name STRING DEFAULT 'Glosario-20-Confirmed Orders - non Double Ya';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 20
-- Nombre:     Confirmed Orders - non Double Ya
-- Chapter:   Demand Stimulation
-- Query bajada en: 21 - Double Ya Data
-- Sheets Name: 1. ET - DY Data (21 - Double Ya Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/18cUpQbzQXxAMcDix675p1zscuc_SmvXS_bYaVtEkUUU
-- Tablas de origen: `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya` (RAW) + `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
-- Tipo:       Dato Directo
-- Fórmula:    COUNT(DISTINCT order_id) canal directo
-- Definición: Órdenes orgánicas directas realizadas en PeYa Market.
-- ====================================================================================

WITH dy_orders AS (
  SELECT DISTINCT CAST(order_details.id.secondary AS STRING) AS order_id
  FROM `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya`
  WHERE order_type = 'DOUBLE_YA'
)
SELECT
  d.country_name AS country,
  DATE_TRUNC(d.order_date, MONTH) AS month,
  COUNT(DISTINCT d.order_id) AS confirmed_orders_non_double_ya
FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` d
LEFT JOIN dy_orders dy ON CAST(d.order_id AS STRING) = dy.order_id
WHERE dy.order_id IS NULL
  AND UPPER(d.state) = 'CONFIRMED'
  AND d.order_date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +--------------------------------+----------------------+-------+
-- | confirmed_orders_non_double_ya | country              | month |
-- +--------------------------------+----------------------+-------+
-- |                      2.560.106 | Argentina            | 2.026 |
-- |                        142.934 | Bolivia              | 2.026 |
-- |                        335.733 | Chile                | 2.026 |
-- |                         89.341 | Ecuador              | 2.026 |
-- |                         79.252 | El Salvador          | 2.026 |
-- |                         89.103 | Guatemala            | 2.026 |
-- |                         40.433 | Honduras             | 2.026 |
-- |                         51.880 | Nicaragua            | 2.026 |
-- |                         92.999 | Panam�               | 2.026 |
-- |                        123.377 | Paraguay             | 2.026 |
-- |                        273.380 | Per�                 | 2.026 |
-- |                        159.940 | Rep�blica Dominicana | 2.026 |
-- |                        279.150 | Uruguay              | 2.026 |
-- +--------------------------------+----------------------+-------+
