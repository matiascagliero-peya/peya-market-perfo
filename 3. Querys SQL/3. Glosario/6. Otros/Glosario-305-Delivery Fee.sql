DECLARE query_name STRING DEFAULT 'Glosario-305-Delivery Fee';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 305
-- Nombre:     Delivery Fee
-- Chapter:   Otros
-- Query bajada en: 0 - Orders
-- Sheets Name: 1. TD - OKRs Mensual (0 - Orders)
-- Sheets Link: https://docs.google.com/spreadsheets/d/13yTO_kFzIvISmbSz6p93BFUub1HODpuiGhB3yElZ2fw
-- Tablas de origen: `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` + `peya-bi-tools-pro.il_core.fact_orders` + `peya-bi-tools-pro.il_core.dim_partner` + `peya-datamarts-pro.dm_order_profitability.fact_order_profitability`
-- Tipo:       Dato / Ratio Calculado
-- Fórmula:    SUM(delivery_fee_amount_eur)
-- Definición: Ingresos totales cobrados a los usuarios finales en concepto de tarifa de envío a domicilio en órdenes de PeYa Market.
-- ====================================================================================

SELECT
  o.country.country_name AS country,
  DATE_TRUNC(DATE(o.registered_date), MONTH) AS month,
  SUM(SAFE_DIVIDE(COALESCE(o.delivery_fee_amount, o.shipping_amount, 0), fop.monthly_rate_eu)) AS delivery_fee_eur
FROM `peya-bi-tools-pro.il_core.fact_orders` o
INNER JOIN `peya-bi-tools-pro.il_core.dim_partner` p ON o.restaurant.id = p.partner_id
LEFT JOIN `peya-datamarts-pro.dm_order_profitability.fact_order_profitability` fop ON o.order_id = fop.order_id
WHERE o.order_status = 'CONFIRMED'
  AND p.is_darkstore = TRUE
  AND DATE(o.registered_date) BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;
