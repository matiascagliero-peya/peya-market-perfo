DECLARE query_name STRING DEFAULT '1. Users History - Base - Performance (Monthly Type)';

SELECT * 
FROM `peya-food-and-groceries.automated_tables_reports.frank_user_type_monthly`
WHERE Mes >= '2026-01-01'
  AND Mes < '2027-01-01'
  -- Excluye países no deseados (aprovecha CLUSTER BY country)
  AND country NOT IN ('Venezuela', 'Costa Rica')
  -- Excluye usuarios de la plataforma que nunca compraron en Market (reduce drásticamente el peso)
  AND Market_Actual_Type != 'Never Active'