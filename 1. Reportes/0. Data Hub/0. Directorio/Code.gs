// =================================================================
// --- CONSTANTES GLOBALES Y CONFIGURACIÓN INICIAL ---
const SPREADSHEET_ID = "1OV9JkT1KKfjKdKSxncQJH8-mFrwpZInaEOv_pdEisE4";
const MAIN_SHEET_NAME = "1. Lista de reportes";
const LOG_SHEET_NAME = "ReportLog";
const ACCESS_LOG_SHEET_NAME = "IngresosReportes";

const UNIFIED_LOG_SPREADSHEET_ID = "11VJ9UmrXxRLwseAqbLj6FW-0hIgwU6w6Yg9hQjFtoxw";
const UNIFIED_LOG_SHEET_NAME = "LogUnificado";

// Claves de caché para el método de fragmentos (chunks)
const CACHE_KEY_META = 'DATA_HUB_META'; // Guarda metadatos y el número de chunks
const CACHE_KEY_CHUNK_PREFIX = 'DATA_HUB_CHUNK_'; // Prefijo para cada fragmento
const CACHE_KEY_MSG = 'dynamic_messages';

// AGREGA ESTA NUEVA FUNCIÓN
const LOG_GENERAL_SHEET_NAME = "LogGeneral";

// =================================================================
// --- PUNTO DE ENTRADA WEB Y TRIGGERS ---

function doGet(e) {
  try {
    // --- 1. NUEVA VALIDACIÓN DE DOMINIO ---
    const userEmail = Session.getActiveUser().getEmail();
    
    // Si el correo no termina en @pedidosya.com, bloqueamos el acceso
    if (!userEmail.endsWith('@pedidosya.com')) {
      const htmlError = `
        <div style="font-family: 'Arial', sans-serif; text-align: center; margin-top: 100px; color: #333;">
          <h1 style="color: #E91C4F;">⛔ Acceso Denegado</h1>
          <p>El Data Hub es de uso exclusivo para el equipo interno.</p>
          <p>Por favor, asegúrate de iniciar sesión con tu cuenta <b>@pedidosya.com</b>.</p>
          <p style="font-size: 0.8em; color: #777; margin-top: 20px;">Cuenta actual detectada: ${userEmail || "Sesión no iniciada"}</p>
        </div>
      `;
      return HtmlService.createHtmlOutput(htmlError)
        .setTitle("Acceso Denegado - Data Hub")
        .addMetaTag('viewport', 'width=device-width, initial-scale=1.0');
    }
    // --- FIN DE LA VALIDACIÓN ---

    // 2. Si es de PedidosYa, cargamos la página normalmente
    const params = e.parameter || {};
    let pageData = {
      baseUrl: ScriptApp.getService().getUrl(),
      message: getDynamicMessages().homeMessage,
      colorMap: getColorMappings(),
      filterContext: params.filter || "Todos",
      filterType: params.filterType,
      paisFilter: params.pais,
      ownerFilter: params.owner,
      plataformaFilter: params.plataforma,
      defaultView: params.view || 'ampliada'
    };

    let htmlOutput;
    if (params.page === "resultados") {
      pageData.message = getDynamicMessages().resultsMessage;
      htmlOutput = HtmlService.createTemplateFromFile('resultados');
      htmlOutput.pageData = pageData;
      return htmlOutput.evaluate()
        .setTitle(`Resultados: ${pageData.filterContext} - Data Hub`)
        .addMetaTag('viewport', 'width=device-width, initial-scale=1.0')
        .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);
    }
    
    // Sirve la página principal por defecto
    htmlOutput = HtmlService.createTemplateFromFile('index');
    htmlOutput.pageData = pageData;
    return htmlOutput.evaluate()
        .setTitle("Data Hub PeYa Market")
        .addMetaTag('viewport', 'width=device-width, initial-scale=1.0')
        .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);

  } catch (error) {
    Logger.log(`ERROR en doGet: ${error.message}. Stack: ${error.stack}`);
    return HtmlService.createHtmlOutput("Ocurrió un error grave en el servidor.");
  }
}

