# Guía de Estudio de Consultas SQL — All-Map (Spatial Intelligence)

Bienvenido a la arquitectura de datos geoespaciales y transaccionales de **PedidosYa Market (D-Marts)**.

Este directorio fue estructurado para que puedas **estudiar, comprender y auditar paso a paso** el funcionamiento de la inteligencia territorial sin redundancias ni fragmentaciones innecesarias.

---

## 🏛️ Mapa de los 5 Pilares Maestros

Cada archivo resuelve **una sola función de negocio bien delimitada**:

```
PeYa Market/1. Reportes/5. All-Map/SQL/
├── 01_geometria_y_shapes_warehouse.sql   --> [Pilar 1: Terreno y Cobertura]
├── 02_analisis_anillos_concentricos.sql  --> [Pilar 2: Penetración por Radios]
├── 03_censo_cuadrantes_manzanas.sql      --> [Pilar 3: Censo Micro Cuadra a Cuadra]
├── 04_rendimiento_360_darkstore.sql      --> [Pilar 4: Visión Holística WHS/Mes + Frank]
├── 05_penetracion_macro_ciudad.sql       --> [Pilar 5: KPIs Macro por Ciudad y País]
├── GUIA_ESTUDIO_SQL.md                   --> [Esta Guía Didáctica]
└── backup_referencia/                    --> [12 consultas históricas y desgloses previos]
```

---

## 📘 Detalle Didáctico de cada Pilar para Estudiar

### 📍 Pilar 1: `01_geometria_y_shapes_warehouse.sql`
* **Pregunta de Negocio:** *¿Dónde está ubicada físicamente cada darkstore y cuál es su polígono oficial de reparto (Shape) mes a mes?*
* **Función:** Generar la dimensión maestra espacial de almacenes.
* **Tablas que consulta:**
  * `dim_partner` (coordenadas geográficas `latitude`, `longitude` del local).
  * `qc_coverage_partner_shapes` (polígonos mensuales `partner_shape` en formato GEOGRAPHY).
  * `fact_orders` (filtro de actividad real para descartar tiendas de prueba o cerradas).
* **Conceptos clave a aprender:**
  * `ST_AREA(shape) / 1000000.0`: Cálculo de superficie en kilómetros cuadrados ($km^2$).
  * `ST_CENTROID(shape)`: Centro de gravedad geométrico del área de cobertura.
  * `ST_ASGEOJSON(shape)`: Conversión a formato JSON compatible con Google Maps y Mapbox.

---

### ⭕ Pilar 2: `02_analisis_anillos_concentricos.sql`
* **Pregunta de Negocio:** *¿Cómo cae la demanda, el tiempo de entrega y la penetración a medida que nos alejamos de la tienda (< 1 km, 1-2 km, 2-3 km)?*
* **Función:** Descomponer el servicio en anillos de fricción geográfica.
* **Tablas que consulta:**
  * `qc_coverage_partner_shapes` (polígono de la tienda).
  * `qc_coverage_customer_location` (domicilio del cliente `customer_geogpoint`).
  * `customer_orders_sku_level` (facturación neta, unidades y pedidos con categorías Ultra Fresh).
  * `dmarts_timings` (tiempos reales de entrega `actual_dt_min` y demoras `is_order_late_10`).
* **Conceptos clave a aprender:**
  * `ST_DISTANCE(cliente, tienda)`: Distancia euclídea/geodésica en metros.
  * `Covered_MAUs` vs `Dmart_MAUs_Covered`: Usuarios que tienen la tienda disponible vs los que efectivamente compraron.
  * `Sin Cobertura`: Pedidos entregados fuera del polígono oficial del mes (desbordes de frontera, mal tiempo o pickup).

---

### 🔲 Pilar 3: `03_censo_cuadrantes_manzanas.sql`
* **Pregunta de Negocio:** *Si divido la ciudad en una cuadrícula $N \times N$, ¿cuántos usuarios viven y cuántos compran en cada recuadro/esquina?*
* **Función:** Censo territorial micro de demanda latente para expansión o redistribución de shapes.
* **Tablas que consulta:**
  * `qc_coverage_customer_location` (coordenadas domiciliarias de los usuarios).
  * `fact_orders` y `dim_partner` (compras confirmadas en darkstores).
* **Conceptos clave a aprender:**
  * `ST_CONTAINS(celda_geom, customer_geogpoint)`: Asignación booleana espacial de punto dentro de polígono.
  * `platform_users`: Densidad total de usuarios de PedidosYa en esa celda (usada para la escala de calor del mapa).
  * `penetration_pct`: Cuota de mercado de darkstores en esa cuadrícula específica.

---

### 📊 Pilar 4: `04_rendimiento_360_darkstore.sql`
* **Pregunta de Negocio:** *¿Cómo le va a cada darkstore integralmente en ventas, usuarios, ticket, logística y fidelidad de clientes?*
* **Función:** Datamart integral mensual por tienda (el corazón de los reportes ejecutivos).
* **Tablas que consulta:**
  * `dim_partner` + `fact_orders` (ventas brutas, clientes únicos, frecuencia).
  * `customer_orders_sku_level` (ventas netas en EUR, unidades, Ultra Fresh Produce/Meat).
  * `non_seamless_delivery_order_level` (Fulfillment: pedidos lentos, cancelados o rechazados).
  * `dmarts_timings` (minutos de entrega, atrasos >10m y tiempo de picking de artículos en góndola).
  * `frank_user_type_monthly` (**Motor Frank:** clasificación de clientes en *New User*, *M1 Return*, *Reorder*, *Recurring Return*, *Re-Activation*).
* **Conceptos clave a aprender:**
  * `Seamless %`: Porcentaje de pedidos entregados sin fallas de stock, rechazos ni demoras excesivas.
  * `Ultra Fresh Share %`: Penetración de frescos (frutas, verduras, carnes) como palanca de retención y recurrencia.
  * `Taxonomía Frank`: Medición de salud de la base de usuarios por darkstore.

---

### 🌆 Pilar 5: `05_penetracion_macro_ciudad.sql`
* **Pregunta de Negocio:** *A nivel macro, ¿qué porcentaje de los usuarios totales de la app en la ciudad compran en supermercado?*
* **Función:** Visión agregada para Gerencia y Dirección (City & Country Level).
* **Tablas que consulta:**
  * `fact_orders` + `dim_partner` (cálculo de Platform MAUs cruzando todos los restaurantes y verticales de la ciudad).
* **Conceptos clave a aprender:**
  * `City Penetration %`: $\frac{\text{Dmart MAUs de la Ciudad}}{\text{Platform MAUs de la Ciudad}} \times 100$. Permite identificar en qué ciudades la vertical de supermercados tiene espacio para duplicar su tamaño.

---

## 🗄️ Carpeta `backup_referencia/`
Para garantizar que nunca se pierda ningún desarrollo previo, las 12 consultas intermedias anteriores se encuentran intactas en la subcarpeta `backup_referencia/`:
* Desgloses parciales (`1. warehouse_users`, `2. warehouse_orders`, `3. warehouse_ops`).
* Consultas de extracción para Google Sheets (`14. Mapster (WHS orders)`).
* Datamarts preliminares de prueba.
