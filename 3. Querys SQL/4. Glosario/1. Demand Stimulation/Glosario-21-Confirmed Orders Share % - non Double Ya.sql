DECLARE query_name STRING DEFAULT 'Glosario-21-Confirmed Orders Share % - non Double Ya';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 21
-- Nombre:     Confirmed Orders Share % - non Double Ya
-- Chapter:   Demand Stimulation
-- Query bajada en: 21 - Double Ya Data
-- Sheets Name: 1. ET - DY Data (21 - Double Ya Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/18cUpQbzQXxAMcDix675p1zscuc_SmvXS_bYaVtEkUUU
-- Tablas de origen: `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya` (RAW) + `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
-- Tipo:       Ratio Calculado
-- Fórmula:    Confirmed Orders - non Double Ya / Total Orders
-- Definición: Participación del canal directo sobre el total.
-- ====================================================================================

WITH dy_orders AS (
  SELECT DISTINCT CAST(order_details.id.secondary AS STRING) AS order_id
  FROM `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya`
  WHERE order_type = 'DOUBLE_YA'
)
SELECT
  d.country_name AS country,
  DATE_TRUNC(d.order_date, MONTH) AS month,
  COUNT(DISTINCT CASE WHEN dy.order_id IS NULL THEN d.order_id END) AS non_double_ya_orders,
  COUNT(DISTINCT d.order_id) AS total_orders,
  SAFE_DIVIDE(
    COUNT(DISTINCT CASE WHEN dy.order_id IS NULL THEN d.order_id END),
    NULLIF(COUNT(DISTINCT d.order_id), 0)
  ) AS non_double_ya_orders_share_pct
FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` d
LEFT JOIN dy_orders dy ON CAST(d.order_id AS STRING) = dy.order_id
WHERE UPPER(d.state) = 'CONFIRMED'
  AND d.order_date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------+----------------------+--------------------------------+--------------+
-- | country              | month | non_double_ya_orders | non_double_ya_orders_share_pct | total_orders |
-- +----------------------+-------+----------------------+--------------------------------+--------------+
-- | Argentina            | 2.026 |            2.560.106 |                         96,51% |    2.652.678 |
-- | Bolivia              | 2.026 |              142.934 |                        100,00% |      142.934 |
-- | Chile                | 2.026 |              335.733 |                         98,09% |      342.270 |
-- | Ecuador              | 2.026 |               89.341 |                         91,71% |       97.415 |
-- | El Salvador          | 2.026 |               79.252 |                         91,85% |       86.285 |
-- | Guatemala            | 2.026 |               89.103 |                         93,10% |       95.705 |
-- | Honduras             | 2.026 |               40.433 |                         79,72% |       50.718 |
-- | Nicaragua            | 2.026 |               51.880 |                         91,93% |       56.437 |
-- | Panam�               | 2.026 |               92.999 |                        100,00% |       92.999 |
-- | Paraguay             | 2.026 |              123.377 |                         90,85% |      135.799 |
-- | Per�                 | 2.026 |              273.380 |                        100,00% |      273.380 |
-- | Rep�blica Dominicana | 2.026 |              159.940 |                         93,34% |      171.348 |
-- | Uruguay              | 2.026 |              279.150 |                         97,23% |      287.095 |
-- +----------------------+-------+----------------------+--------------------------------+--------------+
