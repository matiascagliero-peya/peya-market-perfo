DECLARE query_name STRING DEFAULT 'Glosario-169-Discounts';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 169
-- Nombre:     Discounts
-- Chapter:   Assortment, Pricing & Promo
-- Query bajada en: 0 - Orders
-- Sheets Name: 1. TD - OKRs Mensual (0 - Orders)
-- Sheets Link: https://docs.google.com/spreadsheets/d/13yTO_kFzIvISmbSz6p93BFUub1HODpuiGhB3yElZ2fw
-- Tablas de origen: `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(COALESCE(pcm_discount_amount_net_eur, discount_amount_eur, 0))
-- Definición: Total de descuentos otorgados a clientes en órdenes confirmadas de PeYa Market en euros. Se calcula y baja en la planilla 0 - Orders.
-- ====================================================================================

SELECT
  d.country_name AS country,
  DATE_TRUNC(d.order_date, MONTH) AS month,
  SUM(COALESCE(d.pcm_discount_amount_net_eur, d.pcm_discount_amount_net_eur, 0)) AS discounts_eur
FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` d
WHERE UPPER(d.state) = 'CONFIRMED'
  AND d.order_date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+------------+----------------+
-- | country              | month      |  discounts_eur |
-- +----------------------+------------+----------------+
-- | Argentina            | 2026-09-01 | 9.217.335,49 € |
-- | Bolivia              | 2026-09-01 |    72.037,19 € |
-- | Chile                | 2026-09-01 |   397.571,81 € |
-- | Ecuador              | 2026-09-01 |   147.602,22 € |
-- | El Salvador          | 2026-09-01 |    31.815,46 € |
-- | Guatemala            | 2026-09-01 |    62.978,52 € |
-- | Honduras             | 2026-09-01 |    17.437,63 € |
-- | Nicaragua            | 2026-09-01 |    34.406,74 € |
-- | Panam�               | 2026-09-01 |    63.736,23 € |
-- | Paraguay             | 2026-09-01 |    61.001,35 € |
-- | Per�                 | 2026-09-01 |   252.384,62 € |
-- | Rep�blica Dominicana | 2026-09-01 |    68.366,81 € |
-- | Uruguay              | 2026-09-01 |   458.006,98 € |
-- +----------------------+------------+----------------+
