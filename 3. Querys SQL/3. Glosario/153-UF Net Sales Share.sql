DECLARE query_name STRING DEFAULT '153-UF Net Sales Share';

-- Query de prueba para calcular la métrica UF Net Sales Share
-- 1. Obtener el UF Net Sales Share de los últimos 3 meses por país.
-- Frecuencia de actualización: la tabla customer_orders_sku_level se actualiza de forma diaria.

SELECT
  d.country_name AS country, -- País del pedido
  DATE_TRUNC(d.order_date, MONTH) AS month, -- Mes del pedido
  
  -- Métrica final: UF Net Sales Share
  SAFE_DIVIDE(
      -- Numerador: Ventas Netas de UF/Fresh
      SUM(IF(
          d.master_category_parent_english IN (
              'Meat / Seafood', 
              'Produce', 
              'Ready To Consume'
          ), 
          d.total_amount_net_with_discount_eur, 
          0
      )),
      -- Denominador: Ventas Netas Totales
      SUM(d.total_amount_net_with_discount_eur)
  ) AS uf_net_sales_share,

FROM
  `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` d -- Tabla con órdenes a nivel SKU
WHERE
  UPPER(d.state) = 'CONFIRMED' -- Solo pedidos confirmados
  AND d.order_date BETWEEN DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 MONTH), MONTH) 
                   AND CURRENT_DATE() -- Últimos 3 meses hasta la fecha actual
GROUP BY 1, 2 -- Agrupar por país y