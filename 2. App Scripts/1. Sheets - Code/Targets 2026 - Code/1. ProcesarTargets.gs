// ============================================================
// SCRIPT: Procesador de Targets Mensuales y Diarios
// ============================================================

// ------------------------------------------------------------
// NOTA: El menú se encuentra unificado en "2. Targets block.gs"
// para evitar colisiones del evento onOpen().
// ------------------------------------------------------------

// ============================================================
// MENSUAL (VERSIÓN CORREGIDA CON ESCUDO ANTIPÁNICO)
// Lee "Targets - Mensual" y escribe en "A. Export Targets-Mensual"
// ============================================================
function procesarTargets() {

  const ss           = SpreadsheetApp.getActiveSpreadsheet();
  const sheetOrigen  = ss.getSheetByName('Targets - Mensual');
  const sheetDestino = ss.getSheetByName('A. Export Targets-Mensual');

  if (!sheetOrigen) {
    SpreadsheetApp.getUi().alert('❌ Error: No se encontró la hoja "Targets - Mensual".');
    return;
  }

  const data = sheetOrigen.getDataRange().getValues();

  // --------------------------------------------------------
  // AJUSTES DE COORDENADAS
  // --------------------------------------------------------
  const FILA_ENCABEZADOS_FECHA = 1;   // Fila 2 (Donde están Jan-26, Feb-26... Índice 1)
  const FILA_DATOS_INICIO      = 2;   // Fila 3 en adelante (Datos reales de métricas)
  const COL_CLAVE              = 4;   // Columna E (Índice 4)
  const COL_FECHAS_INICIO      = 18;  // Columna S (Índice 18)

  const output = [
    ['Metric', 'Country', 'Month', 'Value']
  ];

  const filaFechas = data[FILA_ENCABEZADOS_FECHA];
  
  // --- VALIDACIÓN 1: Verificar que se encuentren fechas ---
  let fechasEncontradas = 0;
  for (let j = COL_FECHAS_INICIO; j < filaFechas.length; j++) {
    if (filaFechas[j] instanceof Date) {
      fechasEncontradas++;
    }
  }
  
  if (fechasEncontradas === 0) {
    SpreadsheetApp.getUi().alert('⚠️ ALERTA: No encontré fechas válidas en la Fila 2 a partir de la Columna S.');
    return;
  }

  let registrosProcesados = 0;

  // --------------------------------------------------------
  // BUCLE PRINCIPAL DE PROCESAMIENTO
  // --------------------------------------------------------
  for (let i = FILA_DATOS_INICIO; i < data.length; i++) {
    const fila  = data[i];
    const clave = fila[COL_CLAVE]; // Lee la Columna E

    // 1. Ignorar vacíos o filas de encabezado repetidas
    if (!clave || clave.toString().trim() === '')  continue;
    if (clave.toString() === 'Clave de búsqueda')  continue;

    let metric  = '';
    let country = '';

    // 2. Separar métrica y país
    const SEPARADOR    = ' - ';
    const posSeparador = clave.indexOf(SEPARADOR);

    if (posSeparador !== -1) {
      metric  = clave.substring(0, posSeparador).trim();
      country = clave.substring(posSeparador + SEPARADOR.length).trim();
    } else {
      metric  = clave;
      country = 'General';
    }

    metric = metric + ' - Target';
    registrosProcesados++;

    // 3. Recorrer las columnas de los meses (Desde la Columna S)
    for (let j = COL_FECHAS_INICIO; j < fila.length; j++) {
      const encabezadoFecha = filaFechas[j];
      let   valor           = fila[j];

      // 🔥 CORRECCIÓN: Si el encabezado no es una fecha válida (ej: texto "2026" o Totales), se ignora la columna
      if (!(encabezadoFecha instanceof Date)) continue;

      // Limpieza de datos (errores de fórmula, vacíos, letras en vez de números)
      if (valor === '' || valor == null)                                 valor = 0;
      if (valor.toString() === '#N/A' || valor.toString() === '#DIV/0!') valor = 0;
      if (typeof valor === 'string') {
        valor = parseFloat(valor);
        if (isNaN(valor)) valor = 0;
      }
      if (valor instanceof Date) valor = 0;

      // Guardar fila estructurada para la base de datos
      output.push([metric, country, encabezadoFecha, valor]);
    }
  }
  
  // --- VALIDACIÓN 2: Verificar que se procesaron métricas ---
  if (registrosProcesados === 0) {
    SpreadsheetApp.getUi().alert('⚠️ ALERTA: No encontré ninguna "Clave de búsqueda" válida en la Columna E.');
    return;
  }

  // --------------------------------------------------------
  // ESCRITURA DE DATOS EN LA HOJA DESTINO
  // --------------------------------------------------------
  let hojaDestino = sheetDestino;

  if (!hojaDestino) {
    hojaDestino = ss.insertSheet('A. Export Targets-Mensual');
  } else {
    hojaDestino.clear();
  }

  if (output.length > 1) {
    // Escribir todos los datos en un solo bloque
    hojaDestino
      .getRange(1, 1, output.length, output[0].length)
      .setValues(output);

    // Formatear columna de fechas
    hojaDestino
      .getRange(2, 3, output.length - 1, 1)
      .setNumberFormat('MM/dd/yyyy');
  }

  // --- NOTIFICACIÓN DE ÉXITO (Toast) ---
  const mensajeExito = `Meses: ${fechasEncontradas} | Claves: ${registrosProcesados} | Filas exportadas: ${output.length - 1}`;
  Logger.log('✅ Proceso Mensual Completado con Éxito. ' + mensajeExito);
  ss.toast(mensajeExito, '✅ Proceso Completado', 5);
}

