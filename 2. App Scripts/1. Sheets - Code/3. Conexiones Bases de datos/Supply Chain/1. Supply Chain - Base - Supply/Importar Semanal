// --- DICCIONARIO DE PAÍSES ---
const MAPEO_PAISES = {
  // Códigos en mayúscula
  "AR": "Argentina",
  "BO": "Bolivia",
  "CL": "Chile",
  "CR": "Costa Rica",
  "DO": "Republica Dominicana",
  "EC": "Ecuador",
  "GT": "Guatemala",
  "HN": "Honduras",
  "NI": "Nicaragua",
  "PA": "Panama",
  "UY": "Uruguay",
  "PY": "Paraguay",
  "PE": "Peru",
  "SV": "El Salvador",
  
  // Códigos en minúscula (por si vienen directo en minúscula en el origen)
  "ar": "Argentina",
  "bo": "Bolivia",
  "cl": "Chile",
  "cr": "Costa Rica",
  "do": "Republica Dominicana",
  "ec": "Ecuador",
  "gt": "Guatemala",
  "hn": "Honduras",
  "ni": "Nicaragua",
  "pa": "Panama",
  "uy": "Uruguay",
  "py": "Paraguay",
  "pe": "Peru",
  "sv": "El Salvador",

  // Nombres completos incorrectos o abreviados a corregir
  "country_code": "",
  "country": "",
  "PAIS": ""
};

/**
 * Función principal que debés asociar al Activador (Trigger) de Apps Script.
 */
function ejecutarImportacionSemanal() {
  const origenId = "14yjg9Vx6uwgaba-JOECa6sqaNYkh48m2pJax2Om5Rlw";
  
  console.log("Abriendo planilla de origen...");
  const ssOrigen = SpreadsheetApp.openById(origenId);
  
  // Buscamos la pestaña con las posibles variaciones de nombre (con o sin barras/espacios)
  let hojaOrigen = ssOrigen.getSheetByName("//ACTUALS-W") || 
                   ssOrigen.getSheetByName("// ACTUALS-W") || 
                   ssOrigen.getSheetByName("ACTUALS-W");
  
  if (!hojaOrigen) {
    throw new Error("No se encontró la pestaña de origen '//ACTUALS-W' ni variaciones en la planilla de origen.");
  }

  // 1. Obtener datos de origen directamente (sin refrescar BigQuery)
  console.log("Obteniendo datos de origen desde la pestaña: " + hojaOrigen.getName() + "...");
  const datosRaw = hojaOrigen.getDataRange().getValues();
  if (datosRaw.length < 2) {
    console.warn("No hay datos para transformar en la hoja origen.");
    return;
  }

  // Preparamos el array de destino con los nuevos encabezados
  const filasTransformadas = [
    ["Métrica", "País", "Año", "Week number", "Valor"]
  ];

  // 2. Transformación fila por fila (omitimos la cabecera i = 0)
  for (let i = 1; i < datosRaw.length; i++) {
    const fila = datosRaw[i];
    
    // Si la fila está vacía, la omitimos
    if (!fila[1] && !fila[2]) continue;

    const metrica = String(fila[1] || "").trim();       // Col B: KPI DOH (ej: DOH, CVR3, etc.)
    const paisRaw = String(fila[2] || "").trim();       // Col C: Country PAIS (ej: AR, ar, SV, sv, CR, etc.)
    
    // Omitimos filas de encabezado repetidas en el origen (ej: PAIS, country_code, country)
    if (paisRaw.toLowerCase() === "pais" || paisRaw.toLowerCase() === "country_code" || paisRaw.toLowerCase() === "country") {
      continue;
    }

    const pais = MAPEO_PAISES[paisRaw] || paisRaw;       // Traduce a nombre limpio o mantiene si ya es correcto
    
    const isoweekYearRaw = String(fila[4] || "").trim(); // Col E: month_date Isoweek_Year (ej: 2026-09)
    let anio = "";
    let semana = "";
    
    if (isoweekYearRaw && isoweekYearRaw.indexOf("-") !== -1) {
      const partes = isoweekYearRaw.split("-");
      if (partes.length >= 2) {
        anio = parseInt(partes[0], 10) || "";
        semana = parseInt(partes[1], 10) || "";
      }
    }

    // Procesar el valor (DOH) de manera robusta (porcentajes, números y valores de error)
    const valorRaw = fila[5]; // Col F: Value DOH
    let valor = 0;
    
    // Si el valor es de error (ej: #NUM! o vacío), decidimos si lo queremos omitir o guardar como string
    if (String(valorRaw).trim() === "#NUM!" || String(valorRaw).trim() === "") {
      continue; // Omitimos filas con errores #NUM! para mantener la base de datos limpia y útil
    }

    if (typeof valorRaw === "string") {
      let limpio = valorRaw.replace("%", "").trim();
      limpio = limpio.replace(",", ".");
      valor = parseFloat(limpio);
      if (valorRaw.includes("%")) {
        valor = valor / 100;
      }
    } else if (typeof valorRaw === "number") {
      valor = valorRaw;
    }

    // Agregamos la fila formateada
    filasTransformadas.push([
      metrica,
      pais,
      anio,
      semana,
      valor
    ]);
  }

  // 3. Abrir destino y escribir los datos limpios
  const destinoId = "1aCrgEjh6qT5T8ayT2H22r3iNc55nAR1O9vaOCW6pRBs";
  const nombreHojaDestino = "B. TI - SC Data - Weekly";
  
  console.log("Abriendo planilla de destino...");
  const ssDestino = SpreadsheetApp.openById(destinoId);
  let hojaDestino = ssDestino.getSheetByName(nombreHojaDestino);
  
  if (!hojaDestino) {
    hojaDestino = ssDestino.insertSheet(nombreHojaDestino);
  }

  console.log("Limpiando y escribiendo datos en el destino...");
  hojaDestino.clearContents();
  
  // Escribimos todo en un solo bloque rápido (setValues)
  hojaDestino.getRange(1, 1, filasTransformadas.length, filasTransformadas[0].length)
             .setValues(filasTransformadas);

  console.log("¡Proceso completado con éxito!");
}