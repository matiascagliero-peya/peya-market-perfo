/**
 * @OnlyCurrentDoc
 * Auditoría de Accesos V10
 *
 * Cambios respecto a V9:
 *   1) La hoja de control ahora es "Lista revisión" con columnas:
 *      A: Nombre de destino | B: id | C: Owner | D: Owner Mail
 *      E: Último chequeo    | F: Resumen estado
 *      El script completa E y F (y C/D si están vacías). Lo MÁS importante:
 *      avisa primero si el archivo NO tiene acceso restringido.
 *   2) En cada archivo auditado, la hoja "Control de accesos" se deja siempre
 *      como ÚLTIMA pestaña (con el detalle de todas las personas con acceso).
 *   3) El email dejó de ser uno por owner con la lista completa. Ahora es UN
 *      solo email de resumen: estado de cada archivo + total de personas
 *      únicas con acceso. Se envía a EMAIL_RESUMEN (o a quien ejecuta).
 */

// =====================================================================
// BLOQUE 1: MENÚ PERSONALIZADO (Se ejecuta al abrir la hoja)
// =====================================================================

function onOpen() {
  const ui = SpreadsheetApp.getUi();
  ui.createMenu('🛡️ Auditoría de Accesos')
    .addItem('🔍 Validar (sin enviar mails)', 'auditoriaSoloValidar')
    .addItem('▶️ Ejecutar y enviar mails', 'auditoriaEstilizadaYCompleta')
    .addToUi();
}

// =====================================================================
// BLOQUE 2: CONFIGURACIÓN GENERAL
// =====================================================================

const ID_HOJA_NOMINA = '1yEjJPUCrW7mnGGybeRwSPMGtaDKSCljikP2n-XxeyOM';
const NOMBRE_HOJA_NOMINA = 'Nomina total';

const NOMBRE_HOJA_LISTA = 'Lista revisión';       // hoja de control (antes "Activos")
const NOMBRE_HOJA_INFORME = 'Control de accesos';  // hoja que se crea/actualiza en cada archivo

// Destinatario del email de resumen. Si lo dejás vacío, se envía a quien
// ejecuta la auditoría (Session.getActiveUser).
const EMAIL_RESUMEN = '';

// MODO DE PRUEBA. En true, los mails a owners y a cada persona NO salen a los
// destinatarios reales: te llegan todos a vos (EMAIL_RESUMEN / quien ejecuta),
// con el destinatario real en el asunto. Poné false cuando quieras enviarlos de verdad.
const MODO_PRUEBA = true;

// Estilo
const COLOR_HEADER_FONDO = '#990000';
const COLOR_HEADER_TEXTO = '#FFFFFF';
const COLOR_OK_FONDO = '#e6f4ea';
const COLOR_OK_TEXTO = '#0f9d58';
const COLOR_ALERTA_FONDO = '#fce8e6';
const COLOR_ALERTA_TEXTO = '#d93025';

const FIRMA_AUDITORIA = "Matias Cagliero | Strategy and Performance | Pedidos Ya Market.";

// Columnas de "Lista revisión" (1 = A)
const COL_NOMBRE = 1;
const COL_ID = 2;
const COL_OWNER = 3;
const COL_OWNER_MAIL = 4;
const COL_CHEQUEO = 5;
const COL_ESTADO = 6;

// =====================================================================
// BLOQUE 3: FUNCIÓN PRINCIPAL
// =====================================================================

// Botón "Ejecutar y enviar mails": corre la auditoría y ADEMÁS envía los correos.
function auditoriaEstilizadaYCompleta() { ejecutarAuditoria(true); }

// Botón "Validar (sin enviar mails)": hace TODO menos enviar correos.
function auditoriaSoloValidar() { ejecutarAuditoria(false); }

