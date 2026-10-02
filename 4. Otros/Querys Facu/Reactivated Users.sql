DECLARE query_name STRING DEFAULT 'Reactivated Users.sql';

-- ====================================================================================
-- PROPÓSITO: Conteo de Usuarios Reactivados (Reactivated Users) de D-Mart
--            por PAÍS y total regional LATAM.
--
-- DERIVADO DE: '1. Dmart Users Type (active users) - Base.sql'
-- FUENTE: `peya-food-and-groceries.automated_tables_reports.latam_dmart_growth_tracker`
-- DEFINICIÓN:
--   • Reactivated: Usuarios que volvieron a comprar en D-Mart tras un período de inactividad
--                  (clasificación oficial de Growth Tracker).
--   • Total Active Users: Total de usuarios compradores en el mes (excluye 'Churned').
--   • Reactivated Share %: Porcentaje de usuarios reactivados sobre el total activo mensual.
-- ====================================================================================

-- Rango de fechas: desde 2025 hasta la fecha actual
DECLARE inicio DATE DEFAULT DATE '2025-01-01';
DECLARE fin    DATE DEFAULT CURRENT_DATE();

WITH
-- 1. Base mensual a nivel usuario desde Growth Tracker
growth_base AS (
  SELECT
    DATE_TRUNC(DATE(gt.month), MONTH) AS month,
    CASE 
      WHEN gt.country_name IN ('República Dominicana', 'Republic Dominican', 'Dominican Republic') THEN 'Republica Dominicana'
      ELSE gt.country_name 
    END AS pais,
    gt.customer_id,
    gt.dmart_growth_status_fixed
  FROM `peya-food-and-groceries.automated_tables_reports.latam_dmart_growth_tracker` gt
  WHERE DATE(gt.month) >= inicio
    AND DATE(gt.month) <= fin
    AND gt.dmart_growth_status_fixed <> 'Churned'
),

-- 2. Agregación mensual por País
reactivated_by_country AS (
  SELECT
    month,
    pais,
    COUNT(DISTINCT CASE WHEN dmart_growth_status_fixed = 'Reactivated' THEN customer_id END) AS reactivated_users,
    COUNT(DISTINCT customer_id) AS total_active_users
  FROM growth_base
  GROUP BY 1, 2
),

-- 3. Consolidado regional para toda la entidad 'LATAM' (deduplicando usuarios entre países)
reactivated_latam AS (
  SELECT
    month,
    'LATAM' AS pais,
    COUNT(DISTINCT CASE WHEN dmart_growth_status_fixed = 'Reactivated' THEN customer_id END) AS reactivated_users,
    COUNT(DISTINCT customer_id) AS total_active_users
  FROM growth_base
  GROUP BY 1, 2
),

-- 4. Unión de países individuales + consolidado LATAM
combined AS (
  SELECT * FROM reactivated_by_country
  UNION ALL
  SELECT * FROM reactivated_latam
)

-- Consulta final con volúmenes y porcentaje de reactivación
SELECT
  month,
  pais,

  -- Conteo de usuarios reactivados
  reactivated_users,

  -- Base total de usuarios activos en el mes
  total_active_users,

  -- Participación de usuarios reactivados sobre el total activo
  ROUND(
    SAFE_DIVIDE(reactivated_users, total_active_users) * 100, 
    2
  ) AS reactivated_share_pct

FROM combined
ORDER BY 
  month DESC, 
  (CASE WHEN pais = 'LATAM' THEN 0 ELSE 1 END), 
  pais ASC;
