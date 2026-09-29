# Glosario y Taxonomía de Usuarios (Level 1, Level 2 y Tenure)

Ubicación: `3. Querys SQL / 2. Querys / 4. Bases Frank - Matias`

---

## 1. Tabla de Taxonomía Completa (Level 1 y Level 2)

| Level 1 | Descripción Level 1 | Level 2 | Regla de Clasificación (M0 = Mes Actual) |
| :--- | :--- | :--- | :--- |
| **Adoption** | Nuevos usuarios que realizan su primera compra histórica en Dmarts en M0. | **App Adoption** | Su compra en Dmarts en M0 es la primera orden de toda su historia en la app completa (adquisición pura). |
| | | **Double Ya Adoption** | Su primera orden en Dmarts ocurre en M0 a través de la funcionalidad Double Ya (flag en orden). |
| | | **AAA Adoption** | Su primera orden en Dmarts es en M0, pero SÍ tenía órdenes previas en supermercados de terceros (AAA). |
| | | **Dmart Adoption** | Su primera orden en Dmarts es en M0, pero SÍ tenía órdenes previas en la app no AAA (Restaurantes, etc.). |
| **M1 Return** | Mide principalmente la retención en el segundo mes de vida. | **M1 App Adoption** | Adquirido como *App Adoption* en M-1 y volvió a comprar en M0. |
| | | **M1 Double Ya Adoption** | Volvió en M0 comprando exclusivamente con Double Ya. |
| | | **M1 Double Ya Converted** | Adquirido por DY en M-1 que en M0 volvió con una compra de Peya Markets Full (regular). |
| | | **M1 AAA Adoption** | Adquirido como *AAA Adoption* en M-1 y volvió a comprar en M0. |
| | | **M1 Dmart Adoption** | Adquirido como *Dmart Adoption* en M-1 y volvió a comprar en M0. |
| **Reactivation** | Usuarios rescatados de la inactividad ($\ge 1$ mes sin comprar en Dmarts). | **Occasional Reactivation** | Compró en M0. No compró en M-1. SÍ compró en M-2 (compró en 2 de los últimos 3 meses). |
| | | **Warm Reactivation** | Compró en M0. Su última compra previa fue hace 3 a 5 meses (M-3 a M-5). |
| | | **True Reactivation** | Compró en M0. Su última compra previa fue hace 6 meses o más ($\ge$ M-6). |
| | | **DY Reactivation** | Usuarios reactivados en M0 exclusivamente a través de Double Ya. |
| **Re-Order** | Retención post-rescate. Valida si el win-back genera retorno genuino. | **Re-Order Occasional Reactivation** | Compró en M0 y en M-1, pero venía inactivo en M-2 (retención de reactivado ocasional). |
| | | **Re-Order Warm Reactivation** | Compró en M0 y en M-1, pero venía inactivo hace 3 a 5 meses (retención de reactivado cálido). |
| | | **Re-Order True Reactivation** | Compró en M0 y en M-1, pero venía inactivo hace 6+ meses (retención de reactivado puro). |
| | | **Re-Order DY Reactivation** | Reactivado por DY en M-1 que en M0 volvió a comprar únicamente con Double Ya. |
| | | **Re-Order DY Full Dmarts** | Reactivado por DY en M-1 que en M0 compró canasta completa de Full Dmarts. |
| **Recurring Return** | Usuarios leales con hábito sólido ($\ge 3$ meses seguidos comprando). | **Recent Recurring Return** | Compró en Dmarts de forma ininterrumpida durante los últimos 3 meses (M0, M-1, M-2). |
| | | **Old Recurring Return** | Compró en Dmarts de forma ininterrumpida durante 4 a 12 meses consecutivos. |
| | | **Royal Recurring Return** | Compró en Dmarts de forma ininterrumpida durante 12 meses o más ($\ge 13$ meses). |
| **Churned** | Base inactiva con historial de compras previas en el negocio. No compró en M0. | **Recently Churn** | No compró en M0. Su última compra en Dmarts fue hace 1 o 2 meses (M-1 o M-2). |
| | | **Churn > 3 Months** | No compró en M0. Su última compra en Dmarts fue hace 3 a 5 meses (M-3 a M-5). |
| | | **Churn > 6 Months** | No compró en M0. Su última compra en Dmarts fue hace 6 meses o más ($\ge$ M-6). |
| **Never Active** | Base registrada en la app que jamás ha transaccionado en el negocio. | **Never Active** | Usuario registrado / activo en PeYa que jamás ha completado una transacción en Dmarts. |

---

## 2. Definición de Métricas de Tenure y Rachas

1. **`user_tenure_months_dmart` (Tenure Histórico Dmarts):**
   * Meses de vida del cliente desde su primera compra histórica en Dmarts (`DATE_DIFF + 1`).
   * No disminuye nunca; mes a mes suma +1.

2. **`user_tenure_months_peya` (Tenure Histórico PeYa):**
   * Meses de vida del cliente desde su primer pedido en toda la plataforma PeYa.

3. **`consecutive_active_months_dmart` (Racha Activa Ininterrumpida):**
   * Cantidad de meses consecutivos comprando sin parar (1, 2, 3, 4...).
   * Si no compra en un mes, se resetea a 0.

4. **`tenure_rr_streak_months_dmart` (Tenure dentro de la Racha RR):**
   * Meses acumulados como cliente Recurring Return dentro de la racha actual (`consecutive_active_months - 2`).
   * Mes 3 de racha = Mes 1 como RR; Mes 4 = Mes 2 como RR; etc.

5. **`last_rr_month_dmart` (Último mes en que fue RR):**
   * Fecha del mes más reciente en el que el usuario cumplió la condición de Recurring Return.

6. **`months_since_last_rr_dmart` (Meses desde que fue RR por última vez):**
   * Si actualmente es RR $\rightarrow 0$.
   * Si dejó de comprar hace 3 meses habiendo sido RR $\rightarrow 3$.
   * Si nunca fue RR $\rightarrow NULL$.

---

## 3. Consultas en esta carpeta

* **`1. Frank - User Type.sql`**: Versión original histórica (respaldo).
* **`2. Frank - User Count.sql`**: Versión original agregada (respaldo).
* **`3. Frank - User Type (Level 1 & 2 + Tenure).sql`**: Nueva consulta granular usuario-mes con toda la taxonomía y métricas de tenure.
* **`4. Frank - User Count (Level 1 & 2 + Tenure).sql`**: Nueva consulta resumen mensual por país, negocio, Level 1 y Level 2 con promedios de tenure y tracking de RR.
