# Índice de Consultas SQL y Auditoría Oficial — All-Map

Este directorio contiene las **5 consultas maestras oficiales** de la suite de inteligencia espacial de **PedidosYa Market (D-Marts)**, optimizadas y certificadas en vivo contra Google Cloud BigQuery.

---

## 🏛️ Las 5 Consultas Maestras Oficiales

| N° | Archivo SQL | Función Única | Grano | Tablas Principales |
| :---: | :--- | :--- | :--- | :--- |
| **01** | `01_geometria_y_shapes_warehouse.sql` | **Geometría y Terreno** | `(month_date, warehouse_id)` | `dim_partner`, `qc_coverage_partner_shapes`, `fact_orders` |
| **02** | `02_analisis_anillos_concentricos.sql` | **Radios Concéntricos** | `(month_date, warehouse_id, anillo)` | `qc_coverage_customer_location`, `customer_orders_sku_level`, `dmarts_timings` |
| **03** | `03_censo_cuadrantes_manzanas.sql` | **Censo Micro Cuadrículas** | `(month_date, cell_id)` | `qc_coverage_customer_location`, `fact_orders`, `dim_partner` |
| **04** | `04_rendimiento_360_darkstore.sql` | **Rendimiento 360° + Frank** | `(month_date, warehouse_id)` | `fact_orders`, `customer_orders_sku_level`, `non_seamless_delivery_order_level`, `dmarts_timings`, `frank_user_type_monthly` |
| **05** | `05_penetracion_macro_ciudad.sql` | **Penetración Macro Ciudad** | `(month_date, country, city)` | `fact_orders`, `dim_partner`, `dim_user` |

---

## ✅ Certificación de Compilación y Validación en BigQuery

Las 5 consultas fueron auditadas mediante **ejecución en vivo (`--dry_run`) contra el motor de Google Cloud BigQuery** (`peya-food-and-groceries`):

```
=== VALIDACIÓN BIGQUERY DE LAS 5 QUERYS MAESTRAS ===

[OK 1/5] 01_geometria_y_shapes_warehouse.sql    -> VALIDADA OK (4.3 GB)
[OK 2/5] 02_analisis_anillos_concentricos.sql   -> VALIDADA OK (7.7 GB)
[OK 3/5] 03_censo_cuadrantes_manzanas.sql       -> VALIDADA OK (2.9 GB)
[OK 4/5] 04_rendimiento_360_darkstore.sql       -> VALIDADA OK (129.7 GB)
[OK 5/5] 05_penetracion_macro_ciudad.sql        -> VALIDADA OK (7.6 GB)

RESULTADO: 100% de consultas compiladas con 0 errores de sintaxis y tipos de datos.
```

---

## 📚 Material de Estudio y Respaldos

* **`GUIA_ESTUDIO_SQL.md`**: Guía didáctica paso a paso que explica el concepto de negocio, las tablas involucradas y cómo interpretar cada métrica.
* **`backup_referencia/`**: Contiene las 12 consultas históricas y desgloses previos guardados intactos como referencia.
