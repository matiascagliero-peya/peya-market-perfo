DECLARE query_name STRING DEFAULT '15. Small Order Fee - Performance (Monthly)';
DECLARE start_date DATE DEFAULT '2025-01-01';

-- =============================================================================
-- REPORTE: Small Order Fee (SOF) vs Non-SOF Performance Mensual
-- =============================================================================

WITH orders AS (
  SELECT
    CAST(f.order_id AS STRING)                               AS order_id,
    f.user.user_id                                            AS user_id,
    DATE_TRUNC(f.registered_date, MONTH)                      AS month,
    f.location.country_name_en                                AS country_name,
    
    -- Segmentaciones
    CASE WHEN f.small_order_fee > 0 THEN 'SOF' ELSE 'Non-SOF' END AS sof_group,
    CASE WHEN COALESCE(f.user.is_user_plus, FALSE) THEN 'Plus' ELSE 'Non-plus' END AS plus_status,

    -- Tarifas pagadas convertidas a EUR
    SAFE_DIVIDE(f.small_order_fee, f.monthly_rate_eu)         AS small_order_fee_eur,
    SAFE_DIVIDE(f.delivery_fee_user, f.monthly_rate_eu)       AS delivery_fee_eur,
    SAFE_DIVIDE(f.service_fee, f.monthly_rate_eu)             AS service_fee_eur,
    SAFE_DIVIDE(
      COALESCE(f.small_order_fee, 0) + 
      COALESCE(f.delivery_fee_user, 0) + 
      COALESCE(f.service_fee, 0), 
      f.monthly_rate_eu
    )                                                         AS total_fees_eur,

    -- Margen Bruto (GPO)
    SAFE_DIVIDE(f.gpo.gpo_harmony, f.monthly_rate_eu)         AS gpo_eur

  FROM `peya-datamarts-pro.dm_order_profitability.fact_order_profitability` AS f
  WHERE f.registered_date >= start_date
    AND f.order_status = 'CONFIRMED'
    AND f.partner.vertical_group = 'D-Mart'
),

sku_orders AS (
  SELECT
    CAST(s.order_id AS STRING)                               AS order_id,
    SUM(s.fulfilled_quantity)                                 AS units_sold,
    SUM(s.total_amount_net_with_discount_eur)                 AS net_sales_eur
  FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` AS s
  WHERE s.order_date >= start_date
    AND UPPER(s.state) = 'CONFIRMED'
  GROUP BY 1
),

metricas_consolidadas AS (
  SELECT
    o.month,
    o.country_name,
    o.sof_group,
    o.plus_status,

    -- Métricas absolutas estándar del glosario
    COUNT(DISTINCT o.user_id)                                 AS sof_dmart_maus,
    COUNT(DISTINCT o.order_id)                                AS sof_confirmed_orders,
    SUM(COALESCE(s.units_sold, 0))                            AS sof_units_sold,
    ROUND(SUM(COALESCE(s.net_sales_eur, 0)), 2)               AS sof_net_sales_eur,
    ROUND(SUM(COALESCE(o.small_order_fee_eur, 0)), 2)         AS small_order_fee_eur,
    ROUND(SUM(COALESCE(o.delivery_fee_eur, 0)), 2)            AS delivery_fee_eur,
    ROUND(SUM(COALESCE(o.service_fee_eur, 0)), 2)             AS service_fee_eur,
    ROUND(SUM(COALESCE(o.total_fees_eur, 0)), 2)              AS total_fees_eur,
    ROUND(SUM(COALESCE(o.gpo_eur, 0)), 2)                     AS gpo_eur

  FROM orders o
  LEFT JOIN sku_orders s 
    ON o.order_id = s.order_id
  GROUP BY 1, 2, 3, 4
)

-- =============================================================================
-- SELECT FINAL (Limpio, con renombres estándar del workspace y sin cálculos)
-- =============================================================================
SELECT
  month,
  country_name,
  sof_group,
  plus_status,
  sof_dmart_maus,
  sof_confirmed_orders,
  sof_units_sold,
  sof_net_sales_eur,
  small_order_fee_eur,
  delivery_fee_eur,
  service_fee_eur,
  total_fees_eur,
  gpo_eur
FROM metricas_consolidadas
ORDER BY 
  month DESC, 
  country_name, 
  sof_group, 
  plus_status;
