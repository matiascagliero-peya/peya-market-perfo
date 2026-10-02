DECLARE query_name STRING DEFAULT '1. AQS - Base - Comercial';

WITH base_data AS (
  SELECT
    DATE_TRUNC(DATE(date_month), MONTH) AS month, 
    country_code,
    gbv,
    
    -- TUS MÉTRICAS EXACTAS
    perc_listed_target_completion,
    perc_design_compliance,
    check_efficiency,
    ultrafresh_bp,
    check_newness,              
    check_perc_availability,   
    check_book_value,          
    avg_listed_skus_check,
    final_score AS aqs_score

  FROM `fulfillment-dwh-production.curated_data_shared_dmart.assortment_quality_scorecard_v7`
  WHERE region = 'Pedidosya'
    AND granularity = 'Country'
    AND date_month >= '2024-01-01'
    AND warehouse_name IS NOT NULL
    AND warehouse_name != ""
),

country_level AS (
  SELECT
    month,
    IFNULL(country_code, 'LATAM') AS country_code,
    
    SUM(perc_listed_target_completion * gbv) / NULLIF(SUM(gbv), 0) AS perc_listed_target_completion,
    SUM(perc_design_compliance * gbv) / NULLIF(SUM(gbv), 0) AS perc_design_compliance,
    SUM(check_efficiency * gbv) / NULLIF(SUM(gbv), 0) AS check_efficiency,
    SUM(ultrafresh_bp * gbv) / NULLIF(SUM(gbv), 0) AS ultrafresh_bp,
    SUM(check_newness * gbv) / NULLIF(SUM(gbv), 0) AS check_newness,
    SUM(check_perc_availability * gbv) / NULLIF(SUM(gbv), 0) AS check_perc_availability,
    SUM(check_book_value * gbv) / NULLIF(SUM(gbv), 0) AS check_book_value,
    
    SUM(avg_listed_skus_check) AS avg_listed_skus_check,
    
    SUM(aqs_score * gbv) / NULLIF(SUM(gbv), 0) AS aqs_score

  FROM base_data
  GROUP BY month, country_code
),

latam_level AS (
  SELECT
    month,
    'LATAM' AS country_code,
    
    SUM(perc_listed_target_completion * gbv) / NULLIF(SUM(gbv), 0) AS perc_listed_target_completion,
    SUM(perc_design_compliance * gbv) / NULLIF(SUM(gbv), 0) AS perc_design_compliance,
    SUM(check_efficiency * gbv) / NULLIF(SUM(gbv), 0) AS check_efficiency,
    SUM(ultrafresh_bp * gbv) / NULLIF(SUM(gbv), 0) AS ultrafresh_bp,
    SUM(check_newness * gbv) / NULLIF(SUM(gbv), 0) AS check_newness,
    SUM(check_perc_availability * gbv) / NULLIF(SUM(gbv), 0) AS check_perc_availability,
    SUM(check_book_value * gbv) / NULLIF(SUM(gbv), 0) AS check_book_value,
    
    SUM(avg_listed_skus_check*gbv)/nullif(sum(gbv),0) AS avg_listed_skus_check,
    
    SUM(aqs_score * gbv) / NULLIF(SUM(gbv), 0) AS aqs_score

  FROM base_data
  GROUP BY month
)

-- UNIÓN FINAL (Con el orden exacto de tus índices)
SELECT 
  month,                            -- Index 0
  country_code,                     -- Index 1
  perc_listed_target_completion,    -- Index 2
  perc_design_compliance,           -- Index 3
  check_efficiency,                 -- Index 4
  ultrafresh_bp,                    -- Index 5
  check_newness,                    -- Index 6
  check_perc_availability,          -- Index 7
  check_book_value,                 -- Index 8
  avg_listed_skus_check,            -- Index 9
  aqs_score                         -- Index 10
FROM (
  SELECT * FROM country_level
  UNION ALL
  SELECT * FROM latam_level
)
ORDER BY month DESC, country_code ASC;