/**
 * ============================================================
 * SCRIPT MAESTRO — VERSIÓN V42 (UNIFICADO)
 * Gestión de reportes: Refresh BQ (Local o Externo) + Envío a Destinos
 *
 * UNIFICACIÓN DE "ScriptMaestro_V41" Y "ScriptMaestro_IMPORT_V1":
 *   - Combina la potencia del refresco de BigQuery de la V41 con la flexibilidad
 *     de importar de múltiples fuentes de la versión IMPORT_V1.
 *   - Nueva columna "Tipo" en la columna B (puede decir "Importar" o "Actualizar").
 *     • "Importar": Realiza una copia directa de datos estándar (no intenta refrescar BigQuery, evitando errores).
 *     • "Actualizar": Realiza el refresco de la conexión de BigQuery de la pestaña.
 *   - Nueva columna "id - Página origen" en la columna C.
 *   - Nueva columna "Página intermedia" en la columna E.
 *     • Los datos importados se guardan de forma intermedia en esta pestaña local en "Este sheets".
 *     • **PRESERVACIÓN DE COLUMNAS DE EDICIÓN**: Durante la importación, el script solo sobrescribe
 *       las columnas correspondientes a los datos importados (desde la columna A hasta el número de columnas
 *       del origen). Cualquier columna adicional a la derecha se mantiene intacta, lo que te permite
 *       agregar fórmulas o contenido de forma manual sin que se borre.
 *     • En el paso de envío, se copiará todo el contenido (incluyendo tus columnas manuales y cambios)
 *       directamente al destino.
 *
 * Características heredadas de V41:
 *   - LOG THROTTLING (OPTIMIZACIÓN DE CARGA EXTREMA): El script no escribe
 *     en "Registros" si la corrida fue silenciosa/no-op (ahorra cuota de Google).
 *   - OPTIMIZACIÓN CRÍTICA BQ: No consulta BigQuery ni escribe en celda
 *     si la fila ya tiene fecha de hoy escrita en la columna J.
 *   - Ventana horaria GLOBAL en el código (CONFIG.VENTANA_GLOBAL).
 *   - Horario por fila del Sheet (col I = BQ/Import, col K = Envío).
 *   - Frecuencia por fila (col H).
 *   - FORZAR (menú) ignora ventana global, frecuencia y horario.
 *   - Log unificado (una línea por destino) + mail de alerta enriquecido.
 *
 * Estructura de columnas en hoja "Envíos":
 *   A: Nombre del destino (referencia)         ← se usa para nombrar el log
 *   B: Tipo                                     ← "Importar" o "Actualizar"
 *   C: id - Página origen                       ← ID del Spreadsheet origen ("Este sheets" o vacío para local)
 *   D: Nombre - Página origen                  ← pestaña de origen en la planilla origen
 *   E: Página intermedia                        ← pestaña local intermedia (staging) en "Este sheets"
 *   F: id - Página destino                     ← ID del Spreadsheet destino final
 *   G: Nombre - Página destino                 ← pestaña destino final
 *   H: Frecuencia de envío                     ← "Diaria", "Lunes", "Día 1", etc.
 *   I: Horario Actualización - Big Query       ← (ej: "8:00hs")
 *   J: Última actualización - Big Query        ← escrito por script (timestamp)
 *   K: Horario Envío                            ← (ej: "8:00hs")
 *   L: Último envío                             ← escrito por script (timestamp)
 *
 * ============================================================
 */

// --- CONFIGURACIÓN GLOBAL ---
const CONFIG = {
  EMAIL_ALERTA_JEFE : "matias.cagliero@pedidosya.com",
  NOMBRE_HOJA_CONFIG: "Envíos",
  NOMBRE_HOJA_LOGS  : "Registros",
  ZONA_HORARIA      : "GMT-3",
  FORMATO_FECHA     : "EEEE, dd MMMM, hh:mm:ss a",

  // 🔁 Reintentos ante fallos transitorios de Google (ej: "Service Spreadsheets failed...")
  REINTENTOS         : 3,      // intentos TOTALES (1 normal + 2 reintentos)
  ESPERA_REINTENTO_MS: 3000,   // espera entre intentos (milisegundos)
  ESPERA_BQ_SEG      : 300,    // cuánto espera a que BQ termine el refresh (segundos)

  // ⏰ VENTANA HORARIA GLOBAL (modo automático).
  // Fuera de este rango el script no actualiza ni envía nada.
  VENTANA_GLOBAL: {
    HORA_INICIO: "06:00",  // no se hace nada antes de esta hora
    HORA_FIN   : "15:00"   // ni después de esta hora
  }
};

