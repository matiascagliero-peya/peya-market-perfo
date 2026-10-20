/**
 * @OnlyCurrentDoc
 * Auditoría de Accesos
 */

function onOpen() {
  try {
    SpreadsheetApp.getUi()
      .createMenu('🛡️ Auditoría de Accesos')
      .addItem('🔍 Validar (sin enviar mails)', 'auditoriaSoloValidar')
      .addItem('▶️ Ejecutar y enviar mails', 'auditoriaEstilizadaYCompleta')
      .addSeparator()
      .addItem('🎨 Aplicar diseño a Lista revisión', 'aplicarEstiloListaRevisionManual')
      .addItem('ℹ️ Verificar cuota y permisos', 'verificarEstadoYCuotas')
      .addToUi();
  } catch (e) {
    console.error("Error en onOpen: " + e.message);
  }
}

const CONFIG_AUDITORIA = {
  ID_HOJA_NOMINA      : '1yEjJPUCrW7mnGGybeRwSPMGtaDKSCljikP2n-XxeyOM',
  NOMBRE_HOJA_NOMINA  : 'Nomina total',
  NOMBRE_HOJA_LISTA   : 'Lista revisión',
  NOMBRE_HOJA_INFORME : 'Control de accesos',

  EMAIL_RESUMEN       : '', // Vacío: se envía a quien ejecuta
  MODO_PRUEBA         : true, // true: redirige todos los correos al admin

  ENVIAR_RESUMEN_ADMIN: true,
  ENVIAR_AVISO_OWNERS : false,
  ENVIAR_AVISO_PERSONAS: false,
  MAX_MAILS_POR_CORRIDA: 40,

  COLOR_HEADER_FONDO  : '#800020',
  COLOR_HEADER_TEXTO  : '#FFFFFF',
  COLOR_CELDA_FONDO   : '#EFEFEF',
  COLOR_BORDE_BLANCO  : '#FFFFFF',

  COLOR_TEXTO_DATOS   : '#2B2B2B',
  COLOR_TEXTO_MUTED   : '#555555',
  COLOR_TEXTO_FECHA   : '#666666',

  COLOR_OK_FONDO      : '#E7F3E9',
  COLOR_OK_TEXTO      : '#24663B',
  COLOR_ALERTA_FONDO  : '#FCECEC',
  COLOR_ALERTA_TEXTO  : '#8E2424',

  ALTURA_HEADER       : 42,
  ALTURA_FILA_DATOS   : 36,
  ALTURA_RESUMEN      : 32,
  ANCHO_MIN_COLUMNA   : 175,

  FIRMA_AUDITORIA     : "Matias Cagliero | Strategy and Performance | Pedidos Ya Market."
};

const COL_DEFAULT = {
  NOMBRE     : 0,
  ID         : 1,
  OWNER      : 2,
  OWNER_MAIL : 3,
  CHEQUEO    : 4,
  ESTADO     : 5
};

function auditoriaEstilizadaYCompleta() {
  ejecutarAuditoria(true);
}

function auditoriaSoloValidar() {
  ejecutarAuditoria(false);
}

