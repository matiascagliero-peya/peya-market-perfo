/**
 * Data Hub — Pedidos Ya Market · Ranking mensual
 * Web app de Apps Script con 3 funciones:
 *   1) PANEL  : página para editar todos los datos del mail y enviarlo.
 *   2) CLICKS : cada link del mail pasa por acá (?p=click&u=email),
 *               se registra el click en una hoja de cálculo y se
 *               redirige a pedidosya.thedatahub.com.ar.
 *   3) STATS  : el panel muestra clicks por día y quiénes entraron.
 *
 * DEPLOY (una sola vez):
 *   1. script.google.com → Nuevo proyecto → pegar este archivo en Código.gs
 *   2. Archivo → HTML → nombrarlo "Panel" → pegar Panel.html
 *   3. Implementar → Nueva implementación → Aplicación web
 *        · Ejecutar como: VOS
 *        · Quién accede: "Cualquier usuario de pedidosya.com"
 *          (así el tracking identifica QUIÉN entra, no solo cuántos)
 *   4. Abrir la URL /exec → ese es tu panel.
 *
 * Los datos se guardan en ScriptProperties; los clicks en una hoja
 * "Data Hub — Clicks del email" que se crea sola en tu Drive.
 */

const URL_DATAHUB = 'https://pedidosya.thedatahub.com.ar';
const PROP_DATA   = 'RANKING_DATA_V1';
const PROP_SHEET  = 'CLICKS_SHEET_ID';

// Logo oficial de PedidosYa, tomado directo de Wikimedia Commons.
const LOGO_URL = 'https://upload.wikimedia.org/wikipedia/commons/c/c5/Isologotipo_PedidosYa.jpg';

// ===================== RUTAS =====================
function doGet(e) {
  if (e && e.parameter && e.parameter.p === 'click') return registrarClick_(e);
  return HtmlService.createHtmlOutputFromFile('Panel')
    .setTitle('Data Hub — Ranking mensual')
    .addMetaTag('viewport', 'width=device-width, initial-scale=1');
}

// ===================== DATOS =====================
function datosPorDefecto_() {
  return {
    destinatarios: '',
    asunto: 'Ranking de uso — Data Hub · junio 2026',
    periodo: 'junio 2026',
    saludo: 'Hola equipo 👋',
    mensaje: 'Cerramos junio con más equipos usando el Data Hub en su día a día. '
           + 'Gracias por sumarse y seguir explorando los reportes y el glosario. '
           + '¿Falta alguna métrica o reporte? Escribime y lo agregamos.',
    firma: '— Matías',
    logoUrl: '',
    headerGifUrl: '',
    totales: { usuarios: 16, sesiones: 472, links: 403, metricas: '' },
    usuarios: [
      { nombre: 'felipe.salaverria@pedidosya.com', valor: 59 },
      { nombre: 'tobias.fay@pedidosya.com', valor: 23 },
      { nombre: 'seba.aquije@pedidosya.com', valor: 13 },
    ],
    metricas: ['Net Sales o Retail Sales', '% CPO / AFV', 'CVR3 (Conversion Rate 3)'],
    reportes: ['Análisis de ajustes', '1. Diccionario de Métricas - PeYa Market'],
    plataformas: [
      { nombre: 'datahub', usuarios: 11 },
      { nombre: 'navlink', usuarios: 3 },
      { nombre: 'glosario', usuarios: 2 },
    ],
    extras: [],
  };
}

function obtenerDatos() {
  var raw = PropertiesService.getScriptProperties().getProperty(PROP_DATA);
  var d = raw ? JSON.parse(raw) : datosPorDefecto_();
  d.urlDataHub = URL_DATAHUB;
  return d;
}

function guardarDatos(data) {
  PropertiesService.getScriptProperties().setProperty(PROP_DATA, JSON.stringify(data));
  return 'Datos guardados';
}

// ===================== CLICKS =====================
function hojaClicks_() {
  var props = PropertiesService.getScriptProperties();
  var id = props.getProperty(PROP_SHEET);
  var ss = null;
  if (id) { try { ss = SpreadsheetApp.openById(id); } catch (err) { ss = null; } }
  if (!ss) {
    ss = SpreadsheetApp.create('Data Hub — Clicks del email');
    props.setProperty(PROP_SHEET, ss.getId());
    var sh0 = ss.getSheets()[0];
    sh0.setName('clicks');
    sh0.appendRow(['timestamp', 'fecha', 'quien', 'email_sesion', 'email_link']);
  }
  return ss.getSheetByName('clicks') || ss.getSheets()[0];
}

