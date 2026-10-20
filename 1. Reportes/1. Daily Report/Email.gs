// =================================================================
// LÓGICA DE CORREO (Archivo: Email.gs)
// =================================================================


const HORA_ENVIO   = 9;
const MINUTO_ENVIO = 30;
const VENTANA_MIN  = 270; // 4.5 horas: de 09:30 a 14:00 para reintentar cada 10 min si BigQuery/OKRs vienen demorados
const PROP_KEY     = 'ULTIMO_ENVIO_EMAIL';

// Verifica si Pedidos confirmados y Facturación (GMV) en la hoja de actuals
// están cargados al menos hasta la fecha que reporta la página daily.
// Si no están actualizados, no se debe enviar el correo.
function verificarDatosActualizadosParaEmail(payload) {
  const zona = Session.getScriptTimeZone();

  // 1) Fecha del daily (fechaReferencia / d1Date)
  let d1Date;
  if (payload && payload.fechaReferencia) {
    const ref = new Date(payload.fechaReferencia);
    d1Date = new Date(Utilities.formatDate(ref, zona, "yyyy-MM-dd'T'12:00:00"));
  } else {
    const hoy = new Date(Utilities.formatDate(new Date(), zona, "yyyy-MM-dd'T'12:00:00"));
    d1Date = new Date(hoy); d1Date.setDate(hoy.getDate() - 1);
  }
  const dailyDateStr = Utilities.formatDate(d1Date, zona, 'yyyy-MM-dd');

  // 2) Fechas reales cargadas en "A. TI - Actuals OKRs"
  const actuals = (typeof _getFechasActuals === 'function') ? _getFechasActuals() : { orders: null, gmv: null };
  const ordersDateStr = actuals.orders;
  const gmvDateStr = actuals.gmv;

  const ordersOk = Boolean(ordersDateStr && ordersDateStr >= dailyDateStr);
  const gmvOk    = Boolean(gmvDateStr && gmvDateStr >= dailyDateStr);
  const ok = Boolean(ordersOk && gmvOk);

  function fmtDmy(ymd) {
    if (!ymd) return '—';
    const p = ymd.split('-');
    return (p.length === 3) ? `${p[2]}/${p[1]}/${p[0]}` : ymd;
  }

  let motivo = '';
  if (!ordersOk && !gmvOk) {
    motivo = `Pedidos confirmados (cargado hasta el ${fmtDmy(ordersDateStr)}) y Facturación (GMV) (cargada hasta el ${fmtDmy(gmvDateStr)}) no están actualizados con la fecha del daily (${fmtDmy(dailyDateStr)})`;
  } else if (!ordersOk) {
    motivo = `Pedidos confirmados (cargado hasta el ${fmtDmy(ordersDateStr)}) no está actualizado con la fecha del daily (${fmtDmy(dailyDateStr)})`;
  } else if (!gmvOk) {
    motivo = `Facturación (GMV) (cargada hasta el ${fmtDmy(gmvDateStr)}) no está actualizada con la fecha del daily (${fmtDmy(dailyDateStr)})`;
  }

  return {
    ok: ok,
    dailyDate: dailyDateStr,
    ordersDate: ordersDateStr,
    gmvDate: gmvDateStr,
    dailyDateDmy: fmtDmy(dailyDateStr),
    ordersDateDmy: fmtDmy(ordersDateStr),
    gmvDateDmy: fmtDmy(gmvDateStr),
    ordersOk: ordersOk,
    gmvOk: gmvOk,
    motivo: motivo
  };
}

function checkYEnviarEmail() {
  // Calienta la caché del daily si quedó fría (p.ej. tras expirar a las 10:00),
  // así el primer usuario del día no paga la lectura lenta. Es barato si ya está
  // caliente. Corre en CADA tick del trigger (cada 10 min), no solo al enviar.
  try { warmupDailyCache(); } catch (e) { Logger.log('warmup (email trigger): ' + e.message); }

  const zona  = Session.getScriptTimeZone();
  const ahora = new Date();
  const hh       = parseInt(Utilities.formatDate(ahora, zona, 'H'));
  const mm       = parseInt(Utilities.formatDate(ahora, zona, 'm'));
  const minAhora = hh * 60 + mm;
  const minObj   = HORA_ENVIO * 60 + MINUTO_ENVIO;
  const hoyStr   = Utilities.formatDate(ahora, zona, 'yyyy-MM-dd');
  const horaStr  = Utilities.formatDate(ahora, zona, 'HH:mm');

  const props    = PropertiesService.getScriptProperties();

  Logger.log('=== checkYEnviarEmail ===');
  Logger.log('Hora actual     : ' + horaStr + ' (' + zona + ')');
  Logger.log('Ventana de envío: ' + HORA_ENVIO + ':' + String(MINUTO_ENVIO).padStart(2,'0') + ' → ' + HORA_ENVIO + ':' + String(MINUTO_ENVIO + VENTANA_MIN).padStart(2,'0'));
  Logger.log('Hoy             : ' + hoyStr);

  if (minAhora < minObj || minAhora > minObj + VENTANA_MIN) {
    Logger.log('Último envío    : ' + (props.getProperty(PROP_KEY) || 'nunca'));
    Logger.log('Estado          : FUERA DE VENTANA — no se envía');
    Logger.log('========================');
    return;
  }

  // ── Pre-chequeo liviano de actualización ────────────────────────────────────
  // Comprueba que la hoja del daily tenga al menos la fecha de ayer y que
  // Pedidos confirmados y GMV hayan sido cargados hasta esa fecha. Si aún no
  // están listos, sale rápido sin reservar ni enviar, esperando el próximo tick.
  const ayer = new Date(ahora);
  ayer.setDate(ahora.getDate() - 1);
  const ayerStr = Utilities.formatDate(ayer, zona, 'yyyy-MM-dd');

  try {
    var fastRes = _readSheetFast();
    if (fastRes && fastRes.payload) {
      var preCheck = verificarDatosActualizadosParaEmail(fastRes.payload);
      if (preCheck.dailyDate < ayerStr) {
        Logger.log('Estado          : ESPERANDO DAILY — Hoja daily tiene fecha ' + preCheck.dailyDateDmy + ', esperando datos de ayer (' + Utilities.formatDate(ayer, zona, 'dd/MM/yyyy') + '). Reintentará en el próximo tick.');
        Logger.log('========================');
        return;
      }
      if (!preCheck.ok) {
        Logger.log('Estado          : ESPERANDO ACTUALIZACIÓN — ' + preCheck.motivo + '. Reintentará en el próximo tick.');
        Logger.log('========================');
        return;
      }
    }
  } catch (eCheck) {
    Logger.log('[checkYEnviarEmail] Advertencia en pre-chequeo: ' + eCheck.message);
  }

  // ── Anti DOBLE ENVÍO ────────────────────────────────────────────────────────
  // El envío es LENTO (2–16 min: arma el PDF y manda a +120 en lotes). El trigger
  // tickea seguido y varios ticks caen dentro de la ventana (10:30→10:39). ANTES la
  // marca "ya enviado hoy" (PROP_KEY) se escribía DESPUÉS del envío: un segundo tick
  // arrancaba mientras el primero seguía enviando, veía "NO enviado" y mandaba el
  // mail otra vez (pasó el 09/07/2026 — dos envíos a las 10:39 y 10:48). Fix:
  //   1) LockService serializa la sección crítica (chequeo + reserva del día).
  //   2) RESERVAMOS el día (seteamos PROP_KEY) ANTES de enviar, no después.
  //   3) Si el envío falla, revertimos la marca para reintentar en el próximo tick.
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(2000)) {
    Logger.log('Estado          : OTRA EJECUCIÓN EN CURSO (lock) — se omite para no duplicar');
    Logger.log('========================');
    return;
  }

  var yaEnviado;
  try {
    yaEnviado = (props.getProperty(PROP_KEY) === hoyStr);
    Logger.log('Último envío    : ' + (props.getProperty(PROP_KEY) || 'nunca'));
    Logger.log('¿Ya enviado hoy?: ' + (yaEnviado ? 'SÍ — se omite' : 'NO'));
    if (!yaEnviado) {
      props.setProperty(PROP_KEY, hoyStr);   // RESERVA: el próximo tick ya verá "hoy" y saldrá
    }
  } finally {
    lock.releaseLock();   // se libera ANTES del envío lento: no bloquea otras tareas del script
  }

  if (yaEnviado) {
    Logger.log('Estado          : YA ENVIADO HOY — se omite');
    Logger.log('========================');
    return;
  }

  Logger.log('Estado          : DENTRO DE VENTANA — enviando... (día ' + hoyStr + ' ya reservado)');

  var result;
  try {
    result = sendDailyEmail();
  } catch (err) {
    props.deleteProperty(PROP_KEY);   // rollback: ni terminó → permitir reintento en el próximo tick
    Logger.log('Resultado       : [ERROR] Excepción al enviar — ' + (err && err.message) + ' (reserva revertida)');
    Logger.log('========================');
    return;
  }

  if (result && result.ok) {
    Logger.log('Resultado       : [OK] Email enviado OK a ' + result.sent + ' destinatarios');
    Logger.log('Registrado      : fecha ' + hoyStr + ' confirmada en Properties');
  } else {
    props.deleteProperty(PROP_KEY);   // rollback: falló → permitir reintento en el próximo tick
    Logger.log('Resultado       : [ERROR] Error al enviar — ' + ((result && result.error) || 'desconocido') + ' (reserva revertida)');
  }

  Logger.log('========================');
}

// Estado del envío para mostrar en la página "Email": a qué hora sale el mail
// automático, a cuántos va, y si ya salió hoy. Sirve para que al guardar el
// mensaje se entienda cuándo y cómo se va a enviar.
function getEmailStatus() {
  var zona  = Session.getScriptTimeZone();
  var props = PropertiesService.getScriptProperties();
  var ultimo = props.getProperty(PROP_KEY) || '';
  var hoy = Utilities.formatDate(new Date(), zona, 'yyyy-MM-dd');
  var check = null;
  try {
    var res = _readSheetFast();
    if (res && res.payload) {
      check = verificarDatosActualizadosParaEmail(res.payload);
    }
  } catch(e) {
    check = { ok: false, motivo: 'Error verificando datos: ' + e.message };
  }
  var weekly = null;
  try {
    if (typeof getWeeklyEmailStatus === 'function') {
      weekly = getWeeklyEmailStatus();
    }
  } catch(eWk) {}

  return {
    hora:        HORA_ENVIO,
    minuto:      MINUTO_ENVIO,
    horaStr:     HORA_ENVIO + ':' + String(MINUTO_ENVIO).padStart(2, '0'),
    zona:        zona,
    recipients:  getEmailRecipients().length,
    ultimoEnvio: ultimo,
    enviadoHoy:  (ultimo === hoy),
    hasMessage:  getEmailMessage() !== '',
    executionsUrl: getExecutionsUrl(),
    dataCheck:   check,
    weekly:      weekly
  };
}

