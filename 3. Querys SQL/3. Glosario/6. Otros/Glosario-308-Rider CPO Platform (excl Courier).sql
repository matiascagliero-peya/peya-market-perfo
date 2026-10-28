DECLARE query_name STRING DEFAULT 'Glosario-308-Rider CPO Platform (excl Courier)';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 308
-- Nombre:     Rider CPO Platform (excl Courier)
-- Chapter:   Otros
-- Query bajada en: 0 - Orders
-- Sheets Name: 1. TD - OKRs Mensual (0 - Orders)
-- Sheets Link: https://docs.google.com/spreadsheets/d/13yTO_kFzIvISmbSz6p93BFUub1HODpuiGhB3yElZ2fw
-- Tablas de origen: `peya-bi-tools-pro.il_core.fact_orders` + `peya-bi-tools-pro.il_core.dim_partner` + `peya-datamarts-pro.dm_order_profitability.fact_order_profitability` + `peya-bi-tools-pro.il_core.dim_country`
-- Tipo:       Dato / Ratio Calculado
-- Fórmula:    SUM(rider_cost_eur) / Confirmed Orders OD Platform
-- Definición: Costo promedio de entrega por pedido de repartidores en toda la plataforma PedidosYa (excluyendo envíos de mensajería).
-- ====================================================================================

SELECT
  dc.country_name_en AS country,
  DATE_TRUNC(registered_date, MONTH) AS month,
  SUM(rider_cost.rider_cost / monthly_rate_eu) AS total_rider_cost_eur,
  COUNT(DISTINCT CASE WHEN order_status = 'CONFIRMED' THEN order_id END) AS confirmed_orders,
  SAFE_DIVIDE(
    SUM(rider_cost.rider_cost / monthly_rate_eu),
    NULLIF(COUNT(DISTINCT CASE WHEN order_status = 'CONFIRMED' THEN order_id END), 0)
  ) AS rider_cpo_platform_eur
FROM `peya-datamarts-pro.dm_order_profitability.fact_order_profitability` fop
LEFT JOIN `peya-bi-tools-pro.il_core.dim_country` dc ON fop.country_id = dc.country_id
WHERE partner.vertical_group NOT IN ('Courier Business', 'Courier', 'D-Mart')
  AND delivery.delivery_type = 'OD'
  AND registered_date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +------------------+----------------------+-------+------------------------+----------------------+
-- | confirmed_orders | country              | month | rider_cpo_platform_eur | total_rider_cost_eur |
-- +------------------+----------------------+-------+------------------------+----------------------+
-- |       10.879.193 | Argentina            | 2.026 |                -1,51 € |     -16.390.275,11 € |
-- |        1.372.641 | Bolivia              | 2.026 |                -0,92 € |      -1.261.543,80 € |
-- |        2.916.492 | Chile                | 2.026 |                -2,10 € |      -6.114.351,42 € |
-- |          258.683 | Costa Rica           | 2.026 |                -2,77 € |        -717.259,47 € |
-- |        1.742.148 | República Dominicana | 2.026 |                -1,46 € |      -2.538.610,05 € |
-- |        1.463.849 | Ecuador              | 2.026 |                -1,45 € |      -2.119.614,73 € |
-- |        1.396.627 | El Salvador          | 2.026 |                -1,62 € |      -2.261.770,55 € |
-- |        1.286.268 | Guatemala            | 2.026 |                -1,97 € |      -2.531.834,10 € |
-- |        1.208.648 | Honduras             | 2.026 |                -1,43 € |      -1.728.142,46 € |
-- |          875.649 | Nicaragua            | 2.026 |                -1,21 € |      -1.062.066,91 € |
-- |        1.367.817 | Panamá               | 2.026 |                -2,07 € |      -2.827.294,28 € |
-- |          874.616 | Paraguay             | 2.026 |                -1,50 € |      -1.312.527,58 € |
-- |        2.763.973 | Perú                 | 2.026 |                -1,54 € |      -4.245.849,01 € |
-- |        1.296.298 | Uruguay              | 2.026 |                -2,04 € |      -2.641.187,00 € |
-- |          223.900 | Venezuela            | 2.026 |                -1,13 € |        -253.932,25 € |
-- +------------------+----------------------+-------+------------------------+----------------------+
