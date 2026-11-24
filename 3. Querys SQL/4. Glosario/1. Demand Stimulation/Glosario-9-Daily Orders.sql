DECLARE query_name STRING DEFAULT 'Glosario-9-Daily Orders';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 9
-- Nombre:     Daily Orders
-- Chapter:   Demand Stimulation
-- Query bajada en: 0 - Orders
-- Sheets Name: 1. TD - OKRs Mensual (0 - Orders)
-- Sheets Link: https://docs.google.com/spreadsheets/d/13yTO_kFzIvISmbSz6p93BFUub1HODpuiGhB3yElZ2fw
-- Tablas de origen: `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
-- Tipo:       Ratio Calculado
-- Fórmula:    Confirmed Orders / Días del Mes
-- Definición: Promedio diario de órdenes confirmadas a nivel país/región.
-- ====================================================================================

SELECT
  d.country_name AS country,
  DATE_TRUNC(d.order_date, MONTH) AS month,
  SAFE_DIVIDE(COUNT(DISTINCT d.order_id), 30) AS daily_orders
FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` d
WHERE UPPER(d.state) = 'CONFIRMED'
  AND d.order_date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+--------------+-------+
-- | country              | daily_orders | month |
-- +----------------------+--------------+-------+
-- | Argentina            |    88.422,60 | 2.026 |
-- | Bolivia              |     4.764,47 | 2.026 |
-- | Chile                |       11.409 | 2.026 |
-- | Ecuador              |     3.247,17 | 2.026 |
-- | El Salvador          |     2.876,17 | 2.026 |
-- | Guatemala            |     3.190,17 | 2.026 |
-- | Honduras             |     1.690,60 | 2.026 |
-- | Nicaragua            |     1.881,23 | 2.026 |
-- | Panam�               |     3.099,97 | 2.026 |
-- | Paraguay             |     4.526,63 | 2.026 |
-- | Per�                 |     9.112,67 | 2.026 |
-- | Rep�blica Dominicana |     5.711,60 | 2.026 |
-- | Uruguay              |     9.569,83 | 2.026 |
-- +----------------------+--------------+-------+