/** Función interna para construir y devolver una página HTML completa. */
function renderPage(filename, title, pageData) {
  let htmlOutput = HtmlService.createTemplateFromFile(filename);
  htmlOutput.pageData = pageData;
  let finalHtml = htmlOutput.evaluate().setTitle(title).addMetaTag('viewport', 'width=device-width, initial-scale=1.0');
  finalHtml.setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);
  return finalHtml;
}

function placeholder() {
  SpreadsheetApp.getUi().alert("Función de administrador.");
}

// =================================================================
// --- FUNCIONES PARA LA APP WEB (LLAMADAS DESDE EL CLIENTE) ---
function getHomePageInitialData() {
  try {
    const cache = CacheService.getScriptCache();
    const metaString = cache.get(CACHE_KEY_META);

    if (metaString) {
      const metaData = JSON.parse(metaString);
      return {
        success: true,
        uniqueAreas: metaData.uniqueAreas || [],
        uniqueChapters: metaData.uniqueChapters || []
      };
    } else {
      Logger.log("getHomePageInitialData: El caché está vacío. Se necesita una actualización por trigger.");
      return { 
        success: false, 
        error: "Los datos se están actualizando. Por favor, intenta de nuevo en unos minutos." 
      };
    }
  } catch (e) {
    Logger.log(`ERROR CRÍTICO en getHomePageInitialData: ${e.message}`);
    return { success: false, error: `Error del servidor: ${e.message}` };
  }
}

/** Obtiene los datos filtrados para la página de resultados.*/
function obtenerDatosParaResultadosOriginal() {
  try {
    // 1. Lee la lista principal de reportes desde el caché global (esto es rápido).
    const cachedData = obtenerDatosDelCache();
    let allItems = cachedData.allItems;
    if (!allItems || allItems.length === 0) {
      return { error: "No se encontraron datos en el caché. Intenta refrescar la página." };
    }

    // --- INICIO DE LA CORRECCIÓN ---
    const userEmail = Session.getActiveUser().getEmail();
    const userCache = CacheService.getUserCache();
    const userReportedCacheKey = 'user_reported_ids';
    
    let userReportedIDs = new Set();
    const cachedUserReports = userCache.get(userReportedCacheKey);

    if (cachedUserReports) {
      // RUTA RÁPIDA: Si encontramos los IDs en el caché del usuario, los usamos.
      userReportedIDs = new Set(JSON.parse(cachedUserReports));
    } else {
      // RUTA LENTA: Si no, leemos el log completo UNA SOLA VEZ.
      const spreadsheet = SpreadsheetApp.openById(SPREADSHEET_ID);
      const logSheet = spreadsheet.getSheetByName(LOG_SHEET_NAME);
      const logData = logSheet ? logSheet.getDataRange().getValues() : [];
      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
      
      const reportedIDsArray = [];
      for (let i = logData.length - 1; i > 0; i--) {
        if (logData[i][1] === userEmail && new Date(logData[i][0]) > thirtyDaysAgo) {
          reportedIDsArray.push(String(logData[i][2]));
        }
      }
      userReportedIDs = new Set(reportedIDsArray);
      
      // Guardamos el resultado en el caché del usuario para la próxima vez (expira en 15 min).
      userCache.put(userReportedCacheKey, JSON.stringify(reportedIDsArray), 900); 
    }
    // --- FIN DE LA CORRECCIÓN ---

    // Agrega la propiedad 'yaReportado' a cada item.
    allItems.forEach(item => {
      item.yaReportado = userReportedIDs.has(String(item.id));
    });

    return allItems;

  } catch (e) {
    Logger.log("ERROR en obtenerDatosParaResultados: " + e.message + " Stack: " + e.stack);
    return { error: "Fallo del servidor al obtener datos para resultados: " + e.message };
  }
}

