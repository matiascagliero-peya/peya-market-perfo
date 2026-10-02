// =================================================================
// SIMULATOR DAILY DASHBOARD - CONFIGURACIÓN PRINCIPAL (DEMO/APARENTAR)
// =================================================================
const SS_ID = "1RJ148x2zKVoM8kMXvaoR0Y1wIlp1KcoUJMsyRZ-6Y3k_DEMO";
const CACHE_KEY = "daily_dash_simulado_v1";

/**
 * Función principal para servir la interfaz web del dashboard.
 * Retorna la única página Index.html con datos simulados y métrica inventada.
 */
function doGet(e) {
  var template = HtmlService.createTemplateFromFile('Index');
  
  // Pasamos parámetros opcionales a la plantilla para mayor realismo
  template.version = "1.0.4-sim";
  template.serverTime = new Date().toLocaleString("es-AR", { timeZone: "America/Argentina/Buenos_Aires" });
  template.env = "Simulation";

  return template.evaluate()
      .setTitle('Daily Report - PeYa Markets (Simulado)')
      .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL)
      .addMetaTag('viewport', 'width=device-width, initial-scale=1.0');
}

/**
 * Obtiene los datos consolidados del backend (Simulado para BQ y Sheets).
 * Esta función es invocada desde el frontend usando google.script.run.
 * 
 * @param {string} countryCode Filtro de país (e.g. 'AR', 'UY', 'CL', 'LATAM')
 * @param {string} dateStr Fecha en formato 'YYYY-MM-DD'
 * @return {object} Payload estructurado con métricas, targets e histórico para gráficos.
 */
function getDailyMetrics(countryCode, dateStr) {
  Logger.log("getDailyMetrics solicitado para: " + countryCode + " en fecha: " + dateStr);
  
  // Simular un retardo de red de 800ms para mayor realismo en la UI (pantalla de splash y loaders)
  Utilities.sleep(800);
  
  countryCode = countryCode || 'LATAM';
  dateStr = dateStr || new Date().toISOString().split('T')[0];

  // Base de datos de métricas simuladas por país
  var mockDb = {
    'LATAM': {
      'Quantum Delivery Efficiency (QDE)': { current: 0.948, target: 0.925, wow: 0.015, mom: 0.024, yoy: 0.048, format: 'percent' },
      'Confirmed Orders': { current: 184500, target: 180000, wow: 0.021, mom: 0.035, yoy: 0.125, format: 'number' },
      'GMV User Dmarts': { current: 2214000, target: 2150000, wow: 0.032, mom: 0.041, yoy: 0.152, format: 'currency' },
      'Delivery Time': { current: 21.4, target: 23.0, wow: -0.8, mom: -1.2, yoy: -2.4, format: 'decimal_low_is_better' },
      'Seamless Experience %': { current: 0.892, target: 0.880, wow: 0.007, mom: 0.012, yoy: 0.031, format: 'percent' }
    },
    'AR': {
      'Quantum Delivery Efficiency (QDE)': { current: 0.952, target: 0.930, wow: 0.018, mom: 0.029, yoy: 0.051, format: 'percent' },
      'Confirmed Orders': { current: 85200, target: 83000, wow: 0.025, mom: 0.038, yoy: 0.141, format: 'number' },
      'GMV User Dmarts': { current: 980000, target: 950000, wow: 0.038, mom: 0.045, yoy: 0.165, format: 'currency' },
      'Delivery Time': { current: 20.8, target: 22.5, wow: -1.1, mom: -1.5, yoy: -2.9, format: 'decimal_low_is_better' },
      'Seamless Experience %': { current: 0.901, target: 0.890, wow: 0.009, mom: 0.015, yoy: 0.035, format: 'percent' }
    },
    'UY': {
      'Quantum Delivery Efficiency (QDE)': { current: 0.939, target: 0.920, wow: 0.011, mom: 0.018, yoy: 0.038, format: 'percent' },
      'Confirmed Orders': { current: 28400, target: 28000, wow: 0.014, mom: 0.021, yoy: 0.095, format: 'number' },
      'GMV User Dmarts': { current: 369000, target: 360000, wow: 0.022, mom: 0.031, yoy: 0.118, format: 'currency' },
      'Delivery Time': { current: 22.1, target: 23.5, wow: -0.5, mom: -0.9, yoy: -1.8, format: 'decimal_low_is_better' },
      'Seamless Experience %': { current: 0.884, target: 0.875, wow: 0.005, mom: 0.008, yoy: 0.024, format: 'percent' }
    },
    'CL': {
      'Quantum Delivery Efficiency (QDE)': { current: 0.941, target: 0.925, wow: 0.013, mom: 0.022, yoy: 0.042, format: 'percent' },
      'Confirmed Orders': { current: 41300, target: 40500, wow: 0.019, mom: 0.028, yoy: 0.112, format: 'number' },
      'GMV User Dmarts': { current: 524000, target: 510000, wow: 0.029, mom: 0.036, yoy: 0.134, format: 'currency' },
      'Delivery Time': { current: 21.9, target: 23.2, wow: -0.7, mom: -1.1, yoy: -2.1, format: 'decimal_low_is_better' },
      'Seamless Experience %': { current: 0.889, target: 0.880, wow: 0.006, mom: 0.011, yoy: 0.029, format: 'percent' }
    },
    'BO': {
      'Quantum Delivery Efficiency (QDE)': { current: 0.925, target: 0.910, wow: 0.008, mom: 0.014, yoy: 0.031, format: 'percent' },
      'Confirmed Orders': { current: 16500, target: 16000, wow: 0.011, mom: 0.019, yoy: 0.081, format: 'number' },
      'GMV User Dmarts': { current: 185000, target: 180000, wow: 0.018, mom: 0.025, yoy: 0.098, format: 'currency' },
      'Delivery Time': { current: 23.2, target: 24.5, wow: -0.4, mom: -0.7, yoy: -1.4, format: 'decimal_low_is_better' },
      'Seamless Experience %': { current: 0.872, target: 0.865, wow: 0.004, mom: 0.006, yoy: 0.019, format: 'percent' }
    },
    'PY': {
      'Quantum Delivery Efficiency (QDE)': { current: 0.931, target: 0.915, wow: 0.009, mom: 0.016, yoy: 0.035, format: 'percent' },
      'Confirmed Orders': { current: 13100, target: 12500, wow: 0.015, mom: 0.024, yoy: 0.089, format: 'number' },
      'GMV User Dmarts': { current: 156000, target: 150000, wow: 0.024, mom: 0.032, yoy: 0.105, format: 'currency' },
      'Delivery Time': { current: 22.8, target: 24.0, wow: -0.6, mom: -1.0, yoy: -1.6, format: 'decimal_low_is_better' },
      'Seamless Experience %': { current: 0.879, target: 0.870, wow: 0.005, mom: 0.009, yoy: 0.022, format: 'percent' }
    }
  };

  // Aseguramos que si envían un código de país no contemplado, retorne LATAM
  var countryData = mockDb[countryCode] || mockDb['LATAM'];
  
  // Generar histórico simulado de los últimos 7 días para el gráfico de la métrica inventada (QDE)
  var history = [];
  var baseQDE = countryData['Quantum Delivery Efficiency (QDE)'].current;
  var baseOrders = countryData['Confirmed Orders'].current;
  
  for (var i = 6; i >= 0; i--) {
    var d = new Date(new Date(dateStr) - i * 24 * 60 * 60 * 1000);
    var dateLabel = d.toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit' });
    
    // Pequeñas fluctuaciones aleatorias pero controladas para que se vea real
    var seed = Math.sin(i + countryCode.charCodeAt(0));
    var qdeVal = baseQDE - 0.03 + (seed * 0.015) + (i * 0.004);
    var ordVal = Math.round(baseOrders * (0.92 + (seed * 0.04) + (i * 0.01)));
    
    history.push({
      date: dateLabel,
      qde: Math.min(0.99, Math.max(0.85, qdeVal)),
      qdeTarget: countryData['Quantum Delivery Efficiency (QDE)'].target,
      orders: ordVal,
      ordersTarget: Math.round(countryData['Confirmed Orders'].target * (0.95 + seed * 0.02))
    });
  }

  return {
    success: true,
    country: countryCode,
    date: dateStr,
    metrics: countryData,
    history: history,
    metadata: {
      cached: false,
      timestamp: new Date().getTime(),
      engine: "BQ-Quantum-Query-Simulated"
    }
  };
}

