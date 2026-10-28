// ==============================================================================
// REPORTE WEB APP: USER 360 (LIFECYCLE & METRICS ANALYTICS)
// Backend: Conexión directa con BigQuery (frank_user_metrics_summary + qc_coverage)
// Telemetría & Analytics: Registro de vistas y panel exclusivo de auditoría (Admin)
// ==============================================================================

const USER360_CONFIG = {
  BQ_PROJECT_ID: "peya-food-and-groceries",
  BQ_DATASET_ID: "automated_tables_reports",
  BQ_TABLE_ID:   "frank_user_metrics_summary",
  FECHA_MINIMA:  "2025-01-01",
  SHEET_TELEMETRIA_ID: "1XTjLS_VZuID-bQRvvcADlg2M2idy1SoWVLrIHIk24fA",
  ADMIN_EMAILS: [
    "matias.cagliero@pedidosya.com"
  ],
  PAISES_PERMITIDOS: [
    "Argentina",
    "Bolivia",
    "Chile",
    "Ecuador",
    "El Salvador",
    "Guatemala",
    "Honduras",
    "Nicaragua",
    "Panama",
    "Paraguay",
    "Peru",
    "Republica Dominicana",
    "Uruguay"
  ]
};

function normalizarPais(countryStr) {
  if (!countryStr) return "";
  const s = String(countryStr).trim();
  if (s.includes("Dominic") || s.includes("Rep")) return "Republica Dominicana";
  if (s.includes("Per")) return "Peru";
  if (s.includes("Panam")) return "Panama";
  return s;
}

function doGet(e) {
  return HtmlService.createTemplateFromFile("Index")
    .evaluate()
    .setTitle("User 360 | PeYa Market Analytics")
    .addMetaTag("viewport", "width=device-width, initial-scale=1.0")
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);
}

function include(filename) {
  return HtmlService.createHtmlOutputFromFile(filename).getContent();
}

/**
 * Valida si el usuario actual es administrador (exclusivo para Matías Cagliero).
 */
function checkAdminAccess() {
  try {
    const email = (Session.getActiveUser().getEmail() || "").toLowerCase().trim();
    return USER360_CONFIG.ADMIN_EMAILS.includes(email);
  } catch (_) {
    return false;
  }
}

/**
 * Retorna los filtros disponibles (Meses desde 2025, Paises, Negocios, DY, UF),
 * bytes consumidos y credenciales de administrador para la vista exclusiva.
 */
function getFiltrosIniciales() {
  let userEmail = "";
  try { userEmail = Session.getActiveUser().getEmail(); } catch (_) {}
  const isAdmin = checkAdminAccess();

  const sql = `
    DECLARE query_name STRING DEFAULT 'User 360 - Filtros Iniciales';

    SELECT
      CAST(Mes AS STRING) AS mes,
      country,
      business,
      DY,
      UF
    FROM \`${USER360_CONFIG.BQ_PROJECT_ID}.${USER360_CONFIG.BQ_DATASET_ID}.${USER360_CONFIG.BQ_TABLE_ID}\`
    WHERE country NOT IN ('Venezuela', 'Costa Rica', 'Colombia')
      AND Mes >= DATE '${USER360_CONFIG.FECHA_MINIMA}'
    GROUP BY 1, 2, 3, 4, 5
    ORDER BY mes DESC, country, business;
  `;

  const bqRes = ejecutarQueryBigQuery(sql);
  const results = bqRes.rows;

  const mesesSet = new Set();
  const paisesSet = new Set(["LATAM"]);
  const negociosSet = new Set();
  const dySet = new Set(["ALL"]);
  const ufSet = new Set(["ALL"]);

  results.forEach(r => {
    if (r.mes) mesesSet.add(r.mes);
    if (r.country) {
      const pNorm = normalizarPais(r.country);
      if (USER360_CONFIG.PAISES_PERMITIDOS.includes(pNorm)) paisesSet.add(pNorm);
    }
    if (r.business) negociosSet.add(r.business);
    const dyNorm = (r.DY === 'Sin compras') ? 'No DY' : r.DY;
    const ufNorm = (r.UF === 'Sin compras') ? 'No UF' : r.UF;
    if (dyNorm && dyNorm !== "-") dySet.add(dyNorm);
    if (ufNorm && ufNorm !== "-") ufSet.add(ufNorm);
  });

  const monthBytes = getMonthBytesFromTelemetry() + (bqRes.bytesProcessed || 0);

  const listaPaisesFinal = ["LATAM"].concat(
    Array.from(paisesSet).filter(p => p !== 'LATAM').sort()
  );

  const payload = {
    meses: Array.from(mesesSet).sort().reverse(),
    paises: listaPaisesFinal,
    negocios: Array.from(negociosSet),
    dy: Array.from(dySet),
    uf: ["ALL", "UF", "No UF"],
    bytesProcessed: bqRes.bytesProcessed || 0,
    monthBytesProcessed: monthBytes,
    todayBytesProcessed: monthBytes,
    isAdmin: isAdmin,
    userEmail: userEmail
  };

  return payload;
}