function obtenerDatosParaResultados() {
  try {
    const cachedData = obtenerDatosDelCache();
    let allItems = cachedData.allItems;
    if (!allItems || allItems.length === 0) return { error: "Caché vacío. Ejecuta actualizarCacheCompleta." };

    // --- Lógica de reportes del usuario (Enlace caído) ---
    const userEmail = Session.getActiveUser().getEmail();
    const userCache = CacheService.getUserCache();
    const userReportedCacheKey = 'user_reported_ids';
    let userReportedIDs = new Set();
    const cachedUserReports = userCache.get(userReportedCacheKey);

    if (cachedUserReports) {
      userReportedIDs = new Set(JSON.parse(cachedUserReports));
    } else {
      const spreadsheet = SpreadsheetApp.openById(SPREADSHEET_ID);
      const logSheet = spreadsheet.getSheetByName(LOG_SHEET_NAME);
      const logData = logSheet ? logSheet.getDataRange().getValues() : [];
      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
      const reportedIDsArray = [];
      for (let i = logData.length - 1; i > 0; i--) {
        if (logData[i][1] === userEmail && new Date(logData[i][0]) > thirtyDaysAgo) {
          reportedIDsArray.push(String(logData[i][2]).trim());
        }
      }
      userReportedIDs = new Set(reportedIDsArray);
      userCache.put(userReportedCacheKey, JSON.stringify(reportedIDsArray), 900);
    }

    allItems.forEach(item => {
      item.yaReportado = userReportedIDs.has(String(item.id).trim());
    });

    // --- AGRUPACIÓN DE CARPETAS ---
    const groupsMap = new Map();
    const hierarchicalItems = [];

    allItems.forEach(item => {
      const groupName = (item.grupo && item.grupo.trim() !== "") ? String(item.grupo).trim() : String(item.nombreArchivo).trim();
      if (!groupsMap.has(groupName)) groupsMap.set(groupName, []);
      groupsMap.get(groupName).push(item);
    });

    groupsMap.forEach((children, groupName) => {
      if (children.length === 1) {
        const singleItem = children[0];
        singleItem.children = [];
        hierarchicalItems.push(singleItem);
      } else {
        const first = children[0];
        hierarchicalItems.push({
          id: 'grp_' + Utilities.base64Encode(groupName).replace(/[^a-zA-Z0-9]/g, '').substring(0, 15),
          nombreArchivo: groupName,
          descripcion: `Carpeta agrupada con ${children.length} reportes.`,
          // ESTO ES LO QUE SOLUCIONA EL ESPACIO EN BLANCO:
          categoria: first.categoria,           
          chapterPrincipal: first.chapterPrincipal, 
          pais: children.every(c => c.pais === first.pais) ? first.pais : 'Varios',
          owner: children.every(c => c.owner === first.owner) ? first.owner : 'Múltiples',
          plataforma: children.every(c => c.plataforma === first.plataforma) ? first.plataforma : 'Varias',
          children: children.sort((a, b) => a.nombreArchivo.localeCompare(b.nombreArchivo))
        });
      }
    });
    
    // Devolvemos todo ordenado alfabéticamente
    return hierarchicalItems.sort((a, b) => a.nombreArchivo.localeCompare(b.nombreArchivo));
  } catch (e) {
    Logger.log("ERROR en obtenerDatosParaResultados: " + e.message);
    return { error: "Fallo del servidor: " + e.message };
  }
}


