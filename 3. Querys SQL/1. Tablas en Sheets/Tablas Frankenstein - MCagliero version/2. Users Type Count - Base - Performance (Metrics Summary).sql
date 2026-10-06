DECLARE query_name STRING DEFAULT '2. Users Type Count - Base - Performance (Metrics Summary)';

SELECT *
FROM `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
WHERE country NOT IN ('Venezuela', 'Costa Rica')
ORDER BY Mes DESC, country, users_count DESC;
