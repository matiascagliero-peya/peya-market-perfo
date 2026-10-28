// ====================================================================================
// PROYECTO: Update - Reporte User 360 (Lifecycle & Metrics Summary)
// DESCRIPCIÓN: Tres funciones independientes de ejecución:
//              1. importar()   : Lee '1. ET - Metrics Summary' y guarda en '0 - Metrics Summary'.
//              2. consolidar() : Lee '0 - Metrics Summary', agrupa sobre DY/UF y genera
//                                las métricas oficiales L1 (MAUs, New Users, etc.) y L2
//                                para Dmart, PeYa Food y AAA (con consolidado regional LATAM).
//                                Salida en 5 columnas: Metric | Country | Month | Value | formato de color.
//              3. enviar()     : Lee '1. Consolidado User 360' y escribe en el destino (gid=1705705164).
//              4. ejecutarTodo(): Ejecuta importar -> consolidar -> enviar.
// AUTOR: Matias Cagliero / PeYa Market Analytics
// ====================================================================================

// ====================================================================================
// 1. CONFIGURACIÓN GLOBAL
// ====================================================================================

// A. Archivo de Origen
const ID_ARCHIVO_ORIGEN_ET    = "1X0bnsCoDszeSlq5TT1uw20GWtcfu1iBpshXXI1QIv7M";
const NOMBRE_HOJA_ORIGEN_ET   = "1. ET - Metrics Summary";
const GID_HOJA_ORIGEN_ET      = 268251089;

// B. Archivo Maestro de Update
const ID_ARCHIVO_UPDATE       = "1XTjLS_VZuID-bQRvvcADlg2M2idy1SoWVLrIHIk24fA";
const NOMBRE_HOJA_IMPORTADA   = "0 - Metrics Summary";
const HOJA_STAGING_LOCAL      = "1. Consolidado User 360";

// C. Archivo de Envío
const ID_ARCHIVO_ENVIO        = "1KRypViJtd2V7-st7TjRyWMSTIEPXrWm3fHQbs1KG9X0";
const GID_DESTINO_ACTUALS     = 1705705164;
const NOMBRE_HOJA_DESTINO     = "A. TI - Actuals User 360";

// D. Países oficiales considerados para el reporte y cálculo de LATAM
const U360_PAISES_PERMITIDOS = [
  "Argentina",
  "Bolivia",
  "Chile",
  "Colombia",
  "Dominican Republic",
  "Ecuador",
  "El Salvador",
  "Guatemala",
  "Honduras",
  "Nicaragua",
  "Panama",
  "Paraguay",
  "Peru",
  "Uruguay"
];

// ====================================================================================
// 2. CACHÉ Y HELPERS
// ====================================================================================
const _ssCache = {};
function obtenerSpreadsheet(id) {
  const cleanId = String(id).trim();
  if (!_ssCache[cleanId]) {
    try {
      const active = SpreadsheetApp.getActiveSpreadsheet();
      if (active && active.getId() === cleanId) {
        _ssCache[cleanId] = active;
      }
    } catch (_) {}
    if (!_ssCache[cleanId]) {
      _ssCache[cleanId] = SpreadsheetApp.openById(cleanId);
    }
  }
  return _ssCache[cleanId];
}

function quitarFiltros(sheet) {
  if (sheet && sheet.getFilter()) {
    try { sheet.getFilter().remove(); } catch (_) {}
  }
}

function obtenerHojaPorGidONombre(ss, gidEsperado, nombreFallback) {
  const sheets = ss.getSheets();
  for (let i = 0; i < sheets.length; i++) {
    if (sheets[i].getSheetId() === Number(gidEsperado)) {
      return sheets[i];
    }
  }
  return ss.getSheetByName(nombreFallback);
}

// ====================================================================================
// 3. FUNCIÓN 1: IMPORTAR
// ====================================================================================

/**
 * Lee de forma directa '1. ET - Metrics Summary' y guarda la copia en '0 - Metrics Summary'.
 */
