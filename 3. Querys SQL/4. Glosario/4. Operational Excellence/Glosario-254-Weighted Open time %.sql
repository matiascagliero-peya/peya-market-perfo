DECLARE query_name STRING DEFAULT 'Glosario-254-Weighted Open time %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 254
-- Nombre:     Weighted Open time %
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-food-and-groceries.automated_tables_reports.wot_hour_by_whs`
-- Tipo:       Ratio Calculado
-- Fórmula:    SUM(disponibilidad_ponderada_hora) / SUM(peso_trafico_hora)
-- Definición: Disponibilidad horaria de tienda ponderada por la demanda: porcentaje de tiempo abierto ajustado por el peso de tráfico de cada hora del día.
-- ====================================================================================

SELECT
  pais AS country,
  DATE_TRUNC(fecha, MONTH) AS month,
  SUM(disponibilidad_ponderada_hora) AS disponibilidad_ponderada_mensual,
  SUM(peso_trafico_hora) AS peso_trafico_mensual,
  SAFE_DIVIDE(
    SUM(disponibilidad_ponderada_hora),
    NULLIF(SUM(peso_trafico_hora), 0)
  ) AS weighted_open_time_monthly
FROM `peya-food-and-groceries.automated_tables_reports.wot_hour_by_whs`
WHERE fecha BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+----------------------------------+-------+----------------------+----------------------------+
-- | country              | disponibilidad_ponderada_mensual | month | peso_trafico_mensual | weighted_open_time_monthly |
-- +----------------------+----------------------------------+-------+----------------------+----------------------------+
-- | Argentina            |                         2.010,49 | 2.026 |             2.021,68 |                       0,99 |
-- | Bolivia              |                           145,04 | 2.026 |               145,68 |                       1,00 |
-- | Chile                |                           737,45 | 2.026 |               806,78 |                       0,91 |
-- | Ecuador              |                           177,21 | 2.026 |               177,63 |                       1,00 |
-- | El Salvador          |                            87,87 | 2.026 |                88,09 |                       1,00 |
-- | Guatemala            |                           147,60 | 2.026 |               147,69 |                       1,00 |
-- | Honduras             |                            59,35 | 2.026 |                59,46 |                       1,00 |
-- | Nicaragua            |                            29,73 | 2.026 |                29,73 |                          1 |
-- | Panam�               |                           145,10 | 2.026 |               145,10 |                          1 |
-- | Paraguay             |                           115,00 | 2.026 |               117,94 |                       0,98 |
-- | Per�                 |                           304,53 | 2.026 |               304,68 |                       1,00 |
-- | Republica Dominicana |                           176,14 | 2.026 |               176,53 |                       1,00 |
-- | Uruguay              |                           202,05 | 2.026 |               218,87 |                       0,92 |
-- +----------------------+----------------------------------+-------+----------------------+----------------------------+
