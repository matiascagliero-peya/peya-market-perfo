# Resumen Ejecutivo y Arquitectura: Proyecto "Frank User Type (Usuarios)"

**Fecha de consolidación:** Octubre 2026  
**Autor:** Matias Cagliero  
**Ubicación oficial:** `PeYa Market / 3. Querys SQL / 2. Querys / 4. Bases Frank - Matias / Frank Matias/`

---

## 1. Objetivo del Ecosistema
Construir y mantener un pipeline analítico modular y de alto rendimiento en Google BigQuery para clasificar el ciclo de vida y medir la retención, reactivación, hábito y unit economics de los clientes de **PeYa Market (Darkstores)**, **Supermercados Terceros (AAA)** y **Plataforma (Food / toda la app)**, alimentando directamente dashboards ejecutivos y **Connected Sheets** sin lag de procesamiento.

---

## 2. Arquitectura Modular en 3 Niveles (BigQuery)

```
                       FUENTES TRANSACCIONALES CRUDAS
      • fact_orders (Core PeYa)        • customer_orders_sku_level (UF y ventas)
      • dim_partner (is_darkstore)     • fact_orders_double_ya (Double Ya)
                                     │
                                     ▼
 ┌─────────────────────────────────────────────────────────────────────────────┐
 │ NIVEL 1: frank_user_monthly_activity  (Staging de Compras Reales)           │
 ├─────────────────────────────────────────────────────────────────────────────┤
 │ • 15 columnas oficiales (sin dim_user y sin DENSE_RANK histórico).          │
 │ • Grano: 1 fila por (month, customer_id, country) con compra real.          │
 │ • Lógica auto-incremental: recarga últimos 2 meses en ~5 segundos.         │
 └─────────────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼ (Lee 100% de la Tabla 1)
 ┌─────────────────────────────────────────────────────────────────────────────┐
 │ NIVEL 2: frank_user_type_monthly  (Motor de Ciclo de Vida L1 y L2)          │
 ├─────────────────────────────────────────────────────────────────────────────┤
 │ • 26 columnas oficiales (Platform, AAA, Market y Tenures).                  │
 │ • Grano: 1 fila por (Mes, customer_id, country) CONTINUA (con Fantasmas).   │
 │ • Algoritmo: Generador de Fantasmas (UNNEST 60m) + Islands & Gaps (Rachas). │
 │ • Tiempo de corrida: ~15 segundos en BigQuery.                              │
 └─────────────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼ (Cruza Tabla 2 + Tabla 1)
 ┌─────────────────────────────────────────────────────────────────────────────┐
 │ NIVEL 3: frank_user_metrics_summary  (Datamart Multi-Negocio Agregado)      │
 ├─────────────────────────────────────────────────────────────────────────────┤
 │ • Grano: 1 fila por (Mes, country, business, level_1, level_2).             │
 │ • Jerarquía: business (Market, AAA, Platform) ➔ level_1 ➔ level_2.          │
 │ • 18 columnas de métricas, unit economics y tenures ponderados.             │
 │ • Peso: Menos de 1 MB (instantáneo en Connected Sheets y Looker).           │
 └─────────────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
 ┌─────────────────────────────────────────────────────────────────────────────┐
 │ CAPA DE CONSUMO: Connected Sheets / Google Sheets                           │
 ├─────────────────────────────────────────────────────────────────────────────┤
 │ • Archivo: 4. Connected Sheets (Ultimos 3 Meses).sql                        │
 │ • Árbol desplegable en Tabla Dinámica: business ➔ level_1 ➔ level_2.        │
 └─────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Matriz Oficial de Taxonomía Level 2 (Market vs AAA)

| L1 Macro | Subtipo `L2_Market_Actual_Type` | Subtipo `L2_AAA_Actual_Type` | Regla Oficial de Clasificación |
| :--- | :--- | :--- | :--- |
| **Never Active** | `-` | `-` | Usuario en la app que jamás realizó una compra en el negocio. |
| **New User** | `App Adoption` | `App Adoption` | Primera orden en el negocio y en la aplicación (adopción pura). |
| | `DY Adoption` | `DY Adoption` | Primera orden en el negocio realizada mediante Double Ya. |
| | `Dmart Adoption` | `AAA Adoption` | Primera orden en la vertical (sin compras en la otra). |
| | `AAA Adoption` | `Dmart Adoption` | Primera orden en la vertical habiendo comprado previamente en la otra. |
| **M1 Return** | `M1 Return Users - Dmart` | `M1 Return Users - AAA` | En M0 compró en la vertical y en M1 vuelve a comprar (retención orgánica). |
| | `M1 Dmart DY` | `M1 AAA DY` | En M0 compró con DY y en M1 repite con DY. |
| | `M1 Dmart DY Converted` | `M1 AAA DY Converted` | En M0 compró con DY y en M1 convierte a canasta sin DY. |
| **Reactivation** | `Occasional Reactivation` | `Occasional Reactivation` | Inactivo solo el mes anterior (última compra hace 2 meses). |
| | `Warm Reactivation` | `Warm Reactivation` | Inactivo de 2 a 4 meses (última compra hace 3 a 5 meses). |
| | `True Reactivation` | `True Reactivation` | Inactivo 5 meses o más (última compra hace 6 meses o más). |
| | `DY Reactivation` | `DY Reactivation` | Reactivado en el negocio exclusivamente vía Double Ya. |
| **Re-Order** | `Re-Order Occasional` | `Re-Order Occasional` | Segundo mes de compra tras reactivación ocasional. |
| | `Re-Order Warm` | `Re-Order Warm` | Segundo mes de compra tras reactivación tibia. |
| | `Re-Order True` | `Re-Order True` | Segundo mes de compra tras reactivación profunda. |
| | `Re-Order DY` | `Re-Order DY` | Reactivado por DY que repite con DY en su segundo mes. |
| | `Re-Order DY Converted` | `Re-Order DY Converted` | Reactivado por DY que convierte a canasta completa en su segundo mes. |
| **Recurring Return** | `Recent Recurring Return` | `Recent Recurring Return` | Racha ininterrumpida de **3 meses seguidos**. |
| | `Old Recurring Return` | `Old Recurring Return` | Racha ininterrumpida de **4 a 12 meses seguidos**. |
| | `Royal Recurring Return` | `Royal Recurring Return` | Racha ininterrumpida de **13 meses o más** (Heavy User / VIP). |
| **Churned** | `Recently Churn` | `Recently Churn` | Inactivo hace **1 o 2 meses**. |
| | `Churn > 3 Months` | `Churn > 3 Months` | Inactivo hace **3 a 5 meses**. |
| | `Churn > 6 Months` | `Churn > 6 Months` | Inactivo hace **6 meses o más** (usuario dormido). |

---

## 4. Estructura de Columnas por Tabla

### Tabla 1: `frank_user_monthly_activity` (15 columnas)
1. `month` (DATE)
2. `customer_id` (STRING)
3. `country` (STRING)
4. `is_active_platform` (BOOLEAN)
5. `is_active_food` (BOOLEAN)
6. `is_active_aaa` (BOOLEAN)
7. `is_active_dmart` (BOOLEAN)
8. `orders_platform` (INTEGER)
9. `orders_dmart` (INTEGER)
10. `orders_uf_dmart` (INTEGER)
11. `orders_dy_dmart` (INTEGER)
12. `units_sold_dmart` (INTEGER)
13. `net_sales_dmart_eur` (FLOAT)
14. `DY_order` (STRING)
15. `UF_order` (STRING)

### Tabla 2: `frank_user_type_monthly` (26 columnas)
* **Identidad:** `Fecha`, `Mes`, `customer_id`, `country`.
* **Platform:** `Platform_adoption_date`, `Platform_user_adoption_tenure`, `Platform_previous_type`, `Platform_previous_type_ternure`, `Platform_Actual_Type` (L1), `Platform_Actual_type_ternure`.
* **AAA:** `AAA_adoption_date`, `AAA_user_adoption_tenure`, `AAA_previous_type`, `AAA_previous_type_ternure`, `AAA_Actual_Type` (L1), `AAA_Actual_type_ternure`, `L2_AAA_Actual_Type`.
* **Market:** `Market_adoption_date`, `Market_user_adoption_tenure`, `Market_previous_type`, `Market_previous_type_ternure`, `Market_Actual_Type` (L1), `Market_Actual_type_ternure`, `L2_Market_Actual_Type`, `DY_order`, `UF_order`.

### Tabla 3: `frank_user_metrics_summary` (18 columnas)
1. `Mes` (DATE)
2. `country` (STRING)
3. `business` (STRING: `'Market'`, `'AAA'`, `'Platform'`)
4. `level_1` (STRING)
5. `level_2` (STRING)
6. `Market_Actual_Type` (alias de `level_1`)
7. `L2_Market_Actual_Type` (alias de `level_2`)
8. `users_count` (INTEGER)
9. `users_share_pct` (FLOAT, relativo a activos de ese negocio)
10. `confirmed_orders` (INTEGER)
11. `confirmed_orders_uf` (INTEGER, solo Market)
12. `confirmed_orders_dy` (INTEGER, solo Market)
13. `net_sales_eur` (FLOAT, solo Market)
14. `units_sold` (INTEGER, solo Market)
15. `basket_size` (FLOAT)
16. `afv` (FLOAT)
17. `frequency` (FLOAT)
18. `monthly_customer_units` (FLOAT)
19. `uf_user_penetration_pct` (FLOAT)
20. `avg_actual_tenure` (FLOAT, racha compras)
21. `avg_adoption_tenure` (FLOAT, antigüedad adopción)

---

## 5. Inventario de Archivos en `Frank Matias/`

1. **`1. Frank - User Monthly Activity.sql`**: Pipeline auto-incremental de compras reales.
2. **`2. Frank - User Type (Level 1 & 2 + Tenure).sql`**: Motor de ciclo de vida con L2 para Market y AAA.
3. **`2.1 Borrar Columna Duplicada Tabla 2.sql`**: `ALTER TABLE` instantáneo a costo 0 bytes.
4. **`3. Frank - User Metrics Summary.sql`**: Datamart multi-negocio agrupado por jerarquía.
5. **`4. Connected Sheets (Ultimos 3 Meses).sql`**: Extracción filtrada de los últimos 3 meses cerrados.
6. **`GLOSARIO_TAXONOMIA_USER_TYPE.html`**: Visualizador v3.1 interactivo con simulador y matriz completa.
7. **`Auditorias y Benchmarks/`**: Scripts de control de calidad, comparativa con la SKU table y sanity checks.
