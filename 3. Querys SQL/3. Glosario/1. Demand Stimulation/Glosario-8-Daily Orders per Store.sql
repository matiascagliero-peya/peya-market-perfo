DECLARE query_name STRING DEFAULT 'Glosario-8-Daily Orders per Store';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 8
-- Nombre:     Daily Orders per Store
-- Chapter:   Demand Stimulation
-- Query bajada en: 0 - Orders
-- Sheets Name: 1. TD - OKRs Mensual (0 - Orders)
-- Sheets Link: https://docs.google.com/spreadsheets/d/13yTO_kFzIvISmbSz6p93BFUub1HODpuiGhB3yElZ2fw
-- Tablas de origen: `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
-- Tipo:       Ratio Calculado
-- Fórmula:    Confirmed Orders / (Active Warehouses * Días del Mes)
-- Definición: Promedio de órdenes diarias despachadas por cada tienda activa.
-- ====================================================================================

SELECT
  d.country_name AS country,
  DATE_TRUNC(d.order_date, MONTH) AS month,
  SAFE_DIVIDE(COUNT(DISTINCT d.order_id), NULLIF(COUNT(DISTINCT d.warehouse_id) * 30, 0)) AS daily_orders_per_store
FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` d
WHERE UPPER(d.state) = 'CONFIRMED'
  AND d.order_date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+------------------------+-------+
-- | country              | daily_orders_per_store | month |
-- +----------------------+------------------------+-------+
-- | Argentina            |               1.245,39 | 2.026 |
-- | Bolivia              |                 952,89 | 2.026 |
-- | Chile                |                 407,46 | 2.026 |
-- | Ecuador              |                 463,88 | 2.026 |
-- | El Salvador          |                 958,72 | 2.026 |
-- | Guatemala            |                 638,03 | 2.026 |
-- | Honduras             |                 845,30 | 2.026 |
-- | Nicaragua            |               1.881,23 | 2.026 |
-- | Panam�               |                 516,66 | 2.026 |
-- | Paraguay             |               1.131,66 | 2.026 |
-- | Per�                 |                 828,42 | 2.026 |
-- | Rep�blica Dominicana |                 951,93 | 2.026 |
-- | Uruguay              |               1.196,23 | 2.026 |
-- +----------------------+------------------------+-------+
