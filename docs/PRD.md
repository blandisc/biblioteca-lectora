# Biblioteca Lectora: PRD v2.1

> **Estado:** borrador para revisión · **Versión:** 2.1 · **Fecha:** 19 oct 2026 · **Alcance:** uso personal, diseñado para poder abrirse al público después.
>
> **Cambios en v2.1:**
> - **Readwise Reader** entra como integración de primera clase: importar originales y artículos, subrayados en ambos sentidos y progreso de Reader a la app (§4.6, investigación [06](investigacion/06-readwise-reader.md)).
> - **IA:** ya no depende del Mac. Funciona en el iPhone y, de forma opcional, en la nube de Apple o con tu propia clave de Anthropic, OpenAI, xAI o Google (§4.5, investigación [07](investigacion/07-ia-dispositivo-y-nube.md)).
> - **Subrayados de Kindle** (vía Readwise) ligados a tus libros: pasa a P0/P1.
> - Sin columnas personalizadas ni plugins de Calibre.
>
> **Cambios en v2.0 (giro de arquitectura):**
> - **Sin servidor propio.** Todo corre en tus dispositivos y la nube es **iCloud (CloudKit)**. Google Drive y OneDrive quedan como fuentes para importar.
> - **La app reemplaza a Calibre** como herramienta de administración; Calibre solo se usa para **migrar** una vez.
> - **Readwise sincroniza subrayados en ambos sentidos** (enviar y traer).
> - El bot de Telegram sigue **diferido**.
> - Las decisiones D1–D11 de la v1.1 quedan reemplazadas por las de §4. Las investigaciones en [`investigacion/`](investigacion/) siguen vigentes como referencia; donde hablan de "servidor", aplica la traducción de §4.9.

---

## 1. Problema y oportunidad

Hoy, leer "en serio" con una biblioteca propia obliga a usar varias herramientas separadas:
- **Calibre** cataloga, pero lee mal, no tiene app móvil, su interfaz es densa y el manual advierte que **en Google Drive pierde datos** *[01 §9]*.
- **Kindle / Apple Books** leen bien, pero encierran tus libros y tus subrayados. Kindle además **limita el export** *[03 §4]*.
- **Readwise** convierte subrayados en conocimiento, pero no gestiona libros.
- La **IA de lectura** ya es común (Kindle *Ask this Book*, Gemini), pero **en la nube del vendedor** *[03 §0, 05 §1]*.
- **Readest**, el competidor más cercano, depende de Calibre/OPDS o de su propia nube y no tiene capa de conocimiento local *[03 §1.6]*.

**Oportunidad:** una app nativa de Apple que **es** tu biblioteca (reemplaza a Calibre) y tu lector (a la altura de Apple Books), sincronizada por **tu iCloud**, sin servidor que mantener, con **IA en tus dispositivos** y Readwise como memoria a largo plazo. Diseñada para el **iPhone Duo** desde el día uno.

## 2. Objetivos y no-objetivos

**Objetivos (v1)**
1. Ser el **único lector y gestor de libros** en iPhone, iPhone Duo, iPad y Mac (y la web como respaldo) para EPUB, PDF y cómics.
2. **Cero infraestructura propia:** nada que encender, actualizar ni respaldar a mano.
3. **Cero pérdida** de subrayados, progreso o metadatos entre dispositivos.
4. **Migrar tu biblioteca de Calibre** (1,000–2,000 libros) con metadatos, portadas, series, etiquetas y anotaciones en una sola importación.
5. **Insights útiles y sin spoilers** generados en tus dispositivos.
6. **Todo exportable**: archivos originales, Markdown, JSON y Readwise.

**No-objetivos (v1)**
- Convertir formatos (de MOBI a EPUB, etc.). La app **lee** los formatos tal cual.
- Enviar a e-readers por cable, plugins al estilo Calibre, multiusuario y tienda.
- Android y Windows nativos (la web cubre lo básico).
- **Bot de Telegram** (diferido; ver §4.8).

## 3. Usuario y casos de uso

**Persona principal: tú.** Lector intenso con iPhone Pro (pronto iPhone Duo), Mac y biblioteca de Calibre en Google Drive. Lee en **español e inglés**. Biblioteca de **1,000–2,000 libros**.

| # | Historia | P |
|---|---|---|
| U1 | Importo mi biblioteca de Calibre desde Google Drive una sola vez, con sus metadatos y subrayados. | P0 |
| U2 | Arrastro un EPUB al Mac (o lo comparto desde Archivos en el iPhone); la app completa los metadatos y la portada, y aparece en todos mis dispositivos. | P0 |
| U3 | Leo en el iPhone, lo despliego (Duo) y aparecen dos páginas enfrentadas en la misma frase. | P0 |
| U4 | Subrayo con un gesto; aparece en el Mac, en la web y en Readwise con un enlace que vuelve al pasaje. | P0 |
| U5 | Edito los metadatos de 30 libros a la vez en el Mac (serie, etiquetas, autor) en una tabla rápida. | P0 |
| U6 | Mis subrayados de Kindle que están en Readwise aparecen **dentro de mis EPUB**, en su lugar exacto, y alimentan los insights. | P0 |
| U12 | Empiezo un libro en Reader y lo sigo en la app (o al revés); mis subrayados están en los dos lados. | P1 |
| U7 | Activo la lectura guiada: un marcador avanza a mi ritmo y me ayuda a leer más rápido sin perder el contexto. | P1 |
| U8 | Toco "Explícame" sobre un subrayado y recibo una respuesta local en menos de 2 s. | P1 |
| U9 | Retomo una novela tras 2 semanas y leo "lo que va hasta aquí" sin spoilers. | P1 |
| U10 | Leo un manga en el Duo desplegado: la doble página impresa cae sobre la bisagra, de derecha a izquierda. | P1 |
| U11 | Le pregunto a mi biblioteca "¿dónde leí sobre X?" y obtengo citas clicables. | P2 |