function ejecutarAuditoria(enviarMails) {
  console.log(`--- INICIO DE AUDITORÍA (envío de mails: ${enviarMails ? 'SÍ' : 'NO'}) ---`);

  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const hojaLista = ss.getSheetByName(NOMBRE_HOJA_LISTA);

  if (!hojaLista) {
    const msg = `No se encontró la hoja '${NOMBRE_HOJA_LISTA}'.`;
    console.error(msg);
    SpreadsheetApp.getUi().alert('❌ ' + msg);
    return;
  }

  const datosLista = hojaLista.getDataRange().getValues();
  const datosNomina = obtenerDatosDeNomina(ID_HOJA_NOMINA);
  const ahora = new Date();
  const fechaHoy = Utilities.formatDate(ahora, "GMT-3", "dd/MM/yyyy");
  const fechaHora = Utilities.formatDate(ahora, "GMT-3", "dd/MM/yyyy HH:mm");

  const resumen = [];             // una entrada por archivo (para el email)
  const emailsUnicos = {};        // set de personas con acceso (para el total)
  const accesosPorPersona = {};   // email -> { nombre, tipo, accesos:[{archivo,rol}] }

  console.log(`Filas de datos a revisar (sin encabezado): ${datosLista.length - 1}`);

  // Recorremos desde la fila 2 (la 1 es encabezado)
  for (let i = 1; i < datosLista.length; i++) {
    const fila = datosLista[i];
    const numFila = i + 1;
    const id = extraerId(fila[COL_ID - 1]);   // acepta id pelado o link completo
    const nombreEnLista = String(fila[COL_NOMBRE - 1] || '').trim();

    if (id.length <= 10) continue; // fila vacía o id inválido

    try {
      const archivo = DriveApp.getFileById(id);
      const nombreArchivo = nombreEnLista || archivo.getName();
      console.log(`[${i}] Procesando: ${nombreArchivo}`);

      const resultado = auditarArchivo(id, datosNomina, fechaHoy);

      // Acumular accesos por persona (para el total y el mail por persona)
      resultado.personas.forEach(p => {
        if (!p.email) return;
        emailsUnicos[p.email] = true;
        if (!accesosPorPersona[p.email]) {
          accesosPorPersona[p.email] = { nombre: p.nombre, tipo: p.tipo, accesos: [] };
        }
        accesosPorPersona[p.email].accesos.push({ archivo: nombreArchivo, rol: p.rol });
      });

      // --- Actualizar fila en "Lista revisión" ---
      // Nombre / owner / mail: solo si están vacíos (respetamos lo que cargaste a mano)
      if (!nombreEnLista) hojaLista.getRange(numFila, COL_NOMBRE).setValue(archivo.getName());
      if (!String(fila[COL_OWNER - 1] || '').trim() && resultado.nombreOwner) {
        hojaLista.getRange(numFila, COL_OWNER).setValue(resultado.nombreOwner);
      }
      if (!String(fila[COL_OWNER_MAIL - 1] || '').trim() && resultado.emailOwner) {
        hojaLista.getRange(numFila, COL_OWNER_MAIL).setValue(resultado.emailOwner);
      }

      // Últimas dos columnas: siempre se actualizan
      hojaLista.getRange(numFila, COL_CHEQUEO).setValue(fechaHora);
      hojaLista.getRange(numFila, COL_ESTADO)
        .setValue(resultado.resumenEstado)
        .setBackground(resultado.esSeguro ? COLOR_OK_FONDO : COLOR_ALERTA_FONDO)
        .setFontColor(resultado.esSeguro ? COLOR_OK_TEXTO : COLOR_ALERTA_TEXTO)
        .setFontWeight('bold');

      resumen.push({
        nombre: nombreArchivo,
        owner: resultado.nombreOwner || resultado.emailOwner || '—',
        tipoAcceso: resultado.tipoAcceso,
        esSeguro: resultado.esSeguro,
        nPersonas: resultado.personas.length,
        resumenEstado: resultado.resumenEstado
      });

      // Aviso corto al owner de este archivo (estado + cantidad, sin la lista)
      if (enviarMails) enviarMailOwner(resultado, nombreArchivo, fechaHoy);

    } catch (e) {
      console.error(`Error en ID ${id}: ${e.message}`);
      hojaLista.getRange(numFila, COL_CHEQUEO).setValue(fechaHora);
      hojaLista.getRange(numFila, COL_ESTADO)
        .setValue('❌ Sin acceso / error: ' + e.message)
        .setBackground(COLOR_ALERTA_FONDO).setFontColor(COLOR_ALERTA_TEXTO).setFontWeight('bold');

      resumen.push({
        nombre: nombreEnLista || id,
        owner: '—',
        tipoAcceso: 'Error',
        esSeguro: false,
        nPersonas: 0,
        resumenEstado: 'Sin acceso / error'
      });
    }
  }

  if (enviarMails) {
    // Un solo email de resumen consolidado (para vos)
    enviarResumen(resumen, Object.keys(emailsUnicos).length, fechaHoy);

    // Un mail por persona: a cada usuario, la lista de archivos a los que accede
    Object.keys(accesosPorPersona).forEach(email => {
      const info = accesosPorPersona[email];
      if (info.tipo === 'group') return; // no mandamos a grupos/listas
      enviarMailPersona(email, info.nombre, info.accesos, fechaHoy);
    });
  }

  const conError = resumen.filter(r => r.tipoAcceso === 'Error').length;
  console.log(`✅ --- AUDITORÍA FINALIZADA --- Archivos: ${resumen.length} · Con error: ${conError}`);
  SpreadsheetApp.getUi().alert(
    (enviarMails ? '✅ Auditoría completada (con envío de mails).' : '🔍 Validación completada (SIN enviar mails).') + '\n' +
    'Archivos en la lista: ' + resumen.length + '\n' +
    'Con error / sin acceso: ' + conError
  );
}

