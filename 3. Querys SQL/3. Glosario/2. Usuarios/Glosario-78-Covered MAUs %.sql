DECLARE query_name STRING DEFAULT 'Glosario-78-Covered MAUs %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 78
-- Nombre:     Covered MAUs %
-- Chapter:   Usuarios
-- Query bajada en: 15 - MAUs Coverage
-- Sheets Name: 1. ET - MAUs Coverage (15 - MAUs Coverage)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1MiQ6pB0Oc4TdiCGfXBR50mp-h22nBQt91g_QWOXO67k
-- Tablas de origen: `peya-food-and-groceries.automated_tables_reports.qc_coverage_city_MAUs` + `qc_dmart_coverage_city_MAUs` + `peya-bi-tools-pro.il_core.dim_country`
-- Tipo:       Ratio Calculado
-- Fórmula:    Covered MAUs / Platform MAUs Coverage = SUM(dm.CUSTOMERS_CUBIERTOS) / SUM(cm.MAUs)
-- Definición: Porcentaje de usuarios de la plataforma que se encuentran cubiertos dentro del polígono de entrega de las tiendas PeYa Market.
-- ====================================================================================

WITH coverage AS (
  SELECT
    cm.month_date,
    dc.country_name_en AS country_name,
    SUM(cm.MAUs) AS platform_maus_coverage,
    SUM(dm.CUSTOMERS_CUBIERTOS) AS dmart_maus_cubiertos
  FROM `peya-food-and-groceries.automated_tables_reports.qc_coverage_city_MAUs` cm
  LEFT JOIN `peya-food-and-groceries.automated_tables_reports.qc_dmart_coverage_city_MAUs` dm
    ON cm.country_id = dm.country_id 
    AND cm.month_date = dm.month_date 
    AND cm.city_name_lz = dm.city_name_lz
  LEFT JOIN `peya-bi-tools-pro.il_core.dim_country` dc
    ON cm.country_id = dc.country_id
  WHERE cm.month_date = '2026-09-01'
  GROUP BY 1, 2
)
SELECT 
  country_name AS country,
  month_date AS month,
  dmart_maus_cubiertos AS covered_maus,
  platform_maus_coverage,
  SAFE_DIVIDE(dmart_maus_cubiertos, platform_maus_coverage) AS covered_maus_pct
FROM coverage
WHERE country_name IS NOT NULL
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+--------------+------------------+-------+------------------------+
-- | country              | covered_maus | covered_maus_pct | month | platform_maus_coverage |
-- +----------------------+--------------+------------------+-------+------------------------+
-- | Argentina            |    2.828.331 |           83,96% | 2.026 |              3.368.567 |
-- | Bolivia              |      324.461 |           81,30% | 2.026 |                399.103 |
-- | Chile                |      885.834 |           79,82% | 2.026 |              1.109.793 |
-- | Costa Rica           |            0 |            0,00% | 2.026 |                102.902 |
-- | República Dominicana |      327.350 |           77,35% | 2.026 |                423.200 |
-- | Ecuador              |      290.904 |           63,05% | 2.026 |                461.372 |
-- | El Salvador          |      176.140 |           49,61% | 2.026 |                355.026 |
-- | Guatemala            |      211.539 |           53,16% | 2.026 |                397.953 |
-- | Honduras             |      195.894 |           72,36% | 2.026 |                270.703 |
-- | Nicaragua            |      172.615 |           82,52% | 2.026 |                209.182 |
-- | Panamá               |      248.557 |           68,40% | 2.026 |                363.383 |
-- | Paraguay             |      164.536 |           71,52% | 2.026 |                230.052 |
-- | Perú                 |      699.707 |           80,61% | 2.026 |                868.005 |
-- | Uruguay              |      263.093 |           81,33% | 2.026 |                323.503 |
-- | Venezuela            |            0 |            0,00% | 2.026 |                 86.163 |
-- +----------------------+--------------+------------------+-------+------------------------+
