---
name: host-html
description: >-
  Hostea un HTML como web app de Google Apps Script protegida por login @pedidosya.com,
  deployada desde la terminal con clasp. Da una URL fija, accesible solo para el dominio,
  sin servidor ni hosting propio. Usá este skill SIEMPRE que el usuario pida "hosteá este
  HTML", "publicá / subí este dashboard", "dame un link interno para esto", "convertí este
  HTML/dashboard/reporte en una web app", "deployá esto con clasp", "que tenga una URL fija
  protegida", o quiera compartir un HTML/tablero/visualización con el equipo de PedidosYa por
  link (en vez de mandar el archivo por chat). También cuando pida actualizar un dashboard ya
  hosteado sin que cambie la URL. Aplica tanto si el HTML ya existe como si hay que generarlo
  primero.
---

# host-html — hostear un HTML como web app interna (clasp + Apps Script)

Convierte un HTML en una **web app de Google Apps Script** con una **URL fija** protegida por
login `@pedidosya.com`. Reemplaza el flujo de mandar HTMLs estáticos por chat: queda un link,
solo accesible para gente del dominio, que se puede actualizar sin cambiar la URL.

No hace falta servidor ni hosting: todo vive dentro del Workspace. Setup ya montado: `clasp`
v3 logueado como `tu_usuario@pedidosya.com`, Apps Script API activada.

## Cuándo es esto y cuándo no
- **Sí**: querés un link interno y privado para un HTML/dashboard/reporte, una sola URL que se
  actualiza, data en vivo o pre-calculada, acceso restringido al dominio.
- **No**: alto tráfico o público anónimo masivo (esto tiene quotas de uso interno), frontend
  pesado tipo React/Vue (acá es JS vanilla del lado cliente; tablas y Chart.js/Google Charts van bien).

## Flujo principal (HTML estático)

Este es el caso por defecto: tenés (o generás) un HTML y lo querés hostear tal cual.

1. **Conseguí el HTML.** Si ya existe, partís de ahí. Si hay que generarlo (un dashboard, un
   reporte), generalo primero — para entregables visuales de PedidosYa usá el skill `peya-style`
   (paleta/tipografía/reglas), y los skills de dashboards/diagramas según corresponda.

2. **Armá el directorio del proyecto** en `~/apps-script/<nombre-corto>/` (un dir por web app;
   ahí viven `~/apps-script/hola-equipo`, etc.). Necesita exactamente tres archivos:
   - `index.html` ← tu HTML completo (HTML + CSS en `<style>` + JS de browser en `<script>`,
     todo junto; en Apps Script no hay `.css`/`.js` sueltos).
   - `Code.gs` ← backend mínimo que sirve el HTML. Copiá `assets/Code.gs` de este skill y
     reemplazá `__TITLE__` por el título de la pestaña.
   - `appsscript.json` ← manifest con el acceso DOMAIN. Copiá `assets/appsscript.json` tal cual.

   El control de acceso es **el manifest, no flags de clasp**:
   `"webapp": { "executeAs": "USER_DEPLOYING", "access": "DOMAIN" }`.
   `access: DOMAIN` = solo `@pedidosya.com`; `executeAs: USER_DEPLOYING` = corre con tu identidad
   (ve tus Sheets/BQ aunque el visitante no tenga permiso directo).

3. **Deployá** con el script bundleado, que encadena create-script (si hace falta) + push +
   deploy, persiste el deployment id y verifica que quede protegido:
   ```bash
   ~/.gemini/skills/host-html/scripts/deploy.sh ~/apps-script/<nombre-corto> "<Título>" "v1"
   ```
   Imprime la **URL de dominio** y el código HTTP. La URL también queda en
   `~/apps-script/<nombre-corto>/.web_app_url`.
   - **302** = protegido por login del dominio y activo ✓.
   - **404** en un deploy nuevo = esperado: el web app recién creado da 404 a accesos anónimos
     **hasta que el dueño lo abre una vez en el browser** (logueado con su cuenta del dominio) y
     acepta los permisos del script. Después de ese primer OK pasa a 302. No es un error.

4. **Pasale la URL al usuario.** Formato:
   `https://script.google.com/a/macros/pedidosya.com/s/<deploymentId>/exec`.
   Avisá que la **primera vez** que la abra le va a pedir autorizar los permisos del script
   (porque corre con su identidad) — es esperado, una sola vez.

## Actualizar sin cambiar la URL

Editás `index.html` (u otro archivo) y volvés a correr **el mismo** `deploy.sh`:
```bash
~/.gemini/skills/host-html/scripts/deploy.sh ~/apps-script/<nombre-corto> "<Título>" "v2"
```
Como ya existe `.deployment_id` en el dir, hace `redeploy` sobre el mismo deployment → **la URL
se mantiene**. (Por eso no borres `.deployment_id`: es lo que evita generar una URL nueva.)

## Variantes (leé `references/advanced.md` cuando apliquen)

El flujo de arriba cubre HTML estático. Para lo demás, abrí `references/advanced.md`:
- **Datos en vivo / interpolar variables del backend o query params** → patrón con plantilla
  (`createTemplateFromFile` + `<?= var ?>`), §1.
- **Queries pesadas** (timeout 6 min/ejecución) → pre-calcular con trigger a un Sheet, §2.
- **Re-autenticar clasp** (si da 401/403) → login OAuth interactivo, §3.
- **Dashboard que se actualiza solo** con cómputo Python/BQ → cron local (launchd) que regenera
  el HTML y hace redeploy, §4.
- **Borrar un proyecto** (clasp no borra el proyecto, solo deployments) → Drive API con token de
  gcloud, §5.
- **Algo falla** (`clasp not found`, `fetch failed`, da 200 en vez de 302, cambió la URL) →
  troubleshooting, §6.

## Notas operativas
- `clasp` está en `~/.npm-global/bin/clasp` (no en el PATH del sandbox; el script ya usa el path
  absoluto). Si lo corrés a mano, usá esa ruta.
- Ante ambigüedad sobre nombre del proyecto, título o si el HTML debe llevar datos en vivo,
  preguntá antes de deployar — un deploy crea un artefacto real en Drive.
