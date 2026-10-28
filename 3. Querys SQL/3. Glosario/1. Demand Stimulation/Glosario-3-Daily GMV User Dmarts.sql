DECLARE query_name STRING DEFAULT 'Glosario-3-Daily GMV User Dmarts';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 3
-- Nombre:     Daily GMV User Dmarts
-- Chapter:   Demand Stimulation
-- Query bajada en: 0 - Orders
-- Sheets Name: 1. TD - OKRs Mensual (0 - Orders)
-- Sheets Link: https://docs.google.com/spreadsheets/d/13yTO_kFzIvISmbSz6p93BFUub1HODpuiGhB3yElZ2fw
-- Tablas de origen: `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
-- Tipo:       Ratio Calculado
-- Fórmula:    GMV User Dmarts / Días del Mes
-- Definición: Promedio diario de GMV de usuarios generado en el mes.
-- ====================================================================================

SELECT
  d.country_name AS country,
  DATE_TRUNC(d.order_date, MONTH) AS month,
  SAFE_DIVIDE(SUM(d.total_amount_sold_eur), 30) AS daily_gmv_user_dmarts
FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` d
WHERE UPPER(d.state) = 'CONFIRMED'
  AND d.order_date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-----------------------+-------+
-- | country              | daily_gmv_user_dmarts | month |
-- +----------------------+-----------------------+-------+
-- | Argentina            |        1.870.486,06 € | 2.026 |
-- | Bolivia              |           37.692,42 € | 2.026 |
-- | Chile                |          192.468,93 € | 2.026 |
-- | Ecuador              |           43.806,39 € | 2.026 |
-- | El Salvador          |           38.925,79 € | 2.026 |
-- | Guatemala            |           49.982,68 € | 2.026 |
-- | Honduras             |           14.867,30 € | 2.026 |
-- | Nicaragua            |           21.365,26 € | 2.026 |
-- | Panam�               |           53.857,46 € | 2.026 |
-- | Paraguay             |           50.566,19 € | 2.026 |
-- | Per�                 |          126.712,43 € | 2.026 |
-- | Rep�blica Dominicana |           64.133,80 € | 2.026 |
-- | Uruguay              |          255.221,72 € | 2.026 |
-- +----------------------+-----------------------+-------+