function setupTriggerEmail() {
  ['sendDailyEmail', 'checkYEnviarEmail'].forEach(handler => {
    ScriptApp.getProjectTriggers()
      .filter(t => t.getHandlerFunction() === handler)
      .forEach(t => ScriptApp.deleteTrigger(t));
  });
  ScriptApp.newTrigger('checkYEnviarEmail')
    .timeBased()
    .everyMinutes(10)
    .create();
  Logger.log('Trigger cada 10 min instalado.');
}

function forzarEnvioEmail() {
  PropertiesService.getScriptProperties().deleteProperty(PROP_KEY);
  sendDailyEmail(false, false, true); // force=true para saltar validación de fecha si el admin lo fuerza manualmente
  Logger.log('Envío forzado ejecutado.');
}

// Devuelve la lista completa de destinatarios con nombre y email para el panel de admins
function getRecipientsParaAdmin() {
  if (typeof _isEmailAdmin === 'function' && !_isEmailAdmin()) {
    throw new Error('Acceso denegado: solo administradores.');
  }
  var list = getEmailRecipients();
  return list.map(function(email) {
    var em = String(email || '').trim();
    return {
      email: em,
      name: (typeof _emailToName === 'function') ? _emailToName(em) : ''
    };
  });
}

// Envío forzado del Daily Report con exclusión de destinatarios desmarcados
function forzarEnvioDailyFiltrado(excluidos) {
  if (typeof _isEmailAdmin === 'function' && !_isEmailAdmin()) {
    throw new Error('Acceso denegado: solo administradores.');
  }
  excluidos = (excluidos || []).map(function(e){ return String(e).toLowerCase().trim(); });

  var todos = getEmailRecipients();
  var filtrados = todos.filter(function(e){
    return excluidos.indexOf(String(e).toLowerCase().trim()) === -1;
  });
  if (!filtrados.length) {
    return { ok: false, error: 'No se puede enviar: todos los destinatarios fueron desmarcados.' };
  }

  _FORCE_RECIPIENTS = filtrados;
  try {
    PropertiesService.getScriptProperties().deleteProperty(PROP_KEY);
    var res = sendDailyEmail(false, false, true); // force=true
    if (res && res.ok) {
      var zona = Session.getScriptTimeZone();
      var hoyStr = Utilities.formatDate(new Date(), zona, 'yyyy-MM-dd');
      PropertiesService.getScriptProperties().setProperty(PROP_KEY, hoyStr);
    }
    return res;
  } finally {
    _FORCE_RECIPIENTS = null;
  }
}

// ENVÍO DE PRUEBA: manda el email real (mismo contenido, gráficos y PDF que el
// envío masivo) SOLO a matias.cagliero@pedidosya.com — sin CCO al resto y con
// [PRUEBA] en el asunto. No toca el guard de envío diario (PROP_KEY), así que
// no interfiere con el envío real. Corré esta función desde el editor para
// revisar cómo llega el mail antes de mandarlo a toda la lista.
function enviarPruebaEmail(force) {
  const r = sendDailyEmail(false, true, !!force);   // previewMode=false, testMode=true
  Logger.log('Envío de PRUEBA → ' + JSON.stringify(r));
  return r;
}

