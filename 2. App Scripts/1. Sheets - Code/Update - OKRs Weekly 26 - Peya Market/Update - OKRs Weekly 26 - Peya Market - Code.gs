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
       { name: 'Discounts EUR',        index: 19, colorFormating: 0, latam: false },
       { name: 'DY Orders',            index: 20, colorFormating: 1, latam: false },
       { name: 'SOF Orders',           index: 21, colorFormating: 1, latam: false },
       { name: 'Units ndy_nsof',       index: 22, colorFormating: 1, latam: false },
       { name: 'Net Sales ndy_nsof',   index: 23, colorFormating: 1, latam: false },
       { name: 'Sessions',             index: 31, colorFormating: 1, latam: false },
       { name: 'transactions',         index: 32, colorFormating: 1, latam: false },
       { name: 'Sessions - non Double Ya', index: 33, colorFormating: 1, latam: false },
       { name: 'transactions_non_dy',  index: 34, colorFormating: 1, latam: false },
       { name: 'Sessions - Double Ya', index: 35, colorFormating: 1, latam: false },
       { name: 'transactions_dy',      index: 36, colorFormating: 1, latam: false },
       { name: 'instant_need',         index: 24, colorFormating: 1, latam: false },
       { name: 'fill_in',              index: 25, colorFormating: 1, latam: false },
       { name: 'stock_up',             index: 26, colorFormating: 1, latam: false },

       // --- Métricas Calculadas en Sheet (Vacías en origen para formato de color) ---
       { name: 'Units sold',                    colorFormating: 1 },
       { name: 'GMV User Share Dmarts %',       colorFormating: 1 },
       { name: 'Daily GMV User Dmarts',         colorFormating: 1 },
       { name: 'Daily Orders per Store',        colorFormating: 1 },
       { name: 'Order share Dmarts %',          colorFormating: 1 },
       { name: '% Orders DY',                   colorFormating: 1 },
       { name: '% Orders SOF',                  colorFormating: 0 },
       { name: '% Orders Plus',                 colorFormating: 1 },
       { name: '% Plus Users',                  colorFormating: 1 },
       { name: 'Platform Maus penetration %',   colorFormating: 1 },
       { name: 'CVR3 %',                        colorFormating: 1 },
       { name: 'CVR3 % - Double Ya',            colorFormating: 1 },
       { name: 'CVR3 % - non Double Ya',        colorFormating: 1 },
       { name: 'AFV €',                         colorFormating: 1 },
       { name: 'AFV No DY no SoF',              colorFormating: 1 },
       { name: 'Basket Size',                   colorFormating: 1 },
       { name: 'Basket size No DY no SoF',      colorFormating: 1 },
       { name: 'UF Basket Penetration %',       colorFormating: 1 },
       { name: 'Frequency',                     colorFormating: 1 },
       { name: 'Customer Units',                colorFormating: 1 },
       { name: 'Avg PVP (wo VAT)  €',           colorFormating: 0 },
       { name: 'Fill In %',                     colorFormating: 1 },
       { name: 'Instant Need %',                colorFormating: 1 },
       { name: 'Stock Up %',                    colorFormating: 1 },
       { name: 'Gross basket discount %',       colorFormating: 1 },
       { name: 'Promo contribution %',          colorFormating: 1 }
     ]
   }, { // 2 - OPS Data (DIARIO)
     nombreHoja: "2 - OPS Data",
     indices: { date: 0, country: 1 }, // 0: date, 1: Country_en
     calcularLatam: true,
     esGranularidadDiaria: true,
     metricas: [

       // ════════════════════════════════════════════════════════════════
       // orders_data_agg (od)  → cols 2-3
       // ════════════════════════════════════════════════════════════════
       { name: 'Total_orders_fact_orders',            index: 2,  colorFormating: 1, latam: false },
       { name: 'Total_orders_fact_orders_all_status', index: 3,  colorFormating: 1, latam: false },

       // ════════════════════════════════════════════════════════════════
       // seamless_data_daily (sdd)  → cols 4-10
       // ════════════════════════════════════════════════════════════════
       { name: 'Seamless Delivery orders',            index: 4,  colorFormating: 1, latam: false },
       { name: 'Rejected orders',                     index: 5,  colorFormating: 0, latam: false },
       { name: 'Forced Pre Orders',                   index: 6,  colorFormating: 0, latam: false },
       { name: 'Modified orders',                     index: 7,  colorFormating: 0, latam: false },
       { name: 'HC Sessions orders',                  index: 8,  colorFormating: 0, latam: false },
       { name: 'Slow orders',                         index: 9,  colorFormating: 0, latam: false },
       { name: 'Late Orders',                         index: 10, colorFormating: 0, latam: false },

       // ════════════════════════════════════════════════════════════════
       // pickers_orders (picko)  → cols 11-14
       // ════════════════════════════════════════════════════════════════
       { name: 'Picker shift confirmed orders',       index: 11, colorFormating: 1, latam: false },
       { name: 'Assignment Time total',               index: 12, colorFormating: 1, latam: false },
       { name: 'Assignment Time > 6 min orders',      index: 13, colorFormating: 0, latam: false },
       { name: 'Picking Time',                        index: 14, colorFormating: 1, latam: false },

       // ════════════════════════════════════════════════════════════════
       // delivery_time_agg (dta)  → cols 15-20
       // ════════════════════════════════════════════════════════════════
       { name: 'non_forced_completed_orders_logistics', index: 15, colorFormating: 1, latam: false },
       { name: 'Delivery Time total',                 index: 16, colorFormating: 1, latam: false },
       { name: 'Stacked 0 orders',                    index: 17, colorFormating: 1, latam: false },
       { name: 'Stacked 1 orders',                    index: 18, colorFormating: 1, latam: false },
       { name: 'stacked 2 orders',                    index: 19, colorFormating: 1, latam: false },
       { name: 'stacked 3 or more orders',            index: 20, colorFormating: 1, latam: false },

       // ════════════════════════════════════════════════════════════════
       // timings_data (td)  → cols 21-27
       // ════════════════════════════════════════════════════════════════
       { name: 'Total_orders_timings',                index: 21, colorFormating: 1, latam: false },
       { name: 'Picked_items',                        index: 22, colorFormating: 1, latam: false },
       { name: 'Item Picking Time',                   index: 23, colorFormating: 0, latam: false },
       { name: 'Order late 10 orders',                index: 24, colorFormating: 0, latam: false },
       { name: 'Delivery time > 35 min orders',       index: 25, colorFormating: 0, latam: false },
       { name: 'vendor_late_count',                   index: 26, colorFormating: 0, latam: false },
       { name: 'vendor_late_deno',                    index: 27, colorFormating: 1, latam: false },

       // ════════════════════════════════════════════════════════════════
       // inaccuracy  → cols 28-31
       // ════════════════════════════════════════════════════════════════
       { name: 'Total orders inaccuracy',             index: 28, colorFormating: 1, latam: false },
       { name: 'Inaccuracy Orders',                   index: 29, colorFormating: 0, latam: false },
       { name: 'Food Issue Orders',                   index: 30, colorFormating: 0, latam: false },
       { name: 'Item Issue Orders',                   index: 31, colorFormating: 0, latam: false },

       // ════════════════════════════════════════════════════════════════
       // productividad_data (proDa)  → cols 32-37
       // ════════════════════════════════════════════════════════════════
       { name: 'Picking units',                       index: 32, colorFormating: 1, latam: false },
       { name: 'Receiving units',                     index: 33, colorFormating: 1, latam: false },
       { name: 'Ajuste utr',                          index: 34, colorFormating: 1, latam: true },
       { name: 'Picker working hours',                index: 35, colorFormating: 1, latam: false },
       { name: 'Manager working hours',               index: 36, colorFormating: 1, latam: false },
       { name: 'Received bags',                       index: 37, colorFormating: 0, latam: false },

       // ════════════════════════════════════════════════════════════════
       // original_by_ops_diario (opsd)  → cols 38-40
       // ════════════════════════════════════════════════════════════════
       { name: 'Total_orders_ops',                    index: 38, colorFormating: 1, latam: false },
       { name: 'Partial orders',                      index: 39, colorFormating: 0, latam: false },
       { name: 'Lost orders',                         index: 40, colorFormating: 0, latam: false },

       // --- Métricas Calculadas en Sheet (Vacías en origen para formato de color) ---
       { name: 'Seamless Delivery %',                 colorFormating: 1 },
       { name: 'Modified orders %',                  colorFormating: 0 },
       { name: 'HC Sessions orders %',               colorFormating: 0 },
       { name: 'Rejected orders %',                  colorFormating: 0 },
       { name: 'Late Orders %',                      colorFormating: 0 },
       { name: 'Forced Pre Orders %',                colorFormating: 0 },
       { name: 'Slow orders %',                      colorFormating: 0 },
       { name: 'Assignment Time %',                  colorFormating: 0 },
       { name: 'Assignment Time',                    colorFormating: 0 },
       { name: 'Assignment Time > 6 min %',          colorFormating: 0 },
       { name: 'Lost orders %',                      colorFormating: 0 },
       { name: 'Avg. Delivery Time',                 colorFormating: 0 },
       { name: 'Non_forced_completed_orders_logistics', colorFormating: 1 },
       { name: 'Delivery time > 35 min %',           colorFormating: 0 },
       { name: 'Confirmed Orders from timings',      colorFormating: 1 },
       { name: 'Ajuste UTR',                         colorFormating: 1 },
       { name: 'UTR+',                               colorFormating: 1 }
     ]
   }, { // 3 - Supply Data
     nombreHoja: "3 - Supply Data",
     indices: { date: 0, country: 2 },
     calcularLatam: true,
     esGranularidadDiaria: true,
     metricas: [
       { name: 'WIS Denominador', index: 3, colorFormating: 1, latam: false },
       { name: 'WIS Numerador',   index: 4, colorFormating: 1, latam: false },
       { name: 'WIS UF Denominador', index: 6, colorFormating: 1, latam: false },
       { name: 'WIS UF Numerador',   index: 7, colorFormating: 1, latam: false },
       { name: 'Peya Issues Numerador',   index: 9,  colorFormating: 0, latam: false },
       { name: 'Peya Issues Denominador', index: 10, colorFormating: 1, latam: false },
       { name: 'Peya Issues UF Numerador',   index: 12, colorFormating: 0, latam: false },
       { name: 'Peya Issues UF Denominador', index: 13, colorFormating: 1, latam: false },
       { name: 'Supplier Issues Numerador',   index: 15, colorFormating: 0, latam: false },
       { name: 'Supplier Issues Denominador', index: 16, colorFormating: 1, latam: false },
       { name: 'Supplier Issues UF Numerador',   index: 18, colorFormating: 0, latam: false },
       { name: 'Supplier Issues UF Denominador', index: 19, colorFormating: 1, latam: false },

       // --- Métricas Calculadas en Sheet (Vacías en origen para formato de color) ---
       { name: 'Days on hand (DOH)',           colorFormating: 0 },
       { name: 'Stock ZM (Eur) %',             colorFormating: 0 },
       { name: 'Stock SM (Eur) %',             colorFormating: 0 },
       { name: 'WIS %',                        colorFormating: 1 },
       { name: 'WIS UF %',                     colorFormating: 1 },
       { name: 'WLT Lvl3 - Peya Issues %',     colorFormating: 0 },
       { name: 'WLT Lvl3 - Supplier Issues %', colorFormating: 0 },
       { name: 'Listed SKUs',                  colorFormating: 1 }
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

       // --- Métricas Calculadas en Sheet (Vacías en origen para formato de color) ---
       { name: 'Dmart MAUs',                   colorFormating: 1 },
       { name: 'New Users - Dmart',            colorFormating: 1 },
       { name: 'Dmart MAUs - Plus',            colorFormating: 1 },
       { name: 'PeYa MAUs',                    colorFormating: 1 }
     ]
   }, { // 5 - Open Time (DIARIO)
     nombreHoja: "5 - Open Time",
     indices: { date: 0, country: 1 },
     calcularLatam: false,
     esGranularidadDiaria: true,
     metricas: [
       { name: 'Weighted Open time %', index: 7, colorFormating: 1, format: '0.00%', latam: false },

       // --- Métricas Calculadas en Sheet (Vacías en origen para formato de color) ---
       { name: 'WHS minutes schedule',         colorFormating: 1 },
       { name: 'WHS minutes closed',           colorFormating: 0 },
       { name: 'Open Time Simple',             colorFormating: 1 }
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
   Logger.log("[INICIO] Refrescando extractos (Data Source Tables) en PARALELO...");
   const TIEMPO_ESPERA_MAX = 300;

   try { SpreadsheetApp.enableBigQueryExecution(); } catch (e) {
     Logger.log("[WARN] No se pudo habilitar BigQueryExecution.");
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
       Logger.log(`[DIR] Iniciando disparos en: ${ssExterna.getName()}`);

       archivos[id].hojasExtracto.forEach(nombreHoja => {
         const sheet = ssExterna.getSheetByName(nombreHoja);
         if (!sheet) {
           Logger.log(`   [WARN] Hoja no encontrada: '${nombreHoja}'`);
           return;
         }

         const tables = sheet.getDataSourceTables();
         if (tables.length === 0) {
           Logger.log(`   [INFO] Sin Data Source Tables en '${nombreHoja}'.`);
           return;
         }

         tables.forEach((table, index) => {
           try {
             Logger.log(`   [WAIT] Disparando asíncronamente refresh de tabla ${index + 1} de '${nombreHoja}'...`);
             const execution = table.refreshData();
             activeRefreshes.push({
               execution: execution,
               descripcion: `tabla ${index + 1} de '${nombreHoja}' en '${ssExterna.getName()}'`
             });
           } catch (e) {
             Logger.log(`   [ERROR] Error al disparar refresh: ${e.message}`);
           }
         });
       });
     } catch (e) {
       Logger.log(`[ERROR] Error crítico al abrir ID ${id}: ${e.message}`);
     }
   });

   // Esperar a que terminen todas las ejecuciones iniciadas en paralelo
   Logger.log(`[WAIT] Esperando que completen las ${activeRefreshes.length} ejecuciones asíncronas...`);
   activeRefreshes.forEach(item => {
     try {
       Logger.log(`   [WAIT] Esperando por: ${item.descripcion}...`);
       item.execution.waitForCompletion(TIEMPO_ESPERA_MAX);
       Logger.log(`   [OK] ${item.descripcion}`);
     } catch (e) {
       Logger.log(`   [ERROR] Error esperando a ${item.descripcion}: ${e.message}`);
     }
   });
   Logger.log("[FIN] Refresco completado.");
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

