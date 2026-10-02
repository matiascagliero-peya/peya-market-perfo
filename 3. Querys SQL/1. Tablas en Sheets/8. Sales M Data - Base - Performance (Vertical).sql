WITH fdf AS (
        SELECT
            fact_orders__country.country_name  AS country_name,
            fact_orders__country.country_code  AS country_code,
            f.registered_date,
            dim_partner.business_type.business_type_name AS business_name,
            COUNT(DISTINCT CASE WHEN f.order_status = 'CONFIRMED' THEN f.order_id END) AS confirmed_orders,
            COUNT(DISTINCT CASE WHEN f.order_status = 'CONFIRMED' AND f.shipping_amount_no_discount = 0 AND f.pickup = FALSE THEN   f.order_id ELSE NULL END) AS DF0,
    COUNT(distinct CASE WHEN f.order_status = 'CONFIRMED' AND dps.is_df_discount_basket_value_deal = TRUE and f.pickup = false then f.order_id else null end) as DF0_BV,
            COUNT(DISTINCT case when  f.confirmed_order_with_voucher_discount = 1 AND f.order_status = 'CONFIRMED' then f.order_id end) AS voucher_orders,
            COUNT(DISTINCT(CASE WHEN f.confirmed_order_with_voucher_discount = 1 AND f.order_status = 'CONFIRMED' THEN f.order_id
                                WHEN f.order_status  = 'CONFIRMED' and  f.shipping_amount_no_discount  = 0 AND f.pickup = FALSE THEN f.order_id END)) AS Incentivized_Orders,
        FROM `peya-bi-tools-pro.il_core.fact_orders`  AS f
        -- LEFT JOIN UNNEST (f.details) as fact_orders_details
        LEFT JOIN UNNEST([f.country]) as fact_orders__country
        LEFT JOIN `peya-bi-tools-pro.il_core.dim_partner` AS dim_partner ON dim_partner.partner_id=f.restaurant.id
        LEFT JOIN `peya-bi-tools-pro.il_core.dim_country`  AS dim_country ON f.country_id = dim_country.country_id
        LEFT JOIN `peya-data-origins-pro.cl_hurrier.dps_sessions_mapped_to_orders` dps ON CAST(f.order_id as string)=dps.platform_order_code
        WHERE (f.registered_date ) BETWEEN date_trunc(date_sub(current_date()-1, interval 3 MONTH), month) AND current_date ()-1
            AND (dim_partner.is_darkstore )
            AND ((f.country_id ) > 0 OR (f.country_id ) IS NULL)
            AND lower(fact_orders__country.country_code) = "do"
            AND ((f.restaurant.id ) > 0 OR (f.restaurant.id ) IS NULL)
            AND f.order_status  = 'CONFIRMED'
        GROUP BY 1,2,3,4
        ORDER BY 3,5 desc, 1
)
SELECT
    order_date,
    EXTRACT (ISOWEEK FROM order_date) AS week,
    d.country_name,
    vertical,
    fdf.DF0,
    --city_name,
    COUNT(DISTINCT d.order_id) AS Total_Orders,
    SUM(total_amount_sold_net_lc) as Total_Sales_wo_VAT,
    SUM(pcm_discount_amount_lc/(1+vat_pct)) as Discounts,
    SUM(total_amount_sold_net_lc-(pcm_discount_amount_lc/(1+vat_pct))) as Total_Sales_Net,
    SUM(total_amount_sold_net_lc-(pcm_discount_amount_lc/(1+vat_pct)))/COUNT(DISTINCT d.order_id) AS AFV_wo_VAT,
    COUNT(DISTINCT (CASE WHEN pcm_discount_amount_lc > 0 then sku_id end)) as total_skus_with_discount,
    SUM(fulfilled_quantity)/COUNT(DISTINCT d.order_id) as Basket_Size,
    SUM(fulfilled_quantity) as Units_Sold,
    SUM(total_cogs_sold_net_lc) as Total_COGS,
    SUM(CASE WHEN pcm_discount_amount_lc > 0 THEN total_amount_net_with_discount_lc END) as net_sales_dinamicas,
    SUM(total_amount_sold_net_eur) as Total_Sales_wo_VAT_eur,
    SUM(pcm_discount_amount_eur/(1+vat_pct)) as Discounts_eur,
    SUM(total_amount_sold_net_eur-(pcm_discount_amount_eur/(1+vat_pct))) as Total_Sales_Net_eur,
    SUM(total_amount_sold_net_eur-(pcm_discount_amount_eur/(1+vat_pct)))/COUNT(DISTINCT d.order_id) AS AFV_wo_VAT_eur,
    SUM(total_cogs_sold_net_eur) as Total_COGS_eur,
    SUM(CASE WHEN pcm_discount_amount_eur > 0 THEN total_amount_net_with_discount_eur END) as net_sales_dinamicas_eur,
    fdf.DF0_BV,
    fdf.voucher_orders,
    fdf.Incentivized_Orders,
    SUM(CASE WHEN pcm_discount_subtype = "multi-buy" THEN total_amount_net_with_discount_lc END) multi_buy_sales_lc,
    SUM(CASE WHEN pcm_discount_subtype = "mix & match" THEN total_amount_net_with_discount_lc END) mixmatch_sales_lc,
    SUM(CASE WHEN pcm_discount_subtype = "percentageDiscount" THEN total_amount_net_with_discount_lc END) percentage_sales_lc,
    SUM(CASE WHEN pcm_discount_subtype = "multi-buy" OR pcm_discount_subtype = "mix & match" THEN total_amount_net_with_discount_eur END) multi_buy_sales_eur,
    SUM(CASE WHEN pcm_discount_subtype = "percentageDiscount" THEN total_amount_net_with_discount_eur END) percentage_sales_eur
FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` d
-- INNER JOIN `peya-data-origins-pro.cl_core.orders` d ON SAFE_CAST(o.order_id AS INT64) = d.id
--     AND DATE(d.registeredDate) BETWEEN date_from AND date_to
INNER JOIN `peya-bi-tools-pro.il_core.fact_orders` f ON DATE(f.registered_date) >= date_trunc(date_sub(current_date()-1, interval 3 MONTH), month) AND DATE(d.order_date) >= date_trunc(date_sub(current_date()-1, interval 3 MONTH), month) AND SAFE_CAST(d.order_id AS INT64) = f.order_id
LEFT JOIN fdf ON fdf.country_code = UPPER(d.country_code) AND fdf.registered_date = d.order_date AND fdf.business_name = d.vertical
WHERE order_date BETWEEN date_trunc(date_sub(current_date()-1, interval 3 MONTH), month) AND current_date ()-1
--AND vertical = "Kiosks"
--AND order_status IN ('sent')
AND d.state = "CONFIRMED"
AND d.store_name NOT IN ("RD_12_Torre OV", "PA_9_Midtown", "SV_6_Torre Futura", "EC_17_TiendaPick-Up Oficina", "PE_3_PuntaHermosa","BO_19_Truck", "UY_15_Eventos", "PE_24_FILO")
GROUP BY 1,2,3,4,5, DF0, DF0_BV, voucher_orders, Incentivized_Orders
ORDER BY 1 DESC, 2, 3