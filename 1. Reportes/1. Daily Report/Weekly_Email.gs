/**
 * Weekly_Email.gs — EMAIL SEMANAL (Reporte Semanal) con CIERRE POR SEMANA.
 *
 * Manda las mismas métricas por país del reporte, pero acotadas a la
 * ÚLTIMA SEMANA CERRADA (lunes→domingo). Reutiliza:
 *   • fetchMtdActuals(inicio, fin)  → métricas por país para un rango (Code.gs)
 *   • _generatePdfFromHtml(html, t) → PDF adjunto (Email.gs)
 *   • getEmailRecipients()          → destinatarios masivos (del sheet, con fallback a EMAIL_TO)
 *
 * Programación POR CÓDIGO (igual que el Daily, sin página): se corre una sola
 * vez setupTriggerSemanal() desde el editor y queda andando solo. El trigger
 * corre cada 10 min y checkYEnviarSemanal() decide si toca enviar (lunes, dentro
 * de la ventana horaria, y sin haber enviado ya esa semana).
 *
 * Funciones útiles (correr desde el editor):
 *   • setupTriggerSemanal()        → instala el envío automático (correr UNA vez)
 *   • previewWeeklyEmail()         → genera el mail SIN enviar y guarda HTML+PDF en tu Drive
 *   • forzarEnvioSemanal()         → ENVÍA ahora a TODOS (semana cerrada), ignorando ventana/dedup/validaciones
 *   • forzarEnvioPruebaSemanal()   → ENVÍA de PRUEBA a matias.cagliero forzando el envío (ignora datos incompletos)
 *   • checkYEnviarSemanal()        → lo que corre el trigger cada 10 min
 */

// Ventana de envío semanal: lunes ~12:00 (mismo esquema que el Daily).
const DIA_ENVIO_SEM    = 1;   // getDay(): 0=Dom .. 1=Lun
const HORA_ENVIO_SEM   = 12;
const MINUTO_ENVIO_SEM = 0;
const VENTANA_SEM_MIN  = 20;  // tolerancia (trigger cada 10 min → 12:00–12:20)
const PROP_KEY_SEM     = 'ULTIMO_ENVIO_SEMANAL';

// Orden y color (por NOMBRE de métrica).
var WK_METRIC_ORDER = [
  'Confirmed Orders','GMV User Dmarts',
  // Usuarios SEMANALES (pestaña "C. Weekly users"): foto de la semana cerrada.
  // Van JUSTO DESPUÉS de GMV, igual que en el MTD (usuarios, new users, cobertura).
  'Dmart MAUs','Dmart MAUs - Plus % (Weekly)','New Users - Dmart','Covered MAUs penetration %',
  'WIS %','WIS UF %','Seamless Delivery %','Avg. Delivery Time',
  'Assignment Time','Assignment Time > 6 min %','HC Sessions orders %','Rejected Orders %'
];
// Métricas que NO se incluyen en el mail semanal:
//  • New Users (diaria)                 → se usa "New Users - Dmart" (semanal).
//  • Users DMart (hoja actuals)         → es el Dmart MAUs ACUMULADO; se muestra el
//    "Dmart MAUs" de la base semanal en su lugar (saca el duplicado).
//  • Platform Maus penetration % (actuals) → se muestra la penetración de la base
//    semanal ("Covered MAUs penetration %") pero CON ESE nombre (ver WK_METRIC_DISPLAY).
var WK_METRIC_EXCLUDE = ['New Users', 'Users DMart', 'Platform Maus penetration %', 'Dmart MAUs - Plus', 'Assignment Time'];
// Renombre SOLO de cara al mail: la key interna ("Covered MAUs penetration %") no
// cambia para no romper el lookup en metrics/config/color; solo se muestra distinto.
var WK_METRIC_DISPLAY = { 
  'Covered MAUs penetration %': 'Platform Maus penetration %',
  'Dmart MAUs - Plus % (Weekly)': 'Dmart MAUs - Plus %',
  'Users DMart': 'Dmart MAUs'
};
var WK_METRIC_COLOR = {
  'Confirmed Orders':'#e50044','GMV User Dmarts':'#2563eb','Users DMart':'#0284c7',
  'Platform Maus penetration %':'#0891b2','New Users':'#ea580c','WIS %':'#16a34a',
  'WIS UF %':'#0891b2','Seamless Delivery %':'#16a34a','Avg. Delivery Time':'#d97706',
  'Assignment Time':'#9333ea','HC Sessions orders %':'#7c3aed','Rejected Orders %':'#dc2626','Assignment Time > 6 min %':'#f43f5e',
  'Dmart MAUs':'#0284c7','Dmart MAUs - Plus':'#0ea5e9','Dmart MAUs - Plus %':'#0ea5e9','Dmart MAUs - Plus % (Weekly)':'#0ea5e9','New Users - Dmart':'#06b6d4','Covered MAUs penetration %':'#0891b2'
};
var WK_CCN = {AR:'Argentina',BO:'Bolivia',CL:'Chile',CO:'Colombia',CR:'Costa Rica',
  EC:'Ecuador',SV:'El Salvador',GT:'Guatemala',HN:'Honduras',NI:'Nicaragua',
  PA:'Panamá',PY:'Paraguay',PE:'Perú',UY:'Uruguay',DO:'Rep. Dominicana',MX:'México',LATAM:'LATAM'};

// ── Rango de la última semana CERRADA (lunes → domingo) ──────────────
function _weekRangeLunDom(refDate) {
  var tz = Session.getScriptTimeZone();
  var today = refDate ? new Date(refDate)
                      : new Date(Utilities.formatDate(new Date(), tz, "yyyy-MM-dd'T'12:00:00"));
  var dow = today.getDay();              // 0=Dom .. 6=Sáb
  var sinceMon = (dow + 6) % 7;          // días desde el lunes de ESTA semana
  var thisMon = new Date(today); thisMon.setDate(today.getDate() - sinceMon);
  var start = new Date(thisMon); start.setDate(thisMon.getDate() - 7);  // lunes anterior
  var end   = new Date(thisMon); end.setDate(thisMon.getDate() - 1);    // domingo anterior
  function ymd(d){ return Utilities.formatDate(d, tz, 'yyyy-MM-dd'); }
  function dm(d){ return Utilities.formatDate(d, tz, 'dd/MM'); }
  return {
    start: ymd(start), end: ymd(end),
    labelShort: dm(start) + '–' + dm(end),                       // 09/06–15/06
    fileLabel:  'Weekly_report_' + ymd(start) + '_a_' + ymd(end)  // Weekly_report_2026-06-09_a_2026-06-15
  };
}

// ── Formateadores (millones con 2 decimales) ──
function _wFv(v, fmt) {
  if (v == null || isNaN(v)) return '—';
  if (v === 0) return (fmt === 'pct' || fmt === 'pct_pre') ? '0.0%' : '0';
  if (fmt === 'time')    return v.toFixed(1) + ' min';
  if (fmt === 'pct')     return (v * 100).toFixed(1) + '%';
  if (fmt === 'pct_pre') return v.toFixed(1) + '%';
  var a = Math.abs(v);
  if (a >= 1e6) return (v / 1e6).toFixed(2) + 'M';
  if (a >= 1e3) return (v / 1e3).toFixed(1) + 'k';
  return v.toFixed(1);
}
function _wBadge(cur, prev, fmt, tc) {
  if (cur == null || prev == null || prev === 0) return '<span style="color:#94a3b8">—</span>';
  var d, sfx;
  if      (fmt === 'pct')     { d = (cur - prev) * 100;                 sfx = ' pp'; }
  else if (fmt === 'pct_pre') { d = cur - prev;                         sfx = ' pp'; }
  else if (fmt === 'time')    { d = cur - prev;                         sfx = ' min'; }
  else                        { d = ((cur - prev) / Math.abs(prev)) * 100; sfx = '%'; }
  if (Math.abs(d) < 0.05) return '<span style="color:#94a3b8">0.0' + sfx + '</span>';
  var good = (tc === 1) ? (d > 0) : (d < 0);
  var color = good ? '#059669' : '#e11d48';
  return '<span style="color:' + color + ';font-weight:700">' + (d > 0 ? '+' : '') + d.toFixed(1) + sfx + '</span>';
}

// Badge en formato "pill" (con fondo) para el diseño nuevo. Usa clases CSS
// (up/dn/flat) definidas en el <style> del mail → liviano y consistente.
function _wPill(cur, prev, fmt, tc) {
  if (cur == null || prev == null || prev === 0) return '<span class="pill flat">—</span>';
  var d, sfx;
  if      (fmt === 'pct')     { d = (cur - prev) * 100;                  sfx = ' pp'; }
  else if (fmt === 'pct_pre') { d = cur - prev;                          sfx = ' pp'; }
  else if (fmt === 'time')    { d = cur - prev;                          sfx = ' min'; }
  else                        { d = ((cur - prev) / Math.abs(prev)) * 100; sfx = '%'; }
  if (Math.abs(d) < 0.05) return '<span class="pill flat">0.0' + sfx + '</span>';
  var good = (tc === 1) ? (d > 0) : (d < 0);
  return '<span class="pill ' + (good ? 'up' : 'dn') + '">' + (d > 0 ? '+' : '') + d.toFixed(1) + sfx + '</span>';
}

