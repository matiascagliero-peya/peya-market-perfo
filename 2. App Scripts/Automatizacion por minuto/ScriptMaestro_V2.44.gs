const CONFIG = {
  EMAIL_ALERTA_JEFE : "matias.cagliero@pedidosya.com",
  NOMBRE_HOJA_CONFIG: "Envíos",
  NOMBRE_HOJA_LOGS  : "Registros",
  ZONA_HORARIA      : "GMT-3",
  FORMATO_FECHA     : "EEEE, dd MMMM, hh:mm:ss a",
  REINTENTOS         : 3,
  ESPERA_REINTENTO_MS: 3000,
  ESPERA_BQ_SEG      : 300,
  VENTANA_GLOBAL: {
    HORA_INICIO: "06:00",
    HORA_FIN   : "15:00"
  }
};

const COL = {
  NOMBRE_DESTINO   : 0,  // A: Nombre de referencia / destino
  TIPO             : 1,  // B: Tipo ("Actualizar" o "Importar")
  ID_ORIGEN        : 2,  // C: id - Página de origen (vacío, "-", "Este sheets" o ID externo)
  ORIGEN_NOMBRE    : 3,  // D: Nombre - Página origen
  FRECUENCIA       : 4,  // E: Frecuencia ("Día 1", "Diaria", etc.)
  HORARIO_BQ       : 5,  // F: Horario Actualización
  ULTIMA_ACT_BQ    : 6,  // G: Última actualización (timestamp escrito por script)
  ID_DESTINO       : 7,  // H: id - Página destino
  DESTINO_NOMBRE   : 8,  // I: Nombre - Página destino
  HORARIO_ENVIO    : 9,  // J: Horario Envío
  ULTIMO_ENVIO     : 10  // K: Último envío (timestamp escrito por script)
};

const TOTAL_COLS = 11;

function onOpen() {
  try {
    verificarOCrearHojas();
  } catch (e) {
    console.error("Error al verificar/crear hojas en onOpen: " + e.message);
  }

  try {
    SpreadsheetApp.getUi()
      .createMenu('🚀 Gestión de Reportes')
      .addItem('⚠️ FORZAR Sincronizar Extracto', 'forzarSincronizacion')
      .addItem('⚠️ FORZAR Enviar a destinos',    'forzarEnvios')
      .addToUi();
  } catch (e) {
    console.error("Error al crear menú en onOpen: " + e.message);
  }
}

function ejecutarTodo() {
  let lock;
  try {
    lock = LockService.getScriptLock();
    if (!lock.tryLock(10000)) return;
  } catch (errLock) {
    console.warn("Aviso temporal de LockService/Storage: " + errLock.message);
    return;
  }

  try {
    procesarTodo(false, "todo");
  } catch (e) {
    const msg = String(e && e.message ? e.message : e);
    console.error("Error capturado en ejecutarTodo: " + msg);

    const esErrorStorage = msg.includes("reading from storage") ||
                           msg.includes("INTERNAL") ||
                           msg.includes("Service Spreadsheets failed");

    if (!esErrorStorage) {
      try {
        log("Error Crítico", "Sistema", msg, e);
      } catch (e2) {
        console.error("No se pudo registrar el error crítico: " + e2.message);
      }
    } else {
      console.warn("Hipo transitorio de Google Storage detectado (" + msg + "). Se reintentará en el próximo ciclo.");
    }
  } finally {
    try {
      SpreadsheetApp.flush();
    } catch (eFlush) {
      console.warn("Aviso al hacer flush en finally: " + eFlush.message);
    }
    try {
      if (lock) lock.releaseLock();
    } catch (e3) {}
  }
}

function procesarTodo(esForzado, modo) {
  const hoy = new Date();

  if (!esForzado && !dentroDeVentanaGlobal(hoy)) {
    logDecision("⚙ Sistema", `⏭ FUERA DE VENTANA (${textoVentanaGlobal()}) · ahora ${formatHoraActual(hoy)}`, "—");
    return;
  }

  SpreadsheetApp.enableBigQueryExecution();
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const hojaConfig = ss.getSheetByName(CONFIG.NOMBRE_HOJA_CONFIG);
  if (!hojaConfig) return;

  const colMap = obtenerMapeoColumnas(hojaConfig);
  const filas = leerFilas(hojaConfig, colMap);
  const yaRefrescado = new Set();
  const bufferLog = [];

  filas.forEach(({ fila, numFila }) => {
    if (esFilaVacia(fila, colMap)) return;

    const nombreRef = (colMap.NOMBRE_DESTINO >= 0) ? String(fila[colMap.NOMBRE_DESTINO] || "(sin nombre)").trim() : "(sin nombre)";
    const frecuencia = (colMap.FRECUENCIA >= 0) ? String(fila[colMap.FRECUENCIA] || "").trim() : "";

    const fc = frecuenciaCorresponde(frecuencia, hoy);

    // Si no tiene frecuencia (vacío o guión), no hace nada (desactivado)
    if (fc.desactivado) {
      acumularLog(bufferLog, nombreRef, "⏸ sin frecuencia (desactivado)", "⏸ sin frecuencia (desactivado)");
      return;
    }

    if (!esForzado && !fc.ok) {
      const txt = `⏸ no corresponde hoy (${fc.etiqueta || frecuencia})`;
      acumularLog(bufferLog, nombreRef, (modo === "envio") ? "— (omitido)" : txt, (modo === "bq") ? "— (omitido)" : txt);
      return;
    }

    const resBQ = (modo === "envio")
      ? "— (omitido)"
      : evaluarActualizacion(ss, hojaConfig, fila, numFila, hoy, esForzado, yaRefrescado, colMap);

    const resEnvio = (modo === "bq")
      ? "— (omitido)"
      : evaluarEnvio(ss, hojaConfig, fila, numFila, hoy, esForzado, colMap);

    acumularLog(bufferLog, nombreRef, resBQ, resEnvio);
  });

  escribirLogsBatch(bufferLog);
  try { SpreadsheetApp.flush(); } catch (e) {}
}