// =====================================================================
// BLOQUE 4: AUDITORÍA DE UN ARCHIVO (escribe "Control de accesos")
// =====================================================================

function auditarArchivo(id, datosNomina, fechaHoy) {
  const ssDestino = SpreadsheetApp.openById(id);
  const hoja = ssDestino.getSheetByName(NOMBRE_HOJA_INFORME) ||
               ssDestino.insertSheet(NOMBRE_HOJA_INFORME);

  // Rescatar verificaciones manuales previas (columna G)
  const verificacionesPrevias = {};
  if (hoja.getLastRow() > 0) {
    hoja.getDataRange().getValues().forEach(f => {
      if (String(f[0]).includes('@')) verificacionesPrevias[String(f[0]).toLowerCase()] = f[6] || '';
    });
  }

  const permisos = Drive.Permissions.list(id, { supportsAllDrives: true });
  const items = (permisos && permisos.items) ? permisos.items : [];

  // Tipo de acceso: lo más importante es detectar si NO es restringido
  let tipoAcceso = 'Restringido';
  let esSeguro = true;
  if (items.some(p => p.type === 'anyone')) {
    tipoAcceso = 'Público';
    esSeguro = false;
  } else if (items.some(p => p.type === 'domain')) {
    tipoAcceso = 'Organización';
    esSeguro = false;
  }

  // Personas con acceso directo (user / group)
  const personas = [];
  let emailOwner = '', nombreOwner = '';

  items.filter(p => p.type === 'user' || p.type === 'group').forEach(p => {
    const email = (p.emailAddress || '').toLowerCase();
    const info = datosNomina[email];
    const nombre = info ? info.nombre : (p.displayName || reconstruirNombreDesdeEmail(email));

    personas.push({
      email: email,
      nombre: nombre,
      puesto: info ? info.puesto : 'N/A',
      pais: info ? info.pais : 'N/A',
      departamento: info ? info.departamento : 'N/A',
      tipo: p.type,
      rol: p.role,
      verificacion: verificacionesPrevias[email] || ''
    });

    if (p.role === 'owner') { emailOwner = email; nombreOwner = nombre; }
  });

  personas.sort(ordenarPorJerarquiaYPais);

  escribirHojaControl(ssDestino, hoja, tipoAcceso, esSeguro, personas, fechaHoy);

  return {
    tipoAcceso: tipoAcceso,
    esSeguro: esSeguro,
    personas: personas,
    emailOwner: emailOwner,
    nombreOwner: nombreOwner,
    resumenEstado: construirResumenEstado(tipoAcceso, esSeguro, personas.length)
  };
}

