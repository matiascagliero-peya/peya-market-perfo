DECLARE query_name STRING DEFAULT '2. Users Type Count - Base - Performance (Metrics Summary)';

-- Sheets Name: 2. Metrics Summary - Base - Performance
-- Sheets Link: https://docs.google.com/spreadsheets/d/1X0bnsCoDszeSlq5TT1uw20GWtcfu1iBpshXXI1QIv7M/edit?gid=1946621285#gid=1946621285
-- Sheets Page: 2. ET - User Metrics L1
-- Relacionado con: 1. ET - Users Type Count (4 - Users) y 1. ET - Users details (24 - Users details)

-- ==============================================================================
-- TABLA: Frank - User Metrics L1 (Users & Tenures a Nivel Level 1)
-- ==============================================================================
-- Origen: 
--   - `peya-food-and-groceries.automated_tables_reports.frank_user_type_monthly` (Motor L1 y L2)
-- Destino / Uso: 
--   - Google Sheets 'Update - OKRs Monthly 26 - Peya Market' (Hoja '4 - Users')
-- Grain: (month, country, business, user_type_l1)
-- Métricas: users (col 4), ternure (col 5), adoption_tenure (col 6)
-- ==============================================================================

DECLARE start_date DATE DEFAULT '2025-01-01';

WITH

-- 1. Base a nivel usuario con tenures y tipos L1 desde la Tabla 2
user_base AS (
  SELECT
    Mes                                                        AS month,
    country,
    customer_id,

    -- D-Marts (Darkstores)
    CASE 
      WHEN Market_Actual_Type = 'Re-Order'     THEN 'Reorder'
      WHEN Market_Actual_Type = 'Reactivation' THEN 'Re-Activation'
      ELSE Market_Actual_Type
    END                                                        AS market_l1,
    Market_Actual_type_ternure                                 AS market_actual_tenure,
    Market_user_adoption_tenure                                AS market_adoption_tenure,

    -- Plataforma PeYa
    CASE 
      WHEN Platform_Actual_Type = 'Re-Order'     THEN 'Reorder'
      WHEN Platform_Actual_Type = 'Reactivation' THEN 'Re-Activation'
      ELSE Platform_Actual_Type
    END                                                        AS platform_l1,
    Platform_Actual_type_ternure                               AS platform_actual_tenure,
    Platform_user_adoption_tenure                              AS platform_adoption_tenure

  FROM `peya-food-and-groceries.automated_tables_reports.frank_user_type_monthly`
  WHERE Mes >= start_date
    AND country NOT IN ('Venezuela', 'Costa Rica')
),

-- 2. Desanidado y apertura de estados L1 (activos e inactivos)
unpivoted_users AS (
  -- A. D-Marts (Estados L1 directos)
  SELECT
    month,
    country,
    'Dmart'                    AS business,
    market_l1                  AS user_type_l1,
    customer_id,
    market_actual_tenure       AS actual_tenure,
    market_adoption_tenure     AS adoption_tenure
  FROM user_base

  UNION ALL

  -- Sub-segmento D-Mart Inactive < 6 month (Fuga reciente de 1 a 5 meses)
  SELECT
    month,
    country,
    'Dmart'                    AS business,
    'Inactive < 6 month'       AS user_type_l1,
    customer_id,
    market_actual_tenure,
    market_adoption_tenure
  FROM user_base
  WHERE market_l1 = 'Churned' AND market_actual_tenure < 6

  UNION ALL

  -- Sub-segmento D-Mart Inactive > 6 month (Fuga prolongada de 6 meses o más)
  SELECT
    month,
    country,
    'Dmart'                    AS business,
    'Inactive > 6 month'       AS user_type_l1,
    customer_id,
    market_actual_tenure,
    market_adoption_tenure
  FROM user_base
  WHERE market_l1 = 'Churned' AND market_actual_tenure >= 6

  UNION ALL

  -- B. Plataforma PeYa (Estados L1 directos)
  SELECT
    month,
    country,
    'PeYa'                     AS business,
    platform_l1                AS user_type_l1,
    customer_id,
    platform_actual_tenure     AS actual_tenure,
    platform_adoption_tenure   AS adoption_tenure
  FROM user_base

  UNION ALL

  -- Sub-segmento PeYa Inactive < 6 month
  SELECT
    month,
    country,
    'PeYa'                     AS business,
    'Inactive < 6 month'       AS user_type_l1,
    customer_id,
    platform_actual_tenure,
    platform_adoption_tenure
  FROM user_base
  WHERE platform_l1 = 'Churned' AND platform_actual_tenure < 6

  UNION ALL

  -- Sub-segmento PeYa Inactive > 6 month
  SELECT
    month,
    country,
    'PeYa'                     AS business,
    'Inactive > 6 month'       AS user_type_l1,
    customer_id,
    platform_actual_tenure,
    platform_adoption_tenure
  FROM user_base
  WHERE platform_l1 = 'Churned' AND platform_actual_tenure >= 6
)

-- 3. Agregación final exclusiva: usuarios y tenures
SELECT
  month,
  country,
  business,
  user_type_l1,

  -- Métricas exclusivas de usuarios y tenures
  COUNT(DISTINCT customer_id)      AS users,
  ROUND(AVG(actual_tenure), 2)     AS ternure,
  ROUND(AVG(adoption_tenure), 2)   AS adoption_tenure

FROM unpivoted_users
GROUP BY
  month,
  country,
  business,
  user_type_l1
ORDER BY
  month DESC,
  country ASC,
  business ASC,
  users DESC;