/** Elimina el reporte de un enlace caído hecho por un usuario. */
/** Registra el reporte de un enlace caído. */
function reportarEnlaceCaido(reporteId) {
  try {
    const userEmail = Session.getActiveUser().getEmail();
    if (!reporteId || !userEmail) {
      return { success: false, message: "Faltan datos para procesar el reporte." };
    }
    const spreadsheet = SpreadsheetApp.openById(SPREADSHEET_ID);
    const logSheet = spreadsheet.getSheetByName(LOG_SHEET_NAME);
    if (!logSheet) {
      return { success: false, message: `Error del servidor: Hoja de log no encontrada.` };
    }
    const logData = logSheet.getDataRange().getValues();
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    for (let i = logData.length - 1; i > 0; i--) {
      // --- CORRECCIÓN: Se añade .trim() para una comparación robusta ---
      const sheetEmail = String(logData[i][1]).trim();
      const sheetReporteId = String(logData[i][2]).trim();

      if (sheetEmail === userEmail && sheetReporteId === String(reporteId)) {
        if (new Date(logData[i][0]) > thirtyDaysAgo) {
          return { success: false, message: "Ya has alertado este reporte en los últimos 30 días." };
        }
        break;
      }
    }

    logSheet.appendRow([new Date(), userEmail, reporteId]);
    
    const userCache = CacheService.getUserCache();
    userCache.remove('user_reported_ids');
    
    return { success: true, message: "¡Reporte enviado! Gracias por tu ayuda." };
  } catch (e) {
    Logger.log(`ERROR CRÍTICO en reportarEnlaceCaido: ${e.message}. Stack: ${e.stack}`);
    return { success: false, message: `Error del servidor al registrar el reporte: ${e.message}` };
  }
}

/** Elimina el reporte de un enlace caído hecho por un usuario. */
function retirarReporte(reporteId) {
  try {
    const userEmail = Session.getActiveUser().getEmail();
    if (!reporteId || !userEmail) {
      return { success: false, message: "Faltan datos para retirar el reporte." };
    }

    const spreadsheet = SpreadsheetApp.openById(SPREADSHEET_ID);
    const logSheet = spreadsheet.getSheetByName(LOG_SHEET_NAME);
    if (!logSheet) {
        return { success: false, message: "Hoja de log no encontrada." };
    }
    const data = logSheet.getDataRange().getValues();

    for (let i = data.length - 1; i > 0; i--) {
      if (String(data[i][1]) === userEmail && String(data[i][2]) === String(reporteId)) {
        logSheet.deleteRow(i + 1);
        actualizarCacheCompleta(); // Llama a refrescar el caché.
        return { success: true, message: "Alerta retirada con éxito." };
      }
    }
    return { success: false, message: "No se encontró una alerta previa para retirar." };
  } catch (e) {
    Logger.log(`ERROR CRÍTICO en retirarReporte: ${e.message}. Stack: ${e.stack}`);
    return { success: false, message: `Error del servidor al retirar el reporte: ${e.message}` };
  }
}

// =================================================================
// --- FUNCIONES PARA registro de datos

function registrarEstadistica(eventType, eventValue, dispositivo) {
  const userEmail = Session.getActiveUser().getEmail();
  registrarEventoUnificado(userEmail, eventType, eventValue, dispositivo);
}

function logEventoUnificado(app, device, eventType, eventValue, userEmailOverride) {
  try {
    const ss = SpreadsheetApp.openById(UNIFIED_LOG_SPREADSHEET_ID);
    let logSheet = ss.getSheetByName(UNIFIED_LOG_SHEET_NAME);

    // Si la hoja no existe, la crea con los encabezados.
    if (!logSheet) {
      logSheet = ss.insertSheet(UNIFIED_LOG_SHEET_NAME);
      // Colocamos los encabezados en el orden solicitado
      const headers = [
        "Timestamp", "Año", "Mes", "Dia", "UserEmail", 
        "App", "Dispositivo", "EventType", "EventValue"
      ];
      logSheet.getRange(1, 1, 1, headers.length).setValues([headers]);
      logSheet.setFrozenRows(1);
    }

    // Obtener la información de la sesión
    let userEmail = userEmailOverride;
    if (!userEmail) {
      try {
        userEmail = Session.getActiveUser().getEmail();
      } catch (e) {
        userEmail = "no_sesion_anonima"; // Caso de doGet anónimo (ej: pixel de apertura)
      }
    }
    
    const timestamp = new Date();
    const year = timestamp.getFullYear();
    const month = timestamp.getMonth() + 1; // getMonth() es 0-indexado
    const day = timestamp.getDate();

    // Creamos la fila en el orden solicitado
    const row = [
      timestamp,
      year,
      month,
      day,
      userEmail,
      app || "Desconocida",
      device || "Indefinido",
      eventType || "Indefinido",
      eventValue || ""
    ];

    // Añadir la nueva fila al final de la hoja
    logSheet.appendRow(row);

  } catch (e) {
    Logger.log(`Error CRÍTICO al registrar evento unificado: ${e.message}`);
  }
}

