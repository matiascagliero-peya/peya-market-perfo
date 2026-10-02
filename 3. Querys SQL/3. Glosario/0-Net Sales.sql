DECLARE query_name STRING DEFAULT '0-Net Sales';

-- Query de prueba para calcular la métrica Net Sales  
-- 1. Obtener el Net Sales en EUR de Sept-2025 por país.  
-- Frecuencia de actualización: la tabla customer_orders_sku_level se actualiza de forma diaria.

SELECT
  d.country_name AS country, -- País del pedido
  DATE_TRUNC(d.order_date, MONTH) AS month, -- Mes del pedido
  SUM(d.total_amount_net_with_discount_eur) AS net_sales_eur -- Net Sales total en EUR (ya convertido)
FROM
  `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` d -- Tabla con órdenes a nivel SKU
WHERE
  UPPER(d.state) = 'CONFIRMED' -- Solo pedidos confirmados
  AND d.order_date BETWEEN DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 MONTH), MONTH) 
                      AND CURRENT_DATE() -- Últimos 3 meses hasta la fecha actual
GROUP BY 1, 2 -- Agrupar por país y mes
ORDER BY 2 DESC, 1; -- Ordenar por mes descendente y luego país
