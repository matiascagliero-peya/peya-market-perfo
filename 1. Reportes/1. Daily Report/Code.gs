// =================================================================
// CONFIGURACIÓN PRINCIPAL
// =================================================================
const SS_ID = "1RJ148x2zKVoM8kMXvaoR0Y1wIlp1KcoUJMsyRZ-6Y3k";
const SHEET_NAME = "Daily Data";   // antes "Extract 1" (renombrada en la planilla)
const CACHE_KEY = "daily_dash_v6";

const TARGETS_SS_ID = "1WC2EpydmUiu3dvHzYGQeDH5njZlGnfisa5DGfIknJI4";
const TARGETS_SHEET_RE = /Export Targets-Diario/i;
const TARGET_KEY_ORDERS = "Daily Confirmed Orders BE - Target";
const TARGET_KEY_GMV = "Daily GMV BE - Target";

//  ÚNICO lugar para cambiar el número de BE que se muestra en TODAS las
// páginas y en el email. Es solo etiqueta (no cambia de qué columna se leen
// los targets). Para usar otro BE, cambiá esto y listo. Ej: 'BE_LABEL'.
const BE_LABEL = "BE09";

//  LISTA ÚNICA DE ADMINS. Quien esté en este array ve los paneles de ADMIN:
// "Email" (mensajes) y "Analytics". Quien NO esté —incluido vos si te sacás— NO
// ve ninguno de los dos. Un email por línea, entre comillas y con coma al final.
// Tras editar, copiá Code.gs a GAS y redeployá el web app.
const ADMIN_EMAILS = [
  'matias.cagliero@pedidosya.com',
  'eugenio.irigoin@pedidosya.com',
  'nicki.krawiecki@pedidosya.com',
  "juan.pinori@pedidosya.com",
  // 'nombre.apellido@pedidosya.com',
];

const COUNTRY_ISO = {
  'argentina':'AR','bolivia':'BO','chile':'CL','colombia':'CO',
  'ecuador':'EC','el salvador':'SV','guatemala':'GT','honduras':'HN','nicaragua':'NI',
  'panama':'PA','paraguay':'PY','peru':'PE','uruguay':'UY',
  'república dominicana':'DO','republica dominicana':'DO','latin america':'LATAM','latam':'LATAM'
};

const FULL_COUNTRY_NAMES = {
  'AR':'Argentina','BO':'Bolivia','CL':'Chile','CO':'Colombia',
  'EC':'Ecuador','SV':'El Salvador','GT':'Guatemala','HN':'Honduras','NI':'Nicaragua',
  'PA':'Panamá','PY':'Paraguay','PE':'Perú','UY':'Uruguay','DO':'Rep. Dominicana',
};

// EMAIL_TO — lista MANUAL, VACÍA a propósito. Los destinatarios reales salen del
// sheet (getEmailRecipients). Si el sheet falla, el envío normal NO manda a nadie
// (sin fallback). EMAIL_TO SOLO lo usa el envío manual de respaldo
// (enviarSemanalPorEmailTo / enviarDailyPorEmailTo): pegás los mails acá abajo y
// corrés esa función. Admin (ADMIN_EMAILS) y prueba (TEST_RECIPIENT) NO salen de acá.
const EMAIL_TO = [
  // Pegá acá los mails SOLO si necesitás el envío manual de respaldo. Ej:
  // "nombre.apellido@pedidosya.com",
];

/* ── Lista anterior (NO activa; guardada por si hace falta el envío manual) ──────
   Copiá lo que necesites DENTRO de EMAIL_TO de arriba.
  "matias.cagliero@pedidosya.com",
  "eugenio.irigoin@pedidosya.com",
  "nicki.krawiecki@pedidosya.com",
  "tobias.fay@pedidosya.com",
  "juan.pinori@pedidosya.com",
  "juan.lopez@pedidosya.com",
  "nicolas.molina@pedidosya.com",
  "fernando.antel@pedidosya.com",
  "marcos.rodriguez@pedidosya.com",
  "nicolas.mendez@pedidosya.com",
  "nicolas.vidal@pedidosya.com",
  "esteban@pedidosya.com",
  "sebastian.scasso@pedidosya.com",
  "sebastian.genesio@pedidosya.com",
  "pablo.setuain@pedidosya.com",

  // Appended Array
  "ana.segoviano@pedidosya.com",
  "federico.avaca@pedidosya.com",
  "juan.gortari@pedidosya.com",
  "pablo.klemencic@pedidosya.com",
  "rocio.scopetta@pedidosya.com",
  "shirley.ochoa@pedidosya.com",
  "loream.montiel@pedidosya.com",
  "lorena.ibarra@pedidosya.com",
  "patricio.freixas@pedidosya.com",
  "maria.muniz@pedidosya.com",
  "daniel.santillan.2@pedidosya.com",
  "arlette.garay@pedidosya.com",
  "diego.banegas@pedidosya.com",
  "mariano.sarachu@pedidosya.com",
  "jorge.siles@pedidosya.com",
  "fabrizio.velazquez@pedidosya.com",
  "franco.mainetti@pedidosya.com",
  "nicolas.amorim@pedidosya.com",
  "ariel.ventura@pedidosya.com",
  "daiana.laperuta@pedidosya.com",
  "pilar.navarro@pedidosya.com",
  "edvin.egas@pedidosya.com",
  "juan.pesce@pedidosya.com",
  "maria.orellana@pedidosya.com",
  "leandro.arana@pedidosya.com",
  "ronald.rodriguez@pedidosya.com",
  "paul.zavala@pedidosya.com",
  "flavio.lia@pedidosya.com",
  "francisco.loayza@pedidosya.com",
  "hugo.diaz@pedidosya.com",
  "daniela.ossio@pedidosya.com",
  "daniel.guital@pedidosya.com",
  "maximilian.krasner@pedidosya.com",
  "sabrina.puricelli@pedidosya.com",
  "maria.olaso@pedidosya.com",
  "sofia.colantone@pedidosya.com",
  "dario.berro@pedidosya.com",
  "micaela.manzo@pedidosya.com",
  "ramiro.olivieri@pedidosya.com",
  "carolina.varela.2@pedidosya.com",
  "carlota.paiva@pedidosya.com",
  "maria.rodriguez.3@pedidosya.com",
  "joshua.lamas@pedidosya.com",
  "ricardo.charpentier@pedidosya.com",
  "ana.romeri@pedidosya.com",
  "francisco.alvarez@pedidosya.com",
  "jimmy.molina@pedidosya.com",
  "jorge.herrera@pedidosya.com",
  "maria.deves@pedidosya.com",
  "pamela.escoto@pedidosya.com",
  "alejandro.jorge@pedidosya.com",
  "gonzalo.servan@pedidosya.com",
  "franco.mira@pedidosya.com",
  "juan.espinosa@pedidosya.com",
  "camilo.etchebehere@pedidosya.com",
  "madelin.rodriguez@pedidosya.com",
  "david.bueno@pedidosya.com",
  "julio.ilich@pedidosya.com",
  "juan.mullen@pedidosya.com",
  "manuel.leoni@pedidosya.com",
  "martin.lazzarini@pedidosya.com",
  "ramiro.tesone@pedidosya.com",
  "fernando.carbonetti@pedidosya.com",
  "leticia.pinto@pedidosya.com",
  "andrea.ponce.2@pedidosya.com",
  "sarah.marquez@pedidosya.com",
  "andrea.halabi@pedidosya.com",
  "santiago.estevez@pedidosya.com",
  "gustavo.orellana@pedidosya.com",
  "leo.lamas@pedidosya.com",
  "nikole.pilquinao@pedidosya.com",
  "jess.estrella@pedidosya.com",
  "fabian.mendez@pedidosya.com",
  "natalia.nadal@pedidosya.com",
  "felipe.salaverria@pedidosya.com",
  "pablo.martinez.5@pedidosya.com",
  "laura.prieto@pedidosya.com",
  "david.santamaria@pedidosya.com",
  "jose.quacquarini@pedidosya.com",
  "jose.straguzzi@pedidosya.com",
  "emilce.alfonso@pedidosya.com",
  "alfonsina.boccardo@pedidosya.com",
  "nacho.angelino@pedidosya.com",
  "tomas.gavina@pedidosya.com",
  "francisco.trujillo@pedidosya.com",
  "gerardo.morocho@pedidosya.com",
  "carlos.mella@pedidosya.com",
  "walter.robles@pedidosya.com",
  "evalencia@pedidosya.com",
  "javier.aranguiz@pedidosya.com",
  "juan.muxi@pedidosya.com",
  "maximiliano.nocioni@pedidosya.com",
  "juan.lopezsaubidet@pedidosya.com",
  "alex.gejtman@pedidosya.com",
  "alejandro.figari@pedidosya.com",
  "patricia.gonzalez@pedidosya.com",
  "ivan.valdez@pedidosya.com",
  "eduardo.escobar@pedidosya.com",
  "paola.sevilla@pedidosya.com",
  "rodrigo.cambon@pedidosya.com",
  "edgar.maradiaga@pedidosya.com",
  "yoel.kwacz@pedidosya.com",
  "agustina.sanguinetti@pedidosya.com",
  "andres.musetti@pedidosya.com",
  "tomas.cordes@pedidosya.com",
*/

// ── LISTA DE DISTRIBUCIÓN DINÁMICA (desde el sheet) ──────────────────────────
// Los destinatarios masivos del mail (diario y semanal) salen de este sheet,
// pestaña "Listado destinatarios", columna "Mail". Admin (ADMIN_EMAILS) y prueba
// (TEST_RECIPIENT) NO: esos siguen hardcodeados. Si el sheet falla o está vacío,
// se cae a EMAIL_TO (respaldo de arriba) para no quedarse nunca sin enviar.
var RECIPIENTS_SS_ID = '1gBt9iakSVSR8aI3vp3mEW_5XKvJBJZ0e6KzScRjezvo';
var RECIPIENTS_SHEET = 'Lista destinatarios';   // nombre EXACTO de la pestaña (captura del usuario)
var RECIPIENTS_COL   = 'Mail';   // encabezado EXACTO de la columna con los emails

// Lee la columna "Mail" del sheet: emails trimmeados, validados (tienen "@") y
// deduplicados (case-insensitive, conservando el texto original). Nunca lanza.
function _readRecipientsFromSheet() {
  var out = [];
  try {
    var ss = SpreadsheetApp.openById(RECIPIENTS_SS_ID);
    // Tolerante: "Lista destinatarios" o "Listado destinatarios" (con/sin variantes).
    var sh = ss.getSheetByName(RECIPIENTS_SHEET) ||
             ss.getSheets().find(function(s){ return /lista(do)?\s*destinatarios/i.test(s.getName()); });
    if (!sh) { Logger.log('_readRecipientsFromSheet: no existe la pestaña "' + RECIPIENTS_SHEET + '"'); return out; }
    var data = sh.getDataRange().getValues();
    if (data.length < 2) return out;
    var H = data[0].map(function(h){ return String(h).trim().toLowerCase(); });
    var iMail = H.indexOf(RECIPIENTS_COL.toLowerCase());
    if (iMail < 0) { Logger.log('_readRecipientsFromSheet: falta la columna "' + RECIPIENTS_COL + '"'); return out; }
    var seen = {};
    for (var i = 1; i < data.length; i++) {
      var orig = String(data[i][iMail] || '').trim();
      var k = orig.toLowerCase();
      if (!orig || k.indexOf('@') < 0 || seen[k]) continue;
      seen[k] = true;
      out.push(orig);
    }
  } catch (e) { Logger.log('_readRecipientsFromSheet: ' + (e && e.message)); }
  return out;
}

// Lista final de destinatarios masivos. Cachea 1h (evita releer el sheet en cada
// lote; como diario/semanal se envían con >1h de diferencia, cada envío lee fresco).
// SIN fallback: si el sheet viene vacío/ilegible, devuelve [] → NO se envía a nadie.
// (Para un envío de emergencia está EMAIL_TO + enviar…PorEmailTo, más abajo.)
// Admin y prueba NO pasan por acá.
var _FORCE_RECIPIENTS = null;   // override manual: si es un array, se usa tal cual (envío por EMAIL_TO)
function getEmailRecipients() {
  if (_FORCE_RECIPIENTS) return _FORCE_RECIPIENTS.slice();
  var CK = 'cache_recipients_v1', cache = CacheService.getScriptCache();
  var hit = cache.get(CK);
  if (hit) { try { var a = JSON.parse(hit); if (a && a.length) return a; } catch(e){} }
  var list = _readRecipientsFromSheet();
  if (!list.length) { Logger.log('[AVISO] getEmailRecipients: sheet vacío/ilegible → 0 destinatarios, NO se envía (sin fallback a EMAIL_TO).'); return []; }
  try { cache.put(CK, JSON.stringify(list), 3600); } catch(e){}
  return list;
}

// DEBUG (correr desde el editor): muestra de dónde salen los destinatarios y cuántos.
function debugDestinatarios() {
  var L = [], log = function(m){ Logger.log(m); L.push(m); };
  try {
    log('════ DEBUG DESTINATARIOS ════');
    var ss = SpreadsheetApp.openById(RECIPIENTS_SS_ID);
    log('Planilla: "' + ss.getName() + '"  (' + RECIPIENTS_SS_ID + ')');
    var sh = ss.getSheetByName(RECIPIENTS_SHEET);
    log('Pestaña "' + RECIPIENTS_SHEET + '": ' + (sh ? '[OK] existe' : '[FAIL] NO existe'));
    if (!sh) { log('Pestañas disponibles: ' + JSON.stringify(ss.getSheets().map(function(s){return s.getName();}))); return L.join('\n'); }
    log('Encabezados: ' + JSON.stringify(sh.getDataRange().getValues()[0]));
    var fromSheet = _readRecipientsFromSheet();
    log('Emails leídos del sheet (col "' + RECIPIENTS_COL + '"): ' + fromSheet.length);
    log('Primeros 5: ' + JSON.stringify(fromSheet.slice(0, 5)));
    try { CacheService.getScriptCache().remove('cache_recipients_v1'); } catch(e){}
    var fin = getEmailRecipients();
    log('LISTA FINAL a enviar: ' + fin.length + (fromSheet.length ? '  [OK] (del sheet)' : '  [AVISO] 0 → NO se envía (el sheet falló; sin fallback)'));
    log('EMAIL_TO (envío manual de respaldo): ' + EMAIL_TO.length + (EMAIL_TO.length ? ' mail(s) cargados' : ' vacío'));
    log('Admin (queda en código, ADMIN_EMAILS): ' + JSON.stringify(ADMIN_EMAILS));
    log('Prueba (queda en código, TEST_RECIPIENT): matias.cagliero@pedidosya.com');
    log('════ FIN ════');
  } catch (err) { log('[FAIL] EXCEPCIÓN: ' + (err && err.message)); }
  return L.join('\n');
}

// ── ENVÍO MANUAL POR EMAIL_TO (respaldo, NO usa el sheet) ────────────────────
// Úsalas SOLO si el sheet falla y necesitás mandar igual: pegá los destinatarios
// en la const EMAIL_TO (arriba) y corré la función que corresponda desde el editor.
// Fuerzan la lista a EMAIL_TO por esta corrida (_FORCE_RECIPIENTS) y la resetean.
function enviarSemanalPorEmailTo() {
  if (!EMAIL_TO.length) { Logger.log('EMAIL_TO está vacío. Pegá los destinatarios en la const EMAIL_TO (Code.gs) y volvé a correr.'); return { ok:false, error:'EMAIL_TO vacío' }; }
  _FORCE_RECIPIENTS = EMAIL_TO;
  try {
    var r = sendWeeklyMtdEmail(false, false, true); // force=true para envío manual
    if (r && r.ok) {
      try {
        var rng = (typeof _weekRangeLunDom === 'function') ? _weekRangeLunDom() : null;
        if (rng) {
          PropertiesService.getScriptProperties().setProperty(PROP_KEY_SEM, rng.start);
          PropertiesService.getScriptProperties().deleteProperty('WEEKLY_BLOCKED_REASON');
        }
      } catch (eProp) {}
    }
    Logger.log('[OK] Mail SEMANAL enviado por EMAIL_TO a ' + EMAIL_TO.length + ' destinatario(s).');
    return r;
  } finally { _FORCE_RECIPIENTS = null; }
}
function enviarDailyPorEmailTo() {
  if (!EMAIL_TO.length) { Logger.log('EMAIL_TO está vacío. Pegá los destinatarios en la const EMAIL_TO (Code.gs) y volvé a correr.'); return { ok:false, error:'EMAIL_TO vacío' }; }
  _FORCE_RECIPIENTS = EMAIL_TO;
  try {
    var r = sendDailyEmail(false);
    Logger.log('[OK] Mail DIARIO enviado por EMAIL_TO a ' + EMAIL_TO.length + ' destinatario(s).');
    return r;
  } finally { _FORCE_RECIPIENTS = null; }
}

// =================================================================
// ENVÍOS DE PRUEBA RÁPIDOS
// =================================================================
// Mandan el correo real (diario o semanal) con el contenido y PDF adjunto
// correspondientes, pero únicamente a matias.cagliero@pedidosya.com.
// No marcan el reporte como enviado en script properties, por lo que son
// 100% seguros de usar en cualquier momento para probar el correo.
function enviarPruebaDailyRapido() {
  return enviarPruebaEmail(); // Delegado en la función de Email.gs
}

function enviarPruebaSemanalRapido() {
  return enviarPruebaSemanal(); // Delegado en la función de Weekly_Email.gs
}

function forzarEnvioPruebaSemanalRapido() {
  return forzarEnvioPruebaSemanal(); // Delegado en la función de Weekly_Email.gs
}

const EMAIL_SUBJECT = "PedidosYa Market - Daily Report";
const APP_URL = "https://script.google.com/a/pedidosya.com/macros/s/AKfycbweXEclWcWIkaH1OZ7YxMvWj70-Ku4oyA9g098Ea_is7-Pqr0GPVPNpdYIn8q3NOzKqsw/exec";

// =================================================================
// TTL DINÁMICO
// =================================================================
function _getCacheTTL() {
  const ahora = new Date();
  const hh = ahora.getHours();
  const mm = ahora.getMinutes();
  const minAhora = hh * 60 + mm;
  const min10hs = 10 * 60;
  const minHasta = minAhora < min10hs ? min10hs - minAhora : (24 * 60 - minAhora) + min10hs;
  return Math.min(minHasta * 60, 21600);
}

// =================================================================
// DICCIONARIO DE MÉTRICAS
// =================================================================
// Colores accent por métrica (usado en email HTML y dashboard)
const MET_COLORS = {
  orders:'#e50044', gmv:'#2563eb', new_users:'#ea580c', wis:'#0284c7', wis_uf:'#0891b2',
  seamless:'#16a34a', delivery_time:'#d97706', assignment_time:'#9333ea', rejected_orders:'#dc2626', session_orders:'#7c3aed',
  assignment_time_orders_over_6min:'#f43f5e'
};

const METRIC_DEFS = [
  { id: 1,  key: 'orders',          label: 'Orders',              type: 'sum',   fmt: 'int', varFmt: 'pct_rel', columna_suma: 'orders',          higherGood: true,  beKey: 'orders', lwIsRatio: false },
  { id: 2,  key: 'gmv',             label: 'GMV (EUR)',           type: 'sum',   fmt: 'eur', varFmt: 'pct_rel', columna_suma: 'gmv',             higherGood: true,  beKey: 'gmv',    lwIsRatio: false },
  { id: 3,  key: 'new_users',       label: 'New Users',           type: 'sum',   fmt: 'int', varFmt: 'pct_rel', columna_suma: 'new_users',       higherGood: true,  beKey: null,     lwIsRatio: false },
  { id: 4,  key: 'wis',             label: 'WIS %',               type: 'ratio', fmt: 'pct', varFmt: 'pp',      columna_numerador: 'wis_numerador',    columna_denominador: 'wis_denominador',    higherGood: true,  beKey: null, lwIsRatio: true },
  { id: 5,  key: 'wis_uf',          label: 'WIS UF %',            type: 'ratio', fmt: 'pct', varFmt: 'pp',      columna_numerador: 'wis_uf_numerador', columna_denominador: 'wis_uf_denominador', higherGood: true,  beKey: null, lwIsRatio: true },
  { id: 6,  key: 'seamless',        label: 'Seamless Delivery %', type: 'ratio', fmt: 'pct', varFmt: 'pp',      columna_numerador: 'seamless_numerador', columna_denominador: 'total_orders',     higherGood: true,  beKey: null, lwIsRatio: true },
  { id: 7,  key: 'delivery_time',   label: 'AVG Delivery Time',   type: 'ratio', fmt: 'min', varFmt: 'min_abs', columna_numerador: 'delivery_time_sum',   columna_denominador: 'delivery_time_order_count',   higherGood: false, beKey: null, lwIsRatio: true },
  { id: 11, key: 'assignment_time_orders_over_6min', label: 'Assignment T. > 6 min %', type: 'ratio', fmt: 'pct', varFmt: 'pp', columna_numerador: 'assignment_time_orders_over_6min', columna_denominador: 'assignment_time_order_count', higherGood: false, beKey: null, lwIsRatio: true },
  { id: 8,  key: 'assignment_time', label: 'Assignment Time',     type: 'ratio', fmt: 'min', varFmt: 'min_abs', columna_numerador: 'assignment_time_sum', columna_denominador: 'assignment_time_order_count', higherGood: false, beKey: null, lwIsRatio: true },
  { id: 9,  key: 'rejected_orders', label: 'Rejected Orders %',   type: 'ratio', fmt: 'pct', varFmt: 'pp',      columna_numerador: 'rejected_orders', columna_denominador: 'total_orders', higherGood: false, beKey: null, lwIsRatio: true },
  { id: 10, key: 'session_orders',  label: 'HC Sessions orders %', type: 'ratio', fmt: 'pct', varFmt: 'pp',      columna_numerador: 'session_orders',  columna_denominador: 'orders',       higherGood: false, beKey: null, lwIsRatio: true } // menos es mejor
];

const METRIC_COLS = {
  orders:          ['d1_orders', 'd8_orders', 'lw_orders'],
  gmv:             ['d1_gmv', 'd8_gmv', 'lw_gmv'],
  new_users:       ['d1_new_users','d8_new_users','lw_new_users'],
  wis:             ['d1_wis_numerador','d8_wis_numerador','lw_wis_numerador','d1_wis_denominador','d8_wis_denominador','lw_wis_denominador'],
  wis_uf:          ['d1_wis_uf_numerador','d8_wis_uf_numerador','lw_wis_uf_numerador','d1_wis_uf_denominador','d8_wis_uf_denominador','lw_wis_uf_denominador'],
  seamless:        ['d1_seamless_numerador','d8_seamless_numerador','lw_seamless_numerador','d1_total_orders','d8_total_orders','lw_total_orders'],
  delivery_time:   ['d1_delivery_time_sum','d8_delivery_time_sum','lw_delivery_time_sum','d1_delivery_time_order_count','d8_delivery_time_order_count','lw_delivery_time_order_count'],
  assignment_time: ['d1_assignment_time_sum','d8_assignment_time_sum','lw_assignment_time_sum','d1_assignment_time_order_count','d8_assignment_time_order_count','lw_assignment_time_order_count'],
  rejected_orders: ['d1_rejected_orders','d8_rejected_orders','lw_rejected_orders','d1_total_orders','d8_total_orders','lw_total_orders'],
  session_orders:  ['d1_session_orders','d8_session_orders','lw_session_orders','d1_orders','d8_orders','lw_orders'],
  assignment_time_orders_over_6min: ['d1_assignment_time_orders_over_6min','d8_assignment_time_orders_over_6min','lw_assignment_time_orders_over_6min','d1_assignment_time_order_count','d8_assignment_time_order_count','lw_assignment_time_order_count']
};

const GLOBAL_FALLBACKS = {
  'confirmed_orders': ['orders'],
  'total_orders_all_status': ['total_orders'],
  'seamless_delivery': ['seamless_numerador'],
  'non_forced_completed_orders_logistics': ['delivery_time_order_count'],
  'open_time': ['weighted_open_time', 'weighted_open_time_percent', 'open_time_%', 'wot'],
  'assignment_time_orders_over_6min': ['assignment_time_over_6min', 'orders_over_6min', 'saturation_orders_over_6min'],
  'assignment_time_order_count': ['picker_shift_confirmed_orders', 'assignment_time_confirmed_orders'],
  'd1_assignment_time_confirmed_orders': ['d1_assignment_time_order_count'],
  'd8_assignment_time_confirmed_orders': ['d8_assignment_time_order_count'],
  'lw_assignment_time_confirmed_orders': ['lw_assignment_time_order_count'],
  'd1_orders_over_6min': ['d1_saturation_orders_over_6min'],
  'd8_orders_over_6min': ['d8_saturation_orders_over_6min'],
  'lw_orders_over_6min': ['lw_saturation_orders_over_6min'],
  'd1_assignment_time_order_count': ['d1_assignment_time_confirmed_orders'],
  'd8_assignment_time_order_count': ['d8_assignment_time_confirmed_orders'],
  'lw_assignment_time_order_count': ['lw_assignment_time_confirmed_orders'],
  'd1_assignment_time_orders_over_6min': ['d1_orders_over_6min', 'd1_saturation_orders_over_6min'],
  'd8_assignment_time_orders_over_6min': ['d8_orders_over_6min', 'd8_saturation_orders_over_6min'],
  'lw_assignment_time_orders_over_6min': ['lw_orders_over_6min', 'lw_saturation_orders_over_6min']
};

// =================================================================
// WEB SERVER — ENRUTADOR UNIFICADO
// =================================================================
function doGet(e) {
  var page = (e && e.parameter) ? (e.parameter.pagina || e.parameter.page || 'daily') : 'daily';

  var pages = {
    'daily':          { file: '1_Daily',             title: 'Daily — PeYa Markets' },
    'whs-date':       { file: '2_WHS_by_Metric',     title: 'WHS by Metric — PeYa Markets' },
    'country-metric': { file: '3_WHS_all_Metrics',   title: 'WHS all Metrics — PeYa Markets' },
    'mtd':            { file: '4_MTD',               title: 'MTD by Country — PeYa Markets' },
    'mtd-whs':        { file: '6_MTD_by_WHS',        title: 'MTD by WHS — PeYa Markets' },
    'grafic':         { file: '5_Grafico_vs_Target', title: 'Gráfico vs ' + BE_LABEL + ' — PeYa Markets' },
    'email':          { file: '7_Email',             title: 'Email — PeYa Markets' },
    'rrcompare':      { file: '8_RR_Compare',        title: 'RR View' },
    'analytics':      { file: '10_Analytics',        title: 'Analytics — PeYa Markets' },
    // Alias por compatibilidad con links viejos (All Dates / MTD by Metric → MTD by WHS).
    'mtd-metric':     { file: '6_MTD_by_WHS',        title: 'MTD by WHS — PeYa Markets' },
    'daily-hist':     { file: '6_MTD_by_WHS',        title: 'MTD by WHS — PeYa Markets' },
  };

  var def = pages[page] || pages['daily'];

  // Registrar la vista (quién, cuándo, qué página, de dónde). Nunca rompe la carga.
  try { _logView(page, (e && e.parameter) ? e.parameter.src : ''); } catch (e2) {}

  // "Email" y "Analytics" son de ADMIN: solo los ADMIN_EMAILS.
  // RR View (rrcompare) quedó PÚBLICA (a pedido): la ve cualquiera y aparece en el nav.
  var adminOnly = (page === 'email' || page === 'analytics');
  if (adminOnly && !_isEmailAdmin()) {
    return HtmlService.createHtmlOutput(_accessDeniedHtml())
      .setTitle('Acceso restringido — PeYa Markets')
      .addMetaTag('viewport', 'width=device-width, initial-scale=1.0')
      .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);
  }

  // Las páginas usan el scriptlet <?!= include('_nav'); ?> para la navegación
  // compartida, por eso se sirven como template (evaluate).
  return HtmlService.createTemplateFromFile(def.file).evaluate()
    .setTitle(def.title)
    .addMetaTag('viewport', 'width=device-width, initial-scale=1.0')
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);
}

function include(filename) {
  // Se evalúa como template para poder inyectar BE_LABEL (y futuros valores)
  // en el parcial compartido (_nav), que está incluido en todas las páginas.
  var t = HtmlService.createTemplateFromFile(filename);
  t.BE_LABEL = BE_LABEL;
  t.EMAIL_ADMIN = _isEmailAdmin();          // controla si se muestra la pestaña "Email"
  t.ANALYTICS_VIEWER = _isAnalyticsViewer();// controla si se muestra la pestaña "Analytics"
  return t.evaluate().getContent();
}

// Pantalla de acceso restringido para la página "Email".
function _accessDeniedHtml() {
  var who = _currentUserEmail() || '(no identificado)';
  return '<!DOCTYPE html><html lang="es"><head><meta charset="UTF-8">' +
    '<meta name="viewport" content="width=device-width, initial-scale=1.0">' +
    '<style>body{margin:0;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Arial,sans-serif;' +
    'background:#f8fafc;color:#0f172a;display:flex;align-items:center;justify-content:center;min-height:100vh;}' +
    '.box{background:#fff;border:1px solid #e2e8f0;border-radius:14px;box-shadow:0 4px 12px rgba(0,0,0,.05);' +
    'padding:36px 40px;max-width:420px;text-align:center;}' +
    '.dot{width:46px;height:46px;border-radius:50%;background:#fff1f2;display:flex;align-items:center;justify-content:center;margin:0 auto 14px;}' +
    'h1{font-size:18px;margin:0 0 8px;} p{font-size:13px;color:#475569;line-height:1.5;margin:0 0 6px;}' +
    '.mail{font-size:12px;color:#94a3b8;margin-top:10px;word-break:break-all;}</style></head><body>' +
    '<div class="box"><div class="dot">' +
    '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#e50044" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">' +
    '<rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg></div>' +
    '<h1>Acceso restringido</h1>' +
    '<p>Esta sección es solo para el administrador del reporte.</p>' +
    '<p class="mail">Tu usuario: ' + who + '</p></div></body></html>';
}

// =================================================================
// MENSAJE PERSONALIZADO DEL EMAIL
// Texto opcional que se configura desde la página "Email" y se muestra
// arriba de todo en el mail diario. Si está vacío, no se muestra nada.
// Se guarda en ScriptProperties (persistente entre envíos hasta que lo cambies).
// =================================================================
const EMAIL_MSG_KEY = 'EMAIL_CUSTOM_MSG';
const EMAIL_MSG_BY_KEY = 'EMAIL_CUSTOM_MSG_BY';   // email del admin que escribió el mensaje
const EMAIL_MSG_AT_KEY = 'EMAIL_CUSTOM_MSG_AT';   // fecha/hora (texto) en que se guardó
const EMAIL_MSG_ONCE_KEY = 'EMAIL_CUSTOM_MSG_ONCE'; // 'true' si se autodestruye tras el envío

const WEEKLY_EMAIL_MSG_KEY = 'WEEKLY_EMAIL_CUSTOM_MSG';
const WEEKLY_EMAIL_MSG_BY_KEY = 'WEEKLY_EMAIL_CUSTOM_MSG_BY';
const WEEKLY_EMAIL_MSG_AT_KEY = 'WEEKLY_EMAIL_CUSTOM_MSG_AT';
const WEEKLY_EMAIL_MSG_ONCE_KEY = 'WEEKLY_EMAIL_CUSTOM_MSG_ONCE';

// El admin de "Email" y "Analytics" se controla con ADMIN_EMAILS (al principio del archivo).

function _currentUserEmail() {
  try { return (Session.getActiveUser().getEmail() || '').toLowerCase(); } catch (e) { return ''; }
}

// Admin = estar en ADMIN_EMAILS. Sin bypass: si tu email no está en la lista,
// no sos admin (aunque seas el dueño del script).
function _isEmailAdmin() {
  var e = _currentUserEmail();
  return e !== '' && ADMIN_EMAILS.map(function (x) { return x.toLowerCase(); }).indexOf(e) !== -1;
}