/**
 * Consulta y agrega los datos de User 360 acotados a partir de 2025.
 * Trae simultáneamente datos de ciclo de vida y datos de cobertura (Covered MAUs).
 */
function getDataUser360(filtros) {
  const mesSeleccionado = (filtros && filtros.mes) ? String(filtros.mes).trim() : "LAST_6";
  const dySeleccionado = (filtros && filtros.dy && filtros.dy !== "ALL") ? String(filtros.dy).trim() : null;
  const ufSeleccionado = (filtros && filtros.uf && filtros.uf !== "ALL") ? String(filtros.uf).trim() : null;

  const whereClauses = [
    "country NOT IN ('Venezuela', 'Costa Rica', 'Colombia')",
    `Mes >= DATE '${USER360_CONFIG.FECHA_MINIMA}'`
  ];

  if (mesSeleccionado === "LAST_6") {
    whereClauses.push("Mes >= DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 6 MONTH)");
  } else if (mesSeleccionado === "LAST_12") {
    whereClauses.push("Mes >= DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 12 MONTH)");
  } else if (mesSeleccionado !== "ALL" && mesSeleccionado) {
    whereClauses.push(`Mes = DATE '${mesSeleccionado}'`);
  }

  if (dySeleccionado) {
    if (dySeleccionado === 'No DY') {
      whereClauses.push("DY IN ('No DY', 'Sin compras')");
    } else {
      whereClauses.push(`DY = '${dySeleccionado}'`);
    }
  }

  if (ufSeleccionado) {
    if (ufSeleccionado === 'No UF') {
      whereClauses.push("UF IN ('No UF', 'Sin compras')");
    } else {
      whereClauses.push(`UF = '${ufSeleccionado}'`);
    }
  }

  const whereSql = "WHERE " + whereClauses.join(" AND ");

  // 1. Consulta Principal a frank_user_metrics_summary
  const sql = `
    DECLARE query_name STRING DEFAULT 'User 360 - Dashboard Matriz L1-L2';

    SELECT
      CAST(Mes AS STRING) AS mes,
      country,
      business,
      l1,
      l2,
      SUM(users_count) AS users_count,
      SUM(confirmed_orders) AS confirmed_orders,
      ROUND(SUM(net_sales_eur), 2) AS net_sales_eur,
      SUM(units_sold) AS units_sold,
      SUM(total_actual_tenure) AS total_actual_tenure,
      SUM(total_adoption_tenure) AS total_adoption_tenure
    FROM \`${USER360_CONFIG.BQ_PROJECT_ID}.${USER360_CONFIG.BQ_DATASET_ID}.${USER360_CONFIG.BQ_TABLE_ID}\`
    ${whereSql}
    GROUP BY Mes, country, business, l1, l2
    ORDER BY Mes ASC, country, business, l1, l2;
  `;

  const bqRes = ejecutarQueryBigQuery(sql);
  const rawRows = bqRes.rows;

  let totalBytes = bqRes.bytesProcessed || 0;

  // 2. Consulta de Cobertura según la query oficial '3. MAUs Coverage - Base - Performance'
  const coverageData = getCoverageDataBigQuery(mesSeleccionado);
  totalBytes += (coverageData.bytesProcessed || 0);

  const mesesEncontrados = new Set();
  const processedRows = rawRows.map(r => {
    const uCount = parseFloat(r.users_count) || 0;
    const cOrders = parseFloat(r.confirmed_orders) || 0;
    const nSales = parseFloat(r.net_sales_eur) || 0;
    const uSold = parseFloat(r.units_sold) || 0;
    const actTenure = parseFloat(r.total_actual_tenure) || 0;
    const adoptTenure = parseFloat(r.total_adoption_tenure) || 0;

    mesesEncontrados.add(r.mes);

    return {
      mes: r.mes,
      country: normalizarPais(r.country),
      business: r.business,
      l1: r.l1,
      l2: (r.l2 && r.l2 !== '-' && r.l2 !== 'Total' && r.l2.toUpperCase() !== String(r.l1 || '').toUpperCase()) ? r.l2 : 'Otros',
      users_count: uCount,
      confirmed_orders: cOrders,
      net_sales_eur: nSales,
      units_sold: uSold,
      total_actual_tenure: actTenure,
      total_adoption_tenure: adoptTenure,
      basket_size: cOrders > 0 ? Math.round((uSold / cOrders) * 100) / 100 : 0,
      afv: cOrders > 0 ? Math.round((nSales / cOrders) * 100) / 100 : 0,
      frequency: uCount > 0 ? Math.round((cOrders / uCount) * 100) / 100 : 0,
      customer_value: uCount > 0 ? Math.round((nSales / uCount) * 100) / 100 : 0,
      avg_actual_tenure: uCount > 0 ? Math.round((actTenure / uCount) * 100) / 100 : 0,
      avg_adoption_tenure: uCount > 0 ? Math.round((adoptTenure / uCount) * 100) / 100 : 0
    };
  });

  return {
    rows: processedRows,
    coverageRows: coverageData.rows || [],
    meses: Array.from(mesesEncontrados).sort(),
    totalFilas: processedRows.length,
    bytesProcessed: totalBytes
  };
}

