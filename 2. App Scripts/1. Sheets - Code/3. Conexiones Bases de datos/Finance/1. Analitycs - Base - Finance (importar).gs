function importar() {
  var idOrigen = "1cDv2VtMsMZZFT7QudD1eq2kpCFg6PzwQfufNRxaYdrI";
  var hojaOrigen = "E - Analytics (DDU)";

  var idDestino = "1MeXHCeDGOkS7WIztOeWAD1WkwvuFOW_Mr-d1zdnoYww";
  var hojaDestino = "1. IT - Analitycs"; 

  Logger.log("🚀 Iniciando proceso de importación...");

  try {
    // 1. Obtener datos origen
    var ssOrigen = SpreadsheetApp.openById(idOrigen);
    var shOrigen = ssOrigen.getSheetByName(hojaOrigen);

    if (!shOrigen) {
      throw new Error("❌ La hoja '" + hojaOrigen + "' NO existe en el libro de origen.");
    }

    var datos = shOrigen.getDataRange().getValues();
    Logger.log("📊 Datos leídos de origen: " + datos.length + " filas x " + (datos[0] ? datos[0].length : 0) + " columnas.");

    if (datos.length === 0 || datos[0].length === 0) {
      Logger.log("⚠️ No hay datos para copiar.");
      return;
    }

    // 2. Destino
    var ssDest = SpreadsheetApp.openById(idDestino);
    Logger.log("📂 Nombre del archivo destino: '" + ssDest.getName() + "'");

    var shDest = ssDest.getSheetByName(hojaDestino);
    if (!shDest) {
      Logger.log("ℹ️ Creando la hoja de destino '" + hojaDestino + "'...");
      shDest = ssDest.insertSheet(hojaDestino);
    }

    // 3. Limpiar y Pega
    Logger.log("🧹 Limpiando contenido actual...");
    shDest.clearContents();

    Logger.log("✍️ Escribiendo valores...");
    shDest.getRange(1, 1, datos.length, datos[0].length).setValues(datos);

    // 4. FORZAR GUARDADO INMEDIATO
    SpreadsheetApp.flush();
    Logger.log("💾 Cambios guardados forzosamente con SpreadsheetApp.flush()");

    // 5. Verificación
    var filasEscritas = shDest.getLastRow();
    var colEscritas = shDest.getLastColumn();
    Logger.log("🎉 Confirmación: La hoja de destino ahora tiene " + filasEscritas + " filas y " + colEscritas + " columnas con datos.");

  } catch (error) {
    Logger.log("💥 ERROR: " + error.message);
  }
}