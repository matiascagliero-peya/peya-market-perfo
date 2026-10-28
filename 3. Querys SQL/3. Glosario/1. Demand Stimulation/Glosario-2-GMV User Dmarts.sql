DECLARE query_name STRING DEFAULT 'Glosario-2-GMV User Dmarts';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 2
-- Nombre:     GMV User Dmarts
-- Chapter:   Demand Stimulation
-- Query bajada en: 0 - Orders
-- Sheets Name: 1. TD - OKRs Mensual (0 - Orders)
-- Sheets Link: https://docs.google.com/spreadsheets/d/13yTO_kFzIvISmbSz6p93BFUub1HODpuiGhB3yElZ2fw
-- Tablas de origen: `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
-- Tipo:       Dato Directo (Col 15)
-- Fórmula:    SUM(gmv_user_eur)
-- Definición: Volumen Bruto de Mercadería pagado por los usuarios finales en Dmarts en euros.
-- ====================================================================================

SELECT
  d.country_name AS country,
  DATE_TRUNC(d.order_date, MONTH) AS month,
  SUM(d.total_amount_sold_eur) AS gmv_user_eur
FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` d
WHERE UPPER(d.state) = 'CONFIRMED'
  AND d.order_date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-----------------+-------+
-- | country              | gmv_user_eur    | month |
-- +----------------------+-----------------+-------+
-- | Argentina            | 56.114.581,76 € | 2.026 |
-- | Bolivia              |  1.130.772,70 € | 2.026 |
-- | Chile                |  5.774.067,81 € | 2.026 |
-- | Ecuador              |  1.314.191,61 € | 2.026 |
-- | El Salvador          |  1.167.773,55 € | 2.026 |
-- | Guatemala            |  1.499.480,35 € | 2.026 |
-- | Honduras             |    446.018,90 € | 2.026 |
-- | Nicaragua            |    640.957,75 € | 2.026 |
-- | Panam�               |  1.615.723,86 € | 2.026 |
-- | Paraguay             |  1.516.985,63 € | 2.026 |
-- | Per�                 |  3.801.372,94 € | 2.026 |
-- | Rep�blica Dominicana |  1.924.013,93 € | 2.026 |
-- | Uruguay              |  7.656.651,68 € | 2.026 |
-- +----------------------+-----------------+-------+