// Índices de columna (base 0 para arrays, base 1 para getRange)
const COL = {
  NOMBRE_DESTINO   : 0,  // A
  TIPO             : 1,  // B
  ID_ORIGEN        : 2,  // C
  ORIGEN_NOMBRE    : 3,  // D
  PAGINA_INTERMEDIA: 4,  // E  ← NUEVO: Página intermedia de staging local en "Este sheets"
  ID_DESTINO       : 5,  // F
  DESTINO_NOMBRE   : 6,  // G
  FRECUENCIA       : 7,  // H
  HORARIO_BQ       : 8,  // I
  ULTIMA_ACT_BQ    : 9,  // J  ← escrito por script (base 0) / col 10 (base 1)
  HORARIO_ENVIO    : 10, // K
  ULTIMO_ENVIO     : 11  // L  ← escrito por script (base 0) / col 12 (base 1)
};

// Cuántas columnas lee el script de la hoja de config (A..L = 12).
const TOTAL_COLS = 12;

// ============================================================
// MENÚ Y PUNTO DE ENTRADA AL ABRIR
// ============================================================

function onOpen() {
  SpreadsheetApp.getUi()
    .createMenu('🚀 Gestión de Reportes')
    .addItem('⚠️ FORZAR Sincronizar Extracto', 'forzarSincronizacion')
    .addItem('⚠️ FORZAR Enviar a destinos',    'forzarEnvios')
    .addSeparator()
    .addItem('🧩 Preparar hoja (Columnas Maestro)', 'prepararHojaMaestro')
    .addItem('📧 Enviar Estado Actual', 'enviarEstado')
    .addToUi();
}

// ============================================================
// TRIGGER PRINCIPAL (cada 1 / 15 min)
// ============================================================

function ejecutarTodo() {
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(0)) return;   // evita solapamiento entre corridas

  try {
    procesarTodo(false, "todo");
  } catch (e) {
    // Los "server error" transitorios de Google son inevitables; los registramos
    // pero NO dejamos que un fallo DENTRO del manejo de error (mail/appendRow)
    // escape como excepción sin capturar (eso dispara la notificación de Google).
    try {
      log("Error Crítico", "Sistema", e.message, e);
    } catch (e2) {
      console.error("No se pudo registrar el error crítico: " + e2.message);
    }
  } finally {
    try { lock.releaseLock(); } catch (e3) { /* el lock ya expiró: no importa */ }
  }
}

// ============================================================
// NÚCLEO: UNA SOLA PASADA, UNA LÍNEA DE LOG POR DESTINO
//   modo: "todo" | "bq" | "envio"
// ============================================================

function procesarTodo(esForzado, modo) {
  const hoy = new Date();

  // 🛡️ Ventana global (solo en modo automático)
  if (!esForzado && !dentroDeVentanaGlobal(hoy)) {
    logDecision("⚙ Sistema",
      `⏭ FUERA DE VENTANA (${textoVentanaGlobal()}) · ahora ${formatHoraActual(hoy)}`,
      "—");
    return;
  }

  SpreadsheetApp.enableBigQueryExecution();
  const ss         = SpreadsheetApp.getActiveSpreadsheet();
  const hojaConfig = ss.getSheetByName(CONFIG.NOMBRE_HOJA_CONFIG);
  if (!hojaConfig) return;

  const filas        = leerFilas(hojaConfig);
  const yaRefrescado = new Set();   // evita refrescar 2 veces la misma pestaña por corrida
  const bufferLog    = [];          // acumula las líneas de log de TODA la corrida

  filas.forEach(({ fila, numFila }) => {
    const nombreRef  = String(fila[COL.NOMBRE_DESTINO] || "(sin nombre)").trim();
    const frecuencia = String(fila[COL.FRECUENCIA]     || "").trim();

    // 0️⃣ FRECUENCIA (col H) — controla TODA la fila (solo en automático).
    //    Si hoy no corresponde según la frecuencia, no se actualiza ni se envía.
    if (!esForzado) {
      const fc = frecuenciaCorresponde(frecuencia, hoy);
      if (!fc.ok) {
        const txt = `⏸ no corresponde hoy (${fc.etiqueta || frecuencia})`;
        acumularLog(bufferLog, nombreRef,
          (modo === "envio") ? "— (omitido)" : txt,
          (modo === "bq")    ? "— (omitido)" : txt);
        return;
      }
    }

    // 1️⃣ ACTUALIZACIÓN (Big Query / Importación en planilla origen local o externa y guardado en local)
    const resBQ = (modo === "envio")
      ? "— (omitido)"
      : evaluarActualizacion(ss, hojaConfig, fila, numFila, hoy, esForzado, yaRefrescado);

    // 2️⃣ ENVÍO (copia de staging local en este sheets → destino final)
    const resEnvio = (modo === "bq")
      ? "— (omitido)"
      : evaluarEnvio(ss, hojaConfig, fila, numFila, hoy, esForzado);

    // 3️⃣ Acumula una sola línea de log para este destino (se escribe al final)
    acumularLog(bufferLog, nombreRef, resBQ, resEnvio);
  });

  // 4️⃣ UNA sola escritura al log con TODAS las líneas de la corrida.
  //    Evita el error "Too many simultaneous invocations: Spreadsheets" que
  //    provocaba el appendRow fila-por-fila.
  escribirLogsBatch(bufferLog);
}

