// ====================================================================================
// CONFIGURACIÓN GLOBAL
// ====================================================================================
const ID_ARCHIVO_UNICO = "1eNegsxjvy8MRsPjId7uQpdOdEvHgRxRnM6tjuTR3Dro";
const ID_DESTINO       = "10CBChAymE8k09cb_-D_ECD9KriZ0SbSve75IYBU7ZzM";

// ====================================================================================
// CONFIGURACIÓN DE BIGQUERY (Sincronización Directa)
// ====================================================================================
const BQ_PROJECT_ID       = "peya-food-and-groceries";
const BQ_DATASET_ID       = "automated_tables_reports";
const BQ_TABLE_ID         = "wekly_absolute_okrs";          // Tabla de producción especificada
const BQ_TABLE_ID_PRUEBAS = "wekly_absolute_okrs_pruebas";  // Tabla de pruebas

// ====================================================================================
// CACHÉ DE HOJAS DE CÁLCULO (Evita latencias de red repetitivas)
// ====================================================================================
const _ssCache = {};
function getSpreadsheet(id) {
   const cleanId = id.trim();
   if (!_ssCache[cleanId]) {
     _ssCache[cleanId] = SpreadsheetApp.openById(cleanId);
   }
   return _ssCache[cleanId];
}

// ====================================================================================
// FUENTES DE IMPORTACIÓN (CONFIG_GD_IMPORT)
// ====================================================================================
const CONFIG_GD_IMPORT = [
   {
     id_origen: '13yTO_kFzIvISmbSz6p93BFUub1HODpuiGhB3yElZ2fw',
     nombre_hoja_conexion: 'Connection - Mensual',
     nombre_hoja_origen: '2. TD - OKRs Diario',
     nombre_hoja_destino: '1 - Orders'
   },
   {
     id_origen: '1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo',
     nombre_hoja_conexion: 'Connection - Principal',
     nombre_hoja_origen: '2. TD - OPS Data - Diario',
     nombre_hoja_destino: '2 - OPS Data'
   },
   {
     id_origen: '1aCrgEjh6qT5T8ayT2H22r3iNc55nAR1O9vaOCW6pRBs',
     nombre_hoja_conexion: 'Connection - Diario',
     nombre_hoja_origen: '2. ET - SC - Diario',
     nombre_hoja_destino: '3 - Supply Data'
   },
   {
     id_origen: '1TLFRg2ekFUebOYt9J0MmlvL_homtkMFsHMqR3jZRLgY',
     nombre_hoja_conexion: 'Connection - MTD',
     nombre_hoja_origen: '2. ET - MTD Users',
     nombre_hoja_destino: '4 - MTD Users'
   }
];

