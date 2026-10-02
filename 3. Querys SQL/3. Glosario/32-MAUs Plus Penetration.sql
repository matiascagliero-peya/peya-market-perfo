DECLARE query_name STRING DEFAULT '32-MAUs Plus Penetration';

-- Query de prueba para calcular la métrica MAUs Plus Penetration y Plus MAUs Share
-- 1. Obtener la cantidad de usuarios activos mensuales (MAUs) que son miembros de Plus.
-- 2. Calcular la penetración de Plus MAUs sobre el total de MAUs de Dmart (Plus Share) y sobre los usuarios cubiertos (Plus Penetration).
-- Frecuencia de actualización: la tabla customer_orders_sku_level se actualiza de forma diaria.

WITH base_maus AS (
  SELECT
    dc.country_name AS country, -- País del pedido
    DATE_TRUNC(o.order_date, MONTH) AS month, -- Mes de la actividad
    
    -- Usuarios únicos de Dmart (Dmart MAUs)
    COUNT(DISTINCT o.customer_id) AS dmart_maus,
    
    -- Usuarios únicos de Dmart con membresía Plus (Plus MAUs)
    COUNT(DISTINCT CASE WHEN o.is_user_plus = 1 THEN o.customer_id END) AS plus_maus

  FROM
    `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` o
  LEFT JOIN `peya-bi-tools-pro.il_core.dim_country` dc
    ON o.country_id = dc.country_id
  WHERE
    UPPER(o.state) = 'CONFIRMED' -- Solo pedidos confirmados
    AND o.order_date BETWEEN DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 MONTH), MONTH) 
                        AND CURRENT_DATE() -- Últimos 3 meses hasta la fecha actual
  GROUP BY 1, 2
)

SELECT
  bm.country,
  bm.month,
  bm.dmart_maus,
  bm.plus_maus,
  
  -- Métrica A: Plus MAUs Share % (Porcentaje de usuarios Plus sobre el total de compradores mensuales de Dmart)
  ROUND(SAFE_DIVIDE(bm.plus_maus, bm.dmart_maus) * 100, 2) AS plus_maus_share_pct

FROM
  base_maus bm
ORDER BY
  bm.country ASC, bm.month DESC;