function registrarClick_(e) {
  try {
    var u = String((e.parameter && e.parameter.u) || '').toLowerCase();
    var sesion = '';
    try { sesion = (Session.getActiveUser().getEmail() || '').toLowerCase(); } catch (err) {}
    var quien = sesion || u || 'desconocido';
    var ahora = new Date();
    hojaClicks_().appendRow([
      ahora,
      Utilities.formatDate(ahora, Session.getScriptTimeZone(), 'yyyy-MM-dd'),
      quien, sesion, u,
    ]);
  } catch (err) { /* nunca frenar la redirección por un error de log */ }
  // Meta refresh (funciona sin JS y es inmediato) + script de respaldo con
  // location.replace en un try/catch (window.top puede tirar SecurityError si
  // el navegador abre esto dentro de un frame cross-origin, lo que dejaba a
  // los usuarios trabados en esta pantalla) + botón visible como último resort.
  var url = URL_DATAHUB;
  return HtmlService.createHtmlOutput(
    '<!DOCTYPE html><html><head><meta charset="utf-8">'
    + '<meta http-equiv="refresh" content="0; url=' + url + '">'
    + '<meta name="viewport" content="width=device-width,initial-scale=1">'
    + '<style>body{font-family:Arial,Helvetica,sans-serif;background:#F4F5F7;color:#1F2024;'
    + 'display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0;}'
    + '.box{text-align:center;} .btn{display:inline-block;margin-top:16px;background:#FA0050;color:#fff;'
    + 'text-decoration:none;font-weight:800;padding:12px 28px;border-radius:999px;}</style></head>'
    + '<body><div class="box"><div>Entrando al Data Hub…</div>'
    + '<a class="btn" href="' + url + '">Entrar al Data Hub →</a></div></body>'
    + '<script>'
    + 'try { location.replace(' + JSON.stringify(url) + '); }'
    + 'catch (e) { try { location.href = ' + JSON.stringify(url) + '; } catch (e2) {} }'
    + '</script>'
    + '</html>'
  ).setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);
}

function obtenerAnaliticas() {
  var props = PropertiesService.getScriptProperties();
  var sh = hojaClicks_();
  var rows = sh.getDataRange().getValues().slice(1);
  var tz = Session.getScriptTimeZone();
  var porDia = {}, unicos = {};
  rows.forEach(function (r) {
    var fecha = (r[1] instanceof Date) ? Utilities.formatDate(r[1], tz, 'yyyy-MM-dd') : String(r[1]);
    var quien = String(r[2] || 'desconocido');
    if (!porDia[fecha]) porDia[fecha] = { total: 0, quienes: {} };
    porDia[fecha].total++;
    porDia[fecha].quienes[quien] = true;
    unicos[quien] = true;
  });
  var dias = Object.keys(porDia).sort().map(function (f) {
    return {
      fecha: f,
      total: porDia[f].total,
      unicos: Object.keys(porDia[f].quienes).length,
      quienes: Object.keys(porDia[f].quienes),
    };
  });
  var ultimos = rows.slice(-50).reverse().map(function (r) {
    return {
      ts: (r[0] instanceof Date) ? Utilities.formatDate(r[0], tz, 'dd/MM HH:mm') : String(r[0]),
      quien: String(r[2] || ''),
    };
  });
  return {
    totalClicks: rows.length,
    totalUnicos: Object.keys(unicos).length,
    dias: dias,
    ultimos: ultimos,
    sheetUrl: SpreadsheetApp.openById(props.getProperty(PROP_SHEET)).getUrl(),
  };
}

// ===================== ENVÍO =====================
function urlWebApp_() {
  try { return ScriptApp.getService().getUrl() || ''; } catch (err) { return ''; }
}
function urlClick_(base, email) {
  if (!base) return URL_DATAHUB;
  return base + '?p=click&u=' + encodeURIComponent(String(email || '').toLowerCase());
}

