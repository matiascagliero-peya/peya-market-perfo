DECLARE query_name STRING DEFAULT '201-WIS UF';

-- ====================================================================================
-- CÁLCULO DEL WIS ULTRA FRESH (Para el día de ayer)
-- ====================================================================================
-- El WIS UF mide el porcentaje de disponibilidad de tu catálogo, dándole más peso o 
-- castigo a la falta de stock en los artículos que más se venden y en las horas de mayor 
-- tráfico, pero calculada de manera exclusiva sobre el universo de productos perecederos 
-- de alta rotación (la categoría Ultra Fresh).
-- Frecuencia de actualización: la tabla availability_data se actualiza de forma diaria.

WITH sku_level_uf AS (
    -- 1. Calculamos forecast y disponibilidad SOLO para productos frescos
    SELECT
        period_day AS fecha,
        country_code,
        warehouse_id,
        warehouse_name,
        sku,
        
        MAX(sales_forecast_quantity) AS forecast_sku_uf,
        SAFE_DIVIDE(SUM(available_hourly * hourly_events_weightage), SUM(hourly_events_weightage)) AS disp_ponderada_sku_uf
        
    FROM `fulfillment-dwh-production.curated_data_shared_dmart.availability_data`
    WHERE period_day = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) -- Filtro de ayer
      AND store_open = 1
      AND is_active = TRUE
      AND management_entity = 'Pedidosya'
      
      -- FILTRO CLAVE: Aislamos únicamente la categoría Ultra Fresh
      AND level_zero_category = 'Ultra Fresh' 
      
      AND (
            (period_day >= status_implementation_date AND sku_status IN ('ACTIVE') AND is_stale IS FALSE)
            OR (((period_day < status_implementation_date) OR (status_implementation_date IS NULL)) AND is_active AND is_stale IS FALSE)
          )
    GROUP BY 1, 2, 3, 4, 5
)

-- 2. Agrupamos los SKUs frescos a nivel de Tienda (Warehouse)
SELECT
    fecha,
    country_code,
    warehouse_id,
    warehouse_name,
    
    -- Numerador UF
    SUM(disp_ponderada_sku_uf * forecast_sku_uf) AS wis_uf_numerador,
    
    -- Denominador UF
    SUM(forecast_sku_uf) AS wis_uf_denominador,
    
    -- Ratio Final WIS Ultra Fresh
    SAFE_DIVIDE(SUM(disp_ponderada_sku_uf * forecast_sku_uf), SUM(forecast_sku_uf)) AS wis_ultra_fresh
    
FROM sku_level_uf
GROUP BY 1, 2, 3, 4;
