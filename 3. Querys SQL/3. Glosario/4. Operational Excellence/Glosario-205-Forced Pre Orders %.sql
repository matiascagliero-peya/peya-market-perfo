DECLARE query_name STRING DEFAULT 'Glosario-205-Forced Pre Orders %';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 205
-- Nombre:     Forced Pre Orders %
-- Chapter:   Operational Excellence
-- Query bajada en: 1 - OPS Data
-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo
-- Tablas de origen: `peya-datamarts-pro.dm_fulfillment.non_seamless_delivery_order_level` + `peya-bi-tools-pro.il_core.fact_orders` + `peya-bi-tools-pro.il_core.dim_partner`
-- Tipo:       Ratio Calculado
-- Fórmula:    Forced Pre Orders / Total Orders All Status
-- Definición: Porcentaje de pedidos programados forzosamente como pre-órdenes diferidas debido a saturación o falta de capacidad operativa.
-- ====================================================================================

SELECT
  o.country.country_name AS country,
  DATE_TRUNC(DATE(o.registered_date), MONTH) AS month,
  COUNT(DISTINCT CASE WHEN CAST(ns.is_forced_preorder AS STRING) IN ('1','true','TRUE') THEN o.order_id END) AS forced_pre_orders,
  COUNT(DISTINCT o.order_id) AS total_orders_all_status,
  SAFE_DIVIDE(
    COUNT(DISTINCT CASE WHEN CAST(ns.is_forced_preorder AS STRING) IN ('1','true','TRUE') THEN o.order_id END),
    NULLIF(COUNT(DISTINCT o.order_id), 0)
  ) AS forced_pre_orders_pct
FROM `peya-bi-tools-pro.il_core.fact_orders` o
INNER JOIN `peya-bi-tools-pro.il_core.dim_partner` p ON o.restaurant.id = p.partner_id
LEFT JOIN `peya-datamarts-pro.dm_fulfillment.non_seamless_delivery_order_level` ns
  ON CAST(o.order_id AS STRING) = CAST(ns.platform_order_code AS STRING)
WHERE p.is_darkstore = TRUE
  AND DATE(o.registered_date) BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +----------------------+-------------------+-----------------------+-------+-------------------------+
-- | country              | forced_pre_orders | forced_pre_orders_pct | month | total_orders_all_status |
-- +----------------------+-------------------+-----------------------+-------+-------------------------+
-- | Argentina            |             5.024 |                 0,19% | 2.026 |               2.689.254 |
-- | Bolivia              |                65 |                 0,05% | 2.026 |                 144.397 |
-- | Chile                |                 0 |                 0,00% | 2.026 |                 346.919 |
-- | Ecuador              |                 0 |                 0,00% | 2.026 |                  98.848 |
-- | El Salvador          |                 0 |                 0,00% | 2.026 |                  87.268 |
-- | Guatemala            |                31 |                 0,03% | 2.026 |                  97.654 |
-- | Honduras             |                 0 |                 0,00% | 2.026 |                  51.377 |
-- | Nicaragua            |                 0 |                 0,00% | 2.026 |                  56.933 |
-- | Panam�               |                 0 |                 0,00% | 2.026 |                  94.071 |
-- | Paraguay             |                 0 |                 0,00% | 2.026 |                 137.201 |
-- | Per�                 |                24 |                 0,01% | 2.026 |                 277.278 |
-- | Rep�blica Dominicana |                 0 |                 0,00% | 2.026 |                 173.094 |
-- | Uruguay              |               943 |                 0,32% | 2.026 |                 290.698 |
-- +----------------------+-------------------+-----------------------+-------+-------------------------+