function ejecutarAuditoria(enviarMails) {
  if (!validarServicioDrive()) return;

  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const hojaLista = ss.getSheetByName(CONFIG_AUDITORIA.NOMBRE_HOJA_LISTA);

  if (!hojaLista) {
    const msg = `No se encontró la hoja '${CONFIG_AUDITORIA.NOMBRE_HOJA_LISTA}'.`;
    console.error(msg);
    SpreadsheetApp.getUi().alert('❌ ' + msg);
    return;
  }

  estilizarHojaListaRevision(hojaLista);

  const colMap = obtenerMapeoColumnasLista(hojaLista);
  const datosLista = hojaLista.getDataRange().getValues();
  if (datosLista.length < 2) {
    SpreadsheetApp.getUi().alert(`⚠️ La hoja '${CONFIG_AUDITORIA.NOMBRE_HOJA_LISTA}' no contiene filas para auditar.`);
    return;
  }

  const datosNomina = obtenerDatosDeNomina(CONFIG_AUDITORIA.ID_HOJA_NOMINA);
  const ahora = new Date();
  const fechaHoy = Utilities.formatDate(ahora, "GMT-3", "dd/MM/yyyy");
  const fechaChequeo = Utilities.formatDate(ahora, "GMT-3", "dd/MM · HH:mm");

  const resumen = [];
  const emailsUnicos = {};
  const accesosPorPersona = {};
  const totalFilas = datosLista.length - 1;

  for (let i = 1; i < datosLista.length; i++) {
    const fila = datosLista[i];
    const numFila = i + 1;
    const rawId = (colMap.ID >= 0) ? fila[colMap.ID] : fila[1];
    const id = extraerId(rawId);
    const nombreEnLista = (colMap.NOMBRE >= 0) ? String(fila[colMap.NOMBRE] || '').trim() : '';

    if (!id || id.length <= 10) continue;

    try {
      ss.toast(`Auditando ${i}/${totalFilas}: ${nombreEnLista || id}`, "Auditoría en curso", 3);

      let nombreArchivo = nombreEnLista;
      let driveFile = null;
      try {
        driveFile = DriveApp.getFileById(id);
        if (!nombreArchivo) nombreArchivo = driveFile.getName();
      } catch (errDrive) {
        console.warn(`No se pudo obtener objeto DriveApp para ${id}: ${errDrive.message}`);
      }

      const resultado = auditarArchivo(id, datosNomina, fechaHoy, driveFile);

      resultado.personas.forEach(p => {
        if (!p.email) return;
        emailsUnicos[p.email] = true;
        if (!accesosPorPersona[p.email]) {
          accesosPorPersona[p.email] = { nombre: p.nombre, tipo: p.tipo, accesos: [] };
        }
        accesosPorPersona[p.email].accesos.push({ archivo: nombreArchivo || id, rol: p.rol });
      });

      actualizarFilaListaRevision(hojaLista, numFila, colMap, fila, {
        nombre: nombreArchivo,
        owner: resultado.nombreOwner,
        ownerMail: resultado.emailOwner,
        fechaHora: fechaChequeo,
        estado: resultado.resumenEstado,
        esSeguro: resultado.esSeguro
      });

      resumen.push({
        nombre: nombreArchivo || id,
        owner: resultado.nombreOwner || resultado.emailOwner || '—',
        emailOwner: resultado.emailOwner,
        tipoAcceso: resultado.tipoAcceso,
        esSeguro: resultado.esSeguro,
        nPersonas: resultado.personas.length,
        resumenEstado: resultado.resumenEstado,
        hojaInternaEscrita: resultado.hojaInternaEscrita
      });

      if (enviarMails && CONFIG_AUDITORIA.ENVIAR_AVISO_OWNERS) {
        enviarMailOwner(resultado, nombreArchivo, fechaHoy);
      }

    } catch (e) {
      console.error(`Error procesando ID ${id}: ${e.message}`);
      const estadoError = 'Error: ' + acortarMensaje(e.message, 30);

      actualizarFilaListaRevision(hojaLista, numFila, colMap, fila, {
        fechaHora: fechaChequeo,
        estado: estadoError,
        esSeguro: false
      });

      resumen.push({
        nombre: nombreEnLista || id,
        owner: '—',
        emailOwner: '',
        tipoAcceso: 'Error',
        esSeguro: false,
        nPersonas: 0,
        resumenEstado: estadoError,
        hojaInternaEscrita: false
      });
    }
  }

  if (enviarMails) {
    if (CONFIG_AUDITORIA.ENVIAR_RESUMEN_ADMIN) {
      enviarResumen(resumen, Object.keys(emailsUnicos).length, fechaHoy);
    }

    if (CONFIG_AUDITORIA.ENVIAR_AVISO_PERSONAS) {
      let enviadosPersonas = 0;
      for (const email of Object.keys(accesosPorPersona)) {
        if (enviadosPersonas >= CONFIG_AUDITORIA.MAX_MAILS_POR_CORRIDA) break;
        const info = accesosPorPersona[email];
        if (info.tipo === 'group') continue;
        if (enviarMailPersona(email, info.nombre, info.accesos, fechaHoy)) enviadosPersonas++;
      }
    }
  }

  const conAlerta = resumen.filter(r => !r.esSeguro).length;
  SpreadsheetApp.getUi().alert(
    (enviarMails ? '✅ Auditoría completada (con correos procesados).' : '🔍 Validación completada (SIN enviar correos).') + '\n\n' +
    '• Archivos revisados: ' + resumen.length + '\n' +
    '• Con alertas o error: ' + conAlerta + '\n' +
    '• Personas únicas detectadas: ' + Object.keys(emailsUnicos).length
  );
}

function auditarArchivo(id, datosNomina, fechaHoy, driveFile) {
  const items = obtenerPermisosDrive(id);

  let tipoAcceso = 'Restringido';
  let esSeguro = true;
  if (items.some(p => p.type === 'anyone')) {
    tipoAcceso = 'Público';
    esSeguro = false;
  } else if (items.some(p => p.type === 'domain')) {
    tipoAcceso = 'Organización';
    esSeguro = false;
  }

  const personas = [];
  let emailOwner = '', nombreOwner = '';

  items.filter(p => p.type === 'user' || p.type === 'group').forEach(p => {
    const email = (p.emailAddress || '').toLowerCase();
    const info = datosNomina[email];
    const nombre = info ? info.nombre : (p.displayName || reconstruirNombreDesdeEmail(email));

    personas.push({
      email: email,
      nombre: nombre,
      puesto: info ? info.puesto : '—',
      pais: info ? info.pais : '—',
      departamento: info ? info.departamento : '—',
      tipo: p.type,
      rol: p.role,
      verificacion: ''
    });

    if (p.role === 'owner') {
      emailOwner = email;
      nombreOwner = nombre;
    }
  });

  // Fallback para Shared Drives donde no existe el rol 'owner'
  if (!emailOwner && driveFile) {
    try {
      const driveOwner = driveFile.getOwner();
      if (driveOwner) {
        emailOwner = driveOwner.getEmail().toLowerCase();
        nombreOwner = driveOwner.getName() || reconstruirNombreDesdeEmail(emailOwner);
      }
    } catch (eShared) {
      const organizer = personas.find(p => p.rol === 'organizer');
      if (organizer) {
        emailOwner = organizer.email;
        nombreOwner = organizer.nombre;
      }
    }
  }

  personas.sort(ordenarPorJerarquiaYPais);

  let hojaInternaEscrita = false;
  let mensajeEscritura = '';

  try {
    const ssDestino = SpreadsheetApp.openById(id);
    const hoja = ssDestino.getSheetByName(CONFIG_AUDITORIA.NOMBRE_HOJA_INFORME) ||
                 ssDestino.insertSheet(CONFIG_AUDITORIA.NOMBRE_HOJA_INFORME);

    const verificacionesPrevias = {};
    if (hoja.getLastRow() > 0) {
      hoja.getDataRange().getValues().forEach(f => {
        if (f && String(f[0]).includes('@')) {
          verificacionesPrevias[String(f[0]).toLowerCase()] = f[6] || '';
        }
      });
    }

    personas.forEach(p => {
      if (verificacionesPrevias[p.email]) {
        p.verificacion = verificacionesPrevias[p.email];
      }
    });

    escribirHojaControl(ssDestino, hoja, tipoAcceso, esSeguro, personas, fechaHoy);
    hojaInternaEscrita = true;
  } catch (errPerm) {
    console.warn(`[Permiso de edición] No se pudo escribir pestaña de control en ${id}: ${errPerm.message}`);
    mensajeEscritura = ' · (Solo lectura)';
  }

  return {
    tipoAcceso: tipoAcceso,
    esSeguro: esSeguro,
    personas: personas,
    emailOwner: emailOwner,
    nombreOwner: nombreOwner,
    hojaInternaEscrita: hojaInternaEscrita,
    resumenEstado: construirResumenEstado(tipoAcceso, esSeguro, personas.length) + mensajeEscritura
  };
}

