# Biblioteca Lectora: PRD v1.0

> **Estado:** borrador para revisión · **Fecha:** 19 oct 2026 · **Alcance:** uso personal (single-user, self-hosted), diseñado para poder abrirse al público después.
> **Base:** [`vision-producto.md`](vision-producto.md) y las 5 investigaciones en [`investigacion/`](investigacion/). Cada decisión cita su fuente (p. ej. *[01 §3]* = `01-calibre.md`, sección 3).

---

## 1. Problema y oportunidad

Hoy, leer "en serio" con una biblioteca propia obliga a usar varias herramientas separadas:
- **Calibre** cataloga, pero lee mal, no tiene app móvil buena y el manual advierte que **en Google Drive pierde datos** *[01 §9]*.
- **Kindle / Apple Books** leen bien, pero encierran tus libros y tus subrayados. Kindle además **limita el export** *[03 §4]*.
- **Readwise** convierte subrayados en conocimiento, pero no gestiona libros.
- La **IA de lectura** ya es común (Kindle *Ask this Book*, Gemini con citas), pero siempre **en la nube del vendedor y solo con libros comprados ahí** *[03 §0, 05 §1]*.
- **Readest**, el competidor más cercano, ya se conecta a Calibre/OPDS. Pero no tiene capa de conocimiento local, su selección de texto falla y no está pensado para un servidor propio con bot *[03 §1.6]*.

**Oportunidad:** ninguna herramienta une *conseguir → leer → subrayar → pensar → recordar* sobre **tu servidor, tu Calibre y un modelo local**, con una app nativa de Apple a la altura de Apple Books y diseñada para el **iPhone Duo** desde el primer día.

## 2. Objetivos y no-objetivos

**Objetivos (v1, uso personal)**
1. Ser el **único lector** que uses en iPhone, iPhone Duo, iPad y Mac, y como respaldo en la web, para EPUB, PDF y cómics.
2. **Cero pérdida** de subrayados o progreso. La sincronización debe ser confiable entre dispositivos.
3. Que un libro pedido al **bot de Telegram** esté listo para leer en la app en menos de 2 minutos, sin pasos manuales.
4. **Insights útiles y sin spoilers** a partir de tus subrayados, generados en local.
5. Que **todo lo tuyo sea exportable** (Markdown, JSON, Readwise), sin límites.

**No-objetivos (v1)**
- Tienda de libros, DRM, red social o multiusuario.
- Reemplazar la interfaz de Calibre para tareas masivas: Calibre sigue siendo la herramienta de administración.
- Android y Windows nativos (la web los cubre de forma básica).
- Escribir un motor de render propio.

## 3. Usuario y casos de uso

**Persona principal: tú.** Lector intenso, técnico, con iPhone Pro y pronto iPhone Duo, Mac, servidor propio y bot de Telegram. Lee en español y en inglés (por confirmar).

| # | Historia | Prioridad |
|---|---|---|
| U1 | Pido un libro en Telegram y me llega un push "listo": lo abro y leo sin conexión. | P0 |
| U2 | Leo en el iPhone, lo despliego (Duo) y aparecen dos páginas enfrentadas en la misma frase. | P0 |
| U3 | Subrayo con un gesto; aparece en el Mac, en la web y en Readwise con un enlace que vuelve al pasaje. | P0 |
| U4 | Toco "Explícame" sobre un subrayado y recibo una respuesta local en menos de 2 s. | P1 |
| U5 | Retomo una novela tras 2 semanas y leo "lo que va hasta aquí" sin spoilers. | P1 |
| U6 | Los domingos, Telegram me manda un digest: subrayados destacados, una conexión entre libros, una pregunta. | P1 |
| U7 | Leo un PDF académico en el iPhone con reflow o recorte de márgenes y lo subrayo. | P1 |
| U8 | Leo un manga en el Duo desplegado: cada doble página impresa cae sobre la bisagra, de derecha a izquierda. | P1 |
| U9 | Le pregunto a mi biblioteca "¿dónde leí sobre X?" y obtengo citas clicables. | P2 |
| U10 | Paso de escuchar el audiolibro a leer en la misma frase. | P3 |

## 4. Decisiones de arquitectura

