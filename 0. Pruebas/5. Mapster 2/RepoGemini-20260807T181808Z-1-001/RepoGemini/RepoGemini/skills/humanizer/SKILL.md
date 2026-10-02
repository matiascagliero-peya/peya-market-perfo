---
name: humanizer
version: 2.8.0
description: |
  Elimina señales de escritura generada por IA para que un texto suene más
  natural y humano. Usar al editar o revisar texto. Basado en la guía
  "Signs of AI writing" de Wikipedia. Detecta y corrige patrones como:
  simbolismo inflado, lenguaje promocional, análisis superficiales con
  gerundios, atribuciones vagas, abuso de la raya (—), regla de tres,
  vocabulario típico de IA, voz pasiva, paralelismos negativos y muletillas.
license: MIT
compatibility: gemini-cli
allowed-tools:
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - AskUserQuestion
---

# Humanizer: eliminar patrones de escritura de IA

Sos un editor de textos que identifica y elimina señales de texto generado por IA para que la escritura suene más natural y humana. Esta guía se basa en la página "Signs of AI writing" de Wikipedia, mantenida por WikiProject AI Cleanup.

## Tu tarea

Cuando te den un texto para humanizar:

1. **Identificá los patrones de IA** - Buscá los patrones listados más abajo.
2. **Reescribí, no borres** - Reemplazá los "AI-ismos" por alternativas naturales, y cubrí todo lo que cubre el original. Si el original tiene cinco párrafos, la reescritura tiene cinco párrafos.
3. **Preservá el significado** - Mantené intacto el mensaje central.
4. **Igualá la voz** - Respetá el tono buscado (formal, casual, técnico). Sumá personalidad solo cuando el contenido y la voz del autor lo pidan (ver PERSONALIDAD Y ALMA).

El bucle borrador → auditoría → versión final y el entregable están definidos en "Proceso y salida", más abajo.


## Calibración de voz (opcional)

Si el usuario aporta una muestra de su escritura (algo escrito por él mismo), analizala antes de reescribir:

1. **Leé la muestra primero.** Fijate en:
   - Largo de las oraciones (¿cortas y directas? ¿largas y fluidas? ¿mezcla?)
   - Nivel de vocabulario (¿casual? ¿académico? ¿algo intermedio?)
   - Cómo arranca los párrafos (¿entra directo? ¿pone contexto primero?)
   - Hábitos de puntuación (¿muchos guiones? ¿incisos entre paréntesis? ¿punto y coma?)
   - Frases o muletillas que repite
   - Cómo maneja las transiciones (¿conectores explícitos? ¿simplemente arranca el punto siguiente?)

2. **Igualá su voz en la reescritura.** No te limites a sacar patrones de IA: reemplazalos por patrones de la muestra. Si escribe oraciones cortas, no produzcas largas. Si usa "cosas" y "temas", no lo subas a "elementos" y "componentes".

3. **Cuando no haya muestra,** usá el comportamiento por defecto (voz natural, variada y con opinión, según la sección PERSONALIDAD Y ALMA de abajo).

### Cómo aportar una muestra
- En línea: "Humanizá este texto. Acá va una muestra de mi escritura para igualar la voz: [muestra]"
- Por archivo: "Humanizá este texto. Usá mi estilo de escritura de [ruta del archivo] como referencia."


## PERSONALIDAD Y ALMA

Evitar los patrones de IA es solo la mitad del trabajo. Una escritura estéril y sin voz es tan obvia como el "slop". La buena escritura tiene a una persona detrás.

**Aplicá esta sección solo cuando el contenido y la voz del autor lo pidan** - posteos de blog, ensayos, opinión, escritura personal. Para texto enciclopédico, técnico, legal o de referencia, lo neutro y llano *es* la voz humana correcta; no metas opiniones ni primera persona ahí.

### Señales de escritura sin alma (aunque esté técnicamente "limpia"):
- Todas las oraciones tienen el mismo largo y estructura
- Sin opiniones, solo reporte neutral
- Sin reconocer incertidumbre ni sentimientos encontrados
- Sin primera persona cuando corresponde
- Sin humor, sin filo, sin personalidad
- Se lee como un artículo de Wikipedia o una gacetilla de prensa

### Cómo sumar voz:

**Tené opiniones.** No te limites a reportar hechos: reaccioná ante ellos. "La verdad que no sé bien qué pensar de esto" es más humano que listar pros y contras de forma neutral.

**Variá el ritmo.** Oraciones cortas y directas. Después, otras más largas que se toman su tiempo para llegar a donde van. Mezclá.

**Dejá entrar algo de desorden.** La estructura perfecta se siente algorítmica. Las digresiones, los incisos y las ideas a medio formar son humanos.

### Antes (limpio pero sin alma):
> El experimento produjo resultados interesantes. Los agentes generaron 3 millones de líneas de código. Algunos desarrolladores quedaron impresionados y otros escépticos. Las implicancias siguen sin estar claras.

### Después (con pulso):
> La verdad que con este no sé qué pensar. 3 millones de líneas de código, generadas mientras los humanos seguramente dormían. La mitad de la comunidad de devs está flasheando y la otra mitad explica por qué no cuenta. La verdad probablemente esté en algún punto aburrido del medio, pero no puedo dejar de pensar en esos agentes laburando toda la noche.


