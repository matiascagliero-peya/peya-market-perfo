// --- CONFIGURACIÓN ---
const reportName = "Glosario de Métricas";
const SPREADSHEET_ID = '1PyynFYXHCjv0iZPA0v75hrdUrzUDF0Qa04Yu26z0Zws';
const METRICS_SHEET_NAME = '0. Glosario unificado';
const LOG_SHEET_NAME = 'Estadisticas'; // Nombre de la nueva hoja de logs

/**
 * Función principal que se ejecuta al acceder a la URL.
 * Lee parámetros de ID, Nombre o Búsqueda y los pasa a la plantilla HTML.
 */
function doGet(e) {
  // 1. USA createTemplateFromFile
  let html = HtmlService.createTemplateFromFile('Index');

  // 2. Asigna variables (si las usas)
  html.baseUrl = ScriptApp.getService().getUrl();
  html.startMetricId = e.parameter.metricId || null;
  html.startMetricName = e.parameter.metricName || null;
  html.startSearchTerm = e.parameter.q || null;
  html.reportName = reportName; // Asumiendo que 'reportName' es una variable global

  // 3. USA .evaluate() AL FINAL
  return html.evaluate()
    .setTitle(reportName + " - PeYa") // Asegúrate que reportName exista aquí también
    .addMetaTag('viewport', 'width=device-width, initial-scale=1.0')
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);
}

/**
 * Obtiene, ordena y enriquece los datos de las métricas desde la hoja principal.
 */
function getMetricsData() {
  try {
    const sheet = SpreadsheetApp.openById(SPREADSHEET_ID).getSheetByName(METRICS_SHEET_NAME);
    const allValues = sheet.getDataRange().getValues();

    const headers = allValues.shift().map(h => h.trim());

    const headerMap = {};
    headers.forEach((header, index) => {
      headerMap[header] = index;
    });

    let data = allValues.map(row => {
      if (row.join('').trim() === '') return null;

      return {
        "Id": row[headerMap['Id']],
        "Orden": row[headerMap['Orden']],
        "Categoria": row[headerMap['Categoría']],
        "Metrica": row[headerMap['Métrica']],
        "Description": row[headerMap['Description']],
        "Chapter": row[headerMap['Chapter']],
        "Formula": row[headerMap['Formula']],
        "Fuente": row[headerMap['Fuente']],
        "Owner": row[headerMap['Owner de referencia']],
        "OwnerSlackLink": row[headerMap['Link a slack']],
        "Example": row[headerMap['Example']] // Lee la columna 'Example'
      };
    })
      .filter(row => row && row.Id && row.Metrica && row.Description);

    data.forEach(metric => {
      // Establece "Confirmed Orders" como la métrica por defecto al cargar.
      if (metric.Metrica === "Confirmed Orders") {
        metric.isRecommended = true;
      }
    });

    // Ordenamos alfabéticamente por el nombre de la métrica por defecto.
    data.sort((a, b) => a.Metrica.localeCompare(b.Metrica));

    return JSON.stringify(data);

  } catch (e) {
    Logger.log(e.toString());
  	return JSON.stringify({ error: `No se pudo procesar la hoja de cálculo. Revisa que el ID, nombre de pestaña y los encabezados de columna (incluido 'Example') sean correctos. Error: ${e.message}` });
 }
}