function importar() {
  Logger.log("Iniciando importacion desde: " + NOMBRE_HOJA_ORIGEN_ET);

  const ssOrigen = obtenerSpreadsheet(ID_ARCHIVO_ORIGEN_ET);
  const hojaOrigen = obtenerHojaPorGidONombre(ssOrigen, GID_HOJA_ORIGEN_ET, NOMBRE_HOJA_ORIGEN_ET);

  if (!hojaOrigen) {
    throw new Error("No se encontro la hoja origen '" + NOMBRE_HOJA_ORIGEN_ET + "' en " + ID_ARCHIVO_ORIGEN_ET);
  }

  const rawData = hojaOrigen.getDataRange().getValues();
  if (rawData.length < 2) {
    throw new Error("La hoja origen contiene datos insuficientes.");
  }

  Logger.log("Filas leidas: " + rawData.length);

  const ssUpdate = obtenerSpreadsheet(ID_ARCHIVO_UPDATE);
  let hojaDestino = ssUpdate.getSheetByName(NOMBRE_HOJA_IMPORTADA);
  if (!hojaDestino) {
    hojaDestino = ssUpdate.insertSheet(NOMBRE_HOJA_IMPORTADA);
  }

  quitarFiltros(hojaDestino);
  hojaDestino.clearContents();

  const totalFilas = rawData.length;
  const totalCols  = rawData[0].length;

  if (hojaDestino.getMaxRows() < totalFilas) {
    hojaDestino.insertRowsAfter(hojaDestino.getMaxRows(), totalFilas - hojaDestino.getMaxRows());
  }
  if (hojaDestino.getMaxColumns() < totalCols) {
    hojaDestino.insertColumnsAfter(hojaDestino.getMaxColumns(), totalCols - hojaDestino.getMaxColumns());
  }

  const BATCH_SIZE = 10000;
  for (let i = 0; i < totalFilas; i += BATCH_SIZE) {
    const chunk = rawData.slice(i, i + BATCH_SIZE);
    hojaDestino.getRange(i + 1, 1, chunk.length, totalCols).setValues(chunk);
  }

  const maxRowsFin = hojaDestino.getMaxRows();
  if (maxRowsFin > totalFilas + 1000) {
    try { hojaDestino.deleteRows(totalFilas + 1, maxRowsFin - totalFilas); } catch (_) {}
  }

  SpreadsheetApp.flush();
  Logger.log("Importacion completada en: " + NOMBRE_HOJA_IMPORTADA);
  return totalFilas;
}

// ====================================================================================
// 4. FUNCIÓN 2: CONSOLIDAR (Métricas L1 y L2 sin desglose de DY/UF)
// ====================================================================================

/**
 * Lee '0 - Metrics Summary', agrupa sobre DY/UF y genera las métricas oficiales L1 y L2:
 * Dmart (Market), PeYa Food (Platform) y AAA (Supermercados), con consolidado LATAM.
 */