function evaluarActualizacion(ss, hojaConfig, fila, numFila, hoy, esForzado, yaRefrescado, colMap) {
  const col = colMap || COL;
  const tipo = (col.TIPO >= 0) ? String(fila[col.TIPO] || "").trim().toLowerCase() : "actualizar";
  const idOrigen = (col.ID_ORIGEN >= 0) ? String(fila[col.ID_ORIGEN] || "").trim() : "";
  const origen = (col.ORIGEN_NOMBRE >= 0) ? String(fila[col.ORIGEN_NOMBRE] || "").trim() : "";
  const horarioBQ = (col.HORARIO_BQ >= 0) ? String(fila[col.HORARIO_BQ] || "").trim() : "";
  let ultimaActBQ = (col.ULTIMA_ACT_BQ >= 0) ? fila[col.ULTIMA_ACT_BQ] : null;
  const ahoraStr = formatHoraActual(hoy);

  if (!origen) return "— (sin pestaña origen)";

  const minProg = horarioAMinutos(horarioBQ);
  if (!esForzado && minProg === null) return "⏸ desactivado (sin horario BQ)";

  const horarioPaso = pasaHorario(horarioBQ, hoy);
  if (!esForzado && !horarioPaso) return `⏳ aún no (prog ${horarioBQ} · ahora ${ahoraStr})`;

  let yaHoy = yaFueHoy(ultimaActBQ, hoy);
  if (yaHoy && !esForzado) return `⏭ ya fue hoy`;

  try {
    const ssOrig = obtenerSpreadsheetOrigen(idOrigen, ss);
    const esLocal = (ssOrig.getId() === ss.getId());

    if (esLocal) {
      const hojaOrig = ss.getSheetByName(origen);
      if (!hojaOrig) throw new Error(`no existe la pestaña "${origen}" en este sheets`);

      if (tipo.includes("actualiz") || !tipo.includes("import")) {
        const claveRefresco = `${ss.getId()}::${origen}`;
        if (!(esForzado && yaRefrescado.has(claveRefresco))) {
          refrescarHojaConReintentos(hojaOrig);
          yaRefrescado.add(claveRefresco);
        }
      }

      let tsExito = new Date();
      if (tipo.includes("actualiz") || !tipo.includes("import")) {
        const tsBQ = obtenerTimestampBQ(hojaOrig);
        if (tsBQ) tsExito = tsBQ;
      }
      escribirFechaBQ(hojaConfig, numFila, tsExito, col);

      return "✅ actualiza";
    } else {
      const hojaOrig = ssOrig.getSheetByName(origen);
      if (!hojaOrig) throw new Error(`no existe la pestaña "${origen}" en el origen externo`);

      const hojaLocal = ss.getSheetByName(origen) || ss.insertSheet(origen);
      quitarFiltro(hojaOrig);
      quitarFiltro(hojaLocal);
      const valores = hojaOrig.getDataRange().getValues();
      if (valores.length > 0 && valores[0].length > 0) {
        const numCols = valores[0].length;
        const maxRows = hojaLocal.getMaxRows();
        hojaLocal.getRange(1, 1, maxRows, numCols).clearContent();
        hojaLocal.getRange(1, 1, valores.length, numCols).setValues(valores);
      }

      let tsExito = new Date();
      escribirFechaBQ(hojaConfig, numFila, tsExito, col);

      return "✅ importado";
    }
  } catch (e) {
    const errorPrefix = tipo.includes("import") ? "Error Import" : "Error BQ";
    const clasif = clasificarError(e.message, errorPrefix);
    const valorCelda = `${errorPrefix}: ${clasif.resumen}`;

    if (col.ULTIMA_ACT_BQ >= 0) {
      const celda = hojaConfig.getRange(numFila, col.ULTIMA_ACT_BQ + 1);
      celda.setValue(valorCelda);
      const horaStr = Utilities.formatDate(hoy, CONFIG.ZONA_HORARIA, "dd/MM/yyyy HH:mm:ss");
      const nota = `[${errorPrefix}] ${clasif.diagnostico}\n\nDetalle técnico:\n${e.message}\n\nHora: ${horaStr}`;
      try { celda.setNote(nota); } catch (errNote) {}
    }
    return `❌ ${valorCelda} (${e.message})`;
  }
}

function escribirFechaBQ(hojaConfig, numFila, fecha, colMap) {
  const col = colMap || COL;
  if (col.ULTIMA_ACT_BQ >= 0) {
    const fechaTxt = Utilities.formatDate(fecha, CONFIG.ZONA_HORARIA, CONFIG.FORMATO_FECHA);
    const celda = hojaConfig.getRange(numFila, col.ULTIMA_ACT_BQ + 1);
    celda.setValue(fechaTxt);
    try { celda.clearNote(); } catch (errNote) {}
  }
}

function evaluarEnvio(ss, hojaConfig, fila, numFila, hoy, esForzado, colMap) {
  const col = colMap || COL;
  const origen = (col.ORIGEN_NOMBRE >= 0) ? String(fila[col.ORIGEN_NOMBRE] || "").trim() : "";
  const destinoId = (col.ID_DESTINO >= 0) ? String(fila[col.ID_DESTINO] || "").trim() : "";
  const destinoHoja = (col.DESTINO_NOMBRE >= 0) ? String(fila[col.DESTINO_NOMBRE] || "").trim() : "";
  const horarioEnvio = (col.HORARIO_ENVIO >= 0) ? String(fila[col.HORARIO_ENVIO] || "").trim() : "";
  const ultimoEnvio = (col.ULTIMO_ENVIO >= 0) ? fila[col.ULTIMO_ENVIO] : null;
  const ahoraStr = formatHoraActual(hoy);

  if (!origen || !destinoId || !destinoHoja) return "— (faltan datos)";

  const yaHoy = yaFueHoy(ultimoEnvio, hoy);
  const horarioPaso = pasaHorario(horarioEnvio, hoy);

  if (!esForzado) {
    if (horarioAMinutos(horarioEnvio) === null) return "⏸ desactivado (sin horario envío)";
    if (yaHoy) return `⏭ ya fue hoy`;
    if (!horarioPaso) return `⏳ aún no (prog ${horarioEnvio} · ahora ${ahoraStr})`;
  }

  try {
    const id = extraerIdSpreadsheet(destinoId);
    const ssDest = SpreadsheetApp.openById(id);
    const shDest = ssDest.getSheetByName(destinoHoja) || ssDest.insertSheet(destinoHoja);
    
    const shOrig = ss.getSheetByName(origen);
    if (!shOrig) throw new Error(`no existe la pestaña local "${origen}" en este sheets`);

    // Validar si la pestaña origen de BigQuery tiene un estado de error
    const detalleErrorBQ = obtenerDetalleErrorBQ(shOrig);
    if (detalleErrorBQ) {
      throw new Error(`BigQuery en origen "${origen}" con error: ${detalleErrorBQ}`);
    }

    quitarFiltro(shOrig);
    quitarFiltro(shDest);

    const valores = shOrig.getDataRange().getValues();
    if (!valores || valores.length === 0 || !valores[0] || valores[0].length === 0) {
      throw new Error(`la pestaña origen "${origen}" está vacía`);
    }

    shDest.clearContents();
    shDest.getRange(1, 1, valores.length, valores[0].length).setValues(valores);

    if (col.ULTIMO_ENVIO >= 0) {
      const fechaExito = Utilities.formatDate(new Date(), CONFIG.ZONA_HORARIA, CONFIG.FORMATO_FECHA);
      const celda = hojaConfig.getRange(numFila, col.ULTIMO_ENVIO + 1);
      celda.setValue(fechaExito);
      try { celda.clearNote(); } catch (errNote) {}
    }

    return `✅ enviado → ${destinoHoja}`;
  } catch (e) {
    const msgLower = String(e.message || "").toLowerCase();
    const esErrorBQ = msgLower.includes("bigquery") || msgLower.includes("bq");
    const errorPrefix = esErrorBQ ? "Error BQ" : "Error Envío";
    const clasif = clasificarError(e.message, errorPrefix);
    const valorCelda = `${errorPrefix}: ${clasif.resumen}`;

    if (col.ULTIMO_ENVIO >= 0) {
      const celda = hojaConfig.getRange(numFila, col.ULTIMO_ENVIO + 1);
      celda.setValue(valorCelda);
      const horaStr = Utilities.formatDate(hoy, CONFIG.ZONA_HORARIA, "dd/MM/yyyy HH:mm:ss");
      const nota = `[${errorPrefix}] ${clasif.diagnostico}\n\nDetalle técnico:\n${e.message}\n\nHora: ${horaStr}`;
      try { celda.setNote(nota); } catch (errNote) {}
    }

    return `❌ ${valorCelda} (${e.message})`;
  }
}