// Pill para un porcentaje YA calculado (ej. Var BE Mes del RR). tc: 1 = más es mejor.
function _wPctBadge(pct, tc) {
  if (pct == null || isNaN(pct)) return '<span class="pill flat">—</span>';
  if (Math.abs(pct) < 0.05) return '<span class="pill flat">0.0%</span>';
  var good = (tc === 1) ? (pct > 0) : (pct < 0);
  return '<span class="pill ' + (good ? 'up' : 'dn') + '">' + (pct > 0 ? '+' : '') + pct.toFixed(1) + '%</span>';
}

// Rango de fechas que cubre CADA métrica (para validar el envío). Devuelve HTML.
//  • Semanales (foto): la semana que eligió _readWeeklyUsers (Semana N · dd/MM → dd/MM).
//  • Diarias (acumulado): inicio de semana → último día CON DATOS de esa métrica
//    (dataThroughByMetric). Si ese día es anterior al domingo, marca aviso (semana parcial).
function _wkMetricRangeLabel(m, cfg, rng, p) {
  function dm(ymd){ return ymd ? ymd.slice(8,10) + '/' + ymd.slice(5,7) : '—'; }
  if (cfg.weekly && cfg.week) {
    var wk = (cfg.weekNum != null ? 'Semana ' + cfg.weekNum + ' · ' : '');
    return wk + cfg.week + ' &rarr; ' + (cfg.weekEnd || cfg.week);
  }
  var dt = (p.dataThroughByMetric || {})[m];         // último día con datos reales de la métrica
  var partial = dt && dt < rng.end;
  var endYmd = partial ? dt : rng.end;               // capado al fin de semana
  var base = 'Semana ' + dm(rng.start) + ' &rarr; ' + dm(endYmd);
  return partial
    ? base + ' <span style="color:#d97706;font-weight:700">&#9888; datos hasta ' + dm(dt) + ' (esperado ' + dm(rng.end) + ')</span>'
    : base;
}

// BE (target) de la SEMANA cerrada, por país, para Orders y GMV. Lee la hoja de
// targets DIARIOS ("Export Targets-Diario": Metric | Country | Date | Value) UNA
// sola vez y SUMA los días dentro de [startYmd, endYmd] (los 7 lun→dom). Devuelve
// { orders:{ISO:sum}, gmv:{ISO:sum} } con LATAM = suma de países. Mismas constantes
// y mapeo de país que _readTargets (Code.gs, alcance global).
function _readWeeklyBE(startYmd, endYmd) {
  var result = { orders:{}, gmv:{} };
  try {
    var sheet = SpreadsheetApp.openById(TARGETS_SS_ID).getSheets()
      .find(function(s){ return TARGETS_SHEET_RE.test(s.getName()); });
    if (!sheet) { Logger.log('_readWeeklyBE: no encontré la hoja de targets diarios'); return result; }
    var data = sheet.getDataRange().getValues();
    var headers = data[0].map(function(h){ return String(h).trim().toLowerCase(); });
    var ci = { metric:headers.indexOf('metric'), country:headers.indexOf('country'),
               date:headers.indexOf('date'), value:headers.indexOf('value') };
    if (ci.metric < 0 || ci.country < 0 || ci.date < 0 || ci.value < 0) return result;
    var startT = new Date(startYmd + 'T00:00:00').getTime();
    var endT   = new Date(endYmd   + 'T00:00:00').getTime();
    for (var i = 1; i < data.length; i++) {
      var r = data[i], rawDate = r[ci.date];
      if (!rawDate) continue;
      var t = (rawDate instanceof Date)
        ? new Date(rawDate.getFullYear(), rawDate.getMonth(), rawDate.getDate()).getTime()
        : new Date(String(rawDate).slice(0, 10) + 'T00:00:00').getTime();
      if (isNaN(t) || t < startT || t > endT) continue;
      var metric  = String(r[ci.metric] || '').trim();
      var country = String(r[ci.country] || '').trim().toLowerCase();
      // Usar los diccionarios globales compartidos para normalizar el país a ISO-2.
      // Así ignoramos agregaciones espurias de la hoja como "LATAM", "LATAM ex AR", etc.
      var iso = (typeof COUNTRY_NAME_TO_CODE !== 'undefined' && COUNTRY_NAME_TO_CODE[country]) ||
                (typeof COUNTRY_ISO !== 'undefined' && COUNTRY_ISO[country]) ||
                country.toUpperCase().slice(0, 2);
      if (iso === 'LATAM' || iso === 'LA' || iso.length > 2) continue; // Saltea cualquier agregado regional.
      var val = Number(r[ci.value]);
      if (isNaN(val)) continue;
      if (metric === TARGET_KEY_ORDERS)   result.orders[iso] = (result.orders[iso] || 0) + val;
      else if (metric === TARGET_KEY_GMV) result.gmv[iso]    = (result.gmv[iso]    || 0) + val;
    }
    result.orders['LATAM'] = Object.keys(result.orders).reduce(function(a, k){ return a + result.orders[k]; }, 0);
    result.gmv['LATAM']    = Object.keys(result.gmv).reduce(function(a, k){ return a + result.gmv[k]; }, 0);
  } catch (e) { Logger.log('_readWeeklyBE: ' + (e && e.message)); }
  return result;
}

