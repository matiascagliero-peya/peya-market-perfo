DECLARE query_name STRING DEFAULT '200-UF Net Sales';

-- Query de prueba para calcular la métrica UF Net Sales (en absolutos)
-- 1. Obtener las ventas netas UF/Fresh de los últimos 3 meses por país.
-- Frecuencia de actualización: la tabla customer_orders_sku_level se actualiza de forma diaria.

SELECT
  d.country_name AS country, -- País del pedido
  DATE_TRUNC(d.order_date, MONTH) AS month, -- Mes del pedido
  
  -- Ventas netas UF/Fresh (categorías Meat / Seafood, Produce, Ready To Consume)
  SUM(
    IF(
      d.master_category_parent_english IN (
        'Meat / Seafood', 
        'Produce', 
        'Ready To Consume'
      ), 
      d.total_amount_net_with_discount_eur, 
      0
    )
  ) AS uf_net_sales_eur, -- Ventas UF en EUR
  
  -- (Opcional) Total de ventas netas del mes, para referencia
  SUM(d.total_amount_net_with_discount_eur) AS total_net_sales_eur -- Ventas totales en EUR

FROM
  `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` d -- Tabla de órdenes a nivel SKU
WHERE
  UPPER(d.state) = 'CONFIRMED' -- Solo pedidos confirmados
  AND d.order_date BETWEEN DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 MONTH), MONTH)
                   AND CURRENT_DATE() -- Últimos 3 meses hasta la fecha actual
GROUP BY
  d.country_name, -- Agrupar por país
  DATE_TRUNC(d.order_date, MONTH) -- Agrupar por mes
ORDER BY
  country, month; -- Ordenar salida para lectura
