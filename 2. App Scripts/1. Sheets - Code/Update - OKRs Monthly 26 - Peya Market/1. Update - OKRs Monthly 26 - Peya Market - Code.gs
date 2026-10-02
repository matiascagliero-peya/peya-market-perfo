// 1. CONFIGURACIÓN GLOBAL
const ID_ARCHIVO_UNICO = "1oGrGlkUxSeuW2CInKxpGSJQpkA_SJL-uqEF5nDx6FiI";

// Cache global para SpreadsheetApp.openById para evitar latencias de red repetitivas
const CACHE_SS = {};
function obtenerSpreadsheetConCache(id) {
  const cleanId = id.trim();
  if (!CACHE_SS[cleanId]) {
    try {
      const activeSS = SpreadsheetApp.getActiveSpreadsheet();
      if (activeSS && activeSS.getId() === cleanId) {
        CACHE_SS[cleanId] = activeSS;
      }
    } catch (e) {
      // Ignorar si no hay ActiveSpreadsheet en este contexto
    }
    if (!CACHE_SS[cleanId]) {
      CACHE_SS[cleanId] = SpreadsheetApp.openById(cleanId);
    }
  }
  return CACHE_SS[cleanId];
}

// Módulo General data
// PARTE 0: Refrescar las fuentes (MANTENIDA EXACTAMENTE IGUAL, SIN CAMBIOS)
function RefreshAllSources() {
  Logger.log("🔄 INICIO: Refrescando SOLO extractos (Data Source Tables) para ahorrar consultas a BQ...");
  
  const TIEMPO_ESPERA_MAX = 300; 

  try { SpreadsheetApp.enableBigQueryExecution(); } catch (e) { Logger.log("⚠️ No se pudo habilitar BigQueryExecution."); }

  // 1. Agrupar la configuración por ID de archivo para optimizar aperturas
  const archivos = {};

  if (typeof CONFIG_GD_IMPORT !== 'undefined') {
    CONFIG_GD_IMPORT.forEach(c => {
      if (c.id_origen && !c.id_origen.includes("PENDIENTE")) {
        const id = c.id_origen.trim();
        if (!archivos[id]) {
          // Ya no guardamos hojasConexion, solo los extractos
          archivos[id] = { hojasExtracto: new Set() };
        }
        // Guardamos los nombres de las hojas de extracto a actualizar
        if (c.nombre_hoja_origen) archivos[id].hojasExtracto.add(c.nombre_hoja_origen);
      }
    });
  }

  // B. ID manual de P&L (si no está en la config, lo iniciamos vacío)
  const idPL = "1MeXHCeDGOkS7WIztOeWAD1WkwvuFOW_Mr-d1zdnoYww";
  if (!archivos[idPL]) archivos[idPL] = { hojasExtracto: new Set() };

  // 2. Iterar sobre cada archivo único
  Object.keys(archivos).forEach(id => {
    try {
      const ssExterna = SpreadsheetApp.openById(id);
      Logger.log(`📂 Procesando archivo: ${ssExterna.getName()}`);
      
      const configArchivo = archivos[id];

      // SE OMITIÓ EL PASO 1 INTENCIONALMENTE PARA AHORRAR DATOS EN BQ

      // PASO 2: Refrescar ÚNICAMENTE los Extractos (Tablas vinculadas)
      configArchivo.hojasExtracto.forEach(nombreHoja => {
        const sheet = ssExterna.getSheetByName(nombreHoja);
        if (sheet) {
          const tables = sheet.getDataSourceTables();
          if (tables.length > 0) {
            tables.forEach((table, index) => {
              try {
                Logger.log(`   ⏳ Iniciando refresh en Extracto ${index + 1} de ${nombreHoja}...`);
                const execution = table.refreshData();
                execution.waitForCompletion(TIEMPO_ESPERA_MAX);
                Logger.log(`   ✅ Extracto refrescado.`);
              } catch (e) {
                Logger.log(`   🔸 Error refrescando tabla en ${nombreHoja}: ${e.message}`);
              }
            });
          } else {
            // Logger opcional por si la hoja no tiene tabla de extracción
            Logger.log(`   ℹ️ La hoja '${nombreHoja}' no contiene Data Source Tables para refrescar.`);
          }
        } else {
          Logger.log(`   ⚠️ La hoja de extracto '${nombreHoja}' no existe en este archivo.`);
        }
      });

      Logger.log(`🏁 Fin del proceso en: ${ssExterna.getName()}`);
      
    } catch (e) {
      Logger.log(`❌ Error crítico al abrir ID ${id}: ${e.message}`);
    }
  });
  
  Logger.log("🔄 FIN TOTAL: Proceso completado (Solo Extractos).");
}

// PARTE A: Configuración de Importación (Origen -> Destino) ---
const CONFIG_GD_IMPORT = [
  { id_origen: '13yTO_kFzIvISmbSz6p93BFUub1HODpuiGhB3yElZ2fw', nombre_hoja_conexion: 'Connection - Mensual', nombre_hoja_origen: '1. TD - OKRs Mensual', nombre_hoja_destino: '0 - Orders' },

  { id_origen: '1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo', nombre_hoja_conexion: 'Connection - Mensual', nombre_hoja_origen: '1. ET - OPS Data - Mensual', nombre_hoja_destino: '1 - OPS Data' },
  { id_origen: '1uHtKswKM8TkGATjcP7IcNkQxUhIYyzhJ0HeseJk3RpA', nombre_hoja_conexion: 'Connection - Principal', nombre_hoja_origen: '1. TD - Sessions Latam', nombre_hoja_destino: '2 - Sessions Type' },
  { id_origen: '1F4SltNDW-xuEoRzIeWkxjtBH91GzQoz8KrqW0aGQyrQ', nombre_hoja_conexion: 'Connection - Principal', nombre_hoja_origen: '1. ET - Sessions Resume', nombre_hoja_destino: '3 - Sessions & CVR' },
  { id_origen: '1X0bnsCoDszeSlq5TT1uw20GWtcfu1iBpshXXI1QIv7M', nombre_hoja_conexion: 'Connection - Principal', nombre_hoja_origen: '1. ET - Users Type Count', nombre_hoja_destino: '4 - Users' },
  { id_origen: '1aCrgEjh6qT5T8ayT2H22r3iNc55nAR1O9vaOCW6pRBs', nombre_hoja_origen: 'A. TI - SC Data - Monthly', nombre_hoja_destino: '5 - Supply Chain' },

  { id_origen: '1OKKkKQUF_n3FbBzOJLteOoRSIPxm3PZZKIgdeoPXB4E', nombre_hoja_conexion: 'Connection - Principal', nombre_hoja_origen: '1. TD - Users Type', nombre_hoja_destino: '6 - Active User Dmart - old' },
  { id_origen: '1k1CC8AkfWwnI4aRQATtBQ2t3bYu8RbDYU6Vwxk5qW9o', nombre_hoja_conexion: 'Connection - Principal', nombre_hoja_origen: '1. ET - Market Coverage', nombre_hoja_destino: '7 - Market Coverage' },
  { id_origen: '1v5Ch2HIK3MJTX1aR9iWiNbxbtMUjYLROCiQz4DqzjNk', nombre_hoja_conexion: 'Connection - Principal', nombre_hoja_origen: '1. ET - Stacked deliveries', nombre_hoja_destino: '8 - Stacked deliveries' },
  { id_origen: '1J5vZqkDrxGRlEFE07W9BD-SquluwzoGhpu3z32tYFZM', nombre_hoja_conexion: 'Connection - Mensual', nombre_hoja_origen: '1. TE - AQS v7', nombre_hoja_destino: '9 - AQS' },

  { id_origen: '11QqrvD_M--OnZZWvGt-MNi17ixPqIToIe5ca-wrRn3k', nombre_hoja_conexion: 'Connection - Principal', nombre_hoja_origen: '1. ET - Rating', nombre_hoja_destino: '11 - Rating' },
  { id_origen: '1RmOQIQNuIy_9UiBxz1M1TF4q03RkYOx-BEO2jK4kWKc', nombre_hoja_conexion: 'Connection - Principal', nombre_hoja_origen: '1. ET - Planning', nombre_hoja_destino: '12 - Planning Data' },
  { id_origen: '1VfL2mU3HpUZgFqCxTjtWeoqZ5lupjqpeKK8b0y96JB0', nombre_hoja_conexion: 'Connection - Principal', nombre_hoja_origen: '1. ET - Fill In', nombre_hoja_destino: '13 - Fill In' },
  { id_origen: '15-zHA4HDBopwhCBjwhIeHr-mLpVuYCe5I0G4bd8X-4s', nombre_hoja_conexion: 'Connection - Principal', nombre_hoja_origen: '1. ET - UF Data', nombre_hoja_destino: '14 - UF Data' },
  { id_origen: '1MiQ6pB0Oc4TdiCGfXBR50mp-h22nBQt91g_QWOXO67k', nombre_hoja_conexion: 'Connection - Principal', nombre_hoja_origen: '1. ET - MAUs Coverage', nombre_hoja_destino: '15 - MAUs Coverage' },

  { id_origen: '1MeXHCeDGOkS7WIztOeWAD1WkwvuFOW_Mr-d1zdnoYww', nombre_hoja_conexion: '', nombre_hoja_origen: '1. IT - Analitycs', nombre_hoja_destino: '16 - Analitycs' },
  { id_origen: '1iYX7EcVJ6hl4G6Jw4SkPfEOX25uNvw6Kw1F2LNXCfMk', nombre_hoja_conexion: 'Connection - Principal', nombre_hoja_origen: '1. ET - PQS v3', nombre_hoja_destino: '17 - PQS' },
  { id_origen: '1s91vz3ppIavr6dyXWHqRRqeYHSs-gWkoEaYBq8qkrBw', nombre_hoja_conexion: 'Connection - Principal', nombre_hoja_origen: '1. ET - Mensual', nombre_hoja_destino: '18 - Open Time' },
  { id_origen: '10-Tj3b4ZkGnxQTEnrD9Vfw4Tj--vMTeScrtSLmo03bw', nombre_hoja_conexion: 'Connection - Principal', nombre_hoja_origen: '1. ET - Promo', nombre_hoja_destino: '19 - Promo' },
  { id_origen: '1NrJvp-cP72Eu5tFBYL86J0kRYsdxuVQofFnPfcZ85PE', nombre_hoja_origen: '1. TI - Price index', nombre_hoja_destino: '20 - Price Index' },
  
  { id_origen: '18cUpQbzQXxAMcDix675p1zscuc_SmvXS_bYaVtEkUUU', nombre_hoja_conexion: 'Connection - Principal', nombre_hoja_origen: '1. ET - DY Data', nombre_hoja_destino: '21 - Double Ya Data' },
  { id_origen: '1MqB23kt7VUaunpVheYPi-Yef2u_jtnW7FPtxN6ILj34', nombre_hoja_conexion: 'Connection - Principal', nombre_hoja_origen: '1. TD - Churned Users', nombre_hoja_destino: '22 - Churned Users' },
  { id_origen: '1P3DswnPrt7VF3DM1jC-IhtoOKmI6CRWx_Hbf-5qYaDk', nombre_hoja_conexion: 'Connection - Principal', nombre_hoja_origen: '1. ET - New user>60', nombre_hoja_destino: '23 - New user>60' },
   
  { id_origen: '1yoIkjCi3mwaXQOwpPpvbxcVE5IEFHXY7uRSytN9WaTo', nombre_hoja_conexion: 'Connection - Principal', nombre_hoja_origen: '1. ET - Users details', nombre_hoja_destino: '24 - Users details' },
  { id_origen: '1O-diG9Qc9NqB5ydMwkCPlB9usIGg66s_nRl2uRAAlx4', nombre_hoja_conexion: 'Connection - Principal', nombre_hoja_origen: '1. ET - NPS', nombre_hoja_destino: '25 - NPS Score' },
  { id_origen: '1jrU8gZPV_nGQCea7cHw85fo9HNZT37uuBfGY9AqjAiY', nombre_hoja_conexion: 'Connection - Principal', nombre_hoja_origen: '1. ET - Mensual', nombre_hoja_destino: '26 - Small Order Fee' }
];

// --- PARTE B: Función de Importación ---
function GeneralData_ImportarTablas() {
  const ssDestino = obtenerSpreadsheetConCache(ID_ARCHIVO_UNICO.trim());
  Logger.log("... Importando tablas externas ...");
  CONFIG_GD_IMPORT.forEach(conf => {
    if (!conf.id_origen.includes("PENDIENTE")) {
       GeneralData_Helper_Importar(conf, ssDestino);
    } else {
       Logger.log(`⚠️ SALTADO: Falta ID para ${conf.nombre_hoja_origen}`);
    }
  });
}