function obtenerMapeoColumnas(hojaConfig) {
  const map = { ...COL };
  if (!hojaConfig) return map;

  const lastCol = hojaConfig.getLastColumn();
  if (lastCol < 1) return map;

  const headers = hojaConfig.getRange(1, 1, 1, lastCol).getValues()[0];

  headers.forEach((h, idx) => {
    const raw = String(h || "").trim().toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "");
    if (!raw) return;

    if (raw.includes("referencia") || (raw.includes("destino") && raw.includes("nombre") && !raw.includes("pagina") && !raw.includes("pestana"))) {
      map.NOMBRE_DESTINO = idx;
    } else if (raw === "tipo") {
      map.TIPO = idx;
    } else if (raw.includes("id") && raw.includes("origen")) {
      map.ID_ORIGEN = idx;
    } else if (raw.includes("origen")) {
      map.ORIGEN_NOMBRE = idx;
    } else if (raw.includes("frecuencia")) {
      map.FRECUENCIA = idx;
    } else if (raw.includes("horario") && (raw.includes("actualiz") || raw.includes("bq"))) {
      map.HORARIO_BQ = idx;
    } else if (raw.includes("actualiz")) {
      map.ULTIMA_ACT_BQ = idx;
    } else if (raw.includes("id") && raw.includes("destino")) {
      map.ID_DESTINO = idx;
    } else if (raw.includes("destino") && (raw.includes("nombre") || raw.includes("pagina") || raw.includes("pestana"))) {
      map.DESTINO_NOMBRE = idx;
    } else if (raw.includes("horario") && raw.includes("envio")) {
      map.HORARIO_ENVIO = idx;
    } else if (raw.includes("envio")) {
      map.ULTIMO_ENVIO = idx;
    }
  });

  return map;
}

function leerFilas(hojaConfig, colMap) {
  const lastRow = hojaConfig.getLastRow();
  if (lastRow < 2) return [];
  const anchoDisponible = hojaConfig.getLastColumn();
  const datos = hojaConfig.getRange(2, 1, lastRow - 1, anchoDisponible).getValues();
  return datos
    .map((fila, i) => ({ fila, numFila: i + 2 }))
    .filter(({ fila }) => !esFilaVacia(fila, colMap));
}

function esFilaVacia(fila, colMap) {
  if (!fila || !fila.length) return true;

  const todasVacias = fila.every(c => c === "" || c === null || c === undefined || String(c).trim() === "");
  if (todasVacias) return true;

  const col = colMap || COL;
  const colNombre = (col.NOMBRE_DESTINO >= 0) ? col.NOMBRE_DESTINO : 0;
  const colOrigen = (col.ORIGEN_NOMBRE >= 0) ? col.ORIGEN_NOMBRE : 3;
  const colDestino = (col.ID_DESTINO >= 0) ? col.ID_DESTINO : 7;

  const nombreDestino = String(fila[colNombre] || "").trim();
  const origen = String(fila[colOrigen] || "").trim();
  const destinoId = String(fila[colDestino] || "").trim();

  if (!nombreDestino && !origen && !destinoId) {
    return true;
  }

  return false;
}

function esIdSpreadsheetValido(str) {
  if (!str) return false;
  const clean = extraerIdSpreadsheet(String(str).trim());
  return /^[a-zA-Z0-9_-]{25,}$/.test(clean);
}

function obtenerSpreadsheetOrigen(idOrigen, ssActual) {
  const idStr = String(idOrigen || "").trim();
  const lowerStr = idStr.toLowerCase();

  // Si está vacío, es "-", dice "este sheets", o cualquier cosa que no sea un ID externo válido
  if (!idStr || idStr === "-" || lowerStr.includes("este") || lowerStr.includes("local") || !esIdSpreadsheetValido(idStr)) {
    return ssActual;
  }

  try {
    const id = extraerIdSpreadsheet(idStr);
    return SpreadsheetApp.openById(id);
  } catch (e) {
    console.warn(`No se pudo abrir spreadsheet externo con ID "${idStr}": ${e.message}. Se asume este sheets.`);
    return ssActual;
  }
}

function frecuenciaCorresponde(frecuenciaStr, hoy) {
  const raw = String(frecuenciaStr || "")
    .trim().toLowerCase()
    .normalize("NFD").replace(/[̀-ͯ]/g, "");

  // 1. Si no tiene frecuencia (vacío o guión), no se ejecuta nada (desactivado)
  if (!raw || /^[-–—]+$/.test(raw) || raw === "none" || raw === "no") {
    return { ok: false, desactivado: true, etiqueta: "sin frecuencia (desactivado)" };
  }

  // 2. Diario / Daily: corre todos los días
  if (
    raw === "diario" ||
    raw === "diaria" ||
    raw === "todos los dias" ||
    raw === "daily" ||
    raw === "every day" ||
    raw === "everyday" ||
    raw === "all days"
  ) {
    return { ok: true, etiqueta: "Diario / Daily" };
  }

  // 3. Día del mes: "dia 1", "día 15", "day 1", "day 15", "d1", "1", "15"
  const mDia = raw.match(/(?:dia|day|d)\s*(\d{1,2})/) || raw.match(/^(\d{1,2})$/);
  if (mDia) {
    const n = parseInt(mDia[1], 10);
    const correspondeHoy = (hoy.getDate() === n);
    return {
      ok: correspondeHoy,
      etiqueta: correspondeHoy ? `Día ${n}` : `espera al día ${n} (hoy es ${hoy.getDate()})`
    };
  }

  // 4. Días de la semana en español e inglés
  const DIAS = {
    domingo: 0, sunday: 0, sun: 0,
    lunes: 1, monday: 1, mon: 1,
    martes: 2, tuesday: 2, tue: 2,
    miercoles: 3, wednesday: 3, wed: 3,
    jueves: 4, thursday: 4, thu: 4,
    viernes: 5, friday: 5, fri: 5,
    sabado: 6, saturday: 6, sat: 6
  };

  for (const nombre in DIAS) {
    let coincide = false;
    if (nombre.length <= 3) {
      const reg = new RegExp(`(^|\\s|[._-])${nombre}($|\\s|[._-])`);
      coincide = reg.test(raw);
    } else {
      coincide = (raw.indexOf(nombre) !== -1);
    }

    if (coincide) {
      const diaObjetivo = DIAS[nombre];
      const correspondeHoy = (hoy.getDay() === diaObjetivo);
      return {
        ok: correspondeHoy,
        etiqueta: correspondeHoy ? nombre : `solo los ${nombre}`
      };
    }
  }

  return { ok: false, etiqueta: `frecuencia no reconocida ("${frecuenciaStr}")` };
}

