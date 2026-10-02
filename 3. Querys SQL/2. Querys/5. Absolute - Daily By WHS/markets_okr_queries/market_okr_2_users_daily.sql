DECLARE query_name STRING DEFAULT 'market_okr_2_users_daily';

-- ============================================================
-- markets_users_daily
-- Responsable: Growth / CRM
-- Grain: fecha_completa + country_name  (sin warehouse — DAU/WAU/MAU son country-level)
-- La vista une con orders_revenue en fecha + country
-- ============================================================

DECLARE table_exists BOOL;
SET table_exists = EXISTS (
  SELECT 1
  FROM `peya-food-and-groceries.automated_tables_reports.markets_users_daily`
);

DECLARE from_date DATE;
DECLARE to_date DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);
IF NOT table_exists THEN
  SET from_date = DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 10 WEEK), WEEK(MONDAY));
ELSE
  SET from_date = DATE_SUB(CURRENT_DATE(), INTERVAL 3 DAY);
END IF;

-- CREACIÓN DE TABLA
IF NOT table_exists THEN
  CREATE TABLE `peya-food-and-groceries.automated_tables_reports.markets_users_daily` (
    fecha_completa      DATE,
    country_name        STRING,
    country_code        STRING,
    active_warehouses   INT64,
    -- DAU
    dau_peya            INT64,
    dau_dmart           INT64,
    dau_dmart_plus      INT64,
    -- WAU
    wau_peya            INT64,
    wau_dmart           INT64,
    wau_dmart_plus      INT64,
    -- MAU
    mau_peya            INT64,
    mau_dmart           INT64,
    mau_dmart_plus      INT64
  )
  PARTITION BY fecha_completa
  CLUSTER BY country_name;
END IF;

-- LIMPIEZA INCREMENTAL
IF table_exists THEN
  DELETE FROM `peya-food-and-groceries.automated_tables_reports.markets_users_daily`
  WHERE fecha_completa BETWEEN from_date AND to_date;
END IF;

-- INSERCIÓN
INSERT INTO `peya-food-and-groceries.automated_tables_reports.markets_users_daily`

WITH

partners AS (
  SELECT p.country_id, p.partner_id, pd.warehouse_id, TRUE AS darkstore
  FROM `peya-bi-tools-pro.il_core.dim_partner` p
  INNER JOIN `peya-datamarts-pro.dm_dmarts.dim_partner_darkstore` pd ON p.partner_id = pd.partner_id
),

active_stores AS (
  SELECT order_date AS day, country_code,
    COUNT(DISTINCT warehouse_id) AS active_warehouses
  FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
  WHERE order_date BETWEEN from_date AND to_date
    AND state = 'CONFIRMED'
    AND store_name NOT IN (
      'RD_12_Torre OV', 'PA_9_Midtown', 'SV_6_Torre Futura', 'EC_17_TiendaPick-Up Oficina',
      'PE_3_PuntaHermosa', 'BO_19_Truck', 'UY_15_Eventos', 'PE_24_FILO', 'EC_6_Oficina'
    )
  GROUP BY 1, 2
),

active_cust_dau AS (
  SELECT DATE(o.registered_date) AS day, o.country_id,
    COUNT(DISTINCT o.user.id)                                                          AS dau_peya,
    COUNT(DISTINCT CASE WHEN p.darkstore = TRUE THEN o.user.id END)                    AS dau_dmart,
    COUNT(DISTINCT CASE WHEN p.darkstore = TRUE AND o.is_user_plus = 1 THEN o.user.id END) AS dau_dmart_plus
  FROM `peya-bi-tools-pro.il_core.fact_orders` o
  LEFT JOIN partners p ON p.partner_id = o.restaurant.id
  WHERE o.registered_date BETWEEN from_date AND to_date
    AND o.order_status = 'CONFIRMED'
  GROUP BY 1, 2
),

active_cust_wau AS (
  SELECT DATE_TRUNC(DATE(o.registered_date), WEEK(MONDAY)) AS week_start, o.country_id,
    COUNT(DISTINCT o.user.id)                                                          AS wau_peya,
    COUNT(DISTINCT CASE WHEN p.darkstore = TRUE THEN o.user.id END)                    AS wau_dmart,
    COUNT(DISTINCT CASE WHEN p.darkstore = TRUE AND o.is_user_plus = 1 THEN o.user.id END) AS wau_dmart_plus
  FROM `peya-bi-tools-pro.il_core.fact_orders` o
  LEFT JOIN partners p ON p.partner_id = o.restaurant.id
  WHERE o.registered_date BETWEEN from_date AND to_date
    AND o.order_status = 'CONFIRMED'
  GROUP BY 1, 2
),

active_cust_mau AS (
  SELECT DATE_TRUNC(DATE(o.registered_date), MONTH) AS month_start, o.country_id,
    COUNT(DISTINCT o.user.id)                                                          AS mau_peya,
    COUNT(DISTINCT CASE WHEN p.darkstore = TRUE THEN o.user.id END)                    AS mau_dmart,
    COUNT(DISTINCT CASE WHEN p.darkstore = TRUE AND o.is_user_plus = 1 THEN o.user.id END) AS mau_dmart_plus
  FROM `peya-bi-tools-pro.il_core.fact_orders` o
  LEFT JOIN partners p ON p.partner_id = o.restaurant.id
  WHERE o.registered_date BETWEEN DATE_TRUNC(from_date, MONTH) AND to_date
    AND o.order_status = 'CONFIRMED'
  GROUP BY 1, 2
)

SELECT
  dau.day                       AS fecha_completa,
  c.country_name,
  c.country_code,
  a.active_warehouses,
  dau.dau_peya,
  dau.dau_dmart,
  dau.dau_dmart_plus,
  wau.wau_peya,
  wau.wau_dmart,
  wau.wau_dmart_plus,
  mau.mau_peya,
  mau.mau_dmart,
  mau.mau_dmart_plus

FROM active_cust_dau dau
INNER JOIN `peya-bi-tools-pro.il_core.dim_country` c ON c.country_id = dau.country_id AND c.active = TRUE
LEFT JOIN active_cust_wau wau  ON wau.week_start  = DATE_TRUNC(dau.day, WEEK(MONDAY)) AND wau.country_id  = dau.country_id
LEFT JOIN active_cust_mau mau  ON mau.month_start = DATE_TRUNC(dau.day, MONTH)        AND mau.country_id  = dau.country_id
LEFT JOIN active_stores a      ON a.day = dau.day AND UPPER(a.country_code) = UPPER(c.country_code)
WHERE dau.day BETWEEN from_date AND to_date;
