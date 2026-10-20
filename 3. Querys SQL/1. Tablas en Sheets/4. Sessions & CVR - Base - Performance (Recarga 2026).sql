-- ====================================================================================
-- 4. Sessions & CVR - Base - Performance (Recarga 2026)
-- PROPÓSITO: Recarga y auditoría de Sesiones y ratios de Conversión (CVR) para D-Marts
--            desde 2026-01-01 hasta la fecha, con desglose Total, Directo y Double Ya.
-- GRAIN: (month, country)
-- ====================================================================================

DECLARE query_name STRING DEFAULT '4. Sessions & CVR - Base - Performance (Recarga 2026).sql';
DECLARE start_date DATE DEFAULT '2026-01-01';

WITH

-- 1. PARTNERS: Darkstores operativos de D-Marts (excluyendo locales de prueba y oficinas)
partners AS (
  SELECT
    p.country_id,
    p.partner_id,
    pd.warehouse_id,
    TRUE AS darkstore
  FROM `peya-bi-tools-pro.il_core.dim_partner` p
  INNER JOIN `peya-datamarts-pro.dm_dmarts.dim_partner_darkstore` AS pd
    ON p.partner_id = pd.partner_id
  WHERE p.partner_name NOT IN (
    "RD_12_Torre OV", "PA_9_Midtown", "SV_6_Torre Futura",
    "EC_17_TiendaPick-Up Oficina", "PE_3_PuntaHermosa", "BO_19_Truck",
    "UY_15_Eventos", "PE_24_FILO", "EC_6_Oficina"
  )
),

-- 2. PAÍSES: Normalización de nombres de país y códigos ISO
dim_countries AS (
  SELECT
    country_id,
    UPPER(country_code) AS country_code,
    IF(country_name_en = 'Dominican Republic', 'Republica Dominicana', country_name_en) AS country_name
  FROM `peya-bi-tools-pro.il_core.dim_country`
  WHERE active = TRUE
),

-- 3. SESSIONS PERSEUS: Funnel completo de navegación, checkout y conversión desde 2026
sessions_raw AS (
  SELECT
    DATE_TRUNC(DATE(fp.date), MONTH) AS month,
    c.country_code,
    c.country_name,
    
    -- Funnel Total
    SUM(fp.funnel_shop_details)     AS total_sessions_details,
    SUM(fp.funnel_shop_add_cart)    AS total_sessions_add_cart,
    SUM(fp.funnel_shop_checkout)    AS total_sessions_checkout,
    SUM(fp.funnel_shop_transaction) AS total_sessions_transaction,

    -- Funnel Directo / Sin Double Ya (Flag = 0 o NULL)
    SUM(IF(IFNULL(fp.funnel_shop_double_ya, 0) = 0, fp.funnel_shop_details, 0))     AS sessions_details_direct,
    SUM(IF(IFNULL(fp.funnel_shop_double_ya, 0) = 0, fp.funnel_shop_add_cart, 0))    AS sessions_add_cart_direct,
    SUM(IF(IFNULL(fp.funnel_shop_double_ya, 0) = 0, fp.funnel_shop_checkout, 0))    AS sessions_checkout_direct,
    SUM(IF(IFNULL(fp.funnel_shop_double_ya, 0) = 0, fp.funnel_shop_transaction, 0)) AS sessions_transaction_direct,

    -- Funnel Double Ya (Flag > 0)
    SUM(IF(IFNULL(fp.funnel_shop_double_ya, 0) > 0, fp.funnel_shop_details, 0))     AS sessions_details_dy,
    SUM(IF(IFNULL(fp.funnel_shop_double_ya, 0) > 0, fp.funnel_shop_add_cart, 0))    AS sessions_add_cart_dy,
    SUM(IF(IFNULL(fp.funnel_shop_double_ya, 0) > 0, fp.funnel_shop_checkout, 0))    AS sessions_checkout_dy,
    SUM(IF(IFNULL(fp.funnel_shop_double_ya, 0) > 0, fp.funnel_shop_transaction, 0)) AS sessions_transaction_dy

  FROM `peya-bi-tools-pro.il_sessions.perseus_fact_partner_funnel` fp
  INNER JOIN partners p
    ON fp.partner_id = p.partner_id
   AND (fp.country_id = p.country_id OR fp.country_id IS NULL OR fp.country_id = 0)
  INNER JOIN dim_countries c
    ON p.country_id = c.country_id
  WHERE DATE(fp.date) >= start_date
  GROUP BY 1, 2, 3
)

-- 4. CONSOLIDADO FINAL: Volúmenes y Ratios de Conversión (CVR3, mCVR, CVR DY)
SELECT
  -- Dimensiones
  month,
  country_code,
  country_name                                                                      AS country,

  -- Funnel y Ratios Totales
  total_sessions_details,
  total_sessions_add_cart,
  total_sessions_checkout,
  total_sessions_transaction,
  ROUND(SAFE_DIVIDE(total_sessions_transaction, total_sessions_details) * 100, 2)  AS cvr_total_pct,
  ROUND(SAFE_DIVIDE(total_sessions_transaction, total_sessions_add_cart) * 100, 2) AS mcvr_cart_to_trx_pct,

  -- Funnel y Ratios Directo (Orgánico)
  sessions_details_direct,
  sessions_add_cart_direct,
  sessions_checkout_direct,
  sessions_transaction_direct,
  ROUND(SAFE_DIVIDE(sessions_transaction_direct, sessions_details_direct) * 100, 2) AS cvr_direct_pct,

  -- Funnel y Ratios Double Ya
  sessions_details_dy,
  sessions_add_cart_dy,
  sessions_checkout_dy,
  sessions_transaction_dy,
  ROUND(SAFE_DIVIDE(sessions_transaction_dy, sessions_details_dy) * 100, 2)        AS cvr_dy_pct,

  -- Participación de Double Ya sobre el total
  ROUND(SAFE_DIVIDE(sessions_details_dy, total_sessions_details) * 100, 2)         AS share_dy_sessions_pct,
  ROUND(SAFE_DIVIDE(sessions_transaction_dy, total_sessions_transaction) * 100, 2) AS share_dy_transactions_pct

FROM sessions_raw
ORDER BY month DESC, country_name ASC;
