DECLARE query_name STRING DEFAULT '3. Dmarts Unprofitable Margin';

-- Fecha manual
--- DECLARE start_date DATE DEFAULT DATE('2025-04-01');
--- DECLARE end_date DATE DEFAULT DATE('2026-03-31');

-- Fecha automátrica
DECLARE cantidad_filas INT64;
DECLARE start_date DATE;
DECLARE end_date DATE DEFAULT LAST_DAY(DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 1 MONTH));

-- ¿Cuantas filas tiene la tabla? (NULL/0 => backfill)
SET cantidad_filas = (
    SELECT row_count
    FROM `peya-food-and-groceries.automated_tables_reports.__TABLES__`
    WHERE table_id = 'dmarts_unprofitable_margin'
);

-- Backfill => ventana de 12 meses ; Incremental => reprocesa los ultimos 2 meses completos
SET start_date = IF(
    cantidad_filas IS NULL OR cantidad_filas = 0,
    DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 12 MONTH),
    DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 2 MONTH)
);

-- ============================================================
-- 1) Calcula el slice nuevo (tu query, sin cambios) en una temp
-- ============================================================
CREATE TEMP TABLE nuevos AS

WITH discounts AS (

  SELECT
    order_id,
    sum(pcm_discount_amount_lc) as discounts,
    sum(fulfilled_quantity) as units_sold,

    SAFE_DIVIDE(SUM(total_amount_sold_eur), SUM(total_amount_sold_net_eur)) AS vat_tax_aprox

  FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`

  WHERE order_date BETWEEN start_date AND end_date
    --AND pcm_discount_amount_lc > 0

  GROUP BY 1

), 

orders as (

  SELECT
    user.user_id,
    f.order_id as order_id,
    
    registered_date,
    location.country_name_en as country_name,
    partner.vertical_group,
    partner.vertical_type,
    user.is_user_plus,

    delivery.distance_range,
    COALESCE(delivery.distance_meters,0) AS distance_meters,

    CASE WHEN (d.discounts > 0 or null) THEN 1 ELSE 0 END as has_promo_discounts,
    CASE WHEN delivery.delivery_type = "DF0" THEN 1 ELSE 0 END is_df0,
    CASE WHEN delivery.delivery_type = "DF0" AND user.is_user_plus = TRUE THEN 1 ELSE 0 END is_df0_plus,
    CASE WHEN delivery.delivery_type = "DF0" AND user.is_user_plus = FALSE THEN 1 ELSE 0 END is_df0_campaign,
    gmv.shipping_amount_after_plus_discounts/monthly_rate_eu as shipping_amount_no_discount,
    SAFE_DIVIDE(gmv.shipping_amount_after_plus_discounts/monthly_rate_eu,vat_tax_aprox) as shipping_amount_no_discount_net,

    SAFE_DIVIDE(gmv.gfv_vendor,monthly_rate_eu) AS afv_gross,
    SAFE_DIVIDE(dmart.retail_sales,monthly_rate_eu) AS retail_sales,
    SAFE_DIVIDE(-d.discounts + dmart.back_margin,monthly_rate_eu) AS net_discounts_impact,
    SAFE_DIVIDE(ic_dmart.ic_dmart_df_plus,monthly_rate_eu) as ic_dmart_df_plus,
    COALESCE(SAFE_DIVIDE(fda.user_refund_dmart,monthly_rate_eu),0) AS user_refund_dmart,
    SAFE_DIVIDE(gpo.gpo,monthly_rate_eu) AS total_gpo,
    SAFE_DIVIDE(dmart.shopper_cost_dmart,monthly_rate_eu) As shopper_cost,
   d.units_sold As unit_sold,
   SAFE_DIVIDE(dmart.back_margin, monthly_rate_eu) as back_margin,

CASE WHEN (COALESCE(
       SAFE_DIVIDE( (dmart.retail_sales + dmart.cogs +dmart.back_margin + dmart.wdc_allowance +  dmart.wdc_cost+ dmart.wdc_personnel_cost + dmart.gross_income_tax + dmart.shrinkage + dmart.packaging + dmart.others_variable_costs )
       ,dmart.retail_sales) ,0) <= 0.15)
       THEN 1 
       ELSE 0
       END AS low_contr_margin,

    SAFE_DIVIDE(gpo.gpo,monthly_rate_eu) as gpo,
    SAFE_DIVIDE(gpo.gpo_fl,monthly_rate_eu) AS gpo_fl,

    CASE WHEN gpo.gpo < 0
      THEN 1 ELSE 0 END AS is_unprofitable_gpo,

    CASE WHEN gpo.gpo_fl < 0
      THEN 1 ELSE 0 END AS is_unprofitable_gpoFL,




  FROM `peya-datamarts-pro.dm_order_profitability.fact_order_profitability` f

  LEFT JOIN discounts d
    ON CAST(f.order_id AS STRING) = d.order_id
  
  WHERE registered_date BETWEEN start_date AND end_date
  --  AND partner.vertical_group = 'D-Mart'
    AND order_status = 'CONFIRMED'


)

select
registered_date as mes,
    o.country_name country,
    o.order_id as ordenes,
    master_category_parent_english as category,
    supplier_name as supplier,
    product_name as product, 
    delivered_quantity AS cantidad_productos,
    total_amount_net_with_discount_eur AS net_sales,
    total_cogs_sold_net_eur AS cogs,
    pcm_discount_amount_net_eur AS net_discounts,
    front_margin_eur AS front_margin_eur,
    total_amount_net_with_discount_eur - total_cogs_sold_net_eur + pcm_discount_amount_net_eur AS teoric_margin_net_eur,
    gpo AS gpo,

     CASE 
    WHEN o.back_margin IS NOT NULL AND pcm_discount_amount_net_eur > 0 
    THEN (pcm_discount_amount_net_eur / SUM(pcm_discount_amount_net_eur) OVER (PARTITION BY o.order_id)) * o.back_margin 
    ELSE 0 
  END AS prorated_back_margin


from orders o 
LEFT JOIN `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` co

ON CAST(o.order_id AS string) = co.order_id

where   

is_unprofitable_gpo = 1 
AND user_refund_dmart >= 0 AND is_user_plus = FALSE AND is_df0 = 0 AND has_promo_discounts = 1 AND ((gpo - net_discounts_impact) <= 0 or (gpo - net_discounts_impact) is null) AND low_contr_margin = 1
AND state= 'CONFIRMED'
AND vertical_group = 'D-Mart'
--AND business_category_salesforce = 'kiosks'
--AND o.country_name = 'Argentina'
AND co.order_date BETWEEN start_date AND end_date;

-- ============================================================
-- 2) Crea la tabla (schema + particion) SOLO si no existe
-- ============================================================
CREATE TABLE IF NOT EXISTS `peya-food-and-groceries.automated_tables_reports.dmarts_unprofitable_margin`
PARTITION BY DATE_TRUNC(mes, MONTH)
CLUSTER BY country
AS SELECT * FROM nuevos WHERE FALSE;

-- ============================================================
-- 3) Reemplaza solo los meses reprocesados (idempotente)
-- ============================================================
BEGIN TRANSACTION;

  DELETE FROM `peya-food-and-groceries.automated_tables_reports.dmarts_unprofitable_margin`
  WHERE mes >= start_date;

  INSERT INTO `peya-food-and-groceries.automated_tables_reports.dmarts_unprofitable_margin`
  SELECT * FROM nuevos;

COMMIT TRANSACTION;