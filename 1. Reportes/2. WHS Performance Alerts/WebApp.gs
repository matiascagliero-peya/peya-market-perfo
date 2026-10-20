// Versión: 2.0 (Corregida por Gemini)
// =================================================================
// SISTEMA DE ALERTAS DE PERFORMANCE — PedidosYa Markets
// =================================================================
// Archivo maestro de backend (Code.gs). Contiene la lógica de:
// 1. Configuración de reglas de negocio y desvíos críticos.
// 2. Operaciones de base de datos (Google Sheets).
// 3. Motor de cálculo de anomalías (D-1 vs L3W / 7D Rolling).
// 4. Motor de distribución de correos basado en suscripciones.
// =================================================================

function _getUserEmail() {
  try {
    return Session.getActiveUser().getEmail();
  } catch(e) {
    return '(unknown)'; // Para debugging local
  }
}

// ── LISTA DE ADMINISTRADORES ─────────────────────────────────────
var ADMIN_EMAILS = [
  'matias.cagliero@pedidosya.com',
  'eugenio.irigoin@pedidosya.com',
  'nicki.krawiecki@pedidosya.com',
  'tobias.fay@pedidosya.com',
  'juan.pinori@pedidosya.com'
];

function doGet(e) {
  var page = (e && e.parameter && e.parameter.page) ? e.parameter.page : 'dashboard';
  var src = (e && e.parameter && e.parameter.src) ? e.parameter.src : '';
  var user = _getUserEmail();
  
  try {
    if (page !== 'analytics') { // No loguear las vistas de la propia página de analytics
      var logAction = 'WebApp GET Request: page=' + page + (src ? ' src=' + src : '');
      logAccess(user, logAction);
    }
  } catch(eLog) {
    Logger.log("Aviso registrando logAccess en doGet: " + eLog.message);
  }
  
  var filename;
  var isAdmin = (ADMIN_EMAILS.indexOf(user) !== -1);
  
  if (page === 'dashboard') {
    filename = '1_Dashboard';
  } else if (page === 'bycountry') {
    filename = '1_ByCountry';
  } else if (page === 'subscriptions') {
    filename = '2_Suscripciones';
  } else if (page === 'analytics' && isAdmin) {
    filename = '3_Analytics';
  } else if (page === 'debug' && user === 'matias.cagliero@pedidosya.com') {
    filename = '4_Debug';
  } else {
    filename = '1_Dashboard'; // Default
  }
  
  var template = HtmlService.createTemplateFromFile(filename);
  template.userEmail = user;
  template.isAdmin = isAdmin;
  try {
    template.scriptUrl = ScriptApp.getService().getUrl();
  } catch(eUrl) {
    template.scriptUrl = "";
  }
  
  var html = template.evaluate();
  html.setTitle('WHS Performance Alerts');
  html.addMetaTag('viewport', 'width=device-width, initial-scale=1');
  return html;
}

function include(filename, data) {
  var template = HtmlService.createTemplateFromFile(filename);
  
  // Inyección de seguridad por defecto para evitar ReferenceErrors en sub-plantillas como _nav
  try {
    template.scriptUrl = ScriptApp.getService().getUrl();
  } catch(e) {
    template.scriptUrl = "";
  }
  
  var user = _getUserEmail();
  template.userEmail = user;
  template.isAdmin = (ADMIN_EMAILS.indexOf(user) !== -1);

  if (data) {
    Object.keys(data).forEach(function(key) {
      template[key] = data[key];
    });
  }
  return template.evaluate().getContent();
}

