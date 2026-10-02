DECLARE query_name STRING DEFAULT 'Dmart MAUs - Plus share %.sql';

-- ====================================================================================
-- PROPÓSITO: Cálculo de Dmart MAUs y Plus Share % a nivel SEMANAL
--            por PAÍS y total consolidado LATAM.
--
-- DERIVADO DE: '1. OKRs_daily_data.sql'
-- CAMPOS EXPORTADOS:
--   • fecha: Fecha de inicio de la semana (Lunes).
--   • dia_fin_semana: Fecha de cierre de la semana (Domingo).
--   • pais: Nombre del país (o 'LATAM' para el consolidado regional).
--   • dmart_maus: Usuarios únicos compradores en D-Mart en la semana.
--   • dmart_maus_plus: Usuarios únicos compradores con Plus en D-Mart en la semana.
--   • plus_share_pct: Porcentaje de usuarios Plus sobre el total de compradores (Plus / Total).
--   • plus_sobre_normales_pct: Ratio directo de usuarios Plus sobre normales (Plus / Normales).
-- ====================================================================================

-- Rango de fechas: por defecto últimas 8 semanas completas hasta ayer (Lunes a Domingo)
-- (Para tomar un histórico mayor, por ejemplo desde 2025, ajustar 'inicio' a DATE '2025-01-01')
DECLARE inicio DATE DEFAULT DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 8 WEEK), WEEK(MONDAY));
DECLARE fin    DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);

WITH
-- 1. Identificación de darkstores oficiales (excluyendo locales de prueba y oficinas)
partners AS (
  SELECT
    p.country_id,
    p.partner_id,
    pd.warehouse_id,
    TRUE AS darkstore
  FROM `peya-bi-tools-pro.il_core.dim_partner` p
  INNER JOIN `peya-datamarts-pro.dm_dmarts.dim_partner_darkstore` AS pd
    ON p.partner_id = pd.partner_id
  WHERE p.is_darkstore IS TRUE
    AND p.partner_name NOT IN (
      "RD_12_Torre OV", "PA_9_Midtown", "SV_6_Torre Futura",
      "EC_17_TiendaPick-Up Oficina", "PE_3_PuntaHermosa", "BO_19_Truck",
      "UY_15_Eventos", "PE_24_FILO", "EC_6_Oficina"
    )
),

-- 2. Base semanal de compradores únicos por país con flag de membresía Plus
orders_base AS (
  SELECT
    DATE_TRUNC(DATE(o.registered_date), WEEK(MONDAY))                         AS fecha,
    DATE_ADD(DATE_TRUNC(DATE(o.registered_date), WEEK(MONDAY)), INTERVAL 6 DAY) AS dia_fin_semana,
    CASE 
      WHEN o.country.country_name IN ('República Dominicana', 'Republic Dominican', 'Dominican Republic') THEN 'Republica Dominicana'
      ELSE o.country.country_name 
    END AS pais,
    o.customer_id,
    -- Si el cliente realizó al menos 1 orden confirmada como Plus en la semana, clasifica como Plus
    MAX(CASE WHEN o.is_user_plus = 1 THEN 1 ELSE 0 END) AS is_plus_user
  FROM `peya-bi-tools-pro.il_core.fact_orders` o
  INNER JOIN partners p 
    ON o.restaurant.id = p.partner_id
  WHERE o.order_status = 'CONFIRMED'
    AND DATE(o.registered_date) BETWEEN inicio AND fin
  GROUP BY 1, 2, 3, 4
),

-- 3. Agregación semanal a nivel de País
weekly_by_country AS (
  SELECT
    fecha,
    dia_fin_semana,
    pais,
    COUNT(DISTINCT customer_id) AS dmart_maus,
    COUNT(DISTINCT CASE WHEN is_plus_user = 1 THEN customer_id END) AS dmart_maus_plus,
    COUNT(DISTINCT CASE WHEN is_plus_user = 0 THEN customer_id END) AS dmart_maus_normales
  FROM orders_base
  GROUP BY 1, 2, 3
),

-- 4. Consolidado regional LATAM (deduplicando clientes únicos a nivel regional)
weekly_latam AS (
  SELECT
    fecha,
    dia_fin_semana,
    'LATAM' AS pais,
    COUNT(DISTINCT customer_id) AS dmart_maus,
    COUNT(DISTINCT CASE WHEN is_plus_user = 1 THEN customer_id END) AS dmart_maus_plus,
    COUNT(DISTINCT CASE WHEN is_plus_user = 0 THEN customer_id END) AS dmart_maus_normales
  FROM (
    SELECT
      fecha,
      dia_fin_semana,
      customer_id,
      MAX(is_plus_user) AS is_plus_user
    FROM orders_base
    GROUP BY 1, 2, 3
  )
  GROUP BY 1, 2
),

-- 5. Unión de países individuales + consolidado LATAM
combined AS (
  SELECT * FROM weekly_by_country
  UNION ALL
  SELECT * FROM weekly_latam
)

-- Consulta final con fecha, país, volúmenes de usuarios y shares porcentuales
SELECT
  fecha,
  dia_fin_semana,
  pais,

  -- Volúmenes de usuarios en la semana
  dmart_maus,
  dmart_maus_plus,
  dmart_maus_normales,

  -- Plus Share %: Usuarios Plus sobre el total de compradores de D-Mart en la semana
  ROUND(
    SAFE_DIVIDE(dmart_maus_plus, dmart_maus) * 100, 
    2
  ) AS plus_share_pct,

  -- Plus sobre Normales %: Ratio de usuarios Plus sobre usuarios normales
  ROUND(
    SAFE_DIVIDE(dmart_maus_plus, dmart_maus_normales) * 100, 
    2
  ) AS plus_sobre_normales_pct

FROM combined
ORDER BY 
  fecha DESC, 
  (CASE WHEN pais = 'LATAM' THEN 0 ELSE 1 END), 
  pais ASC;