// ============================================================
// PASO 1: ACTUALIZACIÓN BQ / IMPORTAR (devuelve el texto de resultado)
// ============================================================

function evaluarActualizacion(ss, hojaConfig, fila, numFila, hoy, esForzado, yaRefrescado) {
  const tipo          = String(fila[COL.TIPO]             || "").trim().toLowerCase();
  const idOrigen      = String(fila[COL.ID_ORIGEN]        || "").trim();
  const origen        = String(fila[COL.ORIGEN_NOMBRE]    || "").trim();
  const pagIntermedia = String(fila[COL.PAGINA_INTERMEDIA]|| "").trim() || origen;
  const horarioBQ     = String(fila[COL.HORARIO_BQ]       || "").trim();
  let   ultimaActBQ   = fila[COL.ULTIMA_ACT_BQ];
  const ahoraStr      = formatHoraActual(hoy);

  if (!origen) return "— (sin pestaña origen)";

  // 1. ¿Está desactivado el horario?
  const minProg = horarioAMinutos(horarioBQ);
  if (!esForzado && minProg === null) {
    return "⏸ desactivado (col I sin horario)";
  }

  // 2. ¿Aún no llega el horario programado? (Retorno inmediato sin gastar APIs en toda la mañana)
  const horarioPaso = pasaHorario(horarioBQ, hoy);
  if (!esForzado && !horarioPaso) {
    return `⏳ aún no (prog ${horarioBQ} · ahora ${ahoraStr})`;
  }

  // 3. ¿Ya se actualizó hoy (según el valor escrito en la celda)?
  let yaHoy = yaFueHoy(ultimaActBQ, hoy);
  if (yaHoy && !esForzado) {
    return `⏭ ya fue hoy`;
  }

  try {
    const ssOrig = obtenerSpreadsheetOrigen(idOrigen, ss);
    const hojaOrig = ssOrig.getSheetByName(origen);
    if (!hojaOrig) return `❌ no existe la pestaña "${origen}" en el origen`;

    const esLocal = (ssOrig.getId() === ss.getId());

    // A. Si es externo y el tipo es "Actualizar", refrescamos BigQuery primero en el origen
    if (!esLocal && tipo.includes("actualiz")) {
      const claveRefresco = `${ssOrig.getId()}::${origen}`;
      if (!(esForzado && yaRefrescado.has(claveRefresco))) {
        refrescarHojaConReintentos(hojaOrig);
        yaRefrescado.add(claveRefresco);
      }
    }

    // B. COPIAMOS SIEMPRE A LA PÁGINA INTERMEDIA LOCAL en "Este sheets" (ss)
    if (!esLocal) {
      const hojaDest = ss.getSheetByName(pagIntermedia) || ss.insertSheet(pagIntermedia);
      quitarFiltro(hojaOrig);
      quitarFiltro(hojaDest);
      const valores = hojaOrig.getDataRange().getValues();
      if (valores.length > 0 && valores[0].length > 0) {
        const numCols = valores[0].length;
        const maxRows = hojaDest.getMaxRows();
        // Limpiamos únicamente el rango de las columnas que importamos, conservando las de la derecha (manuales/fórmulas)
        hojaDest.getRange(1, 1, maxRows, numCols).clearContent();
        hojaDest.getRange(1, 1, valores.length, numCols).setValues(valores);
      }
    } else {
      // Si es local y es "Actualizar", corremos el refresco local
      if (tipo.includes("actualiz")) {
        const claveRefresco = `${ss.getId()}::${origen}`;
        if (!(esForzado && yaRefrescado.has(claveRefresco))) {
          refrescarHojaConReintentos(hojaOrig);
          yaRefrescado.add(claveRefresco);
        }
      }
    }

    // C. Registramos el éxito en la planilla
    let tsExito = new Date();
    // Solo si es de tipo "Actualizar" intentamos obtener el timestamp real de BigQuery
    if (tipo.includes("actualiz")) {
      const tsBQ = obtenerTimestampBQ(hojaOrig);
      if (tsBQ) {
        tsExito = tsBQ;
      }
    }
    escribirFechaBQ(hojaConfig, numFila, tsExito);

    return tipo.includes("import") ? "✅ importado" : "✅ actualiza";

  } catch (e) {
    const errorPrefix = tipo.includes("import") ? "Error Import" : "Error BQ";
    hojaConfig.getRange(numFila, COL.ULTIMA_ACT_BQ + 1).setValue(errorPrefix);
    return `❌ ERROR: ${e.message}`;
  }
}