// ── HTML del email ───────────────────────────────────────────────────
function _buildWeeklyMtdHtml(rng, forPdf) {
  var res = fetchMtdActuals(rng.start, rng.end);
  var p = res && res.payload;
  if (!p || p.error) return { html: '<p>Error: ' + ((p && p.error) || 'sin datos') + '</p>', empty: true };

  var metrics = p.metrics || {}, config = p.config || {}, countries = (p.countries || []).slice();
  var customOrder = ['AR', 'BO', 'CL', 'DO', 'EC', 'SV', 'GT', 'HN', 'NI', 'PA', 'PY', 'PE', 'UY', 'CO', 'CR', 'MX'];
  var order = countries.filter(function(c){ return c !== 'LATAM'; })
                       .sort(function(a, b){
                         var valA = (metrics['Confirmed Orders'] && metrics['Confirmed Orders'][a]) ? (metrics['Confirmed Orders'][a].current || 0) : 0;
                         var valB = (metrics['Confirmed Orders'] && metrics['Confirmed Orders'][b]) ? (metrics['Confirmed Orders'][b].current || 0) : 0;
                         if (valB !== valA) {
                           return valB - valA;
                         }
                         var idxA = customOrder.indexOf(a);
                         var idxB = customOrder.indexOf(b);
                         if (idxA === -1) idxA = 999;
                         if (idxB === -1) idxB = 999;
                         return idxA - idxB;
                       });

  // Semana ANTERIOR (los 7 días previos a la semana cerrada) para la variación
  // semanal (WoW). El "current" de ese rango = el acumulado de la semana pasada.
  var sp0 = rng.start.split('-'), ep0 = rng.end.split('-');
  function _ymd(d){ return d.getFullYear() + '-' + ('0'+(d.getMonth()+1)).slice(-2) + '-' + ('0'+d.getDate()).slice(-2); }
  var prevStart = _ymd(new Date(+sp0[0], +sp0[1]-1, +sp0[2]-7));
  var prevEnd   = _ymd(new Date(+ep0[0], +ep0[1]-1, +ep0[2]-7));
  var prevRes = fetchMtdActuals(prevStart, prevEnd);
  var prevMetrics = (prevRes && prevRes.payload && prevRes.payload.metrics) || {};

  // RR mensual (run-rate) para las 3 columnas de RR. Solo aplica a Orders y GMV.
  // Respeta el origen elegido en rrcompare (export / cálculo).
  var rrData = (typeof _getRRDataFromSheet === 'function') ? _getRRDataFromSheet() : {orders:{},gmv:{}};
  var beLbl  = BE_LABEL;
  // BE de la SEMANA cerrada por país (Orders y GMV): suma de los targets DIARIOS de
  // los 7 días lun→dom. Reemplaza a la columna "semana anterior" en Orders y GMV.
  var weeklyBE = (typeof _readWeeklyBE === 'function') ? _readWeeklyBE(rng.start, rng.end) : {orders:{},gmv:{}};
  // Extracción del mes en el que cierra la semana para aclarar el BE Mensual.
  var endMonthNames = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
  var endMonthIdx = parseInt(rng.end.split('-')[1], 10) - 1;
  var endMonthName = endMonthNames[endMonthIdx];

  // "Cierre de mes": si el mes ya cerró (corte del RR = último día del mes), las
  // etiquetas de RR pasan a "Cierre de mes" (flag isMonthClose en Code.gs).
  var RR_CLOSE   = !!(rrData && rrData.meta && rrData.meta.isMonthClose);
  var RR_MES_LBL = RR_CLOSE ? 'Cierre de mes'       : 'RR Mes (' + endMonthName + ')';
  var RR_LM_LBL  = RR_CLOSE ? 'Cierre de mes vs LM' : 'RR vs LM';
  var RR_LY_LBL  = RR_CLOSE ? 'Cierre de mes vs LY' : 'RR vs LY';

  // Orden de métricas + exclusiones (New Users fuera del mail semanal, e ignorar métricas MTD).
  var hasWeeklyMaus = !!(metrics['Dmart MAUs'] && Object.keys(metrics['Dmart MAUs']).length > 0);
  var effectiveExclude = WK_METRIC_EXCLUDE.slice();
  if (!hasWeeklyMaus && metrics['Users DMart']) {
    // Si no se cargó la base semanal, usar Users DMart de la hoja diaria como fallback en lugar de excluirlo
    effectiveExclude = effectiveExclude.filter(function(e){ return e !== 'Users DMart' && e !== 'Platform Maus penetration %'; });
  }

  var keys = WK_METRIC_ORDER.filter(function(m){ return metrics[m] && effectiveExclude.indexOf(m) < 0; });
  if (!hasWeeklyMaus && metrics['Users DMart'] && keys.indexOf('Users DMart') < 0) {
    var gmvIdx = keys.indexOf('GMV User Dmarts');
    if (gmvIdx >= 0) {
      keys.splice(gmvIdx + 1, 0, 'Users DMart');
      if (metrics['Platform Maus penetration %']) {
        keys.splice(gmvIdx + 2, 0, 'Platform Maus penetration %');
      }
    } else {
      keys.push('Users DMart');
    }
  }

  Object.keys(metrics).forEach(function(m){
    var cfg = config[m] || {};
    var isMtd = !!(cfg.mtd || /- MTD/i.test(m));
    if (keys.indexOf(m) < 0 && effectiveExclude.indexOf(m) < 0 && !isMtd) {
      keys.push(m);
    }
  });

  // Las hero (Orders/GMV) van full-width; el resto se agrupan en una grilla de 2
  // columnas para que el mail no quede tan largo, pero con estilos compactos optimizados
  // para evitar scrollbars horizontales en la grilla.
  var heroCards = '', smallCards = [];
  keys.forEach(function(m){
    var cfg = config[m] || { formato:'num', tipo_color:1 };
    var fmt = cfg.formato, tc = cfg.tipo_color;
    // Plus % solo muestra WoW. Para el resto de semanales (weekly=true), se oculta YoY pero queda MoM.
    // También ocultamos YoY para las métricas configuradas y pedidas por el usuario.
    var showMom = !(m === 'Dmart MAUs - Plus % (Weekly)');
    var noYoyMetrics = [
      'Dmart MAUs - Plus % (Weekly)', 'WIS %', 'WIS UF %',
      'Assignment Time', 'Assignment Time > 6 min %', 'Seamless Delivery %',
      'HC Sessions orders %', 'Rejected Orders %'
    ];
    var showYoy = !cfg.weekly && noYoyMetrics.indexOf(m) < 0;

    var rows = metrics[m] || {};
    var prevRows = prevMetrics[m] || {};   // misma métrica, semana anterior (para WoW)
    // Las 3 columnas de RR solo aplican a Orders y GMV (las que tienen RR/BE).
    var rrK = (m === 'Confirmed Orders') ? 'orders' : (m === 'GMV User Dmarts') ? 'gmv' : null;
    var rrSet = (rrK && rrData[rrK]) ? rrData[rrK] : null;
    var isHero = !!rrSet;
    var list = order.filter(function(c){ return rows[c] && rows[c].current != null && rows[c].current !== 0; });
    if (!list.length) return;
    var color = WK_METRIC_COLOR[m] || '#64748b';
    var beSet = isHero ? (weeklyBE[rrK] || {}) : null;

    function rrCells(e){
      if (!isHero) return '';
      return '<td class="rr rr1 now">' + _wFv(e ? e.rr : null, fmt) + '</td>' +
             '<td class="rr prev">'   + _wFv(e ? e.be : null, fmt) + '</td>' +
             '<td class="rr">'        + _wPctBadge(e ? e.varBe : null, tc) + '</td>' +
             '<td class="rr rr1">'    + _wPctBadge(e ? e.rrVsLm : null, tc) + '</td>' +
             '<td class="rr">'        + _wPctBadge(e ? e.rrVsLy : null, tc) + '</td>';
    }

    var body = '';
    list.forEach(function(c, i){
      var d = rows[c];
      var pw = prevRows[c] ? prevRows[c].current : null;
      var zebra = (i % 2 === 1) ? ' style="background:#fbfcff"' : '';
      var momCell = showMom ? '<td>' + _wPill(d.current, d.m1, fmt, tc) + '</td>' : '';
      var yoyCell = showYoy ? '<td>' + _wPill(d.current, d.y1, fmt, tc) + '</td>' : '';
      
      body += '<tr' + zebra + '>' +
        '<td class="l">' + (WK_CCN[c]||c) + '</td>' +
        '<td class="now">' + _wFv(d.current, fmt) + '</td>' +
        (isHero
          ? '<td class="prev">' + _wFv(beSet[c], fmt) + '</td><td>' + _wPill(d.current, beSet[c], fmt, tc) + '</td><td>' + _wPill(d.current, pw, fmt, tc) + '</td>'
          : '<td class="prev">' + _wFv(pw, fmt) + '</td><td>' + _wPill(d.current, pw, fmt, tc) + '</td>') +
        momCell + yoyCell +
        rrCells(rrSet ? rrSet[c] : null) +
      '</tr>';
    });
    var L = rows['LATAM'];
    if (L && L.current != null) {
      var pwL = prevRows['LATAM'] ? prevRows['LATAM'].current : null;
      var momL = showMom ? '<td>' + _wPill(L.current, L.m1, fmt, tc) + '</td>' : '';
      var yoyL = showYoy ? '<td>' + _wPill(L.current, L.y1, fmt, tc) + '</td>' : '';

      body += '<tr class="latam" style="background:#eef2f7">' +
        '<td class="l" style="font-weight:800;color:#0f172a">LATAM</td>' +
        '<td class="now">' + _wFv(L.current, fmt) + '</td>' +
        (isHero
          ? '<td class="prev">' + _wFv(beSet['LATAM'], fmt) + '</td><td>' + _wPill(L.current, beSet['LATAM'], fmt, tc) + '</td><td>' + _wPill(L.current, pwL, fmt, tc) + '</td>'
          : '<td class="prev">' + _wFv(pwL, fmt) + '</td><td>' + _wPill(L.current, pwL, fmt, tc) + '</td>') +
        momL + yoyL +
        rrCells(rrSet ? rrSet['LATAM'] : null) +
      '</tr>';
    }

    var rrHead = isHero
      ? '<th class="rr rr1">' + RR_MES_LBL + '</th><th class="rr">' + beLbl + ' Mes (' + endMonthName + ')</th><th class="rr">Var ' + beLbl + ' Mes</th><th class="rr rr1">' + RR_LM_LBL + '</th><th class="rr">' + RR_LY_LBL + '</th>'
      : '';
    var cardHtml =
      '<div class="card">' +
        '<div class="acc" style="background:' + color + '">&#8203;</div>' +
        '<div class="mname" style="color:' + color + '">' + (WK_METRIC_DISPLAY[m] || m) + '</div>' +
        '<div class="mrange">' + _wkMetricRangeLabel(m, cfg, rng, p) + '</div>' +
        '<div class="htblwrap">' +
        '<table class="wk-tbl"><thead><tr>' +
          '<th class="l">País</th><th>Semana</th>' +
          (isHero ? '<th>' + beLbl + ' Sem.</th><th>Act vs BE</th>' : '<th>Sem. ant.</th>') +
          '<th>WoW</th>' + (showMom ? '<th>MoM</th>' : '') + (showYoy ? '<th>YoY</th>' : '') + rrHead +
        '</tr></thead><tbody>' + body + '</tbody></table>' +
        '</div>' +
      '</div>';
    if (isHero) heroCards += cardHtml; else smallCards.push(cardHtml);
  });

  // Grilla de 2 columnas para las métricas no-hero (email-safe con <table>).
  // En móvil el media query las apila a 1 columna.
  var smallGrid = '';
  if (smallCards.length) {
    smallGrid = '<table class="grid2" width="100%" cellpadding="0" cellspacing="0" border="0"><tr class="grow">';
    smallCards.forEach(function(ch, i){
      if (i > 0 && i % 2 === 0) smallGrid += '</tr><tr class="grow">';
      smallGrid += '<td class="gcell" width="50%" valign="top">' + ch + '</td>';
    });
    if (smallCards.length % 2 === 1) smallGrid += '<td class="gcell" width="50%">&#8203;</td>';
    smallGrid += '</tr></table>';
  }
  var cards = heroCards + smallGrid;

  if (!cards) return { html: '<p>Sin datos para la semana ' + rng.labelShort + '.</p>', empty: true };

  var styles =
    '*,*:before,*:after{box-sizing:border-box}' +
    'body{margin:0;background:#eef2f6;font-family:Arial,Helvetica,sans-serif;color:#0f172a;width:100% !important;-webkit-text-size-adjust:100%;-ms-text-size-adjust:100%}' +
    '.wrap{width:100% !important;max-width:840px !important;margin:0 auto;padding:18px 12px}' +
    'table,img{max-width:100%}' +
    '.hd{background:#fff;border:1px solid #e2e8f0;border-radius:12px;padding:15px 16px;margin-bottom:12px}' +
    '.kick{font-size:10.5px;font-weight:800;letter-spacing:.5px;text-transform:uppercase;color:#e50044}' +
    '.dot{display:inline-block;width:6px;height:7px;border-radius:50%;background:#e50044;margin-right:6px;vertical-align:middle}' +
    '.ttl{font-size:19px;font-weight:900;margin:6px 0 0;color:#0f172a;letter-spacing:-.3px}' +
    '.wkpill{display:inline-block;background:#fff1f4;color:#e11d48;font-weight:800;font-size:11px;padding:3px 9px;border-radius:20px;border:1px solid #fbd0db}' +
    '.btn{display:inline-block;background:#e50044;color:#ffffff !important;font-size:11px;font-weight:700;padding:7px 14px;border-radius:6px;text-decoration:none;margin-left:8px}' +
    '.sub{font-size:11px;color:#64748b;margin-top:8px;line-height:1.5}.sub b{color:#334155}' +
    '.card{background:#fff;border:1px solid #e2e8f0;border-radius:11px;margin-bottom:10px;overflow:hidden}' +
    '.acc{height:3px;font-size:0;line-height:3px}' +
    '.mname{font-size:12px;font-weight:800;padding:10px 14px 2px}' +
    '.mrange{font-size:9.5px;color:#94a3b8;padding:1px 14px 6px;line-height:1.4;font-variant-numeric:tabular-nums}' +
    '.wk-tbl{width:100%;border-collapse:collapse;font-size:9.5px}' +
    // nowrap en todas las celdas: los números NUNCA se parten en dos líneas.
    '.wk-tbl th{font-size:7.5px;text-transform:uppercase;letter-spacing:.1px;color:#94a3b8;font-weight:700;padding:5px 4px;border-bottom:1px solid #e9eef5;text-align:right;white-space:nowrap}' +
    '.wk-tbl th.l{text-align:left}' +
    '.wk-tbl td{padding:5px 4px;border-bottom:1px solid #f4f6fa;text-align:right;font-variant-numeric:tabular-nums;white-space:nowrap}' +
    '.wk-tbl th:first-child,.wk-tbl td:first-child{padding-left:4px}' +
    '.wk-tbl th:last-child,.wk-tbl td:last-child{padding-right:4px}' +
    // Contenedor con scroll horizontal para la tabla hero (12 col) en pantallas angostas.
    '.htblwrap{padding:0 14px 14px 14px;overflow-x:auto;-webkit-overflow-scrolling:touch}' +
    '.wk-tbl td.l{text-align:left;font-weight:600;color:#475569}' +
    '.wk-tbl td.now{font-weight:800;color:#0f172a}' +
    '.wk-tbl td.prev{color:#94a3b8}' +
    '.wk-tbl tr.latam td{border-top:2px solid #dbe3ee;border-bottom:none}' +
    '.wk-tbl th.rr{background:#faf5ff;color:#7c3aed}' +
    '.wk-tbl td.rr{background:#faf5ff}' +
    '.wk-tbl .rr1{border-left:2px solid #e2e8f0}' +
    '.pill{display:inline-block;font-size:9px;font-weight:700;padding:1px 5px;border-radius:20px}' +
    '.pill.up{background:#ecfdf5;color:#059669}.pill.dn{background:#fff1f2;color:#e11d48}.pill.flat{background:#f1f5f9;color:#64748b}' +
    '.sech{font-size:14px;font-weight:900;color:#0f172a;margin:18px 0 8px}' +
    '.tb{width:100%;border-collapse:collapse;margin-bottom:10px;border-radius:11px;overflow:hidden;background:#fff;border:1px solid #e2e8f0}' +
    // Clases del gráfico de barras (las usa _buildDailyChartsEmail). DEBEN coincidir
    // con las del mail diario; sin ellas las barras del semanal salen sin estilo (feas).
    '.sg{font-size:0;mso-line-height-rule:exactly}' +
    '.sl{font-family:Arial,sans-serif;font-size:7.5px;font-weight:800;color:#ffffff;white-space:nowrap;mso-line-height-rule:exactly;text-align:center;vertical-align:middle}' +
    '.bcw{padding:0 1.5px}' +
    '.cxd{font-family:Arial,sans-serif;font-size:8px;color:#334155;font-weight:700;padding-top:5px;text-align:center}' +
    '.cxt{font-family:Arial,sans-serif;font-size:7px;color:#94a3b8;font-weight:600;white-space:nowrap;padding-top:1px;text-align:center}' +
    '.cxa{font-family:Arial,sans-serif;font-size:7.5px;color:#0f172a;font-weight:800;white-space:nowrap;padding-top:2.5px;text-align:center}' +
    '.cxv{font-family:Arial,sans-serif;font-size:7.5px;font-weight:700;white-space:nowrap;padding-top:1.5px;text-align:center}' +
    // Grilla de 2 columnas para las métricas no-hero (celdas un poco más compactas).
    // Usamos table-layout: fixed para obligar a que las dos columnas midan exactamente 50% y no se estiren si hay overflow.
    '.grid2{table-layout:fixed;width:100%;border-collapse:separate}' +
    '.gcell{padding:0 4px;vertical-align:top}' +
    '.gcell .wk-tbl{font-size:9px !important}' +
    '.gcell .wk-tbl th{font-size:7.5px !important;padding:4px 4px !important}' +
    '.gcell .wk-tbl td{padding:4px 4px !important}' +
    '.gcell .wk-tbl th:first-child,.gcell .wk-tbl td:first-child{padding-left:4px !important}' +
    '.gcell .wk-tbl th:last-child,.gcell .wk-tbl td:last-child{padding-right:4px !important}' +
    '.gcell .pill{font-size:8.5px !important;padding:1px 3px !important}' +
    // Apilar la grilla a 1 columna cuando NO hay ancho para 2 tablas al lado (los
    // 6 col no-hero necesitan ~400px c/u): así nunca quedan apretadas ni con wrap.
    '@media only screen and (max-width:820px){' +
      '.grow,.gcell{display:block !important;width:100% !important}' +
      '.gcell{padding:0 !important}' +
    '}' +
    // Responsive del GRÁFICO (Gmail/Apple Mail): en móvil el KPI strip se apila y los
    // números del eje se achican para que NO se salgan del cuadro.
    '@media only screen and (max-width:480px){' +
      '.chdr-l,.chdr-r{display:block !important;width:100% !important;text-align:left !important}' +
      '.chdr-r{margin-top:10px !important}' +
      // El KPI strip es auto-layout con 4 celdas nowrap: su min-content fuerza el
      // panel más ancho que la pantalla. En móvil las apilamos/envolvemos (inline-block).
      '.kpis{width:100% !important}' +
      '.kpis td{display:inline-block !important;vertical-align:top;margin-bottom:5px !important}' +
      '.cxd,.cxa,.cxt,.cxv{font-size:7px !important;padding-left:0 !important;padding-right:0 !important}' +
      '.sl{font-size:7px !important}' +
    '}' +
    '.foot{font-size:11px;color:#94a3b8;text-align:center;padding:16px 0 4px}';

  // Gráfico diario de la semana cerrada (barras actual vs target, como el daily),
  // acotado a los 7 días lun→dom. Incluye el KPI de RR Mes (proyección mensual).
  var chartSection = '';
  if (typeof _buildDailyChartsEmail === 'function') {
    var sp2 = rng.start.split('-'), ep2 = rng.end.split('-');
    var startMs = new Date(+sp2[0], +sp2[1]-1, +sp2[2]).getTime();
    var endMs   = new Date(+ep2[0], +ep2[1]-1, +ep2[2]).getTime();
    var weekEnd = new Date(+ep2[0], +ep2[1]-1, +ep2[2]);
    var chartHtml = _buildDailyChartsEmail(weekEnd, !!forPdf, rrData,
      { startMs: startMs, endMs: endMs, periodTxt: 'LATAM · Semana ' + rng.labelShort });
    if (chartHtml) chartSection = '<div class="sech">Evolución diaria de la semana</div>' + chartHtml;
  }

  // Carga del mensaje personalizado del mail semanal (configurable de la pág "Email").
  // Si está vacío o no está definido, msgHtml es '' y no se ve nada.
  var weeklyMsgInfo = (typeof getWeeklyEmailMessageInfo === 'function')
    ? getWeeklyEmailMessageInfo()
    : { msg: '', by: '', at: '' };
  var weeklyMsgHtml = (typeof _buildMessageBlock === 'function')
    ? _buildMessageBlock(weeklyMsgInfo.msg, weeklyMsgInfo.by, weeklyMsgInfo.at)
    : '';

  var html =
    '<!DOCTYPE html><html lang="es"><head><meta charset="UTF-8">' +
    '<meta name="viewport" content="width=device-width,initial-scale=1">' +
    '<style>' + styles + '</style></head>' +
    '<body><div class="wrap">' +
      '<div class="hd">' +
        '<div class="kick"><span class="dot"></span>PeYa Markets · Weekly report</div>' +
        '<table width="100%" cellpadding="0" cellspacing="0" border="0"><tr>' +
          '<td valign="middle"><div class="ttl">Weekly report</div></td>' +
          '<td valign="middle" align="right" style="white-space:nowrap;">' +
            '<span class="wkpill">Semana ' + rng.labelShort + '</span>' +
            '<a href="' + APP_URL + '?page=mtd&src=mail-semanal" target="_blank" class="btn">Ver dashboard →</a>' +
          '</td>' +
        '</tr></table>' +
        '<div class="sub">Período: <b>' + rng.start + '</b> al <b>' + rng.end + '</b> (lunes a domingo). ' +
          '<b>Semana</b> = acumulado de esos días · en <b>Orders y GMV</b>: <b>' + beLbl + ' Sem.</b> = target (BE) sumado de la semana y <b>Act vs BE</b> = variación del actual vs ese BE · <b>WoW</b> vs la semana anterior · <b>MoM</b> vs mismo tramo del mes anterior · <b>YoY</b> vs mismo tramo del año anterior · ' + (RR_CLOSE ? '<b>Cierre de mes</b> = valor del mes ya cerrado' : '<b>RR Mes</b> = proyección mensual') + ' (solo Orders y GMV). Para semanas que cruzan de mes, el RR/BE Mensual corresponde al mes de cierre de la semana (' + endMonthName + ').</div>' +
      '</div>' +
      weeklyMsgHtml +
      cards +
      chartSection +
      '<div class="foot">' +
        '<div style="margin-bottom:15px;"><a href="' + APP_URL + '?page=mtd&src=mail-semanal" target="_blank" class="btn">Abrir dashboard interactivo →</a></div>' +
        'Desarrollado por el equipo de Strategy &amp; Performance · PeYa Markets' +
      '</div>' +
    '</div></body></html>';
  return { html: html, empty: false };
}