/** Registra el acceso de un usuario a un reporte. */
function registrarAcceso(archivoId) {
  if (!archivoId) { return; }
  const userEmail = Session.getActiveUser().getEmail();
  registrarEventoUnificado(userEmail, 'CLIC_ABRIR_REPORTE', archivoId);
}

// =================================================================
// --- LÓGICA INTERNA Y DE SOPORTE ---

function getQuickAccessReportsOptimized(allItems) {
  try {
    const userEmail = Session.getActiveUser().getEmail();
    const spreadsheet = SpreadsheetApp.openById(SPREADSHEET_ID);
    const accessLogSheet = spreadsheet.getSheetByName(ACCESS_LOG_SHEET_NAME);

    if (!accessLogSheet) {
      Logger.log(`ADVERTENCIA en getQuickAccessReportsOptimized: Hoja '${ACCESS_LOG_SHEET_NAME}' no encontrada.`);
      return [];
    }
    
    const logData = accessLogSheet.getDataRange().getValues();
    const ninetyDaysAgo = new Date();
    ninetyDaysAgo.setDate(ninetyDaysAgo.getDate() - 90);
    const userAccessCounts = {};

    for (let i = 1; i < logData.length; i++) {
        const row = logData[i];
        if (row[1] && row[2]) {
            const logTimestamp = new Date(row[0]);
            const logUserEmail = String(row[1]);
            const logArchivoId = String(row[2]);
            if (logUserEmail === userEmail && logTimestamp > ninetyDaysAgo) {
                userAccessCounts[logArchivoId] = (userAccessCounts[logArchivoId] || 0) + 1;
            }
        }
    }
    
    const reportDetails = {};
    allItems.forEach(item => {
      reportDetails[String(item.id)] = {
        nombreArchivo: item.nombreArchivo || 'Sin Nombre',
        link: item.link || '#',
        plataforma: item.plataforma || ''
      };
    });

    const popularReports = Object.keys(userAccessCounts)
      .filter(id => reportDetails[id])
      .map(id => ({
        id: id,
        nombreArchivo: reportDetails[id].nombreArchivo,
        link: reportDetails[id].link,
        plataforma: reportDetails[id].plataforma,
        accessCount: userAccessCounts[id]
      }));

    popularReports.sort((a, b) => b.accessCount - a.accessCount);
    return popularReports.slice(0, 5);

  } catch (e) {
    Logger.log(`ERROR en getQuickAccessReportsOptimized: ${e.message}`);
    return [];
  }
}

/** Obtiene mensajes dinámicos desde la hoja "Settings". */
function getDynamicMessages() {
  const cache = CacheService.getScriptCache();
  const cached = cache.get(CACHE_KEY_MSG);
  if (cached != null) { return JSON.parse(cached); }

  const defaultMessages = { home: "💡 Bienvenido al Data Hub.", results: "🤓 Filtra los resultados." };
  try {
    const sheet = SpreadsheetApp.openById(SPREADSHEET_ID).getSheetByName("Settings");
    if (!sheet) return defaultMessages;
    const homeMessages = sheet.getRange("B2:B").getValues().flat().filter(String);
    const resultsMessages = sheet.getRange("C2:C").getValues().flat().filter(String);
    const messagesToCache = {
      homeMessage: homeMessages.length > 0 ? homeMessages[Math.floor(Math.random() * homeMessages.length)] : defaultMessages.home,
      resultsMessage: resultsMessages.length > 0 ? resultsMessages[Math.floor(Math.random() * resultsMessages.length)] : defaultMessages.results
    };
    cache.put(CACHE_KEY_MSG, JSON.stringify(messagesToCache), 300); // Cache por 5 minutos
    return messagesToCache;
  } catch (e) { return defaultMessages; }
}