/**
 * Escribe en la col J ("Última actualización - Big Query") la fecha indicada,
 * con el formato configurado.
 */
function escribirFechaBQ(hojaConfig, numFila, fecha) {
  const fechaTxt = Utilities.formatDate(fecha, CONFIG.ZONA_HORARIA, CONFIG.FORMATO_FECHA);
  hojaConfig.getRange(numFila, COL.ULTIMA_ACT_BQ + 1).setValue(fechaTxt);
}

// ============================================================
// PASO 2: ENVÍO A DESTINO (devuelve el texto de resultado)
// ============================================================

function evaluarEnvio(ss, hojaConfig, fila, numFila, hoy, esForzado) {
  const origen        = String(fila[COL.ORIGEN_NOMBRE]    || "").trim();
  const pagIntermedia = String(fila[COL.PAGINA_INTERMEDIA]|| "").trim() || origen;
  const destinoId     = String(fila[COL.ID_DESTINO]       || "").trim();
  const destinoHoja   = String(fila[COL.DESTINO_NOMBRE]   || "").trim();
  const horarioEnvio  = String(fila[COL.HORARIO_ENVIO]    || "").trim();
  const ultimoEnvio   = fila[COL.ULTIMO_ENVIO];
  const ahoraStr      = formatHoraActual(hoy);

  if (!pagIntermedia || !destinoId) return "— (faltan datos)";

  const yaHoy       = yaFueHoy(ultimoEnvio, hoy);
  const horarioPaso = pasaHorario(horarioEnvio, hoy);

  if (!esForzado) {
    if (horarioAMinutos(horarioEnvio) === null) return "⏸ desactivado (col K sin horario)";
    if (yaHoy)        return `⏭ ya fue hoy`;
    if (!horarioPaso) return `⏳ aún no (prog ${horarioEnvio} · ahora ${ahoraStr})`;
  }

  try {
    const id      = extraerIdSpreadsheet(destinoId);
    const ssDest  = SpreadsheetApp.openById(id);
    const shDest  = ssDest.getSheetByName(destinoHoja) || ssDest.insertSheet(destinoHoja);
    
    // El origen de los datos SIEMPRE se toma de la pestaña local intermedia de staging (ss)
    const shOrig  = ss.getSheetByName(pagIntermedia);
    if (!shOrig) return `❌ no existe la pestaña local de staging "${pagIntermedia}" en este sheets`;

    // 🧹 Quita filtros de origen y destino para que la copia no se pegue mal
    //    (filas ocultas / rango de filtro desalineado).
    quitarFiltro(shOrig);
    quitarFiltro(shDest);

    const valores = shOrig.getDataRange().getValues();

    shDest.clearContents();
    shDest.getRange(1, 1, valores.length, valores[0].length).setValues(valores);

    const fechaExito = Utilities.formatDate(new Date(), CONFIG.ZONA_HORARIA, CONFIG.FORMATO_FECHA);
    hojaConfig.getRange(numFila, COL.ULTIMO_ENVIO + 1).setValue(fechaExito);

    return `✅ enviado → ${destinoHoja}`;

  } catch (e) {
    return `❌ ERROR: ${e.message}`;
  }
}

// ============================================================
// FUNCIONES AUXILIARES
// ============================================================

function leerFilas(hojaConfig) {
  const lastRow = hojaConfig.getLastRow();
  if (lastRow < 2) return [];
  const anchoDisponible = hojaConfig.getLastColumn();
  const ancho = Math.min(TOTAL_COLS, anchoDisponible);
  const datos = hojaConfig.getRange(2, 1, lastRow - 1, ancho).getValues();
  return datos.map((fila, i) => ({ fila, numFila: i + 2 }));
}