## 4. Arquitectura sin servidor

```
┌────────────── Tus dispositivos (todo el cómputo) ──────────────┐
│  iPhone / iPhone Duo     iPad          Mac (centro de mando)   │
│  · lector                · lector      · lector                │
│  · IA nivel 0            · IA nivel 0  · administración tipo   │
│  · índice semántico      · índice      │  Calibre              │
│                                        · importación y OCR     │
└───────┬───────────────────────┬────────────────────┬───────────┘
        │ CKSyncEngine          │ HTTPS (opcional)   │ API Reader v3 + Readwise v2
┌───────▼───────────────────┐ ┌─▼────────────────┐ ┌─▼─────────────────────────┐
│ iCloud: tu base privada   │ │ IA en la nube:   │ │ Readwise Reader/Readwise  │
│ (CloudKit)                │ │ PCC de Apple o   │ │ ⇄ subrayados              │
│ · catálogo y metadatos    │ │ tu clave         │ │ ← originales, progreso,   │
│ · subrayados y progreso   │ │ (Anthropic,      │ │   subrayados de Kindle    │
│ · archivos (CKAsset)      │ │ OpenAI, xAI…)    │ └───────────────────────────┘
│ · índice e insights       │ └──────────────────┘   Fuentes de importación:
└───────▲───────────────────┘   Drive · OneDrive · Archivos · Calibre
        │ CloudKit JS
┌───────┴───────┐
│ Web (estática)│  ← solo HTML y JS publicados; no es un servidor tuyo
└───────────────┘
```

### 4.1 ¿Por qué iCloud y no Google Drive u OneDrive como base?

| | **iCloud (CloudKit)** ✅ | Google Drive / OneDrive |
|---|---|---|
| Qué es | Una **base de datos privada por usuario** con registros, archivos y sincronización incremental | Un **disco de archivos** |
| Sincronizar subrayados y progreso | Nativo: `CKSyncEngine` resuelve sync, offline y conflictos por registro | Hay que inventarlo encima de archivos. Una base de datos en un disco sincronizado es justo lo que corrompe a Calibre *[01 §9]* |
| Costo y cuenta | Usa **tu** iCloud; la app no paga servidores | Usa tu cuenta; requiere OAuth y verificación de Google para una app pública |
| Web | **CloudKit JS** (inicio de sesión con Apple ID) | API REST (OAuth) |
| Android (futuro) | ❌ | ✅ |

**Decisión:** iCloud es "el servidor que ya tienes". Google Drive y OneDrive se usan como **fuentes de importación**: conectas tu cuenta, eliges carpetas o tu biblioteca de Calibre, e importas. Si la versión pública necesita Android, se agrega un `StorageProvider` alternativo detrás de la misma interfaz (ver §4.7).

**Espacio:** EPUB: ~2–8 GB para 2,000 libros; con PDFs y cómics, +10–100 GB. Probablemente necesitas **iCloud+ de 200 GB o 2 TB**.

### 4.2 Modelo de datos en CloudKit (base privada, zona propia)
| Tipo de registro | Campos clave |
|---|---|
| `Book` | uuid, título, orden de título, autores (lista), serie y número, etiquetas, idioma, ISBN y otros identificadores, editorial, fecha, descripción, valoración, estado de lectura, columnas personalizadas (JSON), `fileHash`, formatos |
| `BookFile` | referencia a `Book`, formato, tamaño, sha256, **`CKAsset`** con el archivo |
| `Cover` | `CKAsset` de la portada y una miniatura |
| `Annotation` | uuid, referencia a `Book`, tipo, selectores (CFI, cita, posición, página + quads), color, nota, etiquetas, fechas, `deleted` (tombstone), `readwiseId` |
| `Progress` | libro, dispositivo, Locator/CFI, **posición más lejana**, porcentaje, fecha |
| `Shelf` | estante manual o inteligente (consulta guardada) |
| `Insight` | resultados de IA guardados (resumen de capítulo, personajes, conexiones) para no recalcularlos en cada dispositivo |
| `Settings` | ajustes globales y por libro |

