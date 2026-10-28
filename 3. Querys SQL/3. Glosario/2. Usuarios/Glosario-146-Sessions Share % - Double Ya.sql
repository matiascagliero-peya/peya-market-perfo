DECLARE query_name STRING DEFAULT 'Glosario-146-Sessions Share % - Double Ya';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 146
-- Nombre:     Sessions Share % - Double Ya
-- Chapter:   Usuarios
-- Query bajada en: 4 - Users / Growth Tracker
-- Sheets Name: 1. ET - Users Type Count (4 - Users)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1X0bnsCoDszeSlq5TT1uw20GWtcfu1iBpshXXI1QIv7M
-- Tablas de origen: `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya` (RAW) + `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
-- Tipo:       Ratio Calculado
-- Fórmula:    Sessions Double Ya / Sessions Total
-- Definición: Porcentaje del tráfico de tienda originado mediante el flujo Double Ya sobre el total de sesiones.
-- ====================================================================================

WITH dy_orders AS (
  -- 1. Órdenes RAW identificadas en el flujo de cross-selling Double Ya
  SELECT DISTINCT
    CAST(order_details.id.secondary AS STRING) AS order_id
  FROM `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya`
  WHERE order_type = 'DOUBLE_YA'
)
SELECT
  d.country_name AS country,
  DATE_TRUNC(d.order_date, MONTH) AS month,
  COUNT(DISTINCT d.order_id) AS total_orders,
  COUNT(DISTINCT CASE WHEN dy.order_id IS NOT NULL THEN d.order_id END) AS confirmed_orders_double_ya,
  COUNT(DISTINCT CASE WHEN dy.order_id IS NULL THEN d.order_id END) AS confirmed_orders_non_double_ya,
  SUM(CASE WHEN dy.order_id IS NOT NULL THEN d.fulfilled_quantity ELSE 0 END) AS units_sold_double_ya,
  SUM(CASE WHEN dy.order_id IS NOT NULL THEN d.total_amount_net_with_discount_eur ELSE 0 END) AS net_sales_double_ya,
  SAFE_DIVIDE(
    COUNT(DISTINCT CASE WHEN dy.order_id IS NOT NULL THEN d.order_id END),
    NULLIF(COUNT(DISTINCT d.order_id), 0)
  ) AS double_ya_orders_share
FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` d
LEFT JOIN dy_orders dy
  ON CAST(d.order_id AS STRING) = dy.order_id
WHERE UPPER(d.state) = 'CONFIRMED'
  AND d.order_date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------------+--------------------------------+----------------------+------------------------+-------+---------------------+--------------+----------------------+
-- | confirmed_orders_double_ya | confirmed_orders_non_double_ya | country              | double_ya_orders_share | month | net_sales_double_ya | total_orders | units_sold_double_ya |
-- +----------------------------+--------------------------------+----------------------+------------------------+-------+---------------------+--------------+----------------------+
-- |                     92.572 |                      2.560.106 | Argentina            |                  3,49% | 2.026 |        290.896,13 € |    2.652.678 |              128.733 |
-- |                          0 |                        142.934 | Bolivia              |                  0,00% | 2.026 |              0,00 € |      142.934 |                    0 |
-- |                      6.537 |                        335.733 | Chile                |                  1,91% | 2.026 |         18.102,77 € |      342.270 |                7.824 |
-- |                      8.074 |                         89.341 | Ecuador              |                  8,29% | 2.026 |         15.587,77 € |       97.415 |               10.168 |
-- |                      7.033 |                         79.252 | El Salvador          |                  8,15% | 2.026 |         17.709,87 € |       86.285 |               10.439 |
-- |                      6.602 |                         89.103 | Guatemala            |                  6,90% | 2.026 |         18.816,79 € |       95.705 |                9.948 |
-- |                     10.285 |                         40.433 | Honduras             |                 20,28% | 2.026 |         21.725,72 € |       50.718 |               12.654 |
-- |                      4.557 |                         51.880 | Nicaragua            |                  8,07% | 2.026 |          8.465,18 € |       56.437 |                5.632 |
-- |                          0 |                         92.999 | Panam�               |                  0,00% | 2.026 |              0,00 € |       92.999 |                    0 |
-- |                     12.422 |                        123.377 | Paraguay             |                  9,15% | 2.026 |         27.189,16 € |      135.799 |               16.939 |
-- |                          0 |                        273.380 | Per�                 |                  0,00% | 2.026 |              0,00 € |      273.380 |                    0 |
-- |                     11.408 |                        159.940 | Rep�blica Dominicana |                  6,66% | 2.026 |         23.458,62 € |      171.348 |               15.268 |
-- |                      7.945 |                        279.150 | Uruguay              |                  2,77% | 2.026 |         34.489,77 € |      287.095 |               11.187 |
-- +----------------------------+--------------------------------+----------------------+------------------------+-------+---------------------+--------------+----------------------+
