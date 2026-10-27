# Project Tracker & Report Hub — PeYa Market

Sistema integral de gestion de scope, tareas recurrentes, prioridades semanales y directorio de reportes por usuario, desarrollado con Google Sheets como base de datos en tiempo real y una Web App en Google Apps Script.

---

## Estructura de las 2 Paginas Principales

### 1. Pagina 1: Tareas y Scope por Responsable (Semana a Semana)
Muestra a todos los miembros del equipo en la misma fila horizontal (con selector de vista en Columnas o Filas). En la columna de cada persona se organizan tres areas bien definidas:

#### A. Scope & Tareas Recurrentes
- Responsabilidades fijas y entregables habituales de cada miembro.
- Frecuencia de actualizacion claramente visible: `Diario`, `Semanal`, `Quincenal`, `Mensual / Cierre`.
- Links directos y clicables a las herramientas asociadas (Google Sheets, Looker Studio, Google Slides, Datamarts).
- Boton `+ Agregar` para incorporar nuevas tareas recurrentes con su frecuencia y enlace.

#### B. Prioridades de la Semana (Semana en Curso)
- Iniciativa o proyecto principal de la semana.
- Lista de prioridades y to-dos de la semana con autoguardado en tiempo real en Google Sheets.
- Boton `+ Cargar Mi Semana` para registrar los entregables del periodo.
- Cajas destacadas de novedades (verde esmeralda) y bloqueos/riesgos (rojo coral).
- **Rollover automatico:** Las tareas no completadas de la semana previa se traspasan automaticamente a la nueva semana.

#### C. Temas a Cubrir Mas Adelante (Backlog / Parking Lot)
- Registro de iniciativas futuras, propuestas o pendientes que se abordaran en periodos posteriores.
- Incluye periodo target estimado (ej: `Noviembre 2026`, `Q1 2027`) y pilar.
- **Boton `Promover a semana ->`:** Con un solo clic, cualquier tema del backlog se convierte en una prioridad activa de la semana actual.
- Boton `+ Agregar` para sumar nuevos temas futuros.

---

### 2. Pagina 2: Hub de Reportes
- Repositorio centralizado de reportes, dashboards de Looker Studio, Google Sheets y presentaciones por usuario.
- Buscador en tiempo real por nombre, responsable o tag.
- Edicion directa in-line del nombre, URL y descripcion del reporte en la tarjeta.
- Boton destacado "Abrir Reporte" con registro de telemetria de clics.
- Boton "+ Cargar Reporte" con ventana modal de creacion propia.

---

### Modulo Adicional: Auditoria & Telemetria (Exclusivo matias.cagliero@pedidosya.com)
- Solo visible e invocable por el correo administrador.
- Monitoreo de ingresos a la app, changelog de modificaciones por usuario y conteo de clics en reportes.

---

## Pestanas en Google Sheets

1. `Seguimiento Semanal`: Prioridades, to-dos, novedades y bloqueos semana a semana.
2. `Tareas Recurrentes`: Scope estructural de cada persona, frecuencia de actualizacion y enlaces directos.
3. `Temas Futuros`: Backlog de iniciativas futuras con target estimado y opcion de promocion a semanal.
4. `Hub de Reportes`: Directorio de reportes y URLs directas.
5. `Equipo`: Miembros del equipo de trabajo.
6. `Log_Sesiones`: Registro cronologico de ingresos a la aplicacion.
7. `Log_Auditoria`: Registro cronologico de trazabilidad de cambios.