// "Email" y "Analytics" comparten la MISMA lista de admins (ADMIN_EMAILS).
function _isAnalyticsViewer() {
  return _isEmailAdmin();
}

function getEmailMessage() {
  return PropertiesService.getScriptProperties().getProperty(EMAIL_MSG_KEY) || '';
}

// "eugenio.irigoin@pedidosya.com" → "Eugenio Irigoin" (mejor esfuerzo; ignora números).
function _emailToName(email) {
  var local = String(email || '').split('@')[0];
  if (!local) return '';
  return local.split(/[._]+/)
    .filter(function (w) { return w && !/^\d+$/.test(w); })
    .map(function (w) { return w.charAt(0).toUpperCase() + w.slice(1); })
    .join(' ');
}

// Mensaje + quién lo escribió + cuándo + si es de un solo uso.
function getEmailMessageInfo() {
  var p = PropertiesService.getScriptProperties();
  var by = p.getProperty(EMAIL_MSG_BY_KEY) || '';
  return {
    msg:    p.getProperty(EMAIL_MSG_KEY) || '',
    by:     by,
    byName: _emailToName(by),
    at:     p.getProperty(EMAIL_MSG_AT_KEY) || '',
    once:   p.getProperty(EMAIL_MSG_ONCE_KEY) === 'true'
  };
}

function setEmailMessage(msg, once) {
  if (!_isEmailAdmin()) return { ok: false, error: 'No autorizado.' };
  var props = PropertiesService.getScriptProperties();
  var clean = (msg == null) ? '' : String(msg).trim();
  if (clean === '') {
    props.deleteProperty(EMAIL_MSG_KEY);
    props.deleteProperty(EMAIL_MSG_BY_KEY);
    props.deleteProperty(EMAIL_MSG_AT_KEY);
    props.deleteProperty(EMAIL_MSG_ONCE_KEY);
    return { ok: true, message: '', by: '', byName: '', at: '', once: false };
  }
  // Guardamos QUIÉN lo escribió (el admin logueado), CUÁNDO y si es de un solo envío.
  var by = _currentUserEmail();
  var at = Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'yyyy-MM-dd HH:mm');
  props.setProperty(EMAIL_MSG_KEY, clean);
  props.setProperty(EMAIL_MSG_BY_KEY, by);
  props.setProperty(EMAIL_MSG_AT_KEY, at);
  if (once) {
    props.setProperty(EMAIL_MSG_ONCE_KEY, 'true');
  } else {
    props.deleteProperty(EMAIL_MSG_ONCE_KEY);
  }
  return { ok: true, message: clean, by: by, byName: _emailToName(by), at: at, once: !!once };
}

function getWeeklyEmailMessageInfo() {
  var p = PropertiesService.getScriptProperties();
  var by = p.getProperty(WEEKLY_EMAIL_MSG_BY_KEY) || '';
  return {
    msg:    p.getProperty(WEEKLY_EMAIL_MSG_KEY) || '',
    by:     by,
    byName: _emailToName(by),
    at:     p.getProperty(WEEKLY_EMAIL_MSG_AT_KEY) || '',
    once:   p.getProperty(WEEKLY_EMAIL_MSG_ONCE_KEY) === 'true'
  };
}

function setWeeklyEmailMessage(msg, once) {
  if (!_isEmailAdmin()) return { ok: false, error: 'No autorizado.' };
  var props = PropertiesService.getScriptProperties();
  var clean = (msg == null) ? '' : String(msg).trim();
  if (clean === '') {
    props.deleteProperty(WEEKLY_EMAIL_MSG_KEY);
    props.deleteProperty(WEEKLY_EMAIL_MSG_BY_KEY);
    props.deleteProperty(WEEKLY_EMAIL_MSG_AT_KEY);
    props.deleteProperty(WEEKLY_EMAIL_MSG_ONCE_KEY);
    return { ok: true, message: '', by: '', byName: '', at: '', once: false };
  }
  var by = _currentUserEmail();
  var at = Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'yyyy-MM-dd HH:mm');
  props.setProperty(WEEKLY_EMAIL_MSG_KEY, clean);
  props.setProperty(WEEKLY_EMAIL_MSG_BY_KEY, by);
  props.setProperty(WEEKLY_EMAIL_MSG_AT_KEY, at);
  if (once) {
    props.setProperty(WEEKLY_EMAIL_MSG_ONCE_KEY, 'true');
  } else {
    props.deleteProperty(WEEKLY_EMAIL_MSG_ONCE_KEY);
  }
  return { ok: true, message: clean, by: by, byName: _emailToName(by), at: at, once: !!once };
}

// =================================================================
// ORIGEN DEL RR (global, lo elige el admin y aplica a TODOS)
//   'export' → RR/BE Mes salen de la hoja "RR orders y GMV export"
//   'calc'   → RR/BE Mes calculados por nosotros (BE = target mensual,
//              RR = BE × (Actual MTD / BE MTD))
// El valor se guarda en ScriptProperties (compartido por todos los usuarios),
// así que la elección del admin se ve en daily / MTD / gráfico / email.
// =================================================================
const RR_SOURCE_KEY = 'RR_SOURCE_MODE';

function getRRSource() {
  var v = PropertiesService.getScriptProperties().getProperty(RR_SOURCE_KEY);
  return (v === 'calc') ? 'calc' : 'export';   // default: export
}

function setRRSource(src) {
  if (!_isEmailAdmin()) return { ok: false, error: 'No autorizado.' };
  var clean = (src === 'calc') ? 'calc' : 'export';
  PropertiesService.getScriptProperties().setProperty(RR_SOURCE_KEY, clean);
  // Limpiar la caché del RR para que el cambio se vea YA en todas las páginas.
  try { CacheService.getScriptCache().remove('cache_rrdata_mtd'); } catch (e) {}
  Logger.log('[RR] Origen cambiado a: ' + clean);
  return { ok: true, source: clean };
}

// =================================================================
// ANALYTICS — registro de vistas del reporte (quién, cuándo, página, origen)
// =================================================================
var ANALYTICS_SS_ID = '1gBt9iakSVSR8aI3vp3mEW_5XKvJBJZ0e6KzScRjezvo';
var ANALYTICS_SHEET = 'Vistas';
var ANALYTICS_SHEET_GID = 0;            // gid de la pestaña "Vistas" (del link que pasaste)

// Pestaña de analytics. La resuelve de forma robusta para NUNCA terminar leyendo
// o escribiendo en una pestaña vacía paralela por una diferencia de nombre:
//   1) por gid (ANALYTICS_SHEET_GID)  2) por nombre exacto
//   3) por nombre ignorando mayúsculas/espacios  4) último recurso: crearla.
// Columnas esperadas: Timestamp · Email · Pagina · Origen.
function _analyticsSheet() {
  var ss = SpreadsheetApp.openById(ANALYTICS_SS_ID);
  var sheets = ss.getSheets();
  var sh = null;
  for (var i = 0; i < sheets.length; i++) {           // 1) por gid
    if (sheets[i].getSheetId() === ANALYTICS_SHEET_GID) { sh = sheets[i]; break; }
  }
  if (!sh) sh = ss.getSheetByName(ANALYTICS_SHEET);   // 2) nombre exacto
  if (!sh) {                                           // 3) nombre normalizado
    var target = ANALYTICS_SHEET.toLowerCase().replace(/\s+/g, '');
    for (var j = 0; j < sheets.length; j++) {
      if (sheets[j].getName().toLowerCase().replace(/\s+/g, '') === target) { sh = sheets[j]; break; }
    }
  }
  if (!sh) sh = ss.insertSheet(ANALYTICS_SHEET);       // 4) crear
  if (sh.getLastRow() === 0) {
    sh.getRange(1, 1, 1, 4).setValues([['Timestamp', 'Email', 'Pagina', 'Origen']]);
  }
  return sh;
}

// Convierte el valor de la celda de fecha en un Date válido (o null). Tolera:
// objetos Date, números (serial de Sheets) y texto ISO o dd/MM/yyyy [HH:mm[:ss]]
// (formato regional es-AR), que con new Date() solo daría "Invalid Date".
function _parseTs(v) {
  if (v instanceof Date) return isNaN(v.getTime()) ? null : v;
  if (v == null || v === '') return null;
  if (typeof v === 'number') {
    var d0 = new Date(Date.UTC(1899, 11, 30) + Math.round(v * 86400000));
    return isNaN(d0.getTime()) ? null : d0;
  }
  var s = String(v).trim();
  var d = new Date(s);
  if (!isNaN(d.getTime())) return d;
  var m = s.match(/^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})(?:[ T](\d{1,2}):(\d{2})(?::(\d{2}))?)?$/);
  if (m) {
    var yr = +m[3]; if (yr < 100) yr += 2000;
    var dt = new Date(yr, (+m[2]) - 1, +m[1], +(m[4] || 0), +(m[5] || 0), +(m[6] || 0));
    return isNaN(dt.getTime()) ? null : dt;
  }
  return null;
}

// Registra una vista (lo llama doGet). Robusto: cualquier error se ignora.
function _logView(page, src) {
  var lock = null, got = false;
  try {
    var email = '';
    try { email = (Session.getActiveUser().getEmail() || '').toLowerCase(); } catch (e) {}
    // Se registran TODAS las vistas, incluidos los admins (pedido de matias).
    // Antes se excluían los ADMIN_EMAILS para no inflar; si en algún momento
    // querés volver a esa lógica, descomentá la línea de abajo.
    // if (email && ADMIN_EMAILS.map(function(x){ return x.toLowerCase(); }).indexOf(email) !== -1) return;
    // Registra como origen 'mail' si viene del diario (src === 'mail') o del semanal (src === 'mail-semanal')
    var origen = (src === 'mail' || src === 'mail-semanal') ? 'mail' : 'directo';
    var row = [new Date(), email, page || 'daily', origen];

    // Lock SUAVE: intentamos serializar para reducir choques, pero NUNCA
    // descartamos la vista si no se consigue el lock. Antes esto era
    // waitLock(10000): en un pico (mail a +100 personas que abren el link
    // casi a la vez) todas las vistas se encolaban en ESTE lock global —el app
    // corre "como el dueño", así que el lock es único para todos—; las que no
    // lo tomaban en 10s LANZABAN excepción y la fila se PERDÍA. Por eso Analytics
    // registraba "solo algunas sesiones". tryLock devuelve true/false (no lanza);
    // pase lo que pase, igual escribimos.
    lock = LockService.getScriptLock();
    try { got = lock.tryLock(2000); } catch (e) { got = false; }
    _appendRowRetry(row);   // reintenta ante errores transitorios; appendRow es atómico
  } catch (e) {
    // Solo llega acá si fallaron TODOS los reintentos. Queda en el registro de
    // ejecución para poder detectar si algo del backend de Sheets está caído.
    try { Logger.log('[_logView] NO se registró la vista (' + (page || '') + '): ' + (e && e.message)); } catch (e3) {}
  } finally {
    if (lock && got) { try { lock.releaseLock(); } catch (e2) {} }
  }
}

// Agrega una fila reintentando ante errores transitorios de Sheets. appendRow
// es atómico (apunta siempre a la última fila + 1), así que es seguro incluso
// sin tener el lock: preferimos una colisión rarísima antes que perder la
// sesión con certeza. 4 intentos con backoff corto (0.15s, 0.3s, 0.45s).
function _appendRowRetry(row) {
  var lastErr = null;
  for (var i = 0; i < 4; i++) {
    try { _analyticsSheet().appendRow(row); return; }
    catch (e) { lastErr = e; try { Utilities.sleep(150 * (i + 1)); } catch (e2) {} }
  }
  throw lastErr || new Error('appendRow falló tras reintentos');
}

// Correr UNA vez desde el editor: autoriza el permiso para crear el archivo y
// crea (si no existe) el spreadsheet de Analytics. Loguea su URL.
function setupAnalytics() {
  var sh = _analyticsSheet();
  var url = sh.getParent().getUrl();
  Logger.log('[OK] Analytics listo. Hoja "Vistas" en: ' + url);
  return url;
}

// Analíticas agregadas para la página Analytics (solo ADMIN_EMAILS).
function fetchAnalytics() {
  if (!_isAnalyticsViewer()) return { error: 'No autorizado.' };
  try {
    var tz = Session.getScriptTimeZone();
    var sh = _analyticsSheet();
    var last = sh.getLastRow();
    var nowStr = Utilities.formatDate(new Date(), tz, 'yyyy-MM-dd HH:mm');
    var empty = { byPeriod:{day:[],week:[],month:[]}, users:[], pages:[], totals:{views:0,users:0,mail:0,directo:0}, asOf:nowStr };
    if (last < 1) return empty;
    var width = Math.max(4, sh.getLastColumn());
    var all = sh.getRange(1, 1, last, width).getValues();

    // Mapeo de columnas. Si la fila 1 parece encabezado (col0 NO es fecha y hay
    // una columna tipo "Timestamp/Fecha"), se mapea por nombre y se saltea esa
    // fila; si no, se asume el orden por defecto y se lee desde la fila 1.
    var idx = { ts:0, email:1, page:2, origen:3 }, startRow = 0;
    var hdr = all[0].map(function(x){ return String(x||'').toLowerCase().trim(); });
    if (!_parseTs(all[0][0]) && hdr.some(function(c){ return /time|fecha|stamp/.test(c); })) {
      startRow = 1;
      hdr.forEach(function(c, k){
        if (/time|fecha|stamp/.test(c)) idx.ts = k;
        else if (/mail|correo|usuario|user/.test(c)) idx.email = k;
        else if (/pag|page|secc/.test(c)) idx.page = k;
        else if (/orig|source|fuente/.test(c)) idx.origen = k;
      });
    }

    var dayMap={}, weekMap={}, monthMap={}, userMap={}, pageMap={};
    var totViews=0, totMail=0, totDir=0, totUsers={};
    // Acumula una vista en un período como una "celda" (página × usuario), para
    // que el front pueda filtrar la tabla por página y/o por usuario y combinar
    // ambos. Clave compuesta pagina + SEP + email; email vacío => "(anónimo)".
    var SEP = String.fromCharCode(1);  // separador de clave; nunca aparece en paginas ni emails
    function bump(map, key, email, origen, page){
      if(!map[key]) map[key]={period:key, cells:{}};
      var pg=page||'', em=email||'(anónimo)', ck=pg+SEP+em;
      var c=map[key].cells[ck] || (map[key].cells[ck]={page:pg, email:em, views:0, mail:0, directo:0});
      c.views++; if(origen==='mail') c.mail++; else c.directo++;
    }
    function mondayOf(d){ var x=new Date(d.getFullYear(),d.getMonth(),d.getDate()); var dow=(x.getDay()+6)%7; x.setDate(x.getDate()-dow); return x; }
    for (var i=startRow;i<all.length;i++){
      var ts=_parseTs(all[i][idx.ts]); if(!ts) continue;
      var email=String(all[i][idx.email]||'').toLowerCase().trim();
      var page=String(all[i][idx.page]||'').trim();
      var origen=(String(all[i][idx.origen]||'').toLowerCase().trim()==='mail')?'mail':'directo';
      bump(dayMap,   Utilities.formatDate(ts,tz,'yyyy-MM-dd'),       email, origen, page);
      bump(weekMap,  Utilities.formatDate(mondayOf(ts),tz,'yyyy-MM-dd'), email, origen, page);
      bump(monthMap, Utilities.formatDate(ts,tz,'yyyy-MM'),          email, origen, page);
      totViews++; if(email) totUsers[email]=1; if(origen==='mail') totMail++; else totDir++;
      var ukey=email||'(anónimo)';
      if(!userMap[ukey]) userMap[ukey]={email:ukey,views:0,last:ts.getTime()};
      userMap[ukey].views++; if(ts.getTime()>userMap[ukey].last) userMap[ukey].last=ts.getTime();
      if(page){ pageMap[page]=(pageMap[page]||0)+1; }
    }
    // Serializa un mapa de períodos: cada fila lleva sus celdas
    // [{page,email,views,mail,directo}]. El front agrega según los filtros
    // (página y/o usuario) y calcula vistas/usuarios/mail/directo por período.
    function toArr(map){
      return Object.keys(map).sort().reverse().map(function(k){
        var o=map[k];
        var cells=Object.keys(o.cells).map(function(ck){ return o.cells[ck]; });
        return { period:o.period, cells:cells };
      });
    }
    var users=Object.keys(userMap).map(function(k){ var u=userMap[k]; return {email:u.email, views:u.views, last:Utilities.formatDate(new Date(u.last),tz,'yyyy-MM-dd HH:mm')}; }).sort(function(a,b){ return b.views-a.views; });
    var pagesArr=Object.keys(pageMap).map(function(k){ return {page:k, views:pageMap[k]}; }).sort(function(a,b){ return b.views-a.views; });
    return {
      byPeriod: { day:toArr(dayMap), week:toArr(weekMap), month:toArr(monthMap) },
      users: users, pages: pagesArr,
      totals: { views:totViews, users:Object.keys(totUsers).length, mail:totMail, directo:totDir },
      asOf: nowStr
    };
  } catch (e) { return { error: e.message }; }
}

// Diagnóstico de Analytics. CORRER DESDE EL EDITOR (botón ▶ con debugAnalytics
// seleccionado) y abrir "Registro de ejecución". Muestra a qué spreadsheet y
// pestaña apunta el código, todas las pestañas con su gid/filas, la fila de
// encabezados, las primeras filas con su tipo, y el resultado de fetchAnalytics.
// Sirve para saber por qué la página podría salir vacía aunque el sheet tenga datos.
function debugAnalytics() {
  var out = [];
  function log(s){ out.push(s); Logger.log(s); }
  try {
    var ss = SpreadsheetApp.openById(ANALYTICS_SS_ID);
    log('Spreadsheet: "' + ss.getName() + '"  ->  ' + ss.getUrl());
    var sheets = ss.getSheets();
    log('Pestañas (' + sheets.length + '):');
    sheets.forEach(function(s){
      log('  - "' + s.getName() + '"  gid=' + s.getSheetId() + '  filas=' + s.getLastRow() + '  cols=' + s.getLastColumn());
    });
    var sh = _analyticsSheet();
    log('>> Pestaña que usa el código: "' + sh.getName() + '"  gid=' + sh.getSheetId() + '  filas=' + sh.getLastRow());
    var last = sh.getLastRow(), w = Math.max(4, sh.getLastColumn());
    if (last >= 1) {
      log('Fila 1 (encabezado?): ' + JSON.stringify(sh.getRange(1, 1, 1, w).getValues()[0]));
      var n = Math.min(3, last - 1);
      if (n > 0) {
        sh.getRange(2, 1, n, w).getValues().forEach(function(r, i){
          log('Fila ' + (i + 2) + ': ' + JSON.stringify(r) + '  | col0 Date? ' + (r[0] instanceof Date) + '  parseTs=' + _parseTs(r[0]));
        });
      }
    }
    var res = fetchAnalytics();
    if (res.error) log('fetchAnalytics ERROR: ' + res.error);
    else log('fetchAnalytics OK -> totals=' + JSON.stringify(res.totals) + '  usuarios=' + res.users.length + '  páginas=' + res.pages.length);
  } catch (e) {
    log('ERROR: ' + e.message);
  }
  return out.join('\n');
}

// =================================================================
// PUBLIC API (Caché del Servidor)
// =================================================================
function fetchDataFast() {
  const cache = CacheService.getScriptCache();
  const FAST_KEY = CACHE_KEY + '_fast';

  const TKEY = CACHE_KEY + '_targets';
  if (!cache.get(TKEY)) _readTargets();

  try {
    const hit = cache.get(FAST_KEY);
    if (hit) {
      const payload = JSON.parse(hit);
      // El payload cacheado trae los targets INCRUSTADOS (los de cuando se armó).
      // Se re-inyectan acá los vigentes (caché propia de 15 min) para que un BE
      // re-subido durante el día aparezca en el daily sin esperar al Actualizar.
      try { payload.targets = _readTargets(payload.fechaReferencia ? new Date(payload.fechaReferencia) : null); } catch(e2) {}
      return { payload: payload, fromCache: true };
    }
  } catch(e) {}
  return _readSheetFast();
}

function fetchMetric(key) {
  const cache = CacheService.getScriptCache();
  const MK = CACHE_KEY + '_m_' + key;
  try {
    const hit = cache.get(MK);
    if (hit) return { key, data: JSON.parse(hit), fromCache: true };
  } catch(e) {}
  return _readMetric(key);
}

function fetchData() {
  const cache = CacheService.getScriptCache();
  const TKEY = CACHE_KEY + '_targets';
  if (!cache.get(TKEY)) _readTargets();

  try {
    const hit = cache.get(CACHE_KEY);
    if (hit) {
      const payload = JSON.parse(hit);
      // Igual que en fetchDataFast: targets vigentes aunque el payload sea cacheado.
      try { payload.targets = _readTargets(payload.fechaReferencia ? new Date(payload.fechaReferencia) : null); } catch(e2) {}
      return { payload: payload, fromCache: true };
    }
  } catch(e) {}
  return _readSheet();
}

function forceRefreshCache() {
  const cache = CacheService.getScriptCache();
  cache.remove(CACHE_KEY);
  cache.remove(CACHE_KEY + '_fast');
  _clearTargetsCacheKeys(cache);      // fija + datadas (BP1/hoy/ayer): si no, el BE del daily quedaba viejo
  cache.remove('cache_rrdata_mtd');   // si no, el RR se reusa stale al reconstruir el payload
  
  var bp1 = '';
  try { bp1 = PropertiesService.getScriptProperties().getProperty('LAST_VALID_DATE') || ''; } catch(e) {}
  cache.remove('cache_rrdata_mtd_' + bp1 + '_export');
  cache.remove('cache_rrdata_mtd_' + bp1 + '_calc');

  ['new_users','wis','wis_uf','seamless','delivery_time',
   'assignment_time','rejected_orders','session_orders','assignment_time_orders_over_6min']
    .forEach(k => cache.remove(CACHE_KEY + '_m_' + k));
  // OJO: NO reconstruimos acá (_readSheetFast es lo lento y dejaba colgado el
  // botón Actualizar sin escape). Solo limpiamos y devolvemos rápido; la recarga
  // siguiente reconstruye vía fetchDataFast, que tiene su red de seguridad (90s + Reintentar).
  return true;
}

function refreshData() {
  const cache = CacheService.getScriptCache();
  cache.remove(CACHE_KEY);
  cache.remove(CACHE_KEY + '_fast');
  _clearTargetsCacheKeys(cache);      // fija + datadas (BP1/hoy/ayer)
  cache.remove('cache_rrdata_mtd');   // idem: forzar recálculo del RR
  
  var bp1 = '';
  try { bp1 = PropertiesService.getScriptProperties().getProperty('LAST_VALID_DATE') || ''; } catch(e) {}
  cache.remove('cache_rrdata_mtd_' + bp1 + '_export');
  cache.remove('cache_rrdata_mtd_' + bp1 + '_calc');

  ['new_users','wis','wis_uf','seamless','delivery_time',
   'assignment_time','rejected_orders','session_orders','assignment_time_orders_over_6min']
    .forEach(k => cache.remove(CACHE_KEY + '_m_' + k));
  _readSheetFast();
  return true;
}

// =================================================================
// DIAGNÓSTICO / TEST
// =================================================================
function testFechaBP1() {
  const sheet = _openSheet();
  const valorCelda = sheet.getRange("BP1").getValue();
  Logger.log('BP1 raw: ' + valorCelda);
  Logger.log('BP1 tipo: ' + typeof valorCelda);
  Logger.log('BP1 es Date: ' + (valorCelda instanceof Date));
  Logger.log('BP1 timestamp: ' + (valorCelda instanceof Date ? valorCelda.getTime() : 'N/A'));
  Logger.log('BP1 formateada: ' + (valorCelda instanceof Date ? Utilities.formatDate(valorCelda, Session.getScriptTimeZone(), 'dd/MM/yyyy') : 'no es fecha'));
}

function warmCache() {
  refreshData();
  _readSheetFast();
  ['new_users','wis','wis_uf','seamless','delivery_time','assignment_time','assignment_time_orders_over_6min','rejected_orders','session_orders']
    .forEach(k => _readMetric(k));
  Logger.log("Cache calentado OK.");
}

// Calienta la caché del daily SOLO si está fría (barato si ya está caliente:
// es apenas un cache.get). Lo llama el trigger de cada 10 min (checkYEnviarEmail)
// para que, cuando la caché expira a las 10:00, se reconstruya sola ANTES de que
// llegue el primer usuario → así nadie paga la "primera carga del día" lenta.
function warmupDailyCache() {
  const cache = CacheService.getScriptCache();
  if (cache.get(CACHE_KEY + '_fast')) return false;   // ya está caliente, nada que hacer
  try {
    if (!cache.get(CACHE_KEY + '_targets')) _readTargets();
    _readSheetFast();                       // payload principal del daily (lo pesado)
    try { _getRRDataFromSheet(); } catch (e) {}   // RR (el front lo pide aparte)
    Logger.log('[warmup] Caché del daily reconstruida (estaba fría).');
    return true;
  } catch (e) {
    Logger.log('[warmup] Error: ' + e.message);
    return false;
  }
}

function testTargetsDetalle() {
  CacheService.getScriptCache().remove(CACHE_KEY + '_targets');
  const t = _readTargets();
  Logger.log('ORDERS: ' + JSON.stringify(t.orders));
  Logger.log('GMV: '    + JSON.stringify(t.gmv));
}

function testRRData() {
  CacheService.getScriptCache().remove(CACHE_KEY + '_fast');
  const r = _getRRDataFromSheet();
  const ar = r.orders['AR'];
  if (ar) {
    Logger.log('=== AR Orders ===');
    Logger.log('RR:    ' + ar.rr?.toLocaleString());
    Logger.log('BE:    ' + ar.be?.toLocaleString());
    Logger.log('varBe: ' + ar.varBe?.toFixed(1) + '%');
    Logger.log('varLY: ' + ar.varLY?.toFixed(1) + '%');
    Logger.log('LY:    ' + ar.ly?.toLocaleString());
  } else {
    Logger.log('[AVISO] Sin datos AR');
  }
  Logger.log('LATAM Orders: ' + JSON.stringify(r.orders['LATAM']));
  Logger.log('[OK] Done');
}

function FORZAR_PERMISOS_SHEETS() {
  try {
    SpreadsheetApp.openById(SS_ID);
    SpreadsheetApp.openById(TARGETS_SS_ID);
    MailApp.sendEmail(Session.getActiveUser().getEmail(), "PeYa — Permisos OK", "Acceso autorizado.");
  } catch(e) { Logger.log("ERROR: " + e.message); }
}

// =================================================================
// LECTURAS CORE
// =================================================================
function _openSheet() {
  const ss = SpreadsheetApp.openById(SS_ID);
  // Tolerante: acepta el nombre nuevo ("Daily Data") o el viejo ("Extract 1") por si
  // la pestaña todavía no se renombró en la planilla.
  const sheet = ss.getSheetByName(SHEET_NAME) ||
                ss.getSheets().find(function(s){ return /daily\s*data|extract\s*1/i.test(s.getName()); });
  if (!sheet) throw new Error(`Hoja "${SHEET_NAME}" no encontrada.`);
  return sheet;
}

function _getHeaderIndex(sheet) {
  const lastCol = sheet.getLastColumn();
  const headers = sheet.getRange(1,1,1,lastCol).getValues()[0].map(h => String(h).trim());
  const ix = {};
  headers.forEach((h,i) => ix[h] = i);
  return { ix, lastCol };
}

function _readSheetFast() {
  const FAST_KEY = CACHE_KEY + '_fast';
  const cache = CacheService.getScriptCache();
  let sheet;
  try { sheet = _openSheet(); } catch(e) { return { error: e.message }; }

  const lastRow = sheet.getLastRow();
  if (lastRow < 2) return { error:'Hoja vacía.' };
  const { ix } = _getHeaderIndex(sheet);

  const NEED = ['warehouse_id','warehouse_name','country_code','d1_orders','d8_orders','lw_orders','d1_gmv','d8_gmv','lw_gmv'];
  const C = {}; NEED.forEach(k => C[k] = ix[k] !== undefined ? ix[k] : -1);

  const raw = sheet.getRange(2, 1, lastRow - 1, sheet.getLastColumn()).getValues();

  const nv = (r,col) => { if(col<0)return null; const v=r[col]; return(v===''||v==null)?null:Number(v); };
  const sv = (r,col) => { if(col<0)return''; return String(r[col]||'').trim(); };

  const map = {};
  raw.forEach(r => {
    const wid = sv(r,C.warehouse_id) || 'all';
    const wname = sv(r,C.warehouse_name) || 'All';
    const cc = sv(r,C.country_code).toUpperCase();
    if (!cc) return;
    const key = `${wid}||${cc}`;
    if (!map[key]) map[key] = { wid, wname, cc, d1_o:0,d8_o:0,lw_o:0, d1_g:0,d8_g:0,lw_g:0 };
    const c = map[key];
    const a = (d,src) => { const v=nv(r,C[src]); if(v!=null) c[d]+=v; };
    a('d1_o','d1_orders'); a('d8_o','d8_orders'); a('lw_o','lw_orders');
    a('d1_g','d1_gmv');    a('d8_g','d8_gmv');    a('lw_g','lw_gmv');
  });

  const rows = Object.values(map).map(c => ({
    warehouse_id: c.wid, warehouse_name: c.wname, country: c.cc,
    _raw: {
      d1_orders:c.d1_o, d8_orders:c.d8_o, lw_orders:c.lw_o,
      d1_gmv:c.d1_g,    d8_gmv:c.d8_g,    lw_gmv:c.lw_g
    },
    orders: { d1:c.d1_o, d8:c.d8_o, lw:c.lw_o },
    gmv:    { d1:c.d1_g, d8:c.d8_g, lw:c.lw_g },
  }));

  const whMap = {}; rows.forEach(r => whMap[r.warehouse_id] = r.warehouse_name);
  const warehouses = Object.entries(whMap).map(([id,name]) => ({id,name})).sort((a,b) => a.name.localeCompare(b.name));

  // LÓGICA DE FECHA CON MEMORIA EN EL SERVIDOR (COLUMNA max_fact_orders_date O CELDA BP1)
  let fechaReferencia = null;
  const scriptProps = PropertiesService.getScriptProperties();

  try {
    let valorColumna = null;
    if (ix['max_fact_orders_date'] !== undefined && raw.length > 0) {
      valorColumna = raw[0][ix['max_fact_orders_date']];
    }
    if (valorColumna instanceof Date && !isNaN(valorColumna.getTime())) {
      fechaReferencia = valorColumna.getTime();
    } else if (valorColumna && !isNaN(Date.parse(valorColumna))) {
      fechaReferencia = new Date(valorColumna).getTime();
    } else {
      // Fallback a BP1 si la columna no está o está vacía
      const valorCelda = sheet.getRange("BP1").getValue();
      if (valorCelda instanceof Date && !isNaN(valorCelda.getTime())) {
        fechaReferencia = valorCelda.getTime();
      } else if (valorCelda && !isNaN(Date.parse(valorCelda))) {
        fechaReferencia = new Date(valorCelda).getTime();
      }
    }
  } catch(e) {
    Logger.log("Error leyendo fecha de actualización en fast: " + e.message);
  }

  if (fechaReferencia) {
    scriptProps.setProperty('LAST_VALID_DATE', fechaReferencia.toString());
  } else {
    const lastSaved = scriptProps.getProperty('LAST_VALID_DATE');
    fechaReferencia = lastSaved ? Number(lastSaved) : new Date().getTime();
  }

  const payload = {
    rows,
    warehouses,
    targets: _readTargets(fechaReferencia ? new Date(fechaReferencia) : null),
    // RR DESACOPLADO: NO se calcula acá (re-leía la hoja Actuals enorme + targets
    // y frenaba la carga del daily). El front lo pide aparte con fetchRRData()
    // (loadDailyRR) y rellena las columnas de RR cuando llega.
    rrData: { orders: {}, gmv: {} },
    fechaReferencia: fechaReferencia
  };

  try { cache.put(FAST_KEY, JSON.stringify(payload), _getCacheTTL()); } catch(e) {}
  return { payload, fromCache:false };
}