// --- PARTE C: Configuración de Métricas ---
const CONFIG_GD_METRICAS = [
  { // 0 - Orders
    nombreHoja: "0 - Orders", 
    indices: { month: 0, country: 1 }, 
    calcularLatam: true, 
    metricas: [
      // --- INDEX 2 ---
      { name: 'Active warehouses', index: 2, colorFormating: 1 },

      // --- INDEX 4 ---
      { name: 'PeYa MAUs', index: 4, colorFormating: 1 },

      // --- INDEX 5 ---
      { name: 'Dmart MAUs', index: 5, colorFormating: 1 },

      // --- INDEX 6 ---
      { name: 'Dmart MAUs - Plus', index: 6, colorFormating: 1 },

      // --- INDEX 7 ---
      { name: 'Confirmed Orders', index: 7, colorFormating: 1 },
      { name: 'Daily Orders', calculo: (f) => safeDiv(f[7], obtenerDiasDelMes(f[0])), colorFormating: 1 },
      { name: 'Daily Orders per Store', calculo: (f) => safeDiv(f[7], (parseFloat(f[2])||0) * obtenerDiasDelMes(f[0])), usarComponentes: true, indicesLatam: [7, 2], calculoLatam: (c, mes) => safeDiv(c[0], c[1] * obtenerDiasDelMes(mes)), format: '0.00', colorFormating: 1 },

      // --- INDEX 8 ---
      { name: 'Total Platform confirmed Orders', index: 8, colorFormating: 1 },
      { name: 'Confirmed Orders share %', calculo: (f) => safeDiv(f[7], f[8]), usarComponentes: true, indicesLatam: [7, 8], calculoLatam: (c) => safeDiv(c[0], c[1]), format: '0.00%', colorFormating: 1 },

      // --- INDEX 10 ---
      { name: 'Units Sold', index: 10, colorFormating: 1 },
      { name: 'Basket Size', calculo: (f) => safeDiv(f[10], f[7]), usarComponentes: true, indicesLatam: [10, 7], calculoLatam: (c) => safeDiv(c[0], c[1]), format: '0.00', colorFormating: 1 },

      // --- INDEX 11 ---
      { name: 'Confirmed Orders - Plus', index: 11, colorFormating: 1 },
      { name: 'Daily Orders - Plus', calculo: (f) => safeDiv(f[11], obtenerDiasDelMes(f[0])), colorFormating: 1 },
      { name: 'Plus Orders %', calculo: (f) => safeDiv(f[11], f[7]), usarComponentes: true, indicesLatam: [11, 7], calculoLatam: (c) => safeDiv(c[0], c[1]), format: '0.00%', colorFormating: 1 },
      { name: 'Confirmed Orders share % - Plus', calculo: (f) => safeDiv(f[11], f[7]), usarComponentes: true, indicesLatam: [11, 7], calculoLatam: (c) => safeDiv(c[0], c[1]), format: '0.00%', colorFormating: 1 },

      // --- INDEX 12 ---
      { name: 'Discounts', index: 12, colorFormating: 0 },

      // --- INDEX 13 ---
      { name: 'GMV Vendor Dmarts', index: 13, colorFormating: 1 },

      // --- INDEX 15 / 16 ---
      { name: 'GMV User Dmarts', index: 15, colorFormating: 1 },
      { name: 'Daily GMV User Dmarts', calculo: (f) => safeDiv(f[15], obtenerDiasDelMes(f[0])), colorFormating: 1 },
      { name: 'GMV User Share Dmarts %', calculo: (f) => safeDiv(f[15], f[16]), usarComponentes: true, indicesLatam: [15, 16], calculoLatam: (c) => safeDiv(c[0], c[1]), format: '0.00000%', colorFormating: 1 },
      { name: 'GMV User by Store', calculo: (f) => safeDiv(f[15], f[2]), usarComponentes: true, indicesLatam: [15, 2], calculoLatam: (c) => safeDiv(c[0], c[1]), format: '0.00', colorFormating: 1 },

      // --- INDEX 17 ---
      { name: 'Delivery Fee', index: 17, colorFormating: 0 },

      // --- INDEX 18 ---
      { name: 'Service Fee', index: 18, colorFormating: 0 },

      // --- INDEX 24 ---
      { name: 'Free Delivery Fee Orders', index: 24, colorFormating: 0 },

      // --- INDEX 25 ---
      { name: 'Voucher Orders', index: 25, colorFormating: 0 },

      // --- INDEX 26 ---
      { name: 'Incentivized Orders', index: 26, colorFormating: 0 },
      { name: 'Incentivized Orders %', calculo: (f) => safeDiv(f[26], f[7]), usarComponentes: true, indicesLatam: [26, 7], calculoLatam: (c) => safeDiv(c[0], c[1]), format: '0.00%', colorFormating: 0 },

      // --- INDEX 28 ---
      { name: 'Rider CPO Dmarts', index: 28, colorFormating: 1 },

      // --- INDEX 29 ---
      { name: 'Rider CPO Platform (excl Courier)', index: 29, colorFormating: 1 }
    ]
  },  { // 1 - OPS Data (MENSUAL)
    nombreHoja: "1 - OPS Data",
    indices: { month: 0, country: 1 },
    calcularLatam: true,
    esGranularidadDiaria: false,
    metricas: [

      // ════════════════════════════════════════════════════════════════
      // orders_data_agg (od)  → cols 2-3
      // ════════════════════════════════════════════════════════════════
      { name: 'Total_orders_fact_orders',            index: 2, colorFormating: 1, latam: false },
      { name: 'Total_orders_fact_orders_all_status', index: 3, colorFormating: 1, latam: false },

      // ════════════════════════════════════════════════════════════════
      // seamless_data_monthly (sdm)  → cols 4-10
      // ════════════════════════════════════════════════════════════════
      { name: 'Seamless Delivery orders',    index: 4,  colorFormating: 0, latam: false },
      { name: 'Seamless Delivery %',
        calculo: (f) => safeDiv(f[4], f[3]),
        usarComponentes: true, indicesLatam: [4, 3], calculoLatam: (c) => safeDiv(c[0], c[1]),
        format: '0.00%', colorFormating: 1, latam: true },

      { name: 'Rejected orders',             index: 5,  colorFormating: 0, latam: false },
      { name: 'Rejected orders %',
        calculo: (f) => safeDiv(f[5], f[3]),
        usarComponentes: true, indicesLatam: [5, 3], calculoLatam: (c) => safeDiv(c[0], c[1]),
        format: '0.00%', colorFormating: 0, latam: true },

      { name: 'Forced Pre Orders',           index: 6,  colorFormating: 0, latam: false },
      { name: 'Forced Pre Orders %',
        calculo: (f) => safeDiv(f[6], f[3]),
        usarComponentes: true, indicesLatam: [6, 3], calculoLatam: (c) => safeDiv(c[0], c[1]),
        format: '0.00%', colorFormating: 0, latam: true },

      { name: 'Modified orders',             index: 7,  colorFormating: 0, latam: false },
      { name: 'Modified orders %',
        calculo: (f) => safeDiv(f[7], f[3]),
        usarComponentes: true, indicesLatam: [7, 3], calculoLatam: (c) => safeDiv(c[0], c[1]),
        format: '0.00%', colorFormating: 0, latam: true },

      { name: 'HC Sessions orders',          index: 8,  colorFormating: 0, latam: false },
      { name: 'HC Sessions orders %',
        calculo: (f) => safeDiv(f[8], f[3]),
        usarComponentes: true, indicesLatam: [8, 3], calculoLatam: (c) => safeDiv(c[0], c[1]),
        format: '0.00%', colorFormating: 0, latam: true },

      { name: 'Slow orders',                 index: 9,  colorFormating: 0, latam: false },
      { name: 'Slow orders %',
        calculo: (f) => safeDiv(f[9], f[3]),
        usarComponentes: true, indicesLatam: [9, 3], calculoLatam: (c) => safeDiv(c[0], c[1]),
        format: '0.00%', colorFormating: 0, latam: true },

      { name: 'Late Orders',                 index: 10, colorFormating: 0, latam: false },
      { name: 'Late Orders %',
        calculo: (f) => safeDiv(f[10], f[3]),
        usarComponentes: true, indicesLatam: [10, 3], calculoLatam: (c) => safeDiv(c[0], c[1]),
        format: '0.00%', colorFormating: 0, latam: true },

      // ════════════════════════════════════════════════════════════════
      // pickers_orders (picko)  → cols 11-14
      // ════════════════════════════════════════════════════════════════
      { name: 'Picker shift confirmed orders',            index: 11, colorFormating: 1, latam: false },
      { name: 'Assignment Time total',                    index: 12, colorFormating: 1, latam: false },
      { name: 'Assignment Time',
        calculo: (f) => safeDiv(f[12], f[11]),
        usarComponentes: true, indicesLatam: [12, 11], calculoLatam: (c) => safeDiv(c[0], c[1]),
        format: '0.00', colorFormating: 0, latam: true },
      { name: 'Assignment Time > 6 min orders',           index: 13, colorFormating: 0, latam: false }, 
      { name: 'Assignment Time > 6 min %',
        calculo: (f) => safeDiv(f[13], f[11]),
        usarComponentes: true,
        indicesLatam: [13, 11], 
        calculoLatam: (c) => safeDiv(c[0], c[1]),
        format: '0.00%', colorFormating: 0, latam: true },
      { name: 'Picking Time',                             index: 14, colorFormating: 1, latam: false },

      // ════════════════════════════════════════════════════════════════
      // delivery_time_agg (dta)  → cols 15-20
      // ════════════════════════════════════════════════════════════════
      { name: 'non_forced_completed_orders_logistics', index: 15, colorFormating: 1, latam: false },

      { name: 'Delivery Time total',         index: 16, colorFormating: 1, latam: false },
       // OPS
      { 
        name: 'Avg. Delivery Time',
        calculo: (f) => safeDiv(f[16], f[15]), 
        usarComponentes: true, 
        indicesLatam: [16, 15], 
        calculoLatam: (c) => safeDiv(c[0], c[1]), 
        format: '0.00', 
        colorFormating: 0, 
        latam: true 
      },

      { name: 'Stacked 0 orders',            index: 17, colorFormating: 1, latam: false },
      { name: 'Stacked 1 orders',            index: 18, colorFormating: 1, latam: false },
      { name: 'Stacked 2 orders',            index: 19, colorFormating: 1, latam: false },
      { name: 'Stacked 3 or more orders',    index: 20, colorFormating: 1, latam: false },
      { name: 'Total Stacked Orders',
        calculo: (f) => (parseFloat(f[18]) || 0) + (parseFloat(f[19]) || 0) + (parseFloat(f[20]) || 0),
        format: '#,##0', colorFormating: 1, latam: true },

      { 
        name: 'Stacked deliveries %',
        calculo: (f) => safeDiv((parseFloat(f[18]) || 0) + (parseFloat(f[19]) || 0) + (parseFloat(f[20]) || 0), f[15]),
        usarComponentes: true, 
        indicesLatam: [18, 19, 20, 15], 
        calculoLatam: (c) => safeDiv(c[0] + c[1] + c[2], c[3]), 
        format: '0.00%', 
        colorFormating: 0, 
        latam: true 
      },
          // ════════════════════════════════════════════════════════════════
      // timings_data (td)  → cols 21-24
      // ════════════════════════════════════════════════════════════════
      { name: 'Total_orders_timings',        index: 21, colorFormating: 1, latam: false },
      { name: 'Picked_items',                index: 22, colorFormating: 1, latam: false },

      { name: 'Item Picking Time Total',     index: 23, colorFormating: 0, latam: false },
      { name: 'Item Picking Time',
        calculo: (f) => safeDiv(f[23], f[22]),
        usarComponentes: true, indicesLatam: [23, 22], calculoLatam: (c) => safeDiv(c[0], c[1]),
        format: '0.00', colorFormating: 0, latam: true },

      { name: 'Delivery time > 35 min orders', index: 24, colorFormating: 0, latam: false },
      { name: 'Delivery time > 35 min %',
        calculo: (f) => safeDiv(f[24], f[21]),
        usarComponentes: true, indicesLatam: [24, 21], calculoLatam: (c) => safeDiv(c[0], c[1]),
        format: '0.00%', colorFormating: 0, latam: true },

      // ════════════════════════════════════════════════════════════════
      // logistics_orders_monthly (lom)  → cols 25-29
      // denominador = total_orders_logistics (col 25)
      // ════════════════════════════════════════════════════════════════
      { name: 'Total orders logistics',      index: 25, colorFormating: 1, latam: false },

      { name: 'Order late 10 min orders',    index: 26, colorFormating: 0, latam: false },
      { name: 'Order late 10 min %',
        calculo: (f) => safeDiv(f[26], f[25]),
        usarComponentes: true, indicesLatam: [26, 25], calculoLatam: (c) => safeDiv(c[0], c[1]),
        format: '0.00%', colorFormating: 0, latam: true },

      { name: 'Vendor late 10 min orders',   index: 27, colorFormating: 0, latam: false },
      { name: 'Vendor Late > 10 min %',
        calculo: (f) => safeDiv(f[27], f[25]),
        usarComponentes: true, indicesLatam: [27, 25], calculoLatam: (c) => safeDiv(c[0], c[1]),
        format: '0.00%', colorFormating: 0, latam: true },

      { name: 'AWT total',                   index: 28, colorFormating: 0, latam: false },
      { name: 'Avg. AWT',
        calculo: (f) => safeDiv(f[28] / 60, f[25]),
        usarComponentes: true, indicesLatam: [28, 25], calculoLatam: (c) => safeDiv(c[0] / 60, c[1]),
        format: '0.00', colorFormating: 0, latam: true },
      { name: 'EPT-APT > 5 min orders',                   index: 29, colorFormating: 0, latam: false }, 
      { name: 'EPT-APT > 5 min %',
        calculo: (f) => safeDiv(f[29], f[25]),
        usarComponentes: true,
        indicesLatam: [29, 25], 
        calculoLatam: (c) => safeDiv(c[0], c[1]),
        format: '0.00%', colorFormating: 0, latam: true },

      // ════════════════════════════════════════════════════════════════
      // inaccuracy  → cols 30-33
      // ════════════════════════════════════════════════════════════════
      { name: 'Total orders inaccuracy',     index: 30, colorFormating: 1, latam: false },

      { name: 'Inaccuracy Orders',           index: 31, colorFormating: 0, latam: false },
      { name: 'Inaccuracy %',
        calculo: (f) => safeDiv(f[31], f[30]),
        usarComponentes: true, indicesLatam: [31, 30], calculoLatam: (c) => safeDiv(c[0], c[1]),
        format: '0.00%', colorFormating: 0, latam: true },

      { name: 'Food Issue Orders',           index: 32, colorFormating: 0, latam: false },
      { name: 'Item Issue Orders',           index: 33, colorFormating: 0, latam: false },
      { name: 'Inaccuracy Product %',
        calculo: (f) => safeDiv((parseFloat(f[32]) || 0) + (parseFloat(f[33]) || 0), f[31]),
        usarComponentes: true, indicesLatam: [32, 33, 31], calculoLatam: (c) => safeDiv(c[0] + c[1], c[2]),
        format: '0.00%', colorFormating: 0, latam: true },

      // ════════════════════════════════════════════════════════════════
      // productividad_data (proDa)  → cols 34-39
      // ════════════════════════════════════════════════════════════════
      { name: 'Picking units',                index: 34, colorFormating: 1, latam: false },
      { name: 'Receiving units',              index: 35, colorFormating: 1, latam: false },
      { name: 'Ajuste UTR',                   index: 36, colorFormating: 1, latam: false }, 
      { name: 'Received bags',                index: 39, colorFormating: 0, latam: false },
      { name: 'Numerador UTR+',
        calculo: (f) => (parseFloat(f[34]) || 0) + (parseFloat(f[35]) || 0) + (parseFloat(f[36]) || 0) - (parseFloat(f[39]) || 0), 
        format: '#,##0', colorFormating: 1, latam: true },

      { name: 'Picker working hours',        index: 37, colorFormating: 1, latam: false }, 
      { name: 'Manager working hours',       index: 38, colorFormating: 1, latam: false }, 
      { name: 'Denominador UTR+',
        calculo: (f) => (parseFloat(f[37]) || 0),
        format: '#,##0.00', colorFormating: 1, latam: true },
        
      { name: 'UTR+',
        calculo: (f) => safeDiv((parseFloat(f[34]) || 0) + (parseFloat(f[35]) || 0) + (parseFloat(f[36]) || 0) - (parseFloat(f[39]) || 0), (parseFloat(f[37]) || 0)),
        usarComponentes: true,
        indicesLatam: [34, 35, 36, 37, 39], 
        calculoLatam: (c) => safeDiv(c[0] + c[1] + c[2] - c[4], c[3]),
        format: '0.00', colorFormating: 1, latam: true },

      { name: 'Total Working Hours',
        calculo: (f) => (parseFloat(f[37]) || 0) + (parseFloat(f[38]) || 0),
        usarComponentes: true,
        indicesLatam: [37, 38],
        calculoLatam: (c) => c[0] + c[1],
        format: '#,##0.00', colorFormating: 1, latam: true },

      { name: 'UTR Picking',
        calculo: (f) => safeDiv(f[34], (parseFloat(f[37]) || 0)),
        usarComponentes: true,
        indicesLatam: [34, 37],
        calculoLatam: (c) => safeDiv(c[0], c[1]),
        format: '0.00', colorFormating: 1, latam: true },

      { name: 'UTR Receiving',
        calculo: (f) => safeDiv((parseFloat(f[35]) || 0) - (parseFloat(f[39]) || 0), (parseFloat(f[37]) || 0)),
        usarComponentes: true,
        indicesLatam: [35, 37, 39],
        calculoLatam: (c) => safeDiv(c[0] - c[2], c[1]),
        format: '0.00', colorFormating: 1, latam: true },

      // ════════════════════════════════════════════════════════════════
      // original_by_ops_diario (opsd)  → cols 40-42
      // ════════════════════════════════════════════════════════════════
      { name: 'Total_orders_ops',            index: 40, colorFormating: 1, latam: false }, 

      { name: 'Partial orders',              index: 41, colorFormating: 0, latam: false }, 
      { name: 'Partial orders %',
        calculo: (f) => safeDiv(f[41], f[40]),
        usarComponentes: true, indicesLatam: [41, 40], calculoLatam: (c) => safeDiv(c[0], c[1]),
        format: '0.00%', colorFormating: 0, latam: true },

      { name: 'Lost orders',                 index: 42, colorFormating: 0, latam: false }, 
      { name: 'Lost orders %',
        calculo: (f) => safeDiv(f[42], f[3]),
        usarComponentes: true, indicesLatam: [42, 3], calculoLatam: (c) => safeDiv(c[0], c[1]),
        format: '0.00%', colorFormating: 0, latam: true },
    ]
  }, { // 3 - Sessions & CVR 
    nombreHoja: "3 - Sessions & CVR", 
    indices: { month: 1, country: 2 }, 
    calcularLatam: true, 
    metricas: [
      // === METRICAS DE VOLUMEN (CONTEOS BRUTOS) ===
      { name: 'Sessions',          index: 3, colorFormating: 1 }, 
      { name: 'Daily Sessions',    calculo: (f) => safeDiv(f[3], obtenerDiasDelMes(f[1])), colorFormating: 1 }, 
      { name: 'Cart Added Sessions',           index: 4, colorFormating: 1 }, 
      { name: 'Checkout Sessions',             index: 5, colorFormating: 1 }, 
      { name: 'Shop Checkout Sessions',           index: 6, colorFormating: 1 }, 

      // === RATIOS DE CONVERSIÓN ===
      { 
        name: 'CVR3 %', 
        calculo: (f) => safeDiv(f[6], f[3]), 
        usarComponentes: true,
        indicesLatam: [6, 3], 
        calculoLatam: (c) => safeDiv(c[0], c[1]),
        format: '0.00%',
        colorFormating: 1 
      },
      { 
        name: 'mCVR3 %', 
        calculo: (f) => safeDiv(f[6], f[4]), 
        usarComponentes: true,
        indicesLatam: [6, 4], 
        calculoLatam: (c) => safeDiv(c[0], c[1]),
        format: '0.00%',
        colorFormating: 1 
      },
      { 
        name: 'mCVR4 %', 
        calculo: (f) => safeDiv(f[6], f[5]), 
        usarComponentes: true,
        indicesLatam: [6, 5], 
        calculoLatam: (c) => safeDiv(c[0], c[1]),
        format: '0.00%',
        colorFormating: 1 
      }
    ]
  }, { // 4 - Users 
    nombreHoja: "4 - Users", 
    indices: { month: 0, country: 1 },
    calcularLatam: true, 
    metricas: [
      { name: 'Churned Users - Dmart',      calculo: (f) => (String(f[2]).trim() === 'Dmart' && String(f[3]).trim() === 'Churned') ? (parseFloat(f[4])||0) : 0, colorFormating: 0 },
      { name: 'Inactive < 6m - Dmart',      calculo: (f) => (String(f[2]).trim() === 'Dmart' && String(f[3]).trim() === 'Inactive < 6 month') ? (parseFloat(f[4])||0) : 0, colorFormating: 0 },
      { name: 'Inactive > 6m - Dmart',      calculo: (f) => (String(f[2]).trim() === 'Dmart' && String(f[3]).trim() === 'Inactive > 6 month') ? (parseFloat(f[4])||0) : 0, colorFormating: 0 },
      { name: 'Never Active - Dmart',       calculo: (f) => (String(f[2]).trim() === 'Dmart' && String(f[3]).trim() === 'Never Active') ? (parseFloat(f[4])||0) : 0, colorFormating: 0 },

      // ==========================================
      // 2. PEYA METRICS
      // ==========================================
      { name: 'New Users - PeYa',           calculo: (f) => (String(f[2]).trim() === 'PeYa' && String(f[3]).trim() === 'New User') ? (parseFloat(f[4])||0) : 0, colorFormating: 1 },
      { name: 'M1 Return Users - PeYa',     calculo: (f) => (String(f[2]).trim() === 'PeYa' && String(f[3]).trim() === 'M1 Return') ? (parseFloat(f[4])||0) : 0, colorFormating: 1 },
      { name: 'Reorder Users - PeYa',       calculo: (f) => (String(f[2]).trim() === 'PeYa' && String(f[3]).trim() === 'Reorder') ? (parseFloat(f[4])||0) : 0, colorFormating: 1 },
      { name: 'Recurring Return - PeYa',    calculo: (f) => (String(f[2]).trim() === 'PeYa' && String(f[3]).trim() === 'Recurring Return') ? (parseFloat(f[4])||0) : 0, colorFormating: 1 },
      { name: 'Re-Activation Users - PeYa', calculo: (f) => (String(f[2]).trim() === 'PeYa' && String(f[3]).trim() === 'Re-Activation') ? (parseFloat(f[4])||0) : 0, colorFormating: 1 },
      
      { name: 'Churned Users - PeYa',       calculo: (f) => (String(f[2]).trim() === 'PeYa' && String(f[3]).trim() === 'Churned') ? (parseFloat(f[4])||0) : 0, colorFormating: 0 },
      { name: 'Inactive < 6m - PeYa',       calculo: (f) => (String(f[2]).trim() === 'PeYa' && String(f[3]).trim() === 'Inactive < 6 month') ? (parseFloat(f[4])||0) : 0, colorFormating: 0 },
      { name: 'Inactive > 6m - PeYa',       calculo: (f) => (String(f[2]).trim() === 'PeYa' && String(f[3]).trim() === 'Inactive > 6 month') ? (parseFloat(f[4])||0) : 0, colorFormating: 0 },
      { name: 'Never Active - PeYa',        calculo: (f) => (String(f[2]).trim() === 'PeYa' && String(f[3]).trim() === 'Never Active') ? (parseFloat(f[4])||0) : 0, colorFormating: 0 },

      // ====================================================================================
      // Total Churned Users calculado directamente en la hoja 4 - Users
      // ====================================================================================
      { 
        name: 'Total Churned Users', 
        calculo: (f) => String(f[3]).trim() === 'Churned' ? (parseFloat(f[4]) || 0) : 0, 
        colorFormating: 0 
      }
    ]
  }, { // 5 - Supply Chain
    nombreHoja: "5 - Supply Chain",
    indices: { month: 4, country: 2 },
    calcularLatam: false,
    metricas: [
      // --- 1. KPIs Principales de Inventario (DOH & WIS) ---
      // ACTUALIZADO: DOH ahora usa colorFormating: 1 según requerimiento
      { name: 'Days on hand (DOH)',      calculo: (f) => String(f[1]).trim() === 'DOH'    ? f[5] : 0, format: '0.0', colorFormating: 0 },
      { name: 'WIS %',                   calculo: (f) => String(f[1]).trim() === 'WIS'    ? f[5] : 0, format: '0.00%', colorFormating: 1 },
      { name: 'WIS UF %',                calculo: (f) => String(f[1]).trim() === 'WIS UF' ? f[5] : 0, format: '0.00%', colorFormating: 1 },
      { name: 'Velocity',                calculo: (f) => String(f[1]).trim() === 'Velocity' ? f[5] : 0, format: '0.00', colorFormating: 1 },

      // --- 2. Composición de Stock y Ventas ---
      { name: 'Active FM (DOH)',      calculo: (f) => String(f[1]).trim() === 'Active Fast Movers (DOH)'     ? f[5] : 0, format: '0.0', colorFormating: 0 },
      { name: 'Active ZM (DOH)',              calculo: (f) => String(f[1]).trim() === 'Active ZM (DOH)'    ? f[5] : 0, format: '0.0', colorFormating: 1 },
      { name: 'Stock ZM (Eur) %',              calculo: (f) => String(f[1]).trim() === '% Stock ZM (Eur)'   ? f[5] : 0, format: '0.00%', colorFormating: 0 },
      { name: 'Active SM (eur)',               calculo: (f) => String(f[1]).trim() === 'Active SM (eur)'              ? f[5] : 0, format: '#,##0.00', colorFormating: 1 },
      { name: 'AVG Stock (Eur)',               calculo: (f) => String(f[1]).trim() === 'AVG Stock (Eur)'              ? f[5] : 0, format: '#,##0.00', colorFormating: 0 },
      { name: 'F&UF Net Sales Participation',  calculo: (f) => String(f[1]).trim() === 'F&UF Net Sales Participation' ? f[5] : 0, format: '0.00%', colorFormating: 1 },

      // --- 3. Costos (W&DC) ---
      { name: 'Net W&DC Cost / GFV (Income St)', calculo: (f) => String(f[1]).trim() === 'Net W&DC Cost / GFV (Income St)' ? f[5] : 0, format: '0.00%', colorFormating: 0 },
      { name: 'Net W&DC Cost / CMT (Income St)', calculo: (f) => String(f[1]).trim() === 'Net W&DC Cost / CMT (Income St)' ? f[5] : 0, format: '0.00', colorFormating: 1 },
      { name: 'W&DC Cost / CMT (SC)',            calculo: (f) => String(f[1]).trim() === 'W&DC Cost / CMT (SC)'            ? f[5] : 0, format: '0.00', colorFormating: 0 },

      // --- 4. Pérdidas y Expiración ---
      { name: 'Expired',                 calculo: (f) => String(f[1]).trim() === 'Expired'                 ? f[5] : 0, format: '#,##0.00', colorFormating: 0 },
      { name: 'Loss & Damaged (DC/HUB)', calculo: (f) => String(f[1]).trim() === 'Loss & Damaged (DC/HUB)' ? f[5] : 0, format: '#,##0.00', colorFormating: 0 },
      { name: 'Expiration Impact',       calculo: (f) => String(f[1]).trim() === 'Expiration Impact'       ? f[5] : 0, format: '#,##0.00', colorFormating: 0 },
      { name: 'Expire Shrinkage (PVP)',  calculo: (f) => String(f[1]).trim() === 'Expire Shrinkage (PVP)'  ? f[5] : 0, format: '#,##0.00', colorFormating: 0 },

      // --- 5. Nivel de Servicio (WLT Issues) ---
      { name: 'WLT Lvl3 - Peya Issues %',      calculo: (f) => String(f[1]).trim() === 'WLT Lvl3 - Peya Issues'      ? f[5] : 0, format: '0.00%', colorFormating: 0 },
      { name: 'WLT Lvl3 - Supplier Issues %',  calculo: (f) => String(f[1]).trim() === 'WLT Lvl3 - Supplier Issues'  ? f[5] : 0, format: '0.00%', colorFormating: 0 },
      { name: 'WLT UF Lvl3 - Peya Issues %',   calculo: (f) => String(f[1]).trim() === 'WLT UF Lvl3 - Peya Issues'   ? f[5] : 0, format: '0.00%', colorFormating: 0 },
      { name: 'WLT UF Lvl3 - Supplier Issues %', calculo: (f) => String(f[1]).trim() === 'WLT UF Lvl3 - Supplier Issues' ? f[5] : 0, format: '0.00%', colorFormating: 0 },

      // --- 6. Otros Scores ---
      { name: 'Assortment Score',        calculo: (f) => String(f[1]).trim() === 'Assortment Score' ? f[5] : 0, format: '0.00', colorFormating: 1 }
    ]
  }, { // 6 - Active User Dmart - old
    nombreHoja: "6 - Active User Dmart - old", 
    indices: { month: 0, country: 1 },
    calcularLatam: true, 
    metricas: [
      { 
        name: 'New Users - Dmart',          
        calculo: (f) => String(f[2]).trim() === 'Adoption' ? (parseFloat(f[3])||0) : 0,
        colorFormating: 1 
      },
      { 
        name: 'M1 Return Users - Dmart',    
        calculo: (f) => String(f[2]).trim() === 'M1 Return' ? (parseFloat(f[3])||0) : 0,
        colorFormating: 1
      },
      { 
        name: 'Reorder Users - Dmart',      
        calculo: (f) => String(f[2]).trim() === 'Reorder' ? (parseFloat(f[3])||0) : 0,
        colorFormating: 1 
      },
      { 
        name: 'Recurring Return - Dmart',   
        calculo: (f) => String(f[2]).trim() === 'Recurring Return' ? (parseFloat(f[3])||0) : 0,
        colorFormating: 1 
      },
      { 
        name: 'Re-Activation Users - Dmart',
        calculo: (f) => String(f[2]).trim() === 'Reactivated' ? (parseFloat(f[3])||0) : 0,
        colorFormating: 1
      },
    ]
  }, { // 7 - Market Coverage (Nielsen)
    nombreHoja: "7 - Market Coverage",
    indices: { month: 0, country: 1 }, 
    calcularLatam: true, 
    metricas: [
      { 
        name: 'Nielsen Market Total EUR', 
        index: 2, 
        format: '#,##0.00', 
        colorFormating: 1 
      },
      { 
        name: 'Dmart Market Captured EUR', 
        index: 3, 
        format: '#,##0.00', 
        colorFormating: 1 
      },
      { 
        name: 'Nielsen Market Coverage %', 
        calculo: (f) => safeDiv(f[3], f[2]),
        usarComponentes: true,
        indicesLatam: [
          (f) => safeDiv(f[3], f[2]) * (parseFloat(f[6]) || 1e-9),
          (f) => parseFloat(f[6]) || 1e-9
        ], 
        calculoLatam: (c) => safeDiv(c[0], c[1]), 
        format: '0.00%', 
        colorFormating: 1 
      },
      { 
        name: 'Total Stock EUR', 
        index: 4, 
        format: '#,##0.00', 
        colorFormating: 1 
      },
      { 
        name: 'SZM Stock EUR', 
        index: 5, 
        format: '#,##0.00', 
        colorFormating: 1 
      },
      { 
        name: '% SM & ZM Stock Value', 
        calculo: (f) => safeDiv(f[5], f[4]),
        usarComponentes: true,
        indicesLatam: [5, 4], 
        calculoLatam: (c) => safeDiv(c[0], c[1]), 
        format: '0.00%', 
        colorFormating: 1 
      },
    ]
  }, { // 8 - Stacked deliveries
    nombreHoja: "8 - Stacked deliveries",
    indices: { month: 0, country: 1 }, 
    calcularLatam: true, 
    metricas: [
      { 
        name: 'Total orders Stacked Deliveries', 
        index: 8, 
        format: '#,##0',
        colorFormating: 1 
      },
      { 
        name: 'Avg. Delivery Time - Stack 1', 
        calculo: (f) => safeDiv(f[2], f[3]), 
        usarComponentes: true,
        indicesLatam: [2, 3], 
        calculoLatam: (c) => safeDiv(c[0], c[1]), 
        format: '0.00%',
        colorFormating: 0
      },
      { 
        name: 'Avg. Delivery Time - Stack 2', 
        calculo: (f) => safeDiv(f[5], f[6]), 
        usarComponentes: true,
        indicesLatam: [5, 6], 
        calculoLatam: (c) => safeDiv(c[0], c[1]), 
        format: '0.00%',
        colorFormating: 0
      }
    ]
  }, { // 9 - AQS
    nombreHoja: "9 - AQS",
    indices: { month: 0, country: 1 },
    calcularLatam: false,
    metricas: [
      { name: 'AQS', index: 10, format: '0.00', colorFormating: 1 },
      { name: 'Listed SKUs', index: 9, colorFormating: 1 },
      { name: 'Listed SKUs Achievement %', index: 2, format: '0.00%', colorFormating: 1 }, 
      { name: 'Design Compliance %', index: 3, format: '0.00%', colorFormating: 1 },
      { name: 'Efficiency %', index: 4, format: '0.00%', colorFormating: 1 },
      { name: 'UF Basket Penetration %', index: 5, format: '0.00%', colorFormating: 1 },
      { name: 'Newness %', index: 6, format: '0.00%', colorFormating: 1 },
      { name: 'Weighted Availability %', index: 7, format: '0.00%', colorFormating: 1 },
      { name: 'Discontinued Book Value %', index: 8, format: '0.00%', colorFormating: 1 }
    ]
  },{ // 11 - Rating
    nombreHoja: "11 - Rating",
    indices: { month: 1, country: 0 },
    calcularLatam: true,
    metricas: [
      { 
        name: 'Total Rating Score', 
        index: 3, 
        format: '#,##0', 
        colorFormating: 1 
      },
      { 
        name: 'Total Rated Orders', 
        index: 4, 
        format: '#,##0', 
        colorFormating: 1 
      },
      { 
        name: 'Rating', 
        calculo: (f) => safeDiv(f[3], f[4]), 
        usarComponentes: true, 
        indicesLatam: [3, 4], 
        calculoLatam: (c) => safeDiv(c[0], c[1]), 
        format: '0.00', 
        colorFormating: 1 
      }
    ]
  }, { // 12 - Planning Data
    nombreHoja: "12 - Planning Data", 
    indices: { month: 0, country: 1 }, 
    calcularLatam: true,
    metricas: [
      { name: 'Expire Shrinkage PVP', index: 2, colorFormating: 0 }, 
      { name: 'Precio Real Menos PVP', index: 3, colorFormating: 1 }, 
      { name: 'Nominator SM', index: 4, colorFormating: 1 }, 
      { name: 'Nominator ZM', index: 5, colorFormating: 1 }, 
      { name: 'Dominator', index: 6, colorFormating: 1 } 
    ]
  }, { // 13 - Fill In
    nombreHoja: "13 - Fill In", 
    indices: { month: 0, country: 1 }, 
    calcularLatam: true, 
    metricas: [
      { 
        name: 'Fill In %', 
        calculo: (f) => safeDiv(f[4], f[2]),
        usarComponentes: true,
        indicesLatam: [4, 2], 
        calculoLatam: (c) => safeDiv(c[0], c[1]),
        format: '0.00%',
        colorFormating: 1 
      },
      { 
        name: 'Instant Need %', 
        calculo: (f) => safeDiv(f[3], f[2]),
        usarComponentes: true,
        indicesLatam: [3, 2], 
        calculoLatam: (c) => safeDiv(c[0], c[1]),
        format: '0.00%',
        colorFormating: 1 
      },
      { 
        name: 'Stock Up %', 
        calculo: (f) => safeDiv(f[5], f[2]),
        usarComponentes: true,
        indicesLatam: [5, 2], 
        calculoLatam: (c) => safeDiv(c[0], c[1]),
        format: '0.00%',
        colorFormating: 1 
      } 
    ]
  }, { // 14 - UF Data
    nombreHoja: "14 - UF Data", 
    indices: { month: 0, country: 1 }, 
    calcularLatam: true, 
    metricas: [
      // ==========================================
      // 1. VOLUMEN DE USUARIOS
      // ==========================================
      { 
        name: 'Dmart MAUs - Ultra Fresh', 
        calculo: (f) => parseFloat(f[4]) || 0,
        colorFormating: 1 
      },
      { 
        name: 'New Users - UF - Dmart', 
        calculo: (f) => String(f[2]).trim() === 'Adoption' ? (parseFloat(f[4]) || 0) : 0,
        colorFormating: 1 
      },
      { 
        name: 'M1 Return Users - UF - Dmart', 
        calculo: (f) => String(f[2]).trim() === 'M1 Return' ? (parseFloat(f[4]) || 0) : 0,
        colorFormating: 1 
      },
      { 
        name: 'Re-Activation - UF - Dmart', 
        calculo: (f) => String(f[2]).trim() === 'Reactivated' ? (parseFloat(f[4]) || 0) : 0,
        colorFormating: 1 
      },
      { 
        name: 'Reorder - UF - Dmart', 
        calculo: (f) => String(f[2]).trim() === 'Reorder' ? (parseFloat(f[4]) || 0) : 0,
        colorFormating: 1 
      },
      { 
        name: 'Recurring Return - UF - Dmart', 
        calculo: (f) => String(f[2]).trim() === 'Recurring Return' ? (parseFloat(f[4]) || 0) : 0,
        colorFormating: 1 
      },

      // ==========================================
      // 2. MÉTRICAS PLUS +
      // ==========================================
      { name: 'Dmart MAUs - Plus - UF', calculo: (f) => parseFloat(f[11]) || 0, colorFormating: 1 },
      { 
        name: 'UF Penetration %  Users - Plus', 
        usarComponentes: true,
        indicesLatam: [11, 12], 
        calculoLatam: (c) => safeDiv(c[0], c[1]),
        format: '0.00%',
        colorFormating: 1
      },
      { name: 'Confirmed Orders - UF - Plus', calculo: (f) => parseFloat(f[10]) || 0, colorFormating: 1 },
      { 
        name: 'Confirmed Orders Share % - UF - Plus', 
        usarComponentes: true,
        indicesLatam: [10, 8], 
        calculoLatam: (c) => safeDiv(c[0], c[1]),
        format: '0.00%',
        colorFormating: 1
      },
      { 
        name: 'Frequency - UF orders - Plus Users', 
        usarComponentes: true,
        indicesLatam: [10, 11], 
        calculoLatam: (c) => safeDiv(c[0], c[1]),
        format: '0.00',
        colorFormating: 1
      },
      { 
        name: 'Basket Size - UF orders - Plus', 
        usarComponentes: true,
        indicesLatam: [14, 10], 
        calculoLatam: (c) => safeDiv(c[0], c[1]),
        format: '0.00',
        colorFormating: 1
      },
      { 
        name: 'AFV - UF - Plus  orders', 
        usarComponentes: true,
        indicesLatam: [16, 10], 
        calculoLatam: (c) => safeDiv(c[0], c[1]),
        format: '0.00',
        colorFormating: 1
      },

      // ==========================================
      // 3. FRECUENCIA Y ÓRDENES GENERALES
      // ==========================================
      { name: 'Total orders - Source UF', calculo: (f) => parseFloat(f[7]) || 0, colorFormating: 1 },
      { name: 'Confirmed Orders - UF', calculo: (f) => parseFloat(f[8]) || 0, colorFormating: 1 },
      { 
        name: 'Confirmed Orders share % - UF', 
        usarComponentes: true,
        indicesLatam: [8, 7], 
        calculoLatam: (c) => safeDiv(c[0], c[1]),
        format: '0.00%',
        colorFormating: 1
      },
      { 
        name: 'Frequency - UF', 
        usarComponentes: true,
        indicesLatam: [8, 4], 
        calculoLatam: (c) => safeDiv(c[0], c[1]),
        format: '0.00',
        colorFormating: 1
      },

      // ==========================================
      // 4. UNIDADES, VENTAS Y BÁSKET
      // ==========================================
      { name: 'Units sold - UF', calculo: (f) => parseFloat(f[22]) || 0, colorFormating: 1 },
      { name: 'Units Sold  in UF Orders', calculo: (f) => parseFloat(f[23]) || 0, colorFormating: 1 },
      { name: 'Net Sales - UF', calculo: (f) => parseFloat(f[17]) || 0, colorFormating: 1 },
      { name: 'Net Sales - UF Baskets', calculo: (f) => parseFloat(f[18]) || 0, colorFormating: 1 },
      { 
        name: 'Net Sales Share % - UF', 
        usarComponentes: true,
        indicesLatam: [17, 18], 
        calculoLatam: (c) => safeDiv(c[0], c[1]),
        format: '0.00%',
        colorFormating: 1
      },
      { 
        name: 'AFV - UF', 
        usarComponentes: true,
        indicesLatam: [18, 8], 
        calculoLatam: (c) => safeDiv(c[0], c[1]),
        format: '0.00',
        colorFormating: 1
      },

      // ==========================================
      // 5. RENTABILIDAD Y DESCUENTOS
      // ==========================================
      { name: 'Front Margin - UF', calculo: (f) => parseFloat(f[27]) || 0, colorFormating: 1 },
      { 
        name: 'Theoric Margin % - UF', 
        usarComponentes: true,
        indicesLatam: [26, 25], 
        calculoLatam: (c) => safeDiv(c[0], c[1]),
        format: '0.00%',
        colorFormating: 1
      },
      { 
        name: 'Front Margin % - UF', 
        usarComponentes: true,
        indicesLatam: [27, 17], 
        calculoLatam: (c) => safeDiv(c[0], c[1]),
        format: '0.00%',
        colorFormating: 1
      },
      { 
        name: 'Discounts % - UF', 
        usarComponentes: true,
        indicesLatam: [29, 17], 
        calculoLatam: (c) => safeDiv(c[0], c[1]),
        format: '0.00%',
        colorFormating: 0
      }
    ]
  }, { // 15 - MAUs Coverage
    nombreHoja: "15 - MAUs Coverage", 
    indices: { month: 0, country: 1 }, 
    calcularLatam: true, 
    metricas: [
      // --- VOLÚMENES BASE ---
      { name: 'Covered MAUs', index: 3, colorFormating: 1 },
      
      // --- RATIOS CALCULADOS ---
      { 
        name: 'Covered MAUs %', 
        calculo: (f) => safeDiv(f[3], f[2]),
        usarComponentes: true,
        indicesLatam: [3, 2], 
        calculoLatam: (c) => safeDiv(c[0], c[1]),
        format: '0.00%',
        colorFormating: 1 
      }
    ]
  }, { // 16 - Analitycs - Finance
    nombreHoja: "16 - Analitycs",
    indices: { month: 0, country: 3 }, 
    filtroFila: (f) => String(f[5]).trim() === "Actual", 
    calcularLatam: true, 
    metricas: [
      // --- MÉTRICAS BASE (Ordenadas por index) ---
      { name: 'Net Sales', index: 8, format: '#,##0.00', colorFormating: 1 }, 
      { name: 'Back Margin', index: 10, format: '#,##0.00', colorFormating: 1 }, 
      { name: 'W&DC Net Cost', index: 11, format: '#,##0.00', colorFormating: 0 }, 
      { name: 'Shrinkage', index: 13, format: '#,##0.00', colorFormating: 0 }, 
      { name: 'Packaging Cost', index: 14, format: '#,##0.00', colorFormating: 0 }, 
      { name: 'Labor Cost', index: 17, format: '#,##0.00', colorFormating: 0 }, 
      { name: 'NMR', index: 20, format: '#,##0.00', colorFormating: 1 }, 
      { name: 'Revenue Fee', index: 26, format: '#,##0.00', colorFormating: 1 }, 
      { name: 'Delivery Cost', index: 27, format: '#,##0.00', colorFormating: 0 }, 
      { name: 'Voucher P&L Amount', index: 29, format: '#,##0.00', colorFormating: 0 }, 
      { name: 'Front Margin', index: 36, format: '#,##0.00', colorFormating: 1 }, 
      { name: 'Retail GP', index: 40, format: '#,##0.00', colorFormating: 1 }, 
      { name: 'Retail EBITDA', index: 44, format: '#,##0.00', colorFormating: 1 }, 
      { // --- EBITDA
        name: 'EBITDA', 
        calculo: (f) => parseFloat(String(f[47]).replace(/,/g, '')) || 0,
        indicesLatam: [53], 
        calculoLatam: c => c[0], 
        format: '#,##0.00',
        colorFormating: 1
      },
      { name: 'Warehouse Allowance', index: 58, format: '#,##0.00', colorFormating: 1 }, 
      { name: 'W&DC Cost', index: 59, format: '#,##0.00', colorFormating: 0 }, 

      // --- PORCENTAJES Y CALCULADOS (Ordenados por index de numerador/componente principal) ---
      { name: 'Back Margin %', calculo: (f) => safeDiv(f[10], f[8]), usarComponentes: true, indicesLatam: [10, 8], calculoLatam: c=>safeDiv(c[0],c[1]), format: '0.00%', colorFormating: 1 },
      { name: 'W&DC Net Cost %', calculo: (f) => safeDiv(f[11], f[8]), usarComponentes: true, indicesLatam: [11, 8], calculoLatam: c=>safeDiv(c[0],c[1]), format: '0.00%', colorFormating: 1 },
      { name: 'Shrinkage %', calculo: (f) => safeDiv(f[13], f[8]), usarComponentes: true, indicesLatam: [13, 8], calculoLatam: c=>safeDiv(c[0],c[1]), format: '0.00%', colorFormating: 0 },
      { name: 'Packaging Cost %', calculo: (f) => safeDiv(f[14], f[8]), usarComponentes: true, indicesLatam: [14, 8], calculoLatam: c=>safeDiv(c[0],c[1]), format: '0.00%', colorFormating: 0 },
      { name: 'Labor Cost %', calculo: (f) => safeDiv(f[17], f[8]), usarComponentes: true, indicesLatam: [17, 8], calculoLatam: c=>safeDiv(c[0],c[1]), format: '0.00%', colorFormating: 0 },
      { name: 'NMR %', calculo: (f) => safeDiv(f[20], f[8]), usarComponentes: true, indicesLatam: [20, 8], calculoLatam: c=>safeDiv(c[0],c[1]), format: '0.00%', colorFormating: 1 },
      { name: 'Revenue Fee %', calculo: (f) => safeDiv(f[26], f[8]), usarComponentes: true, indicesLatam: [26, 8], calculoLatam: c=>safeDiv(c[0],c[1]), format: '0.00%', colorFormating: 1 },
      { name: 'Delivery Cost %', calculo: (f) => safeDiv(f[27], f[8]), usarComponentes: true, indicesLatam: [27, 8], calculoLatam: c=>safeDiv(c[0],c[1]), format: '0.00%', colorFormating: 0 },
      { name: 'Voucher P&L Amount %', calculo: (f) => safeDiv(f[29], f[8]), usarComponentes: true, indicesLatam: [29, 8], calculoLatam: c=>safeDiv(c[0],c[1]), format: '0.00%', colorFormating: 0 },
      { name: 'Front Margin %', calculo: (f) => safeDiv(f[36], f[8]), usarComponentes: true, indicesLatam: [36, 8], calculoLatam: c=>safeDiv(c[0],c[1]), format: '0.00%', colorFormating: 1 },
      
      { 
        name: 'Commercial Margin', 
        calculo: (f) => (parseFloat(f[36])||0) + (parseFloat(f[10])||0),
        usarComponentes: true,
        indicesLatam: [36, 10], 
        calculoLatam: (c) => c[0] + c[1], 
        format: '#,##0.00',
        colorFormating: 1
      },
      { 
        name: 'Commercial Margin %', 
        calculo: (f) => safeDiv( (parseFloat(f[36])||0) + (parseFloat(f[10])||0), f[8]),
        usarComponentes: true,
        indicesLatam: [36, 10, 8], 
        calculoLatam: (c) => safeDiv(c[0] + c[1], c[2]),
        format: '0.00%',
        colorFormating: 1
      },

      { name: 'Retail GP %', calculo: (f) => safeDiv(f[40], f[8]), usarComponentes: true, indicesLatam: [40, 8], calculoLatam: c=>safeDiv(c[0],c[1]), format: '0.00%', colorFormating: 1 },
      { name: 'Retail EBITDA %', calculo: (f) => safeDiv(f[44], f[8]), usarComponentes: true, indicesLatam: [44, 8], calculoLatam: c=>safeDiv(c[0],c[1]), format: '0.00%', colorFormating: 1 },
      { 
        name: 'EBITDA %', 
        calculo: (f) => safeDiv(f[47], f[8]), 
        usarComponentes: true, 
        indicesLatam: [53, 8], 
        calculoLatam: (c) => safeDiv(c[0], c[1]), 
        format: '0.00%',
        colorFormating: 1 
      },
      { name: 'Warehouse Allowance %', calculo: (f) => safeDiv(f[58], f[8]), usarComponentes: true, indicesLatam: [58, 8], calculoLatam: c=>safeDiv(c[0],c[1]), format: '0.00%', colorFormating: 1 },
      { name: 'W&DC Cost %', calculo: (f) => safeDiv(f[59], f[8]), usarComponentes: true, indicesLatam: [59, 8], calculoLatam: c=>safeDiv(c[0],c[1]), format: '0.00%', colorFormating: 0 },

      { 
        name: 'Total Margin', 
        calculo: (f) => (parseFloat(f[36])||0) + (parseFloat(f[10])||0) + (parseFloat(f[13])||0) + (parseFloat(f[20])||0) + (parseFloat(f[11])||0),
        usarComponentes: true,
        indicesLatam: [36, 10, 13, 20, 11],
        calculoLatam: (c) => c[0]+c[1]+c[2]+c[3]+c[4],
        format: '#,##0.00',
        colorFormating: 1
      },
      { 
        name: 'Total Margin %', 
        calculo: (f) => safeDiv( (parseFloat(f[36])||0) + (parseFloat(f[10])||0) + (parseFloat(f[13])||0) + (parseFloat(f[20])||0) + (parseFloat(f[11])||0), f[8]),
        usarComponentes: true,
        indicesLatam: [36, 10, 13, 20, 11, 8], 
        calculoLatam: (c) => safeDiv(c[0]+c[1]+c[2]+c[3]+c[4], c[5]),
        format: '0.00%',
        colorFormating: 1
      }
    ]
  }, { // 17 - PQS
    nombreHoja: "17 - PQS",
    indices: { month: 0, country: 1 }, 
    calcularLatam: false, 
    metricas: [
      { 
        name: 'Promo-Contribution %', 
        calculo: (f) => f[5] === "" ? 0 : (Number(f[5]) || 0), 
        format: '0.00%',
        colorFormating: 1 
      },
      { 
        name: 'Gross-Basket Discount %', 
        calculo: (f) => f[6] === "" ? 0 : (Number(f[6]) || 0), 
        format: '0.00%',
        colorFormating: 1 
      },
      { 
        name: 'Promo Attractiveness', 
        calculo: (f) => f[7] === "" ? 0 : (Number(f[7]) || 0), 
        format: '0.00',
        colorFormating: 1 
      },
      { 
        name: 'Weighted Availability %', 
        calculo: (f) => f[8] === "" ? 0 : (Number(f[8]) || 0), 
        format: '0.00%',
        colorFormating: 1 
      },
      { 
        name: 'Share of Effective Promotions %', 
        calculo: (f) => f[9] === "" ? 0 : (Number(f[9]) || 0), 
        format: '0.00%',
        colorFormating: 1 
      },
      { 
        name: 'Gross GPV Uplift %', 
        calculo: (f) => f[10] === "" ? 0 : (Number(f[10]) || 0), 
        format: '0.00%',
        colorFormating: 1 
      }
    ]
  }, { // 18 - Open Time
      nombreHoja: "18 - Open Time",
      indices: { month: 0, country: 1 }, 
      calcularLatam: false, 
      metricas: [
          { 
        name: 'Weighted Open time %', 
        index: 5,           
        format: '0.00%',     
        colorFormating: 1 
      }
      ]
  }, { // 19 - Promo
    nombreHoja: "19 - Promo",
    indices: { month: 0, country: 1 }, 
    calcularLatam: true,
    metricas: [
      { // Promo Contribution %
        name: 'Promo Contribution %', 
        calculo: (f) => safeDiv(f[3], f[4]),
        usarComponentes: true,
        indicesLatam: [3, 4], 
        calculoLatam: (c) => safeDiv(c[0], c[1]),
        format: '0.00%',
        colorFormating: 1 
      },
      { // Gross Basket Discount %
        name: 'Gross Basket Discount %', 
        calculo: (f) => safeDiv(f[8], f[4]),
        usarComponentes: true,
        indicesLatam: [8, 4], 
        calculoLatam: (c) => safeDiv(c[0], c[1]),
        format: '0.00%',
        colorFormating: 1 
      },
      { // Units w Discounts %
        name: 'Units w Discounts %', 
        calculo: (f) => safeDiv(f[7], f[6]),
        usarComponentes: true,
        indicesLatam: [7, 6], 
        calculoLatam: (c) => safeDiv(c[0], c[1]),
        format: '0.00%',
        colorFormating: 0 
      },
    ]
  }, { // 20 - Price Index
    nombreHoja: "20 - Price Index",
    indices: { month: 7, country: 0 }, 
    calcularLatam: true,
    metricas: [
      { 
        name: 'KVI Price Index', 
        index: 4,           
        format: '0.00',     
        averageLatam: true,
        colorFormating: 0 
      }
    ]
  }, { // 21 - Double Ya Data
    nombreHoja: "21 - Double Ya Data", 
    indices: { month: 0, country: 1 }, 
    calcularLatam: true, 
    metricas: [
      // --- SCOPE: DOUBLE YA (VOLUMEN) ---
      { name: 'Dmart MAUs - Double Ya', calculo: (f) => String(f[2]).trim() === 'Double Ya' ? (parseFloat(f[3]) || 0) : 0, colorFormating: 1 },
      { name: 'New Users - Double Ya', calculo: (f) => String(f[2]).trim() === 'Double Ya' ? (parseFloat(f[4]) || 0) : 0, colorFormating: 1 },
      { name: 'Confirmed Orders - Double Ya', calculo: (f) => String(f[2]).trim() === 'Double Ya' ? (parseFloat(f[5]) || 0) : 0, colorFormating: 1 },
      { name: 'Units sold - Double Ya', calculo: (f) => String(f[2]).trim() === 'Double Ya' ? (parseFloat(f[6]) || 0) : 0, colorFormating: 1 },
      { name: 'Net Sales - Double Ya', calculo: (f) => String(f[2]).trim() === 'Double Ya' ? (parseFloat(f[7]) || 0) : 0, colorFormating: 1 },
      { name: 'COGS - Double Ya', calculo: (f) => String(f[2]).trim() === 'Double Ya' ? (parseFloat(f[8]) || 0) : 0, colorFormating: 1 },
      { name: 'Sessions - Double Ya', calculo: (f) => String(f[2]).trim() === 'Double Ya' ? (parseFloat(f[9]) || 0) : 0, colorFormating: 1 },
      { name: 'Transactions - Double Ya', calculo: (f) => String(f[2]).trim() === 'Double Ya' ? (parseFloat(f[10]) || 0) : 0, colorFormating: 1 },
      { name: 'M1 Return Users - Double Ya', calculo: (f) => String(f[2]).trim() === 'Double Ya' ? (parseFloat(f[11]) || 0) : 0, colorFormating: 1 },

      // --- SCOPE: DOUBLE YA (RATIOS) ---
      { 
        name: 'M1 Return Users Share % - Double Ya', 
        calculo: (f) => String(f[2]).trim() === 'Double Ya' ? safeDiv(f[11], f[4]) : 0,
        usarComponentes: true,
        indicesLatam: [
          f => String(f[2]).trim() === 'Double Ya' ? (parseFloat(f[11])||0) : 0, 
          f => String(f[2]).trim() === 'Double Ya' ? (parseFloat(f[4])||0) : 0
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), format: '0.00%', colorFormating: 1 
      },
      { 
        name: 'AFV - Double Ya', 
        calculo: (f) => String(f[2]).trim() === 'Double Ya' ? safeDiv(f[7], f[5]) : 0,
        usarComponentes: true,
        indicesLatam: [
          f => String(f[2]).trim() === 'Double Ya' ? (parseFloat(f[7])||0) : 0, 
          f => String(f[2]).trim() === 'Double Ya' ? (parseFloat(f[5])||0) : 0
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), format: '0.00', colorFormating: 1 
      },
      { 
        name: 'CVR3 % - Double Ya', 
        calculo: (f) => String(f[2]).trim() === 'Double Ya' ? safeDiv(f[10], f[9]) : 0,
        usarComponentes: true,
        indicesLatam: [
          f => String(f[2]).trim() === 'Double Ya' ? (parseFloat(f[10])||0) : 0, 
          f => String(f[2]).trim() === 'Double Ya' ? (parseFloat(f[9])||0) : 0
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), format: '0.00%', colorFormating: 1 
      },

      // --- SCOPE: NO DOUBLE YA (VOLUMEN) ---
      { name: 'Confirmed Orders - non Double Ya', calculo: (f) => String(f[2]).trim() === 'No Double Ya' ? (parseFloat(f[5]) || 0) : 0, colorFormating: 1 },
      { name: 'Net Sales - non Double Ya', calculo: (f) => String(f[2]).trim() === 'No Double Ya' ? (parseFloat(f[7]) || 0) : 0, colorFormating: 1 },
      { name: 'Units sold - non Double Ya', calculo: (f) => String(f[2]).trim() === 'No Double Ya' ? (parseFloat(f[6]) || 0) : 0, colorFormating: 1 },
      { name: 'Sessions - non Double Ya', calculo: (f) => String(f[2]).trim() === 'No Double Ya' ? (parseFloat(f[9]) || 0) : 0, colorFormating: 1 },
      { name: 'Transactions - non Double Ya', calculo: (f) => String(f[2]).trim() === 'No Double Ya' ? (parseFloat(f[10]) || 0) : 0, colorFormating: 1 },
      { name: 'Dmart MAUs - non Double Ya', calculo: (f) => String(f[2]).trim() === 'No Double Ya' ? (parseFloat(f[3]) || 0) : 0, colorFormating: 1 },
      { name: 'New Users - non Double Ya', calculo: (f) => String(f[2]).trim() === 'No Double Ya' ? (parseFloat(f[4]) || 0) : 0, colorFormating: 1 },
      { name: 'M1 Return Users - non Double Ya', calculo: (f) => String(f[2]).trim() === 'No Double Ya' ? (parseFloat(f[11]) || 0) : 0, colorFormating: 1 },

      // --- SCOPE: NO DOUBLE YA (RATIOS) ---
      { 
        name: 'CVR3 % - non Double Ya', 
        calculo: (f) => String(f[2]).trim() === 'No Double Ya' ? safeDiv(f[10], f[9]) : 0,
        usarComponentes: true,
        indicesLatam: [
          f => String(f[2]).trim() === 'No Double Ya' ? (parseFloat(f[10])||0) : 0, 
          f => String(f[2]).trim() === 'No Double Ya' ? (parseFloat(f[9])||0) : 0
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), format: '0.00%', colorFormating: 1 
      },
      { 
        name: 'AFV - non Double Ya', 
        calculo: (f) => String(f[2]).trim() === 'No Double Ya' ? safeDiv(f[7], f[5]) : 0,
        usarComponentes: true,
        indicesLatam: [
          f => String(f[2]).trim() === 'No Double Ya' ? (parseFloat(f[7])||0) : 0, 
          f => String(f[2]).trim() === 'No Double Ya' ? (parseFloat(f[5])||0) : 0
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), format: '0.00', colorFormating: 1 
      },

      // ====================================================================================
      // NUEVO: Métricas Double Ya calculadas directamente en su sección CONFIG_GD_METRICAS
      // ====================================================================================
      { 
        name: 'Basket Size - Double Ya', 
        calculo: (f) => String(f[2]).trim() === 'Double Ya' ? safeDiv(f[6], f[5]) : 0,
        usarComponentes: true,
        indicesLatam: [
          f => String(f[2]).trim() === 'Double Ya' ? (parseFloat(f[6])||0) : 0, 
          f => String(f[2]).trim() === 'Double Ya' ? (parseFloat(f[5])||0) : 0
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), 
        format: '0.00', 
        colorFormating: 1 
      },
      { 
        name: 'Basket Size - non Double Ya', 
        calculo: (f) => String(f[2]).trim() === 'No Double Ya' ? safeDiv(f[6], f[5]) : 0,
        usarComponentes: true,
        indicesLatam: [
          f => String(f[2]).trim() === 'No Double Ya' ? (parseFloat(f[6])||0) : 0, 
          f => String(f[2]).trim() === 'No Double Ya' ? (parseFloat(f[5])||0) : 0
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), 
        format: '0.00', 
        colorFormating: 1 
      },
      { 
        name: 'Frequency - Double Ya', 
        calculo: (f) => String(f[2]).trim() === 'Double Ya' ? safeDiv(f[5], f[3]) : 0,
        usarComponentes: true,
        indicesLatam: [
          f => String(f[2]).trim() === 'Double Ya' ? (parseFloat(f[5])||0) : 0, 
          f => String(f[2]).trim() === 'Double Ya' ? (parseFloat(f[3])||0) : 0
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), 
        format: '0.00', 
        colorFormating: 1 
      },
      { 
        name: 'Frequency - non Double Ya', 
        calculo: (f) => String(f[2]).trim() === 'No Double Ya' ? safeDiv(f[5], f[3]) : 0,
        usarComponentes: true,
        indicesLatam: [
          f => String(f[2]).trim() === 'No Double Ya' ? (parseFloat(f[5])||0) : 0, 
          f => String(f[2]).trim() === 'No Double Ya' ? (parseFloat(f[3])||0) : 0
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), 
        format: '0.00', 
        colorFormating: 1 
      }
    ]
  }, { // 22 - Churned Users
    nombreHoja: "22 - Churned Users",
    indices: { month: 0, country: 1 }, 
    calcularLatam: true, 
    metricas: [
      // 1. TOTAL DMART MAUs
      { 
        name: 'Retention Rate % - Dmart MAUs', 
        usarComponentes: true, 
        indicesLatam: [
          f => parseFloat(f[4]) || 0, 
          f => parseFloat(f[3]) || 0  
        ],
        calculoLatam: c => c[1] !== 0 ? 1 - (c[0] / c[1]) : 0,
        format: '0.00%',
        colorFormating: 1 
      },

      // 2. NEW USERS
      { 
        name: 'Retention Rate - New Users %- Dmart', 
        usarComponentes: true, 
        indicesLatam: [
          f => String(f[2]).trim() === 'Adoption' ? (parseFloat(f[4]) || 0) : 0, 
          f => String(f[2]).trim() === 'Adoption' ? (parseFloat(f[3]) || 0) : 0
        ],
        calculoLatam: c => c[1] !== 0 ? 1 - (c[0] / c[1]) : 0,
        format: '0.00%',
        colorFormating: 1 
      },

      // 3. M1 RETURN USERS
      { 
        name: 'Retention Rate - M1 Return Users % - Dmart', 
        usarComponentes: true, 
        indicesLatam: [
          f => String(f[2]).trim() === 'M1 Return' ? (parseFloat(f[4]) || 0) : 0, 
          f => String(f[2]).trim() === 'M1 Return' ? (parseFloat(f[3]) || 0) : 0
        ],
        calculoLatam: c => c[1] !== 0 ? 1 - (c[0] / c[1]) : 0,
        format: '0.00%',
        colorFormating: 1 
      },

      // 4. REORDER USERS
      { 
        name: 'Retention Rate - Reorder Users % - Dmart', 
        usarComponentes: true, 
        indicesLatam: [
          f => String(f[2]).trim() === 'Reorder' ? (parseFloat(f[4]) || 0) : 0, 
          f => String(f[2]).trim() === 'Reorder' ? (parseFloat(f[3]) || 0) : 0
        ],
        calculoLatam: c => c[1] !== 0 ? 1 - (c[0] / c[1]) : 0,
        format: '0.00%',
        colorFormating: 1 
      },

      // 5. RECURRING RETURN
      { 
        name: 'Retention Rate - Recurring Return % - Dmart', 
        usarComponentes: true, 
        indicesLatam: [
          f => String(f[2]).trim() === 'Recurring Return' ? (parseFloat(f[4]) || 0) : 0, 
          f => String(f[2]).trim() === 'Recurring Return' ? (parseFloat(f[3]) || 0) : 0
        ],
        calculoLatam: c => c[1] !== 0 ? 1 - (c[0] / c[1]) : 0,
        format: '0.00%',
        colorFormating: 1 
      },

      // 6. RE-ACTIVATION USERS
      { 
        name: 'Retention Rate - Re-Activation Users % - Dmart', 
        usarComponentes: true, 
        indicesLatam: [
          f => (String(f[2]).trim() === 'Reactivated' || String(f[2]).trim() === 'Re-Activation') ? (parseFloat(f[4]) || 0) : 0, 
          f => (String(f[2]).trim() === 'Reactivated' || String(f[2]).trim() === 'Re-Activation') ? (parseFloat(f[3]) || 0) : 0
        ],
        calculoLatam: c => c[1] !== 0 ? 1 - (c[0] / c[1]) : 0,
        format: '0.00%',
        colorFormating: 1 
      }
    ]
  }, { // 23 - Análisis de Retención Ventana 60 Días (Mes 2 y 3)
    nombreHoja: "23 - New user>60",
    indices: { month: 0, country: 1 }, 
    calcularLatam: true, 
    metricas: [
      { 
        name: 'Return Users (M2 or M3) - PeYa', 
        calculo: (f) => parseFloat(f[3] || 0),
        format: '#,##0', colorFormating: 1 
      },
      { 
        name: 'Return Users (M2 or M3) - Dmart', 
        calculo: (f) => parseFloat(f[6] || 0),
        format: '#,##0', colorFormating: 1 
      }
    ]
  }, { // 24 - Users details
    nombreHoja: "24 - Users details", 
    indices: { month: 0, country: 1 }, 
    calcularLatam: true, 
    metricas: [
      // ==========================================
      // 1. NEW USERS
      // ==========================================
      { 
        name: 'Confirmed Orders - New Users - Dmart', 
        calculo: (f) => ['New User', 'Adoption'].includes(String(f[2]).trim()) ? (parseFloat(f[6]) || 0) : 0, 
        format: '#,##0', colorFormating: 1 
      },
      { 
        name: 'Confirmed Orders - UF - New Users - Dmart', 
        calculo: (f) => ['New User', 'Adoption'].includes(String(f[2]).trim()) ? (parseFloat(f[10]) || 0) : 0, 
        format: '#,##0', colorFormating: 1 
      },
      { 
        name: 'Net Sales - New Users - Dmart', 
        calculo: (f) => ['New User', 'Adoption'].includes(String(f[2]).trim()) ? (parseFloat(f[4]) || 0) : 0, 
        format: '#,##0.00', colorFormating: 1 
      },
      { 
        name: 'Basket Size - New Users - Dmart', 
        calculo: (f) => ['New User', 'Adoption'].includes(String(f[2]).trim()) ? (parseFloat(f[7]) || 0) : 0, 
        usarComponentes: true, 
        indicesLatam: [
          (f) => ['New User', 'Adoption'].includes(String(f[2]).trim()) ? (parseFloat(f[5]) || 0) : 0, 
          (f) => ['New User', 'Adoption'].includes(String(f[2]).trim()) ? (parseFloat(f[6]) || 0) : 0  
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), format: '0.00', colorFormating: 1 
      },
      { 
        name: 'AFV - New Users - Dmart', 
        calculo: (f) => ['New User', 'Adoption'].includes(String(f[2]).trim()) ? (parseFloat(f[9]) || 0) : 0, 
        usarComponentes: true, 
        indicesLatam: [
          (f) => ['New User', 'Adoption'].includes(String(f[2]).trim()) ? (parseFloat(f[4]) || 0) : 0, 
          (f) => ['New User', 'Adoption'].includes(String(f[2]).trim()) ? (parseFloat(f[6]) || 0) : 0  
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), format: '0.00', colorFormating: 1 
      },
      { 
        name: 'Frequency - New Users - Dmart', 
        calculo: (f) => ['New User', 'Adoption'].includes(String(f[2]).trim()) ? (parseFloat(f[8]) || 0) : 0, 
        usarComponentes: true, 
        indicesLatam: [
          (f) => ['New User', 'Adoption'].includes(String(f[2]).trim()) ? (parseFloat(f[6]) || 0) : 0, 
          (f) => ['New User', 'Adoption'].includes(String(f[2]).trim()) ? (parseFloat(f[3]) || 0) : 0  
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), format: '0.00', colorFormating: 1 
      },
      { 
        name: 'Monthly Customer Units - New Users - Dmart', 
        calculo: (f) => ['New User', 'Adoption'].includes(String(f[2]).trim()) ? safeDiv(f[5], f[3]) : 0, 
        usarComponentes: true, 
        indicesLatam: [
          (f) => ['New User', 'Adoption'].includes(String(f[2]).trim()) ? (parseFloat(f[5]) || 0) : 0, 
          (f) => ['New User', 'Adoption'].includes(String(f[2]).trim()) ? (parseFloat(f[3]) || 0) : 0  
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), format: '0.00', colorFormating: 1 
      },
      { 
        name: 'Units Sold - New Users - Dmart', 
        calculo: (f) => ['New User', 'Adoption'].includes(String(f[2]).trim()) ? (parseFloat(f[5]) || 0) : 0, 
        format: '#,##0', colorFormating: 1 
      },
      { 
        name: 'UF User Penetration % - New Users - Dmart', 
        calculo: (f) => ['New User', 'Adoption'].includes(String(f[2]).trim()) ? safeDiv(f[11], f[3]) : 0, 
        usarComponentes: true, 
        indicesLatam: [
          (f) => ['New User', 'Adoption'].includes(String(f[2]).trim()) ? (parseFloat(f[11]) || 0) : 0, 
          (f) => ['New User', 'Adoption'].includes(String(f[2]).trim()) ? (parseFloat(f[3]) || 0) : 0   
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), format: '0.00%', colorFormating: 1 
      },
      { 
        name: 'AVG Ternure - New Users - Dmart', 
        calculo: (f) => ['New User', 'Adoption'].includes(String(f[2]).trim()) ? (parseFloat(f[12]) || 0) : 0, 
        usarComponentes: true, 
        indicesLatam: [
          (f) => ['New User', 'Adoption'].includes(String(f[2]).trim()) ? ((parseFloat(f[12]) || 0) * (parseFloat(f[3]) || 0)) : 0, 
          (f) => ['New User', 'Adoption'].includes(String(f[2]).trim()) ? (parseFloat(f[3]) || 0) : 0  
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), format: '0.00', colorFormating: 1 
      },

      // ==========================================
      // 2. M1 RETURN USERS
      // ==========================================
      { 
        name: 'Confirmed Orders - M1 Return Users - Dmart', 
        calculo: (f) => String(f[2]).trim() === 'M1 Return' ? (parseFloat(f[6]) || 0) : 0, 
        format: '#,##0', colorFormating: 1 
      },
      { 
        name: 'Confirmed Orders - UF - M1 Return Users - Dmart', 
        calculo: (f) => String(f[2]).trim() === 'M1 Return' ? (parseFloat(f[10]) || 0) : 0, 
        format: '#,##0', colorFormating: 1 
      },
      { 
        name: 'Net Sales - M1 Return Users - Dmart', 
        calculo: (f) => String(f[2]).trim() === 'M1 Return' ? (parseFloat(f[4]) || 0) : 0, 
        format: '#,##0.00', colorFormating: 1 
      },
      { 
        name: 'Basket Size - M1 Return Users - Dmart', 
        calculo: (f) => String(f[2]).trim() === 'M1 Return' ? (parseFloat(f[7]) || 0) : 0, 
        usarComponentes: true, 
        indicesLatam: [
          (f) => String(f[2]).trim() === 'M1 Return' ? (parseFloat(f[5]) || 0) : 0, 
          (f) => String(f[2]).trim() === 'M1 Return' ? (parseFloat(f[6]) || 0) : 0  
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), format: '0.00', colorFormating: 1 
      },
      { 
        name: 'AFV - M1 Return Users - Dmart', 
        calculo: (f) => String(f[2]).trim() === 'M1 Return' ? (parseFloat(f[9]) || 0) : 0, 
        usarComponentes: true, 
        indicesLatam: [
          (f) => String(f[2]).trim() === 'M1 Return' ? (parseFloat(f[4]) || 0) : 0, 
          (f) => String(f[2]).trim() === 'M1 Return' ? (parseFloat(f[6]) || 0) : 0  
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), format: '0.00', colorFormating: 1 
      },
      { 
        name: 'Frequency - M1 Return Users - Dmart', 
        calculo: (f) => String(f[2]).trim() === 'M1 Return' ? (parseFloat(f[8]) || 0) : 0, 
        usarComponentes: true, 
        indicesLatam: [
          (f) => String(f[2]).trim() === 'M1 Return' ? (parseFloat(f[6]) || 0) : 0, 
          (f) => String(f[2]).trim() === 'M1 Return' ? (parseFloat(f[3]) || 0) : 0  
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), format: '0.00', colorFormating: 1 
      },
      { 
        name: 'Monthly Customer Units - M1 Return Users - Dmart', 
        calculo: (f) => String(f[2]).trim() === 'M1 Return' ? safeDiv(f[5], f[3]) : 0, 
        usarComponentes: true, 
        indicesLatam: [
          (f) => String(f[2]).trim() === 'M1 Return' ? (parseFloat(f[5]) || 0) : 0, 
          (f) => String(f[2]).trim() === 'M1 Return' ? (parseFloat(f[3]) || 0) : 0  
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), format: '0.00', colorFormating: 1 
      },
      { 
        name: 'Units Sold - M1 Return Users - Dmart', 
        calculo: (f) => String(f[2]).trim() === 'M1 Return' ? (parseFloat(f[5]) || 0) : 0, 
        format: '#,##0', colorFormating: 1 
      },
      { 
        name: 'UF User Penetration % - M1 Return Users - Dmart', 
        calculo: (f) => String(f[2]).trim() === 'M1 Return' ? safeDiv(f[11], f[3]) : 0, 
        usarComponentes: true, 
        indicesLatam: [
          (f) => String(f[2]).trim() === 'M1 Return' ? (parseFloat(f[11]) || 0) : 0, 
          (f) => String(f[2]).trim() === 'M1 Return' ? (parseFloat(f[3]) || 0) : 0   
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), format: '0.00%', colorFormating: 1 
      },
      { 
        name: 'AVG Ternure - M1 Return Users - Dmart', 
        calculo: (f) => String(f[2]).trim() === 'M1 Return' ? (parseFloat(f[12]) || 0) : 0, 
        usarComponentes: true, 
        indicesLatam: [
          (f) => String(f[2]).trim() === 'M1 Return' ? ((parseFloat(f[12]) || 0) * (parseFloat(f[3]) || 0)) : 0, 
          (f) => String(f[2]).trim() === 'M1 Return' ? (parseFloat(f[3]) || 0) : 0  
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), format: '0.00', colorFormating: 1 
      },

      // ==========================================
      // 3. REORDER USERS
      // ==========================================
      { 
        name: 'Confirmed Orders - Reorder Users - Dmart', 
        calculo: (f) => String(f[2]).trim() === 'Reorder' ? (parseFloat(f[6]) || 0) : 0, 
        format: '#,##0', colorFormating: 1 
      },
      { 
        name: 'Confirmed Orders - UF - Reorder Users - Dmart', 
        calculo: (f) => String(f[2]).trim() === 'Reorder' ? (parseFloat(f[10]) || 0) : 0, 
        format: '#,##0', colorFormating: 1 
      },
      { 
        name: 'Net Sales - Reorder Users - Dmart', 
        calculo: (f) => String(f[2]).trim() === 'Reorder' ? (parseFloat(f[4]) || 0) : 0, 
        format: '#,##0.00', colorFormating: 1 
      },
      { 
        name: 'Basket Size - Reorder Users - Dmart', 
        calculo: (f) => String(f[2]).trim() === 'Reorder' ? (parseFloat(f[7]) || 0) : 0, 
        usarComponentes: true, 
        indicesLatam: [
          (f) => String(f[2]).trim() === 'Reorder' ? (parseFloat(f[5]) || 0) : 0, 
          (f) => String(f[2]).trim() === 'Reorder' ? (parseFloat(f[6]) || 0) : 0  
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), format: '0.00', colorFormating: 1 
      },
      { 
        name: 'AFV - Reorder Users - Dmart', 
        calculo: (f) => String(f[2]).trim() === 'Reorder' ? (parseFloat(f[9]) || 0) : 0, 
        usarComponentes: true, 
        indicesLatam: [
          (f) => String(f[2]).trim() === 'Reorder' ? (parseFloat(f[4]) || 0) : 0, 
          (f) => String(f[2]).trim() === 'Reorder' ? (parseFloat(f[6]) || 0) : 0  
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), format: '0.00', colorFormating: 1 
      },
      { 
        name: 'Frequency - Reorder Users - Dmart', 
        calculo: (f) => String(f[2]).trim() === 'Reorder' ? (parseFloat(f[8]) || 0) : 0, 
        usarComponentes: true, 
        indicesLatam: [
          (f) => String(f[2]).trim() === 'Reorder' ? (parseFloat(f[6]) || 0) : 0, 
          (f) => String(f[2]).trim() === 'Reorder' ? (parseFloat(f[3]) || 0) : 0  
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), format: '0.00', colorFormating: 1 
      },
      { 
        name: 'Monthly Customer Units - Reorder Users - Dmart', 
        calculo: (f) => String(f[2]).trim() === 'Reorder' ? safeDiv(f[5], f[3]) : 0, 
        usarComponentes: true, 
        indicesLatam: [
          (f) => String(f[2]).trim() === 'Reorder' ? (parseFloat(f[5]) || 0) : 0, 
          (f) => String(f[2]).trim() === 'Reorder' ? (parseFloat(f[3]) || 0) : 0  
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), format: '0.00', colorFormating: 1 
      },
      { 
        name: 'Units Sold - Reorder Users - Dmart', 
        calculo: (f) => String(f[2]).trim() === 'Reorder' ? (parseFloat(f[5]) || 0) : 0, 
        format: '#,##0', colorFormating: 1 
      },
      { 
        name: 'UF User Penetration % - Reorder Users - Dmart', 
        calculo: (f) => String(f[2]).trim() === 'Reorder' ? safeDiv(f[11], f[3]) : 0, 
        usarComponentes: true, 
        indicesLatam: [
          (f) => String(f[2]).trim() === 'Reorder' ? (parseFloat(f[11]) || 0) : 0, 
          (f) => String(f[2]).trim() === 'Reorder' ? (parseFloat(f[3]) || 0) : 0   
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), format: '0.00%', colorFormating: 1 
      },
      { 
        name: 'AVG Ternure - Reorder Users - Dmart', 
        calculo: (f) => String(f[2]).trim() === 'Reorder' ? (parseFloat(f[12]) || 0) : 0, 
        usarComponentes: true, 
        indicesLatam: [
          (f) => String(f[2]).trim() === 'Reorder' ? ((parseFloat(f[12]) || 0) * (parseFloat(f[3]) || 0)) : 0, 
          (f) => String(f[2]).trim() === 'Reorder' ? (parseFloat(f[3]) || 0) : 0  
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), format: '0.00', colorFormating: 1 
      },

      // ==========================================
      // 4. RECURRING RETURN
      // ==========================================
      { 
        name: 'Confirmed Orders - Recurring Return - Dmart', 
        calculo: (f) => String(f[2]).trim() === 'Recurring Return' ? (parseFloat(f[6]) || 0) : 0, 
        format: '#,##0', colorFormating: 1 
      },
      { 
        name: 'Confirmed Orders - UF - Recurring Return - Dmart', 
        calculo: (f) => String(f[2]).trim() === 'Recurring Return' ? (parseFloat(f[10]) || 0) : 0, 
        format: '#,##0', colorFormating: 1 
      },
      { 
        name: 'Net Sales - Recurring Return - Dmart', 
        calculo: (f) => String(f[2]).trim() === 'Recurring Return' ? (parseFloat(f[4]) || 0) : 0, 
        format: '#,##0.00', colorFormating: 1 
      },
      { 
        name: 'Basket Size - Recurring Return - Dmart', 
        calculo: (f) => String(f[2]).trim() === 'Recurring Return' ? (parseFloat(f[7]) || 0) : 0, 
        usarComponentes: true, 
        indicesLatam: [
          (f) => String(f[2]).trim() === 'Recurring Return' ? (parseFloat(f[5]) || 0) : 0, 
          (f) => String(f[2]).trim() === 'Recurring Return' ? (parseFloat(f[6]) || 0) : 0  
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), format: '0.00', colorFormating: 1 
      },
      { 
        name: 'AFV - Recurring Return - Dmart', 
        calculo: (f) => String(f[2]).trim() === 'Recurring Return' ? (parseFloat(f[9]) || 0) : 0, 
        usarComponentes: true, 
        indicesLatam: [
          (f) => String(f[2]).trim() === 'Recurring Return' ? (parseFloat(f[4]) || 0) : 0, 
          (f) => String(f[2]).trim() === 'Recurring Return' ? (parseFloat(f[6]) || 0) : 0  
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), format: '0.00', colorFormating: 1 
      },
      { 
        name: 'Frequency - Recurring Return - Dmart', 
        calculo: (f) => String(f[2]).trim() === 'Recurring Return' ? (parseFloat(f[8]) || 0) : 0, 
        usarComponentes: true, 
        indicesLatam: [
          (f) => String(f[2]).trim() === 'Recurring Return' ? (parseFloat(f[6]) || 0) : 0, 
          (f) => String(f[2]).trim() === 'Recurring Return' ? (parseFloat(f[3]) || 0) : 0  
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), format: '0.00', colorFormating: 1 
      },
      { 
        name: 'Monthly Customer Units - Recurring Return - Dmart', 
        calculo: (f) => String(f[2]).trim() === 'Recurring Return' ? safeDiv(f[5], f[3]) : 0, 
        usarComponentes: true, 
        indicesLatam: [
          (f) => String(f[2]).trim() === 'Recurring Return' ? (parseFloat(f[5]) || 0) : 0, 
          (f) => String(f[2]).trim() === 'Recurring Return' ? (parseFloat(f[3]) || 0) : 0  
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), format: '0.00', colorFormating: 1 
      },
      { 
        name: 'Units Sold - Recurring Return - Dmart', 
        calculo: (f) => String(f[2]).trim() === 'Recurring Return' ? (parseFloat(f[5]) || 0) : 0, 
        format: '#,##0', colorFormating: 1 
      },
      { 
        name: 'UF User Penetration % - Recurring Return - Dmart', 
        calculo: (f) => String(f[2]).trim() === 'Recurring Return' ? safeDiv(f[11], f[3]) : 0, 
        usarComponentes: true, 
        indicesLatam: [
          (f) => String(f[2]).trim() === 'Recurring Return' ? (parseFloat(f[11]) || 0) : 0, 
          (f) => String(f[2]).trim() === 'Recurring Return' ? (parseFloat(f[3]) || 0) : 0   
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), format: '0.00%', colorFormating: 1 
      },
      { 
        name: 'AVG Ternure - Recurring Return - Dmart', 
        calculo: (f) => String(f[2]).trim() === 'Recurring Return' ? (parseFloat(f[12]) || 0) : 0, 
        usarComponentes: true, 
        indicesLatam: [
          (f) => String(f[2]).trim() === 'Recurring Return' ? ((parseFloat(f[12]) || 0) * (parseFloat(f[3]) || 0)) : 0, 
          (f) => String(f[2]).trim() === 'Recurring Return' ? (parseFloat(f[3]) || 0) : 0  
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), format: '0.00', colorFormating: 1 
      },

      // ==========================================
      // 5. RE-ACTIVATION USERS
      // ==========================================
      { 
        name: 'Confirmed Orders - Re-Activation Users - Dmart', 
        calculo: (f) => ['Reactivated', 'Re-Activation'].includes(String(f[2]).trim()) ? (parseFloat(f[6]) || 0) : 0, 
        format: '#,##0', colorFormating: 1 
      },
      { 
        name: 'Confirmed Orders - UF - Re-Activation Users - Dmart', 
        calculo: (f) => ['Reactivated', 'Re-Activation'].includes(String(f[2]).trim()) ? (parseFloat(f[10]) || 0) : 0, 
        format: '#,##0', colorFormating: 1 
      },
      { 
        name: 'Net Sales - Re-Activation Users - Dmart', 
        calculo: (f) => ['Reactivated', 'Re-Activation'].includes(String(f[2]).trim()) ? (parseFloat(f[4]) || 0) : 0, 
        format: '#,##0.00', colorFormating: 1 
      },
      { 
        name: 'Basket Size - Re-Activation Users - Dmart', 
        calculo: (f) => ['Reactivated', 'Re-Activation'].includes(String(f[2]).trim()) ? (parseFloat(f[7]) || 0) : 0, 
        usarComponentes: true, 
        indicesLatam: [
          (f) => ['Reactivated', 'Re-Activation'].includes(String(f[2]).trim()) ? (parseFloat(f[5]) || 0) : 0, 
          (f) => ['Reactivated', 'Re-Activation'].includes(String(f[2]).trim()) ? (parseFloat(f[6]) || 0) : 0  
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), format: '0.00', colorFormating: 1 
      },
      { 
        name: 'AFV - Re-Activation Users - Dmart', 
        calculo: (f) => ['Reactivated', 'Re-Activation'].includes(String(f[2]).trim()) ? (parseFloat(f[9]) || 0) : 0, 
        usarComponentes: true, 
        indicesLatam: [
          (f) => ['Reactivated', 'Re-Activation'].includes(String(f[2]).trim()) ? (parseFloat(f[4]) || 0) : 0, 
          (f) => ['Reactivated', 'Re-Activation'].includes(String(f[2]).trim()) ? (parseFloat(f[6]) || 0) : 0  
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), format: '0.00', colorFormating: 1 
      },
      { 
        name: 'Frequency - Re-Activation Users - Dmart', 
        calculo: (f) => ['Reactivated', 'Re-Activation'].includes(String(f[2]).trim()) ? (parseFloat(f[8]) || 0) : 0, 
        usarComponentes: true, 
        indicesLatam: [
          (f) => ['Reactivated', 'Re-Activation'].includes(String(f[2]).trim()) ? (parseFloat(f[6]) || 0) : 0, 
          (f) => ['Reactivated', 'Re-Activation'].includes(String(f[2]).trim()) ? (parseFloat(f[3]) || 0) : 0  
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), format: '0.00', colorFormating: 1 
      },
      { 
        name: 'Monthly Customer Units - Re-Activation Users - Dmart', 
        calculo: (f) => ['Reactivated', 'Re-Activation'].includes(String(f[2]).trim()) ? safeDiv(f[5], f[3]) : 0, 
        usarComponentes: true, 
        indicesLatam: [
          (f) => ['Reactivated', 'Re-Activation'].includes(String(f[2]).trim()) ? (parseFloat(f[5]) || 0) : 0, 
          (f) => ['Reactivated', 'Re-Activation'].includes(String(f[2]).trim()) ? (parseFloat(f[3]) || 0) : 0  
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), format: '0.00', colorFormating: 1 
      },
      { 
        name: 'Units Sold - Re-Activation Users - Dmart', 
        calculo: (f) => ['Reactivated', 'Re-Activation'].includes(String(f[2]).trim()) ? (parseFloat(f[5]) || 0) : 0, 
        format: '#,##0', colorFormating: 1 
      },
      { 
        name: 'UF User Penetration % - Re-Activation Users - Dmart', 
        calculo: (f) => ['Reactivated', 'Re-Activation'].includes(String(f[2]).trim()) ? safeDiv(f[11], f[3]) : 0, 
        usarComponentes: true, 
        indicesLatam: [
          (f) => ['Reactivated', 'Re-Activation'].includes(String(f[2]).trim()) ? (parseFloat(f[11]) || 0) : 0, 
          (f) => ['Reactivated', 'Re-Activation'].includes(String(f[2]).trim()) ? (parseFloat(f[3]) || 0) : 0   
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), format: '0.00%', colorFormating: 1 
      },
      { 
        name: 'AVG Ternure - Re-Activation Users - Dmart', 
        calculo: (f) => ['Reactivated', 'Re-Activation'].includes(String(f[2]).trim()) ? (parseFloat(f[12]) || 0) : 0, 
        usarComponentes: true, 
        indicesLatam: [
          (f) => ['Reactivated', 'Re-Activation'].includes(String(f[2]).trim()) ? ((parseFloat(f[12]) || 0) * (parseFloat(f[3]) || 0)) : 0, 
          (f) => ['Reactivated', 'Re-Activation'].includes(String(f[2]).trim()) ? (parseFloat(f[3]) || 0) : 0  
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), format: '0.00', colorFormating: 1 
      }
    ]
  }, { // 25 - NPS Score
    nombreHoja: "25 - NPS Score",
    indices: { month: 0, country: 1 }, 
    calcularLatam: true, 
    metricas: [
      { name: 'NPS Survey Volume', index: 2, colorFormating: 1 }, 
      { name: 'NPS Promoters', index: 3, colorFormating: 1 },     
      { name: 'NPS Passives', index: 4, colorFormating: 1 },      
      { name: 'NPS Detractors', index: 5, colorFormating: 0 },    

      { 
        name: 'NPS Score', 
        calculo: (f) => parseFloat(f[6]) || 0, 
        usarComponentes: true,
        indicesLatam: [3, 5, 2], 
        calculoLatam: (c) => c[2] > 0 ? ((c[0] - c[1]) / c[2]) * 100 : 0,
        format: '0.00',
        colorFormating: 1 
      }
    ]
  }, { // 26 - Small Order Fee
    nombreHoja: "26 - Small Order Fee",
    indices: { month: 0, country: 1 },
    calcularLatam: true,
    metricas: [
      // ==========================================
      // 1. SCOPE: SOF (TOTAL SOF)
      // ==========================================
      { 
        name: 'Confirmed Orders - SOF', 
        calculo: (f) => String(f[2]).trim() === 'SOF' ? (parseFloat(f[6]) || 0) : 0, 
        format: '#,##0', 
        colorFormating: 1 
      },
      { 
        name: 'Dmart MAUs - SOF', 
        calculo: (f) => String(f[2]).trim() === 'SOF' ? (parseFloat(f[4]) || 0) : 0, 
        format: '#,##0', 
        colorFormating: 1 
      },
      { 
        name: 'New Users - SOF', 
        calculo: (f) => String(f[2]).trim() === 'SOF' ? (parseFloat(f[5]) || 0) : 0, 
        format: '#,##0', 
        colorFormating: 1 
      },
      { 
        name: 'Units sold - SOF', 
        calculo: (f) => String(f[2]).trim() === 'SOF' ? (parseFloat(f[7]) || 0) : 0, 
        format: '#,##0', 
        colorFormating: 1 
      },
      { 
        name: 'Net Sales - SOF', 
        calculo: (f) => String(f[2]).trim() === 'SOF' ? (parseFloat(f[8]) || 0) : 0, 
        format: '#,##0.00', 
        colorFormating: 1 
      },
      { 
        name: 'Small Order Fee', 
        calculo: (f) => String(f[2]).trim() === 'SOF' ? (parseFloat(f[9]) || 0) : 0, 
        format: '#,##0.00', 
        colorFormating: 1 
      },
      { 
        name: 'Delivery Fee - SOF', 
        calculo: (f) => String(f[2]).trim() === 'SOF' ? (parseFloat(f[10]) || 0) : 0, 
        format: '#,##0.00', 
        colorFormating: 0 
      },
      { 
        name: 'Service Fee - SOF', 
        calculo: (f) => String(f[2]).trim() === 'SOF' ? (parseFloat(f[11]) || 0) : 0, 
        format: '#,##0.00', 
        colorFormating: 0 
      },
      { 
        name: 'Total Fees - SOF', 
        calculo: (f) => String(f[2]).trim() === 'SOF' ? (parseFloat(f[12]) || 0) : 0, 
        format: '#,##0.00', 
        colorFormating: 1 
      },
      { 
        name: 'GPO - SOF', 
        calculo: (f) => String(f[2]).trim() === 'SOF' ? (parseFloat(f[13]) || 0) : 0, 
        format: '#,##0.00', 
        colorFormating: 1 
      },

      // ==========================================
      // 2. SCOPE: NON-SOF (TOTAL NON-SOF)
      // ==========================================
      { 
        name: 'Confirmed Orders - Non-SOF', 
        calculo: (f) => String(f[2]).trim() === 'Non-SOF' ? (parseFloat(f[6]) || 0) : 0, 
        format: '#,##0', 
        colorFormating: 1 
      },
      { 
        name: 'Dmart MAUs - Non-SOF', 
        calculo: (f) => String(f[2]).trim() === 'Non-SOF' ? (parseFloat(f[4]) || 0) : 0, 
        format: '#,##0', 
        colorFormating: 1 
      },
      { 
        name: 'New Users - non SOF', 
        calculo: (f) => String(f[2]).trim() === 'Non-SOF' ? (parseFloat(f[5]) || 0) : 0, 
        format: '#,##0', 
        colorFormating: 1 
      },
      { 
        name: 'Units sold - Non-SOF', 
        calculo: (f) => String(f[2]).trim() === 'Non-SOF' ? (parseFloat(f[7]) || 0) : 0, 
        format: '#,##0', 
        colorFormating: 1 
      },
      { 
        name: 'Net Sales - Non-SOF', 
        calculo: (f) => String(f[2]).trim() === 'Non-SOF' ? (parseFloat(f[8]) || 0) : 0, 
        format: '#,##0.00', 
        colorFormating: 1 
      },
      { 
        name: 'Delivery Fee - Non-SOF', 
        calculo: (f) => String(f[2]).trim() === 'Non-SOF' ? (parseFloat(f[10]) || 0) : 0, 
        format: '#,##0.00', 
        colorFormating: 0 
      },
      { 
        name: 'Service Fee - Non-SOF', 
        calculo: (f) => String(f[2]).trim() === 'Non-SOF' ? (parseFloat(f[11]) || 0) : 0, 
        format: '#,##0.00', 
        colorFormating: 0 
      },
      { 
        name: 'Total Fees - Non-SOF', 
        calculo: (f) => String(f[2]).trim() === 'Non-SOF' ? (parseFloat(f[12]) || 0) : 0, 
        format: '#,##0.00', 
        colorFormating: 1 
      },
      { 
        name: 'GPO - Non-SOF', 
        calculo: (f) => String(f[2]).trim() === 'Non-SOF' ? (parseFloat(f[13]) || 0) : 0, 
        format: '#,##0.00', 
        colorFormating: 1 
      },

      // ==========================================
      // 3. SEGMENTACIÓN PLUS / NON-PLUS EN SOF
      // ==========================================
      { 
        name: 'Confirmed Orders - SOF - Plus', 
        calculo: (f) => (String(f[2]).trim() === 'SOF' && String(f[3]).trim() === 'Plus') ? (parseFloat(f[6]) || 0) : 0, 
        format: '#,##0', 
        colorFormating: 1 
      },
      { 
        name: 'Confirmed Orders - SOF - Non-plus', 
        calculo: (f) => (String(f[2]).trim() === 'SOF' && String(f[3]).trim() === 'Non-plus') ? (parseFloat(f[6]) || 0) : 0, 
        format: '#,##0', 
        colorFormating: 1 
      },
      { 
        name: 'Dmart MAUs - SOF - Plus', 
        calculo: (f) => (String(f[2]).trim() === 'SOF' && String(f[3]).trim() === 'Plus') ? (parseFloat(f[4]) || 0) : 0, 
        format: '#,##0', 
        colorFormating: 1 
      },
      { 
        name: 'Dmart MAUs - SOF - Non-plus', 
        calculo: (f) => (String(f[2]).trim() === 'SOF' && String(f[3]).trim() === 'Non-plus') ? (parseFloat(f[4]) || 0) : 0, 
        format: '#,##0', 
        colorFormating: 1 
      },
      { 
        name: 'New Users - SOF - Plus', 
        calculo: (f) => (String(f[2]).trim() === 'SOF' && String(f[3]).trim() === 'Plus') ? (parseFloat(f[5]) || 0) : 0, 
        format: '#,##0', 
        colorFormating: 1 
      },
      { 
        name: 'New Users - SOF - Non-plus', 
        calculo: (f) => (String(f[2]).trim() === 'SOF' && String(f[3]).trim() === 'Non-plus') ? (parseFloat(f[5]) || 0) : 0, 
        format: '#,##0', 
        colorFormating: 1 
      },
      { 
        name: 'Net Sales - SOF - Plus', 
        calculo: (f) => (String(f[2]).trim() === 'SOF' && String(f[3]).trim() === 'Plus') ? (parseFloat(f[8]) || 0) : 0, 
        format: '#,##0.00', 
        colorFormating: 1 
      },
      { 
        name: 'Net Sales - SOF - Non-plus', 
        calculo: (f) => (String(f[2]).trim() === 'SOF' && String(f[3]).trim() === 'Non-plus') ? (parseFloat(f[8]) || 0) : 0, 
        format: '#,##0.00', 
        colorFormating: 1 
      },
      { 
        name: 'Units sold - SOF - Plus', 
        calculo: (f) => (String(f[2]).trim() === 'SOF' && String(f[3]).trim() === 'Plus') ? (parseFloat(f[7]) || 0) : 0, 
        format: '#,##0', 
        colorFormating: 1 
      },
      { 
        name: 'Units sold - SOF - Non-plus', 
        calculo: (f) => (String(f[2]).trim() === 'SOF' && String(f[3]).trim() === 'Non-plus') ? (parseFloat(f[7]) || 0) : 0, 
        format: '#,##0', 
        colorFormating: 1 
      },
      { 
        name: 'Small Order Fee - Plus', 
        calculo: (f) => (String(f[2]).trim() === 'SOF' && String(f[3]).trim() === 'Plus') ? (parseFloat(f[9]) || 0) : 0, 
        format: '#,##0.00', 
        colorFormating: 1 
      },
      { 
        name: 'Small Order Fee - Non-plus', 
        calculo: (f) => (String(f[2]).trim() === 'SOF' && String(f[3]).trim() === 'Non-plus') ? (parseFloat(f[9]) || 0) : 0, 
        format: '#,##0.00', 
        colorFormating: 1 
      },

      // ==========================================
      // 4. RATIOS SOF Y NON-SOF (BASKET SIZE, AFV, FREQUENCY, CUSTOMER UNITS)
      // ==========================================
      { 
        name: 'Basket Size - SOF', 
        calculo: (f) => String(f[2]).trim() === 'SOF' ? safeDiv(f[7], f[6]) : 0,
        usarComponentes: true,
        indicesLatam: [
          (f) => String(f[2]).trim() === 'SOF' ? (parseFloat(f[7]) || 0) : 0, 
          (f) => String(f[2]).trim() === 'SOF' ? (parseFloat(f[6]) || 0) : 0  
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), 
        format: '0.00', 
        colorFormating: 1 
      },
      { 
        name: 'Basket Size - Non-SOF', 
        calculo: (f) => String(f[2]).trim() === 'Non-SOF' ? safeDiv(f[7], f[6]) : 0,
        usarComponentes: true,
        indicesLatam: [
          (f) => String(f[2]).trim() === 'Non-SOF' ? (parseFloat(f[7]) || 0) : 0, 
          (f) => String(f[2]).trim() === 'Non-SOF' ? (parseFloat(f[6]) || 0) : 0  
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), 
        format: '0.00', 
        colorFormating: 1 
      },
      { 
        name: 'AFV - SOF', 
        calculo: (f) => String(f[2]).trim() === 'SOF' ? safeDiv(f[8], f[6]) : 0,
        usarComponentes: true,
        indicesLatam: [
          (f) => String(f[2]).trim() === 'SOF' ? (parseFloat(f[8]) || 0) : 0, 
          (f) => String(f[2]).trim() === 'SOF' ? (parseFloat(f[6]) || 0) : 0  
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), 
        format: '0.00', 
        colorFormating: 1 
      },
      { 
        name: 'AFV - Non-SOF', 
        calculo: (f) => String(f[2]).trim() === 'Non-SOF' ? safeDiv(f[8], f[6]) : 0,
        usarComponentes: true,
        indicesLatam: [
          (f) => String(f[2]).trim() === 'Non-SOF' ? (parseFloat(f[8]) || 0) : 0, 
          (f) => String(f[2]).trim() === 'Non-SOF' ? (parseFloat(f[6]) || 0) : 0  
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), 
        format: '0.00', 
        colorFormating: 1 
      },
      { 
        name: 'Frequency - SOF', 
        calculo: (f) => String(f[2]).trim() === 'SOF' ? safeDiv(f[6], f[4]) : 0,
        usarComponentes: true,
        indicesLatam: [
          (f) => String(f[2]).trim() === 'SOF' ? (parseFloat(f[6]) || 0) : 0, 
          (f) => String(f[2]).trim() === 'SOF' ? (parseFloat(f[4]) || 0) : 0  
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), 
        format: '0.00', 
        colorFormating: 1 
      },
      { 
        name: 'Frequency - Non-SOF', 
        calculo: (f) => String(f[2]).trim() === 'Non-SOF' ? safeDiv(f[6], f[4]) : 0,
        usarComponentes: true,
        indicesLatam: [
          (f) => String(f[2]).trim() === 'Non-SOF' ? (parseFloat(f[6]) || 0) : 0, 
          (f) => String(f[2]).trim() === 'Non-SOF' ? (parseFloat(f[4]) || 0) : 0  
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), 
        format: '0.00', 
        colorFormating: 1 
      },
      { 
        name: 'Customer Units - SOF', 
        calculo: (f) => String(f[2]).trim() === 'SOF' ? safeDiv(f[7], f[4]) : 0,
        usarComponentes: true,
        indicesLatam: [
          (f) => String(f[2]).trim() === 'SOF' ? (parseFloat(f[7]) || 0) : 0, 
          (f) => String(f[2]).trim() === 'SOF' ? (parseFloat(f[4]) || 0) : 0  
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), 
        format: '0.00', 
        colorFormating: 1 
      },
      { 
        name: 'Customer Units - Non-SOF', 
        calculo: (f) => String(f[2]).trim() === 'Non-SOF' ? safeDiv(f[7], f[4]) : 0,
        usarComponentes: true,
        indicesLatam: [
          (f) => String(f[2]).trim() === 'Non-SOF' ? (parseFloat(f[7]) || 0) : 0, 
          (f) => String(f[2]).trim() === 'Non-SOF' ? (parseFloat(f[4]) || 0) : 0  
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), 
        format: '0.00', 
        colorFormating: 1 
      },
      { 
        name: 'GPO per Order - SOF', 
        calculo: (f) => String(f[2]).trim() === 'SOF' ? safeDiv(f[13], f[6]) : 0,
        usarComponentes: true,
        indicesLatam: [
          (f) => String(f[2]).trim() === 'SOF' ? (parseFloat(f[13]) || 0) : 0, 
          (f) => String(f[2]).trim() === 'SOF' ? (parseFloat(f[6]) || 0) : 0  
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), 
        format: '0.00', 
        colorFormating: 1 
      },
      { 
        name: 'GPO per Order - Non-SOF', 
        calculo: (f) => String(f[2]).trim() === 'Non-SOF' ? safeDiv(f[13], f[6]) : 0,
        usarComponentes: true,
        indicesLatam: [
          (f) => String(f[2]).trim() === 'Non-SOF' ? (parseFloat(f[13]) || 0) : 0, 
          (f) => String(f[2]).trim() === 'Non-SOF' ? (parseFloat(f[6]) || 0) : 0  
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), 
        format: '0.00', 
        colorFormating: 1 
      },
      { 
        name: 'Avg Small Order Fee', 
        calculo: (f) => String(f[2]).trim() === 'SOF' ? safeDiv(f[9], f[6]) : 0,
        usarComponentes: true,
        indicesLatam: [
          (f) => String(f[2]).trim() === 'SOF' ? (parseFloat(f[9]) || 0) : 0, 
          (f) => String(f[2]).trim() === 'SOF' ? (parseFloat(f[6]) || 0) : 0  
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), 
        format: '0.00', 
        colorFormating: 1 
      },
      { 
        name: 'Avg Total Fees - SOF', 
        calculo: (f) => String(f[2]).trim() === 'SOF' ? safeDiv(f[12], f[6]) : 0,
        usarComponentes: true,
        indicesLatam: [
          (f) => String(f[2]).trim() === 'SOF' ? (parseFloat(f[12]) || 0) : 0, 
          (f) => String(f[2]).trim() === 'SOF' ? (parseFloat(f[6]) || 0) : 0  
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), 
        format: '0.00', 
        colorFormating: 0 
      },
      { 
        name: 'Avg Total Fees - Non-SOF', 
        calculo: (f) => String(f[2]).trim() === 'Non-SOF' ? safeDiv(f[12], f[6]) : 0,
        usarComponentes: true,
        indicesLatam: [
          (f) => String(f[2]).trim() === 'Non-SOF' ? (parseFloat(f[12]) || 0) : 0, 
          (f) => String(f[2]).trim() === 'Non-SOF' ? (parseFloat(f[6]) || 0) : 0  
        ],
        calculoLatam: (c) => safeDiv(c[0], c[1]), 
        format: '0.00', 
        colorFormating: 0 
      }
    ]
  }
];
     
