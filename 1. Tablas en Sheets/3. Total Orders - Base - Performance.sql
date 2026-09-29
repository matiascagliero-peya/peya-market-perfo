-- 3. Total Orders - Base - Performance
DECLARE query_name STRING DEFAULT '3. Total Orders - Base - Performance';
DECLARE date_from DATE DEFAULT '2024-12-01'; 
DECLARE date_to DATE DEFAULT CURRENT_DATE() - 1;

WITH
    AAA AS (
        SELECT DISTINCT
            COALESCE(cp.franchise, t.franchise) AS franchise,
            COALESCE(cp.partner_id, t.partner_id) AS partner_id,
            COALESCE(cp.clasificacion, t.clasificacion) AS clasificacion
        FROM `peya-data-origins-pro.cl_qcommerce.partners_aaa` cp
        FULL JOIN `peya-food-and-groceries.automated_tables_reports.partners_aaa_temporary` t 
            ON t.partner_ID = cp.partner_id
    ),
    darkstores AS (
        SELECT DISTINCT partner_id
        FROM `peya-datamarts-pro.dm_dmarts.dim_partner_darkstore`
    )
SELECT
    DATE_TRUNC(o.registered_date, MONTH) AS Month,
    FORMAT_DATE('%G-%V', o.registered_date) AS Week,
    o.country.country_name_en AS country_name,
    o.business_type.business_type_name,
    
    COUNT(DISTINCT IF(d.partner_id IS NOT NULL, o.order_id, NULL)) AS dmarts_orders,
    COUNT(DISTINCT IF(d.partner_id IS NOT NULL AND o.business_type.business_type_name = 'Restaurant', o.order_id, NULL)) AS dmarts_restaurant_orders,
    COUNT(DISTINCT IF(d.partner_id IS NULL AND o.business_type.business_type_name NOT IN ('Restaurant', 'Courier', 'Courier Business', 'Coffee'), o.order_id, NULL)) AS qc_orders,
    COUNT(DISTINCT IF(d.partner_id IS NULL AND o.business_type.business_type_name IN ('Restaurant', 'Courier', 'Courier Business', 'Coffee'), o.order_id, NULL)) AS food_orders,
    COUNT(DISTINCT o.order_id) AS confirmed_orders,
    COUNT(DISTINCT IF(d.partner_id IS NULL AND aaa.clasificacion IN ('Small Supermarket', 'Supermarket'), o.order_id, NULL)) AS AAA_orders

FROM `peya-bi-tools-pro.il_core.fact_orders` AS o
LEFT JOIN darkstores d 
    ON d.partner_id = o.restaurant.id
LEFT JOIN AAA aaa 
    ON aaa.partner_id = o.restaurant.id
WHERE o.registered_date BETWEEN date_from AND date_to
    AND o.order_status = 'CONFIRMED'
GROUP BY 1, 2, 3, 4
ORDER BY 1, 2, 3, 4;