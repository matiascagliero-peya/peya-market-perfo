/**
 * PEDIDOSYA MARKET — PROJECT TRACKER & REPORT HUB
 * Sistema de Gestión de Scope, Tareas Recurrentes, Prioridades y Reportes
 * Sincronizado en tiempo real con Google Sheets (Estructura agrupada de 4 pestañas)
 */
const CONFIG = {
  SPREADSHEET_ID: "1vBq5i_IRlAuhgos6awzl68j-tlKo-7vZAKtwp4do1dA",
  // Estructura agrupada optimizada (4 pestañas)
  SHEET_SEMANAL: "1. Seguimiento Semanal",
  SHEET_TAREAS_PENDIENTES: "2. Tareas y Pendientes",
  SHEET_EQUIPO: "3. Equipo",
  SHEET_LOGS: "4. Logs",
  // Hojas separadas de respaldo (por si existen en la planilla)
  SHEET_RECURRENTES: "Tareas Recurrentes",
  SHEET_FUTUROS: "Temas Futuros",
  SHEET_BOLSA: "Bolsa de Pendientes",
  SHEET_REPORTES: "Hub de Reportes",
  SHEET_LOG_SESIONES: "Log_Sesiones",
  SHEET_LOG_AUDITORIA: "Log_Auditoria",
  ADMIN_EMAIL: "matias.cagliero@pedidosya.com",
  TITULO_APP: "Project Tracker & Hub de Reportes | PeYa Market",
  VERSION: "2.2.0"
};

function getDB() {
  if (CONFIG.SPREADSHEET_ID && CONFIG.SPREADSHEET_ID.trim()) {
    try { return SpreadsheetApp.openById(CONFIG.SPREADSHEET_ID.trim()); } catch (e) {}
  }
  try { return SpreadsheetApp.getActiveSpreadsheet(); } catch (e) {}
  return null;
}

function getHojaInteligente(ss, nombreBuscado) {
  if (!ss) return null;
  let s = ss.getSheetByName(nombreBuscado);
  if (s) return s;
  const clean = String(nombreBuscado).trim().toLowerCase();
  const sheets = ss.getSheets();
  for (let i = 0; i < sheets.length; i++) {
    if (sheets[i].getName().trim().toLowerCase() === clean) return sheets[i];
  }
  for (let i = 0; i < sheets.length; i++) {
    const cur = sheets[i].getName().trim().toLowerCase();
    if (clean.includes("semanal") && (cur.includes("semanal") || cur.includes("seguimiento") || cur.includes("weekly"))) return sheets[i];
    if ((clean.includes("tareas") || clean.includes("pendientes") || clean.includes("scope")) && (cur.includes("tareas y pendientes") || cur.includes("scope y pendientes"))) return sheets[i];
    if (clean.includes("recurrente") && (cur.includes("recurrente") || cur.includes("scope") || cur.includes("fija"))) return sheets[i];
    if (clean.includes("futuro") && (cur.includes("futuro") || cur.includes("backlog") || cur.includes("parking"))) return sheets[i];
    if (clean.includes("bolsa") && (cur.includes("bolsa") || cur.includes("pendientes") || cur.includes("pool"))) return sheets[i];
    if (clean.includes("reporte") && (cur.includes("reporte") || cur.includes("hub") || cur.includes("dashboards"))) return sheets[i];
    if (clean.includes("equipo") && (cur.includes("equipo") || cur.includes("team") || cur.includes("miembro"))) return sheets[i];
    if (clean.includes("log") && (cur.includes("logs") || cur.includes("auditoria") || cur.includes("sesion"))) return sheets[i];
  }
  return null;
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
  return String(str).toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/[^a-z0-9]/g, "_").replace(/^_+|_+$/g, "").replace(/_{2,}/g, "_");
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
  const sheet = getHojaInteligente(ss, sheetName);
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
      if (val instanceof Date) val = Utilities.formatDate(val, "GMT-3", "yyyy-MM-dd HH:mm");
      obj[headers[j]] = val;
    }
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
  const sheet = getHojaInteligente(ss, sheetName);
  if (!sheet) return { success: false, error: "Hoja no encontrada: " + sheetName };
  const rowIndex = buscarFilaPorId(sheet, id);
  if (rowIndex <= 0) return { success: false, error: "Registro no encontrado" };
  const col = mapaCols[campo.toLowerCase().replace(/[^a-z0-9]/g, "")];
  if (!col) return { success: false, error: "Campo no reconocido" };
  sheet.getRange(rowIndex, col).setValue(valor);
  sheet.getRange(rowIndex, sheet.getLastColumn()).setValue(_getFechaHoy());
  SpreadsheetApp.flush();
  registrarAuditoria(ss, _getUserEmail(), entidad, "EDITAR_CAMPO", `Actualizo ${campo} en ${entidad} [ID: ${id}]`);
  return { success: true };
}