function getSubscriptionsPageData() {
  var user = _getUserEmail();
  logAccess(user, 'Subscriptions Page Load');

  try {
    // Para las listas de opciones, leemos el universo completo de WHS y Países desde la fuente original
    var actualsSheet = SpreadsheetApp.openById(SPREADSHEET_ID).getSheetByName(SHEET_ACTUALS);
    var lastRow = actualsSheet.getLastRow();
    
    var countries = {};
    var warehouses = {};

    if (lastRow > 1) {
      // Forzamos la lectura de la columna D (índice 4), que es donde están los nombres de los WHS (ej: AR_BUE_02).
      var paisColumn = actualsSheet.getRange(2, 4, lastRow - 1, 1).getValues();
      
      paisColumn.forEach(function(row) {
        var pais = row[0];
        if (pais && pais.trim() !== "") {
          warehouses[pais] = true;
          var subCountryCode = String(pais).split('_')[0].toUpperCase();
          countries[subCountryCode] = true;
        }
      });
    }

    var countriesList = Object.keys(countries).sort().map(function(c) {
      var FULL_PAIS_NAMES = {
        'AR': 'Argentina', 'BO': 'Bolivia', 'CL': 'Chile', 'CH': 'Chile', 
        'CO': 'Colombia', 'EC': 'Ecuador', 'SV': 'El Salvador', 'GT': 'Guatemala', 
        'HN': 'Honduras', 'NI': 'Nicaragua', 'PA': 'Panamá', 'PY': 'Paraguay', 
        'PE': 'Perú', 'UY': 'Uruguay', 'DO': 'Rep. Dominicana', 'RD': 'Rep. Dominicana'
      };
      return { key: c, label: FULL_PAIS_NAMES[c] || c };
    });
    
    var warehousesList = Object.keys(warehouses).sort();

    var metricsList = METRICS_TO_ALERT.map(function(m) {
      return { key: m.key, label: m.label };
    });

    var userSub = getSubscriptionFromDb(user);

    return {
      countriesList: countriesList,
      warehousesList: warehousesList,
      metricsList: metricsList,
      userSub: userSub
    };
  } catch (e) {
    Logger.log("ERROR FATAL en getSubscriptionsPageData: " + e.stack);
    return {
      error: 'No se pudieron cargar los datos de la página de suscripciones. Causa: ' + e.message,
      countriesList: [],
      warehousesList: [],
      metricsList: [],
      userSub: {}
    };
  }
}

function getDashboardData(forceRecalc) {
  var user = _getUserEmail();
  logAccess(user, 'Dashboard Load (Direct Fetch)');

  try {
    if (forceRecalc === true) {
      GLOBAL_AD_CACHE = null;
      GLOBAL_HEADERS_CACHE = null;
      GLOBAL_AD_DATE_STR_CACHE = null;
      GLOBAL_AD_DATE_MS_CACHE = null;
      GLOBAL_METRICS_AVAILABILITY_CACHE = null;
      GLOBAL_REAL_LAST_ROW_CACHE = null;
      GLOBAL_DATE_COL_VALUES_CACHE = null;
    }

    var history = getAlertsHistoryFromDb();
    var needsProcessing = false;

    if (forceRecalc === true) {
      needsProcessing = true;
      Logger.log("[INFO] Forzando procesamiento on-demand por solicitud de recálculo...");
    } else if (history.length === 0) {
      needsProcessing = true;
      Logger.log("DIAGNÓSTICO: El historial está vacío. Forzando procesamiento on-demand...");
    } else {
      var maxHistoryMs = -Infinity;
      history.forEach(function(h) {
        var t = parseDateToMs(h.fecha);
        if (!isNaN(t) && t > maxHistoryMs) maxHistoryMs = t;
      });

      var actSheet = SpreadsheetApp.openById(SPREADSHEET_ID).getSheetByName(SHEET_ACTUALS);
      var lastCol = actSheet.getLastColumn();
      var headers = lastCol > 0 ? actSheet.getRange(1, 1, 1, lastCol).getValues()[0] : [];
      var dateColIdx = headers.indexOf('fecha');
      if (dateColIdx === -1) dateColIdx = headers.indexOf('date');

      if (dateColIdx !== -1) {
        var lastRow = actSheet.getLastRow();
        if (lastRow > 1) {
          var sampleCount = Math.min(5, lastRow - 1);
          var topDateValues = actSheet.getRange(2, dateColIdx + 1, sampleCount, 1).getValues();
          var maxRawMs = -Infinity;
          var nowMs = Date.now();

          topDateValues.forEach(function(row) {
            var t = parseDateToMs(row[0]);
            if (!isNaN(t) && t <= nowMs && t > maxRawMs) maxRawMs = t;
          });

          if (maxRawMs > maxHistoryMs) {
            needsProcessing = true;
            Logger.log("[INFO] Se detectó fecha más reciente en datos reales (" + normalizeDateToYMD(new Date(maxRawMs)) + ") que en el historial (" + normalizeDateToYMD(new Date(maxHistoryMs)) + "). Ejecutando procesarAlertasDiarias() on-demand...");
          }
        }
      }
    }

    if (needsProcessing) {
      procesarAlertasDiarias(false);
      history = getAlertsHistoryFromDb();
    }
    
    var finalAlerts = calcularYAgregarDiasConsecutivos(history);
    var masterWhs = _getMasterCountriesAndWarehouses(forceRecalc).warehousesList || [];
    var metricsAvail = _getMetricsAvailability(forceRecalc);
    var userSub = getSubscriptionFromDb(user);
    var metricsList = METRICS_TO_ALERT.map(function(m) { return { key: m.key, label: m.label }; });

    var latestDateStr = null;
    if (finalAlerts && finalAlerts.length > 0) {
      finalAlerts.forEach(function(a) {
        if (a && a.fecha && (!latestDateStr || a.fecha > latestDateStr)) {
          latestDateStr = a.fecha;
        }
      });
    }
    var whsWeatherMap = latestDateStr ? getWarehouseWeatherMapForDate(latestDateStr) : {};

    return {
      alerts: finalAlerts,
      userSub: userSub,
      metricsList: metricsList,
      masterWhs: masterWhs,
      metricsAvailability: metricsAvail,
      whsWeather: whsWeatherMap,
      weatherDate: latestDateStr
    };
  } catch (e) {
    Logger.log("ERROR FATAL en getDashboardData: " + e.stack);
    return {
      error: 'No se pudieron cargar los datos del dashboard. Causa: ' + e.message,
      alerts: [],
      userSub: { paises: [], metricas: [], activo: false },
      metricsList: [],
      metricsAvailability: {},
      whsWeather: {}
    };
  }
}

