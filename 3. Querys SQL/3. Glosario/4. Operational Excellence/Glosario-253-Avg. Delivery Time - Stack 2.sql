DECLARE query_name STRING DEFAULT 'Glosario-253-Avg. Delivery Time - Stack 2';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 253
-- Nombre:     Avg. Delivery Time - Stack 2
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-data-origins-pro.cl_hurrier.orders_v2` + `peya-bi-tools-pro.il_core.dim_country`
-- Tipo:       Ratio Calculado
-- Fórmula:    AVG(actual_delivery_time / 60) para entregas en stack 2
-- Definición: Tiempo promedio de entrega en minutos para el segundo cliente entregado dentro de una ruta de reparto apilada.
-- ====================================================================================

SELECT
  dc.country_name_en AS country,
  DATE_TRUNC(DATE(o.created_at, o.timezone), MONTH) AS month,
  AVG(CASE WHEN d.stacked_deliveries_rank = 2 THEN d.timings.actual_delivery_time / 60 END) AS avg_delivery_time_stack_2
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
-- | avg_delivery_time_stack_2 | country              | month |
-- +---------------------------+----------------------+-------+
-- |                     29,91 | Argentina            | 2.026 |
-- |                     35,32 | Bolivia              | 2.026 |
-- |                     34,57 | Chile                | 2.026 |
-- |                     28,12 | República Dominicana | 2.026 |
-- |                     33,72 | Ecuador              | 2.026 |
-- |                     34,96 | El Salvador          | 2.026 |
-- |                     37,80 | Guatemala            | 2.026 |
-- |                     34,79 | Honduras             | 2.026 |
-- |                     38,71 | Nicaragua            | 2.026 |
-- |                     30,08 | Panamá               | 2.026 |
-- |                     32,38 | Paraguay             | 2.026 |
-- |                     29,27 | Perú                 | 2.026 |
-- |                     32,21 | Uruguay              | 2.026 |
-- +---------------------------+----------------------+-------+
