DECLARE query_name STRING DEFAULT 'Glosario-18-Confirmed Orders - Double Ya';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 18
-- Nombre:     Confirmed Orders - Double Ya
-- Chapter:   Demand Stimulation
-- Query bajada en: 21 - Double Ya Data
-- Sheets Name: 1. ET - DY Data (21 - Double Ya Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/18cUpQbzQXxAMcDix675p1zscuc_SmvXS_bYaVtEkUUU
-- Tablas de origen: `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya` (RAW) + `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
-- Tipo:       Dato Directo
-- Fórmula:    COUNT(DISTINCT order_id) canal Double Ya
-- Definición: Órdenes originadas mediante el flujo de compra cruzada Double Ya.
-- ====================================================================================

WITH dy_orders AS (
  SELECT DISTINCT CAST(order_details.id.secondary AS STRING) AS order_id
  FROM `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya`
  WHERE order_type = 'DOUBLE_YA'
)
SELECT
  d.country_name AS country,
  DATE_TRUNC(d.order_date, MONTH) AS month,
  COUNT(DISTINCT d.order_id) AS confirmed_orders_double_ya
FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` d
INNER JOIN dy_orders dy ON CAST(d.order_id AS STRING) = dy.order_id
WHERE UPPER(d.state) = 'CONFIRMED'
  AND d.order_date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------------+----------------------+-------+
-- | confirmed_orders_double_ya | country              | month |
-- +----------------------------+----------------------+-------+
-- |                     92.572 | Argentina            | 2.026 |
-- |                      6.537 | Chile                | 2.026 |
-- |                      8.074 | Ecuador              | 2.026 |
-- |                      7.033 | El Salvador          | 2.026 |
-- |                      6.602 | Guatemala            | 2.026 |
-- |                     10.285 | Honduras             | 2.026 |
-- |                      4.557 | Nicaragua            | 2.026 |
-- |                     12.422 | Paraguay             | 2.026 |
-- |                     11.408 | Rep�blica Dominicana | 2.026 |
-- |                      7.945 | Uruguay              | 2.026 |
-- +----------------------------+----------------------+-------+