- **Archivos bajo demanda:** cada dispositivo descarga el `CKAsset` solo al abrir o marcar "descargar". El iPhone no necesita tener los 2,000 libros.
- **Índice local** en cada dispositivo (SQLite con GRDB, o SwiftData): búsqueda instantánea, portadas en caché y lista de 2,000 libros a 120 fps.
- ⚠️ **A verificar en el spike S3:** un ingeniero de Apple indica en los foros que un `CKAsset` admite hasta 50 GB (limitado por tu cuota). Hay menciones históricas de 50 MB para **CloudKit Web Services**: comprobar el límite real en la web con PDFs y cómics grandes.

### 4.3 Reemplazar a Calibre: qué tan complicado es

**Respuesta corta: complejidad media, porque no vamos a reemplazar la parte más difícil de Calibre (la conversión de formatos), que no necesitamos.** Calibre son ~20 años de trabajo, pero su valor para ti cabe en un conjunto acotado:

| Función de Calibre | ¿La necesitamos? | Cómo la hacemos | Dificultad |
|---|---|---|---|
| Catálogo: autores, series, etiquetas, identificadores, valoración, columnas personalizadas | Sí | Modelo de §4.2 | Baja |
| Vista de tabla, orden, filtros y **edición masiva** | Sí (**Mac**) | SwiftUI `Table` en Mac; en iPad, una versión simplificada | Media |
| Lenguaje de búsqueda (`tags:x series:y`) y bibliotecas virtuales | Sí | Parser propio sobre el índice local + estantes inteligentes | Media |
| **Descarga de metadatos y portadas** | Sí | Directo desde el dispositivo con **Open Library** (gratis), **Google Books API** y **Hardcover** (GraphQL con token); fusión inspirada en Calibre: título más corto, descripción más larga, fecha más antigua *[01 §6]* | Media |
| Leer metadatos de los archivos (OPF del EPUB, PDF, `ComicInfo.xml`) | Sí | Parsers en Swift (ZIPFoundation + XMLParser; PDFKit) | Baja |
| Escribir metadatos de vuelta en el archivo | Opcional | "Incrustar metadatos al exportar" (reescribir el OPF dentro del EPUB) | Media |
| Detección de duplicados | Sí | Hash del archivo + ISBN + título/autor normalizados | Baja |
| Renombrar y organizar carpetas | No | CloudKit no necesita carpetas; la exportación sí genera `Autor/Título.epub` | — |
| **Conversión** (`ebook-convert`) | **No** | foliate-js lee EPUB, MOBI, AZW3 y FB2 directamente; los cómics CBR/CB7 se leen con **libarchive** (BSD, sin UnRAR) | — |
| Enviar a e-readers y plugins | No (v1) | — | — |
| Servidor de contenido y OPDS | No | La sync es CloudKit | — |

**Migración desde Calibre (una vez):**
1. La app de Mac se conecta a Google Drive (o abre la carpeta local sincronizada) y lee `metadata.db` **en solo lectura** (SQLite está disponible en Apple). Se recomienda copiar antes la biblioteca a una carpeta local, por los riesgos de Drive *[01 §2]*.
2. Por cada libro: metadatos, portada, archivos, columnas personalizadas y **anotaciones de Calibre** (tabla `annotations`, JSON con CFI y texto citado *[01 §5]*). Se re-anclan por la cita, porque los CFI de Calibre no coinciden con los de foliate-js.
3. Pantalla de revisión: duplicados, libros sin portada, errores. Luego, subida a iCloud con progreso y posibilidad de reanudar.
4. Calibre queda como respaldo de solo lectura; puedes retirarlo cuando quieras.

**Licencia:** no se copia código de Calibre (GPL v3). Se toman ideas y el formato de su base de datos solo para leerla.

### 4.4 Motor de render por formato (todo en el dispositivo)
| Formato | Apple (iOS/iPadOS/macOS) | Web |
|---|---|---|
| EPUB, MOBI, AZW3, FB2 | foliate-js en `WKWebView` (fork fijado, servido por `WKURLSchemeHandler`) con UI y gestos nativos en SwiftUI | foliate-js |
| PDF | **PDFKit** con subrayados en una capa propia (sin escribir en el archivo). OCR de escaneados con **Vision** (preferentemente en el Mac, en segundo plano) | pdf.js |
| Cómics (CBZ/CBR/CB7/CBT) | Lector nativo en Swift; **libarchive** para abrir los archivos; `ComicInfo.xml` para manga y dobles páginas | Lector en TypeScript (CBZ con JSZip; CBR con libarchive.js en WASM) |

- **PDF reflow:** en la v1.1 se apoyaba en Docling, en el servidor. Ahora pasa a **P2**: texto de PDFKit + análisis de layout con Vision para generar una vista reflow en el Mac, que se sincroniza como derivado.
- **Guided View de cómics** (detección de viñetas) pasa a **P3**, con un modelo Core ML en el dispositivo.

### 4.5 IA: iPhone primero, nube opcional *[07]*

Todo pasa por **una sola API** (`LanguageModelSession` de Foundation Models). En iOS 27, el protocolo `LanguageModel` permite poner otros modelos detrás de ella: MLX, Claude, Gemini y servidores compatibles con Chat Completions ✅. Cambiar de proveedor es un ajuste, no reescribir código.