function escribirHojaControl(ssDestino, hoja, tipoAcceso, esSeguro, personas, fechaHoy) {
  hoja.clear();

  const encabezados = [
    'Email',
    'Nombre y Apellido',
    'Título de puesto',
    'País',
    'Departamento',
    'Rol de Acceso',
    `Verificación del ${fechaHoy.slice(0, 5)}`
  ];
  const totalCols = encabezados.length;

  const datosSuperiores = [
    ['Visibilidad', tipoAcceso, esSeguro ? 'Seguro' : 'Alerta'],
    ['Última actualización', Utilities.formatDate(new Date(), 'GMT-3', 'dd/MM/yyyy · HH:mm'), '']
  ];
  const rangoSuperior = hoja.getRange(1, 1, 2, 3);
  rangoSuperior.setValues(datosSuperiores)
    .setBackground(CONFIG_AUDITORIA.COLOR_CELDA_FONDO)
    .setFontColor(CONFIG_AUDITORIA.COLOR_TEXTO_DATOS)
    .setFontSize(9.5)
    .setFontWeight('normal')
    .setVerticalAlignment('middle')
    .setHorizontalAlignment('center')
    .setBorder(true, true, true, true, true, true, CONFIG_AUDITORIA.COLOR_BORDE_BLANCO, SpreadsheetApp.BorderStyle.SOLID);

  hoja.getRange('A1:A2').setFontColor(CONFIG_AUDITORIA.COLOR_TEXTO_MUTED);
  hoja.getRange('B1').setFontColor(esSeguro ? CONFIG_AUDITORIA.COLOR_OK_TEXTO : CONFIG_AUDITORIA.COLOR_ALERTA_TEXTO);
  hoja.getRange('C1')
    .setBackground(esSeguro ? CONFIG_AUDITORIA.COLOR_OK_FONDO : CONFIG_AUDITORIA.COLOR_ALERTA_FONDO)
    .setFontColor(esSeguro ? CONFIG_AUDITORIA.COLOR_OK_TEXTO : CONFIG_AUDITORIA.COLOR_ALERTA_TEXTO)
    .setFontSize(9);

  hoja.setRowHeights(1, 2, CONFIG_AUDITORIA.ALTURA_RESUMEN);
  hoja.setRowHeight(3, 12);

  const rangoHeader = hoja.getRange(4, 1, 1, totalCols);
  rangoHeader.setValues([encabezados])
    .setBackground(CONFIG_AUDITORIA.COLOR_HEADER_FONDO)
    .setFontColor(CONFIG_AUDITORIA.COLOR_HEADER_TEXTO)
    .setFontWeight('bold')
    .setFontSize(10.5)
    .setVerticalAlignment('middle')
    .setHorizontalAlignment('center')
    .setBorder(true, true, true, true, true, true, CONFIG_AUDITORIA.COLOR_BORDE_BLANCO, SpreadsheetApp.BorderStyle.SOLID);

  hoja.setRowHeight(4, CONFIG_AUDITORIA.ALTURA_HEADER);

  if (personas.length > 0) {
    const filas = personas.map(p => [
      p.email,
      p.nombre,
      p.puesto,
      p.pais,
      p.departamento,
      p.rol,
      p.verificacion
    ]);

    const rangoDatos = hoja.getRange(5, 1, filas.length, totalCols);
    rangoDatos.setValues(filas)
      .setBackground(CONFIG_AUDITORIA.COLOR_CELDA_FONDO)
      .setFontColor(CONFIG_AUDITORIA.COLOR_TEXTO_DATOS)
      .setFontWeight('normal')
      .setFontSize(9.5)
      .setVerticalAlignment('middle')
      .setHorizontalAlignment('center')
      .setBorder(true, true, true, true, true, true, CONFIG_AUDITORIA.COLOR_BORDE_BLANCO, SpreadsheetApp.BorderStyle.SOLID);

    hoja.getRange(5, 1, filas.length, 1)
      .setFontSize(9)
      .setFontColor(CONFIG_AUDITORIA.COLOR_TEXTO_MUTED);

    hoja.getRange(5, 2, filas.length, 1)
      .setFontSize(10)
      .setFontColor(CONFIG_AUDITORIA.COLOR_TEXTO_DATOS);

    hoja.setRowHeights(5, filas.length, CONFIG_AUDITORIA.ALTURA_FILA_DATOS);
  }

  hoja.setFrozenRows(4);

  try {
    hoja.autoResizeColumns(1, totalCols);
    for (let c = 1; c <= totalCols; c++) {
      const anchoActual = hoja.getColumnWidth(c);
      hoja.setColumnWidth(c, Math.max(anchoActual + 40, CONFIG_AUDITORIA.ANCHO_MIN_COLUMNA));
    }
  } catch (eResize) {}

  hoja.showSheet();

  try {
    ssDestino.setActiveSheet(hoja);
    ssDestino.moveActiveSheet(ssDestino.getSheets().length);
  } catch (eMove) {}
}

