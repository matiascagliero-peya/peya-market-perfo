DECLARE query_name STRING DEFAULT 'Glosario-251-Stacked deliveries %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 251
-- Nombre:     Stacked deliveries %
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-data-origins-pro.cl_hurrier.orders_v2` + `peya-bi-tools-pro.il_core.dim_country`
-- Tipo:       Ratio Calculado
-- Fórmula:    COUNT(DISTINCT entregas apiladas > 0) / Total Deliveries
-- Definición: Porcentaje de entregas logísticas realizadas bajo modalidad apilada sobre el total de despachos completados.
-- ====================================================================================

SELECT
  dc.country_name_en AS country,
  DATE_TRUNC(DATE(o.created_at, o.timezone), MONTH) AS month,
  COUNT(DISTINCT CASE WHEN d.stacked_deliveries > 0 THEN d.id END) AS total_stacked_deliveries,
  COUNT(DISTINCT d.id) AS total_deliveries,
  SAFE_DIVIDE(
    COUNT(DISTINCT CASE WHEN d.stacked_deliveries > 0 THEN d.id END),
    NULLIF(COUNT(DISTINCT d.id), 0)
  ) AS stacked_deliveries_pct
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
-- +----------------------+-------+------------------------+------------------+--------------------------+
-- | country              | month | stacked_deliveries_pct | total_deliveries | total_stacked_deliveries |
-- +----------------------+-------+------------------------+------------------+--------------------------+
-- | Argentina            | 2.026 |                 88,64% |        2.642.805 |                2.342.591 |
-- | Bolivia              | 2.026 |                 80,52% |          144.913 |                  116.687 |
-- | Chile                | 2.026 |                 70,19% |          343.807 |                  241.321 |
-- | República Dominicana | 2.026 |                 82,68% |          173.859 |                  143.738 |
-- | Ecuador              | 2.026 |                 74,61% |           99.014 |                   73.874 |
-- | El Salvador          | 2.026 |                 90,82% |           86.849 |                   78.874 |
-- | Guatemala            | 2.026 |                 88,78% |           96.325 |                   85.520 |
-- | Honduras             | 2.026 |                 90,07% |           51.107 |                   46.030 |
-- | Nicaragua            | 2.026 |                 90,43% |           57.325 |                   51.837 |
-- | Panamá               | 2.026 |                 56,06% |           95.172 |                   53.356 |
-- | Paraguay             | 2.026 |                 87,84% |          135.907 |                  119.384 |
-- | Perú                 | 2.026 |                 74,27% |          278.484 |                  206.831 |
-- | Uruguay              | 2.026 |                 90,42% |          286.709 |                  259.230 |
-- +----------------------+-------+------------------------+------------------+--------------------------+
