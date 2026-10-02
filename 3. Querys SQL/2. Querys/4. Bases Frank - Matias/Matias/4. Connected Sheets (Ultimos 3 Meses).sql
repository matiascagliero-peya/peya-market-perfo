-- ==============================================================================
-- QUERY PARA CONNECTED SHEETS: Últimos 3 Meses Cerrados
--
-- Tabla origen: peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary
-- Filtro: Últimos 3 meses completos (excluye el mes en curso)
-- ==============================================================================

SELECT
    Mes,
    country,
    Market_Actual_Type,
    L2_Actual_Type,

    -- Métricas de Usuarios y Share
    users_count,
    users_share_pct,

    -- Órdenes
    confirmed_orders,
    confirmed_orders_uf,
    confirmed_orders_dy,

    -- Facturación y Unidades
    net_sales_eur,
    units_sold,

    -- Unit Economics y Ratios
    basket_size,
    afv,
    frequency,
    monthly_customer_units,
    uf_user_penetration_pct,

    -- Tenures
    avg_actual_tenure,
    avg_adoption_tenure

FROM `peya-food-and-groceries.automated_tables_reports.frank_user_metrics_summary`
WHERE Mes >= DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 MONTH), MONTH)
  AND Mes < DATE_TRUNC(CURRENT_DATE(), MONTH)
ORDER BY Mes DESC, country, users_count DESC;
