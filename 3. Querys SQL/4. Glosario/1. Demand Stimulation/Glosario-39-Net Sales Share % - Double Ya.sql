DECLARE query_name STRING DEFAULT 'Glosario-39-Net Sales Share % - Double Ya';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 39
-- Nombre:     Net Sales Share % - Double Ya
-- Chapter:   Demand Stimulation
-- Query bajada en: 21 - Double Ya Data
-- Sheets Name: 1. ET - DY Data (21 - Double Ya Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/18cUpQbzQXxAMcDix675p1zscuc_SmvXS_bYaVtEkUUU
-- Tablas de origen: `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya` (RAW) + `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
-- Tipo:       Ratio Calculado
-- Fórmula:    Net Sales - Double Ya / Total Net Sales
-- Definición: Participación porcentual de ventas netas vía Double Ya.
-- ====================================================================================

WITH dy_orders AS (
  SELECT DISTINCT CAST(order_details.id.secondary AS STRING) AS order_id
  FROM `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya`
  WHERE order_type = 'DOUBLE_YA'
)
SELECT
  d.country_name AS country,
  DATE_TRUNC(d.order_date, MONTH) AS month,
  SUM(CASE WHEN dy.order_id IS NOT NULL THEN d.total_amount_net_with_discount_eur ELSE 0 END) AS net_sales_double_ya_eur,
  SUM(d.total_amount_net_with_discount_eur) AS total_net_sales_eur,
  SAFE_DIVIDE(
    SUM(CASE WHEN dy.order_id IS NOT NULL THEN d.total_amount_net_with_discount_eur ELSE 0 END),
    NULLIF(SUM(d.total_amount_net_with_discount_eur), 0)
  ) AS net_sales_share_double_ya_pct
FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` d
LEFT JOIN dy_orders dy ON CAST(d.order_id AS STRING) = dy.order_id
WHERE UPPER(d.state) = 'CONFIRMED'
  AND d.order_date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------+-------------------------+-------------------------------+---------------------+
-- | country              | month | net_sales_double_ya_eur | net_sales_share_double_ya_pct | total_net_sales_eur |
-- +----------------------+-------+-------------------------+-------------------------------+---------------------+
-- | Argentina            | 2.026 |            290.896,13 € |                         0,76% |     38.180.783,43 € |
-- | Bolivia              | 2.026 |                  0,00 € |                         0,00% |        912.047,81 € |
-- | Chile                | 2.026 |             18.102,77 € |                         0,40% |      4.502.418,25 € |
-- | Ecuador              | 2.026 |             15.587,77 € |                         1,47% |      1.058.639,43 € |
-- | El Salvador          | 2.026 |             17.709,87 € |                         1,77% |      1.001.595,76 € |
-- | Guatemala            | 2.026 |             18.816,79 € |                         1,47% |      1.275.808,28 € |
-- | Honduras             | 2.026 |             21.725,72 € |                         5,52% |        393.674,13 € |
-- | Nicaragua            | 2.026 |              8.465,18 € |                         1,55% |        547.571,18 € |
-- | Panam�               | 2.026 |                  0,00 € |                         0,00% |      1.516.665,54 € |
-- | Paraguay             | 2.026 |             27.189,16 € |                         2,04% |      1.331.331,97 € |
-- | Per�                 | 2.026 |                  0,00 € |                         0,00% |      3.021.814,65 € |
-- | Rep�blica Dominicana | 2.026 |             23.458,62 € |                         1,43% |      1.645.347,89 € |
-- | Uruguay              | 2.026 |             34.489,77 € |                         0,58% |      5.996.485,93 € |
-- +----------------------+-------+-------------------------+-------------------------------+---------------------+
