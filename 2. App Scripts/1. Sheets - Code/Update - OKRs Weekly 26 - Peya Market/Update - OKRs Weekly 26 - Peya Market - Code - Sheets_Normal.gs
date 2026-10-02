// ====================================================================================
// CONFIGURACIÓN GLOBAL
// ====================================================================================
const ID_ARCHIVO_UNICO = "1eNegsxjvy8MRsPjId7uQpdOdEvHgRxRnM6tjuTR3Dro";
const ID_DESTINO       = "10CBChAymE8k09cb_-D_ECD9KriZ0SbSve75IYBU7ZzM";

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
// PARTE 0: REFRESCAR FUENTES (En paralelo de forma asíncrona)
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

   const idPL = "1MeXHCeDGOkS7WIztOeWAD1WkwvuFOW_Mr-d1zdnoYww";
   if (!archivos[idPL]) archivos[idPL] = { hojasExtracto: new Set() };

   const activeRefreshes = [];

   Object.keys(archivos).forEach(id => {
     try {
       const ssExterna = getSpreadsheet(id);
       Logger.log(`📂 Iniciando disparos en: ${ssExterna.getName()}`);

       archivos[id].hojasExtracto.forEach(nombreHoja => {
         const sheet = ssExterna.getSheetByName(nombreHoja);
         if (!sheet) {
           Logger.log(`   ⚠️ Hoja no encontrada: '${nombreHoja}'`);
           return;
         }

         const tables = sheet.getDataSourceTables();
         if (tables.length === 0) {
           Logger.log(`   ℹ️ Sin Data Source Tables en '${nombreHoja}'.`);
           return;
         }

         tables.forEach((table, index) => {
           try {
             Logger.log(`   ⏳ Disparando asíncronamente refresh de tabla ${index + 1} de '${nombreHoja}'...`);
             const execution = table.refreshData();
             activeRefreshes.push({
               execution: execution,
               descripcion: `tabla ${index + 1} de '${nombreHoja}' en '${ssExterna.getName()}'`
             });
           } catch (e) {
             Logger.log(`   🔸 Error al disparar refresh: ${e.message}`);
           }
         });
       });
     } catch (e) {
       Logger.log(`❌ Error crítico al abrir ID ${id}: ${e.message}`);
     }
   });

   // Esperar a que terminen todas las ejecuciones iniciadas en paralelo
   Logger.log(`⏳ Esperando que completen las ${activeRefreshes.length} ejecuciones asíncronas...`);
   activeRefreshes.forEach(item => {
     try {
       Logger.log(`   ⏳ Esperando por: ${item.descripcion}...`);
       item.execution.waitForCompletion(TIEMPO_ESPERA_MAX);
       Logger.log(`   ✅ OK: ${item.descripcion}`);
     } catch (e) {
       Logger.log(`   🔸 Error esperando a ${item.descripcion}: ${e.message}`);
     }
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

function GeneralData_Helper_EsFechaPermitida(fechaObj) {
   if (!fechaObj) return false;
   const hoy = new Date();
   const anioActual = hoy.getFullYear();
   const anioPasado = anioActual - 1;
   const mesActual = hoy.getMonth(); // 0-11 (ej: 7 para Agosto)

   const mesesPermitidos = [];
   for (let i = 0; i < 5; i++) {
     let m = mesActual - i;
     if (m < 0) {
       m = m + 12;
     }
     mesesPermitidos.push(m);
   }

   const anioFecha = fechaObj.getFullYear();
   const mesFecha  = fechaObj.getMonth();

   // Solo permitir si pertenece al año actual o al año pasado,
   // y su mes es uno de los últimos 5 meses operativos recientes
   if (anioFecha === anioActual || anioFecha === anioPasado) {
     return mesesPermitidos.includes(mesFecha);
   }
   return false;
}

function obtenerDiasDelMes(fechaRaw) {
   const d = GeneralData_Helper_NormalizarFecha(fechaRaw);
   if (!d) return 30;
   return new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate();
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
   try {
     const filtro = sheet.getFilter();
     if (filtro) filtro.remove();
   } catch (e) {
     Logger.log(`   [WARN] No se pudo quitar filtro: ${e.message}`);
   }
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
       hojaDest.clearContents(); // clearContents es súper eficiente y preserva cuadrículas limpias

       // Asegurar que la hoja tenga filas y columnas suficientes para los datos antes de escribir
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

       // Recorte seguro: solo si hay un exceso enorme (> 5000 filas vacías) para no congelar el servidor
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

// 1. IMPORTAR TABLAR EXTERNAS
function GeneralData_ImportarTablas() {
   const ssDestino = getSpreadsheet(ID_ARCHIVO_UNICO);
   Logger.log("... Importando tablas externas ...");
   CONFIG_GD_IMPORT.forEach(conf => {
     if (!conf.id_origen.includes("PENDIENTE")) {
       GeneralData_Helper_Importar(conf, ssDestino);
     } else {
       Logger.log(`⚠️ SALTADO: Falta ID para '${conf.nombre_hoja_origen}'`);
     }
   });
}

// ====================================================================================
// 2. CONSOLIDAR MÉTRICAS GENERALES (Optimizado con Cachés de Alto Rendimiento)
// ====================================================================================
function GeneralData_ConsolidarMetricas() {
   const ss = getSpreadsheet(ID_ARCHIVO_UNICO);
   const nombreHojaDestino = "Consolidado General Data";
   const timeZone = ss.getSpreadsheetTimeZone();

   Logger.log("... Generando Consolidado General Data");

   const MAPA_RESULTADOS       = {};
   const MAPA_FORMATOS         = {};
   const MAPA_COMPONENTES_PAIS = {};
   const MAPA_COLOR_CONFIG     = {};
   const MAPA_GRANULARIDAD     = {};

   // Cachés en memoria para acelerar llamadas lentas a Utilities.formatDate, regexes y números de semana ISO
   const cacheFechas  = {};
   const cachePaises  = {};
   const cacheSemanas = {};

   const PAISES_PERMITIDOS = [
     "LATAM", "Argentina", "Bolivia", "Chile", "Republica Dominicana",
     "Ecuador", "El Salvador", "Guatemala", "Honduras",
     "Nicaragua", "Panama", "Paraguay", "Peru", "Uruguay"
   ];
   const PAISES_UPPER = PAISES_PERMITIDOS.map(p => p.toUpperCase());

   // Pre-poblar mapas estáticos para evitar asignaciones redundantes en el bucle principal de filas
   CONFIG_GD_METRICAS.forEach(config => {
     config.metricas.forEach(metrica => {
       MAPA_COLOR_CONFIG[metrica.name] = metrica.colorFormating ?? 1;
       MAPA_GRANULARIDAD[metrica.name] = config.esGranularidadDiaria ?? false;
       MAPA_FORMATOS[metrica.name]     = metrica.format || "General";
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
       if (config.filtroFila && !config.filtroFila(fila)) continue;

       const rawDate = fila[idxFecha];
       let   country = fila[idxCountry];
       if (!rawDate || !country) continue;

       // Caching de NormalizarFecha y Utilities.formatDate
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

       // Caching de limpieza de textos de países
       const rawCountryStr = String(country).trim();
       let countryClean = cachePaises[rawCountryStr];
       if (countryClean === undefined) {
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
           countryClean = MAPEO_CODIGOS_PAISES[paisNormalizado];
         } else {
           countryClean = GeneralData_Helper_LimpiarTexto(rawCountryStr);
           if (countryClean === "Republic Dominican" || countryClean === "Dominican Republic") {
             countryClean = "Republica Dominicana";
           }
         }
         cachePaises[rawCountryStr] = countryClean;
       }

       const esPaisValido      = PAISES_UPPER.includes(countryClean.toUpperCase());
       const esHolding         = countryClean === "LATAM Holding";
       const esCostaRica       = countryClean === "Costa Rica";
       const esExcepcionEBITDA = (esCostaRica || esHolding) && config.nombreHoja === "16 - Analitycs";

       if (!esPaisValido && !esExcepcionEBITDA) continue;

       config.metricas.forEach(metrica => {
         if (esExcepcionEBITDA && metrica.name !== "EBITDA") return;

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
           if (esExcepcionEBITDA && m.name !== "EBITDA") return;
           if (!m.latam) return;          // solo acumula LATAM si la métrica lo pide

           if (m.indicesLatam && Array.isArray(m.indicesLatam)) {
             const keyComp = m.name + '_components';
             if (!acumuladorLatam[dateStr][keyComp]) {
               acumuladorLatam[dateStr][keyComp] = new Array(m.indicesLatam.length).fill(0);
             }
             m.indicesLatam.forEach((idxCol, k) => {
               const val = typeof idxCol === 'function' ? idxCol(fila) : parseFloat(fila[idxCol]);
               acumuladorLatam[dateStr][keyComp][k] += (val || 0);
             });
           } else {
             let val = 0;
             if (m.calculo) {
               try { val = m.calculo(fila); } catch (_) { val = 0; }
             } else if (m.index !== undefined) {
               val = parseFloat(fila[m.index]) || 0;
             }

             if (acumuladorLatam[dateStr][m.name] === undefined) acumuladorLatam[dateStr][m.name] = 0;
             acumuladorLatam[dateStr][m.name] += val;

             if (m.averageLatam) {
               const keyCount = m.name + '_count';
               if (acumuladorLatam[dateStr][keyCount] === undefined) acumuladorLatam[dateStr][keyCount] = 0;
               acumuladorLatam[dateStr][keyCount]++;
             }
           }
         });
       }
     }

     if (config.calcularLatam) {
       for (const fecha in acumuladorLatam) {
         config.metricas.forEach(m => {
           if (!m.latam) return;          // solo escribe fila LATAM si la métrica lo pide
           let valLatam = 0;
           if (m.calculoLatam && m.indicesLatam && !m.averageLatam) {
             const comps = acumuladorLatam[fecha][m.name + '_components'];
             if (comps) {
               try { valLatam = m.calculoLatam(comps, fecha); } catch (_) { valLatam = 0; }
             }
           } else if (m.averageLatam) {
             const suma   = acumuladorLatam[fecha][m.name]             || 0;
             const cuenta = acumuladorLatam[fecha][m.name + '_count'] || 0;
             valLatam = safeDiv(suma, cuenta);
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
       try {
         MAPA_RESULTADOS[key] = configMetrica.calculoLatam(MAPA_COMPONENTES_PAIS[key]);
       } catch (_) {
         MAPA_RESULTADOS[key] = 0;
       }
     }
   }

   if (typeof CONFIG_GD_METRICAS_RELACIONADAS !== 'undefined') {
     CONFIG_GD_METRICAS_RELACIONADAS.forEach(rel => {
       const clavesActuales = Object.keys(MAPA_RESULTADOS);

       if (rel.operation === 'SUM' && rel.components) {
         const procesados = new Set();
         clavesActuales.forEach(key => {
           const parts = key.split('|');
           if (!rel.components.includes(parts[0])) return;
           const tag = `${parts[1]}|${parts[2]}`;
           if (procesados.has(tag)) return;
           const sumaTotal = rel.components.reduce((acc, comp) =>
             acc + (MAPA_RESULTADOS[`${comp}|${parts[1]}|${parts[2]}`] || 0), 0);
           MAPA_RESULTADOS[`${rel.name}|${parts[1]}|${parts[2]}`] = sumaTotal;
           procesados.add(tag);
         });
       } else if (rel.numerator && rel.denominator) {
         clavesActuales.forEach(key => {
           if (!key.startsWith(rel.numerator + "|")) return;
           const parts    = key.split('|');
           const keyDenom = `${rel.denominator}|${parts[1]}|${parts[2]}`;
           if (MAPA_RESULTADOS[keyDenom] === undefined) return;
           let resultado = safeDiv(MAPA_RESULTADOS[key], MAPA_RESULTADOS[keyDenom]);
           if (rel.inverseRatio) resultado = MAPA_RESULTADOS[keyDenom] !== 0 ? (1 - resultado) : 0;
           MAPA_RESULTADOS[`${rel.name}|${parts[1]}|${parts[2]}`] = resultado;
         });
       } else if (rel.operation === 'MULTIPLY' && rel.factors?.length === 2) {
         clavesActuales.forEach(key => {
           if (!key.startsWith(rel.factors[0] + "|")) return;
           const parts = key.split('|');
           const keyB  = `${rel.factors[1]}|${parts[1]}|${parts[2]}`;
           if (MAPA_RESULTADOS[keyB] === undefined) return;
           MAPA_RESULTADOS[`${rel.name}|${parts[1]}|${parts[2]}`] = MAPA_RESULTADOS[key] * MAPA_RESULTADOS[keyB];
         });
       }
     });
   }

   // ====================================================================================
   // EXPORTACIÓN DE PLACEHOLDER PARA 'Weighted Open time %' (Valor 0, Color 1)
   // Permite configurar reglas de color y fórmulas en destino sin calcular la fuente pesada
   // ====================================================================================
   MAPA_FORMATOS['Weighted Open time %']     = '0.00%';
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

   const datosFinales    = [];
   const formatosFinales = [];

   for (const key in MAPA_RESULTADOS) {
     const [nombreMetrica, pais, dateStr] = key.split('|');
     if (nombreMetrica.includes('_components') || nombreMetrica.includes('_count') || pais === "LATAM Holding") continue;

     const colorVal   = MAPA_COLOR_CONFIG[nombreMetrica] ?? 1;
     const esDiaria   = MAPA_GRANULARIDAD[nombreMetrica] ?? false;

     // Caching de cálculo de números de semana ISO
     let weekNumber = null;
     if (esDiaria) {
       weekNumber = cacheSemanas[dateStr];
       if (weekNumber === undefined) {
         weekNumber = getISOWeekNumber(dateStr);
         cacheSemanas[dateStr] = weekNumber;
       }
     }

     datosFinales.push([nombreMetrica, pais, dateStr, weekNumber, MAPA_RESULTADOS[key], colorVal]);
     formatosFinales.push([MAPA_FORMATOS[nombreMetrica] || "General"]);
   }

   let hojaDest = ss.getSheetByName(nombreHojaDestino);
   if (!hojaDest) hojaDest = ss.insertSheet(nombreHojaDestino);
   else hojaDest.clearContents(); // clearContents rinde 5x más rápido que clear() para celdas cargadas

   if (datosFinales.length > 0) {
     hojaDest.getRange(1, 1, 1, 6)
             .setValues([["Metric", "Country", "Date", "Week Number", "Value", "formato de color"]])
             .setFontWeight("bold");
     hojaDest.getRange(2, 1, datosFinales.length, 6).setValues(datosFinales);
     hojaDest.getRange(2, 5, datosFinales.length, 1).setNumberFormats(formatosFinales);
     hojaDest.getRange(2, 3, datosFinales.length, 1).setNumberFormat("dd-MMM-yyyy");
     hojaDest.getRange(2, 4, datosFinales.length, 1).setNumberFormat("0");

     // ELIMINAR FILAS EN EXCESO PARA REDUCIR EL USO DE CELDAS DEL LIBRO (Evita exceder el límite de 10M)
     const maxRows = hojaDest.getMaxRows();
     const requiredRows = datosFinales.length + 1;
     if (maxRows > requiredRows) {
       hojaDest.deleteRows(requiredRows + 1, maxRows - requiredRows);
     }

     Logger.log(`✅ Consolidado creado con ${datosFinales.length} filas.`);
   } else {
     Logger.log("⚠️ Sin datos para escribir.");
   }
}

// ====================================================================================
// 3. ENVIAR DATOS A LA HOJA DESTINO FINAL (Optimizado con copyTo)
// ====================================================================================
function enviar_consolidado() {
   try {
     Logger.log("--- 🚀 Iniciando envío de consolidado a PRODUCCIÓN...");
     const HOJA_ORIGEN  = "Consolidado General Data";
     const HOJA_DESTINO = "A. TI - Actuals OKRs";

     Logger.log("   📂 [Paso 1/4] Abriendo archivo de origen...");
     const ssOrigen = getSpreadsheet(ID_ARCHIVO_UNICO);
     const sourceSheet = ssOrigen.getSheetByName(HOJA_ORIGEN);
     if (!sourceSheet) throw new Error(`No existe la hoja '${HOJA_ORIGEN}'`);

     Logger.log("   📊 [Paso 2/4] Leyendo datos de origen...");
     const data = sourceSheet.getDataRange().getValues().filter(row => row.join("").length > 0);
     if (data.length < 2) throw new Error("Sin datos suficientes en el Consolidado.");

     const monthIndex = data[0].findIndex(h => ["MONTH", "DATE"].includes(h.toString().trim().toUpperCase()));
     
     Logger.log("   🎯 [Paso 3/4] Conectando con archivo destino de PRODUCCIÓN...");
     const ssDestino = getSpreadsheet(ID_DESTINO);
     const targetSheet = ssDestino.getSheetByName(HOJA_DESTINO) || ssDestino.insertSheet(HOJA_DESTINO);

     Logger.log("   🧹 Limpiando filtros y contenido viejo en destino...");
     GeneralData_Helper_QuitarFiltros(targetSheet);
     targetSheet.clearContents();

     // ASEGURAR DIMENSIONES SUFICIENTES (Evita error de coordenadas fuera de las dimensiones de la hoja)
     const maxRows = targetSheet.getMaxRows();
     if (maxRows < data.length) {
       targetSheet.insertRowsAfter(maxRows, data.length - maxRows);
     }
     const maxCols = targetSheet.getMaxColumns();
     if (maxCols < data[0].length) {
       targetSheet.insertColumnsAfter(maxCols, data[0].length - maxCols);
     }

     Logger.log("   ⚡ [Paso 4/4] Escribiendo nuevos datos en destino (" + data.length + " filas)...");
     targetSheet.getRange(1, 1, data.length, data[0].length).setValues(data);

     // ELIMINAR FILAS EN EXCESO EN EL DESTINO (Súper importante para no sobrepasar el límite de 10M de celdas)
     const finalMaxRows = targetSheet.getMaxRows();
     if (finalMaxRows > data.length) {
       targetSheet.deleteRows(data.length + 1, finalMaxRows - data.length);
     }

     const colFecha = monthIndex > -1 ? monthIndex + 1 : 3;
     targetSheet.getRange(2, colFecha, data.length - 1, 1).setNumberFormat("dd-MMM-yyyy");

     SpreadsheetApp.flush();
     Logger.log("✅ Consolidado enviado a PRODUCCIÓN con éxito.");
   } catch (e) {
     Logger.log(`❌ ERROR al enviar a PRODUCCIÓN: ${e.message}\n${e.stack}`);
   }
}

// ====================================================================================
// 4. FUNCIONES MAESTRAS DE EJECUCIÓN
// ====================================================================================
function Ejecutar_Proceso_Total() {
   Logger.log("🚀 INICIANDO PROCESO COMPLETO...");

   Logger.log("👉 Paso 1/3: Importando tablas externas (Orders, OPS, Supply)...");
   GeneralData_ImportarTablas();

   Logger.log("👉 Paso 2/3: Calculando métricas y estructurando consolidado general...");
   GeneralData_ConsolidarMetricas();

   Logger.log("👉 Paso 3/3: Enviando datos finales a la hoja de OKRs...");
   enviar_consolidado();

   Logger.log("🏆 ¡PROCESO TOTAL COMPLETADO CON ÉXITO!");
}

function GeneralData_ConsolidarYEnviar() {
   Logger.log("🔄 Iniciando proceso abreviado: Consolidar y Enviar...");

   Logger.log("👉 Paso 1/2: Calculando métricas y estructurando consolidado general...");
   GeneralData_ConsolidarMetricas();

   Logger.log("👉 Paso 2/2: Enviando datos finales a la hoja de OKRs...");
   enviar_consolidado();

   Logger.log("🏆 ¡Consolidación y envío completados con éxito!");
}

// ====================================================================================
// HOJA DE PRUEBAS
// ====================================================================================
const ID_DESTINO_PRUEBAS = "1GO3jcGh8dSPz33A7KDyWASxPX8hYxWgIfbRuGgwqtC8";

function enviar_consolidado_pruebas() {
   try {
     Logger.log("--- 🧪 🚀 Iniciando envío de consolidado a PRUEBAS...");
     const HOJA_ORIGEN  = "Consolidado General Data";
     const HOJA_DESTINO = "A. TI - Actuals OKRs";

     Logger.log("   📂 [Paso 1/4] Abriendo archivo de origen...");
     const ssOrigen = getSpreadsheet(ID_ARCHIVO_UNICO);
     const sourceSheet = ssOrigen.getSheetByName(HOJA_ORIGEN);
     if (!sourceSheet) throw new Error(`No existe la hoja '${HOJA_ORIGEN}'`);

     Logger.log("   📊 [Paso 2/4] Leyendo datos de origen...");
     const data = sourceSheet.getDataRange().getValues().filter(row => row.join("").length > 0);
     if (data.length < 2) throw new Error("Sin datos suficientes en el Consolidado.");

     const monthIndex = data[0].findIndex(h => ["MONTH", "DATE"].includes(h.toString().trim().toUpperCase()));
     
     Logger.log("   🎯 [Paso 3/4] Conectando con archivo destino de PRUEBAS...");
     const ssDestino = getSpreadsheet(ID_DESTINO_PRUEBAS);
     const targetSheet = ssDestino.getSheetByName(HOJA_DESTINO) || ssDestino.insertSheet(HOJA_DESTINO);

     Logger.log("   🧹 Limpiando filtros y contenido viejo en destino...");
     GeneralData_Helper_QuitarFiltros(targetSheet);
     targetSheet.clearContents();

     // ASEGURAR DIMENSIONES SUFICIENTES (Evita error de coordenadas fuera de las dimensiones de la hoja)
     const maxRows = targetSheet.getMaxRows();
     if (maxRows < data.length) {
       targetSheet.insertRowsAfter(maxRows, data.length - maxRows);
     }
     const maxCols = targetSheet.getMaxColumns();
     if (maxCols < data[0].length) {
       targetSheet.insertColumnsAfter(maxCols, data[0].length - maxCols);
     }

     Logger.log("   ⚡ [Paso 4/4] Escribiendo nuevos datos en destino de PRUEBAS (" + data.length + " filas)...");
     targetSheet.getRange(1, 1, data.length, data[0].length).setValues(data);

     // ELIMINAR FILAS EN EXCESO EN EL DESTINO (Súper importante para no sobrepasar el límite de 10M de celdas)
     const finalMaxRows = targetSheet.getMaxRows();
     if (finalMaxRows > data.length) {
       targetSheet.deleteRows(data.length + 1, finalMaxRows - data.length);
     }

     const colFecha = monthIndex > -1 ? monthIndex + 1 : 3;
     targetSheet.getRange(2, colFecha, data.length - 1, 1).setNumberFormat("dd-MMM-yyyy");

     SpreadsheetApp.flush();
     Logger.log(`✅ 🧪 Consolidado enviado a PRUEBAS con éxito.`);
   } catch (e) {
     Logger.log(`❌ ERROR al enviar a PRUEBAS: ${e.message}\n${e.stack}`);
   }
}

/**
 * Copia la página exacta desde el origen a PRUEBAS (duplicado nativo con copyTo de Google Sheets).
 * 1. Elimina la página existente previa en destino (borrado limpio).
 * 2. Recorta filas vacías de hojas estándar en pruebas para evitar topar el límite global de 10M de celdas.
 * 3. Desactiva temporalmente filtros en origen para evitar 'This operation is not supported'.
 * 4. Pega la misma página idéntica con copyTo() (preservando gráficos, fórmulas, formatos y diseño).
 * 5. Le asigna el nombre exacto y posición original.
 */
function copiarPaginaNativa(ssOrigen, ssDestino, nombreHoja) {
   Logger.log(`--- 🧪 Copiando página exacta '${nombreHoja}' a PRUEBAS...`);
   const hojaOrigen = ssOrigen.getSheetByName(nombreHoja);
   if (!hojaOrigen) throw new Error(`No existe la hoja '${nombreHoja}' en el archivo origen.`);

   const posicionOrigen = hojaOrigen.getIndex();

   // 1. Si la hoja ya existe en destino, eliminarla primero (borrado total solicitado)
   const hojaExistente = ssDestino.getSheetByName(nombreHoja);
   if (hojaExistente) {
     if (ssDestino.getSheets().length === 1) {
       ssDestino.insertSheet("temp_holder");
     }
     ssDestino.deleteSheet(hojaExistente);
     SpreadsheetApp.flush();
     Logger.log(`   🗑️ Hoja previa '${nombreHoja}' eliminada en PRUEBAS.`);
   }

   // 2. Liberar celdas en destino recortando filas vacías en hojas estándar (omitiendo DATASOURCE)
   ssDestino.getSheets().forEach(h => {
     if (h.getType && h.getType() === SpreadsheetApp.SheetType.DATASOURCE) return;
     try {
       const maxR = h.getMaxRows();
       const lastR = Math.max(h.getLastRow(), 1);
       if (maxR > lastR + 2) {
         h.deleteRows(lastR + 3, maxR - (lastR + 2));
       }
     } catch (_) {}
   });
   SpreadsheetApp.flush();

   // 3. Desactivar temporalmente filtro activo en origen (evita 'This operation is not supported')
   let filtroRango = null;
   let filtroCriterios = null;
   const filtro = hojaOrigen.getFilter();
   if (filtro) {
     try {
       filtroRango = filtro.getRange();
       filtroCriterios = [];
       const startCol = filtroRango.getColumn();
       const endCol = filtroRango.getLastColumn();
       for (let c = startCol; c <= endCol; c++) {
         const crit = filtro.getColumnFilterCriteria(c);
         if (crit) filtroCriterios.push({ col: c, criteria: crit });
       }
       filtro.remove();
       SpreadsheetApp.flush();
     } catch (_) {}
   }

   // 4. Copiar la página idéntica mediante copyTo nativo
   let nuevaHoja = null;
   try {
     nuevaHoja = hojaOrigen.copyTo(ssDestino);
   } finally {
     // Restaurar inmediatamente el filtro en el origen
     if (filtroRango && filtroCriterios && filtroCriterios.length > 0) {
       try {
         const nuevoFiltro = filtroRango.createFilter();
         filtroCriterios.forEach(item => nuevoFiltro.setColumnFilterCriteria(item.col, item.criteria));
       } catch (_) {}
     }
   }

   // 5. Asignar nombre original y posición
   nuevaHoja.setName(nombreHoja);
   ssDestino.setActiveSheet(nuevaHoja);
   try { ssDestino.moveActiveSheet(posicionOrigen); } catch (_) {}

   // 6. Eliminar placeholder temporal si se usó
   const holder = ssDestino.getSheetByName("temp_holder");
   if (holder && ssDestino.getSheets().length > 1) {
     try { ssDestino.deleteSheet(holder); } catch (_) {}
   }

   SpreadsheetApp.flush();
   Logger.log(`✅ 🧪 Página '${nombreHoja}' pegada exactamente igual en PRUEBAS (posición ${posicionOrigen}).`);
}

/**
 * Función unificada: Borra las versiones previas en destino y pega las páginas exactas
 * '1. Template' y '2. Benchmark LATAM' desde producción a PRUEBAS todo igual.
 */
function copiar_template_y_benchmark_a_pruebas() {
   Logger.log("🚀 🧪 INICIANDO COPIA DE PÁGINAS A PRUEBAS (BORRAR Y PEGAR EXACTAS)...");
   const ssOrigen  = getSpreadsheet(ID_DESTINO);
   const ssDestino = getSpreadsheet(ID_DESTINO_PRUEBAS);

   copiarPaginaNativa(ssOrigen, ssDestino, "1. Template");
   copiarPaginaNativa(ssOrigen, ssDestino, "2. Benchmark LATAM");

   Logger.log("🏆 🧪 ¡PÁGINAS '1. Template' Y '2. Benchmark LATAM' COPIADAS EXACTAMENTE IGUAL!");
}

function ejecutar_sincronizacion_pruebas_total() {
   Logger.log("🚀 🧪 INICIANDO SINCRO DE PRUEBAS COMPLETA...");
   
   Logger.log("👉 Paso 1/2: Enviando Consolidado General Data a PRUEBAS...");
   enviar_consolidado_pruebas();
   
   Logger.log("👉 Paso 2/2: Copiando páginas exactas '1. Template' y '2. Benchmark LATAM' a PRUEBAS...");
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
    Logger.log(`💤 [FUERA DE RANGO] Hora actual: ${horaFormateada} (Rango permitido: 07:45 a 09:20). No se ejecuta el proceso.`);
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
           
  Logger.log(`✅ Activador creado con éxito. '${funcionDestino}' se ejecutará cada 5 minutos.`);
}