function consolidar() {
  Logger.log("Iniciando consolidacion desde: " + NOMBRE_HOJA_IMPORTADA);

  const ssLocal = obtenerSpreadsheet(ID_ARCHIVO_UPDATE);
  let hojaImportada = ssLocal.getSheetByName(NOMBRE_HOJA_IMPORTADA);

  if (!hojaImportada || hojaImportada.getDataRange().getValues().length < 2) {
    Logger.log("No se encontraron datos en '" + NOMBRE_HOJA_IMPORTADA + "'. Ejecutando importar() primero...");
    importar();
    hojaImportada = ssLocal.getSheetByName(NOMBRE_HOJA_IMPORTADA);
  }

  const rawData = hojaImportada.getDataRange().getValues();
  if (rawData.length < 2) {
    throw new Error("La hoja '" + NOMBRE_HOJA_IMPORTADA + "' no contiene datos para consolidar.");
  }

  const headers = rawData[0].map(h => String(h).trim().toUpperCase());

  let colIdx = {
    mes: headers.findIndex(h => ["MES", "MONTH", "FECHA"].includes(h)),
    country: headers.findIndex(h => ["COUNTRY", "PAIS"].includes(h)),
    business: headers.findIndex(h => ["BUSINESS", "NEGOCIO"].includes(h)),
    l1: headers.findIndex(h => ["L1", "LEVEL_1", "MARKET_ACTUAL_TYPE"].includes(h)),
    l2: headers.findIndex(h => ["L2", "LEVEL_2", "L2_MARKET_ACTUAL_TYPE"].includes(h)),
    users_count: headers.findIndex(h => ["USERS_COUNT"].includes(h))
  };

  // Fallback posicional
  if (colIdx.mes === -1 && rawData[0].length >= 8) {
    colIdx = { mes: 0, country: 1, business: 2, l1: 5, l2: 6, users_count: 7 };
  }

  if (colIdx.mes === -1 || colIdx.country === -1 || colIdx.business === -1 || colIdx.l1 === -1 || colIdx.users_count === -1) {
    throw new Error("Encabezados indispensables ausentes. Detectados: " + headers.join(", "));
  }

  // Estructuras de acumulación (agrupando e ignorando DY y UF)
  const l1Map = {};       // Clave: `${mesKey}|${country}|${business}|${l1}`
  const l2Map = {};       // Clave: `${mesKey}|${country}|${business}|${l2}`
  const dateObjMap = {};  // Clave: `${mesKey}` -> Date object

  for (let r = 1; r < rawData.length; r++) {
    const fila = rawData[r];
    const mesVal = fila[colIdx.mes];
    const country = String(fila[colIdx.country] || '').trim();
    const business = String(fila[colIdx.business] || '').trim();
    const l1 = String(fila[colIdx.l1] || '').trim();
    const l2 = colIdx.l2 !== -1 ? String(fila[colIdx.l2] || '').trim() : '';

    if (!mesVal || !country || !business || !l1) continue;

    const uCount = parseFloat(fila[colIdx.users_count]) || 0;
    if (uCount === 0) continue;

    let mesDate = (mesVal instanceof Date) ? mesVal : new Date(mesVal);
    let mesKey = Utilities.formatDate(mesDate, "GMT", "yyyy-MM-01");
    if (!dateObjMap[mesKey]) dateObjMap[mesKey] = mesDate;

    // 1. Acumular L1 por país
    const kL1 = `${mesKey}|${country}|${business}|${l1}`;
    l1Map[kL1] = (l1Map[kL1] || 0) + uCount;

    // 2. Acumular L2 por país (si tiene un L2 válido y distinto de L1 o '-')
    if (l2 && l2 !== '-' && l2 !== 'Total' && l2.toUpperCase() !== l1.toUpperCase()) {
      const kL2 = `${mesKey}|${country}|${business}|${l2}`;
      l2Map[kL2] = (l2Map[kL2] || 0) + uCount;
    }

    // 3. Acumular para LATAM si es país oficial
    const esPaisValido = U360_PAISES_PERMITIDOS.map(p => p.toUpperCase()).includes(country.toUpperCase());
    if (country.toUpperCase() !== "LATAM" && esPaisValido) {
      const kL1_Latam = `${mesKey}|LATAM|${business}|${l1}`;
      l1Map[kL1_Latam] = (l1Map[kL1_Latam] || 0) + uCount;

      if (l2 && l2 !== '-' && l2 !== 'Total' && l2.toUpperCase() !== l1.toUpperCase()) {
        const kL2_Latam = `${mesKey}|LATAM|${business}|${l2}`;
        l2Map[kL2_Latam] = (l2Map[kL2_Latam] || 0) + uCount;
      }
    }
  }

  // Generación de registros finales en 5 columnas
  const filasActuals = [];

  // Mapear sufijo de negocio
  function getBusinessTag(b) {
    const bUp = String(b || '').toUpperCase();
    if (bUp === 'MARKET') return 'Dmart';
    if (bUp === 'AAA') return 'AAA';
    if (bUp === 'PLATFORM') return 'PeYa Food';
    return b;
  }

  // Identificar países y meses únicos para calcular MAUs
  const contextKeys = {};
  for (const k in l1Map) {
    const parts = k.split("|");
    const ctx = `${parts[0]}|${parts[1]}|${parts[2]}`; // mesKey|country|business
    if (!contextKeys[ctx]) contextKeys[ctx] = {};
    contextKeys[ctx][parts[3]] = l1Map[k];
  }

  // Estados considerados activos para MAUs
  const activeStates = ['NEW USER', 'M1 RETURN', 'REACTIVATION', 'RE-ACTIVATION', 'RE-ORDER', 'REORDER', 'RECURRING RETURN'];

  for (const ctx in contextKeys) {
    const [mesKey, country, business] = ctx.split("|");
    const states = contextKeys[ctx];
    const mesDate = dateObjMap[mesKey];
    const tag = getBusinessTag(business);

    let mausCount = 0;
    let churnedCount = 0;
    let neverActiveCount = 0;

    for (const st in states) {
      const stUp = st.toUpperCase();
      const val = states[st];

      if (activeStates.includes(stUp)) {
        mausCount += val;
      } else if (stUp === 'CHURNED') {
        churnedCount += val;
      } else if (stUp === 'NEVER ACTIVE') {
        neverActiveCount += val;
      }

      // Nombre específico de L1
      let l1MetricName = "";
      if (stUp === 'NEW USER') {
        l1MetricName = `New Users - ${tag}`;
      } else if (stUp === 'M1 RETURN') {
        l1MetricName = `M1 Return Users - ${tag}`;
      } else if (stUp === 'REACTIVATION' || stUp === 'RE-ACTIVATION') {
        l1MetricName = `Re-Activation Users - ${tag}`;
      } else if (stUp === 'RE-ORDER' || stUp === 'REORDER') {
        l1MetricName = `Reorder Users - ${tag}`;
      } else if (stUp === 'RECURRING RETURN') {
        l1MetricName = `Recurring Return - ${tag}`;
      } else if (stUp === 'CHURNED') {
        l1MetricName = `Churned Users - ${tag}`;
      } else if (stUp === 'NEVER ACTIVE') {
        l1MetricName = `Never Active - ${tag}`;
      } else {
        l1MetricName = `${st} - ${tag}`;
      }

      filasActuals.push([l1MetricName, country, mesDate, val, 1]);
    }

    // Métrica de MAUs
    let mausMetricName = "";
    if (tag === 'Dmart') {
      mausMetricName = "Dmart MAUs";
    } else if (tag === 'PeYa Food') {
      mausMetricName = "PeYa food MAUs";
    } else if (tag === 'AAA') {
      mausMetricName = "PeYa MAUs";
    } else {
      mausMetricName = `${tag} MAUs`;
    }
    filasActuals.push([mausMetricName, country, mesDate, mausCount, 1]);

    // Total Churned Users
    if (churnedCount > 0) {
      filasActuals.push([`Total Churned Users - ${tag}`, country, mesDate, churnedCount, 1]);
    }
  }

  // Generar métricas L2
  for (const k in l2Map) {
    const [mesKey, country, business, l2] = k.split("|");
    const mesDate = dateObjMap[mesKey];
    const tag = getBusinessTag(business);
    const val = l2Map[k];

    // Formatear nombre de L2
    let l2MetricName = l2.trim();
    if (!l2MetricName.toUpperCase().endsWith(`- ${tag.toUpperCase()}`)) {
      l2MetricName = `${l2MetricName} - ${tag}`;
    }

    filasActuals.push([l2MetricName, country, mesDate, val, 1]);
  }

  // Guardar en '1. Consolidado User 360' (5 columnas estrictas)
  let hojaStaging = ssLocal.getSheetByName(HOJA_STAGING_LOCAL);
  if (!hojaStaging) {
    hojaStaging = ssLocal.insertSheet(HOJA_STAGING_LOCAL);
  }

  quitarFiltros(hojaStaging);
  hojaStaging.clearContents();

  const encabezados = ["Metric", "Country", "Month", "Value", "formato de color"];
  const totalFilas = filasActuals.length + 1;
  const totalCols = encabezados.length;

  if (hojaStaging.getMaxRows() < totalFilas) {
    hojaStaging.insertRowsAfter(hojaStaging.getMaxRows(), totalFilas - hojaStaging.getMaxRows());
  }
  if (hojaStaging.getMaxColumns() < totalCols) {
    hojaStaging.insertColumnsAfter(hojaStaging.getMaxColumns(), totalCols - hojaStaging.getMaxColumns());
  } else if (hojaStaging.getMaxColumns() > totalCols) {
    try { hojaStaging.deleteColumns(totalCols + 1, hojaStaging.getMaxColumns() - totalCols); } catch (_) {}
  }

  hojaStaging.getRange(1, 1, 1, totalCols).setValues([encabezados]).setFontWeight("bold");

  const BATCH_SIZE = 10000;
  for (let i = 0; i < filasActuals.length; i += BATCH_SIZE) {
    const chunk = filasActuals.slice(i, i + BATCH_SIZE);
    hojaStaging.getRange(i + 2, 1, chunk.length, totalCols).setValues(chunk);
  }

  hojaStaging.getRange(2, 3, filasActuals.length, 1).setNumberFormat("MMM-yyyy");

  const finalRows = hojaStaging.getMaxRows();
  if (finalRows > totalFilas + 200) {
    try { hojaStaging.deleteRows(totalFilas + 1, finalRows - totalFilas); } catch (_) {}
  }

  SpreadsheetApp.flush();
  Logger.log("Consolidacion completada: " + filasActuals.length + " filas guardadas en " + HOJA_STAGING_LOCAL);
  return filasActuals.length;
}

