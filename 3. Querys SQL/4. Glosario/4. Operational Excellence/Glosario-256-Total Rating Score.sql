DECLARE query_name STRING DEFAULT 'Glosario-256-Total Rating Score';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 256
-- Nombre:     Total Rating Score
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-bi-tools-pro.il_core.fact_orders` + `peya-bi-tools-pro.il_core.fact_partner_survey_reviews` + `peya-bi-tools-pro.il_core.dim_partner`
-- Tipo:       Dato Directo
-- Fórmula:    SUM(partner_rating) puntos acumulados
-- Definición: Suma total acumulada de estrellas y puntos de satisfacción recibidos en las valoraciones de tienda.
-- ====================================================================================

SELECT
  o.country.country_name AS country,
  DATE_TRUNC(DATE(o.registered_date), MONTH) AS month,
  SUM(r.partner.partner_rating) AS total_rating_score
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
-- | country              | month | total_rating_score |
-- +----------------------+-------+--------------------+
-- | Argentina            | 2.026 |          1.054.490 |
-- | Bolivia              | 2.026 |             49.393 |
-- | Chile                | 2.026 |            101.959 |
-- | Ecuador              | 2.026 |             40.891 |
-- | El Salvador          | 2.026 |             25.647 |
-- | Guatemala            | 2.026 |             34.780 |
-- | Honduras             | 2.026 |             18.388 |
-- | Nicaragua            | 2.026 |             19.638 |
-- | Panam�               | 2.026 |             21.754 |
-- | Paraguay             | 2.026 |             61.176 |
-- | Per�                 | 2.026 |             87.078 |
-- | Rep�blica Dominicana | 2.026 |             59.011 |
-- | Uruguay              | 2.026 |             85.358 |
-- +----------------------+-------+--------------------+