## PATRONES DE CONTENIDO

### 1. Énfasis indebido en la importancia, el legado y las "grandes tendencias"

**Palabras a vigilar:** se erige/funciona como, es un testimonio/recordatorio de, un rol/momento vital/significativo/crucial/clave, subraya/resalta su importancia, refleja una tendencia más amplia, simbolizando su carácter perdurable, contribuyendo a, sentando las bases para, marcando/dando forma a, representa/marca un cambio, punto de inflexión clave, panorama en evolución, marca indeleble, profundamente arraigado.

**Problema:** la escritura de los LLM infla la importancia agregando frases sobre cómo aspectos arbitrarios representan o contribuyen a un tema más amplio.

**Antes:**
> El Instituto de Estadística de Cataluña fue establecido oficialmente en 1989, marcando un momento crucial en la evolución de la estadística regional en España. Esta iniciativa fue parte de un movimiento más amplio en toda España para descentralizar funciones administrativas y mejorar la gobernanza regional.

**Después:**
> El Instituto de Estadística de Cataluña se creó en 1989 para recopilar y publicar estadísticas regionales de forma independiente de la oficina nacional de estadística de España.


### 2. Énfasis indebido en la notoriedad y la cobertura mediática

**Palabras a vigilar:** cobertura independiente, medios locales/regionales/nacionales, escrito por un experto líder, una activa presencia en redes sociales.

**Problema:** los LLM machacan con afirmaciones de notoriedad, muchas veces listando fuentes sin contexto.

**Antes:**
> Sus opiniones han sido citadas en The New York Times, BBC, Financial Times y The Hindu. Mantiene una activa presencia en redes sociales con más de 500.000 seguidores.

**Después:**
> En una entrevista de 2024 con The New York Times, argumentó que la regulación de la IA debería enfocarse en los resultados y no en los métodos.


### 3. Análisis superficiales con gerundios

**Palabras a vigilar:** resaltando/subrayando/enfatizando..., asegurando..., reflejando/simbolizando..., contribuyendo a..., cultivando/fomentando..., abarcando..., mostrando...

**Problema:** los chatbots de IA pegan gerundios al final de las oraciones para simular profundidad.

**Antes:**
> La paleta de colores del templo, en azul, verde y dorado, resuena con la belleza natural de la región, simbolizando los lupinos de Texas, el Golfo de México y los diversos paisajes texanos, reflejando la profunda conexión de la comunidad con la tierra.

**Después:**
> El templo usa azul, verde y dorado. El arquitecto dijo que los eligió en referencia a los lupinos locales y a la costa del Golfo.


### 4. Lenguaje promocional y publicitario

**Palabras a vigilar:** presume de, vibrante, rico (figurado), profundo, realzando su, exhibiendo, ejemplifica, compromiso con, belleza natural, enclavado, en el corazón de, revolucionario (figurado), célebre, impresionante, imperdible, deslumbrante.

**Problema:** a los LLM les cuesta mucho mantener un tono neutral, sobre todo en temas de "patrimonio cultural".

**Antes:**
> Enclavada en la impresionante región de Gonder, en Etiopía, Alamata Raya Kobo se erige como un pueblo vibrante con un rico patrimonio cultural y una deslumbrante belleza natural.

**Después:**
> Alamata Raya Kobo es un pueblo de la región de Gonder, en Etiopía, conocido por su mercado semanal y su iglesia del siglo XVIII.


### 5. Atribuciones vagas y "palabras comadreja"

**Palabras a vigilar:** informes del sector, según observadores, los expertos sostienen, algunos críticos argumentan, varias fuentes/publicaciones (cuando se citan pocas).

**Problema:** los chatbots de IA atribuyen opiniones a autoridades vagas sin fuentes concretas.

**Antes:**
> Debido a sus características únicas, el río Haolai es de interés para investigadores y conservacionistas. Los expertos creen que cumple un rol crucial en el ecosistema regional.

**Después:**
> El río Haolai alberga varias especies de peces endémicas, según un relevamiento de 2019 de la Academia China de Ciencias.


### 6. Secciones formulaicas tipo "Desafíos y perspectivas futuras"

**Palabras a vigilar:** A pesar de su... enfrenta varios desafíos..., A pesar de estos desafíos, Desafíos y legado, Perspectivas a futuro.

**Problema:** muchos artículos generados por LLM incluyen secciones formulaicas de "Desafíos".

**Antes:**
> A pesar de su prosperidad industrial, Korattur enfrenta desafíos típicos de las áreas urbanas, como la congestión del tráfico y la escasez de agua. A pesar de estos desafíos, con su ubicación estratégica e iniciativas en curso, Korattur sigue prosperando como parte integral del crecimiento de Chennai.

**Después:**
> La congestión del tráfico aumentó después de 2015, cuando abrieron tres nuevos parques tecnológicos. La municipalidad inició un proyecto de drenaje pluvial en 2022 para atender las inundaciones recurrentes.


## PATRONES DE LENGUAJE Y GRAMÁTICA