const CONFIG_GD_METRICAS_RELACIONADAS = [
  { // Avg PVP (wo VAT)
    name: 'Avg PVP (wo VAT)',
    numerator: 'Net Sales',   
    denominator: 'Units Sold', 
    format: '0.00',
    colorFormating: 0 
  },
  { 
    name: 'AFV',
    numerator: 'Net Sales',
    denominator: 'Confirmed Orders',
    format: '0.00',
    colorFormating: 1
  },
  { // Dmart Churn Share %
    name: 'Dmart Churn Share %',
    numerator: 'Churned Users - Dmart',
    denominator: 'Total Churned Users',
    format: '0.00%',
    colorFormating: 0 
  },
  { 
    name: 'Retention Rate - Return Users % - PeYa', 
    numerator: 'Return Users (M2 or M3) - PeYa', 
    denominator: 'New Users - PeYa', 
    format: '0.00%',
    colorFormating: 1
  },
  { 
    name: 'Retention Rate - Return Users % - Dmart', 
    numerator: 'Return Users (M2 or M3) - Dmart', 
    denominator: 'New Users - Dmart', 
    format: '0.00%',
    colorFormating: 1
  },
  // PENETRACIÓN DE USUARIOS ULTRA FRESH
  { 
    name: 'MAUs penetration % - UF', 
    numerator: 'Dmart MAUs - Ultra Fresh', 
    denominator: 'Dmart MAUs', 
    format: '0.00%',
    colorFormating: 1
  }, { // New Users % - UF - Dmart
    name: 'New Users % - UF - Dmart', 
    numerator: 'New Users - UF - Dmart', 
    denominator: 'New Users - Dmart', 
    format: '0.00%',
    colorFormating: 1
  }, { // M1 Return Users % - UF - Dmart
    name: 'M1 Return Users % - UF - Dmart', 
    numerator: 'M1 Return Users - UF - Dmart', 
    denominator: 'M1 Return Users - Dmart', 
    format: '0.00%',
    colorFormating: 1
  }, { // Re-Activation % - UF - Dmart
    name: 'Re-Activation % - UF - Dmart', 
    numerator: 'Re-Activation - UF - Dmart', 
    denominator: 'Re-Activation Users - Dmart', 
    format: '0.00%',
    colorFormating: 1
  }, { // Reorder % - UF - Dmart
    name: 'Reorder % - UF - Dmart', 
    numerator: 'Reorder - UF - Dmart', 
    denominator: 'Reorder Users - Dmart', 
    format: '0.00%',
    colorFormating: 1
  }, { // Recurring Return % - UF - Dmart
    name: 'Recurring Return % - UF - Dmart', 
    numerator: 'Recurring Return - UF - Dmart', 
    denominator: 'Recurring Return - Dmart', 
    format: '0.00%',
    colorFormating: 1
  },

  // OTROS RATIOS GENERALES (Ops, Finance, Users)
  { 
    name: 'Covered MAUs penetration %',          
    numerator: 'Dmart MAUs',      
    denominator: 'Covered MAUs',
    format: '0.00%',
    colorFormating: 1                    
  }, { // Platform Maus penetration %
    name: 'Platform Maus penetration %',          
    numerator: 'Dmart MAUs',      
    denominator: 'PeYa MAUs',
    format: '0.00%',
    colorFormating: 1                    
  } ,{ // MAUs % - Plus
    name: 'MAUs % - Plus',
    numerator: 'Dmart MAUs - Plus',
    denominator: 'Dmart MAUs',
    format: '0.00%',
    colorFormating: 1
  }, { // % New Users / Dmart MAUs
    name: '% New Users / Dmart MAUs',
    numerator: 'New Users - Dmart',
    denominator: 'Dmart MAUs',
    format: '0.00%',
    colorFormating: 1
  }, 
  
  // ====================================================================================
  // CORRECCIÓN: Frequency y ratios básicos movidos antes de Customer Value
  // para evitar lookup failures durante la evaluación secuencial de relaciones.
  // ====================================================================================
  { // Frequency
    name: 'Frequency',
    numerator: 'Confirmed Orders',
    denominator: 'Dmart MAUs', 
    format: '0.00',
    colorFormating: 1
  }, 
  { // Frequency Plus
    name: 'Frequency - Plus Users',
    numerator: 'Confirmed Orders - Plus',
    denominator: 'Dmart MAUs', 
    format: '0.00',
    colorFormating: 1
  },
  { // Customer Value
    name: 'Customer Value',
    operation: 'MULTIPLY',
    factors: ['AFV', 'Frequency'], 
    format: '0.00',
    colorFormating: 1
  }, { // Stock SM (Eur) %
    name: 'Stock SM (Eur) %', 
    numerator: 'Active SM (eur)',
    denominator: 'AVG Stock (Eur)',
    format: '0.00%',
    colorFormating: 0
  }, 
  { // Promo funding %
    name: 'Promo funding %',
    numerator: 'Back Margin',   
    denominator: 'Discounts',   
    format: '0.00%',
    colorFormating: 1
  }, 
  { // Discounts % (Calculado a nivel global)
    name: 'Discounts %',
    numerator: 'Discounts',
    denominator: 'Net Sales',
    format: '0.00%',
    colorFormating: 0
  },
  { // Customer Units
    name: 'Customer Units',
    numerator: 'Units Sold',
    denominator: 'Dmart MAUs',
    format: '0.00',
    colorFormating: 1
  },

  // ==========================================
  // MÉTRICAS DOUBLE YA (Generales)
  // ==========================================
  { // Confirmed Orders Share % - Double Ya
    name: 'Confirmed Orders Share % - Double Ya',
    numerator: 'Confirmed Orders - Double Ya',
    denominator: 'Confirmed Orders',
    format: '0.00%',
    colorFormating: 1
  },
  { // Net Sales Share % - Double Ya
    name: 'Net sales Share % - Double Ya',
    numerator: 'Net Sales - Double Ya',
    denominator: 'Net Sales',
    format: '0.00%',
    colorFormating: 1
  },
  { // Units Sold Share % - Double Ya
    name: 'Units sold Share % - Double Ya',
    numerator: 'Units sold - Double Ya',
    denominator: 'Units Sold',
    format: '0.00%',
    colorFormating: 1
  },
  { // Sessions Share % - Double Ya
    name: 'Sessions Share % - Double Ya',
    numerator: 'Sessions - Double Ya',
    denominator: 'Sessions',
    format: '0.00%',
    colorFormating: 1
  },

  // ==========================================
  // USUARIOS (SHARE) - DOUBLE YA
  // ==========================================
  { // Dmart MAUs Share % - Double Ya
    name: 'Dmart MAUs Share % - Double Ya',
    numerator: 'Dmart MAUs - Double Ya',
    denominator: 'Dmart MAUs', 
    format: '0.00%',
    colorFormating: 1
  },
  { // New Users Share % - Double Ya
    name: 'New Users Share % - Double Ya',
    numerator: 'New Users - Double Ya',
    denominator: 'New Users - Dmart', 
    format: '0.00%',
    colorFormating: 1
  },

  // ==========================================
  // SHARE DE USUARIOS DMART (Composición de MAUs)
  // ==========================================
  { 
    name: 'New Users Share % - Dmart', 
    numerator: 'New Users - Dmart', 
    denominator: 'Dmart MAUs', 
    format: '0.00%',
    colorFormating: 1 
  },
  { 
    name: 'M1 Return Users Share % - Dmart', 
    numerator: 'M1 Return Users - Dmart', 
    denominator: 'Dmart MAUs', 
    format: '0.00%',
    colorFormating: 1 
  },
  { 
    name: 'Reorder Users Share % - Dmart', 
    numerator: 'Reorder Users - Dmart', 
    denominator: 'Dmart MAUs', 
    format: '0.00%',
    colorFormating: 1 
  },
  { 
    name: 'Recurring Return Share % - Dmart', 
    numerator: 'Recurring Return - Dmart', 
    denominator: 'Dmart MAUs', 
    format: '0.00%',
    colorFormating: 1 
  },
  { 
    name: 'Re-Activation Users Share % - Dmart', 
    numerator: 'Re-Activation Users - Dmart', 
    denominator: 'Dmart MAUs', 
    format: '0.00%',
    colorFormating: 1 
  },

  // ==========================================
  // NUEVAS MÉTRICAS RELACIONADAS RESTANTES
  // ==========================================
  { // Dmart MAUs - Plus share %
    name: 'Dmart MAUs - Plus share %',
    numerator: 'Dmart MAUs - Plus',
    denominator: 'Dmart MAUs',
    format: '0.00%',
    colorFormating: 1
  },

  // ==========================================
  // MÉTRICAS SMALL ORDER FEE (SOF) SHARES & RATIOS
  // ==========================================
  { // Confirmed Orders Share % - SOF
    name: 'Confirmed Orders Share % - SOF',
    numerator: 'Confirmed Orders - SOF',
    denominator: 'Confirmed Orders',
    format: '0.00%',
    colorFormating: 0
  },
  { // Net Sales Share % - SOF
    name: 'Net Sales Share % - SOF',
    numerator: 'Net Sales - SOF',
    denominator: 'Net Sales',
    format: '0.00%',
    colorFormating: 0
  },
  { // Dmart MAUs Share % - SOF
    name: 'Dmart MAUs Share % - SOF',
    numerator: 'Dmart MAUs - SOF',
    denominator: 'Dmart MAUs',
    format: '0.00%',
    colorFormating: 0
  },
  { // Units Sold Share % - SOF
    name: 'Units Sold Share % - SOF',
    numerator: 'Units sold - SOF',
    denominator: 'Units Sold',
    format: '0.00%',
    colorFormating: 0
  },
  { // New Users Share % - SOF
    name: 'New Users Share % - SOF',
    numerator: 'New Users - SOF',
    denominator: 'New Users - Dmart',
    format: '0.00%',
    colorFormating: 0
  },
  { // Plus Orders Share % - SOF
    name: 'Plus Orders Share % - SOF',
    numerator: 'Confirmed Orders - SOF - Plus',
    denominator: 'Confirmed Orders - SOF',
    format: '0.00%',
    colorFormating: 1
  },
  { // Plus MAUs Penetration % - SOF
    name: 'Plus MAUs Penetration % - SOF',
    numerator: 'Dmart MAUs - SOF - Plus',
    denominator: 'Dmart MAUs - SOF',
    format: '0.00%',
    colorFormating: 1
  },
  { // SOF Penetration % in Plus Orders
    name: 'SOF Penetration % in Plus Orders',
    numerator: 'Confirmed Orders - SOF - Plus',
    denominator: 'Confirmed Orders - Plus',
    format: '0.00%',
    colorFormating: 0
  },
  { // GPO % - SOF
    name: 'GPO % - SOF',
    numerator: 'GPO - SOF',
    denominator: 'Net Sales - SOF',
    format: '0.00%',
    colorFormating: 1
  },
  { // GPO % - Non-SOF
    name: 'GPO % - Non-SOF',
    numerator: 'GPO - Non-SOF',
    denominator: 'Net Sales - Non-SOF',
    format: '0.00%',
    colorFormating: 1
  }
];