// ============================================================
// DIARIO
// Lee "Targets - Diario" y escribe en "B. Export Targets-Diario"
// ============================================================
function procesarTargetsDiario() {

  const ss           = SpreadsheetApp.getActiveSpreadsheet();
  const sheetOrigen  = ss.getSheetByName('Targets - Diario');
  const sheetDestino = ss.getSheetByName('B. Export Targets-Diario');

  if (!sheetOrigen) {
    SpreadsheetApp.getUi().alert('No se encontró la hoja "Targets - Diario".');
    return;
  }

  const data = sheetOrigen.getDataRange().getValues();

  const FILA_ENCABEZADOS_FECHA = 4;   // Fila 5 → fechas diarias
  const FILA_DATOS_INICIO      = 5;   // Fila 6 → datos reales
  const COL_FECHAS_INICIO      = 6;   // Columna G → inicio de valores diarios
  const COL_CLAVE              = 4;   // Columna E → "Métrica - País"

  const output = [
    ['Metric', 'Country', 'Date', 'Value']
  ];

  const filaFechas = data[FILA_ENCABEZADOS_FECHA];

  for (let i = FILA_DATOS_INICIO; i < data.length; i++) {
    const fila  = data[i];
    const clave = fila[COL_CLAVE];

    if (!clave || clave.toString().trim() === '')  continue;
    if (clave.toString() === 'Clave de búsqueda')  continue;

    let metric  = '';
    let country = '';

    const SEPARADOR    = ' - ';
    const posSeparador = clave.lastIndexOf(SEPARADOR);

    if (posSeparador !== -1) {
      metric  = clave.substring(0, posSeparador).trim();
      country = clave.substring(posSeparador + SEPARADOR.length).trim();
    } else {
      metric  = clave;
      country = 'General';
    }

    metric = metric + ' - Target';

    for (let j = COL_FECHAS_INICIO; j < fila.length; j++) {
      const encabezadoFecha = filaFechas[j];
      let   valor           = fila[j];

      if (!(encabezadoFecha instanceof Date)) continue;

      if (valor === '' || valor == null)                                  valor = 0;
      if (valor.toString() === '#N/A' || valor.toString() === '#DIV/0!')  valor = 0;
      if (typeof valor === 'string') {
        valor = parseFloat(valor);
        if (isNaN(valor)) valor = 0;
      }
      if (valor instanceof Date) valor = 0;

      output.push([metric, country, encabezadoFecha, valor]);
    }
  }

  let hojaDestino = sheetDestino;

  if (!hojaDestino) {
    hojaDestino = ss.insertSheet('B. Export Targets-Diario');
  } else {
    hojaDestino.clear();
  }

  if (output.length > 0) {
    hojaDestino
      .getRange(1, 1, output.length, output[0].length)
      .setValues(output);

    hojaDestino
      .getRange(2, 3, output.length - 1, 1)
      .setNumberFormat('MM/dd/yyyy');
  }

  Logger.log('✅ Diario completado. Filas exportadas: ' + (output.length - 1));
}