/**
 * Obtiene el contenido de un archivo de texto (SQL) desde un link de Google Drive.
 * @param {string} driveUrl - El link completo al archivo de Google Drive.
 * @return {string} El contenido del archivo o un mensaje de error.
*/
function getSqlExample(driveUrl) {
  if (!driveUrl || typeof driveUrl !== 'string') {
    return "No se proporcionó un link válido.";
  }

  let fileId = null;
  
  // Regex para extraer el ID de formatos:
  // .../d/FILE_ID/edit...
  // .../file/d/FILE_ID/...
  // ...open?id=FILE_ID...
  const regex1 = /\/d\/([a-zA-Z0-9_-]{28,})/; // Formato /d/FILE_ID
  const regex2 = /id=([a-zA-Z0-9_-]{28,})/;   // Formato id=FILE_ID
  
  let match = driveUrl.match(regex1);
  if (match && match[1]) {
    fileId = match[1];
  } else {
    match = driveUrl.match(regex2);
    if (match && match[1]) {
      fileId = match[1];
    }
  }

  if (!fileId) {
    Logger.log(`No se pudo extraer el File ID de la URL: ${driveUrl}`);
    return `Link de "Example" no es un formato de Google Drive reconocible.`;
  }

  try {
    const file = DriveApp.getFileById(fileId);
    const content = file.getBlob().getDataAsString();
    return content;
  } catch (e) {
    Logger.log(`Error al leer el archivo de Drive ${fileId}: ${e.message}`);
  	return `Error al leer el archivo SQL: ${e.message}. \n\nAsegúrate de que el archivo es "Público en la web" o está compartido con cualquier persona que tenga el enlace.`;
  }
}


/**
 * Registra un evento de usuario en la hoja 'Estadisticas'.
 * Crea la hoja si no existe con los encabezados.
 * @param {Object} eventData - { type: string, value: string, device: string }
 */
function logUserEvent(eventData) {
  const sheetId = SPREADSHEET_ID;
  const logSheetName = LOG_SHEET_NAME;

  try {
    const ss = SpreadsheetApp.openById(sheetId);
  	let logSheet = ss.getSheetByName(logSheetName);

  	// Si la hoja no existe, la crea con los encabezados.
  	if (!logSheet) {
      logSheet = ss.insertSheet(logSheetName);
      const headers = [
        "Timestamp", "Año", "Mes", "Dia", "UserEmail",
        "Dispositivo", "EventType", "EventValue"
      ];
      logSheet.getRange(1, 1, 1, headers.length).setValues([headers]);
  	}

  	// Obtener la información de la sesión
  	const userEmail = Session.getActiveUser().getEmail();
  	const timestamp = new Date();

  	// Preparar la fila de datos
  	const year = timestamp.getFullYear();
  	const month = timestamp.getMonth() + 1; // getMonth() es 0-indexado
  	const day = timestamp.getDate();

  	const row = [
      timestamp,
      year,
      month,
      day,
      userEmail,
      eventData.device || 'Desconocido',
      eventData.type,
      eventData.value || ''
  	];

  	// Añadir la nueva fila al final de la hoja
  	logSheet.appendRow(row);

  	return { success: true };

  } catch (e) {
    Logger.log(`Error al registrar el evento: ${e.toString()}`);
  	return { success: false, error: e.message };
  }
}

/**
 * Busca la definición de una métrica (nombre, descripción, fórmula, etc.)
 * a partir de su nombre.
 *
 * @param {string} metricName El nombre de la métrica a buscar (e.g., "Confirmed Orders").
 * @param {string} [field="Description"] El campo a devolver: "Description", "Formula", "Owner", etc.
 * @return {string} La definición o valor del campo solicitado.
 * @customfunction
 */
function GET_METRIC_DEFINITION(metricName, field = "Description") {
  // Asegurarse de que el input es una cadena y no está vacío
  if (typeof metricName !== 'string' || !metricName.trim()) {
  	return 'Nombre de métrica inválido';
  }
  
  // 1. Obtener los datos de las métricas (usando tu función existente)
  const dataString = getMetricsData(); 
  let metrics;
  try {
    metrics = JSON.parse(dataString);
  } catch (e) {
    return 'Error al obtener datos del glosario.';
  }

  if (metrics.error) {
  	return metrics.error; 
  }

  // 2. Buscar la métrica por su nombre
  const targetMetric = metrics.find(m => 
    String(m.Metrica).trim().toLowerCase() === String(metricName).trim().toLowerCase()
  );

  if (!targetMetric) {
    return 'Métrica no encontrada: ' + metricName;
  }

  // 3. Devolver el campo solicitado
  const normalizedField = field.trim();
  const result = targetMetric[normalizedField];

  // Si el valor es nulo, indefinido o vacío, devolver un mensaje por defecto.
  if (result === undefined || result === null || String(result).trim() === "") {
    return `Campo '${field}' no disponible.`;
  }
  
  return result;
}