function construirResumenEstado(tipoAcceso, esSeguro, nPersonas) {
  if (!esSeguro && tipoAcceso === 'Público') {
    return `Público · ${nPersonas}`;
  }
  if (!esSeguro && tipoAcceso === 'Organización') {
    return `Organización · ${nPersonas}`;
  }
  return `Restringido · ${nPersonas}`;
}

function enviarResumen(resumen, totalPersonasUnicas, fechaHoy) {
  const destinatario = CONFIG_AUDITORIA.EMAIL_RESUMEN || Session.getActiveUser().getEmail();
  if (!destinatario || resumen.length === 0) return;

  const conAlerta = resumen.filter(r => !r.esSeguro).length;
  const asunto = (conAlerta > 0 ? `⚠️ ${conAlerta} con alerta · ` : 'Auditoría · ') +
                 `Resumen de Accesos (${fechaHoy})`;

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
  const alertas = resumen.filter(r => !r.esSeguro);
  const ok = resumen.filter(r => r.esSeguro);
  const MAX_FILAS = 25;

  let filasHtml = '';
  alertas.slice(0, MAX_FILAS).forEach(r => {
    filasHtml += `<tr style="border-bottom:1px solid #ffffff; background-color:${CONFIG_AUDITORIA.COLOR_CELDA_FONDO}; text-align:center;">
      <td style="padding:12px; font-weight:normal; color:#222; font-size:13px;">${r.nombre}</td>
      <td style="padding:12px;"><span style="background:${CONFIG_AUDITORIA.COLOR_ALERTA_FONDO};color:${CONFIG_AUDITORIA.COLOR_ALERTA_TEXTO};padding:4px 10px;border-radius:10px;font-size:11px;font-weight:normal;white-space:nowrap;">${r.tipoAcceso}</span></td>
      <td style="padding:12px;color:#333;font-size:13px;">${r.nPersonas}</td>
      <td style="padding:12px;color:#666;font-size:12px;">${r.owner}</td></tr>`;
  });
  if (alertas.length > MAX_FILAS) {
    filasHtml += `<tr><td colspan="4" style="padding:12px;font-size:12px;color:#70757a;text-align:center;background:${CONFIG_AUDITORIA.COLOR_CELDA_FONDO};">… y ${alertas.length - MAX_FILAS} archivo(s) más. Ver la hoja «${CONFIG_AUDITORIA.NOMBRE_HOJA_LISTA}».</td></tr>`;
  }

  const bloqueAlerta = conAlerta > 0
    ? `<div style="background:${CONFIG_AUDITORIA.COLOR_ALERTA_FONDO};color:${CONFIG_AUDITORIA.COLOR_ALERTA_TEXTO};padding:14px 18px;border-radius:6px;margin-bottom:20px;font-size:13px;text-align:center;">
         ${conAlerta} de ${totalArchivos} archivo(s) requieren atención por visibilidad amplia o error.
       </div>`
    : `<div style="background:${CONFIG_AUDITORIA.COLOR_OK_FONDO};color:${CONFIG_AUDITORIA.COLOR_OK_TEXTO};padding:14px 18px;border-radius:6px;margin-bottom:20px;font-size:13px;text-align:center;">
         Todos los archivos auditados tienen acceso restringido correctamente.
       </div>`;

  const kpi = (valor, etiqueta, color) => `
    <td style="padding:0 8px;" width="33%">
      <div style="background:${CONFIG_AUDITORIA.COLOR_CELDA_FONDO};border:1px solid #ffffff;border-radius:8px;padding:16px;text-align:center;">
        <div style="font-size:24px;font-weight:normal;color:${color};line-height:1;">${valor}</div>
        <div style="font-size:11px;color:#777;margin-top:6px;text-transform:uppercase;letter-spacing:.5px;">${etiqueta}</div>
      </div>
    </td>`;

  return `
    <div style="font-family:Arial,sans-serif;color:#333;max-width:740px;border:1px solid #e0e0e0;border-radius:8px;margin:auto;overflow:hidden;background:#fff;">
      <div style="background-color:${CONFIG_AUDITORIA.COLOR_HEADER_FONDO};padding:22px;text-align:center;">
        <h2 style="color:white;margin:0;font-weight:normal;font-size:20px;letter-spacing:.5px;">Auditoría de Accesos</h2>
        <p style="color:#f1c9c9;margin:6px 0 0 0;font-size:12px;">${fechaHoy}</p>
      </div>
      <div style="padding:22px;">
        <table style="width:100%;border-collapse:collapse;margin-bottom:20px;"><tr>
          ${kpi(totalArchivos, 'Archivos revisados', '#222')}
          ${kpi(conAlerta, 'Con alerta / error', conAlerta > 0 ? CONFIG_AUDITORIA.COLOR_ALERTA_TEXTO : CONFIG_AUDITORIA.COLOR_OK_TEXTO)}
          ${kpi(totalPersonasUnicas, 'Personas con acceso', '#222')}
        </tr></table>

        ${bloqueAlerta}

        ${alertas.length > 0 ? `
        <table style="width:100%;border-collapse:collapse;font-size:13px;border:1px solid #ffffff;">
          <thead style="background-color:${CONFIG_AUDITORIA.COLOR_HEADER_FONDO};color:#ffffff;">
            <tr>
              <th style="padding:12px;text-align:center;font-weight:normal;font-size:12px;">Archivo</th>
              <th style="padding:12px;text-align:center;font-weight:normal;font-size:12px;">Estado</th>
              <th style="padding:12px;text-align:center;font-weight:normal;font-size:12px;">Personas</th>
              <th style="padding:12px;text-align:center;font-weight:normal;font-size:12px;">Owner</th>
            </tr>
          </thead>
          <tbody>${filasHtml}</tbody>
        </table>` : ''}

        ${ok.length > 0 ? `<div style="background:${CONFIG_AUDITORIA.COLOR_OK_FONDO};color:${CONFIG_AUDITORIA.COLOR_OK_TEXTO};padding:12px 15px;border-radius:6px;margin-top:16px;font-size:13px;text-align:center;">${ok.length} archivo(s) con acceso restringido.</div>` : ''}

        ${urlHoja ? `<div style="margin-top:22px;text-align:center;"><a href="${urlHoja}" style="display:inline-block;background:${CONFIG_AUDITORIA.COLOR_HEADER_FONDO};color:#fff;text-decoration:none;padding:10px 20px;border-radius:6px;font-size:12px;">Abrir lista en «${CONFIG_AUDITORIA.NOMBRE_HOJA_LISTA}»</a></div>` : ''}

        <p style="margin-top:22px;font-size:11px;color:#888;border-top:1px solid #eee;padding-top:15px;text-align:center;">
          ${CONFIG_AUDITORIA.FIRMA_AUDITORIA}
        </p>
      </div>
    </div>`;
}