// ── Validación de datos completos para el Reporte Semanal ────────────
// Verifica que todos los datos de la semana cerrada (lunes a domingo)
// estén completos en Actuals, Usuarios Semanales y Targets antes del envío.
function verificarDatosActualizadosSemanal(rng) {
  if (!rng) rng = _weekRangeLunDom();
  var startMs = (typeof parseDateToMs === 'function') ? parseDateToMs(rng.start) : new Date(rng.start + 'T00:00:00').getTime();
  var endMs   = (typeof parseDateToMs === 'function') ? parseDateToMs(rng.end)   : new Date(rng.end   + 'T00:00:00').getTime();

  var faltantes = [];

  // 1) Actuals en "A. TI - Actuals OKRs" (Orders y GMV deben llegar al menos hasta el domingo rng.end)
  var act = (typeof _getFechasActuals === 'function') ? _getFechasActuals() : { orders: null, gmv: null };
  if (!act.orders || act.orders < rng.end) {
    faltantes.push('Confirmed Orders en Actuals llega hasta ' + (act.orders || 'sin dato') + ' (la semana cierra el ' + rng.end + ')');
  }
  if (!act.gmv || act.gmv < rng.end) {
    faltantes.push('GMV User Dmarts en Actuals llega hasta ' + (act.gmv || 'sin dato') + ' (la semana cierra el ' + rng.end + ')');
  }

  // 2) Pestaña "C. Weekly users": debe existir la fila de la semana cerrada
  var hasWeeklyUsersSheetOk = false;
  try {
    var ss = SpreadsheetApp.openById(SPREADSHEET_ID);
    var sh = _openWeeklyUsersSheet(ss);
    if (!sh) {
      faltantes.push('Pestaña de usuarios semanales ("' + WEEKLY_USERS_SHEET + '") no encontrada');
    } else {
      var data = sh.getDataRange().getValues();
      var H = (data[0] || []).map(function(h){ return String(h || '').trim().toLowerCase(); });
      var iW = H.indexOf('week');
      if (iW < 0) iW = H.indexOf('semana');
      if (iW < 0) iW = H.indexOf('date');
      var hasWeek = false;
      if (iW >= 0) {
        for (var i = 1; i < data.length; i++) {
          var wMs = (typeof parseDateToMs === 'function') ? parseDateToMs(data[i][iW]) : new Date(data[i][iW]).getTime();
          if (!isNaN(wMs) && wMs >= startMs && wMs <= endMs) {
            hasWeek = true;
            break;
          }
        }
      }
      if (!hasWeek) {
        faltantes.push('Pestaña "' + sh.getName() + '": falta cargar la semana ' + rng.labelShort + ' (' + rng.start + ' al ' + rng.end + ')');
      } else {
        hasWeeklyUsersSheetOk = true;
      }
    }
  } catch (eWk) {
    faltantes.push('Error leyendo usuarios semanales: ' + eWk.message);
  }

  // 3) Targets diarios de la semana (weeklyBE)
  try {
    var be = _readWeeklyBE(rng.start, rng.end);
    if (!be.orders || !be.orders['LATAM'] || be.orders['LATAM'] <= 0) {
      faltantes.push('Targets (BE) de Confirmed Orders no disponibles para la semana ' + rng.labelShort);
    }
    if (!be.gmv || !be.gmv['LATAM'] || be.gmv['LATAM'] <= 0) {
      faltantes.push('Targets (BE) de GMV no disponibles para la semana ' + rng.labelShort);
    }
  } catch (eBe) {
    faltantes.push('Error leyendo targets semanales: ' + eBe.message);
  }

  // 4) Validación exhaustiva de todas las métricas del Reporte Semanal
  try {
    var mtdRes = fetchMtdActuals(rng.start, rng.end);
    var p = mtdRes && mtdRes.payload;
    if (!p || p.error || !p.metrics) {
      faltantes.push('Cálculo de métricas falló para la semana ' + rng.labelShort + ': ' + ((p && p.error) || 'sin datos'));
    } else {
      var metrics = p.metrics || {};
      var config  = p.config  || {};
      var dtByMetric = p.dataThroughByMetric || {};

      // Lista de métricas que componen el mail semanal (respetando orden y exclusiones)
      var metricKeys = WK_METRIC_ORDER.filter(function(m){
        return WK_METRIC_EXCLUDE.indexOf(m) < 0;
      });
      Object.keys(metrics).forEach(function(m){
        var cfg = config[m] || {};
        var isMtd = !!(cfg.mtd || /- MTD/i.test(m));
        if (metricKeys.indexOf(m) < 0 && WK_METRIC_EXCLUDE.indexOf(m) < 0 && !isMtd) {
          metricKeys.push(m);
        }
      });

      var metricsByLagDate = {}; // dt -> [displayName, ...]
      var metricsSinDatos = [];

      metricKeys.forEach(function(m){
        var cfg = config[m] || {};
        var mRows = metrics[m];
        var displayName = WK_METRIC_DISPLAY[m] || m;

        // 4.1 Métricas semanales fijas de usuarios (C. Weekly users)
        // Solo las reportamos si no se reportó ya la pestaña completa en el paso 2
        if (cfg.weekly) {
          if (!hasWeeklyUsersSheetOk) return;
          if (!mRows || Object.keys(mRows).length === 0) {
            faltantes.push('Usuarios semanales ("' + displayName + '"): sin registros cargados');
          }
          return;
        }

        // 4.2 Métricas diarias acumuladas: deben tener datos hasta el domingo de cierre (rng.end)
        if (m === 'Confirmed Orders' && (!act.orders || act.orders < rng.end)) return;
        if (m === 'GMV User Dmarts' && (!act.gmv || act.gmv < rng.end)) return;

        var dt = dtByMetric[m];
        if (!dt) {
          metricsSinDatos.push(displayName);
        } else if (dt < rng.end) {
          if (!metricsByLagDate[dt]) metricsByLagDate[dt] = [];
          metricsByLagDate[dt].push(displayName);
        } else if (!mRows || Object.keys(mRows).length === 0) {
          faltantes.push(displayName + ': sin datos consolidados para la semana ' + rng.labelShort);
        }
      });

      // Agrupar métricas retrasadas en una sola línea clara por fecha
      Object.keys(metricsByLagDate).forEach(function(dt){
        var list = metricsByLagDate[dt];
        faltantes.push('Métricas con datos hasta el ' + dt + ' (falta domingo ' + rng.end + '): ' + list.join(', '));
      });

      if (metricsSinDatos.length > 0) {
        faltantes.push('Métricas sin datos cargados: ' + metricsSinDatos.join(', '));
      }
    }
  } catch (eMtd) {
    faltantes.push('Error calculando métricas semanales: ' + eMtd.message);
  }

  var ok = (faltantes.length === 0);
  return {
    ok: ok,
    semana: rng.labelShort,
    start: rng.start,
    end: rng.end,
    faltantes: faltantes,
    motivo: faltantes.join(' · ')
  };
}

