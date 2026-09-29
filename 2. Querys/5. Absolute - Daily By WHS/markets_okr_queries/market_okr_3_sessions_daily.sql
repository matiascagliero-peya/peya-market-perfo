DECLARE query_name STRING DEFAULT 'market_okr_3_sessions_daily';

-- ============================================================
-- markets_sessions_daily
-- Responsable: Product Analytics
-- Grain: fecha_completa + country_name + warehouse_id
-- ============================================================

DECLARE table_exists BOOL;
SET table_exists = EXISTS (
  SELECT 1
  FROM `peya-food-and-groceries.automated_tables_reports.markets_sessions_daily`
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
  CREATE TABLE `peya-food-and-groceries.automated_tables_reports.markets_sessions_daily` (
    fecha_completa          DATE,
    country_name            STRING,
    warehouse_id            STRING,
    warehouse_name          STRING,
    sessions                INT64,
    transactions            INT64,
    sessions_non_dy         INT64,
    transactions_non_dy     INT64,
    uf_orders               INT64,
    double_ya_orders        INT64
  )
  PARTITION BY fecha_completa
  CLUSTER BY country_name, warehouse_id;
END IF;

-- LIMPIEZA INCREMENTAL
IF table_exists THEN
  DELETE FROM `peya-food-and-groceries.automated_tables_reports.markets_sessions_daily`
  WHERE fecha_completa BETWEEN from_date AND to_date;
END IF;

-- INSERCIÓN
INSERT INTO `peya-food-and-groceries.automated_tables_reports.markets_sessions_daily`

WITH

partners AS (
  SELECT p.country_id, p.partner_id, pd.warehouse_id, pd.warehouse_name, TRUE AS darkstore
  FROM `peya-bi-tools-pro.il_core.dim_partner` p
  INNER JOIN `peya-datamarts-pro.dm_dmarts.dim_partner_darkstore` pd ON p.partner_id = pd.partner_id
),

sessions_perseus AS (
  SELECT
    DATE(fp.date)       AS day,
    fp.country_id,
    p.warehouse_id,
    p.warehouse_name,
    SUM(fp.funnel_shop_details)                                                                               AS sessions,
    SUM(fp.funnel_shop_transaction)                                                                           AS transactions,
    SUM(CASE WHEN (fp.funnel_shop_double_ya = 0 OR fp.funnel_shop_double_ya IS NULL) THEN fp.funnel_shop_details     END) AS sessions_non_dy,
    SUM(CASE WHEN (fp.funnel_shop_double_ya = 0 OR fp.funnel_shop_double_ya IS NULL) THEN fp.funnel_shop_transaction  END) AS transactions_non_dy
  FROM `peya-bi-tools-pro.il_sessions.perseus_fact_partner_funnel` fp
  INNER JOIN partners p ON CAST(fp.partner_id AS STRING) = CAST(p.partner_id AS STRING)
  WHERE DATE(fp.date) BETWEEN from_date AND to_date
  GROUP BY 1, 2, 3, 4
),

orders_agg AS (
  -- uf_orders y double_ya_orders atribuidos por warehouse
  SELECT
    DATE(o.registered_date)   AS day,
    o.country_id,
    p.warehouse_id,
    COUNT(DISTINCT CASE WHEN o.order_status = 'CONFIRMED' AND dco_agg.uf_order = 1 THEN o.order_id END)                AS uf_orders,
    COUNT(DISTINCT CASE WHEN o.order_status = 'CONFIRMED' AND dy.order_details.id.secondary IS NOT NULL THEN o.order_id END) AS double_ya_orders
  FROM `peya-bi-tools-pro.il_core.fact_orders` o
  INNER JOIN partners p ON CAST(p.partner_id AS STRING) = CAST(o.restaurant.id AS STRING)
  LEFT JOIN (
    SELECT order_id,
      MAX(CASE WHEN master_category_parent_english IN ('Produce', 'Meat / Seafood', 'Ready To Consume') THEN 1 ELSE 0 END) AS uf_order
    FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
    WHERE order_date BETWEEN from_date AND to_date
    GROUP BY 1
  ) dco_agg ON CAST(o.order_id AS STRING) = dco_agg.order_id
  LEFT JOIN `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya` dy
    ON CAST(o.order_id AS STRING) = CAST(dy.order_details.id.secondary AS STRING)
    AND dy.order_type = 'DOUBLE_YA'
  WHERE o.registered_date BETWEEN from_date AND to_date
  GROUP BY 1, 2, 3
)

SELECT
  sp.day          AS fecha_completa,
  c.country_name,
  sp.warehouse_id,
  sp.warehouse_name,
  sp.sessions,
  sp.transactions,
  sp.sessions_non_dy,
  sp.transactions_non_dy,
  COALESCE(oa.uf_orders, 0)        AS uf_orders,
  COALESCE(oa.double_ya_orders, 0) AS double_ya_orders

FROM sessions_perseus sp
INNER JOIN `peya-bi-tools-pro.il_core.dim_country` c ON c.country_id = sp.country_id AND c.active = TRUE
LEFT JOIN orders_agg oa ON oa.day = sp.day AND oa.country_id = sp.country_id AND oa.warehouse_id = sp.warehouse_id
WHERE sp.day BETWEEN from_date AND to_date;