> Estas decisiones **actualizan** a `vision-producto.md` v0.2 donde no coinciden. Los cambios principales son D2 y D4.

**D1. Servidor propio (FastAPI + Postgres/pgvector) sobre Calibre.** No se adopta calibre-web/CWA, Kavita, Komga ni Grimmory como backend: tienen su propia base de datos (sería un segundo catálogo) o no ofrecen API *[02 §recomendación]*. De ellos se copian ideas, no código (GPL/AGPL) *[02, 01 §1]*.

**D2. Calibre: un único proceso dueño de la biblioteca** *[01 §2–4]*
- Un `calibre-server` sin interfaz gráfica, en disco local, escuchando solo en localhost y con un usuario de escritura. Calibre usa SQLite sin WAL y no detecta cambios hechos por otros procesos; además, `calibredb` local **no puede correr junto al server**.
- **Lectura:** SQLite en modo solo lectura, con transacciones cortas, sincronizando a Postgres de forma incremental por `last_modified`.
- **Escritura:** solo por los endpoints `/cdb/add-book` y `/cdb/set-fields`, o con `calibredb --with-library http://127.0.0.1:8080/#lib`. **Nunca escribir directo en `metadata.db`**: sus triggers usan funciones SQL que solo registra Calibre.
- **Identidad del libro:** `books.uuid` de Calibre más sha256 del archivo. La ruta en disco cambia cada vez que editas título o autor.
- **Archivos:** se sirven directo del disco con soporte de Range y ETag. No se usa `/get/epub`, porque reescribe los metadatos y cambia el hash del archivo.
- **Respaldo:** `sqlite3 .backup` a un snapshot, y de ahí `rclone copy` en una sola dirección hacia Google Drive. Se elimina la sincronización en vivo con Drive.
- Se fija la versión de Calibre (9.16.x) y se escriben tests de contrato del adaptador, porque esos endpoints son internos y sin versión.

**D3. Bot de Telegram = cliente del servidor.** La lógica del bot pasa a una cola de trabajos compartida (`fetch_book → import → enrich → notify`) que también usa la app. Para archivos de más de 20 MB (PDFs y cómics) se monta el **servidor local de la Bot API** de Telegram, que admite hasta 2000 MB *[02 §Telegram]*.

**D4. Motor de render por formato** (corrige v0.2: foliate-js deja de ser el motor universal) *[04, 03 §5]*

| Formato | Apple (iOS/iPadOS/macOS) | Web | Servidor |
|---|---|---|---|
| EPUB (reflow y fixed-layout), MOBI/AZW3/FB2 | foliate-js en `WKWebView`, fijado a un commit o fork, servido por `WKURLSchemeHandler` | foliate-js | Parser de CFI compartido (`epubcfi.js` en un worker de Node) para el RAG |
| PDF | **PDFKit** nativo, con subrayados en una capa propia (`PDFPageOverlayViewProvider`), sin escribir en el archivo | **pdf.js** | PDFium (`pypdfium2`): mapa de texto, miniaturas, recorte. OCRmyPDF para escaneados. Docling para generar una versión reflow que se lee en foliate-js |
| Cómics (CBZ/CBR/CB7/CBT, PDF-cómic) | **Lector nativo en Swift**, con páginas en streaming | Lector equivalente en TypeScript | Normaliza todo a CBZ, lee `ComicInfo.xml`, genera un manifiesto JSON de páginas, dobles páginas, sentido de lectura y viñetas, y expone OPDS-PSE. Nada de UnRAR en los clientes |

**D5. Shell 100 % nativo en SwiftUI** (un solo target multiplataforma; Mac nativo, no Catalyst). La UI que se ve al leer, los gestos de página, el menú de selección (`UIEditMenuInteraction`), el panel de insights y la biblioteca son nativos. WKWebView **solo renderiza**. El mayor riesgo de sensación "web" está en los gestos *[03 §2.3]*.

