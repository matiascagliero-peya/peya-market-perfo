DECLARE query_name STRING DEFAULT 'Glosario-79-Covered MAUs';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 79
-- Nombre:     Covered MAUs
-- Chapter:   Usuarios
-- Query bajada en: 15 - MAUs Coverage
-- Sheets Name: 1. ET - MAUs Coverage (15 - MAUs Coverage)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1MiQ6pB0Oc4TdiCGfXBR50mp-h22nBQt91g_QWOXO67k
-- Tablas de origen: `peya-food-and-groceries.automated_tables_reports.qc_dmart_coverage_city_MAUs` + `peya-bi-tools-pro.il_core.dim_country`
-- Tipo:       Dato Directo (Col 3)
-- Fórmula:    SUM(dm.CUSTOMERS_CUBIERTOS)
-- Definición: Cantidad total de usuarios activos de la plataforma que residen o compran dentro del área de cobertura geográfica (polígonos de darkstores).
-- ====================================================================================

SELECT 
  dc.country_name_en AS country,
  dm.month_date AS month,
  SUM(dm.CUSTOMERS_CUBIERTOS) AS covered_maus
FROM `peya-food-and-groceries.automated_tables_reports.qc_dmart_coverage_city_MAUs` dm
LEFT JOIN `peya-bi-tools-pro.il_core.dim_country` dc
  ON dm.country_id = dc.country_id
WHERE dm.month_date = '2026-09-01'
  AND dc.country_name_en IS NOT NULL
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+--------------+-------+
-- | country              | covered_maus | month |
-- +----------------------+--------------+-------+
-- | Argentina            |    2.828.331 | 2.026 |
-- | Bolivia              |      324.461 | 2.026 |
-- | Chile                |      885.834 | 2.026 |
-- | Costa Rica           |            0 | 2.026 |
-- | República Dominicana |      327.350 | 2.026 |
-- | Ecuador              |      290.904 | 2.026 |
-- | El Salvador          |      176.140 | 2.026 |
-- | Guatemala            |      211.539 | 2.026 |
-- | Honduras             |      195.894 | 2.026 |
-- | Nicaragua            |      172.615 | 2.026 |
-- | Panamá               |      248.557 | 2.026 |
-- | Paraguay             |      164.536 | 2.026 |
-- | Perú                 |      699.707 | 2.026 |
-- | Uruguay              |      263.093 | 2.026 |
-- | Venezuela            |            0 | 2.026 |
-- +----------------------+--------------+-------+
