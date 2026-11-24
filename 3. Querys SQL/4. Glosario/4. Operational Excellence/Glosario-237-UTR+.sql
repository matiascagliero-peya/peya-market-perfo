DECLARE query_name STRING DEFAULT 'Glosario-237-UTR+';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 237
-- Nombre:     UTR+
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Owner:       Juan Pablo Pinori Diaz (juan.pinori@pedidosya.com)
-- Slack Link:  https://deliveryhero.enterprise.slack.com/archives/D093J9QN9CK
-- Tablas de origen: `peya-delivery-and-support.automated_tables_reports.dmarts_productividad`
-- Tipo:       Ratio Calculado
-- Fórmula:    (Picking units + Receiving units + Ajuste UTR - Received bags) / Picker working hours
-- Definición: Productividad operativa global (Unidades por hora de picker trabajada).
-- ====================================================================================

SELECT
  LOWER(country_name) AS country,
  DATE_TRUNC(date, MONTH) AS month,
  SUM(picking_units) AS picking_units,
  SUM(receiving_units) AS receiving_units,
  SUM(ajuste) AS ajuste_utr,
  SUM(received_bags) AS received_bags,
  SUM(picker_working_hours) AS picker_working_hours,
  SAFE_DIVIDE(
    SUM(picking_units) + SUM(receiving_units) + SUM(ajuste) - SUM(received_bags),
    NULLIF(SUM(picker_working_hours), 0)
  ) AS utr_plus
FROM `peya-delivery-and-support.automated_tables_reports.dmarts_productividad`
WHERE date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+------------+----------+
-- | country              | month      | utr_plus |
-- +----------------------+------------+----------+
-- | Argentina            | 2026-09-01 |    96,59 |
-- | Bolivia              | 2026-09-01 |   102,51 |
-- | Chile                | 2026-09-01 |    83,25 |
-- | Ecuador              | 2026-09-01 |   106,90 |
-- | El Salvador          | 2026-09-01 |    83,27 |
-- | Guatemala            | 2026-09-01 |    76,72 |
-- | Honduras             | 2026-09-01 |        - |
-- | Nicaragua            | 2026-09-01 |    83,47 |
-- | Panam�               | 2026-09-01 |        - |
-- | Paraguay             | 2026-09-01 |    91,62 |
-- | Per�                 | 2026-09-01 |        - |
-- | Rep�blica Dominicana | 2026-09-01 |        - |
-- | Uruguay              | 2026-09-01 |    91,83 |
-- +----------------------+------------+----------+
