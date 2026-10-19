# Investigación 04: PDF y cómics

> Documento de trabajo, octubre 2026. Complementa la [visión de producto v0.2](../vision-producto.md).
> **Pregunta:** ¿cómo debe Biblioteca Lectora leer PDF y cómics (CBZ/CBR/CB7, manga, webtoon) en iPhone, iPhone Duo, iPad, Mac y web, de forma que los subrayados se sincronicen y alimenten el pipeline de insights y Readwise?

---

## 0. Resumen ejecutivo

1. **foliate-js se queda para EPUB (y EPUB fixed-layout), pero no debe ser el motor de PDF ni de cómics.** Su README describe el soporte PDF como *"proof-of-concept, highly experimental adapter for PDF.js"* y trata los CBZ "como un EPUB fixed-layout": carga el ZIP completo en el cliente, sin streaming de páginas, sin modo webtoon, sin Guided View y sin CBR/CB7. Sirve como respaldo, no como experiencia principal.
2. **PDF:**
   - **Apple:** PDFKit nativo, con los subrayados dibujados como overlay propio. No se escriben en el archivo.
   - **Web:** pdf.js directo (`pdfjs-dist`, componentes `PDFViewer`), sin pasar por el adaptador de foliate.
   - **Servidor:** PDFium (`pypdfium2`, licencia permisiva) para generar un **mapa de texto canónico** por página. OCRmyPDF + Tesseract se encargan de los PDF escaneados, y Docling genera una "edición reflow" para pantallas pequeñas.
3. **Ancla portable para PDF:** índice de página (base 0) + *quads* en espacio de usuario PDF sin rotar + `TextQuoteSelector` (exact/prefix/suffix) + offsets en el mapa de texto canónico del servidor + huella del archivo. El modelo sigue al W3C Web Annotation y se puede exportar a anotaciones `/Highlight` (ISO 32000, `QuadPoints`) y XFDF.
4. **Cómics:**
   - **Clientes:** un **lector de imágenes nativo propio** en Swift (SwiftUI + `UIScrollView`/`NSScrollView`, ImageIO con *downsampling*) y un lector TypeScript equivalente en la web. Los dos consumen el mismo **manifiesto de lectura** JSON que genera el servidor: páginas, dimensiones, dobles páginas, RTL y paneles.
   - **Servidor:** normaliza CBR/CB7/CBT/PDF-cómic a CBZ (o a páginas sueltas), sirve las páginas por streaming (endpoint propio + OPDS-PSE para apps de terceros), genera miniaturas y detecta paneles (Kumiko → YOLO/Magi).
5. **iPhone Duo:** la doble página de cómic **sobre la bisagra es el caso de uso estrella**. Los *spreads* impresos ya traen el pliegue (*gutter*) al centro, así que la división física coincide con la del papel. El manga se muestra RTL (la página derecha va primero). El webtoon (scroll vertical) **no** se parte en la bisagra, como pide Apple.
6. **RAR:** en el cliente no hace falta. El servidor convierte con `unrar`/`7z`/`libarchive`. Si algún día se lee CBR offline en el dispositivo, `libarchive` (BSD, con implementación *clean-room* de RAR5) evita la licencia no libre de UnRAR.

---

## 1. PDF

### 1.1 Motores disponibles