/**
 * Consulta la cobertura de tiendas Dmart utilizando la lógica exacta de:
 * '3. MAUs Coverage - Base - Performance'
 */
function getCoverageDataBigQuery(mesFiltro) {
  try {
    let whereMes = `cm.month_date >= DATE '${USER360_CONFIG.FECHA_MINIMA}'`;
    if (mesFiltro === "LAST_6") {
      whereMes = "cm.month_date >= DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 6 MONTH)";
    } else if (mesFiltro === "LAST_12") {
      whereMes = "cm.month_date >= DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 12 MONTH)";
    } else if (mesFiltro !== "ALL" && mesFiltro) {
      whereMes = `cm.month_date = DATE '${mesFiltro}'`;
    }

    const sql = `
      DECLARE query_name STRING DEFAULT '3. MAUs Coverage - Base - Performance';

      WITH coverage AS (
        -- Lógica oficial de Matías: Usuarios cubiertos por el polígono
        SELECT
          CAST(cm.month_date AS STRING) AS mes,
          cm.country_id, 
          dc.country_name_en AS country_name,
          SUM(cm.MAUs) AS platform_maus_coverage,
          SUM(dm.CUSTOMERS_CUBIERTOS) AS dmart_maus_cubiertos
        FROM \`${USER360_CONFIG.BQ_PROJECT_ID}.${USER360_CONFIG.BQ_DATASET_ID}.qc_coverage_city_MAUs\` cm
        LEFT JOIN \`${USER360_CONFIG.BQ_PROJECT_ID}.${USER360_CONFIG.BQ_DATASET_ID}.qc_dmart_coverage_city_MAUs\` dm
          ON cm.country_id = dm.country_id 
          AND cm.month_date = dm.month_date 
          AND cm.city_name_lz = dm.city_name_lz
        LEFT JOIN \`peya-bi-tools-pro.il_core.dim_country\` dc
          ON cm.country_id = dc.country_id
        WHERE ${whereMes}
          AND dc.country_name_en NOT IN ('Venezuela', 'Costa Rica')
        GROUP BY 1, 2, 3
      )
      SELECT 
        mes,
        country_name AS country,
        platform_maus_coverage,
        dmart_maus_cubiertos,
        SAFE_DIVIDE(dmart_maus_cubiertos, platform_maus_coverage) AS qc_coverage
      FROM coverage
      ORDER BY 1, 2;
    `;

    const bqRes = ejecutarQueryBigQuery(sql);
    return {
      rows: bqRes.rows.map(r => ({
        mes: r.mes,
        country: r.country,
        platform_maus_coverage: parseFloat(r.platform_maus_coverage) || 0,
        dmart_maus_cubiertos: parseFloat(r.dmart_maus_cubiertos) || 0,
        qc_coverage: (parseFloat(r.qc_coverage) || 0) * 100
      })),
      bytesProcessed: bqRes.bytesProcessed || 0
    };
  } catch (err) {
    return { rows: [], bytesProcessed: 0 };
  }
}

