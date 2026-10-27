/**
 * ==============================================================================
 * PEDIDOSYA MARKET — PROJECT TRACKER & REPORT HUB
 * Sistema de Gestión de Scope, Tareas Recurrentes, Prioridades y Reportes
 * Sincronizado en tiempo real con Google Sheets
 * ==============================================================================
 */

const CONFIG = {
  SPREADSHEET_ID: "1vBq5i_IRlAuhgos6awzl68j-tlKo-7vZAKtwp4do1dA",
  SHEET_SEMANAL: "Seguimiento Semanal",
  SHEET_RECURRENTES: "Tareas Recurrentes",
  SHEET_FUTUROS: "Temas Futuros",
  SHEET_REPORTES: "Hub de Reportes",
  SHEET_EQUIPO: "Equipo",
  SHEET_BOLSA: "Bolsa de Pendientes",
  SHEET_LOG_SESIONES: "Log_Sesiones",
  SHEET_LOG_AUDITORIA: "Log_Auditoria",
  ADMIN_EMAIL: "matias.cagliero@pedidosya.com",
  TITULO_APP: "Project Tracker & Hub de Reportes | PeYa Market",
  VERSION: "2.0.0"
};

// ==============================================================================
// HELPERS DE SISTEMA Y BASE DE DATOS
// ==============================================================================

function getDB() {
  if (CONFIG.SPREADSHEET_ID && CONFIG.SPREADSHEET_ID.trim() !== "") {
    return SpreadsheetApp.openById(CONFIG.SPREADSHEET_ID.trim());
  }
  return SpreadsheetApp.getActiveSpreadsheet();
}

function _getUserEmail() {
  let email = "";
  try { email = Session.getActiveUser().getEmail() || ""; } catch (_) {}
  if (!email || email.startsWith("Error:")) {
    try { email = Session.getEffectiveUser().getEmail() || ""; } catch (_) {}
  }
  return (email && !email.startsWith("Error:")) ? email : CONFIG.ADMIN_EMAIL;
}

function _getFechaHoy() {
  return Utilities.formatDate(new Date(), "GMT-3", "yyyy-MM-dd HH:mm");
}

function verificarEsAdmin(email) {
  if (!email) return false;
  const e = email.toLowerCase().trim();
  return e === CONFIG.ADMIN_EMAIL.toLowerCase() || e.includes("cagli") || e.includes("matias");
}

function normalizarClave(str) {
  return String(str)
    .toLowerCase()
    .normalize("NFD").replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]/g, "_")
    .replace(/^_+|_+$/g, "")
    .replace(/_{2,}/g, "_");
}

function buscarFilaPorId(sheet, id) {
  if (!sheet) return -1;
  const data = sheet.getDataRange().getValues();
  const searchId = String(id).trim();
  for (let i = 1; i < data.length; i++) {
    if (String(data[i][0]).trim() === searchId) return i + 1;
  }
  return -1;
}

function leerHoja(ss, sheetName) {
  if (!ss) return [];
  const sheet = ss.getSheetByName(sheetName);
  if (!sheet) return [];
  const data = sheet.getDataRange().getValues();
  if (data.length <= 1) return [];

  const headers = data[0].map(h => normalizarClave(h));
  const items = [];

  for (let i = 1; i < data.length; i++) {
    const row = data[i];
    if (row.every(cell => cell === "" || cell === null)) continue;
    const obj = {};
    for (let j = 0; j < headers.length; j++) {
      let val = row[j];
      if (val instanceof Date) {
        val = Utilities.formatDate(val, "GMT-3", "yyyy-MM-dd HH:mm");
      }
      obj[headers[j]] = val;
    }
    // Compatibilidad uniforme de campos
    if (obj.nombre_del_reporte && !obj.nombre) obj.nombre = obj.nombre_del_reporte;
    if (obj.url_directa && !obj.url) obj.url = obj.url_directa;
    if (obj.creado_por && !obj.creadoPor) obj.creadoPor = obj.creado_por;
    if (obj.asignado_a && !obj.asignadoA) obj.asignadoA = obj.asignado_a;
    items.push(obj);
  }
  return items;
}

function _actualizarCelda(sheetName, id, mapaCols, campo, valor, entidad) {
  const ss = getDB();
  const sheet = ss.getSheetByName(sheetName);
  if (!sheet) return { success: false, error: "Hoja no encontrada" };

  const rowIndex = buscarFilaPorId(sheet, id);
  if (rowIndex <= 0) return { success: false, error: "Registro no encontrado" };

  const clave = campo.toLowerCase().replace(/[^a-z0-9]/g, "");
  const col = mapaCols[clave];
  if (!col) return { success: false, error: "Campo no reconocido" };

  sheet.getRange(rowIndex, col).setValue(valor);
  sheet.getRange(rowIndex, sheet.getLastColumn()).setValue(_getFechaHoy());

  registrarAuditoria(ss, _getUserEmail(), entidad, "EDITAR_CAMPO", `Actualizo ${campo} en ${entidad} [ID: ${id}]`);
  return { success: true };
}