function escribirHojaControl(ssDestino, hoja, tipoAcceso, esSeguro, personas, fechaHoy) {
  hoja.clear();

  const check = esSeguro ? '✅' : '⚠️';
  hoja.getRange('A1:C2').setValues([
    ['Visibilidad:', tipoAcceso, check],
    ['Última actualización:', Utilities.formatDate(new Date(), 'GMT-3', 'dd/MM/yyyy HH:mm:ss'), '']
  ]);
  hoja.getRange('A1:A2').setFontWeight('bold');
  hoja.getRange('B1').setFontWeight('bold').setFontColor(esSeguro ? COLOR_OK_TEXTO : COLOR_ALERTA_TEXTO);
  hoja.getRange('C1').setHorizontalAlignment('center').setFontSize(14);

  const encabezados = ['Email', 'Nombre y Apellido', 'Título de puesto', 'País', 'Departamento', 'Rol de Acceso', `Verificación del ${fechaHoy.slice(0, 5)}`];
  hoja.getRange(4, 1, 1, encabezados.length).setValues([encabezados])
    .setBackground(COLOR_HEADER_FONDO).setFontColor(COLOR_HEADER_TEXTO).setFontWeight('bold');

  if (personas.length > 0) {
    const filas = personas.map(p => [p.email, p.nombre, p.puesto, p.pais, p.departamento, p.rol, p.verificacion]);
    hoja.getRange(5, 1, filas.length, encabezados.length).setValues(filas);
  }

  hoja.setFrozenRows(4);
  hoja.autoResizeColumns(1, encabezados.length);
  hoja.showSheet();

  // Dejar "Control de accesos" como ÚLTIMA pestaña
  ssDestino.setActiveSheet(hoja);
  ssDestino.moveActiveSheet(ssDestino.getSheets().length);
}

function construirResumenEstado(tipoAcceso, esSeguro, nPersonas) {
  if (!esSeguro && tipoAcceso === 'Público') {
    return `⚠️ SIN RESTRINGIR · Público en internet · ${nPersonas} con acceso directo`;
  }
  if (!esSeguro && tipoAcceso === 'Organización') {
    return `⚠️ SIN RESTRINGIR · Toda la organización · ${nPersonas} con acceso directo`;
  }
  return `✅ Restringido · ${nPersonas} personas con acceso`;
}

// =====================================================================
// BLOQUE 5: EMAIL DE RESUMEN (uno solo, consolidado)
// =====================================================================

function enviarResumen(resumen, totalPersonasUnicas, fechaHoy) {
  const destinatario = EMAIL_RESUMEN || Session.getActiveUser().getEmail();
  if (!destinatario) {
    console.warn('No hay destinatario para el email de resumen (configurá EMAIL_RESUMEN).');
    return;
  }
  if (resumen.length === 0) return;

  const conAlerta = resumen.filter(r => !r.esSeguro).length;
  const asunto = (conAlerta > 0 ? `⚠️ ${conAlerta} con alerta · ` : '') +
                 `Resumen de Auditoría de Accesos - ${fechaHoy}`;

  let urlHoja = '';
  try { urlHoja = SpreadsheetApp.getActiveSpreadsheet().getUrl(); } catch (e) {}

  MailApp.sendEmail({
    to: destinatario,
    subject: asunto,
    htmlBody: generarHtmlResumen(resumen, totalPersonasUnicas, fechaHoy, urlHoja)
  });
}

