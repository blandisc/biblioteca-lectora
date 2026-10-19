# Biblioteca Lectora: PRD v2.0

> **Estado:** borrador para revisión · **Versión:** 2.0 · **Fecha:** 19 oct 2026 · **Alcance:** uso personal, diseñado para poder abrirse al público después.
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
| U6 | Mis subrayados de Kindle o Apple Books que están en Readwise aparecen en la app y alimentan los insights. | P1 |
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
│  · IA ligera             · IA ligera   · administración tipo   │
│  · índice local          · índice      │  Calibre              │
│                                        · IA pesada en segundo  │
│                                        │  plano (opcional)     │
│                                        · importación y OCR     │
└───────────────┬────────────────────────────────┬───────────────┘
                │ CKSyncEngine                   │ API de Readwise (v2)
        ┌───────▼─────────────────────┐   ┌──────▼──────┐
        │  iCloud: tu base de datos   │   │  Readwise   │ ⇄ subrayados
        │  privada (CloudKit)         │   └─────────────┘
        │  · catálogo y metadatos     │
        │  · subrayados y progreso    │   Fuentes de importación:
        │  · archivos (CKAsset)       │   Google Drive · OneDrive ·
        └───────▲─────────────────────┘   Archivos · biblioteca Calibre
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

### 4.5 IA solo en el dispositivo
| Nivel | Dónde | Para qué |
|---|---|---|
| **Ligera** | **Apple Foundation Models** en iPhone, iPad y Mac (~3B parámetros, contexto de ~4K tokens, español soportado) | Definir, explicar, traducir, etiquetar, flashcards, preguntas de reflexión, "ideas clave" a partir de tus subrayados |
| **Pesada** | **El Mac como "cerebro"**, opcional: un modelo abierto con **MLX** (p. ej. Qwen3 8–14B, si tu Mac tiene 16–32 GB) en segundo plano | Resúmenes de capítulo, "lo que va hasta aquí", personajes, conexiones entre libros, digest. Los resultados se guardan como `Insight` en CloudKit y **aparecen en el iPhone aunque el Mac esté apagado después** |
| **Búsqueda semántica** | Embeddings en cada dispositivo (`NLContextualEmbedding` de Apple o un modelo multilingüe pequeño en Core ML) + índice vectorial local (SQLite + sqlite-vec) | Indexar **tus subrayados** en todos los dispositivos (es poco texto); el texto completo solo del libro que estás leyendo, o de toda la biblioteca en el Mac |

- **Sin Mac encendido:** todo lo ligero funciona en el iPhone. Los resúmenes de capítulo también pueden hacerse en el iPhone por partes (map-reduce con ~4K tokens), pero son lentos: se ejecutan cargando y con la app en segundo plano (`BGProcessingTask`).
- **Antispoiler:** solo texto hasta la posición más lejana alcanzada, más una instrucción explícita al modelo, más validación de citas *[05 §5.0]*.
- **iOS 27** ⚠️: nuevo modelo en el dispositivo y un modelo en **Private Cloud Compute** con más contexto. Sería una opción "en la nube privada de Apple", **apagada por defecto** y a verificar.
- **Web:** muestra los insights ya calculados (sincronizados vía CloudKit); no genera IA propia.

### 4.6 Readwise: qué se puede meter y qué se puede sacar

**Resumen:** Readwise **sí puede ser el "servidor" de tus subrayados**, en los dos sentidos. **No puede ser el almacén de tus libros**: su API no permite subir ni descargar archivos EPUB o PDF.

**Lo que podemos METER (desde la app)**
| Qué | Cómo | Notas |
|---|---|---|
| **Subrayados con nota, etiquetas, color, fecha y ubicación** | `POST /api/v2/highlights/` (en lotes) ✅ | Campos: `text` (obligatorio), `title`, `author`, `image_url`, `source_url`, `source_type`, `category=books`, `note`, `location` + `location_type` (`page`/`order`), `highlighted_at`, **`highlight_url`** |
| **Enlace de vuelta al pasaje exacto** | `highlight_url` = universal link `…/h/{uuid}` ✅ | Desde Readwise (web o Daily Review) tocas el subrayado y **abre la app en esa frase**. Reenviar con el mismo `highlight_url` **actualiza** en vez de duplicar |
| Etiquetas en línea | Nota que empieza con `.etiqueta` ⚠️ | Por confirmar |
| Editar o borrar un subrayado | `PATCH` / `DELETE /api/v2/highlights/{id}/` ⚠️ | Guardamos el `readwiseId` en `Annotation` |
| Etiquetas del libro | `/api/v2/books/{id}/tags/` ⚠️ | |
| Marcar la Daily Review como hecha | `POST /api/v2/review/complete/` ✅ | Si repasas dentro de la app |