/**
 * Retorna el Spreadsheet de origen.
 * Si idOrigen es vacío o "este sheets", retorna ssActual.
 */
function obtenerSpreadsheetOrigen(idOrigen, ssActual) {
  const idStr = String(idOrigen || "").trim();
  const lowerStr = idStr.toLowerCase();
  if (!idStr || lowerStr === "este sheets" || lowerStr === "este sheet" || lowerStr === "este spreadsheet") {
    return ssActual;
  }
  const id = extraerIdSpreadsheet(idStr);
  return SpreadsheetApp.openById(id);
}

/**
 * Decide si HOY corresponde ejecutar la fila según su "Frecuencia" (col H).
 * Devuelve { ok: true/false, etiqueta: "..." }.
 */
function frecuenciaCorresponde(frecuenciaStr, hoy) {
  const raw = String(frecuenciaStr || "")
    .trim().toLowerCase()
    .normalize("NFD").replace(/[̀-ͯ]/g, "");   // quita acentos

  // Diario (o vacío)
  if (raw === "" || raw === "diario" || raw === "diaria" || raw === "todos los dias") {
    return { ok: true, etiqueta: "Diario" };
  }

  // Día del mes: "dia 15", "día 1", "d1", o un número suelto ("1", "15")
  const mDia = raw.match(/(?:dia|d)\s*(\d{1,2})/) || raw.match(/^(\d{1,2})$/);
  if (mDia) {
    const n = parseInt(mDia[1], 10);
    return { ok: hoy.getDate() === n, etiqueta: `Día ${n}` };
  }

  // Día de la semana (getDay: 0=domingo … 6=sábado)
  const DIAS = { domingo:0, lunes:1, martes:2, miercoles:3, jueves:4, viernes:5, sabado:6 };
  for (const nombre in DIAS) {
    if (raw.indexOf(nombre) !== -1) {
      return { ok: hoy.getDay() === DIAS[nombre], etiqueta: nombre };
    }
  }

  // No reconocida → no bloquea (se comporta como diario para no romper)
  return { ok: true, etiqueta: frecuenciaStr };
}

/**
 * Convierte un texto de horario ("8:30hs", "08:30") a minutos desde medianoche.
 * Devuelve null si no encuentra un patrón hh:mm válido.
 */
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

/**
 * ¿La hora actual está dentro de la ventana global definida en CONFIG?
 */
function dentroDeVentanaGlobal(ahora) {
  const ini = horarioAMinutos(CONFIG.VENTANA_GLOBAL.HORA_INICIO);
  const fin = horarioAMinutos(CONFIG.VENTANA_GLOBAL.HORA_FIN);
  if (ini === null || fin === null) return true; // config mal cargada → no bloquea
  const minAhora = ahora.getHours() * 60 + ahora.getMinutes();
  return minAhora >= ini && minAhora <= fin;
}

function textoVentanaGlobal() {
  return `${CONFIG.VENTANA_GLOBAL.HORA_INICIO}–${CONFIG.VENTANA_GLOBAL.HORA_FIN}`;
}

function yaFueHoy(valorFecha, hoy) {
  if (!valorFecha) return false;

  // 1. Si Google Sheets lo convirtió en un objeto Fecha (Date) automáticamente
  if (valorFecha instanceof Date) {
    const diaCelda = Utilities.formatDate(valorFecha, CONFIG.ZONA_HORARIA, "yyyy-MM-dd");
    const diaHoy = Utilities.formatDate(hoy, CONFIG.ZONA_HORARIA, "yyyy-MM-dd");
    return diaCelda === diaHoy;
  }

  // 2. Si sigue siendo texto (String)
  const fechaStr = String(valorFecha);
  const hoyStr = Utilities.formatDate(hoy, CONFIG.ZONA_HORARIA, "dd MMMM");
  return fechaStr.includes(hoyStr);
}

function extraerIdSpreadsheet(input) {
  return input.includes("/d/") ? input.split("/d/")[1].split("/")[0] : input;
}

/**
 * Quita el filtro básico de una pestaña (si tiene) y muestra todas las filas/
 * columnas, para que la copia origen→destino no quede desalineada ni con filas
 * ocultas. Es tolerante a errores: si la hoja no soporta filtros, no rompe.
 */
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

/**
 * Refresca el origen de Big Query con REINTENTOS ante fallos transitorios de
 * Google. Si tras todos los intentos sigue fallando, propaga el último error.
 */