function _readMetric(key) {
  const MK = CACHE_KEY + '_m_' + key;
  const cache = CacheService.getScriptCache();
  const mDef = METRIC_DEFS.find(m => m.key === key);
  if (!mDef) return { error: 'Métrica desconocida' };

  let sheet;
  try { sheet = _openSheet(); } catch(e) { return { error: e.message }; }

  const lastRow = sheet.getLastRow();
  if (lastRow < 2) return { error:'Hoja vacía.' };
  const { ix } = _getHeaderIndex(sheet);

  const NEED = ['warehouse_id','country_code', ...(METRIC_COLS[key]||[])];
  const C = {};
  NEED.forEach(col => {
    var idx = ix[col];
    if (idx === undefined && GLOBAL_FALLBACKS[col]) {
      for (var f = 0; f < GLOBAL_FALLBACKS[col].length; f++) {
        idx = ix[GLOBAL_FALLBACKS[col][f]];
        if (idx !== undefined) break;
      }
    }
    C[col] = idx !== undefined ? idx : -1;
  });
  const maxCol = Math.max(...Object.values(C).filter(v => v >= 0)) + 1;
  const raw = sheet.getRange(2, 1, lastRow - 1, maxCol).getValues();

  const nv = (r,col) => { if(col<0)return null; const v=r[col]; return(v===''||v==null)?null:Number(v); };
  const sv = (r,col) => { if(col<0)return''; return String(r[col]||'').trim(); };

  const map = {};
  raw.forEach(r => {
    const wid = sv(r,C.warehouse_id) || 'all', cc = sv(r,C.country_code).toUpperCase();
    if (!cc) return;
    const k = `${wid}||${cc}`;
    if (!map[k]) { map[k] = { wid, cc }; (METRIC_COLS[key]||[]).forEach(col => map[k][col] = 0); }
    (METRIC_COLS[key]||[]).forEach(col => { const v = nv(r,C[col]); if (v != null) map[k][col] += v; });
  });

  const data = {};
  Object.values(map).forEach(c => {
    const rowKey = `${c.wid}||${c.cc}`;
    let d1=null, d8=null, lw=null;
    const rawEntry = {};

    if (mDef.type === 'ratio') {
      ['d1','d8','lw'].forEach(p => {
        const numCol = `${p}_${mDef.columna_numerador}`, denCol = `${p}_${mDef.columna_denominador}`;
        const num = c[numCol] || 0, den = c[denCol] || 0;
        const val = den > 0 ? (num/den) * (mDef.fmt === 'pct' ? 100 : 1) : null;
        if (p==='d1') d1=val; else if (p==='d8') d8=val; else lw=val;
        rawEntry[numCol] = num; rawEntry[denCol] = den;
      });
    } else {
      d1 = c[METRIC_COLS[key][0]] || 0; d8 = c[METRIC_COLS[key][1]] || 0; lw = c[METRIC_COLS[key][2]] || 0;
      rawEntry[METRIC_COLS[key][0]] = d1; rawEntry[METRIC_COLS[key][1]] = d8; rawEntry[METRIC_COLS[key][2]] = lw;
    }
    data[rowKey] = { d1, d8, lw, _raw: rawEntry };
  });

  try { cache.put(MK, JSON.stringify(data), _getCacheTTL()); } catch(e) {}
  return { key, data, fromCache:false };
}

function _readSheet() {
  const cache = CacheService.getScriptCache();
  let sheet; try { sheet = _openSheet(); } catch(e) { return { error: e.message }; }
  const lastRow = sheet.getLastRow(), lastCol = sheet.getLastColumn();
  if (lastRow < 2) return { error:'Hoja vacía.' };

  const { ix } = _getHeaderIndex(sheet);
  const raw = sheet.getRange(2,1,lastRow-1,lastCol).getValues();
  const nv = (r,col) => { if(col==null||col===-1)return null; const v=r[col]; return(v===''||v==null)?null:Number(v); };
  const sv = (r,col) => { if(col==null||col===-1)return''; return String(r[col]||'').trim(); };

  const C = {};
  ['warehouse_id','warehouse_name','country_code', ...Object.values(METRIC_COLS).flat()].forEach(k => C[k] = ix[k] !== undefined ? ix[k] : -1);

  const map = {};
  raw.forEach(r => {
    const wid = sv(r,C.warehouse_id) || 'all', wname = sv(r,C.warehouse_name) || 'All', cc = sv(r,C.country_code).toUpperCase();
    if (!cc) return;
    const key = `${wid}||${cc}`;
    if (!map[key]) {
      map[key] = { wid, wname, cc };
      Object.values(METRIC_COLS).flat().forEach(col => map[key][col] = 0);
    }
    Object.values(METRIC_COLS).flat().forEach(col => {
      const v = nv(r,C[col]); if (v != null) map[key][col] += v;
    });
  });

  const rows = Object.values(map).map(c => {
    const out = { warehouse_id:c.wid, warehouse_name:c.wname, country:c.cc, _raw:c };
    METRIC_DEFS.forEach(m => {
      out[m.key] = {};
      ['d1','d8','lw'].forEach(p => {
        if (m.type === 'ratio') {
          const num=c[`${p}_${m.columna_numerador}`]||0, den=c[`${p}_${m.columna_denominador}`]||0;
          out[m.key][p] = den>0 ? (num/den) * (m.fmt==='pct'?100:1) : null;
        } else {
          out[m.key][p] = c[`${p}_${m.columna_suma}`]||0;
        }
      });
    });
    return out;
  }).sort((a,b) => a.warehouse_name.localeCompare(b.warehouse_name)||a.country.localeCompare(b.country));

  const whMap = {}; rows.forEach(r => whMap[r.warehouse_id]=r.warehouse_name);
  const warehouses = Object.entries(whMap).map(([id,name]) => ({id,name})).sort((a,b) => a.name.localeCompare(b.name));

  // LÓGICA DE FECHA CON MEMORIA EN EL SERVIDOR (COLUMNA max_fact_orders_date O CELDA BP1)
  let fechaReferencia = null;
  const scriptProps = PropertiesService.getScriptProperties();

  try {
    let valorColumna = null;
    if (ix['max_fact_orders_date'] !== undefined && raw.length > 0) {
      valorColumna = raw[0][ix['max_fact_orders_date']];
    }
    if (valorColumna instanceof Date && !isNaN(valorColumna.getTime())) {
      fechaReferencia = valorColumna.getTime();
    } else if (valorColumna && !isNaN(Date.parse(valorColumna))) {
      fechaReferencia = new Date(valorColumna).getTime();
    } else {
      // Fallback a BP1 si la columna no está o está vacía
      const valorCelda = sheet.getRange("BP1").getValue();
      if (valorCelda instanceof Date && !isNaN(valorCelda.getTime())) {
        fechaReferencia = valorCelda.getTime();
      } else if (valorCelda && !isNaN(Date.parse(valorCelda))) {
        fechaReferencia = new Date(valorCelda).getTime();
      }
    }
  } catch(e) {
    Logger.log("Error leyendo fecha de actualización en normal: " + e.message);
  }

  if (fechaReferencia) {
    scriptProps.setProperty('LAST_VALID_DATE', fechaReferencia.toString());
  } else {
    const lastSaved = scriptProps.getProperty('LAST_VALID_DATE');
    fechaReferencia = lastSaved ? Number(lastSaved) : new Date().getTime();
  }

  const targets = _readTargets(fechaReferencia ? new Date(fechaReferencia) : null);
  // RR DESACOPLADO: ya NO se computa acá (re-leía actuals + 3 hojas de targets y
  // hacía lento/colgaba la carga del daily). El front lo pide aparte con
  // fetchRRData() y rellena las columnas de RR cuando llega.
  const rrData = { orders:{}, gmv:{} };
  const payload = { rows, warehouses, targets, rrData, fechaReferencia };

  try { cache.put(CACHE_KEY, JSON.stringify(payload), _getCacheTTL()); } catch(e) {}
  return { payload, fromCache:false };
}

// =================================================================
// RR DATA — RR Mes / BE Mes / Var BE Mes por país (Orders y GMV)
//   El GRUPO RR completo (RR / BE / Var) sale de "RR orders y GMV export":
//     RR Mes     = columna rr_mensual (por país/KPI)
//     BE Mes     = columna be_mensual (por país/KPI)
//     Var BE Mes = (RR − BE) / BE   ← idéntico a var_vs_be_mensual del export
//   Fallback si un país/KPI no está en el export:
//     BE Mes = target mensual (A. Export Targets-Mensual); RR = BE × (Act/BE_MTD)
//     con BE MTD = Σ target diario (B. Export Targets-Diario) y Actual de Actuals.
//   LATAM (calculado): RR = ΣRR_países, BE = ΣBE_países, Var = (ΣRR−ΣBE)/ΣBE.
//   ly / Var LY (columna aparte, NO del grupo RR): Actual MTD vs mismo período
//     año pasado (A. TI - Actuals OKRs); Var LY = (Actual − ly)/ly.
// =================================================================
function _getRRDataFromSheet(freshRead) {
  var result = { orders: {}, gmv: {} };
  var rrSource = getRRSource();   // 'export' | 'calc' (global, lo elige el admin en rrcompare)
  Logger.log('[RR] Origen activo (definido en rrcompare): ' + rrSource);
  
  var bp1 = '';
  try { bp1 = PropertiesService.getScriptProperties().getProperty('LAST_VALID_DATE') || ''; } catch(e) {}
  var cacheKey = 'cache_rrdata_mtd_' + bp1 + '_' + rrSource;
  
  var cache = CacheService.getScriptCache();
  if (!freshRead) {
    try { var hit = cache.get(cacheKey); if (hit) return JSON.parse(hit); } catch (eC) {}
  }

  var PAIS_ISO = {
    'argentina':'AR','bolivia':'BO','chile':'CL','colombia':'CO','costa rica':'CR',
    'ecuador':'EC','el salvador':'SV','guatemala':'GT','honduras':'HN','nicaragua':'NI',
    'panama':'PA','panamá':'PA','paraguay':'PY','peru':'PE','perú':'PE','uruguay':'UY',
    'republica dominicana':'DO','república dominicana':'DO','rep. dominicana':'DO',
    'dominican republic':'DO','mexico':'MX','méxico':'MX',
    'ar':'AR','bo':'BO','cl':'CL','co':'CO','cr':'CR','ec':'EC','sv':'SV','gt':'GT',
    'hn':'HN','ni':'NI','pa':'PA','py':'PY','pe':'PE','uy':'UY','do':'DO','mx':'MX',
    'latam':'LATAM','latin america':'LATAM'
  };
  function getISO(raw){ var s=String(raw||'').trim().toLowerCase(); return PAIS_ISO[s] || String(raw||'').trim().toUpperCase(); }
  function num(v){ if(v===''||v==null) return null; var n=parseFloat(v); return isNaN(n)?null:n; }

  // Nombres de métrica (target) por KPI; orden = prioridad.
  // 1ro los nombres EXACTOS del Target (mensual y diario usan estos); luego alternativas.
  var ORD_TGT = ['Confirmed Orders - Target', 'Daily Confirmed Orders BE - Target', 'Orquest - Confirmed Orders - Target'];
  var GMV_TGT = ['GMV User Dmarts - Target', 'Daily GMV BE - Target', 'GMV BE - Target'];
  function kpiOfTarget(nm){
    if (ORD_TGT.indexOf(nm)!==-1) return 'orders';
    if (GMV_TGT.indexOf(nm)!==-1) return 'gmv';
    var low=String(nm).toLowerCase();
    if (low.indexOf('gmv')!==-1) return 'gmv';
    if (low.indexOf('order')!==-1 && low.indexOf('target')!==-1) return 'orders';
    return null;
  }
  // De un mapa {nombreMetrica: valor} elige el de mayor prioridad (evita doble conteo).
  function pick(kpi, byName){
    if(!byName) return null;
    var arr = (kpi==='orders')?ORD_TGT:GMV_TGT;
    for (var j=0;j<arr.length;j++){ if(byName[arr[j]]!=null) return byName[arr[j]]; }
    var ks=Object.keys(byName); return ks.length? byName[ks[0]] : null;
  }

  try {
    var tz = Session.getScriptTimeZone();
    var tgtSS = SpreadsheetApp.openById(TARGETS_SS_ID);

    // ── as-of + mes actual (desde actuals, capado por BP1) ─────────────
    var actSheet = SpreadsheetApp.openById(SPREADSHEET_ID).getSheetByName(SHEET_ACTUALS);
    var ad = actSheet.getDataRange().getValues();
    var aMi=ad[0].indexOf('Metric'), aCi=ad[0].indexOf('Country'), aDi=ad[0].indexOf('Date'), aVi=ad[0].indexOf('Value');
    // maxMs = último día con dato REAL (cualquier KPI) → define la ventana.
    // maxKpiMs = último día con dato REAL por KPI → para detectar KPIs rezagados.
    var maxMs=-Infinity, maxKpiMs={orders:-Infinity,gmv:-Infinity};
    for (var i=1;i<ad.length;i++){
      var mm0=ad[i][aMi]; var kk0=(mm0==='Confirmed Orders')?'orders':(mm0==='GMV User Dmarts')?'gmv':null; if(!kk0) continue;
      var t0=parseDateToMs(ad[i][aDi]); if(isNaN(t0)) continue;
      if(num(ad[i][aVi])==null) continue;   // solo días con dato real (ignora filas vacías)
      if(t0>maxMs) maxMs=t0;
      if(t0>maxKpiMs[kk0]) maxKpiMs[kk0]=t0;
    }
    // El día de CORTE lo define Confirmed Orders (la métrica LÍDER), capado por BP1.
    // Una métrica con RR (GMV) se considera "incompleta" si su último día con dato
    // NO llega a ese día de corte → su RR y su Var quedan VACÍOS en todas las páginas
    // (preferimos vacío a un número engañoso). Orders nunca queda incompleto contra sí mismo.
    var leaderMs = (maxKpiMs.orders!==-Infinity) ? maxKpiMs.orders : maxMs;
    
    var bp1_date = null;
    try { 
      var bp1 = PropertiesService.getScriptProperties().getProperty('LAST_VALID_DATE');
      if (bp1) { bp1_date = new Date(parseInt(bp1)); } 
    } catch(eb){}

    // Si la fecha de la página (bp1_date) es posterior a la última fecha con actuals reales (leaderMs):
    // significa que hoy (bp1_date) aún no se ha cargado/procesado en actuals OKRs.
    // Para evitar inconsistencias de datos (mezclar meses), solo omitimos si el mes de bp1_date
    // es posterior al mes de leaderMs. Si es el mismo mes, permitimos proyectar con la última fecha real.
    if (bp1_date && leaderMs !== -Infinity) {
      var leaderDate = new Date(leaderMs);
      var leaderMonth = leaderDate.getFullYear() * 12 + leaderDate.getMonth();
      var bp1Month = bp1_date.getFullYear() * 12 + bp1_date.getMonth();
      
      if (leaderMonth < bp1Month) {
        Logger.log('[RR] Omitiendo datos de RR: la fecha de la página (' + bp1_date + ') es de un mes posterior a la última con actuals (' + leaderDate + ').');
        return { orders: {}, gmv: {}, meta: { isMonthClose: false, asOfLabel: 'Sin datos' } };
      }
    }

    var asOf = (leaderMs!==-Infinity)? new Date(leaderMs) : new Date();
    if (bp1_date && bp1_date < asOf) {
      asOf = bp1_date;
    }
    var Y=asOf.getFullYear(), Mo=asOf.getMonth();
    var monthStartMs=new Date(Y,Mo,1).getTime();
    var asOfMs=new Date(Y,Mo,asOf.getDate(),23,59,59).getTime();
    var curMonthKey=Y+'-'+('0'+(Mo+1)).slice(-2);
    var asOfDayMs=new Date(Y,Mo,asOf.getDate()).getTime();
    var incomplete={
      orders:(maxKpiMs.orders===-Infinity)||(maxKpiMs.orders<asOfDayMs),
      gmv:   (maxKpiMs.gmv===-Infinity)   ||(maxKpiMs.gmv<asOfDayMs)
    };
    // Mismo período del año pasado (MTD LY): día 1 → mismo día, año -1.
    var lyMonthStartMs=new Date(Y-1,Mo,1).getTime();
    var lyAsOfMs=new Date(Y-1,Mo,asOf.getDate(),23,59,59).getTime();
    // Mes COMPLETO cerrado del año pasado (para RR vs LY) y mes anterior COMPLETO (RR vs LM).
    var lyFullEndMs = new Date(Y-1, Mo+1, 0, 23,59,59).getTime();   // último día del mes, año pasado
    var lmStartMs   = new Date(Y, Mo-1, 1).getTime();               // 1° del mes anterior (enero→dic ok)
    var lmEndMs     = new Date(Y, Mo, 0, 23,59,59).getTime();       // último día del mes anterior

    // ── Actuals por ventana: MTD actual, LY MTD (mismo tramo), LY mes COMPLETO,
    //    LM mes anterior COMPLETO. Ojo: NO son else-if (LY MTD ⊂ LY mes completo,
    //    así que una misma fecha puede sumar a varias ventanas).
    var actualMTD={orders:{},gmv:{}}, actualLY={orders:{},gmv:{}};
    var lyFull={orders:{},gmv:{}}, lmFull={orders:{},gmv:{}};
    for (var i=1;i<ad.length;i++){
      var mm=ad[i][aMi]; var kA=(mm==='Confirmed Orders')?'orders':(mm==='GMV User Dmarts')?'gmv':null; if(!kA) continue;
      var tA=parseDateToMs(ad[i][aDi]); if(isNaN(tA)) continue;
      var isoA=getISO(ad[i][aCi]); if(!isoA) continue;   // LATAM se captura (fila propia si existe)
      var vA=num(ad[i][aVi])||0;
      if(tA>=monthStartMs   && tA<=asOfMs)      actualMTD[kA][isoA]=(actualMTD[kA][isoA]||0)+vA;   // MTD actual
      if(tA>=lyMonthStartMs && tA<=lyAsOfMs)    actualLY[kA][isoA] =(actualLY[kA][isoA] ||0)+vA;   // LY MTD (mismo tramo)
      if(tA>=lyMonthStartMs && tA<=lyFullEndMs) lyFull[kA][isoA]   =(lyFull[kA][isoA]   ||0)+vA;   // LY mes COMPLETO
      if(tA>=lmStartMs      && tA<=lmEndMs)     lmFull[kA][isoA]   =(lmFull[kA][isoA]   ||0)+vA;   // LM mes anterior COMPLETO
    }

    // ── BE MTD (B. Export Targets-Diario, día 1 → as-of) ───────────────
    var beMTDraw={orders:{},gmv:{}};   // {iso: {nombreMetrica: valor}}
    var dSheet = tgtSS.getSheets().find(function(s){return /Export Targets-Diario/i.test(s.getName());});
    if (dSheet){
      var dd=dSheet.getDataRange().getValues();
      var dH=dd[0].map(function(h){return String(h).trim().toLowerCase();});
      var dMi=dH.indexOf('metric'),dCi=dH.indexOf('country'),dDi=dH.indexOf('date'),dVi=dH.indexOf('value');
      for (var i=1;i<dd.length;i++){
        var nmD=String(dd[i][dMi]||'').trim(); var kD=kpiOfTarget(nmD); if(!kD) continue;
        var tD=parseDateToMs(dd[i][dDi]); if(isNaN(tD)||tD<monthStartMs||tD>asOfMs) continue;
        var isoD=getISO(dd[i][dCi]); if(!isoD) continue;   // LATAM se captura (fila propia si existe)
        if(!beMTDraw[kD][isoD]) beMTDraw[kD][isoD]={};
        beMTDraw[kD][isoD][nmD]=(beMTDraw[kD][isoD][nmD]||0)+(num(dd[i][dVi])||0);
      }
    } else { Logger.log('[RR] Hoja "B. Export Targets-Diario" no encontrada.'); }

    // ── BE Mes (A. Export Targets-Mensual, mes actual) ─────────────────
    var beMesRaw={orders:{},gmv:{}};
    var mSheet = tgtSS.getSheets().find(function(s){return /Export Targets-Mensual/i.test(s.getName());});
    if (mSheet){
      var msd=mSheet.getDataRange().getValues();
      var mH=msd[0].map(function(h){return String(h).trim().toLowerCase();});
      var mMi=mH.indexOf('metric'),mCi=mH.indexOf('country'),mMoi=mH.indexOf('month'),mVi=mH.indexOf('value');
      for (var i=1;i<msd.length;i++){
        var nmM=String(msd[i][mMi]||'').trim(); var kM=kpiOfTarget(nmM); if(!kM) continue;
        if(_monthKeyOf(msd[i][mMoi])!==curMonthKey) continue;
        var isoM=getISO(msd[i][mCi]); if(!isoM) continue;   // LATAM se captura (fila propia si existe)
        if(!beMesRaw[kM][isoM]) beMesRaw[kM][isoM]={};
        beMesRaw[kM][isoM][nmM]=(beMesRaw[kM][isoM][nmM]||0)+(num(msd[i][mVi])||0);
      }
    } else { Logger.log('[RR] Hoja "A. Export Targets-Mensual" no encontrada.'); }

    // ── RR/BE Mes desde "RR orders y GMV export" ───────────────────────
    // SOLO si el origen elegido por el admin es 'export'. En 'calc' dejamos
    // estos mapas vacíos y la composición de abajo usa el cálculo propio
    // (BE = target mensual, RR = BE × (Actual MTD / BE MTD)).
    var rrExport={orders:{},gmv:{}}, beExport={orders:{},gmv:{}};
    var rrSheet = (rrSource === 'export')
      ? tgtSS.getSheets().find(function(s){return /RR orders y GMV export/i.test(s.getName());})
      : null;
    if (rrSheet){
      var rd=rrSheet.getDataRange().getValues();
      // Normaliza headers a ASCII sin acentos, minúsculas, sin espacios ni signos
      // (así "Var vs BE Mensual" / "var_vs_be_mensual" / "VAR-VS-BE-MENSUAL" matchean igual).
      var rHnorm=rd[0].map(function(h){
        return String(h||'').toLowerCase()
          .replace(/[áàä]/g,'a').replace(/[éèë]/g,'e').replace(/[íìï]/g,'i')
          .replace(/[óòö]/g,'o').replace(/[úùü]/g,'u').replace(/[^a-z0-9]/g,'');
      });
      // Devuelve el índice de la 1ra columna cuyo header normalizado matchea el regex.
      function colIdx(re){ for(var h=0;h<rHnorm.length;h++){ if(re.test(rHnorm[h])) return h; } return -1; }
      var rPi=colIdx(/^(pais|country)$/); if(rPi<0)rPi=colIdx(/pais|country/);
      var rKi=colIdx(/^kpi$/);            if(rKi<0)rKi=colIdx(/kpi/);
      // RR mensual y BE mensual (^ ancla para no matchear "var_vs_be_mensual").
      var rRi=colIdx(/^rr.*mensual$/);    if(rRi<0)rRi=colIdx(/^rr$/);    if(rRi<0)rRi=colIdx(/^rr.*mes/);
      var rBi=colIdx(/^be.*mensual$/);    if(rBi<0)rBi=colIdx(/^be.*mes/); if(rBi<0)rBi=colIdx(/^be$/);
      if(rPi>=0 && rKi>=0 && rRi>=0){
        for (var i=1;i<rd.length;i++){
          var rkRaw=String(rd[i][rKi]||'').trim().toLowerCase();
          var rk=(rkRaw.indexOf('gmv')!==-1)?'gmv':(rkRaw.indexOf('order')!==-1)?'orders':null; if(!rk) continue;
          var rIso=getISO(rd[i][rPi]); if(!rIso) continue;
          var rVal=num(rd[i][rRi]); if(rVal!=null) rrExport[rk][rIso]=rVal;
          if(rBi>=0){ var bV=num(rd[i][rBi]); if(bV!=null) beExport[rk][rIso]=bV; }
        }
      } else { Logger.log('[RR] "RR orders y GMV export": no encontré columnas pais/kpi/rr_mensual. Headers normalizados: '+JSON.stringify(rHnorm)); }
    } else if (rrSource === 'export') {
      var _names = tgtSS.getSheets().map(function(s){ return s.getName(); });
      Logger.log('[RR] ORIGEN=export, pero NO encontré la hoja "RR orders y GMV export" en el spreadsheet de targets → se usa el RR CALCULADO como fallback.');
      Logger.log('[RR] Hojas disponibles en ese spreadsheet: ' + JSON.stringify(_names));
    } else {
      Logger.log('[RR] ORIGEN=cálculo → RR calculado a propósito (no se lee la hoja export). Esto es lo esperado en este modo.');
    }

    // ── Componer por país ──────────────────────────────────────────────
    // ly  = Actual MTD mismo período año pasado; Var LY = (Actual − ly)/ly (crecimiento puro).
    ['orders','gmv'].forEach(function(kpi){
      var isoset={};
      Object.keys(actualMTD[kpi]).forEach(function(c){isoset[c]=true;});
      Object.keys(beMesRaw[kpi]).forEach(function(c){isoset[c]=true;});
      Object.keys(rrExport[kpi]).forEach(function(c){isoset[c]=true;});
      Object.keys(beExport[kpi]).forEach(function(c){isoset[c]=true;});
      Object.keys(isoset).forEach(function(iso){
        if(iso==='LATAM') return;   // LATAM se arma aparte (fila propia o suma de países)
        // BE Mes: del export (be_mensual) si está; si no, target mensual.
        var be   = (beExport[kpi][iso]!=null) ? beExport[kpi][iso] : pick(kpi, beMesRaw[kpi][iso]);
        var beTd = pick(kpi, beMTDraw[kpi][iso]);
        var act  = actualMTD[kpi][iso];
        // RR Mes: del export (rr_mensual) si está; si no, calculado.
        var rr;
        if (rrExport[kpi][iso]!=null) {
          rr = rrExport[kpi][iso];
        } else {
          rr = (be!=null && beTd) ? be*((act||0)/beTd) : null;
        }
        // Si el KPI no tiene datos hasta el día de corte (Orders líder), RR queda
        // VACÍO sin importar el origen (export o cálculo) → y la Var BE también.
        if (incomplete[kpi]) rr=null;
        // Var BE Mes = (RR − BE)/BE. Con RR y BE del export es idéntico a
        // var_vs_be_mensual, sin depender de leer/parsear esa columna.
        var varBe= (be!=null && be!==0 && rr!=null) ? ((rr-be)/Math.abs(be))*100 : null;
        var lyVal= actualLY[kpi][iso];
        var varLY= (lyVal!=null && lyVal!==0 && act!=null) ? ((act-lyVal)/Math.abs(lyVal))*100 : null;
        // RR vs LY = RR (proyección del mes) vs el MES COMPLETO del año pasado.
        // RR vs LM = RR vs el MES ANTERIOR completo.
        var lyF  = lyFull[kpi][iso];
        var lmF  = lmFull[kpi][iso];
        var rrVsLy= (rr!=null && lyF!=null && lyF!==0) ? ((rr-lyF)/Math.abs(lyF))*100 : null;
        var rrVsLm= (rr!=null && lmF!=null && lmF!==0) ? ((rr-lmF)/Math.abs(lmF))*100 : null;
        result[kpi][iso] = { rr:rr, be:be, beTd:(beTd!=null?beTd:null), varBe:varBe,
          varLY:varLY, ly:(lyVal!=null?lyVal:null), act:(act!=null?act:null),
          lyFull:(lyF!=null?lyF:null), lmFull:(lmF!=null?lmF:null), rrVsLy:rrVsLy, rrVsLm:rrVsLm };
      });
    });

    // ── LATAM (calculado) ───────────────────────────────────────────────
    // El grupo RR (RR/BE/Var) de LATAM = suma del RR y BE de los países (del
    // export). Var = (ΣRR − ΣBE)/ΣBE. ly/Var LY se siguen calculando con actuals.
    ['orders','gmv'].forEach(function(kpi){
      // Solo países REALES: evita que filas agregadas del target/export ("LATAM",
      // "LATAM EX AR", etc.) se sumen en el total LATAM e inflen BE/RR/actual.
      var KNOWN={AR:1,BO:1,CL:1,CO:1,CR:1,EC:1,SV:1,GT:1,HN:1,NI:1,PA:1,PY:1,PE:1,UY:1,DO:1,MX:1};
      // suma de países reales. isVal=true → valores directos; false → pick por métrica.
      function sumCountries(obj, isVal){
        var s=0, has=false;
        Object.keys(obj).forEach(function(iso){
          if(!KNOWN[iso]) return;
          var v = isVal ? obj[iso] : pick(kpi, obj[iso]);
          if(v!=null){ s+=v; has=true; }
        });
        return has ? s : null;
      }
      var actL  = (actualMTD[kpi]['LATAM']!=null) ? actualMTD[kpi]['LATAM'] : sumCountries(actualMTD[kpi], true);
      var lyL   = (actualLY[kpi]['LATAM']!=null)  ? actualLY[kpi]['LATAM']  : sumCountries(actualLY[kpi], true);
      var lyFL  = (lyFull[kpi]['LATAM']!=null)    ? lyFull[kpi]['LATAM']    : sumCountries(lyFull[kpi], true);
      var lmFL  = (lmFull[kpi]['LATAM']!=null)    ? lmFull[kpi]['LATAM']    : sumCountries(lmFull[kpi], true);
      // RR y BE de LATAM = suma de los países ya compuestos (RR/BE del export).
      var sRrL=0, sBeL=0, hasRrL=false, hasBeL=false;
      Object.keys(result[kpi]).forEach(function(iso){
        if(!KNOWN[iso]) return;   // descarta LATAM y agregados ("LATAM EX AR", etc.)
        if(result[kpi][iso].rr!=null){ sRrL+=result[kpi][iso].rr; hasRrL=true; }
        if(result[kpi][iso].be!=null){ sBeL+=result[kpi][iso].be; hasBeL=true; }
      });
      var beL = hasBeL ? sBeL : null;
      var rrL = hasRrL ? sRrL : null;
      if (beL!=null || rrL!=null || lyL!=null){
        result[kpi]['LATAM'] = {
          rr:rrL, be:beL,
          varBe:(beL!=null && beL!==0 && rrL!=null) ? ((rrL-beL)/Math.abs(beL))*100 : null,
          varLY:(lyL!=null && lyL!==0 && actL!=null) ? ((actL-lyL)/Math.abs(lyL))*100 : null,
          ly:(lyL!=null?lyL:null), act:(actL!=null?actL:null),
          lyFull:(lyFL!=null?lyFL:null), lmFull:(lmFL!=null?lmFL:null),
          rrVsLy:(rrL!=null && lyFL!=null && lyFL!==0)?((rrL-lyFL)/Math.abs(lyFL))*100:null,
          rrVsLm:(rrL!=null && lmFL!=null && lmFL!==0)?((rrL-lmFL)/Math.abs(lmFL))*100:null };
      }
    });

    // Metadata para mostrar el cartel "datos hasta X" en todas las páginas:
    // día de corte (Orders líder) + último día con dato por KPI + si está incompleto.
    function _fmtD(ms){ return (ms===-Infinity||ms==null)?null:Utilities.formatDate(new Date(ms),tz,'yyyy-MM-dd'); }
    // isMonthClose: el corte del RR (asOf) es el ÚLTIMO día de su mes → el mes ya
    // cerró y el RR deja de ser proyección = es el cierre real. El front y los mails
    // usan esto para mostrar "Cierre de mes" en vez de "RR". (Ver _rrLabelClose).
    var _lastDayOfAsOfMonth = new Date(asOf.getFullYear(), asOf.getMonth()+1, 0).getDate();
    var isMonthClose = (asOf.getDate() === _lastDayOfAsOfMonth);
    result.meta = {
      cutoff: Utilities.formatDate(asOf, tz, 'yyyy-MM-dd'),
      lastByKpi: { orders:_fmtD(maxKpiMs.orders), gmv:_fmtD(maxKpiMs.gmv) },
      incomplete: incomplete,
      isMonthClose: isMonthClose
    };

    try { cache.put(cacheKey, JSON.stringify(result), 1500); } catch(ep){}
  } catch(e) {
    Logger.log('[RR] EXCEPCIÓN: ' + e.message);
  }

  return result;
}