function generarHtmlResumen(resumen, totalPersonasUnicas, fechaHoy, urlHoja) {
  const totalArchivos = resumen.length;
  const conAlerta = resumen.filter(r => !r.esSeguro).length;

  // Solo listamos los que tienen alerta (lo accionable). Los OK van resumidos
  // en una línea, así el mail no crece con la cantidad de archivos.
  const alertas = resumen.filter(r => !r.esSeguro);
  const ok = resumen.filter(r => r.esSeguro);
  const MAX_FILAS = 20;

  let filasHtml = '';
  alertas.slice(0, MAX_FILAS).forEach(r => {
    filasHtml += `<tr style="border-bottom:1px solid #eee;">
      <td style="padding:10px;"><strong>${r.nombre}</strong></td>
      <td style="padding:10px;"><span style="background:${COLOR_ALERTA_FONDO};color:${COLOR_ALERTA_TEXTO};padding:3px 8px;border-radius:10px;font-size:11px;font-weight:bold;white-space:nowrap;">⚠️ ${r.tipoAcceso}</span></td>
      <td style="padding:10px;text-align:center;">${r.nPersonas}</td>
      <td style="padding:10px;">${r.owner}</td></tr>`;
  });
  if (alertas.length > MAX_FILAS) {
    filasHtml += `<tr><td colspan="4" style="padding:10px;font-size:12px;color:#70757a;">… y ${alertas.length - MAX_FILAS} archivo(s) más con alerta. Ver la hoja «${NOMBRE_HOJA_LISTA}».</td></tr>`;
  }

  const bloqueAlerta = conAlerta > 0
    ? `<div style="background:${COLOR_ALERTA_FONDO};color:${COLOR_ALERTA_TEXTO};padding:12px 15px;border-radius:6px;margin-bottom:20px;font-weight:bold;">
         ⚠️ ${conAlerta} de ${totalArchivos} archivo(s) NO tienen acceso restringido. Los listamos abajo.
       </div>`
    : `<div style="background:${COLOR_OK_FONDO};color:${COLOR_OK_TEXTO};padding:12px 15px;border-radius:6px;margin-bottom:20px;font-weight:bold;">
         ✅ Todos los archivos auditados tienen acceso restringido.
       </div>`;

  const kpi = (valor, etiqueta, color) => `
    <td style="padding:0 8px;" width="33%">
      <div style="border:1px solid #e0e0e0;border-radius:8px;padding:14px;text-align:center;">
        <div style="font-size:26px;font-weight:bold;color:${color};line-height:1;">${valor}</div>
        <div style="font-size:11px;color:#70757a;margin-top:6px;text-transform:uppercase;letter-spacing:.5px;">${etiqueta}</div>
      </div>
    </td>`;

  return `
    <div style="font-family:Arial,sans-serif;color:#3c4043;max-width:720px;border:1px solid #e0e0e0;border-radius:8px;margin:auto;overflow:hidden;">
      <div style="background-color:${COLOR_HEADER_FONDO};padding:20px;text-align:center;">
        <h2 style="color:white;margin:0;">Resumen de Auditoría de Accesos</h2>
        <p style="color:#f1c9c9;margin:6px 0 0 0;font-size:13px;">${fechaHoy}</p>
      </div>
      <div style="padding:20px;">
        <table style="width:100%;border-collapse:collapse;margin-bottom:20px;"><tr>
          ${kpi(totalArchivos, 'Archivos revisados', '#3c4043')}
          ${kpi(conAlerta, 'Con alerta', conAlerta > 0 ? COLOR_ALERTA_TEXTO : COLOR_OK_TEXTO)}
          ${kpi(totalPersonasUnicas, 'Personas únicas con acceso', '#3c4043')}
        </tr></table>

        ${bloqueAlerta}

        ${alertas.length > 0 ? `
        <p style="font-weight:bold;margin:0 0 8px;">Archivos sin acceso restringido</p>
        <table style="width:100%;border-collapse:collapse;font-size:13px;">
          <thead style="background-color:#f1f3f4;">
            <tr>
              <th style="padding:10px;text-align:left;">Archivo</th>
              <th style="padding:10px;text-align:left;">Estado</th>
              <th style="padding:10px;text-align:center;">Personas</th>
              <th style="padding:10px;text-align:left;">Owner</th>
            </tr>
          </thead>
          <tbody>${filasHtml}</tbody>
        </table>` : ''}

        ${ok.length > 0 ? `<div style="background:${COLOR_OK_FONDO};color:${COLOR_OK_TEXTO};padding:12px 15px;border-radius:6px;margin-top:16px;font-weight:bold;">✅ ${ok.length} archivo(s) con acceso restringido.</div>` : ''}

        ${urlHoja ? `<div style="margin-top:18px;text-align:center;"><a href="${urlHoja}" style="display:inline-block;background:${COLOR_HEADER_FONDO};color:#fff;text-decoration:none;padding:10px 20px;border-radius:6px;font-size:13px;font-weight:bold;">Ver la lista completa en «${NOMBRE_HOJA_LISTA}»</a></div>` : ''}

        <p style="margin-top:18px;font-size:12px;color:#70757a;">
          El estado de todos los archivos está en la hoja <strong>“${NOMBRE_HOJA_LISTA}”</strong>, y el detalle de quién tiene acceso, en la pestaña <strong>“${NOMBRE_HOJA_INFORME}”</strong> (última hoja) de cada archivo.
        </p>

        <p style="margin-top:20px;font-size:12px;color:#70757a;border-top:1px solid #eee;padding-top:15px;">
          ${FIRMA_AUDITORIA}
        </p>
      </div>
    </div>`;
}

