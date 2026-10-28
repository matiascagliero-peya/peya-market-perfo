DECLARE query_name STRING DEFAULT 'Glosario-255-Rating';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 255
-- Nombre:     Rating
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-bi-tools-pro.il_core.fact_orders` + `peya-bi-tools-pro.il_core.fact_partner_survey_reviews` + `peya-bi-tools-pro.il_core.dim_partner`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(partner_rating) / COUNT(partner_rating)
-- Definición: Puntuación promedio de satisfacción otorgada por los clientes hacia la tienda en la aplicación (escala de 1 a 5 estrellas).
-- ====================================================================================

SELECT
  o.country.country_name AS country,
  DATE_TRUNC(DATE(o.registered_date), MONTH) AS month,
  COUNT(DISTINCT o.order_id) AS total_orders,
  SUM(r.partner.partner_rating) AS total_rating_score,
  COUNT(r.partner.partner_rating) AS total_rated_orders,
  SAFE_DIVIDE(SUM(r.partner.partner_rating), NULLIF(COUNT(r.partner.partner_rating), 0)) AS rating
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
-- +----------------------+-------+--------+--------------+--------------------+--------------------+
-- | country              | month | rating | total_orders | total_rated_orders | total_rating_score |
-- +----------------------+-------+--------+--------------+--------------------+--------------------+
-- | Argentina            | 2.026 |   4,65 |    2.652.678 |        226.574,00% |          1.054.490 |
-- | Bolivia              | 2.026 |   4,45 |      142.934 |         11.094,00% |             49.393 |
-- | Chile                | 2.026 |   4,51 |      342.270 |         22.628,00% |            101.959 |
-- | Ecuador              | 2.026 |   4,62 |       97.415 |          8.848,00% |             40.891 |
-- | El Salvador          | 2.026 |   4,61 |       86.285 |          5.564,00% |             25.647 |
-- | Guatemala            | 2.026 |   4,71 |       95.705 |          7.388,00% |             34.780 |
-- | Honduras             | 2.026 |   4,59 |       50.718 |          4.007,00% |             18.388 |
-- | Nicaragua            | 2.026 |   4,60 |       56.437 |          4.267,00% |             19.638 |
-- | Panam�               | 2.026 |   4,42 |       92.999 |          4.918,00% |             21.754 |
-- | Paraguay             | 2.026 |   4,64 |      135.799 |         13.180,00% |             61.176 |
-- | Per�                 | 2.026 |   4,63 |      273.381 |         18.824,00% |             87.078 |
-- | Rep�blica Dominicana | 2.026 |   4,60 |      171.348 |         12.815,00% |             59.011 |
-- | Uruguay              | 2.026 |   4,58 |      287.095 |         18.650,00% |             85.358 |
-- +----------------------+-------+--------+--------------+--------------------+--------------------+
