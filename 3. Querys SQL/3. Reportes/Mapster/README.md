# 🗺️ Mapster (All-Map) — Inteligencia Geoespacial y Rendimiento 360° de Darkstores

**Mapster** es la suite de análisis territorial y operacional de **PedidosYa Market (D-Marts)**. Combina geometría espacial (polígonos de reparto de Hurrier, áreas en $km^2$, distancias y cuadrículas) con rendimiento comercial, fulfilment y salud de clientes.

Este directorio contiene todo el código SQL del ecosistema Mapster, dividido en **3 capas bien delimitadas según su propósito de consumo**:

---

## 🏛️ Las 3 Capas de Mapster

```text
3. Reportes/Mapster/
│
├── 1. Conexiones Sheets/               <── Conectores directos para la planilla Google Sheets
│   ├── 12. Mapster - Base - Performance (WHS data).sql
│   └── 12. Mapster - Base - Performance (WHS orders).sql
│
├── 2. Core & API/                      <── Suite de inteligencia espacial para la Web App All-Map
│   ├── 01_geometria_y_shapes_warehouse.sql
│   ├── 02_analisis_anillos_concentricos.sql
│   ├── 03_censo_cuadrantes_manzanas.sql
│   ├── 04_rendimiento_360_darkstore.sql
│   ├── 05_penetracion_macro_ciudad.sql
│   ├── GUIA_ESTUDIO_SQL.md
│   └── README_AUDITORIA_SQL.md
│
└── 3. Modelos & Datamarts/             <── Cimientos pesados de modelado de datos en BigQuery
    ├── dim_warehouse_all_partners_master.sql
    ├── dim_warehouse_footprint_master.sql
    ├── datamart_warehouse_shape_analytics.sql
    ├── datamart_warehouse_ops_and_users_performance.sql
    └── crear_tabla_externa_whs_master.sql
```

---

## 📘 Detalle Consulta por Consulta

### 📁 Capa 1: `Conexiones Sheets/`
Consultas livianas optimizadas específicamente para Connected Sheets. Alimentan la planilla `12. Mapster - Base - Performance.gsheet` en Google Drive:

| Archivo SQL | Pestaña en Google Sheets | Grano (1 fila por...) | Tablas Principales | Qué resuelve / Lógica clave |
|---|---|---|---|---|
| **`12. Mapster - Base - Performance (WHS data).sql`** | `1. WHS data` | `(month_date, warehouse_id, partner_id)` | `dim_partner`, `cl_hurrier.vendors_delivery_areas`, `vendor_delivery_area_shapes`, `fact_orders` | **Catálogo de locales y polígonos Hurrier:** Lista cada almacén físico y todos sus partners asociados. Extrae el polígono real oficial de Hurrier (`shape_geojson`), calcula el área en $km^2$ y genera el flag `same_shape_as_main` (detecta si los partners secundarios cubren exactamente el mismo mapa que la tienda principal). |
| **`12. Mapster - Base - Performance (WHS orders).sql`** | `2. WHS orders` | `(month_date, warehouse_id)` | `dmart_metrics_by_whs_daily`, `dim_partner`, `fact_orders` | **Rendimiento mensual por almacén:** Agrupa métricas mensuales de ventas y logística (órdenes confirmadas, GMV, ticket promedio, Seamless %, fallas, tiempo de entrega y Open Time %). Consume directamente la tabla oficial `dmart_metrics_by_whs_daily` para coincidir al 100% con los reportes diarios de Ops. |

---

### 📁 Capa 2: `Core & API/`
Las 5 consultas maestras utilizadas por la aplicación web **All-Map** (`1. Reportes/5. All-Map`) para procesar mapas interactivos, visualizaciones espaciales y analítica avanzada:

| N° | Archivo SQL | Función Única | Grano | Tablas de Origen | Lógica de Negocio |
|:---:|---|---|---|---|---|
| **01** | **`01_geometria_y_shapes_warehouse.sql`** | **Geometría y Terreno** | `(month_date, warehouse_id)` | `dim_partner`, `qc_coverage_partner_shapes`, `fact_orders` | Determina las coordenadas físicas exactas del local y su polígono de reparto histórico en formato `GEOGRAPHY`. Calcula `ST_AREA(shape) / 1000000.0` ($km^2$) y el centroide de cobertura. |
| **02** | **`02_analisis_anillos_concentricos.sql`** | **Radios de Cobertura** | `(month_date, warehouse_id, anillo)` | `qc_coverage_partner_shapes`, `qc_coverage_customer_location`, `customer_orders_sku_level`, `dmarts_timings` | Mide la fricción por distancia desglosando la demanda en anillos concéntricos ($<1\text{ km}$, $1-2\text{ km}$, $2-3\text{ km}$, $>3\text{ km}$, y Sin Cobertura). Evalúa cómo cae la conversión y sube el tiempo de entrega a mayor distancia. |
| **03** | **`03_censo_cuadrantes_manzanas.sql`** | **Censo Micro Cuadra a Cuadra** | `(month_date, cell_id)` | `qc_coverage_customer_location`, `fact_orders`, `dim_partner` | Divide el territorio en celdas espaciales $N \times N$. Identifica cuántos usuarios de PedidosYa residen en cada cuadrícula vs cuántos compran en Darkstores, generando el mapa de calor (Heatmap) para expansión. |
| **04** | **`04_rendimiento_360_darkstore.sql`** | **Rendimiento 360° + Motor Frank** | `(month_date, warehouse_id)` | `fact_orders`, `customer_orders_sku_level`, `non_seamless_delivery_order_level`, `dmarts_timings`, `frank_user_type_monthly` | Cruza ventas, órdenes, Ultra Fresh (frutas/verduras/carnes) y fulfilment con la **taxonomía de usuarios Frank** (*New Users*, *M1 Return*, *Reorder*, *Recurring Return*, *Re-Activation*). |
| **05** | **`05_penetracion_macro_ciudad.sql`** | **Penetración Macro Ciudad** | `(month_date, country, city)` | `fact_orders`, `dim_partner`, `dim_user` | Calcula a nivel ciudad y país la cuota de mercado de D-Marts sobre la base total de usuarios de la aplicación ($\frac{\text{Dmart MAUs}}{\text{Platform MAUs}} \times 100$). |