function refrescarHojaConReintentos(hoja) {
  const MAX_INTENTOS = Math.max(1, CONFIG.REINTENTOS || 1);
  const ESPERA_SEG   = CONFIG.ESPERA_BQ_SEG || 300;
  let ultimoError;

  for (let intento = 1; intento <= MAX_INTENTOS; intento++) {
    try {
      if (hoja.getType() === SpreadsheetApp.SheetType.DATASOURCE) {
        hoja.asDataSourceSheet().refreshData();
        hoja.asDataSourceSheet().waitForCompletion(ESPERA_SEG);
      } else {
        const tablas = hoja.getDataSourceTables();
        tablas.forEach(t => { t.refreshData(); t.waitForCompletion(ESPERA_SEG); });
      }
      return;   // ✅ salió bien
    } catch (e) {
      ultimoError = e;
      console.warn(`[BQ] Refresh falló (intento ${intento}/${MAX_INTENTOS}): ${e.message}`);

      // Un TIMEOUT significa "la consulta es lenta", no un glitch: reintentar la
      // reinicia y gasta minutos sin sentido. Cortamos y la dejamos terminar sola.
      if (/timed out|timeout/i.test(e.message)) break;

      if (intento < MAX_INTENTOS) Utilities.sleep(CONFIG.ESPERA_REINTENTO_MS || 3000);
    }
  }

  throw ultimoError;   // agotó los reintentos (o fue timeout) → lo maneja quien llamó
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

/**
 * Formatea la hora actual para mostrar en logs (ej: "08:47")
 */
function formatHoraActual(fecha) {
  return Utilities.formatDate(fecha, CONFIG.ZONA_HORARIA, "HH:mm");
}

/**
 * Indica si un resultado de log representa una acción real (ejecución o error)
 * o si es simplemente un estado de espera ("aún no", "ya fue", "desactivado", "omitido", etc.).
 */
function esAccionReal(res) {
  if (!res) return false;
  const r = String(res).toLowerCase();
  return r.includes("✅") || r.includes("❌");
}

/**
 * Acumula una línea de log en un buffer en memoria (sin tocar el Spreadsheet).
 * Deja también el rastro en Cloud Logs.
 */
function acumularLog(buffer, destino, resActualizacion, resEnvio) {
  console.log(`[${destino}] Actualización: ${resActualizacion} | Envío: ${resEnvio}`);
  buffer.push([new Date(), destino, resActualizacion, resEnvio]);
}

/**
 * Escribe TODAS las líneas acumuladas en la hoja "Registros" en UNA sola
 * operación (setValues), en vez de un appendRow por fila. Esto reduce al mínimo
 * las llamadas al servicio Spreadsheets y evita el error de invocaciones
 * simultáneas cuando corren varios reportes a la misma hora.
 */
function escribirLogsBatch(bufferLog) {
  if (!bufferLog || !bufferLog.length) return;

  // OPTIMIZACIÓN DE CARGA (LOG THROTTLING): Solo escribimos en Sheets si al menos un destino
  // tuvo una ejecución real o un error. Evitamos miles de escrituras silenciosas de no-op
  // ("ya fue hoy", "aún no") que bloquean el SpreadsheetApp de Google.
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

  // Limpieza para no saturar la hoja
  if (sh.getLastRow() > 2000) sh.deleteRows(2, 500);
}

/**
 * Log unificado — UNA línea por destino.
 * Columnas en hoja "Registros": Fecha | Destino | Actualización | Envío
 */
function logDecision(destino, resActualizacion, resEnvio) {
  // 1. Cloud Logs (historial de Apps Script)
  console.log(`[${destino}] Actualización: ${resActualizacion} | Envío: ${resEnvio}`);

  // Solo escribimos el log general en Sheets si es una acción real o un error, para evitar spam.
  if (!esAccionReal(resActualizacion) && !esAccionReal(resEnvio)) {
    return;
  }

  // 2. Pestaña "Registros" del Spreadsheet
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let sh = ss.getSheetByName(CONFIG.NOMBRE_HOJA_LOGS);
  if (!sh) {
    sh = ss.insertSheet(CONFIG.NOMBRE_HOJA_LOGS);
    sh.appendRow(["Fecha", "Destino", "Actualización", "Envío"]);
  }

  sh.appendRow([new Date(), destino, resActualizacion, resEnvio]);

  // Limpieza para no saturar la hoja
  if (sh.getLastRow() > 2000) sh.deleteRows(2, 500);
}

/**
 * Log de errores CRÍTICOS de toda la corrida — envía alerta por correo (HTML).
 * Los errores por fila NO pasan por acá (se ven en la columna del destino).
 *
 * @param {string} accion   Tipo de error (ej: "Error Crítico").
 * @param {string} pagina   Contexto (ej: "Sistema").
 * @param {string} detalle  Mensaje técnico del error.
 * @param {Error}  [errorObj]  Objeto de error original (para stack trace).
 */
function log(accion, pagina, detalle, errorObj) {
  if (accion.toLowerCase().includes("error")) {
    console.error(`[${accion}] ${pagina} | ${detalle}`);

    // 🔎 Datos enriquecidos para que el mail explique QUÉ pasó y DÓNDE.
    const fechaHora = Utilities.formatDate(new Date(), CONFIG.ZONA_HORARIA, "EEEE dd/MM/yyyy · HH:mm:ss");
    const info      = describirSpreadsheetAfectado(detalle);   // {id, link, nombreArchivo, referencia, pestana} | null
    const causa     = diagnosticarError(detalle);              // texto legible
    const stack     = (errorObj && errorObj.stack) ? String(errorObj.stack) : "";

    // Filas dinámicas: sólo se muestran si hay dato.
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

    // Asunto: el TÍTULO del Spreadsheet donde corre el script (V40).
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

  // Deja también una línea de sistema en la hoja
  logDecision("⚙ Sistema", `${accion}: ${detalle}`, "—");
}

/**
 * Extrae el ID de spreadsheet mencionado en un mensaje de error de Google
 * y devuelve la información relacionada cargada en el config.
 *
 * @return {Object|null} {id, link, nombreArchivo, referencia, pestana}
 */
function describirSpreadsheetAfectado(detalle) {
  const match = String(detalle).match(/([a-zA-Z0-9_-]{25,})/);
  if (!match) return null;

  const id   = match[1];
  const link = `https://docs.google.com/spreadsheets/d/${id}/edit`;

  // 1) Nombre real del archivo (si tenemos acceso).
  let nombreArchivo = "(no se pudo abrir — revisá permisos o si el archivo existe)";
  try {
    nombreArchivo = SpreadsheetApp.openById(id).getName();
  } catch (e) { /* documento inaccesible: dejamos el texto por defecto */ }

  // 2) ¿Ese ID está configurado como destino u origen en la hoja "Envíos"?
  let referencia = "", pestana = "";
  try {
    const ss         = SpreadsheetApp.getActiveSpreadsheet();
    const hojaConfig = ss.getSheetByName(CONFIG.NOMBRE_HOJA_CONFIG);
    if (hojaConfig) {
      const filas = leerFilas(hojaConfig);
      for (const { fila } of filas) {
        const esDestino = String(fila[COL.ID_DESTINO] || "").includes(id);
        const esOrigen  = String(fila[COL.ID_ORIGEN]  || "").includes(id);
        if (esDestino) {
          referencia = String(fila[COL.NOMBRE_DESTINO] || "").trim();
          pestana    = String(fila[COL.DESTINO_NOMBRE] || "").trim() + " (destino)";
          break;
        } else if (esOrigen) {
          referencia = String(fila[COL.NOMBRE_DESTINO] || "").trim();
          pestana    = String(fila[COL.PAGINA_INTERMEDIA] || fila[COL.ORIGEN_NOMBRE] || "").trim() + " (origen)";
          break;
        }
      }
    }
  } catch (e) { /* si la búsqueda falla, no bloqueamos el mail */ }

  return { id, link, nombreArchivo, referencia, pestana };
}

/**
 * Traduce los errores más comunes de Google a una "posible causa" en lenguaje claro.
 */
function diagnosticarError(detalle) {
  const d = String(detalle).toLowerCase();

  if (d.includes("illegal spreadsheet id") || d.includes("illegal document id"))
    return "Un ID de spreadsheet (columna C de origen o columna F de destino) no es válido. " +
           "Probablemente hay un nombre de pestaña o texto donde debería ir el ID del Sheets.";

  if (d.includes("no existe la pestaña"))
    return "El nombre de pestaña no coincide con ninguna hoja del archivo. " +
           "Revisá las columnas D (pestaña origen) o G (pestaña destino).";

  if (d.includes("failed while accessing document"))
    return "Google no pudo acceder momentáneamente al documento. Suele ser un error " +
           "transitorio de infraestructura, pero también puede ser falta de permisos " +
           "o que el archivo haya sido movido/eliminado. Verificá el link de abajo.";

  if (d.includes("timed out") || d.includes("timeout"))
    return "La consulta de Big Query tardó demasiado. No es un error del script; " +
           "la actualización probablemente sigue corriendo y termina sola.";

  if (d.includes("permission") || d.includes("you do not have permission") || d.includes("access denied"))
    return "El script no tiene permiso sobre ese archivo. Revisá que la cuenta que " +
           "corre el script esté compartida con acceso de edición.";

  if (d.includes("not found") || d.includes("no item with the given id"))
    return "El archivo no existe o fue eliminado. Revisá el ID en la columna C o F.";

  if (d.includes("service invoked too many times") || d.includes("quota"))
    return "Se superó una cuota de Google (demasiadas ejecuciones o llamadas). " +
           "Suele resolverse solo esperando al próximo ciclo.";

  return "Error no catalogado. Revisá el detalle técnico y el stack más abajo.";
}

/**
 * Devuelve el link directo a la hoja "Registros" del Spreadsheet activo,
 * o null si no se puede resolver.
 */
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

/**
 * Devuelve el TÍTULO del Spreadsheet donde corre el script (el nombre del archivo).
 */
function obtenerTituloSheets() {
  try {
    return SpreadsheetApp.getActiveSpreadsheet().getName();
  } catch (e) {
    return "Sistema";
  }
}

// ============================================================
// ACCESOS DIRECTOS DESDE EL MENÚ
// ============================================================

function forzarSincronizacion() { procesarTodo(true, "bq");    }
function forzarEnvios()         { procesarTodo(true, "envio"); }

// ============================================================
// PREPARAR HOJA — crea/renombra los encabezados de la V42
// ============================================================

function prepararHojaMaestro() {
  const ui = SpreadsheetApp.getUi();
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sh = ss.getSheetByName(CONFIG.NOMBRE_HOJA_CONFIG);
  if (!sh) {
    ui.alert(`No existe la hoja "${CONFIG.NOMBRE_HOJA_CONFIG}". Creála primero.`);
    return;
  }

  const headers = [
    "Nombre del destino (referencia)",   // A
    "Tipo",                              // B
    "id - Página origen",                // C
    "Nombre - Página origen",            // D
    "Página intermedia",                 // E
    "id - Página destino",               // F
    "Nombre - Página destino",           // G
    "Frecuencia de envío",               // H
    "Horario Actualización - Big Query", // I
    "Última actualización - Big Query",  // J
    "Horario Envío",                     // K
    "Último envío"                       // L
  ];

  sh.getRange(1, 1, 1, headers.length).setValues([headers]).setFontWeight("bold");
  sh.setFrozenRows(1);

  ui.alert(
    "✅ Hoja preparada",
    "Se crearon/actualizaron los encabezados A–L.\n\n" +
    "Ahora completá por cada fila:\n" +
    "• Col B: el tipo de operación ('Importar' para copia directa de datos estándar, 'Actualizar' para refresco de BigQuery).\n" +
    "• Col C: el ID (o URL) del Spreadsheet de origen. Dejalo vacío o poné 'Este sheets' para usar el actual.\n" +
    "• Col D: la pestaña de origen.\n" +
    "• Col E: el nombre de la pestaña intermedia de staging local (donde se importará y podrás editar, manteniendo tus columnas extras a la derecha).\n" +
    "• Col F: el ID (o URL) del Spreadsheet de destino.\n" +
    "• Col G: la pestaña de destino.\n\n" +
    "Col I = horario de actualización BQ/Import · Col K = horario de envío.",
    ui.ButtonSet.OK
  );
}

// ============================================================
// ESTADO GENERAL (mail manual desde el menú)
// ============================================================

function enviarEstado() {
  const ss         = SpreadsheetApp.getActiveSpreadsheet();
  const hojaConfig = ss.getSheetByName(CONFIG.NOMBRE_HOJA_CONFIG);
  if (!hojaConfig) return;

  const filas = leerFilas(hojaConfig);
  const hoy   = new Date();
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

    htmlCuerpo += `
              <tr>
                <td style="padding: 12px 10px; border-bottom: 1px solid #eee;"><strong>${nombre}</strong></td>
                <td style="padding: 12px 10px; border-bottom: 1px solid #eee; color: #555;">${ultimaActBQ}</td>
                <td style="padding: 12px 10px; border-bottom: 1px solid #eee; color: #27ae60; font-weight: bold;">${ultimoEnvio}</td>
              </tr>
    `;
  });

  htmlCuerpo += `
            </tbody>
          </table>
        </div>

        <div style="background-color: #f9f9f9; padding: 15px; text-align: center; border-top: 1px solid #eee;">
          <p style="margin: 0; font-size: 12px; color: #999;">Script Maestro V42 (Unificado) • Envíos Automáticos</p>
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
