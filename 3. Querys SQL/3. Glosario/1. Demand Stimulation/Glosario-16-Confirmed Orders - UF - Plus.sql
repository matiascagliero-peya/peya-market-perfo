DECLARE query_name STRING DEFAULT 'Glosario-16-Confirmed Orders - UF - Plus';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 16
-- Nombre:     Confirmed Orders - UF - Plus
-- Chapter:   Demand Stimulation
-- Query bajada en: 14 - UF Data
-- Sheets Name: 1. ET - UF Data (14 - UF Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/15-zHA4HDBopwhCBjwhIeHr-mLpVuYCe5I0G4bd8X-4s
-- Tablas de origen: `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` + `peya-bi-tools-pro.il_core.fact_orders`
-- Tipo:       Dato Directo (Col 10)
-- Fórmula:    COUNT(DISTINCT order_id) UF realizadas por usuarios Plus
-- Definición: Órdenes con productos Ultra Fresh realizadas por clientes Plus.
-- ====================================================================================

SELECT
  d.country_name AS country,
  DATE_TRUNC(d.order_date, MONTH) AS month,
  COUNT(DISTINCT CASE WHEN d.master_category_parent_english IN ('Produce', 'Meat / Seafood', 'Ready To Consume') AND (fo.is_user_plus = 1 OR fo.is_user_plus = 1) THEN d.order_id END) AS confirmed_orders_uf_plus
FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` d
INNER JOIN `peya-bi-tools-pro.il_core.fact_orders` fo ON CAST(d.order_id AS STRING) = CAST(fo.order_id AS STRING)
WHERE UPPER(d.state) = 'CONFIRMED'
  AND d.order_date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;