function _eliminarFila(sheetName, id, colNombre, entidad) {
  const ss = getDB();
  const sheet = getHojaInteligente(ss, sheetName);
  if (!sheet) return { success: false, error: "Hoja no encontrada: " + sheetName };
  const rowIndex = buscarFilaPorId(sheet, id);
  if (rowIndex <= 0) return { success: false, error: "Registro no encontrado" };
  const nombre = colNombre ? String(sheet.getRange(rowIndex, colNombre).getValue()) : id;
  sheet.deleteRow(rowIndex);
  SpreadsheetApp.flush();
  registrarAuditoria(ss, _getUserEmail(), entidad, "ELIMINAR", `Elimino ${entidad}: ${nombre} [ID: ${id}]`);
  return { success: true };
}

// ==============================================================================
// CICLO DE VIDA WEB APP Y CARGA DE DATOS AGRUPADA
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

    // Intentar leer desde la hoja unificada '2. Tareas y Pendientes'
    const sUnificada = getHojaInteligente(ss, "tareas y pendientes") || getHojaInteligente(ss, CONFIG.SHEET_TAREAS_PENDIENTES);
    if (sUnificada) {
      const data = leerHoja(ss, sUnificada.getName());
      data.forEach(r => {
        const tipo = String(r.tipo || "").toLowerCase();
        const tit = r.titulo_tarea || r.titulo___tarea || r.tarea || r.titulo || "";
        const frecPilar = r.frecuencia_pilar || r.frecuencia___pilar || r.frecuencia || r.pilar || "";
        const prioTarget = r.prioridad_target || r.prioridad___target || r.prioridad || r.target || "";
        if (tipo.includes("rec")) {
          recurrentes.push({ id: r.id, owner: r.owner || "", tarea: tit, frecuencia: frecPilar || "Semanal", links: r.links || "", descripcion: prioTarget || "" });
        } else if (tipo.includes("fut")) {
          futuros.push({ id: r.id, owner: r.owner || "", tema: tit, pilar: frecPilar || "General", target: prioTarget || "A definir", notas: r.links || "", estado: r.estado || "Pendiente" });
        } else if (tipo.includes("bolsa") || tipo.includes("pend")) {
          bolsa.push({ id: r.id, titulo: tit, descripcion: r.links || "", pilar: frecPilar || "General", prioridad: prioTarget || "Media", creadoPor: r.creadopor || "Analista", asignadoA: r.owner || "Sin asignar", estado: r.estado || "Pendiente" });
        }
      });
    } else {
      // Si existen separadas, leer cada una
      try { recurrentes = leerHoja(ss, CONFIG.SHEET_RECURRENTES); } catch (_) {}
      try { futuros = leerHoja(ss, CONFIG.SHEET_FUTUROS); } catch (_) {}
      try { bolsa = leerHoja(ss, CONFIG.SHEET_BOLSA); } catch (_) {}
      try { reportes = leerHoja(ss, CONFIG.SHEET_REPORTES); } catch (_) {}
    }

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
  return {
    seguimientoSemanal: semanal,
    recurrentes: recurrentes,
    futuros: futuros,
    reportes: reportes,
    bolsa: bolsa,
    equipo: equipo,
    semanaSeleccionada: semanaFiltro || semanaActual,
    semanaActual: semanaActual
  };
}

function obtenerConfiguracionInicial() {
  const ss = getDB();
  const email = _getUserEmail();
  const semanaActual = calcularSemanaActualISO();
  const datos = _cargarPaqueteDatos(ss, semanaActual);
  return {
    usuarioActual: {
      email: email,
      nombre: deducirNombreDeEmail(email, datos.equipo),
      esAdmin: verificarEsAdmin(email)
    },
    spreadsheetUrl: ss ? ss.getUrl() : "",
    spreadsheetName: ss ? ss.getName() : "",
    semanaActual: semanaActual,
    semanasDisponibles: generarSemanasDisponibles(semanaActual),
    equipo: datos.equipo,
    conexionSheets: { conectado: !!ss },
    datos: datos
  };
}

