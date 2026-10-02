---
name: peya-style
description: Estilo visual PeYa - paleta, tipografía y reglas de diseño para slides, tableros, dashboards, HTML y cualquier visualización. Usar siempre que se pida un entregable visual.
---

# Estilo Visual PeYa (Fénix)

Aplicar esta identidad en TODO output visual: slides, tableros, dashboards, HTML, PPTX, diagramas.

## Cómo usar este archivo

**Opción A — Como skill de Gemini CLI (recomendado):**
Guardar como `~/.gemini/skills/peya-style/SKILL.md`. Invocar con `/peya-style` o mencionar al pedir un entregable visual.

**Opción B — Global:**
Pegar el contenido (sin el frontmatter de arriba) en tu contexto global `~/.gemini/GEMINI.md`. Se aplica siempre.

---

## Paleta de colores

### Rojos (primario marca)
- `red-50`: #EA044E (principal)
- `red-40`: #EC1D60
- `red-70`: #B40443 (oscuro)
- `red-20`: #F481A6 (claro)

### Navy (textos, fondos oscuros)
- `navy-90`: #100423 (más oscuro, títulos)
- `navy-70`: #4C4359
- `navy-60`: #70697A (texto secundario/gris)

### Acentos
- `informative`: #04ADDF (azul info)
- `deals/comms`: #F8EA46 (amarillo)
- `accent`: #72E6FF (celeste)
- `positive/dmarts`: #2DE1A0 (verde — usar para DMarts)

## Tipografía
- **Font**: Outfit (pesos: Normal, Medium, Semibold, Bold, Extrabold)
- En PPTX: "Outfit" si está disponible, fallback a "Poppins"

## Estructura de slides
- Top bar con logo "P" en rojo (#EA044E) + título en gris
- Línea fina separadora debajo del header
- Label de sección en rojo bold (ej: "TESTEOS", "FOUNDATIONS")
- Título principal en navy-90 (#100423) bold grande
- Cards con bordes redondeados y borde gris claro (#E0E0E5)
- Fondo de slide: blanco
- "Volver al índice ↩" en rojo arriba derecha (opcional)

## Elementos de UI
- Pills/chips para estados: WIP, NEW, TBD, DONE
- Callouts: informative (azul), warning (amarillo), positive (verde), error (rojo)
- Botones: fondo rojo, texto blanco
- Links con iconos de servicio (Drive, Slack, Figma, etc.)
- Progress bars y termómetros disponibles

## Reglas generales
- NO usar colores genéricos (azul/verde/naranja Material Design)
- Priorizar rojo PeYa como acento, navy para textos
- Cards siempre con rounded corners
- Diseño limpio, mucho white space
- Tablas: headers en navy-90 fondo oscuro texto blanco; filas alternadas con gris muy claro