// ====================================================================================
// CONFIGURACIÓN DE MÉTRICAS (CONFIG_GD_METRICAS)
// ====================================================================================
const CONFIG_GD_METRICAS = [
   { // 1 - Orders (DIARIO)
     nombreHoja: "1 - Orders",
     indices: { date: 0, country: 1 },
     calcularLatam: true,
     esGranularidadDiaria: true,
     metricas: [
       { name: 'Active warehouses',             index: 2,  colorFormating: 1, latam: false },
       { name: 'Confirmed Orders',              index: 3,  colorFormating: 1, latam: false },
       { name: 'Total Platform confirmed Orders', index: 4,  colorFormating: 1, latam: false },
       { name: 'Failed Orders',                 index: 5,  colorFormating: 0, latam: false },
       { name: 'Units Sold',                    index: 6,  colorFormating: 1, latam: false },
       { name: 'Confirmed Orders - Plus',       index: 7, colorFormating: 1, latam: false },
       {
         name: 'Plus Orders %',
         calculo: (f) => safeDiv(f[7], f[3]),
         usarComponentes: true, indicesLatam: [7, 3], calculoLatam: (c) => safeDiv(c[0], c[1]),
         format: '0.00%', colorFormating: 1, latam: true
       },
       { name: 'GMV Vendor Dmarts',    index: 29, colorFormating: 1, latam: false },
       { name: 'GMV Vendor Total',     index: 30, colorFormating: 1, latam: false },
       { name: 'GMV User Dmarts',      index: 27, colorFormating: 1, latam: false },
       { name: 'GMV User Total',       index: 28, colorFormating: 1, latam: false },
       { name: 'Discount Amount',      index: 8, colorFormating: 0, latam: false },
       { name: 'Delivery Fee',         index: 9, colorFormating: 0, latam: false },
       { name: 'Service Fee',          index: 10, colorFormating: 0, latam: false },
       { name: 'Revenue Fee',          index: 11, colorFormating: 0, latam: false },
       { name: 'DF Net',               index: 12, colorFormating: 0, latam: false },
       { name: 'SF Net',               index: 13, colorFormating: 0, latam: false },
       { name: 'RF Net',               index: 14, colorFormating: 0, latam: false },
       { name: 'Discount Plus Net',    index: 15, colorFormating: 0, latam: false },
       { name: 'Free Delivery Fee Orders', index: 16, colorFormating: 0, latam: false },
       { name: 'Voucher Orders',       index: 37, colorFormating: 0, latam: false },
       { name: 'Incentivized Orders',  index: 38, colorFormating: 0, latam: false },
       { name: 'Voucher Amount',       index: 39, colorFormating: 0, latam: false },
       { name: 'Rider CPO Dmarts',     index: 40, colorFormating: 1, latam: false },
       { name: 'Rider CPO Platform (excl Courier)', index: 41, colorFormating: 1, latam: false },
       { name: 'Courier CPO',          index: 42, colorFormating: 1, latam: false },
       { name: 'Platform Orders excl Dmarts', index: 43, colorFormating: 1, latam: false },
       { name: 'Dmart Orders CPO',     index: 44, colorFormating: 1, latam: false },
       { name: 'UF Orders',            index: 17, colorFormating: 1, latam: false },
       { name: 'Net Sales EUR',        index: 18, colorFormating: 1, latam: false },
       { name: 'Discounts EUR',        index: 19, colorFormating: 1, latam: false },
       { name: 'DY Orders',            index: 20, colorFormating: 1, latam: false },
       { name: 'SOF Orders',           index: 21, colorFormating: 1, latam: false },
       { name: 'Units ndy_nsof',       index: 22, colorFormating: 1, latam: false },
       { name: 'Net Sales ndy_nsof',   index: 23, colorFormating: 1, latam: false },
       { name: 'Sessions',             index: 31, colorFormating: 1, latam: false },
       { name: 'transactions',         index: 32, colorFormating: 1, latam: false },
       { name: 'sessions_non_dy',      index: 33, colorFormating: 1, latam: false },
       { name: 'transactions_non_dy',  index: 34, colorFormating: 1, latam: false },
       { name: 'sessions_dy',          index: 35, colorFormating: 1, latam: false },
       { name: 'transactions_dy',      index: 36, colorFormating: 1, latam: false },
       { name: 'instant_need',         index: 24, colorFormating: 1, latam: false },
       { name: 'fill_in',              index: 25, colorFormating: 1, latam: false },
       { name: 'stock_up',             index: 26, colorFormating: 1, latam: false },
       {
         name: 'Incentivized Orders %',
         calculo: (f) => safeDiv(f[38], f[3]),
         usarComponentes: true, indicesLatam: [38, 3], calculoLatam: (c) => safeDiv(c[0], c[1]),
         format: '0.00%', colorFormating: 0, latam: true
       },
       {
         name: 'Basket Size',
         calculo: (f) => safeDiv(f[6], f[3]),
         usarComponentes: true, indicesLatam: [6, 3], calculoLatam: (c) => safeDiv(c[0], c[1]),
         format: '0.00', colorFormating: 1, latam: true
       },
       {
         name: 'GMV User Share Dmarts %',
         calculo: (f) => safeDiv(f[27], f[28]),
         usarComponentes: true, indicesLatam: [27, 28], calculoLatam: (c) => safeDiv(c[0], c[1]),
         format: '0.00000%', colorFormating: 1, latam: true
       },
       {
         name: 'GMV User by Store',
         calculo: (f) => safeDiv(f[28], f[2]),
         usarComponentes: true, indicesLatam: [28, 2], calculoLatam: (c) => safeDiv(c[0], c[1]),
         format: '0.00', colorFormating: 1, latam: true
       }
     ]
   }, { // 2 - OPS Data (DIARIO)
     nombreHoja: "2 - OPS Data",
     indices: { date: 0, country: 1 },
     calcularLatam: true,
     esGranularidadDiaria: true,
     metricas: [
       { name: 'Total_orders_fact_orders',      index: 2,  colorFormating: 1, latam: false },
       { name: 'Total_orders_fact_orders_all_status', index: 3, colorFormating: 1, latam: false },
       { name: 'Seamless Delivery orders',    index: 4,  colorFormating: 1, latam: false },
       { name: 'Seamless Delivery %',
         calculo: (f) => safeDiv(f[4], f[2]),
         usarComponentes: true, indicesLatam: [4, 2], calculoLatam: (c) => safeDiv(c[0], c[1]),
         format: '0.00%', colorFormating: 1, latam: true },
       { name: 'Rejected orders',             index: 5,  colorFormating: 0, latam: false },
       { name: 'Rejected orders %',
         calculo: (f) => safeDiv(f[5], f[2]),
         usarComponentes: true, indicesLatam: [5, 2], calculoLatam: (c) => safeDiv(c[0], c[1]),
         format: '0.00%', colorFormating: 0, latam: true },
       { name: 'Forced Pre Orders',           index: 6,  colorFormating: 0, latam: false },
       { name: 'Forced Pre Orders %',
         calculo: (f) => safeDiv(f[6], f[2]),
         usarComponentes: true, indicesLatam: [6, 2], calculoLatam: (c) => safeDiv(c[0], c[1]),
         format: '0.00%', colorFormating: 0, latam: true },
       { name: 'Modified orders',             index: 7,  colorFormating: 0, latam: false },
       { name: 'Modified orders %',
         calculo: (f) => safeDiv(f[7], f[2]),
         usarComponentes: true, indicesLatam: [7, 2], calculoLatam: (c) => safeDiv(c[0], c[1]),
         format: '0.00%', colorFormating: 0, latam: true },
       { name: 'HC Sessions orders',          index: 8,  colorFormating: 0, latam: false },
       { name: 'HC Sessions orders %',
         calculo: (f) => safeDiv(f[8], f[2]),
         usarComponentes: true, indicesLatam: [8, 2], calculoLatam: (c) => safeDiv(c[0], c[1]),
         format: '0.00%', colorFormating: 0, latam: true },
       { name: 'Slow orders',                 index: 9,  colorFormating: 0, latam: false },
       { name: 'Slow orders %',
         calculo: (f) => safeDiv(f[9], f[2]),
         usarComponentes: true, indicesLatam: [9, 2], calculoLatam: (c) => safeDiv(c[0], c[1]),
         format: '0.00%', colorFormating: 0, latam: true },
       { name: 'Late Orders',                 index: 10, colorFormating: 0, latam: false },
       { name: 'Late Orders %',
         calculo: (f) => safeDiv(f[10], f[2]),
         usarComponentes: true, indicesLatam: [10, 2], calculoLatam: (c) => safeDiv(c[0], c[1]),
         format: '0.00%', colorFormating: 0, latam: true },
       { name: 'Assignment Time total',       index: 11, colorFormating: 1, latam: false },
       { name: 'Picking Time',                index: 12, colorFormating: 1, latam: false },
       { name: 'non_forced_completed_orders_logistics', index: 13, colorFormating: 1, latam: false },
       { name: 'Delivery Time total',         index: 14, colorFormating: 1, latam: false },
       { name: 'Stacked 0 orders',            index: 15, colorFormating: 1, latam: false },
       { name: 'Stacked 1 orders',            index: 16, colorFormating: 1, latam: false },
       { name: 'stacked 2 orders',            index: 17, colorFormating: 1, latam: false },
       { name: 'stacked 3 or more orders',    index: 18, colorFormating: 1, latam: false },
       { name: 'Total Stacked Orders',
         calculo: (f) => (parseFloat(f[16]) || 0) + (parseFloat(f[17]) || 0) + (parseFloat(f[18]) || 0),
         format: '#,##0', colorFormating: 1, latam: true },
       { name: 'Total_orders_timings',        index: 19, colorFormating: 1, latam: false },
       { name: 'Assignment Time',
         calculo: (f) => safeDiv(f[11], f[2]),
         usarComponentes: true, indicesLatam: [11, 19], calculoLatam: (c) => safeDiv(c[0], c[1]),
         format: '0.00', colorFormating: 0, latam: true },
       { name: 'Picked_items',                index: 20, colorFormating: 1, latam: false },
       { name: 'Item Picking Time',           index: 21, colorFormating: 0, latam: false },
       { name: 'Order late 10 orders',        index: 22, colorFormating: 0, latam: false },
       { name: 'Delivery time > 35 min orders', index: 23, colorFormating: 0, latam: false },
       { name: 'Delivery time > 35 min %',
         calculo: (f) => safeDiv(f[23], f[2]),
         usarComponentes: true, indicesLatam: [23, 2], calculoLatam: (c) => safeDiv(c[0], c[1]),
         format: '0.00%', colorFormating: 0, latam: true },
       { name: 'vendor_late_count',           index: 24, colorFormating: 0, latam: false },
       { name: 'vendor_late_deno',            index: 25, colorFormating: 1, latam: false },
       { name: 'Vendor Late > 10 %',
         calculo: (f) => safeDiv(f[24], f[25]),
         usarComponentes: true, indicesLatam: [24, 25], calculoLatam: (c) => safeDiv(c[0], c[1]),
         format: '0.00%', colorFormating: 0, latam: true },
       { name: 'Total orders inaccuracy',     index: 26, colorFormating: 1, latam: false },
       { name: 'Inaccuracy Orders',           index: 27, colorFormating: 0, latam: false },
       { name: 'Inaccuracy %',
         calculo: (f) => safeDiv(f[27], f[2]),
         usarComponentes: true, indicesLatam: [27, 2], calculoLatam: (c) => safeDiv(c[0], c[1]),
         format: '0.00%', colorFormating: 0, latam: true },
       { name: 'Food Issue Orders',           index: 28, colorFormating: 0, latam: false },
       { name: 'Item Issue Orders',           index: 29, colorFormating: 0, latam: false },
       { name: 'Inaccuracy Product %',
         calculo: (f) => safeDiv((parseFloat(f[28]) || 0) + (parseFloat(f[29]) || 0), f[27]),
         usarComponentes: true, indicesLatam: [28, 29, 27], calculoLatam: (c) => safeDiv(c[0] + c[1], c[2]),
         format: '0.00%', colorFormating: 0, latam: true },

       // === 30: Picking units (Helper_Total_Units) ===
       { name: 'Picking units',               index: 30, colorFormating: 1, latam: false },

       // === 31: Receiving units ===
       { name: 'Receiving units',             index: 31, colorFormating: 1, latam: false },

       // === 32: Ajuste utr ===
       { name: 'Ajuste utr',                  index: 32, colorFormating: 1, latam: true },

       // === 33: Picker working hours ===
       { name: 'Picker working hours',        index: 33, colorFormating: 1, latam: false },

       // === 34: Manager working hours ===
       { name: 'Manager working hours',       index: 34, colorFormating: 1, latam: false },

       // === 35: Total_orders_ops ===
       { name: 'Total_orders_ops',            index: 35, colorFormating: 1, latam: false },

       // === 36: Partial orders ===
       { name: 'Partial orders',              index: 36, colorFormating: 0, latam: false },

       // === 37: Lost orders (lost_sessions) ===
       { name: 'Lost orders',                 index: 37, colorFormating: 0, latam: false },

       // === 38: Assignment Time > 6 min orders
       { name: 'Assignment Time > 6 min orders',           index: 38, colorFormating: 0, latam: false },

       // === 39: Received bags ===
       { name: 'Received bags',               index: 39, colorFormating: 1, latam: false }
     ]
   }, { // 3 - Supply Data
     nombreHoja: "3 - Supply Data",
     indices: { date: 0, country: 2 },
     calcularLatam: true,
     esGranularidadDiaria: true,
     metricas: [
       { name: 'WIS Denominador', index: 3, colorFormating: 1, latam: false },
       { name: 'WIS Numerador',   index: 4, colorFormating: 1, latam: false },
       {
         name: 'WIS %',
         calculo: (f) => safeDiv(f[4], f[3]),
         usarComponentes: false,
         indicesLatam: [4, 3],
         calculoLatam: (c) => safeDiv(c[0], c[1]),
         format: '0.00%',
         colorFormating: 1, latam: false
       },
       { name: 'WIS UF Denominador', index: 6, colorFormating: 1, latam: false },
       { name: 'WIS UF Numerador',   index: 7, colorFormating: 1, latam: false },
       {
         name: 'WIS UF %',
         calculo: (f) => safeDiv(f[7], f[6]),
         usarComponentes: true,
         indicesLatam: [7, 6],
         calculoLatam: (c) => safeDiv(c[0], c[1]),
         format: '0.00%',
         colorFormating: 1, latam: true
       },
       { name: 'Peya Issues Numerador',   index: 9,  colorFormating: 0, latam: false },
       { name: 'Peya Issues Denominador', index: 10, colorFormating: 1, latam: false },
       {
         name: 'Peya Issues %',
         calculo: (f) => safeDiv(f[9], f[10]),
         usarComponentes: true,
         indicesLatam: [9, 10],
         calculoLatam: (c) => safeDiv(c[0], c[1]),
         format: '0.00%',
         colorFormating: 0,
         latam: true
       },
       { name: 'Peya Issues UF Numerador',   index: 12, colorFormating: 0, latam: false },
       { name: 'Peya Issues UF Denominador', index: 13, colorFormating: 1, latam: false },
       {
         name: 'Peya Issues UF %',
         calculo: (f) => safeDiv(f[12], f[13]),
         usarComponentes: true,
         indicesLatam: [12, 13],
         calculoLatam: (c) => safeDiv(c[0], c[1]),
         format: '0.00%',
         colorFormating: 0,
         latam: true
       },
       { name: 'Supplier Issues Numerador',   index: 15, colorFormating: 0, latam: false },
       { name: 'Supplier Issues Denominador', index: 16, colorFormating: 1, latam: false },
       {
         name: 'Supplier Issues %',
         calculo: (f) => safeDiv(f[15], f[16]),
         usarComponentes: true,
         indicesLatam: [15, 16],
         calculoLatam: (c) => safeDiv(c[0], c[1]),
         format: '0.00%',
         colorFormating: 0,
         latam: true
       },
       { name: 'Supplier Issues UF Numerador',   index: 18, colorFormating: 0, latam: false },
       { name: 'Supplier Issues UF Denominador', index: 19, colorFormating: 1, latam: false },
       {
         name: 'Supplier Issues UF %',
         calculo: (f) => safeDiv(f[18], f[19]),
         usarComponentes: true,
         indicesLatam: [18, 19],
         calculoLatam: (c) => safeDiv(c[0], c[1]),
         format: '0.00%',
         colorFormating: 0,
         latam: true
       }
     ]
   }, { // 4 - MTD Users
     nombreHoja: "4 - MTD Users",
     indices: { date: 0, country: 2 },
     calcularLatam: true,
     esGranularidadDiaria: true,
     metricas: [
       { name: 'PeYa MAUs - MTD',       index: 3, colorFormating: 1, latam: true },
       { name: 'Dmart MAUs - MTD',      index: 4, colorFormating: 1, latam: true },
       { name: 'Dmart MAUs - Plus - MTD', index: 5, colorFormating: 1, latam: true },
       { name: 'New Users - Dmart - MTD',  index: 6, colorFormating: 1, latam: true },
     ]
   }
];