// --- Aviso corto para el owner de cada archivo (estado + cantidad, sin lista) ---
function enviarMailOwner(res, nombreArchivo, fechaHoy) {
  if (!res.emailOwner) return;
  enviarMail(
    res.emailOwner,
    (res.esSeguro ? '' : '⚠️ ') + `Auditoría de Accesos - ${nombreArchivo} - ${fechaHoy}`,
    generarHtmlOwner(res, nombreArchivo)
  );
}

function generarHtmlOwner(res, nombreArchivo) {
  const consejo = res.esSeguro
    ? `<span style="color:${COLOR_OK_TEXTO};"><strong>✅ Tu archivo cumple con las normas de seguridad (acceso restringido).</strong></span>`
    : `<span style="color:${COLOR_ALERTA_TEXTO};"><strong>⚠️ Este archivo NO tiene acceso restringido. Se recomienda cambiarlo a “Restringido” para proteger la información.</strong></span>`;

  const chip = res.esSeguro
    ? `<span style="background:${COLOR_OK_FONDO};color:${COLOR_OK_TEXTO};padding:4px 10px;border-radius:12px;font-size:12px;font-weight:bold;">✅ ${res.tipoAcceso}</span>`
    : `<span style="background:${COLOR_ALERTA_FONDO};color:${COLOR_ALERTA_TEXTO};padding:4px 10px;border-radius:12px;font-size:12px;font-weight:bold;">⚠️ ${res.tipoAcceso}</span>`;

  return `
    <div style="font-family:Arial,sans-serif;color:#3c4043;max-width:600px;border:1px solid #e0e0e0;border-radius:8px;margin:auto;overflow:hidden;">
      <div style="background-color:${COLOR_HEADER_FONDO};padding:20px;text-align:center;">
        <h2 style="color:white;margin:0;">Auditoría de Accesos</h2>
      </div>
      <div style="padding:20px;">
        <p>Hola <strong>${res.nombreOwner || 'equipo'}</strong>,</p>
        <p>Este es el estado de acceso de tu archivo. El objetivo es <strong>tomar conciencia sobre quién puede verlo</strong>.</p>

        <div style="background-color:#f8f9fa;padding:15px;border-radius:6px;margin:18px 0;">
          <h3 style="margin:0 0 10px 0;">📄 ${nombreArchivo}</h3>
          <p style="margin:0 0 8px 0;">Visibilidad: ${chip}</p>
          <p style="margin:0;">Personas con acceso: <strong>${res.personas.length}</strong></p>
        </div>

        <p>${consejo}</p>
        <p style="font-size:13px;color:#70757a;">El detalle de quién tiene acceso está en la pestaña <strong>“${NOMBRE_HOJA_INFORME}”</strong> (última hoja) de tu archivo.</p>

        <p style="margin-top:25px;font-size:12px;color:#70757a;border-top:1px solid #eee;padding-top:15px;">
          ${FIRMA_AUDITORIA}
        </p>
      </div>
    </div>`;
}

// --- Envío con modo de prueba: en pruebas, redirige todo a tu casilla ---
function enviarMail(to, subject, htmlBody) {
  if (MODO_PRUEBA) {
    const admin = EMAIL_RESUMEN || Session.getActiveUser().getEmail();
    if (!admin) return;
    MailApp.sendEmail({ to: admin, subject: `[PRUEBA → ${to}] ${subject}`, htmlBody: htmlBody });
  } else {
    MailApp.sendEmail({ to: to, subject: subject, htmlBody: htmlBody });
  }
}

// --- Un mail por persona: los archivos a los que tiene acceso ---
function enviarMailPersona(email, nombre, accesos, fechaHoy) {
  if (!email || !accesos || accesos.length === 0) return;
  enviarMail(
    email,
    `Tu acceso a archivos - Auditoría de Accesos - ${fechaHoy}`,
    generarHtmlPersona(nombre || reconstruirNombreDesdeEmail(email), accesos)
  );
}

