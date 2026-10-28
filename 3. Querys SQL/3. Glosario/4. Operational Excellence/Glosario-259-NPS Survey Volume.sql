DECLARE query_name STRING DEFAULT 'Glosario-259-NPS Survey Volume';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 259
-- Nombre:     NPS Survey Volume
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-delivery-and-support.automated_tables_reports.npsgroceries_monitor` + `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
-- Tipo:       Dato Directo
-- Fórmula:    COUNT(response_id) encuestas respondidas
-- Definición: Cantidad total de encuestas de satisfacción NPS respondidas por los usuarios durante el mes.
-- ====================================================================================

SELECT
  c.country_name AS country,
  DATE_TRUNC(DATE(n.recorded_at_utc), MONTH) AS month,
  COUNT(n.response_id) AS survey_volume
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
-- +----------------------+-------+---------------+
-- | country              | month | survey_volume |
-- +----------------------+-------+---------------+
-- | -                    | 2.026 |            16 |
-- | Argentina            | 2.026 |         5.335 |
-- | Bolivia              | 2.026 |           582 |
-- | Chile                | 2.026 |           593 |
-- | República Dominicana | 2.026 |           320 |
-- | Ecuador              | 2.026 |           264 |
-- | El Salvador          | 2.026 |           245 |
-- | Guatemala            | 2.026 |           302 |
-- | Honduras             | 2.026 |           159 |
-- | Nicaragua            | 2.026 |            98 |
-- | Panamá               | 2.026 |           169 |
-- | Panam�               | 2.026 |           169 |
-- | Paraguay             | 2.026 |           422 |
-- | Perú                 | 2.026 |           865 |
-- | Per�                 | 2.026 |           865 |
-- | Rep�blica Dominicana | 2.026 |           320 |
-- | Uruguay              | 2.026 |           360 |
-- +----------------------+-------+---------------+