function enviarMailOwner(res, nombreArchivo, fechaHoy) {
  if (!res.emailOwner) return;
  enviarMail(
    res.emailOwner,
    `Auditoría de Accesos - ${nombreArchivo} - ${fechaHoy}`,
    generarHtmlOwner(res, nombreArchivo)
  );
}

function generarHtmlOwner(res, nombreArchivo) {
  const chip = `<span style="background:${res.esSeguro ? CONFIG_AUDITORIA.COLOR_OK_FONDO : CONFIG_AUDITORIA.COLOR_ALERTA_FONDO};color:${res.esSeguro ? CONFIG_AUDITORIA.COLOR_OK_TEXTO : CONFIG_AUDITORIA.COLOR_ALERTA_TEXTO};padding:4px 10px;border-radius:12px;font-size:12px;">${res.tipoAcceso}</span>`;

  return `
    <div style="font-family:Arial,sans-serif;color:#333;max-width:600px;border:1px solid #e0e0e0;border-radius:8px;margin:auto;overflow:hidden;background:#fff;">
      <div style="background-color:${CONFIG_AUDITORIA.COLOR_HEADER_FONDO};padding:20px;text-align:center;">
        <h2 style="color:white;margin:0;font-weight:normal;font-size:18px;">Auditoría de Accesos</h2>
      </div>
      <div style="padding:22px;text-align:center;">
        <p style="font-size:14px;">Hola <strong>${res.nombreOwner || 'equipo'}</strong>,</p>
        <p style="font-size:13px;color:#555;">Estado de visibilidad de tu documento:</p>

        <div style="background-color:${CONFIG_AUDITORIA.COLOR_CELDA_FONDO};border:1px solid #ffffff;padding:16px;border-radius:6px;margin:18px 0;">
          <h3 style="margin:0 0 10px 0;color:#222;font-size:15px;font-weight:normal;">📄 ${nombreArchivo}</h3>
          <p style="margin:0 0 8px 0;font-size:13px;">Visibilidad: ${chip}</p>
          <p style="margin:0;font-size:13px;color:#555;">Personas con acceso: ${res.personas.length}</p>
        </div>

        <p style="font-size:12px;color:#777;">El detalle nominal figura en la pestaña <strong>“${CONFIG_AUDITORIA.NOMBRE_HOJA_INFORME}”</strong> de tu archivo.</p>

        <p style="margin-top:22px;font-size:11px;color:#888;border-top:1px solid #eee;padding-top:15px;">
          ${CONFIG_AUDITORIA.FIRMA_AUDITORIA}
        </p>
      </div>
    </div>`;
}

function enviarMailPersona(email, nombre, accesos, fechaHoy) {
  if (!email || !accesos || accesos.length === 0) return false;
  return enviarMail(
    email,
    `Accesos a archivos corporativos - ${fechaHoy}`,
    generarHtmlPersona(nombre || reconstruirNombreDesdeEmail(email), accesos)
  );
}

