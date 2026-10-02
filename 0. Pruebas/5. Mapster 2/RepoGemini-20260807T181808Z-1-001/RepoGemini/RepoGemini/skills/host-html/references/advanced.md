# host-html — referencia avanzada

Leé la sección que necesites; el flujo básico (HTML estático) está en `SKILL.md`.

## Tabla de contenidos
1. [Datos en vivo / interpolar variables (plantilla)](#1-datos-en-vivo)
2. [Datos pre-calculados con trigger (queries pesadas)](#2-datos-pre-calculados)
3. [Login de clasp (si hace falta re-autenticar)](#3-login-de-clasp)
4. [Auto-refresh: dashboard que se actualiza solo (launchd)](#4-auto-refresh)
5. [Borrar un proyecto Apps Script](#5-borrar-un-proyecto)
6. [Troubleshooting](#6-troubleshooting)

---

## 1. Datos en vivo

Cuando el HTML necesita datos del backend (no es estático puro), usá una **plantilla**.
El `.html` lleva placeholders `<?= variable ?>` (valor) y `<? ... ?>` (lógica if/for),
y el `Code.gs` los completa antes de servir.

`Code.gs`:
```javascript
function doGet(e) {
  // los query params de la URL llegan en e.parameter (?nombre=ALG → e.parameter.nombre)
  const nombre = (e.parameter.nombre || 'EQUIPO').toUpperCase();

  const tpl = HtmlService.createTemplateFromFile('index');
  tpl.nombre = nombre;                 // queda disponible como <?= nombre ?> en el HTML
  return tpl.evaluate()
    .setTitle('Mi Dashboard')
    .addMetaTag('viewport', 'width=device-width, initial-scale=1');
}
```

`index.html`:
```html
<h1>HOLA <span class="equipo"><?= nombre ?></span></h1>
```

Para datos que vienen de una query/Sheet **en cada visita**, el `doGet` puede leer un
Sheet o correr una query BQ y pasar el resultado a la plantilla. Ojo el **timeout de 6 min**
por ejecución → para queries pesadas, ver pre-calculado.

El puente front↔back para llamadas asíncronas desde el browser es `google.script.run`:
```javascript
// en el <script> del index.html
google.script.run.withSuccessHandler(pintar).getData();
// en Code.gs: function getData() { return [...]; }
```

---

## 2. Datos pre-calculados

Para queries pesadas, NO las corras en cada visita. Un **time-driven trigger** corre la
query cada X (ej: 7am), guarda el resultado en un Sheet, y el web app solo lo lee (rápido).

En el editor de Apps Script: ⏰ Triggers → Add trigger → función que escribe el Sheet,
time-driven, cada hora/día. El `doGet` solo hace `SpreadsheetApp.openById(...).getDataRange().getValues()`.

Si el cómputo **no puede** correr en Apps Script (Python/BQ pesado, proxy corporativo),
usá auto-refresh local (sección 4).

---

## 3. Login de clasp

Normalmente ya está logueado como `tu_usuario@pedidosya.com` (creds en `~/.clasprc.json`),
no hace falta tocar nada. Si clasp da 401/403 de auth, re-logueá. Es OAuth interactivo
(igual que `gcloud auth login`): no se puede automatizar a ciegas.

```bash
~/.npm-global/bin/clasp login --no-localhost
```

1. clasp imprime un **URL** → el usuario lo abre en un browser logueado con la cuenta.
2. Autoriza; el browser tira a `http://localhost:8888/?code=...` con error de conexión (esperado).
3. Se pega esa **URL completa** al proceso.

La OAuth app default de clasp NO está bloqueada por el Workspace → no hace falta `--creds`.

**Inyección del código sin TTY (agente/script):** el proceso queda esperando stdin → usar FIFO
con un holder que evite EOF:
```bash
mkfifo /tmp/clasp_fifo
( while true; do sleep 2; done ) > /tmp/clasp_fifo &        # holder
~/.npm-global/bin/clasp login --no-localhost < /tmp/clasp_fifo > /tmp/login.log 2>&1 &
# leer el URL de /tmp/login.log → pedirle al usuario que autorice → pegar la URL completa:
echo 'http://localhost:8888/?code=...URL_COMPLETA...' > /tmp/clasp_fifo
```

La Apps Script API debe estar ON en https://script.google.com/home/usersettings (ya activada).

---

## 4. Auto-refresh

Patrón validado para "dash que se actualiza solo" cuando el cómputo es Python/BQ (no cabe en
Apps Script): un **cron local (launchd)** regenera el `index.html` y hace redeploy. La URL no cambia.

`refresh.sh` (lo corre launchd): query BQ → build del HTML (Python) → `clasp push --force` +
`clasp redeploy <id>`. Reutilizá `scripts/deploy.sh` para los dos últimos pasos.

**Gotchas launchd en esta Mac:**
- `launchctl bootstrap gui/$(id -u) <plist>` (y `bootout`/`kickstart`) fallan con
  "Input/output error 5" dentro del sandbox → correr con `dangerouslyDisableSandbox: true`
  (el sandbox bloquea el socket Mach de launchd). No uses `launchctl load -w`; usá `bootstrap`.
- launchd tiene PATH mínimo → paths absolutos o exportar PATH (`/opt/homebrew/bin` para bq/gcloud,
  `/usr/bin/python3`, `~/.npm-global/bin/clasp`).
- gcloud/clasp leen creds de `~/.config` y `~/.clasprc.json` → andan desde launchd (HOME seteado).
  Validar con `launchctl kickstart -k gui/$(id -u)/<label>` y revisar el log.
- Depende de la Mac prendida + VPN corporativa a la hora del cron. Para independizar → Cloud Run + Scheduler.

---

## 5. Borrar un proyecto

`clasp` **no** borra el proyecto, solo deployments:
```bash
~/.npm-global/bin/clasp delete-deployment <deploymentId>   # el @HEAD es read-only, muere con el proyecto
```

Para borrar el **proyecto entero** (es un archivo en Drive) usá la Drive API con el token de
**gcloud** (la cuenta gcloud está logueada con scope drive completo; el token de clasp,
scope `drive.file`, da 403 sobre proyectos creados vía Apps Script API):
```bash
curl -s -X DELETE \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  "https://www.googleapis.com/drive/v3/files/<scriptId>"
```
El `scriptId` está en `.clasp.json` del proyecto.

---

## 6. Troubleshooting

- **`clasp: command not found`** → no está en el PATH del sandbox. Usá el path absoluto
  `~/.npm-global/bin/clasp` (el script `deploy.sh` ya lo hace).
- **`fetch failed` / `ECONNREFUSED` / `ETIMEDOUT`** en algún comando Node → proxy corporativo.
  Prefijá el comando con el ProxyAgent de undici, apuntando `--import` a tu script de proxy local:
  `PROXY_PORT=$(gcloud config get-value proxy/port); HTTPS_PROXY=http://localhost:$PROXY_PORT NODE_OPTIONS="--import $HOME/.ctx7/proxy-inject.mjs" <comando>`.
- **404 / "Sorry, unable to open the file at this time" tras el PRIMER deploy** → casi siempre
  el manifest subió **sin el bloque `webapp`**, así que el deploy no tiene entry point de web app.
  Causa típica: `clasp create-script` clona el `appsscript.json` default del server y **pisa el
  local** (queda `timeZone New_York` y sin `webapp`). Verificá con `cat appsscript.json` que tenga
  el bloque `webapp`; si no, restauralo y re-deployá. El `deploy.sh` ya respalda/restaura el
  manifest alrededor del `create-script` para evitar esto.
- **El curl de verificación da 404 con el manifest correcto** → NO es error. Un web app recién
  creado responde 404 a accesos anónimos **hasta que el dueño lo abre una vez en el browser**
  (logueado con su cuenta del dominio) y acepta los permisos del script. Después de ese primer
  OK, el acceso anónimo pasa a dar 302 → ServiceLogin. O sea: deployás → abrís la URL una vez
  vos → recién ahí el curl da 302. Por eso el `deploy.sh` trata 404 como "falta autorizar",
  no como fallo.
- **El curl de verificación da 200 en vez de 302** → revisá que `appsscript.json` tenga
  `"access": "DOMAIN"` y volvé a deployar. 200 puede significar acceso público (`ANYONE`).
- **La URL cambió después de actualizar** → usaste `create-deployment` en vez de `redeploy`.
  El `deploy.sh` guarda el id en `.deployment_id` justamente para evitar esto; no lo borres.
- **"Acceso bloqueado por el administrador" en el login** → Plan B: crear OAuth client ID propio
  (Desktop app) en console.cloud.google.com y `clasp login --creds /ruta/client_secret.json`.