function _eliminarFila(sheetName, id, colNombre, entidad) {
  const ss = getDB();
  const sheet = ss.getSheetByName(sheetName);
  if (!sheet) return { success: false, error: "Hoja no encontrada" };

  const rowIndex = buscarFilaPorId(sheet, id);
  if (rowIndex <= 0) return { success: false, error: "Registro no encontrado" };

  const nombre = colNombre ? String(sheet.getRange(rowIndex, colNombre).getValue()) : id;
  sheet.deleteRow(rowIndex);
  registrarAuditoria(ss, _getUserEmail(), entidad, "ELIMINAR", `Elimino ${entidad}: ${nombre} [ID: ${id}]`);
  return { success: true };
}

// ==============================================================================
// CICLO DE VIDA WEB APP (DOGET)
// ==============================================================================

function doGet(e) {
  if (e && e.parameter && (e.parameter.debug === "1" || e.parameter.debug === "true")) {
    return ContentService.createTextOutput(ejecutarDiagnosticoBackend()).setMimeType(ContentService.MimeType.TEXT);
  }

  const template = HtmlService.createTemplateFromFile("Index");
  return template.evaluate()
    .setTitle(CONFIG.TITULO_APP)
    .addMetaTag("viewport", "width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no")
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL)
    .setFaviconUrl("https://live.pystatic.com/webassets/favicon-8f0ea2519d2575076b739999329af939.ico");
}

function include(filename) {
  return HtmlService.createHtmlOutputFromFile(filename).getContent();
}

function _cargarPaqueteDatos(ss, semanaFiltro) {
  let semanal = [], recurrentes = [], futuros = [], reportes = [], bolsa = [], equipo = [];

  if (ss) {
    try { semanal = leerHoja(ss, CONFIG.SHEET_SEMANAL); } catch (_) {}
    try { recurrentes = leerHoja(ss, CONFIG.SHEET_RECURRENTES); } catch (_) {}
    try { futuros = leerHoja(ss, CONFIG.SHEET_FUTUROS); } catch (_) {}
    try { reportes = leerHoja(ss, CONFIG.SHEET_REPORTES); } catch (_) {}
    try { bolsa = leerHoja(ss, CONFIG.SHEET_BOLSA); } catch (_) {}
    try { equipo = leerHoja(ss, CONFIG.SHEET_EQUIPO); } catch (_) {}
  }

  if (!equipo || equipo.length === 0) {
    equipo = [
      { nombre: "Matías Cagliero", email: "matias.cagliero@pedidosya.com", rol: "Lead Analyst" },
      { nombre: "Nicki Krawiecki", email: "nicole.krawiecki@pedidosya.com", rol: "Head of Performance" },
      { nombre: "Juan Pablo Pinori Diaz", email: "juan.pinori@pedidosya.com", rol: "Specialist Data" }
    ];
  }

  const semanaActual = calcularSemanaActualISO();
  const semanaSel = semanaFiltro || semanaActual;

  return {
    seguimientoSemanal: semanal,
    recurrentes: recurrentes,
    futuros: futuros,
    reportes: reportes,
    bolsa: bolsa,
    equipo: equipo,
    semanaSeleccionada: semanaSel,
    semanaActual: semanaActual
  };
}

function obtenerBootstrapServidor() {
  let ss = null;
  try {
    ss = getDB();
    asegurarEstructuraPlanilla(ss);
  } catch (e) {
    Logger.log("Aviso conexion DB: " + e.message);
  }

  const email = _getUserEmail();
  const semanaActual = calcularSemanaActualISO();
  if (ss) {
    try { ejecutarRolloverTareasIncompletas(ss, semanaActual); } catch (_) {}
    try { registrarSesion(ss, email, "APERTURA_APP", "Inicio de sesion en Web App"); } catch (_) {}
  }

  const datos = _cargarPaqueteDatos(ss, semanaActual);

  return {
    config: {
      usuarioActual: {
        email: email,
        nombre: deducirNombreDeEmail(email, datos.equipo),
        esAdmin: verificarEsAdmin(email)
      },
      spreadsheetUrl: ss ? ss.getUrl() : "",
      semanaActual: semanaActual,
      semanasDisponibles: generarSemanasDisponibles(semanaActual),
      equipo: datos.equipo
    },
    datos: datos
  };
}

function obtenerConfiguracionInicial() {
  const boot = obtenerBootstrapServidor();
  return boot.config;
}

function obtenerDatosCompletos(semanaFiltro) {
  const ss = getDB();
  return _cargarPaqueteDatos(ss, semanaFiltro);
}

// ==============================================================================
// ROLLOVER DE TAREAS SEMANALES INCOMPLETAS
// ==============================================================================

function coincidenSemanas(sem1, sem2) {
  if (!sem1 || !sem2) return false;
  const s1 = String(sem1).trim().toLowerCase();
  const s2 = String(sem2).trim().toLowerCase();
  if (s1 === s2) return true;
  const m1 = s1.match(/(?:w|semana\s*)(\d{1,2})/i);
  const m2 = s2.match(/(?:w|semana\s*)(\d{1,2})/i);
  return !!(m1 && m2 && m1[1] === m2[1]);
}