// ====================================================================================
// FORMATO DE COLOR PARA MÉTRICAS ADICIONALES (1: Buena / 0: Mala)
// Solo para asignar formato de color en consolidado sin definir extracción de hojas
// ====================================================================================
const CONFIG_COLOR_METRICAS_EXTRA = {
  'Weighted Open time %': 1,
  'WHS minutes schedule': 1,
  'WHS minutes closed':   0,
  'Open Time Simple':     1
};

// ====================================================================================
// REFRESCAR FUENTES
// ====================================================================================
function RefreshAllSources() {
   Logger.log("🔄 INICIO: Refrescando extractos (Data Source Tables) en PARALELO...");
   const TIEMPO_ESPERA_MAX = 300;

   try { SpreadsheetApp.enableBigQueryExecution(); } catch (e) {
     Logger.log("⚠️ No se pudo habilitar BigQueryExecution.");
   }

   const archivos = {};
   if (typeof CONFIG_GD_IMPORT !== 'undefined') {
     CONFIG_GD_IMPORT.forEach(c => {
       if (c.id_origen && !c.id_origen.includes("PENDIENTE")) {
         const id = c.id_origen.trim();
         if (!archivos[id]) archivos[id] = { hojasExtracto: new Set() };
         if (c.nombre_hoja_origen) archivos[id].hojasExtracto.add(c.nombre_hoja_origen);
       }
     });
   }

   const activeRefreshes = [];

   Object.keys(archivos).forEach(id => {
     try {
       const ssExterna = getSpreadsheet(id);
       archivos[id].hojasExtracto.forEach(nombreHoja => {
         const sheet = ssExterna.getSheetByName(nombreHoja);
         if (!sheet) return;
         const tables = sheet.getDataSourceTables();
         tables.forEach((table, index) => {
           try {
             const execution = table.refreshData();
             activeRefreshes.push({ execution: execution, descripcion: `tabla ${index + 1} de '${nombreHoja}'` });
           } catch (e) { }
         });
       });
     } catch (e) { Logger.log(`❌ Error crítico al abrir ID ${id}: ${e.message}`); }
   });

   activeRefreshes.forEach(item => {
     try { item.execution.waitForCompletion(TIEMPO_ESPERA_MAX); } catch (e) {}
   });
   Logger.log("🔄 FIN TOTAL: Refresco completado.");
}

