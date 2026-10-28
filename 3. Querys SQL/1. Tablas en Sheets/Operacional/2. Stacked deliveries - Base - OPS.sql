DECLARE query_name STRING DEFAULT '2. Stacked deliveries - Base - OPS';

-- Sheets Name: 1. ET - Stacked deliveries (8 - Stacked deliveries)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1v5Ch2HIK3MJTX1aR9iWiNbxbtMUjYLROCiQz4DqzjNk


DECLARE fecha_inicio DATE DEFAULT '2024-01-01';

WITH base_deliveries AS (
    SELECT
        DATE_TRUNC(DATE(o.created_at, o.timezone), MONTH) as month_date,
        IF(dc.country_name_en = 'Dominican Republic', 'Republica Dominicana', dc.country_name_en) AS country,

        d.stacked_deliveries_rank,
        d.timings.actual_delivery_time / 60 as dt_minutes,
        d.id as delivery_id

    FROM `peya-data-origins-pro.cl_hurrier.orders_v2` AS o
    INNER JOIN UNNEST(o.rider.deliveries) as d
    
    LEFT JOIN `peya-bi-tools-pro.il_core.dim_country` AS dc 
        ON UPPER(o.rider.country_code) = UPPER(dc.country_code)

    WHERE 
        o.created_date >= fecha_inicio 
        AND DATE(o.created_at, o.timezone) >= fecha_inicio
        AND o.rider.vendor.vertical_type = 'darkstores'
        AND d.stacked_deliveries > 0
        AND o.is_preorder IS FALSE
        AND d.delivery_status = 'completed'
) 

SELECT
    month_date,
    country,
    sum(case when stacked_deliveries_rank = 1 then dt_minutes end) as time_stack_1_orders, 
   count(distinct case when stacked_deliveries_rank = 1 then delivery_id end) as deliverys_stack_1_orders, 
   SAFE_DIVIDE(sum(case when stacked_deliveries_rank = 1 then dt_minutes end),count(distinct case when stacked_deliveries_rank = 1 then delivery_id end)) AS DT_stack_1, 

    sum(case when stacked_deliveries_rank = 2 then dt_minutes end) as time_stack_2_orders, 
    count(distinct case when stacked_deliveries_rank = 2 then delivery_id end) as deliverys_stack_2_orders,
    SAFE_DIVIDE(sum(case when stacked_deliveries_rank = 2 then dt_minutes end),count(distinct case when stacked_deliveries_rank = 2 then delivery_id end)) AS DT_stack_2, 

    COUNT(DISTINCT delivery_id) as total_deliveries
FROM base_deliveries
GROUP BY 1, 2
ORDER BY 1 DESC, 2 ASC, 3 ASC;