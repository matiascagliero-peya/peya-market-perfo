DECLARE query_name STRING DEFAULT 'Glosario-40-Net Sales - non Double Ya';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 40
-- Nombre:     Net Sales - non Double Ya
-- Chapter:   Demand Stimulation
-- Query bajada en: 21 - Double Ya Data
-- Sheets Name: 1. ET - DY Data (21 - Double Ya Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/18cUpQbzQXxAMcDix675p1zscuc_SmvXS_bYaVtEkUUU
-- Tablas de origen: `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya` (RAW) + `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(net_sales_eur) canal directo
-- Definición: Venta neta generada por compras tradicionales directas.
-- ====================================================================================

WITH dy_orders AS (
  SELECT DISTINCT CAST(order_details.id.secondary AS STRING) AS order_id
  FROM `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya`
  WHERE order_type = 'DOUBLE_YA'
)
SELECT
  d.country_name AS country,
  DATE_TRUNC(d.order_date, MONTH) AS month,
  SUM(d.total_amount_net_with_discount_eur) AS net_sales_non_double_ya_eur
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
-- +----------------------+-------+-----------------------------+
-- | country              | month | net_sales_non_double_ya_eur |
-- +----------------------+-------+-----------------------------+
-- | Argentina            | 2.026 |             37.889.887,30 € |
-- | Bolivia              | 2.026 |                912.047,81 € |
-- | Chile                | 2.026 |              4.484.315,48 € |
-- | Ecuador              | 2.026 |              1.043.051,66 € |
-- | El Salvador          | 2.026 |                983.885,89 € |
-- | Guatemala            | 2.026 |              1.256.991,49 € |
-- | Honduras             | 2.026 |                371.948,41 € |
-- | Nicaragua            | 2.026 |                539.106,00 € |
-- | Panam�               | 2.026 |              1.516.665,54 € |
-- | Paraguay             | 2.026 |              1.304.142,81 € |
-- | Per�                 | 2.026 |              3.021.814,65 € |
-- | Rep�blica Dominicana | 2.026 |              1.621.889,27 € |
-- | Uruguay              | 2.026 |              5.961.996,16 € |
-- +----------------------+-------+-----------------------------+
