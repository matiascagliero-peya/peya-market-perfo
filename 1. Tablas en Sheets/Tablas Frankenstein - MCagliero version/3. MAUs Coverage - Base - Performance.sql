DECLARE query_name STRING DEFAULT '3. MAUs Coverage - Base - Performance';

-- 3. MAUs Coverage - Base - Performance
WITH coverage AS (
    -- Lógica de Matías: Usuarios cubiertos por el polígono
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
    GROUP BY 1, 2, 3
),

penetration AS (
    -- Lógica de Luciano: Usuarios que efectivamente compraron
    SELECT 
        p.month_date,
        dc.country_id, -- Traemos el ID limpio desde la dimensión de países
        COUNT(DISTINCT IF(p.category_partner="D-Mart", p.customer_id, NULL)) AS active_dmart_users,
        COUNT(DISTINCT p.customer_id) AS active_platform_users
    FROM `peya-food-and-groceries.automated_tables_reports.qc_performance_order_overall` p
    -- Sumamos este JOIN para traducir el country_code al country_id
    LEFT JOIN `peya-bi-tools-pro.il_core.dim_country` dc
        ON p.country_code = dc.country_code 
    WHERE p.order_status="CONFIRMED"
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