function ejecutarRolloverTareasIncompletas(ss, semanaActual) {
  try {
    const sheet = ss.getSheetByName(CONFIG.SHEET_SEMANAL);
    if (!sheet) return;
    const data = sheet.getDataRange().getValues();
    if (data.length <= 1) return;

    const headers = data[0].map(h => normalizarClave(h));
    const idxSem = headers.indexOf("semana");
    const idxOwn = headers.indexOf("owner");
    const idxProy = headers.indexOf("proyecto");
    const idxTodos = headers.indexOf("todos");
    const idxBloq = headers.indexOf("bloqueos");
    const idxEst = headers.indexOf("estado");

    if (idxSem === -1 || idxOwn === -1 || idxEst === -1) return;

    const existentesActual = new Set();
    const tareasPorSemana = {};

    for (let i = 1; i < data.length; i++) {
      const r = data[i];
      const s = String(r[idxSem] || "").trim();
      const o = String(r[idxOwn] || "").trim();
      const p = String(r[idxProy] || "").trim();

      if (coincidenSemanas(s, semanaActual)) existentesActual.add(o + "||" + p);

      if (!tareasPorSemana[s]) tareasPorSemana[s] = [];
      tareasPorSemana[s].push({ id: r[0], semana: s, owner: o, proyecto: p, todos: r[idxTodos] || "", bloqueos: r[idxBloq] || "", estado: String(r[idxEst] || "").trim() });
    }

    const semanas = generarSemanasDisponibles(semanaActual);
    const idxAct = semanas.findIndex(s => coincidenSemanas(s, semanaActual));
    if (idxAct <= 0) return;

    const semanaPrev = semanas[idxAct - 1];
    let previas = [];
    for (const k in tareasPorSemana) {
      if (coincidenSemanas(k, semanaPrev)) { previas = tareasPorSemana[k]; break; }
    }

    const nuevas = [];
    const fecha = _getFechaHoy();
    previas.forEach(item => {
      if (item.estado !== "Completado") {
        const clave = item.owner + "||" + item.proyecto;
        if (!existentesActual.has(clave)) {
          nuevas.push(["SEM-" + Utilities.getUuid().substring(0, 8).toUpperCase(), semanaActual, item.owner, item.proyecto, item.todos, "", item.bloqueos, item.estado, fecha]);
          existentesActual.add(clave);
        }
      }
    });

    if (nuevas.length > 0) {
      sheet.getRange(data.length + 1, 1, nuevas.length, nuevas[0].length).setValues(nuevas);
      registrarAuditoria(ss, "SISTEMA", "SEGUIMIENTO_SEMANAL", "ROLLOVER", `Traspaso de ${nuevas.length} tareas pendientes a ${semanaActual}`);
    }
  } catch (err) {
    Logger.log("Error en rollover: " + err.message);
  }
}

// ==============================================================================
// CRUD — SEGUIMIENTO SEMANAL
// ==============================================================================

function guardarSeguimientoSemanal(item) {
  const ss = getDB();
  if (!ss) return { success: false, error: "Base de datos no disponible" };
  const sheet = ss.getSheetByName(CONFIG.SHEET_SEMANAL);
  if (!sheet) return { success: false, error: "Hoja de seguimiento semanal no encontrada" };
  const userEmail = _getUserEmail();
  const id = item.id || "SEM-" + Utilities.getUuid().substring(0, 8).toUpperCase();
  const fila = [id, item.semana || "", item.owner || "", item.proyecto || "", item.todos || "", item.novedades || "", item.bloqueos || "", item.estado || "En proceso", _getFechaHoy()];

  if (item.id) {
    const row = buscarFilaPorId(sheet, item.id);
    if (row > 0) {
      sheet.getRange(row, 1, 1, fila.length).setValues([fila]);
      registrarAuditoria(ss, userEmail, "SEGUIMIENTO_SEMANAL", "EDITAR", `Actualizo ${item.proyecto} (${item.owner})`);
      return { success: true, id: id, accion: "actualizado" };
    }
  }
  sheet.appendRow(fila);
  registrarAuditoria(ss, userEmail, "SEGUIMIENTO_SEMANAL", "CREAR", `Creo ${item.proyecto} (${item.owner})`);
  return { success: true, id: id, accion: "creado" };
}

function actualizarCampoSemanal(id, campo, valor) {
  const mapa = { semana: 2, owner: 3, proyecto: 4, todos: 5, novedades: 6, bloqueos: 7, estado: 8 };
  return _actualizarCelda(CONFIG.SHEET_SEMANAL, id, mapa, campo, valor, "SEGUIMIENTO_SEMANAL");
}

function actualizarEstadoSemanal(id, nuevoEstado) {
  return actualizarCampoSemanal(id, "estado", nuevoEstado);
}

function eliminarSeguimientoSemanal(id) {
  return _eliminarFila(CONFIG.SHEET_SEMANAL, id, 4, "SEGUIMIENTO_SEMANAL");
}

// ==============================================================================
// CRUD — TAREAS RECURRENTES
// ==============================================================================

function guardarTareaRecurrente(item) {
  const ss = getDB();
  if (!ss) return { success: false, error: "Base de datos no disponible" };
  const sheet = ss.getSheetByName(CONFIG.SHEET_RECURRENTES);
  if (!sheet) return { success: false, error: "Hoja de tareas recurrentes no encontrada" };
  const userEmail = _getUserEmail();
  const id = item.id || "REC-" + Utilities.getUuid().substring(0, 8).toUpperCase();
  const fila = [id, item.owner || "", item.tarea || "", item.frecuencia || "Semanal", item.links || "", item.descripcion || "", _getFechaHoy()];

  if (item.id) {
    const row = buscarFilaPorId(sheet, item.id);
    if (row > 0) {
      sheet.getRange(row, 1, 1, fila.length).setValues([fila]);
      registrarAuditoria(ss, userEmail, "TAREA_RECURRENTE", "EDITAR", `Modifico recurrente ${item.tarea}`);
      return { success: true, id: id, accion: "actualizado" };
    }
  }
  sheet.appendRow(fila);
  registrarAuditoria(ss, userEmail, "TAREA_RECURRENTE", "CREAR", `Creo recurrente ${item.tarea}`);
  return { success: true, id: id, accion: "creado" };
}

