DECLARE query_name STRING DEFAULT 'Glosario-33-Units w Discounts %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 33
-- Nombre:     Units w Discounts %
-- Chapter:   Demand Stimulation
-- Query bajada en: 19 - Promo
-- Sheets Name: 1. ET - Promo (19 - Promo)
-- Sheets Link: https://docs.google.com/spreadsheets/d/10-Tj3b4ZkGnxQTEnrD9Vfw4Tj--vMTeScrtSLmo03bw
-- Tablas de origen: `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
-- Tipo:       Ratio Calculado
-- Fórmula:    Units Sold with Discount / Total Units Sold
-- Definición: Porcentaje de unidades comercializadas con descuento promocional.
-- ====================================================================================

SELECT
  d.country_name AS country,
  DATE_TRUNC(d.order_date, MONTH) AS month,
  SUM(CASE WHEN COALESCE(d.pcm_discount_amount_net_eur, d.pcm_discount_amount_net_eur, 0) > 0 THEN d.fulfilled_quantity ELSE 0 END) AS units_with_discount,
  SUM(d.fulfilled_quantity) AS total_units,
  SAFE_DIVIDE(SUM(CASE WHEN COALESCE(d.pcm_discount_amount_net_eur, d.pcm_discount_amount_net_eur, 0) > 0 THEN d.fulfilled_quantity ELSE 0 END), NULLIF(SUM(d.fulfilled_quantity), 0)) AS units_w_discounts_pct
FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` d
WHERE UPPER(d.state) = 'CONFIRMED'
  AND d.order_date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------+---------------+-----------------------+---------------------+
-- | country              | month | total_units   | units_w_discounts_pct | units_with_discount |
-- +----------------------+-------+---------------+-----------------------+---------------------+
-- | Argentina            | 2.026 | 22.537.552,57 |                63,33% |       14.273.761,86 |
-- | Bolivia              | 2.026 |  1.032.909,38 |                41,45% |          428.117,04 |
-- | Chile                | 2.026 |  2.824.960,59 |                37,47% |        1.058.548,28 |
-- | Ecuador              | 2.026 |    598.603,74 |                41,80% |          250.239,89 |
-- | El Salvador          | 2.026 |       543.397 |                14,22% |              77.298 |
-- | Guatemala            | 2.026 |       593.219 |                17,08% |             101.314 |
-- | Honduras             | 2.026 |       234.762 |                20,25% |              47.541 |
-- | Nicaragua            | 2.026 |    346.016,56 |                21,31% |           73.740,88 |
-- | Panam�               | 2.026 |    682.329,75 |                19,20% |          130.978,56 |
-- | Paraguay             | 2.026 |    829.499,15 |                22,92% |          190.100,31 |
-- | Per�                 | 2.026 |  1.503.957,68 |                35,90% |          539.861,64 |
-- | Rep�blica Dominicana | 2.026 |  1.007.107,98 |                24,85% |          250.292,73 |
-- | Uruguay              | 2.026 |  2.285.044,38 |                31,42% |          718.045,79 |
-- +----------------------+-------+---------------+-----------------------+---------------------+
