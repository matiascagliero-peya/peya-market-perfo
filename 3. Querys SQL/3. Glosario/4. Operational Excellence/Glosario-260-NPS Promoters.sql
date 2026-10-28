DECLARE query_name STRING DEFAULT 'Glosario-260-NPS Promoters';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 260
-- Nombre:     NPS Promoters
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-delivery-and-support.automated_tables_reports.npsgroceries_monitor` + `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
-- Tipo:       Dato Directo
-- Fórmula:    COUNT(response_id) con calificación Promotor (9-10)
-- Definición: Cantidad de clientes que calificaron con 9 o 10 puntos en la encuesta (Promotores activos de la marca).
-- ====================================================================================

SELECT
  c.country_name AS country,
  DATE_TRUNC(DATE(n.recorded_at_utc), MONTH) AS month,
  COUNT(CASE WHEN UPPER(n.nps_group) = "PROMOTER" THEN 1 END) AS promoters
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
-- +----------------------+-------+-----------+
-- | country              | month | promoters |
-- +----------------------+-------+-----------+
-- | -                    | 2.026 |        10 |
-- | Argentina            | 2.026 |     3.501 |
-- | Bolivia              | 2.026 |       356 |
-- | Chile                | 2.026 |       350 |
-- | República Dominicana | 2.026 |       233 |
-- | Ecuador              | 2.026 |       172 |
-- | El Salvador          | 2.026 |       139 |
-- | Guatemala            | 2.026 |       206 |
-- | Honduras             | 2.026 |       108 |
-- | Nicaragua            | 2.026 |        64 |
-- | Panamá               | 2.026 |        88 |
-- | Panam�               | 2.026 |        88 |
-- | Paraguay             | 2.026 |       262 |
-- | Perú                 | 2.026 |       546 |
-- | Per�                 | 2.026 |       546 |
-- | Rep�blica Dominicana | 2.026 |       233 |
-- | Uruguay              | 2.026 |       202 |
-- +----------------------+-------+-----------+