function horarioAMinutos(horarioStr) {
  const match = String(horarioStr).match(/(\d+):(\d+)/);
  if (!match) return null;
  return parseInt(match[1]) * 60 + parseInt(match[2]);
}

function pasaHorario(horarioStr, ahora) {
  const minProg = horarioAMinutos(horarioStr);
  if (minProg === null) return false;
  const minAhora = ahora.getHours() * 60 + ahora.getMinutes();
  return minAhora >= minProg;
}

function dentroDeVentanaGlobal(ahora) {
  const ini = horarioAMinutos(CONFIG.VENTANA_GLOBAL.HORA_INICIO);
  const fin = horarioAMinutos(CONFIG.VENTANA_GLOBAL.HORA_FIN);
  if (ini === null || fin === null) return true;
  const minAhora = ahora.getHours() * 60 + ahora.getMinutes();
  return minAhora >= ini && minAhora <= fin;
}

function textoVentanaGlobal() {
  return `${CONFIG.VENTANA_GLOBAL.HORA_INICIO}–${CONFIG.VENTANA_GLOBAL.HORA_FIN}`;
}

function yaFueHoy(valorFecha, hoy) {
  if (!valorFecha) return false;

  const str = String(valorFecha).toLowerCase();
  if (str.includes("error") || str.includes("❌")) return false;

  if (valorFecha instanceof Date) {
    const diaCelda = Utilities.formatDate(valorFecha, CONFIG.ZONA_HORARIA, "yyyy-MM-dd");
    const diaHoy = Utilities.formatDate(hoy, CONFIG.ZONA_HORARIA, "yyyy-MM-dd");
    return diaCelda === diaHoy;
  }

  const fechaStr = String(valorFecha);
  const hoyStr = Utilities.formatDate(hoy, CONFIG.ZONA_HORARIA, "dd MMMM");
  return fechaStr.includes(hoyStr);
}

function extraerIdSpreadsheet(input) {
  return input.includes("/d/") ? input.split("/d/")[1].split("/")[0] : input;
}

function quitarFiltro(sheet) {
  try {
    const filtro = sheet.getFilter();
    if (filtro) filtro.remove();
    sheet.showRows(1, sheet.getMaxRows());
    sheet.showColumns(1, sheet.getMaxColumns());
  } catch (e) {
    console.warn(`[FILTRO] No se pudo quitar filtro en "${sheet.getName()}": ${e.message}`);
  }
}

function refrescarHojaConReintentos(hoja) {
  const MAX_INTENTOS = Math.max(1, CONFIG.REINTENTOS || 1);
  const ESPERA_SEG   = CONFIG.ESPERA_BQ_SEG || 300;
  let ultimoError;

  for (let intento = 1; intento <= MAX_INTENTOS; intento++) {
    try {
      if (hoja.getType() === SpreadsheetApp.SheetType.DATASOURCE) {
        const ds = hoja.asDataSourceSheet();
        try {
          ds.refreshData();
        } catch (errRefresh) {
          if (String(errRefresh.message || "").toLowerCase().includes("error state")) {
            ds.forceRefreshData();
          } else {
            throw errRefresh;
          }
        }
        const status = ds.waitForCompletion(ESPERA_SEG);
        if (status) {
          const state = status.getExecutionState();
          if (state === SpreadsheetApp.DataExecutionState.ERROR) {
            const msg = status.getErrorMessage() || `Código error: ${status.getErrorCode()}`;
            throw new Error(`BigQuery falló: ${msg}`);
          } else if (state === SpreadsheetApp.DataExecutionState.RUNNING) {
            throw new Error(`BigQuery timeout: la consulta sigue ejecutándose tras ${ESPERA_SEG}s`);
          }
        }
      } else {
        const tablas = hoja.getDataSourceTables();
        for (const t of tablas) {
          try {
            t.refreshData();
          } catch (errRefresh) {
            if (String(errRefresh.message || "").toLowerCase().includes("error state")) {
              t.forceRefreshData();
            } else {
              throw errRefresh;
            }
          }
          const status = t.waitForCompletion(ESPERA_SEG);
          if (status) {
            const state = status.getExecutionState();
            if (state === SpreadsheetApp.DataExecutionState.ERROR) {
              const msg = status.getErrorMessage() || `Código error: ${status.getErrorCode()}`;
              throw new Error(`BigQuery falló: ${msg}`);
            } else if (state === SpreadsheetApp.DataExecutionState.RUNNING) {
              throw new Error(`BigQuery timeout: la tabla sigue ejecutándose tras ${ESPERA_SEG}s`);
            }
          }
        }
      }
      return;
    } catch (e) {
      ultimoError = e;
      console.warn(`[BQ] Refresh falló (intento ${intento}/${MAX_INTENTOS}): ${e.message}`);
      if (/timed out|timeout/i.test(e.message)) break;
      if (intento < MAX_INTENTOS) Utilities.sleep(CONFIG.ESPERA_REINTENTO_MS || 3000);
    }
  }

  const detalleBQ = obtenerDetalleErrorBQ(hoja);
  if (detalleBQ && ultimoError && !String(ultimoError.message).includes(detalleBQ)) {
    throw new Error(`${ultimoError.message} (${detalleBQ})`);
  }

  throw ultimoError;
}

