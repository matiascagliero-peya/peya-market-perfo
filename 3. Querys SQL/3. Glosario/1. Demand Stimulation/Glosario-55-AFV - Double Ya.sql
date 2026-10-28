DECLARE query_name STRING DEFAULT 'Glosario-55-AFV - Double Ya';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 55
-- Nombre:     AFV - Double Ya
-- Chapter:   Demand Stimulation
-- Query bajada en: 21 - Double Ya Data
-- Sheets Name: 1. ET - DY Data (21 - Double Ya Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/18cUpQbzQXxAMcDix675p1zscuc_SmvXS_bYaVtEkUUU
-- Tablas de origen: `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya` (RAW) + `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
-- Tipo:       Ratio Calculado
-- Fórmula:    Net Sales (Double Ya) / Confirmed Orders - Double Ya
-- Definición: Ticket promedio neto en compras vía Double Ya.
-- ====================================================================================

WITH dy_orders AS (
  SELECT DISTINCT CAST(order_details.id.secondary AS STRING) AS order_id
  FROM `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya`
  WHERE order_type = 'DOUBLE_YA'
)
SELECT
  d.country_name AS country,
  DATE_TRUNC(d.order_date, MONTH) AS month,
  SUM(d.total_amount_net_with_discount_eur) AS net_sales_double_ya_eur,
  COUNT(DISTINCT d.order_id) AS confirmed_orders_double_ya,
  SAFE_DIVIDE(
    SUM(d.total_amount_net_with_discount_eur),
    NULLIF(COUNT(DISTINCT d.order_id), 0)
  ) AS afv_double_ya_eur
FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` d
INNER JOIN dy_orders dy ON CAST(d.order_id AS STRING) = dy.order_id
WHERE UPPER(d.state) = 'CONFIRMED'
  AND d.order_date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +-------------------+----------------------------+----------------------+-------+-------------------------+
-- | afv_double_ya_eur | confirmed_orders_double_ya | country              | month | net_sales_double_ya_eur |
-- +-------------------+----------------------------+----------------------+-------+-------------------------+
-- |            3,14 € |                     92.572 | Argentina            | 2.026 |            290.896,13 € |
-- |            2,77 € |                      6.537 | Chile                | 2.026 |             18.102,77 € |
-- |            1,93 € |                      8.074 | Ecuador              | 2.026 |             15.587,77 € |
-- |            2,52 € |                      7.033 | El Salvador          | 2.026 |             17.709,87 € |
-- |            2,85 € |                      6.602 | Guatemala            | 2.026 |             18.816,79 € |
-- |            2,11 € |                     10.285 | Honduras             | 2.026 |             21.725,72 € |
-- |            1,86 € |                      4.557 | Nicaragua            | 2.026 |              8.465,18 € |
-- |            2,19 € |                     12.422 | Paraguay             | 2.026 |             27.189,16 € |
-- |            2,06 € |                     11.408 | Rep�blica Dominicana | 2.026 |             23.458,62 € |
-- |            4,34 € |                      7.945 | Uruguay              | 2.026 |             34.489,77 € |
-- +-------------------+----------------------------+----------------------+-------+-------------------------+