/**
 * Helper para correr consultas en BigQuery via API.
 * Retorna las filas y los bytes procesados (totalBytesProcessed).
 */
function ejecutarQueryBigQuery(sql) {
  if (typeof BigQuery === 'undefined') {
    throw new Error("El servicio avanzado BigQuery no esta habilitado en este proyecto de Apps Script.");
  }

  const request = {
    query: sql,
    useLegacySql: false,
    useQueryCache: false,
    timeoutMs: 120000
  };

  let queryResults = BigQuery.Jobs.query(request, USER360_CONFIG.BQ_PROJECT_ID);
  const jobId = queryResults.jobReference.jobId;

  let sleepMs = 300;
  while (!queryResults.jobComplete) {
    Utilities.sleep(sleepMs);
    sleepMs = Math.min(sleepMs * 2, 4000);
    queryResults = BigQuery.Jobs.getQueryResults(USER360_CONFIG.BQ_PROJECT_ID, jobId);
  }

  let totalBytes = Number(queryResults.totalBytesProcessed || 0);

  let allRows = queryResults.rows || [];
  while (queryResults.pageToken) {
    queryResults = BigQuery.Jobs.getQueryResults(USER360_CONFIG.BQ_PROJECT_ID, jobId, {
      pageToken: queryResults.pageToken
    });
    if (queryResults.rows && queryResults.rows.length > 0) {
      allRows = allRows.concat(queryResults.rows);
    }
  }

  const fieldNames = queryResults.schema.fields.map(f => f.name);
  const mapped = allRows.map(r => {
    const obj = {};
    for (let i = 0; i < fieldNames.length; i++) {
      obj[fieldNames[i]] = r.f[i] ? r.f[i].v : null;
    }
    return obj;
  });

  return {
    rows: mapped,
    bytesProcessed: totalBytes
  };
}

// ==============================================================================
// SISTEMA DE TELEMETRÍA Y REGISTRO EN GOOGLE SHEETS
// ==============================================================================

function esFechaDeEsteMes(valFecha, monthPrefix) {
  if (!valFecha) return false;
  const targetPrefix = monthPrefix || Utilities.formatDate(new Date(), "America/Argentina/Buenos_Aires", "yyyy-MM");

  if (valFecha instanceof Date && !isNaN(valFecha.getTime())) {
    const dStr = Utilities.formatDate(valFecha, "America/Argentina/Buenos_Aires", "yyyy-MM");
    return dStr === targetPrefix;
  }

  const s = String(valFecha).trim();
  if (s.startsWith(targetPrefix)) return true;

  const dObj = new Date(s);
  if (!isNaN(dObj.getTime())) {
    const dStr = Utilities.formatDate(dObj, "America/Argentina/Buenos_Aires", "yyyy-MM");
    return dStr === targetPrefix;
  }
  return false;
}

function extraerBytes(val) {
  if (typeof val === 'number') return val;
  if (!val) return 0;
  const s = String(val).trim().toUpperCase();
  const num = parseFloat(s) || 0;
  if (s.includes('GB')) return num * 1024 * 1024 * 1024;
  if (s.includes('MB')) return num * 1024 * 1024;
  if (s.includes('KB')) return num * 1024;
  return num;
}

function getMonthBytesFromTelemetry() {
  try {
    const ss = SpreadsheetApp.openById(USER360_CONFIG.SHEET_TELEMETRIA_ID);
    const sheet = ss.getSheetByName("Registro_Vistas");
    if (!sheet) return 0;
    const lastRow = sheet.getLastRow();
    if (lastRow <= 1) return 0;

    const data = sheet.getRange(2, 1, lastRow - 1, 11).getValues();
    const currentMonthPrefix = Utilities.formatDate(new Date(), "America/Argentina/Buenos_Aires", "yyyy-MM");
    let totalBytesMes = 0;

    for (let i = 0; i < data.length; i++) {
      const rawFecha = data[i][0];
      const rawBytes = data[i][10];
      if (esFechaDeEsteMes(rawFecha, currentMonthPrefix)) {
        totalBytesMes += extraerBytes(rawBytes);
      }
    }
    return totalBytesMes;
  } catch (err) {
    return 0;
  }
}