/**
 * Función simulada para simular el envío de correos del Daily Report.
 * Da la apariencia de que el sistema puede enviar reportes reales de prueba.
 */
function sendTestEmail(recipientEmail) {
  Logger.log("Simulando envío de reporte diario a: " + recipientEmail);
  Utilities.sleep(1000);
  
  if (!recipientEmail || recipientEmail.indexOf('@') === -1) {
    return { success: false, message: "Email inválido" };
  }
  
  return { 
    success: true, 
    message: "Reporte diario de prueba enviado con éxito a " + recipientEmail + " (Simulado)" 
  };
}

/**
 * CÓDIGO INTERNO DE RESPALDO (Oculto para propósitos de simulación).
 * Muestra cómo sería la consulta real de BigQuery en producción si se habilitara.
 */
/*
function _executeBigQueryQuery(country) {
  var query = 
    "SELECT \n" +
    "  date, \n" +
    "  SUM(confirmed_orders) as confirmed_orders, \n" +
    "  SUM(gmv_user_dmarts) as gmv_user_dmarts, \n" +
    "  AVG(quantum_efficiency) as qde \n" +
    "FROM `peya-bi.dmarts.daily_report_metrics` \n" +
    "WHERE country = '" + country + "' AND date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY) \n" +
    "GROUP BY 1 ORDER BY 1 DESC";
    
  var request = {
    query: query,
    useLegacySql: false
  };
  
  try {
    var queryResults = BigQuery.Jobs.query(request, "peya-bi");
    var jobId = queryResults.jobReference.jobId;
    // ... procesar filas ...
  } catch (err) {
    Logger.log("Error en BQ: " + err.toString());
  }
}
*/