// --- HELPERS Y UTILIDADES ---
// ==========================================
function safeDiv(num, den) {
  const n = (typeof num === 'string') ? parseFloat(num.replace(/,/g, '')) : parseFloat(num);
  const d = (typeof den === 'string') ? parseFloat(den.replace(/,/g, '')) : parseFloat(den);

  if (isNaN(n) || isNaN(d) || d === 0) return 0;
  return n / d;
}
function textHas(val, txt) {
  return String(val).toLowerCase().includes(txt.toLowerCase());
}
function GeneralData_Helper_LimpiarTexto(str) {
  return str ? str.normalize("NFD").replace(/[\u0300-\u036f]/g, "").trim() : "";
}
function GeneralData_Helper_NormalizarFecha(valor) {
  if (!valor) return null;

  let d;
  if (valor instanceof Date) {
    d = new Date(valor); 
  } else if (typeof valor === 'number') {
    d = new Date(((valor - 25569) * 86400000) + 43200000);
  } else {
    d = new Date(String(valor).trim().replace(/-/g, '\/'));
  }

  if (isNaN(d.getTime())) return null;

  d.setTime(d.getTime() + (6 * 60 * 60 * 1000));
  d.setHours(12, 0, 0, 0);

  return d;
}
function obtenerDiasDelMes(fechaRaw) {
  const d = GeneralData_Helper_NormalizarFecha(fechaRaw);
  if (!d) return 30; 
  return new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate();
}
function GeneralData_Helper_QuitarFiltros(sheet, forceUnhide) {
  if (!sheet) return;
  try {
    const filtro = sheet.getFilter();
    if (filtro) filtro.remove();                 
  } catch (e) {
    Logger.log(`   ⚠️ No se pudo quitar filtro: ${e.message}`);
  }
  if (!forceUnhide) return; // OPTIMIZACIÓN CRÍTICA: Evitamos el costo altísimo de showRows y showColumns por defecto
  try {
    sheet.showRows(1, sheet.getMaxRows());        
    sheet.showColumns(1, sheet.getMaxColumns());  
  } catch (e) {
    Logger.log(`   ⚠️ No se pudieron mostrar filas/columnas: ${e.message}`);
  }
}