function generarHtmlPersona(nombre, accesos) {
  const ordenados = accesos.slice().sort((a, b) =>
    (a.rol === 'owner' ? 0 : 1) - (b.rol === 'owner' ? 0 : 1) ||
    String(a.archivo).localeCompare(String(b.archivo)));

  let filasHtml = '';
  ordenados.forEach(a => {
    filasHtml += `<tr style="border-bottom:1px solid #ffffff;background-color:${CONFIG_AUDITORIA.COLOR_CELDA_FONDO};text-align:center;">
      <td style="padding:10px;color:#222;font-size:13px;">${a.archivo}</td>
      <td style="padding:10px;"><span style="background:#f0f0f0;color:#555;padding:3px 8px;border-radius:10px;font-size:11px;">${String(a.rol).toUpperCase()}</span></td></tr>`;
  });

  return `
    <div style="font-family:Arial,sans-serif;color:#333;max-width:640px;border:1px solid #e0e0e0;border-radius:8px;margin:auto;overflow:hidden;background:#fff;">
      <div style="background-color:${CONFIG_AUDITORIA.COLOR_HEADER_FONDO};padding:20px;text-align:center;">
        <h2 style="color:white;margin:0;font-weight:normal;font-size:18px;">Auditoría de Accesos</h2>
      </div>
      <div style="padding:22px;text-align:center;">
        <p style="font-size:14px;">Hola <strong>${nombre}</strong>,</p>
        <p style="font-size:13px;color:#555;">Tenés acceso registrado a los siguientes archivos:</p>
        <table style="width:100%;border-collapse:collapse;font-size:13px;margin-top:12px;border:1px solid #ffffff;">
          <thead style="background-color:${CONFIG_AUDITORIA.COLOR_HEADER_FONDO};color:#ffffff;"><tr>
            <th style="padding:10px;text-align:center;font-weight:normal;font-size:12px;">Archivo</th>
            <th style="padding:10px;text-align:center;font-weight:normal;font-size:12px;">Rol</th>
          </tr></thead>
          <tbody>${filasHtml}</tbody>
        </table>
        <p style="margin-top:16px;font-size:12px;color:#777;">Si hay algún documento al que no deberías acceder, avisanos para gestionar la baja.</p>
        <p style="margin-top:20px;font-size:11px;color:#888;border-top:1px solid #eee;padding-top:15px;">${CONFIG_AUDITORIA.FIRMA_AUDITORIA}</p>
      </div>
    </div>`;
}

function enviarMail(to, subject, htmlBody) {
  try {
    const cuotaRestante = MailApp.getRemainingDailyQuota();
    if (cuotaRestante <= 5) {
      console.warn(`Cuota diaria baja (${cuotaRestante}). No se envía correo a ${to}.`);
      return false;
    }

    if (CONFIG_AUDITORIA.MODO_PRUEBA) {
      const admin = CONFIG_AUDITORIA.EMAIL_RESUMEN || Session.getActiveUser().getEmail();
      if (!admin) return false;
      MailApp.sendEmail({ to: admin, subject: `[PRUEBA → ${to}] ${subject}`, htmlBody: htmlBody });
    } else {
      MailApp.sendEmail({ to: to, subject: subject, htmlBody: htmlBody });
    }
    return true;
  } catch (errMail) {
    console.error(`Error enviando email a ${to}: ${errMail.message}`);
    return false;
  }
}

function aplicarEstiloListaRevisionManual() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const hojaLista = ss.getSheetByName(CONFIG_AUDITORIA.NOMBRE_HOJA_LISTA);
  if (!hojaLista) {
    SpreadsheetApp.getUi().alert(`No se encontró la hoja '${CONFIG_AUDITORIA.NOMBRE_HOJA_LISTA}'.`);
    return;
  }
  estilizarHojaListaRevision(hojaLista);
  SpreadsheetApp.getUi().alert("✅ Diseño minimalista aplicado a 'Lista revisión'.");
}

function estilizarHojaListaRevision(hojaLista) {
  if (!hojaLista) return;
  const lastRow = hojaLista.getLastRow();
  const lastCol = hojaLista.getLastColumn();
  if (lastRow < 1 || lastCol < 1) return;

  const colMap = obtenerMapeoColumnasLista(hojaLista);

  const rangoHeader = hojaLista.getRange(1, 1, 1, lastCol);
  rangoHeader
    .setBackground(CONFIG_AUDITORIA.COLOR_HEADER_FONDO)
    .setFontColor(CONFIG_AUDITORIA.COLOR_HEADER_TEXTO)
    .setFontWeight('bold')
    .setFontSize(10.5)
    .setVerticalAlignment('middle')
    .setHorizontalAlignment('center')
    .setBorder(true, true, true, true, true, true, CONFIG_AUDITORIA.COLOR_BORDE_BLANCO, SpreadsheetApp.BorderStyle.SOLID);

  hojaLista.setRowHeight(1, CONFIG_AUDITORIA.ALTURA_HEADER);
  hojaLista.setFrozenRows(1);

  if (lastRow >= 2) {
    const numRows = lastRow - 1;
    const rangoDatos = hojaLista.getRange(2, 1, numRows, lastCol);
    rangoDatos
      .setVerticalAlignment('middle')
      .setHorizontalAlignment('center')
      .setFontWeight('normal')
      .setBorder(true, true, true, true, true, true, CONFIG_AUDITORIA.COLOR_BORDE_BLANCO, SpreadsheetApp.BorderStyle.SOLID);

    hojaLista.setRowHeights(2, numRows, CONFIG_AUDITORIA.ALTURA_FILA_DATOS);

    for (let r = 2; r <= lastRow; r++) {
      for (let c = 1; c <= lastCol; c++) {
        const celda = hojaLista.getRange(r, c);
        const colIdx = c - 1;

        if (colIdx === colMap.ESTADO) {
          celda.setFontSize(9.5).setFontWeight('normal');
          continue;
        }

        celda.setBackground(CONFIG_AUDITORIA.COLOR_CELDA_FONDO);

        if (colIdx === colMap.OWNER_MAIL) {
          celda.setFontSize(9).setFontColor(CONFIG_AUDITORIA.COLOR_TEXTO_MUTED).setFontWeight('normal');
        } else if (colIdx === colMap.CHEQUEO) {
          celda.setFontSize(9).setFontColor(CONFIG_AUDITORIA.COLOR_TEXTO_FECHA).setFontWeight('normal');
        } else if (colIdx === colMap.ID) {
          celda.setFontSize(8.5).setFontColor('#777777').setFontWeight('normal');
        } else {
          celda.setFontSize(10).setFontColor(CONFIG_AUDITORIA.COLOR_TEXTO_DATOS).setFontWeight('normal');
        }
      }
    }
  }

  try {
    hojaLista.autoResizeColumns(1, lastCol);
    for (let c = 1; c <= lastCol; c++) {
      const anchoActual = hojaLista.getColumnWidth(c);
      hojaLista.setColumnWidth(c, Math.max(anchoActual + 40, CONFIG_AUDITORIA.ANCHO_MIN_COLUMNA));
    }
  } catch (eResize) {}
}

