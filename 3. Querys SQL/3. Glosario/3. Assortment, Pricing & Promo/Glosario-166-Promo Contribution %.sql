DECLARE query_name STRING DEFAULT 'Glosario-166-Promo Contribution %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 166
-- Nombre:     Promo Contribution %
-- Chapter:   Assortment, Pricing & Promo
-- Query bajada en: 5 - Supply Chain / AQS
-- Sheets Name: A. TI - SC Data - Monthly (5 - Supply Chain)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1aCrgEjh6qT5T8ayT2H22r3iNc55nAR1O9vaOCW6pRBs
-- Tablas de origen: `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
-- Tipo:       Ratio Calculado
-- Fórmula:    SUM(net_sales con descuento) / SUM(total_net_sales)
-- Definición: Métrica comercial de surtido/precios: Promo Contribution %.
-- ====================================================================================

SELECT
  country_name AS country,
  DATE_TRUNC(order_date, MONTH) AS month,
  SAFE_DIVIDE(
    SUM(CASE WHEN pcm_discount_amount_net_eur > 0 THEN total_amount_net_with_discount_eur ELSE 0 END),
    NULLIF(SUM(total_amount_net_with_discount_eur), 0)
  ) AS promo_contribution_pct
FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
WHERE order_date BETWEEN '2026-09-01' AND '2026-09-30'
  AND state = 'CONFIRMED'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------+------------------------+
-- | country              | month | promo_contribution_pct |
-- +----------------------+-------+------------------------+
-- | Argentina            | 2.026 |                 53,75% |
-- | Bolivia              | 2.026 |                 31,48% |
-- | Chile                | 2.026 |                 36,35% |
-- | Ecuador              | 2.026 |                 37,44% |
-- | El Salvador          | 2.026 |                 10,62% |
-- | Guatemala            | 2.026 |                 14,21% |
-- | Honduras             | 2.026 |                 19,19% |
-- | Nicaragua            | 2.026 |                 24,25% |
-- | Panam�               | 2.026 |                 13,08% |
-- | Paraguay             | 2.026 |                 21,21% |
-- | Per�                 | 2.026 |                 37,87% |
-- | Rep�blica Dominicana | 2.026 |                 15,23% |
-- | Uruguay              | 2.026 |                 27,56% |
-- +----------------------+-------+------------------------+
