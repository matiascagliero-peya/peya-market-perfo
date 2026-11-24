-- Recarga rápida de sesiones en dmart_okrs_daily (2026 a la fecha)
-- Actualiza únicamente las 6 métricas de sesiones y transacciones de funnel sin reescanear pedidos ni GMV.

DECLARE start_date DATE DEFAULT DATE '2026-01-01';
DECLARE end_date   DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);

UPDATE `peya-food-and-groceries.automated_tables_reports.dmart_okrs_daily` target
SET
  total_sessions              = source.sessions,
  total_transactions          = source.transactions,
  non_double_ya_sessions      = source.sessions_non_dy,
  non_double_ya_transactions  = source.transactions_non_dy,
  double_ya_sessions          = source.sessions_dy,
  double_ya_transactions      = source.transactions_dy
FROM (
  WITH partners AS (
    SELECT
      p.country_id,
      p.partner_id
    FROM `peya-bi-tools-pro.il_core.dim_partner` p
    INNER JOIN `peya-datamarts-pro.dm_dmarts.dim_partner_darkstore` AS pd
      ON p.partner_id = pd.partner_id
    WHERE p.partner_name NOT IN (
      "RD_12_Torre OV", "PA_9_Midtown", "SV_6_Torre Futura",
      "EC_17_TiendaPick-Up Oficina", "PE_3_PuntaHermosa", "BO_19_Truck",
      "UY_15_Eventos", "PE_24_FILO", "EC_6_Oficina"
    )
  ),
  sessions_perseus AS (
    SELECT
      DATE(fp.date)       AS day,
      c.country_name      AS country_name,
      c.country_name_en   AS country_name_en,
      
      SUM(fp.funnel_shop_details)     AS sessions,
      SUM(fp.funnel_shop_transaction) AS transactions,
      
      SUM(CASE WHEN (fp.funnel_shop_double_ya = 0 OR fp.funnel_shop_double_ya IS NULL) 
          THEN fp.funnel_shop_details ELSE 0 END) AS sessions_non_dy,
      SUM(CASE WHEN (fp.funnel_shop_double_ya = 0 OR fp.funnel_shop_double_ya IS NULL) 
          THEN fp.funnel_shop_transaction ELSE 0 END) AS transactions_non_dy,
          
      SUM(CASE WHEN fp.funnel_shop_double_ya > 0 
          THEN fp.funnel_shop_details ELSE 0 END) AS sessions_dy,
      SUM(CASE WHEN fp.funnel_shop_double_ya > 0 
          THEN fp.funnel_shop_transaction ELSE 0 END) AS transactions_dy
    FROM `peya-bi-tools-pro.il_sessions.perseus_fact_partner_funnel` fp
    INNER JOIN partners
      ON fp.partner_id = partners.partner_id
     AND (fp.country_id = partners.country_id OR fp.country_id IS NULL OR fp.country_id = 0)
    INNER JOIN `peya-bi-tools-pro.il_core.dim_country` c
      ON partners.country_id = c.country_id
    WHERE DATE(fp.date) BETWEEN start_date AND end_date
    GROUP BY 1, 2, 3
  )
  SELECT * FROM sessions_perseus
) source
WHERE target.day = source.day
  AND (target.country_name = source.country_name OR target.country_name = source.country_name_en)
  AND target.day BETWEEN start_date AND end_date;