function obtenerDatosCompletos(semanaFiltro) {
  return _cargarPaqueteDatos(getDB(), semanaFiltro);
}

// ==============================================================================
// CRUD — 1. SEGUIMIENTO SEMANAL
// ==============================================================================

function coincidenSemanas(sem1, sem2) {
  if (!sem1 || !sem2) return false;
  const s1 = String(sem1).trim().toLowerCase(), s2 = String(sem2).trim().toLowerCase();
  if (s1 === s2) return true;
  const m1 = s1.match(/(?:w|semana\s*)(\d{1,2})/i), m2 = s2.match(/(?:w|semana\s*)(\d{1,2})/i);
  return !!(m1 && m2 && m1[1] === m2[1]);
}

function guardarSeguimientoSemanal(item) {
  const ss = getDB();
  if (!ss) return { success: false, error: "Base de datos no disponible" };
  const sheet = getHojaInteligente(ss, CONFIG.SHEET_SEMANAL);
  if (!sheet) return { success: false, error: "Hoja de seguimiento semanal no encontrada" };

  const data = sheet.getDataRange().getValues();
  let rowIndex = item.id ? buscarFilaPorId(sheet, item.id) : -1;
  if (rowIndex <= 0 && item.owner && item.semana) {
    for (let i = 1; i < data.length; i++) {
      if (String(data[i][2] || "").trim().toLowerCase() === item.owner.toLowerCase() && coincidenSemanas(data[i][1], item.semana)) {
        rowIndex = i + 1; break;
      }
    }
  }

  const idFinal = (rowIndex > 0 && data[rowIndex - 1][0]) ? String(data[rowIndex - 1][0]).trim() : (item.id || "SEM-" + Utilities.getUuid().substring(0, 8).toUpperCase());
  const fila = [idFinal, item.semana || "", item.owner || "", item.proyecto || "Iniciativa Principal", item.todos || "", item.novedades || "", item.bloqueos || "", item.estado || "En proceso", _getFechaHoy()];

  if (rowIndex > 0) {
    sheet.getRange(rowIndex, 1, 1, fila.length).setValues([fila]);
  } else {
    sheet.appendRow(fila);
  }
  SpreadsheetApp.flush();
  registrarAuditoria(ss, _getUserEmail(), "SEGUIMIENTO_SEMANAL", rowIndex > 0 ? "EDITAR" : "CREAR", `${item.proyecto} (${item.owner})`);
  return { success: true, id: idFinal, accion: rowIndex > 0 ? "actualizado" : "creado" };
}

function actualizarCampoSemanal(id, campo, valor, owner, semana) {
  const ss = getDB();
  const sheet = getHojaInteligente(ss, CONFIG.SHEET_SEMANAL);
  if (!sheet) return { success: false, error: "Hoja no encontrada" };

  let rowIndex = id ? buscarFilaPorId(sheet, id) : -1;
  if (rowIndex <= 0 && owner && semana) {
    const data = sheet.getDataRange().getValues();
    for (let i = 1; i < data.length; i++) {
      if (String(data[i][2] || "").toLowerCase() === owner.toLowerCase() && coincidenSemanas(data[i][1], semana)) {
        rowIndex = i + 1; break;
      }
    }
  }
  const col = { semana: 2, owner: 3, proyecto: 4, todos: 5, novedades: 6, bloqueos: 7, estado: 8 }[campo.toLowerCase().replace(/[^a-z0-9]/g, "")];
  if (rowIndex > 0 && col) {
    sheet.getRange(rowIndex, col).setValue(valor);
    sheet.getRange(rowIndex, sheet.getLastColumn()).setValue(_getFechaHoy());
    SpreadsheetApp.flush();
    return { success: true };
  }
  return guardarSeguimientoSemanal({ id: id, owner: owner || "", semana: semana || "", [campo]: valor });
}

function actualizarEstadoSemanal(id, nuevoEstado, owner, semana) {
  return actualizarCampoSemanal(id, "estado", nuevoEstado, owner, semana);
}

function eliminarSeguimientoSemanal(id) {
  return _eliminarFila(CONFIG.SHEET_SEMANAL, id, 4, "SEGUIMIENTO_SEMANAL");
}