**D6. Modelo de anclas y anotaciones** *[01 §5, 02, 04, 05 §6]*
- Formato **W3C Web Annotation**. Cada anotación lleva un UUID estable, un log append-only, merge por elemento con "gana el más reciente" y un borrado marcado (tombstone).
- Cada ancla guarda varios selectores: **EPUB CFI** (de foliate-js) + **cita exacta con prefijo y sufijo** + `(spine_index, char_offset)`. En PDF: página + quads en coordenadas PDF + cita + posición en el mapa de texto del servidor. En cómics: página + región.
- El servidor **vuelve a anclar** el subrayado si cambian el archivo o el motor. Por ejemplo, los CFI de Calibre no coinciden con los de foliate-js.
- Progreso: Readium Locator + CFI + **la posición más lejana alcanzada**, que también marca el límite para evitar spoilers.

**D7. IA en dos niveles** *[05 §3–5]*
- **Dispositivo:** Apple Foundation Models, con contexto de unos 4K tokens. Sirve para definir, explicar, traducir, etiquetar, crear flashcards y hacer preguntas de reflexión.
- **Servidor:** Ollama con Qwen3 14B/30B-A3B o Gemma 4, embeddings Qwen3-Embedding-0.6B o bge-m3 (1024 dimensiones) y un reranker. Sirve para RAG, resúmenes, personajes, conexiones entre libros, chat y el digest. Hardware sugerido: Mac mini de 24–32 GB o una GPU de 12–16 GB.
- **Antispoiler:** filtro SQL `pos ≤ posición más lejana`, más una instrucción explícita al modelo, más validación de cada cita antes de convertirla en CFI.
- Si el protocolo `LanguageModel` de iOS 27 se confirma, permite poner Ollama detrás de la misma API de Swift ⚠️.

**D8. Readwise = destino de conocimiento** *[05 §2]*
- Se usa `POST /api/v2/highlights/` con un **`highlight_url` estable** (universal link al pasaje), lo que hace el envío idempotente y permite volver al libro desde Readwise.
- Se respeta un límite de 240 peticiones por minuto con backoff según `Retry-After`.
- `/export/` permite **importar** tus subrayados de Kindle y Apple Books a la capa de conocimiento.
- Detalles marcados ⚠️ en la investigación: verificarlos contra la documentación oficial.

**D9. Protocolos:** v1 = API REST propia (OpenAPI). v2 = OPDS 1.2 + PSE y el endpoint de sincronización de **KOReader** (kosync, requiere el hash MD5 parcial de cada archivo al importarlo), para que un e-reader con KOReader funcione como un cliente más. v3 = OPDS 2.0; la sincronización con Kobo queda como opcional *[02]*.

**D10. Módulos removibles para la versión pública:** `LibrarySource`, `Acquisition` (bot y descargas), `KnowledgeSink`, `AIProvider` y `Auth`, cada uno detrás de una interfaz y una *feature flag*. Los componentes AGPL (MuPDF, Kumiko) se quedan **solo en el servidor** *[04, 05 §7]*.

## 5. Catálogo de funcionalidades priorizado

**P0** = MVP (sin esto no reemplaza a Apple Books o Kindle) · **P1** = v1 completa (el diferenciador) · **P2** = después · **P3** = algún día.
Etiquetas: **[T]** básico que todos tienen · **[D]** diferenciador · **[M]** momento mágico. Referencias detalladas en *[03 §2]* y *[05 §5]*.

### 5.1 Lectura EPUB
| Función | P | Tipo |
|---|---|---|
| Paginado con slide **interrumpible** a 120 Hz + modo scroll | P0 | T |
| Tipografía: guiones en español e inglés (`hyphens:auto` + `lang`, Hyphenopoly como respaldo), justificación, márgenes exactos, ancho de línea máximo | P0 | T→D |
| 5–6 fuentes curadas (Literata, Charter, Iowan, Atkinson, OpenDyslexic) + importar las tuyas | P0 / P1 | T / D |
| Temas claro, sepia, oscuro y negro OLED; cambio automático con el sistema | P0 | T |
| Ajustes por libro y "respetar el estilo del editor" | P1 | D |
| TOC, scrubber con marcas de capítulo, historial "volver a pág. X" | P0 | T |
| **Notas al pie en popover** | P0 | M |
| "Te faltan N min de capítulo", según tu velocidad | P0 | M |
| Búsqueda en el libro (ignora acentos, muestra resultados progresivos) | P0 | T |
| Diccionario del sistema, traducción on-device (Translation framework), Wikipedia | P0 / P1 | T |
| Page curl opcional | P2 | D |
| Scroll continuo entre capítulos (encima de foliate-js) | P2 | D |
| Números de página estables (page-list del editor) | P2 | D |
| Lectura paralela: dos libros o dos ubicaciones a la vez en iPad y Duo | P2 | D |
| Encabezado y pie configurables, auto-page-turn, RSVP | P3 | N |