// Endpoint liviano que el front (daily / MTD) llama APARTE para traer el RR,
// sin bloquear la carga principal. Usa la caché propia de _getRRDataFromSheet.
function fetchRRData() {
  return _getRRDataFromSheet();
}

// Devuelve las últimas fechas reales con datos cargados en "A. TI - Actuals OKRs"
// para Confirmed Orders y GMV User Dmarts, en formato 'yyyy-MM-dd'.
function _getFechasActuals() {
  try {
    var tz = Session.getScriptTimeZone();
    var actSheet = SpreadsheetApp.openById(SPREADSHEET_ID).getSheetByName(SHEET_ACTUALS);
    if (!actSheet) return { orders: null, gmv: null };
    var ad = actSheet.getDataRange().getValues();
    if (!ad || ad.length < 2) return { orders: null, gmv: null };
    var aMi = ad[0].indexOf('Metric'), aDi = ad[0].indexOf('Date'), aVi = ad[0].indexOf('Value');
    var maxKpi = { orders: -Infinity, gmv: -Infinity };
    for (var i = 1; i < ad.length; i++) {
      var mm0 = ad[i][aMi];
      var k0 = (mm0 === 'Confirmed Orders') ? 'orders' : (mm0 === 'GMV User Dmarts') ? 'gmv' : null;
      if (!k0) continue;
      var v = ad[i][aVi];
      if (v === '' || v == null || isNaN(parseFloat(v))) continue;
      var t0 = parseDateToMs(ad[i][aDi]);
      if (isNaN(t0)) continue;
      if (t0 > maxKpi[k0]) maxKpi[k0] = t0;
    }
    function _fmt(ms) { return (ms === -Infinity || ms == null) ? null : Utilities.formatDate(new Date(ms), tz, 'yyyy-MM-dd'); }
    return {
      orders: _fmt(maxKpi.orders),
      gmv: _fmt(maxKpi.gmv),
      ordersMs: maxKpi.orders,
      gmvMs: maxKpi.gmv
    };
  } catch (e) {
    Logger.log('[_getFechasActuals] Error: ' + e.message);
    return { orders: null, gmv: null, error: e.message };
  }
}

// Diagnóstico del RR de PRODUCCIÓN (el que ven daily / MTD / email). Limpia la
// caché y recalcula FRESCO, logueando BE Mes / Actual MTD / BE MTD / RR por país,
// para comparar contra RR Compare y ver qué input está mal. CORRER DESDE EL EDITOR
// (▶ con debugRR seleccionado) y abrir "Registro de ejecución".
function debugRR() {
  try { CacheService.getScriptCache().remove('cache_rrdata_mtd'); } catch (e) {}
  var r = _getRRDataFromSheet();
  Logger.log('[debugRR] origen RR = ' + getRRSource() + '  (debería ser el mismo que RR Compare)');
  ['AR','CL','UY','LATAM'].forEach(function(iso){
    ['orders','gmv'].forEach(function(kpi){
      var o = (r[kpi] && r[kpi][iso]) || null;
      if (!o) { Logger.log('[debugRR] ' + iso + ' ' + kpi + ' → (sin dato)'); return; }
      function pct(x){ return (x==null||isNaN(x)) ? '—' : (x>=0?'+':'') + x.toFixed(1) + '%'; }
      Logger.log('[debugRR] ' + iso + ' ' + kpi +
        ' → RR=' + o.rr + '  BE Mes=' + o.be + '  Actual MTD=' + o.act + '  BE MTD=' + o.beTd +
        '  | LY mes compl=' + o.lyFull + ' (RR vs LY ' + pct(o.rrVsLy) + ')' +
        '  | LM mes compl=' + o.lmFull + ' (RR vs LM ' + pct(o.rrVsLm) + ')');
    });
  });
  return r;
}

// =================================================================
// DIAGNÓSTICO WIS UF — correr desde el editor (▶ debugWISUF) y abrir el
// "Registro de ejecución". Sirve para cuando "WIS UF %" NO aparece en MTD.
// Lee "A. TI - Actuals OKRs" y muestra:
//   1) los nombres EXACTOS de métricas que contienen "WIS" en la hoja (para ver
//      si están "Numerador WIS UF" / "Denominador WIS UF" y cómo se escriben), y
//   2) por país, la suma del MES ACTUAL de los 4 componentes + el % calculado.
// Si WIS UF no aparece, acá vas a ver o que faltan esos nombres, o que el
// denominador viene en 0 (→ WIS UF % = 0 → el panel se oculta por el filtro).
// =================================================================
function debugWISUF() {
  var sh = SpreadsheetApp.openById(SPREADSHEET_ID).getSheetByName(SHEET_ACTUALS);
  var d  = sh.getDataRange().getValues();
  var H  = d[0], mi=H.indexOf('Metric'), ci=H.indexOf('Country'), di=H.indexOf('Date'), vi=H.indexOf('Value');
  var hoy=new Date(), Y=hoy.getFullYear(), M=hoy.getMonth();
  var ini=new Date(Y,M,1).getTime(), fin=new Date(Y,M+1,0,23,59,59).getTime();
  var comps=['WIS Numerador','WIS Denominador','WIS UF Numerador','WIS UF Denominador',
             'Numerador WIS','Denominador WIS','Numerador WIS UF','Denominador WIS UF'];
  var wisNames={}, sums={};
  for (var i=1;i<d.length;i++){
    var m=d[i][mi]; if(m==null) continue;
    if(/wis/i.test(String(m))) wisNames[String(m)]=(wisNames[String(m)]||0)+1;
    if(comps.indexOf(m)===-1) continue;
    var t=parseDateToMs(d[i][di]); if(isNaN(t)||t<ini||t>fin) continue;
    var pais=COUNTRY_NAME_TO_CODE[String(d[i][ci]).trim()]||String(d[i][ci]).trim();
    if(!sums[pais]) sums[pais]={};
    sums[pais][m]=(sums[pais][m]||0)+(parseFloat(d[i][vi])||0);
  }
  Logger.log('=== Métricas con "WIS" en la hoja (nombres EXACTOS) ===');
  var ks=Object.keys(wisNames).sort();
  if(!ks.length) Logger.log('  (NINGUNA fila con "WIS" — el upstream no produce WIS)');
  ks.forEach(function(n){ Logger.log('  • "'+n+'"  ('+wisNames[n]+' filas)'); });
  Logger.log('=== Suma del mes actual por país + % calculado ===');
  Object.keys(sums).sort().forEach(function(p){
    var s=sums[p];
    function pct(n,den){ return (den>0)?((n/den)*100).toFixed(1)+'%':'—'; }
    var wN=(s['WIS Numerador']||0)+(s['Numerador WIS']||0), wD=(s['WIS Denominador']||0)+(s['Denominador WIS']||0);
    var uN=(s['WIS UF Numerador']||0)+(s['Numerador WIS UF']||0), uD=(s['WIS UF Denominador']||0)+(s['Denominador WIS UF']||0);
    Logger.log('  '+p+' → WIS '+pct(wN,wD)+' (num '+wN+'/den '+wD+')  |  '+
      'WIS UF '+pct(uN,uD)+' (num '+uN+'/den '+uD+')');
  });
  return { wisNames: ks, paises: Object.keys(sums) };
}

// =================================================================
// TEST — Compara RR y BE de los DOS orígenes, por país y KPI:
//   • EXPORT    : rr_mensual / be_mensual de "RR orders y GMV export"
//   • CALCULADO : BE Mes (target mensual) y RR = BE × (Actual MTD / BE MTD)
// La consume la mini-página 8_RR_Compare.html (?pagina=rrcompare).
// =================================================================
function fetchRRCompare(asOfOverride) {
  try {
    var tz = Session.getScriptTimeZone();
    var PAIS_ISO = {
      'argentina':'AR','bolivia':'BO','chile':'CL','colombia':'CO','costa rica':'CR',
      'ecuador':'EC','el salvador':'SV','guatemala':'GT','honduras':'HN','nicaragua':'NI',
      'panama':'PA','panamá':'PA','paraguay':'PY','peru':'PE','perú':'PE','uruguay':'UY',
      'republica dominicana':'DO','república dominicana':'DO','rep. dominicana':'DO',
      'dominican republic':'DO','mexico':'MX','méxico':'MX',
      'ar':'AR','bo':'BO','cl':'CL','co':'CO','cr':'CR','ec':'EC','sv':'SV','gt':'GT',
      'hn':'HN','ni':'NI','pa':'PA','py':'PY','pe':'PE','uy':'UY','do':'DO','mx':'MX',
      'latam':'LATAM','latin america':'LATAM'
    };
    function getISO(raw){ var s=String(raw||'').trim().toLowerCase(); return PAIS_ISO[s] || String(raw||'').trim().toUpperCase(); }
    function num(v){ if(v===''||v==null) return null; var n=parseFloat(v); return isNaN(n)?null:n; }
    var ORD_TGT=['Confirmed Orders - Target','Daily Confirmed Orders BE - Target','Orquest - Confirmed Orders - Target'];
    var GMV_TGT=['GMV User Dmarts - Target','Daily GMV BE - Target','GMV BE - Target'];
    function kpiOfTarget(nm){ if(ORD_TGT.indexOf(nm)!==-1)return 'orders'; if(GMV_TGT.indexOf(nm)!==-1)return 'gmv'; var low=String(nm).toLowerCase(); if(low.indexOf('gmv')!==-1)return 'gmv'; if(low.indexOf('order')!==-1&&low.indexOf('target')!==-1)return 'orders'; return null; }
    function pick(kpi, byName){ if(!byName)return null; var arr=(kpi==='orders')?ORD_TGT:GMV_TGT; for(var j=0;j<arr.length;j++){if(byName[arr[j]]!=null)return byName[arr[j]];} var ks=Object.keys(byName); return ks.length?byName[ks[0]]:null; }

    var tgtSS = SpreadsheetApp.openById(TARGETS_SS_ID);

    // ── as-of (último día con dato real de Orders/GMV, capado por BP1) ──
    var actSheet = SpreadsheetApp.openById(SPREADSHEET_ID).getSheetByName(SHEET_ACTUALS);
    var ad = actSheet.getDataRange().getValues();
    var aMi=ad[0].indexOf('Metric'),aCi=ad[0].indexOf('Country'),aDi=ad[0].indexOf('Date'),aVi=ad[0].indexOf('Value');
    var maxMs=-Infinity, maxKpi={orders:-Infinity,gmv:-Infinity};
    for (var i=1;i<ad.length;i++){ var mm0=ad[i][aMi]; var k0=(mm0==='Confirmed Orders')?'orders':(mm0==='GMV User Dmarts')?'gmv':null; if(!k0)continue; if(num(ad[i][aVi])==null)continue; var t0=parseDateToMs(ad[i][aDi]); if(isNaN(t0))continue; if(t0>maxMs)maxMs=t0; if(t0>maxKpi[k0])maxKpi[k0]=t0; }
    var asOf=(maxMs!==-Infinity)?new Date(maxMs):new Date();
    try{var bp1=PropertiesService.getScriptProperties().getProperty('LAST_VALID_DATE'); if(bp1){var b=new Date(parseInt(bp1)); if(!isNaN(b.getTime())&&b<asOf)asOf=b;}}catch(e){}
    // ── Día de corte. Por defecto el automático (realAsOf = último con dato real).
    //    RR Compare puede pedir otro día con asOfOverride, SOLO para esta vista:
    //    esta función no escribe caches ni propiedades, así que el día elegido NO
    //    cambia el RR que muestran las demás páginas. availableDays = los días
    //    elegibles (1° del mes → realAsOf) para armar el <select> en el front.
    var realAsOf = new Date(asOf.getTime());
    var _rY=realAsOf.getFullYear(), _rMo=realAsOf.getMonth();
    // Días elegibles: desde el 1° de ENERO del año en curso hasta realAsOf (antes era
    // solo el mes actual). Ampliado a pedido para ver el RR de cualquier día del año.
    var _yStart = new Date(_rY, 0, 1);
    var availableDays=[];
    for (var _d=new Date(_yStart.getTime()); _d.getTime()<=realAsOf.getTime(); _d.setDate(_d.getDate()+1)){
      availableDays.push(Utilities.formatDate(_d,tz,'yyyy-MM-dd'));
    }
    if (asOfOverride){
      var _m=String(asOfOverride).match(/^(\d{4})-(\d{2})-(\d{2})$/);
      if(_m){ var _ov=new Date(+_m[1],(+_m[2])-1,+_m[3]);
        // Acepta cualquier día entre el 1° de enero y realAsOf (ya no solo el mes actual).
        if(_ov.getTime()>=_yStart.getTime() && _ov.getTime()<=realAsOf.getTime()) asOf=_ov;
      }
    }
    var Y=asOf.getFullYear(),Mo=asOf.getMonth();
    var monthStartMs=new Date(Y,Mo,1).getTime(), asOfMs=new Date(Y,Mo,asOf.getDate(),23,59,59).getTime();
    var asOfDayMs=new Date(Y,Mo,asOf.getDate()).getTime();
    var curMonthKey=Y+'-'+('0'+(Mo+1)).slice(-2);
    // ¿Cada KPI tiene dato en el día de corte (as-of)? Si un KPI viene rezagado
    // (ej. GMV sin el último día), se OMITE en la página — puede pasar que esté
    // Confirmed Orders y no GMV.
    var complete={ orders:(maxKpi.orders!==-Infinity&&maxKpi.orders>=asOfDayMs),
                   gmv:   (maxKpi.gmv!==-Infinity   &&maxKpi.gmv>=asOfDayMs) };
    function _fmtMs(ms){ return ms===-Infinity?null:Utilities.formatDate(new Date(ms),tz,'yyyy-MM-dd'); }
    var lastByKpi={ orders:_fmtMs(maxKpi.orders), gmv:_fmtMs(maxKpi.gmv) };

    // ── Actual MTD ──
    var actual={orders:{},gmv:{}};
    for (var i=1;i<ad.length;i++){ var mm=ad[i][aMi]; var k=(mm==='Confirmed Orders')?'orders':(mm==='GMV User Dmarts')?'gmv':null; if(!k)continue; var t=parseDateToMs(ad[i][aDi]); if(isNaN(t)||t<monthStartMs||t>asOfMs)continue; var iso=getISO(ad[i][aCi]); if(!iso||iso==='LATAM')continue; actual[k][iso]=(actual[k][iso]||0)+(num(ad[i][aVi])||0); }

    // ── BE MTD (diario, día 1 → as-of) ──
    var beMTD={orders:{},gmv:{}};
    var dSheet=tgtSS.getSheets().find(function(s){return /Export Targets-Diario/i.test(s.getName());});
    if(dSheet){ var dd=dSheet.getDataRange().getValues(); var dH=dd[0].map(function(h){return String(h).trim().toLowerCase();}); var dMi=dH.indexOf('metric'),dCi=dH.indexOf('country'),dDi=dH.indexOf('date'),dVi=dH.indexOf('value');
      for(var i=1;i<dd.length;i++){ var nm=String(dd[i][dMi]||'').trim(); var k=kpiOfTarget(nm); if(!k)continue; var t=parseDateToMs(dd[i][dDi]); if(isNaN(t)||t<monthStartMs||t>asOfMs)continue; var iso=getISO(dd[i][dCi]); if(!iso||iso==='LATAM')continue; if(!beMTD[k][iso])beMTD[k][iso]={}; beMTD[k][iso][nm]=(beMTD[k][iso][nm]||0)+(num(dd[i][dVi])||0); } }

    // ── BE Mes (mensual, mes actual) ──
    var beMes={orders:{},gmv:{}};
    var mSheet=tgtSS.getSheets().find(function(s){return /Export Targets-Mensual/i.test(s.getName());});
    if(mSheet){ var msd=mSheet.getDataRange().getValues(); var mH=msd[0].map(function(h){return String(h).trim().toLowerCase();}); var mMi=mH.indexOf('metric'),mCi=mH.indexOf('country'),mMoi=mH.indexOf('month'),mVi=mH.indexOf('value');
      for(var i=1;i<msd.length;i++){ var nm=String(msd[i][mMi]||'').trim(); var k=kpiOfTarget(nm); if(!k)continue; if(_monthKeyOf(msd[i][mMoi])!==curMonthKey)continue; var iso=getISO(msd[i][mCi]); if(!iso||iso==='LATAM')continue; if(!beMes[k][iso])beMes[k][iso]={}; beMes[k][iso][nm]=(beMes[k][iso][nm]||0)+(num(msd[i][mVi])||0); } }

    // ── EXPORT (rr_mensual / be_mensual) ──
    var rrExp={orders:{},gmv:{}}, beExp={orders:{},gmv:{}};
    var exportFound=false, exportHeaders=null;
    var rrSheet=tgtSS.getSheets().find(function(s){return /RR orders y GMV export/i.test(s.getName());});
    if(rrSheet){
      var rd=rrSheet.getDataRange().getValues(); exportHeaders=rd[0];
      var rHn=rd[0].map(function(h){return String(h||'').toLowerCase().replace(/[áàä]/g,'a').replace(/[éèë]/g,'e').replace(/[íìï]/g,'i').replace(/[óòö]/g,'o').replace(/[úùü]/g,'u').replace(/[^a-z0-9]/g,'');});
      function colIdx(re){ for(var h=0;h<rHn.length;h++){ if(re.test(rHn[h])) return h; } return -1; }
      var rPi=colIdx(/^(pais|country)$/); if(rPi<0)rPi=colIdx(/pais|country/);
      var rKi=colIdx(/^kpi$/); if(rKi<0)rKi=colIdx(/kpi/);
      var rRi=colIdx(/^rr.*mensual$/); if(rRi<0)rRi=colIdx(/^rr$/); if(rRi<0)rRi=colIdx(/^rr.*mes/);
      var rBi=colIdx(/^be.*mensual$/); if(rBi<0)rBi=colIdx(/^be.*mes/); if(rBi<0)rBi=colIdx(/^be$/);
      if(rPi>=0&&rKi>=0&&rRi>=0){ exportFound=true;
        for(var i=1;i<rd.length;i++){ var rkRaw=String(rd[i][rKi]||'').trim().toLowerCase(); var k=(rkRaw.indexOf('gmv')!==-1)?'gmv':(rkRaw.indexOf('order')!==-1)?'orders':null; if(!k)continue; var iso=getISO(rd[i][rPi]); if(!iso||iso==='LATAM')continue; var rv=num(rd[i][rRi]); if(rv!=null)rrExp[k][iso]=rv; if(rBi>=0){var bv=num(rd[i][rBi]); if(bv!=null)beExp[k][iso]=bv;} }
      }
    }

    // ── Filas comparativas ──
    // Solo países reales: evita filas agregadas del export/targets como
    // "LATAM EX AR", que si no se sumarían dentro del total LATAM e inflarían el BE.
    var KNOWN={AR:1,BO:1,CL:1,CO:1,CR:1,EC:1,SV:1,GT:1,HN:1,NI:1,PA:1,PY:1,PE:1,UY:1,DO:1,MX:1};
    var rows=[];
    ['orders','gmv'].forEach(function(kpi){
      if(!complete[kpi]) return;   // KPI sin el último día → no se incluye
      var isoset={};
      [actual[kpi],beMes[kpi],rrExp[kpi],beExp[kpi]].forEach(function(o){ Object.keys(o).forEach(function(c){ if(KNOWN[c]) isoset[c]=true; }); });
      var tRrE=0,tBeE=0,tRrC=0,tBeC=0,hRrE=false,hRrC=false,hBeE=false,hBeC=false;
      Object.keys(isoset).sort().forEach(function(iso){
        var beCalc=pick(kpi,beMes[kpi][iso]);
        var beTd  =pick(kpi,beMTD[kpi][iso]);
        var act   =actual[kpi][iso];
        var rrCalc=(beCalc!=null&&beTd)?beCalc*((act||0)/beTd):null;
        var rrE=(rrExp[kpi][iso]!=null)?rrExp[kpi][iso]:null;
        var beE=(beExp[kpi][iso]!=null)?beExp[kpi][iso]:null;
        rows.push({kpi:kpi,pais:iso,rrExport:rrE,rrCalc:rrCalc,beExport:beE,beCalc:(beCalc!=null?beCalc:null),actual:(act!=null?act:null),beMtd:(beTd!=null?beTd:null)});
        if(rrE!=null){tRrE+=rrE;hRrE=true;} if(beE!=null){tBeE+=beE;hBeE=true;}
        if(rrCalc!=null){tRrC+=rrCalc;hRrC=true;} if(beCalc!=null){tBeC+=beCalc;hBeC=true;}
      });
      rows.push({kpi:kpi,pais:'LATAM',latam:true,rrExport:hRrE?tRrE:null,rrCalc:hRrC?tRrC:null,beExport:hBeE?tBeE:null,beCalc:hBeC?tBeC:null,actual:null,beMtd:null});
    });

    return { rows:rows, asOf:Utilities.formatDate(asOf,tz,'yyyy-MM-dd'), monthKey:curMonthKey,
             exportFound:exportFound, exportHeaders:exportHeaders, complete:complete, lastByKpi:lastByKpi,
             availableDays:availableDays,
             firstDay:Utilities.formatDate(_yStart,tz,'yyyy-MM-dd'),
             realAsOf:Utilities.formatDate(realAsOf,tz,'yyyy-MM-dd') };
  } catch(e){ return { error:e.message }; }
}

// Mes/año de una celda "Month" → "YYYY-MM". Acepta Date o "MM/DD/YYYY"
// (la hoja mensual usa MM/DD/YYYY con día siempre 01).
function _monthKeyOf(raw){
  if (raw instanceof Date) return raw.getFullYear()+'-'+('0'+(raw.getMonth()+1)).slice(-2);
  var s=String(raw||'').trim();
  var m=s.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/);
  if(m) return m[3]+'-'+('0'+m[1]).slice(-2);
  var d=new Date(s);
  if(!isNaN(d.getTime())) return d.getFullYear()+'-'+('0'+(d.getMonth()+1)).slice(-2);
  return null;
}

// =================================================================
// TARGETS
// =================================================================
function _readTargets(refDate, freshRead) {
  const cache = CacheService.getScriptCache();
  // Con refDate usa clave por fecha (para el email); sin ella usa clave fija (dashboard).
  const TKEY = refDate
    ? CACHE_KEY + '_targets_' + Utilities.formatDate(refDate, Session.getScriptTimeZone(), 'yyyyMMdd')
    : CACHE_KEY + '_targets';
  // freshRead=true (email): saltea la caché y lee la hoja SÍ o SÍ. El mail se arma
  // una vez al día — leer fresco acá garantiza que el BE del mail sea el vigente
  // aunque la planilla de targets se haya re-subido durante la mañana.
  if (!freshRead) {
    try {
      const hit = cache.get(TKEY);
      if (hit) return JSON.parse(hit);
    } catch(e) {}
  }

  const result = { orders:{}, gmv:{} };
  try {
    const sheet = SpreadsheetApp.openById(TARGETS_SS_ID)
      .getSheets()
      .find(s => TARGETS_SHEET_RE.test(s.getName()));
    if (!sheet) return result;

    const data = sheet.getDataRange().getValues();
    const headers = data[0].map(h => String(h).trim().toLowerCase());
    const colIdx = {
      metric : headers.indexOf('metric'),
      country: headers.indexOf('country'),
      date   : headers.indexOf('date'),
      value  : headers.indexOf('value')
    };

    // refDate = D-1 desde BP1 (email). Sin refDate = ayer por reloj (dashboard).
    const d1 = refDate
      ? new Date(refDate.getFullYear(), refDate.getMonth(), refDate.getDate())
      : (() => { const hoy = new Date(); return new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate() - 1); })();
    const d1Time = d1.getTime();

    for (let i = 1; i < data.length; i++) {
      const r = data[i];
      const rawDate = r[colIdx.date];
      if (!rawDate) continue;

      const rowTime = rawDate instanceof Date
        ? new Date(rawDate.getFullYear(), rawDate.getMonth(), rawDate.getDate()).getTime()
        : new Date(String(rawDate).slice(0, 10) + 'T00:00:00').getTime();

      if (rowTime !== d1Time) continue;

      const metric = String(r[colIdx.metric] || '').trim();
      const country = String(r[colIdx.country] || '').trim().toLowerCase();
      const value = r[colIdx.value];
      const iso = COUNTRY_ISO[country] || country.toUpperCase().slice(0, 2);
      if (iso === 'LATAM') continue;

      if (metric === TARGET_KEY_ORDERS && !isNaN(Number(value))) result.orders[iso] = Number(value);
      if (metric === TARGET_KEY_GMV    && !isNaN(Number(value))) result.gmv[iso]    = Number(value);
    }
  } catch(e) {}

  // TTL CORTO (15 min) a propósito — NO _getCacheTTL(). Los targets se re-suben
  // durante el día; con el TTL largo el daily/mail mostraban un BE viejo mientras
  // RR Compare (que lee la hoja en vivo, sin caché) mostraba el nuevo.
  try { cache.put(TKEY, JSON.stringify(result), 900); } catch(e) {}
  return result;
}

// Limpia TODAS las claves de caché de targets: la fija y las datadas (BP1, hoy y
// ayer). Los botones "Actualizar" limpiaban solo la fija — la datada (la que usan
// fetchDataFast con BP1 y el email) quedaba viva y el BE del daily seguía viejo.
function _clearTargetsCacheKeys(cache) {
  cache.remove(CACHE_KEY + '_targets');
  var tz = Session.getScriptTimeZone(), days = {};
  var hoy = new Date();
  days[Utilities.formatDate(hoy, tz, 'yyyyMMdd')] = 1;
  days[Utilities.formatDate(new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate() - 1), tz, 'yyyyMMdd')] = 1;
  try {
    var bp1 = PropertiesService.getScriptProperties().getProperty('LAST_VALID_DATE');
    if (bp1) days[Utilities.formatDate(new Date(parseInt(bp1)), tz, 'yyyyMMdd')] = 1;
  } catch (e) {}
  Object.keys(days).forEach(function(d){ cache.remove(CACHE_KEY + '_targets_' + d); });
}

// =================================================================
// DEBUG — Por qué el "BE diario" del Daily/mail difiere del de RR Compare/Gráfico.
// Correr desde el editor (▶ debugBEDaily) y abrir el Registro de ejecución.
// Compara el DÍA que usa cada camino y el target diario que sale para cada uno:
//   • Daily/mail            → día = celda BP1 en "Daily Data"  (_readTargets)
//   • RR Compare / Gráfico  → día = último día con dato real en "A. TI - Actuals
//                             OKRs", capado por BP1 (asOf de fetchRRCompare)
// Ambos leen el MISMO target ("Export Targets-Diario"); si los DÍAS difieren, el
// BE diario difiere (cada día tiene su propio target).
// =================================================================
function debugBEDaily() {
  var out = []; function L(s){ out.push(s); Logger.log(s); }
  var tz = Session.getScriptTimeZone();
  function ymd(d){ return (d && !isNaN(d.getTime())) ? Utilities.formatDate(d, tz, 'yyyy-MM-dd') : '(?)'; }

  // 1) DÍA del Daily/mail = celda BP1 en "Daily Data".
  var bp1d = null;
  try {
    var v = _openSheet().getRange('BP1').getValue();
    if (v instanceof Date && !isNaN(v.getTime())) bp1d = v;
    else if (v && !isNaN(Date.parse(v))) bp1d = new Date(v);
  } catch(e) { L('No pude leer BP1 en "Daily Data": ' + e.message); }
  L('DÍA Daily/mail          (BP1 en "Daily Data") : ' + ymd(bp1d));

  // 2) DÍA de RR Compare/Gráfico = último día con dato real de Orders/GMV en
  //    "A. TI - Actuals OKRs", capado por BP1 (idéntico a fetchRRCompare).
  var asOf = null;
  try {
    var ad = SpreadsheetApp.openById(SPREADSHEET_ID).getSheetByName(SHEET_ACTUALS).getDataRange().getValues();
    var aMi = ad[0].indexOf('Metric'), aDi = ad[0].indexOf('Date'), aVi = ad[0].indexOf('Value');
    var maxMs = -Infinity;
    for (var i = 1; i < ad.length; i++) {
      var mm = ad[i][aMi];
      if (mm !== 'Confirmed Orders' && mm !== 'GMV User Dmarts') continue;
      if (isNaN(parseFloat(ad[i][aVi]))) continue;
      var t = parseDateToMs(ad[i][aDi]); if (isNaN(t)) continue;
      if (t > maxMs) maxMs = t;
    }
    if (maxMs !== -Infinity) asOf = new Date(maxMs);
    if (asOf && bp1d && bp1d < asOf) asOf = new Date(bp1d.getTime());   // capado por BP1
  } catch(e) { L('No pude leer "A. TI - Actuals OKRs": ' + e.message); }
  L('DÍA RR Compare/Gráfico  (último real, cap BP1): ' + ymd(asOf));

  var distintos = bp1d && asOf && ymd(bp1d) !== ymd(asOf);
  L(distintos
    ? '>>> LOS DOS DÍAS SON DISTINTOS → esa es la causa del BE diario que no coincide.'
    : '>>> Los días coinciden → si igual difiere, avisame y miramos otra causa (granularidad/columna).');

  // 3) Target diario (Orders y GMV) por país para CADA día, para ver la diferencia.
  var sh = SpreadsheetApp.openById(TARGETS_SS_ID).getSheets()
             .find(function(s){ return TARGETS_SHEET_RE.test(s.getName()); });
  if (!sh) { L('No encontré la hoja "Export Targets-Diario".'); return out.join('\n'); }
  var td = sh.getDataRange().getValues();
  var h = td[0].map(function(x){ return String(x).trim().toLowerCase(); });
  var mi = h.indexOf('metric'), ci = h.indexOf('country'), di = h.indexOf('date'), vi = h.indexOf('value');
  function targetsForDay(d, metricName) {
    var map = {}; if (!d) return map; var key = ymd(d);
    for (var i = 1; i < td.length; i++) {
      if (String(td[i][mi] || '').trim() !== metricName) continue;
      var rd = td[i][di];
      var rk = (rd instanceof Date) ? ymd(rd) : String(rd).slice(0, 10);
      if (rk !== key) continue;
      var c = String(td[i][ci] || '').trim();
      map[c] = (map[c] || 0) + (parseFloat(td[i][vi]) || 0);
    }
    return map;
  }
  [['Orders', TARGET_KEY_ORDERS], ['GMV', TARGET_KEY_GMV]].forEach(function(kv){
    var tB = targetsForDay(bp1d, kv[1]), tA = targetsForDay(asOf, kv[1]);
    L('--- BE_LABEL ' + kv[0] + ' por país:  Daily/mail (BP1)  vs  RR Compare/Gráfico (asOf) ---');
    var paises = {}; Object.keys(tB).forEach(function(k){ paises[k]=1; }); Object.keys(tA).forEach(function(k){ paises[k]=1; });
    Object.keys(paises).sort().forEach(function(c){
      var a = tB[c], b = tA[c];
      L('  ' + c + ':  Daily=' + (a==null?'—':Math.round(a)) + '   RRCompare/Gráfico=' + (b==null?'—':Math.round(b)) + ((a!=b)?'   ⟵ DISTINTO':''));
    });
  });
  return out.join('\n');
}

