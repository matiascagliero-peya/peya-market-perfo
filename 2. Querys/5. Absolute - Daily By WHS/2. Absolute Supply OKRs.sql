DECLARE query_name STRING DEFAULT '2. Absolute Supply OKRs';

DECLARE cantidad_filas INT64;
DECLARE max_fuente DATE;
DECLARE ini_actual, fin_actual, ini_pasado, fin_pasado DATE;

CREATE TABLE IF NOT EXISTS `peya-food-and-groceries.automated_tables_reports.absolute_okrs_supply` (

    fecha DATE OPTIONS(description="Dia especifico al que corresponden los datos. Campo de particion."),
    country_code STRING OPTIONS(description="Codigo de dos letras del pais en minusculas."),
    country_name STRING OPTIONS(description="Nombre completo del pais en ingles."),
    wis_denominador FLOAT64, wis_numerador FLOAT64, wis FLOAT64,
    wis_uf_denominador FLOAT64, wis_uf_numerador FLOAT64, wis_ultra_fresh FLOAT64,
    peya_issues_numerador FLOAT64, peya_issues_denominador FLOAT64, peya_issues FLOAT64,
    peya_issues_uf_numerador FLOAT64, peya_issues_uf_denominador FLOAT64, peya_issues_uf FLOAT64,
    supplier_issues_numerador FLOAT64, supplier_issues_denominador FLOAT64, supplier_issues FLOAT64,
    supplier_issues_uf_numerador FLOAT64, supplier_issues_uf_denominador FLOAT64, supplier_issues_uf FLOAT64
)

PARTITION BY fecha CLUSTER BY country_code;

SET max_fuente = (
    SELECT MAX(date)
    FROM `peya-delivery-and-support.automated_tables_reports.dmarts_loss_tree`
);

SET cantidad_filas = (
    SELECT row_count
    FROM `peya-food-and-groceries.automated_tables_reports.__TABLES__`
    WHERE table_id = 'absolute_okrs_supply'
);