// ==============================================================================
// CRUD — 2. TAREAS Y PENDIENTES (AGRUPADA: RECURRENTES, FUTUROS Y BOLSA)
// ==============================================================================

function _upsertHojaTareasUnificada(ss, item, tipoDefecto) {
  const sUnificada = getHojaInteligente(ss, "tareas y pendientes") || getHojaInteligente(ss, CONFIG.SHEET_TAREAS_PENDIENTES);
  if (!sUnificada) return null;

  const data = sUnificada.getDataRange().getValues();
  let rowIndex = item.id ? buscarFilaPorId(sUnificada, item.id) : -1;
  const idFinal = (rowIndex > 0 && data[rowIndex - 1][0]) ? String(data[rowIndex - 1][0]).trim() : (item.id || `${tipoDefecto.slice(0,3).toUpperCase()}-` + Utilities.getUuid().substring(0, 8).toUpperCase());

  const tit = item.tarea || item.tema || item.titulo || "";
  const frecPilar = item.frecuencia || item.pilar || "";
  const prioTarget = item.target || item.prioridad || item.descripcion || "";
  const fila = [idFinal, tipoDefecto, item.owner || item.asignado_a || "", tit, frecPilar, prioTarget, item.links || item.notas || "", item.estado || "Pendiente", _getFechaHoy()];

  if (rowIndex > 0) {
    sUnificada.getRange(rowIndex, 1, 1, fila.length).setValues([fila]);
  } else {
    sUnificada.appendRow(fila);
  }
  SpreadsheetApp.flush();
  return { success: true, id: idFinal };
}

function guardarTareaRecurrente(item) {
  const ss = getDB();
  if (!ss) return { success: false, error: "DB no disponible" };
  const resUni = _upsertHojaTareasUnificada(ss, item, "Recurrente");
  if (resUni) return resUni;

  const sheet = getHojaInteligente(ss, CONFIG.SHEET_RECURRENTES);
  if (!sheet) return { success: false, error: "Hoja no encontrada" };
  const row = item.id ? buscarFilaPorId(sheet, item.id) : -1;
  const id = (row > 0) ? item.id : (item.id || "REC-" + Utilities.getUuid().substring(0, 8).toUpperCase());
  const fila = [id, item.owner || "", item.tarea || "", item.frecuencia || "Semanal", item.links || "", item.descripcion || "", _getFechaHoy()];
  if (row > 0) sheet.getRange(row, 1, 1, fila.length).setValues([fila]); else sheet.appendRow(fila);
  SpreadsheetApp.flush();
  return { success: true, id: id };
}

function actualizarCampoRecurrente(id, campo, valor, owner, tareaNombre) {
  const ss = getDB();
  const sUni = getHojaInteligente(ss, "tareas y pendientes") || getHojaInteligente(ss, CONFIG.SHEET_TAREAS_PENDIENTES);
  if (sUni) {
    const col = { owner: 3, tarea: 4, frecuencia: 5, links: 7, descripcion: 6 }[campo.toLowerCase()] || 4;
    return _actualizarCelda(sUni.getName(), id, { [campo]: col }, campo, valor, "TAREA_RECURRENTE");
  }
  return guardarTareaRecurrente({ id: id, owner: owner || "", tarea: tareaNombre || valor, [campo]: valor });
}

function eliminarTareaRecurrente(id) {
  const sUni = getHojaInteligente(getDB(), "tareas y pendientes");
  return _eliminarFila(sUni ? sUni.getName() : CONFIG.SHEET_RECURRENTES, id, 3, "TAREA_RECURRENTE");
}

function guardarTemaFuturo(item) {
  const ss = getDB();
  const resUni = _upsertHojaTareasUnificada(ss, item, "Futuro");
  if (resUni) return resUni;

  const sheet = getHojaInteligente(ss, CONFIG.SHEET_FUTUROS);
  if (!sheet) return { success: false, error: "Hoja no encontrada" };
  const id = item.id || "FUT-" + Utilities.getUuid().substring(0, 8).toUpperCase();
  const fila = [id, item.owner || "", item.tema || "", item.pilar || "General", item.target || "A definir", item.notas || "", item.estado || "Pendiente", _getFechaHoy()];
  const row = item.id ? buscarFilaPorId(sheet, item.id) : -1;
  if (row > 0) sheet.getRange(row, 1, 1, fila.length).setValues([fila]); else sheet.appendRow(fila);
  SpreadsheetApp.flush();
  return { success: true, id: id };
}