| Nivel | Qué es | Costo | Qué sale del dispositivo | Para qué |
|---|---|---|---|---|
| **0 · En el iPhone** | Modelo de Apple (iOS 27: nuevo, acepta imágenes, ~8K de contexto ✅) + opcional un modelo abierto de ~4B con MLX (Qwen3.5-4B, Gemma 4 E4B) | Gratis | Nada | Definir, explicar, traducir, etiquetar, flashcards, reflexión, "tus ideas clave", pre-lectura; resúmenes de capítulo por partes (lentos) |
| **1 · Nube privada de Apple (PCC)** | Modelo más grande de Apple, ~32K de contexto, con razonamiento ✅ | Gratis para el desarrollador; límites diarios por usuario | Texto enviado a la nube privada de Apple (no se guarda) | Resúmenes de capítulo, "lo que va hasta aquí", personajes. ⚠️ Requiere el Small Business Program y un entitlement que se pide a Apple; hay que confirmar si aplica a una app personal en TestFlight |
| **2 · Tu propia clave de API** | Anthropic, OpenAI, xAI, Google u OpenRouter, en el Llavero de iCloud | ~0.25–13 USD/mes para un lector intenso, según el modelo ⚠️ | **Solo los fragmentos necesarios**, siempre limitados a lo ya leído | Chat con tu biblioteca, conexiones profundas, digest, contraargumentos, mapas de argumentos |
| **3 · Suscripciones** | Ver la tabla siguiente | Lo que ya pagas | Igual que el nivel 2 | Igual que el nivel 2 |

**¿Se pueden usar tus suscripciones?**
| Suscripción | ¿Se puede? | Cómo |
|---|---|---|
| **Claude Pro/Max** | ❌ con el inicio de sesión de claude.ai: Anthropic lo **prohíbe explícitamente** en apps de terceros ✅. ✅ **Max incluye créditos de API** (100 o 200 USD/mes): creas una API key en la consola y la pegas en la app ⚠️ confirmar en tu cuenta | Nivel 2 con tu clave |
| **ChatGPT Plus/Pro** | ⚠️ Parcial. Existe **"Sign in with ChatGPT"** con uso del plan, pero en autoservicio solo para apps open-source que corren en tu máquina (encajaría en el Mac). En iOS no está documentado | Lo más seguro: API key de OpenAI |
| **SuperGrok / X Premium** | ❌ No hay vía oficial | API key de xAI |
| **Google AI Pro (Gemini)** | ❌ Google ha suspendido cuentas por usar su OAuth en terceros | API key de Gemini **con facturación** (el nivel gratis entrena con tus datos) |
| **ChatGPT dentro de Apple Intelligence** | ❌ No hay API para que una app use esa integración | — |

**Al revés: que tu Claude o ChatGPT lean tu biblioteca**
- **Readwise MCP oficial:** Claude y ChatGPT ya pueden consultar tus subrayados de Readwise, incluidos los que la app sincroniza. Funciona sin hacer nada.
- **P2:** un servidor MCP local en la app de Mac para Claude Desktop o Codex, con filtro antispoiler.

**Búsqueda semántica sin servidor**
- Embeddings en el iPhone con **EmbeddingGemma-300M** (Core ML) e índice local en **sqlite-vec**.
- **Tus subrayados** se indexan al instante, porque son poco texto.
- **El texto completo** se indexa por etapas: primero el libro que estás leyendo, después los terminados, y el resto de noche con el iPhone cargando. Toda la biblioteca son ~600k fragmentos y **12–30 h de cómputo** acumulado ⚠️. El índice (~150 MB) se sincroniza por iCloud para no repetirlo en cada dispositivo.
- Si el Mac lo permite, también puede ayudar a indexar; no es obligatorio.

**Reglas fijas**
- **Antispoiler:** nunca se envía ni se usa texto posterior a tu posición más lejana; instrucción explícita al modelo; citas validadas *[05 §5.0]*.
- **Privacidad:** el nivel 0 es el predeterminado. Los niveles 2 y 3 requieren activarlos y se muestra qué se envía. En "chat con tu biblioteca" solo salen los fragmentos recuperados; las citas se resuelven en el dispositivo para saltar a la frase exacta.
- **Web:** muestra los insights ya calculados; con una clave de API puede hacer consultas de nivel 2.

### 4.6 Readwise Reader y Readwise: qué se puede hacer *[06]*

**Resumen:** Reader **no puede ser el almacén** de tu biblioteca, pero sí puede ser **otra puerta de entrada y salida**. Puedes leer un libro en Reader o en la app y que tus subrayados estén en los dos lados. iCloud sigue siendo la fuente de verdad de archivos, metadatos, anclas exactas y progreso.

