DECLARE query_name STRING DEFAULT 'Glosario-176-Gross Basket Discount %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 176
-- Nombre:     Gross Basket Discount %
-- Chapter:   Assortment, Pricing & Promo
-- Query bajada en: 5 - Supply Chain / AQS
-- Sheets Name: A. TI - SC Data - Monthly (5 - Supply Chain)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1aCrgEjh6qT5T8ayT2H22r3iNc55nAR1O9vaOCW6pRBs
-- Tablas de origen: `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
-- Tipo:       Ratio Calculado
-- Fórmula:    SUM(pcm_discount_amount_net_eur) / SUM(total_amount_sold_net_eur)
-- Definición: Métrica comercial de surtido/precios: Gross Basket Discount %.
-- ====================================================================================

SELECT
  country_name AS country,
  DATE_TRUNC(order_date, MONTH) AS month,
  SAFE_DIVIDE(
    SUM(pcm_discount_amount_net_eur),
    NULLIF(SUM(total_amount_sold_net_eur), 0)
  ) AS gross_basket_discount_pct
FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
WHERE order_date BETWEEN '2026-09-01' AND '2026-09-30'
  AND state = 'CONFIRMED'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+---------------------------+-------+
-- | country              | gross_basket_discount_pct | month |
-- +----------------------+---------------------------+-------+
-- | Argentina            |                    19,45% | 2.026 |
-- | Bolivia              |                     7,32% | 2.026 |
-- | Chile                |                     8,11% | 2.026 |
-- | Ecuador              |                    12,24% | 2.026 |
-- | El Salvador          |                     3,08% | 2.026 |
-- | Guatemala            |                     4,70% | 2.026 |
-- | Honduras             |                     4,24% | 2.026 |
-- | Nicaragua            |                     5,91% | 2.026 |
-- | Panam�               |                     4,03% | 2.026 |
-- | Paraguay             |                     4,38% | 2.026 |
-- | Per�                 |                     7,72% | 2.026 |
-- | Rep�blica Dominicana |                     3,99% | 2.026 |
-- | Uruguay              |                     7,10% | 2.026 |
-- +----------------------+---------------------------+-------+
