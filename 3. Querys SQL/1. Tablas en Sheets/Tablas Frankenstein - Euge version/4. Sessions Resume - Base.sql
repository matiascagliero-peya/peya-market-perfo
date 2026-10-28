DECLARE query_name STRING DEFAULT '4. Sessions Resume - Base';

-- Sheets Name: 1. ET - Sessions Resume (3 - Sessions & CVR)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1F4SltNDW-xuEoRzIeWkxjtBH91GzQoz8KrqW0aGQyrQ


-- 4. Sessions Resume - Base
WITH partners AS (
    SELECT DISTINCT
        vendor_id
    FROM 
        `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` 
    WHERE 
        order_date >= '2025-01-01'
)

SELECT
    EXTRACT(YEAR FROM date) AS year,
    DATE_TRUNC(date, MONTH) AS month, 
    IF(country_name_en = 'Dominican Republic', 'Republica Dominicana', country_name_en) AS country_name_en,
    
    -- MÉTRICAS TOTALES (Sin importar el filtro Double Ya)
    SUM(funnel_shop_details)     AS total_sessions_shop_details,
    SUM(funnel_shop_add_cart)    AS total_sessions_shop_add_cart,
    SUM(funnel_shop_checkout)    AS total_sessions_shop_checkout,
    SUM(funnel_shop_transaction) AS total_sessions_shop_transaction,
    SAFE_DIVIDE(
        SUM(funnel_shop_transaction), 
        SUM(funnel_shop_details)
    ) AS CVR3_dmart,

-- MÉTRICAS ESPECÍFICAS DOUBLE YA (Solo cuando el flag es 0 o NULL)
    SUM(IF(IFNULL(funnel_shop_double_ya, 0) = 0, funnel_shop_details, 0))     AS sessions_shop_details_non_dmart,
    SUM(IF(IFNULL(funnel_shop_double_ya, 0) = 0, funnel_shop_add_cart, 0))    AS sessions_shop_add_cart_non_dmart,
    SUM(IF(IFNULL(funnel_shop_double_ya, 0) = 0, funnel_shop_checkout, 0))    AS sessions_shop_checkout_non_dmart,
    SUM(IF(IFNULL(funnel_shop_double_ya, 0) = 0, funnel_shop_transaction, 0)) AS sessions_shop_transaction_non_dmart,
    
    SAFE_DIVIDE(
        SUM(IF(IFNULL(funnel_shop_double_ya, 0) = 0, funnel_shop_transaction, 0)),  
        SUM(IF(IFNULL(funnel_shop_double_ya, 0) = 0, funnel_shop_details, 0))
    ) AS CVR3_non_dmart

FROM 
    `peya-bi-tools-pro.il_sessions.perseus_fact_partner_funnel` fp
INNER JOIN 
    partners ON CAST(fp.partner_id AS STRING) = partners.vendor_id
LEFT JOIN 
    `peya-bi-tools-pro.il_core.dim_country` dc ON fp.country_id = dc.country_id
WHERE 
    date >= '2025-01-01'
GROUP BY 
    ALL;