**Reader (API v3): lo que SÍ se puede**
| Capacidad | Detalle |
|---|---|
| **Descargar el EPUB o PDF original** que subiste a Reader ✅ | `GET /api/v3/list/?withRawSourceUrl=true` devuelve `raw_source_url`, un enlace firmado de S3 válido 1 hora (vacío si el documento no es distribuible). **Importar desde Reader** a tu biblioteca es P1 |
| **Crear subrayados en un documento de Reader** ✅ (desde el 18 sep 2026) | `POST /api/v3/save/` con `parent_id` + `content` (+ `notes`, `tags`). Reader ancla por coincidencia de texto (400 si no lo encuentra). Desde el 25 sep, `PATCH` (notas y etiquetas) y `DELETE` sobre subrayados. *Corrige lo dicho en v2.0 y en la investigación 05* |
| **Leer subrayados de Reader** ✅ | Son documentos `category=highlight` con `parent_id`. El `id` coincide con el `external_id` de la API v2 |
| **Leer el progreso** de Reader ✅ | `reading_progress` (0–1, solo lectura). Fluye de Reader a la app como sugerencia: "en Reader vas en el 43 %, ¿saltar?" |
| **Editar el documento** ✅ | Título, autor, resumen, etiquetas, notas, idioma, imagen, `location` (archivar), `seen`; `bulk_update` hasta 50 documentos por llamada |
| **Guardar artículos o URLs** ✅ | `POST /save/` con `url` (o `html`). Para la app: "leer después" de artículos que se leen en nuestro lector |
| Enviar un EPUB a Reader | ✅ por correo a `<alias>@library.readwise.io` (la app puede abrir el compositor de correo con el archivo adjunto). ⚠️ Guardar una URL temporal de iCloud con `category=epub` podría funcionar, pero es frágil |

**Reader: lo que NO se puede**
- ❌ Subir archivos por API (solo `url` o `html`).
- ❌ Escribir el progreso de lectura.
- ❌ Posiciones de subrayado utilizables: solo texto (y campos no documentados ⚠️). Las anclas exactas viven en iCloud; hacia Reader se envía el texto y Reader lo ancla.
- ❌ Cómics, metadatos de biblioteca (series, número, ISBN) y estantes.
- ❌ Webhooks sin servidor: existen, pero piden un endpoint público. Usamos sondeo con `updatedAfter` (límite de 20 listados/min, suficiente).
- Requiere la suscripción **Readwise Full**.

**Readwise (API v2): lo que se usa**
| Uso | Detalle |
|---|---|
| **Subrayados de libros que no están en Reader** | `POST /api/v2/highlights/` con `highlight_url` (enlace de vuelta e idempotencia) |
| **Subrayados de Kindle** ✅ | `GET /api/v2/export/` trae los libros con `source: "kindle"`, `asin`, título y autor, y sus subrayados con `location`. **Emparejamiento:** ASIN (los identificadores `amazon:` de Calibre) → título y autor normalizados → confirmación buscando citas en el texto. Después cada subrayado se **re-ancla** por búsqueda difusa de la cita, conservando el orden de Kindle. **Tus subrayados de Kindle aparecen dentro de tus EPUB** |
| **Borrados** | `export?includeDeleted=true` (Reader no avisa de borrados) |
| Daily Review | `GET /api/v2/review/` y `/review/complete/` |

**Reglas de sincronización**
1. **Libro vinculado a Reader** (el mismo libro en los dos): subrayados en ambos sentidos vía v3, emparejados por texto; progreso solo de Reader a la app.
2. **Libro solo en la app:** subrayados → Readwise v2.
3. **Libros de Kindle:** importar sus subrayados y anclarlos en tu EPUB si lo tienes, o guardarlos como "subrayados sin libro" si no.
- Sin servidor, la sync la hace el dispositivo activo. El cursor `updatedAfter` vive en CloudKit para que los dispositivos no repitan trabajo; la idempotencia viene del `highlight_url` y de los ids de Reader.
- **Web:** las llamadas a Readwise desde el navegador pueden fallar por CORS ⚠️ (ver investigación 06). La web hereda los datos ya sincronizados vía CloudKit.
- **Términos de uso:** para uso personal, con tu propio token, no hay problema. Para una app pública, hablar antes con Readwise y que la integración sea opcional.
- **Spike R:** 9 pruebas con tu token real antes de programar (investigación 06).

### 4.7 Módulos removibles (para la versión pública)
`StorageProvider` (iCloud; en el futuro Google Drive para Android), `ImportSource` (Archivos, Drive, OneDrive, Calibre), `MetadataProvider` (Open Library, Google Books, Hardcover), `KnowledgeSink` (Readwise, Markdown, Obsidian), `AIProvider` (Foundation Models, MLX, PCC opcional) y `Acquisition` (el futuro bot). Cada uno detrás de una interfaz y una *feature flag*.

### 4.8 Bot de Telegram (diferido, solo una nota)
Sin servidor, el bot necesitará **algo encendido** cuando llegue su momento: el Mac encendido o una función mínima en la nube que deje el archivo en una carpeta de importación. Se decide en su fase; nada de la arquitectura actual lo bloquea.

### 4.9 Traducción de las investigaciones (servidor → dispositivo)
| En las investigaciones decía | Ahora |
|---|---|
| Postgres + pgvector | Índice local (SQLite + sqlite-vec) + CloudKit para lo que se sincroniza |
| Ollama en el servidor | Foundation Models en el iPhone + PCC de Apple o tu clave de API |
| `calibre-server` / `calibredb` | Catálogo propio en CloudKit; Calibre solo para migrar |
| PDFium / OCRmyPDF / Docling | PDFKit + Vision en el dispositivo |
| Conversión de cómics a CBZ en el servidor | libarchive en el dispositivo |
| Push del servidor (APNs) | Notificaciones de CloudKit (cambios en la base) |

