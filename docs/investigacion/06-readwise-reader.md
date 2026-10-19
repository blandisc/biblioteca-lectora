# 06 · Readwise Reader (y Readwise) como backend de Biblioteca Lectora

> Investigación del 19 de octubre de 2026. Complementa [PRD v2.0 §4.6](../PRD.md) y [05 · IA e insights](05-ia-e-insights.md).
> **Pregunta:** ¿puede **Readwise Reader** (no solo Readwise v2) ser el servidor, el almacén y la capa de sync de la app? ¿Qué roles puede cumplir, qué no, y cómo se combina con iCloud/CloudKit?

> **Nota metodológica.** Desde este entorno, `readwise.io`, `docs.readwise.io`, `web.archive.org`, los proxys de Google Translate y `r.jina.ai` fallaron (DNS o proxy). La información se reunió con estas fuentes:
> 1. **Fragmentos indexados** de las páginas oficiales (`readwise.io/reader_api`, `readwise.io/api_deets`, `docs.readwise.io/changelog`, `docs.readwise.io/readwise/docs/webhooks`, las notas de versión de Reader #12 a #14), obtenidos con búsqueda web.
> 2. El **código fuente** de clientes abiertos, clonado en `scratchpad/reader-research/` y leído sin ejecutarlo:
>    - Oficiales de Readwise: `readwiseio/readwise-cli` (v0.5.10, octubre de 2026), `readwiseio/readwise-skills` y `readwiseio/readwise-mcp` (obsoleto).
>    - Conectores de terceros:
>      - `withmarfa/marfa-connectors`: conector bidireccional de Reader, **15–18 de octubre de 2026**, verificado contra una cuenta real.
>      - `Endle/readwisereader`: plugin de KOReader, 12 de octubre de 2026, que **crea subrayados en Reader**.
>      - `CaseyRo/mcp-readwise` (septiembre de 2026), `zacharytamas/readwise-cli` (enero de 2026), `arnaldo-delisio/readwise-mcp-enhanced`, `joshbeckman/readwise-ruby`, `rwxd/pyreadwise` y `edwinhu/workflows`, que incluye una copia resumida de `reader_api`.
>
> **Leyenda:** ✅ confirmado, con la fuente indicada. ⚠️ sin verificar: viene de una sola fuente de terceros, es una inferencia, o hay que probarlo con un token real (ver §11, *Spike R*).

---

## 0. Resumen ejecutivo (respuestas sí/no)

| Pregunta | Respuesta |
|---|---|
| ¿Reader puede ser **el almacén de los libros** (EPUB/PDF/cómics)? | **No como fuente de verdad.** No hay subida de archivos por API (solo `url` o `html`). Los cómics (CBZ/CBR) no son un formato de Reader. No hay campos para series, identificadores ni metadatos propios. Y todo depende de una suscripción. ✅ |
| ¿Se puede **descargar el EPUB/PDF original** que está en Reader? | **Sí.** `GET /api/v3/list/?withRawSourceUrl=true` agrega `raw_source_url`: un enlace firmado a S3 (`readwise-assets.s3.amazonaws.com`) **válido 1 hora**, vacío en documentos no distribuibles (p. ej., vistas previas de Wisereads). ✅ También existe la exportación completa en ZIP desde la UI. ✅ |
| ¿Se puede **subir** un EPUB/PDF por API? | **No.** ✅ Las alternativas son: `save` con una `url` descargable (⚠️ una URL firmada temporal de iCloud *podría* funcionar, pero es frágil); la dirección de correo `…@library.readwise.io` con el EPUB adjunto ✅; o la subida manual en la app o la web de Reader (hasta 500 MB) ✅. |
| ¿Se pueden **crear subrayados dentro de un documento de Reader** por API? | **Sí, desde el 18 de septiembre de 2026.** `POST /api/v3/save/` con `parent_id` + `content` (el pasaje), y opcionalmente `notes` y `tags`. Reader **ancla por texto**: si no encuentra el pasaje, responde 400. ✅ **Esto corrige el PRD §4.6 y el doc 05.** |
| ¿Se pueden editar o borrar subrayados de Reader? | **Sí, desde el 25 de septiembre de 2026.** `PATCH /api/v3/update/<id>/` acepta **solo** `notes` y `tags`. `DELETE /api/v3/delete/<id>/` también funciona. El texto del pasaje **no** se puede editar. ✅ |
| ¿Hay **posición exacta** de los subrayados (offsets, CFI, rangos)? | **No documentada.** La API devuelve `content` (texto) y `parent_id`. Hay campos `highlight_offset` (entero) y `highlight_location` (cadena) que nadie documenta ⚠️. El autor del plugin de KOReader confirma que *"la API de Reader no da los datos de ubicación"* para sync bidireccional. ✅ |
| ¿`reading_progress` se puede **leer**? | **Sí.** Es un float de 0 a 1 por documento, más `first_opened_at`, `last_opened_at` y `last_moved_at`. ✅ |
| ¿`reading_progress` se puede **escribir**? | **No hay soporte documentado.** Marfa lo declara explícitamente *read-only*. Un cliente lo intenta por `PATCH` sin evidencia de que funcione ⚠️. Sí se pueden escribir `seen` y `location` (new/later/shortlist/archive). ✅ |
| ¿Los subrayados de Reader llegan a Readwise v2? | **Sí.** Además, **el `id` del subrayado en Reader = `external_id` del subrayado en el export v2**, y **el `external_id` del libro v2 = `id` del documento en Reader** (con `source: "reader"`). ✅ (verificado en vivo por Marfa) |
| ¿Hay **webhooks**? | **Sí.** Están en Export → Webhooks, con eventos `readwise.highlight.created`, `reader.any_document.created` (más variantes de feed y no feed) y uno de etiqueta añadida a un subrayado (enero de 2026) ✅. Para recibirlos hace falta un **endpoint HTTPS público**: sin servidor no sirven, así que **usaremos polling**. |
| ¿Kindle se puede casar con nuestros EPUB? | **Sí, con heurística.** En v2 el libro trae `source: "kindle"`, `asin`, `title`, `author`, `readable_title` y `cover_image_url`. Los subrayados traen `text`, `location` y `location_type` (en Kindle, ⚠️ `"location"`). Se casa por ASIN (Calibre suele guardar `amazon:` en `identifiers`) o por título y autor normalizados, y se re-ancla **buscando la cita** en el texto del EPUB. |
| Precio | Reader **solo** viene con Readwise **Full**: ⚠️ ~US$9.99/mes en plan anual o ~US$12.99/mes en plan mensual (fuentes de terceros). Lite (~US$5.59) **no** incluye Reader. |

**Recomendación en una línea:** **iCloud/CloudKit sigue siendo la fuente de verdad** para archivos, anclas (CFI) y progreso. **Reader** funciona como (a) **fuente de importación** (originales vía `raw_source_url`, artículos vía HTML), (c) **espejo parcial** (subrayados en ambos sentidos para libros vinculados; progreso solo de Reader hacia nosotros) y (d) **destino de subrayados**. **Readwise v2** queda para el export de todo (Kindle incluido, con borrados) y para los subrayados de libros que no están en Reader.

---

## 1. Reader API v3: superficie completa

Base: `https://readwise.io/api/v3/`. Autenticación: `Authorization: Token <token>`, con el token de `readwise.io/access_token`. El token se valida con `GET https://readwise.io/api/v2/auth/`, que responde 204. ✅ [reader_api; edwinhu/reader-api.md; código de readwise-mcp-enhanced]

### 1.1 `POST /save/`: crear un documento (o un subrayado, ver §3)

| Parámetro | Tipo | Notas | Estado |
|---|---|---|---|
| `url` | string, **obligatorio** | Identidad del documento. Si ya existe, responde **200** con el `id` existente y no duplica; si es nuevo, **201**. | ✅ [fragmento oficial; issue #208 de Marfa] |
| `html` | string | Contenido propio. Sin `html`, Reader *scrapea* la `url`. | ✅ |
| `should_clean_html` | bool, por defecto `false` | Solo aplica con `html`. Con `true`, Reader limpia el HTML y extrae título y autor. | ✅ [fragmento oficial] |
| `title`, `author`, `summary`, `published_date` (ISO 8601), `image_url` | string | Metadatos que sobrescriben los detectados. | ✅ [zacharytamas, readwise-ruby, pyreadwise] |
| `location` | `new` \| `later` \| `archive` \| `feed` | Algunos clientes aceptan `shortlist` en listas, pero no al guardar. | ✅ / ⚠️ shortlist |
| `category` | `article`, `email`, `rss`, `highlight`, `note`, `pdf`, `epub`, `tweet`, `video` | Si falta, se adivina por la URL ("normalmente article"). Para que Reader trate el contenido como PDF o EPUB **hay que pasarla**. | ✅ [fragmento oficial] |
| `saved_using` | string | Nombre de la app que guarda, p. ej. `"koreader"`. Nosotros: `"biblioteca-lectora"`. | ✅ [KOReader, zacharytamas] |
| `tags` | string[] | | ✅ |
| `notes` | string | Nota del documento. | ✅ [CLI y MCP oficiales] |
| `language` | string | **Nuevo en agosto de 2026** ("set a document's language when saving"). | ✅ [Update #14] |
| `markdown` | string | Lo expone `reader_create_document` del **MCP oficial**. No está claro si existe en REST. | ⚠️ |
| `parent_id` + `content` | | Crea un **subrayado** (§3). | ✅ |

- **Límite de tamaño de `html`:** no encontré ninguna cifra. ⚠️ Hay que probarlo con un libro entero.
- **Subida de archivos (multipart):** **no existe** ✅. Lo dicen el README de CaseyRo/mcp-readwise ("verificado contra la doc v3 y el CLI oficial") y Marfa ("original-file upload remain read-only"). Ni el CLI ni el MCP oficiales tienen una herramienta de subida ✅.
- **¿Sirve una `url` cualquiera, como una URL firmada temporal de CloudKit?** ⚠️ Técnicamente Reader descarga lo que haya en la `url`, y con `category=pdf|epub` debería procesarlo como archivo. **Problemas:**
  1. La descarga es asíncrona: si la URL expira antes, falla.
  2. La URL temporal queda como **identidad** del documento: la deduplicación por URL se rompe y el enlace queda guardado en Readwise.
  3. Los `downloadURL` de CloudKit Web Services son firmados y de vida corta ⚠️.
  4. Los enlaces "compartir" de iCloud Drive llevan a una página HTML, no al archivo.

  **Conclusión:** sirve como experimento, no como diseño. Para mandar un EPUB a Reader, lo fiable es el **correo** a `<alias>@library.readwise.io` con el adjunto. Desde iOS/macOS se hace con `MFMailComposeViewController` o el menú Compartir, y el usuario pulsa *Enviar* ✅ [CaseyRo README]. La otra vía es la subida manual en Reader (hasta 500 MB) ✅ [docs "Adding Content"].

### 1.2 `GET /list/`: listar documentos (y subrayados y notas)

| Parámetro | Notas | Estado |
|---|---|---|
| `id` | Un documento concreto. | ✅ |
| `updatedAfter` | ISO 8601. Es la base de la sync incremental (existe desde agosto de 2023). | ✅ |
| `location` | `new`, `later`, `shortlist`, `archive`, `feed` | ✅ |
| `category` | La misma lista que en `save`. `category=epub` devuelve solo libros, y `highlight`/`note` solo hijos. | ✅ [fhjgch #2] |
| `tag` | Repetible, **hasta 5, con lógica AND**. `?tag=` (vacío) devuelve los documentos sin etiqueta. | ✅ [edwinhu] |
| `limit` | 1–100 (100 por defecto). | ✅ [edwinhu] / ⚠️ |
| `pageCursor` | Viene de `nextPageCursor`. | ✅ |
| `withHtmlContent` | Agrega `html_content`. Es **lento**. | ✅ |
| `withRawSourceUrl` | Agrega `raw_source_url` (S3 firmado, 1 h). | ✅ [fragmento oficial; Marfa] |
| `seen` | Lo expone el MCP oficial (`seen=false`). En REST no está claro. | ⚠️ |

**Respuesta:** `{ count, nextPageCursor, results: [...] }`.

**Campos de cada resultado.** Se unieron los tipos de Marfa (`shared/readwise/src/reader.ts`, validados contra respuestas reales), la lista `response_fields` del MCP oficial y readwise-ruby:

| Campo | Tipo | Comentario |
|---|---|---|
| `id` | string (ULID) | |
| `url` | string | URL de Reader (`https://read.readwise.io/read/<id>`) ⚠️ formato exacto |
| `source_url` | string | URL original. Si guardaste un archivo, ⚠️ puede ser la URL de subida. |
| `title`, `author`, `summary`, `site_name`, `image_url`, `language` | string | |
| `source` | string | Origen, p. ej. `web` o `"Reader RSS"`. |
| `category` | string | `article`, `epub`, `pdf`, `highlight`, `note`, … |
| `location` | string | new/later/shortlist/archive/feed |
| `tags` | **objeto** `{clave: {name, type, created}}`. Algunos clientes lo ven como arreglo. | ⚠️ forma variable |
| `notes` | string | Nota del documento o del subrayado. |
| `content` | string | En **subrayados y notas**: el texto del pasaje o de la nota. |
| `parent_id` | string \| null | En subrayados: el documento. En notas: el subrayado. |
| `word_count` | int | |
| `reading_time`, `listening_time` | string | |
| `reading_progress` | float 0–1 | |
| `first_opened_at`, `last_opened_at`, `saved_at`, `last_moved_at`, `created_at`, `updated_at`, `published_date` | string (o número en `published_date`) | `first_opened_at = null` ⇒ "no visto". |
| `highlight_offset` | int | ⚠️ Sin documentar. Probablemente un orden u offset dentro del documento. Hay que medirlo. |
| `highlight_location` | string | ⚠️ Sin documentar. |
| `html_content` | string | Solo con `withHtmlContent`. |
| `raw_source_url` | string | Solo con `withRawSourceUrl`. |
| `is_deleted` | bool | Aparece en `response_fields` del MCP. ⚠️ En REST, Reader **no informa borrados** (Marfa). |

### 1.3 `PATCH /update/<id>/`: actualizar

Los campos que se omiten no cambian ✅ (fragmento oficial). La respuesta trae solo `{id, url}` ✅ [Marfa #208], así que **conviene volver a leer el documento** después de escribir.

| Campo escribible (documento) | Estado |
|---|---|
| `title`, `author`, `summary`, `published_date`, `image_url`, `language`, `category` | ✅ [Marfa #208, zacharytamas] |
| `location` (new/later/archive/feed; un valor inválido se reemplaza en silencio) | ✅ |
| `seen` (true/false; pone o borra `first_opened_at`/`last_opened_at`) | ✅ [Update #14; fhjgch #2] |
| `tags` (**reemplaza la lista completa**; `[]` la vacía) | ✅ |
| `notes` (`""` la borra) | ✅ |
| `reading_progress` | ❌ No documentado. Marfa: "progress writes … remain read-only". CaseyRo manda `PATCH {reading_progress}` sin verificarlo ⚠️ |
| Cuerpo (`html`) | ❌ "Replacing a document's body" no se puede ✅ [Marfa] |

### 1.4 `PATCH /bulk_update/`

Agosto de 2026. Recibe `{"updates": [{"id": ..., "location"|"seen"|"category"|"tags"...}]}` con **hasta 50 documentos por llamada**. Límite de **20/min**. Devuelve **207** si algunos fallan. ✅ [Update #14; fragmento oficial; Marfa #208]

### 1.5 `DELETE /delete/<id>/`

Responde 204 (y 404 si ya no existe). Funciona con documentos **y con subrayados** (desde el 25 de septiembre de 2026). ✅ [changelog; Marfa]

### 1.6 `GET /tags/`

Responde `{count, nextPageCursor, results: [{key, name}]}` y es paginado. ✅

### 1.7 Endpoints "bulk" y exportación

- `bulk_update` (arriba) ✅.
- La **exportación de documentos** a un ZIP de Markdown es asíncrona y delta (`since_updated`). La exponen el MCP y el CLI oficiales (`reader_export_documents` → `reader_get_export_documents_status` → `download_url`) ✅. ⚠️ Es Markdown, **no** los archivos originales.
- Desde la UI, **"Export Full Files and Articles"** genera un ZIP con **todos los archivos subidos** y el contenido de los artículos, y lo manda por correo ✅ [docs "Exporting"]. Sirve para una migración puntual, no para sync.

### 1.8 Límites de uso

| Endpoint | Límite | Estado |
|---|---|---|
| Base (`list` y demás) | **20 req/min por token** | ✅ |
| `save` y `update` | **50 req/min** | ✅ (fragmento oficial y changelog de febrero de 2025) |
| `bulk_update` | 20/min (y comparte cuota con `move` en el MCP) | ✅ [Marfa #208; skill del MCP] |
| 429 | Trae `Retry-After` (en segundos) | ✅ |

Para una sola persona, con sync incremental por `updatedAfter`, sobra.

### 1.9 Webhooks

Existen ✅ [docs.readwise.io/readwise/docs/webhooks; Update #13, diciembre de 2025; changelog]. Se configuran en Export → Webhooks y cada uno lleva un `secret` para verificarlo.

- **Eventos confirmados:** `readwise.highlight.created`, `reader.any_document.created` (más variantes de feed y no feed) y "tag añadido a un subrayado" (enero de 2026).
- **Eventos mencionados sin nombre exacto ⚠️:** "document finished" y "highlight modified".
- **Plan:** ⚠️ un blog lo pone en un plan "Advanced".
- **Para nosotros:** requieren una URL pública que reciba un POST, y **no tenemos servidor**. Se usa *polling* con `updatedAfter` al abrir la app y cada ~15 min en primer plano, más `BGAppRefreshTask` en iOS y un intervalo en el Mac. Si algún día hay un relay mínimo (una función *serverless*), los webhooks podrían despertar a los dispositivos con un push silencioso. Eso queda fuera del alcance de "sin servidor".

---

## 2. Archivos originales y contenido HTML

### 2.1 Descargar el original (EPUB/PDF)

- **API:** `withRawSourceUrl=true` → `raw_source_url`, un enlace S3 firmado de 1 hora ✅. Marfa lo usa en producción: solo acepta el host `readwise-assets.s3.amazonaws.com`, no manda credenciales a S3, y cuando el enlace caduca lo pide de nuevo con `list?id=` ✅.
  - Contradicción: `pdf2reader` dice que "la API no devuelve los bytes de los PDF subidos". Probablemente es anterior a `withRawSourceUrl` ⚠️. Hay que comprobarlo en el Spike R con un EPUB **subido** (no guardado desde una URL).
- **`source_url`:** en documentos guardados desde la web es la URL original, y puede ser descargable. En archivos subidos ⚠️.
- **UI:** la exportación completa en ZIP ✅. No encontré un botón "descargar original" por documento ⚠️.
- **Wisereads** y otros documentos "no distribuibles": `raw_source_url` vacío ✅.

### 2.2 `html_content` de un EPUB

- Reader convierte el EPUB en su propio HTML. Hasta junio de 2025 trataba los EPUB "como artículos muy largos" y cargaba el libro entero en memoria. Desde **EPUBs v2** carga capítulo por capítulo y conserva por defecto los estilos del EPUB ✅ [Update #12, junio de 2025; Update #9, julio de 2024].
- Por API, `html_content` debería traer el libro completo como **un solo HTML** procesado ⚠️ (sin confirmar si viene entero o solo el primer capítulo). El MCP devuelve Markdown (`reader_get_document_details`) ✅.
- **Calidad para nosotros:** ese HTML se pierde la estructura del EPUB (spine, `nav`, CSS e IDs originales). **Los CFI calculados sobre él no valen para el EPUB original.**
- **Conclusión:** para libros se usa **siempre el original** (`raw_source_url`) e `html_content` solo para artículos web.

---

## 3. Subrayados en Reader

### 3.1 Cómo aparecen

- Son documentos con `category: "highlight"`, `content` = el pasaje, `parent_id` = el documento, más `notes`, `tags`, `created_at` y `updated_at` ✅.
- Las notas sueltas son `category: "note"` con `parent_id` = el subrayado ✅ [Marfa: `foldReaderNotes`].
- Desde el 25 de septiembre de 2026, el listado **trae la nota y las etiquetas** del subrayado (antes la nota venía vacía) ✅.
- **Anclaje:** solo el texto, más los campos opacos `highlight_offset` y `highlight_location` ⚠️. **No hay CFI, offsets de caracteres documentados ni número de página.** El plugin de KOReader lo confirma: *"two way highlight syncing is not possible as the Readwise Reader API does not provide the location data"* ✅.

### 3.2 Crear subrayados en un documento de Reader

`POST /api/v3/save/` con este cuerpo ✅ [changelog del 18 de septiembre de 2026; código del plugin de KOReader y de Marfa]:

```json
{ "parent_id": "<id del documento>", "content": "<pasaje exacto>", "notes": "…", "tags": ["…"], "saved_using": "biblioteca-lectora" }
```

- Reader **busca el pasaje en su copia** del documento. Si no lo encuentra, o si `parent_id`/`content` no son válidos → **400**. Si el documento no existe → **404**. Antes de la corrección, este mismo request creaba un "artículo fantasma" ✅.
- `notes` en blanco → 400 (no hay que mandarlo vacío) ✅ [KOReader].
- El MCP oficial expone `reader_create_highlight(document_id, html_content, note, tags)`, donde *"html_content must match the document's HTML exactly"* ✅. Es otra interfaz sobre el mismo mecanismo de **coincidencia de texto**.
- **Riesgos de la coincidencia:** espacios, guiones blandos, comillas tipográficas, ligaduras y saltos entre párrafos. Un pasaje que cruza dos párrafos ⚠️ podría fallar. Por eso: normalizar antes de enviar y, si sale 400, **enviarlo por v2** (lo mismo que hace KOReader).
- **No hay idempotencia por clave**: reintentar puede duplicar. Marfa, ante una respuesta perdida, relista y acepta "exactamente un objeto nuevo que coincida". Nosotros guardamos el `id` devuelto y deduplicamos por (`parent_id`, texto normalizado).

### 3.3 Relación con Readwise v2

- Los subrayados de Reader **fluyen a Readwise** (Daily Review, export) ✅ [docs "How are Readwise and Reader related?"; Marfa].
- **IDs** ✅ (Marfa, comprobación de solo lectura contra una cuenta real):
  - `id` del subrayado en Reader == `highlights[].external_id` en `/api/v2/export/`.
  - Libro v2 con `source: "reader"`: `external_id` == `id` del documento en Reader, y `source_url` contiene el ULID (CaseyRo extrae el ULID de `source_url` para cruzarlos).
- **Borrados:** Reader **no informa** los documentos borrados. El **export v2 con `includeDeleted=true`** sí informa `is_deleted` en libros y subrayados ✅ [Marfa]. Lo usamos para propagar los borrados hechos en Reader.
- El texto del pasaje puede diferir un poco entre Reader y el export. Marfa guarda el de Reader como canónico y el del export en `readwise_text` ✅.

---

## 4. Progreso de lectura

| Aspecto | Estado |
|---|---|
| Lectura de `reading_progress` (float 0–1, fracción del documento) | ✅ |
| Granularidad | Un solo número por documento. No hay posición (CFI, página ni capítulo). En PDF suele quedarse en ~0.9 al terminar (CaseyRo usa ≥ 0.9 como "terminado") ✅ (dato empírico de un tercero) |
| Escritura de `reading_progress` | ❌ No documentada. Marfa la trata como imposible. ⚠️ Hay que probarlo en el Spike R (`PATCH` y releer). |
| Señales escribibles | `seen` ✅, `location` (p. ej. `archive` al terminar) ✅ |
| Fechas útiles | `first_opened_at` (empezó), `last_opened_at`, y `last_moved_at` si está en `archive` (terminó) ✅ (heurística, fhjgch #2) |

**Consecuencia:**
- **De Reader a nosotros:** si el usuario leyó en Reader, abrimos el EPUB en la posición ≈ `reading_progress × longitud` (por caracteres del spine) y le avisamos que la posición es aproximada.
- **De nosotros a Reader:** no se puede espejar la posición. Solo se marca `seen` y se archiva al terminar.

---

## 5. Readwise v2 (`/api/v2/`): superficie completa

Autenticación: `Authorization: Token …`; `GET /auth/` → 204 ✅.

| Endpoint | Uso | Estado |
|---|---|---|
| `POST /highlights/` | Crear en lote: `{"highlights":[{text*, title, author, image_url, source_url, source_type, category (books\|articles\|tweets\|podcasts), note, location, location_type, highlighted_at, highlight_url}]}`. `text` y `note` admiten hasta **8191 caracteres**. | ✅ [fragmento api_deets; tipos de readwise-mcp-enhanced y readwise-go] |
| Deduplicación | Por **título + autor + texto + `source_url`** (cuenta los null). Reenviar con el mismo **`highlight_url`** **actualiza** el subrayado. | ✅ [fragmento api_deets] |
| `location_type` | `page`, `location`, `none`, `order` (por defecto), `offset`, `time_offset` | ✅ [fragmento api_deets] |
| `GET /highlights/` | Listado paginado (`page`, `page_size` ≤ 1000, `book_id`, `updated__lt/gt`, `highlighted_at__lt/gt`) | ✅ |
| `GET/PATCH/DELETE /highlights/<id>/` | Detalle, edición (texto, nota, color, ubicación, etiquetas) y borrado | ✅ [readwise-ruby, skill del MCP: `readwise_update_highlight` con `color`] |
| `GET/POST /highlights/<id>/tags/`, `PATCH/DELETE …/tags/<tag_id>` | Etiquetas de un subrayado | ✅ [readwise-ruby] |
| `GET /books/` y `/books/<id>/` | Fuentes (`category`, `source`, `updated__*`, `last_highlight_at__*`) | ✅ |
| `/books/<id>/tags/` | Etiquetas del libro | ⚠️ |
| **`GET /export/`** | `updatedAfter`, `ids` (user_book_id separados por coma), `includeDeleted`, `pageCursor`. Es **la** vía de sync incremental (primero todo, luego `updatedAfter`). | ✅ |
| `GET /review/` | Daily Review: `review_id`, `review_url`, `review_completed`, `highlights[]` | ✅ |
| Completar la Daily Review | Por API pública desde agosto de 2026 | ✅ [Update #14] / ⚠️ ruta exacta |
| Colores | yellow, blue, pink, orange, green, purple | ✅ [skill del MCP] |
| Límites | ⚠️ ~240/min en general y **20/min** en los listados `highlights`/`books`; `Retry-After` en 429. Otra fuente dice 60/min. Hay que verificarlo. | ⚠️ |

**Campos del export** ✅ (tipos de Marfa `export.ts`, fixture real de readwise-ruby):
- **Libro:** `user_book_id`, `is_deleted`, `title`, `readable_title`, `author`, `source`, `cover_image_url`, `unique_url`, `category`, `document_note`, `summary`, `readwise_url`, `source_url`, `external_id`, `asin`, `book_tags[]`, `highlights[]`.
- **Subrayado:** `id`, `is_deleted`, `text`, `note`, `color`, `location`, `end_location`, `location_type`, `highlighted_at`, `created_at`, `updated_at`, `external_id`, `url`, `readwise_url`, `book_id`, `tags[]`, `is_favorite`, `is_discard`.

---

## 6. Subrayados de Kindle: cómo vienen y cómo casarlos con nuestros EPUB

### 6.1 Cómo vienen

- Libro v2 con `source: "kindle"` ✅ [tests de CaseyRo], `category: "books"`, `asin` (p. ej. `B07HDSHP7N`, fixture real) ✅, más `title`, `readable_title` (sin subtítulo), `author` y `cover_image_url` (Amazon).
- Subrayados con `location` (número de *location* de Kindle) y `location_type: "location"` ⚠️ (es un valor válido del enum ✅, pero no vi un ejemplo real de Kindle). `end_location` puede venir ✅ (campo existente).
- **Límite de exportación por copyright:** Amazon corta el texto exportable de algunos libros, así que hay subrayados truncados ✅ [docs de Readwise, citados en la búsqueda].
- Readwise también importa el **notebook de Kindle** por archivo (corregido el 21 de agosto de 2026) ✅.

### 6.2 Algoritmo de emparejamiento libro ↔ libro

1. **ASIN exacto:** en la migración desde Calibre, guardar `identifiers` (Calibre suele tener `amazon:` y `mobi-asin`) ⚠️ (depende de la biblioteca del usuario). Si coincide → confianza 1.0.
2. **ISBN:** v2 no trae ISBN ⚠️. Se podría resolver ASIN → ISBN con un `MetadataProvider` (Open Library o Google Books), pero el ASIN de Kindle no es un ISBN, así que la confianza es media.
3. **Título y autor normalizados:** minúsculas, sin acentos (NFKD), sin subtítulo (usar `readable_title`), sin artículos iniciales, autores ordenados y con iniciales normalizadas. Similitud Jaro-Winkler ≥ 0.92 en título y coincidencia de apellido.
4. **Confirmación por contenido:** se toman 3 subrayados al azar del libro Kindle; si ≥ 2 aparecen en el texto del EPUB candidato → match. Es lo que resuelve los empates de ediciones.
5. Lo que no case queda como "Libro de Kindle sin archivo" (solo subrayados), con la opción de vincularlo a mano.

### 6.3 Re-anclaje por cita (Kindle, Apple Books o Reader → CFI en nuestro EPUB)

1. Normalizar el texto del EPUB por capítulo del spine y la cita: NFKC, comillas y guiones unificados, sin guiones blandos (U+00AD), espacios colapsados y ligaduras expandidas. Hay que mantener un **mapa de offsets normalizados → offsets DOM** para volver al CFI.
2. **Búsqueda exacta** (`range(of:)` o un autómata Aho-Corasick para el lote completo).
3. Si falla, **búsqueda aproximada**: semillas de n-gramas (los primeros y últimos ~30 caracteres), luego Levenshtein acotado en una ventana, y aceptar si la distancia es ≤ 10 % de la longitud. Para citas truncadas (límite de Amazon), anclar el prefijo y marcar el subrayado como `truncated`.
4. **Desempate y orden:** usar `location` (Kindle) u `order` como **restricción monótona**: los subrayados deben quedar en el mismo orden en el libro. La fracción `location / location_max` da una ventana aproximada para buscar primero.
5. Guardar `anchorConfidence` (exacta / aproximada / sin ancla) y, si queda sin ancla, mostrar el subrayado en la lista del libro sin pintarlo en el texto.
6. El mismo procedimiento sirve para **subrayados hechos en Reader** sobre un libro vinculado: Reader solo nos da el texto.

---

## 7. MCP y CLI oficiales, Ghostreader y feed

- **MCP oficial alojado:** `https://mcp2.readwise.io/mcp`. Usa OAuth con *dynamic client registration* en `readwise.io/o/.well-known/oauth-authorization-server`, scopes `openid read write`, o `Authorization: Token`. Salió de beta en 2026 ✅ [código de readwise-cli; README de readwise-skills; Update #14]. El MCP local antiguo (`@readwise/readwise-mcp`) está **obsoleto** ✅.
- **Herramientas (las del CLI son las mismas, con guiones)** ✅ [skills oficiales]:
  - **Documentos:** `reader_search_documents` (híbrida semántica + texto, con filtros), `reader_list_documents` (`response_fields`), `reader_get_document_details` (Markdown), `reader_create_document`.
  - **Subrayados de Reader:** `reader_get_document_highlights`, `reader_create_highlight`, `reader_add_tags_to_highlight`, `reader_remove_tags_from_highlight`, `reader_set_highlight_notes`.
  - **Organización y exportación:** `reader_move_documents` (≤ 50), `reader_bulk_edit_document_metadata`, `reader_list_tags`, `reader_add_tags_to_document`, `reader_remove_tags_from_document`, `reader_export_documents`, `reader_get_export_documents_status`.
  - **Readwise:** `readwise_search_highlights` (vectorial), `readwise_list_highlights`, `readwise_create_highlights`, `readwise_update_highlight`, `readwise_delete_highlight`, `readwise_get_daily_review`.
  - **No hay** herramientas de subida de archivos ni de escritura de progreso ✅.
- **CLI oficial** (`@readwise/cli`, código abierto): es un envoltorio del MCP que descubre las herramientas dinámicamente; incluye un modo *readonly* ✅.
- **Uso para la app:**
  - La **búsqueda semántica** del MCP (`reader_search_documents`, `readwise_search_highlights`) no tiene equivalente REST documentado ⚠️. Una app Swift podría hablar MCP por HTTP (JSON-RPC) con OAuth, pero es una interfaz pensada para agentes y no está garantizada como API estable ⚠️.
  - Para el producto usamos REST v2/v3; el MCP queda para Claude u otros agentes del usuario.
- **Ghostreader:** es la IA de Reader (Global Ghostreader en agosto de 2026: chat con citas sobre toda la biblioteca). **No tiene API pública** ⚠️ (no encontré ninguna). Nuestra IA sigue siendo local (doc 05).
- **Feed:** con `location=feed` se listan RSS, newsletters y digests ✅. Una pestaña opcional de "Artículos de Reader" en nuestro lector podría mostrarlos, pero no es el foco.

---

## 8. Términos de uso y precio

- **ToS:** no pude abrir `readwise.io/tos` ⚠️. Lo que sí se sabe:
  - El token es **personal**: cada usuario usa el suyo, con su propia suscripción ✅.
  - Integraciones como Obsidian usan un flujo de autenticación propio (`/api_auth?token=…&service=obsidian`) ✅ (código del plugin), que parece reservado a socios.
  - Existe un servidor OAuth (`readwise.io/o/`) usado por el MCP y el CLI ✅. ⚠️ No sabemos si sus tokens valen contra REST v2/v3, ni si se permite registrar clientes de terceros.
- **Personal:** sin riesgo práctico. Es el uso para el que existe la API.
- **Pública:**
  1. Pedir el token al usuario (como KOReader y Obsidian) o pedir a Readwise acceso OAuth (`api@readwise.io`).
  2. No hacer que la app **dependa** de Readwise: debe funcionar sin él (App Store, guideline 3.1: no vender ni desbloquear funciones por una suscripción externa).
  3. Respetar los límites de uso.
  4. No usar la marca Readwise como si fuera un producto oficial.
  5. **Privacidad:** subir libros del usuario a Reader los copia a los servidores de Readwise, y debe ser opt-in explícito.
- **Precio (2026, fuentes de terceros ⚠️):** Readwise **Full** (incluye Reader) cuesta ~US$9.99/mes en plan anual o ~US$12.99/mes en plan mensual; **Lite** (~US$5.59/mes, solo Readwise) **no incluye Reader**. Hay 30 días de prueba y 50 % de descuento académico. **La API de Reader exige Full.**

---

## 9. Arquitectura recomendada

### 9.1 ¿Qué papel puede jugar Reader?

| Rol | ¿Viable? | Cómo / por qué no |
|---|---|---|
| **(a) Fuente de documentos para importar** | ✅ **Sí** | `list?category=epub\|pdf&withRawSourceUrl=true` → se descarga el original desde S3 en < 1 h → entra al pipeline normal de importación (metadatos, portada, CloudKit). Los artículos llegan por `html_content` (o se leen "en vivo" sin importarlos). Las etiquetas de Reader pasan a ser etiquetas de la biblioteca. |
| **(b) Almacén de libros** | ❌ **No** (como mucho, una copia secundaria) | No hay subida por API. Los enlaces de descarga duran 1 h. Los cómics no entran. No hay metadatos de biblioteca (series, identificadores, columnas propias, colecciones). La deduplicación es por URL. Depende de la suscripción. Si se reemplaza un archivo, Reader no puede cambiar el cuerpo. **Sigue iCloud.** |
| **(c) Sync para alternar Reader ↔ nuestra app** | ⚠️ **Parcial** | **Subrayados:** sí en ambos sentidos para libros **vinculados** (crear por texto, editar notas y etiquetas, borrar, leer con `updatedAfter`). Los borrados se detectan con el export v2. **Progreso:** solo Reader → app (fracción aproximada). De app → Reader solo `seen` y `archive`. **No hay** sync de posición exacta en ningún sentido. |
| **(d) Destino de subrayados** | ✅ **Sí** | Libro vinculado a un documento de Reader → `POST /v3/save` con `parent_id` (aparece **dentro** del libro en Reader y fluye a Readwise). Si no está vinculado, o Reader devuelve 400 → `POST /v2/highlights` con `highlight_url` (enlace de vuelta a la app). |

### 9.2 Lo que NO se puede hacer, y cómo rodearlo

| Limitación | Solución |
|---|---|
| Subir EPUB/PDF por API | Botón "Enviar a Reader" que abre un correo a `…@library.readwise.io` con el archivo adjunto; el usuario lo envía. Después se busca el documento (`list?category=epub&updatedAfter=…`, comparando título y autor) y se guarda el `readerDocId`. Alternativa: el usuario lo sube a mano en Reader. |
| Posición exacta (CFI) en Reader | La guardamos nosotros en CloudKit (`Annotation.cfi`). Para lo que viene de Reader, se re-ancla por texto (§6.3). |
| Escribir el progreso en Reader | Solo `seen` y `location=archive` al terminar. Se documenta como "la posición de Reader no se actualiza desde la app". Se reprueba en cada versión de la API (el Spike R incluye el test). |
| Editar el texto de un subrayado en Reader | Borrar y volver a crear (DELETE + save). |
| Webhooks sin servidor | *Polling* incremental: v3 `list?updatedAfter` (documentos, subrayados y notas) y v2 `export?updatedAfter&includeDeleted=true`. |
| Reader no informa borrados | Usar `is_deleted` del export v2, mapeado por `external_id`. |
| Llamadas desde la **web** (CloudKit JS) | ⚠️ No sabemos si la API admite CORS para un origen de navegador (probablemente no). **La web no habla con Readwise**: la sync la hacen los dispositivos Apple y la web lee CloudKit. |
| Kindle sin anclas | Casar por ASIN o título y autor más re-anclaje por cita (§6). |

### 9.3 iCloud como fuente de verdad vs. Reader como fuente de verdad

| Criterio | iCloud/CloudKit (recomendado) | Reader como backend |
|---|---|---|
| Archivos (EPUB, PDF, **cómics**) | ✅ Todos, en tu cuota | ❌ Sin subida por API y sin cómics |
| Metadatos de biblioteca (reemplazo de Calibre) | ✅ Modelo propio | ❌ Solo título, autor, resumen, imagen, etiquetas y notas |
| Anclas exactas (CFI) y progreso fino | ✅ | ❌ Solo texto y un float |
| Sync entre los dispositivos de la app | ✅ `CKSyncEngine` con push | ⚠️ Polling a 20 req/min, sin push |
| Web | ✅ CloudKit JS | ⚠️ CORS sin verificar y token expuesto en el navegador |
| Costo | iCloud+ | Readwise Full (~US$120/año) **además** |
| Sin dependencia de terceros | ✅ | ❌ |
| Interoperar con Reader, Kindle y Daily Review | Por API (este documento) | Nativo |

### 9.4 Diseño híbrido propuesto

```
                ┌───────────────────────── Dispositivos Apple (iPhone/Duo/iPad/Mac) ─────────────────────────┐
                │  Biblioteca (SQLite local)  ⇄  CKSyncEngine  ⇄  iCloud (CloudKit): Book, File(CKAsset),     │
                │                                                  Annotation(cfi), Progress, SyncState        │
                │                                                                                             │
                │  ReadwiseSyncService (lo ejecuta el dispositivo "líder"; preferencia: Mac)                  │
                │   ├─ ReaderImporter  : v3 list (epub/pdf, withRawSourceUrl) → descarga S3 → importa         │
                │   ├─ ReaderMirror    : v3 list?updatedAfter → subrayados/notas/progreso de libros vinculados │
                │   ├─ HighlightSink   : v3 save(parent_id) | v2 highlights(highlight_url)                   │
                │   └─ ReadwiseExport  : v2 export?updatedAfter&includeDeleted → Kindle/otros + borrados     │
                └────────────────────────────────────────────────────────────────────────────────────────────┘
                         │ REST v3 (Reader)                          │ REST v2 (Readwise)
                  ┌──────▼──────┐                              ┌─────▼──────┐
                  │   Reader    │ ── subrayados fluyen ─────▶ │  Readwise  │ ◀── Kindle, Apple Books…
                  └─────────────┘                              └────────────┘
```

**Cambios en el modelo de datos (CloudKit):**
- `Book`: `readerDocId?`, `readwiseBookId?` (`user_book_id`), `asin?`, `identifiers{}` (incluidos `amazon` e `isbn`), `readerLinkState` (none / linked / pendingEmail).
- `Annotation`: `origin` (app / reader / kindle / readwise), `readerHighlightId?`, `readwiseHighlightId?`, `readwiseExternalId?`, `highlightURL` (universal link `…/h/{uuid}`), `anchorConfidence`, `quoteNormalized`, `lastSyncedHash`.
- `SyncState` (un registro, en CloudKit): `v3UpdatedAfter`, `v2ExportUpdatedAfter`, `leaderDeviceId` + `leaseUntil` (para que solo un dispositivo sincronice), `rateLimitUntil`.

**Flujos:**
1. **Importar desde Reader** (a petición o automático por etiqueta, p. ej. `#biblioteca`):
   1. `list?category=epub` (y `pdf`) con `withRawSourceUrl=true`.
   2. Descargar del host S3 permitido.
   3. Calcular el hash del archivo y deduplicarlo contra la biblioteca.
   4. Importarlo y guardar `readerDocId` → libro **vinculado**.
   5. Traer sus subrayados (`list?category=highlight` y filtrar por `parent_id`) y re-anclarlos por texto.
2. **Subrayado nuevo en la app:**
   - Si el libro está vinculado: `POST /v3/save {parent_id, content, notes, tags}`. Si responde 201, guardar `readerHighlightId`. Si responde 400, pasar al caso v2.
   - Si no está vinculado: `POST /v2/highlights` con `highlight_url` (idempotente), `location_type: "order"` y `location` = índice ordinal.
   - **Nunca por los dos caminos**: lo que entra a Reader ya llega a v2 solo.
3. **Editar o borrar en la app:**
   - Reader: `PATCH /v3/update/<hid>/ {notes, tags}` o `DELETE`.
   - v2: `PATCH` o `DELETE /v2/highlights/<id>/`.
   - Si cambió el **texto** en Reader: borrar y volver a crear.
4. **Polling Reader → app:**
   1. `list?updatedAfter=<cursor - 5 min>` (con solapamiento, como Marfa).
   2. Subrayados nuevos en documentos vinculados → `Annotation(origin: reader)` re-anclada.
   3. Cambios de nota o etiquetas → fusión: gana el `updated_at` más reciente.
   4. `reading_progress` de libros vinculados → si es mayor que el nuestro y **el usuario leyó en Reader después** (`last_opened_at` > nuestro `Progress.updatedAt`), ofrecer "Continuar donde lo dejaste en Reader (~43 %)".
5. **Polling Readwise v2 → app:**
   1. `export?updatedAfter&includeDeleted=true`.
   2. Libros `source: "kindle"` (y Apple Books, Kobo…) → emparejar (§6.2) y re-anclar (§6.3).
   3. `is_deleted` en subrayados cuyo `external_id` == `readerHighlightId` → borrado que vino de Reader.
6. **Al terminar un libro vinculado:** `PATCH /v3/update {seen: true, location: "archive"}` (opcional, según los ajustes del usuario).

**Presupuesto de llamadas:** una sync incremental típica son 1–3 `list` + 1–2 `export` + N escrituras a ≤ 50/min. La importación inicial de una biblioteca de Reader grande, a 100 documentos por página y 20 páginas/min, son ~2,000 documentos/min. Va bien.

**Token:** en el Llavero de iCloud (como en el PRD). Antes de activar la integración se prueba con `GET /v2/auth/`.

### 9.5 Correcciones al PRD v2.0 §4.6

- ❌→✅ "Crear subrayados dentro de un documento de Reader por API": **ya se puede** (18 de septiembre de 2026), y editar o borrar desde el 25 de septiembre de 2026.
- ❌→✅ "Descargar el archivo original de un libro guardado en Reader": **se puede** con `withRawSourceUrl` (enlace de 1 h).
- Se mantiene: no hay **subida** por API, ni CFI, ni escritura de progreso.
- Nuevo: `external_id` une Reader con v2. El export trae `includeDeleted`. Existen webhooks (pero no sirven sin servidor).

---

## 10. Riesgos

| Riesgo | Mitigación |
|---|---|
| Campos no documentados (`highlight_offset`, formato de `tags`) cambian | Parseo tolerante. No depender de campos ⚠️. |
| La coincidencia de texto de Reader rechaza pasajes (400) | Normalizar antes de enviar; si falla, mandarlo por v2. Contar los rechazos en la telemetría local. |
| Duplicados por reintentos (v3 no es idempotente) | Diario de envíos en CloudKit, relistar antes de reintentar, y deduplicar por (`parent_id`, texto). |
| Dos dispositivos sincronizan a la vez | Lease de líder en `SyncState` (registro de CloudKit con `leaseUntil`). |
| El usuario deja de pagar Readwise | La app sigue funcionando; la integración se desactiva y no se pierde nada (iCloud es la verdad). |
| ToS o API para la versión pública | Contactar a Readwise antes de publicar; integración opt-in; token del usuario. |

---

## 11. Spike R: pruebas con un token real (≈ medio día, con `curl` desde el Mac)

1. `GET /v3/list/?category=epub&withRawSourceUrl=true&limit=5`: ¿llega `raw_source_url` en un EPUB **subido** (no guardado desde una URL)? ¿El archivo descargado es idéntico al original (SHA-256)?
2. `GET /v3/list/?id=<epub>&withHtmlContent=true`: tamaño, ¿el libro entero o un capítulo?, ¿hay `id`s o anclas?
3. `GET /v3/list/?category=highlight&updatedAfter=…`: valores reales de `highlight_offset`, `highlight_location`, `notes` y `tags`. ¿`highlight_offset` es un offset de caracteres en `html_content`?
4. `POST /v3/save/ {parent_id, content}` con: (a) una frase exacta; (b) comillas rectas en vez de tipográficas; (c) una frase que cruza dos párrafos; (d) un texto inexistente (¿400?). ¿Aparece en Reader iOS y en el export v2 con `external_id`?
5. `PATCH /v3/update/<doc> {reading_progress: 0.5}` y releer: ¿cambia? (Esperado: no.)
6. `POST /v3/save/ {url: <URL firmada de CloudKit o S3 de prueba>, category: "epub"}`: ¿lo procesa como EPUB?, ¿qué queda en `source_url`?
7. `GET /v2/export/?updatedAfter=…&includeDeleted=true`: un libro de Kindle real (`source`, `asin`, `location_type`, `location`, `end_location`, `url`).
8. Límites: ráfaga de 25 `list` en un minuto → ¿429 con `Retry-After`? Cabeceras de rate limit.
9. CORS: `fetch()` desde un origen web → ¿`Access-Control-Allow-Origin`?

---

## 12. Fuentes

**Oficiales** (vía fragmentos indexados; las páginas no se pudieron abrir directamente):
- Reader API: https://readwise.io/reader_api (`should_clean_html`, categorías, `withRawSourceUrl`, `bulk_update`, límites)
- Readwise API: https://readwise.io/api_deets (`location_type`, 8191 caracteres, deduplicación, `highlight_url`)
- Changelog: https://docs.readwise.io/changelog (subrayados por API en Reader el 18 y el 25 de septiembre de 2026; arreglo de webhooks en mayo de 2026; disparador de etiquetas en enero de 2026; importación de Kindle el 21 de agosto de 2026)
- Webhooks: https://docs.readwise.io/readwise/docs/webhooks
- Reader Public Beta Update #14 (agosto de 2026): https://readwise.io/reader/update-aug2026 (`seen`, bulk de 50, `language`, Daily Review por API, MCP)
- Update #13 (diciembre de 2025, webhooks): https://readwise.io/reader/update-dec2025
- Update #12 (EPUBs v2, junio de 2025): https://readwise.io/reader/update-june2025
- Adding content: https://docs.readwise.io/reader/docs/faqs/adding-new-content
- Exporting: https://docs.readwise.io/reader/docs/faqs/exporting
- Readwise y Reader: https://docs.readwise.io/get-started/app-relationship
- Kindle: https://docs.readwise.io/readwise/docs/importing-highlights/kindle

**Código abierto oficial de Readwise:**
- CLI (OAuth, MCP): https://github.com/readwiseio/readwise-cli
- Skills (referencia de herramientas MCP): https://github.com/readwiseio/readwise-skills
- MCP antiguo (obsoleto): https://github.com/readwiseio/readwise-mcp
- Plugin de Obsidian: https://github.com/readwiseio/obsidian-readwise

**Terceros (código leído):**
- Marfa, conector de Reader (octubre de 2026; IDs, `raw_source_url`, campos, límites, escritura): https://github.com/withmarfa/marfa-connectors, issues [#203](https://github.com/withmarfa/marfa-connectors/issues/203) y [#208](https://github.com/withmarfa/marfa-connectors/issues/208)
- Plugin de KOReader (crea subrayados en Reader con `parent_id`; sin ubicación): https://github.com/Endle/readwisereader
- CaseyRo/mcp-readwise (sin subida de archivos; correo `@library.readwise.io`; unión v2/v3 por ULID): https://github.com/CaseyRo/mcp-readwise
- zacharytamas/readwise-cli (parámetros de `save` y `update`, `withRawSourceUrl`): https://github.com/zacharytamas/readwise-cli
- readwise-mcp-enhanced (tipos v2/v3): https://github.com/arnaldo-delisio/readwise-mcp-enhanced
- readwise-ruby (endpoints v2 y fixture de export con `asin`): https://github.com/joshbeckman/readwise-ruby
- pyreadwise: https://github.com/rwxd/pyreadwise
- edwinhu/workflows (resumen de `reader_api`: `limit`, `tag` AND, `?tag=`): https://github.com/edwinhu/workflows
- pdf2reader: https://github.com/lancejohnson/pdf2reader
- readwise-go: https://pkg.go.dev/github.com/ethanholz/readwise-go
- fhjgch/personal-dashboard #2 (semántica de fechas y `seen`): https://github.com/fhjgch/personal-dashboard/issues/2

**Precio (terceros ⚠️):** https://www.readless.app/blog/readwise-reader-pricing-2026 · https://toolradar.com/tools/readwise/pricing
