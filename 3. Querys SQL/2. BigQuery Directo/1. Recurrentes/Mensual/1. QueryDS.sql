DECLARE query_name STRING DEFAULT '1. QueryDS';

DECLARE date_from DATE;
DECLARE date_from_cupons DATE DEFAULT '2025-01-01';
DECLARE max_existing_date DATE;

-- 1. Obtener último mes cargado y calcular date_from
BEGIN
    SET max_existing_date = (
        SELECT MAX(Month)
        FROM `peya-food-and-groceries.automated_tables_reports.daily_monitor`
    );
    -- Si hay datos: recarga solo el último mes | Si no: carga histórica desde 2025-01-01
    SET date_from = COALESCE(max_existing_date, '2025-01-01');
    EXCEPTION WHEN ERROR THEN
    SET date_from = '2025-01-01';
END;

-- 2. Borrar solo el último mes para evitar duplicados
BEGIN
    IF max_existing_date IS NOT NULL THEN
        DELETE FROM `peya-food-and-groceries.automated_tables_reports.daily_monitor`
        WHERE Month = max_existing_date;
    END IF;
    EXCEPTION WHEN ERROR THEN
    SELECT 'Tabla no encontrada. Procediendo con creación inicial...';
END;

-- 3. Creamos la tabla si no existe (FDF_Orders ajustado a INT64 para coincidir con tu DB)
CREATE TABLE IF NOT EXISTS `peya-food-and-groceries.automated_tables_reports.daily_monitor` (
  Year                                INT64   OPTIONS(description='Año del pedido'),
  Month                               DATE    OPTIONS(description='Primer día del mes del pedido (truncado a mes)'),
  Week                                STRING  OPTIONS(description='Semana ISO del pedido en formato YYYY-WW'),
  Country                             STRING  OPTIONS(description='País estandarizado en inglés'),
  Vertical                            STRING  OPTIONS(description='Vertical de negocio (ej: Groceries, Alcohol)'),
  sessions                            INT64   OPTIONS(description='Sesiones únicas en la tienda (funnel_shop_details), excluye Double Ya'),
  transactions                        INT64   OPTIONS(description='Transacciones completadas en sesión (funnel_shop_transaction)'),
  sessions_add_cart                   INT64   OPTIONS(description='Sesiones donde el usuario agregó al carrito'),
  sessions_checkout                   INT64   OPTIONS(description='Sesiones que llegaron al checkout'),
  fx_rate_eur                         FLOAT64 OPTIONS(description='Tipo de cambio promedio de moneda local a EUR para el mes'),
  orders_instant_need                 FLOAT64 OPTIONS(description='Promedio de órdenes de misión instant need (compra de urgencia)'),
  orders_fill_in                      FLOAT64 OPTIONS(description='Promedio de órdenes de misión fill in (reposición parcial)'),
  orders_stock_up                     FLOAT64 OPTIONS(description='Promedio de órdenes de misión stock up (compra de abastecimiento)'),
  units_sold                          FLOAT64 OPTIONS(description='Unidades vendidas en órdenes CONFIRMED'),
  Confirmed_orders                    INT64   OPTIONS(description='Cantidad de órdenes confirmadas'),
  organic_orders                      INT64   OPTIONS(description='Órdenes confirmadas sin ningún tipo de incentivo (voucher ni FDF)'),
  Incentivized_Orders                 INT64   OPTIONS(description='Órdenes confirmadas con algún incentivo: voucher Dmart, PEYA o envío gratis'),
  Voucher_Orders                      INT64   OPTIONS(description='Órdenes confirmadas que usaron cupón (Dmart o PEYA)'),
  FDF_Orders                          INT64   OPTIONS(description='Órdenes con envío gratis aplicado (shipping = 0 y no pickup)'),
  Rejected_orders                     INT64   OPTIONS(description='Cantidad de órdenes rechazadas'),
  Partial_Orders                      INT64   OPTIONS(description='Órdenes CONFIRMED donde la cantidad entregada fue menor a la pedida'),
  total_amount_sold_lc                FLOAT64 OPTIONS(description='Monto total vendido en moneda local con IVA, sin aplicar descuentos'),
  total_amount_sold_net_lc            FLOAT64 OPTIONS(description='Monto total vendido en moneda local sin IVA, sin aplicar descuentos'),
  total_amount_net_with_discounts_lc  FLOAT64 OPTIONS(description='Monto neto (sin IVA) después de aplicar descuentos PCM, en moneda local'),
  net_sales_lc                        FLOAT64 OPTIONS(description='Ventas netas finales en moneda local'),
  front_margin_lc                     FLOAT64 OPTIONS(description='Margen frontal en moneda local: net_sales - COGS'),
  total_discount_wo_vat_lc            FLOAT64 OPTIONS(description='Total de descuentos PCM aplicados sin IVA, en moneda local'),
  net_sales_promotions_lc             FLOAT64 OPTIONS(description='Ventas netas de órdenes con descuento PCM, en moneda local'),
  net_sales_uf_lc                     FLOAT64 OPTIONS(description='Ventas netas de categorías Ultra Fresh y Fresh, en moneda local'),
  DF_net_lc                           FLOAT64 OPTIONS(description='Ingresos netos por delivery fee en moneda local'),
  Service_Fee_lc                      FLOAT64 OPTIONS(description='Ingresos por service fee en moneda local'),
  Dmarts_Vouchers_lc                  FLOAT64 OPTIONS(description='Monto de cupones Dmart utilizados neto de IVA, en moneda local'),
  PEYA_Vouchers_lc                    FLOAT64 OPTIONS(description='Monto de cupones PedidosYa utilizados neto de IVA, en moneda local'),
  max_fecha_fact_orders               TIMESTAMP OPTIONS(description='Fecha máxima de registro en fact_orders'),
  total_amount_sold_eur               FLOAT64 OPTIONS(description='Monto total vendido convertido a EUR'),
  total_amount_sold_net_eur           FLOAT64 OPTIONS(description='Monto total vendido neto convertido a EUR'),
  total_amount_net_with_discounts_eur FLOAT64 OPTIONS(description='Monto neto con descuentos convertido a EUR'),
  net_sales_eur                       FLOAT64 OPTIONS(description='Ventas netas convertidas a EUR'),
  front_margin_eur                    FLOAT64 OPTIONS(description='Margen frontal convertido a EUR'),
  total_discount_wo_vat_eur           FLOAT64 OPTIONS(description='Descuentos PCM convertidos a EUR'),
  net_sales_promotions_eur            FLOAT64 OPTIONS(description='Ventas netas en promoción convertidas a EUR'),
  net_sales_uf_eur                    FLOAT64 OPTIONS(description='Ventas Ultra Fresh y Fresh convertidas a EUR'),
  df_net_eur                          FLOAT64 OPTIONS(description='Delivery fee neto convertido a EUR'),
  service_fee_eur                     FLOAT64 OPTIONS(description='Service fee convertido a EUR'),
  peya_vouchers_eur                   FLOAT64 OPTIONS(description='Cupones PEYA convertidos a EUR'),
  Commercial_sales_lc                 FLOAT64 OPTIONS(description='Ventas netas de campañas con propósito comercial, en moneda local'),
  Lifecycle_sales_lc                  FLOAT64 OPTIONS(description='Ventas netas de campañas de ciclo de vida, en moneda local'),
  commercial_sales_eur                FLOAT64 OPTIONS(description='Ventas comerciales convertidas a EUR'),
  lifecycle_sales_eur                 FLOAT64 OPTIONS(description='Ventas lifecycle convertidas a EUR'),
  multi_buy_sales_lc                  FLOAT64 OPTIONS(description='Ventas netas con descuento tipo multi-buy, en moneda local'),
  percentage_sales_lc                 FLOAT64 OPTIONS(description='Ventas netas con descuento tipo porcentaje, en moneda local'),
  mixmatch_sales_lc                   FLOAT64 OPTIONS(description='Ventas netas con descuento tipo mix & match, en moneda local'),
  multi_buy_sales_eur                 FLOAT64 OPTIONS(description='Ventas multi-buy convertidas a EUR'),
  percentage_sales_eur                FLOAT64 OPTIONS(description='Ventas porcentaje convertidas a EUR'),
  mixmatch_sales_eur                  FLOAT64 OPTIONS(description='Ventas mix & match convertidas a EUR'),
  plus_orders                         INT64   OPTIONS(description='Órdenes confirmadas de usuarios con suscripción Plus'),
  covered_MAUs                        FLOAT64 OPTIONS(description='Usuarios únicos con cobertura de entrega'),
  dmart_MAUs                          FLOAT64 OPTIONS(description='Usuarios únicos que realizaron al menos una orden confirmada (Monthly Active Users)'),
  total_peya_user INT64 OPTIONS(description='Usuarios únicos de PedidosYa con al menos una orden en el mes, por vertical'),
);

