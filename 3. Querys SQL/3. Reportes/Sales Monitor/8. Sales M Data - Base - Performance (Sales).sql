-- DECLARE date_from  date DEFAULT date_trunc(date_sub(current_date()-1, interval 2 MONTH), month); --DATE_TRUNC(CURRENT_DATE(), month)
-- DECLARE date_to  date DEFAULT current_date ()-1;

WITH fdf AS (
        SELECT
            fact_orders__country.country_name  AS country_name,
            fact_orders__country.country_code  AS country_code,
            f.registered_date,
            COUNT(DISTINCT case when  f.order_status    = 'CONFIRMED' then   f.order_id   end) AS confirmed_orders,
            COUNT(DISTINCT case when  f.order_status = 'CONFIRMED' then   f.order_id   end) - COUNT(DISTINCT case when  f.order_status  = 'CONFIRMED' and f.pickup = FALSE and  f.shipping_amount_no_discount   > 0  then   f.order_id   end) AS DF0,
            -- COUNT(distinct CASE WHEN f.order_status = 'CONFIRMED' and f.shipping_amount_no_discount=0 AND (dps.vendor_price_scheme_type!="Campaign") and f.pickup = false then f.order_id else null end) as DF0_BV,
            COUNT(DISTINCT CASE WHEN f.order_status = 'CONFIRMED' AND dps.is_df_discount_basket_value_deal = TRUE AND f.pickup = FALSE THEN f.order_id END) as DF0_BV,
            COUNT(DISTINCT case when  f.confirmed_order_with_voucher_discount = 1 AND f.order_status = 'CONFIRMED' then f.order_id end) AS voucher_orders,
            COUNT(DISTINCT(CASE
              WHEN f.confirmed_order_with_voucher_discount = 1 AND f.order_status = 'CONFIRMED'
                THEN f.order_id
              WHEN f.order_status  = 'CONFIRMED' and  f.shipping_amount_no_discount  = 0 and f.pickup = FALSE
                THEN f.order_id
            END)) AS Incentivized_Orders,

        FROM `peya-bi-tools-pro.il_core.fact_orders`  AS f
        -- LEFT JOIN UNNEST (f.details) as fact_orders_details
        LEFT JOIN UNNEST([f.country]) as fact_orders__country
        LEFT JOIN `peya-bi-tools-pro.il_core.dim_partner` AS dim_partner ON dim_partner.partner_id=f.restaurant.id
        LEFT JOIN `peya-bi-tools-pro.il_core.dim_country`  AS dim_country ON f.country_id = dim_country.country_id
        LEFT JOIN `peya-data-origins-pro.cl_hurrier.dps_sessions_mapped_to_orders` dps ON CAST(f.order_id as string)=dps.platform_order_code
        WHERE (f.registered_date ) BETWEEN date_trunc(date_sub(current_date()-1, interval 2 MONTH), month) AND current_date ()-1
            AND (dim_partner.is_darkstore )
            AND ((f.country_id ) > 0 OR (f.country_id ) IS NULL)
            AND ((f.restaurant.id ) > 0 OR (f.restaurant.id ) IS NULL)
            AND f.order_status  = 'CONFIRMED'
        GROUP BY 1,2,3
        ORDER BY 3,4 desc, 1
)