// ====================================================================================
// 5. FUNCIÓN 3: ENVIAR
// ====================================================================================

/**
 * Lee '1. Consolidado User 360' y exporta al libro de envío (gid=1705705164).
 */
function enviar() {
  Logger.log("Iniciando envio hacia: " + ID_ARCHIVO_ENVIO);

  const ssLocal = obtenerSpreadsheet(ID_ARCHIVO_UPDATE);
  let hojaStaging = ssLocal.getSheetByName(HOJA_STAGING_LOCAL);

  if (!hojaStaging || hojaStaging.getDataRange().getValues().length < 2) {
    Logger.log("No se encontro consolidado en '" + HOJA_STAGING_LOCAL + "'. Ejecutando consolidar() primero...");
    consolidar();
    hojaStaging = ssLocal.getSheetByName(HOJA_STAGING_LOCAL);
  }

  const vals = hojaStaging.getDataRange().getValues();
  if (vals.length < 2) {
    throw new Error("La hoja '" + HOJA_STAGING_LOCAL + "' esta vacia.");
  }

  const filasActuals = vals.slice(1);
  const encabezados = vals[0];

  const ssDestino = obtenerSpreadsheet(ID_ARCHIVO_ENVIO);
  const hojaDestino = obtenerHojaPorGidONombre(ssDestino, GID_DESTINO_ACTUALS, NOMBRE_HOJA_DESTINO);

  if (!hojaDestino) {
    throw new Error("No se pudo obtener la hoja de destino en " + ID_ARCHIVO_ENVIO);
  }

  quitarFiltros(hojaDestino);
  hojaDestino.clearContents();

  const totalFilas = filasActuals.length + 1;
  const totalCols  = encabezados.length;

  const maxFilasActual = hojaDestino.getMaxRows();
  if (maxFilasActual < totalFilas) {
    hojaDestino.insertRowsAfter(maxFilasActual, totalFilas - maxFilasActual);
  }
  const maxColsActual = hojaDestino.getMaxColumns();
  if (maxColsActual < totalCols) {
    hojaDestino.insertColumnsAfter(maxColsActual, totalCols - maxColsActual);
  } else if (maxColsActual > totalCols) {
    try { hojaDestino.deleteColumns(totalCols + 1, maxColsActual - totalCols); } catch (_) {}
  }

  hojaDestino.getRange(1, 1, 1, totalCols)
             .setValues([encabezados])
             .setFontWeight("bold")
             .setBackground("#E8EAED");

  const BATCH_SIZE = 10000;
  for (let i = 0; i < filasActuals.length; i += BATCH_SIZE) {
    const chunk = filasActuals.slice(i, i + BATCH_SIZE);
    hojaDestino.getRange(i + 2, 1, chunk.length, totalCols).setValues(chunk);
  }

  hojaDestino.getRange(2, 3, filasActuals.length, 1).setNumberFormat("MMM-yyyy");

  const filasFinales = hojaDestino.getMaxRows();
  if (filasFinales > totalFilas + 200) {
    try { hojaDestino.deleteRows(totalFilas + 1, filasFinales - totalFilas); } catch (_) {}
  }

  SpreadsheetApp.flush();
  Logger.log("Envio completado con exito en: " + hojaDestino.getName() + " (" + filasActuals.length + " filas)");
  return filasActuals.length;
}