function getTodayBytesFromTelemetry() {
  return getMonthBytesFromTelemetry();
}

function registrarTelemetriaUser360(evento) {
  try {
    const ss = SpreadsheetApp.openById(USER360_CONFIG.SHEET_TELEMETRIA_ID);
    asegurarHojasTelemetria(ss);

    const sheetLogs = ss.getSheetByName("Registro_Vistas");
    if (!sheetLogs) return;

    let email = "";
    try { email = Session.getActiveUser().getEmail(); } catch (_) {}
    if (!email) email = "Usuario Web";

    const fecha = Utilities.formatDate(new Date(), "America/Argentina/Buenos_Aires", "yyyy-MM-dd HH:mm:ss");

    sheetLogs.appendRow([
      fecha,
      email,
      evento.accion || "Vista",
      evento.tab || "1. Matriz",
      evento.pais || "LATAM",
      evento.negocio || "Market",
      evento.metrica || "Usuarios Únicos",
      evento.mes || "LAST_6",
      evento.dy || "ALL",
      evento.uf || "ALL",
      evento.bytes || 0
    ]);
  } catch (err) {
    // Silencioso
  }
}

function asegurarHojasTelemetria(ss) {
  let sheetLogs = ss.getSheetByName("Registro_Vistas");
  if (!sheetLogs) {
    sheetLogs = ss.insertSheet("Registro_Vistas");
    sheetLogs.appendRow([
      "Fecha / Hora",
      "Usuario",
      "Acción",
      "Pestaña",
      "País",
      "Negocio",
      "Métrica / Segmento",
      "Rango Temporal",
      "Double Ya",
      "Ultra Fresh",
      "Bytes BQ"
    ]);
    sheetLogs.getRange(1, 1, 1, 11)
      .setFontWeight("bold")
      .setBackground("#EA1D2C")
      .setFontColor("#FFFFFF");
    sheetLogs.setFrozenRows(1);
    sheetLogs.setColumnWidth(1, 150);
    sheetLogs.setColumnWidth(2, 220);
    sheetLogs.setColumnWidth(7, 200);
  }

  let sheetTop = ss.getSheetByName("Lo_Mas_Buscado");
  if (!sheetTop) {
    sheetTop = ss.insertSheet("Lo_Mas_Buscado");

    sheetTop.getRange("A1:H1").merge()
      .setValue("MONITOR DE USO Y ANÁLISIS DE TELEMETRÍA | USER 360")
      .setFontWeight("bold")
      .setFontSize(13)
      .setBackground("#202124")
      .setFontColor("#FFFFFF")
      .setHorizontalAlignment("center");

    sheetTop.getRange("A3").setValue("Métrica de Uso").setFontWeight("bold").setBackground("#F1F3F4");
    sheetTop.getRange("B3").setValue("Valor").setFontWeight("bold").setBackground("#F1F3F4");

    sheetTop.getRange("A4").setValue("Total Vistas / Consultas");
    sheetTop.getRange("B4").setFormula("=COUNTA(Registro_Vistas!A2:A)");

    sheetTop.getRange("A5").setValue("Usuarios Distintos");
    sheetTop.getRange("B5").setFormula("=COUNTUNIQUE(Registro_Vistas!B2:B)");

    sheetTop.getRange("A6").setValue("Total Bytes BQ Consumidos");
    sheetTop.getRange("B6").setFormula("=SUM(Registro_Vistas!K2:K)");

    sheetTop.getRange("A7").setValue("Última Consulta Registrada");
    sheetTop.getRange("B7").setFormula("=MAX(Registro_Vistas!A2:A)");

    sheetTop.getRange("D3:E3").merge()
      .setValue("Top 5 Métricas / Segmentos Más Consultados")
      .setFontWeight("bold")
      .setBackground("#F1F3F4");
    sheetTop.getRange("D4").setFormula(
      '=IFERROR(QUERY(Registro_Vistas!A2:K, "SELECT G, COUNT(A) WHERE G IS NOT NULL AND G <> \'-\' GROUP BY G ORDER BY COUNT(A) DESC LIMIT 5 LABEL G \'Métrica / Segmento\', COUNT(A) \'Consultas\'", 0), "Sin datos aún")'
    );

    sheetTop.getRange("G3:H3").merge()
      .setValue("Top 5 Países Más Consultados")
      .setFontWeight("bold")
      .setBackground("#F1F3F4");
    sheetTop.getRange("G4").setFormula(
      '=IFERROR(QUERY(Registro_Vistas!A2:K, "SELECT E, COUNT(A) WHERE E IS NOT NULL AND E <> \'-\' GROUP BY E ORDER BY COUNT(A) DESC LIMIT 5 LABEL E \'País\', COUNT(A) \'Consultas\'", 0), "Sin datos aún")'
    );

    sheetTop.getRange("A10:B10").merge()
      .setValue("Top Usuarios Más Activos")
      .setFontWeight("bold")
      .setBackground("#F1F3F4");
    sheetTop.getRange("A11").setFormula(
      '=IFERROR(QUERY(Registro_Vistas!A2:K, "SELECT B, COUNT(A) WHERE B IS NOT NULL GROUP BY B ORDER BY COUNT(A) DESC LIMIT 5 LABEL B \'Usuario\', COUNT(A) \'Accesos\'", 0), "Sin datos aún")'
    );

    sheetTop.getRange("D10:E10").merge()
      .setValue("Consultas por Negocio")
      .setFontWeight("bold")
      .setBackground("#F1F3F4");
    sheetTop.getRange("D11").setFormula(
      '=IFERROR(QUERY(Registro_Vistas!A2:K, "SELECT F, COUNT(A) WHERE F IS NOT NULL GROUP BY F ORDER BY COUNT(A) DESC LABEL F \'Negocio\', COUNT(A) \'Total\'", 0), "Sin datos aún")'
    );

    sheetTop.setColumnWidth(1, 200);
    sheetTop.setColumnWidth(2, 140);
    sheetTop.setColumnWidth(4, 220);
    sheetTop.setColumnWidth(5, 110);
    sheetTop.setColumnWidth(7, 180);
    sheetTop.setColumnWidth(8, 110);
  }
}

