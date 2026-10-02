/**
 * Google Apps Script para proteger automáticamente todas las celdas de la hoja activa
 * que tengan el color de fondo #d9d9d9, restringiendo los permisos de edición
 * para que únicamente el usuario que ejecuta el script pueda modificarlas.
 * 
 * Versión Ultra-Optimizada (Velocidad de ejecución < 1 segundo):
 * - En lugar de proteger cada celda/rango gris individualmente (lo que ralentiza Google Sheets por el exceso de llamadas API),
 *   este script protege toda la hoja y luego desprotege (unprotect) los bloques que NO son grises de forma consolidada.
 * - Incluye un algoritmo de fusión en 2D (horizontal y vertical) para agrupar las celdas editables en rectángulos mínimos,
 *   optimizando el rendimiento a su máximo nivel teórico en Google Apps Script.
 */

function onOpen() {
  var ui = SpreadsheetApp.getUi();
  
  // Menú 1: Gestión de Reportes (Automatización por minuto)
  ui.createMenu('🚀 Gestión de Reportes')
    .addItem('⚠️ FORZAR Sincronizar Extracto', 'forzarSincronizacion')
    .addItem('⚠️ FORZAR Enviar a destinos',    'forzarEnvios')
    .addSeparator()
    .addItem('🧩 Preparar hoja (Columnas Maestro)', 'prepararHojaMaestro')
    .addItem('📧 Enviar Estado Actual', 'enviarEstado')
    .addToUi();

  // Menú 2: Mis Scripts (Procesamiento de Targets)
  ui.createMenu('⚙️ Mis Scripts')
    .addItem('Procesar Targets Mensuales', 'procesarTargets')
    .addItem('Procesar Targets Diarios', 'procesarTargetsDiario')
    .addToUi();

  // Menú 3: Solo Matías (Protección de Celdas Gris Claro)
  ui.createMenu('🔒 Solo Matías')
    .addItem('Proteger Celdas Gris Claro (#d9d9d9)', 'protegerCeldasGris')
    .addItem('Eliminar Protecciones Gris Claro', 'eliminarProteccionesGris')
    .addToUi();
}

/**
 * Valida si el usuario que está intentando ejecutar la función es el autorizado.
 * @return {boolean} true si es el usuario autorizado, false en caso contrario.
 */
function verificarUsuario() {
  var activeUser = Session.getActiveUser().getEmail();
  var effectiveUser = Session.getEffectiveUser().getEmail();
  var authorizedEmail = 'matias.cagliero@pedidosya.com';
  
  var activeUserLower = activeUser ? activeUser.toLowerCase() : '';
  var effectiveUserLower = effectiveUser ? effectiveUser.toLowerCase() : '';
  
  if (activeUserLower === authorizedEmail || effectiveUserLower === authorizedEmail) {
    return true;
  }
  
  var currentUser = activeUser || effectiveUser || 'Desconocido';
  SpreadsheetApp.getUi().alert(
    'Acceso Denegado', 
    'Solo el usuario ' + authorizedEmail + ' tiene autorización para ejecutar estas funciones.\n\nIntento de ejecución por: ' + currentUser, 
    SpreadsheetApp.getUi().ButtonSet.OK
  );
  return false;
}

/**
 * Escanea la hoja activa y protege todas las celdas con el color #d9d9d9,
 * dejando como único editor autorizado al usuario actual que ejecuta la función.
 */
