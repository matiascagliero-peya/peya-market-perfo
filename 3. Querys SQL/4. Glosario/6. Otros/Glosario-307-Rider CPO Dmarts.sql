DECLARE query_name STRING DEFAULT 'Glosario-307-Rider CPO Dmarts';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 307
-- Nombre:     Rider CPO Dmarts
-- Chapter:   Otros
-- Query bajada en: 0 - Orders
-- Sheets Name: 1. TD - OKRs Mensual (0 - Orders)
-- Sheets Link: https://docs.google.com/spreadsheets/d/13yTO_kFzIvISmbSz6p93BFUub1HODpuiGhB3yElZ2fw
-- Tablas de origen: `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` + `peya-datamarts-pro.dm_order_profitability.fact_order_profitability` + `peya-bi-tools-pro.il_core.dim_country`
-- Tipo:       Dato / Ratio Calculado
-- Fórmula:    SUM(rider_cost_eur) / Confirmed Orders OD Dmarts
-- Definición: Costo promedio de entrega por pedido (Cost Per Order) abonado a repartidores en órdenes de PeYa Market.
-- ====================================================================================

SELECT
  dc.country_name_en AS country,
  DATE_TRUNC(registered_date, MONTH) AS month,
  SUM(rider_cost.rider_cost / monthly_rate_eu) AS total_rider_cost_eur,
  COUNT(DISTINCT CASE WHEN order_status = 'CONFIRMED' THEN order_id END) AS confirmed_orders,
  SAFE_DIVIDE(
    SUM(rider_cost.rider_cost / monthly_rate_eu),
    NULLIF(COUNT(DISTINCT CASE WHEN order_status = 'CONFIRMED' THEN order_id END), 0)
  ) AS rider_cpo_dmarts_eur
FROM `peya-datamarts-pro.dm_order_profitability.fact_order_profitability` fop
LEFT JOIN `peya-bi-tools-pro.il_core.dim_country` dc ON fop.country_id = dc.country_id
WHERE partner.vertical_group = 'D-Mart'
  AND delivery.delivery_type = 'OD'
  AND registered_date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +------------------+----------------------+-------+----------------------+----------------------+
-- | confirmed_orders | country              | month | rider_cpo_dmarts_eur | total_rider_cost_eur |
-- +------------------+----------------------+-------+----------------------+----------------------+
-- |        2.634.123 | Argentina            | 2.026 |              -1,12 € |      -2.959.539,71 € |
-- |          142.853 | Bolivia              | 2.026 |              -0,86 € |        -123.248,38 € |
-- |          341.033 | Chile                | 2.026 |              -2,02 € |        -689.128,80 € |
-- |          171.346 | República Dominicana | 2.026 |              -1,29 € |        -221.398,17 € |
-- |           96.673 | Ecuador              | 2.026 |              -1,42 € |        -137.461,99 € |
-- |           85.292 | El Salvador          | 2.026 |              -1,32 € |        -112.701,30 € |
-- |           95.056 | Guatemala            | 2.026 |              -1,84 € |        -174.564,30 € |
-- |           50.431 | Honduras             | 2.026 |              -1,12 € |         -56.464,74 € |
-- |           56.437 | Nicaragua            | 2.026 |              -1,15 € |         -65.143,17 € |
-- |           92.943 | Panamá               | 2.026 |              -2,01 € |        -186.884,36 € |
-- |          135.799 | Paraguay             | 2.026 |              -1,12 € |        -151.648,67 € |
-- |          272.263 | Perú                 | 2.026 |              -1,42 € |        -385.955,36 € |
-- |          282.202 | Uruguay              | 2.026 |              -1,81 € |        -510.723,33 € |
-- +------------------+----------------------+-------+----------------------+----------------------+