-- 4. Insertamos los datos
INSERT INTO `peya-food-and-groceries.automated_tables_reports.daily_monitor`
WITH
-- Datos de ordenes
d AS (
    SELECT
        -- ESTANDARIZACIÓN DEL NOMBRE DEL PAÍS
        CASE d_source.country_name
            WHEN 'Perú' THEN 'Peru'
            WHEN 'Panamá' THEN 'Panama'
            WHEN 'República Dominicana' THEN 'Dominican Republic'
            ELSE d_source.country_name
        END AS Country,

        d_source.warehouse_id AS warehouse_id,
        d_source.vendor_id AS Platform_vendor_id,
        d_source.store_name,
        d_source.order_date,
        d_source.vertical,
        d_source.order_id,
        d_source.state,

        -- Métricas de cantidad (Mantenemos el CAST a FLOAT64 aquí porque actualizaste la tabla a decimales)
        CAST(SUM(d_source.fulfilled_quantity) AS FLOAT64) AS units_sold,
        SUM(d_source.returned_quantity) AS returned_quantity,
        SUM(d_source.ordered_quantity) AS ordered_quantity,

        -- Métricas de montos en moneda local (lc)
        SUM(d_source.total_amount_sold_lc) AS total_amount_sold,
        SUM(d_source.total_amount_sold_net_lc) AS total_amount_sold_net,
        SUM(d_source.pcm_discount_amount_lc) AS total_discount_with_vat,
        SUM(d_source.pcm_discount_amount_net_lc) AS total_discount_wo_vat,
        SUM(d_source.total_amount_sold_lc) - SUM(d_source.pcm_discount_amount_lc) AS total_amount_with_discounts,
        SUM(d_source.total_amount_sold_net_lc) - SUM(d_source.pcm_discount_amount_net_lc) AS total_amount_net_with_discounts,
        SUM(d_source.total_amount_net_with_discount_lc) AS net_sales,
        SUM(d_source.total_cogs_sold_net_lc) AS total_cogs_wo_vat,
        SUM(d_source.total_amount_net_with_discount_lc - d_source.total_cogs_sold_net_lc) AS front_margin,

        -- Métricas de promociones
        SUM(CASE WHEN d_source.pcm_discount_amount_lc > 0 THEN d_source.total_amount_net_with_discount_lc END) AS net_sales_promotions,
        SUM(d_source.pcm_qty_products_applied_discount) AS units_with_discount,

        -- Ventas por TIPO DE DESCUENTO (PCM)
        SUM(CASE WHEN d_source.pcm_discount_subtype = "multi-buy" THEN d_source.total_amount_net_with_discount_lc END) AS multi_buy_sales_lc,
        SUM(CASE WHEN d_source.pcm_discount_subtype = "percentageDiscount" THEN d_source.total_amount_net_with_discount_lc END) AS percentage_sales_lc,
        SUM(CASE WHEN d_source.pcm_discount_subtype = "mix & match" THEN d_source.total_amount_net_with_discount_lc END) AS mixmatch_sales_lc,

        -- Ventas por PROPÓSITO DE CAMPAÑA (PCM)
        SUM(CASE WHEN d_source.campaign_purpose IN ("Competitiveness","NMR","Trading") THEN d_source.total_amount_net_with_discount_lc END) AS Commercial_sales_lc,
        SUM(CASE WHEN d_source.campaign_purpose IN ("Overstock","Delisting","Expiring Soon") THEN d_source.total_amount_net_with_discount_lc END) AS Lifecycle_sales_lc,

        -- Ventas FRESH & ULTRA FRESH
        SUM(IF(d_source.master_category_parent_english IN ( 'Meat / Seafood', 'Produce', 'Ready To Consume'), d_source.total_amount_net_with_discount_lc, 0)) AS sales_uf_fresh_lc

    FROM
        `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` AS d_source
    WHERE
        d_source.order_date >= date_from
    GROUP BY 1,2,3,4,5,6,7,8
),

