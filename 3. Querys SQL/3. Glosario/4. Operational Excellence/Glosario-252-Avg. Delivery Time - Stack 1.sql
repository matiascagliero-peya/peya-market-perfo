DECLARE query_name STRING DEFAULT 'Glosario-252-Avg. Delivery Time - Stack 1';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 252
-- Nombre:     Avg. Delivery Time - Stack 1
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-data-origins-pro.cl_hurrier.orders_v2` + `peya-bi-tools-pro.il_core.dim_country`
-- Tipo:       Ratio Calculado
-- Fórmula:    AVG(actual_delivery_time / 60) para entregas en stack 1
-- Definición: Tiempo promedio de entrega en minutos para el primer cliente entregado dentro de una ruta de reparto apilada.
-- ====================================================================================

SELECT
  dc.country_name_en AS country,
  DATE_TRUNC(DATE(o.created_at, o.timezone), MONTH) AS month,
  AVG(CASE WHEN d.stacked_deliveries_rank = 1 THEN d.timings.actual_delivery_time / 60 END) AS avg_delivery_time_stack_1
FROM `peya-data-origins-pro.cl_hurrier.orders_v2` o
INNER JOIN UNNEST(o.rider.deliveries) d
LEFT JOIN `peya-bi-tools-pro.il_core.dim_country` dc ON UPPER(o.rider.country_code) = UPPER(dc.country_code)
WHERE o.rider.vendor.vertical_type = 'darkstores'
  AND d.delivery_status = 'completed'
  AND o.is_preorder IS FALSE
  AND DATE(o.created_at, o.timezone) BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +---------------------------+----------------------+-------+
-- | avg_delivery_time_stack_1 | country              | month |
-- +---------------------------+----------------------+-------+
-- |                     22,28 | Argentina            | 2.026 |
-- |                     24,57 | Bolivia              | 2.026 |
-- |                     24,89 | Chile                | 2.026 |
-- |                     18,96 | República Dominicana | 2.026 |
-- |                     22,38 | Ecuador              | 2.026 |
-- |                     24,35 | El Salvador          | 2.026 |
-- |                     27,21 | Guatemala            | 2.026 |
-- |                     22,94 | Honduras             | 2.026 |
-- |                     24,47 | Nicaragua            | 2.026 |
-- |                     21,84 | Panamá               | 2.026 |
-- |                     23,12 | Paraguay             | 2.026 |
-- |                     19,35 | Perú                 | 2.026 |
-- |                     25,61 | Uruguay              | 2.026 |
-- +---------------------------+----------------------+-------+
