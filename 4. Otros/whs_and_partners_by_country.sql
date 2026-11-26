DECLARE query_name STRING DEFAULT 'whs_and_partners_by_country';

-- ==============================================================================
-- REPORTE: Penetración y Clientes Aditivos por Vertical y País
-- Objetivo: Generar la tabla final 100% aditiva a nivel País.
--           - Garantiza que SUM(platform_users) dé la suma exacta (8.77M en LATAM).
--           - Garantiza que la suma horizontal (Market + Satélites) dé el Total D-Mart.
--           - Entrega las dos penetraciones oficiales calculadas:
--             * penetracion_market_only_pct (WBR Oficial)
--             * penetracion_total_pct (Frank / Darkstore Integral)
-- ==============================================================================

DECLARE start_date DATE DEFAULT DATE '2026-09-01';
DECLARE end_date   DATE DEFAULT DATE '2026-09-30';

-- 1. Platform Users Oficiales por País (Métrica WBR / Cobertura desduplicada)
WITH platform_by_country AS (
  SELECT 
    dc.country_code,
    SUM(cm.MAUs) AS platform_users
  FROM `peya-food-and-groceries.automated_tables_reports.qc_coverage_city_MAUs` cm
  LEFT JOIN `peya-bi-tools-pro.il_core.dim_country` dc 
    ON cm.country_id = dc.country_id
  WHERE cm.month_date = start_date
    AND cm.country_id NOT IN (16, 8) -- Excluye Costa Rica y Venezuela
  GROUP BY 1
),

-- 2. Atribución Jerárquica Excluyente de Clientes (Sin duplicados por país)
customer_attribution AS (
  SELECT 
    p.country_name,
    p.country_code,
    p.customer_id,
    CASE 
      WHEN LOGICAL_OR(p.vertical_type = 'Market')   THEN 'Market'
      WHEN LOGICAL_OR(p.vertical_type = 'Pharmacy') THEN 'Pharmacy'
      WHEN LOGICAL_OR(p.vertical_type = 'Pets')     THEN 'Pets'
      WHEN LOGICAL_OR(p.vertical_type = 'Drinks')   THEN 'Drinks'
      ELSE 'Shop'
    END AS vertical
  FROM `peya-food-and-groceries.automated_tables_reports.qc_performance_order_overall` p
  WHERE p.registered_date BETWEEN start_date AND end_date
    AND p.order_status = 'CONFIRMED'
    AND p.category_partner = 'D-Mart'
    AND p.country_code NOT IN ('CR', 'VE')
  GROUP BY 1, 2, 3
)

SELECT 
  ca.country_name,
  
  -- Desglose de Clientes por Vertical (Suma horizontal exacta)
  COUNT(DISTINCT IF(ca.vertical = 'Market', ca.customer_id, NULL))   AS Market,
  COUNT(DISTINCT IF(ca.vertical = 'Pharmacy', ca.customer_id, NULL)) AS Pharmacy,
  COUNT(DISTINCT IF(ca.vertical = 'Pets', ca.customer_id, NULL))     AS Pets,
  COUNT(DISTINCT IF(ca.vertical = 'Drinks', ca.customer_id, NULL))   AS Drinks,
  COUNT(DISTINCT IF(ca.vertical = 'Shop', ca.customer_id, NULL))     AS Shop,
  
  -- Total D-Mart (Suma exacta de las columnas anteriores = Frank)
  COUNT(DISTINCT ca.customer_id) AS total_dmart_users,
  
  -- Platform Users (1 sola vez por país: la SUMA da 100% exacta)
  pc.platform_users,
  
  -- Penetraciones Oficiales
  ROUND(SAFE_DIVIDE(COUNT(DISTINCT IF(ca.vertical = 'Market', ca.customer_id, NULL)), pc.platform_users) * 100, 2) AS penetracion_market_only_pct,
  ROUND(SAFE_DIVIDE(COUNT(DISTINCT ca.customer_id), pc.platform_users) * 100, 2) AS penetracion_total_pct

FROM customer_attribution ca
LEFT JOIN platform_by_country pc 
  ON ca.country_code = pc.country_code

GROUP BY 1, pc.platform_users
ORDER BY ca.country_name;