IF max_fuente IS NOT NULL THEN

  IF cantidad_filas IS NULL OR cantidad_filas = 0 THEN
    SET ini_actual = DATE('2026-01-01');
    SET fin_actual = max_fuente;
    SET ini_pasado = DATE('2025-01-01');
    SET fin_pasado = DATE_SUB(max_fuente, INTERVAL 1 YEAR);
  ELSE
    SET fin_actual = max_fuente;
    SET ini_actual = DATE_SUB(max_fuente, INTERVAL 7 DAY);
    SET fin_pasado = DATE_SUB(max_fuente, INTERVAL 1 YEAR);
    SET ini_pasado = DATE_SUB(ini_actual, INTERVAL 1 YEAR);
  END IF;

  BEGIN TRANSACTION;

    DELETE FROM `peya-food-and-groceries.automated_tables_reports.absolute_okrs_supply`
    WHERE (fecha BETWEEN ini_actual AND fin_actual)
       OR (fecha BETWEEN ini_pasado AND fin_pasado);

    INSERT INTO `peya-food-and-groceries.automated_tables_reports.absolute_okrs_supply` (
        fecha, country_code, country_name,
        wis_denominador, wis_numerador, wis,
        wis_uf_denominador, wis_uf_numerador, wis_ultra_fresh,
        peya_issues_numerador, peya_issues_denominador, peya_issues,
        peya_issues_uf_numerador, peya_issues_uf_denominador, peya_issues_uf,
        supplier_issues_numerador, supplier_issues_denominador, supplier_issues,
        supplier_issues_uf_numerador, supplier_issues_uf_denominador, supplier_issues_uf
    )
    
    WITH wis_raw AS (
        SELECT
            period_day,
            LOWER(ad.country_code) AS country_code,
            ad.warehouse_id,
            ad.sku,
            MAX(sales_forecast_quantity) AS sales_forecast_quantity,  
            SUM(available_hourly * hourly_events_weightage) / SUM(hourly_events_weightage) AS hours_ponderado,
            MAX(CASE WHEN level_zero_category = 'Ultra Fresh' THEN sales_forecast_quantity END) AS sales_forecast_quantity_UF,
            SAFE_DIVIDE(
                SUM(CASE WHEN level_zero_category = 'Ultra Fresh' THEN available_hourly * hourly_events_weightage END),
                SUM(CASE WHEN level_zero_category = 'Ultra Fresh' THEN hourly_events_weightage END)
            ) AS hours_ponderado_uf
        FROM `fulfillment-dwh-production.curated_data_shared_dmart.availability_data` ad
        LEFT JOIN `peya-delivery-and-support.automated_tables_reports.reple_flag_supplier_portal_historical` sp 
            ON ad.warehouse_id = sp.warehouse_id AND period_day = date AND ad.sku = sp.sku
        WHERE (
            (period_day >= DATE(status_implementation_date) AND sku_status IN ('ACTIVE') AND is_stale IS FALSE)
            OR
            (((period_day < DATE(status_implementation_date)) OR (status_implementation_date IS NULL)) AND is_active AND is_stale IS FALSE)
        )
        AND store_open = 1
        AND (period_day BETWEEN ini_actual AND fin_actual OR period_day BETWEEN ini_pasado AND fin_pasado)
        AND is_active
        AND management_entity = 'Pedidosya'
        AND status_final <> 'No activo'
        GROUP BY 1, 2, 3, 4
    ),
    wis_agg AS (
        SELECT
            period_day AS fecha,
            country_code,
            SUM(hours_ponderado * sales_forecast_quantity) AS wis_numerador,
            SUM(sales_forecast_quantity) AS wis_denominador,
            SUM(sales_forecast_quantity_UF * hours_ponderado_uf) AS wis_uf_numerador,
            SUM(sales_forecast_quantity_UF) AS wis_uf_denominador
        FROM wis_raw
        GROUP BY 1, 2
    ),
    base AS (
        SELECT
            date                AS fecha,
            LOWER(country_code) AS country_code,
            sales_forecast,
            level_one IN ('Produce','Meat / Seafood','Ready To Consume') AS es_uf,
            IF(loss_tree_lvl3 = 'Available', 0, sales_forecast * (1 - availability_horario))             AS perdida,
            IF(loss_tree_lvl0 = 'Peya Issues', sales_forecast * (1 - availability_horario), 0)           AS perdida_peya,
            IF(loss_tree_lvl0 = 'Supplier + P&N Issues', sales_forecast * (1 - availability_horario), 0) AS perdida_supplier
        FROM `peya-delivery-and-support.automated_tables_reports.dmarts_loss_tree`
        WHERE (date BETWEEN ini_actual AND fin_actual OR date BETWEEN ini_pasado AND fin_pasado)
          AND status_final IN ('Activo directa', 'Activo centralizado')
          AND filter_looker = 'Filter'
          AND sku NOT IN (
              '7R5TPX','LOG54J','RMIOTZ','CTJAV9','FPWZT5','JTOEWH','LC6J56','RYI27W',
              'CP9GL5','NXS0TS','T90KO6','1PEEPJ','BPYZRQ','CYZQJG','FJR3LP','JV8U7V',
              'UGQK4I','V80DW7','AXT412','DND7KL','RHF6T3','UV55ZX','WAECI4','0ZD422',
              '17NIXN','985FY7','Y63Y50','YEPK2V','ZN3HD0','D4NT94','DTBT3N','WHXJBO',
              '09L1ZG','9O341U','AM18YP','R9QWVQ','05675O','224MI7','38L128','K2QX5G',
              'EETQZP','Z73DVS','0AANN5','WIG5Z0','0KJ78F','41LX0F','63HN4V','906UYZ',
              'JAA6VC','N4GDF0','NYO25E','QC0F6M','QEVVZU','V4G31B','V8SVS1'
          )
    ),
    agg AS (
        SELECT
            fecha, country_code,
            SUM(sales_forecast)                 AS den_total,
            SUM(perdida)                        AS perdida_total,
            SUM(IF(es_uf, sales_forecast, 0))   AS den_uf,
            SUM(IF(es_uf, perdida, 0))          AS perdida_uf,
            SUM(perdida_peya)                   AS peya_num,
            SUM(IF(es_uf, perdida_peya, 0))     AS peya_uf_num,
            SUM(perdida_supplier)               AS supplier_num,
            SUM(IF(es_uf, perdida_supplier, 0)) AS supplier_uf_num
        FROM base
        GROUP BY 1, 2
    )
    SELECT
        COALESCE(a.fecha, w.fecha) AS fecha,
        COALESCE(a.country_code, w.country_code) AS country_code,
        c.country_name,

        -- WIS total
        w.wis_denominador,
        w.wis_numerador,
        SAFE_DIVIDE(w.wis_numerador, w.wis_denominador) AS wis,

        -- WIS Ultra Fresh
        w.wis_uf_denominador,
        w.wis_uf_numerador,
        SAFE_DIVIDE(w.wis_uf_numerador, w.wis_uf_denominador) AS wis_ultra_fresh,

        -- Peya Issues
        a.peya_num AS peya_issues_numerador,
        a.den_total AS peya_issues_denominador,
        SAFE_DIVIDE(a.peya_num, a.den_total) AS peya_issues,

        a.peya_uf_num AS peya_issues_uf_numerador,
        a.den_uf AS peya_issues_uf_denominador,
        SAFE_DIVIDE(a.peya_uf_num, a.den_uf) AS peya_issues_uf,

        -- Supplier + P&N Issues
        a.supplier_num AS supplier_issues_numerador,
        a.den_total AS supplier_issues_denominador,
        SAFE_DIVIDE(a.supplier_num, a.den_total) AS supplier_issues,

        a.supplier_uf_num AS supplier_issues_uf_numerador,
        a.den_uf AS supplier_issues_uf_denominador,
        SAFE_DIVIDE(a.supplier_uf_num, a.den_uf) AS supplier_issues_uf
        
    FROM agg a
    FULL OUTER JOIN wis_agg w ON a.fecha = w.fecha AND a.country_code = w.country_code
    LEFT JOIN (
        SELECT LOWER(country_code) AS cc, ANY_VALUE(country_name_en) AS country_name
        FROM `peya-bi-tools-pro.il_core.dim_country`
        GROUP BY 1
    ) c ON COALESCE(a.country_code, w.country_code) = c.cc;

  COMMIT TRANSACTION;

END IF;