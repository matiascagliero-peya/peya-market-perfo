# Glosario Oficial de Criterios y Reglas de Alertas - WHS Performance Alerts

Este documento establece las reglas, fórmulas y criterios de disparo de anomalías para las 16 métricas monitoreadas en la plataforma **WHS Performance Alerts (PeYa Markets)**.

---

## 1. Métricas de Volumen y Negocio

| Métrica | Key Interna | Baseline | Unidad | Criterio de Disparo | Explicación Operativa |
| :--- | :--- | :---: | :---: | :--- | :--- |
| **Confirmed Orders** | `orders` | L3W | Entero | Caída > 20.0% vs L3W | Se compara contra el promedio del mismo día de la semana de las últimas 3 semanas. Dispara si `((val - l3w) / l3w) * 100 < -20.0`. Si `val == 0` con `l3w > 0`, se clasifica como `[CERRADA]`. |
| **GMV (EUR)** | `gmv` | L3W | Moneda (€) | Caída > 20.0% vs L3W | Dispara si la facturación bruta cae más de 20.0% respecto al promedio de las últimas 3 semanas para ese día. |
| **New Users** | `new_users` | L3W | Entero | Caída > 25.0% vs L3W | Dispara si la adquisición de nuevos clientes cae más de 25.0% respecto a su histórico L3W. |

---

## 2. Disponibilidad de Catálogo (Stock)

| Métrica | Key Interna | Baseline | Unidad | Criterio de Disparo | Explicación Operativa |
| :--- | :--- | :---: | :---: | :--- | :--- |
| **WIS %** | `wis` | L3W | Puntos Porcentuales (pp) | Absoluto < 75.0% o Caída > 5.0 pp vs L3W | Evalúa la disponibilidad global del catálogo. Dispara si el valor absoluto cae por debajo de 75.0% o si la diferencia `(val - l3w) * 100 < -5.0 pp`. |
| **WIS UF %** | `wis_uf` | L3W | Puntos Porcentuales (pp) | Absoluto < 75.0% o Caída > 5.0 pp vs L3W | Evalúa la disponibilidad de Ultra Fresh. Dispara si `val < 75.0%` o si cae más de 5.0 pp respecto a su L3W. |

---

## 3. Tiempos de Servicio (Logística y Picking)

| Métrica | Key Interna | Baseline | Unidad | Criterio de Disparo | Explicación Operativa |
| :--- | :--- | :---: | :---: | :--- | :--- |
| **Avg. Delivery Time** | `delivery_time` | L3W | Minutos | Absoluto > 40.0 min o Aumento > 5.0 min vs L3W | Tiempo total de entrega al cliente. Dispara si supera 40 minutos o si aumenta más de 5 minutos respecto a su L3W. |
| **Assignment Time** | `assignment_time` | L3W | Minutos | Absoluto > 7.0 min o Aumento > 5.0 min vs L3W | Tiempo de asignación de repartidor. Dispara si supera 7 minutos o si sube más de 5 minutos respecto a L3W. |

---

## 4. Calidad Operacional e Incidentes de Órdenes

Todas las métricas de porcentaje operativo evalúan variaciones y desvíos estrictamente en **puntos porcentuales (`pp`)** para evitar distorsiones con denominadores bajos.

