DECLARE query_name STRING DEFAULT 'Glosario-80-Covered MAUs penetration %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 80
-- Nombre:     Covered MAUs penetration %
-- Chapter:   Usuarios
-- Query bajada en: 15 - MAUs Coverage / Ratios Relacionados
-- Sheets Name: 1. ET - MAUs Coverage (15 - MAUs Coverage)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1MiQ6pB0Oc4TdiCGfXBR50mp-h22nBQt91g_QWOXO67k
-- Tablas de origen: `peya-food-and-groceries.automated_tables_reports.qc_dmart_coverage_city_MAUs` + `peya-bi-tools-pro.il_core.dim_country` + `peya-food-and-groceries.automated_tables_reports.qc_coverage_city_MAUs` + `peya-food-and-groceries.automated_tables_reports.qc_performance_order_overall`
-- Tipo:       Ratio Calculado
-- Fórmula:    Dmart MAUs / Covered MAUs = Active Dmart Users / Dmart MAUs Cubiertos
-- Definición: Tasa de penetración de clientes activos de PeYa Market sobre el universo total de usuarios cubiertos por los polígonos de las tiendas.
-- ====================================================================================

WITH coverage AS (
  SELECT
    cm.month_date,
    cm.country_id,
    dc.country_name_en AS country_name,
    SUM(dm.CUSTOMERS_CUBIERTOS) AS dmart_maus_cubiertos
  FROM `peya-food-and-groceries.automated_tables_reports.qc_coverage_city_MAUs` cm
  LEFT JOIN `peya-food-and-groceries.automated_tables_reports.qc_dmart_coverage_city_MAUs` dm
    ON cm.country_id = dm.country_id 
    AND cm.month_date = dm.month_date 
    AND cm.city_name_lz = dm.city_name_lz
  LEFT JOIN `peya-bi-tools-pro.il_core.dim_country` dc
    ON cm.country_id = dc.country_id
  WHERE cm.month_date = '2026-09-01'
  GROUP BY 1, 2, 3
),
penetration AS (
  SELECT 
    p.month_date,
    dc.country_id,
    COUNT(DISTINCT IF(p.category_partner = "D-Mart", p.customer_id, NULL)) AS active_dmart_users
  FROM `peya-food-and-groceries.automated_tables_reports.qc_performance_order_overall` p
  LEFT JOIN `peya-bi-tools-pro.il_core.dim_country` dc
    ON p.country_code = dc.country_code 
  WHERE p.order_status = "CONFIRMED"
    AND p.month_date = '2026-09-01'
  GROUP BY 1, 2
)
SELECT 
  c.country_name AS country,
  c.month_date AS month,
  p.active_dmart_users,
  c.dmart_maus_cubiertos AS covered_maus,
  SAFE_DIVIDE(p.active_dmart_users, c.dmart_maus_cubiertos) AS covered_maus_penetration_pct
FROM coverage c
LEFT JOIN penetration p
  ON c.month_date = p.month_date 
  AND c.country_id = p.country_id
WHERE c.country_name IS NOT NULL
  AND c.dmart_maus_cubiertos > 0
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +--------------------+----------------------+--------------+------------------------------+-------+
-- | active_dmart_users | country              | covered_maus | covered_maus_penetration_pct | month |
-- +--------------------+----------------------+--------------+------------------------------+-------+
-- |            987.633 | Argentina            |    2.828.331 |                       34,92% | 2.026 |
-- |             59.007 | Bolivia              |      324.461 |                       18,19% | 2.026 |
-- |            150.089 | Chile                |      885.834 |                       16,94% | 2.026 |
-- |             68.786 | República Dominicana |      327.350 |                       21,01% | 2.026 |
-- |             46.402 | Ecuador              |      290.904 |                       15,95% | 2.026 |
-- |             34.217 | El Salvador          |      176.140 |                       19,43% | 2.026 |
-- |             38.359 | Guatemala            |      211.539 |                       18,13% | 2.026 |
-- |             25.160 | Honduras             |      195.894 |                       12,84% | 2.026 |
-- |             23.238 | Nicaragua            |      172.615 |                       13,46% | 2.026 |
-- |             38.603 | Panamá               |      248.557 |                       15,53% | 2.026 |
-- |             49.905 | Paraguay             |      164.536 |                       30,33% | 2.026 |
-- |            111.780 | Perú                 |      699.707 |                       15,98% | 2.026 |
-- |             92.571 | Uruguay              |      263.093 |                       35,19% | 2.026 |
-- +--------------------+----------------------+--------------+------------------------------+-------+