*Nota: Esta carpeta incluye además `GUIA_ESTUDIO_SQL.md` (manual didáctico de cada fórmula) y `README_AUDITORIA_SQL.md` (validación de compilación y consumos de escaneo en BigQuery).*

---

### 📁 Capa 3: `Modelos & Datamarts/`
Modelos de datos pesados y tablas base de infraestructura reutilizables por todo el equipo:

| Archivo SQL | Tipo | Grano | Propósito |
|---|---|---|---|
| **`dim_warehouse_all_partners_master.sql`** | Dimensión Maestra | `(month_date, warehouse_id)` | Resuelve la red de tiendas físicas y sus múltiples IDs de restaurante (`partner_id`), identificando el partner principal por volumen y agrupando los secundarios en arrays estructurados. |
| **`dim_warehouse_footprint_master.sql`** | Dimensión Geográfica | `(month_date, warehouse_id)` | Construye el footprint espacial mensual: coordenadas, centroides y polígonos de reparto de cada local. |
| **`datamart_warehouse_shape_analytics.sql`** | Datamart Territorial | `(month_date, warehouse_id)` | Cruza los polígonos con métricas de terreno, demografía de la zona, penetración de mercado y tiempos logísticos. |
| **`datamart_warehouse_ops_and_users_performance.sql`** | Datamart Integral | `(month_date, warehouse_id)` | Combina en una sola tabla la segmentación de clientes (*Core Users, High Income, AFV, Tenure*) con los KPIs de operación (*Seamless delivery, Fail rate, Tiempos de entrega, Inaccuracy*). |
| **`crear_tabla_externa_whs_master.sql`** | DDL (Conector Externo) | N/A | Script DDL para crear en BigQuery la tabla externa `ext_dim_warehouse_master`, vinculada en tiempo real a la planilla maestra de Google Sheets de Darkstores. |

---

## 🔍 ¿Por qué antes no coincidía la cantidad de pedidos de un Market?

Si consultabas diferentes queries de Mapster, podías notar discrepancias en las órdenes de una misma tienda. Estas son las **5 razones técnicas exactas**:

1. **Diferente Tabla de Origen:**
   * `WHS data` consultaba `customer_orders_sku_level` (tabla a nivel producto facturado; pedidos cancelados en picking o sin líneas no aparecen).
   * `WHS orders` consume `dmart_metrics_by_whs_daily` (tabla operacional diaria agregada).
   * `04_rendimiento_360` leía directamente de `fact_orders` con `order_status = 'CONFIRMED'`.
2. **Suma de Partners del Local:**
   * Un Warehouse físico puede tener más de un `partner_id` histórico (por cambios de razón social, pickup o cuentas de prueba). Algunas queries sumaban **todos los partners** del warehouse, mientras que otras se quedaban únicamente con el **partner principal**.
3. **Filtro de Courier:**
   * Las consultas de operaciones excluyen `Courier` y `Courier Business`. Otras consultas de BigQuery no aplicaban este filtro y sumaban paquetes externos despachados desde la misma dirección.
4. **Pickup vs Delivery:**
   * Filtrar por `pickup = FALSE` y `with_logistics = TRUE` cuenta únicamente despachos a domicilio con flota de PedidosYa. Si no se filtra, se suman las compras con retiro en el local físico.
5. **Corte Horario (UTC vs Hora Local):**
   * En `fact_orders`, la fecha `registered_date` está en **UTC**. En cambio, `dmart_metrics_by_whs_daily` agrupa por `fecha` en **hora local de cada país**. Además, los filtros `<= end_month` (ej. `<= 2026-11-01`) excluyen los pedidos del mes en curso si no se utiliza `< DATE_ADD(end_month, INTERVAL 1 MONTH)`.

### 🎯 Regla de Oro Canónica
Para que el conteo mensual de pedidos de un market sea **100% idéntico** en todos los reportes, la fuente única certificada es:
```sql
SELECT 
  DATE_TRUNC(fecha, MONTH) AS month_date,
  warehouse_id,
  SUM(confirmed_orders)    AS total_orders
FROM `peya-food-and-groceries.automated_tables_reports.dmart_metrics_by_whs_daily`
GROUP BY 1, 2;
```
*(Lógica implementada oficialmente en `12. Mapster - Base - Performance (WHS orders).sql`).*
