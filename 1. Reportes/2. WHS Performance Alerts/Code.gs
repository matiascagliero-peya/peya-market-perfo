// Versión: 2.0 (Corregida por Gemini)
// =================================================================
// SISTEMA DE ALERTAS DE PERFORMANCE — PedidosYa Markets
// =================================================================
// Archivo maestro de backend (Code.gs).
// =================================================================

// =================================================================
// 🚀 PANEL DE CONTROL DE FUNCIONES (Google Apps Script)
// =================================================================
//
// 🔴 1. FUNCIÓN ÚNICA DE ENVÍO DE CORREOS (PARA EL TRIGGER DE 5 MINUTOS):
//    -> enviarReporteDiario10AM() / enviarReporteDiario11AM()
//    * Es la ÚNICA función autorizada a enviar correos a los suscriptores.
//    * Corre cada 5 minutos e imprime en los LOGS la decisión tomada:
//      [DECISIÓN: OMITIR]           -> Aún no son las 11:00 AM.
//      [DECISIÓN: OMITIR]           -> El reporte de hoy ya fue enviado (anti-duplicados).
//      [DECISIÓN: ESPERAR]          -> 'WHS all Data' aún no tiene cargado el día de ayer.
//      [DECISIÓN: EJECUTAR ENVÍO]   -> Cumple todo: calcula, guarda en Sheets y envía mails.
//
// 🟢 2. FUNCIONES DE MANTENIMIENTO MANUAL (100% SEGURAS / 0 MAILS):
//    -> ejecutarCargaRetroactiva()       : Recalcula y guarda en Sheets los últimos 30 días con lluvias (0 mails).
//    -> llenarLluviasEnSheets()          : Rellena solo las lluvias faltantes en Sheets sin tocar alertas (0 mails).
//    -> probarProcesoAyerSinMails()      : Calcula el cierre de ayer y guarda en Sheets para validar (0 mails).
//    -> resetearSchedulerDeHoy()         : Reinicia el candado para permitir re-enviar hoy en pruebas.
//    -> probarConexionOpenMeteo()        : Prueba de conexión rápida con la API del clima (0 mails).
//    -> limpiarTodoElHistorialDeAlertas(): Vacía la hoja Alertas_Historial para empezar de cero (0 mails).
//    -> configurarTriggerCada5Minutos()  : Crea el activador oficial de Google cada 5 minutos con 1 clic.
// =================================================================

/**
 * 🔴 FUNCIÓN ÚNICA Y OFICIAL DE ENVÍO DE MAILS (ASIGNAR AL TRIGGER DE 5 MINUTOS)
 * Es la ÚNICA función del proyecto autorizada a enviar correos a los suscriptores.
 * 
 * Evalúa las condiciones en cada ejecución e imprime la decisión detallada en los logs:
 * • ¿Son las 11:00 AM o más?
 * • ¿Ya fue enviado hoy?
 * • ¿La planilla 'WHS all Data' ya tiene los datos de ayer cargados?
 *
 * @param {boolean} forzar - Si es true, ignora las restricciones horarias y candados (útil para pruebas).
 */
function enviarReporteDiario10AM(forzar) {
  var tz = Session.getScriptTimeZone() || "America/Argentina/Buenos_Aires";
  var ahora = new Date();
  var hoyStr = Utilities.formatDate(ahora, tz, "yyyy-MM-dd");
  var horaActual = parseInt(Utilities.formatDate(ahora, tz, "H"), 10);
  var horaCompletaStr = Utilities.formatDate(ahora, tz, "HH:mm");
  var props = PropertiesService.getScriptProperties();

  Logger.log("⏱️ ================================================================");
  Logger.log("⏱️ [TRIGGER EVALUADOR 5m] " + hoyStr + " " + horaCompletaStr + " (Buenos Aires)");

  // 1. EVALUACIÓN DE HORARIO: ¿Ya son las 11:00 AM?
  if (forzar !== true && horaActual < 11) {
    Logger.log("⏰ [DECISIÓN: OMITIR] Hora actual: " + horaCompletaStr + " (< 11:00 AM).");
    Logger.log("   Motivo: El envío diario está programado a partir de las 11:00 AM. Esperando la ventana.");
    Logger.log("⏱️ ================================================================");
    return;
  }

  // 2. EVALUACIÓN DE DUPLICADOS: ¿Ya se envió el reporte hoy?
  var yaEnviadoHoy = props.getProperty("LAST_RUN_DATE_TRIGGER");
  if (forzar !== true && yaEnviadoHoy === hoyStr) {
    var fechaEnviada = props.getProperty("LAST_SENT_DATA_DATE") || hoyStr;
    Logger.log("🛡️ [DECISIÓN: OMITIR] El reporte diario de hoy (" + hoyStr + ") ya fue enviado exitosamente.");
    Logger.log("   Motivo: Candado de seguridad activo (datos de " + fechaEnviada + " ya despachados). No se duplicarán correos.");
    Logger.log("⏱️ ================================================================");
    return;
  }

  // 3. EVALUACIÓN DE DISPONIBILIDAD DE DATOS EN 'WHS all Data'
  var latestDataDate = null;
  try {
    var actSheet = SpreadsheetApp.openById(SPREADSHEET_ID).getSheetByName(SHEET_ACTUALS);
    if (actSheet) {
      var lastCol = actSheet.getLastColumn();
      var headers = lastCol > 0 ? actSheet.getRange(1, 1, 1, lastCol).getValues()[0] : [];
      var dateColIdx = headers.indexOf('fecha');
      if (dateColIdx === -1) dateColIdx = headers.indexOf('date');
      
      if (dateColIdx !== -1) {
        var rawTopDate = actSheet.getRange(2, dateColIdx + 1, 1, 1).getValue();
        latestDataDate = normalizeDateToYMD(rawTopDate);
      }
    }
  } catch(e) {
    Logger.log("⚠️ [WARN] Error inspeccionando 'WHS all Data': " + e.message);
  }

  var ayerStr = normalizeDateToYMD(new Date(ahora.getTime() - 24 * 60 * 60 * 1000));
  var ultimaFechaEnviada = props.getProperty("LAST_SENT_DATA_DATE");

  if (forzar !== true) {
    if (latestDataDate && latestDataDate === ultimaFechaEnviada) {
      Logger.log("⏳ [DECISIÓN: ESPERAR] Última fecha en 'WHS all Data': " + latestDataDate + ".");
      Logger.log("   Motivo: Coincide con la última fecha enviada (" + ultimaFechaEnviada + "). Esperando actualización de BigQuery.");
      Logger.log("⏱️ ================================================================");
      return;
    }
    if (latestDataDate && latestDataDate < ayerStr) {
      Logger.log("⏳ [DECISIÓN: ESPERAR] Última fecha en 'WHS all Data': " + latestDataDate + " | Esperada: " + ayerStr + ".");
      Logger.log("   Motivo: La planilla aún no se cargó con el cierre completo de ayer. Reintentando en 5 minutos.");
      Logger.log("⏱️ ================================================================");
      return;
    }
  }

  // 4. ¡EJECUCIÓN DEL ENVÍO OFICIAL!
  Logger.log("🚀 [DECISIÓN: EJECUTAR ENVÍO OFICIAL] ¡Todas las condiciones cumplidas!");
  Logger.log("   • Hora actual: " + horaCompletaStr + " (ventana >= 11:00 AM)");
  Logger.log("   • Fecha de datos a reportar: " + (latestDataDate || ayerStr));
  Logger.log("   • Iniciando cálculo de desvíos, precipitaciones y envío de correos...");

  try {
    procesarAlertasDiarias(true);

    // Registrar candados de seguridad
    props.setProperty("LAST_RUN_DATE_TRIGGER", hoyStr);
    if (latestDataDate) {
      props.setProperty("LAST_SENT_DATA_DATE", latestDataDate);
    }
    Logger.log("✓ [FINALIZADO] ¡Envío completado exitosamente a todos los suscriptores!");
  } catch(err) {
    Logger.log("🚨 [ERROR CRÍTICO DURANTE ENVÍO]: " + err.message);
    Logger.log(err.stack);
  }
  Logger.log("⏱️ ================================================================");
}

/**
 * Alias para compatibilidad con la nueva hora oficial de envío (11:00 AM).
 */
function enviarReporteDiario11AM(forzar) {
  return enviarReporteDiario10AM(forzar);
}

/**
 * Función para reiniciar los candados de seguridad de hoy.
 * Permite que el trigger de 5 minutos vuelva a evaluar y enviar si necesitas hacer pruebas.
 */
function resetearSchedulerDeHoy() {
  var props = PropertiesService.getScriptProperties();
  props.deleteProperty("LAST_RUN_DATE_TRIGGER");
  props.deleteProperty("LAST_SENT_DATA_DATE");
  Logger.log("✓ [SEGURIDAD] Candados reiniciados. El trigger de 5 minutos podrá volver a evaluar y enviar hoy.");
}

/**
 * 1. Recalcula y guarda en Google Sheets el historial de alertas y lluvias de los últimos 30 días (sin mails).
 */
function ejecutarCargaRetroactiva() {
  Logger.log("Iniciando ejecución de carga retroactiva dinámica para los últimos 30 días...");
  var hoy = new Date();
  var ayer = new Date(hoy.getTime() - 24 * 60 * 60 * 1000);
  var hace30Dias = new Date(hoy.getTime() - 30 * 24 * 60 * 60 * 1000);
  var startDateStr = normalizeDateToYMD(hace30Dias);
  var endDateStr = normalizeDateToYMD(ayer);
  Logger.log("Rango detectado dinámicamente: " + startDateStr + " a " + endDateStr);
  backfillAlertsHistory(startDateStr, endDateStr);
  Logger.log("Carga retroactiva finalizada.");
}

/**
 * 2. Completa físicamente en Google Sheets la columna 8 (Precipitacion_mm) para las filas que no tengan lluvia (sin mails).
 */
function llenarLluviasEnSheets() {
  var count = completarPrecipitacionesFaltantesEnSheet();
  Logger.log("Resultado: Se completaron y guardaron " + count + " registros de lluvia en la planilla Alertas_Historial.");
}

/**
 * 3. Ejecuta el procesamiento de ayer y guarda alertas y lluvia en Google Sheets en modo seguro (sin mails).
 */
function probarProcesoAyerSinMails() {
  Logger.log("Iniciando procesamiento de prueba de ayer (modo seguro, sin correos)...");
  procesarAlertasDiarias(false);
  Logger.log("Proceso completado con éxito.");
}

// Alias de compatibilidad
function ejecutarProcesoDiarioSinMails() {
  return probarProcesoAyerSinMails();
}

/**
 * 4. Prueba de conexión y permisos externos con la API de Open-Meteo.
 */
function probarConexionOpenMeteo() {
  Logger.log("Iniciando prueba de conexión con Open-Meteo...");
  var url = 'https://api.open-meteo.com/v1/forecast?latitude=-34.6037&longitude=-58.3816&daily=precipitation_sum&timezone=auto';
  var resp = UrlFetchApp.fetch(url, { muteHttpExceptions: true });
  Logger.log("✓ Conexión exitosa. Código HTTP: " + resp.getResponseCode());
  Logger.log("Datos recibidos: " + resp.getContentText().substring(0, 160) + "...");
}

/**
 * 5. Borra físicamente todas las alertas de la base de datos (excepto los encabezados).
 */
function limpiarTodoElHistorialDeAlertas() {
  if (!isCurrentUserAnAdmin()) {
    throw new Error("Acceso denegado. Se requieren permisos de administrador.");
  }
  Logger.log("Iniciando vaciado completo de la base de datos de alertas...");
  var sheet = _getDbSheet('Alertas_Historial');
  var lastRow = sheet.getLastRow();
  if (lastRow > 1) {
    sheet.deleteRows(2, lastRow - 1);
    Logger.log("¡Éxito! Se borraron físicamente " + (lastRow - 1) + " registros. Alertas_Historial ha quedado vacía.");
  } else {
    Logger.log("La hoja de Alertas_Historial ya está vacía (solo tiene la fila de encabezados).");
  }
  SpreadsheetApp.flush();
}

/**
 * 6. Configura automáticamente el activador (trigger) en Google Apps Script
 * para que enviarReporteDiario10AM se ejecute cada 5 minutos.
 */
function configurarTriggerCada5Minutos() {
  Logger.log("Configurando activador cada 5 minutos...");
  
  // Eliminar activadores previos duplicados para evitar múltiples envíos
  var triggers = ScriptApp.getProjectTriggers();
  for (var i = 0; i < triggers.length; i++) {
    var fn = triggers[i].getHandlerFunction();
    if (fn === 'enviarReporteDiario10AM' || fn === 'ejecutarProcesoDiarioConMails' || fn === 'verificarYEjecutarEnvioDiario' || fn === 'enviarAlertasDiariasPorEmail') {
      ScriptApp.deleteTrigger(triggers[i]);
      Logger.log("Activador previo eliminado: " + fn);
    }
  }
  
  // Crear el nuevo activador cada 5 minutos apuntando a enviarReporteDiario10AM
  ScriptApp.newTrigger('enviarReporteDiario10AM')
    .timeBased()
    .everyMinutes(5)
    .create();
    
  Logger.log("✓ ¡Activador configurado con éxito! Se ejecutará cada 5 minutos llamando a 'enviarReporteDiario10AM'.");
}

// =================================================================
// ⚙️ NÚCLEO DEL SISTEMA Y PLATAFORMA WEB (USO INTERNO / FRONTEND)
// =================================================================
// Todas las funciones a partir de aquí son consumidas automáticamente
// por la aplicación web (Dashboard, Alertas por País, Suscripciones, Analytics).
// NO es necesario ejecutarlas manualmente desde este editor.
// =================================================================

// ── CONFIGURACIÓN DE ORIGEN DE DATOS ─────────────────────────────
var SPREADSHEET_ID  = '1RJ148x2zKVoM8kMXvaoR0Y1wIlp1KcoUJMsyRZ-6Y3k'; // Warehouse-level OKRs
var SHEET_ACTUALS   = 'WHS all Data';

// Cache de ejecución global síncrona para acelerar cálculos multi-día en caliente (In-Vivo)
var GLOBAL_ACT_SHEET_CACHE = null;
var GLOBAL_AD_CACHE = null;
var GLOBAL_HEADERS_CACHE = null;
var GLOBAL_ADI_CACHE = null;
var GLOBAL_AWHNAME_CACHE = null;
var GLOBAL_REAL_LAST_ROW_CACHE = null;
var GLOBAL_DATE_COL_VALUES_CACHE = null;
var GLOBAL_AD_DATE_STR_CACHE = null;
var GLOBAL_AD_DATE_MS_CACHE = null;
var GLOBAL_METRICS_AVAILABILITY_CACHE = null;

// ── CONFIGURACIÓN DE BASE DE DATOS DE ALERTAS ───────────────────
var DATABASE_SS_ID  = '1uEhd2kBO4K93B7bqbABemRyVxOv6w7wKMdGxLDfCLvY'; // Planilla DB de Alertas

// ── LISTA DE ADMINISTRADORES ─────────────────────────────────────
var ADMIN_USERS = [
  'matias.cagliero@pedidosya.com',
  'eugenio.irigoin@pedidosya.com',
  'nicki.krawiecki@pedidosya.com',
  'tobias.fay@pedidosya.com',
  'juan.pinori@pedidosya.com'
];