/** Define y devuelve los mapeos de colores para Áreas y Chapters. */
function getColorMappings() {
  return {
    areas: {
      // Paleta principal con tonos corporativos (SIN CAMBIOS)
      "Performance": "#C0392B",      // Rojo terracota
      "Supply Chain": "#16A085",     // Verde azulado (teal)
      "Finance": "#2980B9",         // Azul corporativo
      "Experience": "#8E44AD",      // Morado moderado
      "Operaciones": "#2980B9",      // Azul corporativo (consistente con Finanzas)
      "People": "#D35400",          // Naranja quemado
      "Marketing": "#5D6D7E",       // Gris azulado
      "Todo PeYa Market": "#7F8C8D", // Gris pizarra
      "Pricing": "#27AE60",         // Verde esmeralda
      "Assortment": "#34495E",      // Azul marino oscuro
      "Finance Strategy": "#2C3E50", // Azul medianoche (más oscuro que Finanzas)
      "Comercial": "#4c2882",
      "Customer Insights": "#efb810" // Violeta
    },

    // --- PALETA DE CHAPTERS AJUSTADA (COLORES MÁS VISIBLES) ---
    chapters: {
      "Demand Stimulation": "#e50044",          // Verde medio
      "Assortment, Pricing & Promo": "#4c2882", // Azul medio
      "Sustainability": "#008000",   // Dorado / Mostaza
      "Operational Excellence": "#00a0de",      // Lavanda medio
    },

    default: "#efb810" // Gris claro por defecto
  };
}

