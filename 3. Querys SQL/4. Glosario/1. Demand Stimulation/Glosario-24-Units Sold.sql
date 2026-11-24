DECLARE query_name STRING DEFAULT 'Glosario-24-Units Sold';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 24
-- Nombre:     Units Sold
-- Chapter:   Demand Stimulation
-- Query bajada en: 0 - Orders
-- Sheets Name: 1. TD - OKRs Mensual (0 - Orders)
-- Sheets Link: https://docs.google.com/spreadsheets/d/13yTO_kFzIvISmbSz6p93BFUub1HODpuiGhB3yElZ2fw
-- Tablas de origen: `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
-- Tipo:       Dato Directo (Col 10)
-- Fórmula:    SUM(quantity_sold)
-- Definición: Cantidad total de unidades vendidas en órdenes confirmadas.
-- ====================================================================================

SELECT
  d.country_name AS country,
  DATE_TRUNC(d.order_date, MONTH) AS month,
  SUM(d.fulfilled_quantity) AS units_sold
FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` d
WHERE UPPER(d.state) = 'CONFIRMED'
  AND d.order_date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------+---------------+
-- | country              | month | units_sold    |
-- +----------------------+-------+---------------+
-- | Argentina            | 2.026 | 22.537.552,57 |
-- | Bolivia              | 2.026 |  1.032.909,38 |
-- | Chile                | 2.026 |  2.824.960,59 |
-- | Ecuador              | 2.026 |    598.603,74 |
-- | El Salvador          | 2.026 |       543.397 |
-- | Guatemala            | 2.026 |       593.219 |
-- | Honduras             | 2.026 |       234.762 |
-- | Nicaragua            | 2.026 |    346.016,56 |
-- | Panam�               | 2.026 |    682.329,75 |
-- | Paraguay             | 2.026 |    829.499,15 |
-- | Per�                 | 2.026 |  1.503.957,68 |
-- | Rep�blica Dominicana | 2.026 |  1.007.107,98 |
-- | Uruguay              | 2.026 |  2.285.044,38 |
-- +----------------------+-------+---------------+
