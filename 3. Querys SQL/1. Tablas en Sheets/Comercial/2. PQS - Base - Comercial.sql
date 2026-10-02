DECLARE query_name STRING DEFAULT '2. PQS - Base - Comercial';

SELECT

        date_month, 
        country_name,
        sum(dd_gpv_from_promo_eur) as gpv_from_promo_eur,
        sum(country_gpv_eur) as gpv_eur,
        sum(dd_total_discount_eur) as total_discount,
        -- promo contribution gpv_from_promo_eur / gpv_eur
        SAFE_DIVIDE( sum(dd_gpv_from_promo_eur),sum(dd_gpv_eur)) AS promo_contribution,
        -- Gross Discounts
        SAFE_DIVIDE(SUM(dd_total_discount_eur),(SUM(dd_total_discount_eur)+sum(dd_gpv_eur))) as gross_discounts,


        -- promo atractivenes
        safe_divide(SUM(w_promo_attractiveness),sum(dd_gpv_eur)) as promo_atractiveness,
        --weighted_availability

        safe_divide(SUM(w_weighted_availability),sum(dd_gpv_eur)) as weighted_availability,
        -- share_effective_promos

        safe_divide(SUM(w_share_effective_promos),sum(dd_gpv_eur)) as share_effective_promos,

        -- gpv_uplift
        safe_divide(SUM(w_net_gpv_uplift),sum(dd_gpv_eur)) as net_gpv_uplift,


FROM  `fulfillment-dwh-production.curated_data_shared_dmart.tableau_promo_quality_score_v3`
WHERE date_month >= '2025-01-01'
AND management_entity_grouped = 'Pedidosya'

group by 1,2
order by 1,2 desc