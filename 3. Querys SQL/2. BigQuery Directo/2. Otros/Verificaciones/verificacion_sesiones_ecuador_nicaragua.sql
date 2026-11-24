-- ====================================================================================
-- PROPÓSITO: Verificar sesiones de Ecuador y Nicaragua en versión LIVIANA (Últimos 6 meses).
-- OPTIMIZACIONES DE RENDIMIENTO Y COSTO:
--   1) Ventana temporal acotada a los últimos 6 meses (DATE_SUB).
--   2) Poda directa por país en `perseus_fact_partner_funnel` mediante target_countries
--      (evita escanear las sesiones de los grandes países de LATAM como AR, CL, PE).
--   3) Poda de partición y filtrado directo de país en `customer_orders_sku_level`.
-- UBICACIÓN: PeYa Market/0. Pruebas/verificacion_sesiones_ecuador_nicaragua.sql
-- ====================================================================================

-- 1. Ventana de 6 meses (inicio de mes de hace 6 meses)
DECLARE start_date DATE DEFAULT DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 6 MONTH), MONTH);

WITH

-- 2. Países en scope para filtrar directamente por country_id en la tabla de sesiones
target_countries AS (
  SELECT
    country_id,
    country_name,
    country_name_en
  FROM `peya-bi-tools-pro.il_core.dim_country`
  WHERE country_name_en IN ('Ecuador', 'Nicaragua')
     OR country_name IN ('Ecuador', 'Nicaragua')
),

-- 3. Partners en scope de D-Marts para Ecuador y Nicaragua (acotado a 6 meses)
partners_scope AS (
  SELECT DISTINCT
    vendor_id,
    country_name AS country
  FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
  WHERE order_date >= start_date
    AND country_name IN ('Ecuador', 'Nicaragua')
  
  -- NOTA ULTRA-LIVIANA (0 bytes de customer_orders_sku_level):
  -- Si querés evitar escanear customer_orders_sku_level por completo, podés
  -- comentar la subquery de arriba y descomentar la siguiente que usa dimensiones:
  /*
  SELECT DISTINCT
    CAST(pd.partner_id AS STRING) AS vendor_id,
    c.country_name_en              AS country
  FROM `peya-datamarts-pro.dm_dmarts.dim_partner_darkstore` pd
  INNER JOIN `peya-bi-tools-pro.il_core.dim_partner` p
    ON pd.partner_id = p.partner_id
  INNER JOIN `peya-bi-tools-pro.il_core.dim_country` c
    ON p.country_id = c.country_id
  WHERE c.country_name_en IN ('Ecuador', 'Nicaragua')
  */
),

-- 4. Sesiones desde perseus_fact_partner_funnel con poda estricta por fecha y country_id
sessions_data AS (
  SELECT
    DATE_TRUNC(DATE(fp.date), MONTH) AS month,
    ps.country                       AS country,
    
    -- Sesiones y transacciones totales
    SUM(fp.funnel_shop_details)      AS total_sessions_details,
    SUM(fp.funnel_shop_transaction)  AS total_sessions_transaction,

    -- Double Ya (Flag = 1)
    SUM(IF(IFNULL(fp.funnel_shop_double_ya, 0) = 1, fp.funnel_shop_details, 0))     AS sessions_details_dy,
    SUM(IF(IFNULL(fp.funnel_shop_double_ya, 0) = 1, fp.funnel_shop_transaction, 0)) AS sessions_transaction_dy,

    -- Direct / No Double Ya (Flag = 0 o NULL)
    SUM(IF(IFNULL(fp.funnel_shop_double_ya, 0) = 0, fp.funnel_shop_details, 0))     AS sessions_details_direct,
    SUM(IF(IFNULL(fp.funnel_shop_double_ya, 0) = 0, fp.funnel_shop_transaction, 0)) AS sessions_transaction_direct

  FROM `peya-bi-tools-pro.il_sessions.perseus_fact_partner_funnel` fp
  INNER JOIN target_countries tc
    ON fp.country_id = tc.country_id
  INNER JOIN partners_scope ps
    ON CAST(fp.partner_id AS STRING) = CAST(ps.vendor_id AS STRING)
  WHERE DATE(fp.date) >= start_date
  GROUP BY 1, 2
)

SELECT
  month,
  country,
  
  -- Totales
  total_sessions_details,
  total_sessions_transaction,
  ROUND(SAFE_DIVIDE(total_sessions_transaction, total_sessions_details) * 100, 2)   AS cvr_total_pct,

  -- Double Ya
  sessions_details_dy,
  sessions_transaction_dy,
  ROUND(SAFE_DIVIDE(sessions_transaction_dy, sessions_details_dy) * 100, 2)         AS cvr_dy_pct,

  -- Direct
  sessions_details_direct,
  sessions_transaction_direct,
  ROUND(SAFE_DIVIDE(sessions_transaction_direct, sessions_details_direct) * 100, 2)  AS cvr_direct_pct,

  -- Share Double Ya sobre sesiones
  ROUND(SAFE_DIVIDE(sessions_details_dy, total_sessions_details) * 100, 2)          AS share_dy_pct

FROM sessions_data
ORDER BY month DESC, country ASC;
