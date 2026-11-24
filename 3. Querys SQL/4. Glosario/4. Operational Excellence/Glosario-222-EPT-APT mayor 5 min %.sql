DECLARE query_name STRING DEFAULT 'Glosario-222-EPT-APT > 5 min %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 222
-- Nombre:     EPT-APT > 5 min %
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-bi-tools-pro.il_logistics.fact_logistic_orders`
-- Tipo:       Ratio Calculado
-- Fórmula:    COUNT(DISTINCT pedidos con EPT-APT > 5 min) / Total Orders Logistics
-- Definición: Porcentaje de órdenes donde el tiempo estimado de preparación superó por más de 5 minutos la llegada del repartidor (descoordinación tienda-logística).
-- ====================================================================================

SELECT
  country_code AS country,
  DATE_TRUNC(DATE(created_date_local), MONTH) AS month,
  COUNT(DISTINCT CASE WHEN (estimated_prep_time / 60 - timings.assumed_actual_preparation_time / 60) > 5 THEN peya_order_id END) AS ept_apt_over_5_min_orders,
  COUNT(DISTINCT peya_order_id) AS total_orders,
  SAFE_DIVIDE(
    COUNT(DISTINCT CASE WHEN (estimated_prep_time / 60 - timings.assumed_actual_preparation_time / 60) > 5 THEN peya_order_id END),
    NULLIF(COUNT(DISTINCT peya_order_id), 0)
  ) AS ept_apt_over_5_min_pct
FROM `peya-bi-tools-pro.il_logistics.fact_logistic_orders`
WHERE DATE(created_date_local) BETWEEN '2026-09-01' AND '2026-09-30'
  AND order_cancelled != 1
  AND vendor.vertical_type = 'darkstores'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +---------+---------------------------+------------------------+-------+--------------+
-- | country | ept_apt_over_5_min_orders | ept_apt_over_5_min_pct | month | total_orders |
-- +---------+---------------------------+------------------------+-------+--------------+
-- | ar      |                   175.588 |                  6,66% | 2.026 |    2.637.142 |
-- | bo      |                    48.194 |                 33,69% | 2.026 |      143.031 |
-- | cl      |                    21.302 |                  6,24% | 2.026 |      341.588 |
-- | do      |                    10.685 |                  6,22% | 2.026 |      171.687 |
-- | ec      |                     8.785 |                  9,07% | 2.026 |       96.883 |
-- | gt      |                       832 |                  0,87% | 2.026 |       95.251 |
-- | hn      |                     4.776 |                  9,45% | 2.026 |       50.536 |
-- | ni      |                     1.648 |                  2,91% | 2.026 |       56.668 |
-- | pa      |                     4.206 |                  4,52% | 2.026 |       93.030 |
-- | pe      |                     4.388 |                  1,61% | 2.026 |      272.594 |
-- | py      |                    36.719 |                 27,01% | 2.026 |      135.928 |
-- | sv      |                    11.475 |                 13,43% | 2.026 |       85.413 |
-- | uy      |                    33.301 |                 11,79% | 2.026 |      282.486 |
-- +---------+---------------------------+------------------------+-------+--------------+