// =================================================================
// GROUP BY COUNTRY (usado por email y otros callers server-side)
// =================================================================
function _groupByCountry(rows, targets) {
  const map = {};
  rows.forEach(r => {
    if (!map[r.country]) map[r.country] = { country: r.country, _rows: [] };
    map[r.country]._rows.push(r);
  });

  const result = Object.values(map).map(g => {
    const out = { country: g.country };
    METRIC_DEFS.forEach(m => {
      out[m.key] = { d1: null, d8: null, lw: null, be: null };
      ['d1', 'd8', 'lw'].forEach(p => {
        if (m.type === 'ratio') {
          const sumNum = g._rows.reduce((s, r) => {
            if (r._raw && r._raw[`${p}_${m.columna_numerador}`] !== undefined) return s + (r._raw[`${p}_${m.columna_numerador}`] || 0);
            if (r[m.key] && r[m.key]._raw && r[m.key]._raw[`${p}_${m.columna_numerador}`] !== undefined) return s + (r[m.key]._raw[`${p}_${m.columna_numerador}`] || 0);
            return s;
          }, 0);
          const sumDen = g._rows.reduce((s, r) => {
            if (r._raw && r._raw[`${p}_${m.columna_denominador}`] !== undefined) return s + (r._raw[`${p}_${m.columna_denominador}`] || 0);
            if (r[m.key] && r[m.key]._raw && r[m.key]._raw[`${p}_${m.columna_denominador}`] !== undefined) return s + (r[m.key]._raw[`${p}_${m.columna_denominador}`] || 0);
            return s;
          }, 0);
          // Seamless: si el porcentaje es mayor al 99% (ej. 100% artificial), el dato del día todavía no
          // cargó → lo tratamos como sin dato (null).
          var ratioNA = (m.key === 'seamless' && sumDen > 0 && (sumNum / sumDen) > 0.99);
          out[m.key][p] = (sumDen > 0 && !ratioNA) ? (sumNum / sumDen) * (m.fmt === 'pct' ? 100 : 1) : null;
        } else {
          out[m.key][p] = g._rows.reduce((s, r) => {
            const fromRaw = r._raw ? r._raw[`${p}_${m.columna_suma}`] : undefined;
            if (fromRaw !== undefined) return s + (fromRaw || 0);
            return s + (r[m.key] ? r[m.key][p] || 0 : 0);
          }, 0);
        }
      });
      out[m.key].be = (m.beKey && targets[m.beKey] && targets[m.beKey][g.country] != null) ? targets[m.beKey][g.country] : null;
    });
    return out;
  }).sort((a, b) => a.country.localeCompare(b.country));

  const latam = { country: 'LATAM' };
  METRIC_DEFS.forEach(m => {
    latam[m.key] = { d1: null, d8: null, lw: null, be: null };
    ['d1', 'd8', 'lw'].forEach(p => {
      if (m.type === 'ratio') {
        const sumNum = rows.reduce((s, r) => {
          if (r._raw && r._raw[`${p}_${m.columna_numerador}`] !== undefined) return s + (r._raw[`${p}_${m.columna_numerador}`] || 0);
          if (r[m.key] && r[m.key]._raw && r[m.key]._raw[`${p}_${m.columna_numerador}`] !== undefined) return s + (r[m.key]._raw[`${p}_${m.columna_numerador}`] || 0);
          return s;
        }, 0);
        const sumDen = rows.reduce((s, r) => {
          if (r._raw && r._raw[`${p}_${m.columna_denominador}`] !== undefined) return s + (r._raw[`${p}_${m.columna_denominador}`] || 0);
          if (r[m.key] && r[m.key]._raw && r[m.key]._raw[`${p}_${m.columna_denominador}`] !== undefined) return s + (r[m.key]._raw[`${p}_${m.columna_denominador}`] || 0);
          return s;
        }, 0);
        var ratioNA = (m.key === 'seamless' && sumDen > 0 && (sumNum / sumDen) > 0.99);  // ratio > 99% ⇒ dato no cargado
        latam[m.key][p] = (sumDen > 0 && !ratioNA) ? (sumNum / sumDen) * (m.fmt === 'pct' ? 100 : 1) : null;
      } else {
        latam[m.key][p] = rows.reduce((s, r) => {
          const fromRaw = r._raw ? r._raw[`${p}_${m.columna_suma}`] : undefined;
          if (fromRaw !== undefined) return s + (fromRaw || 0);
          return s + (r[m.key] ? r[m.key][p] || 0 : 0);
        }, 0);
      }
    });
    if (m.beKey && targets[m.beKey]) {
      let sumBe = 0, hasBe = false;
      Object.values(targets[m.beKey]).forEach(val => { if (val != null && !isNaN(val)) { sumBe += val; hasBe = true; }});
      latam[m.key].be = hasBe ? sumBe : null;
    }
  });
  result.push(latam);
  return result;
}

// =================================================================
// ████  MTD & GRÁFICOS — fusionado desde MTD_Code.gs  ████
// Actuals SS: 10CBChAymE8k09cb_-D_ECD9KriZ0SbSve75IYBU7ZzM
// =================================================================

var SPREADSHEET_ID         = '10CBChAymE8k09cb_-D_ECD9KriZ0SbSve75IYBU7ZzM';
var SHEET_ACTUALS          = 'A. TI - Actuals OKRs';
var SPREADSHEET_TARGETS_ID_MTD = '1WC2EpydmUiu3dvHzYGQeDH5njZlGnfisa5DGfIknJI4';
var SHEET_TARGETS          = 'B. Export Targets-Diario';

// Mapeado de nombre UI → nombre(s) en hoja de targets.
// Arrays = acepta cualquiera de los nombres listados.
var METRIC_TARGET_MAP = {
  'Confirmed Orders': ['Daily Confirmed Orders BE - Target', 'Orquest - Confirmed Orders - Target', 'Confirmed Orders - Target'],
  'GMV User Dmarts':  ['Daily GMV BE - Target', 'GMV User Dmarts - Target', 'GMV BE - Target']
};

var METRICAS_DEMANDA = ['Confirmed Orders', 'GMV User Dmarts', 'Users DMart', 'new_users', 'UF Orders'];

var CONFIG_METRICAS = [
  { metrica: 'Confirmed Orders',   formula: function(c){ return c['Confirmed Orders']||0; },  formato:'num',  tipo_color:1 },
  { metrica: 'GMV User Dmarts',    formula: function(c){ return c['GMV User Dmarts']||0; },   formato:'num',  tipo_color:1 },
  { metrica: 'Users DMart',        formula: function(c){ return c['Users DMart']||0; },        formato:'num',  tipo_color:1 },
  { metrica: 'Platform Maus penetration %',
    formula: function(c){ var u=c['Users DMart']||0,m=c['Users Peya']||0; return m?(u/m):0; },
    formato:'pct', tipo_color:1 },
  { metrica: 'New Users',          formula: function(c){ return c['new_users']||0; },          formato:'num',  tipo_color:1 },
  { metrica: 'WIS %',
    // Nombres NUEVOS del consolidado ("WIS Numerador/Denominador") + los VIEJOS
    // ("Numerador/Denominador WIS") sumados como fallback: una fecha trae solo un
    // juego de nombres, así que sumar ambos NO duplica y sobrevive la transición.
    formula: function(c){
      var n=(c['WIS Numerador']||0)+(c['Numerador WIS']||0);
      var d=(c['WIS Denominador']||0)+(c['Denominador WIS']||0);
      return d?(n/d):0;
    },
    formato:'pct', tipo_color:1 },
  { metrica: 'WIS UF %',
    formula: function(c){
      var n=(c['WIS UF Numerador']||0)+(c['Numerador WIS UF']||0);
      var d=(c['WIS UF Denominador']||0)+(c['Denominador WIS UF']||0);
      return d?(n/d):0;
    },
    formato:'pct', tipo_color:1 },
  { metrica: 'Seamless Delivery %',
    formula: function(c){ var t=c['Total_orders_fact_orders_all_status']||0; return t?((c['Seamless Delivery orders']||0)/t):0; },
    formato:'pct', tipo_color:1 },
  { metrica: 'Avg. Delivery Time',
    formula: function(c){
      var t = (c['Non_forced_completed_orders_logistics'] || 0) + (c['non_forced_completed_orders_logistics'] || 0) || (c['Total_orders_fact_orders'] || 0);
      return t ? ((c['Delivery Time total'] || 0) / t) : 0;
    },
    formato:'time', tipo_color:0 },
  { metrica: 'Assignment Time',
    formula: function(c){ var t=c['Total_orders_fact_orders']||0; return t?((c['Assignment Time total']||0)/t):0; },
    formato:'time', tipo_color:0 },
  { metrica: 'HC Sessions orders %',
    formula: function(c){ var t=c['Total_orders_fact_orders_all_status']||0; return t?((c['HC Sessions orders']||0)/t):0; },
    formato:'pct', tipo_color:0 }, // menos es mejor: bajar = verde
  { metrica: 'Rejected Orders %',
    formula: function(c){ var t=c['Total_orders_fact_orders_all_status']||0; return t?((c['Rejected orders']||0)/t):0; },
    formato:'pct', tipo_color:0 },
  { metrica: 'Assignment Time > 6 min %',
    // Assignment Time > 6 min orders / Total_orders_timings. tipo_color:0 = menos es mejor.
    formula: function(c){ var t=c['Total_orders_timings']||0; return t?((c['Assignment Time > 6 min orders']||0)/t):0; },
    formato:'pct', tipo_color:0 }
];

var COMPONENTES_CRUDOS = [
  'Confirmed Orders','GMV User Dmarts','Users DMart','Users Peya','new_users',
  'WIS Numerador','WIS Denominador','WIS UF Numerador','WIS UF Denominador',        // nombres NUEVOS
  'Numerador WIS','Denominador WIS','Numerador WIS UF','Denominador WIS UF',         // viejos (fallback transición)
  'Seamless Delivery orders','Total_orders_fact_orders','Total_orders_fact_orders_all_status',
  'Delivery Time total','Assignment Time total',
  'HC Sessions orders','Rejected orders',
  'Assignment Time > 6 min orders','Total_orders_timings',
  'Non_forced_completed_orders_logistics', 'non_forced_completed_orders_logistics'
];

var METRICAS_FINALES = CONFIG_METRICAS.map(function(m){ return m.metrica; });

// Métricas MTD "snapshot" para la PÁGINA MTD by country (NO el mail): acumulados
// month-to-date que NO se suman por día — se muestra el valor de la ÚLTIMA fecha
// con dato ≤ fin del rango elegido. Salen de A. TI - Actuals OKRs (mismas filas
// Metric | Country | Date | Value). Se inyectan en el payload con config.mtd=true.
var MTD_SNAPSHOT_METRICS = ['PeYa MAUs - MTD', 'Dmart MAUs - MTD', 'Dmart MAUs - Plus - MTD', 'New Users - Dmart - MTD'];

// Componente "representativo" de cada métrica final → para mostrar "datos hasta
// qué fecha" en cada métrica (la última fecha con dato de ese componente).
var METRIC_REP_COMPONENT = {
  'Confirmed Orders':'Confirmed Orders',
  'GMV User Dmarts':'GMV User Dmarts',
  'Users DMart':'Users DMart',
  'Platform Maus penetration %':'Users DMart',
  'New Users':'new_users',
  'WIS %':'WIS Numerador',
  'WIS UF %':'WIS UF Numerador',
  'Seamless Delivery %':'Seamless Delivery orders',
  'Avg. Delivery Time':'Delivery Time total',
  'Assignment Time':'Assignment Time total',
  'HC Sessions orders %':'HC Sessions orders',
  'Rejected Orders %':'Rejected orders',
  'Assignment Time > 6 min %':'Assignment Time > 6 min orders'
};

var COUNTRY_NAME_TO_CODE = {
  'Argentina':'AR','Bolivia':'BO','Chile':'CL','Colombia':'CO','Costa Rica':'CR',
  'Ecuador':'EC','El Salvador':'SV','Guatemala':'GT','Honduras':'HN','Nicaragua':'NI',
  'Panamá':'PA','Panama':'PA','Paraguay':'PY','Perú':'PE','Peru':'PE',
  'Uruguay':'UY','República Dominicana':'DO','Republica Dominicana':'DO',
  'México':'MX','Mexico':'MX','LATAM':'LATAM','LATAM ex AR':'LATAM ex AR'
};

function getScriptUrl() { return ScriptApp.getService().getUrl(); }

// URL del panel "Ejecuciones" (Executions) del proyecto Apps Script. Se usa para
// saltar desde la web app (página Email) al log de ejecuciones y verificar, p.ej.,
// que el envío del mail corrió una sola vez.
function getExecutionsUrl() {
  return 'https://script.google.com/home/projects/' + ScriptApp.getScriptId() + '/executions';
}

// Precalienta todos los caches del servidor (Daily + MTD + Gráfico)
// Configurar un trigger: cada mañana a las 9hs → función warmAllCaches
function warmAllCaches() {
  try { _readSheetFast();        Logger.log('[OK] Daily cache warmed'); } catch(e){ Logger.log('[ERROR] Daily: '+e.message); }
  try { fetchMtdActuals('','');  Logger.log('[OK] MTD cache warmed');   } catch(e){ Logger.log('[ERROR] MTD: '+e.message);   }
  try { fetchDailyCharts();      Logger.log('[OK] Grafic cache warmed'); } catch(e){ Logger.log('[ERROR] Grafic: '+e.message); }
  try { _readTargets();          Logger.log('[OK] Targets cache warmed'); } catch(e){ Logger.log('[ERROR] Targets: '+e.message); }
  Logger.log('warmAllCaches completado');
}

function limpiarCacheMTD() {
  var c   = CacheService.getScriptCache();
  var tz  = Session.getScriptTimeZone();
  var hoy = new Date();
  var mesInicio = Utilities.formatDate(new Date(hoy.getFullYear(), hoy.getMonth(), 1), tz, 'yyyy-MM-dd');

  // Limpia todas las combinaciones posibles del mes actual (día 1 hasta hoy)
  var keys = ['cache_mtd_actuals__', 'cache_mtd_targets__'];
  for (var d = 1; d <= hoy.getDate(); d++) {
    var endDate = Utilities.formatDate(new Date(hoy.getFullYear(), hoy.getMonth(), d), tz, 'yyyy-MM-dd');
    keys.push('cache_mtd_actuals_'  + mesInicio + '_' + endDate);
    keys.push('cache_mtd_targets_'  + mesInicio + '_' + endDate);
  }
  keys.push('cache_rrdata_mtd');   // RR/BE Mes calculado
  keys.forEach(function(k){ c.remove(k); });
  Logger.log('Cache MTD limpiado OK — ' + keys.length + ' claves removidas (mes inicio: ' + mesInicio + ')');
}

// DEBUG — Por qué "Rejected Orders" viene vacío en MTD.
// Corré esta función desde el editor y abrí el registro (Ver → Registros de ejecución).
// El MTD calcula Rejected Orders = Fail Rate / Total_orders_ops, leyendo filas de la
// hoja de actuals que se llamen LITERAL 'Fail Rate' y 'Total_orders_ops'. Esto confirma
// con qué nombre figuran realmente esas filas en tu hoja.
function debugRejectedNames() {
  var ss = SpreadsheetApp.openById(SPREADSHEET_ID);
  var sheet = ss.getSheetByName(SHEET_ACTUALS);
  var data = sheet.getDataRange().getValues();
  var idxMetric = data[0].indexOf('Metric'), idxValue = data[0].indexOf('Value');
  var names = {}, matches = {};
  for (var i = 1; i < data.length; i++) {
    var m = String(data[i][idxMetric] || '').trim();
    if (!m) continue;
    names[m] = (names[m] || 0) + 1;
    if (/reject|fail/i.test(m)) {
      var v = parseFloat(data[i][idxValue]);
      if (!matches[m]) matches[m] = { filas: 0, conValor: 0 };
      matches[m].filas++;
      if (!isNaN(v) && v > 0) matches[m].conValor++;
    }
  }
  Logger.log('— Métricas que contienen "reject"/"fail" —');
  Logger.log(JSON.stringify(matches, null, 2));
  Logger.log('¿Existe fila "Fail Rate"? ' + (names['Fail Rate'] ? 'SÍ (' + names['Fail Rate'] + ' filas)' : 'NO'));
  Logger.log('¿Existe fila "Total_orders_ops"? ' + (names['Total_orders_ops'] ? 'SÍ (' + names['Total_orders_ops'] + ' filas)' : 'NO'));
  Logger.log('— Todos los nombres de métrica distintos en la hoja —');
  Logger.log(JSON.stringify(Object.keys(names).sort()));
}

// DEBUG — Headers de la hoja Daily Data del daily (D-1/D-8/L3W de Orders y GMV).
// El VAR L3W de Orders/GMV sale vacío si las columnas de L3W NO se llaman
// EXACTAMENTE 'lw_orders' / 'lw_gmv' (la lectura es case-sensitive).
// Corré esto y mirá en los registros qué columnas de orders/gmv hay y si
// existen las de L3W. Si tienen otro nombre, decímelo y ajusto el código.
function debugDailyHeaders() {
  var sheet = _openSheet();
  var lastCol = sheet.getLastColumn();
  var headers = sheet.getRange(1, 1, 1, lastCol).getValues()[0].map(function(h){ return String(h).trim(); });
  Logger.log('— TODOS los headers de la hoja Daily Data (' + headers.length + ') —');
  Logger.log(JSON.stringify(headers));
  var rel = headers.filter(function(h){ return /orders|gmv/i.test(h); });
  Logger.log('— Headers con "orders"/"gmv" —');
  Logger.log(JSON.stringify(rel, null, 2));
  ['d1_orders','d8_orders','lw_orders','d1_gmv','d8_gmv','lw_gmv'].forEach(function(k){
    Logger.log('¿Existe exactamente "' + k + '"? ' + (headers.indexOf(k) !== -1 ? 'SÍ [OK]' : 'NO [ERROR]'));
  });
  var l3wish = headers.filter(function(h){ return /lw|l3w|week|sem|3w|prom/i.test(h); });
  Logger.log('— Candidatos a columnas de L3W (lw/l3w/week/sem/3w/prom) —');
  Logger.log(JSON.stringify(l3wish, null, 2));
}

// DEBUG — Qué métricas devuelve el backend al MTD AHORA mismo.
// Limpia el caché, recalcula y lista las claves. La página solo muestra una
// métrica si su nombre exacto aparece acá. Corré esto y mirá los registros.
function debugMtdKeys() {
  limpiarCacheMTD();                         // fuerza recálculo (saltea caché viejo)
  var r = fetchMtdActuals('', '');           // recalcula con el código actual
  var p = (r && r.payload) ? r.payload : {};
  if (p.error) { Logger.log('ERROR: ' + p.error); return; }
  var keys = Object.keys(p.metrics || {});
  Logger.log('Métricas que devuelve el backend AHORA:');
  Logger.log(JSON.stringify(keys.sort(), null, 2));
  Logger.log('¿Incluye "Rejected Orders %"? ' + (keys.indexOf('Rejected Orders %') !== -1 ? 'SÍ [OK]' : 'NO [ERROR] (subí Code.gs con el rename)'));
  var rj = (p.metrics && p.metrics['Rejected Orders %']) ? p.metrics['Rejected Orders %'] : null;
  Logger.log('Rejected Orders % — LATAM: ' + JSON.stringify(rj ? rj['LATAM'] : '(sin clave)'));
}

// DEBUG — RR/BE Mes calculado desde las tablas de targets + actuals.
// Limpia su caché, recalcula y muestra valores de muestra + los nombres de
// métrica que tiene la hoja mensual (para confirmar que GMV/Orders matchean).
function debugRRData() {
  CacheService.getScriptCache().remove('cache_rrdata_mtd');
  try {
    var ss = SpreadsheetApp.openById(TARGETS_SS_ID);
    var mS = ss.getSheets().find(function(s){ return /Export Targets-Mensual/i.test(s.getName()); });
    if (!mS) { Logger.log('[ERROR] No encontré la hoja "A. Export Targets-Mensual".'); }
    else {
      var md = mS.getDataRange().getValues();
      var mi = md[0].map(function(h){ return String(h).trim().toLowerCase(); }).indexOf('metric');
      var nm = {};
      for (var i = 1; i < md.length; i++) { var n = String(md[i][mi] || '').trim(); if (n) nm[n] = (nm[n] || 0) + 1; }
      Logger.log('Métricas en "A. Export Targets-Mensual": ' + JSON.stringify(Object.keys(nm)));
    }
  } catch (e) { Logger.log('debugRRData (mensual) error: ' + e.message); }
  // "RR orders y GMV export": headers + muestra (de acá sale el RR Mes).
  try {
    var ssR = SpreadsheetApp.openById(TARGETS_SS_ID);
    var rS = ssR.getSheets().find(function(s){ return /RR orders y GMV export/i.test(s.getName()); });
    if (!rS) { Logger.log('[ERROR] No encontré la hoja "RR orders y GMV export".'); }
    else {
      var rdv = rS.getDataRange().getValues();
      Logger.log('Headers "RR orders y GMV export": ' + JSON.stringify(rdv[0]));
      // Misma normalización robusta que usa _getRRDataFromSheet.
      var rhn = rdv[0].map(function(h){ return String(h||'').toLowerCase()
        .replace(/[áàä]/g,'a').replace(/[éèë]/g,'e').replace(/[íìï]/g,'i')
        .replace(/[óòö]/g,'o').replace(/[úùü]/g,'u').replace(/[^a-z0-9]/g,''); });
      Logger.log('Headers normalizados: ' + JSON.stringify(rhn));
      function ci(re){ for(var h=0;h<rhn.length;h++){ if(re.test(rhn[h])) return h; } return -1; }
      var idxPais=ci(/^(pais|country)$/)>=0?ci(/^(pais|country)$/):ci(/pais|country/);
      var idxKpi =ci(/^kpi$/)>=0?ci(/^kpi$/):ci(/kpi/);
      var idxRR  =ci(/^rr.*mensual$/)>=0?ci(/^rr.*mensual$/):(ci(/^rr$/)>=0?ci(/^rr$/):ci(/^rr.*mes/));
      var idxBE  =ci(/^be.*mensual$/)>=0?ci(/^be.*mensual$/):(ci(/^be.*mes/)>=0?ci(/^be.*mes/):ci(/^be$/));
      Logger.log('Columnas detectadas → pais:'+idxPais+'  kpi:'+idxKpi+'  RR:'+idxRR+'  BE:'+idxBE+((idxRR<0||idxBE<0)?'  [ERROR] falta RR o BE':'  [OK]'));
      Logger.log('  fila ejemplo: ' + JSON.stringify(rdv[1] || '(vacía)'));
      if (idxRR>=0 && idxBE>=0 && rdv[1]) {
        var exRR=num(rdv[1][idxRR]), exBE=num(rdv[1][idxBE]);
        Logger.log('  ejemplo → RR:'+exRR+'  BE:'+exBE+'  Var=(RR−BE)/BE:'+((exRR!=null&&exBE)?((exRR-exBE)/Math.abs(exBE)*100).toFixed(2)+'%':'(s/d)'));
      }
    }
  } catch (e) { Logger.log('debugRRData (RR export) error: ' + e.message); }
  // ¿Existe una fila LATAM (country) en las hojas de target? Si SÍ, el RR de
  // LATAM se toma de esa fila; si NO, se calcula sumando países.
  try {
    var ssC = SpreadsheetApp.openById(TARGETS_SS_ID);
    [['Export Targets-Mensual','A. Mensual'], ['Export Targets-Diario','B. Diario']].forEach(function(p){
      var sh = ssC.getSheets().find(function(s){ return new RegExp(p[0],'i').test(s.getName()); });
      if (!sh) { Logger.log(p[1] + ': hoja no encontrada'); return; }
      var d = sh.getDataRange().getValues();
      var ci = d[0].map(function(h){ return String(h).trim().toLowerCase(); }).indexOf('country');
      var hasLatam = false;
      for (var i = 1; i < d.length && !hasLatam; i++) { if (/^(latam|latin america)$/i.test(String(d[i][ci]||'').trim())) hasLatam = true; }
      Logger.log(p[1] + ' — ¿fila LATAM (country)? ' + (hasLatam ? 'SÍ [OK] (usa esa)' : 'NO [ERROR] (suma países)'));
    });
  } catch (e) { Logger.log('debugRRData (LATAM check) error: ' + e.message); }
  var r = _getRRDataFromSheet();
  Logger.log('AR Orders:    ' + JSON.stringify(r.orders && r.orders['AR']));
  Logger.log('AR GMV:       ' + JSON.stringify(r.gmv && r.gmv['AR']));
  Logger.log('LATAM Orders: ' + JSON.stringify(r.orders && r.orders['LATAM']));
  Logger.log('LATAM GMV:    ' + JSON.stringify(r.gmv && r.gmv['LATAM']));
  // ── Fila LATAM vs suma de TODOS los países (sin podar) ──────────────
  // Si "fila LATAM" > "Σ países", la diferencia son países que están en el
  // target de LATAM pero que el daily NO muestra (sin warehouse en el extract),
  // o algo que la fila LATAM incluye y los países no.
  ['orders','gmv'].forEach(function(kpi){
    var d = r[kpi] || {}, sBe=0, sRr=0, cnt=0, paises=[];
    Object.keys(d).forEach(function(iso){
      if (iso==='LATAM') return;
      if (d[iso].be!=null){ sBe+=d[iso].be; cnt++; }
      if (d[iso].rr!=null){ sRr+=d[iso].rr; }
      paises.push(iso);
    });
    var L = d['LATAM'] || {};
    Logger.log('— ' + kpi.toUpperCase() + ' — países en backend (' + cnt + '): ' + JSON.stringify(paises.sort()));
    Logger.log('   Σ BE países = ' + Math.round(sBe) + '  |  fila LATAM BE = ' + (L.be!=null?Math.round(L.be):'(s/d)') + '  |  dif = ' + (L.be!=null?Math.round(L.be - sBe):'?'));
    Logger.log('   Σ RR países = ' + Math.round(sRr) + '  |  fila LATAM RR = ' + (L.rr!=null?Math.round(L.rr):'(s/d)') + '  |  dif = ' + (L.rr!=null?Math.round(L.rr - sRr):'?'));
  });
}

// =================================================================
// DEBUG — fetchTargetsOnly
// Ejecutar manualmente desde el editor para ver qué está pasando
// =================================================================
function debugTargets() {
  // Usa el mismo período que calcularía fetchMtdActuals por defecto
  var tz  = Session.getScriptTimeZone();
  var hoy = new Date();
  var startStr = Utilities.formatDate(new Date(hoy.getFullYear(), hoy.getMonth(), 1), tz, 'yyyy-MM-dd');
  var endStr   = Utilities.formatDate(new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate()-1), tz, 'yyyy-MM-dd');

  Logger.log('=== DEBUG fetchTargetsOnly ===');
  Logger.log('Período: ' + startStr + ' → ' + endStr);

  var ss = SpreadsheetApp.openById(SPREADSHEET_TARGETS_ID_MTD);
  var sheet = ss.getSheets().find(function(s){ return /Export Targets-Diario/i.test(s.getName()); });

  if (!sheet) {
    Logger.log('[ERROR] HOJA NO ENCONTRADA. Hojas disponibles:');
    ss.getSheets().forEach(function(s){ Logger.log('  - "' + s.getName() + '"'); });
    return;
  }
  Logger.log('[OK] Hoja encontrada: "' + sheet.getName() + '"');

  var data = sheet.getDataRange().getValues();
  Logger.log('Total filas (con header): ' + data.length);

  var headers = data[0].map(function(h){ return String(h).trim().toLowerCase(); });
  Logger.log('Headers detectados: ' + JSON.stringify(headers));

  var idxMetric  = headers.indexOf('metric');
  var idxCountry = headers.indexOf('country');
  var idxDate    = headers.indexOf('date');
  var idxValue   = headers.indexOf('value');
  Logger.log('Índices → metric:' + idxMetric + ' country:' + idxCountry + ' date:' + idxDate + ' value:' + idxValue);

  if (idxMetric===-1||idxCountry===-1||idxDate===-1||idxValue===-1) {
    Logger.log('[ERROR] Faltan columnas. Verificá los nombres de las columnas en la hoja.');
    return;
  }

  var reverseMap = {};
  Object.keys(METRIC_TARGET_MAP).forEach(function(fk){
    var v = METRIC_TARGET_MAP[fk];
    if (Array.isArray(v)) { v.forEach(function(s){ reverseMap[s] = fk; }); }
    else { reverseMap[v] = fk; }
  });
  Logger.log('Métricas buscadas: ' + JSON.stringify(Object.keys(reverseMap)));

  var matchedRows = 0, skippedDate = 0, skippedMetric = 0;
  var sampleMatches = [];

  for (var i = 1; i < data.length; i++) {
    var rMR = String(data[i][idxMetric] || '').trim();
    if (!rMR) continue;

    var finalKey = reverseMap[rMR];
    if (!finalKey) { skippedMetric++; continue; }

    var rCR      = String(data[i][idxCountry] || '').trim();
    var rDateRaw = data[i][idxDate];
    var rDateYMD = normalizeDateToYMD(rDateRaw);
    var rValue   = parseFloat(data[i][idxValue]) || 0;

    // Mostrá los primeros 5 rows que pasan el filtro de métrica
    if (sampleMatches.length < 5) {
      sampleMatches.push({
        fila: i+1, metric: rMR, country: rCR,
        dateRaw: String(rDateRaw), dateYMD: rDateYMD, value: rValue,
        pasaFiltro: (rDateYMD >= startStr && rDateYMD <= endStr)
      });
    }

    if (!rDateYMD || rDateYMD < startStr || rDateYMD > endStr) {
      skippedDate++;
      continue;
    }
    matchedRows++;
  }

  Logger.log('--- Primeras filas que matchean la métrica (antes del filtro de fecha):');
  sampleMatches.forEach(function(r){
    Logger.log('  Fila ' + r.fila + ': metric="' + r.metric + '" country="' + r.country +
               '" dateRaw="' + r.dateRaw + '" dateYMD="' + r.dateYMD +
               '" value=' + r.value + ' pasaFiltroFecha=' + r.pasaFiltro);
  });
  Logger.log('Filas que PASAN el filtro de fecha: ' + matchedRows);
  Logger.log('Filas salteadas por fecha:   ' + skippedDate);
  Logger.log('Filas salteadas por métrica: ' + skippedMetric);

  // Mostrá el valor por SOURCE METRIC para Argentina
  Logger.log('--- Valores por source metric para Argentina (Confirmed Orders):');
  var arBySource = {};
  for (var i2 = 1; i2 < data.length; i2++) {
    var rMR2   = String(data[i2][idxMetric]  || '').trim();
    var rCR2   = String(data[i2][idxCountry] || '').trim();
    var rDate2 = normalizeDateToYMD(data[i2][idxDate]);
    var rVal2  = parseFloat(data[i2][idxValue]) || 0;
    var fk2    = reverseMap ? reverseMap[rMR2] : null;
    if (fk2 !== 'Confirmed Orders') continue;
    if (rCR2 !== 'Argentina' && rCR2 !== 'AR') continue;
    if (!rDate2 || rDate2 < startStr || rDate2 > endStr) continue;
    arBySource[rMR2] = (arBySource[rMR2] || 0) + rVal2;
  }
  Object.keys(arBySource).forEach(function(src){
    Logger.log('  "' + src + '" → ' + arBySource[src]);
  });

  // Corré el fetch real y mostrá el resultado final
  CacheService.getScriptCache().remove('cache_mtd_targets_' + startStr + '_' + endStr);
  var result = fetchTargetsOnly(startStr, endStr);
  Logger.log('--- Resultado final (después de priority selection):');
  var co = result['Confirmed Orders'] || {};
  Object.keys(co).slice(0, 6).forEach(function(c){
    Logger.log('  ' + c + ': ' + co[c]);
  });
  Logger.log('Orden de prioridad actual para Confirmed Orders: ' + JSON.stringify(METRIC_TARGET_MAP['Confirmed Orders']));
  Logger.log('=== FIN DEBUG ===');
}

function forceRefresh(s, e) {
  var cache = CacheService.getScriptCache();
  cache.remove("cache_mtd_actuals_" + s + "_" + e);
  cache.remove("cache_mtd_actuals_v2_" + s + "_" + e);
  cache.remove("cache_mtd_targets_" + s + "_" + e);
  cache.remove("cache_mtd_actuals__");
  return true;
}