| Motor | Licencia | Plataformas | Fortalezas | Debilidades |
|---|---|---|---|---|
| **Apple PDFKit** | Propietario, incluido en el SO | iOS, iPadOS, macOS (y Catalyst) | Cero dependencias. `PDFView` con zoom, miniaturas, búsqueda y selección de texto nativa (`PDFSelection`, `selectionsByLine()`, `bounds(for:)`). Anotaciones `PDFAnnotation` con `quadrilateralPoints`. `PDFPageOverlayViewProvider` (iOS 16+) para poner vistas propias encima de cada página. Live Text/accesibilidad del sistema. | Código cerrado y bugs que cambian entre versiones. Las diferencias entre iOS y macOS son sutiles. Rinde mal con muchas anotaciones al hacer zoom ([foro Apple](https://developer.apple.com/forums/thread/802728)) y con PDF muy pesados en vectores. Guardar es lento en archivos grandes ([DEVONthink](https://discourse.devontechnologies.com/t/devonthink-and-large-pdfs/65727)). No existe en la web. |
| **pdf.js** (Mozilla) | Apache-2.0 | Web (y `WKWebView`) | Es el estándar de facto en la web. Tiene *text layer* seleccionable, editor de resaltados (v4+), carga por rangos HTTP (`Range`) y *lazy rendering*. Es el motor de Firefox. | Rinde menos que un motor nativo en PDF complejos. Dentro de `WKWebView` en iPhone sufre el límite de memoria del proceso WebContent. El *text layer* posiciona `span`s por *transform*, lo que da selecciones algo "saltarinas" en PDF con *kerning* raro. |
| **PDFium** (Google/Chrome) | BSD-3 / Apache-2.0 | C/C++; binarios para todo; `pypdfium2` en Python | Es rápido y robusto (el de Chrome). Tiene API de texto completa (`FPDFText_GetCharBox`, `FPDFText_GetText`, búsqueda) y licencia permisiva. Funciona muy bien **en el servidor**. | No tiene UI. Los *wrappers* Swift son escasos o poco mantenidos e integrarlo en Apple exige compilar el XCFramework. |
| **MuPDF** (Artifex) | **AGPL-3** o comercial | C; PyMuPDF; lo usa KOReader | Es el más rápido y ligero. Tiene **reflow** propio (`stext`, `mutool convert -F html`) y además abre EPUB, CBZ y XPS. PyMuPDF4LLM sirve para extraer texto a Markdown. | Es AGPL: para uso personal en el servidor no hay problema, pero en una app pública obliga a liberar el código o pagar licencia. |
| **foliate-js + pdf.js** | MIT + Apache | Las mismas que foliate | Reutiliza la API de foliate (paginación, eventos). Readest lo usa. | El README lo llama *"highly experimental"*. Usa el renderer fixed-layout de EPUB, así que hereda las limitaciones de pdf.js y además las de la capa de adaptación. Los anclajes de texto no son robustos y no hay acceso fino a quads ni a la API de pdf.js. |

Fuentes: [PDFKit](https://developer.apple.com/documentation/pdfkit), [PDFPageOverlayViewProvider](https://developer.apple.com/documentation/pdfkit/pdfpageoverlayviewprovider), [pdf.js](https://github.com/mozilla/pdf.js), [PDFium](https://pdfium.googlesource.com/pdfium/), [pypdfium2](https://github.com/pypdfium2-team/pypdfium2), [MuPDF](https://mupdf.com/), [PyMuPDF](https://github.com/pymupdf/PyMuPDF), [foliate-js](https://github.com/johnfactotum/foliate-js), [KOReader](https://github.com/koreader/koreader), [Readest](https://github.com/readest/readest).

### 1.2 Rendimiento con PDF grandes

- **El peso por página importa más que el número de páginas.** Hay reportes de PDF de 500 páginas y 4.7 MB que van fluidos, y de 27 MB con las mismas páginas que se arrastran ([DEVONthink](https://discourse.devontechnologies.com/t/devonthink-and-large-pdfs/65727)). Los planos vectoriales y los escaneos a 600 dpi sin comprimir son los peores casos.
- **iOS no tiene memoria virtual con swap.** Si un render se pasa de memoria, el sistema mata la app ([PSPDFKit/Nutrient, "Using Document Efficiently"](https://pspdfkit.com/guides/ios/current/getting-started/using-document-efficiently/)). Reglas prácticas:
  - Nunca renderizar páginas completas a resolución de zoom máximo. Usar *tiles*: `PDFView` ya lo hace, y en un render propio `CATiledLayer`.
  - Las miniaturas se piden al **servidor** (pre-generadas con PDFium) en vez de calcularlas en el dispositivo.
  - Las anotaciones van como **overlay propio** (una capa por página visible), no como cientos de `PDFAnnotation` dentro del documento. Así se evita el problema conocido de zoom lento.
  - El archivo no se guarda nunca desde la app (la fuente de verdad es Calibre más nuestra base), y así se evita la ruta lenta de `write(to:)`.
- **Web:** pdf.js con `disableAutoFetch` + `rangeChunkSize` y un servidor que soporte `Range` (Calibre content server o nuestra API) permite abrir un PDF de 300 MB sin descargarlo completo. El servidor debe **linearizar** (`qpdf --linearize`) los PDF grandes al importarlos.
- **Spike recomendado (1 semana):** tres PDF de prueba (novela de 300 págs, libro técnico de 1 200 págs con diagramas y escaneo de 400 págs con OCR). Medir apertura, memoria pico, fluidez de scroll y selección en PDFKit (iPhone y Mac), pdf.js en Safari/Chrome y pdf.js dentro de `WKWebView`.

### 1.3 Selección de texto y anclaje de subrayados entre motores

**El problema:** cada motor extrae el texto de la página de forma distinta. El orden de lectura, los espacios inferidos, las ligaduras (`ﬁ` → `fi`), los guiones de fin de línea y los caracteres invisibles cambian. Por eso **un offset de caracteres calculado en PDFKit no coincide con el de pdf.js**. Lo que sí es universal:

1. **El índice de página** (base 0; el *page label* "xii" es solo para mostrar).
2. **La geometría en espacio de usuario PDF:** puntos (1/72"), con origen abajo a la izquierda del *MediaBox/CropBox*. PDFKit (`PDFPage` coordinates), pdf.js (`viewport.convertToPdfPoint`) y PDFium (`FPDFText_GetCharBox`) pueden convertir a este espacio.
3. **El texto citado** (*quote*) con algo de contexto.

**Solución propuesta: tres capas de anclaje + un mapa de texto canónico en el servidor.**

- Al importar un PDF, el servidor (PDFium) genera un **text map** por página: lista de palabras/caracteres con su `bbox` en espacio PDF y su offset dentro de un texto de página normalizado (NFKC, ligaduras expandidas y guiones de corte unidos). Se versiona (`textMapVersion`).
- El cliente, al subrayar, envía **página + quads + texto exacto + prefijo/sufijo**. El servidor *re-ancla* contra el text map (busca la cita en esa página y desempata con la geometría) y guarda los **offsets canónicos**.
- Para dibujar el subrayado en cualquier motor se usan **los quads**: son geometría pura y no dependen de la extracción de texto.
- Si los quads no cuadran (por ejemplo, porque el archivo cambió), se busca de nuevo por *quote*, como hace Hypothesis con PDF en pdf.js ([hypothesis/client](https://github.com/hypothesis/client)).

Este mismo text map es la **entrada del pipeline de LLM**: los *chunks* con número de página y `bbox` permiten citar "p. 41" y saltar al lugar exacto desde un insight.

### 1.4 Modelo de anotación portable (propuesta)

Se basa en el [W3C Web Annotation Data Model](https://www.w3.org/TR/annotation-model/) y en los [Locators de Readium](https://readium.org/architecture/models/locators/), y es compatible con el locator EPUB (CFI) que ya usa foliate-js.

```jsonc
{
  "id": "hl_01J…",
  "bookId": "calibre:1234",
  "file": {
    "format": "pdf",
    "sha256": "…",            // hash del archivo servido
    "pdfId": ["<…>", "<…>"],  // /ID del trailer PDF: sobrevive a reescrituras de metadatos
    "pageCount": 412
  },
  "target": {
    "selectors": [
      { "type": "FragmentSelector", "conformsTo": "http://tools.ietf.org/rfc/rfc8118", "value": "page=42" },
      { "type": "PdfQuadSelector",            // propio
        "pageIndex": 41,
        "box": "CropBox", "rotation": 0,       // quads normalizados a página SIN rotar
        "quads": [[72.1, 640.3, 301.8, 640.3, 72.1, 627.9, 301.8, 627.9]] },
      { "type": "TextQuoteSelector", "exact": "la memoria es un músculo",
        "prefix": "Dicho de otra forma, ", "suffix": " que se atrofia" },
      { "type": "TextPositionSelector", "start": 1834, "end": 1858,
        "textMapVersion": "pdfium-2026.1-nfkc" } // lo rellena el servidor
    ]
  },
  "body": { "color": "yellow", "note": "…", "tags": [] },
  "progression": { "page": 41, "total": 0.0995 },
  "created": "2026-10-19T…", "device": "iphone-duo"
}
```

Notas:
- **Orden de `QuadPoints`:** ISO 32000 define el orden como x1y1…x4y4 en sentido antihorario, pero Acrobat y casi todos los motores usan *TL, TR, BL, BR*. Hay que fijar *TL, TR, BL, BR* en nuestro modelo y convertir al exportar.
- **Rotación y *boxes*:** se guarda siempre en coordenadas de la página sin rotar, junto con el `CropBox` usado. Cada cliente aplica `/Rotate` al dibujar.
- **Exportación:** el modelo se puede exportar a anotación `/Highlight` dentro de una copia del PDF (con PDFKit, PyMuPDF o pikepdf) o a **XFDF** (ISO 19444-1), para abrirla en Acrobat, Preview o Zotero. Esto se hace solo al exportar; el PDF original de Calibre no se toca nunca, para no cambiar el hash ni chocar con Calibre.
- **Readwise:** `location = pageIndex + 1`, `location_type = "page"` (valores admitidos: `page`, `order`, `time_offset`), y `highlight_url` como deep link `biblioteca://book/1234?page=42&hl=…` ([Readwise API](https://readwise.io/api_deets)).
- **Ya existen precedentes:** KOReader guarda los subrayados PDF como `pos0/pos1` con página y coordenadas, y Hypothesis usa `TextQuote` + `TextPosition` sobre pdf.js. Nuestro modelo combina los dos.

### 1.5 Reflow y extracción de texto para pantallas pequeñas

Leer un A4 a dos columnas en la pantalla exterior del Duo o en un iPhone es incómodo. Hay tres estrategias, de menor a mayor esfuerzo:

1. **Recorte automático de márgenes** (*auto-crop*). El servidor calcula el `bbox` del contenido de cada página (PDFium/MuPDF) y el cliente hace zoom a esa caja. Es barato, conserva la fidelidad y lo hacen KOReader y Chunky. **Va en el MVP.**
2. **Modo columna.** Con el text map y la detección de bloques se navega columna a columna, como un "Guided View" para PDF. Es fase 2.
3. **Edición reflow.** El servidor convierte el PDF en HTML/EPUB reflowable con:
   - [Docling](https://github.com/docling-project/docling) (MIT, de IBM): maneja bien el *layout*, las tablas y el orden de lectura. **Recomendado.**
   - [Marker](https://github.com/VikParuchuri/marker): muy bueno, pero el código es GPL-3 y los pesos tienen restricciones comerciales.
   - PyMuPDF4LLM: AGPL.
   - GROBID: para artículos académicos.

   El resultado se abre en **foliate-js** como un EPUB más, con su tipografía y su tema. Cada bloque del HTML lleva `data-page` y `data-bbox` hacia el PDF original. Así, un subrayado hecho en la vista reflow se **traduce a un ancla PDF** (página + quads + quote) y aparece también en la vista original. Este es el diferenciador frente a Apple Books o Readwise.

### 1.6 OCR para PDF escaneados

| Opción | Dónde | Licencia | Comentario |
|---|---|---|---|
| **[OCRmyPDF](https://github.com/ocrmypdf/OCRmyPDF)** + **[Tesseract](https://github.com/tesseract-ocr/tesseract)** | Servidor (Linux) | MPL-2.0 / Apache-2.0 | Añade una **capa de texto invisible** al PDF (`--output-type pdf`, `-l spa+eng`, `--deskew`, `--rotate-pages`, `--skip-text` para no rehacer páginas que ya tienen texto). El resultado lo leen todos los motores sin cambios. Es la **recomendación principal**. Se guarda como un *formato derivado* en Calibre (o en un caché propio) y el original no se toca. |
| **Apple Vision** (`VNRecognizeTextRequest`; `RecognizeDocumentsRequest` desde iOS/macOS 26, que entiende párrafos, tablas y listas en 26 idiomas) | iPhone/Mac | Del sistema | Da mejor calidad que Tesseract en escaneos difíciles. Sirve para el **OCR bajo demanda en el dispositivo** (seleccionar texto en una página sin capa de texto) o como *worker* en un Mac si hay uno siempre encendido. Hay plugins comunitarios de OCRmyPDF con Apple Vision. [WWDC25 sesión 272](https://developer.apple.com/videos/play/wwdc2025/272/). |
| **Live Text** en `PDFView` | iPhone/Mac | Del sistema | Es gratis y permite copiar texto, pero no da anclas persistentes. Solo sirve como *fallback*. |
| docTR / Surya / PaddleOCR | Servidor con GPU | Varias | Son alternativas ML si Tesseract se queda corto en español antiguo o en tipografías raras. |

**Regla:** si el servidor detecta páginas sin texto (PDFium no devuelve caracteres), encola un trabajo `ocr_pdf`. El text map y el pipeline LLM se generan **después** del OCR.

### 1.7 Recomendación PDF por plataforma

| Plataforma | Motor | Notas |
|---|---|---|
| iPhone / Duo / iPad / Mac | **PDFKit** (`PDFView` configurado + `PDFPageOverlayViewProvider` para subrayados y selección propia) | En pose libro, el Duo muestra 2-up (`displayMode = .twoUp`), con una página en cada mitad alineada a la región `.division`. Si el spike muestra problemas graves con PDF pesados, el plan B es PDFium compilado como XCFramework con render propio en tiles. |
| Web | **pdf.js** (`pdfjs-dist` + `PDFViewer`) dentro de nuestro shell | Mismo modelo de anclas. No se usa el adaptador de foliate. |
| Servidor | **PDFium** (`pypdfium2`) para text map, miniaturas, auto-crop y rasterizado. **OCRmyPDF** para escaneos. **Docling** para reflow. `qpdf` para linearizar. | Si la licencia no importa (uso personal), MuPDF/PyMuPDF es una alternativa válida y más rápida. Para la versión pública conviene quedarse con PDFium. |
| Reflow | **foliate-js** sobre el EPUB/HTML derivado | Los subrayados se traducen a anclas PDF. |

---

## 2. Cómics

### 2.1 Formatos

| Formato | Contenedor | Acceso aleatorio | Comentario |
|---|---|---|---|
| **CBZ** | ZIP (normalmente *store*, sin compresión, porque JPEG/WebP ya están comprimidos) | Sí, por el *central directory* | Es el formato canónico. Lo soportan foliate-js, Komga, Kavita y todos los lectores. |
| **CBR** | RAR4/RAR5 | Sí si no es *solid*; los *solid* exigen descomprimir en secuencia | Problema de licencia (§2.9). **Se convierte a CBZ en el servidor.** |
| **CB7** | 7z | Casi siempre *solid*: abrir la página 200 obliga a descomprimir 199 | **Se convierte a CBZ.** |
| **CBT** | TAR | Secuencial, sin índice | Es raro. **Se convierte a CBZ.** |
| **CBA** | ACE | Formato obsoleto y propietario | Se ignora o se convierte con `unace` si aparece. |
| **PDF-cómic** | PDF con una imagen por página | Sí | Se detecta (cada página es una sola imagen a página completa, sin texto) y se trata como cómic. El servidor extrae las imágenes nativas (sin re-rasterizar) con PDFium/pikepdf. |
| **EPUB fixed-layout** (cómics de tiendas, Kindle Comic Creator) | EPUB con `rendition:layout pre-paginated`, `page-spread-left/right` y `page-progression-direction="rtl"` | Sí | foliate-js lo renderiza bien. Si el EPUB es "una imagen por XHTML", conviene extraerlo también a manifiesto de cómic para tener zoom y paneles. [EPUB 3.3 FXL](https://www.w3.org/TR/epub-33/#sec-fixed-layouts). |

### 2.2 Metadatos: ComicInfo.xml

- **ComicInfo.xml** es el estándar de facto (nació en ComicRack). La gobernanza actual la lleva el [Anansi Project](https://github.com/anansi-project/comicinfo): v2.0 es estable y v2.1 está en *draft*, pero Kavita y otras herramientas ya la usan ([Kavita: metadatos de cómics](https://wiki.kavitareader.com/guides/metadata/comics/)).
- **Campos clave para el lector:**
  - `Series`, `Number`, `Volume`, `Count`, `StoryArc`, `SeriesGroup`: para agrupar y ordenar. Calibre lo hace mal con cómics y nuestra base debe complementarlo.
  - `Writer`, `Penciller`, `Inker`, `Colorist`, `Letterer`, `Publisher`, `Imprint`, `LanguageISO`, `Web`, `GTIN`.
  - **`Manga`**: `Unknown | No | Yes | YesAndRightToLeft`. **Solo `YesAndRightToLeft` implica lectura RTL.**
  - **`<Pages><Page Image="n" Type="FrontCover|Story|Advertisement|…" DoublePage="true" ImageWidth ImageHeight …/>`**: indica la portada, los anuncios que se pueden saltar y **las dobles páginas**, que son críticas para el Duo.
- **Calibre:** importa CBZ/CBR y puede leer algunos metadatos (incluido ComicInfo con el plugin *Comic Metadata*), pero no conoce `Manga`, `DoublePage` ni `Pages`. **El servidor debe parsear ComicInfo.xml por su cuenta** y guardarlo en Postgres. Si falta, se infiere: imagen con `ancho > alto × 1.2` = doble página; idioma `ja` + editorial de manga = RTL sugerido, que el usuario confirma por serie.

### 2.3 Manga, dobles páginas y webtoon

- **RTL:** la paginación, el gesto de swipe, la barra de progreso y el orden de los *spreads* se invierten. Se configura por serie, con valor por defecto desde ComicInfo, y el usuario puede cambiarlo.
- **Spreads:**
  - En modo dos páginas, la portada va **sola** (offset de 1) para que los *spreads* de la página 2-3 casen bien. Hace falta un botón para "desplazar una página" cuando el escaneo viene descuadrado, igual que en Komga, Kavita, Mihon y Panels.
  - Las imágenes ya dobles (`DoublePage`) ocupan las dos mitades y no se emparejan con otra.
  - En una pantalla de una sola página, una doble página se puede ver entera (horizontal, con zoom) o **dividida en dos mitades** (izquierda/derecha según LTR/RTL). Esta opción viene de Mihon y Kavita.
- **Webtoon / manhwa:**
  - Es scroll vertical continuo de tiras muy largas, a menudo cortadas en trozos arbitrarios.
  - Se quitan los espacios entre imágenes y se usa ancho completo. Las imágenes se cargan con *downsampling* a lo ancho de la pantalla, porque una tira de 800×20 000 px sin *downsampling* tumba la memoria.
  - Se detecta por la proporción (`alto/ancho > 3`) o por `Format = Webtoon`/tag.
  - **No se parte en la bisagra del Duo**: la regla de Apple prohíbe desplazar contenido continuo a través de la bisagra.

### 2.4 Guided View / panel por panel

| Solución | Método | Estado |
|---|---|---|
| Comixology Guided View, Marvel Smart Panels | Curación manual del editor | Cerrado y no aplicable a archivos propios |
| **Panels** (iOS/Mac) | Detección ML propietaria, "experimental" | Comercial ([App Store](https://apps.apple.com/app/id1236567663)) |
| Smart Comic Reader (iOS) | Core ML | Comercial |
| **YACReader** | Heurísticas; "Guided reading" | Abierto ([anuncio](https://yacreader.com/60-guided-reading-has-landed)) |
| **[Kumiko](https://github.com/njean42/kumiko)** | OpenCV (contornos), devuelve JSON con `bbox` y orden (opción `rtl`) | AGPL. Rápido y offline; falla con viñetas sin borde o irregulares. |
| best-comic-panel-detection (YOLOv12), DeepPanel (CNN TFLite) | ML con bounding boxes | Apache-2.0 |
| **[Magi / Magiv2](https://github.com/ragavsachdeva/magi)** (Oxford VGG, CVPR 2024) | DETR: paneles, globos y personajes, **orden de lectura** y transcripción con atribución de hablante | Apache-2.0, orientado a manga ([paper](https://arxiv.org/abs/2401.10224)) |
| YOLOv8 de globos ([manga_bubbles_detect](https://huggingface.co/PSImera/manga_bubbles_detect)) | Solo globos | — |
| [Panelizer](https://github.com/hummat/panelizer) | Pipeline por niveles: CV clásico → YOLO/SAM si la confianza es baja; *overrides* manuales separados | MIT, archivado. **Es buena referencia de arquitectura.** |

**Recomendación:**
- Un trabajo de servidor `detect_panels` corre por niveles: Kumiko primero y YOLO o Magi en las páginas de baja confianza.
- El resultado se guarda en el manifiesto como rectángulos **normalizados [0..1]** con orden de lectura. Las correcciones manuales se guardan aparte y sobreviven al re-procesado.
- En el cliente, Guided View es una animación de zoom/pan sobre la página completa (`UIScrollView.zoom(to:)`), no un recorte. El usuario conserva el contexto.
- **Valor extra para insights:** Magi produce la **transcripción de los diálogos** con su hablante. Eso permite meter el cómic en el pipeline de LLM ("resume el arco", "busca dónde dice X") y subrayar diálogos como texto.
- Para OCR de globos en el dispositivo sirve Apple Vision (japonés incluido).

### 2.5 Upscaling

- Muchos CBR antiguos vienen a ~1 000 px de alto, y en un iPad Pro o en el Duo abierto se ven borrosos. Chunky popularizó un "Enhance" en el dispositivo.
- **Servidor (recomendado):** [Real-ESRGAN](https://github.com/xinntao/Real-ESRGAN) (modelo *anime*) o Real-CUGAN/[waifu2x](https://github.com/nagadomi/waifu2x) para manga en blanco y negro. Se ejecuta como trabajo opcional por libro (`upscale_comic`) y genera un derivado CBZ en WebP/AVIF. Con GPU tarda segundos por página; sin GPU es lento pero viable de noche.
- **Dispositivo:** Real-ESRGAN convertido a Core ML corre en el Neural Engine para la página visible. Es fase 3; no merece la pena hasta medir.
- Antes de cualquier ML conviene aplicar *sharpening* ligero y un buen filtro de escalado (Lanczos, que ImageIO/Core Image ya ofrecen).

### 2.6 Apps de referencia (benchmark)

| App | Qué copiar | Qué evitar |
|---|---|---|
| **[Panels](https://apps.apple.com/app/id1236567663)** (iOS/Mac) | Diseño iOS pulido; conexión a Komga, Kavita y OPDS; presets de lectura (horizontal, vertical, guided) | Guided View todavía experimental |
| **[Chunky](http://chunkyreader.com/)** (iPad) | Calidad de imagen, "Enhance", rendimiento con CBR enormes, auto-crop | Solo iPad; sin sincronización |
| **[YACReader](https://www.yacreader.com/)** | YACReaderLibrary Server → app iOS; guided reading | UI anticuada |
| **[Mihon](https://github.com/mihonapp/mihon)** (Android; sucesor de Tachiyomi) | Modos de lectura por serie (L→R, R→L, vertical, **webtoon**), dividir dobles páginas, recorte de bordes, *preload* | Solo Android |
| **[Komga](https://github.com/gotson/komga)** / **[Kavita](https://github.com/Kareadita/Kavita)** (lectores web) | Lectores web con paged, webtoon, RTL y doble página. API de páginas con conversión de formato al vuelo ([Komga image formats](https://komga.org/docs/guides/image-formats)). Implementan **OPDS-PSE**. | Son servidores completos que duplicarían Calibre |
| **KOReader** | Reflow y auto-crop de PDF, anclas de subrayados PDF | UI de e-ink |

### 2.7 Comportamiento por dispositivo

**iPhone (pantalla exterior del Duo o iPhone normal)**
- Vertical: una página con *fit width* + scroll o *fit page*. Guided View es el modo estrella aquí.
- Horizontal: una doble página entera o una página en *fit width*.
- Webtoon: scroll vertical a ancho completo.

**iPhone Duo abierto (regular × regular)**

| Pose | Cómic occidental | Manga | Webtoon |
|---|---|---|---|
| **Libro** (bisagra activa) | **Una página por mitad**, alineada con la región `.division`. Las dobles páginas se reparten: la mitad izquierda de la imagen en el panel izquierdo y la derecha en el derecho. Al imprimir, el *gutter* cae justo en la bisagra, así que **el pliegue físico coincide con el del papel**. Se pasa página hojeando el par. | Igual pero RTL: la página N va a la **derecha** y la N+1 a la izquierda; el gesto de hojear va a la inversa. | No se parte. Va en una sola mitad (la elegida) o en pantalla completa ignorando la división, porque el scroll se adapta solo. |
| **Mesa** | Arriba la página (o el panel en Guided View); abajo una tira de miniaturas, el progreso y los controles. | Igual, RTL. | Arriba la tira; abajo los controles. |
| **Abierto plano** | Doble página como en un iPad. Hay que compensar la zona `.division` aunque esté inactiva si se quiere evitar que el pliegue "corte" una viñeta; opción en ajustes. | Igual, RTL. | Scroll a ancho completo. |

**iPad**
- Vertical: una página. Horizontal: doble página con portada sola.
- Split View / Stage Manager: decidir con *size classes*, igual que en el Duo.
- Apple Pencil: no aplica a cómics salvo para marcar "clips" (§2.8).

**Mac**
- Ventana redimensionable: modo doble página por defecto si la ventana es más ancha que alta.
- Teclado: ←/→ (invertidos en RTL), espacio = siguiente panel o página, `F` = pantalla completa.
- Trackpad: *pinch* y *smart zoom* (doble toque con dos dedos para hacer zoom al panel detectado).
- Varias ventanas: dos números abiertos a la vez.

### 2.8 "Subrayados" en cómics

En un cómic no se subraya texto, sino que se guardan **clips**: un rectángulo normalizado sobre una página o un panel detectado.

```jsonc
{ "file": {"format": "cbz", "sha256": "…"},
  "target": { "selectors": [
    { "type": "FragmentSelector", "value": "page=17" },
    { "type": "ComicRegionSelector", "pageIndex": 16, "rect": [0.08, 0.52, 0.47, 0.91], "panelId": "p16-3" },
    { "type": "TextQuoteSelector", "exact": "¡Con un gran poder…" } ] } } // opcional, vía OCR/Magi
```

- El clip se envía a Readwise como highlight (`location_type = "page"`) con el texto OCR y la URL de la imagen recortada que sirve nuestro servidor.
- Al pipeline LLM llegan el texto, la página y (si hay modelo multimodal local) el recorte.
- **Progreso** de cómics y PDF: `{pageIndex, total}`. Es trivial de sincronizar y lo mapea igual cualquier cliente.

### 2.9 Servidor: streaming de páginas, miniaturas y RAR

**Normalización al importar** (trabajo `normalize_comic`):
1. Abrir el archivo con `libarchive`, `unrar` o `7z`, según el formato.
2. Ordenar las páginas con **orden natural** (`page2` < `page10`) e ignorar `__MACOSX`, `Thumbs.db` y `.DS_Store`.
3. Medir dimensiones (libvips), marcar dobles páginas y leer ComicInfo.xml.
4. Generar un **CBZ normalizado** (*store*) como formato derivado. Sobre si se reemplaza en Calibre: guardarlo como formato adicional es lo más seguro.
5. Generar miniaturas con [libvips](https://github.com/libvips/libvips): portada a 300/600 px en WebP/JPEG; tira de páginas a 160 px.
6. Escribir el **manifiesto de lectura** (JSON): `pages[{w,h,double,type}]`, `direction`, `mode` (paged/webtoon), `panels[]`.

**Streaming propio** (FastAPI):
- `GET /books/{id}/comic/manifest`
- `GET /books/{id}/comic/pages/{n}?w=1290&fmt=webp|jpeg|avif`: lee la entrada del ZIP sin descomprimir el archivo entero (lectura aleatoria del *central directory*) y la redimensiona y cachea con libvips. Se responde con `ETag` y `Cache-Control: immutable`.
- El cliente hace *prefetch* de N+1…N+3 y N−1 y guarda un caché en disco. Para **offline** descarga el CBZ completo y lo lee localmente: [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) (MIT) en Swift y [zip.js](https://github.com/gildas-lormeau/zip.js) en la web.

**OPDS-PSE** (para Panels, Chunky, KOReader y otros clientes externos):
- Es una extensión no oficial de OPDS 1.2, creada para Ubooquity y mantenida ahora en [anansi-project/opds-pse](https://github.com/anansi-project/opds-pse), con aportes de Komga y Kavita.
- Cada `entry` lleva un link con `rel="http://vaemendis.net/opds-pse/stream"`, `pse:count="N"` (si falta o es 0, clientes como Panels muestran "0 páginas") y opcionalmente `pse:lastRead`. El `href` es una plantilla con `{pageNumber}` y `{maxWidth}`.
- La spec solo admite **JPEG, GIF y PNG**, así que sin negociación de contenido no hay WebP ([discusión](https://github.com/anansi-project/opds-pse/discussions/10)).
- Nuestra API puede exponer un feed OPDS con PSE casi gratis encima del endpoint de páginas.

**¿Y Komga o Kavita?** Se pueden montar apuntando **en solo lectura** a la carpeta de la biblioteca de Calibre. Ofrecen OPDS-PSE, API de páginas y lectores web listos. Pero duplican el catálogo y el progreso (otra fuente de verdad), y sus IDs no son los de Calibre. **Recomendación:** endpoint propio mínimo como fuente de verdad. Komga queda como opción "puente" temporal si se quiere usar Panels mientras la app no está lista.

**RAR y licencias:**
- La licencia de **UnRAR** (RARLAB) permite usar el código para *descomprimir* sin pagar, pero prohíbe usarlo para recrear el compresor. **No es software libre**: Debian la pone en `non-free`, nixpkgs quitó RAR de p7zip por este motivo y no es compatible con GPL ([Wikipedia RAR](https://en.wikipedia.org/wiki/RAR_(file_format)), [UnRAR source](https://www.rarlab.com/rar_add.htm)).
- **[libarchive](https://github.com/libarchive/libarchive)** (BSD-2) lee RAR4 y **RAR5 desde la 3.4.0**, con implementación propia escrita a partir de la documentación técnica y sin código de UnRAR ([evince #1190](https://gitlab.gnome.org/GNOME/evince/issues/1190)). Limitaciones: los RAR cifrados y algunos multivolumen.
- `unar` (The Unarchiver) es LGPL. El código RAR de 7-Zip es LGPL **más la restricción de UnRAR**.
- **Conclusión:** en el servidor personal da igual cuál se use (`unrar` es el más compatible). En los **clientes**, y sobre todo en una futura app pública, **no se incluye UnRAR**: el servidor convierte a CBZ. Si hace falta CBR offline en el dispositivo, se usa libarchive.

### 2.10 ¿Basta foliate-js para CBZ y PDF?

| Aspecto | foliate-js | Necesidad del producto |
|---|---|---|
| CBZ | Lo trata como un EPUB FXL: carga el ZIP en memoria en el cliente | Streaming de páginas desde el servidor, caché y *prefetch* |
| CBR / CB7 / CBT | No los soporta | Conversión en el servidor |
| RTL / spreads | Hereda `page-progression-direction` y *spreads* de FXL. En CBZ sin metadatos no conoce `Manga` ni `DoublePage` | Configuración por serie, offset de portada y dividir dobles páginas |
| Webtoon | No lo soporta | Scroll vertical con *downsampling* |
| Guided View / zoom fino | No lo soporta. El zoom es el del WebView, no el nativo de `UIScrollView` | Animación de panel, *smart zoom* y gestos nativos |
| Memoria en iPhone | Las imágenes completas se decodifican en el proceso WebContent | ImageIO con `kCGImageSourceThumbnailMaxPixelSize` decodifica solo lo necesario |
| PDF | "Highly experimental" | Rendimiento, selección y anclas robustas → PDFKit / pdf.js |

**Veredicto:** foliate-js **no** basta como experiencia principal para cómics ni PDF. Se usa solo para EPUB (reflowable y FXL) y para la edición reflow de PDF.

---

## 3. Arquitectura de renderizado recomendada

```
                    ┌──────────── Shell SwiftUI (iOS/iPadOS/macOS) ────────────┐
                    │  protocol ReaderEngine { open, goTo(Locator), progress,  │
                    │                          selection → Annotation }        │
                    │   ├─ FoliateEngine  (WKWebView)  → EPUB, EPUB FXL, Reflow│
                    │   ├─ PDFKitEngine   (PDFView+overlay) → PDF              │
                    │   └─ ComicEngine    (SwiftUI+UIScrollView/NSScrollView,  │
                    │                      ImageIO, streaming+caché) → cómics  │
                    └──────────────────────────────────────────────────────────┘
                    ┌──────────── Web (TypeScript) ────────────────────────────┐
                    │   FoliateEngine (foliate-js) · PdfJsEngine (pdf.js)      │
                    │   ComicEngine (<img>/canvas, mismo manifiesto)           │
                    └──────────────────────────────────────────────────────────┘
                    ┌──────────── Servidor ────────────────────────────────────┐
                    │ import → detectar formato → normalizar (CBZ / OCR / qpdf)│
                    │ PDFium: text map, miniaturas, auto-crop, PDF→imágenes    │
                    │ ComicInfo + manifiesto + paneles (Kumiko→YOLO/Magi)      │
                    │ Docling: reflow EPUB/HTML con data-page/bbox             │
                    │ API: /manifest, /pages/{n}, Range para PDF, OPDS(+PSE)   │
                    │ Anotaciones: re-anclaje y offsets canónicos → LLM/Readwise│
                    └──────────────────────────────────────────────────────────┘
```

| Formato | iPhone / Duo / iPad / Mac | Web | Servidor |
|---|---|---|---|
| EPUB reflowable | foliate-js (`WKWebView`) | foliate-js | Extracción de texto para LLM |
| EPUB fixed-layout (incl. cómics) | foliate-js; si es "solo imágenes" → ComicEngine | Igual | Detección "solo imágenes" + manifiesto |
| PDF de texto | **PDFKit** + overlay propio | **pdf.js** | PDFium text map, `qpdf --linearize`, miniaturas, auto-crop |
| PDF escaneado | PDFKit (tras OCR); Vision en el dispositivo como *fallback* | pdf.js (tras OCR) | **OCRmyPDF + Tesseract** |
| PDF en reflow | foliate-js sobre el derivado | foliate-js | **Docling** → EPUB/HTML con mapeo a página/bbox |
| PDF-cómic | ComicEngine | ComicEngine | Extracción de imágenes nativas con PDFium |
| CBZ | **ComicEngine nativo** (streaming; offline con ZIPFoundation) | ComicEngine TS (streaming; offline con zip.js) | Manifiesto, miniaturas, paneles |
| CBR / CB7 / CBT | ComicEngine sobre el CBZ derivado | Igual | **Convertir a CBZ** (`unrar`/`7z`/libarchive) |
| Webtoon | ComicEngine en modo vertical (no cruza la bisagra) | Igual | Detección por proporción |

**Locator común** (sincronizado en Postgres): `{format, fileHash, kind: "epub-cfi" | "pdf" | "comic", …selectors, progression}`. Los EPUB usan CFI, los PDF página + quads + quote + offsets canónicos y los cómics página + rect. Readwise y el pipeline LLM consumen siempre `quote` + `page/location` + deep link.

## 4. Riesgos y spikes

| Riesgo | Mitigación |
|---|---|
| PDFKit con PDF pesados (memoria, zoom con anotaciones) | Overlay propio en vez de `PDFAnnotation`. Spike de una semana; plan B con PDFium en XCFramework. |
| Diferencias de texto entre PDFKit y pdf.js | Re-anclaje por quote + text map canónico del servidor; dibujo por quads. |
| El hash cambia si Calibre reescribe metadatos en el PDF | Guardar `/ID` del PDF y huellas de texto por página; re-anclar por quote. |
| Detección de paneles mediocre en manga sin bordes | Pipeline por niveles + correcciones manuales + Magi para manga. |
| Licencias (UnRAR, MuPDF AGPL, Kumiko AGPL, pesos de Marker) | Todo eso queda en el servidor personal. Para la versión pública: PDFium, libarchive, YOLO Apache y Docling MIT. |
| OPDS-PSE no admite WebP | JPEG para clientes PSE y WebP/AVIF para nuestros clientes vía `fmt=`. |
| APIs del Duo nuevas (iOS 27.1) | Decidir por *size classes*; `reservedRegions(.division)` tras `if #available`. |

## 5. Fases sugeridas

- **MVP (iPhone + servidor):** PDFKit con subrayados por overlay y modelo de anclas completo; ComicEngine con CBZ por streaming, RTL y doble página; servidor con conversión CBR→CBZ, miniaturas, manifiesto, text map PDF y OCRmyPDF.
- **Fase 2 (Duo, iPad, Mac, web):** *spreads* en la bisagra, pose mesa, pdf.js y ComicEngine web, OPDS-PSE, auto-crop.
- **Fase 3:** Guided View (Kumiko → YOLO/Magi), reflow de PDF con Docling, upscaling, transcripciones de cómic al pipeline LLM.

## 6. Fuentes

- foliate-js: <https://github.com/johnfactotum/foliate-js>
- Apple PDFKit: <https://developer.apple.com/documentation/pdfkit> · `PDFPageOverlayViewProvider`: <https://developer.apple.com/documentation/pdfkit/pdfpageoverlayviewprovider>
- Rendimiento de PDFKit con anotaciones: <https://developer.apple.com/forums/thread/802728> · DEVONthink y PDF grandes: <https://discourse.devontechnologies.com/t/devonthink-and-large-pdfs/65727> · Nutrient/PSPDFKit, memoria en iOS: <https://pspdfkit.com/guides/ios/current/getting-started/using-document-efficiently/>
- pdf.js: <https://github.com/mozilla/pdf.js> · PDFium: <https://pdfium.googlesource.com/pdfium/> · pypdfium2: <https://github.com/pypdfium2-team/pypdfium2>
- MuPDF: <https://mupdf.com/> · PyMuPDF: <https://github.com/pymupdf/PyMuPDF>
- OCRmyPDF: <https://github.com/ocrmypdf/OCRmyPDF> · Tesseract: <https://github.com/tesseract-ocr/tesseract> · Apple Vision, WWDC25 "Read documents using the Vision framework": <https://developer.apple.com/videos/play/wwdc2025/272/>
- Docling: <https://github.com/docling-project/docling> · Marker: <https://github.com/VikParuchuri/marker>
- W3C Web Annotation Data Model: <https://www.w3.org/TR/annotation-model/> · RFC 8118 (fragmentos PDF): <https://www.rfc-editor.org/rfc/rfc8118> · Readium Locators: <https://readium.org/architecture/models/locators/> · Hypothesis client: <https://github.com/hypothesis/client>
- Readwise API: <https://readwise.io/api_deets>
- KOReader: <https://github.com/koreader/koreader> · Readest: <https://github.com/readest/readest>
- EPUB 3.3 Fixed Layouts: <https://www.w3.org/TR/epub-33/#sec-fixed-layouts>
- ComicInfo (Anansi Project): <https://github.com/anansi-project/comicinfo> · Kavita, metadatos de cómics: <https://wiki.kavitareader.com/guides/metadata/comics/>
- OPDS-PSE: <https://github.com/anansi-project/opds-pse> · discusión sobre formatos: <https://github.com/anansi-project/opds-pse/discussions/10>
- Komga: <https://github.com/gotson/komga> · formatos de imagen: <https://komga.org/docs/guides/image-formats> · Kavita: <https://github.com/Kareadita/Kavita> · Mihon: <https://github.com/mihonapp/mihon>
- Panels: <https://apps.apple.com/app/id1236567663> · YACReader, guided reading: <https://yacreader.com/60-guided-reading-has-landed> · Chunky: <http://chunkyreader.com/>
- Kumiko: <https://github.com/njean42/kumiko> · Panelizer (comparativa de detección de paneles): <https://github.com/hummat/panelizer> · Magi: <https://github.com/ragavsachdeva/magi>, paper: <https://arxiv.org/abs/2401.10224> · YOLOv8 de globos: <https://huggingface.co/PSImera/manga_bubbles_detect>
- Real-ESRGAN: <https://github.com/xinntao/Real-ESRGAN> · waifu2x: <https://github.com/nagadomi/waifu2x> · libvips: <https://github.com/libvips/libvips>
- RAR y licencias: <https://en.wikipedia.org/wiki/RAR_(file_format)> · UnRAR: <https://www.rarlab.com/rar_add.htm> · libarchive: <https://github.com/libarchive/libarchive> · libarchive RAR5 (evince #1190): <https://gitlab.gnome.org/GNOME/evince/issues/1190>
- ZIPFoundation: <https://github.com/weichsel/ZIPFoundation> · zip.js: <https://github.com/gildas-lormeau/zip.js>