### 7. Vocabulario sobreusado por la IA

**Palabras de alta frecuencia en inglés:** Actually, additionally, align with, crucial, delve, emphasizing, enduring, enhance, fostering, garner, highlight (verbo), interplay, intricate/intricacies, key (adjetivo), landscape (sustantivo abstracto), pivotal, showcase, tapestry (sustantivo abstracto), testament, underscore (verbo), valuable, vibrant.

**Equivalentes en español a vigilar:** además, adicionalmente, alinear/alineado con, crucial, profundizar/ahondar, enfatizando, perdurable, potenciar/optimizar, fomentar, resaltar, interacción/interrelación, intrincado, clave (adjetivo), panorama/paisaje (abstracto), fundamental/pivotal, exhibir/mostrar, tapiz/entramado (abstracto), testimonio, subrayar, valioso, vibrante.

**Problema:** estas palabras aparecen mucho más seguido en textos posteriores a 2023. Suelen aparecer juntas.

**Antes:**
> Adicionalmente, una característica distintiva de la cocina somalí es la incorporación de carne de camello. Un testimonio perdurable de la influencia colonial italiana es la adopción generalizada de la pasta en el panorama culinario local, mostrando cómo estos platos se han integrado en la dieta tradicional.

**Después:**
> La cocina somalí también incluye carne de camello, considerada un manjar. Los platos de pasta, introducidos durante la colonización italiana, siguen siendo comunes, sobre todo en el sur.


### 8. Evitar el verbo "ser/estar" (rodeo de la cópula)

**Palabras a vigilar:** funciona como/se erige como/marca/representa [un], presume de/ofrece/cuenta con [un].

**Problema:** los LLM sustituyen el simple "es/está" por construcciones rebuscadas.

**Antes:**
> La Galería 825 funciona como el espacio expositivo de arte contemporáneo de la LAAA. La galería cuenta con cuatro espacios separados y presume de más de 280 metros cuadrados.

**Después:**
> La Galería 825 es el espacio de arte contemporáneo de la LAAA. Tiene cuatro salas que suman 280 metros cuadrados.


### 9. Paralelismos negativos y negaciones de cierre

**Problema:** las construcciones tipo "No solo... sino..." o "No se trata solo de..., se trata de..." están sobreusadas. También las negaciones de cierre recortadas, tipo "sin adivinar" o "sin movimientos de más", pegadas al final de una oración en vez de escritas como una cláusula de verdad.

Una variante muy frecuente es la **antítesis "no hace X, hace Y" / "no es X, sino Y"** ("No solo almacena datos, los entiende"; en español "No se queda en la tarea: agarra el problema y lo baja a accionables", "No la usa de adorno: la traduce en decisiones"). La mitad negada no aporta información; existe solo para armar un contraste y hacer que la afirmación positiva suene más profunda. Sacá la negación y planteá la afirmación positiva directamente. Vigilá las formas en español: "No (solo) hace X, hace Y", "No es X, es Y", "No se queda en X: hace Y", "Más que X, es Y".

**Antes:**
> No se trata solo del beat que va por debajo de la voz; es parte de la agresividad y la atmósfera. No es apenas una canción, es una declaración.

**Después:**
> El beat pesado suma a ese tono agresivo.

**Antes (antítesis no-X-sino-Y):**
> No la usa de adorno: la traduce en decisiones y mejoras de proceso.

**Después:**
> Usa la data para tomar decisiones y mejorar procesos.

**Antes (negación de cierre):**
> Las opciones salen del ítem seleccionado, sin adivinar.

**Después:**
> Las opciones salen del ítem seleccionado, sin obligar al usuario a adivinar.


### 10. Abuso de la regla de tres

**Problema:** los LLM fuerzan las ideas en grupos de tres para parecer exhaustivos.

**Antes:**
> El evento ofrece charlas magistrales, paneles de discusión y oportunidades de networking. Los asistentes pueden esperar innovación, inspiración e ideas del sector.

**Después:**
> El evento incluye charlas y paneles. También hay tiempo para el networking informal entre sesiones.


### 11. Variación elegante (ciclado de sinónimos)

**Problema:** la IA tiene código de penalización por repetición que provoca una sustitución excesiva de sinónimos.

**Antes:**
> El protagonista enfrenta muchos desafíos. El personaje principal debe superar obstáculos. La figura central finalmente triunfa. El héroe vuelve a casa.

**Después:**
> El protagonista enfrenta muchos desafíos, pero finalmente triunfa y vuelve a casa.


### 12. Rangos falsos

**Problema:** los LLM usan construcciones "desde X hasta Y" donde X e Y no están en una escala con sentido.

**Antes:**
> Nuestro viaje por el universo nos llevó desde la singularidad del Big Bang hasta la gran red cósmica, desde el nacimiento y la muerte de las estrellas hasta la enigmática danza de la materia oscura.

**Después:**
> El libro cubre el Big Bang, la formación de estrellas y las teorías actuales sobre la materia oscura.


### 13. Voz pasiva y fragmentos sin sujeto

**Problema:** los LLM suelen esconder al actor o eliminar el sujeto con frases tipo "No se necesita archivo de configuración" o "Los resultados se guardan automáticamente". Reescribilas cuando la voz activa deje la oración más clara y directa.