// ── Envío de aviso por correo a Matias cuando fallan las métricas semanales ──
function enviarAlertaMetricasDesactualizadasSemanal(rng, check) {
  var ALERTA_RECIPIENT = 'matias.cagliero@pedidosya.com';
  if (!rng) rng = _weekRangeLunDom();
  if (!check) check = verificarDatosActualizadosSemanal(rng);

  var itemsHtml = '';
  (check.faltantes || []).forEach(function(item) {
    itemsHtml += '<li style="margin-bottom:8px;line-height:1.45;color:#991b1b;font-weight:600;">' + item + '</li>';
  });
  if (!itemsHtml) {
    itemsHtml = '<li style="color:#991b1b;">' + (check.motivo || 'Métricas con datos incompletos') + '</li>';
  }

  var subject = '[ALERTA] Reporte Semanal NO enviado — Métricas desactualizadas (' + rng.labelShort + ')';

  var htmlBody =
    '<!DOCTYPE html><html lang="es"><head><meta charset="UTF-8">' +
    '<meta name="viewport" content="width=device-width,initial-scale=1">' +
    '</head><body style="margin:0;background:#f8fafc;font-family:Arial,Helvetica,sans-serif;color:#0f172a;padding:24px 12px;">' +
    '<div style="max-width:620px;margin:0 auto;background:#ffffff;border:1px solid #fee2e2;border-radius:12px;overflow:hidden;box-shadow:0 4px 6px -1px rgba(0,0,0,0.05);">' +
      '<div style="background:#dc2626;padding:16px 20px;color:#ffffff;">' +
        '<div style="font-size:11px;font-weight:800;letter-spacing:0.5px;text-transform:uppercase;opacity:0.9;">PeYa Markets · Alerta Automática</div>' +
        '<div style="font-size:18px;font-weight:900;margin-top:4px;">Reporte Semanal NO Enviado</div>' +
      '</div>' +
      '<div style="padding:20px;">' +
        '<div style="background:#fef2f2;border:1px solid #fecaca;border-radius:8px;padding:14px 16px;margin-bottom:18px;">' +
          '<div style="font-size:13px;color:#991b1b;line-height:1.5;">' +
            'El envío automático programado para las <b>12:00 hs</b> de hoy fue <b>cancelado y bloqueado</b> porque se detectaron métricas sin actualizar para la semana cerrada <b>' + rng.labelShort + '</b> (' + rng.start + ' al ' + rng.end + ').' +
          '</div>' +
        '</div>' +
        '<div style="font-size:13px;font-weight:800;color:#0f172a;margin-bottom:8px;text-transform:uppercase;letter-spacing:0.3px;">' +
          'Métricas o datos faltantes / desactualizados:' +
        '</div>' +
        '<ul style="margin:0 0 20px 0;padding-left:20px;font-size:12.5px;">' +
          itemsHtml +
        '</ul>' +
        '<div style="background:#f0f9ff;border:1px solid #bae6fd;border-radius:8px;padding:14px 16px;font-size:12.5px;color:#0369a1;line-height:1.5;margin-bottom:20px;">' +
          '<b>¿Cómo proceder?</b><br>' +
          '1. Verificá la actualización de BigQuery / Sheets para las métricas indicadas.<br>' +
          '2. Una vez que los datos estén al día (hasta el domingo ' + rng.end + '), ingresá a la sección <b>Email</b> del dashboard y hacé clic en <b>"Enviar semanal forzado"</b> para despachar el reporte a todos los destinatarios.' +
        '</div>' +
        '<div style="text-align:center;margin-bottom:10px;">' +
          '<a href="' + APP_URL + '?page=email&src=alerta-semanal" target="_blank" style="display:inline-block;background:#e50044;color:#ffffff;text-decoration:none;font-weight:700;font-size:13px;padding:10px 22px;border-radius:8px;">' +
            'Abrir Panel de Envío de Email →' +
          '</a>' +
        '</div>' +
      '</div>' +
      '<div style="background:#f8fafc;border-top:1px solid #f1f5f9;padding:12px 20px;font-size:11px;color:#94a3b8;text-align:center;">' +
        'Alerta automática generada por el sistema de reportes de PeYa Markets' +
      '</div>' +
    '</div>' +
    '</body></html>';

  try {
    MailApp.sendEmail({
      to: ALERTA_RECIPIENT,
      subject: subject,
      htmlBody: htmlBody,
      name: 'PeYa Market Performance - Alertas'
    });
    Logger.log('[enviarAlertaMetricasDesactualizadasSemanal] Alerta enviada con éxito a ' + ALERTA_RECIPIENT);
    return { ok: true, recipient: ALERTA_RECIPIENT, items: check.faltantes };
  } catch (err) {
    Logger.log('[enviarAlertaMetricasDesactualizadasSemanal] Error enviando alerta: ' + err.message);
    return { ok: false, error: err.message };
  }
}