function computeFinalMetrics(components) {
  var res = {};
  CONFIG_METRICAS.forEach(function(item){ res[item.metrica] = item.formula(components); });
  return res;
}

// TZ del script cacheada: Session.getScriptTimeZone() se llamaba por cada fila
// (dos veces) en los loops grandes. Se resuelve una sola vez por ejecución.
var _SCRIPT_TZ_ = null;
function _scriptTz() {
  if (_SCRIPT_TZ_ == null) { try { _SCRIPT_TZ_ = Session.getScriptTimeZone(); } catch (e) { _SCRIPT_TZ_ = 'America/Argentina/Buenos_Aires'; } }
  return _SCRIPT_TZ_;
}

function normalizeDateToYMD(raw) {
  if (!raw) return null;
  if (raw instanceof Date) return Utilities.formatDate(raw, _scriptTz(), "yyyy-MM-dd");
  var s = String(raw).trim();
  if (/^\d{4}-\d{2}-\d{2}$/.test(s)) return s;
  var m1 = s.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/);
  if (m1) return m1[3]+'-'+('0'+m1[2]).slice(-2)+'-'+('0'+m1[1]).slice(-2);
  var MONTHS={
    jan:'01',feb:'02',mar:'03',apr:'04',may:'05',jun:'06',jul:'07',aug:'08',sep:'09',oct:'10',nov:'11',dec:'12',
    ene:'01',abr:'04',ago:'08',set:'09',dic:'12'
  };
  var m2 = s.match(/^(\d{1,2})-([A-Za-z]{3})-(\d{4})$/);
  if (m2){ var mm=MONTHS[m2[2].toLowerCase()]; if(mm) return m2[3]+'-'+mm+'-'+('0'+m2[1]).slice(-2); }
  var d = new Date(s);
  if (!isNaN(d.getTime())) return Utilities.formatDate(d, _scriptTz(), "yyyy-MM-dd");
  return null;
}

// Memo por valor de fecha: las hojas tienen miles de filas pero pocas fechas
// distintas. Cachear el resultado evita llamar Utilities.formatDate por cada
// fila (era el cuello de botella que hacía lentísima/colgaba la carga del MTD
// y el daily). La caché vive durante UNA ejecución (se llena en los loops).
var _DATE_MS_CACHE_ = {};
function parseDateToMs(raw) {
  if (!raw) return NaN;
  // Clave: para Date usamos su timestamp crudo (mismas fechas → mismo getTime);
  // para texto, el string normalizado. Distintos tipos no colisionan (prefijo).
  var key = (raw instanceof Date) ? ('D' + raw.getTime()) : ('S' + raw);
  var hit = _DATE_MS_CACHE_[key];
  if (hit !== undefined) return hit;

  // Importante: incluso para objetos Date pasamos por normalizeDateToYMD
  // (que usa formatDate con la TZ del script) y reconstruimos la medianoche
  // LOCAL del día calendario. Así el bucketing por día coincide con los
  // límites start/end del período (también medianoche local). El atajo
  // viejo `raw.getTime()` devolvía el instante crudo: si la TZ del sheet
  // está adelantada respecto a la del script, el día 1 caía antes de
  // startTime y se perdía (el resto del mes entraba igual).
  var ymd = normalizeDateToYMD(raw);
  var ms;
  if (!ymd) { ms = NaN; }
  else { var p = ymd.split('-'); ms = new Date(parseInt(p[0]), parseInt(p[1])-1, parseInt(p[2])).getTime(); }
  _DATE_MS_CACHE_[key] = ms;
  return ms;
}

// ── Usuarios SEMANALES (pestaña "Weekly users" del MISMO spreadsheet) ──────────
// Son snapshots semanales (no existen a nivel día → no se pueden sumar). Se muestra
// el valor FIJO de una semana, con WoW vs la semana anterior. Métricas:
//   • Dmart MAUs                 = Users_dmart_weekly
//   • New Users - Dmart          = Dmart_New_Users
//   • Covered MAUs penetration % = Users_dmart_weekly / Users_Peya_Weekly (%)
var WEEKLY_USERS_SHEET = 'C. Weekly users';   // nombre exacto en el Sheet: "C. Weekly users"

// Busca la pestaña de usuarios semanales tolerante al PREFIJO y nombre:
// 1) Intenta el nombre exacto configurado
// 2) Búsqueda tolerante por regex de nombre (weekly data, weekly users, etc.)
// 3) Búsqueda por encabezados de la fila 1 (si tiene Week y Users_dmart_weekly)
function _openWeeklyUsersSheet(ss){
  if (!ss) return null;
  var direct = ss.getSheetByName(WEEKLY_USERS_SHEET);
  if (direct) return direct;

  var sheets = ss.getSheets();
  var found = sheets.find(function(s){
    var n = s.getName().trim().toLowerCase();
    return /weekly\s*(data|users?)/i.test(n) ||
           /usuarios?\s*semanal/i.test(n) ||
           (n.includes('weekly') && (n.includes('user') || n.includes('data'))) ||
           n.includes('weekly users');
  });
  if (found) return found;

  // Inspección inteligente de encabezados de la fila 1
  for (var i = 0; i < sheets.length; i++) {
    try {
      var lastCol = sheets[i].getLastColumn();
      if (lastCol < 3) continue;
      var headerRow = sheets[i].getRange(1, 1, 1, Math.min(15, lastCol)).getValues()[0];
      var headerStr = headerRow.map(function(c){ return String(c || '').toLowerCase().trim(); }).join(',');
      if (headerStr.includes('week') && (headerStr.includes('users_dmart') || headerStr.includes('dmart_new_users') || headerStr.includes('users_peya'))) {
        return sheets[i];
      }
    } catch(e) {}
  }

  return null;
}

// Nombre de país (la pestaña usa INGLÉS: "Dominican Republic", "Panama", "Peru") → ISO.
function _weeklyUserISO(raw){
  var s = String(raw||'').trim();
  if(!s) return null;
  var hit = COUNTRY_NAME_TO_CODE[s] || COUNTRY_NAME_TO_CODE[s.toLowerCase()] || COUNTRY_ISO[s.toLowerCase()];
  if(hit) return hit;
  var EN = { 'dominican republic':'DO', 'costa rica':'CR', 'mexico':'MX' };
  return EN[s.toLowerCase()] || null;
}

// Devuelve {ok, metrics, config, countries} para el rango [startStr,endStr]. Toma la
// PRIMERA semana completa del rango (primer anchor de semana dentro del rango) y la
// semana ANTERIOR (para WoW). Nunca lanza: si algo falla, ok=false y el MTD sigue.
function _readWeeklyUsers(startStr, endStr){
  var out = { ok:false, metrics:{}, config:{}, countries:[] };
  try {
    var sh = _openWeeklyUsersSheet(SpreadsheetApp.openById(SPREADSHEET_ID));
    if(!sh) {
      Logger.log('[_readWeeklyUsers] No se encontró ninguna pestaña de usuarios semanales en SPREADSHEET_ID.');
      return out;
    }
    var data = sh.getDataRange().getValues();
    if(data.length < 2) return out;
    var H = data[0].map(function(h){ return String(h || '').trim().toLowerCase(); });

    var findCol = function(candidates) {
      for (var c = 0; c < candidates.length; c++) {
        var idx = H.indexOf(candidates[c].toLowerCase());
        if (idx >= 0) return idx;
      }
      return -1;
    };

    var iW  = findCol(['week', 'semana', 'date', 'fecha']);
    var iWN = findCol(['week_number', 'week number', 'week_num', 'semana_numero']);
    var iC  = findCol(['country_name', 'country', 'pais', 'country_code']);
    var iPe = findCol(['users_peya_weekly', 'users_peya', 'peya_users_weekly']);
    var iDm = findCol(['users_dmart_weekly', 'dmart_maus', 'users_dmart', 'dmart_users_weekly']);
    var iDp = findCol(['users_dmart_plus_weekly', 'users_dmart_plus', 'plus_users_weekly']);
    var iNu = findCol(['dmart_new_users', 'new_users_dmart', 'new_users']);

    if(iW<0 || iC<0 || iPe<0 || iDm<0 || iNu<0) {
      Logger.log('[_readWeeklyUsers] Columnas faltantes en ' + sh.getName() + ': iW=' + iW + ', iC=' + iC + ', iPe=' + iPe + ', iDm=' + iDm + ', iNu=' + iNu);
      return out;
    }
    var tz = Session.getScriptTimeZone();
    var startMs = parseDateToMs(startStr), endMs = parseDateToMs(endStr);
    if(isNaN(startMs)||isNaN(endMs)) return out;

    var byWeek = {};   // anchorMs → { iso → {peya,dmart,plus,nu} }
    var weekNum = {};  // anchorMs → Week_Number (para el subtítulo "Semana N")
    for(var i=1;i<data.length;i++){
      var wMs = parseDateToMs(data[i][iW]); if(isNaN(wMs)) continue;
      var iso = _weeklyUserISO(data[i][iC]); if(!iso||iso==='LATAM') continue;
      if(!byWeek[wMs]) byWeek[wMs] = {};
      if(iWN>=0 && weekNum[wMs]==null){ var _wn=parseInt(data[i][iWN],10); if(!isNaN(_wn)) weekNum[wMs]=_wn; }
      byWeek[wMs][iso] = {
        peya: parseFloat(data[i][iPe])||0,
        dmart: parseFloat(data[i][iDm])||0,
        plus: (iDp>=0 ? parseFloat(data[i][iDp])||0 : 0),
        nu: parseFloat(data[i][iNu])||0
      };
    }
    var weeks = Object.keys(byWeek).map(function(k){ return parseInt(k,10); }).sort(function(a,b){ return a-b; });
    if(!weeks.length) return out;

    // PRIMERA semana completa del rango: primer anchor de semana >= start y <= end.
    var sel = null;
    for(var j=0;j<weeks.length;j++){ if(weeks[j]>=startMs && weeks[j]<=endMs){ sel=weeks[j]; break; } }
    // Si ninguna cae dentro (rango corto), la última <= end (la más cercana hacia atrás).
    if(sel==null){ for(var k2=weeks.length-1;k2>=0;k2--){ if(weeks[k2]<=endMs){ sel=weeks[k2]; break; } } }
    if(sel==null) sel = weeks[0];
    // Semana anterior (WoW): la mayor estrictamente < sel.
    var prev = null;
    for(var p=weeks.length-1;p>=0;p--){ if(weeks[p]<sel){ prev=weeks[p]; break; } }

    // Mes anterior (MoM): ~4 semanas atrás
    var m1 = null;
    var targetM1 = sel - 4 * 7 * 24 * 3600 * 1000;
    var m1Diff = Infinity;
    for(var j=0; j<weeks.length; j++) {
      var d = Math.abs(weeks[j] - targetM1);
      if (d < m1Diff) { m1Diff = d; m1 = weeks[j]; }
    }
    if (m1Diff > 10 * 24 * 3600 * 1000) m1 = null;

    // Año anterior (YoY): ~52 semanas atrás
    var y1 = null;
    var targetY1 = sel - 52 * 7 * 24 * 3600 * 1000;
    var y1Diff = Infinity;
    for(var j=0; j<weeks.length; j++) {
      var d = Math.abs(weeks[j] - targetY1);
      if (d < y1Diff) { y1Diff = d; y1 = weeks[j]; }
    }
    if (y1Diff > 10 * 24 * 3600 * 1000) y1 = null;

    var curD = byWeek[sel] || {}, prevD = (prev!=null ? byWeek[prev] : {}) || {};
    var m1D  = (m1!=null ? byWeek[m1] : {}) || {}, y1D = (y1!=null ? byWeek[y1] : {}) || {};
    var weekLbl    = Utilities.formatDate(new Date(sel), tz, 'dd/MM');
    var weekEndLbl = Utilities.formatDate(new Date(sel + 6*24*3600*1000), tz, 'dd/MM');  // semana = anchor + 6 días
    var prevLbl    = (prev!=null) ? Utilities.formatDate(new Date(prev), tz, 'dd/MM') : null;
    var wkNum      = (weekNum[sel]!=null) ? weekNum[sel] : null;

    var DEFS = [
      { name:'Dmart MAUs',                 fmt:'num',     f:function(e){ return e.dmart; } },
      { name:'Dmart MAUs - Plus',          fmt:'num',     f:function(e){ return e.plus; } },
      { name:'Dmart MAUs - Plus % (Weekly)', fmt:'pct_pre', f:function(e){ return (typeof e.plus === 'number' && e.dmart > 0) ? (e.plus/e.dmart*100) : null; } },
      { name:'New Users - Dmart',          fmt:'num',     f:function(e){ return e.nu; } },
      { name:'Covered MAUs penetration %', fmt:'pct_pre', f:function(e){ return (typeof e.dmart === 'number' && e.peya > 0) ? (e.dmart/e.peya*100) : null; } }
    ];
    var isos = Object.keys(curD);
    DEFS.forEach(function(D){
      out.metrics[D.name] = {};
      out.config[D.name]  = { formato:D.fmt, tipo_color:1, weekly:true, week:weekLbl, weekEnd:weekEndLbl, weekNum:wkNum, prevWeek:prevLbl };
      var sD_c=0,sP_c=0,sN_c=0,sDp_c=0, sD_p=0,sP_p=0,sN_p=0,sDp_p=0;
      var sD_m=0,sP_m=0,sN_m=0,sDp_m=0, sD_y=0,sP_y=0,sN_y=0,sDp_y=0;
      isos.forEach(function(iso){
        var e=curD[iso], pe=prevD[iso], me=m1D[iso], ye=y1D[iso];
        var cm1 = (me && (me.dmart || me.nu || me.plus)) ? D.f(me) : null;
        var cy1 = (ye && (ye.dmart || ye.nu || ye.plus)) ? D.f(ye) : null;
        out.metrics[D.name][iso] = { current:D.f(e), prev:(pe?D.f(pe):null), m1:cm1, y1:cy1, target:0 };
        sD_c+=e.dmart; sP_c+=e.peya; sN_c+=e.nu; sDp_c+=e.plus;
        if(pe){
          sD_p  += pe.dmart || 0;
          sP_p  += pe.peya  || 0;
          sN_p  += pe.nu    || 0;
          sDp_p += pe.plus  || 0;
        }
        if(me){ sD_m+=me.dmart || 0; sP_m+=me.peya || 0; sN_m+=me.nu || 0; sDp_m+=me.plus || 0; }
        if(ye){ sD_y+=ye.dmart || 0; sP_y+=ye.peya || 0; sN_y+=ye.nu || 0; sDp_y+=ye.plus || 0; }
      });
      // LATAM: conteos = suma de países; penetración / mix = ponderado.
      var latC = null, latP = null, latM = null, latY = null;
      if (D.name === 'Dmart MAUs') {
        latC = sD_c; latP = (prev != null) ? sD_p : null;
        latM = (m1 != null) ? sD_m : null; latY = (y1 != null) ? sD_y : null;
      } else if (D.name === 'Dmart MAUs - Plus') {
        latC = sDp_c; latP = (prev != null) ? sDp_p : null;
        latM = (m1 != null) ? sDp_m : null; latY = (y1 != null) ? sDp_y : null;
      } else if (D.name === 'New Users - Dmart') {
        latC = sN_c; latP = (prev != null) ? sN_p : null;
        latM = (m1 != null) ? sN_m : null; latY = (y1 != null) ? sN_y : null;
      } else if (D.name === 'Covered MAUs penetration %') {
        latC = (sP_c > 0) ? (sD_c / sP_c * 100) : null;
        latP = (prev != null && sP_p > 0) ? (sD_p / sP_p * 100) : null;
        latM = (m1 != null && sP_m > 0) ? (sD_m / sP_m * 100) : null;
        latY = (y1 != null && sP_y > 0) ? (sD_y / sP_y * 100) : null;
      } else if (D.name === 'Dmart MAUs - Plus % (Weekly)') {
        latC = (sD_c > 0) ? (sDp_c / sD_c * 100) : null;
        latP = (prev != null && sD_p > 0) ? (sDp_p / sD_p * 100) : null;
        latM = (m1 != null && sD_m > 0) ? (sDp_m / sD_m * 100) : null;
        latY = (y1 != null && sD_y > 0) ? (sDp_y / sD_y * 100) : null;
      }
      out.metrics[D.name]['LATAM'] = { current:latC, prev:latP, m1:latM, y1:latY, target:0 };
    });
    out.countries = isos;
    out.ok = true;
    return out;
  } catch(e){ Logger.log('_readWeeklyUsers: ' + (e && e.message)); return out; }
}

// ── DEBUG: correr DESDE EL EDITOR (no necesita redeploy ni toca la caché) ─────
// Elegí "debugWeekly" en el desplegable de funciones (arriba) → Ejecutar (▶) →
// mirá el resultado en Ver → Registros de ejecución (o en el valor devuelto).
// Chequea paso a paso por qué las 3 métricas semanales aparecen (o no) en el MTD.
// Si algo falla, cada línea con "[FAIL]" o "→ FIX" te dice exactamente qué corregir.
function debugWeekly(){
  var L = [];
  var log = function(m){ Logger.log(m); L.push(m); };
  try {
    log('══════════ DEBUG WEEKLY ══════════');

    // 1) Planilla + pestaña
    var ss = SpreadsheetApp.openById(SPREADSHEET_ID);
    log('Planilla: "' + ss.getName() + '"');
    log('SPREADSHEET_ID: ' + SPREADSHEET_ID);
    var sh = _openWeeklyUsersSheet(ss);
    log('Pestaña de usuarios semanales ("' + WEEKLY_USERS_SHEET + '" o similar): ' + (sh ? '[OK] encontrada → "' + sh.getName() + '"' : '[FAIL] NO existe'));
    if(!sh){
      log('Pestañas disponibles: ' + JSON.stringify(ss.getSheets().map(function(s){return s.getName();})));
      log('→ FIX: poné en la constante WEEKLY_USERS_SHEET el nombre EXACTO de una de esas.');
      return L.join('\n');
    }

    // 2) Encabezados + columnas requeridas
    var data = sh.getDataRange().getValues();
    var tz = Session.getScriptTimeZone();
    log('Filas (incluye encabezado): ' + data.length);
    var H = data[0].map(function(h){ return String(h).trim(); });
    log('Encabezados: ' + JSON.stringify(H));
    log('── Columnas requeridas ──');
    var faltan = [];
    ['Week','Week_Number','country_name','Users_Peya_Weekly','Users_dmart_weekly','Dmart_New_Users'].forEach(function(col){
      var idx = H.indexOf(col);
      log('  "' + col + '": ' + (idx>=0 ? ('[OK] col ' + idx) : '[FAIL] NO está') + (col==='Week_Number' && idx<0 ? ' (opcional)' : ''));
      if(idx<0 && col!=='Week_Number') faltan.push(col);
    });
    if(faltan.length) log('→ FIX: faltan columnas obligatorias (revisá mayúsculas/espacios/guiones): ' + JSON.stringify(faltan));

    // 3) Fecha (primera fila de datos)
    var iW = H.indexOf('Week'), iC = H.indexOf('country_name');
    if(data.length>1 && iW>=0)
      log('── Fecha ── Week fila 2 = ' + JSON.stringify(data[1][iW]) + '  → parseDateToMs = ' + parseDateToMs(data[1][iW]) + '   (NaN = no parsea → se descarta la fila)');

    // 4) Mapeo de países (nombre en inglés → ISO)
    if(iC>=0){
      log('── Mapeo de países ──');
      var mapOk = {}, mapNo = {};
      for(var r=1;r<data.length;r++){
        var raw = data[r][iC]; if(raw===''||raw==null) continue;
        var code = _weeklyUserISO(raw);
        if(code) mapOk[String(raw)] = code; else mapNo[String(raw)] = true;
      }
      log('  OK: ' + JSON.stringify(mapOk));
      var noArr = Object.keys(mapNo);
      log('  SIN mapear: ' + (noArr.length ? JSON.stringify(noArr) + '  ← estos países se pierden (agregar al mapeo)' : 'ninguno [OK]'));
    }

    // 5) Semanas detectadas
    var anchors = {};
    if(iW>=0) for(var r2=1;r2<data.length;r2++){ var ms=parseDateToMs(data[r2][iW]); if(!isNaN(ms)) anchors[ms]=true; }
    var wkList = Object.keys(anchors).map(function(k){return parseInt(k,10);}).sort(function(a,b){return a-b;});
    log('── Semanas detectadas: ' + wkList.length + ' ──');
    log('  ' + wkList.map(function(ms){return Utilities.formatDate(new Date(ms),tz,'dd/MM/yyyy');}).join(' · '));

    // 6) Probar _readWeeklyUsers + el payload real del MTD para un rango
    var probar = function(ini, fin, etiqueta){
      log('── PRUEBA [' + etiqueta + ']: ' + ini + ' → ' + fin + ' ──');
      var wk = _readWeeklyUsers(ini, fin);
      log('  _readWeeklyUsers.ok = ' + wk.ok + (wk.ok ? '' : '  [FAIL] (no arma métricas para este rango)'));
      log('  métricas = ' + JSON.stringify(Object.keys(wk.metrics)) + '  ·  países = ' + (wk.countries||[]).length);
      if(wk.config['Dmart MAUs']) log('  subtítulo (semana/fechas) = ' + JSON.stringify(wk.config['Dmart MAUs']));
      ['Dmart MAUs','New Users - Dmart','Covered MAUs penetration %'].forEach(function(m){
        var lat = wk.metrics[m] && wk.metrics[m]['LATAM'];
        if(lat) log('  ' + m + ' → LATAM = ' + JSON.stringify(lat));
      });
      try { CacheService.getScriptCache().remove('cache_mtd_actuals_' + ini + '_' + fin); } catch(e){}
      var pay = fetchMtdActuals(ini, fin).payload;
      var keys = (pay && pay.metrics) ? Object.keys(pay.metrics) : [];
      log('  ¿llegan al payload del MTD? (las 3 tienen que dar SÍ):');
      ['Dmart MAUs','New Users - Dmart','Covered MAUs penetration %'].forEach(function(m){
        log('    · "' + m + '": ' + (keys.indexOf(m)>=0 ? 'SÍ [OK]' : 'NO [FAIL]'));
      });
    };

    var hoy = new Date();
    probar(
      Utilities.formatDate(new Date(hoy.getFullYear(), hoy.getMonth(), 1), tz, 'yyyy-MM-dd'),
      Utilities.formatDate(hoy, tz, 'yyyy-MM-dd'),
      'mes en curso'
    );
    if(wkList.length){
      var last = wkList[wkList.length-1];
      probar(
        Utilities.formatDate(new Date(last), tz, 'yyyy-MM-dd'),
        Utilities.formatDate(new Date(last + 6*24*3600*1000), tz, 'yyyy-MM-dd'),
        'última semana con datos'
      );
    }

    log('══════════ FIN DEBUG ══════════');
  } catch(err){
    log('[FAIL][FAIL] EXCEPCIÓN: ' + (err && err.message));
    if(err && err.stack) log(String(err.stack));
  }
  return L.join('\n');
}

// Corre una fecha `d` hacia atrás `months` meses para las comparativas MoM (1) y
// YoY (12). Corrige el viejo setMonth()/setFullYear(), que preservaba el número de
// día y se rompía a fin de mes:
//   1) Si `d` es el ÚLTIMO día de su mes, devuelve el último día del mes destino.
//      Así "mes completo vs mes completo": jun 1-30 → may 1-31 (no may 1-30).
//   2) Clampea el día al largo del mes destino, para no desbordar al mes siguiente
//      (mar 31 → feb: 28/29, no mar 3; may 31 → abr 30, no may 1).
// `endOfDay` fija 23:59:59 (fin de rango) vs 00:00:00 (inicio de rango).
function _shiftMonthsBack(d, months, endOfDay) {
  var y=d.getFullYear(), mo=d.getMonth(), day=d.getDate();
  var lastDayCur=new Date(y, mo+1, 0).getDate();          // último día del mes de `d`
  var tgtY=y, tgtMo=mo-months;
  while(tgtMo<0){ tgtMo+=12; tgtY-=1; }
  var lastDayTgt=new Date(tgtY, tgtMo+1, 0).getDate();     // último día del mes destino
  var tgtDay=(day>=lastDayCur) ? lastDayTgt : Math.min(day, lastDayTgt);
  return endOfDay ? new Date(tgtY,tgtMo,tgtDay,23,59,59) : new Date(tgtY,tgtMo,tgtDay,0,0,0);
}