function actualizarFilaListaRevision(hoja, numFila, colMap, filaOriginal, datos) {
  if (colMap.NOMBRE >= 0) {
    const celda = hoja.getRange(numFila, colMap.NOMBRE + 1);
    if (datos.nombre && !String(filaOriginal[colMap.NOMBRE] || '').trim()) {
      celda.setValue(datos.nombre);
    }
    celda.setFontSize(10).setFontColor(CONFIG_AUDITORIA.COLOR_TEXTO_DATOS).setFontWeight('normal');
  }

  if (colMap.ID >= 0) {
    hoja.getRange(numFila, colMap.ID + 1).setFontSize(8.5).setFontColor('#777777').setFontWeight('normal');
  }

  if (colMap.OWNER >= 0) {
    const celda = hoja.getRange(numFila, colMap.OWNER + 1);
    if (datos.owner && !String(filaOriginal[colMap.OWNER] || '').trim()) {
      celda.setValue(datos.owner);
    }
    celda.setFontSize(10).setFontColor(CONFIG_AUDITORIA.COLOR_TEXTO_DATOS).setFontWeight('normal');
  }

  if (colMap.OWNER_MAIL >= 0) {
    const celda = hoja.getRange(numFila, colMap.OWNER_MAIL + 1);
    if (datos.ownerMail && !String(filaOriginal[colMap.OWNER_MAIL] || '').trim()) {
      celda.setValue(String(datos.ownerMail).toLowerCase());
    }
    celda.setFontSize(9).setFontColor(CONFIG_AUDITORIA.COLOR_TEXTO_MUTED).setFontWeight('normal');
  }

  if (colMap.CHEQUEO >= 0 && datos.fechaHora) {
    const celda = hoja.getRange(numFila, colMap.CHEQUEO + 1);
    celda.setValue(datos.fechaHora);
    celda.setFontSize(9).setFontColor(CONFIG_AUDITORIA.COLOR_TEXTO_FECHA).setFontWeight('normal');
  }

  if (colMap.ESTADO >= 0 && datos.estado) {
    hoja.getRange(numFila, colMap.ESTADO + 1)
      .setValue(datos.estado)
      .setBackground(datos.esSeguro ? CONFIG_AUDITORIA.COLOR_OK_FONDO : CONFIG_AUDITORIA.COLOR_ALERTA_FONDO)
      .setFontColor(datos.esSeguro ? CONFIG_AUDITORIA.COLOR_OK_TEXTO : CONFIG_AUDITORIA.COLOR_ALERTA_TEXTO)
      .setFontSize(9.5)
      .setFontWeight('normal');
  }

  const maxCol = Math.max(...Object.values(colMap).filter(v => v >= 0)) + 1;
  const rangoFila = hoja.getRange(numFila, 1, 1, maxCol);
  rangoFila
    .setVerticalAlignment('middle')
    .setHorizontalAlignment('center')
    .setBorder(true, true, true, true, true, true, CONFIG_AUDITORIA.COLOR_BORDE_BLANCO, SpreadsheetApp.BorderStyle.SOLID);

  hoja.setRowHeight(numFila, CONFIG_AUDITORIA.ALTURA_FILA_DATOS);

  for (let c = 0; c < maxCol; c++) {
    if (c !== colMap.ESTADO) {
      hoja.getRange(numFila, c + 1).setBackground(CONFIG_AUDITORIA.COLOR_CELDA_FONDO);
    }
  }
}

function validarServicioDrive() {
  if (typeof Drive === 'undefined') {
    const mensaje =
      "⚠️ El servicio avanzado 'Drive API' no está habilitado en este proyecto.\n\n" +
      "Para habilitarlo en el Editor de Apps Script:\n" +
      "1. En el panel lateral izquierdo, hacé clic en 'Servicios' (+).\n" +
      "2. Buscá 'Google Drive API' (o Drive API).\n" +
      "3. Hacé clic en 'Agregar'.\n\n" +
      "Una vez agregado, volvé a ejecutar la auditoría.";
    console.error(mensaje);
    try { SpreadsheetApp.getUi().alert("Servicio requerido", mensaje, SpreadsheetApp.getUi().ButtonSet.OK); } catch (e) {}
    return false;
  }
  return true;
}

