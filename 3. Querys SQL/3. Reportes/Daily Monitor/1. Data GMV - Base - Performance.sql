DECLARE query_name STRING DEFAULT '1. Data GMV - Base - Performance';

-- 1. Data GMV - Base - Performance

-- REPORTE: GMV y Active Stores por País/Semana
-- 1. CONFIGURACIÓN DE VARIABLES
DECLARE start_date DATE DEFAULT "2023-06-01";
DECLARE excluded_stores ARRAY<STRING> DEFAULT [
    "RD_12_Torre OV", "PA_9_Midtown", "SV_6_Torre Futura", 
    "EC_17_TiendaPick-Up Oficina", "PE_3_PuntaHermosa", "BO_19_Truck", 
    "UY_15_Eventos", "PE_24_FILO", "EC_6_Oficina"
];

-- 2. FUNCIÓN DE NORMALIZACIÓN (Optimización DRY)
CREATE TEMP FUNCTION NormalizeCountry(country_name STRING, reference_date DATE) AS (
  CASE 
    WHEN EXTRACT(YEAR FROM reference_date) >= 2025 THEN 
      CASE country_name 
        WHEN 'República Dominicana' THEN 'Dominican Republic'
        WHEN 'Perú' THEN 'Peru'
        WHEN 'Panamá' THEN 'Panama'
        ELSE country_name
      END
    ELSE country_name
  END
);

WITH 
-- 3. CÁLCULO DE FECHA MÁXIMA
global_metrics AS (
    SELECT MAX(registered_date) AS last_day
    FROM `peya-datamarts-pro.dm_order_profitability.fact_order_profitability`
    WHERE DATE_TRUNC(registered_date, MONTH) >= start_date
      AND order_status = "CONFIRMED"
      AND location.country_name_en <> "Venezuela"
),

-- 4. DATOS PRINCIPALES
gmv AS (
    SELECT 
        EXTRACT(YEAR FROM registered_date) as Year,
        DATE_TRUNC(registered_date, MONTH) as date_month,
        CONCAT(EXTRACT(YEAR FROM registered_date), "-", EXTRACT(ISOWEEK FROM registered_date)) AS Week,

        NormalizeCountry(location.country_name_en, registered_date) AS country_name,

        weekly_rate_eu,
        COUNT(DISTINCT order_id) as Orders_PeYa,

        COUNT(DISTINCT (CASE WHEN partner.vertical_group = 'D-Mart' THEN order_id END)) as Orders_Market,

        ROUND(SAFE_DIVIDE(COUNT(DISTINCT (CASE WHEN partner.vertical_group = 'D-Mart' THEN order_id END)), COUNT(DISTINCT order_id)), 5) as orders_share_PeYa_Market,

        SUM(CASE WHEN partner.vertical_group = 'D-Mart' THEN gmv.gmv_user END) as gmv_dmarts_lc,
        
        SUM(CASE WHEN partner.vertical_group <> 'D-Mart' THEN gmv.gmv_user END) as gmv_platform_lc,
        
        -- ESTA ES LA COLUMNA QUE BUSCAS (Share sobre el total)
        ROUND(SAFE_DIVIDE(SUM(CASE WHEN partner.vertical_group = 'D-Mart' THEN gmv.gmv_user END), SUM(gmv.gmv_user)), 5) as gmv_share_dmarts,
        
        SAFE_DIVIDE(SUM(CASE WHEN partner.vertical_group = 'D-Mart' THEN gmv.gmv_user END), weekly_rate_eu) as gmv_dmarts_eur,
        SAFE_DIVIDE(SUM(CASE WHEN partner.vertical_group <> 'D-Mart' THEN gmv.gmv_user END), weekly_rate_eu) as gmv_platform_eur,
        SAFE_DIVIDE(SUM(CASE WHEN partner.vertical_group IN ('D-Mart', 'Local Stores') THEN gmv.gmv_user END), weekly_rate_eu) as gmv_qc_eur,
        SAFE_DIVIDE(SUM(CASE WHEN partner.aaa_type IN ('Supermarket','Hypermarket','Convenience','Small Supermarket') THEN gmv.gmv_user END), weekly_rate_eu) as gmv_AAA_eur

    FROM `peya-datamarts-pro.dm_order_profitability.fact_order_profitability` 
    WHERE DATE_TRUNC(registered_date, MONTH) >= start_date
      AND order_status = "CONFIRMED"
      AND location.country_name_en <> "Venezuela"
    GROUP BY 1, 2, 3, 4, 5
    ORDER BY 1, 2, 3, 4
),

active_stores_month AS (
    SELECT
        DATE_TRUNC(order_date, MONTH) AS month_year,
        NormalizeCountry(country_name, order_date) AS country_name,
        COUNT(DISTINCT warehouse_id) AS active_warehouses
    FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
    WHERE DATE_TRUNC(order_date, MONTH) >= start_date
      AND store_name NOT IN UNNEST(excluded_stores)
      AND state = "CONFIRMED"
    GROUP BY 1, 2
    ORDER BY 1, 2
),

active_stores_week AS (
    SELECT
        EXTRACT(YEAR FROM order_date) AS year,
        EXTRACT(ISOWEEK FROM order_date) AS week,
        NormalizeCountry(country_name, order_date) AS country_name,
        COUNT(DISTINCT warehouse_id) AS active_warehouses_week
    FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
    WHERE DATE_TRUNC(order_date, MONTH) >= start_date
      AND store_name NOT IN UNNEST(excluded_stores)
      AND state = "CONFIRMED"
    GROUP BY 1, 2, 3
    ORDER BY 1, 2, 3
)

SELECT 
  o.*, 
  a.active_warehouses, 
  b.active_warehouses_week,
  gm.last_day
FROM gmv o
CROSS JOIN global_metrics gm
LEFT JOIN active_stores_month a 
  ON a.month_year = o.date_month AND UPPER(a.country_name) = UPPER(o.country_name) 
LEFT JOIN active_stores_week b 
  ON CONCAT(b.year, "-", b.week) = o.Week AND UPPER(b.country_name) = UPPER(o.country_name) 
ORDER BY 1, 2, 3 DESC, 4;