// ====================================================================================
// CORRECCIÓN: Definición de GeneralData_Helper_Importar añadida para hacer el archivo
// 100% autónomo y evitar depender de otros archivos del proyecto cloud.
// ====================================================================================
function GeneralData_Helper_Importar(conf, ssDestino) {
  try {
    const ssOrigen = obtenerSpreadsheetConCache(conf.id_origen);
    const hojaOrigen = ssOrigen.getSheetByName(conf.nombre_hoja_origen);
    if (!hojaOrigen) {
      Logger.log(`❌ No existe '${conf.nombre_hoja_origen}' en el archivo origen.`);
      return;
    }
    const datos = hojaOrigen.getDataRange().getValues();
    if (datos.length === 0) return;

    let hojaDest = ssDestino.getSheetByName(conf.nombre_hoja_destino);
    if (!hojaDest) hojaDest = ssDestino.insertSheet(conf.nombre_hoja_destino);

    GeneralData_Helper_QuitarFiltros(hojaDest);
    hojaDest.clearContents(); // clearContents preserva cuadrículas limpias y es muy veloz

    hojaDest.getRange(1, 1, datos.length, datos[0].length).setValues(datos);
    Logger.log(`✅ Importado: '${conf.nombre_hoja_destino}'`);
  } catch (e) {
    Logger.log(`❌ Error importando '${conf.nombre_hoja_destino}': ${e.message}`);
  }
}

