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
    f.location.country_name_en                                AS country,
    
    -- Segmentaciones
    CASE WHEN f.small_order_fee > 0 THEN 'SOF' ELSE 'NON-SOF' END AS sof_group,
    CASE WHEN COALESCE(f.user.is_user_plus, FALSE) THEN 'PLUS' ELSE 'REGULAR' END AS user_segment,

    -- Tarifas pagadas convertidas a EUR
    SAFE_DIVIDE(f.small_order_fee, f.monthly_rate_eu)         AS sof_paid_eur,
    SAFE_DIVIDE(f.delivery_fee_user, f.monthly_rate_eu)       AS delivery_fee_paid_eur,
    SAFE_DIVIDE(f.service_fee, f.monthly_rate_eu)             AS service_fee_paid_eur,
    SAFE_DIVIDE(
      COALESCE(f.small_order_fee, 0) + 
      COALESCE(f.delivery_fee_user, 0) + 
      COALESCE(f.service_fee, 0), 
      f.monthly_rate_eu
    )                                                         AS total_fees_paid_eur,

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
    SUM(s.fulfilled_quantity)                                 AS basket_units,
    SUM(s.total_amount_net_with_discount_eur)                 AS net_sales_eur
  FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` AS s
  WHERE s.order_date >= start_date
    AND UPPER(s.state) = 'CONFIRMED'
  GROUP BY 1
),

metricas_consolidadas AS (
  SELECT
    o.month                                                   AS mes,
    o.country                                                 AS pais,
    o.sof_group                                               AS segmento_sof,
    o.user_segment                                            AS segmento_usuario_plus,

    -- Agregaciones absolutas
    COUNT(DISTINCT o.user_id)                                 AS total_usuarios_unicos,
    COUNT(DISTINCT o.order_id)                                AS total_pedidos_confirmados,
    SUM(COALESCE(s.basket_units, 0))                          AS total_unidades_vendidas,
    ROUND(SUM(COALESCE(s.net_sales_eur, 0)), 2)               AS total_ventas_netas_eur,
    ROUND(SUM(COALESCE(o.sof_paid_eur, 0)), 2)                AS total_recaudado_sof_eur,
    ROUND(SUM(COALESCE(o.delivery_fee_paid_eur, 0)), 2)        AS total_recaudado_delivery_fee_eur,
    ROUND(SUM(COALESCE(o.service_fee_paid_eur, 0)), 2)         AS total_recaudado_service_fee_eur,
    ROUND(SUM(COALESCE(o.total_fees_paid_eur, 0)), 2)          AS total_recaudado_todas_las_fees_eur,
    ROUND(SUM(COALESCE(o.gpo_eur, 0)), 2)                     AS total_margen_bruto_gpo_eur

  FROM orders o
  LEFT JOIN sku_orders s 
    ON o.order_id = s.order_id
  GROUP BY 1, 2, 3, 4
)

-- =============================================================================
-- SELECT FINAL (Limpio, con renombres explícitos y sin cálculos)
-- =============================================================================
SELECT
  -- DIMENSIÓN TEMPORAL Y GEOGRÁFICA
  mes,                                  -- Primer día del mes analizado
  pais,                                 -- País de la orden

  -- SEGMENTACIONES DE NEGOCIO
  segmento_sof,                         -- 'SOF' (tuvo cargo por pedido mínimo) o 'NON-SOF'
  segmento_usuario_plus,                -- 'PLUS' (suscriptor activo) o 'REGULAR' (no suscriptor)

  -- VOLUMETRÍA (ABSOLUTOS)
  total_usuarios_unicos,                -- Cantidad de clientes distintos que compraron
  total_pedidos_confirmados,            -- Cantidad total de órdenes entregadas/confirmadas

  -- TAMAÑO DE CANASTA (BASKET SIZE ABSOLUTO)
  total_unidades_vendidas,              -- Cantidad física total de ítems/unidades vendidas

  -- FACTURACIÓN / VENTAS
  total_ventas_netas_eur,               -- Ventas netas totales de mercadería en Euros (Net Sales)

  -- TARIFAS / FEES COBRADAS AL USUARIO (EN EUROS)
  total_recaudado_sof_eur,              -- Total cobrado exclusivamente por Small Order Fee
  total_recaudado_delivery_fee_eur,     -- Total cobrado por costo de envío al cliente
  total_recaudado_service_fee_eur,      -- Total cobrado por tarifa de servicio
  total_recaudado_todas_las_fees_eur,   -- Suma total de todos los fees abonados por el usuario

  -- RENTABILIDAD
  total_margen_bruto_gpo_eur            -- Ganancia bruta total en Euros (Gross Profit per Order)

FROM metricas_consolidadas
ORDER BY 
  mes DESC, 
  pais, 
  segmento_sof, 
  segmento_usuario_plus;
