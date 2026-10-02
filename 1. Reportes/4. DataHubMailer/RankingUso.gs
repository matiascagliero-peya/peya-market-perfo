/**
 * Data Hub — Pedidos Ya Market
 * Ranking de uso mensual (Top 3) enviado por email (HTML, estilo gráfico).
 *
 * Cómo usar:
 *   1) Escribí tu nota del mes en CONFIG.mensaje (aparece arriba de todo).
 *   2) Ajustá CONFIG.destinatarios.
 *   3) Actualizá DATA con los números del mes.
 *   4) Ejecutá enviarRankingUso() y autorizá el permiso de Gmail la 1ra vez.
 *
 * Notas:
 *   - CONFIG.excluir saca emails del ranking (ej: vos como admin/creador).
 *   - Logo: si tenés el PNG hosteado (Drive público o CDN) pegá la URL en
 *     CONFIG.logoUrl. Si lo dejás vacío usa el wordmark "PedidosYa" en CSS.
 */

const CONFIG = {
  destinatarios: 'equipo@pedidosya.com',            // separados por coma
  asunto: 'Ranking de uso — Data Hub · junio 2026',
  periodo: 'junio 2026',
  remitente: 'Data Hub — Pedidos Ya Market',
  logoUrl: '',                                       // opcional (URL del PNG)

  // GIF de degradado animado de fondo del header. Subí peya-gradient.gif a un
  // lugar público (Drive con link, el server del Data Hub, un CDN) y pegá la
  // URL acá. Vacío = degradado CSS (animado en Apple Mail, fijo en Gmail).
  headerGifUrl: '',

  // Mensaje editable que aparece arriba (la "nota" del mes)
  saludo: 'Hola equipo 👋',
  mensaje: 'Cerramos junio con más equipos usando el Data Hub en su día a día. '
         + 'Gracias por sumarse y seguir explorando los reportes y el glosario. '
         + '¿Falta alguna métrica o reporte? Escribime y lo agregamos.',
  firma: '— Matías',

  // Emails que NO entran al ranking (admins, creadores, bots, etc.)
  excluir: ['matias.cagliero@pedidosya.com'],
};

const DATA = {
  totales: { usuarios: 16, sesiones: 472 },

  // Usuarios más activos (por eventos) — se ordena y filtra por código
  usuarios: [
    { nombre: 'matias.cagliero@pedidosya.com', valor: 544 },
    { nombre: 'felipe.salaverria@pedidosya.com', valor: 59 },
    { nombre: 'tobias.fay@pedidosya.com', valor: 23 },
    { nombre: 'seba.aquije@pedidosya.com', valor: 13 },
    { nombre: 'francisco.trujillo@pedidosya.com', valor: 9 },
    { nombre: 'sophia.reynoso@pedidosya.com', valor: 7 },
  ],

  // Métricas más vistas (glosario) — Net Sales como #1
  metricas: [
    { nombre: 'Net Sales o Retail Sales', valor: 3 },
    { nombre: '% CPO / AFV', valor: 3 },
    { nombre: 'CVR3 (Conversion Rate 3)', valor: 3 },
  ],

  // Reportes más abiertos
  reportes: [
    { nombre: 'Análisis de ajustes', valor: 1 },
    { nombre: '1. Diccionario de Métricas - PeYa Market', valor: 1 },
  ],

  // ¿Qué busca la gente? (búsquedas)
  busquedas: [
    { nombre: 'Daily Report OKRs 26 - Peya Market', valor: 3 },
    { nombre: 'okr', valor: 2 },
    { nombre: 'FTE', valor: 1 },
  ],

  // Uso por plataforma (%)
  plataformas: [
    { nombre: 'datahub', pct: 66 },
    { nombre: 'navlink', pct: 18 },
    { nombre: 'glosario', pct: 16 },
  ],
};

// ===== Envío =====
function enviarRankingUso() {
  const html = construirHtml_(DATA, CONFIG);
  MailApp.sendEmail({
    to: CONFIG.destinatarios,
    subject: CONFIG.asunto,
    htmlBody: html,
    name: CONFIG.remitente,
    body: 'Tu cliente no muestra HTML. Abrí el email en Gmail para ver el ranking.',
  });
}

