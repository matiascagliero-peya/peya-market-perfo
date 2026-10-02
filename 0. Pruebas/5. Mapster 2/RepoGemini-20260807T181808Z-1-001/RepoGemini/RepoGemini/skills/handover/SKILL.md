---
name: handover
description: "Genera un documento HANDOVER.md en el directorio de trabajo actual. Usa esta skill cuando el usuario quiere hacer un handover, cerrar una sesion, documentar el estado actual para la proxima sesion, o dice cosas como 'dejame un resumen de lo que hicimos', 'genera el handover', 'parte de cambio de turno', 'documentame donde quedamos'."
---

Genera un documento HANDOVER.md en el directorio de trabajo actual.

Este documento es un "parte de cambio de turno" — le dice a la proxima sesion del asistente exactamente donde quedaron las cosas para que nada se pierda entre sesiones.

## El HANDOVER.md debe cubrir:

1. **Resumen de la sesion**: Que se estuvo trabajando y que se logro
2. **Que funciono y que no**: Incluyendo bugs encontrados y como se resolvieron
3. **Decisiones clave**: Que se decidio y por que
4. **Lecciones aprendidas y gotchas**: Cosas a tener en cuenta
5. **Proximos pasos**: Que queda pendiente, en orden de prioridad
6. **Mapa de archivos importantes**: Archivos clave tocados o relevantes con descripcion breve

## Formato:
- Usa markdown claro y conciso
- Escribi en espanol
- Se especifico: inclui paths, nombres de funciones, versiones
- El objetivo es que alguien (o un asistente) pueda retomar el trabajo sin contexto previo
- NO incluyas secretos, API keys ni datos sensibles

## Nombre del archivo:
- Genera un titulo breve (3-5 palabras) que resuma el tema principal de la sesion
- Usa el formato: `HANDOVER - Titulo breve - YYYY-MM-DD.md`
- Ejemplo: `HANDOVER - Configuracion de hooks - 2026-02-10.md`
- Los espacios en el nombre estan bien (es un archivo local, no una URL)
- Guarda el archivo en el directorio de trabajo actual