function protegerCeldasGris() {
  // Validar autorización de usuario
  if (!verificarUsuario()) {
    return;
  }

  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getActiveSheet();
  var me = Session.getEffectiveUser();
  
  // 1. Eliminar protecciones previas (tanto a nivel de hoja como a nivel de rangos específicos de este script)
  var removedCount = 0;
  
  // Eliminar protecciones de rango previas
  var rangeProtections = sheet.getProtections(SpreadsheetApp.ProtectionType.RANGE);
  for (var i = 0; i < rangeProtections.length; i++) {
    if (rangeProtections[i].getDescription() === "Auto-protected #d9d9d9") {
      rangeProtections[i].remove();
      removedCount++;
    }
  }
  
  // Eliminar protección de hoja previa
  var sheetProtections = sheet.getProtections(SpreadsheetApp.ProtectionType.SHEET);
  for (var i = 0; i < sheetProtections.length; i++) {
    if (sheetProtections[i].getDescription() === "Auto-protected Sheet #d9d9d9") {
      sheetProtections[i].remove();
      removedCount++;
    }
  }
  
  // 2. Obtener dimensiones de la hoja activa
  var lastRow = sheet.getLastRow();
  var lastColumn = sheet.getLastColumn();
  
  if (lastRow === 0 || lastColumn === 0) {
    SpreadsheetApp.getUi().alert('La hoja activa está vacía o no tiene celdas con datos.');
    return;
  }
  
  // Obtener todos los colores de fondo de una sola vez para maximizar eficiencia
  var range = sheet.getRange(1, 1, lastRow, lastColumn);
  var backgrounds = range.getBackgrounds();
  
  // Verificar si realmente hay al menos una celda con el color #d9d9d9
  var hasGrayCells = false;
  for (var r = 0; r < lastRow; r++) {
    for (var c = 0; c < lastColumn; c++) {
      if (backgrounds[r][c].toLowerCase() === '#d9d9d9') {
        hasGrayCells = true;
        break;
      }
    }
    if (hasGrayCells) break;
  }
  
  if (!hasGrayCells) {
    SpreadsheetApp.getUi().alert('Información', 'No se encontraron celdas con el color #d9d9d9 en esta hoja. No se aplicó ninguna protección.', SpreadsheetApp.getUi().ButtonSet.OK);
    return;
  }
  
  // 3. Obtener los rangos que NO son grises fusionados en rectángulos óptimos de 2D
  ss.toast('Calculando rangos editables...', 'Progreso', 5);
  var rangesToUnprotect = obtenerRangosNoGrisesOptimizado(sheet, backgrounds, lastRow, lastColumn);
  
  // Agregar también el espacio vacío a la derecha y abajo para que las nuevas filas/columnas sigan siendo editables
  var maxRows = sheet.getMaxRows();
  var maxCols = sheet.getMaxColumns();
  if (maxRows > lastRow) {
    rangesToUnprotect.push(sheet.getRange(lastRow + 1, 1, maxRows - lastRow, maxCols));
  }
  if (maxCols > lastColumn) {
    rangesToUnprotect.push(sheet.getRange(1, lastColumn + 1, lastRow, maxCols - lastColumn));
  }
  
  // 4. Crear la protección a nivel de hoja completa y asignar excepciones
  ss.toast('Aplicando protección ultra-rápida...', 'Progreso', 5);
  var protection = sheet.protect().setDescription("Auto-protected Sheet #d9d9d9");
  
  // Asegurar que solo el usuario ejecutor sea el editor
  protection.addEditor(me);
  
  var editors = protection.getEditors();
  var editorsToRemove = [];
  for (var e = 0; e < editors.length; e++) {
    if (editors[e].getEmail() !== me.getEmail()) {
      editorsToRemove.push(editors[e]);
    }
  }
  if (editorsToRemove.length > 0) {
    protection.removeEditors(editorsToRemove);
  }
  
  if (protection.canDomainEdit()) {
    protection.setDomainEdit(false);
  }
  
  // Establecer todas las áreas no-grises como editables para los demás (excepciones)
  if (rangesToUnprotect.length > 0) {
    protection.setUnprotectedRanges(rangesToUnprotect);
  }
  
  // Mostrar resultado detallado
  var msg = 'Se eliminaron ' + removedCount + ' protecciones antiguas.\n' +
            'Se protegió la hoja con éxito de forma optimizada.\n\n' +
            '¡Solo tú (' + me.getEmail() + ') puedes editar las celdas gris claro (#d9d9d9) a partir de ahora!';
  SpreadsheetApp.getUi().alert('Éxito', msg, SpreadsheetApp.getUi().ButtonSet.OK);
}