/**
 * Carga asíncrona diferida de coordenadas y clima (mm) para una fecha y lista de almacenes.
 * Se ejecuta en segundo plano DESPUÉS de que la página ya cargó y renderizó todo.
 */
function fetchDeferredWeatherForDate(fechaYMD, whList) {
  try {
    if (!fechaYMD) return {};
    
    var coordsMap = getWarehouseCoordinatesMap(false);
    var stores = (Array.isArray(whList) && whList.length > 0) ? whList : Object.keys(coordsMap);
    
    var result = {};
    var itemsToQuery = [];
    var cache = CacheService.getScriptCache();

    stores.forEach(function(wh) {
      var whKey = String(wh || '').trim();
      var c = (typeof resolveCoordsForWh === 'function')
        ? resolveCoordsForWh(coordsMap, whKey)
        : (coordsMap[whKey] || coordsMap[whKey.toLowerCase()] || getFallbackCoordsForWh(whKey));
      if (c && c.lat && c.lng) {
        var key3 = c.lat.toFixed(3) + '_' + c.lng.toFixed(3);
        var cached = null;
        try { cached = cache.get('RAIN_' + fechaYMD + '_' + key3); } catch(e) {}
        if (cached !== null && !isNaN(cached)) {
          result[whKey] = parseFloat(cached);
        } else {
          itemsToQuery.push({ wh: whKey, lat: c.lat, lng: c.lng, key3: key3 });
        }
      }
    });

    if (itemsToQuery.length === 0) return result;

    var batchSize = 35;
    for (var b = 0; b < itemsToQuery.length; b += batchSize) {
      var batch = itemsToQuery.slice(b, b + batchSize);
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
            var origItem = batch[i];
            if (!origItem) continue;

            var mm = 0.0;
            if (itemRes && itemRes.daily && itemRes.daily.precipitation_sum && itemRes.daily.precipitation_sum.length > 0) {
              var rawVal = itemRes.daily.precipitation_sum[0];
              mm = (rawVal !== null && !isNaN(rawVal)) ? Math.round(rawVal * 10) / 10 : 0.0;
            }
            result[origItem.wh] = mm;
            try {
              cache.put('RAIN_' + fechaYMD + '_' + origItem.key3, String(mm), 21600);
            } catch(e) {}
          }
        }
      } catch(err) {
        Logger.log('Error Open-Meteo batch: ' + err.message);
      }
    }

    return result;
  } catch(e) {
    Logger.log("Error en fetchDeferredWeatherForDate: " + e.message);
    return {};
  }
}