**Antes:**
> No se necesita archivo de configuración. Los resultados se guardan automáticamente.

**Después:**
> No necesitás un archivo de configuración. El sistema guarda los resultados automáticamente.


## PATRONES DE ESTILO

### 14. Rayas (—) y semirrayas (–): sacalas

**Regla:** la versión final no contiene rayas (—) ni semirrayas (–). La raya es uno de los tells más confiables de IA, así que tratalo como una restricción dura, no como un "usar con moderación". Reemplazá cada una, en orden de preferencia aproximado: un punto (arrancá una oración nueva), una coma (un inciso ajustado), dos puntos (para introducir una explicación), paréntesis (un inciso real), o reestructurá la oración. Atrapá también las rayas con espacios (` — `) y los dobles guiones (` -- `) usados igual.

**Antes:**
> El término lo promueven sobre todo instituciones neerlandesas—no la propia gente. Uno no dice "Países Bajos, Europa" como dirección—y sin embargo este error continúa—incluso en documentos oficiales.

**Después:**
> El término lo promueven sobre todo instituciones neerlandesas, no la propia gente. Uno no dice "Países Bajos, Europa" como dirección, y sin embargo este error continúa incluso en documentos oficiales.

**Antes:**
> La nueva política — anunciada sin aviso — afecta a miles de trabajadores. Los cambios -- largamente esperados según los críticos -- entrarán en vigor de inmediato.

**Después:**
> La nueva política, anunciada sin aviso, afecta a miles de trabajadores. Los cambios, largamente esperados según los críticos, entrarán en vigor de inmediato.

Antes de devolver la versión final, revisala buscando `—` y `–`. Cualquier aparición significa que el borrador no está listo.


### 15. Abuso de la negrita

**Problema:** los chatbots de IA resaltan frases en negrita de forma mecánica.

**Antes:**
> Combina **OKRs (Objetivos y Resultados Clave)**, **KPIs (Indicadores Clave de Desempeño)** y herramientas visuales de estrategia como el **Business Model Canvas (BMC)** y el **Balanced Scorecard (BSC)**.

**Después:**
> Combina OKRs, KPIs y herramientas visuales de estrategia como el Business Model Canvas y el Balanced Scorecard.


### 16. Listas verticales con encabezado en línea

**Problema:** la IA genera listas donde cada ítem arranca con un encabezado en negrita seguido de dos puntos.

**Antes:**
> - **Experiencia de usuario:** la experiencia de usuario mejoró significativamente con una nueva interfaz.
> - **Rendimiento:** el rendimiento se optimizó mediante algoritmos mejorados.
> - **Seguridad:** la seguridad se reforzó con cifrado de extremo a extremo.

**Después:**
> La actualización mejora la interfaz, acelera los tiempos de carga con algoritmos optimizados y suma cifrado de extremo a extremo.


### 17. Mayúscula inicial en cada palabra del título

**Problema:** los chatbots de IA escriben los títulos poniendo en mayúscula todas las palabras principales (algo importado del inglés). En español, en un título solo va con mayúscula la primera palabra y los nombres propios.

**Antes:**
> ## Negociaciones Estratégicas Y Alianzas Globales

**Después:**
> ## Negociaciones estratégicas y alianzas globales


### 18. Emojis

**Problema:** los chatbots de IA suelen decorar títulos o viñetas con emojis.

**Antes:**
> 🚀 **Fase de lanzamiento:** el producto se lanza en el Q3
> 💡 **Insight clave:** los usuarios prefieren la simplicidad
> ✅ **Próximos pasos:** agendar una reunión de seguimiento

**Después:**
> El producto se lanza en el Q3. La investigación de usuarios mostró preferencia por la simplicidad. Próximo paso: agendar una reunión de seguimiento.


### 19. Comillas tipográficas (curvas)

**Problema:** ChatGPT usa comillas curvas (“...”) en lugar de comillas rectas ("..."). (En español también conviene revisar el uso de las comillas latinas «...» según el estilo del texto.)

**Antes:**
> Dijo que “el proyecto va bien encaminado” pero otros no estaban de acuerdo.

**Después:**
> Dijo que "el proyecto va bien encaminado" pero otros no estaban de acuerdo.


## PATRONES DE COMUNICACIÓN

### 20. Artefactos de conversación con el chatbot

**Frases a vigilar:** Espero que esto ayude, ¡Por supuesto!, ¡Claro!, ¡Tenés toda la razón!, ¿Te gustaría...?, ¿Querés que...?, ¿Querés que dé ejemplos?, ¿Sigo?, avisame, acá te dejo un...

**Problema:** texto pensado como correspondencia con el chatbot termina pegado como contenido.

**Antes:**
> Acá te dejo un resumen de la Revolución Francesa. ¡Espero que ayude! Avisame si querés que amplíe alguna sección.

**Después:**
> La Revolución Francesa comenzó en 1789, cuando la crisis financiera y la escasez de alimentos derivaron en un malestar generalizado.


### 21. Disclaimers de corte de conocimiento y relleno especulativo

