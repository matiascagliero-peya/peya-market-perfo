DECLARE query_name STRING DEFAULT '2. Planning - Base - Supply';

-- Sheets Name: 1. ET - Planning (12 - Planning Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1RmOQIQNuIy_9UiBxz1M1TF4q03RkYOx-BEO2jK4kWKc


with sku_lfc as (select
mes,
country_code as country_code,
(sum(potential_sales_exp)*-1)/SUM(net_sales_eur) as expire_shrinkage_pvp,
(SUM(total_amount_net_with_discount_eur)-SUM(total_amount_sold_net_eur))/sum(net_sales_eur) as precio_real_menos_pvp,
sum(net_sales_eur) net_sales_eur, #NET SALES (TOTALES PAIS)
sum(total_amount_sold_net_eur) as total_amount_sold_net_eur, #EXPIRING SOON POTENTIAL GMV
sum(total_amount_net_with_discount_eur) as total_amount_net_with_discount_eur #EXPIRING SOON NET SALES

from
`peya-delivery-and-support.automated_tables_reports.dmarts_sku_lifecycle_monitor`

--where country_code = 'ar'
group by 1,2
order by 1 desc), 

slowmovers as (SELECT
DATE_TRUNC(last_day_month,month) as month,
country_code as country_code,
COUNT (DISTINCT(if(Type_SM="SM",SKU_WH_ID,null)))/COUNT (DISTINCT(store_name)) as nominator_sm,
COUNT (DISTINCT(if(Type_SM="ZM",SKU_WH_ID,null)))/COUNT (DISTINCT(store_name)) as nominator_zm,
sum(avg_is)/COUNT (DISTINCT(store_name)) as denominator,
FROM `peya-delivery-and-support.automated_tables_reports.dmarts_slowmovers_regional_2023_H2`
WHERE region NOT IN ("DC")
--AND country_code = 'ar'
GROUP BY 1,2)

select 
mes,
CASE
 WHEN l.country_code ="ar" THEN "Argentina" 
  WHEN l.country_code ="bo" THEN  "Bolivia" 
  WHEN l.country_code ="cl" THEN "Chile" 
  WHEN l.country_code ="cr" THEN "Costa Rica"
  WHEN l.country_code ="do" THEN "Republica Dominicana"
  WHEN l.country_code ="ec" THEN "Ecuador"
  WHEN l.country_code ="sv" THEN "El Salvador"
  WHEN l.country_code ="gt" THEN "Guatemala" 
  WHEN l.country_code ="hn" THEN "Honduras" 
  WHEN l.country_code ="ni" THEN "Nicaragua" 
  WHEN l.country_code ="pa" THEN "Panama" 
  WHEN l.country_code ="py" THEN "Paraguay" 
  WHEN l.country_code ="pe" THEN "Peru"
  WHEN l.country_code ="uy" THEN "Uruguay" 
  WHEN l.country_code ="ve" THEN "Venezuela" 
  END as country_name,
sum(expire_shrinkage_pvp) as expire_shrinkage_pvp ,
sum(precio_real_menos_pvp) as precio_real_menos_pvp,
sum(nominator_sm) as nominator_sm,
sum(nominator_zm) as nominator_zm,
sum(denominator) as denominator,

from sku_lfc l
left join slowmovers s on s.month = l.mes AND s.country_code = l.country_code
where mes >= '2024-01-01'
group by 1,2
order by 1 desc, 2