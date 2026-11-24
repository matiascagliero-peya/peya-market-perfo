DECLARE query_name STRING DEFAULT '1. Analitycs - Base - Finance (Forecast America)';

-- Sheets Name: 1. IT - Analitycs (16 - Analitycs)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1MeXHCeDGOkS7WIztOeWAD1WkwvuFOW_Mr-d1zdnoYww

SELECT * 
FROM `peya-fraud-and-fintech.group_finance_data.fact_dmart_forecast_america`
where f_month_date>= '2026-01-01'
and scenario like ('%BE08%')