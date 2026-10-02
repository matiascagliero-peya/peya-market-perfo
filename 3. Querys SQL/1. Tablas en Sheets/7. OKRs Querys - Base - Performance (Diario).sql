DECLARE query_name STRING DEFAULT '7. OKRs Querys - Base - Performance (Diario)';

SELECT *
FROM `peya-food-and-groceries.automated_tables_reports.dmart_okrs_daily`
WHERE `COUNTRY_nAME` NOT IN ('Venezuela', 'Costa Rica');