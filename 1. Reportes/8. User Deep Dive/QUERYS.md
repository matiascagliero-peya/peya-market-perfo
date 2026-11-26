# Reporte Web App: Customer Deep Dive 360°

## 1. Objetivo y Alcance
Proporcionar una radiografía minuciosa e integral de cualquier cliente de PedidosYa (con foco analítico en PeYa Market), buscando por **User ID** (numérico, ej. `22543952`) o por **Customer ID** (hash string, ej. `D6qWtjm11m1lrDuInjHhHA`).

El reporte expone:
- Perfil demográfico, estado Plus y segmentación (`dim_user`).
- Evolución histórica mes a mes de su clasificación taxonómica L1 y L2 (`frank_user_type_monthly` y `frank_user_monthly_activity`).
- Detalle de cada orden ejecutada en los últimos 3 años (`fact_orders`), discriminando montos, descuentos de voucher, bonificación de envío Plus y comercios.
- Desglose granular de cada línea de producto (SKU) adquirida en PeYa Market (`customer_orders_sku_level`), con precios unitarios, cantidades cumplidas, descuentos PCM, flags Ultra Fresh y darkstores asociadas.
- Preferencias de horario, días de compra y comercios favoritos.
- Visor de auditoría JSON Raw con el 100% de los datos crudos devueltos por BigQuery.

---

## 2. Fuentes de Datos y Consultas SQL

### Consulta 1: Perfil Dimensional (`UserDeepDive_1_DimUser`)
* **Tabla Origen:** `peya-bi-tools-pro.il_core.dim_user`
* **Campos clave:** `user_id`, `customer_id`, `nickname`, `country`, `registered_date`, `first_order_date`, `last_order_date`, `order_count`, `segment`, `lifecycle_stage`, `is_plus`, `qc_user`, `dm_user`, `online_payment_user`.
* **Propósito:** Resuelve la identidad, antigüedad en la aplicación y suscripciones activas.

### Consulta 2: Actividad Mensual y Taxonomía Frank (`UserDeepDive_2_MonthlyActivityAndType`)
* **Tablas Origen:**
  - `peya-food-and-groceries.automated_tables_reports.frank_user_monthly_activity`
  - `peya-food-and-groceries.automated_tables_reports.frank_user_type_monthly`
* **Campos clave:** `month`, `Platform_Actual_Type`, `Platform_Actual_type_ternure`, `Market_Actual_Type`, `Market_Actual_type_ternure`, `L2_Market_Actual_Type`, `AAA_Actual_Type`, `orders_platform`, `orders_dmart`, `orders_uf_dmart`, `orders_dy_dmart`, `units_sold_dmart`, `net_sales_dmart_eur`, `DY_order`, `UF_order`.
* **Propósito:** Reconstruye la evolución del ciclo de vida del cliente en Plataforma, Market y Retailers AAA.

### Consulta 3: Log Transaccional de Órdenes (`UserDeepDive_3_FactOrders`)
* **Tabla Origen:** `peya-bi-tools-pro.il_core.fact_orders`
* **Partición:** `registered_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 36 MONTH)`
* **Filtros:** `country_id`, `customer_id`, `user.id`.
* **Campos clave:** `registered_at`, `order_id`, `business_type`, `partner_name`, `city`, `order_status`, `confirmed_total_amount`, `shipping_amount`, `voucher_discount_amount`, `plus_shipping_discount`, `delivery_type`.
* **Propósito:** Registro cronológico de todas las compras en Restaurantes, Supermercados y Darkstores.

### Consulta 4: Canasta y SKUs Granulares (`UserDeepDive_4_MarketSkuDetails`)
* **Tabla Origen:** `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
* **Partición:** `order_date >= '2025-01-01'`
* **Filtros:** `country_code`, `customer_id`, `user_id`, `state = 'CONFIRMED'`.
* **Campos clave:** `order_date`, `order_id`, `store_name`, `sku_id`, `product_name`, `brand_name`, `master_category_parent_english`, `category_local`, `fulfilled_quantity`, `listed_unit_price_lc`, `paid_unit_price_lc`, `total_amount_sold_lc`, `total_amount_net_with_discount_eur`, `pcm_discount_percentage`, `pcm_discount_amount_lc`, `is_uf`.
* **Propósito:** Análisis a nivel ítem de la canasta de compras de PeYa Market.

---

## 3. Despliegue en Google Apps Script
1. Crear un nuevo proyecto en [script.google.com](https://script.google.com).
2. En la configuración del proyecto (`Configuración del proyecto` -> `Archivo de manifiesto appsscript.json`), habilitar el editor de manifiesto y pegar el contenido de `appsscript.json`.
3. En la sección **Servicios** (`+ Servicios`), agregar el servicio avanzado **BigQuery (v2)**.
4. Crear los archivos de código:
   - `Code.gs` (copiar contenido de `Code.gs`).
   - `Index.html` (copiar contenido de `Index.html`).
5. Publicar como **Aplicación Web**:
   - `Implementar` -> `Nueva implementación` -> Tipo: `Aplicación web`.
   - Ejecutar como: `Usuario que implementa` o `Usuario que accede`.
   - Quién tiene acceso: `Cualquiera dentro de la organización (pedidosya.com)`.
6. Parámetros de URL soportados:
   - `?user_id=22543952`
   - `?id=D6qWtjm11m1lrDuInjHhHA`