// Función para probar el envío del correo de alerta desde el editor
function probarAlertaSemanal() {
  var rng = _weekRangeLunDom();
  var check = verificarDatosActualizadosSemanal(rng);
  if (check.ok) {
    check = {
      ok: false,
      semana: rng.labelShort,
      start: rng.start,
      end: rng.end,
      faltantes: [
        '[SIMULACIÓN] WIS %: datos hasta ' + rng.start + ' (esperado hasta domingo ' + rng.end + ')',
        '[SIMULACIÓN] Seamless Delivery %: datos hasta ' + rng.start + ' (esperado hasta domingo ' + rng.end + ')'
      ],
      motivo: 'Simulación de prueba de alerta'
    };
  }
  return enviarAlertaMetricasDesactualizadasSemanal(rng, check);
}

// ── Envío / preview ──────────────────────────────────────────────────
function sendWeeklyMtdEmail(previewMode, testMode, force) {
  var rng = _weekRangeLunDom();

  // ── Validación de datos completos para el envío semanal ─────────────────
  // Si previewMode=false (envío real o de prueba) y no es forzado (force=true),
  // se valida que TODOS los datos de la semana estén cargados y actualizados.
  var check = verificarDatosActualizadosSemanal(rng);
  if (!previewMode && !force && !check.ok) {
    Logger.log('[sendWeeklyMtdEmail] ENVÍO SEMANAL OMITIDO: ' + check.motivo);
    return {
      ok: false,
      error: check.motivo,
      motivo: check.motivo,
      check: check
    };
  }

  // Caché de actuals para ese rango y el rango anterior: la limpiamos para traer fresco (limpia v1 y v2).
  try {
    var cache = CacheService.getScriptCache();
    cache.remove('cache_mtd_actuals_' + rng.start + '_' + rng.end);
    cache.remove('cache_mtd_actuals_v2_' + rng.start + '_' + rng.end);
    
    // También limpiamos el caché de la semana anterior de forma 100% segura contra descalces de Timezone
    var tz = Session.getScriptTimeZone();
    var pS = rng.start.split('-');
    var dS = new Date(parseInt(pS[0], 10), parseInt(pS[1], 10) - 1, parseInt(pS[2], 10), 12, 0, 0);
    dS.setDate(dS.getDate() - 7);
    var prevStart = Utilities.formatDate(dS, tz, 'yyyy-MM-dd');
    
    var pE = rng.end.split('-');
    var dE = new Date(parseInt(pE[0], 10), parseInt(pE[1], 10) - 1, parseInt(pE[2], 10), 12, 0, 0);
    dE.setDate(dE.getDate() - 7);
    var prevEnd = Utilities.formatDate(dE, tz, 'yyyy-MM-dd');
    
    cache.remove('cache_mtd_actuals_' + prevStart + '_' + prevEnd);
    cache.remove('cache_mtd_actuals_v2_' + prevStart + '_' + prevEnd);
  } catch (e) {}

  var built = _buildWeeklyMtdHtml(rng);
  // Minificado (saca saltos/indentación) para que el mail no supere el límite
  // de Gmail (~102KB) y no se recorte. _minifyEmailHtml está en Email.gs (global).
  var html = (typeof _minifyEmailHtml === 'function') ? _minifyEmailHtml(built.html) : built.html;
  Logger.log('Tamaño HTML del mail semanal: ' + Math.round(html.length / 1024) + ' KB (Gmail recorta > ~102 KB)');
  var subject = 'PeYa Markets — Weekly report | ' + rng.labelShort;
  // PDF: el conversor de GAS NO renderiza las barras HTML (se colapsan a 0), así que
  // el PDF se arma con el gráfico como IMAGEN nativa (forPdf=true), igual que el diario.
  var builtPdf = _buildWeeklyMtdHtml(rng, true);
  var htmlPdf = (typeof _minifyEmailHtml === 'function') ? _minifyEmailHtml(builtPdf.html) : builtPdf.html;
  var pdf = _generatePdfFromHtml(htmlPdf, rng.fileLabel);   // PDF con nombre claro

  if (previewMode) {
    var folderName = 'PeYa Email Preview';
    var it = DriveApp.getFoldersByName(folderName);
    var folder = it.hasNext() ? it.next() : DriveApp.createFolder(folderName);
    var htmlFile = folder.createFile(rng.fileLabel + '.html', html, MimeType.HTML);
    var pdfUrl = pdf ? folder.createFile(pdf).getUrl() : '(no se generó)';
    Logger.log('───── PREVIEW SEMANAL (no se envió) ─────');
    Logger.log('Semana   : ' + rng.start + ' al ' + rng.end);
    Logger.log('HTML     : ' + htmlFile.getUrl());
    Logger.log('PDF      : ' + pdfUrl);
    return { ok:true, preview:true, week:rng, htmlUrl:htmlFile.getUrl(), pdfUrl:pdfUrl, empty:built.empty };
  }

  // testMode: envío de PRUEBA → un único destinatario (matias.cagliero), con [PRUEBA].
  var TEST_RECIPIENT = 'matias.cagliero@pedidosya.com';
  if (testMode) {
    MailApp.sendEmail({
      to:          TEST_RECIPIENT,
      subject:     '[PRUEBA] ' + subject,
      htmlBody:    html,
      attachments: pdf ? [pdf] : [],
      name:        'PeYa Market Performance - Regional'
    });
    Logger.log('Email SEMANAL de PRUEBA enviado SOLO a: ' + TEST_RECIPIENT + '. Semana ' + rng.labelShort);
    _logEnvioLote('prueba-semanal', '[PRUEBA] ' + subject, 1, 1, TEST_RECIPIENT, [TEST_RECIPIENT]);
    return { ok:true, test:true, sent:1, to:TEST_RECIPIENT, week:rng };
  }

  // Envío masivo: CCO en lotes (mismo motivo que el diario: límite de destinatarios
  // por mensaje de Gmail). _sendEmailBccBatched está en Email.gs (alcance global).
  var batches = _sendEmailBccBatched({
    tipo:        'semanal',
    subject:     subject,
    htmlBody:    html,
    attachments: pdf ? [pdf] : []
  });
  var _nDest = getEmailRecipients().length;
  Logger.log('Email SEMANAL enviado (CCO) en ' + batches + ' lote(s) a ' + _nDest + ' destinatarios. Semana ' + rng.labelShort);

  // Si el mensaje estaba marcado como "un solo envío", se borra automáticamente
  if (batches > 0) {
    try {
      var _p = PropertiesService.getScriptProperties();
      if (_p.getProperty('WEEKLY_EMAIL_CUSTOM_MSG_ONCE') === 'true') {
        _p.deleteProperty('WEEKLY_EMAIL_CUSTOM_MSG');
        _p.deleteProperty('WEEKLY_EMAIL_CUSTOM_MSG_BY');
        _p.deleteProperty('WEEKLY_EMAIL_CUSTOM_MSG_AT');
        _p.deleteProperty('WEEKLY_EMAIL_CUSTOM_MSG_ONCE');
        Logger.log('[sendWeeklyMtdEmail] Mensaje semanal de un solo uso eliminado tras el envío.');
      }
    } catch (_eOnce) {}
  }

  return { ok:true, sent:_nDest, week:rng, batches:batches };
}