function GeneralData_Helper_RecortarFilasSeguro(sheet, keepRows) {
   if (!sheet) return;
   try {
     const maxRows = sheet.getMaxRows();
     const exceso = maxRows - keepRows;
     if (exceso > 100) {
       const LOTE = 25000;
       let restantes = exceso;
       while (restantes > 0) {
         const aBorrar = Math.min(restantes, LOTE);
         sheet.deleteRows(keepRows + 1, aBorrar);
         restantes -= aBorrar;
         if (restantes > 0) SpreadsheetApp.flush();
       }
     }
   } catch (e) {
     Logger.log(`   [WARN] No se pudieron recortar filas excedentes: ${e.message}`);
   }
}

function GeneralData_Helper_OrdenarFilasConsolidado(filas) {
   if (!filas || filas.length <= 1) return filas;
   const encabezado = filas[0];
   const resto = filas.slice(1);

   const filasVacias = [];
   const filasDatos = [];

   resto.forEach(row => {
     const fechaVal = row[2];
     const esVacia = (fechaVal === "" || fechaVal == null || String(fechaVal).trim() === "");
     if (esVacia) {
       filasVacias.push(row);
     } else {
       filasDatos.push(row);
     }
   });

   // Filas vacías ordenadas alfabéticamente por métrica
   filasVacias.sort((a, b) => String(a[0]).localeCompare(String(b[0])));

   // Filas con datos: ordenadas de la última semana disponible hacia las primeras (Week Number DESC)
   filasDatos.sort((a, b) => {
     // 1. Semana descendente (b[3] vs a[3]): de la última semana disponible hacia las primeras
     const weekA = Number(a[3]) || 0;
     const weekB = Number(b[3]) || 0;
     if (weekB !== weekA) return weekB - weekA;

     // 2. Fecha / Timestamp descendente: año más nuevo antes, días más recientes antes
     const timeA = a[2] instanceof Date ? a[2].getTime() : new Date(String(a[2]).replace(/-/g, '/')).getTime() || 0;
     const timeB = b[2] instanceof Date ? b[2].getTime() : new Date(String(b[2]).replace(/-/g, '/')).getTime() || 0;
     if (timeB !== timeA) return timeB - timeA;

     // 3. País alfabético
     const countryComp = String(a[1]).localeCompare(String(b[1]));
     if (countryComp !== 0) return countryComp;

     // 4. Métrica alfabética
     return String(a[0]).localeCompare(String(b[0]));
   });

   return [encabezado].concat(filasVacias).concat(filasDatos);
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

// 1. IMPORTAR TABLAS EXTERNAS
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

   // Formato de color explícito para métricas adicionales (1: Buena / 0: Mala)
   if (typeof CONFIG_COLOR_METRICAS_EXTRA !== 'undefined') {
     Object.keys(CONFIG_COLOR_METRICAS_EXTRA).forEach(m => {
       MAPA_COLOR_CONFIG[m] = CONFIG_COLOR_METRICAS_EXTRA[m];
     });
   }

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

         // Las métricas vacías (calculadas en Sheet) se insertan una única vez al final del consolidado
         const esVacia = (metrica.index === undefined && !metrica.calculo);
         if (esVacia) return;

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
           if (m.index === undefined && !m.calculo) return; // Vacías no se acumulan
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
           if (m.index === undefined && !m.calculo) return; // Vacías no generan filas en LATAM diario
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
   // 1. MÉTRICAS VACÍAS (Calculadas en Sheet): Van PRIMERO en el consolidado
   // ====================================================================================
   const filasVacias = [];
   const metricasVaciasProcesadas = new Set();
   CONFIG_GD_METRICAS.forEach(cfg => {
     cfg.metricas.forEach(metrica => {
       const esVacia = (metrica.index === undefined && !metrica.calculo);
       if (esVacia && !metricasVaciasProcesadas.has(metrica.name)) {
         metricasVaciasProcesadas.add(metrica.name);
         const colorVal = MAPA_COLOR_CONFIG[metrica.name] ?? (metrica.colorFormating ?? 1);
         filasVacias.push([metrica.name, "", "", "", "", colorVal]);
       }
     });
   });

   if (typeof CONFIG_COLOR_METRICAS_EXTRA !== 'undefined') {
     Object.keys(CONFIG_COLOR_METRICAS_EXTRA).forEach(nombreExtra => {
       if (!metricasVaciasProcesadas.has(nombreExtra)) {
         metricasVaciasProcesadas.add(nombreExtra);
         const colorVal = CONFIG_COLOR_METRICAS_EXTRA[nombreExtra] ?? 1;
         filasVacias.push([nombreExtra, "", "", "", "", colorVal]);
       }
     });
   }

   // ====================================================================================
   // 2. FILAS CON DATOS: Se extraen y se ordenan de la fecha más reciente a la más vieja
   // ====================================================================================
   const filasDatos = [];

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

     filasDatos.push([nombreMetrica, pais, dateStr, weekNumber, MAPA_RESULTADOS[key], colorVal]);
   }

   // ====================================================================================
   // 3. UNIÓN Y ORDENAMIENTO FINAL: Vacías primero, seguidas de semanas DESC (última a primera)
   // ====================================================================================
   const encabezado = ["Metric", "Country", "Date", "Week Number", "Value", "formato de color"];
   const todosLosDatos = [encabezado].concat(filasVacias).concat(filasDatos);
   const datosOrdenados = GeneralData_Helper_OrdenarFilasConsolidado(todosLosDatos);
   const datosFinales = datosOrdenados.slice(1);

   let hojaDest = ss.getSheetByName(nombreHojaDestino);
   if (!hojaDest) hojaDest = ss.insertSheet(nombreHojaDestino);
   else hojaDest.clearContents(); // clearContents rinde 5x más rápido que clear() para celdas cargadas

   if (datosFinales.length > 0) {
     const maxRows = hojaDest.getMaxRows();
     const requiredRows = datosFinales.length + 1;
     if (maxRows < requiredRows) {
       hojaDest.insertRowsAfter(maxRows, requiredRows - maxRows);
     }
     const maxCols = hojaDest.getMaxColumns();
     if (maxCols < 6) {
       hojaDest.insertColumnsAfter(maxCols, 6 - maxCols);
     }

     hojaDest.getRange(1, 1, 1, 6)
             .setValues([encabezado])
             .setFontWeight("bold");

     // Escritura por lotes para evitar sobrecarga o congelamientos
     const BATCH_SIZE_LOCAL = 20000;
     for (let startRow = 0; startRow < datosFinales.length; startRow += BATCH_SIZE_LOCAL) {
       const batch = datosFinales.slice(startRow, Math.min(startRow + BATCH_SIZE_LOCAL, datosFinales.length));
       hojaDest.getRange(startRow + 2, 1, batch.length, 6).setValues(batch);
     }

     // Optimización 3: Formatear solo columnas con tipos específicos (evita setNumberFormats masivo de 350k celdas)
     hojaDest.getRange(2, 3, datosFinales.length, 1).setNumberFormat("dd-MMM-yyyy");
     hojaDest.getRange(2, 4, datosFinales.length, 1).setNumberFormat("0");

     // Optimización 4: Recorte seguro de filas sobrantes por lotes
     GeneralData_Helper_RecortarFilasSeguro(hojaDest, requiredRows);

     Logger.log(`✅ Consolidado creado con ${datosFinales.length} filas.`);
   } else {
     Logger.log("⚠️ Sin datos para escribir.");
   }

   // Optimización 1: Retornar los datos ordenados en memoria con encabezados incluidos para reutilizar sin releer de red
   return datosOrdenados;
}

