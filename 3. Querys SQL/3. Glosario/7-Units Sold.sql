DECLARE query_name STRING DEFAULT '7-Units Sold';

-- Query de prueba para calcular la métrica Units Sold
-- 1. Obtener la cantidad total de unidades despachadas (vendidas) de pedidos confirmados por país y día.
-- Métrica: Units Sold = Suma de 'fulfilled_quantity' de todos los pedidos confirmados en un periodo de tiempo X
-- Frecuencia de actualización: la tabla customer_orders_sku_level se actualiza de forma diaria.

SELECT
  d.country_name AS country, -- País del pedido
  DATE(d.order_date) AS day, -- Día del pedido
  SUM(d.fulfilled_quantity) AS units_sold -- Total de unidades despachadas (vendidas)
FROM
  `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` d -- Tabla con órdenes a nivel SKU
WHERE
  UPPER(d.state) = 'CONFIRMED' -- Solo pedidos confirmados
  AND d.order_date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY) 
                       AND CURRENT_DATE() -- Últimos 90 días (rango de ejemplo)
GROUP BY 1, 2 -- Agrupar por país y día
ORDER BY 2 DESC, 1; -- Ordenar por día descendente y luego país