/**
 * Función expuesta para que el frontend pueda solicitar el mapa de precipitaciones
 * (mm) de todos los almacenes para una fecha específica al cambiar el filtro de fecha.
 */
function getWhsWeatherForDateClient(fechaYMD) {
  try {
    return getWarehouseWeatherMapForDate(fechaYMD);
  } catch(e) {
    Logger.log("Error en getWhsWeatherForDateClient: " + e.message);
    return {};
  }
}



function getDebugDiagnostics(date) {
  if (_getUserEmail() !== 'matias.cagliero@pedidosya.com') {
    throw new Error("Acceso denegado.");
  }

  var diag = {
    spreadsheets: { actuals: null, database: null },
    sheets: { actuals: null, Suscripciones: null, Alertas_Historial: null },
    dataSummary: null,
    testRun: null
  };

  // 1. Check Spreadsheet Connections
  try {
    var actualsSS = SpreadsheetApp.openById(SPREADSHEET_ID);
    diag.spreadsheets.actuals = { ok: true, name: actualsSS.getName() };
  } catch (e) {
    diag.spreadsheets.actuals = { ok: false, error: e.message };
  }
  try {
    var dbSS = SpreadsheetApp.openById(DATABASE_SS_ID);
    diag.spreadsheets.database = { ok: true, name: dbSS.getName() };
  } catch (e) {
    diag.spreadsheets.database = { ok: false, error: e.message };
  }

  // 2. Check Sheet Structure
  if (diag.spreadsheets.actuals.ok) {
    var actualsSheet = actualsSS.getSheetByName(SHEET_ACTUALS);
    if (actualsSheet) {
      diag.sheets.actuals = { ok: true, name: actualsSheet.getName() };
    } else {
      diag.sheets.actuals = { ok: false };
    }
  }
  if (diag.spreadsheets.database.ok) {
    var subSheet = dbSS.getSheetByName('Suscripciones');
    diag.sheets.Suscripciones = subSheet ? { ok: true, rows: subSheet.getLastRow() } : { ok: false };
    var histSheet = dbSS.getSheetByName('Alertas_Historial');
    diag.sheets.Alertas_Historial = histSheet ? { ok: true, rows: histSheet.getLastRow() } : { ok: false };
  }

  // 3. Data Summary
  if (diag.sheets.actuals && diag.sheets.actuals.ok) {
    var sheet = actualsSS.getSheetByName(SHEET_ACTUALS);
    var lastRow = sheet.getLastRow();
    var lastCol = sheet.getLastColumn();
    diag.dataSummary = {
      actualsRows: lastRow,
      actualsMinDate: lastRow > 1 ? sheet.getRange(2, 1).getDisplayValue() : '—',
      actualsMaxDate: lastRow > 1 ? sheet.getRange(lastRow, 1).getDisplayValue() : '—',
      actualsCountries: [],
      actualsMetrics: []
    };
    if (lastCol > 0) {
      var headers = sheet.getRange(1, 1, 1, lastCol).getValues()[0];
      diag.dataSummary.actualsMetrics = headers.slice(2); // Example, adjust as needed
    }
    if (lastRow > 1) {
       var countryCol = sheet.getRange(2, 2, Math.min(lastRow-1, 100), 1).getValues();
       var countries = {};
       countryCol.forEach(function(row){ if(row[0]) countries[row[0]]=true; });
       diag.dataSummary.actualsCountries = Object.keys(countries);
    }
  }

  // 4. Test Run
  try {
    var forcedDateMs = date ? new Date(date).getTime() : null;
    var result = _analizarAnomaliasDeAyer(forcedDateMs);
    diag.testRun = {
      ok: true,
      yesterdayYMD: result.yesterdayYMD,
      alertsFound: result.alertas.length,
      sampleAlerts: result.alertas.slice(0, 5)
    };
  } catch (e) {
    diag.testRun = { ok: false, error: e.message };
  }

  return diag;
}

