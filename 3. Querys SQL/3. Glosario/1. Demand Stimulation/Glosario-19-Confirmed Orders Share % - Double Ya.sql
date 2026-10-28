DECLARE query_name STRING DEFAULT 'Glosario-19-Confirmed Orders Share % - Double Ya';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 19
-- Nombre:     Confirmed Orders Share % - Double Ya
-- Chapter:   Demand Stimulation
-- Query bajada en: 21 - Double Ya Data
-- Sheets Name: 1. ET - DY Data (21 - Double Ya Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/18cUpQbzQXxAMcDix675p1zscuc_SmvXS_bYaVtEkUUU
-- Tablas de origen: `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya` (RAW) + `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
-- Tipo:       Ratio Calculado
-- Fórmula:    Confirmed Orders - Double Ya / Total Orders
-- Definición: Participación de pedidos Double Ya sobre el total de Market.
-- ====================================================================================

WITH dy_orders AS (
  SELECT DISTINCT CAST(order_details.id.secondary AS STRING) AS order_id
  FROM `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya`
  WHERE order_type = 'DOUBLE_YA'
)
SELECT
  d.country_name AS country,
  DATE_TRUNC(d.order_date, MONTH) AS month,
  COUNT(DISTINCT dy.order_id) AS double_ya_orders,
  COUNT(DISTINCT d.order_id) AS total_orders,
  SAFE_DIVIDE(
    COUNT(DISTINCT dy.order_id),
    NULLIF(COUNT(DISTINCT d.order_id), 0)
  ) AS double_ya_orders_share_pct
FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` d
LEFT JOIN dy_orders dy ON CAST(d.order_id AS STRING) = dy.order_id
WHERE UPPER(d.state) = 'CONFIRMED'
  AND d.order_date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+------------------+----------------------------+-------+--------------+
-- | country              | double_ya_orders | double_ya_orders_share_pct | month | total_orders |
-- +----------------------+------------------+----------------------------+-------+--------------+
-- | Argentina            |           92.572 |                      3,49% | 2.026 |    2.652.678 |
-- | Bolivia              |                0 |                      0,00% | 2.026 |      142.934 |
-- | Chile                |            6.537 |                      1,91% | 2.026 |      342.270 |
-- | Ecuador              |            8.074 |                      8,29% | 2.026 |       97.415 |
-- | El Salvador          |            7.033 |                      8,15% | 2.026 |       86.285 |
-- | Guatemala            |            6.602 |                      6,90% | 2.026 |       95.705 |
-- | Honduras             |           10.285 |                     20,28% | 2.026 |       50.718 |
-- | Nicaragua            |            4.557 |                      8,07% | 2.026 |       56.437 |
-- | Panam�               |                0 |                      0,00% | 2.026 |       92.999 |
-- | Paraguay             |           12.422 |                      9,15% | 2.026 |      135.799 |
-- | Per�                 |                0 |                      0,00% | 2.026 |      273.380 |
-- | Rep�blica Dominicana |           11.408 |                      6,66% | 2.026 |      171.348 |
-- | Uruguay              |            7.945 |                      2,77% | 2.026 |      287.095 |
-- +----------------------+------------------+----------------------------+-------+--------------+