function sendDailyEmail(previewMode, testMode, force) {
  const cache = CacheService.getScriptCache();
  cache.remove(CACHE_KEY + '_fast');
  cache.remove(CACHE_KEY + '_targets');
  cache.remove(CACHE_KEY + '_rr');
  cache.remove('cache_rrdata_mtd');   // RR fresco (mismo origen/datos que la página)

  const res = _readSheetFast();
  if (!res || res.error) {
    Logger.log("sendDailyEmail: error leyendo datos — " + (res?.error || 'No data'));
    return { ok:false, error: res?.error || 'No data' };
  }

  const payload = res.payload;
  let rows      = payload.rows || [];

  // Calcula d1Date desde BP1 aquí, antes de _readTargets, para que ambos
  // usen la misma fecha de referencia y el BE forecast sea consistente.
  const zona  = Session.getScriptTimeZone();
  const mesesEs = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
  let d1Date;
  if (payload.fechaReferencia) {
    const ref = new Date(payload.fechaReferencia);
    d1Date = new Date(Utilities.formatDate(ref, zona, "yyyy-MM-dd'T'12:00:00"));
  } else {
    const hoy = new Date(Utilities.formatDate(new Date(), zona, "yyyy-MM-dd'T'12:00:00"));
    d1Date = new Date(hoy); d1Date.setDate(hoy.getDate() - 1);
  }

  // ── Verificación de actualización de datos antes del envío ──────────────────
  // Si previewMode=false (envío real o de prueba) y no se fuerza explícitamente (force=true),
  // se valida que Confirmed Orders y GMV en Actuals estén al día con la fecha del daily.
  const checkFechas = verificarDatosActualizadosParaEmail(payload);
  if (!previewMode && !force && !checkFechas.ok) {
    Logger.log('[sendDailyEmail] ENVÍO CANCELADO: ' + checkFechas.motivo);
    return {
      ok: false,
      error: checkFechas.motivo,
      motivo: checkFechas.motivo,
      check: checkFechas
    };
  }

  const d8Date = new Date(d1Date); d8Date.setDate(d1Date.getDate() - 7);
  const d1Str  = `${d1Date.getDate()}-${mesesEs[d1Date.getMonth()]}`;
  const d8Str  = `${d8Date.getDate()}-${mesesEs[d8Date.getMonth()]}`;
  const d1Label = Utilities.formatDate(d1Date, zona, "dd 'de' MMMM 'de' yyyy");
  const subjectWithDate = "PedidosYa Market - Daily Report | " + d1Label;

  // freshRead=true: el mail lee los targets DE LA HOJA (sin caché). Se arma una
  // vez al día; así el BE del mail siempre es el vigente aunque la planilla de
  // targets se haya re-subido después de que alguna caché se calentara.
  const targets = _readTargets(d1Date, true);
  const rrData  = _getRRDataFromSheet(true);
  // "Cierre de mes": si el mes ya cerró (corte del RR = último día del mes), las
  // etiquetas de RR pasan a "Cierre de mes" (flag isMonthClose en Code.gs).
  const RR_CLOSE   = !!(rrData && rrData.meta && rrData.meta.isMonthClose);
  const RR_MES_LBL = RR_CLOSE ? 'CIERRE DE MES'       : 'RR MES';
  const RR_LM_LBL  = RR_CLOSE ? 'Cierre de mes vs LM' : 'RR vs LM';
  const RR_LY_LBL  = RR_CLOSE ? 'Cierre de mes vs LY' : 'RR vs LY';

  // LATAM del RR = suma SOLO de los países que se MUESTRAN (idéntico a la página:
  // applyRRData() poda RR a los países visibles y recalcula LATAM como su suma).
  // Antes el mail sumaba TODOS los países de rrData (incluidos los que el daily
  // no muestra) → el LATAM del mail no coincidía con el de la página.
  const visiblesRR = {};
  rows.forEach(r => { if (r.country) visiblesRR[r.country] = true; });
  ['orders', 'gmv'].forEach(kpi => {
    if (!rrData[kpi]) return;
    let sRr = 0, sBe = 0, sLy = 0, sAct = 0, sLmF = 0, sLyF = 0;
    let hasRr = false, hasBe = false, hasLy = false, hasLmF = false, hasLyF = false;
    Object.keys(rrData[kpi]).forEach(pais => {
      if (pais === 'LATAM') return;
      if (!visiblesRR[pais]) { delete rrData[kpi][pais]; return; }   // poda a visibles
      const e = rrData[kpi][pais]; if (!e) return;
      if (e.rr != null && !isNaN(e.rr)) { sRr += e.rr; hasRr = true; }
      if (e.be != null && !isNaN(e.be)) { sBe += e.be; hasBe = true; }
      if (e.ly != null && !isNaN(e.ly)) { sLy += e.ly; hasLy = true; }
      // Mes COMPLETO LM/LY (absolutos) para el RR vs LM / RR vs LY del LATAM.
      if (e.lmFull != null && !isNaN(e.lmFull)) { sLmF += e.lmFull; hasLmF = true; }
      if (e.lyFull != null && !isNaN(e.lyFull)) { sLyF += e.lyFull; hasLyF = true; }
      // Actual MTD por país (para Var vs LY): usa e.act; si no, lo deriva de ly y varLY.
      let actC = e.act;
      if (actC == null && e.ly != null && e.varLY != null) actC = e.ly * (1 + e.varLY / 100);
      if (actC != null) sAct += actC;
    });
    if (hasRr || hasBe || hasLy) {
      rrData[kpi]['LATAM'] = {
        rr:    hasRr ? sRr : null,
        be:    hasBe ? sBe : null,
        varBe: (hasRr && hasBe && sBe !== 0) ? ((sRr - sBe) / Math.abs(sBe)) * 100 : null,
        ly:    hasLy ? sLy : null,
        varLY: (hasLy && sLy !== 0) ? ((sAct - sLy) / Math.abs(sLy)) * 100 : null,
        lmFull: hasLmF ? sLmF : null,
        lyFull: hasLyF ? sLyF : null,
        rrVsLm: (hasRr && hasLmF && sLmF !== 0) ? ((sRr - sLmF) / Math.abs(sLmF)) * 100 : null,
        rrVsLy: (hasRr && hasLyF && sLyF !== 0) ? ((sRr - sLyF) / Math.abs(sLyF)) * 100 : null
      };
    }
  });

  const SECONDARY = ['new_users','wis','wis_uf','seamless','delivery_time','assignment_time_orders_over_6min','rejected_orders','session_orders'];
  SECONDARY.forEach(key => {
    const metRes = _readMetric(key);
    if (metRes && metRes.data) {
      rows.forEach(row => {
        const rowKey = `${row.warehouse_id}||${row.country}`;
        const d = metRes.data[rowKey];
        if (d) row[key] = { d1:d.d1, d8:d.d8, lw:d.lw, _raw:d._raw };
      });
    }
  });

  const grouped = _groupByCountry(rows, targets);

  const isSeamlessAvailable = grouped.some(g => g.seamless && g.seamless.d1 != null);
  const seamlessDependentMetrics = ['seamless'];

  Logger.log('LATAM orders   : ' + JSON.stringify(grouped.find(g => g.country === 'LATAM')?.orders));
  Logger.log('LATAM gmv      : ' + JSON.stringify(grouped.find(g => g.country === 'LATAM')?.gmv));
  Logger.log('rrData orders AR: ' + JSON.stringify(rrData.orders['AR']));
  Logger.log('rrData gmv AR   : ' + JSON.stringify(rrData.gmv['AR']));

  const ordersOrder = grouped
    .filter(g => g.country !== 'LATAM' && g.orders && g.orders.d1 != null)
    .sort((a, b) => (b.orders.d1 || 0) - (a.orders.d1 || 0))
    .map(g => g.country);

  const today = _todayLabel();

  // Mensaje personalizado (configurable desde la página "Email"). Si está
  // vacío, msgHtml queda '' y no se muestra ningún bloque en el mail.
  const msgInfo = (typeof getEmailMessageInfo === 'function')
    ? getEmailMessageInfo()
    : { msg: (typeof getEmailMessage === 'function' ? getEmailMessage() : ''), by: '', at: '' };
  const msgHtml = _buildMessageBlock(msgInfo.msg, msgInfo.by, msgInfo.at);

  // Gráficos MTD (Confirmed Orders + GMV).
  //  • Email (forPdf=false): barras HTML/CSS (se ven bien en Gmail).
  //  • PDF   (forPdf=true) : imagen PNG del gráfico hecha con el servicio Charts de
  //    GAS (nativo, sin servicio externo). El conversor NO renderiza las barras HTML
  //    apiladas (salían en blanco), pero sí un <img>. Si la imagen falla, cae a tabla.
  const chartsHtml    = _buildDailyChartsEmail(d1Date, false, rrData);
  const chartsHtmlPdf = _buildDailyChartsEmail(d1Date, true,  rrData);

  let heroHtml = '';        // Orders + GMV (12 columnas, grupos DÍA/SEMANA/MES)
  const secCards = [];      // métricas de operación (tarjetas de 5 columnas)

  const _pill = (val, m) => {
    if (val == null) return '<span class="p-null">—</span>';
    const good = m.higherGood ? val > 0 : val < 0;
    const bad  = m.higherGood ? val < 0 : val > 0;
    const cls  = good ? 'p-g' : bad ? 'p-b' : 'p-n';
    return `<span class="pill ${cls}">${_fmtVar(val, m.varFmt)}</span>`;
  };

  const _pillDirect = (val, m) => {
    if (val == null) return '<span class="p-null">—</span>';
    const good = m.higherGood ? val > 0 : val < 0;
    const bad  = m.higherGood ? val < 0 : val > 0;
    const cls  = good ? 'p-g' : bad ? 'p-b' : 'p-n';
    const s    = val > 0 ? '+' : '';
    return `<span class="pill ${cls}">${s}${val.toFixed(1)}%</span>`;
  };

  // Orden de filas: LATAM PRIMERO (es lo que más se mira), después países por volumen.
  const _sortLatamFirst = (a, b) => {
    if (a.country === 'LATAM') return -1;
    if (b.country === 'LATAM') return 1;
    const ia = ordersOrder.indexOf(a.country);
    const ib = ordersOrder.indexOf(b.country);
    return (ia === -1 ? 999 : ia) - (ib === -1 ? 999 : ib);
  };

  // "No disponible": si NINGÚN país tiene valor positivo en D-1 (todos en 0 o sin
  // dato), el dato del día todavía no había cargado al enviar (pasa sobre todo en
  // métricas de operaciones). En vez de una tabla de ceros / ocultarla, avisamos.
  const _naRows = (cols) => `
    <tr><td colspan="${cols}" style="padding:26px 20px;background:#fbfcfe;text-align:center;font-family:Arial,sans-serif;">
      <div style="margin-bottom:10px;"><svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#64748b" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="display:inline-block;"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg></div>
      <div style="font-size:13px;font-weight:700;color:#334155;letter-spacing:-.2px;margin-bottom:5px;">Esta métrica todavía no estaba disponible</div>
      <div style="font-size:11.5px;font-weight:400;color:#94a3b8;line-height:1.8;">
        El dato del día aún no había cargado al momento de enviar el mail.<br>
        Ingresá a la <b style="color:#e50044;font-weight:700;">versión web</b> para verla actualizada.
      </div>
    </td></tr>`;

  // ── Tablas HERO (Orders / GMV): 12 columnas con grupos DÍA | SEMANA | MES ──
  METRIC_DEFS.filter(m => !!m.beKey).forEach(m => {
    const accent = MET_COLORS[m.key] || '#64748b';
    const rows_ = grouped
      .map(g => ({ country: g.country, mv: g[m.key] }))
      .filter(r => r.mv && r.mv.d1 != null)
      .sort(_sortLatamFirst);

    const title = `<tr class="title-row"><td colspan="12" style="border-left:6px solid ${accent};"><span class="title-text">${m.label}</span></td></tr>`;

    if (!rows_.some(r => r.country !== 'LATAM' && r.mv.d1 > 0)) {
      heroHtml += `<table class="tb" cellpadding="0" cellspacing="0" border="0">${title}${_naRows(12)}</table>`;
      return;
    }

    let rowsHtml = '';
    let zi = 0;
    rows_.forEach(r => {
      const mv     = r.mv;
      const beVal  = mv.be;
      const varD8  = _calcVar(mv.d1, mv.d8, m.varFmt);
      const varBE  = beVal != null ? _calcVar(mv.d1, beVal, m.varFmt) : null;
      const varLW  = mv.lw != null
        ? _calcVar(mv.d1, m.lwIsRatio ? mv.lw : mv.lw / 3, m.varFmt)
        : null;
      const rrEntry = rrData[m.key] ? rrData[m.key][r.country] : null;
      const isLat   = r.country === 'LATAM';
      // LATAM resaltada; el resto con zebra suave para seguir la fila con la vista.
      const trAttr  = isLat ? ' class="lat"' : ((zi++ % 2) ? ' class="z"' : '');
      rowsHtml += `<tr${trAttr}>
        <td class="td-n">${FULL_COUNTRY_NAMES[r.country] || r.country}</td>
        <td class="td-v">${_fmtV(mv.d1, m.fmt)}</td>
        <td class="td-be">${beVal != null ? _fmtV(beVal, m.fmt) : '—'}</td>
        <td class="td-p">${_pill(varBE, m)}</td>
        <td class="td-8 bl">${_fmtV(mv.d8, m.fmt)}</td>
        <td class="td-p">${_pill(varD8, m)}</td>
        <td class="td-p">${_pill(varLW, m)}</td>
        <td class="td-8 bl">${_fmtV(rrEntry ? rrEntry.rr : null, m.fmt)}</td>
        <td class="td-8">${_fmtV(rrEntry ? rrEntry.be : null, m.fmt)}</td>
        <td class="td-p">${_pillDirect(rrEntry ? rrEntry.varBe : null, m)}</td>
        <td class="td-p bl">${_pillDirect(rrEntry ? rrEntry.rrVsLm : null, m)}</td>
        <td class="td-p">${_pillDirect(rrEntry ? rrEntry.rrVsLy : null, m)}</td>
      </tr>`;
    });

    // Grupos IGUALES a los de la página Daily: DAILY BE05 | VS D-8 | RR MES | RR VS HIST.
    heroHtml += `
      <table class="tb" cellpadding="0" cellspacing="0" border="0">
        ${title}
        <tr>
          <td colspan="2" style="background:#f8fafc;"></td>
          <td colspan="2" class="gh gh-be">DAILY ${BE_LABEL}</td>
          <td colspan="3" class="gh gh-w">VS ${d8Str}</td>
          <td colspan="3" class="gh gh-rr">${RR_CLOSE ? 'CIERRE DE MES' : 'RR MES'}</td>
          <td colspan="2" class="gh gh-h">${RR_CLOSE ? 'CIERRE DE MES VS HIST.' : 'RR VS HIST.'}</td>
        </tr>
        <tr>
          <th class="th-l">PAÍS</th>
          <th class="th-c">${d1Str}</th>
          <th class="th-c gbe">${BE_LABEL}</th>
          <th class="th-c gbe">VAR</th>
          <th class="th-c bl">${d8Str}</th>
          <th class="th-c">VAR D-8</th>
          <th class="th-c">VAR L3W</th>
          <th class="th-c bl">${RR_CLOSE ? 'CIERRE' : 'RR'}</th>
          <th class="th-c">${BE_LABEL} MES</th>
          <th class="th-c">VAR</th>
          <th class="th-c bl">VS LM</th>
          <th class="th-c">VS LY</th>
        </tr>
        ${rowsHtml}
      </table>`;
  });

  // ── Métricas de OPERACIÓN: tarjetas de 5 columnas (después van de a 2 por fila) ──
  METRIC_DEFS.filter(m => !m.beKey && m.key !== 'assignment_time').forEach(m => {
    const accent = MET_COLORS[m.key] || '#64748b';
    const rows_ = grouped
      .map(g => ({ country: g.country, mv: g[m.key] }))
      .filter(r => r.mv && r.mv.d1 != null)
      .sort(_sortLatamFirst);

    const head = `<tr><td colspan="5" class="c-h"><span style="display:inline-block;width:8px;height:8px;border-radius:2px;background:${accent};margin-right:7px;"></span>${m.label}</td></tr>`;

    let isNa = false;
    if (seamlessDependentMetrics.includes(m.key) && !isSeamlessAvailable) {
      isNa = true;
    } else {
      isNa = !rows_.some(r => r.country !== 'LATAM' && r.mv.d1 > 0);
      const activeCountries = rows_.filter(r => r.country !== 'LATAM');
      if (m.key === 'session_orders' && activeCountries.length > 0 && activeCountries.every(r => r.mv.d1 == null || r.mv.d1 < 1)) {
        isNa = true;
      }
    }

    if (isNa) {
      secCards.push(`<table class="tbc" cellpadding="0" cellspacing="0" border="0">${head}${_naRows(5)}</table>`);
      return;
    }

    let rowsHtml = '';
    let zi = 0;
    rows_.forEach(r => {
      const mv    = r.mv;
      const varD8 = _calcVar(mv.d1, mv.d8, m.varFmt);
      const varLW = mv.lw != null
        ? _calcVar(mv.d1, m.lwIsRatio ? mv.lw : mv.lw / 3, m.varFmt)
        : null;
      const isLat  = r.country === 'LATAM';
      const trAttr = isLat ? ' class="lat"' : ((zi++ % 2) ? ' class="z"' : '');
      rowsHtml += `<tr${trAttr}>
        <td class="td-n">${FULL_COUNTRY_NAMES[r.country] || r.country}</td>
        <td class="td-v">${_fmtV(mv.d1, m.fmt)}</td>
        <td class="td-8">${_fmtV(mv.d8, m.fmt)}</td>
        <td class="td-p">${_pill(varD8, m)}</td>
        <td class="td-p">${_pill(varLW, m)}</td>
      </tr>`;
    });

    secCards.push(`<table class="tbc" cellpadding="0" cellspacing="0" border="0">
      ${head}
      <tr><th class="th-l">PAÍS</th><th class="th-c">${d1Str}</th><th class="th-c">${d8Str}</th><th class="th-c">VS D-8</th><th class="th-c">VS L3W</th></tr>
      ${rowsHtml}
    </table>`);
  });

  // De a 2 por fila. En pantallas chicas los .half se apilan (media query del <style>);
  // Outlook ignora la media query y las muestra lado a lado (el mail es de 960px, entra).
  let secHtml = '';
  for (let i = 0; i < secCards.length; i += 2) {
    secHtml += `<table width="100%" cellpadding="0" cellspacing="0" border="0" style="margin-bottom:12px;"><tr>
      <td class="half" width="49%" valign="top">${secCards[i]}</td>
      <td class="hgap" width="2%">&nbsp;</td>
      <td class="half" width="49%" valign="top">${secCards[i + 1] || '&nbsp;'}</td>
    </tr></table>`;
  }

  // ── Resumen LATAM (arriba de todo): Orders D-1 · GMV D-1 · RR mes Orders ──
  const gLat  = grouped.find(g => g.country === 'LATAM') || {};
  const mOrd  = METRIC_DEFS.find(m => m.key === 'orders');
  const mGmvD = METRIC_DEFS.find(m => m.key === 'gmv');
  const rrLatO = (rrData.orders && rrData.orders['LATAM']) ? rrData.orders['LATAM'] : null;
  const rrLatG = (rrData.gmv && rrData.gmv['LATAM']) ? rrData.gmv['LATAM'] : null;
  const _sumCard = (label, val, pillHtml, sub) => `
    <td class="sc" width="24%" valign="top">
      <div style="font-size:10px;font-weight:700;color:#94a3b8;text-transform:uppercase;letter-spacing:.4px;">${label}</div>
      <div style="font-size:20px;font-weight:800;color:#0f172a;letter-spacing:-.5px;margin:3px 0;white-space:nowrap;">${val}</div>
      <div>${pillHtml} <span style="font-size:10px;color:#94a3b8;">${sub}</span></div>
    </td>`;
  let summaryHtml = '';
  if (gLat.orders && gLat.orders.d1 != null) {
    const vO = gLat.orders.be != null ? _calcVar(gLat.orders.d1, gLat.orders.be, mOrd.varFmt) : null;
    const vG = (gLat.gmv && gLat.gmv.d1 != null && gLat.gmv.be != null) ? _calcVar(gLat.gmv.d1, gLat.gmv.be, mGmvD.varFmt) : null;
    const rrLbl = RR_CLOSE ? 'Cierre de mes' : 'RR mes';
    summaryHtml = `
      <div class="sect" style="border-top:none;padding-top:0;margin-top:0;">RESUMEN LATAM · AYER</div>
      <table width="100%" cellpadding="0" cellspacing="0" border="0" style="margin-bottom:18px;"><tr>
        ${_sumCard('Orders D-1', _fmtV(gLat.orders.d1, mOrd.fmt), _pill(vO, mOrd), 'vs ' + BE_LABEL)}
        <td width="6">&nbsp;</td>
        ${_sumCard('GMV D-1', (gLat.gmv && gLat.gmv.d1 != null) ? _fmtV(gLat.gmv.d1, mGmvD.fmt) : '—', _pill(vG, mGmvD), 'vs ' + BE_LABEL)}
        <td width="6">&nbsp;</td>
        ${_sumCard(rrLbl + ' Orders', (rrLatO && rrLatO.rr != null) ? _fmtV(rrLatO.rr, mOrd.fmt) : '—', _pillDirect(rrLatO ? rrLatO.varBe : null, mOrd), 'vs BE mes')}
        <td width="6">&nbsp;</td>
        ${_sumCard(rrLbl + ' GMV', (rrLatG && rrLatG.rr != null) ? _fmtV(rrLatG.rr, mGmvD.fmt) : '—', _pillDirect(rrLatG ? rrLatG.varBe : null, mGmvD), 'vs BE mes')}
      </tr></table>`;
  }

  // El mail YA NO es un solo link gigante (tocarlo sin querer en el celular te
  // sacaba del mail y no se podía copiar un número): el link al dashboard vive
  // en el botón del header y en el del pie, siempre con ?src=mail (analytics).
  const buildBody = (chartsBlock, messageBlock) => `<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<style>
  *,*:before,*:after { box-sizing:border-box; }
  body { background:#e2e8f0; padding:20px 8px; font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Arial,sans-serif; margin:0; width:100% !important; -webkit-text-size-adjust:100%; -ms-text-size-adjust:100%; }
  .wrp { width:100% !important; max-width:840px !important; margin:0 auto; background:#ffffff; border-radius:12px; overflow:hidden; border:1px solid #cbd5e1; }
  table, img { max-width:100%; }
  .header { padding:14px 18px; border-bottom:3px solid #e50044; background:#ffffff; }
  .content { padding:15px 16px; background:#f8fafc; }
  .footer { padding:15px 14px; text-align:center; background:#ffffff; border-top:1px solid #e2e8f0; }
  .btn { display:inline-block; background:#e50044; color:#ffffff !important; font-size:11px; font-weight:700; padding:8px 16px; border-radius:6px; text-decoration:none; }
  .sect { font-size:9.5px; font-weight:800; letter-spacing:.5px; color:#94a3b8; margin:14px 0 8px; border-top:1px solid #e2e8f0; padding-top:10px; }
  .sc { background:#ffffff; border:1px solid #cbd5e1; border-radius:8px; padding:8px 10px; }
  .tb { width:100%; border-collapse:collapse; margin-bottom:12px; border-radius:8px; overflow:hidden; background:#ffffff; border:1px solid #cbd5e1; }
  .tbc { width:100%; border-collapse:collapse; background:#ffffff; border:1px solid #cbd5e1; border-radius:8px; overflow:hidden; }
  .title-row td { padding:10px 14px; background:#ffffff; border-bottom:1px solid #e2e8f0; }
  .title-text { font-size:11px; font-weight:800; text-transform:uppercase; color:#0f172a; }
  .c-h { padding:10px 14px; background:#fbfcfe; border-bottom:1px solid #e2e8f0; font-size:10px; font-weight:800; text-transform:uppercase; letter-spacing:.3px; color:#0f172a; text-align:left; }
  .gh { padding:5px 3px; font-size:8px; font-weight:800; letter-spacing:.4px; text-align:center; }
  .gh-be { background:#f5f3ff; color:#7c3aed; border-bottom:2px solid #ddd6fe; }
  .gh-w  { background:#f8fafc; color:#64748b; border-bottom:2px solid #e2e8f0; }
  .gh-rr { background:#faf5ff; color:#a78bfa; border-bottom:2px solid #ede9fe; }
  .gh-h  { background:#fff7ed; color:#ea7317; border-bottom:2px solid #fed7aa; }
  .gbe { background:#f5f3ff; color:#7c3aed; }
  .th-l { padding:7px 5px; font-size:8px; font-weight:700; color:#64748b; text-align:left; letter-spacing:.2px; border-bottom:1px solid #e2e8f0; background:#f1f5f9; }
  .th-c { padding:7px 5px; font-size:8px; font-weight:700; color:#64748b; text-align:center; letter-spacing:.2px; border-bottom:1px solid #e2e8f0; background:#f1f5f9; }
  .td-n  { padding:6px 5px; border-bottom:1px solid #f1f5f9; font-size:9.5px; color:#1e293b; font-weight:500; white-space:nowrap; text-align:left; }
  .td-v  { padding:6px 5px; border-bottom:1px solid #f1f5f9; text-align:center; font-size:9.5px; font-weight:700; color:#0f172a; white-space:nowrap; }
  .td-be { padding:6px 5px; border-bottom:1px solid #f1f5f9; text-align:center; font-size:9px; font-weight:500; color:#334155; white-space:nowrap; }
  .td-8  { padding:6px 5px; border-bottom:1px solid #f1f5f9; text-align:center; font-size:9px; font-weight:500; color:#64748b; white-space:nowrap; }
  .td-p  { padding:6px 5px; border-bottom:1px solid #f1f5f9; text-align:center; }
  .tb th:first-child, .tb td:first-child, .tbc th:first-child, .tbc td:first-child { padding-left: 10px !important; }
  .tb th:last-child, .tb td:last-child, .tbc th:last-child, .tbc td:last-child { padding-right: 10px !important; }
  .bl { border-left:1px solid #e2e8f0; }
  .lat td { background:#fff7f9; border-bottom:2px solid #f0c9d4; font-weight:bold; }
  .pill { display:inline-block; font-size:9px; font-weight:700; padding:1px 4px; border-radius:20px; min-width:35px; }
  .p-g { background:#e8f7ef; color:#0f7a46; }
  .p-b { background:#fdeaee; color:#c01945; }
  .p-n { background:#f4f6f8; color:#5f6b7a; }
  .p-null { color:#cbd5e1; font-style:italic; font-size:9.5px; }
  @media only screen and (max-width:620px) {
    .half { display:block !important; width:100% !important; padding-bottom:12px; }
    .hgap { display:none !important; }
  }
  .sg { font-size:0; mso-line-height-rule:exactly; }
  .sl { font-family:Arial,sans-serif; font-size:7.5px; font-weight:800; color:#ffffff; white-space:nowrap; mso-line-height-rule:exactly; text-align:center; vertical-align:middle; }
  .bcw { padding:0 1.5px; }
  .cxd { font-family:Arial,sans-serif; font-size:8px; color:#334155; font-weight:700; padding-top:5px; text-align:center; }
  .cxt { font-family:Arial,sans-serif; font-size:7px; color:#94a3b8; font-weight:600; white-space:nowrap; padding-top:1px; text-align:center; }
  .cxa { font-family:Arial,sans-serif; font-size:7.5px; color:#0f172a; font-weight:800; white-space:nowrap; padding-top:2.5px; text-align:center; }
  .cxv { font-family:Arial,sans-serif; font-size:7.5px; font-weight:700; white-space:nowrap; padding-top:1.5px; text-align:center; }
  .z { background:#fbfcfe; }
</style>
</head>
<body>
  <div class="wrp">
    <table width="100%" cellpadding="0" cellspacing="0" border="0">
      <tr><td class="header">
        <table width="100%" cellpadding="0" cellspacing="0" border="0"><tr>
          <td>
            <div style="font-size:18px;font-weight:800;color:#0f172a;">Daily Report <span style="color:#e50044;">PeYa Markets</span></div>
            <div style="font-size:12px;color:#94a3b8;margin-top:2px;">${d1Label} · D-1</div>
          </td>
          <td align="right" valign="middle"><a href="${APP_URL}?src=mail" target="_blank" class="btn">Ver dashboard →</a></td>
        </tr></table>
      </td></tr>
      <tr><td class="content">
        ${messageBlock || ''}
        ${summaryHtml}
        ${heroHtml}
        <div class="sect">MÉTRICAS DE OPERACIÓN</div>
        ${secHtml}
        <div class="sect">GRÁFICOS · MTD LATAM</div>
        ${chartsBlock}
      </td></tr>
      <tr><td class="footer">
        <a href="${APP_URL}?src=mail" target="_blank" class="btn">Abrir dashboard interactivo →</a>
        <div style="font-size:10px;color:#94a3b8;margin-top:10px;">D-1 = ayer &nbsp;·&nbsp; D-8 = hace 8 días &nbsp;·&nbsp; L3W = promedio del mismo día en las últimas 3 semanas &nbsp;·&nbsp; ${RR_CLOSE ? 'Cierre de mes = valor del mes ya cerrado' : 'RR = proyección de cierre de mes'}</div>
      </td></tr>
    </table>
  </div>
</body>
</html>`;

  // Minificamos el HTML (saca saltos de línea + indentación, que es el grueso
  // del peso) para que el mail NO supere el límite de Gmail (~102KB) y no se
  // recorte ("[Mensaje recortado]" cortaba el gráfico de GMV). No quita datos.
  const htmlBody    = _minifyEmailHtml(buildBody(chartsHtml, msgHtml));     // email: barras + valores
  const htmlBodyPdf = _minifyEmailHtml(buildBody(chartsHtmlPdf, msgHtml));  // PDF: KPIs + tabla diaria
  Logger.log('Tamaño HTML del mail: ' + Math.round(htmlBody.length / 1024) + ' KB (Gmail recorta > ~102 KB)');

  // ── Generar PDF adjunto (sin Drive, via API externa) ─────────────
  const pdfTitle = 'PeYa Daily Report ' + d1Label;
  const pdfBlob  = _generatePdfFromHtml(htmlBodyPdf, pdfTitle);
  if (pdfBlob) {
    Logger.log('PDF generado: ' + pdfBlob.getName() + ' (' + pdfBlob.getBytes().length + ' bytes)');
  } else {
    Logger.log('PDF: no se pudo generar (se enviará solo HTML)');
  }

  // ── Modo PREVIEW: no envía; guarda el HTML del email (con los gráficos,
  //    SIN tabla) y el PDF en tu Drive para que los veas tal cual se mandan. ─
  if (previewMode) {
    const folderName = 'PeYa Email Preview';
    const it = DriveApp.getFoldersByName(folderName);
    const folder = it.hasNext() ? it.next() : DriveApp.createFolder(folderName);
    const htmlFile = folder.createFile('preview_email_' + d1Label + '.html', htmlBody, MimeType.HTML);
    let pdfUrl = '(no se generó)';
    if (pdfBlob) pdfUrl = folder.createFile(pdfBlob).getUrl();
    Logger.log('───────── PREVIEW (no se envió) ─────────');
    Logger.log('HTML del email: ' + htmlFile.getUrl());
    Logger.log('PDF adjunto   : ' + pdfUrl);
    Logger.log('Abrí el HTML en el navegador: los valores van EN el gráfico, sin tabla debajo.');
    return { ok:true, preview:true, htmlUrl:htmlFile.getUrl(), pdfUrl:pdfUrl };
  }

  // testMode: envío de PRUEBA → un único destinatario (matias.cagliero), con [PRUEBA].
  const TEST_RECIPIENT = 'matias.cagliero@pedidosya.com';
  if (testMode) {
    MailApp.sendEmail({
      to:          TEST_RECIPIENT,
      subject:     '[PRUEBA] ' + subjectWithDate,
      htmlBody:    htmlBody,
      attachments: pdfBlob ? [pdfBlob] : [],
      name:        'PeYa Market Performance - Regional'
    });
    Logger.log("Email de PRUEBA enviado SOLO a: " + TEST_RECIPIENT);
    _logEnvioLote('prueba', '[PRUEBA] ' + subjectWithDate, 1, 1, TEST_RECIPIENT, [TEST_RECIPIENT]);
    return { ok:true, test:true, sent:1, to:TEST_RECIPIENT };
  }

  // Envío masivo: destinatarios en COPIA OCULTA (CCO) y EN LOTES. Gmail limita la
  // cantidad de destinatarios por mensaje; con los 118 en un solo mensaje tiraba
  // "Limit Exceeded: Email Recipients Per Message". _sendEmailBccBatched parte la
  // lista en lotes chicos (cada lote = un mensaje, 'to' = remitente, resto en CCO).
  const batches = _sendEmailBccBatched({
    tipo:        'daily',
    subject:     subjectWithDate,
    htmlBody:    htmlBody,
    attachments: pdfBlob ? [pdfBlob] : []
  });
  var _nDest = getEmailRecipients().length;
  Logger.log("Email enviado (CCO) en " + batches + " lote(s) a " + _nDest + " destinatarios.");

  // Si el mensaje estaba marcado como "un solo envío", se borra automáticamente
  if (batches > 0) {
    try {
      var _p = PropertiesService.getScriptProperties();
      if (_p.getProperty('EMAIL_CUSTOM_MSG_ONCE') === 'true') {
        _p.deleteProperty('EMAIL_CUSTOM_MSG');
        _p.deleteProperty('EMAIL_CUSTOM_MSG_BY');
        _p.deleteProperty('EMAIL_CUSTOM_MSG_AT');
        _p.deleteProperty('EMAIL_CUSTOM_MSG_ONCE');
        Logger.log('[sendDailyEmail] Mensaje de un solo uso eliminado tras el envío.');
      }
    } catch (_eOnce) {}
  }

  return { ok:true, sent:_nDest, batches:batches };
}

