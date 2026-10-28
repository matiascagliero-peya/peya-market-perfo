DECLARE query_name STRING DEFAULT '1. Users History - Base - Performance (Monthly Activity)';

-- 1. Users History - Base - Performance
select * from  `peya-food-and-groceries.automated_tables_reports.frank_user_monthly_activity`
WHERE month >= '2026-01-01'
ORDER BY month DESC