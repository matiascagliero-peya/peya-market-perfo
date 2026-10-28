DECLARE query_name STRING DEFAULT 'Glosario-246-Total Stacked Orders';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 246
-- Nombre:     Total Stacked Orders
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-data-origins-pro.cl_hurrier.orders_v2` + `peya-bi-tools-pro.il_core.dim_country`
-- Tipo:       Dato Directo
-- Fórmula:    COUNT(DISTINCT CASE WHEN stacked_deliveries > 0 THEN id END)
-- Definición: Total de pedidos despachados bajo rutas agrupadas o apiladas (repartidor asignado a 2 o más entregas simultáneas).
-- ====================================================================================

SELECT
  dc.country_name_en AS country,
  DATE_TRUNC(DATE(o.created_at, o.timezone), MONTH) AS month,
  COUNT(DISTINCT CASE WHEN d.stacked_deliveries > 0 THEN d.id END) AS total_stacked_orders
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
-- +----------------------+-------+----------------------+
-- | country              | month | total_stacked_orders |
-- +----------------------+-------+----------------------+
-- | Argentina            | 2.026 |            2.342.591 |
-- | Bolivia              | 2.026 |              116.687 |
-- | Chile                | 2.026 |              241.321 |
-- | República Dominicana | 2.026 |              143.738 |
-- | Ecuador              | 2.026 |               73.874 |
-- | El Salvador          | 2.026 |               78.874 |
-- | Guatemala            | 2.026 |               85.520 |
-- | Honduras             | 2.026 |               46.030 |
-- | Nicaragua            | 2.026 |               51.837 |
-- | Panamá               | 2.026 |               53.356 |
-- | Paraguay             | 2.026 |              119.384 |
-- | Perú                 | 2.026 |              206.831 |
-- | Uruguay              | 2.026 |              259.230 |
-- +----------------------+-------+----------------------+