function actualizarCampoRecurrente(id, campo, valor) {
  const mapa = { owner: 2, tarea: 3, frecuencia: 4, links: 5, descripcion: 6 };
  return _actualizarCelda(CONFIG.SHEET_RECURRENTES, id, mapa, campo, valor, "TAREA_RECURRENTE");
}

function eliminarTareaRecurrente(id) {
  return _eliminarFila(CONFIG.SHEET_RECURRENTES, id, 3, "TAREA_RECURRENTE");
}

// ==============================================================================
// CRUD — TEMAS FUTUROS (BACKLOG)
// ==============================================================================

function guardarTemaFuturo(item) {
  const ss = getDB();
  if (!ss) return { success: false, error: "Base de datos no disponible" };
  const sheet = ss.getSheetByName(CONFIG.SHEET_FUTUROS);
  if (!sheet) return { success: false, error: "Hoja de temas futuros no encontrada" };
  const userEmail = _getUserEmail();
  const id = item.id || "FUT-" + Utilities.getUuid().substring(0, 8).toUpperCase();
  const fila = [id, item.owner || "", item.tema || "", item.pilar || "General", item.target || "A definir", item.notas || "", item.estado || "Pendiente", _getFechaHoy()];

  if (item.id) {
    const row = buscarFilaPorId(sheet, item.id);
    if (row > 0) {
      sheet.getRange(row, 1, 1, fila.length).setValues([fila]);
      registrarAuditoria(ss, userEmail, "TEMA_FUTURO", "EDITAR", `Modifico futuro ${item.tema}`);
      return { success: true, id: id, accion: "actualizado" };
    }
  }
  sheet.appendRow(fila);
  registrarAuditoria(ss, userEmail, "TEMA_FUTURO", "CREAR", `Creo futuro ${item.tema}`);
  return { success: true, id: id, accion: "creado" };
}

function actualizarCampoFuturo(id, campo, valor) {
  const mapa = { owner: 2, tema: 3, pilar: 4, target: 5, notas: 6, estado: 7 };
  return _actualizarCelda(CONFIG.SHEET_FUTUROS, id, mapa, campo, valor, "TEMA_FUTURO");
}

function eliminarTemaFuturo(id) {
  return _eliminarFila(CONFIG.SHEET_FUTUROS, id, 3, "TEMA_FUTURO");
}

function promoverTemaFuturoASemanal(temaId, semanaTarget) {
  const ss = getDB();
  if (!ss) return { success: false, error: "Base de datos no disponible" };
  const sFut = ss.getSheetByName(CONFIG.SHEET_FUTUROS);
  if (!sFut) return { success: false, error: "Hoja de temas futuros no encontrada" };
  const row = buscarFilaPorId(sFut, temaId);
  if (row <= 0) return { success: false, error: "Tema futuro no encontrado" };

  const datos = sFut.getRange(row, 1, 1, 8).getValues()[0];
  const owner = datos[1], tema = datos[2], target = semanaTarget || calcularSemanaActualISO();

  sFut.getRange(row, 7).setValue("Promovido");
  const resSem = guardarSeguimientoSemanal({ semana: target, owner: owner, proyecto: tema, todos: "- [ ] " + tema, estado: "En proceso" });
  registrarAuditoria(ss, _getUserEmail(), "TEMA_FUTURO", "PROMOVER", `Promovio ${tema} a ${target}`);
  return { success: true, nuevoSemanalId: resSem ? resSem.id : null };
}

// ==============================================================================
// CRUD — HUB DE REPORTES
// ==============================================================================

function guardarReporte(item) {
  const ss = getDB();
  if (!ss) return { success: false, error: "Base de datos no disponible" };
  const sheet = ss.getSheetByName(CONFIG.SHEET_REPORTES);
  if (!sheet) return { success: false, error: "Hoja de reportes no encontrada" };
  const userEmail = _getUserEmail();
  const id = item.id || "REP-" + Utilities.getUuid().substring(0, 8).toUpperCase();
  const nombre = item.nombre || item.nombre_del_reporte || "";
  const url = item.url || item.url_directa || "";
  const fila = [id, item.owner || "", nombre, item.descripcion || "", item.herramienta || "Looker", url, item.frecuencia || "Semanal", item.tags || "", _getFechaHoy()];

  if (item.id) {
    const row = buscarFilaPorId(sheet, item.id);
    if (row > 0) {
      sheet.getRange(row, 1, 1, fila.length).setValues([fila]);
      registrarAuditoria(ss, userEmail, "REPORTE", "EDITAR", `Modifico reporte ${nombre}`);
      return { success: true, id: id, accion: "actualizado" };
    }
  }
  sheet.appendRow(fila);
  registrarAuditoria(ss, userEmail, "REPORTE", "CREAR", `Creo reporte ${nombre}`);
  return { success: true, id: id, accion: "creado" };
}

function actualizarCampoReporte(id, campo, valor) {
  const mapa = { owner: 2, nombre: 3, nombredelreporte: 3, descripcion: 4, herramienta: 5, url: 6, urldirecta: 6, frecuencia: 7, tags: 8 };
  return _actualizarCelda(CONFIG.SHEET_REPORTES, id, mapa, campo, valor, "REPORTE");
}