**Lo que podemos SACAR (hacia la app)**
| Qué | Cómo | Para qué |
|---|---|---|
| **Todos tus subrayados de todas las fuentes** (Kindle, Apple Books, Kobo, Reader, artículos, podcasts…) con libro, autor, portada, nota, etiquetas y ubicación | `GET /api/v2/export/` con `updatedAfter` y `pageCursor` ✅ | Que tus **subrayados de Kindle** aparezcan junto al libro correspondiente de tu biblioteca y alimenten los insights. También trae **cambios hechos en Readwise** (notas o etiquetas editadas allá), que se fusionan de vuelta |
| La **Daily Review** de hoy | `GET /api/v2/review/` ✅ | Mostrar tu repaso de Readwise dentro de la app y en el widget |
| Documentos de **Reader** (artículos, PDFs guardados) y sus subrayados | `GET /api/v3/list/` (con `withHtmlContent`) ⚠️ | Opcional: leer artículos de Reader en nuestro lector. Devuelve **HTML procesado, no el archivo original** |

**Lo que NO se puede hacer** (y por qué Readwise no sirve como almacén de libros)
- ❌ **Subir un EPUB o PDF por API.** `POST /api/v3/save/` solo acepta una `url` pública (y HTML opcional); Reader descarga el archivo desde ahí. Sin servidor no tenemos una URL pública estable, y subir libros a Reader los mete en *su* biblioteca, no en la tuya.
- ❌ **Descargar el archivo original** de un libro guardado en Reader: no hay endpoint para eso.
- ❌ **Crear subrayados dentro de un documento de Reader** por API *[05 §2.5]*.
- ❌ Guardar posiciones exactas (CFI), progreso o metadatos de tu biblioteca: Readwise solo guarda una `location` entera.
- ⚠️ Límites: 240 peticiones/min en general, **20/min en listados**; con lotes y export incremental no es problema para una persona.

**Decisión: sync bidireccional de subrayados, iCloud como fuente de verdad**
- Cada subrayado nuevo o editado se envía a Readwise con su `highlight_url` (idempotente).
- Cada 15 minutos (o al abrir la app) se hace `export?updatedAfter=…`.
  - Los subrayados que vinieron de la app se fusionan (gana la edición más reciente).
  - Los subrayados **de otras fuentes** se guardan como `Annotation` importada (sin ancla precisa) ligada al libro por ISBN o título y autor; si el libro existe en tu biblioteca, se intenta anclarlos buscando la cita en el texto.
- **Como no hay servidor, la sync con Readwise la hace el dispositivo que esté activo.** Para no duplicar envíos entre dispositivos se usa el `highlight_url` (idempotente) y un "cursor" de export guardado en CloudKit.
- El token de Readwise se guarda en el **Llavero de iCloud** (sincronizado y cifrado).

### 4.7 Módulos removibles (para la versión pública)
`StorageProvider` (iCloud; en el futuro Google Drive para Android), `ImportSource` (Archivos, Drive, OneDrive, Calibre), `MetadataProvider` (Open Library, Google Books, Hardcover), `KnowledgeSink` (Readwise, Markdown, Obsidian), `AIProvider` (Foundation Models, MLX, PCC opcional) y `Acquisition` (el futuro bot). Cada uno detrás de una interfaz y una *feature flag*.

### 4.8 Bot de Telegram (diferido, solo una nota)
Sin servidor, el bot necesitará **algo encendido** cuando llegue su momento: el Mac haciendo de "cerebro" o una función mínima en la nube que deje el archivo en una carpeta de importación. Se decide en su fase; nada de la arquitectura actual lo bloquea.

### 4.9 Traducción de las investigaciones (servidor → dispositivo)
| En las investigaciones decía | Ahora |
|---|---|
| Postgres + pgvector | Índice local (SQLite + sqlite-vec) + CloudKit para lo que se sincroniza |
| Ollama en el servidor | Foundation Models + MLX en el Mac (opcional) |
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
| Columnas personalizadas | P2 |
| Exportar la biblioteca (archivos con metadatos incrustados, estructura `Autor/Título`) | P1 |
| Descarga para leer sin conexión y gestión del espacio por dispositivo | P0 |
| "Seguir leyendo" como inicio; series con "siguiente de la serie" | P0 |