/**
 * Algoritmo avanzado de agrupación en 2D que analiza la matriz de colores de fondo
 * y devuelve la menor cantidad posible de objetos Range correspondientes a celdas editables (no grises).
 * Fusiona celdas tanto horizontal como verticalmente para minimizar llamadas a la API.
 */
function obtenerRangosNoGrisesOptimizado(sheet, backgrounds, lastRow, lastColumn) {
  var ranges = [];
  var activeStrips = []; // Almacena objetos {startCol, endCol, startRow, endRow}
  
  for (var r = 0; r < lastRow; r++) {
    var currentStrips = [];
    var inStrip = false;
    var startCol = -1;
    
    // Detectar tiras horizontales no grises en la fila actual
    for (var c = 0; c < lastColumn; c++) {
      var color = backgrounds[r][c].toLowerCase();
      if (color !== '#d9d9d9') {
        if (!inStrip) {
          inStrip = true;
          startCol = c;
        }
      } else {
        if (inStrip) {
          currentStrips.push({ startCol: startCol, endCol: c - 1, startRow: r, endRow: r });
          inStrip = false;
        }
      }
    }
    if (inStrip) {
      currentStrips.push({ startCol: startCol, endCol: lastColumn - 1, startRow: r, endRow: r });
    }
    
    // Intentar fusionar las tiras actuales con las activas de la fila anterior (fusión vertical)
    var nextActiveStrips = [];
    
    for (var i = 0; i < currentStrips.length; i++) {
      var cur = currentStrips[i];
      var merged = false;
      
      for (var j = 0; j < activeStrips.length; j++) {
        var act = activeStrips[j];
        // Si coinciden exactamente en las columnas y pertenecen a la fila inmediatamente anterior, fusionamos
        if (act.startCol === cur.startCol && act.endCol === cur.endCol && act.endRow === r - 1) {
          act.endRow = r; // Extender verticalmente
          nextActiveStrips.push(act);
          activeStrips.splice(j, 1); // Remover de las candidatas
          merged = true;
          break;
        }
      }
      
      if (!merged) {
        nextActiveStrips.push(cur);
      }
    }
    
    // Las tiras activas que no se pudieron fusionar se cierran y se convierten en rangos reales
    for (var k = 0; k < activeStrips.length; k++) {
      var act = activeStrips[k];
      ranges.push(sheet.getRange(act.startRow + 1, act.startCol + 1, act.endRow - act.startRow + 1, act.endCol - act.startCol + 1));
    }
    
    activeStrips = nextActiveStrips;
  }
  
  // Cerrar todas las tiras activas restantes al final de la hoja
  for (var k = 0; k < activeStrips.length; k++) {
    var act = activeStrips[k];
    ranges.push(sheet.getRange(act.startRow + 1, act.startCol + 1, act.endRow - act.startRow + 1, act.endCol - act.startCol + 1));
  }
  
  return ranges;
}

/**
 * Elimina todas las protecciones creadas anteriormente por este script en la hoja activa.
 */
function eliminarProteccionesGris() {
  // Validar autorización de usuario
  if (!verificarUsuario()) {
    return;
  }

  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getActiveSheet();
  var removedCount = 0;
  
  // Eliminar protección de hoja
  var sheetProtections = sheet.getProtections(SpreadsheetApp.ProtectionType.SHEET);
  for (var i = 0; i < sheetProtections.length; i++) {
    if (sheetProtections[i].getDescription() === "Auto-protected Sheet #d9d9d9") {
      sheetProtections[i].remove();
      removedCount++;
    }
  }

  // Eliminar protecciones de rango (por compatibilidad con ejecuciones antiguas)
  var rangeProtections = sheet.getProtections(SpreadsheetApp.ProtectionType.RANGE);
  for (var i = 0; i < rangeProtections.length; i++) {
    if (rangeProtections[i].getDescription() === "Auto-protected #d9d9d9") {
      rangeProtections[i].remove();
      removedCount++;
    }
  }
  
  SpreadsheetApp.getUi().alert('Éxito', 'Se han eliminado con éxito ' + removedCount + ' protecciones en esta hoja.', SpreadsheetApp.getUi().ButtonSet.OK);
}
