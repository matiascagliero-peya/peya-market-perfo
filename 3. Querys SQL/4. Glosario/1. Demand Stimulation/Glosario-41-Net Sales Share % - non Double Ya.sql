DECLARE query_name STRING DEFAULT 'Glosario-41-Net Sales Share % - non Double Ya';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 41
-- Nombre:     Net Sales Share % - non Double Ya
-- Chapter:   Demand Stimulation
-- Query bajada en: 21 - Double Ya Data
-- Sheets Name: 1. ET - DY Data (21 - Double Ya Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/18cUpQbzQXxAMcDix675p1zscuc_SmvXS_bYaVtEkUUU
-- Tablas de origen: `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya` (RAW) + `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
-- Tipo:       Ratio Calculado
-- Fórmula:    Net Sales - non Double Ya / Total Net Sales
-- Definición: Participación porcentual de ventas netas por canal directo.
-- ====================================================================================

WITH dy_orders AS (
  SELECT DISTINCT CAST(order_details.id.secondary AS STRING) AS order_id
  FROM `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya`
  WHERE order_type = 'DOUBLE_YA'
)
SELECT
  d.country_name AS country,
  DATE_TRUNC(d.order_date, MONTH) AS month,
  SUM(CASE WHEN dy.order_id IS NULL THEN d.total_amount_net_with_discount_eur ELSE 0 END) AS net_sales_non_double_ya_eur,
  SUM(d.total_amount_net_with_discount_eur) AS total_net_sales_eur,
  SAFE_DIVIDE(
    SUM(CASE WHEN dy.order_id IS NULL THEN d.total_amount_net_with_discount_eur ELSE 0 END),
    NULLIF(SUM(d.total_amount_net_with_discount_eur), 0)
  ) AS net_sales_share_non_double_ya_pct
FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` d
LEFT JOIN dy_orders dy ON CAST(d.order_id AS STRING) = dy.order_id
WHERE UPPER(d.state) = 'CONFIRMED'
  AND d.order_date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------+-----------------------------+-----------------------------------+---------------------+
-- | country              | month | net_sales_non_double_ya_eur | net_sales_share_non_double_ya_pct | total_net_sales_eur |
-- +----------------------+-------+-----------------------------+-----------------------------------+---------------------+
-- | Argentina            | 2.026 |             37.889.887,30 € |                            99,24% |     38.180.783,43 € |
-- | Bolivia              | 2.026 |                912.047,81 € |                           100,00% |        912.047,81 € |
-- | Chile                | 2.026 |              4.484.315,48 € |                            99,60% |      4.502.418,25 € |
-- | Ecuador              | 2.026 |              1.043.051,66 € |                            98,53% |      1.058.639,43 € |
-- | El Salvador          | 2.026 |                983.885,89 € |                            98,23% |      1.001.595,76 € |
-- | Guatemala            | 2.026 |              1.256.991,49 € |                            98,53% |      1.275.808,28 € |
-- | Honduras             | 2.026 |                371.948,41 € |                            94,48% |        393.674,13 € |
-- | Nicaragua            | 2.026 |                539.106,00 € |                            98,45% |        547.571,18 € |
-- | Panam�               | 2.026 |              1.516.665,54 € |                           100,00% |      1.516.665,54 € |
-- | Paraguay             | 2.026 |              1.304.142,81 € |                            97,96% |      1.331.331,97 € |
-- | Per�                 | 2.026 |              3.021.814,65 € |                           100,00% |      3.021.814,65 € |
-- | Rep�blica Dominicana | 2.026 |              1.621.889,27 € |                            98,57% |      1.645.347,89 € |
-- | Uruguay              | 2.026 |              5.961.996,16 € |                            99,42% |      5.996.485,93 € |
-- +----------------------+-------+-----------------------------+-----------------------------------+---------------------+