// =================================================================
// --- MANEJO DE CACHÉ Y otras funciones
function actualizarCacheCompleta() {
  Logger.log("Iniciando actualización de caché fragmentada y blindada...");
  try {
    const sheet = SpreadsheetApp.openById(SPREADSHEET_ID).getSheetByName(MAIN_SHEET_NAME);
    if (!sheet) throw new Error(`Pestaña no encontrada: ${MAIN_SHEET_NAME}`);

    const headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
    const colMap = {};
    // Guardamos los encabezados limpios y en minúsculas
    headers.forEach((header, i) => { if (header) colMap[String(header).trim().toLowerCase()] = i; });
    
    const allValues = sheet.getRange(2, 1, sheet.getLastRow() - 1, sheet.getLastColumn()).getValues();
    const allItems = [];
    
    for (let i = 0; i < allValues.length; i++) {
      const row = allValues[i];
      const get = (colName) => {
        const index = colMap[colName.toLowerCase().trim()];
        return index !== undefined ? row[index] : "";
      };

      // 1. Solo procesamos los que están "Activo"
      if (String(get('estado')).toLowerCase().trim() !== 'activo') continue; 

      const tituloArchivo = get('titulo del archivo');
      if (tituloArchivo) {
        // Validación por si la columna tiene espacio o guion bajo
        let equipoResp = get('equipo responsable');
        if (!equipoResp) equipoResp = get('equipo_responsable');

        allItems.push({ 
          id: get('id') || `gen_${i}`, 
          grupo: get('titulo_prioridad'), 
          nombreArchivo: tituloArchivo, 
          descripcion: get('descripción del archivo'), 
          pais: get('pais'), 
          owner: get('owner'), 
          ownerLink: get('link de slack - owner'), 
          link: get('link del archivo'), 
          plataforma: get('plataforma'), 
          chapterPrincipal: get('chapter'),   // Mapeado correctamente al Chapter
          categoria: equipoResp,              // Mapeado correctamente al Área
          palabrasClave: get('palabras clave')
        });
      }
    }

    const cache = CacheService.getScriptCache();
    
    // --- LÓGICA DE SEGMENTACIÓN (CHUNKS) PARA EVITAR ERROR DE LÍMITE DE TAMAÑO ---
    const MAX_CHUNK_BYTES = 80 * 1024; // 80KB para margen de seguridad
    let chunks = [];
    let currentChunk = [];

    for (const item of allItems) {
      currentChunk.push(item);
      if (JSON.stringify(currentChunk).length > MAX_CHUNK_BYTES) {
        const lastItem = currentChunk.pop(); 
        chunks.push(currentChunk);
        currentChunk = [lastItem];
      }
    }
    if (currentChunk.length > 0) chunks.push(currentChunk);

    // Guardar Metadatos
    const metaData = {
      uniqueAreas: [...new Set(allItems.map(item => item.categoria).filter(Boolean))].sort(),
      uniqueChapters: [...new Set(allItems.map(item => item.chapterPrincipal).filter(Boolean))].sort(),
      timestamp: new Date().toISOString(),
      chunkCount: chunks.length 
    };
    
    // Limpiar caché viejo antes de guardar para que no queden fantasmas
    cache.remove(CACHE_KEY_META);
    for (let i = 0; i < 20; i++) cache.remove(CACHE_KEY_CHUNK_PREFIX + i);

    // Guardar nuevos fragmentos
    cache.put(CACHE_KEY_META, JSON.stringify(metaData), 21600);
    chunks.forEach((chunkData, i) => {
      cache.put(CACHE_KEY_CHUNK_PREFIX + i, JSON.stringify(chunkData), 21600);
    });

    Logger.log("✅ ÉXITO: Se procesaron " + allItems.length + " reportes en " + chunks.length + " fragmentos.");

  } catch (e) {
    Logger.log("❌ ERROR CRÍTICO: " + e.message);
  }
}

/**
 * Obtiene los datos desde el caché, reensamblando los fragmentos. Si está vacío, fuerza una actualización. */
function obtenerDatosDelCache() {
  const cache = CacheService.getScriptCache();
  
  // PRIMER INTENTO de leer el caché
  let metaString = cache.get(CACHE_KEY_META);
  if (metaString) {
    try {
      // Si tenemos metadatos, intentamos reconstruir el objeto completo
      const metaData = JSON.parse(metaString);
      const chunkCount = metaData.chunkCount;
      const chunkKeys = Array.from({ length: chunkCount }, (_, i) => CACHE_KEY_CHUNK_PREFIX + i);
      
      const cachedChunks = cache.getAll(chunkKeys);
      let allItems = [];
      for (const key of chunkKeys) {
        if (!cachedChunks[key]) {
          throw new Error(`Falta el fragmento de caché: ${key}`);
        }
        allItems = allItems.concat(JSON.parse(cachedChunks[key]));
      }
      
      return {
        allItems: allItems,
        uniqueAreas: metaData.uniqueAreas,
        uniqueChapters: metaData.uniqueChapters,
        timestamp: metaData.timestamp
      };
    } catch (e) {
      Logger.log(`Error al leer o reensamblar el caché: ${e.toString()}. Se forzará la actualización.`);
    }
  }
  
  // Si llegamos aquí, el caché estaba vacío o corrupto. Lo reconstruimos.
  Logger.log("Caché vacío o corrupto. Forzando actualización...");
  actualizarCacheCompleta();
  
  // SEGUNDO Y ÚLTIMO INTENTO de leer el caché
  metaString = cache.get(CACHE_KEY_META);
  if (metaString) {
    try {
      // Reutilizamos la misma lógica de reconstrucción de arriba
      const metaData = JSON.parse(metaString);
      const chunkCount = metaData.chunkCount;
      const chunkKeys = Array.from({ length: chunkCount }, (_, i) => CACHE_KEY_CHUNK_PREFIX + i);
      const cachedChunks = cache.getAll(chunkKeys);
      let allItems = [];
      for (const key of chunkKeys) {
        allItems = allItems.concat(JSON.parse(cachedChunks[key]));
      }
      return { allItems: allItems, uniqueAreas: metaData.uniqueAreas, uniqueChapters: metaData.uniqueChapters, timestamp: metaData.timestamp };
    } catch (e) {
       Logger.log(`FALLO CRÍTICO: No se pudo leer el caché incluso después de actualizarlo. ${e.toString()}`);
    }
  }

  // Si todo falla, devuelve un objeto vacío para evitar que la app se rompa.
  return { allItems: [], uniqueAreas: [], uniqueChapters: [] };
}