## 5. Catálogo de funcionalidades priorizado

**P0** = MVP · **P1** = v1 completa (el diferenciador) · **P2** = después · **P3** = algún día. Etiquetas: **[T]** básico · **[D]** diferenciador · **[M]** momento mágico. Detalle en *[03 §2]* y *[05 §5]*.

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
| Búsqueda en el libro (ignora acentos, resultados progresivos) | P0 | T |
| Diccionario del sistema, traducción on-device (Translation framework), Wikipedia | P0 / P1 | T |
| Page curl opcional | P2 | D |
| Scroll continuo entre capítulos | P2 | D |
| Números de página estables (page-list del editor) | P2 | D |
| Lectura paralela: dos libros o dos ubicaciones a la vez en iPad y Duo | P2 | D |

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
| OCR de escaneados con Vision (en el Mac, en segundo plano; en el iPhone, bajo demanda) | P1 |
| Vista reflow generada en el Mac (PDFKit + Vision) | P2 |
| Apple Pencil: tinta y notas en el margen; exportar anotaciones PDF estándar | P2 |

### 5.4 Cómics
| Función | P |
|---|---|
| CBZ, CBR, CB7 y CBT con libarchive; miniaturas; lectura fluida de archivos grandes | P1 |
| Manga de derecha a izquierda (`ComicInfo.xml`), dobles páginas, ajuste a ancho o alto | P1 |
| Webtoon con scroll vertical | P2 |
| Guided View viñeta a viñeta (Core ML en el dispositivo) | P3 |

### 5.5 Gestión de biblioteca (reemplazo de Calibre)
| Función | P |
|---|---|
| **Migración desde Calibre** (metadatos, portadas, series, etiquetas, columnas, anotaciones) con pantalla de revisión | P0 |
| Importar: arrastrar al Mac, menú Compartir y Archivos en iOS, **carpeta "Buzón" en iCloud Drive** que se vigila | P0 |
| Importar desde **Google Drive y OneDrive** (conectar cuenta, elegir carpetas) | P1 |
| Catálogo: autores, series con número, etiquetas, idioma, identificadores, valoración, estado de lectura | P0 |
| **Tabla de administración en el Mac**: orden, columnas configurables, **edición masiva** | P0 |
| Descarga automática de **metadatos y portadas** (Open Library, Google Books, Hardcover) con fusión y elección manual | P0 |
| Editor de portadas (buscar alternativas, recortar, usar una imagen propia) | P1 |
| Búsqueda con sintaxis (`autor:x serie:y etiqueta:z`) y **estantes inteligentes** | P1 |
| Detección y fusión de duplicados | P1 |
| Exportar la biblioteca (archivos con metadatos incrustados, estructura `Autor/Título`) | P1 |
| Descarga para leer sin conexión y gestión del espacio por dispositivo | P0 |
| "Seguir leyendo" como inicio; series con "siguiente de la serie" | P0 |

### 5.6 Subrayados, notas y Readwise
| Función | P | Tipo |
|---|---|---|
| Subrayado instantáneo con un gesto, 4–5 colores, subrayado que cruza páginas | P0 | T |
| Notas y etiquetas; panel filtrable por color, capítulo y etiqueta | P0 | T |
| **Envío a Readwise** con enlace que vuelve al pasaje | P0 | D |
| **Subrayados de Kindle (vía Readwise) anclados dentro de tus EPUB** | P0 | M |
| **Reader:** importar originales, subrayados en ambos sentidos para libros vinculados, progreso de Reader a la app | P1 | D |
| Traer subrayados de otras fuentes (Apple Books, artículos, podcasts) | P1 | D |
| Daily Review de Readwise dentro de la app y en el widget | P2 | D |
| Export ilimitado a Markdown y JSON; "libro en una página" para Obsidian | P0 | M |
| Copiar con cita y deep link | P1 | D |
| Quote cards como imagen | P2 | M |

### 5.7 Lectura guiada (modo de lectura rápida)
Objetivo: **leer más rápido y con más foco sin perder comprensión.** La evidencia (Rayner et al., 2016) indica que los métodos que quitan el contexto (palabra por palabra) o impiden releer bajan la comprensión por encima de ~400–500 ppm. Por eso el modo por defecto **guía dentro de la página**.

| Modo | Cómo funciona | P |
|---|---|---|
| **Marcador guiado** (por defecto) | Una banda resalta la línea actual y avanza a tu velocidad; la página pasa sola | P1 |
| **Foco por frase** | Resalta grupos de 3–5 palabras que avanzan por la línea | P1 |
| **Lectura con voz** | TTS a 1.2–2× con resaltado sincronizado | P1 |
| **RSVP** (estilo Spritz) | Una palabra a la vez, con la letra de enfoque en color; con aviso de comprensión | P2 |
| **Pre-lectura con IA** | Esquema del capítulo antes de leerlo (solo no ficción) | P2 |

