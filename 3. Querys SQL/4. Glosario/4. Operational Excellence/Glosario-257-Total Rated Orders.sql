DECLARE query_name STRING DEFAULT 'Glosario-257-Total Rated Orders';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 257
-- Nombre:     Total Rated Orders
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-bi-tools-pro.il_core.fact_orders` + `peya-bi-tools-pro.il_core.fact_partner_survey_reviews` + `peya-bi-tools-pro.il_core.dim_partner`
-- Tipo:       Dato Directo
-- Fórmula:    COUNT(partner_rating) órdenes calificadas
-- Definición: Cantidad total de pedidos evaluados y calificados por los clientes tras la entrega.
-- ====================================================================================

SELECT
  o.country.country_name AS country,
  DATE_TRUNC(DATE(o.registered_date), MONTH) AS month,
  COUNT(r.partner.partner_rating) AS total_rated_orders
FROM `peya-bi-tools-pro.il_core.fact_orders` o
INNER JOIN `peya-bi-tools-pro.il_core.dim_partner` p ON o.restaurant.id = p.partner_id
LEFT JOIN `peya-bi-tools-pro.il_core.fact_partner_survey_reviews` r ON r.order_id = o.order_id
WHERE o.order_status = 'CONFIRMED'
  AND p.is_darkstore = TRUE
  AND DATE(o.registered_date) BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------+--------------------+
-- | country              | month | total_rated_orders |
-- +----------------------+-------+--------------------+
-- | Argentina            | 2.026 |        226.574,00% |
-- | Bolivia              | 2.026 |         11.094,00% |
-- | Chile                | 2.026 |         22.628,00% |
-- | Ecuador              | 2.026 |          8.848,00% |
-- | El Salvador          | 2.026 |          5.564,00% |
-- | Guatemala            | 2.026 |          7.388,00% |
-- | Honduras             | 2.026 |          4.007,00% |
-- | Nicaragua            | 2.026 |          4.267,00% |
-- | Panam�               | 2.026 |          4.918,00% |
-- | Paraguay             | 2.026 |         13.180,00% |
-- | Per�                 | 2.026 |         18.824,00% |
-- | Rep�blica Dominicana | 2.026 |         12.815,00% |
-- | Uruguay              | 2.026 |         18.650,00% |
-- +----------------------+-------+--------------------+