// ====================================================================================
// HELPERS Y UTILIDADES
// ====================================================================================
function safeDiv(num, den) {
   const n = parseFloat(typeof num === 'string' ? num.replace(/,/g, '') : num);
   const d = parseFloat(typeof den === 'string' ? den.replace(/,/g, '') : den);
   if (isNaN(n) || isNaN(d) || d === 0) return 0;
   return n / d;
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

function GeneralData_Helper_EsFechaPermitida(fechaObj) {
   if (!fechaObj) return false;
   const hoy = new Date();
   const anioActual = hoy.getFullYear();
   const anioPasado = anioActual - 1;
   const mesActual = hoy.getMonth();
   const mesesPermitidos = [];
   for (let i = 0; i < 5; i++) {
     let m = mesActual - i;
     if (m < 0) m = m + 12;
     mesesPermitidos.push(m);
   }
   const anioFecha = fechaObj.getFullYear();
   const mesFecha  = fechaObj.getMonth();
   if (anioFecha === anioActual || anioFecha === anioPasado) {
     return mesesPermitidos.includes(mesFecha);
   }
   return false;
}

function getISOWeekNumber(fechaRaw) {
   const d = GeneralData_Helper_NormalizarFecha(fechaRaw);
   if (!d) return null;
   const thursday = new Date(d);
   thursday.setDate(d.getDate() - ((d.getDay() + 6) % 7) + 3);
   const firstThursday = new Date(thursday.getFullYear(), 0, 4);
   firstThursday.setDate(4 - ((firstThursday.getDay() + 6) % 7));
   return 1 + Math.round((thursday - firstThursday) / 604800000);
}

function GeneralData_Helper_QuitarFiltros(sheet) {
   if (!sheet) return;
   try { const filtro = sheet.getFilter(); if (filtro) filtro.remove(); } catch (e) {}
}

function GeneralData_Helper_Importar(conf, ssDestino, reintentos = 2) {
   for (let intento = 1; intento <= reintentos; intento++) {
     try {
       const ssOrigen  = getSpreadsheet(conf.id_origen);
       const hojaOrigen = ssOrigen.getSheetByName(conf.nombre_hoja_origen);
       if (!hojaOrigen) {
         Logger.log(`❌ No existe '${conf.nombre_hoja_origen}' en el archivo origen.`);
         return;
       }
       const datos = hojaOrigen.getDataRange().getValues();
       if (datos.length === 0) {
         Logger.log(`⚠️ Hoja origen '${conf.nombre_hoja_origen}' vacía.`);
         return;
       }

       let hojaDest = ssDestino.getSheetByName(conf.nombre_hoja_destino);
       if (!hojaDest) hojaDest = ssDestino.insertSheet(conf.nombre_hoja_destino);

       GeneralData_Helper_QuitarFiltros(hojaDest);
       hojaDest.clearContents();

       const maxRows = hojaDest.getMaxRows();
       const maxCols = hojaDest.getMaxColumns();
       const reqRows = datos.length;
       const reqCols = datos[0].length;

       if (maxRows < reqRows) {
         hojaDest.insertRowsAfter(maxRows, reqRows - maxRows);
       }
       if (maxCols < reqCols) {
         hojaDest.insertColumnsAfter(maxCols, reqCols - maxCols);
       }

       hojaDest.getRange(1, 1, reqRows, reqCols).setValues(datos);

       const filasActuales = hojaDest.getMaxRows();
       if (filasActuales > reqRows + 5000) {
         try {
           hojaDest.deleteRows(reqRows + 1, filasActuales - reqRows);
         } catch (_) {}
       }

       Logger.log(`✅ Importado: '${conf.nombre_hoja_destino}' (${reqRows} filas, ${reqCols} columnas)`);
       return;
     } catch (e) {
       Logger.log(`⚠️ Intento ${intento}/${reintentos} falló en '${conf.nombre_hoja_destino}': ${e.message}`);
       if (intento < reintentos) {
         Utilities.sleep(3000);
         SpreadsheetApp.flush();
         delete _ssCache[ID_ARCHIVO_UNICO.trim()];
         ssDestino = getSpreadsheet(ID_ARCHIVO_UNICO);
       } else {
         Logger.log(`❌ Error definitivo importando '${conf.nombre_hoja_destino}': ${e.message}`);
       }
     }
   }
}

// ====================================================================================
// 1. IMPORTAR TABLAS EXTERNAS
// ====================================================================================
function GeneralData_ImportarTablas() {
   const ssDestino = getSpreadsheet(ID_ARCHIVO_UNICO);
   Logger.log("... Importando tablas externas ...");
   CONFIG_GD_IMPORT.forEach(conf => {
     if (!conf.id_origen.includes("PENDIENTE")) {
       GeneralData_Helper_Importar(conf, ssDestino);
     }
   });
}

// ====================================================================================
// 2. CONSOLIDAR MÉTRICAS (RETORNA ARRAY PARA BIGQUERY EN LUGAR DE ESCRIBIR EN SHEETS)
// ====================================================================================
function GeneralData_ConsolidarMetricas() {
   const ss = getSpreadsheet(ID_ARCHIVO_UNICO);
   const timeZone = ss.getSpreadsheetTimeZone();
   Logger.log("... Generando Consolidado de Datos en Memoria");

   const MAPA_RESULTADOS       = {};
   const MAPA_COMPONENTES_PAIS = {};
   const MAPA_COLOR_CONFIG     = {};
   const MAPA_GRANULARIDAD     = {};

   const cacheFechas  = {};
   const cachePaises  = {};
   const cacheSemanas = {};

   const PAISES_PERMITIDOS = [
     "LATAM", "Argentina", "Bolivia", "Chile", "Republica Dominicana",
     "Ecuador", "El Salvador", "Guatemala", "Honduras",
     "Nicaragua", "Panama", "Paraguay", "Peru", "Uruguay"
   ];
   const PAISES_UPPER = PAISES_PERMITIDOS.map(p => p.toUpperCase());

   CONFIG_GD_METRICAS.forEach(config => {
     config.metricas.forEach(metrica => {
       MAPA_COLOR_CONFIG[metrica.name] = metrica.colorFormating ?? 1;
       MAPA_GRANULARIDAD[metrica.name] = config.esGranularidadDiaria ?? false;
     });
   });

   CONFIG_GD_METRICAS.forEach(config => {
     const hoja = ss.getSheetByName(config.nombreHoja);
     if (!hoja) return;

     const datos = hoja.getDataRange().getValues();
     if (datos.length <= 1) return;

     const acumuladorLatam = {};
     const idxFecha   = config.indices.date ?? config.indices.month;
     const idxCountry = config.indices.country;
     const formatoFecha = config.esGranularidadDiaria ? "yyyy-MM-dd" : "yyyy-MM-01";

     for (let i = 1; i < datos.length; i++) {
       const fila = datos[i];
       const rawDate = fila[idxFecha];
       let   country = fila[idxCountry];
       if (!rawDate || !country) continue;

       const cacheKeyFecha = rawDate + "_" + config.esGranularidadDiaria;
       let dateStr = cacheFechas[cacheKeyFecha];
       if (dateStr === undefined) {
         const fechaObj = GeneralData_Helper_NormalizarFecha(rawDate);
         if (fechaObj && GeneralData_Helper_EsFechaPermitida(fechaObj)) {
           dateStr = Utilities.formatDate(fechaObj, timeZone, formatoFecha);
         } else {
           dateStr = null;
         }
         cacheFechas[cacheKeyFecha] = dateStr;
       }
       if (!dateStr) continue;

       const rawCountryStr = String(country).trim();
       let countryClean = cachePaises[rawCountryStr];
       if (countryClean === undefined) {
         const MAPEO_CODIGOS_PAISES = {
           "AR": "Argentina", "BO": "Bolivia", "CL": "Chile", "CR": "Costa Rica",
           "DO": "Republica Dominicana", "RD": "Republica Dominicana", "EC": "Ecuador",
           "GT": "Guatemala", "HN": "Honduras", "NI": "Nicaragua", "PA": "Panama",
           "UY": "Uruguay", "PY": "Paraguay", "PE": "Peru", "SV": "El Salvador"
         };
         const paisNormalizado = rawCountryStr.toUpperCase();
         if (MAPEO_CODIGOS_PAISES[paisNormalizado]) {
           countryClean = MAPEO_CODIGOS_PAISES[paisNormalizado];
         } else {
           countryClean = GeneralData_Helper_LimpiarTexto(rawCountryStr);
           if (countryClean === "Republic Dominican" || countryClean === "Dominican Republic") {
             countryClean = "Republica Dominicana";
           }
         }
         cachePaises[rawCountryStr] = countryClean;
       }

       const esPaisValido = PAISES_UPPER.includes(countryClean.toUpperCase());
       if (!esPaisValido) continue;

       config.metricas.forEach(metrica => {
         const key = `${metrica.name}|${countryClean}|${dateStr}`;
         if (metrica.usarComponentes && metrica.indicesLatam) {
           if (!MAPA_COMPONENTES_PAIS[key]) {
             MAPA_COMPONENTES_PAIS[key] = new Array(metrica.indicesLatam.length).fill(0);
           }
           metrica.indicesLatam.forEach((idxCol, k) => {
             const val = typeof idxCol === 'function' ? idxCol(fila) : parseFloat(fila[idxCol]);
             MAPA_COMPONENTES_PAIS[key][k] += (val || 0);
           });
         } else {
           let valor = 0;
           if (metrica.calculo) {
             try { valor = metrica.calculo(fila); } catch (_) { valor = 0; }
           } else if (metrica.index !== undefined) {
             valor = parseFloat(fila[metrica.index]) || 0;
           }
           if (MAPA_RESULTADOS[key] === undefined) MAPA_RESULTADOS[key] = 0;
           MAPA_RESULTADOS[key] += valor;
         }
       });

       if (config.calcularLatam && countryClean.toUpperCase() !== "LATAM") {
         if (!acumuladorLatam[dateStr]) acumuladorLatam[dateStr] = {};
         config.metricas.forEach(m => {
           if (!m.latam) return;
           if (m.indicesLatam && Array.isArray(m.indicesLatam)) {
             const keyComp = m.name + '_components';
             if (!acumuladorLatam[dateStr][keyComp]) acumuladorLatam[dateStr][keyComp] = new Array(m.indicesLatam.length).fill(0);
             m.indicesLatam.forEach((idxCol, k) => {
               const val = typeof idxCol === 'function' ? idxCol(fila) : parseFloat(fila[idxCol]);
               acumuladorLatam[dateStr][keyComp][k] += (val || 0);
             });
           } else {
             let val = 0;
             if (m.calculo) { try { val = m.calculo(fila); } catch (_) { val = 0; } } 
             else if (m.index !== undefined) { val = parseFloat(fila[m.index]) || 0; }
             if (acumuladorLatam[dateStr][m.name] === undefined) acumuladorLatam[dateStr][m.name] = 0;
             acumuladorLatam[dateStr][m.name] += val;
           }
         });
       }
     }

     if (config.calcularLatam) {
       for (const fecha in acumuladorLatam) {
         config.metricas.forEach(m => {
           if (!m.latam) return;
           let valLatam = 0;
           if (m.calculoLatam && m.indicesLatam) {
             const comps = acumuladorLatam[fecha][m.name + '_components'];
             if (comps) { try { valLatam = m.calculoLatam(comps, fecha); } catch (_) { valLatam = 0; } }
           } else if (acumuladorLatam[fecha][m.name] !== undefined) {
             valLatam = acumuladorLatam[fecha][m.name];
           }
           MAPA_RESULTADOS[`${m.name}|LATAM|${fecha}`] = valLatam;
         });
       }
     }
   });

   for (const key in MAPA_COMPONENTES_PAIS) {
     const [nombreMetrica] = key.split('|');
     let configMetrica = null;
     for (const cfg of CONFIG_GD_METRICAS) {
       const encontrada = cfg.metricas.find(m => m.name === nombreMetrica);
       if (encontrada) { configMetrica = encontrada; break; }
     }
     if (configMetrica?.calculoLatam) {
       try { MAPA_RESULTADOS[key] = configMetrica.calculoLatam(MAPA_COMPONENTES_PAIS[key]); } 
       catch (_) { MAPA_RESULTADOS[key] = 0; }
     }
   }

   // ====================================================================================
   // EXPORTACIÓN DE PLACEHOLDER PARA 'Weighted Open time %' (Valor 0, Color 1)
   // ====================================================================================
   MAPA_GRANULARIDAD['Weighted Open time %'] = true;
   MAPA_COLOR_CONFIG['Weighted Open time %'] = 1;

   const fechasConsolidadas = new Set();
   for (const k in MAPA_RESULTADOS) {
     const p = k.split('|');
     if (p[2]) fechasConsolidadas.add(p[2]);
   }

   if (fechasConsolidadas.size === 0) {
     const hoyStr = Utilities.formatDate(new Date(), timeZone, "yyyy-MM-dd");
     fechasConsolidadas.add(hoyStr);
   }

   fechasConsolidadas.forEach(fecha => {
     PAISES_PERMITIDOS.forEach(pais => {
       const keyOpenTime = `Weighted Open time %|${pais}|${fecha}`;
       if (MAPA_RESULTADOS[keyOpenTime] === undefined) {
         MAPA_RESULTADOS[keyOpenTime] = 0;
       }
     });
   });

   const datosFinales = [];
   for (const key in MAPA_RESULTADOS) {
     const [nombreMetrica, pais, dateStr] = key.split('|');
     if (nombreMetrica.includes('_components') || nombreMetrica.includes('_count') || pais === "LATAM Holding") continue;

     const colorVal = MAPA_COLOR_CONFIG[nombreMetrica] ?? 1;
     const esDiaria = MAPA_GRANULARIDAD[nombreMetrica] ?? false;

     let weekNumber = null;
     if (esDiaria) {
       weekNumber = cacheSemanas[dateStr];
       if (weekNumber === undefined) {
         weekNumber = getISOWeekNumber(dateStr);
         cacheSemanas[dateStr] = weekNumber;
       }
     }
     datosFinales.push([nombreMetrica, pais, dateStr, weekNumber, MAPA_RESULTADOS[key], colorVal]);
   }

   Logger.log(`✅ Consolidado calculado en memoria con ${datosFinales.length} filas.`);
   return datosFinales;
}

// ====================================================================================
// 3. SUBIR DIRECTAMENTE A BIGQUERY (Evitando Google Sheets límite)
// ====================================================================================
function enviar_a_bigquery(datos, tableId) {
  if (!datos || datos.length === 0) {
    Logger.log("⚠️ No hay datos para enviar a BigQuery.");
    return;
  }
  
  Logger.log(`🚀 Preparando carga de ${datos.length} filas a BigQuery (Tabla: ${tableId})...`);
  
  // 1. Construir CSV en memoria
  let csv = "Metric,Country,Date,Week_Number,Value,Color_Formatting\n";
  for (let i = 0; i < datos.length; i++) {
    let [metric, country, date, week, value, color] = datos[i];
    
    // Escapar para que el CSV sea válido
    metric = `"${String(metric).replace(/"/g, '""')}"`;
    country = `"${String(country).replace(/"/g, '""')}"`;
    
    // Convertir nulos o datos vacíos
    date = date ? date : "";
    week = (week !== null && week !== undefined) ? week : "";
    value = (value === null || value === undefined || isNaN(value) || !isFinite(value)) ? 0 : value;
    color = (color !== null && color !== undefined) ? color : "";
    
    csv += `${metric},${country},${date},${week},${value},${color}\n`;
  }
  
  // 2. Crear Blob de archivo Virtual
  const blob = Utilities.newBlob(csv, "application/octet-stream");
  
  // 3. Configurar trabajo de carga de BigQuery
  const job = {
    configuration: {
      load: {
        destinationTable: {
          projectId: BQ_PROJECT_ID,
          datasetId: BQ_DATASET_ID,
          tableId: tableId
        },
        sourceFormat: 'CSV',
        skipLeadingRows: 1, // Salta la cabecera del CSV
        writeDisposition: 'WRITE_TRUNCATE', // REEMPLAZA todos los datos de la tabla.
        autodetect: false,
        schema: {
          fields: [
            { name: 'Metric', type: 'STRING' },
            { name: 'Country', type: 'STRING' },
            { name: 'Date', type: 'DATE' },
            { name: 'Week_Number', type: 'INTEGER' },
            { name: 'Value', type: 'FLOAT' },
            { name: 'Color_Formatting', type: 'INTEGER' }
          ]
        }
      }
    }
  };
  
  // 4. Iniciar la carga
  try {
    const runJob = BigQuery.Jobs.insert(job, BQ_PROJECT_ID, blob);
    Logger.log(`✅ Carga a BigQuery iniciada correctamente. ID de Trabajo: ${runJob.id}`);
  } catch (err) {
    Logger.log(`❌ Error al subir a BigQuery: ${err.message}`);
    throw err;
  }
}

// ====================================================================================
// 4. FUNCIONES MAESTRAS DE EJECUCIÓN (PRODUCCIÓN Y PRUEBAS)
// ====================================================================================
function Ejecutar_Proceso_Total() {
   Logger.log("🚀 INICIANDO PROCESO COMPLETO A BIGQUERY...");
   
   Logger.log("👉 Paso 1/3: Importando tablas externas (Orders, OPS, Supply)...");
   GeneralData_ImportarTablas();

   Logger.log("👉 Paso 2/3: Calculando métricas en memoria (Sin tocar Google Sheets)...");
   const datos = GeneralData_ConsolidarMetricas();

   Logger.log("👉 Paso 3/3: Subiendo datos finales a BigQuery (Producción)...");
   enviar_a_bigquery(datos, BQ_TABLE_ID);

   Logger.log("🏆 ¡PROCESO TOTAL COMPLETADO CON ÉXITO!");
}

function GeneralData_ConsolidarYEnviar() {
   Logger.log("🔄 Iniciando proceso abreviado: Consolidar y Enviar...");
   const datos = GeneralData_ConsolidarMetricas();
   enviar_a_bigquery(datos, BQ_TABLE_ID);
   Logger.log("🏆 ¡Consolidación y envío completados con éxito!");
}

// ====================================================================================
// HOJA DE PRUEBAS
// ====================================================================================
const ID_DESTINO_PRUEBAS = "1GO3jcGh8dSPz33A7KDyWASxPX8hYxWgIfbRuGgwqtC8";

/**
 * Purga pestañas residuales y recorta filas y columnas vacías para mantener
 * el libro de destino muy por debajo del límite de 10.000.000 de celdas de Google Sheets.
 */
function purgarCeldasExcedentes(ss) {
   try {
     const hojas = ss.getSheets();
     hojas.forEach(hoja => {
       const nombre = hoja.getName();
       if (nombre.includes("_temp") || nombre.includes("_backup") || nombre.includes("_nueva") || nombre.includes("_clon") || nombre.includes("_delete")) {
         if (ss.getSheets().length > 1) {
           try { ss.deleteSheet(hoja); } catch (_) {}
         }
       } else {
         const maxR = hoja.getMaxRows();
         const lastR = Math.max(hoja.getLastRow(), 1);
         if (maxR > lastR + 5) {
           try { hoja.deleteRows(lastR + 6, maxR - (lastR + 5)); } catch (_) {}
         }
         const maxC = hoja.getMaxColumns();
         const lastC = Math.max(hoja.getLastColumn(), 1);
         if (maxC > lastC + 5) {
           try { hoja.deleteColumns(lastC + 6, maxC - (lastC + 5)); } catch (_) {}
         }
       }
     });
     SpreadsheetApp.flush();
   } catch (e) {
     Logger.log(`   ⚠️ Nota en purgarCeldasExcedentes: ${e.message}`);
   }
}

/**
 * Helper para localizar una hoja por su nombre o por su GID numérico.
 */
function Helper_ObtenerHoja(ss, nombre, gid) {
   if (nombre) {
     const h = ss.getSheetByName(nombre);
     if (h) return h;
   }
   if (gid !== null && gid !== undefined) {
     const targetGid = parseInt(gid, 10);
     const h = ss.getSheets().find(sheet => sheet.getSheetId() === targetGid);
     if (h) return h;
   }
   return null;
}

/**
 * Recarga una página en PRUEBAS eliminando la versión previa en destino
 * y creando una copia fiel e independiente con fórmulas, valores, formatos y diseño.
 * Es 100% compatible con libros que contienen hojas DATASOURCE (BigQuery).
 * Permite buscar la hoja origen por nombre o por GID (ej: gid=1241281327)
 * y en destino por nombre o por GID previo (ej: gid=213814536).
 */
function recargarPaginaEnPruebas(ssOrigen, ssDestino, configHoja) {
   const nombreDefecto = typeof configHoja === 'string' ? configHoja : configHoja.nombre;
   const gidOrigen     = typeof configHoja === 'object' ? configHoja.gidOrigen : null;
   const gidDestino    = typeof configHoja === 'object' ? configHoja.gidDestino : null;

   try {
     Logger.log(`--- 🧪 Iniciando recarga de '${nombreDefecto}' (GID Origen: ${gidOrigen || 'N/A'})...`);
     const hojaOrigen = Helper_ObtenerHoja(ssOrigen, nombreDefecto, gidOrigen);
     if (!hojaOrigen) {
       throw new Error(`No se encontró la hoja de origen (Nombre: '${nombreDefecto}', GID: ${gidOrigen}) en ${ssOrigen.getName()}.`);
     }

     const nombreRealHoja = hojaOrigen.getName();
     const posicionOrigen = hojaOrigen.getIndex();

     // 1. Eliminar la hoja previa en destino si existe (por nombre o por GID previo)
     let hojaVieja = Helper_ObtenerHoja(ssDestino, nombreRealHoja, gidDestino);
     if (hojaVieja) {
       if (ssDestino.getSheets().length === 1) {
         ssDestino.insertSheet("temp_holder");
       }
       const nombreViejo = hojaVieja.getName();
       ssDestino.deleteSheet(hojaVieja);
       SpreadsheetApp.flush();
       Logger.log(`   🗑️ Página previa '${nombreViejo}' eliminada en PRUEBAS.`);
     }

     // 2. Insertar hoja nueva limpia con el nombre y posición exactos
     const nuevaHoja = ssDestino.insertSheet(nombreRealHoja, Math.min(posicionOrigen, ssDestino.getSheets().length));
     SpreadsheetApp.flush();

     // 3. Determinar dimensiones y contenido útil
     const lastRow = hojaOrigen.getLastRow();
     const lastCol = hojaOrigen.getLastColumn();

     if (lastRow > 0 && lastCol > 0) {
       const targetRows = Math.max(lastRow + 5, 20);
       const targetCols = Math.max(lastCol + 2, 10);

       if (nuevaHoja.getMaxRows() < targetRows) {
         nuevaHoja.insertRowsAfter(nuevaHoja.getMaxRows(), targetRows - nuevaHoja.getMaxRows());
       } else if (nuevaHoja.getMaxRows() > targetRows) {
         nuevaHoja.deleteRows(targetRows + 1, nuevaHoja.getMaxRows() - targetRows);
       }

       if (nuevaHoja.getMaxColumns() < targetCols) {
         nuevaHoja.insertColumnsAfter(nuevaHoja.getMaxColumns(), targetCols - nuevaHoja.getMaxColumns());
       } else if (nuevaHoja.getMaxColumns() > targetCols) {
         nuevaHoja.deleteColumns(targetCols + 1, nuevaHoja.getMaxColumns() - targetCols);
       }

       const srcRange = hojaOrigen.getRange(1, 1, lastRow, lastCol);
       const dstRange = nuevaHoja.getRange(1, 1, lastRow, lastCol);

       // Fórmulas y valores combinados
       const formulas = srcRange.getFormulas();
       const values   = srcRange.getValues();
       const matrizDatos = values.map((fila, r) =>
         fila.map((val, c) => (formulas[r][c] && formulas[r][c] !== "") ? formulas[r][c] : val)
       );
       dstRange.setValues(matrizDatos);

       // Formatos numéricos y estilos visuales completos
       try { dstRange.setNumberFormats(srcRange.getNumberFormats()); } catch (_) {}
       try { dstRange.setBackgrounds(srcRange.getBackgrounds()); } catch (_) {}
       try { dstRange.setFontColors(srcRange.getFontColors()); } catch (_) {}
       try { dstRange.setFontFamilies(srcRange.getFontFamilies()); } catch (_) {}
       try { dstRange.setFontSizes(srcRange.getFontSizes()); } catch (_) {}
       try { dstRange.setFontLines(srcRange.getFontLines()); } catch (_) {}
       try { dstRange.setFontStyles(srcRange.getFontStyles()); } catch (_) {}
       try { dstRange.setFontWeights(srcRange.getFontWeights()); } catch (_) {}
       try { dstRange.setHorizontalAlignments(srcRange.getHorizontalAlignments()); } catch (_) {}
       try { dstRange.setVerticalAlignments(srcRange.getVerticalAlignments()); } catch (_) {}
       try { dstRange.setWrapStrategies(srcRange.getWrapStrategies()); } catch (_) {}

       // Anchos de columna y altos de fila
       for (let c = 1; c <= lastCol; c++) {
         try { nuevaHoja.setColumnWidth(c, hojaOrigen.getColumnWidth(c)); } catch (_) {}
       }
       for (let r = 1; r <= lastRow; r++) {
         try { nuevaHoja.setRowHeight(r, hojaOrigen.getRowHeight(r)); } catch (_) {}
       }

       // Celdas combinadas (Merges)
       try {
         const merges = srcRange.getMergedRanges();
         merges.forEach(m => {
           try {
             nuevaHoja.getRange(m.getRow(), m.getColumn(), m.getNumRows(), m.getNumColumns()).merge();
           } catch (_) {}
         });
       } catch (_) {}

       // Reglas de formato condicional
       try {
         const rules = hojaOrigen.getConditionalFormatRules();
         if (rules && rules.length > 0) nuevaHoja.setConditionalFormatRules(rules);
       } catch (_) {}

       // Validaciones de datos
       try {
         dstRange.setDataValidations(srcRange.getDataValidations());
       } catch (_) {}
     }

     // 4. Limpieza del placeholder temporal si existiera
     const holder = ssDestino.getSheetByName("temp_holder");
     if (holder && ssDestino.getSheets().length > 1) {
       try { ssDestino.deleteSheet(holder); } catch (_) {}
     }

     SpreadsheetApp.flush();
     Logger.log(`✅ 🧪 Hoja '${nombreRealHoja}' copiada a PRUEBAS con éxito (GID Nuevo: ${nuevaHoja.getSheetId()}).`);
   } catch (e) {
     Logger.log(`❌ ERROR al recargar '${nombreDefecto}': ${e.message}\n${e.stack}`);
     throw e;
   }
}

/**
 * Función unificada: Copia las páginas '1. Template' y '2. Benchmark LATAM' a PRUEBAS,
 * eliminando previamente sus versiones en destino y recargándolas con total fidelidad.
 * Se verifican los enlaces y GIDs exactos de producción (origen) y pruebas (destino).
 */
function copiar_template_y_benchmark_a_pruebas() {
   Logger.log("🚀 🧪 INICIANDO COPIA UNIFICADA DE TEMPLATE Y BENCHMARK A PRUEBAS...");
   const ssOrigen  = getSpreadsheet(ID_DESTINO);
   const ssDestino = getSpreadsheet(ID_DESTINO_PRUEBAS);

   const PAGINAS_CONFIG = [
     {
       nombre: "1. Template",
       gidOrigen: 1241281327, // https://docs.google.com/spreadsheets/d/10CBChAymE8k09cb_-D_ECD9KriZ0SbSve75IYBU7ZzM/edit?gid=1241281327
       gidDestino: 213814536  // https://docs.google.com/spreadsheets/d/1GO3jcGh8dSPz33A7KDyWASxPX8hYxWgIfbRuGgwqtC8/edit?gid=213814536
     },
     {
       nombre: "2. Benchmark LATAM",
       gidOrigen: null,
       gidDestino: null
     }
   ];

   PAGINAS_CONFIG.forEach(cfg => {
     recargarPaginaEnPruebas(ssOrigen, ssDestino, cfg);
   });

   Logger.log("🏆 🧪 ¡COPIA UNIFICADA DE TEMPLATE Y BENCHMARK FINALIZADA CON ÉXITO!");
}

function ejecutar_sincronizacion_pruebas_total() {
   Logger.log("🚀 🧪 INICIANDO SINCRO DE PRUEBAS COMPLETA...");
   
   Logger.log("👉 Paso 1/2: Enviando Consolidado General Data a BigQuery PRUEBAS...");
   const datos = GeneralData_ConsolidarMetricas();
   enviar_a_bigquery(datos, BQ_TABLE_ID_PRUEBAS);
   
   Logger.log("👉 Paso 2/2: Recargando '1. Template' y '2. Benchmark LATAM' en PRUEBAS...");
   copiar_template_y_benchmark_a_pruebas();
   
   Logger.log("🏆 🧪 ¡SINCRO DE PRUEBAS FINALIZADA CON ÉXITO!");
}

// ====================================================================================
// AUTOMATIZACIÓN POR MINUTO (TRIGGER CADA 5 MINUTOS CON FILTRO HORARIO)
// ====================================================================================
function Ejecutar_Con_Filtro_Horario() {
  const ss = getSpreadsheet(ID_ARCHIVO_UNICO);
  const timeZone = ss.getSpreadsheetTimeZone();
  const ahora = new Date();
  
  const horaStr = Utilities.formatDate(ahora, timeZone, "H");
  const minStr = Utilities.formatDate(ahora, timeZone, "m");
  
  const hora = parseInt(horaStr, 10);
  const minutos = parseInt(minStr, 10);
  
  const minutosTotales = (hora * 60) + minutos;
  const inicioRango = (7 * 60) + 45; // 07:45 -> 465 minutos
  const finRango    = (9 * 60) + 20; // 09:20 -> 560 minutos
  
  const horaFormateada = Utilities.formatDate(ahora, timeZone, "HH:mm");
  
  if (minutosTotales >= inicioRango && minutosTotales <= finRango) {
    Logger.log(`⏰ [DENTRO DE RANGO] Hora actual: ${horaFormateada}. Iniciando ejecución del proceso total...`);
    Ejecutar_Proceso_Total();
  } else {
    Logger.log(`💤 [FUERA DE RANGO] Hora actual: ${horaFormateada}. No se ejecuta el proceso.`);
  }
}

function Crear_Trigger_Cada_5_Minutos() {
  const funcionDestino = "Ejecutar_Con_Filtro_Horario";
  const triggers = ScriptApp.getProjectTriggers();
  for (let i = 0; i < triggers.length; i++) {
    if (triggers[i].getHandlerFunction() === funcionDestino) {
      Logger.log(`⚠️ Ya existe un trigger configurado para la función '${funcionDestino}'.`);
      return;
    }
  }
  
  ScriptApp.newTrigger(funcionDestino)
           .timeBased()
           .everyMinutes(5)
           .create();
           
  Logger.log(`✅ Activador creado con éxito.`);
}