// ====================================================================================
// 3. ENVIAR DATOS A LA HOJA DESTINO FINAL (Optimizado en Memoria y por Lotes)
// ====================================================================================
function enviar_consolidado(datosEnMemoria) {
   try {
     Logger.log("--- 🚀 Iniciando envío de consolidado a PRODUCCIÓN...");
     const HOJA_ORIGEN  = "Consolidado General Data";
     const HOJA_DESTINO = "A. TI - Actuals OKRs";

     let dataRaw = null;
     if (datosEnMemoria && Array.isArray(datosEnMemoria) && datosEnMemoria.length > 1) {
       Logger.log(`   ⚡ [Paso 1/4 y 2/4] Usando ${datosEnMemoria.length} filas directamente desde memoria RAM (sin releer de red)...`);
       dataRaw = datosEnMemoria;
     } else {
       Logger.log("   📂 [Paso 1/4] Abriendo archivo de origen...");
       const ssOrigen = getSpreadsheet(ID_ARCHIVO_UNICO);
       const sourceSheet = ssOrigen.getSheetByName(HOJA_ORIGEN);
       if (!sourceSheet) throw new Error(`No existe la hoja '${HOJA_ORIGEN}'`);

       Logger.log("   📊 [Paso 2/4] Leyendo datos de origen...");
       const rawValues = sourceSheet.getDataRange().getValues();
       // Optimización 2: Filtro directo por celda sin row.join()
       dataRaw = rawValues.filter(row => row[0] !== "" && row[0] != null);
     }

     if (!dataRaw || dataRaw.length < 2) throw new Error("Sin datos suficientes en el Consolidado.");

     // Ordenar siempre: vacías primero, y semanas de la última a las primeras
     Logger.log("   🔄 Asegurando ordenamiento (vacías primero, semanas de la última disponible hacia abajo)...");
     const data = GeneralData_Helper_OrdenarFilasConsolidado(dataRaw);

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

     Logger.log("   ⚡ [Paso 4/4] Escribiendo nuevos datos en destino (" + data.length + " filas en lotes)...");
     const BATCH_SIZE = 15000;
     for (let startRow = 0; startRow < data.length; startRow += BATCH_SIZE) {
       const batch = data.slice(startRow, Math.min(startRow + BATCH_SIZE, data.length));
       targetSheet.getRange(startRow + 1, 1, batch.length, data[0].length).setValues(batch);
       SpreadsheetApp.flush();
     }

     // Optimización 4: Recorte seguro de filas sobrantes por lotes
     GeneralData_Helper_RecortarFilasSeguro(targetSheet, data.length);

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

/**
 * Proceso Completo: Importa las tablas externas, consolida las métricas y las envía a la hoja final.
 * Se ejecuta por el trigger automatizado.
 */
function Importar_Consolidar_Y_Enviar() {
   Logger.log("🚀 INICIANDO PROCESO COMPLETO: IMPORTAR, CONSOLIDAR Y ENVIAR...");

   Logger.log("👉 Paso 1/3: Importando tablas externas (Orders, OPS, Supply, Open Time)...");
   GeneralData_ImportarTablas();

   // Pausa breve y flush para que el servidor de Google Sheets asiente los datos importados
   SpreadsheetApp.flush();
   Utilities.sleep(2500);
   delete _ssCache[ID_ARCHIVO_UNICO.trim()]; // Renovar conexión fresca

   Logger.log("👉 Paso 2/3: Calculando métricas y estructurando consolidado general...");
   const datosConsolidados = GeneralData_ConsolidarMetricas();

   SpreadsheetApp.flush();
   Utilities.sleep(1000);

   Logger.log("👉 Paso 3/3: Enviando datos finales a la hoja de OKRs...");
   enviar_consolidado(datosConsolidados);

   Logger.log("🏆 ¡PROCESO COMPLETO COMPLETADO CON ÉXITO!");
}

/**
 * Función rápida de prueba: importa exclusivamente la hoja '5 - Open Time'
 * para verificar la conexión y contenido sin esperar la importación de las demás tablas.
 */
function Test_Importar_Solo_OpenTime() {
  Logger.log("🧪 Probando importación exclusiva de '5 - Open Time'...");
  const confOpenTime = CONFIG_GD_IMPORT.find(c => c.nombre_hoja_destino === '5 - Open Time');
  if (!confOpenTime) {
    Logger.log("❌ No se encontró '5 - Open Time' en CONFIG_GD_IMPORT.");
    return;
  }
  const ssDestino = getSpreadsheet(ID_ARCHIVO_UNICO);
  GeneralData_Helper_Importar(confOpenTime, ssDestino);
  Logger.log("🏁 Fin de la prueba de importación de '5 - Open Time'.");
}

/**
 * Proceso Abreviado: Calcula las métricas y las envía directamente a la hoja de OKRs,
 * omitiendo el paso de importación externa (útil si los de origen ya están actualizados).
 */
function Consolidar_Y_Enviar() {
   Logger.log("🔄 INICIANDO PROCESO ABREVIADO: CONSOLIDAR Y ENVIAR...");

   Logger.log("👉 Paso 1/2: Calculando métricas y estructurando consolidado general...");
   const datosConsolidados = GeneralData_ConsolidarMetricas();

   Logger.log("👉 Paso 2/2: Enviando datos finales a la hoja de OKRs...");
   enviar_consolidado(datosConsolidados);

   Logger.log("🏆 ¡CONSOLIDACIÓN Y ENVÍO COMPLETADOS CON ÉXITO!");
}

// --- ALIAS DE COMPATIBILIDAD ---
// Mantenemos los nombres antiguos por si se llaman desde otros scripts, botones o triggers antiguos.
function GeneralData_ConsolidarYEnviar() {
  Consolidar_Y_Enviar();
}

// ====================================================================================
// HOJA DE PRUEBAS
// ====================================================================================
const ID_DESTINO_PRUEBAS = "1GO3jcGh8dSPz33A7KDyWASxPX8hYxWgIfbRuGgwqtC8";

function enviar_consolidado_pruebas(datosEnMemoria) {
   try {
     Logger.log("--- 🧪 🚀 Iniciando envío de consolidado a PRUEBAS...");
     const HOJA_ORIGEN  = "Consolidado General Data";
     const HOJA_DESTINO = "A. TI - Actuals OKRs";

     let dataRaw = null;
     if (datosEnMemoria && Array.isArray(datosEnMemoria) && datosEnMemoria.length > 1) {
       Logger.log(`   ⚡ [Paso 1/4 y 2/4] Usando ${datosEnMemoria.length} filas directamente desde memoria RAM (sin releer de red)...`);
       dataRaw = datosEnMemoria;
     } else {
       Logger.log("   📂 [Paso 1/4] Abriendo archivo de origen...");
       const ssOrigen = getSpreadsheet(ID_ARCHIVO_UNICO);
       const sourceSheet = ssOrigen.getSheetByName(HOJA_ORIGEN);
       if (!sourceSheet) throw new Error(`No existe la hoja '${HOJA_ORIGEN}'`);

       Logger.log("   📊 [Paso 2/4] Leyendo datos de origen...");
       const rawValues = sourceSheet.getDataRange().getValues();
       // Optimización 2: Filtro directo por celda sin row.join()
       dataRaw = rawValues.filter(row => row[0] !== "" && row[0] != null);
     }

     if (!dataRaw || dataRaw.length < 2) throw new Error("Sin datos suficientes en el Consolidado.");

     // Ordenar siempre: vacías primero, y semanas de la última a las primeras
     Logger.log("   🔄 Asegurando ordenamiento en PRUEBAS (vacías primero, semanas de la última disponible hacia abajo)...");
     const data = GeneralData_Helper_OrdenarFilasConsolidado(dataRaw);

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

     Logger.log("   ⚡ [Paso 4/4] Escribiendo nuevos datos en destino de PRUEBAS (" + data.length + " filas en lotes)...");
     const BATCH_SIZE = 15000;
     for (let startRow = 0; startRow < data.length; startRow += BATCH_SIZE) {
       const batch = data.slice(startRow, Math.min(startRow + BATCH_SIZE, data.length));
       targetSheet.getRange(startRow + 1, 1, batch.length, data[0].length).setValues(batch);
       SpreadsheetApp.flush();
     }

     // Optimización 4: Recorte seguro de filas sobrantes por lotes
     GeneralData_Helper_RecortarFilasSeguro(targetSheet, data.length);

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

/**
 * Función diseñada para ser ejecutada por un activador (trigger) cada 5 minutos.
 * Ejecuta el proceso completo ('Importar_Consolidar_Y_Enviar') exactamente una vez en cada uno de
 * los siguientes rangos horarios (según la zona horaria de la hoja de cálculo):
 * - Rango 1 (8:45 AM): Se ejecuta una vez entre las 08:45 y las 09:00 hs.
 * - Rango 2 (10:00 AM): Se ejecuta una vez entre las 10:00 y las 10:15 hs.
 * Se utiliza 'PropertiesService' para garantizar que no haya ejecuciones duplicadas dentro de cada ventana.
 */
function Ejecutar_Con_Filtro_Horario() {
  const ss = getSpreadsheet(ID_ARCHIVO_UNICO);
  const timeZone = ss.getSpreadsheetTimeZone();
  const ahora = new Date();
  
  // Obtener fecha actual formateada en la zona horaria de la hoja de cálculo (ej: "2026-09-04")
  const hoyStr = Utilities.formatDate(ahora, timeZone, "yyyy-MM-dd");
  const horaFormateada = Utilities.formatDate(ahora, timeZone, "HH:mm");
  
  const hora = parseInt(Utilities.formatDate(ahora, timeZone, "H"), 10);
  const minutos = parseInt(Utilities.formatDate(ahora, timeZone, "m"), 10);
  
  // Convertir a minutos transcurridos desde medianoche para comparación exacta
  const minutosTotales = (hora * 60) + minutos;
  
  // Definición de las ventanas de ejecución
  const inicio845am = (8 * 60) + 45; // 08:45 (525 minutos)
  const fin845am    = (9 * 60) + 0;  // 09:00 (540 minutos)
  
  const inicio1000am = (10 * 60) + 0;  // 10:00 (600 minutos)
  const fin1000am    = (10 * 60) + 15; // 10:15 (615 minutos)
  
  const properties = PropertiesService.getScriptProperties();
  
  if (minutosTotales >= inicio845am && minutosTotales <= fin845am) {
    const ultimaEjecucion = properties.getProperty("LAST_RUN_8_45AM");
    if (ultimaEjecucion === hoyStr) {
      Logger.log(`⏰ [RANGO 08:45 - 09:00] Ya se ejecutó el proceso completo el día de hoy (${hoyStr}).`);
      return;
    }
    Logger.log(`⏰ [RANGO 08:45 - 09:00] Hora actual: ${horaFormateada}. Iniciando ejecución del proceso completo...`);
    try {
      properties.setProperty("LAST_RUN_8_45AM", hoyStr);
      Importar_Consolidar_Y_Enviar();
    } catch (e) {
      Logger.log(`❌ Error al ejecutar el proceso de las 8:45 AM: ${e.message}`);
      properties.deleteProperty("LAST_RUN_8_45AM"); // Remueve la propiedad para permitir un reintento en el siguiente ciclo si falló
    }
  } 
  else if (minutosTotales >= inicio1000am && minutosTotales <= fin1000am) {
    const ultimaEjecucion1000am = properties.getProperty("LAST_RUN_10_00AM");
    if (ultimaEjecucion1000am === hoyStr) {
      Logger.log(`⏰ [RANGO 10:00 - 10:15] Ya se ejecutó el proceso completo el día de hoy (${hoyStr}).`);
      return;
    }
    Logger.log(`⏰ [RANGO 10:00 - 10:15] Hora actual: ${horaFormateada}. Iniciando ejecución del proceso completo...`);
    try {
      properties.setProperty("LAST_RUN_10_00AM", hoyStr);
      Importar_Consolidar_Y_Enviar();
    } catch (e) {
      Logger.log(`❌ Error al ejecutar el proceso de las 10:00 AM: ${e.message}`);
      properties.deleteProperty("LAST_RUN_10_00AM"); // Remueve la propiedad en caso de fallo
    }
  } 
  else {
    Logger.log(`💤 [FUERA DE RANGO] Hora actual: ${horaFormateada}. No es momento de ejecutar (Ventanas: 08:45-09:00 y 10:00-10:15).`);
  }
}

/**
 * Función auxiliar para crear de manera programática el trigger de Google Apps Script.
 * Ejecuta 'Ejecutar_Con_Filtro_Horario' cada 5 minutos. Solo es necesario ejecutarla una vez.
 */
function Crear_Trigger_Cada_5_Minutos() {
  const funcionDestino = "Ejecutar_Con_Filtro_Horario";
  
  // Validar si el trigger ya existe para no duplicarlo
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