// ====================================================================================
// 6. FUNCIÓN MAESTRA Y MENÚ DE USUARIO
// ====================================================================================

/**
 * Ejecuta el ciclo completo: importar -> consolidar -> enviar.
 */
function ejecutarTodo() {
  Logger.log("Iniciando ejecucion completa User 360");
  try {
    importar();
    consolidar();
    const filasEnviadas = enviar();

    Logger.log("Ejecucion completa finalizada con exito.");
    try {
      SpreadsheetApp.getUi().alert("Actualizacion Exitosa", 
        "Se procesaron y enviaron " + filasEnviadas + " filas al reporte User 360.", 
        SpreadsheetApp.getUi().ButtonSet.OK);
    } catch (_) {}

  } catch (err) {
    Logger.log("Error critico: " + err.message);
    try {
      SpreadsheetApp.getUi().alert("Error en Actualizacion", err.message, SpreadsheetApp.getUi().ButtonSet.OK);
    } catch (_) {}
  }
}

function onOpen() {
  try {
    const ui = SpreadsheetApp.getUi();
    ui.createMenu("User 360 Update")
      .addItem("1. Ejecutar Todo (Importar + Consolidar + Enviar)", "ejecutarTodo")
      .addSeparator()
      .addItem("2. Importar", "importar")
      .addItem("3. Consolidar", "consolidar")
      .addItem("4. Enviar", "enviar")
      .addSeparator()
      .addItem("5. Verificar Conexiones", "verificarConexiones")
      .addToUi();
  } catch (_) {}
}