### 5.6 Subrayados, notas y Readwise
| Función | P | Tipo |
|---|---|---|
| Subrayado instantáneo con un gesto, 4–5 colores, subrayado que cruza páginas | P0 | T |
| Notas y etiquetas; panel filtrable por color, capítulo y etiqueta | P0 | T |
| **Envío a Readwise** con enlace que vuelve al pasaje | P0 | D |
| **Traer de Readwise** cambios y subrayados de otras fuentes (Kindle, Apple Books…) y ligarlos a tus libros | P1 | D |
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
| Resumen de capítulo y **"lo que va hasta aquí"** | Mac con MLX, o iPhone en segundo plano | P1 |
| Personajes y conceptos hasta aquí (X-Ray sin spoilers) | Mac con MLX | P2 |
| **Digest semanal** en la app (notificación + pantalla) | Mac o iPhone | P1 |
| Repaso espaciado (FSRS), sin duplicar la Daily Review de Readwise | Dispositivo | P2 |
| **Chatea con tu biblioteca**, con citas clicables | Mac (índice completo); iPhone (subrayados) | P2 |
| Temas a lo largo del tiempo, contradicciones, mapa de argumentos | Mac | P2 |

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

**Fase 1: MVP en iPhone + Mac (8–10 semanas)**
- Migración desde Calibre; catálogo y tabla de administración en el Mac.
- Lector EPUB y PDF con todos los P0; sync CloudKit; Duo (doble página).
- Envío a Readwise.
- *Salida:* dejas de usar Calibre, Apple Books y Kindle para tus libros.

**Fase 2: Diferenciadores (6–8 semanas)**
- Lectura guiada, cómics, P1 de biblioteca, traer subrayados de Readwise, IA ligera, poses del Duo y modo estudio.

**Fase 3: Capa de conocimiento (4–6 semanas)**
- Embeddings locales, "esto conecta con…", resúmenes (MLX en el Mac) y digest semanal.

**Fase 4: Web + P2.** **Fase 5:** bot de Telegram. **Fase 6 (opcional):** versión pública.

## 9. Riesgos principales
| Riesgo | Prob. | Impacto | Mitigación |
|---|---|---|---|
| Gestos y selección en WKWebView se sienten "web" | Media | Alto | Spike S1 primero; gestos nativos; parches de Readest como referencia |
| Límites de CloudKit (archivos grandes, web, cuota de iCloud) | Media | Medio | Spike S3; aviso de espacio; los archivos se descargan bajo demanda |
| Edición masiva y metadatos: subestimar lo que hace Calibre | Media | Medio | Alcance acotado en §4.3; Calibre se conserva en solo lectura los primeros meses |
| IA sin servidor: el iPhone solo tiene un modelo pequeño | Alta | Medio | El Mac hace el trabajo pesado y sincroniza los resultados; lo ligero va en el iPhone |
| Varios dispositivos sincronizando con Readwise a la vez | Baja | Bajo | `highlight_url` idempotente + cursor compartido en CloudKit |
| Limitaciones de foliate-js | Alta | Medio | Fork fijado; scroll continuo en P2 |
| APIs del iPhone Duo (iOS 27.1) nuevas | Media | Medio | Size classes primero; APIs nuevas detrás de `#available` |
| Datos de Readwise e iOS 27 sin verificar (⚠️) | — | Bajo | Verificar antes de programar cada integración |
| Alcance enorme para un proyecto personal | Alta | Alto | Fases con criterios de salida |

## 10. Preguntas abiertas
1. **¿Qué plan de iCloud tienes** (50 GB, 200 GB, 2 TB)? ¿Cuánto pesa tu biblioteca de Calibre hoy?
2. **¿Qué Mac tienes** (chip y RAM)? Define si el Mac puede ser el "cerebro" de la IA.
3. De los 1,000–2,000 libros, **¿cuántos son PDF y cómics?**
4. **¿Usas columnas personalizadas en Calibre** o plugins que te importen?
5. **¿Tienes subrayados de Kindle en Readwise** que quieras ver junto a tus libros?
6. ¿Usas la Daily Review de Readwise? Define si el repaso espaciado propio es P2 o se omite.
7. Nombre del producto ("Biblioteca Lectora" es provisional).

---
**Fuentes nuevas de esta versión:** [CKAsset: límite de tamaño (foro de Apple)](https://developer.apple.com/forums/thread/827897) · [CKAsset (documentación)](https://developer.apple.com/tutorials/data/documentation/cloudkit/ckasset.md) · [Readwise API](https://readwise.io/api_deets) · [Reader API](https://readwise.io/reader_api) · [pyreadwise: Reader API](https://rwxd.github.io/pyreadwise/readwise-reader-api/) · [Rayner et al. 2016 (APS)](https://www.psychologicalscience.org/publications/speed_reading.html)

**Investigaciones de soporte:** [01 Calibre](investigacion/01-calibre.md) · [02 Servidores de biblioteca](investigacion/02-servidores-biblioteca.md) · [03 Lectores](investigacion/03-lectores.md) · [04 PDF y cómics](investigacion/04-pdf-y-comics.md) · [05 IA e insights](investigacion/05-ia-e-insights.md)
