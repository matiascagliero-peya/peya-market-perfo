#!/usr/bin/env bash
#
# deploy.sh — sube y deploya un proyecto Apps Script como web app DOMAIN.
#
# Uso:
#   deploy.sh <dir_proyecto> "<Titulo>" ["descripcion del deploy"]
#
# Qué hace (idempotente):
#   1. Si el dir no tiene .clasp.json → crea el proyecto Apps Script (clasp create-script).
#   2. clasp push --force  (sube Code.gs / index.html / appsscript.json).
#   3. Primer deploy → create-deployment y guarda el deploymentId en .deployment_id.
#      Deploys siguientes → redeploy SOBRE el mismo id (la URL NO cambia).
#   4. Imprime la URL de dominio y verifica que esté protegida (302 → ServiceLogin).
#
# La URL final queda también en .web_app_url dentro del dir del proyecto.

set -euo pipefail

DIR="${1:?Falta el directorio del proyecto}"
TITLE="${2:?Falta el título}"
DESC="${3:-deploy}"
DOMAIN="${DOMAIN:-pedidosya.com}"

# clasp vive en ~/.npm-global/bin (el prefix global /opt/homebrew no es escribible por el sandbox).
CLASP="${CLASP:-$HOME/.npm-global/bin/clasp}"
export PATH="$HOME/.npm-global/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"

[ -x "$CLASP" ] || { echo "ERROR: no encuentro clasp en $CLASP"; exit 1; }
cd "$DIR"

# --- 1. crear proyecto si no existe ---
if [ ! -f .clasp.json ]; then
  echo "▸ Creando proyecto Apps Script…"
  # OJO: clasp create-script CLONA el appsscript.json default del server y PISA el local
  # (pierde timeZone y, crítico, el bloque "webapp" → el deploy queda sin entry point y da 404).
  # Por eso respaldamos nuestro manifest y lo restauramos después del create-script.
  [ -f appsscript.json ] && cp appsscript.json .appsscript.keep
  "$CLASP" create-script --type standalone --title "$TITLE" --rootDir .
  [ -f .appsscript.keep ] && mv -f .appsscript.keep appsscript.json
fi

# --- 2. push ---
echo "▸ Subiendo archivos (push)…"
"$CLASP" push --force

# --- 3. deploy / redeploy ---
if [ -f .deployment_id ]; then
  DEP="$(cat .deployment_id)"
  echo "▸ Redeploy sobre $DEP (la URL se mantiene)…"
  "$CLASP" redeploy "$DEP" --description "$DESC"
else
  echo "▸ Primer deploy…"
  OUT="$("$CLASP" create-deployment --description "$DESC" 2>&1)"
  echo "$OUT"
  DEP="$(printf '%s\n' "$OUT" | grep -oE 'AKfycb[A-Za-z0-9_-]+' | head -1 || true)"
  if [ -z "$DEP" ]; then
    # fallback: tomar el deployment versionado (no @HEAD) de la lista
    DEP="$("$CLASP" deployments 2>/dev/null | grep -oE 'AKfycb[A-Za-z0-9_-]+' | tail -1 || true)"
  fi
  [ -n "$DEP" ] || { echo "ERROR: no pude obtener el deploymentId"; exit 1; }
  printf '%s' "$DEP" > .deployment_id
fi

URL="https://script.google.com/a/macros/$DOMAIN/s/$DEP/exec"
printf '%s' "$URL" > .web_app_url

# --- 4. verificar que está protegido ---
echo "▸ Verificando acceso…"
CODE="$(curl -s -o /dev/null -w '%{http_code}' "$URL" || echo '000')"

case "$CODE" in
  302) STATUS="protegido por login del dominio ✓ (activo)";;
  404) STATUS="deploy OK pero TODAVÍA NO autorizado → abrí la URL una vez en el browser
              (logueado @${DOMAIN%%.*}…) y aceptá los permisos; recién ahí pasa a 302";;
  200) STATUS="⚠ responde sin login: revisá que appsscript.json tenga access=DOMAIN";;
  *)   STATUS="código inesperado, revisar a mano";;
esac

echo
echo "════════════════════════════════════════════════════════════"
echo "  URL:        $URL"
echo "  HTTP:       $CODE  → $STATUS"
echo "  deployment: $DEP"
echo "════════════════════════════════════════════════════════════"
echo
echo "La PRIMERA vez que abras la URL te va a pedir autorizar los permisos del"
echo "script (corre con tu identidad). Hasta ese primer OK, el acceso anónimo da 404."