function verificarConexiones() {
  try {
    const ssOrigen = obtenerSpreadsheet(ID_ARCHIVO_ORIGEN_ET);
    const hojaOrigen = obtenerHojaPorGidONombre(ssOrigen, GID_HOJA_ORIGEN_ET, NOMBRE_HOJA_ORIGEN_ET);

    const ssUpdate = obtenerSpreadsheet(ID_ARCHIVO_UPDATE);

    const ssEnvio = obtenerSpreadsheet(ID_ARCHIVO_ENVIO);
    const hojaEnvio = obtenerHojaPorGidONombre(ssEnvio, GID_DESTINO_ACTUALS, NOMBRE_HOJA_DESTINO);

    const msj = "Verificacion de Conexiones:\n\n" +
      "1. Origen:\n   - Libro: " + ssOrigen.getName() + "\n   - Hoja: " + (hojaOrigen ? hojaOrigen.getName() : "NO ENCONTRADA") + "\n\n" +
      "2. Update:\n   - Libro: " + ssUpdate.getName() + "\n\n" +
      "3. Envio:\n   - Libro: " + ssEnvio.getName() + "\n   - Hoja: " + (hojaEnvio ? hojaEnvio.getName() : "NO ENCONTRADA");

    SpreadsheetApp.getUi().alert("Conexiones Verificadas", msj, SpreadsheetApp.getUi().ButtonSet.OK);
  } catch (e) {
    SpreadsheetApp.getUi().alert("Error de Conexion", e.message, SpreadsheetApp.getUi().ButtonSet.OK);
  }
}
