# Estructura Oficial de Consultas SQL — PeYa Market

Esta estructura divide el repositorio de queries en 4 grandes bloques dentro de `PeYa Market/3. Querys SQL/`:

---

## 📂 1. Tablas en Sheets
> **Propósito:** Queries estructuradas que alimentan todas las bases maestras y planillas de Google Sheets (áreas de mayor a menor volumen, con Frankenstein y Descartados al final).
- **`1. Performance/`**: 12 queries transversales (0. Monitor de actualizaciones, 0. Actualización General, 1. OKRs, 2. Double Ya, 3. Ultra Fresh, 4. Sessions & CVR, 5. Small Order Fee, 6. Fill In, 7. Store Penetration).
- **`2. Operacional/`**: 8 queries (OPS Data diario/mensual/by WHS, Open Time diario/semanal/mensual, Stacked deliveries).
- **`3. Comercial/`**: 6 queries (AQS, PQS, Price index, Promo Contribution, Nielsen).
- **`4. Supply/`**: 4 queries (Supply Chain diario/mensual/by WHS, Planning).
- **`5. Otros/`**: 3 queries (Targets 2026 diario/by WHS, Basket Size).
- **`6. Customer Insights/`**: 2 queries (NPS, Rating).
- **`7. Finance/`**: 1 query (Forecast America).
- **`8. Tablas Frankenstein - MCagliero version/`**: 9 queries de usuarios, cohortes y MAUs coverage.
- **`9. Tablas Frankenstein - Euge version/`**: 4 queries de sesiones y retención de usuarios.
- **`10. Z - Descartados/`**: Consultas obsoletas o en desuso.

---

## ⚙️ 2. BigQuery Directo
> **Propósito:** Rutinas periódicas de cálculo y consultas de soporte ejecutadas en BigQuery.
- **`1. Recurrentes/`**:
  - **`Diario General/`**: `1. OKRs_daily_data.sql`, `2. Ops_daily_data.sql`, `2. Absolute Supply OKRs.sql` (nivel país / región).
  - **`Diario by WHS/`**: `3. Data diaria por Warehouse.sql`, `3. Absolute Ops OKRs.sql`, `4. WOT Hour by WHS.sql` (nivel darkstore / tienda).
  - **`Mensual/`**: `1. QueryDS.sql`, `2. OKRs mensual.sql`.
- **`2. Otros/`**:
  - `Recargas/`: Recargas históricas (`Recarga 2025 a 2026-09-12`, `Recarga_Sessions_2026`, etc.).
  - `Verificaciones/`: Chequeos puntuales (`verificacion_sesiones_*`, `carrefour_check`, etc.).

---

## 🗺️ 3. Reportes
> **Propósito:** Consultas, modelos y datamarts asociados a reportes, herramientas y dashboards específicos.
- **`Daily & WHS Alerts/`**:
  - `11. Daily Alerts - Peya Market (Daily Data).sql` (Alimenta Daily Report y WHS Alerts)
  - `11. Daily Alerts - Peya Market (WHS all Data).sql` (Check de seamless y fallback por WHS)
- **`Daily Monitor/`**:
  - `1. Data GMV - Base - Performance.sql` (GMV y Active Stores)
  - `2. QueryDS - Base - Performance.sql` (QueryDS para el Daily Monitor)
  - `3. Total Orders - Base - Performance.sql` (Órdenes totales de plataforma vs darkstores)
  - `4. Fees - Base - Performance.sql` (Fees, MOV, SOF y valor de ticket)
  - `11. Daily Alerts - Peya Market (Daily Data).sql` (Alimenta Daily Report y WHS Alerts)
  - `11. Daily Alerts - Peya Market (WHS all Data).sql` (Check de seamless y fallback por WHS)
- **`Mapster/`**:
  - **`Conexiones Sheets/`**:
    - `1. Mapster - Base - Performance (WHS data).sql` (Catálogo de locales, partners y shapes Hurrier para pestaña 1)
    - `1. Mapster - Base - Performance (WHS orders).sql` (Órdenes, fallas y tiempos por darkstore para pestaña 2)
  - **`Core & API/`**: Queries espaciales de la aplicación All-Map (`01_geometria_y_shapes_warehouse.sql`, `02_analisis_anillos_concentricos.sql`, etc.).
  - **`Modelos & Datamarts/`**: Modelos maestros espaciales y de tiendas (`dim_warehouse_footprint_master.sql`, `dim_warehouse_all_partners_master.sql`, `datamart_warehouse_shape_analytics.sql`, `crear_tabla_externa_whs_master.sql`, etc.).
- **`Sales Monitor/`**:
  - `1. Sales M Data - Base - Performance (Sales).sql`
  - `1. Sales M Data - Base - Performance (Vertical).sql`
- **`Unprofitable Dashboard/`**:
  - `1. Unprofitable orders.sql`, `2. Dmarts Unprofitable Promotions.sql`, `3. Dmarts Unprofitable Margin.sql`.
- **`User Types (Frank)/`:
  - Taxonomía de usuarios, L1/L2, tenure, glosario HTML, resumen del proyecto y carpetas Matias/Euge.

---

## 📖 4. Glosario
> **Propósito:** Catálogo canónico de métricas por Chapter, sincronizado con la Unidad Compartida de Google Drive.
