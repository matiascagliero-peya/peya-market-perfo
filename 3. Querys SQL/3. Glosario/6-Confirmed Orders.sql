DECLARE query_name STRING DEFAULT '6-Confirmed Orders';

-- Query de prueba para calcular la métrica Confirmed Orders  
-- 1. Obtener la cantidad total de pedidos confirmados por país y día.  
-- Métrica: Confirmed Orders = Cantidad de orders confirmadas en un periodo de tiempo X
-- Frecuencia de actualización: la tabla customer_orders_sku_level se actualiza de forma diaria.
SELECT
  d.country_name AS country, -- País del pedido
  DATE(d.order_date) AS day, -- Día del pedido
  COUNT(DISTINCT d.order_id) AS confirmed_orders -- Total de pedidos confirmados (absolutos)
FROM
  `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` d -- Tabla con órdenes a nivel SKU
WHERE
  UPPER(d.state) = 'CONFIRMED' -- Solo pedidos confirmados
  AND d.order_date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY) 
                      AND CURRENT_DATE() -- Últimos 90 días hasta la fecha actual
GROUP BY 1, 2 -- Agrupar por país y día
ORDER BY 2 DESC, 1; -- Ordenar por día descendente y luego país
