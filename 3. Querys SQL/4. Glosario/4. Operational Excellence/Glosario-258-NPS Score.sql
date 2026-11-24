DECLARE query_name STRING DEFAULT 'Glosario-258-NPS Score';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 258
-- Nombre:     NPS Score
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-delivery-and-support.automated_tables_reports.npsgroceries_monitor` + `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
-- Tipo:       Dato Directo
-- Fórmula:    (Promoters - Detractors) * 100 / Total Survey Volume
-- Definición: Net Promoter Score de PeYa Market: índice de lealtad y recomendación neta de clientes ((Promotores - Detractores) / Total Encuestas * 100).
-- ====================================================================================

SELECT
  c.country_name AS country,
  DATE_TRUNC(DATE(n.recorded_at_utc), MONTH) AS month,
  COUNT(n.response_id) AS survey_volume,
  COUNT(CASE WHEN UPPER(n.nps_group) = 'PROMOTER' THEN 1 END) AS promoters,
  COUNT(CASE WHEN UPPER(n.nps_group) = 'PASSIVE' THEN 1 END) AS passives,
  COUNT(CASE WHEN UPPER(n.nps_group) = 'DETRACTOR' THEN 1 END) AS detractors,
  SAFE_DIVIDE(
    (COUNT(CASE WHEN UPPER(n.nps_group) = 'PROMOTER' THEN 1 END) - COUNT(CASE WHEN UPPER(n.nps_group) = 'DETRACTOR' THEN 1 END)) * 100,
    NULLIF(COUNT(n.response_id), 0)
  ) AS nps_score
FROM `peya-delivery-and-support.automated_tables_reports.npsgroceries_monitor` n
LEFT JOIN (
  SELECT DISTINCT LOWER(country_code) AS country_code, country_name
  FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
  WHERE state = 'CONFIRMED'
) c ON LOWER(n.countrycode) = c.country_code
WHERE LOWER(n.vertical_qc) = 'dmart'
  AND DATE(n.recorded_at_utc) BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+------------+-------+-----------+----------+-----------+---------------+
-- | country              | detractors | month | nps_score | passives | promoters | survey_volume |
-- +----------------------+------------+-------+-----------+----------+-----------+---------------+
-- | -                    |          4 | 2.026 |     37,50 |        2 |        10 |            16 |
-- | Argentina            |        880 | 2.026 |     49,13 |      954 |     3.501 |         5.335 |
-- | Bolivia              |        108 | 2.026 |     42,61 |      118 |       356 |           582 |
-- | Chile                |        157 | 2.026 |     32,55 |       86 |       350 |           593 |
-- | República Dominicana |         53 | 2.026 |     56,25 |       34 |       233 |           320 |
-- | Ecuador              |         47 | 2.026 |     47,35 |       45 |       172 |           264 |
-- | El Salvador          |         54 | 2.026 |     34,69 |       52 |       139 |           245 |
-- | Guatemala            |         39 | 2.026 |     55,30 |       57 |       206 |           302 |
-- | Honduras             |         26 | 2.026 |     51,57 |       25 |       108 |           159 |
-- | Nicaragua            |         19 | 2.026 |     45,92 |       15 |        64 |            98 |
-- | Panamá               |         45 | 2.026 |     25,44 |       36 |        88 |           169 |
-- | Panam�               |         45 | 2.026 |     25,44 |       36 |        88 |           169 |
-- | Paraguay             |         84 | 2.026 |     42,18 |       76 |       262 |           422 |
-- | Perú                 |        156 | 2.026 |     45,09 |      163 |       546 |           865 |
-- | Per�                 |        156 | 2.026 |     45,09 |      163 |       546 |           865 |
-- | Rep�blica Dominicana |         53 | 2.026 |     56,25 |       34 |       233 |           320 |
-- | Uruguay              |         75 | 2.026 |     35,28 |       83 |       202 |           360 |
-- +----------------------+------------+-------+-----------+----------+-----------+---------------+