// ── CONFIGURACIÓN DE SEGURIDAD PARA ENVÍO DE EMAILS ─────────────
// Modos de envío de correo válidos para regular el comportamiento del sistema:
// - 'PRODUCTION': Envío real de las alertas a todos los destinatarios suscritos.
// - 'TEST'      : (MODO POR DEFECTO / RECOMENDADO) Redirige todos los correos de los usuarios al usuario ejecutor actual o a los administradores.
//                 Añade un prefijo '[MODO PRUEBA]' al asunto y un banner rojo explicativo en la parte superior del cuerpo.
// - 'DISABLED'  : Desactiva por completo cualquier llamada a la API de envío de correo de Google (solo loguea lo que se habría enviado).
var DEFAULT_EMAIL_SENDING_MODE = 'PRODUCTION'; 

function getEmailSendingMode() {
  try {
    var mode = PropertiesService.getScriptProperties().getProperty("EMAIL_SENDING_MODE");
    if (mode) {
      mode = mode.trim().toUpperCase();
      if (mode === 'PRODUCTION' || mode === 'TEST' || mode === 'DISABLED') {
        return mode;
      }
    }
  } catch (e) {
    Logger.log("Error leyendo EMAIL_SENDING_MODE de script properties: " + e.toString());
  }
  return DEFAULT_EMAIL_SENDING_MODE;
}

// ── DICCIONARIO DE REGLAS DE ALERTAS (METRICS DEFINITION) ────────
var METRICS_TO_ALERT = [
  {
    key: "orders",
    label: "Confirmed Orders",
    baseline: "L3W", // L3W same-day comparison
    format: "int",
    check: function(val, l3w) {
      if (val == null || l3w == null || l3w === 0) return null;
      var desvio = ((val - l3w) / l3w) * 100;
      if (desvio < -20.0) {
        return { triggered: true, desvio: desvio, expected: l3w, details: "Caída > 20.0% vs L3W" };
      }
      return { triggered: false };
    }
  },
  {
    key: "gmv",
    label: "GMV (EUR)",
    baseline: "L3W",
    format: "eur",
    check: function(val, l3w) {
      if (val == null || l3w == null || l3w === 0) return null;
      var desvio = ((val - l3w) / l3w) * 100;
      if (desvio < -20.0) {
        return { triggered: true, desvio: desvio, expected: l3w, details: "Caída > 20.0% vs L3W" };
      }
      return { triggered: false };
    }
  },
  {
    key: "new_users",
    label: "New Users",
    baseline: "L3W",
    format: "int",
    check: function(val, l3w) {
      if (val == null || l3w == null || l3w === 0) return null;
      var desvio = ((val - l3w) / l3w) * 100;
      if (desvio < -25.0) {
        return { triggered: true, desvio: desvio, expected: l3w, details: "Caída > 25.0% vs L3W" };
      }
      return { triggered: false };
    }
  },
  {
    key: "wis",
    label: "WIS %",
    baseline: "L3W", // L3W same-day comparison
    format: "pct",
    check: function(val, l3w) {
      if (val == null) return null;
      var diffPP = l3w != null ? (val - l3w) * 100 : 0;
      var isBelow75 = val < 0.75;
      if (isBelow75 || (l3w != null && diffPP < -5.0)) {
        var det = isBelow75 
          ? (l3w != null && diffPP < -5.0 ? "Absoluto < 75.0% o Caída > 5.0 pp vs L3W" : "Absoluto < 75.0%")
          : "Caída > 5.0 pp vs L3W";
        var desvio = isBelow75 && (l3w == null || diffPP >= -5.0) ? (val - 0.75) * 100 : diffPP;
        return { triggered: true, desvio: desvio, expected: l3w != null ? l3w : 0.75, details: det };
      }
      return { triggered: false };
    }
  },
  {
    key: "wis_uf",
    label: "WIS UF %",
    baseline: "L3W", // L3W same-day comparison
    format: "pct",
    check: function(val, l3w) {
      if (val == null) return null;
      var diffPP = l3w != null ? (val - l3w) * 100 : 0;
      var isBelow75 = val < 0.75;
      if (isBelow75 || (l3w != null && diffPP < -5.0)) {
        var det = isBelow75 
          ? (l3w != null && diffPP < -5.0 ? "Absoluto < 75.0% o Caída > 5.0 pp vs L3W" : "Absoluto < 75.0%")
          : "Caída > 5.0 pp vs L3W";
        var desvio = isBelow75 && (l3w == null || diffPP >= -5.0) ? (val - 0.75) * 100 : diffPP;
        return { triggered: true, desvio: desvio, expected: l3w != null ? l3w : 0.75, details: det };
      }
      return { triggered: false };
    }
  },
  {
    key: "seamless",
    label: "Seamless Delivery %",
    baseline: "7D",
    format: "pct",
    check: function(val, r7d) {
      if (val == null) return null;
      var diffPP = r7d != null ? (val - r7d) * 100 : 0;
      var isBelow75 = val < 0.75;
      if (isBelow75 || (r7d != null && diffPP < -5.0)) {
        var det = isBelow75 
          ? (r7d != null && diffPP < -5.0 ? "Absoluto < 75.0% o Caída > 5.0 pp vs 7D" : "Absoluto < 75.0%")
          : "Caída > 5.0 pp vs 7D";
        var desvio = isBelow75 && (r7d == null || diffPP >= -5.0) ? (val - 0.75) * 100 : diffPP;
        return { triggered: true, desvio: desvio, expected: r7d != null ? r7d : 0.75, details: det };
      }
      return { triggered: false };
    }
  },
  {
    key: "delivery_time",
    label: "Avg. Delivery Time",
    baseline: "L3W",
    format: "min",
    check: function(val, l3w) {
      if (val == null || l3w == null || l3w === 0) return null;
      var absDiff = val - l3w;
      var isAbove40 = val > 40.0;
      if (absDiff > 5.0 || isAbove40) {
        var det = isAbove40
          ? (absDiff > 5.0 ? "Absoluto > 40.0 min o Aumento > 5.0 min vs L3W" : "Absoluto > 40.0 min")
          : "Aumento > 5.0 min vs L3W";
        return { triggered: true, desvio: absDiff, expected: l3w, details: det };
      }
      return { triggered: false };
    }
  },
  {
    key: "assignment_time_over_6m",
    label: "Assignment Time > 6 min %",
    baseline: "7D",
    format: "pct",
    check: function(val, r7d) {
      if (val == null) return null;
      var valPct = val * 100;
      if (valPct > 30.0) {
        var diffPP = r7d != null ? (val - r7d) * 100 : (valPct - 30.0);
        return { triggered: true, desvio: diffPP, expected: r7d != null ? r7d : 0.30, details: "Absoluto > 30.0%" };
      }
      return { triggered: false };
    }
  },
  {
    key: "open_time",
    label: "Weighted Open time %",
    baseline: "7D",
    format: "pct",
    check: function(val, r7d) {
      if (val == null) return null;
      var valPct = val * 100;
      if (valPct < 90.0) {
        var diffPP = r7d != null ? (val - r7d) * 100 : (valPct - 90.0);
        return { triggered: true, desvio: diffPP, expected: r7d != null ? r7d : 0.90, details: "Absoluto < 90.0%" };
      }
      return { triggered: false };
    }
  },
  {
    key: "assignment_time",
    label: "Assignment Time",
    baseline: "L3W",
    format: "min",
    check: function(val, l3w) {
      if (val == null || l3w == null || l3w === 0) return null;
      var absDiff = val - l3w;
      var isAbove7 = val > 7.0;
      if (absDiff > 5.0 || isAbove7) {
        var det = isAbove7
          ? (absDiff > 5.0 ? "Absoluto > 7.0 min o Aumento > 5.0 min vs L3W" : "Absoluto > 7.0 min")
          : "Aumento > 5.0 min vs L3W";
        return { triggered: true, desvio: absDiff, expected: l3w, details: det };
      }
      return { triggered: false };
    }
  },
  {
    key: "rejected_orders",
    label: "Rejected Orders %",
    baseline: "7D",
    format: "pct",
    check: function(val, r7d) {
      if (val == null) return null;
      var valPct = val * 100;
      if (valPct > 3.0) {
        var diffPP = r7d != null ? (val - r7d) * 100 : (valPct - 3.0);
        return { triggered: true, desvio: diffPP, expected: r7d != null ? r7d : 0.03, details: "Absoluto > 3.0%" };
      }
      return { triggered: false };
    }
  },
  {
    key: "session_orders",
    label: "HC Sessions orders %",
    baseline: "7D",
    format: "pct",
    check: function(val, r7d) {
      if (val == null || r7d == null) return null;
      var diffPP = (val - r7d) * 100;
      if (diffPP > 3.0) {
        return { triggered: true, desvio: diffPP, expected: r7d, details: "Aumento > 3.0 pp vs 7D" };
      }
      return { triggered: false };
    }
  },
  {
    key: "late_orders",
    label: "Late Orders %",
    baseline: "7D",
    format: "pct",
    check: function(val, r7d) {
      if (val == null || r7d == null) return null;
      var diffPP = (val - r7d) * 100;
      if (diffPP > 5.0) {
        return { triggered: true, desvio: diffPP, expected: r7d, details: "Aumento > 5.0 pp vs 7D" };
      }
      return { triggered: false };
    }
  },
  {
    key: "slow_orders",
    label: "Slow Orders %",
    baseline: "7D",
    format: "pct",
    check: function(val, r7d) {
      if (val == null || r7d == null) return null;
      var diffPP = (val - r7d) * 100;
      if (diffPP > 5.0) {
        return { triggered: true, desvio: diffPP, expected: r7d, details: "Aumento > 5.0 pp vs 7D" };
      }
      return { triggered: false };
    }
  },
  {
    key: "forced_preorders",
    label: "Forced Preorders %",
    baseline: "7D",
    format: "pct",
    check: function(val, r7d) {
      if (val == null) return null;
      var valPct = val * 100;
      if (valPct > 2.5) {
        var diffPP = r7d != null ? (val - r7d) * 100 : (valPct - 2.5);
        return { triggered: true, desvio: diffPP, expected: r7d != null ? r7d : 0.025, details: "Absoluto > 2.5%" };
      }
      return { triggered: false };
    }
  },
  {
    key: "modified_orders",
    label: "Modified Orders %",
    baseline: "7D",
    format: "pct",
    check: function(val, r7d) {
      if (val == null || r7d == null) return null;
      var diffPP = (val - r7d) * 100;
      if (diffPP > 3.0) {
        return { triggered: true, desvio: diffPP, expected: r7d, details: "Aumento > 3.0 pp vs 7D" };
      }
      return { triggered: false };
    }
  }
];

// =================================================================
// ── CAPA DE BASE DE DATOS (Google Sheets) ────────────────────────
// =================================================================

function _getDbSheet(sheetName) {
  var ss = SpreadsheetApp.openById(DATABASE_SS_ID);
  var sheet = ss.getSheetByName(sheetName);
  if (!sheet) {
    // Si no existe, la crea con sus encabezados adecuados
    if (sheetName === 'Suscripciones') {
      sheet = ss.insertSheet('Suscripciones');
      var headers = ['Email', 'Paises', 'Warehouses', 'Activo', 'FechaRegistro'];
      METRICS_TO_ALERT.forEach(function(m) { headers.push(m.key); });
      sheet.appendRow(headers);
    } else if (sheetName === 'Alertas_Historial') {
      sheet = ss.insertSheet('Alertas_Historial');
      sheet.appendRow(['Fecha', 'Pais', 'Metrica', 'ValorReal', 'Esperado', 'Desvio', 'Detalle', 'Precipitacion_mm']);
    } else if (sheetName === 'Logs_Acceso') {
      sheet = ss.insertSheet('Logs_Acceso');
      sheet.appendRow(['FechaHora', 'Email', 'Accion']);
    }
  } else if (sheetName === 'Alertas_Historial') {
    // AUTO-MIGRACIÓN DE LA BASE DE DATOS DE ALERTAS (COLUMNA 8: PRECIPITACION_MM):
    var lastColHist = sheet.getLastColumn();
    if (lastColHist === 7) {
      Logger.log('Detectada base de datos de Alertas_Historial versión 7 columnas. Auto-migrando agregando Precipitacion_mm en columna 8...');
      sheet.getRange(1, 8).setValue('Precipitacion_mm');
      SpreadsheetApp.flush();
    }
  } else if (sheetName === 'Suscripciones') {
    // AUTO-MIGRACIÓN DE LA BASE DE DATOS (MIGRACIÓN UNIFICADA DE WAREHOUSES Y MÉTRICAS): 
    var lastCol = sheet.getLastColumn();
    var rawHeaders = lastCol > 0 ? sheet.getRange(1, 1, 1, lastCol).getValues()[0] : [];
    var headers = rawHeaders.map(function(h){ return String(h).trim().toLowerCase(); });
    
    // 1. Auto-insertar columna "Warehouses" si falta en la estructura
    if (headers.length > 0 && headers.indexOf('warehouses') === -1) {
      Logger.log('Detectada base de datos de Suscripciones versión antigua (falta columna Warehouses). Auto-migrando...');
      sheet.insertColumnAfter(2); // Insertar después de 'Paises' (columna 2)
      sheet.getRange(1, 3).setValue('Warehouses');
      
      // Llenar por defecto con ["TODOS"] para todos los registros existentes para mantener consistencia
      var last = sheet.getLastRow();
      if (last > 1) {
        var range = sheet.getRange(2, 3, last - 1, 1);
        var defVals = [];
        for (var i = 0; i < last - 1; i++) { defVals.push(['["TODOS"]']); }
        range.setValues(defVals);
      }
      Logger.log('Se ha insertado la columna Warehouses y se auto-migraron los registros existentes con ["TODOS"].');
    }
    
    // 2. Auto-insertar columnas de métricas de METRICS_TO_ALERT si faltan en la estructura
    var lastColUpdated = sheet.getLastColumn();
    var rawHeadersUpdated = lastColUpdated > 0 ? sheet.getRange(1, 1, 1, lastColUpdated).getValues()[0] : [];
    var headersUpdated = rawHeadersUpdated.map(function(h){ return String(h).trim().toLowerCase(); });
    
    var missingMetrics = [];
    METRICS_TO_ALERT.forEach(function(mDef) {
      if (headersUpdated.indexOf(mDef.key.toLowerCase()) === -1) {
        missingMetrics.push(mDef.key);
      }
    });
    
    if (missingMetrics.length > 0) {
      Logger.log('Detectadas métricas faltantes en la tabla de Suscripciones: ' + missingMetrics.join(', ') + '. Auto-migrando...');
      
      // Añadir cada métrica como una nueva columna al final del sheet
      missingMetrics.forEach(function(mKey) {
        var newColIdx = sheet.getLastColumn() + 1;
        sheet.insertColumnAfter(newColIdx - 1);
        sheet.getRange(1, newColIdx).setValue(mKey);
        
        // Autopoblar con "1" (activo) para los registros de suscriptores existentes para no desconfigurarlos
        var last = sheet.getLastRow();
        if (last > 1) {
          var range = sheet.getRange(2, newColIdx, last - 1, 1);
          var defVals = [];
          for (var i = 0; i < last - 1; i++) { defVals.push([1]); }
          range.setValues(defVals);
        }
      });
      Logger.log('Se han insertado las columnas para las métricas faltantes: ' + missingMetrics.join(', '));
      SpreadsheetApp.flush();
    }
  }
  return sheet;
}

function _parseArrayOrCommaString(val) {
  var clean = String(val || '').trim();
  if (!clean) return [];
  
  // Si empieza con '[' y termina con ']', intentamos parsear como JSON
  if (clean.indexOf('[') === 0 && clean.lastIndexOf(']') === clean.length - 1) {
    try {
      var parsed = JSON.parse(clean);
      if (Array.isArray(parsed)) {
        if (parsed.length === 1 && Array.isArray(parsed[0])) {
          parsed = parsed[0]; // Desanidar si es necesario
        }
        return parsed.map(function(s) { return String(s).trim().toUpperCase(); });
      }
    } catch(e) {
      // Si falla, removemos los corchetes y tratamos como texto separado por comas
      clean = clean.slice(1, -1);
    }
  }
  
  // Tratamos como texto separado por comas (o un solo elemento)
  return clean.split(',').map(function(s) {
    return String(s).trim().toUpperCase();
  }).filter(Boolean);
}

