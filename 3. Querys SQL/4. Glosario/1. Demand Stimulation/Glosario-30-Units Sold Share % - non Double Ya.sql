DECLARE query_name STRING DEFAULT 'Glosario-30-Units Sold Share % - non Double Ya';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 30
-- Nombre:     Units Sold Share % - non Double Ya
-- Chapter:   Demand Stimulation
-- Query bajada en: 21 - Double Ya Data
-- Sheets Name: 1. ET - DY Data (21 - Double Ya Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/18cUpQbzQXxAMcDix675p1zscuc_SmvXS_bYaVtEkUUU
-- Tablas de origen: `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya` (RAW) + `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
-- Tipo:       Ratio Calculado
-- Fórmula:    Units Sold - non Double Ya / Total Units Sold
-- Definición: Porcentaje de unidades vendidas en pedidos directos.
-- ====================================================================================

WITH dy_orders AS (
  SELECT DISTINCT CAST(order_details.id.secondary AS STRING) AS order_id
  FROM `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya`
  WHERE order_type = 'DOUBLE_YA'
)
SELECT
  d.country_name AS country,
  DATE_TRUNC(d.order_date, MONTH) AS month,
  SUM(CASE WHEN dy.order_id IS NULL THEN d.fulfilled_quantity ELSE 0 END) AS units_sold_non_double_ya,
  SUM(d.fulfilled_quantity) AS total_units_sold,
  SAFE_DIVIDE(
    SUM(CASE WHEN dy.order_id IS NULL THEN d.fulfilled_quantity ELSE 0 END),
    NULLIF(SUM(d.fulfilled_quantity), 0)
  ) AS units_sold_share_non_double_ya_pct
FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` d
LEFT JOIN dy_orders dy ON CAST(d.order_id AS STRING) = dy.order_id
WHERE UPPER(d.state) = 'CONFIRMED'
  AND d.order_date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------+------------------+--------------------------+------------------------------------+
-- | country              | month | total_units_sold | units_sold_non_double_ya | units_sold_share_non_double_ya_pct |
-- +----------------------+-------+------------------+--------------------------+------------------------------------+
-- | Argentina            | 2.026 |    22.537.552,57 |            22.408.819,57 |                             99,43% |
-- | Bolivia              | 2.026 |     1.032.909,38 |             1.032.909,38 |                            100,00% |
-- | Chile                | 2.026 |     2.824.960,59 |             2.817.136,59 |                             99,72% |
-- | Ecuador              | 2.026 |       598.603,74 |               588.435,74 |                             98,30% |
-- | El Salvador          | 2.026 |          543.397 |                  532.958 |                             98,08% |
-- | Guatemala            | 2.026 |          593.219 |                  583.271 |                             98,32% |
-- | Honduras             | 2.026 |          234.762 |                  222.108 |                             94,61% |
-- | Nicaragua            | 2.026 |       346.016,56 |               340.384,56 |                             98,37% |
-- | Panam�               | 2.026 |       682.329,75 |               682.329,75 |                            100,00% |
-- | Paraguay             | 2.026 |       829.499,15 |               812.560,15 |                             97,96% |
-- | Per�                 | 2.026 |     1.503.957,68 |             1.503.957,68 |                            100,00% |
-- | Rep�blica Dominicana | 2.026 |     1.007.107,98 |               991.839,98 |                             98,48% |
-- | Uruguay              | 2.026 |     2.285.044,38 |             2.273.857,38 |                             99,51% |
-- +----------------------+-------+------------------+--------------------------+------------------------------------+
