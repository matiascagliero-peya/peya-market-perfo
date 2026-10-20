DECLARE query_name STRING DEFAULT '6. Nielsen Market Coverage - Base - Comercial';

WITH szm_stock AS (
  SELECT
    month,
    LOWER(country_code) AS country_code,
    SUM(month_end_stock_value_eur) AS total_stock_eur,
    SUM(CASE WHEN sku_efficiency != 'Other' THEN month_end_stock_value_eur ELSE 0 END) AS szm_stock_eur
  FROM `peya-delivery-and-support.automated_tables_reports.dmarts_clearence_crusader_monitor`
  GROUP BY 1, 2
),

nielsen AS (
  SELECT
    month,
    LOWER(country_code) AS country_code,
    SAFE_DIVIDE(SUM(IF(activos_por_tienda_con_stock = 1, net_sales_market, 0)), SUM(net_sales_market)) AS market_coverage,
    SAFE_DIVIDE(SUM(net_sales_peya), SUM(net_sales_market)) AS retail_market_share
  FROM `peya-food-and-groceries.automated_tables_reports.base_market_assortment_coverage`
  GROUP BY 1, 2
),

sales AS (
  SELECT
    DATE_TRUNC(order_date, MONTH) AS month,
    LOWER(country_code) AS country_code,
    SUM(total_amount_net_with_discount_eur) AS net_sales
  FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
  WHERE order_date >= '2024-06-01'
  GROUP BY 1, 2
),

all_keys AS (
  SELECT month, country_code FROM szm_stock
  UNION DISTINCT
  SELECT month, country_code FROM nielsen
),

country_level AS (
  SELECT
    k.month,
    COALESCE(dc.country_name, UPPER(k.country_code)) AS country_code,
    n.market_coverage,
    n.retail_market_share,
    szm.total_stock_eur,
    szm.szm_stock_eur,
    s.net_sales
  FROM all_keys k
  LEFT JOIN nielsen n
    ON k.month = n.month AND k.country_code = n.country_code
  LEFT JOIN szm_stock szm
    ON k.month = szm.month AND k.country_code = szm.country_code
  LEFT JOIN sales s
    ON k.month = s.month AND k.country_code = s.country_code
  LEFT JOIN (
    SELECT LOWER(country_code) AS country_code, ANY_VALUE(country_name_en) AS country_name
    FROM `peya-bi-tools-pro.il_core.dim_country`
    GROUP BY 1
  ) dc ON k.country_code = dc.country_code
)

-- Resultados por país
SELECT
  month,
  country_code,
  market_coverage,
  retail_market_share,
  total_stock_eur,
  szm_stock_eur,
  net_sales
FROM country_level

UNION ALL

-- Fila LATAM consolidada (ponderada por Net Sales)
SELECT
  month,
  'LATAM' AS country_code,
  SAFE_DIVIDE(SUM(market_coverage * net_sales), SUM(IF(market_coverage IS NOT NULL, net_sales, 0))) AS market_coverage,
  SAFE_DIVIDE(SUM(retail_market_share * net_sales), SUM(IF(retail_market_share IS NOT NULL, net_sales, 0))) AS retail_market_share,
  SUM(total_stock_eur) AS total_stock_eur,
  SAFE_DIVIDE(SUM(szm_stock_eur), SUM(total_stock_eur)) AS szm_stock_eur,
  SUM(net_sales) AS net_sales
FROM country_level
GROUP BY 1

ORDER BY
  month DESC,
  country_code ASC;