### 5.2 iPhone Duo y layouts adaptativos *[vision §5]*
| Función | P |
|---|---|
| Layout por size class (exterior compact, interior regular); nada de `UIScreen.main` | P0 |
| **Doble página automática al desplegar**, conservando la misma frase (CFI) | P0 |
| Pose libro: cada página alineada a la región `.division` de la bisagra | P1 |
| Pose mesa: texto arriba, controles y TTS abajo | P1 |
| Modo estudio con `ArrangementView(.split)`: libro | subrayados e insights | P1 |
| Cómic o manga: la doble página impresa sobre la bisagra; webtoon nunca se parte | P1 |
| Widget con la cita del día en la pantalla exterior | P2 |

### 5.3 PDF
| Función | P |
|---|---|
| PDFKit: zoom, selección y subrayado en una capa propia | P0 |
| Recorte automático de márgenes, modo columna | P1 |
| Versión reflow (Docling → EPUB derivado) con subrayados que se traducen al PDF original | P1 |
| OCR de escaneados en el servidor (OCRmyPDF) | P1 |
| Apple Pencil: tinta y notas en el margen; exportar a XFDF o anotaciones PDF estándar | P2 |

### 5.4 Cómics
| Función | P |
|---|---|
| CBZ, CBR, CB7 y CBT (normalizados en el servidor), páginas en streaming, miniaturas | P1 |
| Manga de derecha a izquierda (`ComicInfo Manga=YesAndRightToLeft`), dobles páginas, ajuste a ancho o alto | P1 |
| Webtoon con scroll vertical | P2 |
| **Guided View** viñeta a viñeta (Kumiko → YOLO/Magi) | P2 |
| Recorte como subrayado, con texto OCR o Magi que entra a los insights | P3 |

### 5.5 Subrayados, notas y export
| Función | P | Tipo |
|---|---|---|
| Subrayado instantáneo con un gesto, 4–5 colores, subrayado que cruza páginas | P0 | T |
| Notas y etiquetas; panel filtrable por color, capítulo y etiqueta | P0 | T |
| **Push a Readwise** con deep link de vuelta al pasaje | P0 | D |
| Export ilimitado a Markdown, JSON y CSV; "libro en una página" para Obsidian | P0 | M |
| Copiar con cita (autor, libro, ubicación) y deep link | P1 | D |
| Importar subrayados de Readwise, Kindle, Apple Books y KOReader | P1 | D |
| Quote cards como imagen para compartir | P2 | M |

### 5.6 Biblioteca y metadatos (sobre Calibre)
| Función | P |
|---|---|
| Biblioteca rápida con más de 5,000 libros: índice local en SwiftData, portadas en caché, paginación en el servidor | P0 |
| "Seguir leyendo" como inicio; estados (por leer, leyendo, terminado, abandonado) | P0 |
| Series con "siguiente de la serie", autores, etiquetas, estantes manuales y **estantes inteligentes** | P0 / P1 |
| Editar metadatos (escribe en Calibre vía `/cdb`) y descarga de metadatos y portadas en un trabajo (`fetch-ebook-metadata`, más Hardcover como fuente) | P1 |
| **Cola de revisión de importación** y detección de duplicados (idea de Grimmory/CWA) | P1 |
| Leer `ComicInfo.xml`, que Calibre no lee sin plugin | P1 |
| Descarga para leer sin conexión y gestión de almacenamiento | P0 |
| Búsqueda de texto completo en toda la biblioteca (Postgres FTS) | P1 |
| Send-to-Kindle por correo | P3 |

### 5.7 Adquisición (bot de Telegram) — módulo removible
| Función | P |
|---|---|
| `/libro X` → importar a Calibre → enriquecer → push "listo" a la app | P0 |
| "Conseguir" desde la app (el mismo trabajo) y estado de trabajos en la app | P1 |
| Servidor local de la Bot API (archivos de más de 20 MB) | P1 |
| Comandos del bot: `/progreso`, `/subrayados <libro>`, `/digest`, `/pregunta` | P1 / P2 |