function previewWeeklyEmail() { var r = sendWeeklyMtdEmail(true);  Logger.log(JSON.stringify(r, null, 2)); return r; }

// ENVÍO DE PRUEBA (semanal): manda el mail semanal real (mismo contenido, gráfico
// y PDF que el envío masivo) SOLO a matias.cagliero@pedidosya.com — sin CCO al
// resto y con [PRUEBA] en el asunto. No toca el guard semanal (PROP_KEY_SEM),
// así que no marca la semana como enviada ni interfiere con el envío real.
function enviarPruebaSemanal(force) {
  var isForce = (force !== undefined) ? !!force : true;
  var r = sendWeeklyMtdEmail(false, true, isForce);   // previewMode=false, testMode=true, force
  Logger.log('Envío SEMANAL de PRUEBA → ' + JSON.stringify(r, null, 2));
  return r;
}

// ENVÍO DE PRUEBA FORZADO (semanal): Se puede seleccionar y correr DIRECTAMENTE
// desde el editor de Apps Script. Saltea todas las validaciones de datos incompletos
// o pestañas faltantes (force=true) y envía el reporte semanal de prueba
// exclusivamente a matias.cagliero@pedidosya.com sin CCO y con [PRUEBA].
function forzarEnvioPruebaSemanal() {
  Logger.log('>>> [forzarEnvioPruebaSemanal] Iniciando envío de prueba forzado a matias.cagliero@pedidosya.com...');
  var r = sendWeeklyMtdEmail(false, true, true); // previewMode=false, testMode=true, force=true
  Logger.log('Resultado envío SEMANAL de PRUEBA FORZADO → ' + JSON.stringify(r, null, 2));
  return r;
}

// Envío manual forzado: ignora ventana horaria, dedup y chequeos de fecha. Marca la semana como
// enviada y limpia cualquier estado de bloqueo para que el trigger no la repita.
function forzarEnvioSemanal() {
  var rng = _weekRangeLunDom();
  var r = sendWeeklyMtdEmail(false, false, true); // force=true
  if (r && r.ok) {
    PropertiesService.getScriptProperties().setProperty(PROP_KEY_SEM, rng.start);
    PropertiesService.getScriptProperties().deleteProperty('WEEKLY_BLOCKED_REASON');
  }
  Logger.log(JSON.stringify(r, null, 2));
  return r;
}

// Endpoint para invocar el envío forzado desde la interfaz web (7_Email.html)
function forzarEnvioSemanalDesdeUi() {
  return forzarEnvioSemanal();
}

// Envío forzado del Reporte Semanal con exclusión de destinatarios desmarcados
function forzarEnvioWeeklyFiltrado(excluidos) {
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
    var rng = _weekRangeLunDom();
    var res = sendWeeklyMtdEmail(false, false, true); // force=true
    if (res && res.ok) {
      PropertiesService.getScriptProperties().setProperty(PROP_KEY_SEM, rng.start);
      PropertiesService.getScriptProperties().deleteProperty('WEEKLY_BLOCKED_REASON');
    }
    return res;
  } finally {
    _FORCE_RECIPIENTS = null;
  }
}

// Estado del envío semanal para el panel "Email"
function getWeeklyEmailStatus() {
  var zona = Session.getScriptTimeZone();
  var props = PropertiesService.getScriptProperties();
  var ultimo = props.getProperty(PROP_KEY_SEM) || '';
  var rng = _weekRangeLunDom();
  var isBlocked = (ultimo === rng.start + '_BLOCKED');
  var isSent = (ultimo === rng.start);
  var check = null;
  try {
    check = verificarDatosActualizadosSemanal(rng);
  } catch (e) {
    check = { ok: false, motivo: 'Error verificando datos: ' + e.message };
  }

  // Si estaba bloqueado pero los datos AHORA están listos, se desbloquea automáticamente
  if (isBlocked && check && check.ok) {
    props.deleteProperty(PROP_KEY_SEM);
    props.deleteProperty('WEEKLY_BLOCKED_REASON');
    isBlocked = false;
    ultimo = '';
  } else if (isBlocked && check && !check.ok && check.motivo) {
    // Si sigue bloqueado, actualizamos el motivo con el estado en vivo más reciente
    props.setProperty('WEEKLY_BLOCKED_REASON', check.motivo);
  }

  return {
    dia: DIA_ENVIO_SEM,
    hora: HORA_ENVIO_SEM,
    minuto: MINUTO_ENVIO_SEM,
    horaStr: HORA_ENVIO_SEM + ':' + String(MINUTO_ENVIO_SEM).padStart(2, '0'),
    zona: zona,
    semana: rng.labelShort,
    semanaStart: rng.start,
    semanaEnd: rng.end,
    ultimoEnvio: ultimo,
    enviadoEstaSemana: isSent,
    bloqueadoEstaSemana: isBlocked,
    motivoBloqueo: (check && !check.ok) ? check.motivo : (props.getProperty('WEEKLY_BLOCKED_REASON') || ''),
    dataCheck: check
  };
}

