DECLARE query_name STRING DEFAULT 'Glosario-63-Frequency - non Double Ya';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 63
-- Nombre:     Frequency - non Double Ya
-- Chapter:   Demand Stimulation
-- Query bajada en: 21 - Double Ya Data
-- Sheets Name: 1. ET - DY Data (21 - Double Ya Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/18cUpQbzQXxAMcDix675p1zscuc_SmvXS_bYaVtEkUUU
-- Tablas de origen: `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya` (RAW) + `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
-- Tipo:       Ratio Calculado
-- Fórmula:    Orders Direct / (MAUs Direct + MAUs Hybrid)
-- Definición: Frecuencia de pedidos en canal directo.
-- ====================================================================================

WITH dy_orders AS (
  SELECT DISTINCT CAST(order_details.id.secondary AS STRING) AS order_id
  FROM `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya`
  WHERE order_type = 'DOUBLE_YA'
)
SELECT
  d.country_name AS country,
  DATE_TRUNC(d.order_date, MONTH) AS month,
  COUNT(DISTINCT d.order_id) AS orders_non_double_ya,
  COUNT(DISTINCT d.customer_id) AS customers_non_double_ya,
  SAFE_DIVIDE(
    COUNT(DISTINCT d.order_id),
    NULLIF(COUNT(DISTINCT d.customer_id), 0)
  ) AS frequency_non_double_ya
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
-- +----------------------+-------------------------+-------------------------+-------+----------------------+
-- | country              | customers_non_double_ya | frequency_non_double_ya | month | orders_non_double_ya |
-- +----------------------+-------------------------+-------------------------+-------+----------------------+
-- | Argentina            |                 940.925 |                    2,72 | 2.026 |            2.560.106 |
-- | Bolivia              |                  58.902 |                    2,43 | 2.026 |              142.934 |
-- | Chile                |                 145.917 |                    2,30 | 2.026 |              335.733 |
-- | Ecuador              |                  41.694 |                    2,14 | 2.026 |               89.341 |
-- | El Salvador          |                  30.832 |                    2,57 | 2.026 |               79.252 |
-- | Guatemala            |                  34.780 |                    2,56 | 2.026 |               89.103 |
-- | Honduras             |                  19.550 |                    2,07 | 2.026 |               40.433 |
-- | Nicaragua            |                  20.803 |                    2,49 | 2.026 |               51.880 |
-- | Panam�               |                  38.552 |                    2,41 | 2.026 |               92.999 |
-- | Paraguay             |                  44.404 |                    2,78 | 2.026 |              123.377 |
-- | Per�                 |                 111.612 |                    2,45 | 2.026 |              273.380 |
-- | Rep�blica Dominicana |                  62.796 |                    2,55 | 2.026 |              159.940 |
-- | Uruguay              |                  89.017 |                    3,14 | 2.026 |              279.150 |
-- +----------------------+-------------------------+-------------------------+-------+----------------------+
