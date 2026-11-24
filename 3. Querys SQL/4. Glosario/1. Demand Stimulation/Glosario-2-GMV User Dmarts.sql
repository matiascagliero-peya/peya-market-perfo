DECLARE query_name STRING DEFAULT 'Glosario-2-GMV User Dmarts';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 2
-- Nombre:     GMV User Dmarts (Gross Merchandise Value - User Method)
-- Chapter:    Demand Stimulation
-- Query bajada en: 0 - Orders / 1. Data GMV / 11. Daily Alerts
-- Sheets Name: 1. TD - OKRs Mensual (0 - Orders) & 1. Data GMV - Base - Performance
-- Sheets Link: https://docs.google.com/spreadsheets/d/13yTO_kFzIvISmbSz6p93BFUub1HODpuiGhB3yElZ2fw
--
-- ====================================================================================
-- DEFINICIÓN Y LAS 2 FORMAS OFICIALES DE CÁLCULO EN BIGQUERY:
-- ====================================================================================
-- Volumen Bruto de Mercadería pagado por los usuarios finales en Dmarts en Euros.
-- Incluye: Productos netos de descuentos + Tarifa de Envío + Tarifa de Servicio.
--
-- Existen 2 formas oficiales y auditadas de calcularlo en el Data Warehouse:
--
-- FORMA 1: FINANZAS / PROFITABILITY (Fuente corporativa Delivery Hero / Cierres P&L)
--   • Tabla: `peya-datamarts-pro.dm_order_profitability.fact_order_profitability`
--   • Lógica: SAFE_DIVIDE(gmv.gmv_user, monthly_rate_eu)
--   • Ventaja: Columna nativa auditada por finanzas. Incluye órdenes pick-up/B2B.
--
-- FORMA 2: OPERACIONES / FACT ORDERS (Fuente transaccional directa / Daily Alerts)
--   • Tabla: `peya-bi-tools-pro.il_core.fact_orders` + `fact_sap_fx`
--   • Lógica: SUM(total_amount/fx) + SUM(shipping_amount/fx) + SUM(IFNULL(service_fee,0)/fx)
--   • Ventaja: Reconstrucción granular de los 3 componentes del usuario a nivel tienda.
-- ====================================================================================

WITH
-- Fuente de Tasa de Cambio SAP FX (Promedio mensual)
fx AS (
    SELECT
        fx_source.month,
        fx_source.currency_iso,
        c.country_id,
        AVG(fx_source.rate_eur) AS rate_eur
    FROM `peya-fraud-and-fintech.group_finance_data.fact_sap_fx` AS fx_source
    LEFT JOIN `peya-bi-tools-pro.il_core.dim_country` AS c
        ON fx_source.currency_iso = c.currency_price
    WHERE c.country_name_en NOT IN ('Venezuela', 'Puerto Rico')
    GROUP BY 1, 2, 3
),

-- FORMA 1: CÁLCULO DESDE FACT_ORDER_PROFITABILITY (Finanzas / P&L)
forma_1_profitability AS (
    SELECT
        location.country_name_en AS country,
        DATE_TRUNC(registered_date, MONTH) AS month,
        COUNT(DISTINCT order_id) AS orders_profitability,
        ROUND(SUM(SAFE_DIVIDE(gmv.gmv_user, monthly_rate_eu)), 2) AS gmv_user_eur_profitability
    FROM `peya-datamarts-pro.dm_order_profitability.fact_order_profitability`
    WHERE registered_date BETWEEN DATE '2026-10-01' AND DATE '2026-10-31'
      AND order_status = 'CONFIRMED'
      AND partner.vertical_group = 'D-Mart'
      AND location.country_name_en <> 'Venezuela'
    GROUP BY 1, 2
),

-- FORMA 2: CÁLCULO DESDE FACT_ORDERS (Operaciones / Daily Alerts)
forma_2_fact_orders AS (
    SELECT
        c.country_name_en AS country,
        DATE_TRUNC(DATE(fo.registered_date), MONTH) AS month,
        COUNT(DISTINCT fo.order_id) AS orders_fact_orders,
        ROUND(
          SUM(fo.total_amount / fx.rate_eur)
          + SUM(fo.shipping_amount / fx.rate_eur)
          + SUM(IFNULL(fo.serviceFee.service_fee_amount, 0) / fx.rate_eur)
        , 2) AS gmv_user_eur_fact_orders
    FROM `peya-bi-tools-pro.il_core.fact_orders` fo
    INNER JOIN `peya-bi-tools-pro.il_core.dim_country` c
        ON fo.country_id = c.country_id
    LEFT JOIN `peya-bi-tools-pro.il_core.dim_partner` par
        ON fo.restaurant.id = par.partner_id
    LEFT JOIN fx
        ON DATE_TRUNC(DATE(fo.registered_date), MONTH) = fx.month
       AND fo.country_id = fx.country_id
    WHERE fo.registered_date BETWEEN DATE '2026-10-01' AND DATE '2026-10-31'
      AND fo.order_status = 'CONFIRMED'
      AND par.is_logistic
      AND par.is_darkstore
      AND par.business_type.business_type_name NOT IN ('Courier', 'Courier Business')
      AND c.country_name_en <> 'Venezuela'
    GROUP BY 1, 2
)

SELECT
  COALESCE(p.country, f.country) AS country,
  COALESCE(p.month, f.month) AS month,
  -- Métricas Forma 1 (Profitability)
  p.orders_profitability,
  p.gmv_user_eur_profitability,
  -- Métricas Forma 2 (Fact Orders)
  f.orders_fact_orders,
  f.gmv_user_eur_fact_orders,
  -- Conciliación y Variaciones
  ROUND(p.gmv_user_eur_profitability - f.gmv_user_eur_fact_orders, 2) AS diff_gmv_eur,
  ROUND(SAFE_DIVIDE(p.gmv_user_eur_profitability - f.gmv_user_eur_fact_orders, p.gmv_user_eur_profitability) * 100, 3) AS diff_gmv_pct
FROM forma_1_profitability p
FULL OUTER JOIN forma_2_fact_orders f
  ON UPPER(p.country) = UPPER(f.country)
ORDER BY p.gmv_user_eur_profitability DESC;