function actualizarCampoFuturo(id, campo, valor) {
  const sUni = getHojaInteligente(getDB(), "tareas y pendientes");
  if (sUni) return _actualizarCelda(sUni.getName(), id, { owner: 3, tema: 4, pilar: 5, target: 6, notas: 7, estado: 8 }, campo, valor, "TEMA_FUTURO");
  return _actualizarCelda(CONFIG.SHEET_FUTUROS, id, { owner: 2, tema: 3, pilar: 4, target: 5, notas: 6, estado: 7 }, campo, valor, "TEMA_FUTURO");
}

function eliminarTemaFuturo(id) {
  const sUni = getHojaInteligente(getDB(), "tareas y pendientes");
  return _eliminarFila(sUni ? sUni.getName() : CONFIG.SHEET_FUTUROS, id, 3, "TEMA_FUTURO");
}

function promoverTemaFuturoASemanal(temaId, semanaTarget) {
  const ss = getDB();
  const sUni = getHojaInteligente(ss, "tareas y pendientes");
  const sFut = sUni || getHojaInteligente(ss, CONFIG.SHEET_FUTUROS);
  if (!sFut) return { success: false, error: "Hoja no encontrada" };
  const row = buscarFilaPorId(sFut, temaId);
  if (row <= 0) return { success: false, error: "Tema no encontrado" };

  const datos = sFut.getRange(row, 1, 1, 9).getValues()[0];
  const colOwner = sUni ? 2 : 1, colTema = sUni ? 3 : 2;
  const owner = datos[colOwner], tema = datos[colTema], target = semanaTarget || calcularSemanaActualISO();
  sFut.getRange(row, sUni ? 8 : 7).setValue("Promovido");
  SpreadsheetApp.flush();

  const sSem = getHojaInteligente(ss, CONFIG.SHEET_SEMANAL);
  let resSem = null;
  if (sSem) {
    const semData = sSem.getDataRange().getValues();
    let rowSem = -1, existingTodos = "";
    for (let i = 1; i < semData.length; i++) {
      if (String(semData[i][2] || "").toLowerCase() === String(owner).toLowerCase() && coincidenSemanas(semData[i][1], target)) {
        rowSem = i + 1; existingTodos = String(semData[i][4] || ""); break;
      }
    }
    if (rowSem > 0) {
      sSem.getRange(rowSem, 5).setValue(existingTodos ? (existingTodos.trim() + "\n- [ ] " + tema) : ("- [ ] " + tema));
      sSem.getRange(rowSem, sSem.getLastColumn()).setValue(_getFechaHoy());
      SpreadsheetApp.flush();
      resSem = { success: true, id: String(semData[rowSem - 1][0]).trim() };
    } else {
      resSem = guardarSeguimientoSemanal({ semana: target, owner: owner, proyecto: tema, todos: "- [ ] " + tema, estado: "En proceso" });
    }
  }
  return { success: true, nuevoSemanalId: resSem ? resSem.id : null };
}

function guardarTareaBolsa(item) {
  const ss = getDB();
  const resUni = _upsertHojaTareasUnificada(ss, item, "Bolsa");
  if (resUni) return resUni;

  const sheet = getHojaInteligente(ss, CONFIG.SHEET_BOLSA);
  if (!sheet) return { success: false, error: "Hoja no encontrada" };
  const id = item.id || "BOL-" + Utilities.getUuid().substring(0, 8).toUpperCase();
  const fila = [id, item.titulo || "", item.descripcion || "", item.pilar || "General", item.prioridad || "Media", item.creado_por || item.creadoPor || "Analista", item.asignado_a || item.asignadoA || "Sin asignar", item.estado || "Pendiente", _getFechaHoy()];
  const row = item.id ? buscarFilaPorId(sheet, item.id) : -1;
  if (row > 0) sheet.getRange(row, 1, 1, fila.length).setValues([fila]); else sheet.appendRow(fila);
  SpreadsheetApp.flush();
  return { success: true, id: id };
}

