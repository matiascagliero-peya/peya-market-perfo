DECLARE query_name STRING DEFAULT 'Glosario-50-Basket Size - non Double Ya';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 50
-- Nombre:     Basket Size - non Double Ya
-- Chapter:   Demand Stimulation
-- Query bajada en: 21 - Double Ya Data
-- Sheets Name: 1. ET - DY Data (21 - Double Ya Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/18cUpQbzQXxAMcDix675p1zscuc_SmvXS_bYaVtEkUUU
-- Tablas de origen: `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya` (RAW) + `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
-- Tipo:       Ratio Calculado
-- Fórmula:    Units Sold (non Double Ya) / Confirmed Orders - non Double Ya
-- Definición: Unidades promedio por orden en canal directo.
-- ====================================================================================

WITH dy_orders AS (
  SELECT DISTINCT CAST(order_details.id.secondary AS STRING) AS order_id
  FROM `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya`
  WHERE order_type = 'DOUBLE_YA'
)
SELECT
  d.country_name AS country,
  DATE_TRUNC(d.order_date, MONTH) AS month,
  SUM(d.fulfilled_quantity) AS units_sold_non_double_ya,
  COUNT(DISTINCT d.order_id) AS confirmed_orders_non_double_ya,
  SAFE_DIVIDE(
    SUM(d.fulfilled_quantity),
    NULLIF(COUNT(DISTINCT d.order_id), 0)
  ) AS basket_size_non_double_ya
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
-- +---------------------------+--------------------------------+----------------------+-------+--------------------------+
-- | basket_size_non_double_ya | confirmed_orders_non_double_ya | country              | month | units_sold_non_double_ya |
-- +---------------------------+--------------------------------+----------------------+-------+--------------------------+
-- |                      8,75 |                      2.560.106 | Argentina            | 2.026 |            22.408.819,57 |
-- |                      7,23 |                        142.934 | Bolivia              | 2.026 |             1.032.909,38 |
-- |                      8,39 |                        335.733 | Chile                | 2.026 |             2.817.136,59 |
-- |                      6,59 |                         89.341 | Ecuador              | 2.026 |               588.435,74 |
-- |                      6,72 |                         79.252 | El Salvador          | 2.026 |                  532.958 |
-- |                      6,55 |                         89.103 | Guatemala            | 2.026 |                  583.271 |
-- |                      5,49 |                         40.433 | Honduras             | 2.026 |                  222.108 |
-- |                      6,56 |                         51.880 | Nicaragua            | 2.026 |               340.384,56 |
-- |                      7,34 |                         92.999 | Panam�               | 2.026 |               682.329,75 |
-- |                      6,59 |                        123.377 | Paraguay             | 2.026 |               812.560,15 |
-- |                      5,50 |                        273.380 | Per�                 | 2.026 |             1.503.957,68 |
-- |                      6,20 |                        159.940 | Rep�blica Dominicana | 2.026 |               991.839,98 |
-- |                      8,15 |                        279.150 | Uruguay              | 2.026 |             2.273.857,38 |
-- +---------------------------+--------------------------------+----------------------+-------+--------------------------+
