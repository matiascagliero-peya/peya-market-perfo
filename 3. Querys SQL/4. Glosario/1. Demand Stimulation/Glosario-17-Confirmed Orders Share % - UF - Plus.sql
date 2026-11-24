DECLARE query_name STRING DEFAULT 'Glosario-17-Confirmed Orders Share % - UF - Plus';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 17
-- Nombre:     Confirmed Orders Share % - UF - Plus
-- Chapter:   Demand Stimulation
-- Query bajada en: 14 - UF Data
-- Sheets Name: 1. ET - UF Data (14 - UF Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/15-zHA4HDBopwhCBjwhIeHr-mLpVuYCe5I0G4bd8X-4s
-- Tablas de origen: `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` + `peya-bi-tools-pro.il_core.fact_orders`
-- Tipo:       Ratio Calculado
-- Fórmula:    Confirmed Orders - UF - Plus / Confirmed Orders - UF
-- Definición: Participación porcentual de clientes Plus dentro de las compras con Ultra Fresh.
-- ====================================================================================

SELECT
  d.country_name AS country,
  DATE_TRUNC(d.order_date, MONTH) AS month,
  COUNT(DISTINCT CASE WHEN d.master_category_parent_english IN ('Produce', 'Meat / Seafood', 'Ready To Consume') AND (fo.is_user_plus = 1 OR fo.is_user_plus = 1) THEN d.order_id END) AS confirmed_orders_uf_plus,
  COUNT(DISTINCT CASE WHEN d.master_category_parent_english IN ('Produce', 'Meat / Seafood', 'Ready To Consume') THEN d.order_id END) AS confirmed_orders_uf,
  SAFE_DIVIDE(
    COUNT(DISTINCT CASE WHEN d.master_category_parent_english IN ('Produce', 'Meat / Seafood', 'Ready To Consume') AND (fo.is_user_plus = 1 OR fo.is_user_plus = 1) THEN d.order_id END),
    NULLIF(COUNT(DISTINCT CASE WHEN d.master_category_parent_english IN ('Produce', 'Meat / Seafood', 'Ready To Consume') THEN d.order_id END), 0)
  ) AS confirmed_orders_share_uf_plus_pct
FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` d
INNER JOIN `peya-bi-tools-pro.il_core.fact_orders` fo ON CAST(d.order_id AS STRING) = CAST(fo.order_id AS STRING)
WHERE UPPER(d.state) = 'CONFIRMED'
  AND d.order_date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;
