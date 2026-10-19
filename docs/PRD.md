# Biblioteca Lectora: PRD v1.1

> **Estado:** borrador para revisión · **Versión:** 1.1 · **Fecha:** 19 oct 2026 · **Alcance:** uso personal (single-user, self-hosted), diseñado para poder abrirse al público después.
> **Cambios en v1.1:** el bot de Telegram queda **diferido** (se diseña después); se agrega la **lectura guiada** (§5.12); se confirman los idiomas (español + inglés) y el tamaño de la biblioteca (1,000–2,000 libros); se agrega el dimensionamiento del servidor (D11).
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
3. Que un libro agregado a Calibre (o subido desde la app) esté listo para leer en todos tus dispositivos en menos de 2 minutos, sin pasos manuales.
4. **Insights útiles y sin spoilers** a partir de tus subrayados, generados en local.
5. Que **todo lo tuyo sea exportable** (Markdown, JSON, Readwise), sin límites.

**No-objetivos (v1)**
- Tienda de libros, DRM, red social o multiusuario.
- Reemplazar la interfaz de Calibre para tareas masivas: Calibre sigue siendo la herramienta de administración.
- Android y Windows nativos (la web los cubre de forma básica).
- **Bot de Telegram** (diferido: se diseña en una fase posterior; la arquitectura deja el hueco listo, ver D3).
- Escribir un motor de render propio.

## 3. Usuario y casos de uso

**Persona principal: tú.** Lector intenso, técnico, con iPhone Pro y pronto iPhone Duo, Mac, servidor propio y bot de Telegram. Lee en **español y en inglés**. Biblioteca de **1,000–2,000 libros**.

| # | Historia | Prioridad |
|---|---|---|
| U1 | Agrego un libro a Calibre (o lo arrastro a la app en el Mac) y aparece en todos mis dispositivos; lo descargo y lo leo sin conexión. | P0 |
| U2 | Leo en el iPhone, lo despliego (Duo) y aparecen dos páginas enfrentadas en la misma frase. | P0 |
| U3 | Subrayo con un gesto; aparece en el Mac, en la web y en Readwise con un enlace que vuelve al pasaje. | P0 |
| U4 | Toco "Explícame" sobre un subrayado y recibo una respuesta local en menos de 2 s. | P1 |
| U5 | Retomo una novela tras 2 semanas y leo "lo que va hasta aquí" sin spoilers. | P1 |
| U6 | Los domingos, la app me muestra un digest: subrayados destacados, una conexión entre libros, una pregunta. | P1 |
| U11 | Activo la lectura guiada: un marcador avanza por el texto a mi ritmo y me ayuda a leer más rápido y concentrado, sin perder el contexto de la página. | P1 |
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

**D3. Cola de trabajos en el servidor (bot diferido).** Importar, enriquecer metadatos, OCR, indexar para la IA y notificar son trabajos de una cola (`import → enrich → index → notify`). Cuando se diseñe el bot de Telegram, será **otro cliente** que dispara los mismos trabajos. Nota para entonces: archivos de más de 20 MB requieren el **servidor local de la Bot API** *[02 §Telegram]*.

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

**D11. Dimensionamiento del servidor (1,000–2,000 libros)**

"Servidor" = **una computadora que está siempre prendida** y guarda tus libros. Ahí corren Calibre, la API de la app, la base de datos de subrayados y progreso, y el modelo de IA local. Tus dispositivos se conectan a ella desde casa o desde fuera (con Tailscale, sin abrir puertos). No tiene que ser un equipo de centro de datos.

| Recurso | Estimación para 2,000 libros | Comentario |
|---|---|---|
| Archivos | EPUB: ~2–8 GB · PDF y cómics: +10–100 GB según cuántos sean | Un disco de 256–512 GB alcanza; el respaldo va a Google Drive |
| Catálogo y sync (Postgres) | < 1 GB | Trivial; Calibre y Postgres manejan cientos de miles de libros |
| Índice de IA (embeddings) | ~250 fragmentos por libro → ~500k fragmentos → ~1–2 GB con `halfvec` | Se indexa **cuando empiezas a leer un libro**, no toda la biblioteca de golpe |
| Modelo local | Qwen3 14B cuantizado: ~10 GB de RAM · 30B-A3B: ~20 GB | Esto es lo único que pide hardware "serio" |

**Conclusión: 2,000 libros es una biblioteca pequeña para el servidor.** Lo que define el hardware es la IA, no los libros.