function obtenerDetalleErrorBQ(hoja) {
  try {
    if (!hoja) return null;
    if (hoja.getType() === SpreadsheetApp.SheetType.DATASOURCE) {
      const status = hoja.asDataSourceSheet().getStatus();
      if (status && status.getExecutionState() === SpreadsheetApp.DataExecutionState.ERROR) {
        return status.getErrorMessage() || `Código: ${status.getErrorCode()}`;
      }
    }
    const tablas = hoja.getDataSourceTables();
    for (const t of tablas) {
      const status = t.getStatus();
      if (status && status.getExecutionState() === SpreadsheetApp.DataExecutionState.ERROR) {
        return status.getErrorMessage() || `Código: ${status.getErrorCode()}`;
      }
    }
  } catch (err) {
    console.warn("No se pudo obtener detalle de estado BQ: " + err.message);
  }
  return null;
}

function obtenerTimestampBQ(hoja) {
  try {
    if (hoja.getType() === SpreadsheetApp.SheetType.DATASOURCE) {
      return hoja.asDataSourceSheet().getStatus().getLastExecutionTime();
    }
    const tablas = hoja.getDataSourceTables();
    return tablas.length > 0 ? tablas[0].getStatus().getLastExecutionTime() : null;
  } catch (e) {
    return null;
  }
}

function formatHoraActual(fecha) {
  return Utilities.formatDate(fecha, CONFIG.ZONA_HORARIA, "HH:mm");
}

function esAccionReal(res) {
  if (!res) return false;
  const r = String(res).toLowerCase();
  return r.includes("✅") || r.includes("❌");
}

function acumularLog(buffer, destino, resActualizacion, resEnvio) {
  console.log(`[${destino}] Actualización: ${resActualizacion} | Envío: ${resEnvio}`);
  buffer.push([new Date(), destino, resActualizacion, resEnvio]);
}

function escribirLogsBatch(bufferLog) {
  if (!bufferLog || !bufferLog.length) return;

  const tieneAccionReal = bufferLog.some(row => esAccionReal(row[2]) || esAccionReal(row[3]));
  if (!tieneAccionReal) {
    console.log("[LOGS] Corrida silenciosa (sin acciones reales ni errores). Se omite escritura en Sheets.");
    return;
  }

  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let sh = ss.getSheetByName(CONFIG.NOMBRE_HOJA_LOGS);
  if (!sh) {
    sh = ss.insertSheet(CONFIG.NOMBRE_HOJA_LOGS);
    sh.appendRow(["Fecha", "Destino", "Actualización", "Envío"]);
  }

  sh.getRange(sh.getLastRow() + 1, 1, bufferLog.length, 4).setValues(bufferLog);

  if (sh.getLastRow() > 2000) sh.deleteRows(2, 500);

  try { SpreadsheetApp.flush(); } catch (e) {}
}

function logDecision(destino, resActualizacion, resEnvio) {
  console.log(`[${destino}] Actualización: ${resActualizacion} | Envío: ${resEnvio}`);

  if (!esAccionReal(resActualizacion) && !esAccionReal(resEnvio)) {
    return;
  }

  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let sh = ss.getSheetByName(CONFIG.NOMBRE_HOJA_LOGS);
  if (!sh) {
    sh = ss.insertSheet(CONFIG.NOMBRE_HOJA_LOGS);
    sh.appendRow(["Fecha", "Destino", "Actualización", "Envío"]);
  }

  sh.appendRow([new Date(), destino, resActualizacion, resEnvio]);

  if (sh.getLastRow() > 2000) sh.deleteRows(2, 500);

  try { SpreadsheetApp.flush(); } catch (e) {}
}

function log(accion, pagina, detalle, errorObj) {
  if (accion.toLowerCase().includes("error")) {
    console.error(`[${accion}] ${pagina} | ${detalle}`);

    const fechaHora = Utilities.formatDate(new Date(), CONFIG.ZONA_HORARIA, "EEEE dd/MM/yyyy · HH:mm:ss");
    const info = describirSpreadsheetAfectado(detalle);
    const causa = diagnosticarError(detalle);
    const stack = (errorObj && errorObj.stack) ? String(errorObj.stack) : "";

    const filaDoc = info ? `
              <tr>
                <td style="padding: 12px 8px; border-bottom: 1px solid #eee; font-weight: bold; color: #555;">Documento afectado:</td>
                <td style="padding: 12px 8px; border-bottom: 1px solid #eee;">
                  <strong>${info.nombreArchivo}</strong><br>
                  <a href="${info.link}" style="color: #2980b9; font-size: 13px;">🔗 Abrir el Sheets</a>
                </td>
              </tr>` : "";

    const filaDestino = (info && (info.referencia || info.pestana)) ? `
              <tr>
                <td style="padding: 12px 8px; border-bottom: 1px solid #eee; font-weight: bold; color: #555;">Destino configurado:</td>
                <td style="padding: 12px 8px; border-bottom: 1px solid #eee;">
                  ${info.referencia ? `<strong>${info.referencia}</strong>` : ""}
                  ${info.pestana ? `<br><span style="font-size: 13px; color: #666;">Pestaña afectada: ${info.pestana}</span>` : ""}
                </td>
              </tr>` : "";

    const linkRegistros = obtenerLinkRegistros();
    const filaRegistros = linkRegistros ? `
              <tr>
                <td style="padding: 12px 8px; border-bottom: 1px solid #eee; font-weight: bold; color: #555;">Ver historial:</td>
                <td style="padding: 12px 8px; border-bottom: 1px solid #eee;">
                  <a href="${linkRegistros}" style="color: #2980b9; font-size: 13px;">🔗 Abrir hoja de Registros</a>
                </td>
              </tr>` : "";

    const bloqueStack = stack ? `
            <details style="margin-top: 15px;">
              <summary style="cursor: pointer; font-size: 13px; color: #888;">Ver detalle técnico completo (stack)</summary>
              <pre style="background:#f7f7f7; border:1px solid #eee; border-radius:4px; padding:10px; font-size:11px; color:#666; white-space:pre-wrap; overflow-x:auto;">${stack}</pre>
            </details>` : "";

    const htmlCuerpo = `
      <div style="font-family: Arial, sans-serif; background-color: #f4f4f4; padding: 20px; color: #333;">
        <div style="max-width: 600px; margin: 0 auto; background-color: #fff; border-radius: 8px; overflow: hidden; border: 1px solid #ddd; box-shadow: 0 4px 6px rgba(0,0,0,0.05);">
          <div style="background-color: #e74c3c; color: white; padding: 15px 20px; text-align: center;">
            <h2 style="margin: 0; font-size: 22px;">🚨 Falla en Script de Reportes</h2>
          </div>
          <div style="padding: 25px;">
            <p style="font-size: 16px; line-height: 1.5; margin-top: 0;">Hola,</p>
            <p style="font-size: 16px; line-height: 1.5;">El sistema automático detectó un problema durante su ejecución. Detalles:</p>
            <table style="width: 100%; border-collapse: collapse; margin: 20px 0; font-size: 15px;">
              <tr>
                <td style="padding: 12px 8px; border-bottom: 1px solid #eee; font-weight: bold; color: #555; width: 150px;">Tipo de Error:</td>
                <td style="padding: 12px 8px; border-bottom: 1px solid #eee;">${accion}</td>
              </tr>
              <tr>
                <td style="padding: 12px 8px; border-bottom: 1px solid #eee; font-weight: bold; color: #555;">Cuándo:</td>
                <td style="padding: 12px 8px; border-bottom: 1px solid #eee;">${fechaHora}</td>
              </tr>
              <tr>
                <td style="padding: 12px 8px; border-bottom: 1px solid #eee; font-weight: bold; color: #555;">Contexto:</td>
                <td style="padding: 12px 8px; border-bottom: 1px solid #eee;"><strong>${pagina}</strong></td>
              </tr>
              ${filaDoc}
              ${filaDestino}
              <tr>
                <td style="padding: 12px 8px; border-bottom: 1px solid #eee; font-weight: bold; color: #555;">Posible causa:</td>
                <td style="padding: 12px 8px; border-bottom: 1px solid #eee; color: #b9770e;">${causa}</td>
              </tr>
              <tr>
                <td style="padding: 12px 8px; border-bottom: 1px solid #eee; font-weight: bold; color: #555;">Detalle Técnico:</td>
                <td style="padding: 12px 8px; border-bottom: 1px solid #eee; color: #c0392b;">${detalle}</td>
              </tr>
              ${filaRegistros}
            </table>
            ${bloqueStack}
            <p style="font-size: 14px; color: #666; background-color: #fff3cd; padding: 12px; border-left: 4px solid #ffecb5; border-radius: 4px; margin-top: 15px;">
              ⏱️ <strong>Nota:</strong> El script intentará ejecutarse nuevamente en el próximo ciclo.
            </p>
          </div>
          <div style="background-color: #f9f9f9; padding: 15px; text-align: center; border-top: 1px solid #eee;">
            <p style="margin: 0; font-size: 12px; color: #999;">Este es un mensaje automático. No es necesario responder.</p>
          </div>
        </div>
      </div>
    `;

    const asuntoRef = obtenerTituloSheets();

    try {
      MailApp.sendEmail({
        to: CONFIG.EMAIL_ALERTA_JEFE,
        subject: `🚨 ALERTA: Falló el Script (${asuntoRef})`,
        htmlBody: htmlCuerpo
      });
    } catch (errorMail) {
      console.error("No se pudo enviar el mail de alerta: " + errorMail.message);
    }
  }

  logDecision("⚙ Sistema", `${accion}: ${detalle}`, "—");
}