function eliminarReporte(id) {
  return _eliminarFila(CONFIG.SHEET_REPORTES, id, 3, "REPORTE");
}

function registrarClickReporte(nombreReporte, ownerReporte) {
  const ss = getDB();
  registrarSesion(ss, _getUserEmail(), "CLIC_REPORTE", `Abrio reporte: ${nombreReporte || ""} (${ownerReporte || ""})`);
  return { success: true };
}

// ==============================================================================
// CRUD — BOLSA DE TAREAS PENDIENTES
// ==============================================================================

function guardarTareaBolsa(item) {
  const ss = getDB();
  if (!ss) return { success: false, error: "Base de datos no disponible" };
  const sheet = ss.getSheetByName(CONFIG.SHEET_BOLSA);
  if (!sheet) return { success: false, error: "Hoja de bolsa no encontrada" };
  const userEmail = _getUserEmail();
  const id = item.id || "BOL-" + Utilities.getUuid().substring(0, 8).toUpperCase();
  const fila = [id, item.titulo || "", item.descripcion || "", item.pilar || "General", item.prioridad || "Media", item.creado_por || item.creadoPor || userEmail, item.asignado_a || item.asignadoA || "Sin asignar", item.estado || "Pendiente", _getFechaHoy()];

  if (item.id) {
    const row = buscarFilaPorId(sheet, item.id);
    if (row > 0) {
      sheet.getRange(row, 1, 1, fila.length).setValues([fila]);
      registrarAuditoria(ss, userEmail, "BOLSA_PENDIENTES", "EDITAR", `Actualizo tarea en bolsa: ${item.titulo}`);
      return { success: true, id: id, accion: "actualizado" };
    }
  }
  sheet.appendRow(fila);
  registrarAuditoria(ss, userEmail, "BOLSA_PENDIENTES", "CREAR", `Agrego tarea a bolsa: ${item.titulo}`);
  return { success: true, id: id, accion: "creado" };
}

function actualizarCampoBolsa(id, campo, valor) {
  const mapa = { titulo: 2, descripcion: 3, pilar: 4, prioridad: 5, creadopor: 6, creado_por: 6, asignadoa: 7, asignado_a: 7, estado: 8 };
  return _actualizarCelda(CONFIG.SHEET_BOLSA, id, mapa, campo, valor, "BOLSA_PENDIENTES");
}

function eliminarTareaBolsa(id) {
  return _eliminarFila(CONFIG.SHEET_BOLSA, id, 2, "BOLSA_PENDIENTES");
}

function asignarTareaBolsaAMiembro(bolsaId, targetOwner, enviarASemanal, semanaTarget) {
  const ss = getDB();
  if (!ss) return { success: false, error: "Base de datos no disponible" };
  const sheet = ss.getSheetByName(CONFIG.SHEET_BOLSA);
  if (!sheet) return { success: false, error: "Hoja de bolsa no encontrada" };
  const row = buscarFilaPorId(sheet, bolsaId);
  if (row <= 0) return { success: false, error: "No encontrada en la bolsa" };

  const datos = sheet.getRange(row, 1, 1, 9).getValues()[0];
  const titulo = datos[1], desc = datos[2];

  sheet.getRange(row, 7).setValue(targetOwner);
  sheet.getRange(row, 8).setValue("Asignada");
  registrarAuditoria(ss, _getUserEmail(), "BOLSA_PENDIENTES", "ASIGNAR", `Asigno tarea '${titulo}' a ${targetOwner}`);

  let resSemanal = null;
  if (enviarASemanal) {
    resSemanal = guardarSeguimientoSemanal({
      semana: semanaTarget || calcularSemanaActualISO(),
      owner: targetOwner,
      proyecto: titulo,
      todos: desc ? `- ${desc}` : `- ${titulo}`,
      estado: "En proceso"
    });
  }
  return { success: true, semanalId: resSemanal ? resSemanal.id : null };
}

// ==============================================================================
// GESTIÓN DE EQUIPO Y PANEL ADMIN
// ==============================================================================

function guardarMiembroEquipo(item) {
  const ss = getDB();
  const userEmail = _getUserEmail();
  if (!verificarEsAdmin(userEmail)) return { success: false, error: "Acceso denegado: solo administradores" };

  const sheet = ss.getSheetByName(CONFIG.SHEET_EQUIPO);
  const data = sheet.getDataRange().getValues();
  const emailBuscado = String(item.email || "").toLowerCase().trim();

  let rowIndex = -1;
  for (let i = 1; i < data.length; i++) {
    if (String(data[i][1]).toLowerCase().trim() === emailBuscado) { rowIndex = i + 1; break; }
  }

  const fila = [item.nombre || "", emailBuscado, item.rol || "Analyst"];
  if (rowIndex > 0) {
    sheet.getRange(rowIndex, 1, 1, 3).setValues([fila]);
    registrarAuditoria(ss, userEmail, "EQUIPO", "EDITAR", `Actualizo datos de ${item.nombre}`);
  } else {
    sheet.appendRow(fila);
    registrarAuditoria(ss, userEmail, "EQUIPO", "CREAR", `Agrego nuevo miembro: ${item.nombre}`);
  }
  return { success: true, equipo: leerHoja(ss, CONFIG.SHEET_EQUIPO) };
}

