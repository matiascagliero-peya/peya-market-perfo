DECLARE query_name STRING DEFAULT 'Glosario-58-Frequency';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 58
-- Nombre:     Frequency
-- Chapter:   Demand Stimulation
-- Query bajada en: 0 - Orders / 4 - Users
-- Sheets Name: 1. TD - OKRs Mensual (0 - Orders)
-- Sheets Link: https://docs.google.com/spreadsheets/d/13yTO_kFzIvISmbSz6p93BFUub1HODpuiGhB3yElZ2fw
-- Tablas de origen: `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` (RAW)
-- Tipo:       Ratio Calculado
-- Fórmula:    Confirmed Orders / Dmart MAUs
-- Definición: Frecuencia promedio de compra mensual por usuario activo.
-- ====================================================================================

SELECT
  d.country_name AS country,
  DATE_TRUNC(d.order_date, MONTH) AS month,
  COUNT(DISTINCT d.order_id) AS confirmed_orders,
  COUNT(DISTINCT d.customer_id) AS dmart_maus,
  SAFE_DIVIDE(COUNT(DISTINCT d.order_id), NULLIF(COUNT(DISTINCT d.customer_id), 0)) AS frequency
FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` d
WHERE UPPER(d.state) = 'CONFIRMED'
  AND d.order_date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +------------------+----------------------+------------+-----------+-------+
-- | confirmed_orders | country              | dmart_maus | frequency | month |
-- +------------------+----------------------+------------+-----------+-------+
-- |        2.652.678 | Argentina            |    986.252 |      2,69 | 2.026 |
-- |          142.934 | Bolivia              |     58.902 |      2,43 | 2.026 |
-- |          342.270 | Chile                |    149.912 |      2,28 | 2.026 |
-- |           97.415 | Ecuador              |     46.321 |      2,10 | 2.026 |
-- |           86.285 | El Salvador          |     34.164 |      2,53 | 2.026 |
-- |           95.705 | Guatemala            |     38.335 |      2,50 | 2.026 |
-- |           50.718 | Honduras             |     25.111 |      2,02 | 2.026 |
-- |           56.437 | Nicaragua            |     23.216 |      2,43 | 2.026 |
-- |           92.999 | Panam�               |     38.552 |      2,41 | 2.026 |
-- |          135.799 | Paraguay             |     49.820 |      2,73 | 2.026 |
-- |          273.380 | Per�                 |    111.612 |      2,45 | 2.026 |
-- |          171.348 | Rep�blica Dominicana |     68.651 |      2,50 | 2.026 |
-- |          287.095 | Uruguay              |     92.453 |      3,11 | 2.026 |
-- +------------------+----------------------+------------+-----------+-------+
