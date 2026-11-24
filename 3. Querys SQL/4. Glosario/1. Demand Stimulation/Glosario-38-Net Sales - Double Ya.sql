DECLARE query_name STRING DEFAULT 'Glosario-38-Net Sales - Double Ya';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 38
-- Nombre:     Net Sales - Double Ya
-- Chapter:   Demand Stimulation
-- Query bajada en: 21 - Double Ya Data
-- Sheets Name: 1. ET - DY Data (21 - Double Ya Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/18cUpQbzQXxAMcDix675p1zscuc_SmvXS_bYaVtEkUUU
-- Tablas de origen: `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya` (RAW) + `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(net_sales_eur) canal Double Ya
-- Definición: Venta neta generada por pedidos del canal Double Ya.
-- ====================================================================================

WITH dy_orders AS (
  SELECT DISTINCT CAST(order_details.id.secondary AS STRING) AS order_id
  FROM `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya`
  WHERE order_type = 'DOUBLE_YA'
)
SELECT
  d.country_name AS country,
  DATE_TRUNC(d.order_date, MONTH) AS month,
  SUM(d.total_amount_net_with_discount_eur) AS net_sales_double_ya_eur
FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` d
INNER JOIN dy_orders dy ON CAST(d.order_id AS STRING) = dy.order_id
WHERE UPPER(d.state) = 'CONFIRMED'
  AND d.order_date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------+-------------------------+
-- | country              | month | net_sales_double_ya_eur |
-- +----------------------+-------+-------------------------+
-- | Argentina            | 2.026 |            290.896,13 € |
-- | Chile                | 2.026 |             18.102,77 € |
-- | Ecuador              | 2.026 |             15.587,77 € |
-- | El Salvador          | 2.026 |             17.709,87 € |
-- | Guatemala            | 2.026 |             18.816,79 € |
-- | Honduras             | 2.026 |             21.725,72 € |
-- | Nicaragua            | 2.026 |              8.465,18 € |
-- | Paraguay             | 2.026 |             27.189,16 € |
-- | Rep�blica Dominicana | 2.026 |             23.458,62 € |
-- | Uruguay              | 2.026 |             34.489,77 € |
-- +----------------------+-------+-------------------------+
