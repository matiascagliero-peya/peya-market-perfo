DECLARE query_name STRING DEFAULT 'Glosario-14-Confirmed Orders - UF';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 14
-- Nombre:     Confirmed Orders - UF
-- Chapter:   Demand Stimulation
-- Query bajada en: 14 - UF Data
-- Sheets Name: 1. ET - UF Data (14 - UF Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/15-zHA4HDBopwhCBjwhIeHr-mLpVuYCe5I0G4bd8X-4s
-- Tablas de origen: `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
-- Tipo:       Dato Directo (Col 8)
-- Fórmula:    COUNT(DISTINCT order_id) con SKUs Ultra Fresh
-- Definición: Órdenes confirmadas que incluyen al menos un producto Ultra Fresh.
-- ====================================================================================

SELECT
  d.country_name AS country,
  DATE_TRUNC(d.order_date, MONTH) AS month,
  SUM(CASE WHEN d.master_category_parent_english IN ('Produce', 'Meat / Seafood', 'Ready To Consume') THEN d.fulfilled_quantity ELSE 0 END) AS units_sold_uf,
  SUM(CASE WHEN d.master_category_parent_english IN ('Produce', 'Meat / Seafood', 'Ready To Consume') THEN d.total_amount_net_with_discount_eur ELSE 0 END) AS net_sales_uf,
  COUNT(DISTINCT CASE WHEN d.master_category_parent_english IN ('Produce', 'Meat / Seafood', 'Ready To Consume') THEN d.order_id END) AS confirmed_orders_uf,
  SAFE_DIVIDE(
    COUNT(DISTINCT CASE WHEN d.master_category_parent_english IN ('Produce', 'Meat / Seafood', 'Ready To Consume') THEN d.order_id END),
    NULLIF(COUNT(DISTINCT d.order_id), 0)
  ) AS uf_orders_share
FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` d
WHERE UPPER(d.state) = 'CONFIRMED'
  AND d.order_date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +---------------------+----------------------+-------+----------------+-----------------+---------------+
-- | confirmed_orders_uf | country              | month | net_sales_uf   | uf_orders_share | units_sold_uf |
-- +---------------------+----------------------+-------+----------------+-----------------+---------------+
-- |           1.123.009 | Argentina            | 2.026 | 8.519.089,28 € |          42,33% |  3.261.752,41 |
-- |              46.440 | Bolivia              | 2.026 |   132.894,69 € |          32,49% |    207.207,62 |
-- |             139.237 | Chile                | 2.026 |   745.598,89 € |          40,68% |    392.813,59 |
-- |              31.717 | Ecuador              | 2.026 |   163.673,20 € |          32,56% |     96.429,74 |
-- |              30.095 | El Salvador          | 2.026 |   174.555,74 € |          34,88% |       115.267 |
-- |              35.157 | Guatemala            | 2.026 |   259.850,12 € |          36,73% |       147.764 |
-- |              10.614 | Honduras             | 2.026 |    42.065,88 € |          20,93% |        36.822 |
-- |              21.222 | Nicaragua            | 2.026 |   134.186,38 € |          37,60% |    106.302,26 |
-- |              37.162 | Panam�               | 2.026 |   259.082,12 € |          39,96% |    141.756,75 |
-- |              45.689 | Paraguay             | 2.026 |   239.290,03 € |          33,64% |    110.995,05 |
-- |              96.360 | Per�                 | 2.026 |   511.689,35 € |          35,25% |    311.624,77 |
-- |              52.820 | Rep�blica Dominicana | 2.026 |   236.332,78 € |          30,83% |    277.961,98 |
-- |             122.342 | Uruguay              | 2.026 | 1.079.636,07 € |          42,61% |    337.372,43 |
-- +---------------------+----------------------+-------+----------------+-----------------+---------------+
