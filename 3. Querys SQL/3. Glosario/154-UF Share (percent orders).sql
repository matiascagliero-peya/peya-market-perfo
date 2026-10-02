DECLARE query_name STRING DEFAULT '154-UF Share (percent orders)';

-- Query de prueba para calcular la métrica UF Share (% de órdenes con Ultra Fresh)
-- 1. Identificar si cada orden confirmada contiene al menos un producto de la categoría 'Ultra Fresh'.
--    Categorías de Ultra Fresh en Peya Market: 'Produce', 'Meat / Seafood', 'Ready To Consume'.
-- 2. Calcular la participación (%) de las órdenes con al menos un ítem UF sobre el total de órdenes confirmadas.
-- Métrica: UF Share (% orders) = Confirmed Orders con al menos 1 ítem UF / Total Confirmed Orders
-- Frecuencia de actualización: la tabla customer_orders_sku_level se actualiza de forma diaria.

WITH order_details AS (
  SELECT
    dc.country_name AS country, -- País del pedido
    DATE_TRUNC(o.order_date, MONTH) AS month, -- Mes del pedido
    o.order_id,
    
    -- Flag si la fila pertenece a un SKU de la categoría Ultra Fresh
    MAX(IF(o.master_category_parent_english IN ('Produce', 'Meat / Seafood', 'Ready To Consume'), 1, 0)) AS has_uf_item

  FROM
    `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` o
  LEFT JOIN `peya-bi-tools-pro.il_core.dim_country` dc
    ON o.country_id = dc.country_id
  WHERE
    UPPER(o.state) = 'CONFIRMED' -- Solo pedidos confirmados
    AND o.order_date BETWEEN DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 MONTH), MONTH) 
                        AND CURRENT_DATE() -- Últimos 3 meses
  GROUP BY 1, 2, 3
)

SELECT
  od.country,
  od.month,
  
  -- Total de órdenes confirmadas
  COUNT(DISTINCT od.order_id) AS total_orders,
  
  -- Cantidad de órdenes que tienen al menos un ítem de Ultra Fresh
  COUNT(DISTINCT IF(od.has_uf_item = 1, od.order_id, NULL)) AS uf_orders,
  
  -- UF Share (% orders): Porcentaje de penetración en pedidos
  ROUND(SAFE_DIVIDE(COUNT(DISTINCT IF(od.has_uf_item = 1, od.order_id, NULL)), COUNT(DISTINCT od.order_id)) * 100, 2) AS uf_orders_share_pct

FROM
  order_details od
GROUP BY
  1, 2
ORDER BY
  country ASC, month DESC;
