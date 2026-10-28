DECLARE query_name STRING DEFAULT 'Glosario-56-AFV - non Double Ya';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 56
-- Nombre:     AFV - non Double Ya
-- Chapter:   Demand Stimulation
-- Query bajada en: 21 - Double Ya Data
-- Sheets Name: 1. ET - DY Data (21 - Double Ya Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/18cUpQbzQXxAMcDix675p1zscuc_SmvXS_bYaVtEkUUU
-- Tablas de origen: `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya` (RAW) + `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
-- Tipo:       Ratio Calculado
-- Fórmula:    Net Sales (non Double Ya) / Confirmed Orders - non Double Ya
-- Definición: Ticket promedio neto en compras directas de catálogo.
-- ====================================================================================

WITH dy_orders AS (
  SELECT DISTINCT CAST(order_details.id.secondary AS STRING) AS order_id
  FROM `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya`
  WHERE order_type = 'DOUBLE_YA'
)
SELECT
  d.country_name AS country,
  DATE_TRUNC(d.order_date, MONTH) AS month,
  SUM(d.total_amount_net_with_discount_eur) AS net_sales_non_double_ya_eur,
  COUNT(DISTINCT d.order_id) AS confirmed_orders_non_double_ya,
  SAFE_DIVIDE(
    SUM(d.total_amount_net_with_discount_eur),
    NULLIF(COUNT(DISTINCT d.order_id), 0)
  ) AS afv_non_double_ya_eur
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
-- +-----------------------+--------------------------------+----------------------+-------+-----------------------------+
-- | afv_non_double_ya_eur | confirmed_orders_non_double_ya | country              | month | net_sales_non_double_ya_eur |
-- +-----------------------+--------------------------------+----------------------+-------+-----------------------------+
-- |               14,80 € |                      2.560.106 | Argentina            | 2.026 |             37.889.887,30 € |
-- |                6,38 € |                        142.934 | Bolivia              | 2.026 |                912.047,81 € |
-- |               13,36 € |                        335.733 | Chile                | 2.026 |              4.484.315,48 € |
-- |               11,67 € |                         89.341 | Ecuador              | 2.026 |              1.043.051,66 € |
-- |               12,41 € |                         79.252 | El Salvador          | 2.026 |                983.885,89 € |
-- |               14,11 € |                         89.103 | Guatemala            | 2.026 |              1.256.991,49 € |
-- |                9,20 € |                         40.433 | Honduras             | 2.026 |                371.948,41 € |
-- |               10,39 € |                         51.880 | Nicaragua            | 2.026 |                539.106,00 € |
-- |               16,31 € |                         92.999 | Panam�               | 2.026 |              1.516.665,54 € |
-- |               10,57 € |                        123.377 | Paraguay             | 2.026 |              1.304.142,81 € |
-- |               11,05 € |                        273.380 | Per�                 | 2.026 |              3.021.814,65 € |
-- |               10,14 € |                        159.940 | Rep�blica Dominicana | 2.026 |              1.621.889,27 € |
-- |               21,36 € |                        279.150 | Uruguay              | 2.026 |              5.961.996,16 € |
-- +-----------------------+--------------------------------+----------------------+-------+-----------------------------+