Velocidad de 150 a 700 ppm, con arranque gradual y **ritmo adaptativo** (más lento en palabras largas, números y puntuación); **velocidades separadas para español e inglés**; tocar para pausar; deslizar hacia atrás para releer; **subrayar sin salir del modo**; estadísticas de ppm reales y preguntas de comprensión opcionales. En pose mesa del Duo funciona manos libres. Respeta Reduce Motion. *Implementación:* rangos de línea con `Range.getClientRects()` en el WebView y animación CSS a 120 Hz; RSVP como vista nativa.

### 5.8 IA e insights (en el dispositivo)
| Función | Dónde | P |
|---|---|---|
| Definir, explicar o traducir una selección | Foundation Models | P1 |
| Etiquetado automático, pregunta de reflexión, flashcard | Foundation Models | P1 |
| "Tus ideas clave" al terminar un libro (desde tus subrayados) | Foundation Models | P1 |
| **"Esto conecta con…"**: subrayados relacionados de otros libros (incluidos los de Kindle vía Readwise) | Embeddings locales | P1 |
| Resumen de capítulo y **"lo que va hasta aquí"** | iPhone por partes · PCC · tu clave | P1 |
| Personajes y conceptos hasta aquí (X-Ray sin spoilers) | PCC · tu clave | P2 |
| **Digest semanal** en la app (notificación + pantalla) | iPhone · tu clave | P1 |
| Repaso espaciado (FSRS), sin duplicar la Daily Review de Readwise | Dispositivo | P2 |
| **Chatea con tu biblioteca**, con citas clicables | Índice en el iPhone + PCC o tu clave | P2 |
| Temas a lo largo del tiempo, contradicciones, mapa de argumentos | Tu clave | P2 |
| Configurar proveedor de IA (Apple, Anthropic, OpenAI, xAI, Google, OpenRouter) y ver qué se envía | Ajustes | P1 |

### 5.9 Audio y TTS
| Función | P |
|---|---|
| TTS con voces del sistema (Premium), resaltado, sleep timer, pantalla de bloqueo y segundo plano | P1 |
| EPUB 3 Media Overlays (read-along) | P2 |
| Pasar de escuchar el audiolibro a leer en la misma frase | P3 |

### 5.10 Sync, estadísticas y plataforma
| Función | P |
|---|---|
| Sync con CloudKit de catálogo, progreso, anotaciones y ajustes; offline con cola | P0 |
| **Conflictos visibles**: "estás más adelante en el iPad, ¿saltar?" | P0 |
| Estadísticas: tiempo diario, racha, velocidad, objetivo anual | P1 |
| Resumen anual | P2 |
| Mac: menús, atajos, varias ventanas | P1 |
| App Intents y Siri, Live Activity, widgets | P2 |
| Web (CloudKit JS + foliate-js) | P2 |

### 5.11 Accesibilidad (P0 de forma transversal)
VoiceOver con lectura continua dentro del WKWebView, Dynamic Type, Reduce Motion, alto contraste, fuentes para dislexia, teclado completo en Mac y zonas de toque configurables (incluido modo zurdo).

## 6. Requisitos no funcionales
| Área | Meta |
|---|---|
| Rendimiento | Abrir un libro descargado en menos de 700 ms; pasar página con menos de 16 ms de latencia percibida; biblioteca de 2,000 libros con scroll a 120 fps |
| Sync | Un cambio aparece en otro dispositivo en menos de 10 s en línea; **0 anotaciones perdidas** (tests de propiedades sobre el merge) |
| Migración | 2,000 libros importados con revisión en menos de 1 hora en el Mac; reanudable si se interrumpe |
| IA | Respuesta de Foundation Models en menos de 2 s; resúmenes de capítulo en segundo plano |
| Privacidad | Ningún texto de libros sale de tus dispositivos ni de tu iCloud; la IA en la nube está apagada por defecto. Readwise solo recibe los subrayados |
| Fiabilidad | Export completo en todo momento; respaldo opcional programado a una carpeta (Drive u otro) desde el Mac |

## 7. Métricas de éxito (personales)
- **Adopción:** más del 90 % del tiempo de lectura semanal en la app a los 2 meses.
- **Calibre retirado:** dejas de abrir Calibre a los 3 meses.
- **Confianza:** 0 subrayados perdidos o progreso que retrocede.
- **Valor de la IA:** abres al menos el 30 % de los digests; vuelves a ver al menos el 20 % de los subrayados en 90 días.

## 8. Plan por fases y criterios de salida

**Fase 0: Spikes técnicos (2 semanas)**
- S1: foliate-js en WKWebView dentro de SwiftUI: paginación, **gestos interrumpibles nativos**, selección con menú nativo, CFI, guiones en español, VoiceOver, libro de 1,000 páginas. *Salida:* se siente como Apple Books en un test a ciegas contigo.
- S2: PDFKit con un PDF de 500 páginas y 300 subrayados en una capa propia.
- S3: **CloudKit**: `CKSyncEngine` con 2,000 registros `Book` y 10,000 `Annotation`; subir y bajar un `CKAsset` de 300 MB; límites reales en CloudKit JS.
- S4: **lector de `metadata.db` de Calibre** en Swift contra una copia de tu biblioteca.
- S5: lectura guiada: marcador por línea a 300 ppm en un libro en español, fluido a 120 Hz.
- S6 (**Spike R**): las 9 pruebas de Reader y Readwise con tu token real (investigación 06): subrayado en un documento, `raw_source_url`, export de Kindle, emparejamiento por ASIN.
- S7: Foundation Models en tu iPhone: explicar en español, resumen de capítulo por partes, embeddings con EmbeddingGemma.

