DECLARE query_name STRING DEFAULT 'Glosario-62-Frequency - Double Ya';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 62
-- Nombre:     Frequency - Double Ya
-- Chapter:   Demand Stimulation
-- Query bajada en: 21 - Double Ya Data
-- Sheets Name: 1. ET - DY Data (21 - Double Ya Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/18cUpQbzQXxAMcDix675p1zscuc_SmvXS_bYaVtEkUUU
-- Tablas de origen: `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya` (RAW) + `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
-- Tipo:       Ratio Calculado
-- Fórmula:    Orders DY / (MAUs DY + MAUs Hybrid)
-- Definición: Frecuencia de pedidos en el canal Double Ya.
-- ====================================================================================

WITH dy_orders AS (
  SELECT DISTINCT CAST(order_details.id.secondary AS STRING) AS order_id
  FROM `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya`
  WHERE order_type = 'DOUBLE_YA'
)
SELECT
  d.country_name AS country,
  DATE_TRUNC(d.order_date, MONTH) AS month,
  COUNT(DISTINCT d.order_id) AS orders_double_ya,
  COUNT(DISTINCT d.customer_id) AS customers_double_ya,
  SAFE_DIVIDE(
    COUNT(DISTINCT d.order_id),
    NULLIF(COUNT(DISTINCT d.customer_id), 0)
  ) AS frequency_double_ya
FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` d
INNER JOIN dy_orders dy ON CAST(d.order_id AS STRING) = dy.order_id
WHERE UPPER(d.state) = 'CONFIRMED'
  AND d.order_date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+---------------------+---------------------+-------+------------------+
-- | country              | customers_double_ya | frequency_double_ya | month | orders_double_ya |
-- +----------------------+---------------------+---------------------+-------+------------------+
-- | Argentina            |              80.627 |                1,15 | 2.026 |           92.572 |
-- | Chile                |               6.012 |                1,09 | 2.026 |            6.537 |
-- | Ecuador              |               6.954 |                1,16 | 2.026 |            8.074 |
-- | El Salvador          |               5.742 |                1,22 | 2.026 |            7.033 |
-- | Guatemala            |               5.583 |                1,18 | 2.026 |            6.602 |
-- | Honduras             |               7.982 |                1,29 | 2.026 |           10.285 |
-- | Nicaragua            |               3.763 |                1,21 | 2.026 |            4.557 |
-- | Paraguay             |               9.641 |                1,29 | 2.026 |           12.422 |
-- | Rep�blica Dominicana |               9.398 |                1,21 | 2.026 |           11.408 |
-- | Uruguay              |               6.786 |                1,17 | 2.026 |            7.945 |
-- +----------------------+---------------------+---------------------+-------+------------------+
