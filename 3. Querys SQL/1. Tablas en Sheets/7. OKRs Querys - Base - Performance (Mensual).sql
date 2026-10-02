DECLARE query_name STRING DEFAULT '7. OKRs Querys - Base - Performance (Mensual)';

SELECT *
FROM `peya-food-and-groceries.automated_tables_reports.dmart_orders_okrs`
WHERE Month >= '2024-01-01'
  AND country_name <> 'Venezuela'