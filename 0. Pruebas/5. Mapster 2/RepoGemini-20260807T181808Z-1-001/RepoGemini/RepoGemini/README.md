# RepoGemini — Kit de skills y configuración para Gemini CLI

Un conjunto portable de **skills (habilidades)** y **configuraciones de terminal** para trabajar con **Gemini CLI**. Está pensado como kit de inicio limpio: se instala copiando carpetas y no depende de ninguna máquina en particular.

---

## Contenido

- **`skills/`** — 19 habilidades cargables como referencia por el asistente. A grandes rasgos:
  - **Diseño y UI:** `taste-skill`, `soft-skill` (high-end visual design), `minimalist-skill`, `brutalist-skill`, `gpt-tasteskill`, `stitch-skill`, `redesign-skill`, `images-taste-skill`, `frontendwebsiteimageskill`.
  - **Explicaciones visuales:** `visual-explainer`, `generate-slides`, `generate-visual-plan`, `generate-web-diagram`.
  - **Escritura y salida:** `humanizer` (quita el tono robótico de la IA), `output-skill` (fuerza salidas completas sin placeholders).
  - **Productividad:** `handover` (parte de cambio de turno), `find-docs` (documentación de librerías), `host-html` (hostear un HTML como web app de Apps Script), `peya-style` (identidad visual para entregables).
- **`terminal_configs/`** — configuraciones para tu terminal:
  - **`fish/`** — `config.fish` (PATH, `va` para activar venvs, prompt Starship).
  - **`ghostty/`** — config de Ghostty (JetBrains Mono, transparencia, blur, keybindings).
  - **`warp/`** — settings, keybindings, layouts de tabs y tema Dracula para Warp.

---

## Instalación

### Skills

Copiá las habilidades al directorio global de Gemini CLI:

```bash
mkdir -p ~/.gemini/skills
cp -R skills/* ~/.gemini/skills/
```

Algunas skills (por ejemplo `visual-explainer`) traen prompts de comandos en `prompts/`. Para exponerlos como slash-commands:

```bash
mkdir -p ~/.gemini/commands
cp skills/visual-explainer/prompts/*.md ~/.gemini/commands/
```

### Configuraciones de terminal

Copiá cada carpeta a su ubicación por defecto:

- **Fish:** `cp terminal_configs/fish/config.fish ~/.config/fish/config.fish`
- **Ghostty:** `cp terminal_configs/ghostty/config ~/.config/ghostty/config`
- **Warp:** copiá el contenido de `terminal_configs/warp/` a `~/.warp/`.

> Los configs de Warp/Ghostty referencian paths tipo `~/.warp/...` y el binario de fish (`/opt/homebrew/...`). Ajustalos según tu máquina.

---

## Privacidad

- Sin nombres propios, correos ni credenciales.
- Sin rutas absolutas atadas a un usuario: se usan `~` y `$HOME`.
- Nota: `peya-style` y `host-html` referencian un flujo de trabajo con Google Workspace / Apps Script y un dominio corporativo. Si no usás ese entorno, ignorá esas dos skills o adaptá el dominio.
