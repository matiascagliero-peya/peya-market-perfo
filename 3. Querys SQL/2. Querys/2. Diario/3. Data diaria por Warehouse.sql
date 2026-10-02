DECLARE query_name STRING DEFAULT '3. Data diaria por Warehouse';

-- dmart_metrics_by_whs_daily (VERSIÓN INCREMENTAL: DELETE + INSERT)
-- PROPÓSITO: Métricas diarias de Supply, WIS, Orders, Tiempos, Defectos y Open Time.
-- ESTRATEGIA: Si no existe, calcula desde 2026-01-01. Si existe, borra e inserta los últimos 8 días.
-- GRAIN: (fecha, country_code, warehouse_id, warehouse_name)

BEGIN
  -- 1. DECLARACIÓN DE VARIABLES
  -- ====================================================================================
  DECLARE v_table_exists BOOL;
  DECLARE v_from_date    DATE;
  DECLARE v_to_date      DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);

  -- 2. VERIFICAR SI LA TABLA YA EXISTE
  -- ====================================================================================
  SET v_table_exists = (
    SELECT COUNT(1) > 0 
    FROM `peya-food-and-groceries.automated_tables_reports.INFORMATION_SCHEMA.TABLES` 
    WHERE table_name = 'dmart_metrics_by_whs_daily'
  );

  IF v_table_exists THEN
    -- Aseguramos la consistencia de la tabla física con las nuevas columnas
    ALTER TABLE `peya-food-and-groceries.automated_tables_reports.dmart_metrics_by_whs_daily`
    DROP COLUMN IF EXISTS Saturation_orders_over_7min,
    DROP COLUMN IF EXISTS total_orders_timings,
    DROP COLUMN IF EXISTS assignment_time_orders_over_6min;

    ALTER TABLE `peya-food-and-groceries.automated_tables_reports.dmart_metrics_by_whs_daily`
    ADD COLUMN IF NOT EXISTS assignment_time_over_6min INT64,
    ADD COLUMN IF NOT EXISTS picker_shift_confirmed_orders INT64,
    ADD COLUMN IF NOT EXISTS open_time FLOAT64;
  END IF;

  -- 3. DEFINIR LA VENTANA DE TIEMPO SEGÚN EXISTENCIA
  -- ====================================================================================
  IF v_table_exists THEN
    -- INCREMENTAL: Borraremos y recalcularemos los últimos 8 días
    SET v_from_date = DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY);
  ELSE
    -- CARGA INICIAL: Toma tu fecha base original
    SET v_from_date = DATE('2026-01-01');
  END IF;

  -- 4. CALCULAR LOS DATOS Y GUARDAR EN TABLA TEMPORAL
  -- ====================================================================================
  CREATE TEMP TABLE tmp_supply_ops AS
  WITH

  -- MAESTRO DE WAREHOUSES (DIRECTO DESDE DIM_PARTNER)
  -- ============================================================
  master_warehouses AS (
    SELECT
      CAST(warehouse_id AS STRING)     AS warehouse_id,
      MAX(warehouse_name)              AS warehouse_name,
      LOWER(MAX(country.country_code)) AS country_code,
      MAX(country.country_name)        AS country,
      MAX(city.name)                   AS city
    FROM `peya-bi-tools-pro.il_core.dim_partner`
    WHERE is_darkstore IS TRUE
      AND warehouse_id IS NOT NULL
      AND business_type.business_type_name NOT IN ('Courier', 'Courier Business')
    GROUP BY 1
    HAVING LOGICAL_OR(COALESCE(is_active, TRUE))
  ),

  -- SUPPLY METRICS
  -- ============================================================
  supply_metrics AS (
    WITH wis AS (
      SELECT
        ad.period_day,
        ad.country_code, 
        ad.warehouse_id, 
        ad.warehouse_name,
        ad.sku,
        MAX(ad.sales_forecast_quantity) AS sales_forecast_quantity,  
        SUM(ad.available_hourly * ad.hourly_events_weightage) / SUM(ad.hourly_events_weightage) AS hours_ponderado,
        
        MAX(CASE WHEN ad.level_zero_category = 'Ultra Fresh' THEN ad.sales_forecast_quantity END) AS sales_forecast_quantity_UF,
        SAFE_DIVIDE(
          SUM(CASE WHEN ad.level_zero_category = 'Ultra Fresh' THEN ad.available_hourly * ad.hourly_events_weightage END),
          SUM(CASE WHEN ad.level_zero_category = 'Ultra Fresh' THEN ad.hourly_events_weightage END)
        ) AS hours_ponderado_uf
      FROM `fulfillment-dwh-production.curated_data_shared_dmart.availability_data` ad
      LEFT JOIN `peya-delivery-and-support.automated_tables_reports.reple_flag_supplier_portal_historical` sp 
        ON ad.warehouse_id = sp.warehouse_id 
       AND ad.period_day = sp.date 
       AND ad.sku = sp.sku
      WHERE (
              (ad.period_day >= DATE(ad.status_implementation_date) AND ad.sku_status IN ('ACTIVE') AND ad.is_stale IS FALSE)
              OR
              (((ad.period_day < DATE(ad.status_implementation_date)) OR (ad.status_implementation_date IS NULL)) AND ad.is_active AND ad.is_stale IS FALSE)
            )
        AND ad.store_open = 1
        AND ad.period_day BETWEEN v_from_date AND v_to_date
        AND ad.is_active
        AND ad.management_entity = 'Pedidosya'
        AND sp.status_final <> 'No activo'
      GROUP BY 1, 2, 3, 4, 5
    )
    SELECT
      period_day,
      country_code, 
      warehouse_id, 
      warehouse_name,
      SUM(hours_ponderado * sales_forecast_quantity) AS wis_numerador,
      SUM(sales_forecast_quantity)                   AS wis_denominador,
      SUM(sales_forecast_quantity_UF * hours_ponderado_uf) AS wis_uf_numerador,
      SUM(sales_forecast_quantity_UF)                AS wis_uf_denominador
    FROM wis 
    GROUP BY 1, 2, 3, 4   
  ),
  
  -- ORDERS
  -- ============================================================
  orders_data_daily AS (
    SELECT DISTINCT
      DATE(fo.registered_date) AS day_date,
      LOWER(fo.country.country_code) AS country_code,
      par.warehouse_id,
      par.warehouse_name,
      CAST(fo.order_id AS STRING) AS order_id,
      fo.order_status,
      fo.user.id AS customer_id
    FROM `peya-bi-tools-pro.il_core.fact_orders` fo
    LEFT JOIN `peya-bi-tools-pro.il_core.dim_partner` par
      ON fo.restaurant.id = par.partner_id
    WHERE DATE(fo.registered_date) BETWEEN v_from_date AND v_to_date
      AND par.is_darkstore = TRUE
  ),

  orders_data_agg AS (
    SELECT
      day_date AS order_date,
      country_code,
      warehouse_id,
      warehouse_name,
      COUNT(DISTINCT CASE WHEN order_status = 'CONFIRMED' THEN order_id END) AS total_orders_fact_orders,
      COUNT(DISTINCT order_id) AS total_orders_all_status
    FROM orders_data_daily
    GROUP BY 1, 2, 3, 4
  ),

  -- ORDERS PARA SEAMLESS (sin filtro de order_status)
  -- ============================================================
  orders_data_seamless AS (
    SELECT
      DATE(fo.registered_date)        AS order_date,
      LOWER(par.country.country_code) AS country_code,
      par.warehouse_id,
      par.warehouse_name,
      CAST(fo.order_id AS STRING)     AS order_id,
      fo.order_status
    FROM `peya-bi-tools-pro.il_core.fact_orders` fo
    LEFT JOIN `peya-bi-tools-pro.il_core.dim_partner` par
      ON fo.restaurant.id = par.partner_id
    WHERE DATE(fo.registered_date) BETWEEN v_from_date AND v_to_date
      AND par.is_logistic
      AND par.is_darkstore
      AND par.business_type.business_type_name NOT IN ('Courier', 'Courier Business')
  ),

  orders_agg AS (
    SELECT
      day_date AS order_date,
      country_code,
      warehouse_id,
      warehouse_name,
      COUNT(DISTINCT CASE WHEN order_status = 'CONFIRMED' THEN order_id END) AS orders
    FROM orders_data_daily
    GROUP BY 1, 2, 3, 4
  ),

  -- NEW USERS
  -- ============================================================
  new_users AS (
    SELECT
      fo.user.id                    AS customer_id,
      MIN(DATE(fo.registered_date)) AS first_order_date
    FROM `peya-bi-tools-pro.il_core.fact_orders` fo
    LEFT JOIN `peya-bi-tools-pro.il_core.dim_partner` par
      ON fo.restaurant.id = par.partner_id
    WHERE fo.order_status = 'CONFIRMED'
      AND par.is_logistic
      AND par.is_darkstore
      AND fo.registered_date >= '2020-04-01'
      AND par.business_type.business_type_name NOT IN ('Courier', 'Courier Business')
    GROUP BY 1
  ),

  new_users_agg AS (
    SELECT
      od.day_date AS order_date,
      od.country_code,
      od.warehouse_id,
      od.warehouse_name,
      COUNT(DISTINCT od.customer_id) AS new_users
    FROM orders_data_daily od
    INNER JOIN new_users nu
      ON od.customer_id      = nu.customer_id
     AND nu.first_order_date = od.day_date
    WHERE od.order_status = 'CONFIRMED'
    GROUP BY 1, 2, 3, 4
  ),

  -- FX
  -- ============================================================
  fx AS (
    SELECT
      fx_source.month,
      fx_source.currency_iso,
      c.country_id,
      AVG(fx_source.rate_eur) AS rate_eur
    FROM `peya-fraud-and-fintech.group_finance_data.fact_sap_fx` AS fx_source
    LEFT JOIN `peya-bi-tools-pro.il_core.dim_country` AS c
      ON fx_source.currency_iso = c.currency_price
    WHERE c.country_name_en NOT IN ('Venezuela', 'Puerto Rico')
    GROUP BY 1, 2, 3
  ),

  -- GMV
  -- ============================================================
  gmv AS (
    SELECT
      DATE(fo.registered_date)                                         AS day,
      LOWER(par.country.country_code)                                  AS country_code,
      par.warehouse_id,
      par.warehouse_name,

      SUM(fo.total_amount / fx.rate_eur)
        + SUM(fo.shipping_amount / fx.rate_eur)
        + SUM(fo.serviceFee.service_fee_amount / fx.rate_eur)          AS gmv

    FROM `peya-bi-tools-pro.il_core.fact_orders` fo
    LEFT JOIN `peya-bi-tools-pro.il_core.dim_partner` par
      ON fo.restaurant.id = par.partner_id
    LEFT JOIN fx
      ON DATE_TRUNC(DATE(fo.registered_date), MONTH) = fx.month
     AND fo.country_id = fx.country_id
    WHERE DATE(fo.registered_date) BETWEEN v_from_date AND v_to_date
      AND fo.order_status = 'CONFIRMED'
      AND par.is_logistic
      AND par.is_darkstore
      AND par.business_type.business_type_name NOT IN ('Courier', 'Courier Business')
    GROUP BY 1, 2, 3, 4
  ),

  -- SEAMLESS
  -- ============================================================
  seamless_orders AS (
    SELECT
      platform_order_code   AS order_id,
      non_seamless_order,
      is_late_order,
      is_slow_order,
      is_rejected_order,
      is_session_order,
      is_forced_preorder,
      is_modified_order,
      non_seamless_type,
      actual_delivery_time
    FROM `peya-datamarts-pro.dm_fulfillment.non_seamless_delivery_order_level`
    WHERE DATE(created_date_local) BETWEEN v_from_date AND v_to_date
  ),
  
  seamless_agg AS (
    SELECT
      ods.order_date,
      ods.country_code,
      ods.warehouse_id,
      ods.warehouse_name,
      SUM(CASE WHEN so.non_seamless_order = TRUE THEN 0 ELSE 1 END) AS seamless_delivery,
      COUNT(DISTINCT CASE WHEN CAST(so.is_forced_preorder AS STRING) IN ('1','true','TRUE') THEN ods.order_id END) AS forced_preorders,
      COUNT(DISTINCT CASE WHEN CAST(so.is_modified_order AS STRING) IN ('1','true','TRUE') THEN ods.order_id END) AS modified_orders,
      COUNT(DISTINCT CASE WHEN CAST(so.is_session_order AS STRING) IN ('1','true','TRUE') THEN ods.order_id END) AS session_orders,
      COUNT(DISTINCT CASE WHEN CAST(so.is_slow_order AS STRING) IN ('1','true','TRUE') THEN ods.order_id END) AS slow_orders,
      COUNT(DISTINCT CASE WHEN CAST(so.is_late_order AS STRING) IN ('1','true','TRUE') THEN ods.order_id END) AS late_orders,
      COUNT(DISTINCT CASE WHEN CAST(so.is_rejected_order AS STRING) IN ('1','true','TRUE') THEN ods.order_id END) AS rejected_orders
    FROM orders_data_seamless ods
    LEFT JOIN seamless_orders so
      ON CAST(ods.order_id AS STRING) = CAST(so.order_id AS STRING)
    GROUP BY 1, 2, 3, 4
  ),

  -- PICKERS (assignment_time)
  -- ============================================================
  pickers_agg AS (
      SELECT
        ods.day_date AS order_date,
        ods.country_code,
        ods.warehouse_id,
        ods.warehouse_name,
        COUNT(DISTINCT ods.order_id) AS picker_shift_confirmed_orders,
        SUM(order_events.order_available_to_start_duration_sec / 60) AS assignment_time_sum,
        COUNT(DISTINCT CASE WHEN (order_events.order_available_to_start_duration_sec / 60) > 6 THEN ods.order_id END) AS assignment_time_over_6min
      FROM `peya-data-origins-pro.cl_dmarts.qc_picker_shift_orders` picko,
        UNNEST(picko.shifts) AS shifts,
        UNNEST(shifts.order_events) AS order_events
      INNER JOIN orders_data_daily ods
        ON ods.order_id = CAST(order_events.order_id AS STRING)
      WHERE DATETIME(shifts.shift_start_at_utc, shifts.timezone) >= v_from_date
        AND shift_start_date_utc >= v_from_date
        AND ods.order_status = 'CONFIRMED'
      GROUP BY 1, 2, 3, 4
  ),

  -- Delivery Time (delivery_time_data)
  -- ============================================================
  delivery_time_data AS (
    SELECT
      CAST(lo.peya_order_id AS STRING) AS order_id,
      COALESCE(MAX(lo.timings.actual_delivery_time), 0) / 60 AS sum_delivery_time_min
    FROM `peya-bi-tools-pro.il_logistics.fact_logistic_orders` AS lo
    CROSS JOIN UNNEST(lo.deliveries) del
    WHERE DATE(lo.created_date) >= v_from_date
      AND DATE(lo.created_date) <= v_to_date
      AND UPPER(lo.order_status) = 'COMPLETED'
      AND lo.is_preorder = FALSE
      AND lo.is_preorder is not null
    GROUP BY 1
  ),

  delivery_time_agg AS (
    SELECT
      ods.day_date AS order_date,
      ods.country_code,
      ods.warehouse_id,
      ods.warehouse_name,
      COUNT(DISTINCT dt.order_id) AS non_forced_completed_orders_logistics,
      SUM(dt.sum_delivery_time_min) AS delivery_time_sum
    FROM orders_data_daily ods
    INNER JOIN delivery_time_data dt
      ON ods.order_id = dt.order_id
    GROUP BY 1, 2, 3, 4
  ),

  -- WEIGHTED OPEN TIME (WOT) (desde wot_hour_by_whs)
  -- ============================================================
  open_time_agg AS (
    SELECT
      fecha,
      CAST(warehouse_id AS STRING) AS warehouse_id,
      COALESCE(
        SAFE_DIVIDE(
          SUM(disponibilidad_ponderada_hora),
          SUM(peso_trafico_hora)
        ),
        SAFE_DIVIDE(
          SUM(minutos_programados) - COALESCE(SUM(minutos_cerrados_efectivos), 0),
          SUM(minutos_programados)
        )
      ) AS open_time
    FROM `peya-food-and-groceries.automated_tables_reports.wot_hour_by_whs`
    WHERE fecha BETWEEN v_from_date AND v_to_date
    GROUP BY 1, 2
  ),

  -- SKELETON: Fechas evaluadas combinadas con el Maestro Oficial de Warehouses
  -- ============================================================
  fechas_evaluadas AS (
    SELECT DISTINCT fecha FROM (
      SELECT period_day AS fecha FROM supply_metrics
      UNION DISTINCT
      SELECT day_date   AS fecha FROM orders_data_daily
      UNION DISTINCT
      SELECT day        AS fecha FROM gmv
      UNION DISTINCT
      SELECT order_date AS fecha FROM seamless_agg
      UNION DISTINCT
      SELECT fecha      AS fecha FROM open_time_agg
    )
    WHERE fecha BETWEEN v_from_date AND v_to_date
  ),

  skeleton AS (
    SELECT 
      f.fecha,
      mw.country_code,
      mw.warehouse_id,
      mw.warehouse_name
    FROM fechas_evaluadas f
    CROSS JOIN master_warehouses mw
  )
  
  -- RESULTADO FINAL (CRUCE DE TODAS LAS TABLAS)
  -- ============================================================
  SELECT
    sk.fecha,
    LOWER(sk.country_code) AS country_code,
    sk.warehouse_id,
    sk.warehouse_name,
    
    -- Órdenes, Nuevos Usuarios y GMV
    oa.orders AS confirmed_orders,
    nu.new_users,
    g.gmv,

    -- WIS & WIS Ultra Fresh
    sm.wis_numerador,
    sm.wis_denominador,
    sm.wis_uf_numerador,
    sm.wis_uf_denominador,
    
    -- Métricas de Operaciones / Defectos
    oda.total_orders_all_status,
    sa.seamless_delivery,
    sa.late_orders,
    sa.slow_orders,
    sa.rejected_orders,
    sa.session_orders,
    sa.forced_preorders,
    sa.modified_orders,
    
    -- Assignment Time & Saturation
    pa.assignment_time_sum,

    -- Tiempos
    dta.non_forced_completed_orders_logistics,
    dta.delivery_time_sum,

    -- Nuevas columnas agregadas mediante ALTER TABLE (al final de la tabla física)
    pa.picker_shift_confirmed_orders,
    pa.assignment_time_over_6min,

    -- Open Time de cada WHS (desde wot_hour_by_whs)
    ot.open_time

  FROM skeleton sk
  LEFT JOIN supply_metrics    sm  ON sk.fecha = sm.period_day  AND sk.warehouse_id = sm.warehouse_id
  LEFT JOIN orders_agg        oa  ON sk.fecha = oa.order_date  AND sk.warehouse_id = oa.warehouse_id
  LEFT JOIN orders_data_agg   oda ON sk.fecha = oda.order_date AND sk.warehouse_id = oda.warehouse_id
  LEFT JOIN new_users_agg     nu  ON sk.fecha = nu.order_date  AND sk.warehouse_id = nu.warehouse_id
  LEFT JOIN gmv               g   ON sk.fecha = g.day          AND sk.warehouse_id = g.warehouse_id
  LEFT JOIN seamless_agg      sa  ON sk.fecha = sa.order_date  AND sk.warehouse_id = sa.warehouse_id
  LEFT JOIN delivery_time_agg dta ON sk.fecha = dta.order_date AND sk.warehouse_id = dta.warehouse_id
  LEFT JOIN pickers_agg       pa  ON sk.fecha = pa.order_date  AND sk.warehouse_id = pa.warehouse_id
  LEFT JOIN open_time_agg     ot  ON sk.fecha = ot.fecha       AND sk.warehouse_id = ot.warehouse_id;

  -- ====================================================================================
  -- 5. LÓGICA DE DML (CREATE vs DELETE/INSERT)
  -- ====================================================================================
  IF NOT v_table_exists THEN
    -- Si no existe, crea la tabla con toda la data histórica calculada
    CREATE TABLE `peya-food-and-groceries.automated_tables_reports.dmart_metrics_by_whs_daily` AS
    SELECT * FROM tmp_supply_ops
    ORDER BY country_code, warehouse_id, fecha;
  ELSE
    -- Si existe, borra los días específicos que acabamos de calcular
    DELETE FROM `peya-food-and-groceries.automated_tables_reports.dmart_metrics_by_whs_daily`
    WHERE fecha BETWEEN v_from_date AND v_to_date;
    
    -- Inserta la nueva información procesada
    INSERT INTO `peya-food-and-groceries.automated_tables_reports.dmart_metrics_by_whs_daily`
    SELECT * FROM tmp_supply_ops;
  END IF;
END;