| Opción | Pros | Contras | Veredicto |
|---|---|---|---|
| **Mac mini (M4 / M4 Pro, 24–48 GB) en casa** | Silencioso, consume poco, muy bueno con modelos locales (memoria unificada) | Inversión inicial | ✅ **Recomendado** |
| Tu Mac de uso diario | Gratis para empezar | Tiene que estar prendido; no sirve si es laptop | Bien para los spikes y la Fase 1 |
| NAS (Synology, etc.) | Ideal para archivos y Calibre | Muy lento para un LLM | Solo si la IA vive en otro lado |
| VPS en la nube (p. ej. Hetzner) | Siempre disponible, barato | Sin GPU (LLM lento o caro); tus libros en manos de un tercero | No para este proyecto |

La IA en el dispositivo (Foundation Models en tu iPhone Pro) funciona aunque el servidor esté apagado; lo que depende del servidor son los resúmenes, el chat y las conexiones entre libros.

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

### 5.7 Importar libros
| Función | P |
|---|---|
| Detectar libros nuevos en Calibre y avisar con un push "listo para leer" | P0 |
| Subir libros desde la app (arrastrar al Mac, menú Compartir en iOS) → Calibre | P1 |
| **Bot de Telegram** (`/libro X`, `/progreso`, `/digest`…) | **Diferido**: se diseña después, como cliente de la cola de trabajos (D3) |

### 5.8 IA e insights *[05 §5]*
| Función | Nivel | P |
|---|---|---|
| Definir, explicar o traducir una selección | Dispositivo | P1 |
| Etiquetado automático con tu vocabulario; pregunta de reflexión; flashcard | Dispositivo | P1 |
| **"Esto conecta con…"**: subrayados relacionados de otros libros | Servidor | P1 |
| Resumen al terminar cada capítulo; **"lo que va hasta aquí"** al retomar | Servidor | P1 |
| Personajes y conceptos hasta aquí (X-Ray sin spoilers) | Servidor | P1 |
| "Tus ideas clave" al terminar un libro (a partir de tus subrayados) | Servidor | P1 |
| **Digest semanal** en la app (notificación + pantalla), con botones que alimentan el repaso; por Telegram cuando exista el bot | Servidor | P1 |
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


### 5.12 Lectura guiada (modo de lectura rápida) — nuevo
Objetivo: **leer más rápido y con más foco sin perder comprensión.** La evidencia científica (Rayner et al., 2016) indica que los métodos de "lectura veloz" que eliminan el contexto (palabra por palabra) o las relecturas bajan la comprensión por encima de ~400–500 ppm. Por eso el modo por defecto **guía dentro de la página** en vez de quitar el texto.

| Modo | Cómo funciona | Para qué | P |
|---|---|---|---|
| **Marcador guiado** (por defecto) | Una banda suave resalta la línea actual y avanza a tu velocidad (ppm); el resto se atenúa un poco; la página pasa sola | Foco y ritmo constante, conservando el contexto y la posibilidad de volver atrás | P1 |
| **Foco por frase** | Resalta grupos de 3–5 palabras (unidades de sentido) que avanzan por la línea | Entrenar a leer por bloques en lugar de palabra por palabra | P1 |
| **Lectura con voz** | TTS a 1.2–2× con resaltado sincronizado de la frase | Leer y escuchar a la vez (*immersion reading*); muy bueno para no ficción | P1 (con §5.9) |
| **RSVP** (estilo Spritz) | Una palabra a la vez en el centro, con la letra de enfoque (ORP) en color | Textos cortos, la pantalla exterior del Duo, momentos de "solo 5 minutos" | P2, con aviso de comprensión |
| **Pre-lectura con IA** | Antes del capítulo: esquema de 5 puntos y conceptos clave (solo no ficción; nunca en novela) | Saber qué buscar, lo que acelera la lectura real | P2 |

