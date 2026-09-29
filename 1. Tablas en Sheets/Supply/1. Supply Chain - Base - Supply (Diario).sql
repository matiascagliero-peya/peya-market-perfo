DECLARE query_name STRING DEFAULT '1. Supply Chain - Base - Supply (Diario)';

-- 1. Supply Chain - Base - Supply
SELECT *
FROM `peya-food-and-groceries.automated_tables_reports.absolute_okrs_supply`
ORDER BY fecha, country_name;