function generarHtmlPersona(nombre, accesos) {
  const ordenados = accesos.slice().sort((a, b) =>
    (a.rol === 'owner' ? 0 : 1) - (b.rol === 'owner' ? 0 : 1) ||
    String(a.archivo).localeCompare(String(b.archivo)));

  let filasHtml = '';
  ordenados.forEach(a => {
    const esOwner = a.rol === 'owner';
    const colorFondo = esOwner ? '#fce8e6' : '#e8f0fe';
    const colorTexto = esOwner ? '#d93025' : '#1967d2';
    filasHtml += `<tr style="border-bottom:1px solid #eee;">
      <td style="padding:10px;"><strong>${a.archivo}</strong></td>
      <td style="padding:10px;"><span style="background:${colorFondo};color:${colorTexto};padding:3px 8px;border-radius:10px;font-size:11px;font-weight:bold;">${String(a.rol).toUpperCase()}</span></td></tr>`;
  });

  return `
    <div style="font-family:Arial,sans-serif;color:#3c4043;max-width:640px;border:1px solid #e0e0e0;border-radius:8px;margin:auto;overflow:hidden;">
      <div style="background-color:${COLOR_HEADER_FONDO};padding:20px;text-align:center;">
        <h2 style="color:white;margin:0;">Auditoría de Accesos</h2>
      </div>
      <div style="padding:20px;">
        <p>Hola <strong>${nombre}</strong>,</p>
        <p>Según la última auditoría, tenés acceso a <strong>${accesos.length}</strong> archivo(s). El objetivo es que puedas <strong>revisar tus propios accesos</strong>.</p>
        <table style="width:100%;border-collapse:collapse;font-size:13px;margin-top:10px;">
          <thead style="background-color:#f1f3f4;"><tr>
            <th style="padding:10px;text-align:left;">Archivo</th>
            <th style="padding:10px;text-align:left;">Tu rol</th>
          </tr></thead>
          <tbody>${filasHtml}</tbody>
        </table>
        <p style="margin-top:16px;font-size:13px;color:#70757a;">Si hay algún archivo al que <strong>no deberías</strong> tener acceso, respondé este correo o avisá al owner del archivo.</p>
        <p style="margin-top:20px;font-size:12px;color:#70757a;border-top:1px solid #eee;padding-top:15px;">${FIRMA_AUDITORIA}</p>
      </div>
    </div>`;
}

// =====================================================================
// BLOQUE 6: FUNCIONES AUXILIARES
// =====================================================================

function extraerId(valor) {
  const s = String(valor || '').trim();
  const m = s.match(/[-\w]{25,}/);  // el id de Drive es una cadena larga; funciona con id pelado o con link
  return m ? m[0] : s;
}

function reconstruirNombreDesdeEmail(email) {
  if (!email || !email.includes('.')) return email;
  const parteNombre = email.split('@')[0];
  return parteNombre.split('.')
    .map(palabra => palabra.charAt(0).toUpperCase() + palabra.slice(1))
    .join(' ');
}

function obtenerDatosDeNomina(spreadsheetId) {
  try {
    const hoja = SpreadsheetApp.openById(spreadsheetId).getSheetByName(NOMBRE_HOJA_NOMINA);
    const valores = hoja.getRange("A2:E" + hoja.getLastRow()).getValues();
    const mapa = {};
    valores.forEach(f => {
      if (f[0]) mapa[String(f[0]).toLowerCase()] = { nombre: f[1], puesto: f[2], pais: f[3], departamento: f[4] };
    });
    return mapa;
  } catch (e) {
    console.warn('No se pudo leer la nómina: ' + e.message);
    return {};
  }
}

function ordenarPorJerarquiaYPais(a, b) {
  const ownerA = a.rol === 'owner' ? 0 : 1;
  const ownerB = b.rol === 'owner' ? 0 : 1;
  if (ownerA !== ownerB) return ownerA - ownerB;
  if (a.pais !== b.pais) return String(a.pais).localeCompare(String(b.pais));
  const jer = (p) => {
    p = String(p).toLowerCase();
    return p.includes('director') ? 1 : p.includes('manager') ? 2 : 3;
  };
  return jer(a.puesto) - jer(b.puesto) || String(a.nombre).localeCompare(String(b.nombre));
}