function enviarEmail(data) {
  guardarDatos(data);
  var base = urlWebApp_();
  var dests = String(data.destinatarios || '').split(/[,;\n\s]+/).filter(Boolean);
  if (!dests.length) throw new Error('No hay destinatarios cargados.');
  dests.forEach(function (dest) {
    MailApp.sendEmail({
      to: dest,
      subject: data.asunto || 'Ranking de uso — Data Hub',
      htmlBody: construirHtml_(data, urlClick_(base, dest)),
      name: 'Data Hub — Pedidos Ya Market',
      body: 'Abrí este email en un cliente con HTML para ver el ranking.',
    });
  });
  return 'Enviado a ' + dests.length + ' destinatario(s) ✔';
}

function enviarPrueba(data) {
  guardarDatos(data);
  var yo = Session.getEffectiveUser().getEmail();
  MailApp.sendEmail({
    to: yo,
    subject: '[PRUEBA] ' + (data.asunto || 'Ranking de uso — Data Hub'),
    htmlBody: construirHtml_(data, urlClick_(urlWebApp_(), yo)),
    name: 'Data Hub — Pedidos Ya Market',
    body: 'Abrí este email en un cliente con HTML.',
  });
  return 'Prueba enviada a ' + yo + ' ✔';
}

function vistaPrevia(data) {
  return construirHtml_(data, URL_DATAHUB);
}

// ===================== EMAIL (HTML) =====================
const PEYA = {
  red: '#FA0050', ink: '#1F2024', sub: '#6B6F76', muted: '#9A9DA5',
  line: '#EAEBEE', bg: '#F4F5F7',
};
const MEDAL = [
  { med: '🥇', c: '#D7A53A', bg: '#FBF1D8', tx: '#8A6A12' },
  { med: '🥈', c: '#AEB4BF', bg: '#EDEFF2', tx: '#565C66' },
  { med: '🥉', c: '#C0875A', bg: '#F4E7DA', tx: '#7A5230' },
];

function esc_(s) {
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}
function sinDominio_(email) { return String(email).split('@')[0]; }
function iniciales_(email) {
  var p = String(email).split('@')[0].split(/[.\-_]/);
  return (((p[0] || '').charAt(0)) + ((p[1] || '').charAt(0))).toUpperCase() || '?';
}
function badge_(i) {
  var m = MEDAL[i];
  var st = m
    ? 'background:' + m.bg + ';border:1px solid ' + m.c + ';color:' + m.tx + ';'
    : 'background:#F3F4F6;border:1px solid #D7DAE0;color:#6B6F76;';
  return '<div style="width:24px;height:24px;border-radius:50%;' + st
    + 'font-size:12px;font-weight:800;line-height:23px;text-align:center;">' + (i + 1) + '</div>';
}