// ==============================================================================
// MÓDULO EXCLUSIVO DE ANALYTICS Y AUDITORÍA (SOLO VISIBLE PARA MATÍAS)
// Apalancado en la arquitectura de '3_Analytics.html'
// ==============================================================================

/**
 * Consulta y estructura todas las métricas de uso, consultas y datos BQ consumidos
 * a nivel usuario y a nivel total. Exclusivo para el administrador.
 */
function fetchAnalyticsUser360() {
  if (!checkAdminAccess()) {
    return { error: 'Acceso denegado. Panel exclusivo de administrador.' };
  }

  try {
    const ss = SpreadsheetApp.openById(USER360_CONFIG.SHEET_TELEMETRIA_ID);
    const sheet = ss.getSheetByName("Registro_Vistas");
    if (!sheet) {
      return {
        totals: { queries: 0, users: 0, totalBytes: 0, todayQueries: 0 },
        byPeriod: { day: [], week: [], month: [] },
        users: [],
        topMetrics: [],
        topCountries: [],
        topBusinesses: [],
        recentLogs: [],
        asOf: Utilities.formatDate(new Date(), "America/Argentina/Buenos_Aires", "yyyy-MM-dd HH:mm")
      };
    }

    const data = sheet.getDataRange().getValues();
    if (data.length <= 1) {
      return {
        totals: { queries: 0, users: 0, totalBytes: 0, todayQueries: 0 },
        byPeriod: { day: [], week: [], month: [] },
        users: [],
        topMetrics: [],
        topCountries: [],
        topBusinesses: [],
        recentLogs: [],
        asOf: Utilities.formatDate(new Date(), "America/Argentina/Buenos_Aires", "yyyy-MM-dd HH:mm")
      };
    }

    const rows = data.slice(1);
    const now = new Date();
    const todayStr = Utilities.formatDate(now, "America/Argentina/Buenos_Aires", "yyyy-MM-dd");

    let totalQueries = 0;
    let todayQueries = 0;
    let totalBytes = 0;
    const usersSet = new Set();
    const userMap = {};
    const metricMap = {};
    const countryMap = {};
    const businessMap = {};
    const periodMap = { day: {}, week: {}, month: {} };

    rows.forEach(r => {
      const fechaStr = String(r[0] || '').trim();
      const email = String(r[1] || 'Anónimo').trim();
      const accion = String(r[2] || '');
      const tab = String(r[3] || '');
      const pais = String(r[4] || '-');
      const negocio = String(r[5] || '-');
      const metrica = String(r[6] || '-');
      const bytes = parseFloat(r[10]) || 0;

      if (!fechaStr) return;

      totalQueries++;
      totalBytes += bytes;
      usersSet.add(email);

      if (fechaStr.startsWith(todayStr)) {
        todayQueries++;
      }

      // Usuario
      if (!userMap[email]) {
        userMap[email] = { email: email, queries: 0, bytes: 0, lastAccess: fechaStr, metrics: {} };
      }
      const uObj = userMap[email];
      uObj.queries++;
      uObj.bytes += bytes;
      if (fechaStr > uObj.lastAccess) uObj.lastAccess = fechaStr;
      if (metrica && metrica !== '-') {
        uObj.metrics[metrica] = (uObj.metrics[metrica] || 0) + 1;
      }

      // Métricas
      if (metrica && metrica !== '-') {
        metricMap[metrica] = (metricMap[metrica] || 0) + 1;
      }
      // Países
      if (pais && pais !== '-') {
        countryMap[pais] = (countryMap[pais] || 0) + 1;
      }
      // Negocios
      if (negocio && negocio !== '-') {
        businessMap[negocio] = (businessMap[negocio] || 0) + 1;
      }

      // Agrupación temporal (Día, Semana, Mes)
      const dayKey = fechaStr.slice(0, 10);
      const monthKey = fechaStr.slice(0, 7);

      let weekKey = dayKey;
      const dObj = new Date(fechaStr.replace(' ', 'T'));
      if (!isNaN(dObj.getTime())) {
        const dayNum = dObj.getDay();
        const diff = dObj.getDate() - (dayNum === 0 ? 6 : dayNum - 1);
        const mon = new Date(dObj.setDate(diff));
        weekKey = Utilities.formatDate(mon, "America/Argentina/Buenos_Aires", "yyyy-MM-dd");
      }

      [ { gran: 'day', key: dayKey }, { gran: 'week', key: weekKey }, { gran: 'month', key: monthKey } ].forEach(item => {
        if (!periodMap[item.gran][item.key]) periodMap[item.gran][item.key] = {};
        const pObj = periodMap[item.gran][item.key];
        if (!pObj[email]) pObj[email] = { queries: 0, bytes: 0 };
        pObj[email].queries++;
        pObj[email].bytes += bytes;
      });
    });

    // Formatear byPeriod (idéntico a 3_Analytics)
    const finalByPeriod = { day: [], week: [], month: [] };
    ['day', 'week', 'month'].forEach(gran => {
      const keys = Object.keys(periodMap[gran]).sort().reverse();
      keys.forEach(k => {
        const cells = Object.keys(periodMap[gran][k]).map(em => ({
          email: em,
          queries: periodMap[gran][k][em].queries,
          bytes: periodMap[gran][k][em].bytes
        }));
        finalByPeriod[gran].push({ period: k, cells: cells });
      });
    });

    // Ranking de usuarios
    const usersList = Object.values(userMap).map(u => {
      let topMet = '-';
      let maxMetCount = 0;
      for (const m in u.metrics) {
        if (u.metrics[m] > maxMetCount) {
          maxMetCount = u.metrics[m];
          topMet = m;
        }
      }
      return {
        email: u.email,
        queries: u.queries,
        bytes: u.bytes,
        lastAccess: u.lastAccess,
        topMetric: topMet
      };
    }).sort((a,b) => b.bytes - a.bytes || b.queries - a.queries);

    const topMetrics = Object.keys(metricMap).map(m => ({ name: m, count: metricMap[m] })).sort((a,b) => b.count - a.count).slice(0, 10);
    const topCountries = Object.keys(countryMap).map(c => ({ name: c, count: countryMap[c] })).sort((a,b) => b.count - a.count).slice(0, 10);
    const topBusinesses = Object.keys(businessMap).map(b => ({ name: b, count: businessMap[b] })).sort((a,b) => b.count - a.count);

    const recentLogs = rows.slice(-40).reverse().map(r => ({
      fecha: String(r[0] || ''),
      email: String(r[1] || ''),
      accion: String(r[2] || ''),
      tab: String(r[3] || ''),
      pais: String(r[4] || ''),
      negocio: String(r[5] || ''),
      metrica: String(r[6] || ''),
      bytes: parseFloat(r[10]) || 0
    }));

    return {
      totals: {
        queries: totalQueries,
        users: usersSet.size,
        totalBytes: totalBytes,
        todayQueries: todayQueries
      },
      byPeriod: finalByPeriod,
      users: usersList,
      topMetrics: topMetrics,
      topCountries: topCountries,
      topBusinesses: topBusinesses,
      recentLogs: recentLogs,
      asOf: Utilities.formatDate(new Date(), "America/Argentina/Buenos_Aires", "yyyy-MM-dd HH:mm")
    };
  } catch (err) {
    return { error: err.message };
  }
}