// --- FUNCIÓN PRINCIPAL Y UNIFICACIÓN ---
// ==========================================
function GeneralData_ConsolidarMetricas() {
  const ss = obtenerSpreadsheetConCache(ID_ARCHIVO_UNICO.trim());
  const nombreHojaDestino = "Consolidado General Data";
  const timeZone = ss.getSpreadsheetTimeZone();

  Logger.log("... Generando Consolidado General Data");

  const MAPA_RESULTADOS = {};
  const MAPA_FORMATOS = {};
  const MAPA_COMPONENTES_PAIS = {};
  const MAPA_COLOR_CONFIG = {}; // Almacena el 0 o 1 de cada métrica

  // ====================================================================================
  // NUEVO: CONFIGURAR COLORES FIJOS DE MÉTRICAS EXTERNAS / NO CALCULADAS LOCALMENTE
  // ====================================================================================
  MAPA_COLOR_CONFIG['Free Cash Flow'] = 1;
  MAPA_COLOR_CONFIG['Commercial Cycle (DOH - DPO)'] = 1;
  MAPA_COLOR_CONFIG['DPO neto de Bonificaciones'] = 1;
  MAPA_COLOR_CONFIG['Cash Conversion Cycle (CCC)'] = 1;
  MAPA_COLOR_CONFIG['Working Capital'] = 1;

  const PAISES_PERMITIDOS = [
    "LATAM",
    "Argentina", "Bolivia", "Chile", "Republica Dominicana",
    "Ecuador", "El Salvador", "Guatemala", "Honduras",
    "Nicaragua", "Panama", "Paraguay", "Peru", "Uruguay",
  ];

  // ====================================================================================
  // OPTIMIZACIÓN: CACHES EN MEMORIA PARA CPU-BOUND OPERATIONS
  // ====================================================================================
  const cacheNormalizarFecha = {};
  const cacheFormatearFecha = {};
  const cachePaisesLimpios = {};
  const cachePaisesValidos = {};
  const mapPaisesPermitidosUpper = PAISES_PERMITIDOS.map(p => p.toUpperCase());
  const mesesProcesados = new Set(); // Colecciona todos los meses válidos que se procesan

  // ====================================================================================
  // 1. PROCESAMIENTO DE MÉTRICAS NORMALES (Desde las hojas)
  // ====================================================================================
  CONFIG_GD_METRICAS.forEach(config => {
    const hoja = ss.getSheetByName(config.nombreHoja);
    if (!hoja) return;

    GeneralData_Helper_QuitarFiltros(hoja);

    const datos = hoja.getDataRange().getValues();
    if (datos.length <= 1) return;

    const acumuladorLatam = {};

    for (let i = 1; i < datos.length; i++) {
      const fila = datos[i];
      if (config.filtroFila && !config.filtroFila(fila)) continue;

      const rawDate = fila[config.indices.month];
      let country = fila[config.indices.country];

      // OPTIMIZACIÓN: Cache de normalización de fecha para evitar llamadas CPU-bound redundantes
      const rawDateStr = String(rawDate);
      let fechaObj = cacheNormalizarFecha[rawDateStr];
      if (fechaObj === undefined) {
        fechaObj = GeneralData_Helper_NormalizarFecha(rawDate);
        cacheNormalizarFecha[rawDateStr] = fechaObj;
      }
      if (!fechaObj || !country) continue;

      // OPTIMIZACIÓN: Cache de formateado de fechas y timezone
      let monthStr = cacheFormatearFecha[rawDateStr];
      if (monthStr === undefined) {
        monthStr = Utilities.formatDate(fechaObj, timeZone, "yyyy-MM-01");
        cacheFormatearFecha[rawDateStr] = monthStr;
      }
      
      mesesProcesados.add(monthStr); // Registramos el mes para exportación estructural posterior

      // OPTIMIZACIÓN: Cache de normalización de nombres de países para evitar normalizar strings miles de veces
      const rawCountryStr = String(country).trim();
      let cleanCountry = cachePaisesLimpios[rawCountryStr];
      if (cleanCountry === undefined) {
        // Mapeo de códigos de país (ej: AR, CL, etc.) a nombres completos permitidos
        const MAPEO_CODIGOS_PAISES = {
          "AR": "Argentina",
          "BO": "Bolivia",
          "CL": "Chile",
          "CR": "Costa Rica",
          "DO": "Republica Dominicana",
          "RD": "Republica Dominicana",
          "EC": "Ecuador",
          "GT": "Guatemala",
          "HN": "Honduras",
          "NI": "Nicaragua",
          "PA": "Panama",
          "UY": "Uruguay",
          "PY": "Paraguay",
          "PE": "Peru",
          "SV": "El Salvador"
        };
        
        const paisNormalizado = rawCountryStr.toUpperCase();
        if (MAPEO_CODIGOS_PAISES[paisNormalizado]) {
          cleanCountry = MAPEO_CODIGOS_PAISES[paisNormalizado];
        } else {
          cleanCountry = GeneralData_Helper_LimpiarTexto(rawCountryStr);
          if (cleanCountry === "Republic Dominican" || cleanCountry === "Dominican Republic") {
            cleanCountry = "Republica Dominicana";
          }
        }
        cachePaisesLimpios[rawCountryStr] = cleanCountry;
      }
      country = cleanCountry;

      // OPTIMIZACIÓN: Cache de validación del país permitido en lugar de volver a iterar arrays
      let esPaisValido = cachePaisesValidos[country];
      if (esPaisValido === undefined) {
        esPaisValido = mapPaisesPermitidosUpper.indexOf(country.toUpperCase()) !== -1;
        cachePaisesValidos[country] = esPaisValido;
      }

      const esHolding = country === "LATAM Holding";
      const esCostaRica = country === "Costa Rica";
      const esExcepcionEBITDA = (esCostaRica || esHolding) && config.nombreHoja === "16 - Analitycs";

      if (!esPaisValido && !esExcepcionEBITDA) continue;

      // --- 1.1 Calcular valores PAÍS ---
      config.metricas.forEach(metrica => {
        if (esExcepcionEBITDA && metrica.name !== "EBITDA") return;

        const key = `${metrica.name}|${country}|${monthStr}`;

        // GUARDAR CONFIGURACIÓN DE COLOR (Si ya lo definimos arriba, respetarlo)
        if (MAPA_COLOR_CONFIG[metrica.name] === undefined) {
          MAPA_COLOR_CONFIG[metrica.name] = (metrica.colorFormating !== undefined) ? metrica.colorFormating : 1;
        }

        if (metrica.usarComponentes && metrica.indicesLatam) {
          if (!MAPA_COMPONENTES_PAIS[key]) {
            MAPA_COMPONENTES_PAIS[key] = new Array(metrica.indicesLatam.length).fill(0);
          }
          metrica.indicesLatam.forEach((idxCol, k) => {
            let val = typeof idxCol === 'function' ? idxCol(fila) : parseFloat(fila[idxCol]);
            MAPA_COMPONENTES_PAIS[key][k] += (val || 0);
          });
          MAPA_FORMATOS[metrica.name] = metrica.format ? metrica.format : "General";
        } else {
          let valor = 0;
          if (metrica.calculo) { 
            try { valor = metrica.calculo(fila); } catch (e) { } 
          } else if (metrica.index !== undefined) { 
            valor = parseFloat(fila[metrica.index]) || 0; 
          }

          if (!MAPA_RESULTADOS[key]) MAPA_RESULTADOS[key] = 0;
          MAPA_RESULTADOS[key] += valor;
          MAPA_FORMATOS[metrica.name] = m = metrica.format ? metrica.format : "General";
        }
      });

      // --- 1.2 Acumular LATAM ---
      if (config.calcularLatam && country.toUpperCase() !== "LATAM") {
        if (!acumuladorLatam[monthStr]) acumuladorLatam[monthStr] = {};

        config.metricas.forEach(m => {
          if (esExcepcionEBITDA && m.name !== "EBITDA") return;

          if (m.indicesLatam && Array.isArray(m.indicesLatam)) {
            const keyComp = m.name + '_components';
            if (!acumuladorLatam[monthStr][keyComp]) {
              acumuladorLatam[monthStr][keyComp] = new Array(m.indicesLatam.length).fill(0);
            }
            m.indicesLatam.forEach((idxCol, k) => {
              let val = typeof idxCol === 'function' ? idxCol(fila) : parseFloat(fila[idxCol]);
              acumuladorLatam[monthStr][keyComp][k] += (val || 0);
            });
          } else {
            let val = 0;
            if (m.calculo) { 
              try { val = m.calculo(fila); } catch (e) { } 
            } else if (m.index !== undefined) { 
              val = parseFloat(fila[m.index]) || 0; 
            }

            if (!acumuladorLatam[monthStr][m.name]) acumuladorLatam[monthStr][m.name] = 0;
            acumuladorLatam[monthStr][m.name] += val;

            if (m.averageLatam) {
              const keyCount = m.name + '_count';
              if (!acumuladorLatam[monthStr][keyCount]) acumuladorLatam[monthStr][keyCount] = 0;
              acumuladorLatam[monthStr][keyCount]++;
            }
          }
        });
      }
    }

    // --- 1.3 Guardar LATAM Final ---
    if (config.calcularLatam) {
      for (const mes in acumuladorLatam) {
        config.metricas.forEach(m => {
          let valLatam = 0;

          if (m.calculoLatam && m.indicesLatam && !m.averageLatam) {
            const comps = acumuladorLatam[mes][m.name + '_components'];
            if (comps) { 
              try { valLatam = m.calculoLatam(comps, mes); } catch (e) { valLatam = 0; } 
            }
          } else if (m.averageLatam) {
            const sumaTotal = acumuladorLatam[mes][m.name] || 0;
            const cantidadPaises = acumuladorLatam[mes][m.name + '_count'] || 0;
            valLatam = safeDiv(sumaTotal, cantidadPaises);
          } else if (acumuladorLatam[mes][m.name] !== undefined) {
            valLatam = acumuladorLatam[mes][m.name];
          }

          const keyLatam = `${m.name}|LATAM|${mes}`;
          MAPA_RESULTADOS[keyLatam] = valLatam;
          MAPA_FORMATOS[m.name] = m.format ? m.format : "General";
        });
      }
    }
  });

  // --- 1.4 PROCESAR COMPONENTES DE PAÍSES (Ratios individuales) ---
  for (const key in MAPA_COMPONENTES_PAIS) {
    const [nombreMetrica, pais, mes] = key.split('|'); 
    let configMetrica = null;
    
    for (let cfg of CONFIG_GD_METRICAS) {
      const encontrada = cfg.metricas.find(m => m.name === nombreMetrica);
      if (encontrada) { configMetrica = encontrada; break; }
    }
    
    if (configMetrica && configMetrica.calculoLatam) {
      const componentes = MAPA_COMPONENTES_PAIS[key];
      try {
        const resultado = configMetrica.calculoLatam(componentes, mes); 
        MAPA_RESULTADOS[key] = resultado;
      } catch (e) {
        MAPA_RESULTADOS[key] = 0;
      }
    }
  }

  // ====================================================================================
  // 2. MÉTRICAS RELACIONADAS (SUMAS, RATIOS Y MULTIPLICACIONES)
  // ====================================================================================
  if (typeof CONFIG_GD_METRICAS_RELACIONADAS !== 'undefined') {

    CONFIG_GD_METRICAS_RELACIONADAS.forEach(rel => {
      const clavesActuales = Object.keys(MAPA_RESULTADOS);
      
      // GUARDAR CONFIGURACIÓN DE COLOR DE MÉTRICAS RELACIONADAS (Si no está definido)
      if (MAPA_COLOR_CONFIG[rel.name] === undefined) {
        MAPA_COLOR_CONFIG[rel.name] = (rel.colorFormating !== undefined) ? rel.colorFormating : 1;
      }

      // --- CASO A: SUMA ---
      if (rel.operation === 'SUM' && rel.components) {
        const procesados = new Set();

        clavesActuales.forEach(key => {
          const parts = key.split('|');
          const nombreMetricaData = parts[0];

          if (rel.components.includes(nombreMetricaData)) {
            const pais = parts[1];
            const mes = parts[2];
            const tagUnico = `${pais}|${mes}`;

            if (!procesados.has(tagUnico)) {
              let sumaTotal = 0;
              rel.components.forEach(comp => {
                const keyComp = `${comp}|${pais}|${mes}`;
                sumaTotal += (MAPA_RESULTADOS[keyComp] || 0);
              });

              const keyNueva = `${rel.name}|${pais}|${mes}`;
              MAPA_RESULTADOS[keyNueva] = sumaTotal;
              MAPA_FORMATOS[rel.name] = rel.format || "General";
              procesados.add(tagUnico);
            }
          }
        });
      }

      // --- CASO B: RATIOS ---
      else if (rel.numerator && rel.denominator) {
        clavesActuales.forEach(key => {
          if (key.startsWith(rel.numerator + "|")) {
            const parts = key.split('|');
            const pais = parts[1];
            const mes = parts[2];
            const keyDenom = `${rel.denominator}|${pais}|${mes}`;

            if (MAPA_RESULTADOS[keyDenom] !== undefined) {
              const valNum = MAPA_RESULTADOS[key];
              const valDen = MAPA_RESULTADOS[keyDenom];
              let resultado = safeDiv(valNum, valDen);

              if (rel.inverseRatio) {
                resultado = valDen !== 0 ? (1 - resultado) : 0;
              }

              const keyNueva = `${rel.name}|${pais}|${mes}`;
              MAPA_RESULTADOS[keyNueva] = resultado;
              MAPA_FORMATOS[rel.name] = rel.format || "General";
            }
          }
        });
      }

      // --- CASO C: MULTIPLICACIÓN ---
      else if (rel.operation === 'MULTIPLY' && rel.factors && rel.factors.length === 2) {
        const factorA = rel.factors[0];
        const factorB = rel.factors[1];

        clavesActuales.forEach(key => {
          if (key.startsWith(factorA + "|")) {
            const parts = key.split('|');
            const pais = parts[1];
            const mes = parts[2];

            const keyB = `${factorB}|${pais}|${mes}`;

            if (MAPA_RESULTADOS[keyB] !== undefined) {
              const valA = MAPA_RESULTADOS[key];
              const valB = MAPA_RESULTADOS[keyB];
              const resultado = valA * valB;

              const keyNueva = `${rel.name}|${pais}|${mes}`;
              MAPA_RESULTADOS[keyNueva] = resultado;
              MAPA_FORMATOS[rel.name] = rel.format || "General";
            }
          }
        });
      }
    });
  }

  // ====================================================================================
  // NUEVO: EXPORTACIÓN DE MÉTRICAS ESTRUCTURALES VACÍAS (Para uso estructural en Sheets)
  // Creamos filas para las métricas que no se calculan aquí, para todos los países y meses
  // ====================================================================================
  const emptyMetrics = [
    { name: 'Free Cash Flow', color: 1 },
    { name: 'Commercial Cycle (DOH - DPO)', color: 1 },
    { name: 'DPO neto de Bonificaciones', color: 1 },
    { name: 'Cash Conversion Cycle (CCC)', color: 1 },
    { name: 'Working Capital', color: 1 }
  ];

  emptyMetrics.forEach(em => {
    MAPA_COLOR_CONFIG[em.name] = em.color;
    PAISES_PERMITIDOS.forEach(p => {
      // Ignoramos LATAM Holding para la exportación de país
      if (p === "LATAM Holding") return;

      mesesProcesados.forEach(m => {
        const key = `${em.name}|${p}|${m}`;
        // Si no fue calculada (que no lo es), la agregamos vacía para estructura en Sheets
        if (MAPA_RESULTADOS[key] === undefined) {
          MAPA_RESULTADOS[key] = ""; // Valor en blanco
          MAPA_FORMATOS[em.name] = "General";
        }
      });
    });
  });

  // ====================================================================================
  // 3. ESCRITURA EN HOJA DESTINO
  // ====================================================================================
  const datosFinales = [];
  const formatosFinales = [];

  for (const key in MAPA_RESULTADOS) {
    const [nombreMetrica, pais, mes] = key.split('|');

    if (!nombreMetrica.includes('_components') &&
        !nombreMetrica.includes('_count') &&
        pais !== "LATAM Holding") { 

      const valor = MAPA_RESULTADOS[key];
      const colorVal = MAPA_COLOR_CONFIG[nombreMetrica] !== undefined ? MAPA_COLOR_CONFIG[nombreMetrica] : 1;

      datosFinales.push([nombreMetrica, pais, mes, valor, colorVal]);
      formatosFinales.push([MAPA_FORMATOS[nombreMetrica] || "General"]);
    }
  }

  let hojaDest = ss.getSheetByName(nombreHojaDestino);
  
  if (!hojaDest) {
    hojaDest = ss.insertSheet(nombreHojaDestino);
  } else {
    GeneralData_Helper_QuitarFiltros(hojaDest);
    hojaDest.clear();
  }

  if (datosFinales.length > 0) {
    hojaDest.getRange(1, 1, 1, 5).setValues([["Metric", "Country", "Month", "Value", "formato de color"]]).setFontWeight("bold");
    hojaDest.getRange(2, 1, datosFinales.length, 5).setValues(datosFinales);
    hojaDest.getRange(2, 4, datosFinales.length, 1).setNumberFormats(formatosFinales);
    hojaDest.getRange(2, 3, datosFinales.length, 1).setNumberFormat("MMM-yyyy");
    Logger.log(`✅ Consolidado General Data creado con ${datosFinales.length} filas (5 columnas).`);
  }
}