function _eliminarFilasPorOwner(sheet, colIndex, nombre) {
  if (!sheet) return 0;
  const data = sheet.getDataRange().getValues();
  if (data.length <= 1) return 0;
  const target = String(nombre || "").trim().toLowerCase();
  let eliminadas = 0;
  for (let i = data.length - 1; i >= 1; i--) {
    if (String(data[i][colIndex - 1] || "").trim().toLowerCase() === target) {
      sheet.deleteRow(i + 1);
      eliminadas++;
    }
  }
  return eliminadas;
}

function _desasignarBolsaPorOwner(sheet, colAsignado, nombre) {
  if (!sheet) return 0;
  const data = sheet.getDataRange().getValues();
  if (data.length <= 1) return 0;
  const target = String(nombre || "").trim().toLowerCase();
  let modificadas = 0;
  for (let i = 1; i < data.length; i++) {
    if (String(data[i][colAsignado - 1] || "").trim().toLowerCase() === target) {
      sheet.getRange(i + 1, colAsignado).setValue("Sin asignar");
      sheet.getRange(i + 1, 8).setValue("Pendiente");
      modificadas++;
    }
  }
  return modificadas;
}

function eliminarMiembroEquipo(email) {
  const ss = getDB();
  const userEmail = _getUserEmail();
  if (!verificarEsAdmin(userEmail)) return { success: false, error: "Acceso denegado: solo administradores" };

  const sheet = ss.getSheetByName(CONFIG.SHEET_EQUIPO);
  if (!sheet) return { success: false, error: "Hoja de Equipo no encontrada" };

  const data = sheet.getDataRange().getValues();
  const emailBuscado = String(email || "").toLowerCase().trim();

  let rowIndex = -1, nombre = "";
  for (let i = 1; i < data.length; i++) {
    if (String(data[i][1]).toLowerCase().trim() === emailBuscado) {
      rowIndex = i + 1;
      nombre = String(data[i][0]).trim();
      break;
    }
  }

  if (rowIndex > 0) {
    // 1. Eliminar todas sus tareas en cascada en todas las hojas
    let totalEliminadas = 0;
    totalEliminadas += _eliminarFilasPorOwner(ss.getSheetByName(CONFIG.SHEET_SEMANAL), 3, nombre);
    totalEliminadas += _eliminarFilasPorOwner(ss.getSheetByName(CONFIG.SHEET_RECURRENTES), 2, nombre);
    totalEliminadas += _eliminarFilasPorOwner(ss.getSheetByName(CONFIG.SHEET_FUTUROS), 2, nombre);
    totalEliminadas += _eliminarFilasPorOwner(ss.getSheetByName(CONFIG.SHEET_REPORTES), 2, nombre);
    _desasignarBolsaPorOwner(ss.getSheetByName(CONFIG.SHEET_BOLSA), 7, nombre);

    // 2. Eliminar al miembro de la hoja Equipo
    sheet.deleteRow(rowIndex);

    registrarAuditoria(ss, userEmail, "EQUIPO", "ELIMINAR", `Elimino a ${nombre} (${emailBuscado}) y sus ${totalEliminadas} tareas asociadas`);
    return { success: true, totalTareasEliminadas: totalEliminadas, equipo: leerHoja(ss, CONFIG.SHEET_EQUIPO) };
  }
  return { success: false, error: "Miembro no encontrado" };
}

function obtenerDatosAdmin() {
  const ss = getDB();
  const userEmail = _getUserEmail();
  if (!verificarEsAdmin(userEmail)) return { success: false, error: "No autorizado" };

  let sesionesRaw = [], auditoriaRaw = [], equipo = [];
  try { sesionesRaw = leerHoja(ss, CONFIG.SHEET_LOG_SESIONES); } catch (_) {}
  try { auditoriaRaw = leerHoja(ss, CONFIG.SHEET_LOG_AUDITORIA); } catch (_) {}
  try { equipo = leerHoja(ss, CONFIG.SHEET_EQUIPO); } catch (_) {}

  const stats = {};
  sesionesRaw.forEach(s => {
    const u = String(s.usuario || "anonimo").toLowerCase().trim();
    if (!stats[u]) stats[u] = { email: u, sesiones: 0, cambios: 0, clicsReportes: 0, ultimoAcceso: "" };
    stats[u].sesiones++;
    if (s.fecha_y_hora && (!stats[u].ultimoAcceso || s.fecha_y_hora > stats[u].ultimoAcceso)) {
      stats[u].ultimoAcceso = s.fecha_y_hora;
    }
    if (s.accion === "CLIC_REPORTE") stats[u].clicsReportes++;
  });

  auditoriaRaw.forEach(a => {
    const u = String(a.usuario || "anonimo").toLowerCase().trim();
    if (!stats[u]) stats[u] = { email: u, sesiones: 0, cambios: 0, clicsReportes: 0, ultimoAcceso: "" };
    stats[u].cambios++;
  });

  return {
    success: true,
    autorizado: true,
    resumenUsuarios: Object.values(stats),
    ultimasAcciones: auditoriaRaw.slice(-15).reverse(),
    equipo: equipo
  };
}

// ==============================================================================
// TELEMETRÍA Y LOGS
// ==============================================================================

function registrarSesion(ss, email, accion, detalle) {
  try {
    const sheet = ss.getSheetByName(CONFIG.SHEET_LOG_SESIONES);
    if (sheet) sheet.appendRow([_getFechaHoy(), email, accion, detalle]);
  } catch (_) {}
}