/**
 * ==============================================================================
 * FUNCIÓN DE VERIFICACIÓN DIRECTA POR CONSOLA DE APPS SCRIPT:
 * Ejecutala seleccionando 'testConsoleDmartMausSeptiembre' en la barra superior
 * del editor de Apps Script y haciendo clic en 'Ejecutar'.
 * ==============================================================================
 */
function testConsoleDmartMausSeptiembre() {
  const sql = `
    DECLARE query_name STRING DEFAULT 'User 360 - Verificación Consola Sep 2026';

    SELECT
      country,
      business,
      l1,
      l2,
      SUM(users_count) AS users_count
    FROM \`${USER360_CONFIG.BQ_PROJECT_ID}.${USER360_CONFIG.BQ_DATASET_ID}.${USER360_CONFIG.BQ_TABLE_ID}\`
    WHERE Mes = DATE '2026-09-01'
      AND country NOT IN ('Venezuela', 'Costa Rica')
    GROUP BY 1, 2, 3, 4
    ORDER BY country, business, l1, l2;
  `;

  Logger.log("Iniciando consulta directa a BigQuery para septiembre 2026...");
  const res = ejecutarQueryBigQuery(sql);
  const rows = res.rows;

  Logger.log("Total filas obtenidas: " + rows.length);

  const dmartMausPorPais = {};
  const newUsersPorPais = {};
  const l1Set = new Set();
  let totalDmartMausLatam = 0;
  let totalNewUsersLatam = 0;

  rows.forEach(r => {
    l1Set.add(r.l1);
    const l1Up = String(r.l1 || '').toUpperCase();
    const esActivo = !l1Up.includes('CHURN') && !l1Up.includes('NEVER');
    const esNewUser = l1Up.includes('NEW USER') || l1Up.includes('ADOPTION');

    if (r.business === 'Market') {
      const u = parseFloat(r.users_count) || 0;
      if (esActivo) {
        dmartMausPorPais[r.country] = (dmartMausPorPais[r.country] || 0) + u;
        totalDmartMausLatam += u;
      }
      if (esNewUser) {
        newUsersPorPais[r.country] = (newUsersPorPais[r.country] || 0) + u;
        totalNewUsersLatam += u;
      }
    }
  });

  Logger.log("\nValores de L1 encontrados en la tabla:");
  Logger.log(JSON.stringify(Array.from(l1Set)));

  Logger.log("\n--- DMART MAUS POR PAÍS (SEPTIEMBRE 2026) ---");
  for (const c in dmartMausPorPais) {
    Logger.log(`${c}: ${dmartMausPorPais[c].toLocaleString('es-AR')}`);
  }
  Logger.log(`TOTAL LATAM DMART MAUs: ${totalDmartMausLatam.toLocaleString('es-AR')}`);

  Logger.log("\n--- NEW USERS POR PAÍS (SEPTIEMBRE 2026) ---");
  for (const c in newUsersPorPais) {
    Logger.log(`${c}: ${newUsersPorPais[c].toLocaleString('es-AR')}`);
  }
  Logger.log(`TOTAL LATAM NEW USERS: ${totalNewUsersLatam.toLocaleString('es-AR')}`);

  return {
    dmartMausPorPais: dmartMausPorPais,
    totalDmartMausLatam: totalDmartMausLatam,
    newUsersPorPais: newUsersPorPais,
    totalNewUsersLatam: totalNewUsersLatam,
    l1List: Array.from(l1Set)
  };
}