function unificarTodasLasTablas() {
  const ss = obtenerSpreadsheetConCache(ID_ARCHIVO_UNICO);

  const hojasOrigen = [
    "Consolidado General Data",
    "Targets Data"
  ];

  const nombreHojaMaestra = "1. MasterConsolidatedData";

  let filasParaPegar = [];
  let formatosParaPegar = []; 

  Logger.log("--- INICIO UNIFICACIÓN CON FORMATOS Y COLOR ---");

  hojasOrigen.forEach(nombre => {
    const hoja = ss.getSheetByName(nombre);
    if (!hoja) {
      Logger.log(`⚠️ ALERTA: No se encontró la hoja '${nombre}'. Se salta.`);
      return;
    }

    const rangoDatos = hoja.getDataRange();
    const datos = rangoDatos.getValues();
    const formatos = rangoDatos.getNumberFormats(); 

    if (datos.length <= 1) return;

    let contadorHoja = 0;

    for (let i = 1; i < datos.length; i++) {
      const fila = datos[i];
      const formatoFila = formatos[i];
      const metric = fila[0]; 

      if (metric && metric.toString().trim() !== "") {
        const colorVal = (fila[4] !== undefined && fila[4] !== "") ? fila[4] : 1;

        const filaLimpia = [
          fila[0], 
          fila[1], 
          fila[2], 
          fila[3], 
          colorVal 
        ];
        filasParaPegar.push(filaLimpia);
        formatosParaPegar.push([formatoFila[3]]);
        contadorHoja++;
      }
    }
    Logger.log(`✅ ${nombre}: Se extrajeron ${contadorHoja} filas.`);
  });

  Logger.log(`Total acumulado: ${filasParaPegar.length} filas.`);

  let hojaMaestra = ss.getSheetByName(nombreHojaMaestra);
  if (!hojaMaestra) {
    hojaMaestra = ss.insertSheet(nombreHojaMaestra);
  }

  hojaMaestra.clear();

  if (filasParaPegar.length > 0) {
    hojaMaestra.getRange(1, 1, 1, 5).setValues([["Metric", "Country", "Month", "Value", "formato de color"]]).setFontWeight("bold");
    hojaMaestra.getRange(2, 1, filasParaPegar.length, 5).setValues(filasParaPegar);
    hojaMaestra.getRange(2, 4, formatosParaPegar.length, 1).setNumberFormats(formatosParaPegar);
    hojaMaestra.getRange(2, 3, filasParaPegar.length, 1).setNumberFormat("MMM-yyyy");

    Logger.log("💾 Datos, Formatos y Colores pegados correctamente.");
  } else {
    Logger.log("⚠️ No se encontraron datos válidos.");
  }
  Logger.log("--- FIN UNIFICACIÓN ---");
}

