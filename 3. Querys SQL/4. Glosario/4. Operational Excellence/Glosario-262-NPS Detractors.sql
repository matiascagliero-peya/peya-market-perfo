DECLARE query_name STRING DEFAULT 'Glosario-262-NPS Detractors';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 262
-- Nombre:     NPS Detractors
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-delivery-and-support.automated_tables_reports.npsgroceries_monitor` + `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
-- Tipo:       Dato Directo
-- Fórmula:    COUNT(response_id) con calificación Detractor (1-6)
-- Definición: Cantidad de clientes que calificaron con 6 puntos o menos en la encuesta (Clientes insatisfechos o detractores).
-- ====================================================================================

SELECT
  c.country_name AS country,
  DATE_TRUNC(DATE(n.recorded_at_utc), MONTH) AS month,
  COUNT(CASE WHEN UPPER(n.nps_group) = "DETRACTOR" THEN 1 END) AS detractors
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
-- +----------------------+------------+-------+
-- | country              | detractors | month |
-- +----------------------+------------+-------+
-- | -                    |          4 | 2.026 |
-- | Argentina            |        880 | 2.026 |
-- | Bolivia              |        108 | 2.026 |
-- | Chile                |        157 | 2.026 |
-- | República Dominicana |         53 | 2.026 |
-- | Ecuador              |         47 | 2.026 |
-- | El Salvador          |         54 | 2.026 |
-- | Guatemala            |         39 | 2.026 |
-- | Honduras             |         26 | 2.026 |
-- | Nicaragua            |         19 | 2.026 |
-- | Panamá               |         45 | 2.026 |
-- | Panam�               |         45 | 2.026 |
-- | Paraguay             |         84 | 2.026 |
-- | Perú                 |        156 | 2.026 |
-- | Per�                 |        156 | 2.026 |
-- | Rep�blica Dominicana |         53 | 2.026 |
-- | Uruguay              |         75 | 2.026 |
-- +----------------------+------------+-------+