**Fase 1: MVP en iPhone + Mac (8–10 semanas)**
- Migración desde Calibre; catálogo y tabla de administración en el Mac.
- Lector EPUB y PDF con todos los P0; sync CloudKit; Duo (doble página).
- Envío a Readwise y **subrayados de Kindle anclados en tus EPUB**.
- *Salida:* dejas de usar Calibre, Apple Books y Kindle para tus libros.

**Fase 2: Diferenciadores (6–8 semanas)**
- Lectura guiada, cómics, P1 de biblioteca, **integración con Reader**, IA de nivel 0 y configuración de proveedores, poses del Duo y modo estudio.

**Fase 3: Capa de conocimiento (4–6 semanas)**
- Embeddings en el iPhone, "esto conecta con…", resúmenes (PCC o tu clave) y digest semanal.

**Fase 4: Web + P2.** **Fase 5:** bot de Telegram. **Fase 6 (opcional):** versión pública.

## 9. Riesgos principales
| Riesgo | Prob. | Impacto | Mitigación |
|---|---|---|---|
| Gestos y selección en WKWebView se sienten "web" | Media | Alto | Spike S1 primero; gestos nativos; parches de Readest como referencia |
| Límites de CloudKit (archivos grandes, web, cuota de iCloud) | Media | Medio | Spike S3; aviso de espacio; los archivos se descargan bajo demanda |
| Edición masiva y metadatos: subestimar lo que hace Calibre | Media | Medio | Alcance acotado en §4.3; Calibre se conserva en solo lectura los primeros meses |
| IA sin servidor: el iPhone solo tiene un modelo pequeño | Alta | Medio | PCC de Apple o tu clave de API para lo pesado; lo ligero va en el iPhone |
| Acceso a PCC de Apple para una app personal | Media | Medio | Si no aplica, el nivel 2 con tu clave cubre lo mismo |
| La API de Reader es reciente (subrayados desde sep 2026) y puede cambiar | Media | Medio | Spike R; la integración aislada en `KnowledgeSink` |
| Varios dispositivos sincronizando con Readwise y Reader a la vez | Baja | Bajo | `highlight_url` e ids de Reader idempotentes + cursor compartido en CloudKit |
| Limitaciones de foliate-js | Alta | Medio | Fork fijado; scroll continuo en P2 |
| APIs del iPhone Duo (iOS 27.1) nuevas | Media | Medio | Size classes primero; APIs nuevas detrás de `#available` |
| Datos de Readwise e iOS 27 sin verificar (⚠️) | — | Bajo | Verificar antes de programar cada integración |
| Alcance enorme para un proyecto personal | Alta | Alto | Fases con criterios de salida |

## 10. Preguntas abiertas
1. **¿Qué plan de iCloud tienes** (50 GB, 200 GB, 2 TB)? ¿Cuánto pesa tu biblioteca de Calibre hoy?
2. De los 1,000–2,000 libros, **¿cuántos son PDF y cómics?**
3. **¿Qué suscripción de Claude tienes** (Pro o Max)? Con Max, los créditos de API cubrirían la IA de nivel 2.
4. ¿Tus libros de Calibre tienen el **ASIN de Amazon** (identificador `amazon:`)? Facilita ligar los subrayados de Kindle.
5. ¿Usas la Daily Review de Readwise? Define si el repaso espaciado propio es P2 o se omite.
6. Nombre del producto ("Biblioteca Lectora" es provisional).
7. ~~Columnas personalizadas o plugins de Calibre~~ (no) · ~~Subrayados de Kindle en Readwise~~ (sí) · ~~Mac para IA pesada~~ (no se asume).

---
**Fuentes nuevas de esta versión:** [CKAsset: límite de tamaño (foro de Apple)](https://developer.apple.com/forums/thread/827897) · [CKAsset (documentación)](https://developer.apple.com/tutorials/data/documentation/cloudkit/ckasset.md) · [Readwise API](https://readwise.io/api_deets) · [Reader API](https://readwise.io/reader_api) · [pyreadwise: Reader API](https://rwxd.github.io/pyreadwise/readwise-reader-api/) · [Rayner et al. 2016 (APS)](https://www.psychologicalscience.org/publications/speed_reading.html)

**Investigaciones de soporte:** [06 Reader y Readwise](investigacion/06-readwise-reader.md) · [07 IA en el dispositivo y en la nube](investigacion/07-ia-dispositivo-y-nube.md) · [01 Calibre](investigacion/01-calibre.md) · [02 Servidores de biblioteca](investigacion/02-servidores-biblioteca.md) · [03 Lectores](investigacion/03-lectores.md) · [04 PDF y cómics](investigacion/04-pdf-y-comics.md) · [05 IA e insights](investigacion/05-ia-e-insights.md)