function obtenerPermisosDrive(fileId) {
  try {
    const opciones = {
      supportsAllDrives: true,
      supportsTeamDrives: true,
      maxResults: 100
    };

    let res = null;
    try {
      res = Drive.Permissions.list(fileId, opciones);
    } catch (eParam) {
      res = Drive.Permissions.list(fileId);
    }

    if (!res) return [];

    // Compatibilidad dual Drive API v2 (items) y v3 (permissions)
    if (res.items && Array.isArray(res.items)) return res.items;
    if (res.permissions && Array.isArray(res.permissions)) return res.permissions;

    return [];
  } catch (e) {
    console.warn(`No se pudieron listar permisos de ${fileId}: ${e.message}`);
    throw e;
  }
}

function obtenerMapeoColumnasLista(hoja) {
  const map = { ...COL_DEFAULT };
  if (!hoja) return map;

  const lastCol = hoja.getLastColumn();
  if (lastCol < 1) return map;

  const headers = hoja.getRange(1, 1, 1, lastCol).getValues()[0];
  headers.forEach((h, idx) => {
    const raw = String(h || "").trim().toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "");
    if (!raw) return;

    if (raw.includes("destino") || (raw.includes("nombre") && !raw.includes("owner"))) {
      map.NOMBRE = idx;
    } else if (raw === "id" || (raw.includes("id") && !raw.includes("owner"))) {
      map.ID = idx;
    } else if (raw.includes("owner") && !raw.includes("mail") && !raw.includes("correo")) {
      map.OWNER = idx;
    } else if (raw.includes("owner") && (raw.includes("mail") || raw.includes("correo"))) {
      map.OWNER_MAIL = idx;
    } else if (raw.includes("chequeo") || raw.includes("revision") || raw.includes("fecha")) {
      map.CHEQUEO = idx;
    } else if (raw.includes("estado") || raw.includes("resumen")) {
      map.ESTADO = idx;
    }
  });

  return map;
}

function extraerId(valor) {
  if (!valor) return '';
  const s = String(valor).trim();
  if (s.includes('/d/')) {
    const partes = s.split('/d/')[1];
    return partes ? partes.split('/')[0] : s;
  }
  const m = s.match(/[-\w]{25,}/);
  return m ? m[0] : s;
}

function reconstruirNombreDesdeEmail(email) {
  if (!email || !email.includes('.')) return email || 'Usuario';
  const parteNombre = email.split('@')[0];
  return parteNombre.split('.')
    .map(palabra => palabra.charAt(0).toUpperCase() + palabra.slice(1))
    .join(' ');
}

function acortarMensaje(msg, max) {
  const m = String(msg || "").replace(/^Exception:\s*/i, "").replace(/^Error:\s*/i, "").trim();
  return m.length > max ? m.substring(0, max - 3) + '...' : m;
}

function obtenerDatosDeNomina(spreadsheetId) {
  try {
    const cleanId = extraerId(spreadsheetId);
    if (!cleanId) return {};

    const ssNomina = SpreadsheetApp.openById(cleanId);
    const hoja = ssNomina.getSheetByName(CONFIG_AUDITORIA.NOMBRE_HOJA_NOMINA);
    if (!hoja) return {};

    const lastRow = hoja.getLastRow();
    if (lastRow < 2) return {};

    const valores = hoja.getRange(2, 1, lastRow - 1, 5).getValues();
    const mapa = {};
    valores.forEach(f => {
      if (f && f[0]) {
        mapa[String(f[0]).trim().toLowerCase()] = {
          nombre: f[1] || '',
          puesto: f[2] || '',
          pais: f[3] || '',
          departamento: f[4] || ''
        };
      }
    });
    return mapa;
  } catch (e) {
    console.warn('No se pudo leer la nómina: ' + e.message);
    return {};
  }
}

function ordenarPorJerarquiaYPais(a, b) {
  const ownerA = (a.rol === 'owner' || a.rol === 'organizer') ? 0 : 1;
  const ownerB = (b.rol === 'owner' || b.rol === 'organizer') ? 0 : 1;
  if (ownerA !== ownerB) return ownerA - ownerB;

  if (a.pais !== b.pais) return String(a.pais).localeCompare(String(b.pais));

  const jer = (p) => {
    p = String(p).toLowerCase();
    return p.includes('director') ? 1 : p.includes('manager') ? 2 : 3;
  };
  return jer(a.puesto) - jer(b.puesto) || String(a.nombre).localeCompare(String(b.nombre));
}

function verificarEstadoYCuotas() {
  const driveOk = (typeof Drive !== 'undefined');
  const cuotaRestante = MailApp.getRemainingDailyQuota();
  const usuario = Session.getActiveUser().getEmail() || '(no detectado)';

  SpreadsheetApp.getUi().alert(
    "ℹ️ Diagnóstico de Auditoría de Accesos\n\n" +
    `• Google Drive API: ${driveOk ? "✅ Habilitado" : "❌ No habilitado"}\n` +
    `• Cuota de emails restante: ${cuotaRestante}\n` +
    `• Usuario: ${usuario}\n` +
    `• Modo de prueba: ${CONFIG_AUDITORIA.MODO_PRUEBA ? "SÍ" : "NO"}\n` +
    `• Resumen admin: ${CONFIG_AUDITORIA.ENVIAR_RESUMEN_ADMIN ? "SÍ" : "NO"}\n` +
    `• Avisos Owners: ${CONFIG_AUDITORIA.ENVIAR_AVISO_OWNERS ? "SÍ" : "NO"}\n` +
    `• Avisos Personas: ${CONFIG_AUDITORIA.ENVIAR_AVISO_PERSONAS ? "SÍ" : "NO"}`
  );
}