function saveSubscription(countries, warehouses, metrics) {
  var email = _getUserEmail();
  return saveSubscriptionToDb(email, countries, warehouses, metrics);
}

function saveSubscriptionToDb(email, countries, warehouses, metrics) {
  var sheet = _getDbSheet('Suscripciones');
  var data = sheet.getDataRange().getValues();
  var lastCol = sheet.getLastColumn();
  var rawHeaders = lastCol > 0 ? sheet.getRange(1, 1, 1, lastCol).getValues()[0] : [];
  var headers = rawHeaders.map(function(h) { return h.trim().toLowerCase(); });
  var userIndex = -1;
  
  // Normalizar email a minúsculas
  email = email.trim().toLowerCase();
  for (var i = 1; i < data.length; i++) {
    if (String(data[i][0]).trim().toLowerCase() === email) {
      userIndex = i + 1; // 1-based row index
      break;
    }
  }
  
  var now = new Date();
  var pStr = Array.isArray(countries) ? countries.join(', ') : String(countries || '');
  var wStr = Array.isArray(warehouses) ? warehouses.join(', ') : String(warehouses || '');
  
  // Armar la fila basándonos dinámicamente en los nombres de las columnas
  var rowValues = [];
  headers.forEach(function(h) {
    if (h === 'email') rowValues.push(email);
    else if (h === 'paises') rowValues.push(pStr);
    else if (h === 'warehouses') rowValues.push(wStr);
    else if (h === 'activo') rowValues.push('SÍ');
    else if (h === 'fecharegistro') rowValues.push(now);
    else {
      // Buscar si el header es una de nuestras métricas
      var active = (metrics.indexOf('TODAS') !== -1 || metrics.indexOf(h) !== -1) ? 1 : "";
      rowValues.push(active);
    }
  });
  
  if (userIndex !== -1) {
    // Sobrescribir toda la fila de golpe en una sola transacción
    sheet.getRange(userIndex, 1, 1, rowValues.length).setValues([rowValues]);
  } else {
    sheet.appendRow(rowValues);
  }
}

/**
 * Limpia y sanitiza las direcciones de correo electrónico.
 * Remueve comillas simples, dobles, espacios y caracteres extraños de copia y pega de la base de datos.
 */
