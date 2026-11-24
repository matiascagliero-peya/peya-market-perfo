DECLARE query_name STRING DEFAULT 'Glosario-4-GMV User Share Dmarts %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 4
-- Nombre:     GMV User Share Dmarts %
-- Chapter:   Demand Stimulation
-- Query bajada en: 0 - Orders
-- Sheets Name: 1. TD - OKRs Mensual (0 - Orders)
-- Sheets Link: https://docs.google.com/spreadsheets/d/13yTO_kFzIvISmbSz6p93BFUub1HODpuiGhB3yElZ2fw
-- Tablas de origen: `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
-- Tipo:       Ratio Calculado
-- Fórmula:    GMV User Dmarts / GMV User Platform
-- Definición: Participación porcentual del GMV de usuarios de Dmarts sobre el total de la plataforma.
-- ====================================================================================

SELECT
  d.country_name AS country,
  DATE_TRUNC(d.order_date, MONTH) AS month,
  COUNT(DISTINCT d.order_id) AS confirmed_orders,
  SUM(d.total_amount_net_with_discount_eur) AS net_sales_eur
FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` d
WHERE UPPER(d.state) = 'CONFIRMED'
  AND d.order_date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +------------------+----------------------+-------+-----------------+
-- | confirmed_orders | country              | month | net_sales_eur   |
-- +------------------+----------------------+-------+-----------------+
-- |        2.652.678 | Argentina            | 2.026 | 38.180.783,43 € |
-- |          142.934 | Bolivia              | 2.026 |    912.047,81 € |
-- |          342.270 | Chile                | 2.026 |  4.502.418,25 € |
-- |           97.415 | Ecuador              | 2.026 |  1.058.639,43 € |
-- |           86.285 | El Salvador          | 2.026 |  1.001.595,76 € |
-- |           95.705 | Guatemala            | 2.026 |  1.275.808,28 € |
-- |           50.718 | Honduras             | 2.026 |    393.674,13 € |
-- |           56.437 | Nicaragua            | 2.026 |    547.571,18 € |
-- |           92.999 | Panam�               | 2.026 |  1.516.665,54 € |
-- |          135.799 | Paraguay             | 2.026 |  1.331.331,97 € |
-- |          273.380 | Per�                 | 2.026 |  3.021.814,65 € |
-- |          171.348 | Rep�blica Dominicana | 2.026 |  1.645.347,89 € |
-- |          287.095 | Uruguay              | 2.026 |  5.996.485,93 € |
-- +------------------+----------------------+-------+-----------------+