// Dirección que aparece en "Para:" en los envíos masivos (los destinatarios reales
// van TODOS en copia oculta). Si la dejás en '', se usa el remitente (quien dispara
// el envío) — pero como el envío va en lotes, esa persona recibe 1 copia por lote.
// Poné acá una casilla tipo 'noreply@pedidosya.com' para que cada persona reciba
// UNA SOLA copia (incluido vos) y nadie se vea entre sí.
var EMAIL_VISIBLE_TO = '';

// Envía un mismo mail con los destinatarios (getEmailRecipients — del sheet) en COPIA OCULTA, EN LOTES,
// para no superar el límite de destinatarios por mensaje de Gmail (con muchos en un
// solo mensaje tira "Limit Exceeded: Email Recipients Per Message"). Deduplica la
// lista y SACA del CCO a la dirección que va en "Para" (así no manda copia doble a
// esa persona). Lo usan el diario y el semanal. Devuelve la cantidad de lotes.
function _sendEmailBccBatched(opts) {
  var BATCH = 45;   // máx. CCO por mensaje (margen holgado bajo el límite de Gmail)
  // "Para" visible OPCIONAL: si se define EMAIL_VISIBLE_TO (ej. un noreply@), se usa
  // como "Para" en TODOS los lotes. Si queda vacío, se manda SOLO con CCO (sin "Para").
  //
  // Por qué: antes el "Para" era el remitente (matías) y, como hay varios lotes, recibía
  // UNA copia POR LOTE (el bug de "me llega 3 veces" = 3 lotes). Con CCO puro, cada
  // persona —incluido el remitente— aparece una sola vez en un solo lote → 1 copia.
  var visibleTo = String(EMAIL_VISIBLE_TO || '').trim();
  var vt = visibleTo.toLowerCase();
  // Dedup. Si hay "Para" dedicado, lo sacamos del CCO (ya recibe como "Para"). Si NO
  // hay "Para", NO excluimos a nadie: el remitente va como un CCO más (1 sola copia).
  var seen = {};
  var recips = getEmailRecipients().filter(function(e){
    var k = String(e || '').trim().toLowerCase();
    if (!k || seen[k]) return false;
    if (vt && k === vt) return false;
    seen[k] = true;
    return true;
  });
  if (!recips.length) {
    Logger.log('[AVISO] _sendEmailBccBatched: 0 destinatarios (el sheet falló o EMAIL_TO vacío) → NO se envía nada.');
    return 0;
  }
  var total = Math.max(1, Math.ceil(recips.length / BATCH));
  var n = 0;
  for (var i = 0; i < recips.length; i += BATCH) {
    var chunk = recips.slice(i, i + BATCH);
    n++;
    var msg = {
      bcc:         chunk.join(','),
      subject:     opts.subject,
      htmlBody:    opts.htmlBody,
      attachments: opts.attachments || [],
      name:        opts.name || 'PeYa Market Performance - Regional'
    };
    if (visibleTo) msg.to = visibleTo;   // "Para" solo si hay casilla dedicada
    MailApp.sendEmail(msg);
    _logEnvioLote(opts.tipo || 'daily', opts.subject, n, total, visibleTo || '(solo CCO)', chunk);
  }
  return n;
}