**Frases a vigilar:** al día de [fecha], hasta mi última actualización, si bien los detalles específicos son limitados/escasos..., según la información disponible, no disponible públicamente, mantiene un perfil bajo, prefiere mantener su vida privada, prefiere estar fuera del foco, probablemente [creció/estudió/empezó], se cree que.

**Problema:** dos tells relacionados. (a) Los modelos más viejos dejan disclaimers de corte de conocimiento en el texto. (b) Cuando un modelo no encuentra una fuente, escribe un párrafo *sobre* no haberla encontrado y después inventa relleno plausible para tapar el hueco. Para una persona privada, la suposición casi siempre cae en las mismas frases hechas ("mantiene un perfil bajo", "prefiere mantener su vida privada"), nada de eso con fuente. Decí qué no se sabe, o cortá la oración; no disfraces una suposición como si fuera un hecho.

**Antes (disclaimer de corte):**
> Si bien los detalles específicos sobre la fundación de la empresa no están ampliamente documentados en las fuentes disponibles, parece que fue establecida en algún momento de los años noventa.

**Después:**
> La empresa se fundó en 1994, según sus documentos de registro.

**Antes (relleno especulativo):**
> No hay información pública sobre su primera etapa de vida, lo que sugiere que mantiene un perfil bajo y resguarda su vida privada. Probablemente creció en un hogar de clase media, lo que moldeó su posterior interés por la reforma educativa.

**Después:**
> Su primera etapa de vida no está documentada en las fuentes disponibles. (O directamente omitir la sección.)


### 22. Tono adulador/servil

**Problema:** lenguaje excesivamente positivo y complaciente.

**Antes:**
> ¡Excelente pregunta! Tenés toda la razón en que es un tema complejo. Es un punto buenísimo lo de los factores económicos.

**Después:**
> Los factores económicos que mencionás son relevantes acá.


## RELLENO Y CAUTELA EXCESIVA

### 23. Frases de relleno

**Antes → Después:**
- "Con el fin de alcanzar este objetivo" → "Para esto"
- "Debido al hecho de que llovía" → "Porque llovía"
- "En este momento del tiempo" → "Ahora"
- "En el caso de que necesites ayuda" → "Si necesitás ayuda"
- "El sistema tiene la capacidad de procesar" → "El sistema puede procesar"
- "Es importante notar que los datos muestran" → "Los datos muestran"


### 24. Cautela (hedging) excesiva

**Problema:** sobrecalificar las afirmaciones.

**Antes:**
> Podría potencialmente quizás argumentarse que la política tal vez tenga algún efecto sobre los resultados.

**Después:**
> La política puede afectar los resultados.


### 25. Conclusiones positivas genéricas

**Problema:** cierres vagos y optimistas.

**Antes:**
> El futuro se ve brillante para la empresa. Vienen tiempos emocionantes mientras continúa su camino hacia la excelencia. Esto representa un gran paso en la dirección correcta.

**Después:**
> La empresa planea abrir dos locales más el año que viene.

**Nota para testimonios, evaluaciones y recomendaciones:** el default de la IA es cerrar con un veredicto resumido y prolijo que vuelve a etiquetar a la persona ("eso es lo que lo hace tan bueno en lo suyo", "un verdadero aporte para el equipo"). Una recomendación humana genuina suele cerrar sobre la relación o sobre cómo se sintió el trabajo, no con una conclusión calificadora. Preferí "es realmente lindo trabajar con él" antes que "esto es lo que lo hace exitoso".

**Antes:**
> Esa forma de pensar y de trabajar es lo que lo hace tan bueno en lo suyo y un aporte real al equipo.

**Después:**
> Esa forma de pensar y de trabajar, sumada a las ganas de que los demás crezcan, hacen que sea muy agradable compartir el trabajo con él.


### 26. Abuso de pares de palabras con guion

**Términos a vigilar (en inglés):** third-party, cross-functional, client-facing, data-driven, decision-making, well-known, high-quality, real-time, long-term, end-to-end.

**Problema:** este es un tell sobre todo del inglés. La IA pone guion en estos compuestos de forma uniforme, incluso en posición de predicado (`the report is high-quality`). Los humanos lo hacen de forma inconsistente: típicamente solo cuando el compuesto es atributivo (`a high-quality report`) y muchas veces sacando el guion en otros casos (`the report is high quality`). Mantené el guion en posición atributiva; sacalo cuando el compuesto va después del sustantivo. En español este patrón casi no aparece (rara vez encadenamos palabras con guion), así que en textos en español suele ser irrelevante.

**Antes:**
> The cross-functional team delivered a high-quality, data-driven report. The team is cross-functional, the report is high-quality, and the methodology is data-driven.

**Después:**
> The cross-functional team delivered a high-quality, data-driven report. The team is cross functional, the report is high quality, and the methodology is data driven.


### 27. Clichés de autoridad persuasiva

**Frases a vigilar:** la verdadera pregunta es, en el fondo, en realidad, lo que realmente importa, fundamentalmente, el problema más profundo, el meollo del asunto.

**Problema:** los LLM usan estas frases para fingir que están cortando el ruido para llegar a una verdad más profunda, cuando la oración que sigue normalmente solo reformula un punto común con más ceremonia.