function fetchAnalytics() {
  if (!isCurrentUserAnAdmin()) {
    return { error: 'Acceso denegado.' };
  }
  try {
    var logs = getAccessLogsFromDb();
    var byPeriod = { day: {}, week: {}, month: {} };
    var totals = { views: 0, users: new Set(), mail: 0, directo: 0 };
    var byPage = {};

    logs.forEach(function(log) {
      if (!log.fecha || !log.email) return;
      var d = new Date(log.fecha);
      if (isNaN(d.getTime())) return;
      
      var pageMatch = log.accion.match(/page=([a-z]+)/);
      var page = pageMatch ? pageMatch[1] : 'dashboard';
      var isFromMail = /src=alert-mail/.test(log.accion);

      totals.views++;
      totals.users.add(log.email);
      if (isFromMail) totals.mail++; else totals.directo++;

      if (!byPage[page]) byPage[page] = 0;
      byPage[page]++;

      var dayKey = d.toISOString().slice(0, 10);
      d.setDate(d.getDate() - d.getDay() + 1);
      var weekKey = d.toISOString().slice(0, 10);
      var monthKey = dayKey.slice(0, 7);

      [dayKey, weekKey, monthKey].forEach(function(key, i) {
        var gran = i === 0 ? 'day' : i === 1 ? 'week' : 'month';
        if (!byPeriod[gran][key]) byPeriod[gran][key] = {};
        var cellId = log.email + '|' + page;
        if (!byPeriod[gran][key][cellId]) byPeriod[gran][key][cellId] = { views: 0, mail: 0, directo: 0, email: log.email, page: page };
        byPeriod[gran][key][cellId].views++;
        if (isFromMail) byPeriod[gran][key][cellId].mail++; else byPeriod[gran][key][cellId].directo++;
      });
    });

    var finalByPeriod = { day: [], week: [], month: [] };
    for (var gran in byPeriod) {
      for (var period in byPeriod[gran]) {
        finalByPeriod[gran].push({ period: period, cells: Object.values(byPeriod[gran][period]) });
      }
      finalByPeriod[gran].sort(function(a,b){ return b.period.localeCompare(a.period); });
    }
    
    var usersRank = getSubscriptionsFromDb().map(function(s){ return {email: s.email, views:0, last:''}; });
    var userMap = {};
    usersRank.forEach(function(u){ userMap[u.email] = u; });
    logs.forEach(function(log){
      if(userMap[log.email]){
        userMap[log.email].views++;
        if(!userMap[log.email].last || log.fecha > userMap[log.email].last) userMap[log.email].last = log.fecha;
      }
    });
    usersRank = usersRank.filter(function(u){ return u.views > 0; }).sort(function(a,b){return b.views-a.views;});

    return {
      totals: { views: totals.views, users: totals.users.size, mail: totals.mail, directo: totals.directo },
      byPeriod: finalByPeriod,
      pages: Object.keys(byPage).map(function(p){ return {page: p, views: byPage[p]}; }).sort(function(a,b){return b.views-a.views;}),
      subscriptions: getSubscriptionsFromDb(),
      asOf: Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'yyyy-MM-dd HH:mm')
    };
  } catch(e) {
    Logger.log("Error en fetchAnalytics: " + e.stack);
    return { error: e.message };
  }
}

/**
 * FUNCIÓN DE DIAGNÓSTICO EXCLUSIVA PARA LA PÁGINA DE SUSCRIPCIONES
 * Ejecuta este script desde el editor de Apps Script para ver el log de ejecución
 * y verificar si el código está leyendo bien tu planilla de origen.
 */
function debugSubscriptions() {
  Logger.log("🔍 --- INICIANDO DIAGNÓSTICO DE SUSCRIPCIONES ---");
  try {
    var data = getSubscriptionsPageData();
    if (data.error) {
      Logger.log("❌ ERROR EN EL PROCESO: " + data.error);
    } else {
      Logger.log("✅ DIAGNÓSTICO COMPLETADO CON ÉXITO");
      Logger.log("🌎 Países cargados: " + data.countriesList.length + " " + JSON.stringify(data.countriesList.slice(0, 3)));
      Logger.log("🏪 WHS cargados: " + data.warehousesList.length + " sucursales (Muestra: " + JSON.stringify(data.warehousesList.slice(0, 3)) + ")");
      Logger.log("📈 Métricas cargadas: " + data.metricsList.length);
      Logger.log("👤 Suscripción del usuario actual: " + JSON.stringify(data.userSub));
    }
  } catch (e) {
    Logger.log("🚨 ERROR CRÍTICO INESPERADO: " + e.message);
    Logger.log(e.stack);
  }
  Logger.log("🔍 --- FIN DEL DIAGNÓSTICO ---");
}