// Funciones de envíar
function EnviarParte1() {
  console.time("Proceso de Distribución - Parte 1");
  const destinosParte1 = [];

  destinosParte1.push({ id: SOURCE_SPREADSHEET_ID, country: "LATAM" });

  if (typeof DESTINOS_ADICIONALES !== 'undefined') {
    DESTINOS_ADICIONALES.forEach(extra => {
      destinosParte1.push({ id: extra.id, country: "VIP_ACCESS", alias: extra.alias });
    });
  }

  // Dividir los países en 3 partes dinámicas
  const tercio = Math.ceil(PAISES_DE_DESTINO.length / 3);
  const parte1Paises = PAISES_DE_DESTINO.slice(0, tercio);
  parte1Paises.forEach(p => {
    destinosParte1.push({ id: p.id, country: p.country });
  });

  procesarEnvios(destinosParte1);
  console.timeEnd("Proceso de Distribución - Parte 1");
}

function EnviarParte2() {
  console.time("Proceso de Distribución - Parte 2");
  const destinosParte2 = [];

  const tercio = Math.ceil(PAISES_DE_DESTINO.length / 3);
  const parte2Paises = PAISES_DE_DESTINO.slice(tercio, tercio * 2);
  
  parte2Paises.forEach(p => {
    destinosParte2.push({ id: p.id, country: p.country });
  });

  procesarEnvios(destinosParte2);
  console.timeEnd("Proceso de Distribución - Parte 2");
}

function EnviarParte3() {
  console.time("Proceso de Distribución - Parte 3");
  const destinosParte3 = [];

  const tercio = Math.ceil(PAISES_DE_DESTINO.length / 3);
  const parte3Paises = PAISES_DE_DESTINO.slice(tercio * 2);
  
  parte3Paises.forEach(p => {
    destinosParte3.push({ id: p.id, country: p.country });
  });

  procesarEnvios(destinosParte3);
  console.timeEnd("Proceso de Distribución - Parte 3");
}

function procesarEnvios(listaDestinos) {
  const NOMBRE_HOJA_ORIGEN = "1. MasterConsolidatedData"; 
  const NOMBRE_HOJA_DESTINO = "A. TI - Actuals OKRs";

  try {
    if (typeof ID_ARCHIVO_UNICO === 'undefined') throw new Error("La variable 'ID_ARCHIVO_UNICO' no está definida.");
    
    var sourceSpreadsheet = obtenerSpreadsheetConCache(ID_ARCHIVO_UNICO); 
    var sourceSheet = sourceSpreadsheet.getSheetByName(NOMBRE_HOJA_ORIGEN);

    if (!sourceSheet) {
      throw new Error(`La hoja '${NOMBRE_HOJA_ORIGEN}' no se encontró en el archivo Maestro (${ID_ARCHIVO_UNICO}). Asegúrate de correr primero 'unificarTodasLasTablas'.`);
    }

    GeneralData_Helper_QuitarFiltros(sourceSheet);   

    var rawData = sourceSheet.getDataRange().getValues();
    var sourceData = rawData.filter(row => row.join("").length > 0); 

    if (sourceData.length < 2) throw new Error("El Maestro no tiene suficientes datos.");

    var headers = sourceData[0];
    var metricIndex = headers.findIndex(h => h.toString().trim().toUpperCase() === 'METRIC');
    var countryIndex = headers.findIndex(h => h.toString().trim().toUpperCase() === 'COUNTRY');
    var valueIndex = headers.findIndex(h => h.toString().trim().toUpperCase() === 'VALUE');
    var monthIndex = headers.findIndex(h => h.toString().trim().toUpperCase() === 'MONTH'); 

    // OPTIMIZACIÓN DE CPU: Precompilar los metadatos de las filas una sola vez en lugar de hacerlo 15 veces * 30,000 filas.
    var precompiledRows = sourceData.map(function(row, rowIndex) {
      if (rowIndex === 0) return null;
      return {
        isEbitda: row[metricIndex] ? row[metricIndex].toString().trim().toUpperCase() === 'EBITDA' : false,
        countryUpper: row[countryIndex] ? row[countryIndex].toString().trim().toUpperCase() : ''
      };
    });

    listaDestinos.forEach(function(config) {
      try {
        var displayName = config.alias || config.country; 
        var targetType = config.country.trim().toUpperCase(); 

        console.log(`🚀 Actualizando: ${displayName}...`);

        var dataToPaste;
        // OPTIMIZACIÓN: Si es LATAM o VIP_ACCESS, no se clona ni se mapea, se usa directamente el array fuente.
        if (targetType === "LATAM" || targetType === "VIP_ACCESS") {
          dataToPaste = sourceData;
        } else {
          dataToPaste = sourceData.map(function(row, rowIndex) {
            if (rowIndex === 0) return row; 

            var meta = precompiledRows[rowIndex];
            if (meta && meta.isEbitda && meta.countryUpper !== targetType) {
               var newRow = [...row];
               newRow[valueIndex] = ''; 
               return newRow;
            }
            return row; 
          });
        }

        // OPTIMIZACIÓN: Apertura de archivo de destino con caché
        var targetSpreadsheet = obtenerSpreadsheetConCache(config.id);
        var targetSheet = targetSpreadsheet.getSheetByName(NOMBRE_HOJA_DESTINO) || targetSpreadsheet.insertSheet(NOMBRE_HOJA_DESTINO);

        GeneralData_Helper_QuitarFiltros(targetSheet);   

        targetSheet.clearContents(); 
        
        // OPTIMIZACIÓN DE SEGURIDAD: Asegurar que el destino tenga suficientes filas antes de setValues para prevenir errores.
        var maxRows = targetSheet.getMaxRows();
        var totalFilas = dataToPaste.length;
        if (maxRows < totalFilas) {
          targetSheet.insertRowsAfter(maxRows, totalFilas - maxRows);
        }

        targetSheet.getRange(1, 1, dataToPaste.length, dataToPaste[0].length).setValues(dataToPaste); 
        
        var colFecha = (monthIndex > -1) ? monthIndex + 1 : 3; 
        targetSheet.getRange(2, colFecha, dataToPaste.length - 1, 1).setNumberFormat("MMM-yyyy");

        console.log(`   ✅ Completado: ${displayName}`);

      } catch (innerError) {
        console.error(`   ❌ Error en ${config.country}: ${innerError.message}`);
      }
    });

    // OPTIMIZACIÓN SÚPER CRÍTICA: Realizar un único flush al final de todo el lote de envíos
    // para ahorrar latencia de red y evitar llamadas síncronas bloqueantes dentro del bucle.
    SpreadsheetApp.flush();

  } catch (fatalError) {
    console.error("🔴 ERROR FATAL: " + fatalError.message);
  }
}

// --- FUNCIÓNES ATAJO ---
// ==========================================
function importar_consolidad_unificar_enviar() {
    try {
        Logger.log("--- Acordate de actualizar todas las fuentes antes de correr esto.");

        Logger.log("--- Importando la información");
        GeneralData_ImportarTablas()  

        Logger.log("--- Consolidando la informacón (Métricas varias)");
        GeneralData_ConsolidarMetricas();
        
        Logger.log("--- Unificando la informacón (Métricas + Targets)");
        unificarTodasLasTablas();

        Logger.log("--- Enviando la información a los paises (Parte 1)");
        EnviarParte1()

        Logger.log("--- Enviando la información a los paises (Parte 2)");
        EnviarParte2()

        Logger.log("--- Enviando la información a los paises (Parte 3)");
        EnviarParte3()

        Logger.log("Datos enviados a todos los países exitosamente.");
        Logger.log("--- ¡PROCESO COMPLETO Y EXITOSO! ---");

    } catch (e) {
        Logger.log(`Somos pollo, ERROR CRÍTICO en el proceso principal: ${e.message}\n${e.stack}`);
    }
}

function consolidad_unificar_enviar() {
    try {
        Logger.log("--- Acordate de actualizar e importar todas las fuentes antes de correr esto.");

        Logger.log("--- Consolidando la informacón (Métricas varias)");
        GeneralData_ConsolidarMetricas();
        
        Logger.log("--- Unificando la informacón (Métricas + Targets)");
        unificarTodasLasTablas();

        Logger.log("--- Enviando la información a los paises (Parte 1)");
        EnviarParte1()

        Logger.log("--- Enviando la información a los paises (Parte 2)");
        EnviarParte2()

        Logger.log("--- Enviando la información a los paises (Parte 3)");
        EnviarParte3()

        Logger.log("Datos enviados a todos los países exitosamente.");
        Logger.log("--- ¡PROCESO COMPLETO Y EXITOSO! ---");

    } catch (e) {
        Logger.log(`Somos pollo, ERROR CRÍTICO en el proceso principal: ${e.message}\n${e.stack}`);
    }
}

function unificar_enviar() {
    try {
        Logger.log("--- Unificando la informacón (Métricas + Targets)");
        unificarTodasLasTablas();

        Logger.log("--- Enviando la información a los paises (Parte 1)");
        EnviarParte1()

        Logger.log("--- Enviando la información a los paises (Parte 2)");
        EnviarParte2()

        Logger.log("--- Enviando la información a los paises (Parte 3)");
        EnviarParte3()

        Logger.log("Datos enviados a todos los países exitosamente.");
        Logger.log("--- ¡PROCESO COMPLETO Y EXITOSO! ---");

    } catch (e) {
        Logger.log(`Somos pollo, ERROR CRÍTICO en el proceso principal: ${e.message}\n${e.stack}`);
    }
}

function enviartodo () { 
  Logger.log("--- Enviando la información a los paises (Parte 1)");
  EnviarParte1();

  Logger.log("--- Enviando la información a los paises (Parte 2)");
  EnviarParte2();

  Logger.log("--- Enviando la información a los paises (Parte 3)");
  EnviarParte3();
}

// ====================================================================================
// --- FUNCIONES DE PRUEBA ---
// ====================================================================================
function EnviarAlSheetDePrueba() {
  console.time("Proceso de Distribución de Prueba");

  try {
    Logger.log("--- [PRUEBA] Consolidando métricas...");
    GeneralData_ConsolidarMetricas();

    Logger.log("--- [PRUEBA] Unificando tablas...");
    unificarTodasLasTablas();

    Logger.log("--- [PRUEBA] Enviando al Sheet de Prueba...");

    const NOMBRE_HOJA_ORIGEN  = "1. MasterConsolidatedData";
    const NOMBRE_HOJA_DESTINO = "A. TI - Actuals OKRs";
    const ID_SHEET_PRUEBA     = "1dGAwLGz9cRuKmxPylgcPcGDINf2uNFOGMIOcVIuhs3g";
    const BATCH_SIZE          = 5000; 

    if (typeof ID_ARCHIVO_UNICO === 'undefined') throw new Error("'ID_ARCHIVO_UNICO' no está definida.");

    var sourceSheet = obtenerSpreadsheetConCache(ID_ARCHIVO_UNICO)
                                    .getSheetByName(NOMBRE_HOJA_ORIGEN);
    if (!sourceSheet) throw new Error(`La hoja '${NOMBRE_HOJA_ORIGEN}' no existe en el Maestro.`);

    GeneralData_Helper_QuitarFiltros(sourceSheet);   

    var rawData    = sourceSheet.getDataRange().getValues();
    var sourceData = rawData.filter(row => row.join("").length > 0);
    if (sourceData.length < 2) throw new Error("La hoja de origen necesita encabezado y datos.");

    var numCols = sourceData[0].length;

    var targetSS    = obtenerSpreadsheetConCache(ID_SHEET_PRUEBA);
    var targetSheet = targetSS.getSheetByName(NOMBRE_HOJA_DESTINO)
                     || targetSS.insertSheet(NOMBRE_HOJA_DESTINO);

    GeneralData_Helper_QuitarFiltros(targetSheet);   

    targetSheet.clearContents();

    var totalFilas = sourceData.length;
    if (targetSheet.getMaxRows() < totalFilas) {
      targetSheet.insertRowsAfter(targetSheet.getMaxRows(), totalFilas - targetSheet.getMaxRows());
    }

    for (var startRow = 0; startRow < totalFilas; startRow += BATCH_SIZE) {
      var batch = sourceData.slice(startRow, startRow + BATCH_SIZE);
      targetSheet.getRange(startRow + 1, 1, batch.length, numCols).setValues(batch);
      SpreadsheetApp.flush();
      Logger.log(`   📦 Lote escrito: filas ${startRow + 1} → ${startRow + batch.length}`);
    }

    var headers    = sourceData[0];
    var monthIndex = headers.findIndex(h => h.toString().trim().toUpperCase() === 'MONTH');
    var colFecha   = (monthIndex > -1) ? monthIndex + 1 : 3;

    targetSheet.getRange(2, colFecha, totalFilas - 1, 1).setNumberFormat("MMM-yyyy");
    SpreadsheetApp.flush();

    Logger.log(`✅ [PRUEBA] Listo. Total filas enviadas: ${totalFilas - 1}`);

  } catch (error) {
    Logger.log(`❌ ERROR en Sheet de Prueba: ${error.message}\n${error.stack}`);
  }

  console.timeEnd("Proceso de Distribución de Prueba");
}

// --- FUNCIONES DE ENVÍO INDIVIDUAL POR PAÍS ---
// ====================================================================================
function enviar_Argentina() {
  procesarEnvios([{ id: "1rB6CkpTrzmnMGXSMUci2SPIoNBgUaIZQZxr3bEYaTzg", country: "Argentina" }]);
} function enviar_Uruguay() {
  procesarEnvios([{ id: "14cLnA8d09zaoA-Num-yXhmCWqq_TSkx_WbR1DhN6fy8", country: "Uruguay" }]);
} function enviar_Bolivia() {
  procesarEnvios([{ id: "1ftJjSq6fPBH29hir7jb746eF13rQRb3-DDkwEhlSv9U", country: "Bolivia" }]);
} function enviar_Chile() {
  procesarEnvios([{ id: "1dtGRrz4sZUZOzksMQV8yGfZgWbH8n1J7clMeogV_GoY", country: "Chile" }]);
} function enviar_RepublicaDominicana() {
  procesarEnvios([{ id: "1a4gUgeQr5izwQmUTIT8lpyunO_TWWDGLhtlSYinqyWo", country: "Republica Dominicana" }]);
}function enviar_Ecuador() {
  procesarEnvios([{ id: "1NnLsttldtLmbFfLlUcc1-g-n4Un7pQDWu8MoiLPn3To", country: "Ecuador" }]);
}function enviar_ElSalvador() {
  procesarEnvios([{ id: "11M9TRrrW3qyeVT5Tt4JV4t4PC9AwVNWcLYbFsJq2VCk", country: "El Salvador" }]);
}function enviar_Guatemala() {
  procesarEnvios([{ id: "1KYSngPncZVACz6kbLRojUWbBU-XYXebYyJ8ZMM0V5_0", country: "Guatemala" }]);
}function enviar_Honduras() {
  procesarEnvios([{ id: "1N-wNtDJNFsqMeDoOsXMUxK-Q9tVv7lWhS9XKnbIV44U", country: "Honduras" }]);
}function enviar_Nicaragua() {
  procesarEnvios([{ id: "10Z34v86M_79cifmTTfvQVJ-x7pkbAq9y9I1GyyC9daE", country: "Nicaragua" }]);
}function enviar_Panama() {
  procesarEnvios([{ id: "1E7GCIwkyrD2Ple1SALlIeusdY0wuLprJHkLzII6vtvc", country: "Panama" }]);
}function enviar_Paraguay() {
  procesarEnvios([{ id: "1CtwrSQfaR5fp-LI360SUQUmdRz_3ghWMdRFz8gWXhzA", country: "Paraguay" }]);
}function enviar_Peru() {
  procesarEnvios([{ id: "16qF6BsorD-kcHg6p4Acy7a3VdgRRCotjwwH5t8vj9ok", country: "Peru" }]);
}

// Destinos adicionales
function enviar_LATAM() {
  procesarEnvios([{ id: SOURCE_SPREADSHEET_ID, country: "LATAM" }]);
}function enviar_MPCSTeam() {
  procesarEnvios([{ id: "1jn3O8Fkh1AIOeFJaX-2SXPt43FkC0cv6VR3BlkpbNLI", country: "VIP_ACCESS", alias: "MPC S Team" }]);
}function enviar_DmartsPerformanceCommercial() {
  procesarEnvios([{ id: "1cy2rAvbx2Wbnrgn_ArHmzSxhwlAxWBxCbdvAWogg-Bo", country: "VIP_ACCESS", alias: "Dmarts Perfomance Commercial" }]);
}function enviar_AnalisisTempEuge() {
  procesarEnvios([{ id: "1R2dRp9PblfkUnjIp6EqXpHr-qnfbJL30oBkqk5heidU", country: "VIP_ACCESS", alias: "Analisis Temp Euge" }]);
}