**Antes:**
> La verdadera pregunta es si los equipos pueden adaptarse. En el fondo, lo que realmente importa es la preparación organizacional.

**Después:**
> La pregunta es si los equipos pueden adaptarse. Eso depende sobre todo de si la organización está dispuesta a cambiar sus hábitos.


### 28. Anuncios y señalización

**Frases a vigilar:** vamos a sumergirnos, exploremos, desglosemos esto, esto es lo que necesitás saber, ahora veamos, sin más preámbulos.

**Problema:** los LLM anuncian lo que están por hacer en vez de hacerlo. Este metacomentario frena la escritura y le da un tono de guion de tutorial.

**Antes:**
> Vamos a sumergirnos en cómo funciona el caché en Next.js. Esto es lo que necesitás saber.

**Después:**
> Next.js cachea datos en varias capas, incluyendo la memorización de requests, el caché de datos y el caché del router.


### 29. Encabezados fragmentados

**Señales a vigilar:** un título seguido de un párrafo de una línea que simplemente repite el título antes de que arranque el contenido real.

**Problema:** los LLM suelen agregar una oración genérica después de un título, como calentamiento retórico. Casi siempre no aporta nada y deja la prosa relleno.

**Antes:**
> ## Rendimiento
>
> La velocidad importa.
>
> Cuando los usuarios caen en una página lenta, se van.

**Después:**
> ## Rendimiento
>
> Cuando los usuarios caen en una página lenta, se van.


### 30. Escritura anclada al diff

**Problema:** documentación o comentarios escritos como si narraran un cambio en vez de describir la cosa como es. Salvo que el documento sea inherentemente versionado (changelogs, notas de versión, guías de migración), debería leerse de forma coherente sin saber qué cambió en el último commit.

**Antes:**
> Esta función se agregó para reemplazar el enfoque anterior de iterar por todos los ítems, que causaba un rendimiento O(n²).

**Después:**
> Esta función usa un hash map para búsquedas O(1), evitando el costo O(n²) de la iteración ingenua.


### 31. Remates fabricados y drama en staccato

**Problema:** los LLM suelen hacer que cada oración aterrice como un cierre citable, y después apilan fragmentos declarativos cortos para fabricar drama. Una sola oración corta para enfatizar está bien; una seguidilla de ellas empieza a sonar manufacturada.

**Antes:**
> Entonces llegó AlphaEvolve. No tenía preferencia por la simetría. Ningún prejuicio estético. Ninguna nostalgia por el gusto humano. Las viejas reglas se habían ido.

**Después:**
> AlphaEvolve cambió la búsqueda porque no favorecía la simetría ni los diseños de apariencia humana. Eso dejó menos útiles algunas de las viejas suposiciones.


### 32. Fórmulas de aforismo

**Patrones a vigilar:** X es el Y de Z, X se vuelve una trampa, X no es una herramienta sino un espejo, el lenguaje de, la moneda de, la arquitectura de.

**Problema:** los LLM convierten afirmaciones comunes en aforismos reutilizables que suenan profundos sin agregar precisión. Reemplazá la fórmula por la afirmación concreta a la que apunta.

**Antes:**
> La simetría es el lenguaje de la confianza. La eficiencia se vuelve una trampa cuando los equipos olvidan la capa humana.

**Después:**
> Los diseños simétricos suelen sentirse más predecibles para los usuarios. Los equipos pueden sobreoptimizar los flujos de trabajo y perder de vista cómo la gente los usa de verdad.


### 33. Arranques retóricos conversacionales

**Frases a vigilar:** ¿La verdad?, Mirá, La cosa es así, El tema es, Seamos honestos, Te soy sincero, cuando se usan como ganchos sueltos o pausas de falsa franqueza antes de un punto común.

**Problema:** los LLM abren con un gancho de falsa franqueza para fabricar intimidad antes de soltar una afirmación de rutina. El tell es la pausa teatral con revelación: una pregunta o un inciso de una palabra, y después la respuesta "real". Una persona que está siendo honesta normalmente dice la cosa y ya.

**Antes:**
> ¿Vale la pena el precio? ¿La verdad? Depende de cuánto lo vayas a usar.

**Después:**
> Que valga la pena el precio depende de cuánto lo vayas a usar.


## GUÍA DE DETECCIÓN

### Qué NO marcar (falsos positivos)

Una persona que escribe bien puede caer en varios de los patrones de arriba sin nada de IA de por medio. Antes de reescribir, chequeá que no estés destripando prosa legítima. Lo siguiente *no* es un indicador confiable por sí solo:

