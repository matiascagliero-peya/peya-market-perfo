DECLARE query_name STRING DEFAULT 'Glosario-29-Units Sold - non Double Ya';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 29
-- Nombre:     Units Sold - non Double Ya
-- Chapter:   Demand Stimulation
-- Query bajada en: 21 - Double Ya Data
-- Sheets Name: 1. ET - DY Data (21 - Double Ya Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/18cUpQbzQXxAMcDix675p1zscuc_SmvXS_bYaVtEkUUU
-- Tablas de origen: `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya` (RAW) + `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(quantity_sold) canal directo
-- Definición: Unidades vendidas en pedidos orgánicos directos.
-- ====================================================================================

WITH dy_orders AS (
  SELECT DISTINCT CAST(order_details.id.secondary AS STRING) AS order_id
  FROM `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya`
  WHERE order_type = 'DOUBLE_YA'
)
SELECT
  d.country_name AS country,
  DATE_TRUNC(d.order_date, MONTH) AS month,
  SUM(d.fulfilled_quantity) AS units_sold_non_double_ya
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
-- +----------------------+-------+--------------------------+
-- | country              | month | units_sold_non_double_ya |
-- +----------------------+-------+--------------------------+
-- | Argentina            | 2.026 |            22.408.819,57 |
-- | Bolivia              | 2.026 |             1.032.909,38 |
-- | Chile                | 2.026 |             2.817.136,59 |
-- | Ecuador              | 2.026 |               588.435,74 |
-- | El Salvador          | 2.026 |                  532.958 |
-- | Guatemala            | 2.026 |                  583.271 |
-- | Honduras             | 2.026 |                  222.108 |
-- | Nicaragua            | 2.026 |               340.384,56 |
-- | Panam�               | 2.026 |               682.329,75 |
-- | Paraguay             | 2.026 |               812.560,15 |
-- | Per�                 | 2.026 |             1.503.957,68 |
-- | Rep�blica Dominicana | 2.026 |               991.839,98 |
-- | Uruguay              | 2.026 |             2.273.857,38 |
-- +----------------------+-------+--------------------------+