/** Obtiene solo los reportes de acceso rápido para un usuario.
 * Se llama de forma asíncrona después de que la página principal ya cargó */
function getFavoriteReports() {
  try {
    const cachedData = obtenerDatosDelCache(); // Necesita la lista de todos los reportes para obtener los detalles
    const quickAccessReports = getQuickAccessReportsOptimized(cachedData.allItems);
    return quickAccessReports;
  } catch (e) {
    Logger.log(`ERROR en getFavoriteReports: ${e.message}`);
    return []; // Devuelve un array vacío en caso de error
  }
}

// =================================================================
// --- FUNCIONES DE DEPURACIÓN (PARA EL DESARROLLADOR) ---

/** Función de prueba para la lógica de filtrado de la página de resultados. */
function probarObtenerDatosDesdeSheet() {
  const testFilter = { filter: "Performance", filterType: "general" };
  Logger.log("--- INICIANDO PRUEBA DE obtenerDatosParaResultados ---");
  Logger.log("Filtro de prueba: " + JSON.stringify(testFilter));
  const resultados = obtenerDatosParaResultados(testFilter);
  Logger.log("--- RESULTADO DE LA PRUEBA ---");
  if (resultados.error) {
    Logger.log("ERROR: " + resultados.error);
  } else if (resultados.length !== undefined) {
    Logger.log(`ÉXITO: Se encontraron ${resultados.length} resultados.`);
    if (resultados.length > 0) {
      Logger.log("Ejemplo del primer resultado: " + JSON.stringify(resultados[0]));
    }
  } else {
    Logger.log("ERROR INESPERADO: La función no devolvió un array ni un objeto de error.");
  }
}

function probarObtenerDatosDesdeCache() {
  const testFilter = { filter: "Performance", filterType: "general" };
  
  Logger.log("--- INICIANDO PRUEBA DE obtenerDatosParaResultados (desde CACHÉ) ---");
  Logger.log("Filtro de prueba: " + JSON.stringify(testFilter));

  const resultados = obtenerDatosParaResultados(testFilter);

  Logger.log("--- RESULTADO DE LA PRUEBA ---");
  if (resultados.error) {
    Logger.log("ERROR: " + resultados.error);
  } else if (resultados.length !== undefined) {
    Logger.log(`ÉXITO: Se encontraron ${resultados.length} resultados.`);
    
    // Mostramos el array completo en la consola de forma legible
    Logger.log("Resultados completos: %s", JSON.stringify(resultados, null, 2));

  } else {
    Logger.log("ERROR INESPERADO: La función no devolvió un array ni un objeto de error.");
  }
}
// AGREGA ESTO AL FINAL
function crearTriggerParaActualizarCache() {
  const triggersExistentes = ScriptApp.getProjectTriggers();
  for (const trigger of triggersExistentes) {
    if (trigger.getHandlerFunction() === "actualizarCacheCompleta") {
      ScriptApp.deleteTrigger(trigger);
    }
  }

  ScriptApp.newTrigger("actualizarCacheCompleta")
    .timeBased()
    .everyHours(1)
    .create();

  Logger.log("¡Trigger creado con éxito! El caché se actualizará automáticamente cada hora.");
}