**Comportamiento común**
- Velocidad de 150 a 700 ppm, con **arranque gradual** y **ritmo adaptativo**: más lento en palabras largas, números, nombres propios y signos de puntuación; pausa breve al cambiar de párrafo.
- **Bilingüe:** segmentación de palabras y sílabas con `NLTokenizer` / `Intl.Segmenter`, con velocidades separadas para español y para inglés (se lee distinto en cada idioma).
- Toque = pausa. Deslizar hacia atrás = volver a la frase anterior (**las relecturas están permitidas**, son parte de entender).
- Mantener presionado = pausa y selecciona, para **subrayar sin salir del modo**.
- **Estadísticas:** ppm real por libro y por idioma, tiempo en modo guiado y tendencia semanal. Opcional: 2 preguntas de comprensión con IA al final del capítulo para comprobar que la velocidad no está costando entender.
- **iPhone Duo:** en pose mesa, lectura guiada manos libres arriba y control de velocidad abajo.
- **Accesibilidad:** respeta Reduce Motion (la banda salta en vez de deslizarse) y es compatible con VoiceOver.
- **Implementación:** foliate-js expone el texto y los rangos de la página. Las líneas se calculan con `Range.getClientRects()` dentro del WebView y la banda se anima con CSS a 120 Hz. RSVP es una vista nativa SwiftUI alimentada con el texto del capítulo por el puente JS. En PDF, el marcador funciona en la vista reflow.
- **Referentes:** Readest (RSVP, modo párrafo, regla de lectura), Spritz, Outread y la técnica clásica del "pacer" (seguir la línea con el dedo).

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
- **Fricción:** de agregar un libro a Calibre a empezar a leerlo en el iPhone, menos de 2 minutos (p50).

## 8. Plan por fases y criterios de salida

**Fase 0: Spikes técnicos (2 semanas, en paralelo)**
- S1: foliate-js en WKWebView dentro de SwiftUI: paginación, **gestos interrumpibles nativos**, selección con menú nativo, CFI, guiones en español, VoiceOver y un libro de 1,000 páginas. *Criterio de salida:* se siente como Apple Books en un test a ciegas contigo.
- S2: PDFKit con un PDF de 500 páginas y 300 subrayados en una capa propia. *Plan B:* PDFium compilado para Apple.
- S3: adaptador de Calibre: lectura SQLite en solo lectura más `/cdb/add-book` contra un `calibre-server` 9.16 en Docker.
- S4: lectura guiada (§5.12) sobre foliate-js: marcador por línea a 300 ppm en un libro en español, fluido a 120 Hz.

**Fase 1: Fundación del servidor (3–4 semanas)**
- Migrar la biblioteca a disco local con respaldo a Drive.
- API v1 (catálogo, archivos, progreso, anotaciones) y cola de trabajos.
- Push vía APNs.

**Fase 2: MVP de lectura en iPhone + Duo (6–8 semanas)**
- Todos los P0 de §5.1, §5.2, §5.3, §5.5, §5.6, §5.7, §5.10 y §5.11, más la lectura guiada básica (§5.12).
- *Salida:* dejas de usar Apple Books y Kindle para EPUB y PDF.

**Fase 3: iPad + Mac + cómics (4–6 semanas)**
- Los P1 de §5.2 y §5.4, más los extras de Mac.

**Fase 4: Capa de conocimiento (4–6 semanas)**
- Ingesta RAG, P1 de §5.8 y digest en la app.

**Fase 5: Web compañera + P2 + bot de Telegram.** **Fase 6 (opcional):** versión pública con los módulos de D10.

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
1. **¿Dónde corre hoy Calibre?** ¿En tu Mac, en otra computadora o en un servidor? (Ver D11 para elegir el servidor.)
2. **Hardware disponible:** si es un Mac, ¿qué chip y cuánta RAM? Esto decide el tamaño del modelo local.
3. **Composición de la biblioteca:** de los 1,000–2,000, ¿cuántos son PDF y cómics?
4. **¿Usas la Daily Review de Readwise hoy?** Define si el repaso espaciado (FSRS) en la app es P2 o se omite.
5. **Audiolibros:** ¿tienes y te interesan, para Storyteller y Audiobookshelf?
6. **Nombre del producto:** "Biblioteca Lectora" es provisional.
7. ~~Bot de Telegram~~ (diferido) · ~~Idiomas~~ (español + inglés).

---
**Fuente de lectura guiada:** [Rayner et al. 2016, *So Much to Read, So Little Time* (APS)](https://www.psychologicalscience.org/publications/speed_reading.html)

**Investigaciones de soporte:** [01 Calibre](investigacion/01-calibre.md) · [02 Servidores de biblioteca](investigacion/02-servidores-biblioteca.md) · [03 Lectores](investigacion/03-lectores.md) · [04 PDF y cómics](investigacion/04-pdf-y-comics.md) · [05 IA e insights](investigacion/05-ia-e-insights.md)