// Entrada del trigger (corre cada 10 min). Mismo patrón que checkYEnviarEmail:
// chequea día (lunes), ventana horaria y dedup por semana antes de enviar.
function checkYEnviarSemanal() {
  const zona  = Session.getScriptTimeZone();
  const ahora = new Date();
  const dow   = parseInt(Utilities.formatDate(ahora, zona, 'u'), 10) % 7; // u: 1=Lun..7=Dom → 0=Dom
  const hh    = parseInt(Utilities.formatDate(ahora, zona, 'H'), 10);
  const mm    = parseInt(Utilities.formatDate(ahora, zona, 'm'), 10);
  const minAhora = hh * 60 + mm;
  const minObj   = HORA_ENVIO_SEM * 60 + MINUTO_ENVIO_SEM;

  const rng   = _weekRangeLunDom();   // semana lun→dom que se reportaría hoy
  const props = PropertiesService.getScriptProperties();
  const ultimo = props.getProperty(PROP_KEY_SEM) || 'nunca';

  Logger.log('=== checkYEnviarSemanal ===');
  Logger.log('Hora actual : ' + Utilities.formatDate(ahora, zona, 'EEE HH:mm') + ' (' + zona + ')');
  Logger.log('Ventana     : Lunes ' + HORA_ENVIO_SEM + ':' + String(MINUTO_ENVIO_SEM).padStart(2,'0') +
             ' → ' + HORA_ENVIO_SEM + ':' + String(MINUTO_ENVIO_SEM + VENTANA_SEM_MIN).padStart(2,'0'));
  Logger.log('Semana      : ' + rng.start + ' al ' + rng.end);
  Logger.log('Último envío: ' + ultimo);

  if (dow !== DIA_ENVIO_SEM) { Logger.log('Estado      : NO es lunes — no se envía'); Logger.log('==='); return; }
  if (minAhora < minObj || minAhora > minObj + VENTANA_SEM_MIN) {
    Logger.log('Estado      : FUERA DE VENTANA — no se envía'); Logger.log('==='); return;
  }
  if (ultimo === rng.start || ultimo === rng.start + '_BLOCKED') {
    Logger.log('Estado      : YA ENVIADO O BLOQUEADO esta semana (' + ultimo + ') — se omite');
    Logger.log('===');
    return;
  }

  // ── Validación de datos completos al momento del envío ──────────────────────
  // Si los datos de la semana no están completos, se BLOQUEA el envío para toda
  // la semana (no se reintenta automáticamente) y se envía una ALERTA por mail
  // a matias.cagliero@pedidosya.com informando el detalle de las métricas faltantes.
  const check = verificarDatosActualizadosSemanal(rng);
  if (!check.ok) {
    props.setProperty(PROP_KEY_SEM, rng.start + '_BLOCKED');
    props.setProperty('WEEKLY_BLOCKED_REASON', check.motivo);
    Logger.log('Estado      : DATOS INCOMPLETOS — ' + check.motivo);
    Logger.log('Acción      : [BLOQUEADO] Envío semanal cancelado para la semana ' + rng.labelShort + ' (' + rng.start + '). Enviando alerta a matias.cagliero@pedidosya.com...');

    enviarAlertaMetricasDesactualizadasSemanal(rng, check);

    Logger.log('===');
    return { ok: false, blocked: true, error: check.motivo, week: rng, alertaEnviada: true };
  }

  Logger.log('Estado      : DENTRO DE VENTANA Y DATOS COMPLETOS — enviando...');
  const r = sendWeeklyMtdEmail(false);
  if (r && r.ok) {
    props.setProperty(PROP_KEY_SEM, rng.start);
    props.deleteProperty('WEEKLY_BLOCKED_REASON');
    Logger.log('Resultado   : [OK] Enviado a ' + r.sent + ' destinatarios — semana ' + rng.labelShort);
  } else {
    // Si ocurrió un error en el envío, también bloqueamos para no reintentar automáticamente
    props.setProperty(PROP_KEY_SEM, rng.start + '_BLOCKED');
    props.setProperty('WEEKLY_BLOCKED_REASON', (r && r.error) || 'Error desconocido al enviar');
    Logger.log('Resultado   : [ERROR] Error al enviar — ' + (r && r.error || 'desconocido') + '. Bloqueado para reintentos automáticos.');
  }
  Logger.log('===');
  return r;
}

// Instala el envío automático (idempotente). Correr UNA vez desde el editor,
// igual que setupTriggerEmail() del Daily: trigger cada 10 min que delega en
// checkYEnviarSemanal(). Borra duplicados previos antes de crear.
function setupTriggerSemanal() {
  ['checkYEnviarSemanal', 'sendWeeklyMtdEmail'].forEach(function(handler){
    ScriptApp.getProjectTriggers()
      .filter(function(t){ return t.getHandlerFunction() === handler; })
      .forEach(function(t){ ScriptApp.deleteTrigger(t); });
  });
  ScriptApp.newTrigger('checkYEnviarSemanal').timeBased().everyMinutes(10).create();
  Logger.log('Trigger semanal instalado (cada 10 min → checkYEnviarSemanal). Envía lunes ~' +
             HORA_ENVIO_SEM + ':' + String(MINUTO_ENVIO_SEM).padStart(2,'0') + 'hs, semana lun-dom anterior.');
  return { ok:true };
}

// ── Función de debug temporal para verificar componentes de Ops en la hoja de OKRs ──
function debugWeeklyMetrics() {
  var ss = SpreadsheetApp.openById(SPREADSHEET_ID);
  var sheet = ss.getSheetByName(SHEET_ACTUALS);
  if (!sheet) {
    Logger.log("[ERROR] No se encontró la hoja: " + SHEET_ACTUALS);
    return;
  }
  var data = sheet.getDataRange().getValues();
  Logger.log("Total de filas en A. TI - Actuals OKRs: " + data.length);
  
  var headers = data[0];
  var idxMetric = headers.indexOf('Metric');
  var idxCountry = headers.indexOf('Country');
  var idxDate = headers.indexOf('Date');
  var idxValue = headers.indexOf('Value');
  
  var wisComponents = [
    'WIS Numerador', 'WIS Denominador', 'WIS UF Numerador', 'WIS UF Denominador',
    'Numerador WIS', 'Denominador WIS', 'Numerador WIS UF', 'Denominador WIS UF'
  ];
  
  var foundCounts = {};
  wisComponents.forEach(function(comp) { foundCounts[comp] = 0; });
  
  var prevWeekRows = []; // Aug 10 - Aug 16
  var curWeekRows = [];  // Aug 17 - Aug 23
  
  var startPrev = new Date(2026, 7, 10);
  var endPrev = new Date(2026, 7, 16);
  var startCur = new Date(2026, 7, 17);
  var endCur = new Date(2026, 7, 23);
  
  for (var i = 1; i < data.length; i++) {
    var metric = data[i][idxMetric];
    if (wisComponents.indexOf(metric) !== -1) {
      foundCounts[metric]++;
      
      var rawDate = data[i][idxDate];
      var d = null;
      if (rawDate instanceof Date) {
        d = rawDate;
      } else if (rawDate) {
        var ymd = normalizeDateToYMD(rawDate);
        if (ymd) {
          var p = ymd.split('-');
          d = new Date(parseInt(p[0]), parseInt(p[1])-1, parseInt(p[2]));
        }
      }
      
      if (d) {
        var rowObj = {
          row: i + 1,
          metric: metric,
          country: data[i][idxCountry],
          date: Utilities.formatDate(d, Session.getScriptTimeZone(), 'yyyy-MM-dd'),
          value: data[i][idxValue]
        };
        if (d >= startPrev && d <= endPrev && prevWeekRows.length < 15) {
          prevWeekRows.push(rowObj);
        } else if (d >= startCur && d <= endCur && curWeekRows.length < 15) {
          curWeekRows.push(rowObj);
        }
      }
    }
  }
  
  Logger.log("=== Conteo de filas encontradas por componente de WIS (en toda la hoja) ===");
  Object.keys(foundCounts).forEach(function(comp) {
    Logger.log("· " + comp + ": " + foundCounts[comp] + " filas");
  });
  
  Logger.log("=== Muestras de la semana anterior (10/08 al 16/08) ===");
  if (prevWeekRows.length === 0) {
    Logger.log("[ERROR] ¡Ningún componente de WIS tiene datos en la semana del 10/08 al 16/08!");
  } else {
    prevWeekRows.forEach(function(row) {
      Logger.log("Fila " + row.row + ": " + row.metric + " | " + row.country + " | " + row.date + " | " + row.value);
    });
  }
  
  Logger.log("=== Muestras de la semana actual (17/08 al 23/08) ===");
  if (curWeekRows.length === 0) {
    Logger.log("[ERROR] ¡Ningún componente de WIS tiene datos en la semana del 17/08 al 23/08!");
  } else {
    curWeekRows.forEach(function(row) {
      Logger.log("Fila " + row.row + ": " + row.metric + " | " + row.country + " | " + row.date + " | " + row.value);
    });
  }

  // ── NUEVO: Ejecutar fetchMtdActuals para la semana anterior y loggear resultado real ──
  Logger.log("=== NUEVO: Ejecutando fetchMtdActuals('2026-08-10', '2026-08-16') ===");
  try {
    CacheService.getScriptCache().remove('cache_mtd_actuals_v2_2026-08-10_2026-08-16');
    var res = fetchMtdActuals('2026-08-10', '2026-08-16');
    if (res && res.payload) {
      var metrics = res.payload.metrics || {};
      Logger.log("Métricas calculadas en la semana pasada para Argentina (TODAS):");
      Object.keys(metrics).forEach(function(mKey) {
        Logger.log("· " + mKey + " -> " + JSON.stringify(metrics[mKey]['AR'] || {}));
      });
    } else {
      Logger.log("[ERROR] fetchMtdActuals no devolvió payload");
    }
  } catch(err) {
    Logger.log("[ERROR] Error en fetchMtdActuals: " + err.message);
  }
}
