DECLARE query_name STRING DEFAULT 'Glosario-261-NPS Passives';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 261
-- Nombre:     NPS Passives
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-delivery-and-support.automated_tables_reports.npsgroceries_monitor` + `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
-- Tipo:       Dato Directo
-- Fórmula:    COUNT(response_id) con calificación Pasivo (7-8)
-- Definición: Cantidad de clientes que calificaron con 7 u 8 puntos en la encuesta (Clientes neutrales o pasivos).
-- ====================================================================================

SELECT
  c.country_name AS country,
  DATE_TRUNC(DATE(n.recorded_at_utc), MONTH) AS month,
  COUNT(CASE WHEN UPPER(n.nps_group) = "PASSIVE" THEN 1 END) AS passives
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
-- +----------------------+-------+----------+
-- | country              | month | passives |
-- +----------------------+-------+----------+
-- | -                    | 2.026 |        2 |
-- | Argentina            | 2.026 |      954 |
-- | Bolivia              | 2.026 |      118 |
-- | Chile                | 2.026 |       86 |
-- | República Dominicana | 2.026 |       34 |
-- | Ecuador              | 2.026 |       45 |
-- | El Salvador          | 2.026 |       52 |
-- | Guatemala            | 2.026 |       57 |
-- | Honduras             | 2.026 |       25 |
-- | Nicaragua            | 2.026 |       15 |
-- | Panamá               | 2.026 |       36 |
-- | Panam�               | 2.026 |       36 |
-- | Paraguay             | 2.026 |       76 |
-- | Perú                 | 2.026 |      163 |
-- | Per�                 | 2.026 |      163 |
-- | Rep�blica Dominicana | 2.026 |       34 |
-- | Uruguay              | 2.026 |       83 |
-- +----------------------+-------+----------+