### 5.8 IA e insights *[05 §5]*
| Función | Nivel | P |
|---|---|---|
| Definir, explicar o traducir una selección | Dispositivo | P1 |
| Etiquetado automático con tu vocabulario; pregunta de reflexión; flashcard | Dispositivo | P1 |
| **"Esto conecta con…"**: subrayados relacionados de otros libros | Servidor | P1 |
| Resumen al terminar cada capítulo; **"lo que va hasta aquí"** al retomar | Servidor | P1 |
| Personajes y conceptos hasta aquí (X-Ray sin spoilers) | Servidor | P1 |
| "Tus ideas clave" al terminar un libro (a partir de tus subrayados) | Servidor | P1 |
| **Digest semanal por Telegram** con botones que alimentan el repaso | Servidor | P1 |
| Repaso espaciado (FSRS) en la app, sin duplicar la Daily Review de Readwise | Dispositivo + servidor | P2 |
| **Chatea con tu biblioteca**, con citas clicables por ámbito | Servidor | P2 |
| Temas a lo largo del tiempo, contradicciones entre subrayados, mapa de argumentos | Servidor | P2 |
| Recomendaciones de tus libros sin leer | Servidor | P3 |

### 5.9 Audio y TTS
| Función | P |
|---|---|
| TTS con voces del sistema (Premium), resaltado, sleep timer, pantalla de bloqueo y segundo plano | P1 |
| EPUB 3 Media Overlays (read-along) | P2 |
| Storyteller + Audiobookshelf en el servidor: **pasar de escuchar a leer** en la misma frase | P3 |

### 5.10 Sync, estadísticas y plataforma
| Función | P |
|---|---|
| Sync de progreso, anotaciones y ajustes; offline con cola de cambios | P0 |
| **Conflictos visibles**: "estás más adelante en el iPad, ¿saltar?" | P0 |
| Estadísticas: tiempo diario, racha, velocidad, objetivo anual | P1 |
| Resumen anual de lectura | P2 |
| Sync con KOReader (kosync) y OPDS 1.2 + PSE | P2 |
| Sync con Hardcover o StoryGraph | P3 |
| Mac: menús, atajos, varias ventanas | P1 |
| App Intents y Siri ("¿qué subrayé ayer?"), Live Activity, widgets | P2 |

### 5.11 Accesibilidad (P0 de forma transversal)
VoiceOver con lectura continua dentro del WKWebView, Dynamic Type en la UI, Reduce Motion, alto contraste, fuentes para dislexia, teclado completo en Mac y zonas de toque configurables (incluido modo zurdo).

## 6. Requisitos no funcionales
| Área | Meta |
|---|---|
| Rendimiento | Abrir un libro ya descargado en menos de 700 ms; pasar página en menos de 16 ms de latencia percibida; biblioteca de 5,000 libros con scroll a 120 fps |
| Sync | Un cambio aparece en otro dispositivo en menos de 5 s en línea; **0 anotaciones perdidas** (tests de propiedades sobre el merge) |
| IA en el dispositivo | Primera respuesta en menos de 2 s |
| IA en el servidor | Resumen de capítulo en menos de 30 s en segundo plano; chat con primera respuesta en menos de 5 s |
| Privacidad | Ningún texto de libros sale de tus dispositivos o tu servidor (la IA en la nube está apagada por defecto). Acceso remoto vía Tailscale o Cloudflare Access |
| Fiabilidad | Respaldo diario verificado (restauración de prueba mensual); tests de contrato contra Calibre fijado |
| Portabilidad | Export completo en todo momento; formatos abiertos (W3C Annotation, Markdown) |

## 7. Métricas de éxito (personales)
- **Adopción:** más del 90 % del tiempo de lectura semanal ocurre en la app (frente a Kindle o Apple Books) a los 2 meses.
- **Confianza:** 0 incidencias de subrayados perdidos o progreso que retrocede.
- **Valor de la IA:** abres al menos el 30 % de los digests y vuelves a ver al menos el 20 % de los subrayados en 90 días.
- **Fricción:** pedir un libro en Telegram y empezar a leerlo toma menos de 2 minutos (p50).