// ===== Paleta =====
const PEYA = {
  red: '#FA0050',
  redSoft: '#FFE4ED',
  ink: '#1F2024',
  sub: '#6B6F76',
  muted: '#9A9DA5',
  line: '#EAEBEE',
  track: '#EEEFF2',
  bg: '#F4F5F7',
};

// Lenguaje de ranking oro / plata / bronce
const MEDAL = [
  { med: '🥇', c: '#D7A53A', bg: '#FBF1D8', tx: '#8A6A12' },
  { med: '🥈', c: '#AEB4BF', bg: '#EDEFF2', tx: '#565C66' },
  { med: '🥉', c: '#C0875A', bg: '#F4E7DA', tx: '#7A5230' },
];

// ===== Helpers =====
function esc_(s) {
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}
function sinDominio_(email) { return String(email).split('@')[0]; }
function iniciales_(email) {
  var p = String(email).split('@')[0].split(/[.\-_]/);
  var a = (p[0] || '').charAt(0), b = (p[1] || '').charAt(0);
  return ((a + b).toUpperCase()) || (a || '?').toUpperCase();
}
function topUsuarios_(lista, excluir) {
  var ex = (excluir || []).map(function (e) { return String(e).toLowerCase(); });
  return lista
    .filter(function (it) { return ex.indexOf(String(it.nombre).toLowerCase()) === -1; })
    .sort(function (a, b) { return b.valor - a.valor; })
    .slice(0, 3);
}

