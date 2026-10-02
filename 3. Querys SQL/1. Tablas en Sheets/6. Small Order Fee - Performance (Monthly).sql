DECLARE query_name STRING DEFAULT '15. Small Order Fee - Performance (Monthly)';
DECLARE start_date DATE DEFAULT '2025-01-01';

-- =============================================================================
-- REPORTE: Small Order Fee (SOF) vs Non-SOF Performance Mensual
-- Fuente principal: peya-bi-tools-pro.il_core.fact_orders
-- =============================================================================

WITH orders_base AS (
  SELECT
    CAST(o.order_id AS STRING)                               AS order_id,
    o.customer_id                                            AS customer_id,
    DATE_TRUNC(DATE(o.registered_date), MONTH)                AS month,
    CASE 
      WHEN o.country.country_name_en = 'Dominican Republic' THEN 'Republica Dominicana'
      ELSE o.country.country_name_en 
    END                                                       AS country_name,

    -- Segmentaciones (desde columnas nativas de fact_orders con fallback a estructuras previas)
    CASE 
      WHEN COALESCE(o.small_order_fee_amount, o.fees_v2.small_order_fee_amount, 0) > 0 THEN 'SOF' 
      ELSE 'Non-SOF' 
    END                                                       AS sof_group,
    CASE 
      WHEN COALESCE(o.is_user_plus, IF(o.user.is_user_plus, 1, 0), 0) = 1 THEN 'Plus' 
      ELSE 'Non-plus' 
    END                                                       AS plus_status,

    -- Flag New User directo de fact_orders (is_acquisition / is_first_confirmed_order_user)
    CASE 
      WHEN COALESCE(o.is_acquisition, o.is_first_confirmed_order_user, 0) = 1 THEN 1 
      ELSE 0 
    END                                                       AS is_new_user,

    -- Unidades vendidas directas de fact_orders
    COALESCE(o.qty_total_products, 0)                         AS units_sold,

    -- Ventas netas convertidas a EUR
    SAFE_DIVIDE(COALESCE(o.total_amount, 0), fop.monthly_rate_eu) AS net_sales_eur,

    -- Tarifas convertidas a EUR usando monthly_rate_eu de fact_order_profitability
    SAFE_DIVIDE(COALESCE(o.small_order_fee_amount, o.fees_v2.small_order_fee_amount, 0), fop.monthly_rate_eu) AS small_order_fee_eur,
    SAFE_DIVIDE(COALESCE(o.delivery_fee_amount, o.shipping_amount, 0), fop.monthly_rate_eu)                 AS delivery_fee_eur,
    SAFE_DIVIDE(COALESCE(o.service_fee_amount, o.serviceFee.service_fee_no_discount, o.fees_v2.service_fee_amount, 0), fop.monthly_rate_eu) AS service_fee_eur,
    SAFE_DIVIDE(
      COALESCE(o.small_order_fee_amount, o.fees_v2.small_order_fee_amount, 0) + 
      COALESCE(o.delivery_fee_amount, o.shipping_amount, 0) + 
      COALESCE(o.service_fee_amount, o.serviceFee.service_fee_no_discount, o.fees_v2.service_fee_amount, 0), 
      fop.monthly_rate_eu
    )                                                                                AS total_fees_eur,

    -- Margen Bruto (GPO)
    SAFE_DIVIDE(fop.gpo.gpo_harmony, fop.monthly_rate_eu)                            AS gpo_eur

  FROM `peya-bi-tools-pro.il_core.fact_orders` AS o
  INNER JOIN `peya-bi-tools-pro.il_core.dim_partner` AS par
    ON o.restaurant.id = par.partner_id
  LEFT JOIN `peya-datamarts-pro.dm_order_profitability.fact_order_profitability` AS fop
    ON o.order_id = fop.order_id
  WHERE DATE(o.registered_date) >= start_date
    AND o.order_status = 'CONFIRMED'
    AND par.is_darkstore = TRUE
    AND par.is_logistic = TRUE
    AND par.business_type.business_type_name NOT IN ('Courier', 'Courier Business')
),

metricas_consolidadas AS (
  SELECT
    o.month,
    o.country_name,
    o.sof_group,
    o.plus_status,

    -- Métricas absolutas estándar del glosario
    COUNT(DISTINCT o.customer_id)                                           AS sof_dmart_maus,
    COUNT(DISTINCT CASE WHEN o.is_new_user = 1 THEN o.customer_id END)      AS sof_new_users,
    COUNT(DISTINCT o.order_id)                                              AS sof_confirmed_orders,
    SUM(o.units_sold)                                                       AS sof_units_sold,
    ROUND(SUM(COALESCE(o.net_sales_eur, 0)), 2)                             AS sof_net_sales_eur,
    ROUND(SUM(COALESCE(o.small_order_fee_eur, 0)), 2)                       AS small_order_fee_eur,
    ROUND(SUM(COALESCE(o.delivery_fee_eur, 0)), 2)                          AS delivery_fee_eur,
    ROUND(SUM(COALESCE(o.service_fee_eur, 0)), 2)                           AS service_fee_eur,
    ROUND(SUM(COALESCE(o.total_fees_eur, 0)), 2)                            AS total_fees_eur,
    ROUND(SUM(COALESCE(o.gpo_eur, 0)), 2)                                   AS gpo_eur

  FROM orders_base o
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
  sof_new_users,
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