function actualizarCampoBolsa(id, campo, valor) {
  const sUni = getHojaInteligente(getDB(), "tareas y pendientes");
  if (sUni) return _actualizarCelda(sUni.getName(), id, { titulo: 4, descripcion: 7, pilar: 5, prioridad: 6, estado: 8 }, campo, valor, "BOLSA_PENDIENTES");
  return _actualizarCelda(CONFIG.SHEET_BOLSA, id, { titulo: 2, descripcion: 3, pilar: 4, prioridad: 5, creadopor: 6, asignadoa: 7, estado: 8 }, campo, valor, "BOLSA_PENDIENTES");
}

function eliminarTareaBolsa(id) {
  const sUni = getHojaInteligente(getDB(), "tareas y pendientes");
  return _eliminarFila(sUni ? sUni.getName() : CONFIG.SHEET_BOLSA, id, 2, "BOLSA_PENDIENTES");
}

function asignarTareaBolsaAMiembro(bolsaId, targetOwner, enviarASemanal, semanaTarget) {
  const ss = getDB();
  const sUni = getHojaInteligente(ss, "tareas y pendientes");
  const sheet = sUni || getHojaInteligente(ss, CONFIG.SHEET_BOLSA);
  if (!sheet) return { success: false, error: "Hoja no encontrada" };
  const row = buscarFilaPorId(sheet, bolsaId);
  if (row <= 0) return { success: false, error: "No encontrada en bolsa" };

  const datos = sheet.getRange(row, 1, 1, 9).getValues()[0];
  const colTit = sUni ? 3 : 1, colDesc = sUni ? 6 : 2;
  const titulo = datos[colTit], desc = datos[colDesc];
  sheet.getRange(row, sUni ? 3 : 7).setValue(targetOwner);
  sheet.getRange(row, 8).setValue("Asignada");
  SpreadsheetApp.flush();

  let resSemanal = null;
  if (enviarASemanal) {
    const sSem = getHojaInteligente(ss, CONFIG.SHEET_SEMANAL);
    const targetSem = semanaTarget || calcularSemanaActualISO();
    if (sSem) {
      const semData = sSem.getDataRange().getValues();
      let rowSem = -1, existingTodos = "";
      for (let i = 1; i < semData.length; i++) {
        if (String(semData[i][2] || "").toLowerCase() === String(targetOwner).toLowerCase() && coincidenSemanas(semData[i][1], targetSem)) {
          rowSem = i + 1; existingTodos = String(semData[i][4] || ""); break;
        }
      }
      const itemText = desc ? `- [ ] ${desc}` : `- [ ] ${titulo}`;
      if (rowSem > 0) {
        if (!existingTodos.includes(titulo)) {
          sSem.getRange(rowSem, 5).setValue(existingTodos ? (existingTodos.trim() + "\n" + itemText) : itemText);
          sSem.getRange(rowSem, sSem.getLastColumn()).setValue(_getFechaHoy());
          SpreadsheetApp.flush();
        }
        resSemanal = { success: true, id: String(semData[rowSem - 1][0]).trim() };
      } else {
        resSemanal = guardarSeguimientoSemanal({ semana: targetSem, owner: targetOwner, proyecto: titulo, todos: itemText, estado: "En proceso" });
      }
    }
  }
  return { success: true, semanalId: resSemanal ? resSemanal.id : null };
}

// Compatibilidad Reportes (si se invocan)
function guardarReporte(item) { return { success: true }; }
function actualizarCampoReporte(id, c, v) { return { success: true }; }
function eliminarReporte(id) { return { success: true }; }
function registrarClickReporte(nombre, owner) {
  registrarSesion(getDB(), _getUserEmail(), "CLIC_REPORTE", `${nombre || ""} (${owner || ""})`);
  return { success: true };
}

// ==============================================================================
// CRUD — 3. EQUIPO Y 4. LOGS
// ==============================================================================

function guardarMiembroEquipo(item) {
  const ss = getDB(), email = String(item.email || "").toLowerCase().trim();
  const sheet = getHojaInteligente(ss, CONFIG.SHEET_EQUIPO);
  if (!sheet) return { success: false, error: "Hoja de equipo no encontrada" };
  const data = sheet.getDataRange().getValues();
  let rowIndex = -1;
  for (let i = 1; i < data.length; i++) {
    if (String(data[i][1]).toLowerCase().trim() === email) { rowIndex = i + 1; break; }
  }
  const fila = [item.nombre || "", email, item.rol || "Analyst"];
  if (rowIndex > 0) sheet.getRange(rowIndex, 1, 1, 3).setValues([fila]); else sheet.appendRow(fila);
  SpreadsheetApp.flush();
  return { success: true, equipo: leerHoja(ss, CONFIG.SHEET_EQUIPO) };
}

