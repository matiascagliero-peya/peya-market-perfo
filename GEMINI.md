# Directivas de Proyecto — PeYa Market

Este proyecto concentra los datamarts de BigQuery, automatizaciones de Google Apps Script y dashboards operativos de PedidosYa Market.

## 1. Métricas Operativas y Reglas de Alertas
* **Evaluación en Puntos Porcentuales (`pp`):** Todas las métricas de porcentaje operacional evalúan variaciones y desvíos estrictamente en puntos porcentuales para evitar distorsiones con denominadores bajos.
* **Baselines (L3W):** Las alertas de volumen y tiempos comparan contra el promedio del mismo día de la semana de las últimas 3 semanas (L3W).

## 2. Desarrollo en Google Apps Script
* **Límites de Ejecución:** Respetar el límite de 6 minutos por ejecución de Apps Script. Para tareas masivas o de sincronización, particionar las ejecuciones o procesar por lotes.
* **Modularidad:** Separar lógica de servidor (`Code.gs`, `EmailSender.gs`, `RankingUso.gs`) de las vistas (`Index.html`, partials `_nav.html`, etc.) usando `HtmlService`.
* **Seguridad de Datos:** No hardcodear credenciales ni tokens sensibles en el código fuente.

## 3. Consultas SQL y Datamarts (BigQuery)
* **Particionado y Costos:** Siempre filtrar por fecha o partición correspondiente para evitar escaneos completos de tablas.
* **Consistencia de Nomenclatura:** Mantener uniformidad en los identificadores de almacén (`whs_id`, `warehouse_name`) y campos estándar entre datamarts.

## 4. Control de Versiones y Sincronización (Git)
* **Sincronización Previa Obligatoria:** Antes de realizar cualquier modificación, creación o edición de archivos en este proyecto, es MANDATORIO descargar y sincronizar la última versión del repositorio remoto (`git pull origin main` o verificar el estado frente al remoto) para garantizar que todo cambio se construya sobre la versión más reciente del código.