-- Datos de sesiones
sessions_perseus AS (
    WITH partners AS (
        SELECT DISTINCT vendor_id, vertical
        FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` 
        WHERE order_date >= date_from
    )
    SELECT
        EXTRACT(YEAR FROM DATE(fp.date)) AS year,
        DATE_TRUNC(DATE(fp.date), MONTH) AS month, 
        EXTRACT(ISOWEEK FROM DATE(fp.date)) AS week,
        dc.country_name_en AS country_name,
        partners.vertical AS business_type_name,
        SUM(fp.funnel_shop_details) AS sessions,
        SUM(fp.funnel_shop_add_cart) AS sessions_add_cart,
        SUM(fp.funnel_shop_checkout) AS sessions_checkout,
        SUM(fp.funnel_shop_transaction) AS transactions
    FROM `peya-bi-tools-pro.il_sessions.perseus_fact_partner_funnel` fp
    INNER JOIN partners ON CAST(fp.partner_id AS string) = partners.vendor_id
    LEFT JOIN `peya-bi-tools-pro.il_core.dim_country` dc ON fp.country_id = dc.country_id
    WHERE DATE(fp.date) >= date_from
      AND (fp.funnel_shop_double_ya = 0 OR fp.funnel_shop_double_ya IS NULL)
    GROUP BY ALL
),

-- Datos tipo de cambio
fx AS (
    SELECT
        fx_source.month,
        fx_source.currency_iso,
        c.country_name_en AS country_name,
        AVG(fx_source.rate_eur) AS rate_eur
    FROM
        `peya-fraud-and-fintech.group_finance_data.fact_sap_fx` AS fx_source
    LEFT JOIN
        `peya-bi-tools-pro.il_core.dim_country` AS c ON fx_source.currency_iso = c.currency_price
    WHERE
        c.country_name_en NOT IN ("Venezuela","Puerto Rico")
    GROUP BY 1,2,3
),

-- Datos ordenes de shopping_missions
shopping_missions AS (
    SELECT
        EXTRACT(YEAR FROM sm.registered_date) AS year,
        DATE_TRUNC(sm.registered_date,MONTH) AS month,
        EXTRACT(ISOWEEK FROM sm.registered_date) AS week,
        CASE sm.country_name
            WHEN 'Perú' THEN 'Peru'
            WHEN 'República Dominicana' THEN 'Dominican Republic'
            WHEN 'Panamá' THEN 'Panama'
            ELSE sm.country_name
        END AS country_name,
        sm.business_type_name,
        COUNT(DISTINCT sm.order_id) AS total_orders,
        COUNT(DISTINCT CASE WHEN sm.mission_type = "instant need" THEN sm.order_id END) AS orders_instant_need,
        COUNT(DISTINCT CASE WHEN sm.mission_type = "fill in" THEN sm.order_id END) AS orders_fill_in,
        COUNT(DISTINCT CASE WHEN sm.mission_type = "stock up" THEN sm.order_id END) AS orders_stock_up
    FROM
        `peya-bi-tools-pro.il_qcommerce.fact_groceries_shopping_missions` AS sm
    WHERE
        sm.registered_date >= date_from
        AND sm.is_darkstore
        AND sm.order_status = "CONFIRMED"
    GROUP BY 1,2,3,4,5
),

-- Datos de maus_coverage
total_peya_user AS (
    SELECT
        DATE_TRUNC(cl.registered_date, MONTH) AS month,
        cl.country.country_name               AS country,
        cl.business_type.business_type_description AS vertical,
        COUNT(DISTINCT cl.customer_id)        AS total_peya_user
    FROM `peya-bi-tools-pro.il_core.fact_orders` cl
    WHERE registered_date >= date_from
    GROUP BY 1, 2, 3
),

-- Datos de maus_coverage
maus_coverage AS (
    SELECT
        DATE_TRUNC(cl.month_date, MONTH) AS month,
        dc.country_name_en               AS country,
        COUNT(DISTINCT cl.customer_id)   AS covered_MAUs
    FROM `peya-food-and-groceries.automated_tables_reports.qc_coverage_customer_location` cl
    LEFT JOIN `peya-bi-tools-pro.il_core.dim_country` dc ON cl.country_id = dc.country_id
    WHERE cl.month_date >= date_from
    GROUP BY 1, 2
),

-- Datos de dmart_maus
dmart_maus AS (
    SELECT
        DATE_TRUNC(order_date, MONTH) AS month,
        country_name                  AS country,
        COUNT(DISTINCT customer_id)   AS dmart_MAUs
    FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
    WHERE order_date >= date_from
      AND state = 'CONFIRMED'
    GROUP BY 1, 2
)

SELECT
    EXTRACT(YEAR FROM d.order_date),
    DATE_TRUNC(d.order_date, MONTH),
    FORMAT_DATE('%Y-%V', d.order_date),
    IF(d.Country = 'Dominican Republic', 'Republica Dominicana', d.Country) AS Country,
    d.vertical,
    s_perseus.sessions,
    s_perseus.transactions,
    s_perseus.sessions_add_cart,
    s_perseus.sessions_checkout,
    fx.rate_eur,
    AVG(s_missions.orders_instant_need),
    AVG(s_missions.orders_fill_in),
    AVG(s_missions.orders_stock_up),
    SUM(CASE WHEN UPPER(d.state) = 'CONFIRMED' THEN d.units_sold ELSE NULL END),
    COUNT(DISTINCT CASE WHEN UPPER(d.state) = 'CONFIRMED' THEN d.order_id ELSE NULL END),
    (COUNT(DISTINCT CASE WHEN UPPER(d.state) = 'CONFIRMED' THEN d.order_id ELSE NULL END) -
     COUNT(DISTINCT CASE
        WHEN tc.talon_campaign_name LIKE '%dma_%' AND UPPER(d.state) = 'CONFIRMED' THEN d.order_id
        WHEN f.shipping_amount_no_discount = 0 AND f.pickup = false AND UPPER(d.state) = 'CONFIRMED' THEN d.order_id
        WHEN tc.talon_campaign_name NOT LIKE '%dma_%' AND UPPER(d.state) = 'CONFIRMED' THEN d.order_id
     END)),
    COUNT(DISTINCT CASE
        WHEN tc.talon_campaign_name LIKE '%dma_%' AND UPPER(d.state) = 'CONFIRMED' THEN d.order_id
        WHEN f.shipping_amount_no_discount = 0 AND f.pickup = false AND UPPER(d.state) = 'CONFIRMED' THEN d.order_id
        WHEN tc.talon_campaign_name NOT LIKE '%dma_%' AND UPPER(d.state) = 'CONFIRMED' THEN d.order_id
    END),
    COUNT(DISTINCT CASE
        WHEN tc.talon_campaign_name LIKE '%dma_%' AND UPPER(d.state) = 'CONFIRMED' THEN d.order_id
        WHEN tc.talon_campaign_name NOT LIKE '%dma_%' AND UPPER(d.state) = 'CONFIRMED' THEN d.order_id
    END),
    SUM(CASE WHEN f.shipping_amount_no_discount = 0 AND f.pickup = false AND UPPER(d.state) = 'CONFIRMED' THEN 1 ELSE 0 END), -- <- Vuelve a ser INT64 como espera tu BD
    COUNT(DISTINCT CASE WHEN UPPER(d.state) = 'REJECTED' THEN d.order_id ELSE NULL END),
    COUNT(DISTINCT CASE WHEN UPPER(d.state) = 'CONFIRMED' AND d.ordered_quantity > d.units_sold THEN d.order_id ELSE NULL END),
    SUM(CASE WHEN UPPER(d.state) = 'CONFIRMED' THEN d.total_amount_sold ELSE NULL END),
    SUM(CASE WHEN UPPER(d.state) = 'CONFIRMED' THEN d.total_amount_sold_net ELSE NULL END),
    SUM(CASE WHEN UPPER(d.state) = 'CONFIRMED' THEN d.total_amount_net_with_discounts ELSE NULL END),
    SUM(CASE WHEN UPPER(d.state) = 'CONFIRMED' THEN d.net_sales ELSE NULL END),
    SUM(CASE WHEN UPPER(d.state) = 'CONFIRMED' THEN d.front_margin ELSE NULL END),
    SUM(CASE WHEN UPPER(d.state) = 'CONFIRMED' THEN d.total_discount_wo_vat ELSE NULL END),
    SUM(CASE WHEN UPPER(d.state) = 'CONFIRMED' THEN d.net_sales_promotions ELSE NULL END),
    SUM(CASE WHEN UPPER(d.state) = 'CONFIRMED' THEN d.sales_uf_fresh_lc ELSE NULL END),
    SUM(CASE WHEN UPPER(d.state) = 'CONFIRMED' THEN
        CASE WHEN d.Country = 'Bolivia' THEN f.shipping_amount_no_discount * (1 - cd.percentage_tax_logistics)
             ELSE f.shipping_amount_no_discount / (1 + cd.percentage_tax_logistics)
        END ELSE NULL END),
    SUM(CASE WHEN UPPER(d.state) = 'CONFIRMED' THEN f.service_fee_revenue ELSE NULL END),
    SUM(CASE WHEN tc.talon_campaign_name LIKE '%dma_%' AND UPPER(d.state) = 'CONFIRMED' THEN c.coupon_used_amount / (1 + cd.percentage_effective_tax) ELSE 0 END),
    SUM(CASE WHEN tc.talon_campaign_name NOT LIKE '%dma_%' AND UPPER(d.state) = 'CONFIRMED' THEN c.coupon_used_amount / (1 + cd.percentage_effective_tax) ELSE 0 END),
    CAST(MAX(f.registered_date) AS TIMESTAMP),
    SAFE_DIVIDE(SUM(CASE WHEN UPPER(d.state) = 'CONFIRMED' THEN d.total_amount_sold ELSE NULL END), fx.rate_eur),
    SAFE_DIVIDE(SUM(CASE WHEN UPPER(d.state) = 'CONFIRMED' THEN d.total_amount_sold_net ELSE NULL END), fx.rate_eur),
    SAFE_DIVIDE(SUM(CASE WHEN UPPER(d.state) = 'CONFIRMED' THEN d.total_amount_net_with_discounts ELSE NULL END), fx.rate_eur),
    SAFE_DIVIDE(SUM(CASE WHEN UPPER(d.state) = 'CONFIRMED' THEN d.net_sales ELSE NULL END), fx.rate_eur),
    SAFE_DIVIDE(SUM(CASE WHEN UPPER(d.state) = 'CONFIRMED' THEN d.front_margin ELSE NULL END), fx.rate_eur),
    SAFE_DIVIDE(SUM(CASE WHEN UPPER(d.state) = 'CONFIRMED' THEN d.total_discount_wo_vat ELSE NULL END), fx.rate_eur),
    SAFE_DIVIDE(SUM(CASE WHEN UPPER(d.state) = 'CONFIRMED' THEN d.net_sales_promotions ELSE NULL END), fx.rate_eur),
    SAFE_DIVIDE(SUM(CASE WHEN UPPER(d.state) = 'CONFIRMED' THEN d.sales_uf_fresh_lc ELSE NULL END), fx.rate_eur),
    SAFE_DIVIDE(SUM(CASE WHEN UPPER(d.state) = 'CONFIRMED' THEN
        CASE WHEN d.Country = 'Bolivia' THEN f.shipping_amount_no_discount * (1 - cd.percentage_tax_logistics)
             ELSE f.shipping_amount_no_discount / (1 + cd.percentage_tax_logistics)
        END ELSE NULL END), fx.rate_eur),
    SAFE_DIVIDE(SUM(CASE WHEN UPPER(d.state) = 'CONFIRMED' THEN f.service_fee_revenue ELSE NULL END), fx.rate_eur),
    SAFE_DIVIDE(SUM(CASE WHEN tc.talon_campaign_name NOT LIKE '%dma_%' AND UPPER(d.state) = 'CONFIRMED' THEN c.coupon_used_amount / (1 + cd.percentage_effective_tax) ELSE 0 END), fx.rate_eur),
    SUM(CASE WHEN UPPER(d.state) = 'CONFIRMED' THEN d.Commercial_sales_lc ELSE NULL END),
    SUM(CASE WHEN UPPER(d.state) = 'CONFIRMED' THEN d.Lifecycle_sales_lc ELSE NULL END),
    SAFE_DIVIDE(SUM(CASE WHEN UPPER(d.state) = 'CONFIRMED' THEN d.Commercial_sales_lc ELSE NULL END), fx.rate_eur),
    SAFE_DIVIDE(SUM(CASE WHEN UPPER(d.state) = 'CONFIRMED' THEN d.Lifecycle_sales_lc ELSE NULL END), fx.rate_eur),
    SUM(CASE WHEN UPPER(d.state) = 'CONFIRMED' THEN d.multi_buy_sales_lc ELSE NULL END),
    SUM(CASE WHEN UPPER(d.state) = 'CONFIRMED' THEN d.percentage_sales_lc ELSE NULL END),
    SUM(CASE WHEN UPPER(d.state) = 'CONFIRMED' THEN d.mixmatch_sales_lc ELSE NULL END),
    SAFE_DIVIDE(SUM(CASE WHEN UPPER(d.state) = 'CONFIRMED' THEN d.multi_buy_sales_lc ELSE NULL END), fx.rate_eur),
    SAFE_DIVIDE(SUM(CASE WHEN UPPER(d.state) = 'CONFIRMED' THEN d.percentage_sales_lc ELSE NULL END), fx.rate_eur),
    SAFE_DIVIDE(SUM(CASE WHEN UPPER(d.state) = 'CONFIRMED' THEN d.mixmatch_sales_lc ELSE NULL END), fx.rate_eur),
    COUNT(DISTINCT CASE WHEN f.order_status = 'CONFIRMED' AND f.is_user_plus = 1 THEN f.order_id END),
    ANY_VALUE(maus_coverage.covered_MAUs),
    ANY_VALUE(dmart_maus.dmart_MAUs),
    ANY_VALUE(tpu.total_peya_user) AS total_peya_user,
FROM d
LEFT JOIN `peya-bi-tools-pro.il_core.fact_orders` AS f
    ON SAFE_CAST(d.order_id AS INT64) = f.order_id
INNER JOIN `peya-data-origins-pro.cl_core.country_details` AS cd
    ON cd.country_id = f.restaurant.country.id
INNER JOIN `peya-bi-tools-pro.il_core.dim_country` AS dc
    ON dc.country_id = f.restaurant.country.id AND dc.active
LEFT JOIN `peya-bi-tools-pro.il_growth.fact_talon_coupons` AS c
    ON c.order_id = f.order_id
    AND DATE(c.coupon_created_at) >= date_from_cupons
LEFT JOIN `peya-bi-tools-pro.il_growth.dim_talon_campaigns` AS tc
    ON tc.talon_campaign_id = c.talon_campaign_id
LEFT JOIN sessions_perseus AS s_perseus
    ON d.vertical = s_perseus.business_type_name
    AND DATE_TRUNC(d.order_date, MONTH) = s_perseus.month
    AND EXTRACT(ISOWEEK FROM d.order_date) = s_perseus.week
    AND d.Country = s_perseus.country_name
LEFT JOIN fx
    ON DATE_TRUNC(d.order_date, MONTH) = fx.month
    AND d.Country = fx.country_name
LEFT JOIN shopping_missions AS s_missions
    ON d.vertical = s_missions.business_type_name
    AND DATE_TRUNC(d.order_date, MONTH) = s_missions.month
    AND EXTRACT(ISOWEEK FROM d.order_date) = s_missions.week
    AND d.Country = s_missions.country_name
LEFT JOIN maus_coverage
    ON DATE_TRUNC(d.order_date, MONTH) = maus_coverage.month
    AND d.Country                      = maus_coverage.country
LEFT JOIN dmart_maus
    ON DATE_TRUNC(d.order_date, MONTH) = dmart_maus.month
    AND d.Country                      = dmart_maus.country
LEFT JOIN total_peya_user AS tpu
    ON DATE_TRUNC(d.order_date, MONTH) = tpu.month
    AND d.Country = tpu.country
    AND d.vertical = tpu.vertical
WHERE DATE(f.registered_date) >= date_from
GROUP BY
    EXTRACT(YEAR FROM d.order_date),
    DATE_TRUNC(d.order_date, MONTH),
    FORMAT_DATE('%Y-%V', d.order_date),
    d.Country,
    d.vertical,
    s_perseus.sessions,
    s_perseus.transactions,
    s_perseus.sessions_add_cart,
    s_perseus.sessions_checkout,
    fx.rate_eur;