function describirSpreadsheetAfectado(detalle) {
  const match = String(detalle).match(/([a-zA-Z0-9_-]{25,})/);
  if (!match) return null;

  const id = match[1];
  const link = `https://docs.google.com/spreadsheets/d/${id}/edit`;

  let nombreArchivo = "(no se pudo abrir — revisá permisos o si el archivo existe)";
  try {
    nombreArchivo = SpreadsheetApp.openById(id).getName();
  } catch (e) {}

  let referencia = "", pestana = "";
  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const hojaConfig = ss.getSheetByName(CONFIG.NOMBRE_HOJA_CONFIG);
    if (hojaConfig) {
      const colMap = obtenerMapeoColumnas(hojaConfig);
      const filas = leerFilas(hojaConfig, colMap);
      for (const { fila } of filas) {
        const esDestino = (colMap.ID_DESTINO >= 0) && String(fila[colMap.ID_DESTINO] || "").includes(id);
        const esOrigen = (colMap.ID_ORIGEN >= 0) && String(fila[colMap.ID_ORIGEN] || "").includes(id);
        if (esDestino) {
          referencia = (colMap.NOMBRE_DESTINO >= 0) ? String(fila[colMap.NOMBRE_DESTINO] || "").trim() : "";
          pestana = (colMap.DESTINO_NOMBRE >= 0) ? String(fila[colMap.DESTINO_NOMBRE] || "").trim() + " (destino)" : "";
          break;
        } else if (esOrigen) {
          referencia = (colMap.NOMBRE_DESTINO >= 0) ? String(fila[colMap.NOMBRE_DESTINO] || "").trim() : "";
          pestana = (colMap.ORIGEN_NOMBRE >= 0) ? String(fila[colMap.ORIGEN_NOMBRE] || "").trim() + " (origen)" : "";
          break;
        }
      }
    }
  } catch (e) {}

  return { id, link, nombreArchivo, referencia, pestana };
}

/**
 * Clasifica y diagnostica un mensaje de error para extraer un resumen corto
 * adecuado para celdas y un diagnóstico explicativo para notas y alertas.
 *
 * @param {string} mensaje Detalle o mensaje de error.
 * @param {string} [prefijo="Error"] Prefijo de la operación ("Error BQ", "Error Import", "Error Envío").
 * @returns {{ resumen: string, diagnostico: string }}
 */