function registrarAuditoria(ss, email, entidad, accion, detalle) {
  try {
    const sheet = ss.getSheetByName(CONFIG.SHEET_LOG_AUDITORIA);
    if (sheet) sheet.appendRow([_getFechaHoy(), email, entidad, accion, detalle]);
  } catch (_) {}
}

// ==============================================================================
// GESTIÓN AUTOMÁTICA DE ESQUEMA DE HOJAS
// ==============================================================================

function formatearEncabezado(sheet, numCols, estilo) {
  const header = sheet.getRange(1, 1, 1, numCols);
  header.setBackground(estilo.fondo).setFontColor(estilo.colorTexto).setFontWeight("bold").setFontFamily(estilo.fuente).setFontSize(estilo.tamano).setVerticalAlignment("middle");
  sheet.setRowHeight(1, 32).setFrozenRows(1);
}

function asegurarEstructuraPlanilla(ss) {
  const estilo = { fondo: "#0F172A", colorTexto: "#FFFFFF", fuente: "Inter", tamano: 10 };
  const fecha = _getFechaHoy();
  const semActual = calcularSemanaActualISO();

  const schemas = [
    {
      name: CONFIG.SHEET_SEMANAL,
      headers: ["ID", "Semana", "Owner", "Proyecto", "Todos", "Novedades", "Bloqueos", "Estado", "Ultima Actualizacion"],
      widths: [90, 200, 150, 220, 360, 260, 260, 110, 140],
      seed: [
        ["SEM-INIT01", semActual, "Matías Cagliero", "HoD & Monthly Regional", "- [x] Revisar comments de Nicki\n- [ ] Cerrar metricas de fin de mes", "Avances según roadmap", "", "En proceso", fecha],
        ["SEM-INIT02", semActual, "Nicki Krawiecki", "Seguimiento de Proyectos", "- Alinear to-dos con analistas\n- Definir prioridades Q4", "Lanzado sistema unificado", "", "En proceso", fecha]
      ]
    },
    {
      name: CONFIG.SHEET_RECURRENTES,
      headers: ["ID", "Owner", "Tarea", "Frecuencia", "Links", "Descripcion", "Ultima Actualizacion"],
      widths: [90, 150, 280, 110, 200, 240, 140],
      seed: [
        ["REC-INIT01", "Matías Cagliero", "Monitoreo Diario de Alertas Operativas WHS", "Diario", "https://script.google.com", "Alertas operativas diarias", fecha],
        ["REC-INIT02", "Matías Cagliero", "Consolidacion HoD & Monthly Regional", "Semanal", "https://docs.google.com/presentation", "Deck semanal para leadership", fecha]
      ]
    },
    {
      name: CONFIG.SHEET_FUTUROS,
      headers: ["ID", "Owner", "Tema", "Pilar", "Target", "Notas", "Estado", "Ultima Actualizacion"],
      widths: [90, 150, 260, 120, 130, 240, 110, 140],
      seed: [
        ["FUT-01", "Matías Cagliero", "Automatizacion de Alertas de Stockout en Datamart", "Operaciones", "Noviembre 2026", "Query programada en BigQuery", "Pendiente", fecha],
        ["FUT-02", "Nicki Krawiecki", "Redisenio de Matriz de OKRs 2027", "Management", "Diciembre 2026", "Alineacion con VP de Market", "Pendiente", fecha]
      ]
    },
    {
      name: CONFIG.SHEET_REPORTES,
      headers: ["ID", "Owner", "Nombre del Reporte", "Descripcion", "Herramienta", "URL Directa", "Frecuencia", "Tags", "Ultima Actualizacion"],
      widths: [90, 150, 220, 260, 130, 240, 110, 180, 140],
      seed: [
        ["REP-INIT01", "Matías Cagliero", "WHS Performance Alerts", "Alertas operativas diarias por almacen", "Web App", "https://script.google.com", "Diario", "Operaciones, WHS", fecha],
        ["REP-INIT02", "Nicki Krawiecki", "Monthly Regional Review", "Deck ejecutivo de performance", "Google Slides", "https://docs.google.com", "Mensual", "Ejecutivo, OKRs", fecha]
      ]
    },
    {
      name: CONFIG.SHEET_EQUIPO,
      headers: ["Nombre", "Email", "Rol"],
      widths: [200, 260, 180],
      seed: [
        ["Matías Cagliero", "matias.cagliero@pedidosya.com", "Lead Analyst"],
        ["Nicki Krawiecki", "nicole.krawiecki@pedidosya.com", "Head of Performance"],
        ["Juan Pablo Pinori Diaz", "juan.pinori@pedidosya.com", "Specialist Data"]
      ]
    },
    {
      name: CONFIG.SHEET_BOLSA,
      headers: ["ID", "Titulo", "Descripcion", "Pilar", "Prioridad", "Creado Por", "Asignado A", "Estado", "Ultima Actualizacion"],
      widths: [90, 250, 280, 130, 110, 160, 160, 110, 140],
      seed: [
        ["BOL-01", "Auditoria de filtros de feriados y slots en BigQuery", "Revisar consistencia de metricas diarias ante feriados", "Data / BigQuery", "Alta", "Matías Cagliero", "Sin asignar", "Pendiente", fecha],
        ["BOL-02", "Glosario y documentacion de metricas de Small Order Fee", "Resumen tecnico de definicion de SOF", "Operaciones", "Media", "Nicki Krawiecki", "Sin asignar", "Pendiente", fecha]
      ]
    },
    {
      name: CONFIG.SHEET_LOG_SESIONES,
      headers: ["Fecha y Hora", "Usuario", "Accion", "Detalle"],
      widths: [160, 240, 160, 320]
    },
    {
      name: CONFIG.SHEET_LOG_AUDITORIA,
      headers: ["Fecha y Hora", "Usuario", "Entidad", "Accion", "Detalle"],
      widths: [160, 240, 160, 120, 320]
    }
  ];

  schemas.forEach(s => {
    let sheet = ss.getSheetByName(s.name);
    if (!sheet) {
      sheet = ss.insertSheet(s.name);
      sheet.appendRow(s.headers);
      formatearEncabezado(sheet, s.headers.length, estilo);
      s.widths.forEach((w, i) => sheet.setColumnWidth(i + 1, w));
      if (s.seed) s.seed.forEach(r => sheet.appendRow(r));
    }
  });
}

