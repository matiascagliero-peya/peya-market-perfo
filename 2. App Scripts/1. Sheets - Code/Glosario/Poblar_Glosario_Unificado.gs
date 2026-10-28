/**
 * POBLAR GLOSARIO UNIFICADO
 * Lee dinámicamente los archivos .sql de Google Drive en la carpeta "Glosario"
 * y construye la pestaña "0. Glosario unificado" con todas las propiedades de metadatos,
 * resultado esperado de BigQuery, filas compactas 100% homogéneas y ajuste CLIP.
 */
function poblarGlosarioUnificado() {
  Logger.log("=== INICIANDO CONSTRUCCIÓN DEL GLOSARIO UNIFICADO COMPACTO ===");
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const nombrePestana = "0. Glosario unificado";

  // 1. Resetear o crear la pestaña de destino
  let sheet = ss.getSheetByName(nombrePestana);
  if (sheet) {
    if (ss.getSheets().length > 1) {
      ss.deleteSheet(sheet);
      sheet = ss.insertSheet(nombrePestana, 0);
    } else {
      sheet.clear();
      try {
        const lastRow = sheet.getMaxRows();
        sheet.getRange(1, 1, lastRow, 1).shiftRowGroupDepth(-8);
      } catch (e) {
        // Ignorar si no había grupos previos
      }
    }
  } else {
    sheet = ss.insertSheet(nombrePestana, 0);
  }

  // 2. Encabezados de la tabla (15 columnas estructuradas)
  const headers = [
    "ID", "Chapter", "Agrupación", "Métrica", "Tipo", 
    "Query bajada en", "Tablas de origen", "Sheets con datos", 
    "Description", "Formula", "Query de Ejemplo", "Resultado Esperado", 
    "Equipo", "Owner de referencia", "Link a slack"
  ];
  sheet.appendRow(headers);

  // Formato del encabezado principal
  const headerRange = sheet.getRange(1, 1, 1, headers.length);
  headerRange.setBackground("#202124")
             .setFontColor("#FFFFFF")
             .setFontWeight("bold")
             .setHorizontalAlignment("center")
             .setVerticalAlignment("middle");
  sheet.setRowHeight(1, 26);

  // 3. Buscar la carpeta raíz "Glosario" en Google Drive
  const carpetas = DriveApp.getFoldersByName("Glosario");
  if (!carpetas.hasNext()) {
    Logger.log("❌ ERROR: No se encontró la carpeta 'Glosario' en Google Drive.");
    SpreadsheetApp.getUi().alert("No se encontró la carpeta 'Glosario' en Google Drive.");
    return;
  }
  const carpetaGlosario = carpetas.next();

  // Capítulos a procesar y colores de banner
  const chapters = [
    { name: "1. Demand Stimulation", title: "Demand Stimulation", color: "#D2E3FC", team: "Performance / Commercial" },
    { name: "2. Usuarios", title: "Usuarios", color: "#CEEAD6", team: "Growth / Performance" },
    { name: "3. Assortment, Pricing & Promo", title: "Assortment, Pricing & Promo", color: "#FEF7E0", team: "Commercial / Supply" },
    { name: "4. Operational Excellence", title: "Operational Excellence", color: "#FAD2CF", team: "Operations / Logistics" },
    { name: "6. Otros", title: "Otros (Tarifas y Plataforma)", color: "#E8D0F8", team: "Platform / Commercial" },
    { name: "7. Métricas Pendientes", title: "Métricas Pendientes", color: "#E0E0E0", team: "Finance / P&L (Pendiente)" }
  ];

  function inferAgrupacion(name) {
    const n = name.toLowerCase();
    if (n.includes('order') || n.includes('órdenes') || n.includes('ordenes')) return 'Órdenes';
    if (n.includes('gmv')) return 'GMV';
    if (n.includes('unit') || n.includes('unidades')) return 'Unidades';
    if (n.includes('net sales') || n.includes('ventas netas')) return 'Ventas Netas';
    if (n.includes('basket size') || n.includes('canasta')) return 'Tamaño de Canasta';
    if (n.includes('afv')) return 'AFV';
    if (n.includes('frequency') || n.includes('frecuencia')) return 'Frecuencia';
    if (n.includes('session') || n.includes('cvr')) return 'Tráfico & Conversión';
    if (n.includes('user') || n.includes('mau') || n.includes('churn') || n.includes('retention') || n.includes('return')) return 'Usuarios & Lifecycle';
    if (n.includes('aqs') || n.includes('sku') || n.includes('listed')) return 'Surtido (AQS)';
    if (n.includes('pqs') || n.includes('promo') || n.includes('discount')) return 'Promociones (PQS)';
    if (n.includes('nielsen') || n.includes('market')) return 'Cobertura de Mercado';
    if (n.includes('wis') || n.includes('availability') || n.includes('issues')) return 'Disponibilidad (WIS & Pérdidas)';
    if (n.includes('seamless') || n.includes('modified') || n.includes('rejected') || n.includes('late') || n.includes('slow') || n.includes('forced')) return 'Excelencia Operativa (Seamless)';
    if (n.includes('picking') || n.includes('timing') || n.includes('assignment') || n.includes('ept')) return 'Tiempos & Picking';
    if (n.includes('utr')) return 'Productividad (UTR)';
    if (n.includes('inaccuracy')) return 'Inaccuracy & Calidad';
    if (n.includes('stacked') || n.includes('delivery time') || n.includes('awt')) return 'Logística & Despacho';
    if (n.includes('open time')) return 'Horario de Tienda (Open Time)';
    if (n.includes('rating') || n.includes('nps')) return 'Experiencia de Cliente';
    if (n.includes('fee') || n.includes('cpo')) return 'Tarifas & Costos';
    if (n.includes('ebitda') || n.includes('margin') || n.includes('cost') || n.includes('shrinkage') || n.includes('nmr') || n.includes('p&l')) return 'Finanzas & Margen';
    return 'General';
  }

  const colorFondo1 = "#FFFFFF";
  const colorFondo2 = "#F8F9FA";
  let metricCounterGlobal = 0;

  // 4. Recorrer cada subcarpeta y procesar los archivos .sql
  chapters.forEach(ch => {
    const subCarpetas = carpetaGlosario.getFoldersByName(ch.name);
    if (!subCarpetas.hasNext()) {
      Logger.log("⚠️ Subcarpeta no encontrada en Drive: " + ch.name);
      return;
    }
    const sub = subCarpetas.next();
    const files = sub.getFiles();

    Logger.log("📂 PROCESANDO: " + ch.title.toUpperCase());

    // Banner del capítulo (solo Chapter en Col 2, resto vacías)
    const bannerCells = new Array(headers.length).fill("");
    bannerCells[1] = ch.title.toUpperCase();
    sheet.appendRow(bannerCells);

    const bannerRow = sheet.getLastRow();
    sheet.getRange(bannerRow, 1, 1, headers.length)
         .setBackground(ch.color)
         .setFontWeight("bold")
         .setFontColor("#202124")
         .setHorizontalAlignment("center")
         .setVerticalAlignment("middle");

    // Listar y ordenar archivos por número de métrica
    const fileList = [];
    while (files.hasNext()) {
      const file = files.next();
      const fileName = file.getName();
      if (!fileName.endsWith(".sql")) continue;
      fileList.push(file);
    }

    fileList.sort((a, b) => {
      const numA = parseFloat(a.getName().replace(/^Glosario-(?:Pendiente-)?/, '').match(/^(\d+(?:\.\d+)?)/)?.[1] || 9999);
      const numB = parseFloat(b.getName().replace(/^Glosario-(?:Pendiente-)?/, '').match(/^(\d+(?:\.\d+)?)/)?.[1] || 9999);
      return numA - numB;
    });

    // 5. Extraer metadatos de cada archivo .sql y armar filas
    const rowsToAppend = [];
    fileList.forEach(file => {
      const fileName = file.getName();
      const content = file.getBlob().getDataAsString();

      // Extracción de metadatos del encabezado
      const numMatch = content.match(/-- Métrica Nº:\s*([^\n]+)/);
      const nameMatch = content.match(/-- Nombre:\s*([^\n]+)/);
      const tipoMatch = content.match(/-- Tipo:\s*([^\n]+)/);
      const bajadaMatch = content.match(/-- Query bajada en:\s*([^\n]+)/);
      const tablasMatch = content.match(/-- Tablas de origen:\s*([^\n]+)/);
      const formulaMatch = content.match(/-- Fórmula:\s*([^\n]+)/);
      const defMatch = content.match(/-- Definición:\s*([^\n]+)/);
      const sheetNameMatch = content.match(/-- Sheets Name:\s*([^\n]+)/);
      const sheetLinkMatch = content.match(/-- Sheets Link:\s*([^\n]+)/);

      const metricId = numMatch ? numMatch[1].trim() : fileName.replace(/^Glosario-(?:Pendiente-)?/, '').replace(/\.sql$/, '').split('-')[0].trim();
      const metricName = nameMatch ? nameMatch[1].trim() : fileName.replace(/^Glosario-(?:Pendiente-)?|\.sql$/g, '');
      const tipo = tipoMatch ? tipoMatch[1].trim() : "Dato Directo";
      const bajadaEn = bajadaMatch ? bajadaMatch[1].trim() : "-";
      const tablasOrigen = tablasMatch ? tablasMatch[1].trim() : "-";
      const formula = formulaMatch ? formulaMatch[1].trim() : "-";
      const def = defMatch ? defMatch[1].trim() : "-";
      const sheetName = sheetNameMatch ? sheetNameMatch[1].trim() : "-";
      const sheetLink = sheetLinkMatch ? sheetLinkMatch[1].trim() : "";
      const agrupacion = inferAgrupacion(metricName);

      // Separar la Query SQL pura del Resultado Esperado
      let pureSql = content;
      let resultadoEsperado = "-";
      const resIdx = content.indexOf('-- RESULTADO REAL VERIFICADO EN BIGQUERY');
      if (resIdx !== -1) {
        pureSql = content.substring(0, resIdx).trim();
        const tableIdx = content.indexOf('-- +', resIdx);
        if (tableIdx !== -1) {
          resultadoEsperado = content.substring(tableIdx).trim();
        } else {
          resultadoEsperado = content.substring(resIdx).trim();
        }
      }

      let sheetsConDatos = sheetName;
      if (sheetLink && sheetLink.indexOf("http") === 0) {
        sheetsConDatos = '=HYPERLINK("' + sheetLink + '", "' + sheetName + '")';
      }

      metricCounterGlobal++;

      // Asignar Owner y Slack
      let ownerMetric = "Matías Cagliero";
      let slackMetric = "";
      const isUtr = (ch.title.indexOf("Operational") !== -1) && (
        metricName.indexOf("UTR") !== -1 ||
        metricName.toLowerCase().indexOf("picking units") !== -1 ||
        metricName.toLowerCase().indexOf("receiving units") !== -1 ||
        metricName.toLowerCase().indexOf("received bags") !== -1 ||
        metricName.toLowerCase().indexOf("working hours") !== -1
      );
      if (isUtr) {
        ownerMetric = "Juan Pablo Pinori Diaz";
        slackMetric = "https://deliveryhero.enterprise.slack.com/archives/D093J9QN9CK";
      }

      rowsToAppend.push([
        metricId,          // Col 1: ID
        ch.title,          // Col 2: Chapter
        agrupacion,        // Col 3: Agrupación
        metricName,        // Col 4: Métrica
        tipo,              // Col 5: Tipo
        bajadaEn,          // Col 6: Query bajada en
        tablasOrigen,      // Col 7: Tablas de origen
        sheetsConDatos,    // Col 8: Sheets con datos
        def,               // Col 9: Description
        formula,           // Col 10: Formula
        pureSql,           // Col 11: Query de Ejemplo (SQL puro)
        resultadoEsperado, // Col 12: Resultado Esperado
        ch.team,           // Col 13: Equipo
        ownerMetric,       // Col 14: Owner de referencia
        slackMetric        // Col 15: Link a slack
      ]);
    });

    // Escribir datos y agrupar filas
    if (rowsToAppend.length > 0) {
      const startDataRow = sheet.getLastRow() + 1;
      const dataRange = sheet.getRange(startDataRow, 1, rowsToAppend.length, headers.length);
      dataRange.setValues(rowsToAppend);

      // Fondo alternado (zebra)
      const backgrounds = [];
      for (let r = 0; r < rowsToAppend.length; r++) {
        const rowColor = (r % 2 === 0) ? colorFondo1 : colorFondo2;
        backgrounds.push(new Array(headers.length).fill(rowColor));
      }
      dataRange.setBackgrounds(backgrounds);

      // Agrupación plegable bajo el banner
      try {
        sheet.getRange(startDataRow, 1, rowsToAppend.length, 1).shiftRowGroupDepth(1);
      } catch (e) {}
    }
  });

  // Configurar botón toggle en el banner
  try {
    sheet.setRowGroupControlTogglePosition(SpreadsheetApp.GroupControlTogglePosition.BEFORE);
  } catch (e) {}

  // 6. Formato: Centrado total, ajuste CLIP en toda la tabla y altura fija uniforme
  const totalRows = sheet.getLastRow();
  if (totalRows > 1) {
    const fullRange = sheet.getRange(1, 1, totalRows, headers.length);
    fullRange.setVerticalAlignment("middle")
             .setHorizontalAlignment("center")
             .setWrapStrategy(SpreadsheetApp.WrapStrategy.CLIP); // CLIP total para evitar que cualquier celda estire la fila

    // Bordes sutiles grises
    fullRange.setBorder(true, true, true, true, true, true, "#E0E0E0", SpreadsheetApp.BorderStyle.SOLID);

    // FORZAR ALTURA COMPACTA Y EXACTAMENTE IGUAL EN TODAS LAS FILAS (64 píxeles)
    sheet.setRowHeights(2, totalRows - 1, 64);
    Logger.log("   - Altura de filas fijada a 64px exactamente en todas las filas (2 a " + totalRows + ").");
  }

  // Ajustar anchos de columnas óptimos
  sheet.setFrozenRows(1);
  sheet.autoResizeColumns(1, headers.length);
  sheet.setColumnWidth(4, 220); // Métrica
  sheet.setColumnWidth(6, 180); // Query bajada en
  sheet.setColumnWidth(7, 220); // Tablas de origen (CLIP)
  sheet.setColumnWidth(8, 200); // Sheets con datos
  sheet.setColumnWidth(9, 280); // Description (CLIP)
  sheet.setColumnWidth(10, 220); // Formula (CLIP)
  sheet.setColumnWidth(11, 280); // Query de Ejemplo (CLIP)
  sheet.setColumnWidth(12, 280); // Resultado Esperado (CLIP)

  // 7. Eliminar columnas y filas vacías sobrantes
  const maxCols = sheet.getMaxColumns();
  if (maxCols > headers.length) {
    sheet.deleteColumns(headers.length + 1, maxCols - headers.length);
  }

  const lastRow = sheet.getLastRow();
  const maxRows = sheet.getMaxRows();
  if (maxRows > lastRow) {
    sheet.deleteRows(lastRow + 1, maxRows - lastRow);
  }

  Logger.log("✅ Proceso completado. Total métricas: " + metricCounterGlobal);
  Logger.log("   - Todas las filas con altura exacta y uniforme de 22px.");
}