SELECT
        --EXTRACT (ISOWEEK FROM order_date) AS week,
        --EXTRACT (MONTH FROM order_date) AS month,
        --EXTRACT (YEAR FROM order_date) AS year,
        order_date AS fecha,
        o.country_name,
        o.master_category_parent_english as level_1,
        o.vertical AS vertical,
        SUM(fulfilled_quantity) as units_sold,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(total_amount_sold_lc) as total_amount_with_vat,
        SUM(total_amount_sold_net_lc) as total_amount_wo_vat,
        SUM(vat_amount_lc) as vat_amount,
        SUM(pcm_discount_amount_lc) as total_discount_with_vat,
        SUM(pcm_discount_amount_net_lc) as total_discount_wo_vat,
        SUM(total_amount_net_with_discount_lc) as net_sales,
        SUM(total_cogs_sold_net_lc) as total_cogs_wo_vat,
        SUM(pcm_qty_products_applied_discount) as units_with_discount,
        SUM(CASE WHEN pcm_discount_amount_lc > 0 THEN total_amount_net_with_discount_lc END) as net_sales_dinamicas,
        EXTRACT (ISOWEEK FROM order_date) AS week,
        SUM(total_amount_sold_eur) as total_amount_with_vat_eur,
        SUM(total_amount_sold_net_eur) as total_amount_wo_vat_eur,
        SUM(vat_amount_eur) as vat_amount_eur,
        SUM(pcm_discount_amount_eur) as total_discount_with_vat_eur,
        SUM(pcm_discount_amount_net_eur) as total_discount_wo_vat_eur,
        SUM(total_amount_net_with_discount_eur) as net_sales_eur,
        SUM(total_cogs_sold_net_eur) as total_cogs_wo_vat_eur,
        SUM(CASE WHEN pcm_discount_amount_eur > 0 THEN total_amount_net_with_discount_eur END) as net_sales_dinamicas_eur,
        fdf.DF0,
        fdf.DF0_BV,
        fdf.voucher_orders,
        fdf.Incentivized_Orders,

        -- TYPE DISCOUNT
        SUM(CASE WHEN pcm_discount_subtype = "multi-buy" THEN total_amount_net_with_discount_lc END) multi_buy_sales_lc,
        SUM(CASE WHEN pcm_discount_subtype = "percentageDiscount" THEN total_amount_net_with_discount_lc END) percentage_sales_lc,
        SUM(CASE WHEN pcm_discount_subtype = "mix & match" THEN total_amount_net_with_discount_lc END) mixmatch_sales_lc,
        
        SUM(CASE WHEN pcm_discount_subtype = "multi-buy" OR pcm_discount_subtype = "mix & match" THEN total_amount_net_with_discount_eur END) multibuy_sales_eur,
        SUM(CASE WHEN pcm_discount_subtype = "percentageDiscount" THEN total_amount_net_with_discount_eur END) percentage_sales_eur,
        SUM(CASE WHEN pcm_discount_subtype = "mix & match" THEN total_amount_net_with_discount_eur END) mixmatch_sales_eur,

        -- CAMPAIGN PURPOSE
        SUM(CASE WHEN campaign_purpose = "Competitiveness" THEN total_amount_net_with_discount_lc END) Competitiveness_sales_lc,
        SUM(CASE WHEN campaign_purpose = "Delisting" THEN total_amount_net_with_discount_lc END) Delisting_sales_lc,
        SUM(CASE WHEN campaign_purpose = "Expiring Soon" THEN total_amount_net_with_discount_lc END) ExpiringSoon_sales_lc,
        SUM(CASE WHEN campaign_purpose = "NMR" THEN total_amount_net_with_discount_lc END) NMR_sales_lc,
        SUM(CASE WHEN campaign_purpose = "Overstock" THEN total_amount_net_with_discount_lc END) Overstock_sales_lc,
        SUM(CASE WHEN campaign_purpose = "Trading" THEN total_amount_net_with_discount_lc END) Trading_sales_lc,

        SUM(CASE WHEN campaign_purpose = "Competitiveness" THEN total_amount_net_with_discount_eur END) Competitiveness_sales_eur,
        SUM(CASE WHEN campaign_purpose = "Delisting" THEN total_amount_net_with_discount_eur END) Delisting_sales_eur,
        SUM(CASE WHEN campaign_purpose = "Expiring Soon" THEN total_amount_net_with_discount_eur END) ExpiringSoon_sales_eur,
        SUM(CASE WHEN campaign_purpose = "NMR" THEN total_amount_net_with_discount_eur END) NMR_sales_eur,
        SUM(CASE WHEN campaign_purpose = "Overstock" THEN total_amount_net_with_discount_eur END) Overstock_sales_eur,
        SUM(CASE WHEN campaign_purpose = "Trading" THEN total_amount_net_with_discount_eur END) Trading_sales_eur,        
        
        -- Teoric Margin
        SUM(total_amount_net_with_discount_lc)-SUM(total_cogs_sold_net_lc)+SUM(pcm_discount_amount_net_lc) as teoric_margin_net_lc,
        SUM(total_amount_net_with_discount_eur)-SUM(total_cogs_sold_net_eur)+SUM(pcm_discount_amount_net_eur) as teoric_margin_net_eur,

        -- Front Margin
        SUM(total_amount_net_with_discount_lc)-SUM(total_cogs_sold_net_lc) as front_margin_lc,
        SUM(total_amount_net_with_discount_eur)-SUM(total_cogs_sold_net_eur) as front_margin_eur,
        
FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` o

LEFT JOIN fdf ON fdf.country_code = UPPER(o.country_code) AND fdf.registered_date = o.order_date

WHERE order_date BETWEEN date_trunc(date_sub(current_date()-1, interval 2 MONTH), month) AND current_date ()-1
      --AND o.country_code = 'sv'
      AND o.state = "CONFIRMED"
GROUP BY 1,2,3,4, week, DF0, DF0_BV, voucher_orders, Incentivized_Orders
ORDER BY 1 DESC,2,4 desc,6 desc