| Métrica | Key Interna | Baseline | Unidad | Criterio de Disparo | Explicación Operativa |
| :--- | :--- | :---: | :---: | :--- | :--- |
| **Seamless Delivery %** | `seamless` | 7D | Puntos Porcentuales (pp) | Absoluto < 75.0% o Caída > 5.0 pp vs 7D | Dispara si la entrega sin fricción cae por debajo del 75.0% o disminuye más de 5.0 pp frente a los 7 días anteriores (`(val - r7d) * 100 < -5.0`). |
| **Assignment Time > 6 min %** | `assignment_time_over_6m` | 7D | Puntos Porcentuales (pp) | Absoluto > 30.0% | Dispara si más del 30.0% de los pedidos demoran más de 6 min en asignarse. El desvío registrado refleja la diferencia en pp frente al 7D. |
| **Weighted Open time %** | `open_time` | 7D | Porcentaje / pp | Absoluto < 90.0% | Nivel de disponibilidad y apertura de la sucursal ponderado por tráfico (columna J de WHS all Data). Dispara si el valor del día cae por debajo del 90.0% (`val < 0.90`). |
| **Assignment Time** | `assignment_time` | L3W | Minutos | Absoluto > 7.0 min o Aumento > 5.0 min vs L3W | Tiempo de asignación de repartidor. Dispara si supera 7 minutos o si sube más de 5 minutos respecto a L3W. |
| **Rejected Orders %** | `rejected_orders` | 7D | Puntos Porcentuales (pp) | Absoluto > 3.0% | Dispara si los pedidos rechazados superan el 3.0% del total. El desvío registrado refleja la diferencia en pp frente al 7D. |
| **Forced Preorders %** | `forced_preorders` | 7D | Puntos Porcentuales (pp) | Absoluto > 2.5% | Dispara si las preórdenes forzadas superan el 2.5% del total. El desvío registrado refleja la diferencia en pp frente al 7D. |
| **Late Orders %** | `late_orders` | 7D | Puntos Porcentuales (pp) | Aumento > 5.0 pp vs 7D | Pedidos entregados fuera de tiempo. Dispara si el ratio aumenta más de 5.0 puntos porcentuales vs su promedio de 7 días: `(val - r7d) * 100 > 5.0`. |
| **Slow Orders %** | `slow_orders` | 7D | Puntos Porcentuales (pp) | Aumento > 5.0 pp vs 7D | Pedidos con preparación demorada. Dispara si el ratio aumenta más de 5.0 puntos porcentuales vs su promedio de 7 días: `(val - r7d) * 100 > 5.0`. |
| **HC Sessions orders %** | `session_orders` | 7D | Puntos Porcentuales (pp) | Aumento > 3.0 pp vs 7D | Pedidos con sesiones de ayuda/contacto abierto. Dispara si aumenta más de 3.0 puntos porcentuales vs su promedio de 7 días: `(val - r7d) * 100 > 3.0`. |
| **Modified Orders %** | `modified_orders` | 7D | Puntos Porcentuales (pp) | Aumento > 3.0 pp vs 7D | Pedidos modificados por reemplazo/falta de stock en tienda. Dispara si aumenta más de 3.0 puntos porcentuales vs su promedio de 7 días: `(val - r7d) * 100 > 3.0`. |

---

## 5. Tratamiento de Falta de Datos (`NO_DATA`)
* Si una sucursal no reporta componentes para una métrica o las celdas de origen vienen vacías, el sistema no calcula desvío ni asume operación normal.
* En la Tabla Resumen (Dashboard), la fila completa se cubre con una capa oscura indicando `[INFO] Métrica no disponible`.
* En la Vista por País (`1_ByCountry`), toda la columna correspondiente se oscurece y muestra guiones (`—`) impidiendo falsos tildes verdes (`✓`).
* En los correos electrónicos (`EmailSender`), las métricas sin datos se tipifican como `MÉTRICA NO DISPONIBLE` o con guion `—`.

---

## 6. Integración de Precipitaciones (Clima en mm) y Persistencia en Google Sheets
* **Coordenadas de Almacenes:** Base incorporada de 128 tiendas y fallback dinámico desde `1. WHS data` del archivo maestro de Mapster (`1DXcZswpGQsbXcj5RXBALAogLrs32d_rtcxpRb17nROk`).
* **Fuente Meteorológica:** Consulta a la API histórica de **Open-Meteo** para la fecha evaluada (`daily=precipitation_sum&timezone=auto`), agrupada en lotes (batch) y cacheada en `CacheService` por 6 horas.
* **Persistencia Física en Google Sheets:** 
  * Se almacena en la **Columna 8 (`Precipitacion_mm`)** de la hoja `Alertas_Historial` en la base de datos de alertas (`DATABASE_SS_ID`).
  * Al hacer clic en **"Actualizar"** (o en la recarga on-demand), el sistema ejecuta `completarPrecipitacionesFaltantesEnSheet()`, rellenando físicamente en Google Sheets cualquier registro histórico que carezca de dato de lluvia.
  * Todas las lecturas subsiguientes del Dashboard y de la matriz por país leen directamente la columna 8 de Google Sheets en 0 ms sin depender de llamadas asíncronas externas.
  * También se incluye la función `llenarLluviasEnSheets()` para ejecutar la carga en Sheets con un solo clic desde el editor de Google Apps Script.
* **Visualización en Interfaz y Correo:**
  * Si llovió ($\ge 0.1\text{ mm}$): texto azul directo `🌧️ Lluvias: 0.6mm` o `🌧️ Lluvias: 15mm` (con formato decimal para lloviznas leves $< 1.0\text{ mm}$).
  * Si no llovió ($< 0.1\text{ mm}$ o $0.0\text{ mm}$): texto directo `Lluvias: No`.
  * Sin recuadros, fondos grises ni bordes, manteniendo la estética limpia y el alto estándar visual.