function eliminarMiembroEquipo(email) {
  const ss = getDB(), emailBuscado = String(email || "").toLowerCase().trim();
  const sheet = getHojaInteligente(ss, CONFIG.SHEET_EQUIPO);
  if (!sheet) return { success: false, error: "Hoja no encontrada" };
  const data = sheet.getDataRange().getValues();
  let rowIndex = -1;
  for (let i = 1; i < data.length; i++) {
    if (String(data[i][1]).toLowerCase().trim() === emailBuscado) { rowIndex = i + 1; break; }
  }
  if (rowIndex > 0) {
    sheet.deleteRow(rowIndex);
    SpreadsheetApp.flush();
    return { success: true, equipo: leerHoja(ss, CONFIG.SHEET_EQUIPO) };
  }
  return { success: false, error: "Miembro no encontrado" };
}

function obtenerDatosAdmin() {
  const ss = getDB();
  if (!verificarEsAdmin(_getUserEmail())) return { success: false, error: "No autorizado" };
  const sLogs = getHojaInteligente(ss, CONFIG.SHEET_LOGS) || getHojaInteligente(ss, CONFIG.SHEET_LOG_AUDITORIA);
  return {
    success: true,
    autorizado: true,
    resumenUsuarios: [],
    ultimasAcciones: (leerHoja(ss, sLogs ? sLogs.getName() : CONFIG.SHEET_LOG_AUDITORIA) || []).slice(-15).reverse(),
    equipo: leerHoja(ss, CONFIG.SHEET_EQUIPO)
  };
}

function registrarSesion(ss, email, accion, detalle) {
  try {
    const sLogs = getHojaInteligente(ss, CONFIG.SHEET_LOGS) || getHojaInteligente(ss, CONFIG.SHEET_LOG_SESIONES);
    if (sLogs) {
      if (sLogs.getName().includes("4. Logs") || sLogs.getName().toLowerCase() === "logs") {
        sLogs.appendRow([_getFechaHoy(), email, "SESION", accion, detalle]);
      } else {
        sLogs.appendRow([_getFechaHoy(), email, accion, detalle]);
      }
      SpreadsheetApp.flush();
    }
  } catch (_) {}
}

function registrarAuditoria(ss, email, entidad, accion, detalle) {
  try {
    const sLogs = getHojaInteligente(ss, CONFIG.SHEET_LOGS) || getHojaInteligente(ss, CONFIG.SHEET_LOG_AUDITORIA);
    if (sLogs) {
      if (sLogs.getName().includes("4. Logs") || sLogs.getName().toLowerCase() === "logs") {
        sLogs.appendRow([_getFechaHoy(), email, entidad, accion, detalle]);
      } else {
        sLogs.appendRow([_getFechaHoy(), email, entidad, accion, detalle]);
      }
      SpreadsheetApp.flush();
    }
  } catch (_) {}
}

function calcularSemanaActualISO(fechaRef) {
  const d = fechaRef ? new Date(fechaRef) : new Date();
  const diaSem = d.getDay();
  const diffLunes = (diaSem === 0 ? -6 : 1) - diaSem;
  const lunes = new Date(d); lunes.setDate(d.getDate() + diffLunes);
  const domingo = new Date(lunes); domingo.setDate(lunes.getDate() + 6);
  const dTarget = new Date(d.valueOf());
  dTarget.setDate(dTarget.getDate() - ((d.getDay() + 6) % 7) + 3);
  const primerJueves = dTarget.valueOf();
  dTarget.setMonth(0, 1);
  if (dTarget.getDay() !== 4) dTarget.setMonth(0, 1 + ((4 - dTarget.getDay()) + 7) % 7);
  const numeroSemana = 1 + Math.ceil((primerJueves - dTarget) / 604800000);
  const meses = ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"];
  const pad = n => String(n).padStart(2, "0");
  return `Semana ${pad(numeroSemana)} | ${pad(lunes.getDate())} ${meses[lunes.getMonth()]} - ${pad(domingo.getDate())} ${meses[domingo.getMonth()]}`;
}