## 8. Plan por fases y criterios de salida

**Fase 0: Spikes técnicos (2 semanas, en paralelo)**
- S1: foliate-js en WKWebView dentro de SwiftUI: paginación, **gestos interrumpibles nativos**, selección con menú nativo, CFI, guiones en español, VoiceOver y un libro de 1,000 páginas. *Criterio de salida:* se siente como Apple Books en un test a ciegas contigo.
- S2: PDFKit con un PDF de 500 páginas y 300 subrayados en una capa propia. *Plan B:* PDFium compilado para Apple.
- S3: adaptador de Calibre: lectura SQLite en solo lectura más `/cdb/add-book` contra un `calibre-server` 9.16 en Docker.
- S4: inventario del bot. *Pendiente tuyo:* lenguaje, dónde corre, cómo importa los libros.

**Fase 1: Fundación del servidor (3–4 semanas)**
- Migrar la biblioteca a disco local con respaldo a Drive.
- API v1 (catálogo, archivos, progreso, anotaciones), cola de trabajos y refactor del bot.
- Push vía APNs.

**Fase 2: MVP de lectura en iPhone + Duo (6–8 semanas)**
- Todos los P0 de §5.1, §5.2, §5.3, §5.5, §5.6, §5.7, §5.10 y §5.11.
- *Salida:* dejas de usar Apple Books y Kindle para EPUB y PDF.

**Fase 3: iPad + Mac + cómics (4–6 semanas)**
- Los P1 de §5.2 y §5.4, más los extras de Mac.

**Fase 4: Capa de conocimiento (4–6 semanas)**
- Ingesta RAG, P1 de §5.8 y digest por Telegram.

**Fase 5: Web compañera + P2.** **Fase 6 (opcional):** versión pública con los módulos de D10.

## 9. Riesgos principales
| Riesgo | Prob. | Impacto | Mitigación |
|---|---|---|---|
| Gestos y selección en WKWebView se sienten "web" | Media | Alto | Spike S1 primero; gestos nativos; parches de Readest como referencia |
| Limitaciones de foliate-js (API inestable, scroll entre capítulos, búsqueda lenta) | Alta | Medio | Fork fijado; scroll continuo en P2; búsqueda en el servidor |
| APIs internas de Calibre cambian | Media | Medio | Versión fijada + tests de contrato + adaptador aislado |
| APIs del iPhone Duo (iOS 27.1) nuevas o en beta | Media | Medio | Size classes primero; reserved regions y ArrangementView detrás de `#available` |
| Hardware del servidor insuficiente para el LLM | Desconocida | Medio | Modelos de 8–14B cuantizados; los resúmenes corren en segundo plano por la noche |
| Datos de Readwise o iOS 27 sin verificar (⚠️) | — | Bajo | Verificar antes de programar cada integración |
| Alcance enorme para un proyecto personal | Alta | Alto | Fases con criterios de salida; P2 y P3 no entran hasta usar la app a diario |

## 10. Preguntas abiertas
1. **Bot:** ¿lenguaje, dónde corre (VPS, casa, NAS) y cómo mete los libros a Calibre hoy?
2. **Hardware del servidor:** ¿CPU, RAM y GPU? Esto decide el tamaño del modelo.
3. **Idiomas de lectura:** ¿español, inglés o ambos? Afecta los guiones y el modelo.
4. **Tamaño de la biblioteca:** ¿cuántos libros, PDFs y cómics?
5. **¿Usas la Daily Review de Readwise hoy?** Define si el repaso espaciado (FSRS) en la app es P2 o se omite.
6. **Audiolibros:** ¿tienes y te interesan, para Storyteller y Audiobookshelf?
7. **Nombre del producto:** "Biblioteca Lectora" es provisional.

---
**Investigaciones de soporte:** [01 Calibre](investigacion/01-calibre.md) · [02 Servidores de biblioteca](investigacion/02-servidores-biblioteca.md) · [03 Lectores](investigacion/03-lectores.md) · [04 PDF y cómics](investigacion/04-pdf-y-comics.md) · [05 IA e insights](investigacion/05-ia-e-insights.md)