function construirHtml_(d, urlClick) {
  var t = d.totales || {};

  function logo_() {
    var src = d.logoUrl || LOGO_URL;
    return '<img src="' + src + '" alt="PedidosYa" height="32" style="display:block;border:0;">';
  }

  function header_() {
    var grad = 'linear-gradient(120deg,#FA0050,#FF4D8D,#C8003F,#FF2E77,#FA0050)';
    var hasGif = !!d.headerGifUrl;
    var cls = hasGif ? '' : ' class="peya-grad"';
    var bgImg = hasGif ? "url('" + d.headerGifUrl + "')" : grad;
    var bgAttr = hasGif ? ' background="' + d.headerGifUrl + '"' : '';
    return '<tr><td' + cls + ' bgcolor="' + PEYA.red + '"' + bgAttr + ' style="background-color:' + PEYA.red + ';'
      + 'background-image:' + bgImg + ';background-size:' + (hasGif ? 'cover' : '300% 300%') + ';background-position:center;padding:24px 26px;">'
      + '<table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr>'
      +   '<td><a href="' + urlClick + '" style="text-decoration:none;">' + logo_() + '</a></td>'
      +   '<td align="right" style="font-family:Arial,Helvetica,sans-serif;font-size:12px;font-weight:700;color:#ffffff;letter-spacing:1px;">DATA HUB</td>'
      + '</tr></table></td></tr>';
  }

  function nota_() {
    return '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border-collapse:separate;">'
      + '<tr><td style="background:#FBFBFC;border:1px solid ' + PEYA.line + ';border-left:4px solid ' + PEYA.red + ';'
      + 'border-radius:12px;padding:16px 18px;font-family:Arial,Helvetica,sans-serif;">'
      + '<div style="font-size:15px;font-weight:800;color:' + PEYA.ink + ';margin-bottom:6px;">' + esc_(d.saludo || '') + '</div>'
      + '<div style="font-size:14px;line-height:1.6;color:' + PEYA.sub + ';">' + esc_(d.mensaje || '') + '</div>'
      + (d.firma ? '<div style="font-size:13px;color:' + PEYA.muted + ';margin-top:10px;">' + esc_(d.firma) + '</div>' : '')
      + '</td></tr></table>';
  }

  function cta_() {
    return '<table role="presentation" align="center" cellpadding="0" cellspacing="0" style="margin:20px auto 4px;">'
      + '<tr><td bgcolor="' + PEYA.red + '" style="border-radius:999px;">'
      + '<a href="' + urlClick + '" style="display:inline-block;padding:13px 36px;font-family:Arial,Helvetica,sans-serif;'
      + 'font-size:15px;font-weight:800;color:#ffffff;text-decoration:none;border-radius:999px;">Entrar al Data Hub →</a>'
      + '</td></tr></table>';
  }

  function tituloSeccion_(emoji, txt) {
    return '<div style="font-family:Arial,Helvetica,sans-serif;font-size:12.5px;font-weight:800;text-transform:uppercase;'
      + 'letter-spacing:0.6px;color:' + PEYA.ink + ';margin:26px 0 15px;">' + emoji + '&nbsp;&nbsp;' + esc_(txt) + '</div>';
  }

  function podio_() {
    var u = (d.usuarios || []).slice(0, 3);
    if (u.length < 3) {
      // con menos de 3 usuarios, lista simple
      return tituloSeccion_('👥', 'Usuarios más activos')
        + u.map(function (it, i) {
            return '<table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 0 10px;"><tr>'
              + '<td width="32">' + badge_(i) + '</td>'
              + '<td style="font-family:Arial,Helvetica,sans-serif;font-size:13.5px;color:' + PEYA.ink + ';">'
              + esc_(sinDominio_(it.nombre)) + ' · <strong>' + esc_(it.valor) + '</strong></td></tr></table>';
          }).join('');
    }
    function celda(it, rank, av) {
      var m = MEDAL[rank - 1];
      var pasos = { 1: 100, 2: 72, 3: 54 };
      return '<td width="33%" valign="bottom" align="center" style="padding:0 6px;font-family:Arial,Helvetica,sans-serif;">'
        + (rank === 1 ? '<div style="font-size:18px;line-height:1;margin-bottom:4px;">👑</div>' : '')
        + '<div style="width:' + av + 'px;height:' + av + 'px;border-radius:50%;background:' + m.bg + ';border:2px solid ' + m.c + ';'
        + 'color:' + m.tx + ';font-size:15px;font-weight:800;line-height:' + (av - 4) + 'px;text-align:center;margin:0 auto 9px;">' + esc_(iniciales_(it.nombre)) + '</div>'
        + '<div style="font-size:13px;font-weight:700;color:' + PEYA.ink + ';margin-bottom:3px;word-break:break-word;">' + esc_(sinDominio_(it.nombre)) + '</div>'
        + '<div style="font-size:13px;font-weight:800;color:' + PEYA.ink + ';margin-bottom:9px;">' + m.med + ' ' + esc_(it.valor) + '</div>'
        + '<div style="background:' + m.c + ';height:' + pasos[rank] + 'px;border-radius:12px 12px 0 0;'
        + 'color:#ffffff;font-size:19px;font-weight:800;line-height:' + (pasos[rank] - 4) + 'px;">' + rank + '</div></td>';
    }
    return tituloSeccion_('👥', 'Usuarios más activos')
      + '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse;"><tr>'
      + celda(u[1], 2, 46) + celda(u[0], 1, 54) + celda(u[2], 3, 46)
      + '</tr></table>';
  }

  function metricas_() {
    var items = d.metricas || [];
    if (!items.length) return '';
    var resto = items.slice(1, 3).map(function (nombre, i) {
      return '<tr><td width="34" style="padding:12px 0 0;">' + badge_(i + 1) + '</td>'
        + '<td style="padding:14px 0 0;font-family:Arial,Helvetica,sans-serif;font-size:13.5px;color:' + PEYA.ink + ';">' + esc_(nombre) + '</td></tr>';
    }).join('');
    return tituloSeccion_('📈', 'Métricas más vistas (glosario)')
      + '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border-collapse:separate;">'
      + '<tr><td style="background:#FFFDF5;border:1px solid #EFD9A0;border-radius:14px;padding:16px 18px;">'
      + '<table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr>'
      + '<td width="46" valign="middle" style="font-size:30px;line-height:1;">🥇</td>'
      + '<td valign="middle" style="font-family:Arial,Helvetica,sans-serif;">'
      + '<div style="font-size:10.5px;font-weight:800;text-transform:uppercase;letter-spacing:0.8px;color:#8A6A12;margin-bottom:4px;">La más consultada</div>'
      + '<div style="font-size:18px;font-weight:800;color:' + PEYA.ink + ';">' + esc_(items[0]) + '</div>'
      + '</td></tr></table></td></tr></table>'
      + '<table role="presentation" width="100%" cellpadding="0" cellspacing="0">' + resto + '</table>';
  }

  function reportes_() {
    var items = d.reportes || [];
    if (!items.length) return '';
    var iconos = ['📊', '📖', '📂'];
    var n = Math.min(items.length, 3);
    var w = Math.floor(100 / n);
    var cells = items.slice(0, n).map(function (nombre, i) {
      var m = MEDAL[i];
      var pad = (i === 0 ? '0 7px 0 0' : (i === n - 1 ? '0 0 0 7px' : '0 7px'));
      return '<td width="' + w + '%" valign="top" style="padding:' + pad + ';">'
        + '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border-collapse:separate;'
        + 'border:1px solid ' + PEYA.line + ';border-top:3px solid ' + m.c + ';border-radius:14px;">'
        + '<tr><td style="padding:16px 16px 15px;font-family:Arial,Helvetica,sans-serif;">'
        + '<div style="font-size:26px;line-height:1;margin-bottom:10px;">' + iconos[i % iconos.length] + '</div>'
        + '<div style="font-size:14px;font-weight:800;color:' + PEYA.ink + ';line-height:1.4;">' + esc_(nombre) + '</div>'
        + '<div style="font-size:12px;color:' + PEYA.muted + ';margin-top:7px;">' + m.med + ' ' + (i === 0 ? 'El más abierto' : 'Puesto ' + (i + 1)) + '</div>'
        + '</td></tr></table></td>';
    }).join('');
    return tituloSeccion_('📂', 'Reportes más abiertos')
      + '<table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr>' + cells + '</tr></table>';
  }

  function plataformas_() {
    var items = d.plataformas || [];
    if (!items.length) return '';
    var widths = [100, 80, 62];
    var filas = items.slice(0, 3).map(function (it, i) {
      var m = MEDAL[i];
      var borde = (i === 0 ? PEYA.red : PEYA.line);
      return '<table role="presentation" width="' + widths[i] + '%" cellpadding="0" cellspacing="0" '
        + 'style="border-collapse:separate;border:1.5px solid ' + borde + ';border-radius:999px;margin:0 0 10px;background:#ffffff;"><tr>'
        + '<td style="padding:9px 6px 9px 16px;font-family:Arial,Helvetica,sans-serif;font-size:13.5px;color:' + PEYA.ink + ';">'
        + '📱&nbsp;&nbsp;' + esc_(it.nombre) + '</td>'
        + '<td align="right" style="padding:0 16px 0 6px;font-family:Arial,Helvetica,sans-serif;font-size:13.5px;font-weight:800;color:' + PEYA.ink + ';white-space:nowrap;">'
        + esc_(it.usuarios) + '<span style="font-weight:400;color:' + PEYA.muted + ';font-size:12px;"> usuarios</span></td>'
        + '</tr></table>';
    }).join('');
    return tituloSeccion_('📱', 'Plataformas más utilizadas') + filas;
  }

  // Secciones extra definidas desde el panel
  function extras_() {
    return (d.extras || []).map(function (sec) {
      var filas = (sec.items || []).slice(0, 5).map(function (nombre, i) {
        return '<tr><td width="34" style="padding:' + (i ? '12px' : '0') + ' 0 0;">' + badge_(i) + '</td>'
          + '<td style="padding:' + (i ? '14px' : '2px') + ' 0 0;font-family:Arial,Helvetica,sans-serif;font-size:13.5px;color:' + PEYA.ink + ';">' + esc_(nombre) + '</td></tr>';
      }).join('');
      if (!filas) return '';
      return tituloSeccion_(sec.emoji || '✨', sec.titulo || 'Otros datos')
        + '<table role="presentation" width="100%" cellpadding="0" cellspacing="0">' + filas + '</table>';
    }).join('');
  }

  function statGrid_() {
    function cell(num, lab, br, bb) {
      return '<td width="50%" align="center" style="padding:18px 10px;font-family:Arial,Helvetica,sans-serif;'
        + (br ? 'border-right:1px solid ' + PEYA.line + ';' : '')
        + (bb ? 'border-bottom:1px solid ' + PEYA.line + ';' : '') + '">'
        + '<div style="font-size:28px;font-weight:800;color:' + PEYA.red + ';line-height:1;">' + num + '</div>'
        + '<div style="font-size:12px;color:' + PEYA.sub + ';margin-top:6px;">' + lab + '</div></td>';
    }
    var m = (t.metricas === '' || t.metricas === null || t.metricas === undefined) ? '—' : t.metricas;
    return '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border:1px solid ' + PEYA.line + ';border-radius:14px;border-collapse:separate;overflow:hidden;">'
      + '<tr>' + cell(t.usuarios || 0, 'usuarios este mes', true, true) + cell(t.sesiones || 0, 'sesiones totales', false, true) + '</tr>'
      + '<tr>' + cell(t.links || 0, 'links en el Data Hub', true, false) + cell(m, 'métricas en el glosario', false, false) + '</tr>'
      + '</table>';
  }

  return ''
    + '<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
    + '<style>'
    + '@keyframes peyaShift{0%{background-position:0% 50%}50%{background-position:100% 50%}100%{background-position:0% 50%}}'
    + '.peya-grad{background-size:300% 300% !important;animation:peyaShift 7s ease infinite;}'
    + '@media (prefers-reduced-motion:reduce){.peya-grad{animation:none;}}'
    + '</style></head>'
    + '<body style="margin:0;padding:0;background:' + PEYA.bg + ';">'
    + '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:' + PEYA.bg + ';padding:24px 0;"><tr><td align="center">'
    + '<table role="presentation" width="600" cellpadding="0" cellspacing="0" style="width:600px;max-width:600px;background:#ffffff;border-radius:18px;overflow:hidden;box-shadow:0 1px 4px rgba(0,0,0,0.07);">'
    + header_()
    + '<tr><td style="padding:24px 26px 4px;font-family:Arial,Helvetica,sans-serif;">'
    +   '<div style="font-size:23px;font-weight:800;color:' + PEYA.ink + ';">🏆 Ranking de uso</div>'
    +   '<div style="font-size:14px;color:' + PEYA.muted + ';margin-top:5px;">Resumen mensual · ' + esc_(d.periodo || '') + ' · Pedidos Ya Market</div>'
    + '</td></tr>'
    + '<tr><td style="padding:14px 26px 0;">' + nota_() + cta_() + '</td></tr>'
    + '<tr><td style="padding:4px 26px 0;">' + podio_() + metricas_() + reportes_() + plataformas_() + extras_() + '</td></tr>'
    + '<tr><td style="padding:26px 26px 6px;">' + statGrid_() + '</td></tr>'
    + '<tr><td style="padding:18px 26px 26px;font-family:Arial,Helvetica,sans-serif;font-size:12px;color:' + PEYA.muted + ';line-height:1.6;border-top:1px solid ' + PEYA.line + ';">'
    +   '<a href="' + urlClick + '" style="color:' + PEYA.red + ';font-weight:700;text-decoration:none;">pedidosya.thedatahub.com.ar</a><br>'
    +   'Plataforma creada por <strong style="color:' + PEYA.ink + ';">Matias Cagliero</strong> — Strategy &amp; Performance, Pedidos Ya Market.'
    + '</td></tr>'
    + '</table></td></tr></table></body></html>';
}
