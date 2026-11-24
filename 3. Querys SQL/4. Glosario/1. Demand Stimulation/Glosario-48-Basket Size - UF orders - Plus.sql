DECLARE query_name STRING DEFAULT 'Glosario-48-Basket Size - UF orders - Plus';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 48
-- Nombre:     Basket Size - UF orders - Plus
-- Chapter:   Demand Stimulation
-- Query bajada en: 14 - UF Data
-- Sheets Name: 1. ET - UF Data (14 - UF Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/15-zHA4HDBopwhCBjwhIeHr-mLpVuYCe5I0G4bd8X-4s
-- Tablas de origen: `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` + `peya-bi-tools-pro.il_core.fact_orders`
-- Tipo:       Ratio Calculado
-- Fórmula:    Units Sold in UF Orders (Plus) / Confirmed Orders - UF - Plus
-- Definición: Unidades promedio por orden UF en suscriptores Plus.
-- ====================================================================================

WITH uf_plus_orders AS (
  SELECT DISTINCT d.order_id
  FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` d
  INNER JOIN `peya-bi-tools-pro.il_core.fact_orders` fo ON CAST(d.order_id AS STRING) = CAST(fo.order_id AS STRING)
  WHERE UPPER(d.state) = 'CONFIRMED'
    AND d.order_date BETWEEN '2026-09-01' AND '2026-09-30'
    AND d.master_category_parent_english IN ('Produce', 'Meat / Seafood', 'Ready To Consume')
    AND (fo.is_user_plus = 1 OR fo.is_user_plus = 1)
)
SELECT
  d.country_name AS country,
  DATE_TRUNC(d.order_date, MONTH) AS month,
  SUM(d.fulfilled_quantity) AS units_sold_uf_plus,
  COUNT(DISTINCT d.order_id) AS confirmed_orders_uf_plus,
  SAFE_DIVIDE(
    SUM(d.fulfilled_quantity),
    NULLIF(COUNT(DISTINCT d.order_id), 0)
  ) AS basket_size_uf_orders_plus
FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` d
INNER JOIN uf_plus_orders ufo ON d.order_id = ufo.order_id
WHERE UPPER(d.state) = 'CONFIRMED'
  AND d.order_date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;
