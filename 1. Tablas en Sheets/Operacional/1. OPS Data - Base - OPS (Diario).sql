DECLARE query_name STRING DEFAULT '1. OPS Data - Base - OPS (Diario)';

SELECT *
FROM `peya-food-and-groceries.automated_tables_reports.ops_daily_data`
ORDER BY date DESC, Country_en ASC;