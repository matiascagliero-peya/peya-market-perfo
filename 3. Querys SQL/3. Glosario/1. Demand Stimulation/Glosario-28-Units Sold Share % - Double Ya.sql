DECLARE query_name STRING DEFAULT 'Glosario-28-Units Sold Share % - Double Ya';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 28
-- Nombre:     Units Sold Share % - Double Ya
-- Chapter:   Demand Stimulation
-- Query bajada en: 21 - Double Ya Data
-- Sheets Name: 1. ET - DY Data (21 - Double Ya Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/18cUpQbzQXxAMcDix675p1zscuc_SmvXS_bYaVtEkUUU
-- Tablas de origen: `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya` (RAW) + `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
-- Tipo:       Ratio Calculado
-- Fórmula:    Units Sold - Double Ya / Total Units Sold
-- Definición: Porcentaje de unidades físicas vendidas vía Double Ya.
-- ====================================================================================

WITH dy_orders AS (
  SELECT DISTINCT CAST(order_details.id.secondary AS STRING) AS order_id
  FROM `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya`
  WHERE order_type = 'DOUBLE_YA'
)
SELECT
  d.country_name AS country,
  DATE_TRUNC(d.order_date, MONTH) AS month,
  SUM(CASE WHEN dy.order_id IS NOT NULL THEN d.fulfilled_quantity ELSE 0 END) AS units_sold_double_ya,
  SUM(d.fulfilled_quantity) AS total_units_sold,
  SAFE_DIVIDE(
    SUM(CASE WHEN dy.order_id IS NOT NULL THEN d.fulfilled_quantity ELSE 0 END),
    NULLIF(SUM(d.fulfilled_quantity), 0)
  ) AS units_sold_share_double_ya_pct
FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` d
LEFT JOIN dy_orders dy ON CAST(d.order_id AS STRING) = dy.order_id
WHERE UPPER(d.state) = 'CONFIRMED'
  AND d.order_date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------+------------------+----------------------+--------------------------------+
-- | country              | month | total_units_sold | units_sold_double_ya | units_sold_share_double_ya_pct |
-- +----------------------+-------+------------------+----------------------+--------------------------------+
-- | Argentina            | 2.026 |    22.537.552,57 |              128.733 |                          0,57% |
-- | Bolivia              | 2.026 |     1.032.909,38 |                    0 |                          0,00% |
-- | Chile                | 2.026 |     2.824.960,59 |                7.824 |                          0,28% |
-- | Ecuador              | 2.026 |       598.603,74 |               10.168 |                          1,70% |
-- | El Salvador          | 2.026 |          543.397 |               10.439 |                          1,92% |
-- | Guatemala            | 2.026 |          593.219 |                9.948 |                          1,68% |
-- | Honduras             | 2.026 |          234.762 |               12.654 |                          5,39% |
-- | Nicaragua            | 2.026 |       346.016,56 |                5.632 |                          1,63% |
-- | Panam�               | 2.026 |       682.329,75 |                    0 |                          0,00% |
-- | Paraguay             | 2.026 |       829.499,15 |               16.939 |                          2,04% |
-- | Per�                 | 2.026 |     1.503.957,68 |                    0 |                          0,00% |
-- | Rep�blica Dominicana | 2.026 |     1.007.107,98 |               15.268 |                          1,52% |
-- | Uruguay              | 2.026 |     2.285.044,38 |               11.187 |                          0,49% |
-- +----------------------+-------+------------------+----------------------+--------------------------------+
