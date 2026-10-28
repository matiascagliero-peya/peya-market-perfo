DECLARE query_name STRING DEFAULT 'Glosario-5-GMV User by Store';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 5
-- Nombre:     GMV User by Store
-- Chapter:   Demand Stimulation
-- Query bajada en: 0 - Orders
-- Sheets Name: 1. TD - OKRs Mensual (0 - Orders)
-- Sheets Link: https://docs.google.com/spreadsheets/d/13yTO_kFzIvISmbSz6p93BFUub1HODpuiGhB3yElZ2fw
-- Tablas de origen: `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
-- Tipo:       Ratio Calculado
-- Fórmula:    GMV User Dmarts / Active Warehouses
-- Definición: Venta bruta promedio de usuario generada por cada warehouse o tienda activa.
-- ====================================================================================

SELECT
  d.country_name AS country,
  DATE_TRUNC(d.order_date, MONTH) AS month,
  SAFE_DIVIDE(SUM(d.total_amount_sold_eur), NULLIF(COUNT(DISTINCT d.warehouse_id), 0)) AS gmv_user_by_store
FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` d
WHERE UPPER(d.state) = 'CONFIRMED'
  AND d.order_date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------------------+-------+
-- | country              | gmv_user_by_store | month |
-- +----------------------+-------------------+-------+
-- | Argentina            |      790.346,22 € | 2.026 |
-- | Bolivia              |      226.154,54 € | 2.026 |
-- | Chile                |      206.216,71 € | 2.026 |
-- | Ecuador              |      187.741,66 € | 2.026 |
-- | El Salvador          |      389.257,85 € | 2.026 |
-- | Guatemala            |      299.896,07 € | 2.026 |
-- | Honduras             |      223.009,45 € | 2.026 |
-- | Nicaragua            |      640.957,75 € | 2.026 |
-- | Panam�               |      269.287,31 € | 2.026 |
-- | Paraguay             |      379.246,41 € | 2.026 |
-- | Per�                 |      345.579,36 € | 2.026 |
-- | Rep�blica Dominicana |      320.668,99 € | 2.026 |
-- | Uruguay              |      957.081,46 € | 2.026 |
-- +----------------------+-------------------+-------+