// Hoja "Envios" (en ANALYTICS_SS_ID) donde se registra cada lote enviado, para
// auditar después a quién se le mandó. Se crea sola la primera vez, con encabezados.
var ENVIO_LOG_SHEET = 'Envios';
function _enviosSheet() {
  var ss = SpreadsheetApp.openById(ANALYTICS_SS_ID);
  var sh = ss.getSheetByName(ENVIO_LOG_SHEET);
  if (!sh) {
    sh = ss.insertSheet(ENVIO_LOG_SHEET);
    sh.appendRow(['Fecha', 'Tipo', 'Asunto', 'Lote', 'Para (To)', 'Cant. CCO', 'Destinatarios (CCO)']);
    sh.setFrozenRows(1);
  }
  return sh;
}

// Registra un lote: lo loguea en la consola Y lo guarda como fila en la hoja "Envios".
function _logEnvioLote(tipo, subject, loteNum, totalLotes, visibleTo, chunk) {
  var lista = chunk.join(', ');
  Logger.log('  [MAIL] Lote ' + loteNum + '/' + totalLotes + ' [' + tipo + '] → Para: ' + visibleTo +
             ' | CCO (' + chunk.length + '): ' + lista);
  try {
    _enviosSheet().appendRow([
      new Date(), tipo, subject || '', loteNum + '/' + totalLotes, visibleTo, chunk.length, lista
    ]);
  } catch (e) {
    Logger.log('  [AVISO] No se pudo registrar el lote en la hoja "Envios": ' + e.message);
  }
}

