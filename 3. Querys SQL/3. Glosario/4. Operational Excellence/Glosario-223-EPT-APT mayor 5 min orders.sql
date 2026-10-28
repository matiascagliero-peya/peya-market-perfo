DECLARE query_name STRING DEFAULT 'Glosario-223-EPT-APT > 5 min orders';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 223
-- Nombre:     EPT-APT > 5 min orders
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-bi-tools-pro.il_logistics.fact_logistic_orders`
-- Tipo:       Dato Directo
-- Fórmula:    COUNT(DISTINCT CASE WHEN (ept - apt) > 5 THEN peya_order_id END)
-- Definición: Total de órdenes con desfasaje crítico superior a 5 minutos entre el tiempo de preparación de tienda y el arribo del rider.
-- ====================================================================================

SELECT
  country_code AS country,
  DATE_TRUNC(DATE(created_date_local), MONTH) AS month,
  COUNT(DISTINCT CASE WHEN (estimated_prep_time / 60 - timings.assumed_actual_preparation_time / 60) > 5 THEN peya_order_id END) AS ept_apt_over_5_min_orders
FROM `peya-bi-tools-pro.il_logistics.fact_logistic_orders`
WHERE DATE(created_date_local) BETWEEN '2026-09-01' AND '2026-09-30'
  AND order_cancelled != 1
  AND vendor.vertical_type = 'darkstores'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +---------+---------------------------+-------+
-- | country | ept_apt_over_5_min_orders | month |
-- +---------+---------------------------+-------+
-- | ar      |                   175.588 | 2.026 |
-- | bo      |                    48.194 | 2.026 |
-- | cl      |                    21.302 | 2.026 |
-- | do      |                    10.685 | 2.026 |
-- | ec      |                     8.785 | 2.026 |
-- | gt      |                       832 | 2.026 |
-- | hn      |                     4.776 | 2.026 |
-- | ni      |                     1.648 | 2.026 |
-- | pa      |                     4.206 | 2.026 |
-- | pe      |                     4.388 | 2.026 |
-- | py      |                    36.719 | 2.026 |
-- | sv      |                    11.475 | 2.026 |
-- | uy      |                    33.301 | 2.026 |
-- +---------+---------------------------+-------+