function clasificarError(mensaje, prefijo = "Error") {
  const m = String(mensaje || "").trim();
  const lower = m.toLowerCase();

  // 1. Timeout / Tiempo de espera agotado
  if (lower.includes("timeout") || lower.includes("timed out") || lower.includes("deadline exceeded") || lower.includes("sigue ejecutándose tras")) {
    return {
      resumen: "Timeout (>300s)",
      diagnostico: "La consulta tardó más del tiempo máximo permitido (5 minutos). Puede ser por alto volumen de datos o saturación momentánea de BigQuery."
    };
  }

  // 2. Permisos / Acceso denegado
  if (lower.includes("permission") || lower.includes("access denied") || lower.includes("you do not have permission") || lower.includes("no tienes permiso") || lower.includes("unauthorized") || lower.includes("403")) {
    const esBQ = (prefijo && prefijo.includes("BQ")) || lower.includes("bigquery");
    return {
      resumen: esBQ ? "Sin permisos en BigQuery" : "Sin permisos en destino",
      diagnostico: esBQ
        ? "La cuenta que ejecuta el script no tiene permisos suficientes en el proyecto, dataset o tabla de BigQuery."
        : "La cuenta que ejecuta el script no tiene permiso de edición sobre el archivo o carpeta destino."
    };
  }

  // 3. Consulta SQL: Columna no reconocida (Unrecognized name)
  const matchCol = m.match(/Unrecognized name:\s*([^\s;,\)]+)/i);
  if (matchCol) {
    return {
      resumen: `Columna no existe (${matchCol[1]})`,
      diagnostico: `La consulta SQL hace referencia a una columna que no existe en BigQuery: "${matchCol[1]}".`
    };
  }

  // 4. Consulta SQL: Tabla o dataset no encontrado
  const matchTabla = m.match(/(?:Table|Dataset)\s*[`'"]?([a-zA-Z0-9_\-.:]+)[`'"]?\s*was not found/i) ||
                     m.match(/Not found:\s*(?:Table|Dataset)?\s*[`'"]?([a-zA-Z0-9_\-.:]+)/i);
  if (matchTabla) {
    const nombreCorto = matchTabla[1].split('.').pop();
    return {
      resumen: `Tabla no encontrada (${nombreCorto})`,
      diagnostico: `No se encontró la tabla o dataset "${matchTabla[1]}" en BigQuery.`
    };
  }

  // 5. Error de sintaxis SQL
  if (lower.includes("syntax error") || lower.includes("query error") || lower.includes("sintaxis")) {
    return {
      resumen: "Error sintaxis SQL",
      diagnostico: "La consulta SQL en la hoja conectada a BigQuery tiene un error de sintaxis o formato."
    };
  }

  // 6. Límites de recursos o memoria en BigQuery
  if (lower.includes("resources exceeded") || lower.includes("resource limits") || lower.includes("exceeded memory")) {
    return {
      resumen: "Límite recursos BQ",
      diagnostico: "La consulta superó el límite de memoria asignado por BigQuery para consultas en Connected Sheets."
    };
  }

  // 7. Respuesta demasiado grande (Response too large)
  if (lower.includes("response too large") || lower.includes("exceeded maximum size")) {
    return {
      resumen: "Límite tamaño excedido",
      diagnostico: "La cantidad de datos devuelta por BigQuery supera el tamaño máximo permitido por Google Sheets."
    };
  }

  // 8. Estado de error previo en la hoja conectada
  if (lower.includes("currently in an error state") || lower.includes("error state")) {
    return {
      resumen: "Hoja en error previo",
      diagnostico: "La hoja conectada a BigQuery está en estado de error previo. Requiere forzar refresco o revisar la consulta en Sheets."
    };
  }

  // 9. Origen BQ con error detectado en envío
  if (lower.includes("origen") && (lower.includes("error") || lower.includes("falló"))) {
    return {
      resumen: "Origen BQ falló",
      diagnostico: "No se realizó el envío porque la pestaña origen tiene un error de BigQuery o falló al actualizar."
    };
  }

  // 10. Pestaña no encontrada
  const matchPestana = m.match(/no existe la pestaña [^"]*"([^"]+)"/i);
  if (matchPestana) {
    return {
      resumen: `Pestaña "${matchPestana[1]}" no existe`,
      diagnostico: `No se encontró la pestaña "${matchPestana[1]}". Verificá el nombre exacto de la pestaña.`
    };
  }
  if (lower.includes("no existe la pestaña") || lower.includes("sheet not found")) {
    return {
      resumen: "Pestaña no encontrada",
      diagnostico: "El nombre de la pestaña configurado no existe en el archivo correspondiente."
    };
  }

  // 11. ID de Spreadsheet inválido o archivo no encontrado
  if (lower.includes("illegal spreadsheet id") || lower.includes("illegal document id") || lower.includes("no item with the given id") || lower.includes("document is missing")) {
    return {
      resumen: "ID Sheets inválido",
      diagnostico: "El ID del archivo de Google Sheets no es válido o el documento fue eliminado/movido."
    };
  }

  // 12. Cuota o rate limit de Apps Script
  if (lower.includes("service invoked too many times") || lower.includes("quota") || lower.includes("rate limit") || lower.includes("user-rate limit")) {
    return {
      resumen: "Cuota Google excedida",
      diagnostico: "Se superó la cuota de llamadas o tiempo de Google Apps Script. Se reintentará en el próximo ciclo."
    };
  }

  // 13. Fallo transitorio de Google Drive / Storage
  if (lower.includes("failed while accessing document") || lower.includes("reading from storage") || lower.includes("service spreadsheets failed") || lower.includes("internal error")) {
    return {
      resumen: "Fallo temporal Google",
      diagnostico: "Problema temporal de infraestructura de Google al acceder al archivo. Se reintentará automáticamente."
    };
  }

  // 14. Pestaña vacía
  if (lower.includes("vacía") || lower.includes("sin datos") || lower.includes("empty")) {
    return {
      resumen: "Pestaña origen vacía",
      diagnostico: "La pestaña de origen no contiene datos para copiar al destino."
    };
  }

  // 15. Fallback general: limpiar el mensaje técnico para que sea conciso y legible en la celda
  let limpio = m
    .replace(/^Exception:\s*/i, "")
    .replace(/^Error:\s*/i, "")
    .replace(/\[BQ\]\s*/i, "")
    .trim();

  if (limpio.length > 35) {
    limpio = limpio.substring(0, 32) + "...";
  }

  return {
    resumen: limpio || "Falla desconocida",
    diagnostico: m || "No se obtuvo detalle adicional del error."
  };
}

function diagnosticarError(detalle) {
  const clasif = clasificarError(detalle);
  return `${clasif.resumen}: ${clasif.diagnostico}`;
}

function obtenerLinkRegistros() {
  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const sh = ss.getSheetByName(CONFIG.NOMBRE_HOJA_LOGS);
    if (sh) return `${ss.getUrl()}#gid=${sh.getSheetId()}`;
    return ss.getUrl();
  } catch (e) {
    return null;
  }
}

function obtenerTituloSheets() {
  try {
    return SpreadsheetApp.getActiveSpreadsheet().getName();
  } catch (e) {
    return "Sistema";
  }
}

function forzarSincronizacion() { procesarTodo(true, "bq"); }
function forzarEnvios() { procesarTodo(true, "envio"); }

/**
 * ============================================================
 * PREPARACIÓN Y VERIFICACIÓN AUTOMÁTICA DE HOJAS
 * ============================================================
 * Verifica que existan las hojas "Envíos" y "Registros".
 * Si no existen, las crea automáticamente con su estructura oficial
 * de columnas, encabezados en negrita y primera fila congelada.
 * Si ya existen pero están vacías, inserta los encabezados correspondientes.
 *
 * @param {boolean} [forzarEncabezados=false] Si es true, sobrescribe los encabezados de la fila 1.
 */
function verificarOCrearHojas(forzarEncabezados = false) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  if (!ss) return;

  const headersConfig = [
    "Nombre de referencia / destino", // A
    "Tipo",                           // B
    "id - Página de origen",          // C
    "Nombre - Página origen",         // D
    "Frecuencia",                     // E
    "Horario Actualización",          // F
    "Última actualización",           // G
    "id - Página destino",            // H
    "Nombre - Página destino",        // I
    "Horario Envío",                  // J
    "Último envío"                    // K
  ];

  const headersLogs = ["Fecha", "Destino", "Actualización", "Envío"];

  // 1. Hoja de Configuración ("Envíos")
  let shConfig = ss.getSheetByName(CONFIG.NOMBRE_HOJA_CONFIG);
  if (!shConfig) {
    shConfig = ss.insertSheet(CONFIG.NOMBRE_HOJA_CONFIG);
  }

  const configVacia = (shConfig.getLastRow() === 0 || String(shConfig.getRange(1, 1).getValue()).trim() === "");
  if (configVacia || forzarEncabezados) {
    shConfig.getRange(1, 1, 1, headersConfig.length).setValues([headersConfig]).setFontWeight("bold");
    shConfig.setFrozenRows(1);
  } else if (shConfig.getFrozenRows() < 1) {
    shConfig.setFrozenRows(1);
  }

  // 2. Hoja de Registros ("Registros")
  let shLogs = ss.getSheetByName(CONFIG.NOMBRE_HOJA_LOGS);
  if (!shLogs) {
    shLogs = ss.insertSheet(CONFIG.NOMBRE_HOJA_LOGS);
  }

  const logsVacia = (shLogs.getLastRow() === 0 || String(shLogs.getRange(1, 1).getValue()).trim() === "");
  if (logsVacia || forzarEncabezados) {
    shLogs.getRange(1, 1, 1, headersLogs.length).setValues([headersLogs]).setFontWeight("bold");
    shLogs.setFrozenRows(1);
  } else if (shLogs.getFrozenRows() < 1) {
    shLogs.setFrozenRows(1);
  }
}

function prepararHojaMaestro() {
  verificarOCrearHojas(true);

  try {
    const ui = SpreadsheetApp.getUi();
    ui.alert(
      "✅ Hoja preparada",
      "Se crearon/actualizaron los encabezados A–K y la hoja de Registros.\n\n" +
      "Estructura oficial de columnas:\n" +
      "• Col A: Nombre de referencia / destino\n" +
      "• Col B: Tipo ('Actualizar' para BigQuery, 'Importar' para copia estándar)\n" +
      "• Col C: id - Página de origen ('-' o vacío para este sheets)\n" +
      "• Col D: Nombre - Página origen (pestaña en este sheets)\n" +
      "• Col E: Frecuencia ('Diaria', 'Día 1', 'Lunes', etc.)\n" +
      "• Col F: Horario Actualización (ej: '08:00hs')\n" +
      "• Col G: Última actualización (automático)\n" +
      "• Col H: id - Página destino (ID del Sheets destino)\n" +
      "• Col I: Nombre - Página destino (pestaña destino)\n" +
      "• Col J: Horario Envío (ej: '08:20hs')\n" +
      "• Col K: Último envío (automático)",
      ui.ButtonSet.OK
    );
  } catch (e) {
    console.log("prepararHojaMaestro ejecutado.");
  }
}

function enviarEstado() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const hojaConfig = ss.getSheetByName(CONFIG.NOMBRE_HOJA_CONFIG);
  if (!hojaConfig) return;

  const filas = leerFilas(hojaConfig);
  const hoy = new Date();
  const fechaFormateada = Utilities.formatDate(hoy, CONFIG.ZONA_HORARIA, "dd/MM/yyyy HH:mm");

  let htmlCuerpo = `
    <div style="font-family: Arial, sans-serif; background-color: #f4f7f6; padding: 20px; color: #333;">
      <div style="max-width: 700px; margin: 0 auto; background-color: #fff; border-radius: 8px; overflow: hidden; border: 1px solid #ddd; box-shadow: 0 4px 6px rgba(0,0,0,0.05);">
        <div style="background-color: #2980b9; color: white; padding: 20px; text-align: center;">
          <h2 style="margin: 0; font-size: 22px;">📊 Estado de Sincronización y Envíos</h2>
          <p style="margin: 5px 0 0 0; font-size: 14px; opacity: 0.9;">Generado el ${fechaFormateada}</p>
        </div>
        <div style="padding: 25px;">
          <p style="font-size: 16px; line-height: 1.5; margin-top: 0;">Hola,</p>
          <p style="font-size: 16px; line-height: 1.5;">Estado actual de todas las tareas configuradas:</p>
          <table style="width: 100%; border-collapse: collapse; margin: 25px 0; font-size: 14px;">
            <thead>
              <tr style="background-color: #f8f9fa; text-align: left;">
                <th style="padding: 12px 10px; border-bottom: 2px solid #dee2e6; color: #495057;">Destino</th>
                <th style="padding: 12px 10px; border-bottom: 2px solid #dee2e6; color: #495057;">Última Act. BQ</th>
                <th style="padding: 12px 10px; border-bottom: 2px solid #dee2e6; color: #495057;">Último Envío</th>
              </tr>
            </thead>
            <tbody>
  `;

  filas.forEach(({ fila }) => {
    const nombre = fila[COL.NOMBRE_DESTINO] || "(sin nombre)";
    let ultimaActBQ = fila[COL.ULTIMA_ACT_BQ];
    let ultimoEnvio = fila[COL.ULTIMO_ENVIO];

    if (ultimaActBQ instanceof Date) ultimaActBQ = Utilities.formatDate(ultimaActBQ, CONFIG.ZONA_HORARIA, "dd/MM HH:mm");
    else ultimaActBQ = ultimaActBQ || "—";

    if (ultimoEnvio instanceof Date) ultimoEnvio = Utilities.formatDate(ultimoEnvio, CONFIG.ZONA_HORARIA, "dd/MM HH:mm");
    else ultimoEnvio = ultimoEnvio || "—";

    const esErrorAct = String(ultimaActBQ).toLowerCase().includes("error");
    const esErrorEnv = String(ultimoEnvio).toLowerCase().includes("error");

    const estiloAct = esErrorAct ? "color: #c0392b; font-weight: bold;" : "color: #555;";
    const estiloEnv = esErrorEnv ? "color: #c0392b; font-weight: bold;" : (ultimoEnvio !== "—" ? "color: #27ae60; font-weight: bold;" : "color: #555;");

    htmlCuerpo += `
              <tr>
                <td style="padding: 12px 10px; border-bottom: 1px solid #eee;"><strong>${nombre}</strong></td>
                <td style="padding: 12px 10px; border-bottom: 1px solid #eee; ${estiloAct}">${ultimaActBQ}</td>
                <td style="padding: 12px 10px; border-bottom: 1px solid #eee; ${estiloEnv}">${ultimoEnvio}</td>
              </tr>
    `;
  });

  htmlCuerpo += `
            </tbody>
          </table>
        </div>
        <div style="background-color: #f9f9f9; padding: 15px; text-align: center; border-top: 1px solid #eee;">
          <p style="margin: 0; font-size: 12px; color: #999;">Script Maestro V2.44 • Envíos Automáticos</p>
        </div>
      </div>
    </div>
  `;

  MailApp.sendEmail({
    to     : CONFIG.EMAIL_ALERTA_JEFE,
    subject: `📊 Estado Reportes — ${fechaFormateada}`,
    htmlBody: htmlCuerpo
  });
}