function sanitizeEmail(email) {
  if (!email) return "";
  return String(email).trim().replace(/['"“”‘’]/g, "").trim().toLowerCase();
}

function getSubscriptionFromDb(email) {
  var sheet = _getDbSheet('Suscripciones');
  var data = sheet.getDataRange().getValues();
  var lastCol = sheet.getLastColumn();
  var rawHeaders = lastCol > 0 ? sheet.getRange(1, 1, 1, lastCol).getValues()[0] : [];
  var headers = rawHeaders.map(function(h){ return String(h).trim().toLowerCase(); });
  email = sanitizeEmail(email);
  
  for (var i = 1; i < data.length; i++) {
    var dbEmail = sanitizeEmail(data[i][0]);
    if (dbEmail === email) {
      var row = data[i];
      var activeMetrics = [];
      METRICS_TO_ALERT.forEach(function(mDef) {
        var colIdx = headers.indexOf(mDef.key.toLowerCase());
        if (colIdx !== -1) {
          var val = row[colIdx];
          if (val === 1 || String(val).trim() === '1' || String(val).trim().toUpperCase() === 'SÍ') {
            activeMetrics.push(mDef.key);
          }
        }
      });
      
      if (activeMetrics.length === METRICS_TO_ALERT.length) {
        activeMetrics = ['TODAS'];
      }
      
      var countriesIdx = headers.indexOf('paises');
      var warehousesIdx = headers.indexOf('warehouses');
      var activeIdx = headers.indexOf('activo');
      
      var rawP = countriesIdx !== -1 ? row[countriesIdx] : '';
      var rawW = warehousesIdx !== -1 ? row[warehousesIdx] : '';
      var activeVal = activeIdx !== -1 ? row[activeIdx] : 'SÍ';
      
      var parsedP = _parseArrayOrCommaString(rawP);
      var parsedW = _parseArrayOrCommaString(rawW);
      
      return {
        email: email,
        paises: parsedP,
        warehouses: parsedW,
        metricas: activeMetrics,
        activo: activeVal === 'SÍ'
      };
    }
  }
  return { email: email, paises: [], warehouses: [], metricas: [], activo: false };
}

function getSubscriptionsFromDb() {
  var sheet = _getDbSheet('Suscripciones');
  var data = sheet.getDataRange().getValues();
  var lastCol = sheet.getLastColumn();
  var rawHeaders = lastCol > 0 ? sheet.getRange(1, 1, 1, lastCol).getValues()[0] : [];
  var headers = rawHeaders.map(function(h){ return String(h).trim().toLowerCase(); });
  var result = [];
  
  for (var i = 1; i < data.length; i++) {
    var emailClean = sanitizeEmail(data[i][0]);
    if (emailClean && emailClean.indexOf('@') !== -1) {
      var row = data[i];
      var activeMetrics = [];
      METRICS_TO_ALERT.forEach(function(mDef) {
        var colIdx = headers.indexOf(mDef.key.toLowerCase());
        if (colIdx !== -1) {
          var val = row[colIdx];
          if (val === 1 || String(val).trim() === '1' || String(val).trim().toUpperCase() === 'SÍ') {
            activeMetrics.push(mDef.key);
          }
        }
      });
      
      if (activeMetrics.length === METRICS_TO_ALERT.length) {
        activeMetrics = ['TODAS'];
      }
      
      var countriesIdx = headers.indexOf('paises');
      var warehousesIdx = headers.indexOf('warehouses');
      var activeIdx = headers.indexOf('activo');
      
      var rawP = countriesIdx !== -1 ? row[countriesIdx] : '';
      var rawW = warehousesIdx !== -1 ? row[warehousesIdx] : '';
      var activeVal = activeIdx !== -1 ? row[activeIdx] : 'SÍ';
      
      var parsedP = _parseArrayOrCommaString(rawP);
      var parsedW = _parseArrayOrCommaString(rawW);
      
      result.push({
        email: emailClean,
        paises: parsedP,
        warehouses: parsedW,
        metricas: activeMetrics,
        activo: activeVal === 'SÍ'
      });
    }
  }
  return result;
}

function saveAlertsToDb(alertas, fechaYMD) {
  var sheet = _getDbSheet('Alertas_Historial');
  var data = sheet.getDataRange().getValues();
  
  if (data.length > 1) {
    // 1. Filtrar las filas para mantener todas excepto las de la fechaYMD que queremos sobrescribir
    var headers = data[0];
    var filteredRows = [];
    
    for (var i = 1; i < data.length; i++) {
      var rowFecha = normalizeDateToYMD(data[i][0]);
      if (rowFecha !== fechaYMD) {
        filteredRows.push(data[i]);
      }
    }
    
    // 2. Limpiar todo el contenido de la hoja de datos (dejando los encabezados)
    sheet.clearContents();
    sheet.getRange(1, 1, 1, headers.length).setValues([headers]);
    
    // 3. Escribir de vuelta las filas filtradas
    if (filteredRows.length > 0) {
      sheet.getRange(2, 1, filteredRows.length, headers.length).setValues(filteredRows);
    }
  }
  
  if (alertas.length === 0) {
    SpreadsheetApp.flush();
    return;
  }
  
  // 4. Preparar las nuevas alertas para escritura en lote
  var rowsToWrite = alertas.map(function(a) {
    var lluviaVal = (a.lluvia_mm !== undefined && a.lluvia_mm !== null && !isNaN(a.lluvia_mm)) ? a.lluvia_mm : '';
    return [
      fechaYMD,
      a.pais,
      a.metricaLabel,
      a.valorReal,
      a.valorEsperado,
      a.desvio,
      a.detalles,
      lluviaVal
    ];
  });
  
  var lastRow = sheet.getLastRow();
  sheet.getRange(lastRow + 1, 1, rowsToWrite.length, 8).setValues(rowsToWrite);
  
  SpreadsheetApp.flush();
}

/**
 * Revisa la hoja 'Alertas_Historial' en Google Sheets y completa físicamente 
 * la columna 8 (Precipitacion_mm) para todas las filas que aún no tengan dato.
 * Permite que toda la data de lluvia quede almacenada en la planilla y se cargue al recargar.
 */
function completarPrecipitacionesFaltantesEnSheet() {
  try {
    var sheet = _getDbSheet('Alertas_Historial');
    var lastRow = sheet.getLastRow();
    if (lastRow <= 1) return 0;

    var lastCol = sheet.getLastColumn();
    if (lastCol < 8) {
      sheet.getRange(1, 8).setValue('Precipitacion_mm');
      lastCol = 8;
    }

    var data = sheet.getRange(2, 1, lastRow - 1, 8).getValues();
    var missingByDate = {};
    var totalMissing = 0;

    for (var i = 0; i < data.length; i++) {
      var fechaStr = normalizeDateToYMD(data[i][0]);
      var wh = String(data[i][1] || '').trim();
      var currentRain = data[i][7];

      if (fechaStr && wh && (currentRain === '' || currentRain === null || currentRain === undefined || isNaN(currentRain))) {
        if (!missingByDate[fechaStr]) missingByDate[fechaStr] = [];
        missingByDate[fechaStr].push({ rowIdx: i, wh: wh });
        totalMissing++;
      }
    }

    if (totalMissing === 0) {
      Logger.log("[Precipitaciones] Todas las filas en Alertas_Historial ya tienen su dato de lluvia en la columna 8 de Sheets.");
      return 0;
    }

    Logger.log("[Precipitaciones] Se detectaron " + totalMissing + " filas sin dato de lluvia en Google Sheets. Completando...");

    // Cargar coordenadas maestras frescas directamente de la planilla vinculada (gid: 1805962870)
    var coordsMap = getWarehouseCoordinatesMap(true);

    Object.keys(missingByDate).forEach(function(fechaYMD) {
      var items = missingByDate[fechaYMD];
      var uniqueWhs = {};
      items.forEach(function(it) { uniqueWhs[it.wh] = true; });

      var itemsToQuery = [];
      Object.keys(uniqueWhs).forEach(function(wh) {
        var c = resolveCoordsForWh(coordsMap, wh);
        if (c && c.lat && c.lng) {
          itemsToQuery.push({ wh: wh, lat: c.lat, lng: c.lng });
        }
      });

      var weatherMap = fetchPrecipitationForCoordinates(itemsToQuery, fechaYMD);

      items.forEach(function(it) {
        var c = resolveCoordsForWh(coordsMap, it.wh);
        var mm = 0.0;
        if (c && c.lat && c.lng) {
          var key3 = c.lat.toFixed(3) + '_' + c.lng.toFixed(3);
          if (weatherMap[key3] !== undefined && weatherMap[key3] !== null) {
            mm = weatherMap[key3];
          }
        }
        data[it.rowIdx][7] = mm;
      });
    });

    var col8Values = data.map(function(row) {
      return [row[7] !== '' && row[7] !== null && !isNaN(row[7]) ? row[7] : 0.0];
    });

    sheet.getRange(2, 8, col8Values.length, 1).setValues(col8Values);
    SpreadsheetApp.flush();
    Logger.log("[Precipitaciones] ¡Éxito! Se guardaron físicamente los datos de lluvia en Google Sheets para " + totalMissing + " filas.");
    return totalMissing;
  } catch(err) {
    Logger.log("[Precipitaciones] Error al completar precipitaciones en Sheet: " + err.message);
    return 0;
  }
}

var GLOBAL_ALERTS_HISTORY_CACHE = null;

function getAlertsHistoryFromDb() {
  Logger.log("DIAGNÓSTICO: Forzando re-lectura completa de Alertas_Historial, ignorando caché y rangos de fecha.");
  var sheet = _getDbSheet('Alertas_Historial');
  var lastRow = sheet.getLastRow();
  Logger.log("DIAGNÓSTICO: Última fila detectada en la planilla: " + lastRow);

  if (lastRow <= 1) {
    Logger.log("DIAGNÓSTICO: La planilla solo tiene encabezados. Retornando array vacío.");
    return [];
  }
  
  var lastCol = Math.max(8, sheet.getLastColumn());
  var numRowsToRead = lastRow - 1;
  var data = sheet.getRange(2, 1, numRowsToRead, lastCol).getValues();
  Logger.log("DIAGNÓSTICO: Se han leído " + data.length + " filas de datos crudos.");
  
  var result = [];
  for (var i = 0; i < data.length; i++) {
    // Verificación de fila válida para evitar errores con filas vacías
    if (data[i] && data[i][0]) {
      var vReal = parseFloat(data[i][3]);
      var vEsp = parseFloat(data[i][4]);
      var vDesv = parseFloat(data[i][5]);
      var vLluvia = (data[i].length > 7 && data[i][7] !== '' && !isNaN(parseFloat(data[i][7]))) ? parseFloat(data[i][7]) : null;
      result.push({
        fecha: normalizeDateToYMD(data[i][0]),
        pais: String(data[i][1]),
        metricaLabel: String(data[i][2]),
        valorReal: isNaN(vReal) ? null : vReal,
        valorEsperado: isNaN(vEsp) ? null : vEsp,
        desvio: isNaN(vDesv) ? null : vDesv,
        detalles: String(data[i][6]),
        lluvia_mm: vLluvia
      });
    }
  }
  
  Logger.log("DIAGNÓSTICO: Se han procesado y se retornarán " + result.length + " alertas.");
  return result;
}

/**
 * Calcula los días consecutivos que se viene repitiendo cada alerta basándose en el histórico de corridas del sistema.
 * Esto evita cortes de rachas por fines de semana, feriados o días sin ejecución.
 * Añade la propiedad `consecutiveDays` (entero, mínimo 1) a cada alerta.
 */
function calcularYAgregarDiasConsecutivos(alertasNuevas) {
  if (!alertasNuevas || alertasNuevas.length === 0) return alertasNuevas;

  var alertasHistoricas = [];
  try {
    alertasHistoricas = getAlertsHistoryFromDb();
  } catch(e) {
    Logger.log("Error obteniendo historial para días consecutivos: " + e);
  }

  // 1. Obtener todas las fechas únicas de ejecución presentes en la data (histórica y nueva)
  var fechasUnicasMap = {};
  var mapaAlertas = {};

  function registrarAlerta(a) {
    if (!a || !a.fecha || !a.pais || !a.metricaLabel) return;
    var fecha = a.fecha;
    var clave = String(a.pais).trim().toLowerCase() + "_" + String(a.metricaLabel).trim().toLowerCase();
    
    // Registrar fecha de corrida
    fechasUnicasMap[fecha] = true;
    
    // Registrar en mapa de búsqueda rápida
    if (!mapaAlertas[fecha]) {
      mapaAlertas[fecha] = {};
    }
    mapaAlertas[fecha][clave] = true;
  }

  // Registrar tanto alertas históricas como nuevas
  if (Array.isArray(alertasHistoricas)) {
    alertasHistoricas.forEach(registrarAlerta);
  }
  alertasNuevas.forEach(registrarAlerta);

  // 2. Crear una lista ordenada de fechas de ejecución en orden descendente (cronología real de reportes)
  var listaFechas = Object.keys(fechasUnicasMap).sort(function(a, b) {
    return b.localeCompare(a); // De más reciente a más antiguo (ej: "2026-08-17", "2026-08-14", "2026-08-13")
  });

  // 3. Calcular para cada alerta nueva basándonos en la secuencia cronológica de ejecuciones
  alertasNuevas.forEach(function(a) {
    var count = 1;
    var fechaStr = a.fecha;
    if (!fechaStr) {
      a.consecutiveDays = 1;
      return;
    }

    var clave = String(a.pais).trim().toLowerCase() + "_" + String(a.metricaLabel).trim().toLowerCase();
    
    // Encontrar índice de la fecha de la alerta en nuestra lista ordenada de ejecuciones
    var idx = listaFechas.indexOf(fechaStr);
    if (idx !== -1) {
      // Recorrer las ejecuciones previas consecutivas en la lista de fechas
      for (var i = idx + 1; i < listaFechas.length; i++) {
        var fechaPrevia = listaFechas[i];
        if (mapaAlertas[fechaPrevia] && mapaAlertas[fechaPrevia][clave]) {
          count++;
        } else {
          break; // Se rompe la racha si en la corrida anterior la tienda no tuvo esta alerta
        }
      }
    }
    
    a.consecutiveDays = count;
  });

  return alertasNuevas;
}

function logAccess(email, action) {
  var sheet = _getDbSheet('Logs_Acceso');
  sheet.appendRow([new Date(), email, action]);
}

function getAccessLogsFromDb() {
  var sheet = _getDbSheet('Logs_Acceso');
  var data = sheet.getDataRange().getValues();
  var result = [];
  for (var i = 1; i < data.length; i++) {
    if (data[i][0]) {
      result.push({
        fecha: Utilities.formatDate(new Date(data[i][0]), Session.getScriptTimeZone(), 'yyyy-MM-dd HH:mm:ss'),
        email: String(data[i][1]),
        accion: String(data[i][2])
      });
    }
  }
  return result;
}

// =================================================================
// ── MOTOR DE CÁLCULO DE ANOMALÍAS (CRON DIARIO) ─────────────────
// =================================================================

function procesarAlertasDiarias(enviarMails) {
  Logger.log('Iniciando proceso diario de detección de anomalías...');
  var resultado = _analizarAnomaliasDeAyer();
  if (!resultado || !resultado.alertas || resultado.alertas.length === 0) {
    Logger.log('No se detectaron anomalías ayer.');
    saveAlertsToDb([], resultado ? resultado.yesterdayYMD : normalizeDateToYMD(new Date()));
    return;
  }
  
  // Enriquecer con precipitación (mm de lluvia) vía Open-Meteo y coordenadas de Mapster
  enrichAlertsWithPrecipitation(resultado.alertas, resultado.yesterdayYMD);

  // Calcular días consecutivos para las alertas antes de guardarlas y distribuirlas
  var alertasConConsecutivos = calcularYAgregarDiasConsecutivos(resultado.alertas);
  
  Logger.log('Se detectaron ' + alertasConConsecutivos.length + ' alertas. Guardando en DB...');
  saveAlertsToDb(alertasConConsecutivos, resultado.yesterdayYMD);
  
  if (enviarMails === true) {
    Logger.log('Distribuyendo correos personalizados por suscripción...');
    _enviarCorreosBasadosEnSuscripciones(alertasConConsecutivos, resultado.yesterdayYMD, false);
  } else {
    Logger.log('ℹ️ [SEGURIDAD] Omitiendo el envío de correos (enviarMails es falso o no fue suministrado).');
  }
}

/**
 * Carga de forma segura y optimizada el bloque de datos recientes de Actuals (WHS all Data),
 * detectando automáticamente si la hoja está ordenada DESCENDENTE (fechas recientes arriba)
 * o ASCENDENTE (fechas recientes abajo). Pre-parsa fechas en memoria.
 */
function _loadRecentActualsData(actSheet, actHeaders, aDi) {
  if (GLOBAL_AD_CACHE != null && GLOBAL_AD_DATE_STR_CACHE != null && GLOBAL_AD_DATE_MS_CACHE != null) {
    return {
      ad: GLOBAL_AD_CACHE,
      adDateStr: GLOBAL_AD_DATE_STR_CACHE,
      adDateMs: GLOBAL_AD_DATE_MS_CACHE
    };
  }

  var lastPhysicalRow = actSheet.getLastRow();
  if (lastPhysicalRow <= 1) {
    return { ad: [], adDateStr: [], adDateMs: [] };
  }

  // Detección ultrarrápida y precisa de ordenación (compara fila 2 con la última fila)
  var firstVal = actSheet.getRange(2, aDi + 1, 1, 1).getValue();
  var lastVal = actSheet.getRange(lastPhysicalRow, aDi + 1, 1, 1).getValue();
  var firstMs = parseDateToMs(firstVal);
  var lastMs = parseDateToMs(lastVal);
  var isDescending = true; // Por defecto WHS all Data es descendente
  if (!isNaN(firstMs) && !isNaN(lastMs)) {
    isDescending = (firstMs >= lastMs);
  }

  // Escanear bloque de 3,500 filas (cubre más de 50 días de historia completa de todas las sucursales)
  var startRow, numRows;
  if (isDescending) {
    startRow = 2;
    numRows = Math.min(3500, lastPhysicalRow - 1);
  } else {
    startRow = Math.max(2, lastPhysicalRow - 3500);
    numRows = lastPhysicalRow - startRow + 1;
  }

  var ad = [];
  if (numRows > 0) {
    ad = actSheet.getRange(startRow, 1, numRows, actSheet.getLastColumn()).getValues();
  }
  ad.unshift(actHeaders);
  GLOBAL_AD_CACHE = ad;

  var adDateStr = [];
  var adDateMs = [];
  for (var i = 0; i < ad.length; i++) {
    if (i === 0) {
      adDateStr.push(null);
      adDateMs.push(NaN);
    } else {
      var rawDate = ad[i][aDi];
      var ymd = normalizeDateToYMD(rawDate);
      var tMs = parseDateToMs(rawDate);
      adDateStr.push(ymd);
      adDateMs.push(tMs);
    }
  }
  GLOBAL_AD_DATE_STR_CACHE = adDateStr;
  GLOBAL_AD_DATE_MS_CACHE = adDateMs;

  return { ad: ad, adDateStr: adDateStr, adDateMs: adDateMs };
}

function _analizarAnomaliasDeAyer(forcedDateMs) {
  var actSheet;
  if (GLOBAL_ACT_SHEET_CACHE != null) {
    actSheet = GLOBAL_ACT_SHEET_CACHE;
  } else {
    actSheet = SpreadsheetApp.openById(SPREADSHEET_ID).getSheetByName(SHEET_ACTUALS);
    GLOBAL_ACT_SHEET_CACHE = actSheet;
  }
  
  if (!actSheet) {
    Logger.log('Error: No se encontró la hoja de Actuals "' + SHEET_ACTUALS + '".');
    return null;
  }
  
  var actHeaders;
  if (GLOBAL_HEADERS_CACHE != null) {
    actHeaders = GLOBAL_HEADERS_CACHE;
  } else {
    var lastCol = actSheet.getLastColumn();
    if (lastCol === 0) {
      Logger.log('Error: La hoja de Actuals está completamente vacía.');
      return null;
    }
    actHeaders = actSheet.getRange(1, 1, 1, lastCol).getValues()[0].map(function(h){ return String(h).trim().toLowerCase(); });
    GLOBAL_HEADERS_CACHE = actHeaders;
  }
  
  // Buscar índices de las columnas estructurales en la estructura wide de Warehouse
  var aDi = actHeaders.indexOf('fecha');
  if (aDi === -1) aDi = actHeaders.indexOf('date');
  
  var aCi = actHeaders.indexOf('country_code');
  if (aCi === -1) aCi = actHeaders.indexOf('country');
  
  var aWhName = actHeaders.indexOf('warehouse_name');
  if (aWhName === -1) aWhName = actHeaders.indexOf('warehouse');
  
  var aWhId = actHeaders.indexOf('warehouse_id');
  
  if (aDi === -1 || aCi === -1 || aWhName === -1) {
    Logger.log('[ERROR] No se encontraron las columnas requeridas (fecha, country_code, warehouse_name) en la hoja de Actuals.');
    return null;
  }

  var loadedData = _loadRecentActualsData(actSheet, actHeaders, aDi);
  var ad = loadedData.ad;
  var adDateStr = loadedData.adDateStr;
  var adDateMs = loadedData.adDateMs;
  
  var refDate;
  if (forcedDateMs != null && !isNaN(forcedDateMs)) {
    refDate = new Date(forcedDateMs);
  } else {
    // Buscar la última fecha con datos reales en el sheet de Actuals para evitar fallas por latencia de datos.
    // PROTECCIÓN DE FUTURO: Solo consideramos fechas menores o iguales a la fecha de hoy para evitar que 
    // errores de formato locales o tipeos futuros se elijan por error.
    var maxMs = -Infinity;
    var nowMs = Date.now();
    
    for (var i = 1; i < ad.length; i++) {
      if (ad[i][aDi] && ad[i][aWhName]) {
        var t0 = adDateMs[i];
        if (!isNaN(t0) && t0 <= nowMs && t0 > maxMs) {
          maxMs = t0;
        }
      }
    }
    if (maxMs !== -Infinity) {
      refDate = new Date(maxMs);
    } else {
      refDate = new Date();
      refDate.setDate(refDate.getDate() - 1);
    }
  }
  
  var yesterdayYMD = normalizeDateToYMD(refDate);
  Logger.log('Fecha analizada a nivel Warehouse: ' + yesterdayYMD);
  
  var endMs = refDate.getTime();
  var startMs = endMs - (30 * 24 * 60 * 60 * 1000); // 30 días de ventana de seguridad para L3W (cubre D-21 sin cortes por zona horaria)
  
  // Agrupar filas por [WarehouseName][YMD]
  var componentsByWarehouseAndDate = {};
  
  for (var i = 1; i < ad.length; i++) {
    var rawWhName = ad[i][aWhName];
    if (!rawWhName) continue;
    
    var ymd = adDateStr[i];
    if (!ymd) continue;
    
    var tMs = adDateMs[i];
    if (isNaN(tMs) || tMs < startMs || tMs > endMs) continue;
    
    // Crear un objeto con todos los pares clave-valor de la fila
    var comps = {};
    for (var colIdx = 0; colIdx < ad[0].length; colIdx++) {
      comps[actHeaders[colIdx]] = ad[i][colIdx];
    }
    // Mapeo explícito de columna J (índice 9 en 0-based, columna 10 física) para Weighted Open time %
    if (ad[i].length > 9) {
      comps['__col_j__'] = ad[i][9];
      if (comps['open_time'] === undefined) comps['open_time'] = ad[i][9];
    }
    
    var whKey = String(rawWhName).trim();
    if (!componentsByWarehouseAndDate[whKey]) {
      componentsByWarehouseAndDate[whKey] = {};
    }
    componentsByWarehouseAndDate[whKey][ymd] = comps;
  }
  
  var alertas = [];
  var warehouses = Object.keys(componentsByWarehouseAndDate);
  
  warehouses.forEach(function(wh) {
    METRICS_TO_ALERT.forEach(function(mDef) {
      var compsAyer = componentsByWarehouseAndDate[wh][yesterdayYMD];
      var valAyer = calculateMetric(mDef.key, compsAyer);
      if (valAyer == null) return;
      
      var valEsperado = null;
      var baselineUsada = mDef.baseline;
      
      if (baselineUsada === 'L3W') {
        var d7 = addDaysYMD(yesterdayYMD, -7);
        var d14 = addDaysYMD(yesterdayYMD, -14);
        var d21 = addDaysYMD(yesterdayYMD, -21);
        
        var v7 = calculateMetric(mDef.key, componentsByWarehouseAndDate[wh][d7]);
        var v14 = calculateMetric(mDef.key, componentsByWarehouseAndDate[wh][d14]);
        var v21 = calculateMetric(mDef.key, componentsByWarehouseAndDate[wh][d21]);
        
        var sum = 0, count = 0;
        if (v7 != null) { sum += v7; count++; }
        if (v14 != null) { sum += v14; count++; }
        if (v21 != null) { sum += v21; count++; }
        
        if (count > 0) valEsperado = sum / count;
      } else {
        var sum = 0, count = 0;
        for (var dOffset = 1; dOffset <= 7; dOffset++) {
          var ymdOffset = addDaysYMD(yesterdayYMD, -dOffset);
          var vOffset = calculateMetric(mDef.key, componentsByWarehouseAndDate[wh][ymdOffset]);
          if (vOffset != null) { sum += vOffset; count++; }
        }
        if (count > 0) valEsperado = sum / count;
      }
      
      if (valEsperado == null) {
        if (mDef.key === 'open_time') valEsperado = 0.90;
        else if (mDef.key === 'assignment_time_over_6m') valEsperado = 0.30;
        else if (mDef.key === 'rejected_orders') valEsperado = 0.03;
        else if (mDef.key === 'forced_preorders') valEsperado = 0.025;
        else return;
      }
      
      var targetVal = null; // No comparamos contra target país para evitar inconsistencias a nivel warehouse
        
      var res = mDef.check(valAyer, valEsperado, targetVal);
      if (res && res.triggered) {
        alertas.push({
          fecha: yesterdayYMD, // Añadido para que el front cargue el selector de fecha y cierres correctamente in vivo
          pais: wh, // Almacenamos el nombre del warehouse en la columna de 'Pais' para que se renderice directamente en el front
          metricaKey: mDef.key,
          metricaLabel: mDef.label,
          valorReal: valAyer,
          valorEsperado: res.expected,
          desvio: res.desvio,
          tipoBaseline: mDef.baseline, // 'L3W' o '7D'
          detalles: res.details,
          formato: mDef.format
        });
      }
    });
  });
  
  return { alertas: alertas, yesterdayYMD: yesterdayYMD };
}

// =================================================================
// ── DISTRIBUCIÓN DE CORREOS BASADOS EN SUSCRIPCIONES ─────────────
// =================================================================

// =================================================================
// ── DISTRIBUCIÓN DE CORREOS BASADOS EN SUSCRIPCIONES ─────────────
// =================================================================

function _enviarCorreosBasadosEnSuscripciones(alertas, yesterdayYMD, isForced) {
  Logger.log("📬 Iniciando distribución agrupada (BCC) de correos premium...");
  
  var mode = getEmailSendingMode();
  if (mode === 'DISABLED') {
    Logger.log("🚫 [SEGURIDAD] El envío de correos está configurado como DESHABILITADO (DISABLED). Se aborta la distribución de correos.");
    return;
  }

  // Verificar idempotencia (evitar doble envío en producción para la misma fecha)
  if (mode === 'PRODUCTION' && isForced !== true) {
    try {
      var yaEnviado = PropertiesService.getScriptProperties().getProperty("LAST_EMAIL_SENT_DATE_" + yesterdayYMD);
      if (yaEnviado === "SENT") {
        Logger.log("⚠️ [SEGURIDAD] Los correos para la fecha de cierre " + yesterdayYMD + " ya fueron enviados hoy en producción. Omitiendo duplicados por seguridad.");
        return;
      }
    } catch(err) {
      Logger.log("Error consultando script properties de idempotencia: " + err.toString());
    }
  }

  var suscripciones = getSubscriptionsFromDb();
  
  // 1. Agrupar suscripciones por preferencias idénticas para consolidar envíos
  var grupos = {};
  suscripciones.forEach(function(sub) {
    if (!sub.activo || !sub.email) return;
    
    // Normalizar de forma proactiva los países de la suscripción a códigos ISO (ej: 'RD' -> 'DO', 'TODOS' -> 'LATAM')
    if (sub.paises && sub.paises.length > 0) {
      sub.paises = sub.paises.map(function(c) {
        var iso = getISO(c);
        if (iso === 'TODOS' || iso === 'LATAM') {
          return 'LATAM';
        }
        return iso;
      });
      // Eliminar duplicados
      sub.paises = sub.paises.filter(function(item, pos, self) {
        return self.indexOf(item) === pos;
      });
    } else {
      sub.paises = ['LATAM'];
    }

    // Normalizar de forma proactiva las métricas
    if (sub.metricas && sub.metricas.length > 0) {
      sub.metricas = sub.metricas.map(function(m) {
        var metricKey = String(m).trim().toLowerCase();
        if (metricKey === 'todas') return 'TODAS';
        return metricKey;
      });
      // Eliminar duplicados
      sub.metricas = sub.metricas.filter(function(item, pos, self) {
        return self.indexOf(item) === pos;
      });
    } else {
      sub.metricas = ['TODAS'];
    }

    // Normalizar de forma proactiva los warehouses
    if (sub.warehouses && sub.warehouses.length > 0) {
      sub.warehouses = sub.warehouses.map(function(w) {
        return String(w).trim().toUpperCase();
      });
      sub.warehouses = sub.warehouses.filter(function(item, pos, self) {
        return self.indexOf(item) === pos;
      });
    } else {
      sub.warehouses = [];
    }
    
    // Crear una clave única de grupo basada en los filtros ordenados
    var paisesKey = (sub.paises || []).slice().sort().join(',');
    var warehousesKey = (sub.warehouses || []).slice().sort().join(',');
    var metricasKey = (sub.metricas || []).slice().sort().join(',');
    var uniqueKey = paisesKey + '|' + warehousesKey + '|' + metricasKey;
    
    if (!grupos[uniqueKey]) {
      grupos[uniqueKey] = {
        sub: sub, // Guardar una suscripción representativa para el filtro
        emails: []
      };
    }
    // Evitar duplicar correos de un mismo usuario dentro del mismo grupo
    if (grupos[uniqueKey].emails.indexOf(sub.email) === -1) {
      grupos[uniqueKey].emails.push(sub.email);
    }
  });
  
  var totalEnviados = 0;
  
  // 2. Procesar y enviar por cada grupo de suscripción único
  Object.keys(grupos).forEach(function(key) {
    var grupo = grupos[key];
    var sub = grupo.sub;
    var emails = grupo.emails;
    
    var paisesSub = sub.paises || [];
    var warehousesSub = sub.warehouses || [];
    var metricasSub = sub.metricas || [];
    
    // Filtrar alertas para este grupo de usuarios
    var alertasFiltradas = alertas.filter(function(a) {
      var rawCc = String(a.pais || '').split('_')[0].toUpperCase();
      var subCountryCode = getISO(rawCc);
      if (subCountryCode === 'CH') subCountryCode = 'CL';
      if (subCountryCode === 'RD') subCountryCode = 'DO';
      
      // Comprobar coincidencia de país (si está suscrito a TODOS, a LATAM, o al país de la alerta)
      var paisOk = paisesSub.indexOf("TODOS") !== -1 || 
                   paisesSub.indexOf("LATAM") !== -1 || 
                   paisesSub.indexOf(subCountryCode) !== -1 ||
                   paisesSub.indexOf(rawCc) !== -1;

      // Comprobar coincidencia de warehouse (si está suscrito a TODOS, si el array está vacío, o al warehouse específico)
      var whUpper = String(a.pais || '').trim().toUpperCase();
      var whsOk = warehousesSub.length === 0 || 
                  warehousesSub.indexOf("TODOS") !== -1 || 
                  warehousesSub.some(function(w) { return String(w).trim().toUpperCase() === whUpper; });

      // Comprobar coincidencia de métrica
      var metricKey = a.metricaKey || (typeof getMetricaKeyByLabel === 'function' ? getMetricaKeyByLabel(a.metricaLabel) : a.metricaLabel);
      var mKeyLower = String(metricKey || '').toLowerCase();
      var mLabelLower = String(a.metricaLabel || '').toLowerCase();
      var metricaOk = metricasSub.indexOf("TODAS") !== -1 || 
                      metricasSub.indexOf(mKeyLower) !== -1 || 
                      metricasSub.indexOf(mLabelLower) !== -1;

      return paisOk && whsOk && metricaOk;
    });
    
    Logger.log("📬 Enviando lote BCC (" + emails.length + " usuarios) para el perfil: " + key);
    try {
      // Pasar el array de correos a la función de envío
      enviarNewsletterDeAlertas(emails, yesterdayYMD, alertasFiltradas, sub);
      totalEnviados += emails.length;
      
      // Registrar el envío individual en los logs
      emails.forEach(function(email) {
        logAccess(email, 'Email Sent (BCC Batch): ' + alertasFiltradas.length + ' alerts (PREMIUM)');
      });
    } catch(e) {
      Logger.log("❌ Error enviando mail agrupado BCC a " + emails.join(', ') + ": " + e.toString());
    }
  });
  
  // Guardar marca de envío exitoso para la fecha analizada en modo de producción
  if (mode === 'PRODUCTION') {
    try {
      PropertiesService.getScriptProperties().setProperty("LAST_EMAIL_SENT_DATE_" + yesterdayYMD, "SENT");
      Logger.log("💾 [SEGURIDAD] Registrada la marca de envío exitoso para ayer: " + yesterdayYMD);
    } catch(err) {
      Logger.log("Error guardando marca de envío exitoso: " + err.toString());
    }
  }

  Logger.log("✓ Distribución de correos finalizada de forma segura. Total de destinatarios alcanzados: " + totalEnviados);
}

// =================================================================
// ── UTILERÍAS COMPLEMENTARIAS ────────────────────────────────────
// =================================================================

function calculateMetric(key, comps) {
  if (!comps) return null;
  
  // Mapear métricas de la estructura "wide" a nivel Warehouse con paridad matemática al 100% con el Daily Report
  switch (key) {
    case 'orders':
      var rawOrders = comps['confirmed_orders'];
      if (rawOrders === '' || rawOrders == null) rawOrders = comps['orders'];
      if (rawOrders === '' || rawOrders == null) return null;
      var numOrders = parseFloat(rawOrders);
      return isNaN(numOrders) ? null : numOrders;
    case 'gmv':
      var rawGmv = comps['gmv'];
      if (rawGmv === '' || rawGmv == null) return null;
      var numGmv = parseFloat(rawGmv);
      return isNaN(numGmv) ? null : numGmv;
    case 'new_users':
      var rawUsers = comps['new_users'];
      if (rawUsers === '' || rawUsers == null) return null;
      var numUsers = parseFloat(rawUsers);
      return isNaN(numUsers) ? null : numUsers;
    case 'wis':
      var den = parseFloat(comps['wis_denominador']) || 0;
      return den > 0 ? (parseFloat(comps['wis_numerador']) || 0) / den : null;
    case 'wis_uf':
      var den = parseFloat(comps['wis_uf_denominador']) || 0;
      return den > 0 ? (parseFloat(comps['wis_uf_numerador']) || 0) / den : null;
    case 'seamless':
      var den = parseFloat(comps['total_orders_all_status']) || parseFloat(comps['total_orders']) || 0;
      var num = parseFloat(comps['seamless_delivery']) || parseFloat(comps['seamless_numerador']) || 0;
      return den > 0 ? num / den : null;
    case 'delivery_time':
      var den = parseFloat(comps['non_forced_completed_orders_logistics']) || parseFloat(comps['delivery_time_order_count']) || 0;
      return den > 0 ? (parseFloat(comps['delivery_time_sum']) || 0) / den : null;
    case 'assignment_time':
      var den = parseFloat(comps['assignment_time_order_count']) || parseFloat(comps['picker_shift_confirmed_orders']) || parseFloat(comps['assignment_time_confirmed_orders']) || 0;
      return den > 0 ? (parseFloat(comps['assignment_time_sum']) || 0) / den : null;
    case 'rejected_orders':
      var den = parseFloat(comps['total_orders_all_status']) || parseFloat(comps['total_orders']) || 0;
      return den > 0 ? (parseFloat(comps['rejected_orders']) || 0) / den : null;
    case 'session_orders':
      var den = parseFloat(comps['total_orders_all_status']) || parseFloat(comps['total_orders']) || 0;
      return den > 0 ? (parseFloat(comps['session_orders']) || 0) / den : null;
    case 'late_orders':
      var den = parseFloat(comps['total_orders_all_status']) || parseFloat(comps['total_orders']) || 0;
      return den > 0 ? (parseFloat(comps['late_orders']) || 0) / den : null;
    case 'slow_orders':
      var den = parseFloat(comps['total_orders_all_status']) || parseFloat(comps['total_orders']) || 0;
      return den > 0 ? (parseFloat(comps['slow_orders']) || 0) / den : null;
    case 'forced_preorders':
      var den = parseFloat(comps['total_orders_all_status']) || parseFloat(comps['total_orders']) || 0;
      return den > 0 ? (parseFloat(comps['forced_preorders']) || 0) / den : null;
    case 'modified_orders':
      var den = parseFloat(comps['total_orders_all_status']) || parseFloat(comps['total_orders']) || 0;
      return den > 0 ? (parseFloat(comps['modified_orders']) || 0) / den : null;
    case 'assignment_time_over_6m':
      var den = parseFloat(comps['assignment_time_order_count']) || parseFloat(comps['picker_shift_confirmed_orders']) || parseFloat(comps['assignment_time_confirmed_orders']) || 0;
      var num = parseFloat(comps['assignment_time_orders_over_6min']) || parseFloat(comps['assignment_time_over_6m']) || parseFloat(comps['assignment_time_over_6min']) || parseFloat(comps['orders_over_6min']) || parseFloat(comps['saturation_orders_over_6min']) || 0;
      return den > 0 ? num / den : null;
    case 'open_time':
      var rawOpen = comps['open_time'];
      if (rawOpen === '' || rawOpen == null) rawOpen = comps['__col_j__'];
      if (rawOpen === '' || rawOpen == null) rawOpen = comps['weighted_open_time'];
      if (rawOpen === '' || rawOpen == null) rawOpen = comps['weighted_open_time_percent'];
      if (rawOpen === '' || rawOpen == null) return null;
      var numOpen = parseFloat(rawOpen);
      if (isNaN(numOpen)) return null;
      if (numOpen > 1.0) numOpen = numOpen / 100;
      return numOpen;
    default:
      var val = comps[key];
      if (val === '' || val == null) return null;
      var num = parseFloat(val);
      return isNaN(num) ? null : num;
  }
}

/**
 * Valida si una fila cruda de warehouse contiene datos reales para una métrica específica.
 */
function hasMetricDataInRow(key, comps) {
  if (!comps) return false;
  switch (key) {
    case 'orders':
      var co = comps['confirmed_orders'];
      if (co === '' || co == null) co = comps['orders'];
      return co !== '' && co != null && !isNaN(parseFloat(co));
    case 'gmv':
      var g = comps['gmv'];
      return g !== '' && g != null && !isNaN(parseFloat(g));
    case 'new_users':
      var nu = comps['new_users'];
      return nu !== '' && nu != null && !isNaN(parseFloat(nu));
    case 'wis':
      var den = parseFloat(comps['wis_denominador']);
      var num = parseFloat(comps['wis_numerador']);
      return !isNaN(den) && den > 0 && !isNaN(num);
    case 'wis_uf':
      var den = parseFloat(comps['wis_uf_denominador']);
      var num = parseFloat(comps['wis_uf_numerador']);
      return !isNaN(den) && den > 0 && !isNaN(num);
    case 'seamless':
      var den = parseFloat(comps['total_orders_all_status']) || parseFloat(comps['total_orders']);
      var num = parseFloat(comps['seamless_delivery']) || parseFloat(comps['seamless_numerador']);
      return !isNaN(den) && den > 0 && !isNaN(num);
    case 'delivery_time':
      var den = parseFloat(comps['non_forced_completed_orders_logistics']) || parseFloat(comps['delivery_time_order_count']);
      var num = parseFloat(comps['delivery_time_sum']);
      return !isNaN(den) && den > 0 && !isNaN(num);
    case 'assignment_time':
      var den = parseFloat(comps['assignment_time_order_count']) || parseFloat(comps['picker_shift_confirmed_orders']) || parseFloat(comps['assignment_time_confirmed_orders']);
      var num = parseFloat(comps['assignment_time_sum']);
      return !isNaN(den) && den > 0 && !isNaN(num);
    case 'rejected_orders':
      var den = parseFloat(comps['total_orders_all_status']) || parseFloat(comps['total_orders']);
      var num = parseFloat(comps['rejected_orders']);
      return !isNaN(den) && den > 0 && !isNaN(num);
    case 'session_orders':
      var den = parseFloat(comps['total_orders_all_status']) || parseFloat(comps['total_orders']);
      var num = parseFloat(comps['session_orders']);
      return !isNaN(den) && den > 0 && !isNaN(num);
    case 'late_orders':
      var den = parseFloat(comps['total_orders_all_status']) || parseFloat(comps['total_orders']);
      var num = parseFloat(comps['late_orders']);
      return !isNaN(den) && den > 0 && !isNaN(num);
    case 'slow_orders':
      var den = parseFloat(comps['total_orders_all_status']) || parseFloat(comps['total_orders']);
      var num = parseFloat(comps['slow_orders']);
      return !isNaN(den) && den > 0 && !isNaN(num);
    case 'forced_preorders':
      var den = parseFloat(comps['total_orders_all_status']) || parseFloat(comps['total_orders']);
      var num = parseFloat(comps['forced_preorders']);
      return !isNaN(den) && den > 0 && !isNaN(num);
    case 'modified_orders':
      var den = parseFloat(comps['total_orders_all_status']) || parseFloat(comps['total_orders']);
      var num = parseFloat(comps['modified_orders']);
      return !isNaN(den) && den > 0 && !isNaN(num);
    case 'assignment_time_over_6m':
      var den = parseFloat(comps['assignment_time_order_count']) || parseFloat(comps['picker_shift_confirmed_orders']) || parseFloat(comps['assignment_time_confirmed_orders']);
      var num = parseFloat(comps['assignment_time_orders_over_6min']) || parseFloat(comps['assignment_time_over_6m']) || parseFloat(comps['assignment_time_over_6min']) || parseFloat(comps['orders_over_6min']) || parseFloat(comps['saturation_orders_over_6min']);
      return !isNaN(den) && den > 0 && !isNaN(num);
    case 'open_time':
      var rawOpen = comps['open_time'];
      if (rawOpen === '' || rawOpen == null) rawOpen = comps['__col_j__'];
      if (rawOpen === '' || rawOpen == null) rawOpen = comps['weighted_open_time'];
      return rawOpen !== '' && rawOpen != null && !isNaN(parseFloat(rawOpen));
    default:
      var val = comps[key];
      return val !== '' && val != null && !isNaN(parseFloat(val));
  }
}

/**
 * Escanea los datos reales de WHS all Data y genera un mapa de disponibilidad de métricas
 * tanto a nivel global como por país para cada fecha evaluada.
 */
function _getMetricsAvailability(forceRecalc) {
  if (forceRecalc !== true && GLOBAL_METRICS_AVAILABILITY_CACHE != null) {
    return GLOBAL_METRICS_AVAILABILITY_CACHE;
  }

  var cache = CacheService.getScriptCache();
  if (forceRecalc !== true) {
    var cached = cache.get('METRICS_AVAIL_CACHE_V4');
    if (cached) {
      try {
        var parsed = JSON.parse(cached);
        GLOBAL_METRICS_AVAILABILITY_CACHE = parsed;
        return parsed;
      } catch (e) {}
    }
  }

  var actSheet;
  if (GLOBAL_ACT_SHEET_CACHE != null) {
    actSheet = GLOBAL_ACT_SHEET_CACHE;
  } else {
    actSheet = SpreadsheetApp.openById(SPREADSHEET_ID).getSheetByName(SHEET_ACTUALS);
    GLOBAL_ACT_SHEET_CACHE = actSheet;
  }
  
  if (!actSheet) {
    Logger.log('[ERROR] No se encontro la hoja de Actuals "' + SHEET_ACTUALS + '".');
    return {};
  }
  
  var actHeaders;
  if (GLOBAL_HEADERS_CACHE != null) {
    actHeaders = GLOBAL_HEADERS_CACHE;
  } else {
    var lastCol = actSheet.getLastColumn();
    if (lastCol === 0) return {};
    actHeaders = actSheet.getRange(1, 1, 1, lastCol).getValues()[0].map(function(h){ return String(h).trim().toLowerCase(); });
    GLOBAL_HEADERS_CACHE = actHeaders;
  }

  var aDi = actHeaders.indexOf('fecha');
  if (aDi === -1) aDi = actHeaders.indexOf('date');
  var aCi = actHeaders.indexOf('country_code');
  if (aCi === -1) aCi = actHeaders.indexOf('country');
  var aWhName = actHeaders.indexOf('warehouse_name');
  if (aWhName === -1) aWhName = actHeaders.indexOf('warehouse');

  if (aDi === -1 || aCi === -1 || aWhName === -1) return {};

  var loadedData = _loadRecentActualsData(actSheet, actHeaders, aDi);
  var ad = loadedData.ad;
  var adDateStr = loadedData.adDateStr;

  var metricKeys = METRICS_TO_ALERT.map(function(m) { return m.key; });

  var dateCountryMetrics = {};
  var dateGlobalMetrics = {};
  var dateWhMissing = {};
  var datesSet = {};

  for (var i = 1; i < ad.length; i++) {
    var ymd = adDateStr[i];
    if (!ymd) continue;

    var rawWhName = ad[i][aWhName];
    if (!rawWhName) continue;
    var whKey = String(rawWhName).trim();

    var rawCc = ad[i][aCi] ? String(ad[i][aCi]).trim().toUpperCase() : '';
    if (!rawCc && rawWhName) {
      rawCc = String(rawWhName).split('_')[0].toUpperCase();
    }
    var cc = getISO(rawCc);
    if (cc === 'CH') cc = 'CL';
    if (cc === 'RD') cc = 'DO';

    datesSet[ymd] = true;
    if (!dateGlobalMetrics[ymd]) dateGlobalMetrics[ymd] = {};
    if (!dateCountryMetrics[ymd]) dateCountryMetrics[ymd] = {};
    if (!dateCountryMetrics[ymd][cc]) dateCountryMetrics[ymd][cc] = {};
    if (!dateWhMissing[ymd]) dateWhMissing[ymd] = {};
    if (!dateWhMissing[ymd][whKey]) dateWhMissing[ymd][whKey] = [];

    var comps = {};
    for (var col = 0; col < actHeaders.length; col++) {
      comps[actHeaders[col]] = ad[i][col];
    }
    // Mapeo explícito de columna J (índice 9 en 0-based, columna 10 física) para Weighted Open time %
    if (ad[i].length > 9) {
      comps['__col_j__'] = ad[i][9];
      if (comps['open_time'] === undefined) comps['open_time'] = ad[i][9];
    }

    for (var m = 0; m < metricKeys.length; m++) {
      var mKey = metricKeys[m];
      var hasData = hasMetricDataInRow(mKey, comps);
      if (hasData) {
        dateGlobalMetrics[ymd][mKey] = (dateGlobalMetrics[ymd][mKey] || 0) + 1;
        dateCountryMetrics[ymd][cc][mKey] = (dateCountryMetrics[ymd][cc][mKey] || 0) + 1;
      } else {
        dateWhMissing[ymd][whKey].push(mKey);
      }
    }
  }

  var result = {};
  var allDates = Object.keys(datesSet);

  allDates.forEach(function(ymd) {
    var unavailGlobal = [];
    metricKeys.forEach(function(mKey) {
      if (!dateGlobalMetrics[ymd] || !dateGlobalMetrics[ymd][mKey] || dateGlobalMetrics[ymd][mKey] === 0) {
        unavailGlobal.push(mKey);
      }
    });

    var unavailByCountry = {};
    var countriesInDate = Object.keys(dateCountryMetrics[ymd] || {});
    countriesInDate.forEach(function(cc) {
      unavailByCountry[cc] = [];
      metricKeys.forEach(function(mKey) {
        if (!dateCountryMetrics[ymd][cc] || !dateCountryMetrics[ymd][cc][mKey] || dateCountryMetrics[ymd][cc][mKey] === 0) {
          unavailByCountry[cc].push(mKey);
        }
      });
    });

    result[ymd] = {
      hasAnyData: true,
      unavailableGlobal: unavailGlobal,
      unavailableByCountry: unavailByCountry,
      missingByWarehouse: dateWhMissing[ymd] || {}
    };
  });

  GLOBAL_METRICS_AVAILABILITY_CACHE = result;
  try {
    cache.put('METRICS_AVAIL_CACHE_V4', JSON.stringify(result), 1800);
  } catch(e) {}
  return result;
}

function normalizeDateToYMD(raw) {
  if (!raw) return null;
  if (raw instanceof Date) {
    var y = raw.getFullYear();
    var m = ('0' + (raw.getMonth() + 1)).slice(-2);
    var d = ('0' + raw.getDate()).slice(-2);
    return y + '-' + m + '-' + d;
  }
  var s = String(raw).trim();
  if (/^\d{4}-\d{2}-\d{2}$/.test(s)) return s;
  var m1 = s.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/);
  if (m1) return m1[3]+'-'+('0'+m1[2]).slice(-2)+'-'+('0'+m1[1]).slice(-2);
  
  var d = new Date(s);
  if (!isNaN(d.getTime())) {
    var y = d.getFullYear();
    var m = ('0' + (d.getMonth() + 1)).slice(-2);
    var day = ('0' + d.getDate()).slice(-2);
    return y + '-' + m + '-' + day;
  }
  return null;
}

function addDaysYMD(ymd, days) {
  var p = ymd.split('-');
  var d = new Date(parseInt(p[0]), parseInt(p[1])-1, parseInt(p[2]));
  d.setDate(d.getDate() + days);
  var y = d.getFullYear();
  var m = ('0' + (d.getMonth() + 1)).slice(-2);
  var day = ('0' + d.getDate()).slice(-2);
  return y + '-' + m + '-' + day;
}

function getISO(raw) {
  var PAIS_ISO = {
    'argentina':'AR','bolivia':'BO','chile':'CL','colombia':'CO','costa rica':'CR',
    'ecuador':'EC','el salvador':'SV','guatemala':'GT','honduras':'HN','nicaragua':'NI',
    'panama':'PA','panamá':'PA','paraguay':'PY','peru':'PE','perú':'PE','uruguay':'UY',
    'republica dominicana':'DO','república dominicana':'DO','rep. dominicana':'DO',
    'dominican republic':'DO','mexico':'MX','méxico':'MX',
    'ar':'AR','bo':'BO','cl':'CL','ch':'CL','co':'CO','cr':'CR','ec':'EC','sv':'SV','gt':'GT',
    'hn':'HN','ni':'NI','pa':'PA','py':'PY','pe':'PE','uy':'UY','do':'DO','rd':'DO','mx':'MX',
    'latam':'LATAM','latin america':'LATAM'
  };
  var s = String(raw||'').trim().toLowerCase();
  return PAIS_ISO[s] || String(raw||'').trim().toUpperCase();
}

function parseDateToMs(raw) {
  if (!raw) return NaN;
  var ymd = normalizeDateToYMD(raw);
  if (!ymd) return NaN;
  var p = ymd.split('-');
  return new Date(parseInt(p[0]), parseInt(p[1])-1, parseInt(p[2])).getTime();
}

function _fmtVal(v, fmt) {
  if (v == null || isNaN(v)) return '—';
  if (fmt === 'int') return Math.round(v).toLocaleString('es-AR');
  if (fmt === 'eur') {
    if (v >= 1000000) return (v / 1000000).toFixed(2) + 'M €';
    if (v >= 1000) return (v / 1000).toFixed(1) + 'k €';
    return v.toFixed(2) + ' €';
  }
  if (fmt === 'pct') return (v * 100).toFixed(1) + '%';
  if (fmt === 'min') return v.toFixed(1) + ' min';
  return v.toString();
}

var FULL_COUNTRY_NAMES_ALERT = {
  'AR':'Argentina','BO':'Bolivia','CL':'Chile','CH':'Chile','CO':'Colombia',
  'EC':'Ecuador','SV':'El Salvador','GT':'Guatemala','HN':'Honduras','NI':'Nicaragua',
  'PA':'Panamá','PY':'Paraguay','PE':'Perú','UY':'Uruguay','DO':'Rep. Dominicana','RD':'Rep. Dominicana'
};

function backfillAlertsHistory(startDateStr, endDateStr) {
  Logger.log('Iniciando backfill histórico optimizado desde ' + startDateStr + ' hasta ' + endDateStr);
  var start = new Date(startDateStr);
  var end = new Date(endDateStr);
  
  // 1. Obtener todas las fechas del rango
  var fechasTargetMap = {};
  var fechasTargetList = [];
  var current = new Date(start.getTime());
  while (current <= end) {
    var dayStr = normalizeDateToYMD(current);
    fechasTargetMap[dayStr] = true;
    fechasTargetList.push({
      date: new Date(current.getTime()),
      dayStr: dayStr
    });
    current.setDate(current.getDate() + 1);
  }
  
  // Ordenar de más reciente a más antigua (de forma descendente) para procesar del día más actual hacia atrás
  fechasTargetList.sort(function(a, b) {
    return b.dayStr.localeCompare(a.dayStr);
  });
  
  // 2. Limpieza completa de la hoja de destino (borrado físico total excepto encabezados)
  Logger.log('Borrando todas las filas de Alertas_Historial para recargarlas por completo...');
  var sheet = _getDbSheet('Alertas_Historial');
  var lastRow = sheet.getLastRow();
  
  if (lastRow > 1) {
    sheet.deleteRows(2, lastRow - 1);
    SpreadsheetApp.flush();
    Logger.log('Se borraron físicamente ' + (lastRow - 1) + ' registros antiguos. La hoja está vacía y lista para la recarga completa.');
  } else {
    Logger.log('La hoja ya está vacía (solo tiene encabezados).');
  }
  
  // 3. Cargar coordenadas frescas directamente de la planilla maestra vinculada (GID: 1805962870)
  Logger.log('Cargando mapa dinámico de coordenadas desde la planilla maestra vinculada (GID: ' + WHS_MASTER_DATA_SHEET_GID + ')...');
  var coordsMap = getWarehouseCoordinatesMap(true);
  Logger.log('Coordenadas maestras cargadas: ' + Object.keys(coordsMap).length + ' entradas.');

  // 4. Procesar las fechas en orden descendente (más actual primero)
  for (var k = 0; k < fechasTargetList.length; k++) {
    var dateObj = fechasTargetList[k].date;
    var dayStr = fechasTargetList[k].dayStr;
    
    Logger.log('Procesando día: ' + dayStr + ' (' + (k + 1) + '/' + fechasTargetList.length + ')');
    
    // Cambiamos temporalmente LAST_VALID_DATE en ScriptProperties por compatibilidad
    try {
      PropertiesService.getScriptProperties().setProperty('LAST_VALID_DATE', String(dateObj.getTime()));
    } catch(e) {
      Logger.log('Error setting property: ' + e);
    }
    
    var resultado = _analizarAnomaliasDeAyer(dateObj.getTime());
    if (resultado && resultado.alertas && resultado.alertas.length > 0) {
      Logger.log('Guardando ' + resultado.alertas.length + ' alertas para el día ' + dayStr + ' (Inserción directa rápida)');
      
      enrichAlertsWithPrecipitation(resultado.alertas, dayStr, coordsMap);

      // En vez de hacer un guardado lento reescribiendo toda la hoja, hacemos un append directo rápido
      var rowsToWrite = resultado.alertas.map(function(a) {
        var lluviaVal = (a.lluvia_mm !== undefined && a.lluvia_mm !== null && !isNaN(a.lluvia_mm)) ? a.lluvia_mm : '';
        return [
          dayStr,
          a.pais,
          a.metricaLabel,
          a.valorReal,
          a.valorEsperado,
          a.desvio,
          a.detalles,
          lluviaVal
        ];
      });
      
      var lastRow = sheet.getLastRow();
      sheet.getRange(lastRow + 1, 1, rowsToWrite.length, 8).setValues(rowsToWrite);
    } else {
      Logger.log('No se encontraron anomalías para ' + dayStr);
    }
  }
  
  // 4. Limpiar LAST_VALID_DATE al terminar
  try {
    PropertiesService.getScriptProperties().deleteProperty('LAST_VALID_DATE');
  } catch(e) {}
  
  SpreadsheetApp.flush();
  Logger.log('Backfill completado exitosamente.');
}

function _getMasterCountriesAndWarehouses(forceRecalc) {
  var cache = CacheService.getScriptCache();
  if (forceRecalc !== true) {
    var cached = cache.get('MASTER_COUNTRIES_AND_WHS_v1');
    if (cached) {
      try {
        return JSON.parse(cached);
      } catch(e) {
        Logger.log("Error parseando master countries/whs cache, recalculando...");
      }
    }
  }

  var actSheet;
  if (GLOBAL_ACT_SHEET_CACHE != null) {
    actSheet = GLOBAL_ACT_SHEET_CACHE;
  } else {
    actSheet = SpreadsheetApp.openById(SPREADSHEET_ID).getSheetByName(SHEET_ACTUALS);
    GLOBAL_ACT_SHEET_CACHE = actSheet;
  }
  
  if (!actSheet) {
    return { countriesList: [], warehousesList: [] };
  }

  var lastCol = actSheet.getLastColumn();
  if (lastCol === 0) return { countriesList: [], warehousesList: [] };
  var actHeaders = actSheet.getRange(1, 1, 1, lastCol).getValues()[0].map(function(h){ return String(h).trim().toLowerCase(); });
  
  var aCi = actHeaders.indexOf('country_code');
  if (aCi === -1) aCi = actHeaders.indexOf('country');
  
  var aWhName = actHeaders.indexOf('warehouse_name');
  if (aWhName === -1) aWhName = actHeaders.indexOf('warehouse');

  if (aCi === -1 || aWhName === -1) {
    return { countriesList: [], warehousesList: [] };
  }

  var lastPhysicalRow = actSheet.getLastRow();
  var numRows = Math.min(8000, lastPhysicalRow - 1);
  var data = [];
  
  if (numRows > 0) {
    data = actSheet.getRange(2, 1, numRows, actSheet.getLastColumn()).getValues();
  }

  var countriesSet = {};
  var whsSet = {};

  data.forEach(function(row) {
    var rawCC = row[aCi];
    var rawWh = row[aWhName];
    if (rawCC && rawWh) {
      var cc = String(rawCC).toUpperCase().trim();
      if (cc !== 'MX' && cc !== 'CR' && cc !== 'VE' && cc !== 'VENEZUELA' && cc !== 'COSTA RICA' && cc !== 'MEXICO') {
        countriesSet[cc] = true;
        whsSet[String(rawWh).trim()] = true;
      }
    }
  });

  var countriesList = Object.keys(countriesSet).sort().map(function(cc) {
    return { key: cc, label: FULL_COUNTRY_NAMES_ALERT[cc] || cc };
  });

  var warehousesList = Object.keys(whsSet).sort();

  var res = {
    countriesList: countriesList,
    warehousesList: warehousesList
  };

  try {
    cache.put('MASTER_COUNTRIES_AND_WHS_v1', JSON.stringify(res), 86400); // Guardar por 24 horas
  } catch(e) {
    Logger.log("Error guardando master cache: " + e);
  }

  return res;
}

/*
 =================================================================
  HISTORIAL DE CORRECCIONES (v2.0)
 =================================================================
 
 1.  **CRASH AL LEER HOJAS VACÍAS (Error Fatal del Servidor)**
     - **Problema:** El código fallaba con un error irrecuperable si la hoja de cálculo de `Actuals` o de `Suscripciones` estaba completamente vacía (0 filas o 0 columnas).
     - **Causa:** Las funciones `sheet.getLastRow()` y `sheet.getLastColumn()` devolvían 0, y luego se intentaba usar `sheet.getRange(..., 0, ...)` lo cual está prohibido en Apps Script.
     - **Solución:** Se agregaron validaciones explícitas en `_analizarAnomaliasDeAyer`, `_getMasterCountriesAndWarehouses` y `_getDbSheet` para comprobar si el número de filas o columnas es 0. Si lo es, el proceso ahora continúa con una lista vacía en lugar de fallar.
 
 2.  **CRASH AL LEER HOJAS CON SOLO ENCABEZADOS (Error de Rango)**
     - **Problema:** Similar al anterior, si la hoja tenía solo la fila de encabezados, el código intentaba leer un rango de datos con un número de filas igual a 0 (ej: `getLastRow()` es 1, `numRows` se calcula como `1 - 1 = 0`).
     - **Solución:** Se añadió la validación `if (numRows > 0)` en `_getMasterCountriesAndWarehouses` antes de llamar a `getRange` para los datos, asegurando que solo se intente leer si hay al menos una fila de datos.

 3.  **CORRUPCIÓN DE BASE DE DATOS DE SUSCRIPCIONES**
     - **Problema:** La función de auto-migración en `_getDbSheet` intentaba agregar columnas si la hoja de `Suscripciones` estaba vacía, interpretando que era una versión antigua.
     - **Solución:** Se añadió la condición `if (headers.length > 0 && ...)` para asegurar que la migración solo se ejecute si la hoja ya tiene encabezados existentes.

*/

// La función importUserSubscriptionsList ha sido eliminada para proteger la privacidad de los correos electrónicos de los usuarios.

// =================================================================
// ⚙️ FUNCIONES DE ADMINISTRACIÓN DE MÉTRICAS (NUEVO)
// =================================================================

/**
 * Verifica si el usuario actual es un administrador.
 * @returns {boolean} True si el email del usuario está en la lista ADMIN_USERS.
 */
function isCurrentUserAnAdmin() {
  var currentUser = Session.getActiveUser().getEmail();
  return ADMIN_USERS.indexOf(currentUser) !== -1;
}

/**
 * Obtiene la configuración de métricas desde PropertiesService o devuelve la configuración por defecto.
 * @returns {Array<Object>} La configuración de las métricas.
 */
function getMetricsConfig() {
  var properties = PropertiesService.getScriptProperties();
  var configJson = properties.getProperty('METRICS_CONFIG');
  
  if (configJson) {
    try {
      return JSON.parse(configJson);
    } catch (e) {
      // Si hay un error en el JSON, devolvemos el default para evitar romper la app
      Logger.log("Error al parsear METRICS_CONFIG: " + e.message);
    }
  }
  
  // Si no hay configuración guardada, se crea una por defecto desde METRICS_TO_ALERT
  return METRICS_TO_ALERT.map(function(metric) {
    return {
      key: metric.key,
      label: metric.label,
      active: ['orders', 'new_users', 'wis', 'seamless', 'delivery_time', 'assignment_time'].indexOf(metric.key) !== -1
    };
  });
}

/**
 * Guarda la configuración de las métricas en PropertiesService.
 * @param {Array<Object>} config El nuevo array de configuración de métricas.
 */
function saveMetricsConfig(config) {
  if (!isCurrentUserAnAdmin()) {
    throw new Error("Acceso denegado. Se requieren permisos de administrador.");
  }
  var properties = PropertiesService.getScriptProperties();
  properties.setProperty('METRICS_CONFIG', JSON.stringify(config));
  Logger.log("Configuración de métricas guardada por " + Session.getActiveUser().getEmail());
}

// =================================================================
// ── INTEGRACIÓN CLIMÁTICA: COORDENADAS WHS Y API OPEN-METEO ──────
// =================================================================

var WHS_MASTER_SPREADSHEET_ID = '1DXcZswpGQsbXcj5RXBALAogLrs32d_rtcxpRb17nROk';
var WHS_MASTER_DATA_SHEET_GID = 1805962870; // GID oficial de la pestaña '1. WHS data'
var WHS_MASTER_DATA_SHEET     = '1. WHS data';
var GLOBAL_WHS_COORDS_CACHE   = null;

var BUILTIN_WHS_COORDS = {
  "AR_80_Pacheco": { lat: -34.4598, lng: -58.635 },
  "AR_277_Berazategui": { lat: -34.7736, lng: -58.2092 },
  "AR_179_Tucuman Centro II": { lat: -26.8145, lng: -65.2239 },
  "AR_81_Mendoza_Guaymallen": { lat: -32.9047, lng: -68.8182 },
  "AR_15_25deMayo": { lat: -31.4147, lng: -64.1648 },
  "AR_181_San_Juan_Centro": { lat: -31.5291, lng: -68.5265 },
  "AR_518_Boedo_II": { lat: -34.6263, lng: -58.413 },
  "AR_232_San_Justo": { lat: -34.6795, lng: -58.5493 },
  "AR_41_Bahia_Blanca": { lat: -38.7113, lng: -62.2665 },
  "AR_40_Resistencia": { lat: -27.4548, lng: -58.9992 },
  "AR_134_City_Bell": { lat: -34.881, lng: -58.0095 },
  "AR_507_Villa_Crespo": { lat: -34.5924, lng: -58.4416 },
  "AR_522_MDQ_III": { lat: -37.9939, lng: -57.5686 },
  "AR_58_TUCUMAN_YERBA_BUENA": { lat: -26.8174, lng: -65.2703 },
  "AR_16_Pilar": { lat: -34.4538, lng: -58.9085 },
  "AR_197_San_Fernando": { lat: -34.4342, lng: -58.5592 },
  "AR_8_Nordelta": { lat: -34.4015, lng: -58.6332 },
  "Nordelta": { lat: -34.4015, lng: -58.6332 },
  "AR_8": { lat: -34.4015, lng: -58.6332 },
  "Nordelta nuevo": { lat: -34.4015, lng: -58.6332 },
  "AR_126_Parque_Patricios": { lat: -34.6357, lng: -58.3904 },
  "AR_138_Villa_Ortuzar": { lat: -34.5857, lng: -58.4658 },
  "AR_57_PARANA": { lat: -31.7432, lng: -60.5179 },
  "AR_229_Pilar_II": { lat: -34.4294, lng: -58.8854 },
  "AR_515_Castelar_II": { lat: -34.6608, lng: -58.6177 },
  "AR_183_Bahia_Blanca_II": { lat: -38.721, lng: -62.2595 },
  "AR_210_Neuquen_Este": { lat: -38.9627, lng: -68.0646 },
  "AR_215_Lujan": { lat: -34.5632, lng: -59.1031 },
  "AR_220_Villa_Ballester": { lat: -34.5533, lng: -58.5683 },
  "AR_514_Caseros_II": { lat: -34.6139, lng: -58.5761 },
  "AR_156_Crisol": { lat: -31.3807, lng: -64.177 },
  "AR_506_Microcentro_II": { lat: -34.6086, lng: -58.3918 },
  "AR_223_Monte_Grande": { lat: -34.7955, lng: -58.4479 },
  "AR_131_Ing_Maschwitz": { lat: -34.393, lng: -58.7386 },
  "AR_38_Tucuman": { lat: -26.8332, lng: -65.2196 },
  "AR_141_Barracas": { lat: -34.629, lng: -58.3735 },
  "AR_39_Mendoza_Godoy": { lat: -32.9198, lng: -68.8506 },
  "AR_199_Mataderos": { lat: -34.6559, lng: -58.4889 },
  "AR_65_Lomas": { lat: -34.7659, lng: -58.4037 },
  "AR_177_Mendoza_Las_Heras": { lat: -32.8552, lng: -68.8465 },
  "AR_153_Nunez": { lat: -34.556, lng: -58.4645 },
  "AR_66_Escobar": { lat: -34.3474, lng: -58.7936 },
  "AR_509_Parque_Avellaneda_II": { lat: -34.6275, lng: -58.4892 },
  "AR_10_La Plata": { lat: -34.9194, lng: -57.9592 },
  "AR_235_Barrio_Norte": { lat: -34.598, lng: -58.4187 },
  "AR_173_Wilde": { lat: -34.7056, lng: -58.316 },
  "AR_520_Avellaneda_II": { lat: -34.6638, lng: -58.3589 },
  "AR_187_Merlo": { lat: -34.6614, lng: -58.7265 },
  "AR_19_Beccar": { lat: -34.4671, lng: -58.5422 },
  "AR_14_Cordillera": { lat: -31.3653, lng: -64.2227 },
  "AR_226_Moreno": { lat: -34.6463, lng: -58.7918 },
  "AR_129_San_Luis": { lat: -33.2964, lng: -66.3248 },
  "AR_516_San_Miguel_II": { lat: -34.5254, lng: -58.7118 },
  "AR_519_Manuel_Alberti_II": { lat: -34.4426, lng: -58.7767 },
  "AR_30_Mdq_Alvarado": { lat: -38.0086, lng: -57.5576 },
  "AR_63_Corrientes": { lat: -27.4751, lng: -58.8431 },
  "AR_54_Quilmes": { lat: -34.7322, lng: -58.2691 },
  "AR_209_Florencio_Varela": { lat: -34.7892, lng: -58.2543 },
  "AR_3_Belgrano": { lat: -34.5692, lng: -58.4732 },
  "AR_182_Munro": { lat: -34.5141, lng: -58.5256 },
  "AR_170_La_Plata_II": { lat: -34.9074, lng: -57.9505 },
  "AR_68_Rosario_ll": { lat: -32.9076, lng: -60.682 },
  "AR_42_Villa_del_Parque": { lat: -34.6074, lng: -58.4904 },
  "AR_517_Santa_Fe_II": { lat: -31.643, lng: -60.7246 },
  "AR_159_Rio_Cuarto": { lat: -33.1369, lng: -64.3508 },
  "AR_56_SALTA": { lat: -24.7754, lng: -65.4109 },
  "AR_147_Ituzaingo": { lat: -34.6304, lng: -58.6546 },
  "AR_508_San_Martin": { lat: -34.5778, lng: -58.5495 },
  "AR_180_Hurlingham": { lat: -34.5991, lng: -58.6226 },
  "AR_510_Ramos_Mejia_II": { lat: -34.6425, lng: -58.5751 },
  "AR_527_Villa_Ballester_II": { lat: -34.5407, lng: -58.5522 },
  "AR_513_Lanus_II": { lat: -34.7151, lng: -58.3934 },
  "AR_523_Berazategui_II": { lat: -34.7736, lng: -58.2092 },
  "AR_524_La_Plata_III": { lat: -34.9194, lng: -57.9592 },
  "AR_539_Villa_Ortuzar_II": { lat: -34.5857, lng: -58.4658 },
  "CH_1_Santiago": { lat: -33.4489, lng: -70.6693 },
  "CH_4_Chillan": { lat: -36.6067, lng: -72.1034 },
  "CH_5_Temuco": { lat: -38.7359, lng: -72.5904 },
  "CH_6_La Serena": { lat: -29.9027, lng: -71.252 },
  "CH_7_Rancagua": { lat: -34.1708, lng: -70.7444 },
  "CH_9_Las Condes": { lat: -33.4117, lng: -70.5806 },
  "CH_10_Maipu": { lat: -33.5111, lng: -70.7583 },
  "CH_11_La Florida": { lat: -33.5227, lng: -70.5986 },
  "CH_12_Concepcion": { lat: -36.8201, lng: -73.0444 },
  "CH_13_Antofagasta Sur": { lat: -23.6509, lng: -70.3975 },
  "CH_14_Los Angeles": { lat: -37.4697, lng: -72.3537 },
  "CH_15_Bilbao": { lat: -33.4372, lng: -70.6056 },
  "CH_17_Puerto Montt": { lat: -41.4693, lng: -72.9424 },
  "CH_18_Valdivia": { lat: -39.8196, lng: -73.2452 },
  "CH_20_Estacion Central": { lat: -33.455, lng: -70.6861 },
  "CH_22_Manquehue": { lat: -33.4078, lng: -70.5667 },
  "CH_23_Osorno": { lat: -40.5744, lng: -73.136 },
  "CH_24_El Belloto": { lat: -33.0458, lng: -71.4428 },
  "CH_26_Antofagasta Norte": { lat: -23.61, lng: -70.38 },
  "CH_29_Penalolen": { lat: -33.4833, lng: -70.55 },
  "CH_35_Quillota": { lat: -32.88, lng: -71.2483 },
  "CH_37_Curico": { lat: -34.9854, lng: -71.2394 },
  "CH_38_Iquique": { lat: -20.2133, lng: -70.1503 },
  "CH_39_Calama": { lat: -22.4544, lng: -68.9294 },
  "CH_41_SanBernardo": { lat: -33.5928, lng: -70.7042 },
  "PE_2_Lince": { lat: -12.0833, lng: -77.0333 },
  "PE_8_Chorrillos": { lat: -12.1667, lng: -77.0167 },
  "PE_10_Barranco": { lat: -12.1489, lng: -77.0211 },
  "PE_14_PuebloLibre": { lat: -12.0744, lng: -77.0633 },
  "PE_18_Arequipa": { lat: -16.409, lng: -71.5375 },
  "PE_19_Trujillo": { lat: -8.1116, lng: -79.0287 },
  "PE_20_SMP": { lat: -12.0286, lng: -77.0603 },
  "UY_5_Ciudad de la Costa": { lat: -34.825, lng: -55.95 },
  "UY_7_Sayago": { lat: -34.8433, lng: -56.2083 },
  "UY_9_La Blanqueada": { lat: -34.8872, lng: -56.1556 },
  "UY_10_Carrasco Norte": { lat: -34.8717, lng: -56.0717 },
  "UY_12_Aguada": { lat: -34.8944, lng: -56.1917 },
  "BO_1_Equipetrol": { lat: -17.7667, lng: -63.1944 },
  "BO_2_NORTE": { lat: -17.75, lng: -63.18 },
  "BO_6_Sur": { lat: -17.81, lng: -63.19 },
  "EC_4_Solca": { lat: -0.1517, lng: -78.4733 },
  "EC_6_Oficina": { lat: -0.1807, lng: -78.4678 },
  "EC_7_SantaClara": { lat: -0.2, lng: -78.498 },
  "EC_9_Aeropuerto": { lat: -0.1333, lng: -78.4833 },
  "EC_19_Las Monjas": { lat: -2.1894, lng: -79.8891 },
  "PA_4_San_Francisco": { lat: -8.99, lng: -79.5 },
  "PA_5_Chorrera": { lat: -8.8803, lng: -79.7833 },
  "PA_9_Midtown": { lat: -8.98, lng: -79.52 },
  "PA_10_El_Dorado2": { lat: -9.01, lng: -79.53 },
  "GT_1_CAES km16": { lat: 14.55, lng: -90.46 },
  "GT_2_Reforma": { lat: 14.61, lng: -90.52 },
  "GT_3_Vista Hermosa": { lat: 14.59, lng: -90.49 },
  "GT_5_Z7 34 Avenida": { lat: 14.63, lng: -90.55 },
  "RD_2_27 de Febrero": { lat: 18.47, lng: -69.93 },
  "RD_3_San Vicente": { lat: 18.5, lng: -69.86 },
  "PY_2_JAF": { lat: -25.2867, lng: -57.575 },
  "PY_3_Lambare": { lat: -25.34, lng: -57.6 },
  "SV_2_LaMascota": { lat: 13.6929, lng: -89.24 },
  "HN_3_San_Pedro_Sula": { lat: 15.5042, lng: -88.025 }
};

function getFallbackCoordsForWh(wh) {
  var prefix = String(wh || '').split('_')[0].toUpperCase();
  var COUNTRY_CENTERS = {
    'AR': { lat: -34.6037, lng: -58.3816 },
    'CL': { lat: -33.4489, lng: -70.6693 },
    'CH': { lat: -33.4489, lng: -70.6693 },
    'PE': { lat: -12.0464, lng: -77.0428 },
    'UY': { lat: -34.9011, lng: -56.1645 },
    'PY': { lat: -25.2867, lng: -57.5750 },
    'BO': { lat: -17.7833, lng: -63.1821 },
    'EC': { lat: -0.1807, lng: -78.4678 },
    'PA': { lat: 8.9824, lng: -79.5199 },
    'GT': { lat: 14.6349, lng: -90.5069 },
    'DO': { lat: 18.4861, lng: -69.9312 },
    'RD': { lat: 18.4861, lng: -69.9312 },
    'SV': { lat: 13.6929, lng: -89.2182 },
    'HN': { lat: 15.5042, lng: -88.0250 }
  };
  return COUNTRY_CENTERS[prefix] || { lat: -34.6037, lng: -58.3816 };
}

/**
 * Resuelve de forma inteligente y tolerante a fallas las coordenadas geográficas de un Warehouse,
 * contemplando nombres canónicos, minúsculas, espacios/guiones y alias conocidos como Nordelta.
 */
function resolveCoordsForWh(coordsMap, wh) {
  if (!wh) return getFallbackCoordsForWh('');
  var raw = String(wh).trim();
  if (coordsMap[raw]) return coordsMap[raw];
  var lower = raw.toLowerCase();
  if (coordsMap[lower]) return coordsMap[lower];

  var norm = lower.replace(/\s+/g, '_');
  if (coordsMap[norm]) return coordsMap[norm];

  // Si tiene formato "AR_8_Nordelta", intentar buscar por nombre final o id
  var parts = lower.split('_');
  if (parts.length > 2) {
    var nameOnly = parts.slice(2).join('_');
    if (coordsMap[nameOnly]) return coordsMap[nameOnly];
    var idOnly = parts[0] + '_' + parts[1];
    if (coordsMap[idOnly]) return coordsMap[idOnly];
  }

  // Alias y coincidencias clave conocidas
  if (lower.indexOf('nordelta') !== -1) {
    if (coordsMap['AR_8_Nordelta']) return coordsMap['AR_8_Nordelta'];
    if (coordsMap['nordelta']) return coordsMap['nordelta'];
  }

  return getFallbackCoordsForWh(raw);
}

/**
 * Obtiene el mapa de coordenadas (latitud y longitud) de cada Warehouse
 * combinando las coordenadas maestras incorporadas y la lectura dinámica.
 */
function getWarehouseCoordinatesMap(forceRecalc) {
  if (forceRecalc !== true && GLOBAL_WHS_COORDS_CACHE != null) {
    return GLOBAL_WHS_COORDS_CACHE;
  }

  // Inicializar con la base incorporada de 128 tiendas (0ms de latencia)
  var coordsMap = {};
  Object.keys(BUILTIN_WHS_COORDS).forEach(function(k) {
    coordsMap[k] = BUILTIN_WHS_COORDS[k];
    coordsMap[k.toLowerCase()] = BUILTIN_WHS_COORDS[k];
  });

  if (forceRecalc !== true) {
    GLOBAL_WHS_COORDS_CACHE = coordsMap;
    return coordsMap;
  }

  try {
    var ss = SpreadsheetApp.openById(WHS_MASTER_SPREADSHEET_ID);
    var sheet = null;

    // 1. Prioridad: Buscar por GID exacto de pestaña (1805962870)
    var allSheets = ss.getSheets();
    for (var s = 0; s < allSheets.length; s++) {
      if (String(allSheets[s].getSheetId()) === String(WHS_MASTER_DATA_SHEET_GID)) {
        sheet = allSheets[s];
        break;
      }
    }

    // 2. Fallback: Buscar por nombre exacto o que contenga 'whs data'
    if (!sheet) {
      sheet = ss.getSheetByName(WHS_MASTER_DATA_SHEET);
    }
    if (!sheet) {
      for (var s = 0; s < allSheets.length; s++) {
        if (allSheets[s].getName().trim().toLowerCase().indexOf('whs data') !== -1) {
          sheet = allSheets[s];
          break;
        }
      }
    }

    if (sheet) {
      Logger.log('[Coordenadas] Leyendo datos frescos desde la planilla maestra: "' + sheet.getName() + '" (GID: ' + sheet.getSheetId() + ')');
      var lastRow = sheet.getLastRow();
      var lastCol = sheet.getLastColumn();
      if (lastRow > 1 && lastCol > 0) {
        var numRows = Math.min(3000, lastRow);
        var values = sheet.getRange(1, 1, numRows, lastCol).getValues();

        var headerIdx = 0;
        for (var r = 0; r < Math.min(5, values.length); r++) {
          var rowStrs = values[r].map(function(c) { return String(c || '').toLowerCase().trim(); });
          var hasMatch = rowStrs.some(function(h) { return h.indexOf('warehouse_name') !== -1 || h.indexOf('warehouse_id') !== -1; });
          if (hasMatch) {
            headerIdx = r;
            break;
          }
        }

        var headers = values[headerIdx].map(function(h) { return String(h || '').trim().toLowerCase(); });
        var getColIdx = function(target) {
          for (var h = 0; h < headers.length; h++) {
            var col = headers[h];
            if (col === target || col.endsWith('.' + target) || col.indexOf(target) !== -1) return h;
          }
          return -1;
        };

        var idxWhName = getColIdx('warehouse_name');
        var idxWhId   = getColIdx('warehouse_id');
        var idxLat    = getColIdx('store_lat');
        var idxLng    = getColIdx('store_lng');
        if (idxLng === -1) idxLng = getColIdx('store_lon');
        var idxCentLat = getColIdx('centroid_lat');
        var idxCentLng = getColIdx('centroid_lng');
        if (idxCentLng === -1) idxCentLng = getColIdx('centroid_lon');

        var totalLoadedFromSheet = 0;
        for (var i = headerIdx + 1; i < values.length; i++) {
          var row = values[i];
          var rawName = idxWhName !== -1 ? String(row[idxWhName] || '').trim() : '';
          var rawId   = idxWhId !== -1 ? String(row[idxWhId] || '').trim() : '';
          
          var rawLat = idxLat !== -1 ? row[idxLat] : null;
          var rawLng = idxLng !== -1 ? row[idxLng] : null;
          if ((rawLat === null || rawLat === '' || isNaN(rawLat)) && idxCentLat !== -1) {
            rawLat = row[idxCentLat];
          }
          if ((rawLng === null || rawLng === '' || isNaN(rawLng)) && idxCentLng !== -1) {
            rawLng = row[idxCentLng];
          }

          var lat = parseFloat(String(rawLat || '').replace(',', '.'));
          var lng = parseFloat(String(rawLng || '').replace(',', '.'));

          // Detección automática de formato POINT(lng lat) si las columnas numéricas están vacías o empaquetadas
          if (isNaN(lat) || isNaN(lng)) {
            for (var cIdx = 0; cIdx < row.length; cIdx++) {
              var strVal = String(row[cIdx] || '').trim();
              if (strVal.indexOf('POINT') !== -1 || strVal.indexOf('point') !== -1) {
                var match = strVal.match(/POINT\s*\(\s*([-\d\.]+)\s+([-\d\.]+)\s*\)/i);
                if (match) {
                  lng = parseFloat(match[1]);
                  lat = parseFloat(match[2]);
                  break;
                }
              }
            }
          }

          if (!isNaN(lat) && !isNaN(lng)) {
            var coordObj = { lat: lat, lng: lng };
            totalLoadedFromSheet++;

            if (rawName) {
              coordsMap[rawName] = coordObj;
              coordsMap[rawName.toLowerCase()] = coordObj;
              coordsMap[rawName.toLowerCase().replace(/\s+/g, '_')] = coordObj;
              
              // Si tiene formato "AR_8_Nordelta", indexar también alias derivados
              var parts = rawName.toLowerCase().split('_');
              if (parts.length > 2) {
                var nameOnly = parts.slice(2).join('_');
                coordsMap[nameOnly] = coordObj;
                coordsMap[parts[0] + '_' + parts[1]] = coordObj;
              }
            }
            if (rawId) {
              coordsMap[rawId] = coordObj;
              coordsMap[rawId.toLowerCase()] = coordObj;
            }
          }
        }
        Logger.log('[Coordenadas] Se cargaron exitosamente ' + totalLoadedFromSheet + ' almacenes desde la pestaña GID: ' + WHS_MASTER_DATA_SHEET_GID);
      }
    }
  } catch (err) {
    Logger.log('Aviso leyendo coordenadas de WHS data: ' + err.message);
  }

  GLOBAL_WHS_COORDS_CACHE = coordsMap;
  try {
    PropertiesService.getScriptProperties().setProperty('WHS_COORDS_MAP_JSON', JSON.stringify(coordsMap));
  } catch(e) {}

  return coordsMap;
}

/**
 * Consulta la API de Open-Meteo para obtener los milímetros (mm) de precipitación
 * acumulada en una fecha específica para una lista de coordenadas.
 * Realiza batching de hasta 35 coordenadas por llamada HTTP para máxima velocidad.
 */
function fetchPrecipitationForCoordinates(itemsToQuery, fechaYMD) {
  if (!itemsToQuery || itemsToQuery.length === 0 || !fechaYMD) {
    return {};
  }

  var cache = CacheService.getScriptCache();
  var resultMap = {}; // key: "lat_lng" -> mm
  var missingItems = [];

  // 1. Revisar caché
  itemsToQuery.forEach(function(item) {
    var key = 'RAIN_' + fechaYMD + '_' + item.lat.toFixed(3) + '_' + item.lng.toFixed(3);
    var cached = cache.get(key);
    if (cached !== null && cached !== undefined && cached !== '') {
      resultMap[item.lat.toFixed(3) + '_' + item.lng.toFixed(3)] = parseFloat(cached);
    } else {
      missingItems.push(item);
    }
  });

  if (missingItems.length === 0) {
    return resultMap;
  }

  // Desduplicar coordenadas geográficas cercanas (misma ubicación o tienda compartida)
  var uniqueCoords = {};
  missingItems.forEach(function(item) {
    var coordKey = item.lat.toFixed(4) + '_' + item.lng.toFixed(4);
    if (!uniqueCoords[coordKey]) {
      uniqueCoords[coordKey] = { lat: item.lat, lng: item.lng };
    }
  });

  var coordList = Object.keys(uniqueCoords).map(function(k) { return uniqueCoords[k]; });
  var batchSize = 35; // Límite seguro para longitud de URL

  for (var b = 0; b < coordList.length; b += batchSize) {
    var batch = coordList.slice(b, b + batchSize);
    var lats = batch.map(function(c) { return c.lat.toFixed(4); }).join(',');
    var lngs = batch.map(function(c) { return c.lng.toFixed(4); }).join(',');

    var url = 'https://api.open-meteo.com/v1/forecast?' +
              'latitude=' + lats + '&longitude=' + lngs +
              '&start_date=' + fechaYMD + '&end_date=' + fechaYMD +
              '&daily=precipitation_sum&timezone=auto';

    try {
      var resp = UrlFetchApp.fetch(url, { muteHttpExceptions: true });
      if (resp.getResponseCode() === 200) {
        var parsed = JSON.parse(resp.getContentText());
        var resArr = Array.isArray(parsed) ? parsed : [parsed];

        for (var i = 0; i < resArr.length; i++) {
          var itemRes = resArr[i];
          var origCoord = batch[i];
          if (!origCoord) continue;

          var mm = 0.0;
          if (itemRes && itemRes.daily && itemRes.daily.precipitation_sum && itemRes.daily.precipitation_sum.length > 0) {
            var rawVal = itemRes.daily.precipitation_sum[0];
            mm = (rawVal !== null && !isNaN(rawVal)) ? Math.round(rawVal * 10) / 10 : 0.0;
          }

          var key3 = origCoord.lat.toFixed(3) + '_' + origCoord.lng.toFixed(3);
          resultMap[key3] = mm;

          try {
            cache.put('RAIN_' + fechaYMD + '_' + key3, String(mm), 21600); // 6 horas
          } catch(e) {}
        }
      } else {
        Logger.log('Aviso Open-Meteo HTTP ' + resp.getResponseCode() + ': ' + resp.getContentText());
      }
    } catch(err) {
      Logger.log('Error consultando Open-Meteo: ' + err.message);
    }
  }

  return resultMap;
}

/**
 * Enriquece un arreglo de alertas con el campo lluvia_mm para la fecha de cada alerta.
 * Permite recibir optionalCoordsMap para utilizar el mapa fresco cargado de la planilla maestra (gid: 1805962870).
 */
function enrichAlertsWithPrecipitation(alertas, fechaYMD, optionalCoordsMap) {
  if (!alertas || alertas.length === 0) return alertas;

  var coordsMap = optionalCoordsMap || getWarehouseCoordinatesMap(false);
  var alertsByDate = {};

  alertas.forEach(function(a) {
    var f = a.fecha || fechaYMD;
    if (!f) return;
    if (!alertsByDate[f]) alertsByDate[f] = [];
    alertsByDate[f].push(a);
  });

  Object.keys(alertsByDate).forEach(function(fDate) {
    var dateAlerts = alertsByDate[fDate];
    var itemsToQuery = [];

    dateAlerts.forEach(function(a) {
      var whKey = String(a.pais || '').trim();
      var coords = resolveCoordsForWh(coordsMap, whKey);
      if (coords && coords.lat && coords.lng) {
        itemsToQuery.push({ wh: whKey, lat: coords.lat, lng: coords.lng });
      }
    });

    var weatherMap = fetchPrecipitationForCoordinates(itemsToQuery, fDate);

    dateAlerts.forEach(function(a) {
      var whKey = String(a.pais || '').trim();
      var coords = resolveCoordsForWh(coordsMap, whKey);
      if (coords && coords.lat && coords.lng) {
        var key3 = coords.lat.toFixed(3) + '_' + coords.lng.toFixed(3);
        if (weatherMap[key3] !== undefined) {
          a.lluvia_mm = weatherMap[key3];
        }
      }
      if (a.lluvia_mm === undefined) {
        a.lluvia_mm = null;
      }
    });
  });

  return alertas;
}

/**
 * Retorna el mapa de lluvia en mm por Warehouse para una fecha específica { "AR_BUE_02": 14.2, ... }
 */
function getWarehouseWeatherMapForDate(fechaYMD) {
  if (!fechaYMD) return {};
  var coordsMap = getWarehouseCoordinatesMap(false);
  var whList = Object.keys(coordsMap);

  var itemsToQuery = [];
  whList.forEach(function(wh) {
    var c = resolveCoordsForWh(coordsMap, wh);
    if (c && c.lat && c.lng) {
      itemsToQuery.push({ wh: wh, lat: c.lat, lng: c.lng });
    }
  });

  var weatherMap = fetchPrecipitationForCoordinates(itemsToQuery, fechaYMD);
  var result = {};

  whList.forEach(function(wh) {
    var c = resolveCoordsForWh(coordsMap, wh);
    if (c && c.lat && c.lng) {
      var key3 = c.lat.toFixed(3) + '_' + c.lng.toFixed(3);
      if (weatherMap[key3] !== undefined) {
        result[wh] = weatherMap[key3];
      }
    }
  });

  return result;
}



