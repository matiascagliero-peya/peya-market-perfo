DECLARE query_name STRING DEFAULT '3. MAUs Coverage - Base - Performance';

-- Sheets Name: 1. ET - MAUs Coverage (15 - MAUs Coverage)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1MiQ6pB0Oc4TdiCGfXBR50mp-h22nBQt91g_QWOXO67k


-- 3. MAUs Coverage - Base - Performance
WITH coverage AS (
    -- Lógica de Matías: Usuarios cubiertos por el polígono (13 países PeYa Market)
    SELECT
        cm.month_date,
        cm.country_id, 
        dc.country_name_en AS country_name,
        SUM(cm.MAUs) AS platform_maus_coverage,
        SUM(dm.CUSTOMERS_CUBIERTOS) AS dmart_maus_cubiertos
    FROM `peya-food-and-groceries.automated_tables_reports.qc_coverage_city_MAUs` cm
    LEFT JOIN `peya-food-and-groceries.automated_tables_reports.qc_dmart_coverage_city_MAUs` dm
        ON cm.country_id = dm.country_id 
        AND cm.month_date = dm.month_date 
        AND cm.city_name_lz = dm.city_name_lz
    LEFT JOIN `peya-bi-tools-pro.il_core.dim_country` dc
        ON cm.country_id = dc.country_id
    WHERE cm.country_id NOT IN (16, 8) -- Excluye Costa Rica y Venezuela (D-Mart no opera)
    GROUP BY 1, 2, 3
),

penetration AS (
    -- Lógica de Luciano alineada a WBR: Usuarios que efectivamente compraron en Market
    SELECT 
        p.month_date,
        dc.country_id, -- Traemos el ID limpio desde la dimensión de países
        -- Criterio WBR: category_partner = 'D-Mart' Y vertical_type = 'Market'
        COUNT(DISTINCT IF(p.category_partner = "D-Mart" AND p.vertical_type = "Market", p.customer_id, NULL)) AS active_dmart_users,
        COUNT(DISTINCT p.customer_id) AS active_platform_users
    FROM `peya-food-and-groceries.automated_tables_reports.qc_performance_order_overall` p
    -- Sumamos este JOIN para traducir el country_code al country_id
    LEFT JOIN `peya-bi-tools-pro.il_core.dim_country` dc
        ON p.country_code = dc.country_code 
    WHERE p.order_status = "CONFIRMED"
      AND p.registered_date >= DATE '2025-01-01' -- Optimización de partición alineada al inicio de qc_coverage_city_MAUs
      AND dc.country_id NOT IN (16, 8) -- Excluye Costa Rica y Venezuela
    GROUP BY 1, 2
)

-- Unimos ambos mundos
SELECT 
    c.month_date,
    c.country_name,
    
    -- Métricas de Coverage
    c.platform_maus_coverage,
    c.dmart_maus_cubiertos,
    SAFE_DIVIDE(c.dmart_maus_cubiertos, c.platform_maus_coverage) AS qc_coverage,
    
    -- Métricas de Penetration
    p.active_dmart_users,
    p.active_platform_users,
    SAFE_DIVIDE(p.active_dmart_users, p.active_platform_users) AS qc_penetration

FROM coverage c
LEFT JOIN penetration p
    ON c.month_date = p.month_date 
    AND c.country_id = p.country_id -- Cruce perfecto por ID
ORDER BY 1 DESC, 2;