// ── fetchMtdActuals (ex fetchDataFast de MTD_Code.gs) ──────────────
function fetchMtdActuals(startDate, endDate) {
  var cacheKey = "cache_mtd_actuals_v2_" + startDate + "_" + endDate;
  var cache    = CacheService.getScriptCache();
  var cached   = cache.get(cacheKey);
  if (cached) return { payload: JSON.parse(cached) };

  try {
    var ss    = SpreadsheetApp.openById(SPREADSHEET_ID);
    var sheet = ss.getSheetByName(SHEET_ACTUALS);
    var data  = sheet.getDataRange().getValues();
    var headers = data[0];
    var idxMetric=headers.indexOf('Metric'), idxCountry=headers.indexOf('Country'),
        idxDate=headers.indexOf('Date'),     idxValue=headers.indexOf('Value');
    if (idxMetric===-1||idxCountry===-1||idxDate===-1||idxValue===-1)
      throw new Error("Columnas maestras no encontradas.");

    var maxDateMsDemanda=-Infinity, maxDateMsGlobal=-Infinity;
    var maxByMetricMs={}; // última fecha CON DATO real por métrica con target (Orders/GMV)
    var compMaxMs={};     // última fecha CON DATO real por componente crudo (para "datos hasta X")
    for (var i=1;i<data.length;i++){
      var t=parseDateToMs(data[i][idxDate]); if(isNaN(t))continue;
      if(t>maxDateMsGlobal)maxDateMsGlobal=t;
      var mName=data[i][idxMetric];
      var vRaw=data[i][idxValue];
      if(vRaw!==''&&vRaw!=null&&!isNaN(parseFloat(vRaw))){ if(compMaxMs[mName]===undefined||t>compMaxMs[mName])compMaxMs[mName]=t; }
      if(METRICAS_DEMANDA.indexOf(mName)!==-1&&t>maxDateMsDemanda)maxDateMsDemanda=t;
      // Para GMV/Orders: registrar el último día con valor > 0 (GMV suele llegar
      // más tarde, así su target no se acumula más allá de donde hay datos).
      if(METRIC_TARGET_MAP[mName]){
        var vEarly=parseFloat(data[i][idxValue]);
        if(!isNaN(vEarly)&&vEarly>0&&(maxByMetricMs[mName]===undefined||t>maxByMetricMs[mName]))maxByMetricMs[mName]=t;
      }
    }
    var maxDateMs=(maxDateMsDemanda!==-Infinity)?maxDateMsDemanda:maxDateMsGlobal;
    var baseDate=(maxDateMs!==-Infinity)?new Date(maxDateMs):new Date();
    // baseDate = último día con actuals de demanda (Orders/GMV), igual que el gráfico.
    // (Antes se capaba a BP1/LAST_VALID_DATE, lo que escondía el último día disponible
    //  cuando el sheet diario iba un día atrás del de actuals MTD.)
    // El target sigue sin sobre-contarse: se topa por métrica con maxDateByMetric
    // (última fecha con actual > 0 de cada métrica).
    var tz=Session.getScriptTimeZone();
    var defaultEnd=Utilities.formatDate(baseDate,tz,"yyyy-MM-dd");
    var defaultStart=Utilities.formatDate(new Date(baseDate.getFullYear(),baseDate.getMonth(),1),tz,"yyyy-MM-dd");
    var startStr=startDate||defaultStart, endStr=endDate||defaultEnd;
    var sp=startStr.split('-'), ep=endStr.split('-');
    var start=new Date(parseInt(sp[0]),parseInt(sp[1])-1,parseInt(sp[2]),0,0,0);
    var end  =new Date(parseInt(ep[0]),parseInt(ep[1])-1,parseInt(ep[2]),23,59,59);
    // MoM/YoY con corrección de FIN DE MES (ver _shiftMonthsBack):
    //  · mes completo → mes completo (jun 1-30 → may 1-31, NO may 1-30)
    //  · sin desborde cuando el mes destino es más corto (mar 31 → feb 28, no mar 3)
    // Antes: setMonth(-1)/setFullYear(-1) preservaban el día y se rompían a fin de mes.
    var startM1=_shiftMonthsBack(start, 1,false);
    var endM1  =_shiftMonthsBack(end,   1,true);
    var startY1=_shiftMonthsBack(start,12,false);
    var endY1  =_shiftMonthsBack(end,  12,true);
    var startTime=start.getTime(),endTime=end.getTime(),startM1T=startM1.getTime(),endM1T=endM1.getTime();
    var startY1T=startY1.getTime(),endY1T=endY1.getTime();
    var minTime=Math.min(startTime,startM1T,startY1T), maxTime=Math.max(endTime,endM1T,endY1T);
    var dailyMap={}, countriesSet={}, validDatesSet={};
    for (var i=1;i<data.length;i++){
      var rMetric=data[i][idxMetric]; if(!rMetric)continue;
      if(COMPONENTES_CRUDOS.indexOf(rMetric)===-1)continue;
      var rRaw=String(data[i][idxCountry]||'').trim();
      var rTime=parseDateToMs(data[i][idxDate]);
      // Normaliza a ISO igual que fetchTargetsOnly para que los keys coincidan en injectTargets
      var rCountry=COUNTRY_NAME_TO_CODE[rRaw]||COUNTRY_ISO[rRaw.toLowerCase()]||rRaw;
      if(!rCountry||isNaN(rTime))continue;
      validDatesSet[rTime]=true;
      if(rTime<minTime||rTime>maxTime)continue;
      countriesSet[rCountry]=true;
      if(!dailyMap[rCountry])dailyMap[rCountry]={};
      if(!dailyMap[rCountry][rTime])dailyMap[rCountry][rTime]={};
      dailyMap[rCountry][rTime][rMetric]=parseFloat(data[i][idxValue])||0;
    }
    var rawData={}, countries=Object.keys(countriesSet);
    for (var c in dailyMap){
      if(!rawData[c])rawData[c]={};
      for (var tStr in dailyMap[c]){
        var t2=parseInt(tStr,10);
        var isCur=(t2>=startTime&&t2<=endTime),isM1t=(t2>=startM1T&&t2<=endM1T),isY1t=(t2>=startY1T&&t2<=endY1T);
        if(!isCur&&!isM1t&&!isY1t)continue;
        var bucket=isCur?'current':(isM1t?'m1':'y1'), dayData=dailyMap[c][tStr];
        for (var m in dayData){
          if(!rawData[c][m])rawData[c][m]={current:0,m1:0,y1:0};
          rawData[c][m][bucket]+=dayData[m];
        }
      }
    }
    rawData['LATAM']={};
    COMPONENTES_CRUDOS.forEach(function(comp){
      var sc=0,sm1=0,sy1=0;
      countries.forEach(function(c){if(rawData[c]&&rawData[c][comp]){sc+=rawData[c][comp].current;sm1+=rawData[c][comp].m1;sy1+=rawData[c][comp].y1;}});
      rawData['LATAM'][comp]={current:sc,m1:sm1,y1:sy1};
    });
    var metricsData={};
    METRICAS_FINALES.forEach(function(m){metricsData[m]={};});
    var todos=countries.concat(['LATAM']);
    todos.forEach(function(c){
      var cc={},cm1={},cy1={};
      COMPONENTES_CRUDOS.forEach(function(comp){
        cc[comp]=(rawData[c]&&rawData[c][comp])?rawData[c][comp].current:0;
        cm1[comp]=(rawData[c]&&rawData[c][comp])?rawData[c][comp].m1:0;
        cy1[comp]=(rawData[c]&&rawData[c][comp])?rawData[c][comp].y1:0;
      });
      var fc=computeFinalMetrics(cc),fm1=computeFinalMetrics(cm1),fy1=computeFinalMetrics(cy1);
      METRICAS_FINALES.forEach(function(m){
        // y1: null significa sin datos (≠ 0 que es un valor real).
        // null hace que badge() muestre "—" en vez de confundir con 0%.
        var y1val = fy1[m];
        metricsData[m][c]={current:fc[m]||0,m1:fm1[m]||0,y1:(y1val!=null&&y1val!==0?y1val:null),target:0};
      });
    });
    var uiConfig={};
    CONFIG_METRICAS.forEach(function(item){uiConfig[item.metrica]={formato:item.formato,tipo_color:item.tipo_color};});
    var validDatesArray=Object.keys(validDatesSet).map(function(t){return Utilities.formatDate(new Date(parseInt(t,10)),tz,"yyyy-MM-dd");});
    // maxDemandDate = último día con datos de métricas de demanda (Orders/GMV).
    // Siempre es baseDate (ya está capado por BP1). Lo pasamos al front para
    // que fetchPhase2 no pida target más allá de donde hay actuals reales.
    // RR DESACOPLADO: el front lo pide aparte con fetchRRData() (antes esto
    // re-leía actuals + targets y hacía lenta/colgaba la carga del MTD).
    var rrData={orders:{},gmv:{}};
    // Última fecha con dato por métrica (Orders/GMV), capada por baseDate (BP1).
    // El front la usa para acumular el target de cada métrica solo hasta ahí.
    var maxDateByMetric={};
    Object.keys(maxByMetricMs).forEach(function(m){
      var ms=Math.min(maxByMetricMs[m], baseDate.getTime());
      maxDateByMetric[m]=Utilities.formatDate(new Date(ms),tz,'yyyy-MM-dd');
    });
    // "Datos hasta" por MÉTRICA FINAL: última fecha con dato de su componente
    // representativo (para mostrar arriba de cada métrica hasta cuándo hay datos).
    var dataThroughByMetric={};
    METRICAS_FINALES.forEach(function(fm){
      var rep=METRIC_REP_COMPONENT[fm];
      var ms=(rep && compMaxMs[rep]!==undefined)?compMaxMs[rep]:null;
      dataThroughByMetric[fm]=(ms!=null)?Utilities.formatDate(new Date(ms),tz,'yyyy-MM-dd'):null;
    });
    // ── Usuarios SEMANALES (pestaña "Weekly data"): valor FIJO de la primera semana
    // completa del rango (no se suman por día). Se inyectan como métricas más, con
    // config.weekly=true para que el front las renderice distinto (WoW, sin BE/LM/LY).
    try {
      var _wk = _readWeeklyUsers(startStr, endStr);
      if (_wk && _wk.ok) {
        Object.keys(_wk.metrics).forEach(function(k){
          metricsData[k] = _wk.metrics[k];
          uiConfig[k] = Object.assign(uiConfig[k] || {}, _wk.config[k]);
        });
        _wk.countries.forEach(function(c){ if(countries.indexOf(c)===-1) countries.push(c); });
      }
    } catch(_eWk){ Logger.log('weekly users inject: ' + _eWk.message); }

    // ── Métricas MTD "snapshot" (SOLO la página, no el mail): PeYa/Dmart/Dmart
    // Plus/New Users - MTD. Son acumulados month-to-date → NO se suman por día: se
    // muestra el valor de la ÚLTIMA fecha con dato ≤ fin del rango (la "fecha final").
    // LATAM = suma de países. Si un país no tiene dato en el rango, no aparece.
    try {
      var MTD_SNAP = MTD_SNAPSHOT_METRICS;   // 4 crudos leídos de la hoja: PeYa/Dmart/Dmart Plus/New Users - MTD
      // Comparativo = MTD del MISMO tramo del MES PASADO (ej: 1-19 jul vs 1-19 jun).
      // prevCut = mismo día del mes anterior, con corrección de fin de mes de
      // _shiftMonthsBack (mes completo → mes completo). prevV = último valor ≤ prevCut.
      var _prevCut = _shiftMonthsBack(end, 1, true);
      var prevMonthEndTime = _prevCut.getTime();
      var _prevMtdLabel = Utilities.formatDate(_prevCut, tz, 'dd/MM');

      var snap = {}; MTD_SNAP.forEach(function(m){ snap[m] = {}; });
      for (var si = 1; si < data.length; si++) {
        var sm = data[si][idxMetric];
        if (MTD_SNAP.indexOf(sm) === -1) continue;
        var st = parseDateToMs(data[si][idxDate]);
        if (isNaN(st) || st > endTime) continue;                 // solo hasta el fin del rango
        var sRaw = String(data[si][idxCountry] || '').trim();
        var sCc = COUNTRY_NAME_TO_CODE[sRaw] || COUNTRY_ISO[sRaw.toLowerCase()] || sRaw;
        if (!sCc || sCc === 'LATAM') continue;                   // LATAM se calcula como suma de países
        var sv = parseFloat(data[si][idxValue]); if (isNaN(sv)) continue;
        if (!snap[sm][sCc]) snap[sm][sCc] = { curMs:-Infinity, curV:null, prevMs:-Infinity, prevV:null };
        var slot = snap[sm][sCc];
        if (st > slot.curMs) { slot.curMs = st; slot.curV = sv; }                              // último ≤ fin del rango
        if (st <= prevMonthEndTime && st > slot.prevMs) { slot.prevMs = st; slot.prevV = sv; } // último ≤ mismo día mes pasado
      }

      // Países presentes en cualquiera de los snapshots
      var _snapCc = {}; MTD_SNAP.forEach(function(m){ Object.keys(snap[m]).forEach(function(cc){ _snapCc[cc]=true; }); });
      var snapCcList = Object.keys(_snapCc);
      function _rawV(metric, cc, which){ var s=snap[metric] && snap[metric][cc]; return s ? s[which] : null; }
      function _sumRaw(metric, which){ var t=0,has=false; snapCcList.forEach(function(cc){ var v=_rawV(metric,cc,which); if(v!=null){t+=v;has=true;} }); return has?t:null; }

      // Métricas VISIBLES derivadas de los snapshots:
      //   abs   = valor crudo del snapshot (num)
      //   ratio = num/den como % (valor 0-1) → penetración / mix. LATAM de un ratio
      //           = Σnum / Σden (NO promedio de %). Comparativo = mismo ratio al mes
      //           pasado (num.prev/den.prev).
      var SNAP_OUT = [
        { name:'PeYa MAUs - MTD',          kind:'abs',   src:'PeYa MAUs - MTD',          fmt:'num', color:1 },
        { name:'Dmart MAUs - MTD',         kind:'abs',   src:'Dmart MAUs - MTD',         fmt:'num', color:1 },
        { name:'Dmart MAUs penetration %', kind:'ratio', num:'Dmart MAUs - MTD',         den:'PeYa MAUs - MTD',  fmt:'pct', color:1 },
        { name:'Dmart MAUs - Plus %',      kind:'ratio', num:'Dmart MAUs - Plus - MTD',  den:'Dmart MAUs - MTD', fmt:'pct', color:1 },
        { name:'New Users - Dmart - MTD',  kind:'abs',   src:'New Users - Dmart - MTD',  fmt:'num', color:1 }
      ];
      SNAP_OUT.forEach(function(def){
        var md = {}, any = false;
        if (def.kind === 'abs') {
          snapCcList.forEach(function(cc){
            var cv=_rawV(def.src,cc,'curV'), pv=_rawV(def.src,cc,'prevV');
            if (cv==null && pv==null) return;
            md[cc] = { current:cv, prev:(pv!=null?pv:null), m1:0, y1:null, target:0 }; any=true;
          });
          var lc=_sumRaw(def.src,'curV'), lp=_sumRaw(def.src,'prevV');
          if (lc!=null) md['LATAM'] = { current:lc, prev:(lp!=null?lp:null), m1:0, y1:null, target:0 };
        } else { // ratio: num/den por país; LATAM = Σnum/Σden
          snapCcList.forEach(function(cc){
            var nC=_rawV(def.num,cc,'curV'), dC=_rawV(def.den,cc,'curV');
            var nP=_rawV(def.num,cc,'prevV'), dP=_rawV(def.den,cc,'prevV');
            var cv=(nC!=null && dC)? nC/dC : null;
            var pv=(nP!=null && dP)? nP/dP : null;
            if (cv==null && pv==null) return;
            md[cc] = { current:cv, prev:pv, m1:0, y1:null, target:0 }; any=true;
          });
          var nLc=_sumRaw(def.num,'curV'), dLc=_sumRaw(def.den,'curV');
          var nLp=_sumRaw(def.num,'prevV'), dLp=_sumRaw(def.den,'prevV');
          var lcr=(nLc!=null && dLc)? nLc/dLc : null;
          var lpr=(nLp!=null && dLp)? nLp/dLp : null;
          if (lcr!=null) md['LATAM'] = { current:lcr, prev:lpr, m1:0, y1:null, target:0 };
        }
        if (!any) return;
        metricsData[def.name] = md;
        uiConfig[def.name] = { formato:def.fmt, tipo_color:def.color, mtd:true, prevLabel:_prevMtdLabel };
        // "datos hasta": última fecha con dato del snapshot (el numerador en los ratios).
        var _dtSrc = (def.kind==='abs') ? def.src : def.num, _dtMs = -Infinity;
        snapCcList.forEach(function(cc){ var s=snap[_dtSrc] && snap[_dtSrc][cc]; if(s && s.curMs > _dtMs) _dtMs = s.curMs; });
        if (_dtMs !== -Infinity) dataThroughByMetric[def.name] = Utilities.formatDate(new Date(_dtMs), tz, 'yyyy-MM-dd');
      });
      snapCcList.forEach(function(cc){ if(countries.indexOf(cc)===-1) countries.push(cc); });
    } catch(_eMtd){ Logger.log('mtd snapshot inject: ' + _eMtd.message); }

    var resultData={metrics:metricsData,countries:countries,currentStart:startStr,currentEnd:endStr,maxDemandDate:defaultEnd,maxDateByMetric:maxDateByMetric,dataThroughByMetric:dataThroughByMetric,config:uiConfig,validDates:validDatesArray,rrData:rrData};
    cache.put(cacheKey, JSON.stringify(resultData), 1500);
    return { payload: resultData };
  } catch(err) {
    return { payload: { error: err.message || String(err) } };
  }
}

// ── DEBUG: por qué NO aparecen las métricas nuevas (MTD snapshot + Assignment Time > 6 min %) ──
// Correr desde el editor (▶ debugMetricasNuevas) y abrir el Registro de ejecución.
// Chequea, en "A. TI - Actuals OKRs", si existen EXACTO los nombres que buscan las
// fórmulas, y lista los nombres REALES parecidos para detectar typos/espacios/casing.
function debugMetricasNuevas() {
  var out = []; function L(s){ out.push(s); Logger.log(s); }
  var ss = SpreadsheetApp.openById(SPREADSHEET_ID);
  var sheet = ss.getSheetByName(SHEET_ACTUALS);
  if (!sheet) { L('[FAIL] No encontré la hoja "' + SHEET_ACTUALS + '" en ' + SPREADSHEET_ID); return out.join('\n'); }
  var data = sheet.getDataRange().getValues(), H = data[0];
  var iM = H.indexOf('Metric'), iC = H.indexOf('Country'), iD = H.indexOf('Date'), iV = H.indexOf('Value');
  L('Hoja: "' + sheet.getName() + '"  (Metric=col ' + iM + ', Country=' + iC + ', Date=' + iD + ', Value=' + iV + ')');
  if (iM < 0) { L('[FAIL] No hay columna "Metric".'); return out.join('\n'); }

  var info = {};   // nombre -> {n, lastMs, sampleV, sampleC}
  for (var i = 1; i < data.length; i++) {
    var nm = String(data[i][iM] || ''); if (!nm) continue;
    if (!info[nm]) info[nm] = { n:0, lastMs:-Infinity, sampleV:null, sampleC:null };
    info[nm].n++;
    var t = parseDateToMs(data[i][iD]);
    if (!isNaN(t) && t > info[nm].lastMs) { info[nm].lastMs = t; info[nm].sampleV = data[i][iV]; info[nm].sampleC = data[i][iC]; }
  }
  var tz = Session.getScriptTimeZone();
  function ymd(ms){ return (ms && ms !== -Infinity) ? Utilities.formatDate(new Date(ms), tz, 'yyyy-MM-dd') : '(sin fecha)'; }

  L('');
  L('=== ¿Existen EXACTO los nombres que buscan las fórmulas? ===');
  MTD_SNAPSHOT_METRICS.concat(['Assignment Time > 6 min orders', 'Total_orders_timings']).forEach(function(nm){
    var it = info[nm];
    if (it) L('[OK] "' + nm + '"  → ' + it.n + ' filas · última ' + ymd(it.lastMs) + ' · ej. ' + it.sampleC + '=' + it.sampleV);
    else    L('[FAIL] "' + nm + '"  → NO existe con ese nombre exacto');
  });

  L('');
  L('=== Nombres REALES parecidos en la hoja (por si hay typo/espacio/casing) ===');
  var re = /(maus|assignment|timing|mtd|plus|new users)/i;
  Object.keys(info).sort().forEach(function(nm){ if (re.test(nm)) L('   • "' + nm + '"  (' + info[nm].n + ' filas)'); });

  L('');
  L('Si un [FAIL] está arriba pero abajo aparece con OTRO nombre → copiame ese nombre exacto y lo ajusto.');
  return out.join('\n');
}

// ── fetchTargetsOnly ────────────────────────────────────────────────
// capByMetric (opcional): { 'Confirmed Orders': 'yyyy-MM-dd', 'GMV User Dmarts': ... }
// Para cada métrica, el target se acumula solo hasta SU última fecha con datos
// (GMV suele llegar más tarde, así no se sobre-cuenta su target).
function fetchTargetsOnly(startStr, endStr, capByMetric) {
  // Nunca sumar targets para fechas futuras sin actuals reales.
  // El cliente ya pasa maxDemandDate como techo, pero por seguridad también
  // lo limitamos aquí: máximo = día de hoy (sin días futuros al servidor).
  var tz = Session.getScriptTimeZone();
  var todayYMD = Utilities.formatDate(new Date(), tz, 'yyyy-MM-dd');
  if (endStr > todayYMD) endStr = todayYMD;
  capByMetric = capByMetric || {};

  // La clave de caché incluye los topes por métrica (distinto cap → distinto total).
  var capSig = Object.keys(capByMetric).sort().map(function(k){return k+'='+capByMetric[k];}).join('|');
  var cacheKey="cache_mtd_targets_"+startStr+"_"+endStr+(capSig?('_'+capSig):'');
  var cache=CacheService.getScriptCache(), cached=cache.get(cacheKey);
  if(cached)return JSON.parse(cached);
  var result={};
  Object.keys(METRIC_TARGET_MAP).forEach(function(k){result[k]={};});
  try {
    var ss=SpreadsheetApp.openById(SPREADSHEET_TARGETS_ID_MTD);
    var sheet=ss.getSheets().find(function(s){ return /Export Targets-Diario/i.test(s.getName()); });
    if(!sheet) throw new Error("Hoja 'Export Targets-Diario' no encontrada en el spreadsheet de targets.");
    var data=sheet.getDataRange().getValues();
    var headers=data[0].map(function(h){ return String(h).trim().toLowerCase(); });
    var idxMetric=headers.indexOf('metric'),idxCountry=headers.indexOf('country'),idxDate=headers.indexOf('date'),idxValue=headers.indexOf('value');
    if(idxMetric===-1||idxCountry===-1||idxDate===-1||idxValue===-1)throw new Error("Columnas no encontradas en hoja de targets.");
    var reverseMap={};
    Object.keys(METRIC_TARGET_MAP).forEach(function(fk){
      var v=METRIC_TARGET_MAP[fk];
      if(Array.isArray(v)){v.forEach(function(s){reverseMap[s]=fk;});}else{reverseMap[v]=fk;}
    });

    // Acumulamos por (finalKey, sourceMetric, country) para luego elegir
    // solo la métrica de mayor prioridad por país y evitar doble conteo.
    var rawResult={};
    for(var i=1;i<data.length;i++){
      var rMR=String(data[i][idxMetric]||'').trim(); if(!rMR)continue;
      var finalKey=reverseMap[rMR]; if(!finalKey)continue;
      var rCR=String(data[i][idxCountry]||'').trim(), rCRlow=rCR.toLowerCase();
      var rCountry=COUNTRY_NAME_TO_CODE[rCR]||COUNTRY_NAME_TO_CODE[rCRlow]||COUNTRY_ISO[rCRlow]||rCR;
      var rDateYMD=normalizeDateToYMD(data[i][idxDate]), rValue=parseFloat(data[i][idxValue])||0;
      if(!rCountry||!rDateYMD)continue;
      // Tope por métrica: nunca pasar SU última fecha con datos (ni el end pedido).
      var capEnd = capByMetric[finalKey] ? (capByMetric[finalKey] < endStr ? capByMetric[finalKey] : endStr) : endStr;
      if(rDateYMD<startStr||rDateYMD>capEnd)continue;
      if(!rawResult[finalKey])rawResult[finalKey]={};
      if(!rawResult[finalKey][rMR])rawResult[finalKey][rMR]={};
      rawResult[finalKey][rMR][rCountry]=(rawResult[finalKey][rMR][rCountry]||0)+rValue;
    }

    // Para cada (finalKey, country) usa solo la métrica de mayor prioridad
    // (la que aparece primero en el array de METRIC_TARGET_MAP).
    Object.keys(METRIC_TARGET_MAP).forEach(function(finalKey){
      var priorityList=Array.isArray(METRIC_TARGET_MAP[finalKey])?METRIC_TARGET_MAP[finalKey]:[METRIC_TARGET_MAP[finalKey]];
      if(!rawResult[finalKey])return;
      var allCountries={};
      priorityList.forEach(function(src){
        if(rawResult[finalKey][src])Object.keys(rawResult[finalKey][src]).forEach(function(c){allCountries[c]=true;});
      });
      Object.keys(allCountries).forEach(function(country){
        for(var j=0;j<priorityList.length;j++){
          var src=priorityList[j];
          if(rawResult[finalKey][src]&&rawResult[finalKey][src][country]!==undefined){
            result[finalKey][country]=rawResult[finalKey][src][country];
            break;
          }
        }
      });
    });
    var coKey='Confirmed Orders', gmvKey='GMV User Dmarts';
    if(result[coKey]&&!result[coKey]['LATAM']){
      var latamCO=0;
      Object.keys(result[coKey]).forEach(function(c){if(c!=='LATAM'&&c!=='LATAM ex AR')latamCO+=result[coKey][c];});
      result[coKey]['LATAM']=latamCO;
    }
    if(result[coKey])delete result[coKey]['LATAM ex AR'];
    if(result[gmvKey]){
      if(!result[gmvKey]['LATAM']){
        var sumGMV=0;
        Object.keys(result[gmvKey]).forEach(function(c){if(c!=='LATAM'&&c!=='LATAM ex AR')sumGMV+=result[gmvKey][c];});
        if(sumGMV>0) result[gmvKey]['LATAM']=sumGMV;
      }
      delete result[gmvKey]['LATAM ex AR'];
    }

    // Los valores se suman directamente por fecha en rango — sin multiplicar.
    // El sheet tiene una entrada por (métrica, país, mes). El filtro ya acotó
    // por startStr→endStr, por lo que la suma ES el target del período.
    Logger.log('fetchTargetsOnly OK: '+startStr+' → '+endStr);

    cache.put(cacheKey,JSON.stringify(result),21600);
  } catch(err){ Logger.log("Error en fetchTargetsOnly: "+err.message); }
  return result;
}

// ── fetchDailyCharts ────────────────────────────────────────────────
function fetchDailyCharts() {
  var cache=CacheService.getScriptCache(), cached=cache.get("cache_grafic_detallado");
  if(cached)return JSON.parse(cached);
  try {
    // Parseo de fecha RÁPIDO (sin Utilities.formatDate por fila) + label sin
    // toLocaleString por fila → clave para que el barrido de la hoja no tarde.
    var MON=['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    function fastMs(raw){ return (raw instanceof Date) ? new Date(raw.getFullYear(),raw.getMonth(),raw.getDate()).getTime() : parseDateToMs(raw); }
    function fastYMD(raw){ if(raw instanceof Date){var y=raw.getFullYear(),m=raw.getMonth()+1,dd=raw.getDate();return y+'-'+(m<10?'0'+m:m)+'-'+(dd<10?'0'+dd:dd);} return normalizeDateToYMD(raw); }
    // Actuals
    var ss=SpreadsheetApp.openById(SPREADSHEET_ID), sheet=ss.getSheetByName(SHEET_ACTUALS);
    var data=sheet.getDataRange().getValues();
    var idxMetric=data[0].indexOf('Metric'),idxCountry=data[0].indexOf('Country'),idxDate=data[0].indexOf('Date'),idxValue=data[0].indexOf('Value');
    var dailyAgg={}, countriesSet={}, monthsSet={};
    for(var i=1;i<data.length;i++){
      var rMetric=data[i][idxMetric];
      if(rMetric!=='Confirmed Orders'&&rMetric!=='GMV User Dmarts')continue;
      var cRaw=String(data[i][idxCountry]||'').trim();
      var c=COUNTRY_NAME_TO_CODE[cRaw]||COUNTRY_NAME_TO_CODE[cRaw.toLowerCase()]||COUNTRY_ISO[cRaw.toLowerCase()]||cRaw;
      var rMs=fastMs(data[i][idxDate]);
      // "LATAM ex AR" es un pseudo-agregado (no un país real): lo excluimos del
      // gráfico para que no aparezca como país ni infle el total LATAM (que se
      // calcula sumando países).
      if(!c||c==='LATAM ex AR'||isNaN(rMs))continue;
      var d=new Date(rMs); countriesSet[c]=true;
      var yyyy=d.getFullYear(),mm=("0"+(d.getMonth()+1)).slice(-2),monthKey=yyyy+"-"+mm;
      monthsSet[monthKey]=true;
      var label=("0"+d.getDate()).slice(-2)+'-'+MON[d.getMonth()];
      var rVal=parseFloat(data[i][idxValue])||0, key=c+"_"+rMs;
      // null = sin dato real todavía (no 0, para poder filtrar correctamente en el front)
      if(!dailyAgg[key])dailyAgg[key]={c:c,d:rMs,lbl:label,m:monthKey,o:null,g:null};
      if(rMetric==='Confirmed Orders')dailyAgg[key].o=(dailyAgg[key].o||0)+rVal;
      if(rMetric==='GMV User Dmarts') dailyAgg[key].g=(dailyAgg[key].g||0)+rVal;
    }
    // Targets reales — para TODOS los meses con actuals (no solo el mes actual),
    // así el gráfico muestra la línea de target también al navegar meses previos.
    try {
      var tz=Session.getScriptTimeZone(), hoy=new Date();
      // Rango = desde el primer día con actuals hasta fin del mes actual.
      var allMs=Object.keys(dailyAgg).map(function(k){return dailyAgg[k].d;});
      var minMs=allMs.length?Math.min.apply(null,allMs):hoy.getTime();
      var minD=new Date(minMs);
      var tStart=Utilities.formatDate(new Date(minD.getFullYear(),minD.getMonth(),1),tz,'yyyy-MM-dd');
      var tEnd=Utilities.formatDate(new Date(hoy.getFullYear(),hoy.getMonth()+1,0),tz,'yyyy-MM-dd');
      var tss=SpreadsheetApp.openById(SPREADSHEET_TARGETS_ID_MTD);
      var tsheet=tss.getSheets().find(function(s){ return TARGETS_SHEET_RE.test(s.getName()); });
      if(tsheet){
        var td=tsheet.getDataRange().getValues();
        var th=td[0].map(function(h){ return String(h).trim().toLowerCase(); });
        var tiM=th.indexOf('metric'),tiC=th.indexOf('country'),tiD=th.indexOf('date'),tiV=th.indexOf('value');
        if(tiM>=0&&tiC>=0&&tiD>=0&&tiV>=0){
          for(var j=1;j<td.length;j++){
            var tm=String(td[j][tiM]||'').trim();
            if(tm!==TARGET_KEY_ORDERS&&tm!==TARGET_KEY_GMV)continue;
            var traw=td[j][tiD];
            var tymd=fastYMD(traw);
            if(!tymd||tymd<tStart||tymd>tEnd)continue;
            var tcn=String(td[j][tiC]||'').trim();
            var tcc=COUNTRY_NAME_TO_CODE[tcn]||COUNTRY_NAME_TO_CODE[tcn.toLowerCase()]||COUNTRY_ISO[tcn.toLowerCase()]||tcn;
            var tdMs=fastMs(traw);
            if(!tcc||isNaN(tdMs))continue;
            var tv=parseFloat(td[j][tiV])||0;
            var tkey=tcc+'_'+tdMs;
            if(!dailyAgg[tkey]){
              var fd=new Date(tdMs);
              var fLbl=("0"+fd.getDate()).slice(-2)+'-'+MON[fd.getMonth()];
              var fMk=fd.getFullYear()+'-'+("0"+(fd.getMonth()+1)).slice(-2);
              dailyAgg[tkey]={c:tcc,d:tdMs,lbl:fLbl,m:fMk,o:null,g:null};
              countriesSet[tcc]=true;
            }
            if(tm===TARGET_KEY_ORDERS)dailyAgg[tkey].tarO=(dailyAgg[tkey].tarO||0)+tv;
            if(tm===TARGET_KEY_GMV)   dailyAgg[tkey].tarG=(dailyAgg[tkey].tarG||0)+tv;
          }
        }
      }
    } catch(et){ Logger.log('[fetchDailyCharts] targets error: '+et.message); }
    var recs=Object.values(dailyAgg);
    // Un actual de 0 (o negativo) en Orders/GMV = "todavía sin datos" (p.ej. GMV
    // suele llegar más tarde y aparece como 0). Lo pasamos a null para que NO
    // dibuje barra, NO muestre -100% y NO sume su target en el acumulado.
    recs.forEach(function(r){
      if (r.o != null && r.o <= 0) r.o = null;
      if (r.g != null && r.g <= 0) r.g = null;
    });
    // rrData vacío a propósito: el chart page NO usa RR (los KPIs de RR se
    // sacaron). Calcular _getRRDataFromSheet() acá releía la hoja de actuals de
    // nuevo + 2 spreadsheets de targets — trabajo pesado e inútil que hacía
    // lento al gráfico y a veces reventaba el límite de la caché. El daily y el
    // MTD tienen su propio RR; esta página no lo necesita.
    var resultData={records:recs,countries:Object.keys(countriesSet).sort(),months:Object.keys(monthsSet).sort().reverse(),rrData:{orders:{},gmv:{}}};
    try{ cache.put("cache_grafic_detallado",JSON.stringify(resultData),1500); }catch(ec){ Logger.log('[fetchDailyCharts] cache skip (too large): '+ec.message); }
    return resultData;
  } catch(err){ throw new Error("Error en gráfico: "+err.message); }
}

function forceRefreshDataFast() {
  CacheService.getScriptCache().remove("cache_grafic_detallado");
  return true;
}

// ── Muestra todas las métricas disponibles en la hoja de actuals MTD ──────────
// ── Limpia TODOS los caches del servidor de una sola vez ──────────────────────
// Ejecutar desde el editor de Apps Script cuando no se ven cambios reflejados.
function clearAllCaches() {
  var cache = CacheService.getScriptCache();
  var tz    = Session.getScriptTimeZone();
  var hoy   = new Date();

  // Gráfico
  cache.remove('cache_grafic_detallado');

  // RR/BE Mes calculado
  cache.remove('cache_rrdata_mtd');

  // Daily snapshot
  cache.remove(CACHE_KEY);
  cache.remove(CACHE_KEY + '_fast');
  cache.remove(CACHE_KEY + '_targets');
  ['new_users','wis','wis_uf','seamless','delivery_time','assignment_time','rejected_orders','session_orders']
    .forEach(function(k){ cache.remove(CACHE_KEY + '_m_' + k); });

  // MTD actuals + targets (mes actual, todos los días posibles)
  var mesStart = Utilities.formatDate(new Date(hoy.getFullYear(), hoy.getMonth(), 1), tz, 'yyyy-MM-dd');
  for (var d = 1; d <= 31; d++) {
    var dayEnd = Utilities.formatDate(new Date(hoy.getFullYear(), hoy.getMonth(), d), tz, 'yyyy-MM-dd');
    cache.remove('cache_mtd_actuals_' + mesStart + '_' + dayEnd);
    cache.remove('cache_mtd_targets_' + mesStart + '_' + dayEnd);
    // también variante sin fechas (clave vacía)
    cache.remove('cache_mtd_actuals__');
    cache.remove('cache_mtd_targets__');
  }

  Logger.log('[OK] clearAllCaches OK — todos los caches del servidor limpiados.');
}

function debugMtdMetrics() {
  var ss    = SpreadsheetApp.openById(SPREADSHEET_ID);
  var sheet = ss.getSheetByName(SHEET_ACTUALS);
  var data  = sheet.getDataRange().getValues();
  var idxMetric = data[0].indexOf('Metric');
  if (idxMetric === -1) { Logger.log('ERROR: columna Metric no encontrada'); return; }
  var metricSet = {};
  for (var i = 1; i < data.length; i++) {
    var m = String(data[i][idxMetric] || '').trim();
    if (m) metricSet[m] = (metricSet[m] || 0) + 1;
  }
  Logger.log('=== Métricas en "' + SHEET_ACTUALS + '" ===');
  Object.keys(metricSet).sort().forEach(function(m) {
    Logger.log('  "' + m + '" → ' + metricSet[m] + ' filas');
  });
  Logger.log('=== FIN ===');
}

// ── debugMtdYoY ─────────────────────────────────────────────────────
// Diagnostica por qué el MTD no muestra datos YoY.
// Ejecutar desde el editor de Apps Script → ver el log.
function debugMtdYoY() {
  var tz  = Session.getScriptTimeZone();
  var hoy = new Date();

  // Período actual MTD (primer día del mes → ayer)
  var startStr = Utilities.formatDate(new Date(hoy.getFullYear(), hoy.getMonth(), 1), tz, 'yyyy-MM-dd');
  var endStr   = Utilities.formatDate(new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate()-1), tz, 'yyyy-MM-dd');

  // Período Y1 (mismo rango pero un año atrás)
  var startY1  = Utilities.formatDate(new Date(hoy.getFullYear()-1, hoy.getMonth(), 1), tz, 'yyyy-MM-dd');
  var endY1    = Utilities.formatDate(new Date(hoy.getFullYear()-1, hoy.getMonth(), hoy.getDate()-1), tz, 'yyyy-MM-dd');

  Logger.log('=== DEBUG MTD YoY ===');
  Logger.log('Período actual : ' + startStr + ' → ' + endStr);
  Logger.log('Período Y1     : ' + startY1  + ' → ' + endY1);
  Logger.log('Buscando en    : ' + SPREADSHEET_ID + ' → hoja "' + SHEET_ACTUALS + '"');

  var ss, sheet;
  try {
    ss    = SpreadsheetApp.openById(SPREADSHEET_ID);
    sheet = ss.getSheetByName(SHEET_ACTUALS);
    if (!sheet) { Logger.log('[ERROR] Hoja "' + SHEET_ACTUALS + '" no encontrada.'); return; }
  } catch(e) { Logger.log('[ERROR] Error abriendo spreadsheet: ' + e.message); return; }

  var data = sheet.getDataRange().getValues();
  var idxDate    = data[0].indexOf('Date');
  var idxMetric  = data[0].indexOf('Metric');
  var idxCountry = data[0].indexOf('Country');
  var idxValue   = data[0].indexOf('Value');

  Logger.log('Columnas → Date:' + idxDate + ' Metric:' + idxMetric + ' Country:' + idxCountry + ' Value:' + idxValue);
  Logger.log('Total filas (incluye header): ' + data.length);

  // Rango de fechas en la hoja
  var minYmd = null, maxYmd = null;
  var curRows = 0, y1Rows = 0;
  var y1ByMetric = {}, y1Countries = {};

  for (var i = 1; i < data.length; i++) {
    var ymd = normalizeDateToYMD(data[i][idxDate]);
    if (!ymd) continue;
    if (!minYmd || ymd < minYmd) minYmd = ymd;
    if (!maxYmd || ymd > maxYmd) maxYmd = ymd;

    var met = String(data[i][idxMetric]  || '').trim();
    var cnt = String(data[i][idxCountry] || '').trim();
    var val = parseFloat(data[i][idxValue]) || 0;

    if (ymd >= startStr && ymd <= endStr) curRows++;

    if (ymd >= startY1 && ymd <= endY1) {
      y1Rows++;
      if (!y1ByMetric[met]) y1ByMetric[met] = 0;
      y1ByMetric[met] += val;
      y1Countries[cnt] = true;
    }
  }

  Logger.log('--- Rango de fechas en la hoja ---');
  Logger.log('  Fecha mínima : ' + minYmd);
  Logger.log('  Fecha máxima : ' + maxYmd);
  Logger.log('--- Filas encontradas ---');
  Logger.log('  Período actual (' + startStr + '→' + endStr + '): ' + curRows + ' filas');
  Logger.log('  Período Y1     (' + startY1  + '→' + endY1  + '): ' + y1Rows  + ' filas');

  if (y1Rows === 0) {
    Logger.log('');
    Logger.log('[ERROR] NO HAY DATOS para el período Y1.');
    Logger.log('   La hoja tiene datos desde ' + minYmd + ' hasta ' + maxYmd + '.');
    Logger.log('   Para mostrar YoY, necesita datos desde al menos ' + startY1 + '.');
    Logger.log('   → Solución: cargar en la hoja "' + SHEET_ACTUALS + '" los actuals del mismo período del año anterior.');
  } else {
    Logger.log('');
    Logger.log('[OK] Hay ' + y1Rows + ' filas para el período Y1.');
    Logger.log('   Países con datos Y1: ' + Object.keys(y1Countries).sort().join(', '));
    Logger.log('   Totales Y1 por métrica:');
    var mets = Object.keys(y1ByMetric).sort();
    mets.forEach(function(m){ Logger.log('     "' + m + '" → ' + y1ByMetric[m]); });
    Logger.log('');
    Logger.log('   Si los datos existen pero YoY sigue sin aparecer,');
    Logger.log('   verificá que los nombres de métricas coincidan con COMPONENTES_CRUDOS:');
    Logger.log('   ' + JSON.stringify(COMPONENTES_CRUDOS));
    // Chequeo de intersección
    var missing = COMPONENTES_CRUDOS.filter(function(c){ return !y1ByMetric[c]; });
    if (missing.length > 0) {
      Logger.log('');
      Logger.log('[AVISO] Estas métricas de COMPONENTES_CRUDOS NO tienen datos Y1:');
      missing.forEach(function(m){ Logger.log('     "' + m + '"'); });
    } else {
      Logger.log('[OK] Todas las métricas de COMPONENTES_CRUDOS tienen datos Y1.');
    }
  }
  Logger.log('=== FIN debugMtdYoY ===');
}