// ==============================================================================
// FECHAS, SEMANAS ISO Y NOMBRES
// ==============================================================================

function calcularSemanaActualISO(fechaRef) {
  const d = fechaRef ? new Date(fechaRef) : new Date();
  const diaSem = d.getDay();
  const diffLunes = (diaSem === 0 ? -6 : 1) - diaSem;
  const lunes = new Date(d);
  lunes.setDate(d.getDate() + diffLunes);

  const domingo = new Date(lunes);
  domingo.setDate(lunes.getDate() + 6);

  const dTarget = new Date(d.valueOf());
  const dayNr = (d.getDay() + 6) % 7;
  dTarget.setDate(dTarget.getDate() - dayNr + 3);
  const primerJueves = dTarget.valueOf();
  dTarget.setMonth(0, 1);
  if (dTarget.getDay() !== 4) {
    dTarget.setMonth(0, 1 + ((4 - dTarget.getDay()) + 7) % 7);
  }
  const numeroSemana = 1 + Math.ceil((primerJueves - dTarget) / 604800000);

  const meses = ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"];
  const pad = n => String(n).padStart(2, "0");
  const strLunes = `${pad(lunes.getDate())} ${meses[lunes.getMonth()]}`;
  const strDomingo = `${pad(domingo.getDate())} ${meses[domingo.getMonth()]}`;

  return `Semana ${pad(numeroSemana)} | ${strLunes} - ${strDomingo}`;
}

function generarSemanasDisponibles(semanaActual) {
  const lista = [];
  const hoy = new Date();
  for (let i = -8; i <= 8; i++) {
    const d = new Date(hoy);
    d.setDate(hoy.getDate() + (i * 7));
    lista.push(calcularSemanaActualISO(d));
  }
  if (semanaActual && !lista.some(s => coincidenSemanas(s, semanaActual))) {
    lista.push(semanaActual);
  }
  return lista;
}

function deducirNombreDeEmail(email, equipo) {
  if (!email) return "Analista";
  const eClean = email.toLowerCase().trim();
  const match = equipo.find(m => m.email && m.email.toLowerCase().trim() === eClean);
  if (match && match.nombre) return match.nombre;

  const local = email.split("@")[0] || "analista";
  return local.split(/[._-]/).map(p => p.charAt(0).toUpperCase() + p.slice(1).toLowerCase()).join(" ");
}

// ==============================================================================
// DIAGNÓSTICO Y AUTORIZACIÓN
// ==============================================================================

function testDebug() {
  Logger.log(ejecutarDiagnosticoBackend());
}

function ejecutarDiagnosticoBackend() {
  const logs = ["=== DIAGNOSTICO DE BACKEND GOOGLE APPS SCRIPT ==="];
  logs.push("Fecha/Hora: " + new Date().toString());
  logs.push("Spreadsheet ID: " + CONFIG.SPREADSHEET_ID);

  try {
    const ss = getDB();
    logs.push(`[OK] Conexion con Spreadsheet: ${ss.getName()} (${ss.getUrl()})`);
  } catch (e) {
    logs.push("[FALLO] No se pudo abrir la planilla: " + e.message);
  }

  const email = _getUserEmail();
  logs.push(`Usuario: ${email} (Admin: ${verificarEsAdmin(email)})`);

  try {
    const config = obtenerConfiguracionInicial();
    logs.push(`[OK] Config: ${config.semanaActual} (${config.equipo.length} miembros)`);
  } catch (e) {
    logs.push("[FALLO] Config fallo: " + e.message);
  }

  try {
    const datos = obtenerDatosCompletos();
    logs.push(`[OK] Datos: ${datos.seguimientoSemanal.length} semanales, ${datos.recurrentes.length} recurrentes, ${datos.bolsa.length} bolsa`);
  } catch (e) {
    logs.push("[FALLO] Datos fallo: " + e.message);
  }

  return logs.join("\n");
}

function inicializarPlanillaManualmente() {
  const ss = getDB();
  asegurarEstructuraPlanilla(ss);
  Logger.log("[OK] Planilla inicializada exitosamente: " + ss.getUrl());
}

function autorizarPermisos() {
  const email = Session.getActiveUser().getEmail();
  const ss = getDB();
  Logger.log("[OK] Permisos autorizados para: " + email + " en " + ss.getUrl());
}
