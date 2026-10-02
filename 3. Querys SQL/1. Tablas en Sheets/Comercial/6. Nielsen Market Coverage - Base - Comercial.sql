DECLARE query_name STRING DEFAULT '6. Nielsen Market Coverage - Base - Comercial';

WITH szm_stock as (
  SELECT
    month,
    country_code,
    SAFE_DIVIDE(SUM(CASE WHEN sku_efficiency != "Other" THEN month_end_stock_value_eur ELSE 0 END), SUM(month_end_stock_value_eur)) as szm_stock_pct,
    SUM(CASE WHEN sku_efficiency != "Other" THEN month_end_stock_value_eur ELSE 0 END) as szm_stock_eur,
    SUM(month_end_stock_value_eur) as total_stock_eur
  FROM `peya-delivery-and-support.automated_tables_reports.dmarts_clearence_crusader_monitor`
  GROUP BY 1,2
),
gmv as (
  SELECT
    DATE_TRUNC(order_date,month) as month,
    country_code,
    SUM(total_amount_sold_net_eur) as gmv_eur
  FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
  WHERE order_date >= "2024-06-01"
  GROUP BY 1,2
)

SELECT
  base.month,
  COALESCE(dc.country_name_en, UPPER(base.country_code)) as country_code,
  SUM(base.net_sales_market) as market_coverage_total,
  SUM(IF(base.activos_por_tienda_con_stock = 1, base.net_sales_market, 0)) as market_coverage_captured,
  szm.total_stock_eur,
  szm.szm_stock_eur,
  g.gmv_eur
FROM `peya-food-and-groceries.automated_tables_reports.base_market_assortment_coverage` base
LEFT JOIN szm_stock szm ON base.country_code = szm.country_code AND base.month = szm.month
LEFT JOIN gmv g ON base.country_code = g.country_code AND base.month = g.month
LEFT JOIN `peya-bi-tools-pro.il_core.dim_country` dc ON LOWER(base.country_code) = LOWER(dc.country_code)
WHERE base.month < DATE_TRUNC(current_date, MONTH)
GROUP BY 1,2,5,6,7
ORDER BY month DESC, country_code ASC;