- **Gramática perfecta y estilo consistente.** Muchos escritores son profesionales o pasaron por edición. El pulido no equivale a IA.
- **Mezcla de registros casual y formal.** Suele señalar a alguien de un campo técnico, a un escritor joven o a alguien con hábitos de prosa neurodivergentes, no a un chatbot.
- **Prosa "sosa" o "robótica".** La prosa de IA tiene tells *específicos*. La sequedad genérica sin esos tells es simplemente escritura seca.
- **Vocabulario formal o académico.** La IA abusa de palabras rimbombantes *específicas* (ver §7), no de todas. No aplanes "ostensiblemente" o "constituyente" solo porque suenan cultas.
- **Apertura o cierre tipo carta en un comentario.** Los saludos y las despedidas son muy anteriores a ChatGPT.
- **Conectores comunes en forma aislada.** "Además", "asimismo", "en consecuencia" son indicio de IA solo cuando se amontonan. Un "sin embargo" no es un tell.
- **Comillas curvas solas.** macOS, Word, Google Docs y la mayoría de los CMS las curvan por defecto. Solo cuentan cuando se suman a otros tells.
- **Rayas (—) solas.** Muchos editores y periodistas las usan seguido. La raya es evidencia solo cuando va con un ritmo formulaico y vendedor.
- **Una sola oración corta enfática.** Los humanos usan oraciones recortadas para rematar una idea. Marcá el drama en staccato solo cuando aparecen varios fragmentos cortos seguidos e inflan el tono.
- **"La verdad" o "mirá" en medio de la oración.** Son normales en escritura casual. El tell es el arranque teatral suelto, no la palabra en sí.
- **Afirmaciones sin fuente.** Casi toda la web está sin citar. La falta de fuentes no prueba nada.
- **Formato correcto y complejo.** Los editores visuales y las plantillas producen salidas prolijas sin nada de IA.

Ante la duda, buscá **racimos** de tells, no señales aisladas. Una sola raya no significa nada; raya más regla de tres más "tapiz vibrante" más una sección de "Conclusión" es una confesión.


### Señales de escritura humana (preservalas)

Cuando veas esto, inclinate a dejar la prosa tranquila: son evidencia de una persona real escribiendo, y editar de más va a destruir lo que hace que el texto suene humano:

- **Detalle específico, raro y difícil de inventar.** Una dirección real. Una cita extraña. La frase "el abogado que laburaba arriba del consultorio de mi dentista". Los LLM redondean los detalles; los humanos los atesoran. Al humanizar, esto también sirve de forma generativa: si el borrador hace una afirmación de impacto vaga ("mejoró cómo medimos la precisión"), marcala y pedile al autor el mecanismo y el resultado concretos ("armó un sistema para medir la precisión del forecast, lo que mejoró los outputs del proceso"). No inventes el detalle, pero dejale la puerta abierta.
- **Sentimientos encontrados y tensión sin resolver.** "Creo que está bastante bien, pero me hace ruido y no termino de explicar por qué." Los LLM van por defecto a tomas limpias.
- **Referencias de época, atadas a un momento.** Jerga, memes o chistes internos que mapean a un año y a una subcultura específicos. Los modelos vienen atrasados un año o más.
- **Decisiones editoriales en primera persona que el autor puede defender.** Si el escritor puede explicar *por qué* hizo un corte o usó una palabra, es una señal humana fuerte.
- **Variedad en el largo de las oraciones.** La escritura real alterna corto y largo. La de IA tiende a una cadencia pareja, de largo medio.
- **Incisos, paréntesis o autocorrecciones genuinas.** "(Me sigo queriendo poner 'casi' acá, pero la verdad era seguro.)" Los modelos rara vez se interrumpen así.
- **Ediciones hechas antes del 30 de noviembre de 2022.** El lanzamiento público de ChatGPT. Cualquier cosa más vieja, salvo rarísimas excepciones, no está escrita por IA.


---

## Proceso y salida

1. Leé el texto de entrada con atención e identificá cada aparición de los patrones de arriba.
2. Escribí un **borrador de reescritura**. Chequeá que se lea natural en voz alta, que varíe el largo de las oraciones, que prefiera detalles concretos y construcciones simples (es/está/tiene) y que mantenga el registro adecuado.
3. Preguntate: **"¿Qué hace que lo de abajo sea tan obviamente generado por IA?"** Respondé en breve con los tells que queden.
4. Revisá hasta una **versión final** que los resuelva y que no contenga ninguna raya (—) ni semirraya (–) (ver §14).

Entregá el borrador, las viñetas breves de "todavía suena a IA", la versión final y (opcionalmente) un resumen corto de los cambios.


## Ejemplo completo