// ===== Builder =====
function construirHtml_(d, cfg) {
  var top = topUsuarios_(d.usuarios, cfg.excluir);

  function logo_() {
    if (cfg.logoUrl) {
      return '<img src="' + cfg.logoUrl + '" alt="PedidosYa" height="30" style="display:block;border:0;">';
    }
    return ''
      + '<span style="display:inline-block;width:30px;height:30px;border-radius:8px;background:#ffffff;'
      +   'color:' + PEYA.red + ';font-family:Arial,Helvetica,sans-serif;font-size:18px;font-weight:800;line-height:30px;'
      +   'text-align:center;vertical-align:middle;margin-right:9px;">Y</span>'
      + '<span style="font-family:Arial,Helvetica,sans-serif;font-size:23px;font-weight:800;color:#ffffff;'
      +   'letter-spacing:-0.5px;vertical-align:middle;">PedidosYa</span>';
  }

  // ---- Header con GIF de fondo (o degradado CSS si no hay GIF) ----
  function header_() {
    var grad = 'linear-gradient(120deg,#FA0050,#FF4D8D,#C8003F,#FF2E77,#FA0050)';
    var hasGif = !!cfg.headerGifUrl;
    var cls    = hasGif ? '' : ' class="peya-grad"';
    var bgImg  = hasGif ? "url('" + cfg.headerGifUrl + "')" : grad;
    var bgSize = hasGif ? 'cover' : '300% 300%';
    var bgAttr = hasGif ? ' background="' + cfg.headerGifUrl + '"' : '';
    var vmlA = hasGif
      ? '<!--[if gte mso 9]><v:rect xmlns:v="urn:schemas-microsoft-com:vml" fill="true" stroke="false" style="width:600px;height:84px;">'
        + '<v:fill type="frame" src="' + cfg.headerGifUrl + '" color="' + PEYA.red + '"/><v:textbox inset="0,0,0,0"><![endif]-->'
      : '';
    var vmlB = hasGif ? '<!--[if gte mso 9]></v:textbox></v:rect><![endif]-->' : '';
    return ''
      + '<tr><td' + cls + ' bgcolor="' + PEYA.red + '"' + bgAttr + ' style="background-color:' + PEYA.red + ';'
      +   'background-image:' + bgImg + ';background-size:' + bgSize + ';background-position:center;padding:24px 26px;">'
      +   vmlA
      +   '<table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr>'
      +     '<td>' + logo_() + '</td>'
      +     '<td align="right" style="font-family:Arial,Helvetica,sans-serif;font-size:12px;font-weight:700;color:#ffffff;letter-spacing:1px;opacity:0.92;">DATA HUB</td>'
      +   '</tr></table>'
      +   vmlB
      + '</td></tr>';
  }

  function tituloSeccion_(emoji, txt) {
    return '<div style="font-family:Arial,Helvetica,sans-serif;font-size:12.5px;font-weight:800;text-transform:uppercase;'
      + 'letter-spacing:0.6px;color:' + PEYA.ink + ';margin:26px 0 15px;">' + emoji + '&nbsp;&nbsp;' + esc_(txt) + '</div>';
  }

  // ---- Nota / mensaje editable ----
  function nota_() {
    return ''
      + '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border-collapse:separate;">'
      +   '<tr><td style="background:#FBFBFC;border:1px solid ' + PEYA.line + ';border-left:4px solid ' + PEYA.red + ';'
      +     'border-radius:12px;padding:16px 18px;font-family:Arial,Helvetica,sans-serif;">'
      +     '<div style="font-size:15px;font-weight:800;color:' + PEYA.ink + ';margin-bottom:6px;">' + esc_(cfg.saludo) + '</div>'
      +     '<div style="font-size:14px;line-height:1.6;color:' + PEYA.sub + ';">' + esc_(cfg.mensaje) + '</div>'
      +     (cfg.firma ? '<div style="font-size:13px;color:' + PEYA.muted + ';margin-top:10px;">' + esc_(cfg.firma) + '</div>' : '')
      +   '</td></tr>'
      + '</table>';
  }

  // ---- Podio ----
  function podioCelda_(it, rank, alturaAvatar) {
    var m = MEDAL[rank - 1];
    var pasos = { 1: 100, 2: 72, 3: 54 };
    var av = alturaAvatar;
    return ''
      + '<td width="33%" valign="bottom" align="center" style="padding:0 6px;font-family:Arial,Helvetica,sans-serif;">'
      +   (rank === 1 ? '<div style="font-size:18px;line-height:1;margin-bottom:4px;">👑</div>' : '')
      +   '<div style="width:' + av + 'px;height:' + av + 'px;border-radius:50%;background:' + m.bg + ';border:2px solid ' + m.c + ';'
      +     'color:' + m.tx + ';font-size:15px;font-weight:800;line-height:' + (av - 4) + 'px;text-align:center;margin:0 auto 9px;">' + esc_(iniciales_(it.nombre)) + '</div>'
      +   '<div style="font-size:13px;font-weight:700;color:' + PEYA.ink + ';margin-bottom:3px;word-break:break-word;">' + esc_(sinDominio_(it.nombre)) + '</div>'
      +   '<div style="font-size:13px;font-weight:800;color:' + PEYA.ink + ';margin-bottom:9px;">' + m.med + ' ' + esc_(it.valor) + '</div>'
      +   '<div style="background:' + m.c + ';height:' + pasos[rank] + 'px;border-radius:12px 12px 0 0;'
      +     'color:#ffffff;font-size:19px;font-weight:800;line-height:' + (pasos[rank] - 4) + 'px;">' + rank + '</div>'
      + '</td>';
  }
  function podio_() {
    return tituloSeccion_('👥', 'Usuarios más activos')
      + '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse;"><tr>'
      +   podioCelda_(top[1], 2, 46)
      +   podioCelda_(top[0], 1, 54)
      +   podioCelda_(top[2], 3, 46)
      + '</tr></table>';
  }

  // ---- Métricas (glosario): #1 como tarjeta destacada + 2° y 3° en lista ----
  function metricas_(items) {
    var top = items[0];
    var resto = items.slice(1, 3).map(function (it, i) {
      var m = MEDAL[i + 1];
      return ''
        + '<tr>'
        +   '<td width="34" style="padding:12px 0 0;">'
        +     '<div style="width:24px;height:24px;border-radius:50%;background:' + m.bg + ';border:1px solid ' + m.c + ';'
        +       'color:' + m.tx + ';font-size:12px;font-weight:800;line-height:23px;text-align:center;">' + (i + 2) + '</div></td>'
        +   '<td style="padding:14px 0 0;font-family:Arial,Helvetica,sans-serif;font-size:13.5px;color:' + PEYA.ink + ';">' + esc_(it.nombre) + '</td>'
        + '</tr>';
    }).join('');
    return tituloSeccion_('📈', 'Métricas más vistas (glosario)')
      + '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border-collapse:separate;">'
      +   '<tr><td style="background:#FFFDF5;border:1px solid #EFD9A0;border-radius:14px;padding:16px 18px;">'
      +     '<table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr>'
      +       '<td width="46" valign="middle" style="font-size:30px;line-height:1;">🥇</td>'
      +       '<td valign="middle" style="font-family:Arial,Helvetica,sans-serif;">'
      +         '<div style="font-size:10.5px;font-weight:800;text-transform:uppercase;letter-spacing:0.8px;color:#8A6A12;margin-bottom:4px;">La más consultada</div>'
      +         '<div style="font-size:18px;font-weight:800;color:' + PEYA.ink + ';">' + esc_(top.nombre) + '</div>'
      +       '</td>'
      +     '</tr></table>'
      +   '</td></tr>'
      + '</table>'
      + '<table role="presentation" width="100%" cellpadding="0" cellspacing="0">' + resto + '</table>';
  }

  // ---- Reportes: tarjetas lado a lado con acento de medalla ----
  function reportes_(items) {
    var iconos = ['📊', '📖', '📂'];
    var n = Math.min(items.length, 3);
    var w = Math.floor(100 / n);
    var cells = items.slice(0, n).map(function (it, i) {
      var m = MEDAL[i];
      var pad = (i === 0 ? '0 7px 0 0' : (i === n - 1 ? '0 0 0 7px' : '0 7px'));
      return ''
        + '<td width="' + w + '%" valign="top" style="padding:' + pad + ';">'
        +   '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border-collapse:separate;'
        +     'border:1px solid ' + PEYA.line + ';border-top:3px solid ' + m.c + ';border-radius:14px;">'
        +     '<tr><td style="padding:16px 16px 15px;font-family:Arial,Helvetica,sans-serif;">'
        +       '<div style="font-size:26px;line-height:1;margin-bottom:10px;">' + iconos[i % iconos.length] + '</div>'
        +       '<div style="font-size:14px;font-weight:800;color:' + PEYA.ink + ';line-height:1.4;">' + esc_(it.nombre) + '</div>'
        +       '<div style="font-size:12px;color:' + PEYA.muted + ';margin-top:7px;">' + m.med + ' ' + (i === 0 ? 'El más abierto' : 'Puesto ' + (i + 1)) + '</div>'
        +     '</td></tr>'
        +   '</table>'
        + '</td>';
    }).join('');
    return tituloSeccion_('📂', 'Reportes más abiertos')
      + '<table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr>' + cells + '</tr></table>';
  }

  // ---- Búsquedas: pills tipo buscador (el ancho marca el puesto) ----
  function busquedas_(items) {
    var widths = [100, 80, 62];
    var filas = items.slice(0, 3).map(function (it, i) {
      var m = MEDAL[i];
      var borde = (i === 0 ? PEYA.red : PEYA.line);
      return ''
        + '<table role="presentation" width="' + widths[i] + '%" cellpadding="0" cellspacing="0" '
        +   'style="border-collapse:separate;border:1.5px solid ' + borde + ';border-radius:999px;margin:0 0 10px;background:#ffffff;">'
        +   '<tr>'
        +     '<td style="padding:9px 6px 9px 16px;font-family:Arial,Helvetica,sans-serif;font-size:13.5px;color:' + PEYA.ink + ';">'
        +       '🔎&nbsp;&nbsp;&ldquo;' + esc_(it.nombre) + '&rdquo;</td>'
        +     '<td align="right" style="padding:0 12px 0 6px;font-size:15px;white-space:nowrap;">' + m.med + '</td>'
        +   '</tr>'
        + '</table>';
    }).join('');
    return tituloSeccion_('🔎', '¿Qué busca la gente?') + filas;
  }

  // ---- Plataformas (minimalista: una línea de texto) ----
  function plataformas_(items) {
    var sep = '<span style="color:' + PEYA.muted + ';">&nbsp;&nbsp;·&nbsp;&nbsp;</span>';
    var linea = items.map(function (it) {
      return '<span style="color:' + PEYA.sub + ';">' + esc_(it.nombre) + '</span> '
        + '<strong style="color:' + PEYA.ink + ';">' + it.pct + '%</strong>';
    }).join(sep);
    return tituloSeccion_('📱', 'Uso por plataforma')
      + '<div style="font-family:Arial,Helvetica,sans-serif;font-size:14px;">' + linea + '</div>';
  }

  // ---- Hero numbers ----
  function heroNums_(t) {
    function cell(num, lab, borde) {
      return '<td width="50%" align="center" style="padding:18px 10px;font-family:Arial,Helvetica,sans-serif;'
        + (borde ? 'border-right:1px solid ' + PEYA.line + ';' : '') + '">'
        + '<div style="font-size:30px;font-weight:800;color:' + PEYA.red + ';line-height:1;">' + num + '</div>'
        + '<div style="font-size:12px;color:' + PEYA.sub + ';margin-top:6px;">' + lab + '</div></td>';
    }
    return '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border:1px solid ' + PEYA.line + ';border-radius:14px;"><tr>'
      + cell(t.usuarios, 'usuarios este mes', true)
      + cell(t.sesiones, 'sesiones totales', false)
      + '</tr></table>';
  }

  return ''
  + '<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
  +   '<style>'
  +     '@keyframes peyaShift{0%{background-position:0% 50%}50%{background-position:100% 50%}100%{background-position:0% 50%}}'
  +     '.peya-grad{background-size:300% 300% !important;animation:peyaShift 7s ease infinite;}'
  +     '@media (prefers-reduced-motion:reduce){.peya-grad{animation:none;}}'
  +   '</style></head>'
  + '<body style="margin:0;padding:0;background:' + PEYA.bg + ';">'
  + '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:' + PEYA.bg + ';padding:24px 0;">'
  + '<tr><td align="center">'
  +   '<table role="presentation" width="600" cellpadding="0" cellspacing="0" style="width:600px;max-width:600px;background:#ffffff;border-radius:18px;overflow:hidden;box-shadow:0 1px 4px rgba(0,0,0,0.07);">'

  //  Header (GIF de degradado de fondo + logo encima; fallbacks incluidos)
  +     header_()

  //  Título
  +     '<tr><td style="padding:24px 26px 4px;font-family:Arial,Helvetica,sans-serif;">'
  +       '<div style="font-size:23px;font-weight:800;color:' + PEYA.ink + ';">🏆 Ranking de uso</div>'
  +       '<div style="font-size:14px;color:' + PEYA.muted + ';margin-top:5px;">Resumen mensual · ' + esc_(cfg.periodo) + ' · Pedidos Ya Market</div>'
  +     '</td></tr>'

  //  Nota / mensaje
  +     '<tr><td style="padding:14px 26px 2px;">' + nota_() + '</td></tr>'

  //  Podio
  +     '<tr><td style="padding:10px 26px 4px;">' + podio_() + '</td></tr>'

  //  Barras + plataformas
  +     '<tr><td style="padding:6px 26px 0;">'
  +       metricas_(d.metricas)
  +       reportes_(d.reportes)
  +       busquedas_(d.busquedas)
  +       plataformas_(d.plataformas)
  +     '</td></tr>'

  //  Hero numbers
  +     '<tr><td style="padding:24px 26px 6px;">' + heroNums_(d.totales) + '</td></tr>'

  //  Footer
  +     '<tr><td style="padding:18px 26px 26px;font-family:Arial,Helvetica,sans-serif;font-size:12px;color:' + PEYA.muted + ';line-height:1.5;border-top:1px solid ' + PEYA.line + ';margin-top:8px;">'
  +       'Plataforma creada por <strong style="color:' + PEYA.ink + ';">Matias Cagliero</strong> — Strategy &amp; Performance, Pedidos Ya Market.'
  +     '</td></tr>'

  +   '</table>'
  + '</td></tr></table></body></html>';
}
