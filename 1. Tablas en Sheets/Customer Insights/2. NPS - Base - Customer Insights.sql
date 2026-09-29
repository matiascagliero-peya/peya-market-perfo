DECLARE query_name STRING DEFAULT '2. NPS - Base - Customer Insights';

WITH country_names AS (
  -- OPTIMIZACIÓN GIGANTE: 
  -- Solo miramos los últimos 30 días de órdenes. Si un país opera hoy,
  -- tuvo al menos 1 orden este mes. No hace falta escanear años de historia.
  SELECT DISTINCT
    LOWER(country_code) AS country_code,
    country_name
  FROM 
    `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
  WHERE 
    state = 'CONFIRMED'
    AND order_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY) 
    AND country_name IS NOT NULL
),

dmart_metrics AS (
  SELECT
    DATE_TRUNC(DATE(n.recorded_at_utc), MONTH) AS month,
    c.country_name AS country,
    COUNT(n.response_id) AS total_responses,

    -- Counters per NPS group
    COUNT(CASE WHEN UPPER(n.nps_group) = 'PROMOTER' THEN 1 END) AS promoters,
    COUNT(CASE WHEN UPPER(n.nps_group) = 'PASSIVE' THEN 1 END) AS passives,
    COUNT(CASE WHEN UPPER(n.nps_group) = 'DETRACTOR' THEN 1 END) AS detractors
  FROM
    `peya-delivery-and-support.automated_tables_reports.npsgroceries_monitor` AS n
  LEFT JOIN 
    country_names AS c ON LOWER(n.countrycode) = c.country_code
  WHERE
    LOWER(n.vertical_qc) = 'dmart'
    AND n.countrycode IS NOT NULL
    -- NUEVA CONDICIÓN: Trae toda la data desde el 1 de enero de 2025
    AND DATE(n.recorded_at_utc) >= '2025-01-01'
  GROUP BY
    1, 2
)

SELECT
  month,
  country,
  total_responses AS survey_volume,
  promoters,
  passives,
  detractors,

  -- OFFICIAL NPS FORMULA (-100 to 100)
  ROUND(
    (SAFE_DIVIDE(promoters, total_responses) * 100) - 
    (SAFE_DIVIDE(detractors, total_responses) * 100), 
    2
  ) AS nps_index
FROM
  dmart_metrics
WHERE
  total_responses > 50
ORDER BY
  month DESC,
  country ASC;