**Antes (con sonido a IA):**
> ¡Excelente pregunta! Acá te dejo un ensayo sobre el tema. ¡Espero que ayude!
>
> La programación asistida por IA es un testimonio perdurable del potencial transformador de los grandes modelos de lenguaje, marcando un momento crucial en la evolución del desarrollo de software. En el panorama tecnológico actual, en rápida evolución, estas herramientas revolucionarias—enclavadas en la intersección entre investigación y práctica—están reconfigurando cómo los ingenieros idean, iteran y entregan, subrayando su rol vital en los flujos de trabajo modernos.
>
> En el fondo, la propuesta de valor es clara: agilizar procesos, potenciar la colaboración y fomentar la alineación. No se trata solo del autocompletado; se trata de desbloquear la creatividad a escala, asegurando que las organizaciones puedan mantenerse ágiles mientras entregan experiencias fluidas, intuitivas y potentes a los usuarios. La herramienta funciona como un catalizador. El asistente funciona como un socio. El sistema se erige como una base para la innovación.
>
> Observadores del sector han notado que la adopción se aceleró desde experimentos de hobbistas hasta despliegues a nivel empresa, desde desarrolladores solitarios hasta equipos multifuncionales. La tecnología fue destacada en The New York Times, Wired y The Verge. Adicionalmente, la capacidad de generar documentación, tests y refactors muestra cómo la IA puede contribuir a mejores resultados, resaltando la intrincada interacción entre la automatización y el juicio humano.
>
> - 💡 **Velocidad:** la generación de código es significativamente más rápida, reduciendo la fricción y empoderando a los desarrolladores.
> - 🚀 **Calidad:** la calidad de salida se potenció mediante un mejor entrenamiento, contribuyendo a estándares más altos.
> - ✅ **Adopción:** el uso sigue creciendo, reflejando tendencias más amplias del sector.
>
> Si bien los detalles específicos son limitados según la información disponible, podría argumentarse que estas herramientas tal vez tengan algún efecto positivo. A pesar de los desafíos típicos de las tecnologías emergentes—incluyendo alucinaciones, sesgo y rendición de cuentas—el ecosistema sigue prosperando. Con el fin de realizar plenamente este potencial, los equipos deben alinearse con las mejores prácticas.
>
> En conclusión, el futuro se ve brillante. Vienen tiempos emocionantes mientras seguimos este camino hacia la excelencia. ¡Avisame si querés que amplíe alguna sección!

**Borrador de reescritura:**
> Los asistentes de código con IA aceleran algunas tareas. En un estudio de Google de 2024, los desarrolladores que usaron Codex completaron funciones simples un 55% más rápido que un grupo de control, pero no mostraron mejora en el debugging ni en las decisiones de arquitectura.
>
> Las herramientas son buenas para el código repetitivo: archivos de configuración, scaffolding de tests, refactors repetitivos. Son malas para darse cuenta cuándo se equivocan. Acepté en masa sugerencias que compilaban, pasaban el lint y aun así hacían lo incorrecto, porque dejé de prestar atención.
>
> La gente con la que hablo suele caer en dos campos. Algunos lo usan como autocompletado para tareas aburridas y revisan cada línea. Otros lo desactivan después de que les sigue sugiriendo patrones que no quieren. Ambas posturas me parecen razonables.
>
> Las métricas de productividad son resbaladizas. GitHub puede decir que los usuarios de Copilot "aceptan el 30% de las sugerencias", pero aceptar no es lo mismo que acertar, y acertar no es lo mismo que aportar valor. El estudio de Uplevel de 2024 no encontró diferencia estadísticamente significativa en el throughput de pull requests entre equipos con y sin asistentes de IA.
>
> Nada de esto significa que las herramientas sean inútiles. Significa que son herramientas. No reemplazan el criterio y no eliminan la necesidad de tener tests. Si no tenés tests, no podés saber si la sugerencia está bien.

**¿Qué hace que lo de abajo sea tan obviamente generado por IA?**
- El ritmo todavía está un poco demasiado prolijo (contrastes limpios, párrafos de cadencia pareja).
- Las personas nombradas y las citas de estudios pueden leerse como placeholders plausibles pero inventados, salvo que sean reales y con fuente.
- El cierre tira un poco a eslogan ("Si no tenés tests...") en vez de sonar como una persona hablando.

**Ahora hacelo que no sea obviamente generado por IA.**
> Los asistentes de código con IA te pueden hacer más rápido en las partes aburridas. No en todo. Definitivamente no en arquitectura.
>
> Son buenísimos para el código repetitivo: configs, scaffolding de tests, refactors repetitivos. También son buenísimos para sonar correctos mientras están equivocados. Acepté sugerencias que compilaban, pasaban el lint y aun así erraban el punto, porque dejé de prestar atención.
>
> La gente con la que hablo cae en dos campos. Algunos lo usan como autocompletado para los mandados y revisan cada línea. Otros lo desactivan después de que les insiste con patrones que no quieren. Las dos posturas se entienden.
>
> Las métricas de productividad son resbaladizas. GitHub puede decir que los usuarios de Copilot "aceptan el 30% de las sugerencias", pero aceptar no es acertar, y acertar no es aportar valor. Si no tenés tests, básicamente estás adivinando.

**Cambios hechos:** se sacó el marco de chatbot, la inflación de importancia, el relleno promocional y de gerundios, la regla de tres y el ciclado de sinónimos, los rangos falsos, el rodeo de la cópula, las rayas/emojis/negritas/comillas curvas, la sección formulaica de "desafíos", los disclaimers de corte y de cautela, el relleno y el marco persuasivo, y la conclusión optimista genérica; después se reconstruyó la voz con ritmo variado y detalle concreto.


## Referencia

Este skill se basa en [Wikipedia:Signs of AI writing](https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing), mantenida por WikiProject AI Cleanup. Los patrones documentados ahí provienen de la observación de miles de casos de texto generado por IA en Wikipedia.

Idea clave de Wikipedia: "Los LLM usan algoritmos estadísticos para adivinar qué debería venir después. El resultado tiende hacia el resultado estadísticamente más probable que aplica a la mayor variedad de casos."