// =================================================================
// ALL DATES (WHS Data) — fetchDailyMatrix & forceRefreshDailyMatrix
// =================================================================

/**
 * Reads "WHS all Data" sheet (una fila por warehouse × fecha, columnas crudas del
 * esquema nuevo: confirmed_orders, gmv, wis_*, total_orders_all_status,
 * seamless_delivery, late/slow/rejected/session/forced/modified_orders,
 * *_time_sum, non_forced_completed_orders_logistics, total_orders_timings,
 * assignment_time_orders_over_6min), filters by current period [startDate, endDate] AND
 * the automatically-computed comparison period (same duration, immediately before),
 * aggregates by WAREHOUSE (numeradores/denominadores se suman antes de dividir,
 * así los ratios por warehouse quedan bien ponderados) y agrega una fila TOTAL.
 * Devuelve rows[{warehouse_id, warehouse_name, country, isTotal, cur, comp}] y countries[].
 *
 * Default (sin fechas): "último mes disponible" (día 1 del mes con la fecha
 * máxima → esa fecha máxima). Comparación: MISMO rango del mes pasado
 * (resta un mes calendario). Ej: Jun 1–9 → comparación May 1–9.
 * Consumido por: 6_MTD_by_WHS.html
 */
function fetchDailyMatrix(startDate, endDate) {
  var tz = Session.getScriptTimeZone();

  // Si no se pasan fechas: el default se resuelve al "último mes disponible"
  // recién después de leer la hoja (necesitamos la fecha máxima real).
  var isDefault = (!startDate || !endDate);

  // El default usa una clave de caché propia ('default') para que la primera
  // carga de la página sea rápida en visitas repetidas sin saber las fechas.
  var cacheKey = isDefault
    ? 'cache_daily_mx8_default'
    : 'cache_daily_mx8_' + startDate + '_' + endDate; // v8: incluye weighted open time %
  var cache = CacheService.getScriptCache();
  try {
    var hit = cache.get(cacheKey);
    if (hit) {
      var parsed = JSON.parse(hit);
      // Don't return cached empty results — re-fetch so debug info is fresh
      if (parsed && parsed.rows && parsed.rows.length > 0) return parsed;
    }
  } catch(e) {}

  try {
    var ss    = SpreadsheetApp.openById(SS_ID);
    // Busca la hoja "WHS all Data" (tolerante a mayúsculas/espacios y a los nombres
    // viejos "WHS Data" / "Extract 3").
    // Prioridad: cualquier hoja tipo "WHS all Data" (tolerante a mayúsc./espacios)
    // ANTES de caer a la vieja "WHS Data"/"Extract 3". Si no se ordena así y coexisten
    // la nueva (con otro casing) y la vieja, terminaba leyendo la vieja → columnas nuevas
    // faltantes → tabla vacía.
    var sheet = ss.getSheetByName('WHS all Data') ||
                ss.getSheets().find(function(s){ return /whs\s*all\s*data/i.test(s.getName()); }) ||
                ss.getSheetByName('WHS Data') ||
                ss.getSheets().find(function(s){ return /whs\s*data|extract\s*3/i.test(s.getName()); });
    if (!sheet) {
      var names = ss.getSheets().map(function(s){ return '"'+s.getName()+'"'; });
      throw new Error('Hoja "WHS all Data" no encontrada. Hojas en el SS: ' + names.join(', '));
    }
    var data  = sheet.getDataRange().getValues();
    if (data.length < 2) throw new Error('Hoja "WHS all Data" vacía (solo tiene encabezado).');

    // ── Detección robusta de columnas (lowercase + underscore↔space fallback) ──
    var rawHeaders = data[0];
    var headers = rawHeaders.map(function(h){ return String(h).trim().toLowerCase(); });

    function findCol(name) {
      var lo = name.toLowerCase().replace(/[^a-z0-9]/g,'');
      for (var j = 0; j < headers.length; j++) {
        var cleanH = headers[j].replace(/[^a-z0-9]/g,'');
        if (cleanH === lo) return j;
      }
      return -1;
    }

    // Esquema "WHS all Data": una fila por warehouse × fecha, columnas crudas.
    var COLS = ['fecha','country_code','warehouse_id','warehouse_name',
                'confirmed_orders','new_users','gmv',
                'wis_numerador','wis_denominador','wis_uf_numerador','wis_uf_denominador',
                'total_orders_all_status',
                'seamless_delivery','late_orders','slow_orders','rejected_orders','session_orders',
                'forced_preorders','modified_orders',
                'assignment_time_sum','non_forced_completed_orders_logistics','delivery_time_sum',
                'total_orders_timings','assignment_time_orders_over_6min',
                'assignment_time_order_count','open_time'];
    
    // Soporte para nombres de columna viejos (retrocompatibilidad si la hoja no se actualizó con la nueva query)
    var FALLBACKS = GLOBAL_FALLBACKS;

    var CI = {};
    COLS.forEach(function(col){
      var idx = findCol(col);
      if (idx < 0 && FALLBACKS[col]) {
        for (var f = 0; f < FALLBACKS[col].length; f++) {
          idx = findCol(FALLBACKS[col][f]);
          if (idx >= 0) break;
        }
      }
      CI[col] = idx;
    });

    // Fallback explícito a Columna Y (índice 24 en 0-based, columna 25 física) si no se halló por nombre
    if ((CI.open_time === undefined || CI.open_time < 0) && rawHeaders.length > 24) {
      CI.open_time = 24;
    }

    // Validación de columnas críticas con mensaje de ayuda
    var missing = ['fecha','country_code'].filter(function(c){ return CI[c] < 0; });
    if (missing.length > 0) {
      throw new Error('Columnas críticas no encontradas: ' + missing.join(', ') +
        '. Headers reales (primeros 20): ' + headers.slice(0,20).join(' | '));
    }

    // Parser de fecha RÁPIDO: para celdas Date (lo normal en el export de BQ)
    // arma "yyyy-MM-dd" con getFullYear/getMonth/getDate (zona del script, igual
    // que Utilities.formatDate, pero ~100× más barato). Solo cae a
    // normalizeDateToYMD para strings/otros formatos. Es la clave para no
    // timeoutear leyendo una hoja grande (se llama una vez por fila).
    var fechaIdx = CI.fecha;
    function fastYMD(raw){
      if (raw instanceof Date){
        var y=raw.getFullYear(), m=raw.getMonth()+1, d=raw.getDate();
        return y+'-'+(m<10?'0'+m:m)+'-'+(d<10?'0'+d:d);
      }
      return normalizeDateToYMD(raw);
    }

    // ── Default = ÚLTIMO MES DISPONIBLE ──────────────────────────
    // Escaneo barato de la columna fecha para encontrar el día máximo con datos
    // y abrir por defecto desde el día 1 de ese mes hasta ese día.
    if (isDefault) {
      var maxYMD = '';
      for (var di = 1; di < data.length; di++) {
        var fy = fastYMD(data[di][fechaIdx]);
        if (fy && fy > maxYMD) maxYMD = fy;
      }
      if (maxYMD) {
        startDate = maxYMD.slice(0, 7) + '-01';
        endDate   = maxYMD;
      } else {
        // Fallback: MTD del mes corriente
        var hoyDef = new Date();
        startDate = Utilities.formatDate(new Date(hoyDef.getFullYear(), hoyDef.getMonth(), 1), tz, 'yyyy-MM-dd');
        endDate   = Utilities.formatDate(hoyDef, tz, 'yyyy-MM-dd');
      }
    }

    // ── Comparación = MISMO RANGO DEL MES PASADO ─────────────────
    // Resta un mes calendario a inicio y fin (clamp del día al largo del mes).
    function shiftMonthYMD(ymd, delta) {
      var p = ymd.split('-'), y = +p[0], m = +p[1] - 1, d = +p[2];
      var base = new Date(y, m + delta, 1);
      var lastDay = new Date(base.getFullYear(), base.getMonth() + 1, 0).getDate();
      return Utilities.formatDate(new Date(base.getFullYear(), base.getMonth(), Math.min(d, lastDay)), tz, 'yyyy-MM-dd');
    }
    var sp = startDate.split('-'), ep = endDate.split('-');
    var startObj = new Date(+sp[0], +sp[1]-1, +sp[2]);
    var endObj   = new Date(+ep[0], +ep[1]-1, +ep[2]);
    var numDays  = Math.round((endObj - startObj) / 86400000) + 1;
    var compStart = shiftMonthYMD(startDate, -1);
    var compEnd   = shiftMonthYMD(endDate,   -1);
    var yearStart = shiftMonthYMD(startDate, -12);   // mismo rango, un año antes (YoY)
    var yearEnd   = shiftMonthYMD(endDate,   -12);

    var SUM_COLS = ['confirmed_orders','new_users','gmv',
                    'wis_numerador','wis_denominador','wis_uf_numerador','wis_uf_denominador',
                    'total_orders_all_status',
                    'seamless_delivery','late_orders','slow_orders','rejected_orders','session_orders',
                    'forced_preorders','modified_orders',
                    'assignment_time_sum','non_forced_completed_orders_logistics','delivery_time_sum',
                    'total_orders_timings','assignment_time_orders_over_6min',
                    'assignment_time_order_count'];

    var map = {}, submap = {}, validDatesSet = {}, TOTAL = '__TOTAL__';

    // Índices de columnas a sumar, precomputados una sola vez (evita el
    // SUM_COLS.forEach + CI[col] por fila). Helper para inicializar acumuladores.
    var sumIdx = SUM_COLS.map(function(c){ return { k:c, i:CI[c] }; })
                         .filter(function(x){ return x.i !== undefined && x.i >= 0; });
    function zeroAcc(o){
      for (var s=0;s<sumIdx.length;s++){
        o[sumIdx[s].k+'_cur']=0; o[sumIdx[s].k+'_comp']=0; o[sumIdx[s].k+'_year']=0;
      }
      ['_cur','_comp','_year'].forEach(function(sfx){
        o['open_time' + sfx] = null;
        o['open_time_w_sum' + sfx] = 0;
        o['open_time_w_den' + sfx] = 0;
      });
      return o;
    }
    var ciCC = CI.country_code, ciWID = CI.warehouse_id, ciWN = CI.warehouse_name;
    var ciOpen = CI.open_time, ciOrders = CI.confirmed_orders;

    for (var i = 1; i < data.length; i++) {
      var row = data[i];
      var fechaYMD = fastYMD(row[fechaIdx]);
      if (!fechaYMD) continue;
      validDatesSet[fechaYMD] = true;

      var isCur  = fechaYMD >= startDate && fechaYMD <= endDate;
      var isComp = fechaYMD >= compStart  && fechaYMD <= compEnd;
      var isYear = fechaYMD >= yearStart  && fechaYMD <= yearEnd;
      if (!isCur && !isComp && !isYear) continue;

      var cc = ciCC >= 0 ? String(row[ciCC] || '').trim().toUpperCase() : '';
      var wid = ciWID >= 0 ? String(row[ciWID] || '').trim() : '';
      var wname = ciWN >= 0 ? String(row[ciWN] || '').trim() : '';
      
      // Evitar procesar filas que sean pre-totales o resúmenes en la hoja de cálculo
      var isTotalRow = /total|summary|general/i.test(wid) || /total|summary|general/i.test(wname) || /total|summary|general/i.test(cc);
      if (!wid || !cc || cc === 'LATAM' || isTotalRow) continue; // sin warehouse no agrega; LATAM se calcula acá

      // Acumuladores (warehouse, TOTAL global y subtotal por país) en UNA pasada.
      var mw = map[wid]; if (!mw){ mw = map[wid] = zeroAcc({ wid:wid, wname:wname, cc:cc }); }
      else { if (wname) mw.wname = wname; mw.cc = cc; }
      var mt = map[TOTAL]; if (!mt){ mt = map[TOTAL] = zeroAcc({ wid:TOTAL, wname:'TOTAL', cc:'' }); }
      var ms = submap[cc]; if (!ms){ ms = submap[cc] = zeroAcc({}); }

      var sfx = isCur ? '_cur' : isComp ? '_comp' : '_year';
      for (var s = 0; s < sumIdx.length; s++) {
        var v = parseFloat(row[sumIdx[s].i]);
        if (!isNaN(v) && v > 0) { var key = sumIdx[s].k + sfx; mw[key]+=v; mt[key]+=v; ms[key]+=v; }
      }

      // Weighted Open Time % es métrica diaria: toma únicamente el PRIMER día de cada rango
      // (startDate para actual, compStart para período anterior, yearStart para año anterior)
      if (ciOpen >= 0 && row[ciOpen] !== '' && row[ciOpen] != null) {
        var openSfx = (fechaYMD === startDate) ? '_cur' : (fechaYMD === compStart) ? '_comp' : (fechaYMD === yearStart) ? '_year' : null;
        if (openSfx) {
          var rawVal = row[ciOpen];
          var openVal = typeof rawVal === 'number' ? rawVal : parseFloat(String(rawVal).replace('%','').replace(',','.').trim());
          if (!isNaN(openVal) && openVal >= 0) {
            if (openVal <= 1.0 && openVal > 0) openVal = openVal * 100;
            var rowOrders = (ciOrders >= 0 && !isNaN(parseFloat(row[ciOrders]))) ? parseFloat(row[ciOrders]) : 0;
            var w = rowOrders > 0 ? rowOrders : 1;

            mw['open_time' + openSfx] = openVal;

            mt['open_time_w_sum' + openSfx] += (openVal * w);
            mt['open_time_w_den' + openSfx] += w;

            ms['open_time_w_sum' + openSfx] += (openVal * w);
            ms['open_time_w_den' + openSfx] += w;
          }
        }
      }
    }

    function pct(n, d) { return d > 0 ? (n / d) * 100 : null; }
    function avg(n, d) { return d > 0 ? n / d : null; }

    function buildVals(r, sfx){
      var all = r['total_orders_all_status'+sfx];                 // denom. familia order-share
      var log = r['non_forced_completed_orders_logistics'+sfx];    // denom. tiempos
      var tim = r['total_orders_timings'+sfx];                     // denom. saturación
      var ass_log = (r['assignment_time_order_count'+sfx] > 0) ? r['assignment_time_order_count'+sfx] : log;
      var openTimeVal = null;
      if (r['open_time' + sfx] !== undefined && r['open_time' + sfx] !== null) {
        openTimeVal = r['open_time' + sfx];
      } else if (r['open_time_w_den' + sfx] > 0) {
        openTimeVal = r['open_time_w_sum' + sfx] / r['open_time_w_den' + sfx];
      }
      return {
        orders:           r['confirmed_orders'+sfx] || null,
        gmv:              r['gmv'+sfx]              || null,
        new_users:        r['new_users'+sfx]         || null,
        wis:              pct(r['wis_numerador'+sfx],    r['wis_denominador'+sfx]),
        wis_uf:           pct(r['wis_uf_numerador'+sfx], r['wis_uf_denominador'+sfx]),
        seamless:         pct(r['seamless_delivery'+sfx],  all),
        late_orders:      pct(r['late_orders'+sfx],        all),
        slow_orders:      pct(r['slow_orders'+sfx],        all),
        rejected_orders:  pct(r['rejected_orders'+sfx],    all),
        session_orders:   pct(r['session_orders'+sfx],     all),
        forced_preorders: pct(r['forced_preorders'+sfx],   all),
        modified_orders:  pct(r['modified_orders'+sfx],    all),
        delivery_time:    avg(r['delivery_time_sum'+sfx],  log),
        assignment_time:  avg(r['assignment_time_sum'+sfx], r['assignment_time_order_count'+sfx]),
        assignment_time_orders_over_6min: pct(r['assignment_time_orders_over_6min'+sfx], r['assignment_time_order_count'+sfx]),
        open_time:        openTimeVal,
      };
    }

    // Construimos las filas de cada warehouse individual primero (excluyendo pre-totales)
    var warehouseRows = Object.keys(map).filter(function(k){ return k !== TOTAL; }).map(function(k){
      var r = map[k];
      return {
        warehouse_id:   r.wid,
        warehouse_name: r.wname,
        country:        r.cc,
        isTotal:        false,
        cur:  buildVals(r, '_cur'),
        comp: buildVals(r, '_comp'),
        year: buildVals(r, '_year')
      };
    });

    // Calcular la fila TOTAL global aplicando buildVals directamente al acumulado de sumas globales map[TOTAL]
    // Esto realiza un promedio ponderado (suma todo primero, y divide al final) para todas las métricas.
    var totalRowObj = {
      warehouse_id:   '__TOTAL__',
      warehouse_name: 'TOTAL',
      country:        '',
      isTotal:        true,
      cur:  buildVals(map[TOTAL], '_cur'),
      comp: buildVals(map[TOTAL], '_comp'),
      year: buildVals(map[TOTAL], '_year')
    };

    // Ordenar almacenes por volumen de órdenes confirmadas período actual (desc)
    warehouseRows.sort(function(a,b){
      return (b.cur.orders||0) - (a.cur.orders||0);
    });

    // Unir almacenes con la fila TOTAL al final
    var rows = warehouseRows.concat([totalRowObj]);

    // Lista de países presentes (para el filtro del front)
    var ccSet = {};
    warehouseRows.forEach(function(r){ if (r.country) ccSet[r.country] = true; });
    var countries = Object.keys(ccSet).sort();

    // Calcular subtotales por país aplicando buildVals directamente al acumulado por país submap[cc]
    // Esto realiza un promedio ponderado (suma todo primero, y divide al final) para todas las métricas por país.
    var subtotals = {};
    countries.forEach(function(cc){
      if (submap[cc]) {
        subtotals[cc] = {
          cur:  buildVals(submap[cc], '_cur'),
          comp: buildVals(submap[cc], '_comp'),
          year: buildVals(submap[cc], '_year')
        };
      } else {
        subtotals[cc] = null;
      }
    });

    var validDates = Object.keys(validDatesSet).sort();

    // Debug info — incluido siempre para diagnóstico, especialmente útil cuando rows=0
    var debug = {
      sheetName:    sheet.getName(),
      totalRows:    data.length - 1,
      rowsMatched:  rows.length,
      dateRangeInSheet: validDates.length > 0 ? { min: validDates[0], max: validDates[validDates.length-1] } : null,
      colsFound:    COLS.filter(function(c){ return CI[c] >= 0; }),
      colsMissing:  COLS.filter(function(c){ return CI[c] < 0; }),
      headersAll:   headers,   // TODOS los encabezados reales de la hoja (para diagnosticar renombres)
      headersFirst20: headers.slice(0, 20),
    };

    var result = {
      rows: rows, countries: countries, subtotals: subtotals,
      currentStart: startDate, currentEnd: endDate,
      compStart: compStart, compEnd: compEnd,
      yearStart: yearStart, yearEnd: yearEnd,
      validDates: validDates, numDays: numDays,
      _debug: debug
    };
    // Solo cachear si hay datos para no bloquear con un resultado vacío
    if (rows.length > 0) {
      try { cache.put(cacheKey, JSON.stringify(result), 1500); } catch(e) {}
    }
    return result;

  } catch(err) {
    return { error: err.message || String(err) };
  }
}

/**
 * DEBUG de MTD by WHS — ejecutar desde el editor de Apps Script (Ver > Registros).
 * Reporta: si abre el spreadsheet, qué hojas hay, si encuentra "WHS Data",
 * cuántas filas/columnas, cuánto tarda fetchDailyMatrix, y un resumen del resultado.
 */
function debugDailyMatrix() {
  var out = [];
  function log(s){ out.push(s); Logger.log(s); }
  var t0 = Date.now();
  try {
    log('1) Abriendo spreadsheet SS_ID=' + SS_ID + ' ...');
    var ss = SpreadsheetApp.openById(SS_ID);
    log('   OK: "' + ss.getName() + '"');

    var sheetNames = ss.getSheets().map(function(s){ return s.getName(); });
    log('2) Hojas (' + sheetNames.length + '): ' + sheetNames.map(function(n){return '"'+n+'"';}).join(', '));

    var sheet = ss.getSheetByName('WHS all Data') ||
                ss.getSheets().find(function(s){ return /whs\s*all\s*data/i.test(s.getName()); }) ||
                ss.getSheetByName('WHS Data') ||
                ss.getSheets().find(function(s){ return /whs\s*data|extract\s*3/i.test(s.getName()); });
    if (!sheet) { log('   [FAIL] NO se encontró la hoja "WHS all Data".'); return out.join('\n'); }
    log('   [OK] Hoja encontrada: "' + sheet.getName() + '" — filas=' + sheet.getLastRow() + ', cols=' + sheet.getLastColumn());

    log('3) Leyendo encabezados...');
    var headers = sheet.getRange(1,1,1,sheet.getLastColumn()).getValues()[0]
                    .map(function(h){ return String(h).trim(); });
    log('   Headers: ' + headers.join(' | '));

    log('4) Llamando fetchDailyMatrix("","") [MTD por defecto]...');
    var tF = Date.now();
    var res = fetchDailyMatrix('', '');
    var ms = Date.now() - tF;
    log('   fetchDailyMatrix tardó ' + ms + ' ms');

    if (res.error) { log('   [FAIL] ERROR devuelto: ' + res.error); }
    else {
      log('   [OK] rows=' + (res.rows ? res.rows.length : 0) +
          '  período=' + res.currentStart + '→' + res.currentEnd +
          '  vs ' + res.compStart + '→' + res.compEnd);
      if (res._debug) {
        log('   _debug.rowsMatched=' + res._debug.rowsMatched +
            '  totalRows=' + res._debug.totalRows);
        log('   _debug.colsMissing=' + JSON.stringify(res._debug.colsMissing));
        if (res._debug.dateRangeInSheet)
          log('   fechas en hoja: ' + res._debug.dateRangeInSheet.min + ' → ' + res._debug.dateRangeInSheet.max);
      }
      if (res.rows && res.rows[0]) log('   ejemplo fila[0]: ' + JSON.stringify(res.rows[0]));
    }
  } catch(err) {
    log('[FAIL] EXCEPCIÓN: ' + err.message);
  }
  log('TOTAL: ' + (Date.now() - t0) + ' ms');
  return out.join('\n');
}

/**
 * Clears server-side caches for the most-common daily-matrix date ranges
 * (yesterday single day, last 7 days, MTD of current month, and today variants).
 */
function forceRefreshDailyMatrix(startDate, endDate) {
  var cache = CacheService.getScriptCache();
  var tz    = Session.getScriptTimeZone();
  var hoy   = new Date();
  var today    = Utilities.formatDate(hoy, tz, 'yyyy-MM-dd');
  var yesterday = Utilities.formatDate(new Date(hoy.getTime() - 86400000), tz, 'yyyy-MM-dd');
  var firstMo  = Utilities.formatDate(new Date(hoy.getFullYear(), hoy.getMonth(), 1), tz, 'yyyy-MM-dd');
  var wk7start = Utilities.formatDate(new Date(hoy.getTime() - 6 * 86400000), tz, 'yyyy-MM-dd');
  var wk7yst   = Utilities.formatDate(new Date(hoy.getTime() - 7 * 86400000), tz, 'yyyy-MM-dd');
  var keys = [
    'cache_daily_mx8_default',
    'cache_daily_mx8_' + today     + '_' + today,
    'cache_daily_mx8_' + yesterday + '_' + yesterday,
    'cache_daily_mx8_' + firstMo   + '_' + today,
    'cache_daily_mx8_' + firstMo   + '_' + yesterday,
    'cache_daily_mx8_' + wk7start  + '_' + today,
    'cache_daily_mx8_' + wk7yst    + '_' + yesterday,
    'cache_daily_mx7_default',
    'cache_daily_mx7_' + today     + '_' + today,
    'cache_daily_mx7_' + yesterday + '_' + yesterday,
  ];
  if (startDate && endDate) {
    keys.push('cache_daily_mx8_' + startDate + '_' + endDate);
    keys.push('cache_daily_mx7_' + startDate + '_' + endDate);
  }
  keys.forEach(function(k){ cache.remove(k); });
  // Precalentar la caché del default (último mes) para que la próxima carga
  // de la página sea instantánea. Se puede llamar desde un trigger horario.
  try { fetchDailyMatrix('', ''); } catch(e) {}
  return true;
}

// =================================================================
// DIAGNÓSTICO debugGraficTargets (existente — no borrar)
// =================================================================
function debugGraficTargets() {
  var tz  = Session.getScriptTimeZone();
  var hoy = new Date();
  var startStr = Utilities.formatDate(new Date(hoy.getFullYear(), hoy.getMonth(), 1), tz, 'yyyy-MM-dd');
  var endStr   = Utilities.formatDate(hoy, tz, 'yyyy-MM-dd');
  Logger.log('=== debugGraficTargets · periodo: ' + startStr + ' a ' + endStr + ' ===');

  // ── ACTUALS ─────────────────────────────────────────────────────
  var ss=SpreadsheetApp.openById(SPREADSHEET_ID), sheet=ss.getSheetByName(SHEET_ACTUALS);
  var data=sheet.getDataRange().getValues();
  var hdrs=data[0].map(function(h){return String(h).trim();});
  Logger.log('Actuals headers: '+JSON.stringify(hdrs));
  var idxM=hdrs.indexOf('Metric'),idxC=hdrs.indexOf('Country'),idxD=hdrs.indexOf('Date'),idxV=hdrs.indexOf('Value');
  Logger.log('Actuals col idx → Metric:'+idxM+' Country:'+idxC+' Date:'+idxD+' Value:'+idxV);

  var actSample={}, actCount=0;
  for(var i=1;i<data.length;i++){
    if(String(data[i][idxM]).trim()!=='Confirmed Orders')continue;
    var cRaw=String(data[i][idxC]||'').trim();
    var c=COUNTRY_NAME_TO_CODE[cRaw]||COUNTRY_NAME_TO_CODE[cRaw.toLowerCase()]||COUNTRY_ISO[cRaw.toLowerCase()]||cRaw;
    var rMs=parseDateToMs(data[i][idxD]);
    var ymd=normalizeDateToYMD(data[i][idxD]);
    if(!ymd||ymd<startStr||ymd>endStr)continue;
    if(actCount<3)Logger.log('  ACT: cRaw="'+cRaw+'" c="'+c+'" date='+ymd+' key='+c+'_'+rMs);
    if(!actSample[c])actSample[c]=0;
    actSample[c]+=parseFloat(data[i][idxV])||0;
    actCount++;
  }
  Logger.log('Actuals filas en periodo: '+actCount+' | totales: '+JSON.stringify(actSample));

  // ── TARGETS ─────────────────────────────────────────────────────
  var tss=SpreadsheetApp.openById(SPREADSHEET_TARGETS_ID_MTD);
  var tsheet=tss.getSheets().find(function(s){return TARGETS_SHEET_RE.test(s.getName());});
  if(!tsheet){Logger.log('ERROR: hoja targets no encontrada');return;}
  var td=tsheet.getDataRange().getValues();
  var th=td[0].map(function(h){return String(h).trim().toLowerCase();});
  Logger.log('Targets headers: '+JSON.stringify(th));
  var tiM=th.indexOf('metric'),tiC=th.indexOf('country'),tiD=th.indexOf('date'),tiV=th.indexOf('value');
  Logger.log('Targets col idx → metric:'+tiM+' country:'+tiC+' date:'+tiD+' value:'+tiV);

  var tgtSample={}, tgtCount=0;
  for(var j=1;j<td.length;j++){
    var tm=String(td[j][tiM]||'').trim();
    if(tm!==TARGET_KEY_ORDERS)continue;
    var tcn=String(td[j][tiC]||'').trim();
    var tcc=COUNTRY_NAME_TO_CODE[tcn]||COUNTRY_NAME_TO_CODE[tcn.toLowerCase()]||COUNTRY_ISO[tcn.toLowerCase()]||tcn;
    var tdMs=parseDateToMs(td[j][tiD]);
    var tymd=normalizeDateToYMD(td[j][tiD]);
    if(!tymd||tymd<startStr||tymd>endStr)continue;
    if(tgtCount<3)Logger.log('  TGT: tcn="'+tcn+'" tcc="'+tcc+'" date='+tymd+' key='+tcc+'_'+tdMs);
    if(!tgtSample[tcc])tgtSample[tcc]=0;
    tgtSample[tcc]+=parseFloat(td[j][tiV])||0;
    tgtCount++;
  }
  Logger.log('Targets filas en periodo: '+tgtCount+' | totales: '+JSON.stringify(tgtSample));

  // ── MATCH CHECK ──────────────────────────────────────────────────
  Logger.log('--- Match por pais ---');
  var allCtries={};
  Object.keys(actSample).forEach(function(c){allCtries[c]=true;});
  Object.keys(tgtSample).forEach(function(c){allCtries[c]=true;});
  Object.keys(allCtries).sort().forEach(function(c){
    Logger.log('  '+c+': actual='+(actSample[c]?Math.round(actSample[c]):'—')+' | target='+(tgtSample[c]?Math.round(tgtSample[c]):'NO ENCONTRADO'));
  });
}
