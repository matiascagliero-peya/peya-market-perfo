DECLARE query_name STRING DEFAULT '1. Analitycs - Base - Finance (Forecast America)';
SELECT * 
FROM `peya-fraud-and-fintech.group_finance_data.fact_dmart_forecast_america`
where f_month_date>= '2026-01-01'
and scenario like ('%BE08%')