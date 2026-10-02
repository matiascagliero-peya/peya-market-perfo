DECLARE query_name STRING DEFAULT '35-AFV';

-- Query de prueba para calcular la métrica AFV (Average Final Value / Ticket promedio sin IVA)
-- 1. Obtener la facturación de un periodo sin IVA (Net Sales / Retail Sales) y el conteo de órdenes confirmadas.
-- 2. Dividir las ventas netas por la cantidad de órdenes para obtener el AFV.
-- Métrica: AFV = Net Sales / Confirmed Orders
-- Frecuencia de actualización: la tabla customer_orders_sku_level se actualiza de forma diaria.

SELECT
  dc.country_name AS country, -- País de la orden
  DATE_TRUNC(o.order_date, MONTH) AS month, -- Mes de la orden
  
  -- Net Sales: Facturación total sin IVA (Net of Discounts)
  SUM(o.total_amount_net_with_discount_eur) AS net_sales_eur,
  
  -- Confirmed Orders: Cantidad de órdenes únicas confirmadas
  COUNT(DISTINCT o.order_id) AS confirmed_orders,
  
  -- AFV: Ticket promedio neto sin IVA en EUR
  ROUND(SAFE_DIVIDE(SUM(o.total_amount_net_with_discount_eur), COUNT(DISTINCT o.order_id)), 2) AS afv_net_eur

FROM
  `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` o
LEFT JOIN `peya-bi-tools-pro.il_core.dim_country` dc
  ON o.country_id = dc.country_id
WHERE
  UPPER(o.state) = 'CONFIRMED' -- Solo pedidos confirmados
  AND o.order_date BETWEEN DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 MONTH), MONTH) 
                      AND CURRENT_DATE() -- Últimos 3 meses
GROUP BY
  1, 2
ORDER BY
  country ASC, month DESC;