// Genera el email SIN enviarlo y lo guarda en tu Drive (carpeta "PeYa Email
// Preview"). Corré esto en el editor y abrí el HTML que se loguea para ver
// exactamente cómo queda: los valores están dentro del gráfico, sin tabla.
function previewDailyEmail() {
  const r = sendDailyEmail(true);
  Logger.log(JSON.stringify(r, null, 2));
  return r;
}

// =================================================================
// PDF — HTML → PDF
// Método 1 (preferido): conversión directa con Utilities/getAs — NO requiere
//   el servicio avanzado Drive API (era la causa de que el PDF no se adjuntara:
//   el código viejo usaba Drive.Files.create, sintaxis v3, que no existe si el
//   servicio Drive está habilitado como v2 → tiraba error y devolvía null).
// Método 2 (fallback): Doc temporal vía Drive API, autodetectando v2/v3.
// =================================================================
function _generatePdfFromHtml(htmlContent, title) {
  const safeName = title.replace(/[\\/:*?"<>|]/g, '_');

  // El mail mide hasta ~960px de ancho (diario) / 860px (semanal); en A4 vertical
  // (~793px útiles) se corta a la derecha. Inyectamos un tamaño de página A MEDIDA
  // (más ancho que A4, no es A4) para que entre completo. La altura pagina normal;
  // evitamos partir filas de tabla y tarjetas entre páginas.
  const _pageCss = '<style>@page{size:280mm 297mm;margin:6mm;}tr,.card{page-break-inside:avoid;}</style>';
  const _html = (htmlContent.indexOf('</head>') >= 0)
    ? htmlContent.replace('</head>', _pageCss + '</head>')
    : _pageCss + htmlContent;

  // ── Método 1: conversión directa HTML→PDF (sin Drive API) ──────────
  try {
    const htmlBlob = Utilities.newBlob(_html, MimeType.HTML, safeName + '.html');
    const pdf = htmlBlob.getAs(MimeType.PDF).setName(safeName + '.pdf');
    if (pdf && pdf.getBytes().length > 0) {
      Logger.log('PDF (getAs) OK: ' + pdf.getBytes().length + ' bytes');
      return pdf;
    }
    Logger.log('PDF (getAs): blob vacío, probando fallback Drive...');
  } catch (e1) {
    Logger.log('PDF (getAs) falló: ' + e1.message + ' — probando fallback Drive...');
  }

  // ── Método 2 (fallback): Drive API → Doc temporal → export → delete ─
  if (typeof Drive === 'undefined' || !Drive.Files) {
    Logger.log('PDF: servicio avanzado "Drive API" no habilitado. ' +
               'Activalo en el editor (Servicios → Drive API) si querés el fallback. Se envía sin PDF.');
    return null;
  }
  let docId = null;
  try {
    const htmlBlob = Utilities.newBlob(_html, MimeType.HTML, safeName);
    let file;
    if (typeof Drive.Files.create === 'function') {        // Drive API v3
      file = Drive.Files.create({ name: '__peya_pdf_tmp', mimeType: MimeType.GOOGLE_DOCS }, htmlBlob);
    } else if (typeof Drive.Files.insert === 'function') { // Drive API v2
      file = Drive.Files.insert({ title: '__peya_pdf_tmp', mimeType: MimeType.GOOGLE_DOCS }, htmlBlob);
    } else {
      Logger.log('PDF: Drive.Files no tiene create ni insert — versión desconocida.');
      return null;
    }
    docId = file.id;
    const token = ScriptApp.getOAuthToken();
    const exportResp = UrlFetchApp.fetch(
      'https://www.googleapis.com/drive/v3/files/' + docId + '/export?mimeType=application/pdf',
      { headers: { 'Authorization': 'Bearer ' + token }, muteHttpExceptions: true }
    );
    if (exportResp.getResponseCode() !== 200) {
      Logger.log('PDF (Drive): error exportando (' + exportResp.getResponseCode() + '): ' + exportResp.getContentText().slice(0, 300));
      return null;
    }
    const pdfBlob = exportResp.getBlob().setName(safeName + '.pdf');
    Logger.log('PDF (Drive) OK: ' + pdfBlob.getBytes().length + ' bytes');
    return pdfBlob;
  } catch (e2) {
    Logger.log('PDF (Drive) error: ' + e2.message);
    return null;
  } finally {
    if (docId) {
      try {
        if (typeof Drive.Files.remove === 'function') Drive.Files.remove(docId);
        else if (typeof Drive.Files.trash === 'function') Drive.Files.trash(docId);
      } catch (e3) { Logger.log('PDF: no se pudo borrar Doc temporal — ' + e3.message); }
    }
  }
}

// Test manual: corré esto en el editor para verificar la generación del PDF.
// Crea un PDF de prueba en tu Drive y loguea el tamaño. Si falla, el log dice por qué.
function testPdfGeneration() {
  var html = '<html><body><h1>Test PDF PeYa</h1><p>Si ves esto, la conversión HTML→PDF funciona.</p>' +
             '<table border="1" cellpadding="6"><tr><th>País</th><th>Orders</th></tr>' +
             '<tr><td>Argentina</td><td>45.200</td></tr><tr><td>Chile</td><td>28.400</td></tr></table></body></html>';
  var pdf = _generatePdfFromHtml(html, 'Test PeYa PDF');
  if (pdf) {
    var f = DriveApp.createFile(pdf);
    Logger.log('[OK] PDF de prueba generado: ' + pdf.getBytes().length + ' bytes. Guardado en Drive: ' + f.getUrl());
  } else {
    Logger.log('[ERROR] No se pudo generar el PDF. Revisá los logs de arriba para ver el motivo.');
  }
}

// =================================================================
// GRÁFICOS MTD EN EL MAIL (barras HTML/CSS — sin imágenes ni JS)
// =================================================================
// Replica los 2 gráficos de "Gráfico vs Target" con barras diarias:
//   verde si el día ≥ target, rojo si < target, gris si sin target.
// El target de cada día se marca con una línea oscura dentro de la barra.
// Técnica: tablas apiladas de alto fijo (sin position, que Gmail elimina).
function _buildDailyChartsEmail(d1Date, forPdf, rrData, rangeOpt) {
  try {
    var cd = (typeof fetchDailyCharts === 'function') ? fetchDailyCharts() : null;
    if (!cd || cd.error || !cd.records || !cd.records.length) return '';

    var tz   = Session.getScriptTimeZone();
    var ym   = Utilities.formatDate(d1Date, tz, 'yyyy-MM');
    var d1Day = parseInt(Utilities.formatDate(d1Date, tz, 'd'), 10);
    var mesesFull = ['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];
    var mesLabel = mesesFull[d1Date.getMonth()];
    // Texto de período opcional (el mail semanal pasa el rango de la semana cerrada).
    var periodOverride = (rangeOpt && rangeOpt.periodTxt) ? rangeOpt.periodTxt : null;

    // Agregar LATAM por día (suma de países). Por defecto: mes en curso hasta D-1.
    // Con rangeOpt: solo los días dentro de [startMs, endMs] (semana cerrada),
    // keyed por timestamp para soportar semanas que cruzan de mes.
    var byDay = {};
    cd.records.forEach(function(r){
      if (r.c === 'LATAM') return;   // LATAM ya es la suma de países → evita duplicar
      var dayNum = parseInt(Utilities.formatDate(new Date(r.d), tz, 'd'), 10);
      var moNum  = parseInt(Utilities.formatDate(new Date(r.d), tz, 'M'), 10);
      var key;
      if (rangeOpt) {
        if (r.d < rangeOpt.startMs || r.d > rangeOpt.endMs) return;
        key = r.d;
      } else {
        if (r.m !== ym) return;
        if (dayNum > d1Day) return;
        key = dayNum;
      }
      if (!byDay[key]) byDay[key] = { day:dayNum, mo:moNum, k:key, o:null, g:null, tarO:0, tarG:0 };
      if (r.o != null) byDay[key].o = (byDay[key].o || 0) + r.o;
      if (r.g != null) byDay[key].g = (byDay[key].g || 0) + r.g;
      if (r.tarO != null) byDay[key].tarO += r.tarO;
      if (r.tarG != null) byDay[key].tarG += r.tarG;
    });
    var days = Object.keys(byDay).map(function(k){ return byDay[k]; }).sort(function(a,b){ return a.k - b.k; });
    if (!days.length) return '';

    var H = 132; // alto del área de barras en px

    // Un segmento vertical de color y alto fijo (trick email-safe).
    // 'extra' permite agregar estilo (p.ej. redondeo del tope de la barra).
    function seg(h, bg, extra) {
      h = Math.round(h);
      if (h <= 0) return '';
      return '<tr><td class="sg" style="height:'+h+'px;line-height:'+h+'px;background:'+bg+';'+(extra||'')+'">&#8203;</td></tr>';
    }
    var TOP = 'border-radius:3px 3px 0 0;'; // redondeo del tope de la barra
    // Segmento coloreado que además contiene el valor (texto blanco), como en la web.
    function segLabel(h, bg, label, extra) {
      h = Math.round(h);
      if (h <= 0) return '';
      return '<tr><td class="sl" style="height:'+h+'px;background:'+bg+';'+(extra||'')+'">'+
             (label || '&#8203;')+'</td></tr>';
    }
    // Columna de un día: barra coloreada (verde/rojo/gris) con el valor adentro,
    // tope redondeado y la línea de target embebida (como en la página de gráficos).
    function barCol(val, tar, maxVal, label) {
      var aPx = (val != null && maxVal > 0) ? (val / maxVal) * H : 0;
      var tPx = (tar != null && tar > 0 && maxVal > 0) ? (tar / maxVal) * H : 0;
      var color = (val == null) ? '#cbd5e1' : (tar != null && tar > 0 ? (val >= tar ? '#16a34a' : '#dc2626') : '#94a3b8');
      var LINE = '#0f172a', T = 'transparent';
      var rows;
      if (val == null) {
        rows = seg(H - tPx, T) + seg(2, LINE) + seg(tPx - 2, T);
      } else if (tar == null || tar <= 0) {
        rows = seg(H - aPx, T) + segLabel(aPx, color, label, TOP);
      } else if (aPx >= tPx) {
        // arriba del target (tope redondeado), línea, y abajo la base con el valor
        rows = seg(H - aPx, T) + seg(aPx - tPx, color, TOP) + seg(2, LINE) + segLabel(tPx - 2, color, label);
      } else {
        // barra roja por debajo del target; valor adentro + tope redondeado
        rows = seg(H - tPx, T) + seg(2, LINE) + seg(tPx - aPx - 2, T) + segLabel(aPx, color, label, TOP);
      }
      return '<table width="100%" cellpadding="0" cellspacing="0" border="0" style="height:'+H+'px;">'+rows+'</table>';
    }

    // Formato compacto para etiquetas sobre las barras (más angosto)
    function fmtC(v, fmt) {
      if (v == null || isNaN(v)) return '';
      var a = Math.abs(v), s;
      if (a >= 1e6) s = (v / 1e6).toFixed(2) + 'M';
      else if (a >= 1e3) s = (v / 1e3).toFixed(0) + 'k';
      else s = String(Math.round(v));
      return fmt === 'eur' ? s + '€' : s;
    }

    function panel(label, accent, valKey, tarKey, fmt, forPdf, rrKey) {
      var maxVal = 0, sumA = 0, sumT = 0, hasA = false, hasT = false;
      days.forEach(function(d){
        var a = d[valKey], t = d[tarKey] || 0;
        if (a != null) { maxVal = Math.max(maxVal, a); sumA += a; sumT += t; hasA = true; }
        if (t)        { maxVal = Math.max(maxVal, t); hasT = true; }
      });
      // Si no hay NI actuals NI target del mes, mostramos el panel con un aviso
      // (antes devolvía '' y el gráfico desaparecía sin explicación → "no me
      // aparece el de GMV"). Así el bloque siempre se ve.
      if (!hasA && !hasT) {
        return '<table class="tb" cellpadding="0" cellspacing="0" border="0">' +
          '<tr><td style="height:3px;padding:0;font-size:0;line-height:3px;background-color:'+accent+';">&#8203;</td></tr>' +
          '<tr><td style="padding:16px;background:#ffffff;font-family:Arial,sans-serif;">' +
            '<div style="font-size:18px;font-weight:700;color:'+accent+';">'+label+'</div>' +
            '<div style="font-size:12px;color:#94a3b8;margin-top:6px;">Sin datos para el mes en curso.</div>' +
          '</td></tr></table>';
      }
      var vs = sumT > 0 ? ((sumA - sumT) / sumT) * 100 : null;
      var vsColor = vs == null ? '#64748b' : (vs >= 0 ? '#16a34a' : '#dc2626');
      var vsTxt   = vs == null ? '—' : ((vs >= 0 ? '+' : '') + vs.toFixed(1) + '%');
      // RR Mes (proyección mensual) de LATAM, del rrData ya calculado para el mail.
      var rrVal = (rrData && rrKey && rrData[rrKey] && rrData[rrKey]['LATAM']) ? rrData[rrKey]['LATAM'].rr : null;

      // Celdas del gráfico (estilo página): barra con el valor adentro y, abajo,
      // día · target del día · variación vs target (flecha ▲/▼ coloreada).
      // Con muchas fechas (mes avanzado) las barras se angostan y el valor ADENTRO
      // (que es el ACTUAL) se amontona. A partir de 28 días lo sacamos de la barra y
      // lo mostramos en su propia fila abajo, así no se pierde el dato (ojo: el gris
      // de abajo es el BE_LABEL, distinto del actual).
      var manyDays = days.length >= 28;
      var barCells = '', dayCells = '', actCells = '', tarCells = '', varCells = '';
      days.forEach(function(d){
        var a = d[valKey], t = d[tarKey] || 0;
        var v = (t > 0 && a != null) ? ((a - t) / t) * 100 : null;
        var vCol = v == null ? '#94a3b8' : (v >= 0 ? '#16a34a' : '#dc2626');
        var vTxt = v == null ? '' : ((v >= 0 ? '▲+' : '▼') + v.toFixed(1) + '%');
        barCells += '<td class="bcw" valign="bottom">' + barCol(a, d[tarKey], maxVal, manyDays ? '' : fmtC(a, fmt)) + '</td>';
        dayCells += '<td class="cxd">' + (rangeOpt ? (d.day + '-' + ('0'+d.mo).slice(-2)) : d.day) + '</td>';
        actCells += '<td class="cxa">' + (a != null ? fmtC(a, fmt) : '—') + '</td>';
        tarCells += '<td class="cxt">' + (t > 0 ? fmtC(t, fmt) : '—') + '</td>';
        varCells += '<td class="cxv" style="color:' + vCol + ';">' + vTxt + '</td>';
      });

      // Período tipo "LATAM · 1 → 9 Junio" (o el override que pase el semanal).
      var periodTxt = periodOverride || ('LATAM · ' + days[0].day + ' → ' + days[days.length-1].day + ' ' + mesLabel);

      // KPI strip (Acumulado / BE_LABEL / vs BE_LABEL), como en la web
      var kpis =
        '<table class="kpis" cellpadding="0" cellspacing="0" border="0"><tr>' +
          '<td style="background:#f8fafc;border:1px solid #eef2f7;border-radius:8px;padding:6px 12px;">' +
            '<div style="font-size:9px;font-weight:700;text-transform:uppercase;letter-spacing:.4px;color:'+accent+';">Acumulado</div>' +
            '<div style="font-size:18px;font-weight:800;color:#0f172a;letter-spacing:-.5px;white-space:nowrap;">' + _fmtV(sumA, fmt) + '</div></td>' +
          '<td width="6"></td>' +
          '<td style="background:#f8fafc;border:1px solid #eef2f7;border-radius:8px;padding:6px 12px;">' +
            '<div style="font-size:9px;font-weight:700;text-transform:uppercase;letter-spacing:.4px;color:#94a3b8;">' + BE_LABEL + '</div>' +
            '<div style="font-size:16px;font-weight:500;color:#94a3b8;letter-spacing:-.5px;white-space:nowrap;">' + (sumT > 0 ? _fmtV(sumT, fmt) : '—') + '</div></td>' +
          '<td width="6"></td>' +
          '<td style="background:#f8fafc;border:1px solid #eef2f7;border-radius:8px;padding:6px 12px;">' +
            '<div style="font-size:9px;font-weight:700;text-transform:uppercase;letter-spacing:.4px;color:#94a3b8;">vs ' + BE_LABEL + '</div>' +
            '<div style="font-size:18px;font-weight:800;color:'+vsColor+';letter-spacing:-.5px;white-space:nowrap;">' + vsTxt + '</div></td>' +
          (rrData ?
          ('<td width="6"></td>' +
          '<td style="background:#f5f3ff;border:1px solid #ddd6fe;border-radius:8px;padding:6px 12px;">' +
            '<div style="font-size:9px;font-weight:700;text-transform:uppercase;letter-spacing:.4px;color:#7c3aed;">' + ((rrData.meta && rrData.meta.isMonthClose) ? 'Cierre de mes' : 'RR Mes') + '</div>' +
            '<div style="font-size:18px;font-weight:800;color:#7c3aed;letter-spacing:-.5px;white-space:nowrap;">' + (rrVal != null ? _fmtV(rrVal, fmt) : '—') + '</div></td>') : '') +
        '</tr></table>';

      // Header del panel: nombre (coloreado) + período a la izquierda, KPIs a la derecha
      var header =
        '<table class="chdr" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin-bottom:12px;"><tr>' +
          '<td class="chdr-l" valign="top" style="font-family:Arial,sans-serif;">' +
            '<div style="font-size:18px;font-weight:700;color:'+accent+';letter-spacing:-.3px;">' + label + '</div>' +
            '<div style="font-size:11px;color:#94a3b8;font-family:monospace;margin-top:2px;">' + periodTxt + '</div></td>' +
          '<td class="chdr-r" valign="top" align="right">' + kpis + '</td>' +
        '</tr></table>';

      // Legend igual a la web (≥ BE_LABEL / < BE_LABEL / Sin BE_LABEL / línea BE_LABEL)
      var legend =
        '<table cellpadding="0" cellspacing="0" border="0" style="margin-bottom:10px;font-family:Arial,sans-serif;"><tr style="font-size:11px;color:#475569;font-weight:600;">' +
          '<td><span style="display:inline-block;width:12px;height:10px;background:#16a34a;opacity:.85;border-radius:2px;vertical-align:middle;"></span> ≥ ' + BE_LABEL + '</td><td width="14"></td>' +
          '<td><span style="display:inline-block;width:12px;height:10px;background:#dc2626;opacity:.85;border-radius:2px;vertical-align:middle;"></span> &lt; ' + BE_LABEL + '</td><td width="14"></td>' +
          '<td><span style="display:inline-block;width:16px;height:2px;background:#0f172a;vertical-align:middle;"></span> <span style="background:rgba(100,116,139,.12);color:#475569;font-size:8px;font-weight:700;padding:1px 5px;border-radius:10px;">' + BE_LABEL + '</span></td>' +
        '</tr></table>';

      // Gráfico: barras (valor adentro) → día → variación, en contenedor tipo panel.
      var chart =
        '<table width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#fbfcfe;border:1px solid #eef2f7;border-radius:8px;"><tr><td style="padding:14px 12px 10px;">' +
          '<table width="100%" cellpadding="0" cellspacing="0" border="0" style="table-layout:fixed;border-bottom:2px solid #cbd5e1;"><tr>' + barCells + '</tr></table>' +
          '<table width="100%" cellpadding="0" cellspacing="0" border="0" style="table-layout:fixed;"><tr>' + dayCells + '</tr>' + (manyDays ? ('<tr>' + actCells + '</tr>') : '') + '<tr>' + tarCells + '</tr><tr>' + varCells + '</tr></table>' +
        '</td></tr></table>';

      // Versión PDF-safe: el conversor de Google Docs no renderiza las barras
      // apiladas, así que en el PDF mostramos la misma info como tabla diaria.
      // Tabla diaria con FECHA · ACTUAL · BE_LABEL · VAR vs BE_LABEL (números explícitos).
      // Va en el PDF y TAMBIÉN en el email: en el mail las barras suelen colapsar
      // y no muestran el valor del BE_LABEL ni el actual por día → esta tabla lo deja claro.
      var dayTable = '';
      if (forPdf) {
        var mesAbbr = mesLabel.substring(0, 3);   // "Jun"
        var dayRows = '';
        days.forEach(function(d){
          var a = d[valKey], t = d[tarKey] || 0;
          var v = (t > 0 && a != null) ? ((a - t) / t) * 100 : null;
          var cls = v == null ? 'p-n' : (v >= 0 ? 'p-g' : 'p-b');
          var txt = v == null ? '—' : ((v >= 0 ? '+' : '') + v.toFixed(1) + '%');
          dayRows +=
            '<tr><td class="td-n" style="text-align:center;white-space:nowrap;">' + d.day + ' ' + mesAbbr + '</td>' +
            '<td class="td-v">' + _fmtV(a, fmt) + '</td>' +
            '<td class="td-8">' + (t > 0 ? _fmtV(t, fmt) : '—') + '</td>' +
            '<td class="td-p"><span class="pill ' + cls + '">' + txt + '</span></td></tr>';
        });
        var accCls = vs == null ? 'p-n' : (vs >= 0 ? 'p-g' : 'p-b');
        dayTable =
          '<table width="100%" cellpadding="0" cellspacing="0" border="0" style="border-collapse:collapse;border:1px solid #e2e8f0;border-radius:6px;">' +
            '<tr><th class="th-c" style="text-align:center;">FECHA</th><th class="th-c">ACTUAL</th>' +
            '<th class="th-c">' + BE_LABEL + '</th><th class="th-c">VAR vs ' + BE_LABEL + '</th></tr>' +
            dayRows +
            '<tr style="background:#f1f5f9;font-weight:bold;">' +
              '<td class="td-n" style="text-align:center;">Acum.</td>' +
              '<td class="td-v">' + _fmtV(sumA, fmt) + '</td>' +
              '<td class="td-8">' + (sumT > 0 ? _fmtV(sumT, fmt) : '—') + '</td>' +
              '<td class="td-p"><span class="pill ' + accCls + '">' + vsTxt + '</span></td></tr>' +
          '</table>';
      }

      // Email: header + legend + gráfico de barras HTML (se ven bien en Gmail).
      // PDF:   header + imagen PNG del gráfico (servicio Charts de GAS). El conversor
      //        de Google NO renderiza las barras HTML apiladas (salían en blanco),
      //        pero SÍ renderiza un <img> embebido como data-URI. Si por algún motivo
      //        la imagen no se genera, caemos a la tabla diaria (nunca queda vacío).
      var bodyInner;
      if (forPdf) {
        var pdfChart = '';
        try {
          var _blob = _nativeMetricChartBlob(days, valKey, tarKey, label, accent);
          var _uri  = 'data:image/png;base64,' + Utilities.base64Encode(_blob.getBytes());
          pdfChart  = '<img src="' + _uri + '" width="720" style="width:100%;max-width:720px;height:auto;display:block;margin-top:4px;border:1px solid #eef2f7;border-radius:8px;" alt="' + label + '">';
        } catch (eImg) {
          Logger.log('Gráfico nativo falló (' + label + '): ' + eImg.message + ' — uso tabla diaria.');
        }
        // La imagen ya trae su propia leyenda (Actual / BE_LABEL) → no repetimos la HTML.
        bodyInner = pdfChart ? (header + pdfChart) : (header + legend + dayTable);
      } else {
        bodyInner = header + legend + chart;
      }

      // Accent bar arriba (3px) como el .panel-accent de la página.
      return '<table class="tb" cellpadding="0" cellspacing="0" border="0">' +
        '<tr><td style="height:3px;padding:0;font-size:0;line-height:3px;background-color:'+accent+';">&#8203;</td></tr>' +
        '<tr><td style="padding:16px 16px 14px;background:#ffffff;">' + bodyInner + '</td></tr>' +
      '</table>';
    }

    var pOrders = panel('Confirmed Orders', '#e50044', 'o', 'tarO', 'num', forPdf, 'orders');
    var pGmv    = panel('GMV User Dmarts',  '#2563eb', 'g', 'tarG', 'eur', forPdf, 'gmv');
    return pOrders + pGmv;

  } catch (e) {
    Logger.log('_buildDailyChartsEmail error: ' + e.message);
    return '';
  }
}

// Gráfico de columnas NATIVO de Google (servicio Charts) → blob PNG, para el PDF.
// Dos series por día: Actual (color de la métrica) y BE_LABEL (gris). NO usa servicios
// externos: el render lo hace Google y los datos no salen de la cuenta. Se embebe
// como data-URI en el HTML del PDF (las barras HTML no las renderiza el conversor).
function _nativeMetricChartBlob(days, valKey, tarKey, label, accentHex) {
  var dt = Charts.newDataTable()
    .addColumn(Charts.ColumnType.STRING, 'Día')
    .addColumn(Charts.ColumnType.NUMBER, 'Actual')
    .addColumn(Charts.ColumnType.NUMBER, BE_LABEL);
  days.forEach(function(d){
    var a = (d[valKey] != null) ? Number(d[valKey]) : 0;
    var t = Number(d[tarKey] || 0);
    dt.addRow([String(d.day), a, t]);
  });
  var chart = Charts.newColumnChart()
    .setDataTable(dt.build())
    .setDimensions(920, 320)
    .setColors([accentHex, '#9aa7b8'])
    .setLegendPosition(Charts.Position.TOP)
    .setOption('backgroundColor', '#ffffff')
    .build();
  return chart.getAs('image/png');
}

// =================================================================
// UTILIDADES
// =================================================================

// Minifica el HTML del mail SIN alterar el contenido visible: saca los saltos
// de línea y la indentación de las plantillas (cada fila de tabla cargaba ~10
// espacios × cientos de filas), y colapsa espacios SOLO entre etiquetas (>  <),
// nunca dentro del texto. Así el mail pesa bastante menos y Gmail no lo recorta.
function _minifyEmailHtml(h) {
  return String(h)
    .replace(/<!--[\s\S]*?-->/g, '')   // comentarios HTML (no DOCTYPE)
    .replace(/\r/g, '')                // saca retornos de carro (Windows \r\n → \n)
    .replace(/\n\s*/g, '')             // saltos de línea + indentación (el grueso del peso)
    .replace(/>[ \t]{2,}</g, '><');    // 2+ espacios SOLO entre tags (no toca texto con 1 espacio)
}

function _todayLabel() {
  return Utilities.formatDate(new Date(), Session.getScriptTimeZone(), "dd 'de' MMMM 'de' yyyy");
}

// Bloque del mensaje personalizado que va arriba de todo en el mail.
// Devuelve '' si el mensaje está vacío (no se muestra nada). El texto se
// escapa para no romper el HTML y los saltos de línea se respetan.
function _buildMessageBlock(msg, by, at) {
  if (msg == null) return '';
  var clean = String(msg).trim();
  if (clean === '') return '';
  var FF = "-apple-system,BlinkMacSystemFont,'Segoe UI',Arial,sans-serif";
  var safe = clean
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/\r\n|\r|\n/g, '<br>');
  // Línea de autoría: qué admin escribió el mensaje (+ cuándo), para que no haya
  // confusión sobre quién lo redactó. Si no hay autor guardado, no se muestra.
  var byHtml = '';
  if (by) {
    var byName = (typeof _emailToName === 'function') ? _emailToName(by) : '';
    var who = byName ? (byName + ' &lt;' + by + '&gt;') : by;
    byHtml = '<div style="font-size:11px;color:#94a3b8;margin-top:9px;padding-top:8px;border-top:1px solid #eef2f7;font-family:' + FF + ';">' +
      'Escrito por <b style="color:#475569;">' + who + '</b>' + (at ? (' · ' + at) : '') + '</div>';
  }
  return '<table width="100%" cellpadding="0" cellspacing="0" border="0" ' +
    'style="margin-bottom:20px;background:#ffffff;border:1px solid #cbd5e1;border-left:6px solid #e50044;border-radius:8px;">' +
    '<tr><td style="padding:12px 16px;">' +
      '<div style="font-size:10px;font-weight:800;text-transform:uppercase;letter-spacing:.5px;color:#e50044;margin-bottom:4px;font-family:' + FF + ';">Mensaje</div>' +
      '<div style="font-size:13px;line-height:1.5;color:#1e293b;font-family:' + FF + ';">' + safe + '</div>' +
      byHtml +
    '</td></tr></table>';
}

function _calcVar(d1, ref, varFmt) {
  if (d1 == null || ref == null) return null;
  if (varFmt === 'pp' || varFmt === 'min_abs') return d1 - ref;  // diferencia absoluta (pp / minutos)
  if (ref === 0) return null;
  return ((d1 - ref) / Math.abs(ref)) * 100;
}

function _fmtVar(val, varFmt) {
  if (val == null || isNaN(val)) return null;
  const s = val > 0 ? '+' : '';
  if (varFmt === 'pp')      return `${s}${val.toFixed(1)} pp`;
  if (varFmt === 'min_abs') return `${s}${val.toFixed(1)} min`;
  return `${s}${val.toFixed(1)}%`;
}

function _fmtV(v, fmt) {
  if (v == null || isNaN(v)) return '—';
  const a = Math.abs(v);
  if (fmt === 'eur') {
    if (a >= 1e6) return (v / 1e6).toFixed(2) + 'M€';
    if (a >= 1e3) return (v / 1e3).toFixed(1) + 'k€';
    return v.toFixed(2) + '€';
  }
  if (fmt === 'pct') return v.toFixed(1) + '%';
  if (fmt === 'min') return v.toFixed(1) + ' min';
  if (a >= 1e6) return (v / 1e6).toFixed(2) + 'M';
  if (a >= 1e3) return (v / 1e3).toFixed(1) + 'k';
  return v.toLocaleString('es-AR', { minimumFractionDigits:1, maximumFractionDigits:1 });
}