function generarSemanasDisponibles(semanaActual) {
  const lista = [], hoy = new Date();
  for (let i = -8; i <= 8; i++) {
    const d = new Date(hoy); d.setDate(hoy.getDate() + (i * 7));
    lista.push(calcularSemanaActualISO(d));
  }
  if (semanaActual && !lista.some(s => coincidenSemanas(s, semanaActual))) lista.push(semanaActual);
  return lista;
}

function deducirNombreDeEmail(email, equipo) {
  if (!email) return "Analista";
  const eClean = email.toLowerCase().trim();
  const match = (equipo || []).find(m => m.email && m.email.toLowerCase().trim() === eClean);
  if (match && match.nombre) return match.nombre;
  const local = email.split("@")[0] || "analista";
  return local.split(/[._-]/).map(p => p.charAt(0).toUpperCase() + p.slice(1).toLowerCase()).join(" ");
}

function probarConexionSheets() {
  const ss = getDB();
  return { conectado: !!ss, spreadsheetId: CONFIG.SPREADSHEET_ID, spreadsheetName: ss ? ss.getName() : "" };
}

function ejecutarDiagnosticoBackend() {
  const ss = getDB();
  return `=== DIAGNOSTICO DE BACKEND ===\nConexion: ${ss ? ss.getName() : "FALLO"}\nUsuario: ${_getUserEmail()}\nSemana: ${calcularSemanaActualISO()}`;
}

function autorizarPermisos() {
  Logger.log("[OK] Permisos autorizados para: " + _getUserEmail());
}

// ==============================================================================
// CREACIÓN AUTOMÁTICA DE LAS 4 PESTAÑAS AGRUPADAS
// ==============================================================================
function crearPestanasSiNoExisten() {
  const ss = getDB();
  if (!ss) return "[ERROR] No se pudo conectar con la base de datos.";

  const schemas = [
    {
      name: "1. Seguimiento Semanal",
      keyword: "semanal",
      headers: ["ID", "Semana", "Owner", "Proyecto", "Todos", "Novedades", "Bloqueos", "Estado", "Ultima Actualizacion"],
      widths: [90, 200, 150, 220, 360, 260, 260, 110, 140]
    },
    {
      name: "2. Tareas y Pendientes",
      keyword: "tareas y pendientes",
      headers: ["ID", "Tipo", "Owner", "Titulo / Tarea", "Frecuencia / Pilar", "Prioridad / Target", "Links", "Estado", "Ultima Actualizacion"],
      widths: [90, 110, 150, 280, 130, 130, 220, 110, 140]
    },
    {
      name: "3. Equipo",
      keyword: "equipo",
      headers: ["Nombre", "Email", "Rol"],
      widths: [200, 260, 180],
      seed: [
        ["Matías Cagliero", "matias.cagliero@pedidosya.com", "Lead Analyst"],
        ["Nicki Krawiecki", "nicole.krawiecki@pedidosya.com", "Head of Performance"],
        ["Juan Pablo Pinori Diaz", "juan.pinori@pedidosya.com", "Specialist Data"]
      ]
    },
    {
      name: "4. Logs",
      keyword: "logs",
      headers: ["Fecha y Hora", "Usuario", "Entidad", "Accion", "Detalle"],
      widths: [160, 240, 160, 120, 320]
    }
  ];

  const creadas = [], existentes = [];

  schemas.forEach(s => {
    let sheet = getHojaInteligente(ss, s.keyword);
    if (!sheet) {
      sheet = ss.insertSheet(s.name);
      sheet.appendRow(s.headers);
      const hRange = sheet.getRange(1, 1, 1, s.headers.length);
      hRange.setBackground("#0F172A").setFontColor("#FFFFFF").setFontWeight("bold").setFontFamily("Inter").setFontSize(10).setVerticalAlignment("middle");
      sheet.setRowHeight(1, 32).setFrozenRows(1);
      s.widths.forEach((w, i) => sheet.setColumnWidth(i + 1, w));
      if (s.seed) s.seed.forEach(r => sheet.appendRow(r));
      creadas.push(s.name);
    } else {
      existentes.push(sheet.getName());
    }
  });

  SpreadsheetApp.flush();
  const resumen = `[OK] Pestañas agrupadas listas:\n- Creadas (${creadas.length}): ${creadas.join(", ") || "Ninguna (ya existían)"}\n- Detectadas (${existentes.length}): ${existentes.join(", ")}`;
  Logger.log(resumen);
  return resumen;
}
