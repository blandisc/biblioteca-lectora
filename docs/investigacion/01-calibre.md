# Investigación 01: Calibre como catálogo de Biblioteca Lectora

> Documento de trabajo, octubre 2026.
> **Base de la investigación:** lectura directa del código fuente de Calibre (clon superficial de `kovidgoyal/calibre`, commit `a5f438b` del 19-oct-2026, versión de desarrollo 9.16.100, última versión publicada 9.16.0 del 09-oct-2026), del manual oficial (que vive en el mismo repo, carpeta `manual/`, y se publica en manual.calibre-ebook.com) y de hilos de MobileRead.
> No se ejecutó código de Calibre; todo lo descrito sale de leer el fuente.

Convención de enlaces: `SRC/` = `https://github.com/kovidgoyal/calibre/blob/a5f438bfa3feb463d855a7ce2282fab967e3e3da/` (permalink al commit revisado). En la sección de fuentes, al final, están los enlaces completos.

---

## 0. Resumen ejecutivo

1. **Calibre es una aplicación de escritorio de un solo usuario con un servidor HTTP adjunto.** No es un backend multi-cliente. Su base `metadata.db` (SQLite, sin WAL) se carga **entera en memoria** por el proceso que la abre (GUI, `calibre-server` o `calibredb`) y ese proceso **no se entera de cambios externos**. Solo un proceso "dueño" puede escribir a la vez; `calibredb` y `calibre-server` se niegan a arrancar si otro programa de Calibre ya tiene la biblioteca (lock global `singleinstance('db')`).
2. **Consecuencia directa para nosotros:** en el servidor debe correr **un solo `calibre-server` headless** como dueño de la biblioteca, y **todas las escrituras** (alta de libros, metadatos, portadas) pasan por él: vía `calibredb --with-library http://localhost:8080/#lib` o llamando directamente a sus endpoints `/cdb/*`. La premisa de `vision-producto.md` §3.1 ("las escrituras pasan por `calibredb`, que respeta los bloqueos") es correcta **solo** si `calibredb` apunta al servidor por URL; en modo local, con el servidor arriba, `calibredb` aborta.
3. **Las lecturas sí pueden ser directas:** leer `metadata.db` en modo solo lectura (`?mode=ro`) y servir los archivos desde disco es seguro si se hace con transacciones cortas, y es lo más rápido para sincronizar el catálogo a Postgres. Nunca se escribe en `metadata.db` por fuera (los triggers dependen de funciones SQL que solo registra Calibre: `title_sort()`, `uuid4()`).
4. **El Content server tiene una API JSON útil pero no documentada como API pública** (`/ajax/*`, `/cdb/*`, `/get/*`, `/book-*-annotations`, OPDS 1.x). Sirve como backend de un adaptador nuestro, no como API que los clientes consuman directamente.
5. **Anotaciones:** Calibre guarda subrayados como JSON en la tabla `annotations` (anclados con EPUB CFI relativo al documento del spine + `spine_index`), con fusión por `uuid` y "último timestamp gana", y borrado lógico (`removed: true`). Es un buen modelo a **imitar**, pero sus CFI se calculan sobre el HTML que Calibre re-procesa, así que **no hay garantía de compatibilidad 1:1 con foliate-js**. Recomendación: nuestra fuente de verdad de subrayados es Postgres; la integración con Calibre es, a lo sumo, exportación/importación opcional.
6. **Licencia GPL v3:** usar Calibre como proceso aparte (HTTP/CLI) **no** contagia nuestra app. Importar módulos de Calibre en nuestro proceso Python, o portar código suyo (p. ej. su CFI en RapydScript) a la app Swift/web, sí la convertiría en obra derivada GPL, lo que choca con la App Store si algún día se publica. Regla: **integrar por la frontera del proceso, nunca copiar código**.
7. **Calibre en Google Drive es explícitamente "incompatible, sufrirás pérdida de datos"** según el FAQ oficial. Se confirma la decisión de disco local + `rclone` de una vía, con la precaución de hacer el respaldo desde una copia consistente de `metadata.db` (API de backup de SQLite o con el servidor parado).

---

## 1. Arquitectura general

### 1.1 Tamaño, lenguajes y licencia

| Dato | Valor (commit revisado) |
|---|---|
| Archivos Python (`src/`) | ~1 503 archivos, ~858 000 líneas |
| RapydScript (`.pyj`, Python→JS para el Content server y el visor) | 134 archivos, ~41 000 líneas en `src/pyj` |
| C/C++ (extensiones: SQLite, parsers, imágenes, PDF) | ~111 archivos |
| Tamaño de `src/` | ~38 MB |
| UI | Qt 6 (PyQt6) |
| Base de datos | SQLite vía **APSW** (no `sqlite3` de la stdlib) |
| Licencia | **GPL v3** (`LICENSE`, `COPYRIGHT`); algunos recursos con MIT/BSD/OFL |
| Distribución | binarios autocontenidos con su propio Python (`/opt/calibre`); no es instalable con `pip` |

Líneas por paquete de `src/calibre/` (Python + pyj, aproximado):

| Paquete | Líneas | Qué hace |
|---|---|---|
| `ebooks/` | ~473 k | Lectura/escritura de formatos, pipeline de conversión (`ebooks/conversion`), metadatos (`ebooks/metadata`, incluidas las fuentes de descarga), OEB, PDF, MOBI, comics, CFI, etc. |
| `gui2/` | ~182 k | Aplicación de escritorio Qt (biblioteca, editor de metadatos, visor, editor de EPUB, tienda, etc.) |
| `utils/` | ~44 k | Utilidades (fechas, ICU, imágenes, IPC, locks, serialización…) |
| `db/` | ~30 k | **Capa de datos nueva** (desde 2013): `backend.py` (SQL), `cache.py` (API en memoria, thread-safe), `search.py`, `annotations.py`, `fts/` (búsqueda de texto completo), `notes/`, `cli/` (`calibredb`) |
| `devices/` | ~25 k | Drivers de lectores (Kindle, Kobo, MTP, carpeta, "smart device app") |
| `web/` | ~20 k | Descarga de noticias (recipes) |
| `library/` | ~18 k | Capa legacy (`LibraryDatabase2`), `save_to_disk`, catálogos, `check_library`, `restore` |
| `srv/` | ~17 k | **Content server**: servidor HTTP propio (no WSGI), rutas, auth, usuarios, OPDS, AJAX, conversión, render de libros para el visor web |
| `ai/` | ~12 k | Integraciones LLM nuevas (Anthropic, OpenAI, Google, Ollama, LM Studio, OpenRouter…) usadas en el visor ("preguntar a la IA") y para generar portadas |
| `customize/` | ~6 k | Sistema de plugins (`builtins.py` registra todos los plugins internos) |

### 1.2 Piezas relevantes y cómo se relacionan

```
             ┌──────── calibre (GUI Qt) ───────┐
             │  gui2/  → db.cache.Cache         │   ← dueño de la biblioteca
             └──────────────┬──────────────────┘     (o bien calibre-server)
                            │
     ┌──────────────────────▼──────────────────────┐
     │ db/cache.py  (Cache: todo en memoria,        │
     │   lock lector/escritor, API de alto nivel)   │
     │ db/backend.py (DB: SQL sobre APSW, rutas,    │
     │   archivos, portadas, custom columns)        │
     └──────────────────────┬──────────────────────┘
                            │
      Biblioteca en disco:  metadata.db  +  Autor/Título (id)/{libro.epub, cover.jpg, metadata.opf}
                            │
   srv/ (calibre-server) ───┤  /ajax, /cdb, /get, OPDS, visor web (pyj)
   db/cli (calibredb) ──────┘  local, o remoto contra /cdb/cmd/*
   ebooks/conversion (ebook-convert) — independiente de la biblioteca
   ebooks/metadata/sources (fetch-ebook-metadata) — independiente
```

- **`db.cache.Cache`** es la API "buena" (documentada en `manual/db_api.rst`): `search()`, `field_for()`, `get_metadata()`, `set_field()`, `add_books()`, `remove_books()`, `add_format()`, `annotations_map_for_book()`, `merge_annotations_for_book()`, etc. Usa un lock compartido/exclusivo propio (`db/locking.py`), no locks de SQLite.
- **`srv/`** es un servidor HTTP propio con pool de hilos (`srv/loop.py`, `srv/pool.py`), soporte TLS, Range, ETag, gzip y websockets; las rutas se declaran con el decorador `@endpoint` (`srv/routes.py`).
- **Plugins** (`customize/`): tipos `MetadataReader/Writer`, `InputFormat/OutputFormat` (conversión), `MetadataSource` (descarga), `FileType` (hooks al importar), `Device`, `Store`, `InterfaceAction` (GUI). Se instalan como ZIP en la carpeta de configuración.

### 1.3 GPL v3: qué implica para Biblioteca Lectora

El FAQ oficial lo dice sin rodeos: *"You cannot use either code or libraries from calibre in your software without making your software open source"* (`manual/faq.rst`, "How is calibre licensed?"). Los resultados de las conversiones sí son libres de usar.

| Forma de uso | ¿Nuestra app queda bajo GPL? | Comentario |
|---|---|---|
| Ejecutar `calibre-server`, `calibredb`, `ebook-convert`, `fetch-ebook-metadata` como **procesos separados** y hablar por HTTP/CLI/archivos | **No** | Es "agregación" / comunicación a distancia. Es el patrón de calibre-web, Kavita, Komga, etc. |
| Leer `metadata.db` con nuestro propio código SQL | **No** | El esquema/formato de datos no es código; reimplementar la lectura no deriva de Calibre. |
| `from calibre.library import db` dentro de nuestro FastAPI (o usar `calibre-debug` como intérprete) | **Sí** (obra combinada) | Además es técnicamente incómodo: hay que correr con el Python embebido de Calibre. |
| Portar/copiar código de Calibre (p. ej. `pyj/read_book/cfi.pyj`, `db/annotations.py`, el parser de búsqueda) a Swift/TS/Python | **Sí** | Aunque se traduzca de lenguaje, es obra derivada. Reimplementar desde la especificación (EPUB CFI del IDPF) sí es libre. |
| Uso personal sin distribuir | GPL no impone nada | La GPL solo obliga al **distribuir**. GPL v3 (a diferencia de AGPL) no tiene cláusula de red: ofrecer un servicio web no es distribuir. |
| App en la **App Store** con código GPL | Problemático | Los términos de la App Store se consideran incompatibles con GPL (precedente: VLC retirado en 2011). |

**Conclusión:** mantener Calibre al otro lado de una frontera de proceso (adaptador HTTP/CLI) y no copiar su código. foliate-js es MIT, sin conflicto.

---

## 2. La biblioteca en disco y el esquema de `metadata.db`

### 2.1 Estructura de carpetas

```
Biblioteca/
├── metadata.db                ← SQLite principal (user_version = 28)
├── metadata_db_prefs_backup.json   ← respaldo de prefs de la BD
├── full-text-search.db        ← índice FTS de texto completo (opcional, se adjunta)
├── .calnotes/notes.db         ← notas sobre autores/tags/series… + recursos
├── .caltrash/                 ← papelera: libros/formatos borrados (recuperables)
└── Isaac Asimov/
    └── Foundation (123)/      ← "Título (book_id)"
        ├── Foundation - Isaac Asimov.epub
        ├── Foundation - Isaac Asimov.pdf
        ├── cover.jpg          ← siempre se llama cover.jpg
        ├── metadata.opf       ← respaldo de TODOS los metadatos (+ anotaciones)
        └── data/              ← "archivos de datos" extra del libro
```

- Nombres de carpeta y archivo los construyen `DB.construct_path_name()` y `construct_file_name()` (`db/backend.py` ~L1771-1815): `ascii_filename(author)/ascii_filename(title) (id)` y `Título - Autor.ext`, transliterados a ASCII y truncados (`PATH_LIMIT = 100` en Linux/macOS, 40 en Windows). Constantes en `db/constants.py`: `COVER_FILE_NAME='cover.jpg'`, `METADATA_FILE_NAME='metadata.opf'`, `TRASH_DIR_NAME='.caltrash'`, `DATA_DIR_NAME='data'`, `BOOK_ID_PATH_TEMPLATE=' ({})'`.
- **Al cambiar título o autor, Calibre renombra/mueve la carpeta y los archivos** (`Cache.update_path`). Por lo tanto **la ruta nunca es un identificador estable**: hay que resolverla siempre con `books.path` + `data.name` + `data.format`.
- Identificadores estables: `books.id` (entero, se reutiliza la misma id al restaurar la BD desde OPFs) y `books.uuid` (UUID4 asignado por trigger). La biblioteca tiene su propio `library_id.uuid`.
- `metadata.opf` lo escribe un hilo `MetadataBackup` (`db/backup.py`) cada ~2 s para los libros marcados en `metadata_dirtied`. Incluye columnas personalizadas (`calibre:user_metadata:*`) y **las anotaciones** (`<meta name="calibre:annotation" content="{json}">`, ver `ebooks/metadata/opf2.py` `serialize_annotations`). Con esos OPF, `calibredb restore_database` reconstruye `metadata.db`.
- El FAQ insiste: **no añadir archivos a mano** dentro de la biblioteca ("may be automatically deleted") y la estructura Autor/Título (id) **no va a cambiar** ("this is not going to change").

### 2.2 Tablas (de `resources/metadata_sqlite.sql`)

**Núcleo:**

| Tabla | Columnas clave | Notas |
|---|---|---|
| `books` | `id` (AUTOINCREMENT), `title`, `sort`, `timestamp` (fecha de alta), `pubdate`, `series_index` (REAL), `author_sort`, `path`, `uuid`, `has_cover`, `last_modified` | Triggers: al insertar, `sort=title_sort(title)` y `uuid=uuid4()`; al borrar, limpia todas las tablas link |
| `authors` | `id`, `name` (UNIQUE NOCASE), `sort`, `link` | |
| `series` | `id`, `name`, `sort`, `link` | |
| `tags` | `id`, `name` (UNIQUE NOCASE), `link` | Tags jerárquicos por convención `A.B.C` |
| `publishers`, `ratings` (0-10, en medias estrellas), `languages` (`lang_code` ISO 639-2) | | |
| `comments` | `book` (UNIQUE), `text` (HTML) | La sinopsis |
| `identifiers` | `book`, `type` (`isbn`, `amazon`, `google`, `goodreads`…), `val`; UNIQUE(book,type) | |
| `data` | `book`, `format` (EPUB, PDF, CBZ…), `uncompressed_size`, `name` (nombre sin extensión); UNIQUE(book,format) | **Un archivo por formato por libro** |
| `custom_columns` | `id`, `label`, `name`, `datatype`, `is_multiple`, `normalized`, `display` (JSON) | Definición de columnas personalizadas |
| `preferences` | `key`, `val` (JSON) | Aquí viven `virtual_libraries`, `saved_searches`, `field_metadata`, `user_categories`, etc. |
| `library_id` | `uuid` | Id de la biblioteca |

**Tablas de enlace (many-to-many o many-to-one):** `books_authors_link` (orden por `id` del link = orden de autores), `books_series_link` (UNIQUE(book): una serie por libro), `books_tags_link`, `books_publishers_link` (UNIQUE(book)), `books_ratings_link`, `books_languages_link` (con `item_order`).

**Columnas personalizadas:** por cada fila `custom_columns.id = N` se crean `custom_column_N` y, si es "normalizada" (texto, series, enumeración, rating), `books_custom_column_N_link`. Las no normalizadas (`datetime`, `comments`, `int`, `float`, `bool`, `composite`) guardan `(book, value)` directamente en `custom_column_N` (`DB.create_custom_column`, `db/backend.py` L1502). Las de tipo `series` llevan `extra` (= índice en la serie). Las `composite` no se almacenan: se calculan con plantillas.

**Lectura y anotaciones:**

```sql
CREATE TABLE last_read_positions ( id INTEGER PRIMARY KEY,
  book INTEGER NOT NULL, format TEXT NOT NULL COLLATE NOCASE,
  user TEXT NOT NULL, device TEXT NOT NULL,
  cfi TEXT NOT NULL, epoch REAL NOT NULL, pos_frac REAL NOT NULL DEFAULT 0,
  UNIQUE(user, device, book, format));

CREATE TABLE annotations ( id INTEGER PRIMARY KEY,
  book INTEGER NOT NULL, format TEXT NOT NULL COLLATE NOCASE,
  user_type TEXT NOT NULL,   -- 'local' (visor de escritorio) | 'web' (Content server)
  user TEXT NOT NULL,        -- 'viewer' para local; nombre de usuario o '*' (anónimo) para web
  timestamp REAL NOT NULL,
  annot_id TEXT NOT NULL,    -- uuid del highlight o título del bookmark
  annot_type TEXT NOT NULL,  -- 'highlight' | 'bookmark'
  annot_data TEXT NOT NULL,  -- el JSON completo
  searchable_text TEXT NOT NULL DEFAULT '',
  UNIQUE(book, user_type, user, format, annot_type, annot_id));
-- + annotations_fts y annotations_fts_stemmed (FTS5) con triggers
```

**Otras:** `annotations_dirtied`, `metadata_dirtied` (colas para el respaldo OPF), `book_storage` (nueva, `user_version` 28: "localStorage" por libro para scripts del libro en el visor), `books_pages_link` (nuevo conteo de páginas), `books_plugin_data` (datos de plugins por libro, p. ej. *Count Pages*, *Goodreads Sync*), `conversion_options`, `feeds`. Vistas legacy: `meta`, `tag_browser_*` (usan agregados propios `sortconcat`, `concat`: **no se pueden consultar desde sqlite3 normal**).

### 2.3 Concurrencia y bloqueo

Hechos verificados en el código:

- **Sin WAL.** No hay `PRAGMA journal_mode` en todo `src/`; se usa el modo por defecto (rollback journal `DELETE`). Un escritor bloquea a los lectores durante el commit y un lector con una transacción abierta retrasa al escritor. `busy_timeout` de Calibre: 10 s (`Connection.BUSY_TIMEOUT`, `db/backend.py` L453).
- **Funciones SQL propias**: la conexión registra `title_sort`, `author_to_author_sort`, `uuid4`, la colación `PYNOCASE`/`icucollate` y agregados (`db/backend.py` L470-485). Un `INSERT INTO books` desde fuera falla con *"no such function: title_sort"*; un `UPDATE books SET title=…` también, por el trigger `books_update_trg`. **Escribir por fuera es inviable sin reimplementar esas funciones, y aun así saltaría el caché y el respaldo OPF.**
- **Caché en memoria.** `Cache` lee todas las tablas al abrir (`backend.read_tables()`) y responde desde memoria. Solo se recarga con `reload_from_db()` (cambio de biblioteca o acciones de la GUI). Un `calibre-server` **no ve** lo que otro proceso escriba en `metadata.db` hasta reiniciarse (confirmado también en MobileRead).
- **Un solo dueño.** `calibredb` (modo local) y `calibre-server` llaman a `singleinstance('db')` y abortan si otro programa de Calibre tiene la biblioteca (`db/cli/main.py` `DBCtx.__init__`; `srv/standalone.py` `ensure_single_instance`). El mensaje de error sugiere usar `--with-library http://…` para hablar con el servidor. Existe la variable `CALIBRE_NO_SI_DANGER_DANGER` para saltarse el lock: el nombre dice todo.
- **Locks internos**: `db/locking.py` implementa un lock compartido/exclusivo en hilos (un escritor, muchos lectores) dentro del proceso.

### 2.4 Formas seguras de leer y escribir desde fuera

| Operación | Cómo | Riesgo |
|---|---|---|
| Leer catálogo masivo (sincronizar a Postgres) | `sqlite3.connect('file:/lib/metadata.db?mode=ro', uri=True)`; SELECTs simples sobre tablas (no vistas); transacción corta; reintentos ante `SQLITE_BUSY` | Bajo. Evitar `immutable=1` (ignoraría cambios y locks). No mantener cursores abiertos. |
| Leer archivos del libro y portada | Ruta = `lib/` + `books.path` + `/` + `data.name` + `.` + `lower(format)`; `cover.jpg` si `has_cover` | Bajo, pero resolver la ruta en cada acceso: puede cambiar tras editar metadatos. |
| Detectar cambios | `SELECT max(last_modified)` / `SELECT id, last_modified FROM books WHERE last_modified > ?`; más `count(*)` y lista de ids para detectar borrados | Calibre **no emite eventos** externos (no hay webhooks); hay que hacer polling. |
| Escribir metadatos / añadir libros / portadas | A través del `calibre-server` dueño: `calibredb … --with-library http://127.0.0.1:8080/#<library_id>` o `POST /cdb/*` | Ninguno si se usa el servidor. |
| Respaldo | `sqlite3 .backup` (API de backup online) o `VACUUM INTO` hacia un archivo temporal, luego `rclone` de ese snapshot + carpetas de libros | Copiar `metadata.db` "en caliente" con `rclone` puede capturar un estado inconsistente. |
| Escribir directo a `metadata.db` | **No** | Rompe triggers, caché del servidor, respaldo OPF y potencialmente la BD. |

---

## 3. Content server (`calibre-server`, `src/calibre/srv/`)

### 3.1 Qué es

Servidor HTTP/HTTPS propio que sirve: (a) una SPA en RapydScript (biblioteca + visor en el navegador con caché offline), (b) endpoints JSON, (c) OPDS, (d) descargas de archivos, (e) un endpoint RPC para `calibredb` remoto. Se arranca headless con `calibre-server /ruta/biblioteca` (puede servir varias bibliotecas; cada una tiene un `library_id` derivado del nombre de carpeta).

### 3.2 Endpoints (extraídos de los decoradores `@endpoint`)

`{library_id=None}` significa opcional (usa la biblioteca por defecto). Las respuestas JSON salvo que se indique.

**Catálogo y búsqueda (`srv/ajax.py`):**

| Método y ruta | Uso |
|---|---|
| `GET /ajax/library-info` | `{library_map, default_library}` |
| `GET /ajax/book/{book_id}/{library_id}` | Metadatos de un libro (`?id_is_uuid=true` para buscar por uuid; `?category_urls=false` para respuesta más ligera). Incluye `formats`, `main_format`, `other_formats` (URLs), `cover`, `thumbnail`, `format_metadata`, `identifiers`, `user_metadata` (columnas personalizadas). Cabecera `Last-Modified`. |
| `GET /ajax/books/{library_id}?ids=1,2,3` | Lo mismo en lote (`ids=all` para todos) |
| `GET /ajax/search/{library_id}?query=&num=&offset=&sort=&sort_order=&vl=` | Devuelve `book_ids` paginados + `total_num`, usando **el lenguaje de búsqueda de Calibre** y bibliotecas virtuales (`vl`) |
| `GET /ajax/categories/{library_id}` | Categorías de nivel superior (autores, series, tags, etc.) |
| `GET /ajax/category/{encoded_name}/{library_id}` | Elementos de una categoría |
| `GET /ajax/books_in/{encoded_category}/{encoded_item}/{library_id}` | Libros de un elemento de categoría |

**Archivos y portadas (`srv/content.py`):**

| Ruta | Uso |
|---|---|
| `GET /get/{fmt}/{book_id}/{library_id}` | Descarga el formato (`epub`, `pdf`, `cbz`…). Soporta `Range`. **Ojo:** para ciertos formatos (EPUB, AZW3…) incrusta los metadatos actuales en una copia antes de enviarla (`update_metadata_in_fmts`), por lo que el hash **no coincide** con el archivo en disco. |
| `GET /get/cover/{book_id}` | Portada completa |
| `GET /get/thumb/{book_id}?sz=300x400` | Miniatura redimensionada en caché |
| `GET /get/opf/{book_id}` · `GET /get/json/{book_id}` | Metadatos como OPF o JSON |
| `GET /data-files/get/{book_id}/{relpath}` · `POST /data-files/upload/…` · `POST /data-files/remove/…` | Archivos extra del libro |
| `GET /get-note/{field}/{item_id}` · `POST /set-note/…` | Notas de autores/series/tags |

**Escritura (`srv/cdb.py`, requieren permiso de escritura):**

| Ruta | Uso |
|---|---|
| `POST /cdb/cmd/{command}/{version}?library_id=` | **RPC de `calibredb`**: el cuerpo (JSON o msgpack) son los argumentos posicionales de `implementation()` del comando (`db/cli/cmd_*.py`). Respuesta `{result}` o `{err, tb}`. Ej.: `POST /cdb/cmd/search/0` con `["tags:ficción"]`; `POST /cdb/cmd/list/0` con `[fields, sort_by, ascending, search, limit]`. |
| `POST /cdb/add-book/{job_id}/{add_duplicates y/n}/{filename}/{library_id}` | Sube un archivo en el cuerpo y crea el libro; devuelve `book_id` o `duplicates` |
| `POST /cdb/set-fields/{book_id}/{library_id}` | `{"changes": {"title": "...", "tags": [...], "cover": "data:image/jpeg;base64,...", "added_formats": [...], "removed_formats": [...]}}`; devuelve los libros modificados como JSON |
| `POST /cdb/set-cover/{book_id}/{library_id}` | Portada |
| `POST /cdb/delete-books/{ids}/{library_id}` | Borrado (a `.caltrash`) |
| `POST /cdb/copy-to-library/{target}/{library_id}` | Copiar entre bibliotecas |

**Lectura, progreso y anotaciones (`srv/books.py`):**

| Ruta | Uso |
|---|---|
| `GET /book-manifest/{book_id}/{fmt}` | Lanza (o reutiliza) un job que **convierte/"renderiza" el libro** al formato interno del visor web y devuelve el manifest + `annotations_map`, `last_read_positions`, `book_storage` |
| `GET /book-file/{book_id}/{fmt}/{size}/{mtime}/{name}` | Recursos del libro renderizado |
| `GET /book-get-last-read-position/{library_id}/{id-fmt_id-fmt…}` | Posición (CFI + `pos_frac`) por usuario y dispositivo; requiere login |
| `POST /book-set-last-read-position/{library_id}/{book_id}/{fmt}` | `{"device", "cfi", "pos_frac"}` |
| `GET /book-get-annotations/{library_id}/{id-fmt_…}` | `{"<id>:<FMT>": {last_read_positions, annotations_map}}` para el usuario (o `*` anónimo) |
| `POST /book-update-annotations/{library_id}/{book_id}/{fmt}` | Cuerpo `{"highlight": [...], "bookmark": [...]}`; el servidor **fusiona** (`merge_annotations_for_book`) en `user_type='web'` |
| `GET/POST /book-get-storage/…`, `/book-set-storage/…` | Almacenamiento por libro |

**Otros:** búsqueda de texto completo `GET /fts/search?query=…`, `GET /fts/snippets/{ids}`, `POST /fts/reindex|disable|indexing`; conversión `POST /conversion/start/{book_id}`, `GET /conversion/status/{job_id}`; datos de la SPA `/interface-data/*`; usuarios `POST /users/change-pw`; legacy `/mobile`, `/browse`, `/stanza`, `/legacy/get/...`.

**OPDS 1.x (Atom, `srv/opds.py`):** `/opds`, `/opds/navcatalog/{which}`, `/opds/category/{category}/{which}`, `/opds/categorygroup/{category}/{which}`, `/opds/search/{query}`. Incluye enlaces de adquisición (`http://opds-spec.org/acquisition`), portada y miniatura. No es OPDS 2.0 (JSON) ni tiene OPDS-PSE (streaming de páginas de cómic).

### 3.3 Autenticación y permisos

- Opciones (`srv/opts.py`): `--enable-auth`, `--auth-mode auto|basic|digest` (auto: digest sin TLS, basic con TLS; usar `basic` detrás de un proxy TLS), `--userdb`, `--ban-for/--ban-after` (bloqueo por fallos), `--trusted-ips`, `--enable-local-write`, `--url-prefix`, `--listen-on`, `--port`, `--ssl-certfile/keyfile`, `--worker-count`, `--max-jobs`.
- **Sin auth el servidor es de solo lectura.** `--enable-local-write` permite escribir sin credenciales desde `127.0.0.1` (el propio help advierte que cualquier programa local, e incluso webs abiertas en Firefox, podrían escribir). `--trusted-ips` amplía esto a redes concretas.
- Usuarios en `server-users.sqlite` (`srv/users.py`): `readonly`, restricciones por biblioteca (`library_restrictions`, que son búsquedas). **Las contraseñas se guardan en texto plano** (necesario para Digest). Gestión: `calibre-server --userdb users.sqlite --manage-users`.
- No hay tokens, OAuth, CORS configurable ni API keys: está pensado para navegador y `calibredb`.

### 3.4 ¿Sirve como backend de un cliente de terceros?

**Como backend de nuestro adaptador, sí; como API pública para la app, no.**

A favor: cubre lectura, búsqueda con el lenguaje completo de Calibre, descarga con Range, miniaturas, escritura de metadatos, alta de libros, FTS, y es el único camino soportado para escribir mientras el servidor corre.

En contra:
- Los endpoints `/ajax`, `/cdb`, `/interface-data` son **internos de la SPA**; no hay versión ni contrato estable (el RPC `/cdb/cmd` exige que coincida la versión del comando con la de `calibredb`). El manual no los documenta (solo las docstrings del código).
- Auth limitada (basic/digest, contraseñas en claro), sin CORS, sin push de cambios (solo websocket interno para el visor), sin webhooks.
- El progreso y las anotaciones van atados a un "usuario" del Content server y a `user_type`; no hay modelo de dispositivos ni vector clocks.
- Las respuestas por libro son pesadas (incluyen `category_urls`); para miles de libros conviene leer `metadata.db` directo.

---

## 4. `calibredb` y modos de escritura

Comandos (`db/cli/main.py` `COMMANDS`; cada uno en `db/cli/cmd_<nombre>.py`):

| Comando | Para qué | ¿Remoto? |
|---|---|---|
| `list` | Listar libros (`--fields`, `--search`, `--sort-by`, `--limit`, `--for-machine` → JSON) | Sí (sin plantillas en remoto) |
| `search` | Devuelve ids que cumplen una búsqueda | Sí |
| `add` | Añadir archivos o carpetas (`--duplicates`, `--automerge`, `--empty`, `--title`, `--authors`, `--isbn`, `--identifier`, `--tags`, `--series`, `--series-index`, `--cover`, `--languages`, `-r`, `-1`) | Sí |
| `add_format` / `remove_format` | Añadir/quitar un formato a un libro | Sí |
| `remove` | Borrar libros (`--permanent` salta la papelera) | Sí |
| `show_metadata` | Metadatos (`--as-opf`) | Sí |
| `set_metadata` | Desde un OPF o con `--field campo:valor` repetible (`--list-fields`) | Sí |
| `set_custom` | Valor de columna personalizada | Sí |
| `export` | Exportar libros a disco con plantilla de nombres (`--to-dir`, `--single-dir`, `--template`…) | Sí |
| `catalog` | Catálogo CSV/XML/EPUB… | No |
| `saved_searches` | Listar/añadir/quitar búsquedas guardadas | Sí |
| `add_custom_column` / `remove_custom_column` | Gestionar columnas | No |
| `custom_columns` | Listar columnas | Sí |
| `list_categories` | Categorías y conteos | Sí |
| `check_library` | Verificar consistencia BD↔disco | No |
| `restore_database` | Reconstruir `metadata.db` desde los OPF | No |
| `backup_metadata` | Forzar escritura de `metadata.opf` | No |
| `embed_metadata` | Incrustar metadatos de la BD en los archivos | Sí |
| `clone` | Biblioteca vacía con la misma configuración | Sí |
| `fts_index` / `fts_search` | Índice y búsqueda de texto completo | Sí |

Modos:
- **Local:** `calibredb --with-library /lib …` abre la BD directamente. Solo si **ningún** otro programa de Calibre está corriendo.
- **Remoto:** `calibredb --with-library "http://127.0.0.1:8080/#biblioteca" --username u --password '<f:/run/secrets/pw>' …`. Envía la llamada al servidor por `POST /cdb/cmd/...` (msgpack). Requiere usuario con escritura, o `--enable-local-write` en el servidor si es local. `--with-library "http://host:8080/#-"` lista los `library_id`.

Otros CLIs útiles: `ebook-convert`, `ebook-meta` (leer/escribir metadatos de un archivo suelto), `fetch-ebook-metadata`, `ebook-polish`, `calibre-debug`.

---

## 5. Descarga de metadatos y portadas

**Plugins incluidos** (`customize/builtins.py` L900-906, `ebooks/metadata/sources/`):

| Plugin | Capacidades | Notas |
|---|---|---|
| `Google` (Google Books API) | identify | Rápido, buen ISBN; portadas con URL no fiable en caché |
| `Google Images` | cover | Busca portadas por título/autor |
| `Amazon.com` | identify + cover | Scraping HTML (varios dominios de país); el más completo pero frágil; puede usar motores de búsqueda como intermediarios (`search_engines.py`) |
| `Edelweiss` | identify + cover | Catálogo editorial (inglés) |
| `Open Library` | **solo cover** | Portadas por ISBN |

Plugins de terceros populares: Goodreads, Barnes & Noble, Kobo, Casa del Libro/Fantastic Fiction, Comic Vine (cómics), ISBNdb, Douban. Calibre puede actualizar el código de los plugins de fuentes sin nueva versión: descarga código firmado desde `code.calibre-ebook.com/metadata-sources/` (`sources/update.py`), porque el scraping se rompe a menudo.

**Cómo funciona `identify` (`ebooks/metadata/sources/identify.py`):**
1. Lanza un hilo por plugin habilitado con título, autores e identificadores (ISBN, `amazon:`, `google:`…), con timeout (30 s por defecto) y espera un poco tras el primer resultado.
2. **`ISBNMerge`**: agrupa resultados por ISBN (y por identificadores) entre fuentes.
3. **`merge()`** decide campo a campo con heurísticas: título **más corto** ("menos ruido"), autores **más largos**, editorial más corta, tags el conjunto más pequeño (configurable), serie más larga, rating **promedio**, comentarios **más largos**, `pubdate` **más antigua**, unión de identificadores, el resto aleatorio entre fuentes.
4. Ordena por relevancia y prioridad de fuente; la GUI muestra candidatos y el usuario elige. También hay modo masivo automático.
5. Opciones (`msprefs`): campos a ignorar, `fewer_tags`, `cover_priorities`, mapeo de tags, "keep only one tag per…".

**Portadas (`sources/covers.py`):** se consultan todos los plugins con capacidad `cover` en paralelo y se ordenan por `(prioridad del plugin, 1/(ancho×alto))`: gana la de mayor prioridad y, a igualdad, **la de mayor resolución**.

**CLI:** `fetch-ebook-metadata -t "Título" -a "Autor" -i ISBN --identifier asin:… --opf --cover cover.jpg --allowed-plugin Google -d 30`. Ejecutable como subproceso desde nuestro servidor (sin problemas de GPL) y devuelve OPF por stdout.

**Cómics:** el lector de metadatos de CBZ/CBR solo entiende **ComicBookInfo** (JSON en el comentario del ZIP, `ebooks/metadata/archive.py`), **no `ComicInfo.xml`** (el estándar de ComicRack/Komga/Kavita). Para eso hace falta un plugin de terceros ("Comic Metadata"). Relevante si nuestros cómics vienen con `ComicInfo.xml`.

**IA (nuevo en 8.x/9.x):** `src/calibre/ai/` añade proveedores LLM (incluido Anthropic y Ollama) para "preguntar sobre el libro" en el visor y generar portadas (`gui2/actions/llm_cover.py`). Es solo GUI; no se expone por el servidor.

---

## 6. Pipeline de conversión (`ebook-convert`)

Arquitectura (`ebooks/conversion/plumber.py`): **Input plugin → OEB (HTML+CSS+OPF intermedio) → transformaciones (heurísticas, detección de estructura/ToC, CSS, look & feel, perfiles de entrada/salida, jacket, búsqueda/reemplazo) → Output plugin**.

- **Entrada** (`ebooks/conversion/plugins/*_input.py`): AZW, AZW3, AZW4, CBZ, CBR, CB7, CBC, CHM, DJVU, DOCX, EPUB, FB2, FBZ, HTML/HTMLZ, KEPUB, LIT, LRF, MOBI/PRC, ODT, PDF, PDB, PML, RB, RTF, SNB, TCR, TXT/TXTZ/Markdown, recipes.
- **Salida:** AZW3, EPUB, DOCX, FB2, HTMLZ, KEPUB, OEB, LIT, LRF, MOBI, PDB, PMLZ, RB, PDF, RTF, SNB, TCR, TXT, TXTZ, ZIP.
- **Cómics** (`comic_input.py`): extrae imágenes y las procesa (escala de grises opcional, recorte, *sharpen*, división de páginas apaisadas en dos, perfil de pantalla) para generar un EPUB/MOBI de imágenes; opciones `--no-process`, `--landscape`, `--dont-sharpen`, `--comic-image-size`… Útil para e-ink; **para nuestra app es mejor servir el CBZ original** y paginar las imágenes en el cliente.
- **PDF de entrada** (`pdf_input.py`): dos motores, `pdftohtml` (Poppler) o el propio `calibre`. El FAQ: *"PDF is a terrible format to convert from"*. Sirve para PDFs de texto simple; no para maquetados, técnicos o escaneados. **No convertir PDFs: leerlos como PDF** (PDF.js / PDFKit).
- **PDF de salida:** renderiza con Qt WebEngine (Chromium headless), con cabeceras, pies, márgenes y MathJax.
- Conversión remota: `POST /conversion/start/{book_id}` en el Content server (jobs en segundo plano).

Formatos que interesan a Biblioteca Lectora: EPUB (nativo, sin convertir), MOBI/AZW3 (foliate-js los lee; si no, `ebook-convert x.azw3 x.epub` a la importación), PDF (sin convertir), CBZ/CBR (sin convertir; CBR→CBZ por reempaquetado si el cliente no maneja RAR).

---

## 7. Visor y anotaciones

### 7.1 Visor

- El visor de escritorio (`gui2/viewer/`) y el del navegador comparten el mismo código RapydScript (`src/pyj/read_book/`). Antes de mostrar un libro, Calibre lo **"renderiza"**: lo convierte/descompone a su formato interno (`srv/render_book.py`), reescribe enlaces y recursos, y lo cachea por hash. Cualquier formato con plugin de entrada puede verse (MOBI y DOCX se convierten primero).
- Por defecto, la GUI abre en el visor interno: EPUB, KEPUB, MOBI, AZW/AZW3, FB2, HTMLZ, etc. (`internally_viewed_formats`, `gui2/__init__.py` L727); **PDF y cómics se abren con el visor del sistema**. Calibre no tiene un buen lector de PDF/cómic.
- Funciones: paginado/scroll, temas, tipografía, ToC, búsqueda, *read aloud* (Piper TTS o el del sistema), consulta en diccionario/Wikipedia, notas en highlights, "preguntar a la IA".

### 7.2 Formato de un highlight

Lo crea `pyj/read_book/annotations.pyj` (`add_highlight`):

```json
{
  "type": "highlight",
  "uuid": "Wm9k3...",                         // id estable del subrayado
  "timestamp": "2026-10-19T10:21:33.123Z",     // ISO 8601, última modificación
  "highlighted_text": "Texto subrayado…",
  "start_cfi": "/4/2/14/1:23",                 // CFI RELATIVO al documento del spine
  "end_cfi": "/4/2/14/1:87",
  "spine_index": 7,                            // índice del documento en el spine
  "spine_name": "OEBPS/ch07.xhtml",
  "style": {"kind": "color", "type": "builtin", "which": "yellow"},
  "notes": "Mi nota en texto plano",           // opcional
  "toc_family_titles": ["Parte II", "Capítulo 7"]
}
```

Un bookmark: `{"type": "bookmark", "title": "...", "pos_type": "epubcfi", "pos": "epubcfi(/14/4/2:0)", "timestamp": "…"}`. El CFI completo de un highlight se arma como `epubcfi(/{2*(spine_index+1)}{start_cfi})`.

**Borrado:** no se elimina la entrada; se marca `"removed": true`, se actualiza `timestamp` y se quitan texto, CFI y estilo (tombstone), para que la fusión propague el borrado.

### 7.3 Almacenamiento y sincronización

- Tabla `annotations` (§2.2): una fila por anotación, clave `(book, format, user_type, user, annot_type, annot_id)`, JSON completo en `annot_data`, texto + notas en `searchable_text` con FTS5 (búsqueda en todas las anotaciones de la biblioteca: "Browse annotations").
- **Por formato:** las anotaciones son de `book + format`. Un subrayado en el EPUB no aparece en el AZW3 del mismo libro.
- **Fusión** (`db/annotations.py` `merge_annotations`, espejo en `pyj`): highlights agrupados por `uuid`, bookmarks por `title`; **gana el de `timestamp` más reciente** (que incluye tombstones). `last-read` se queda con el más reciente. Es *last-writer-wins* por elemento.
- **Sincronización visor ↔ servidor:** el visor de escritorio guarda en `user_type='local', user='viewer'`; si en preferencias se pone el usuario del Content server, también fusiona con `user_type='web', user=<usuario>` (`save_annotations_list_to_cursor`). El visor web llama a `/book-update-annotations` y `/book-get-annotations`. Progreso: `last_read_positions` por `(user, device, book, format)` con `cfi` y `pos_frac` (0-1).
- **Respaldo:** las anotaciones se copian al `metadata.opf` (`calibre:annotation`), así sobreviven a una reconstrucción de la BD.
- **Exportación** (`gui2/library/annotations.py`, `gui2/viewer/highlights.py`): texto plano, Markdown, HTML y JSON `{"version": 1, "type": "calibre_annotation_collection", "annotations": [...]}` (o `calibre_highlights` desde el visor). Los enlaces de Markdown usan `calibre://view-book/<library>/<id>/<FMT>?open_at=<cfi>` (`manual/url_scheme.rst`).
- Lectores externos que leen/escriben estas anotaciones: KOReader (plugin), Kobo (plugin *Annotations*). No hay un estándar común; cada uno mapea.

### 7.4 ¿Podemos reutilizar los CFI de Calibre con foliate-js?

Con cautela:
- Para **EPUB**, ambos usan EPUB CFI sobre el XHTML del capítulo, pero Calibre calcula sus CFI sobre el DOM **ya procesado por su render** (parseo con su parser HTML5, recursos virtualizados), mientras foliate-js lo hace sobre el XHTML original cargado en un iframe. Diferencias de nodos (p. ej. `tbody` insertado, espacios en blanco, nodos de texto partidos) pueden desplazar índices. Debe **probarse** con un set de libros antes de prometer interoperabilidad.
- Para **MOBI/AZW3**, Calibre ancla sobre su conversión a HTML; foliate-js usa su propio parser de MOBI. No son compatibles.
- **PDF/cómics:** Calibre no tiene anotaciones para ellos.
- Recomendación: guardar en Postgres el CFI de foliate-js **más** `highlighted_text` y contexto (prefijo/sufijo, estilo W3C TextQuoteSelector) para poder re-anclar si el CFI falla. Ese texto también permitiría importar subrayados de Calibre buscando por texto.

---

## 8. Lenguaje de búsqueda, bibliotecas virtuales y búsquedas guardadas

Fuente: `manual/gui.rst` ("The search interface") y `db/search.py` + `utils/search_query_parser.py`.

- **Sintaxis:** términos separados por espacios (= `and`), `or`, `not`, paréntesis. Prefijo de campo `campo:valor` con los *lookup names*: `title`, `author(s)`, `tag(s)`, `series`, `series_index`, `publisher`, `rating`, `comments`, `format(s)`, `identifiers`, `languages`, `date` (alta), `pubdate`, `last_modified`, `size`, `cover`, `vl`, `search` (búsqueda guardada), `template`, columnas personalizadas `#mi_columna`, `marked` (libros marcados temporalmente), etc.
- **Tipos de coincidencia:** *contains* (por defecto, sin mayúsculas), `=` igualdad (`tag:"=ciencia ficción"`), `~` regex (`title:~^El`), `^` variantes de caracteres (acentos), jerárquicas `=.Historia` (prefijo) y `=..Militar` (componente). Super-comillas `"""..."""`.
- **Fechas y números:** `pubdate:>2000-1`, `date:<=45daysago`, `rating:>=4`, `size:>1M`, `_today`, `_yesterday`, `_thismonth`; especiales `true/false/empty`.
- **Identificadores:** `identifiers:isbn:9780…`, `identifiers:=goodreads:`.
- **Bibliotecas virtuales:** son simplemente **una búsqueda con nombre**, guardada en `preferences['virtual_libraries']` (`{"Sin leer": "not #leido:true"}`); restringen todo lo que se ve. El Content server las acepta con `?vl=`.
- **Búsquedas guardadas:** `preferences['saved_searches']`, usables como `search:"nombre"`; gestionables con `calibredb saved_searches`.
- **Categorías de usuario** (`user_categories`) y **tag browser** (navegación por facetas con conteos).
- **Full text search:** índice FTS5 en `full-text-search.db` del texto extraído de los libros (indexación en segundo plano, opcional), consultable en la GUI, `calibredb fts_search` y `/fts/search`.

Para nuestra app: **reutilizar** la búsqueda de Calibre en el servidor (vía `/ajax/search` o `calibredb search`) sirve para "búsqueda avanzada" o importar sus bibliotecas virtuales como colecciones. Para la búsqueda diaria, la indexación en Postgres (tsvector + trigram + pgvector) será más rápida y flexible.

---

## 9. Puntos débiles conocidos

**Diseño y concurrencia**
- **Un solo usuario y un solo proceso** sobre la biblioteca; sin WAL; caché en memoria sin detección de cambios externos. Correr GUI + servidor + scripts a la vez sobre la misma biblioteca no está soportado (`singleinstance`).
- **Unidades de red y nube:** el FAQ prohíbe NAS/unidades de red (*"Do not put your calibre library on a networked drive"*) y es tajante con Google Drive: *"Google Drive is incompatible with calibre … you will suffer data loss"*. Dropbox/rsync solo si **no** corren a la vez que Calibre.
- **Estructura de carpetas rígida** y nombres ASCII truncados (no se puede elegir la organización; el autor de Calibre se niega a cambiarlo).
- Un archivo por formato y libro; las anotaciones van por formato.

**Rendimiento**
- La GUI carga toda la BD en memoria al iniciar; en bibliotecas de 10-20 mil libros los usuarios reportan arranques de minutos (MobileRead, 2012-2014; mejoró mucho con el backend nuevo, pero columnas compuestas, plantillas y reglas de color siguen penalizando).
- El Content server renderiza el libro al abrirlo por primera vez (job), lo que da latencia en libros grandes.
- `/ajax/books?ids=all` en bibliotecas grandes es pesado; mejor paginar o leer SQLite.

**UX**
- Interfaz de escritorio densa, "de ingenieros"; el visor y el Content server son funcionales pero no se sienten nativos en móvil (es la motivación de nuestra app).
- PDF y cómics: sin visor interno decente, conversión de PDF mala.
- Metadatos de cómics: no lee `ComicInfo.xml` sin plugin.
- La descarga de metadatos por scraping (Amazon) se rompe con frecuencia y depende de actualizaciones de plugins.

**Seguridad**
- Contraseñas del servidor en texto plano en `server-users.sqlite`; auth Basic/Digest; `--enable-local-write` abre escritura a cualquier proceso local. Debe ir detrás de un proxy TLS y solo escuchar en `localhost` o en la red privada (Tailscale).
- Las recetas (`.recipe`) y plantillas Python ejecutan código: el servidor ya bloquea subirlas, pero no hay que exponerlas.

**Ecosistema**
- Proyectos como calibre-web, Kavita, Komga o Kobo-sync-servers nacieron precisamente porque Calibre no ofrece una API pública ni un buen lector multi-dispositivo. calibre-web escribe directo en `metadata.db` (registrando funciones como `title_sort`), lo que funciona pero choca si la GUI o el servidor de Calibre están abiertos a la vez.

---

## 10. Recomendaciones para Biblioteca Lectora

### 10.1 Reutilizar de Calibre (vía proceso, sin código)

| Capacidad | Cómo |
|---|---|
| Catálogo de metadatos (fuente de verdad del **libro**) | `metadata.db` leído en solo lectura + `calibre-server` |
| Alta de libros (bot de Telegram, botón "Conseguir") | `calibredb add` remoto o `POST /cdb/add-book` |
| Edición de metadatos y portada | `POST /cdb/set-fields` o `calibredb set_metadata --field` remoto |
| Descarga de metadatos/portadas | `fetch-ebook-metadata` como subproceso en un job, y luego `set-fields` |
| Conversión (MOBI/AZW3→EPUB, CBR→CBZ si hiciera falta) | `ebook-convert` como subproceso, en la cola de trabajos |
| Búsqueda avanzada y bibliotecas virtuales | `/ajax/search?query=&vl=` |
| Full-text search del contenido de libros | `/fts/search` (o reindexar nosotros en Postgres más adelante) |
| OPDS para lectores externos (KOReader, e-ink) | El `/opds` de Calibre, tal cual |
| Respaldo/restauración | `metadata.opf` por libro + `calibredb restore_database` como último recurso |

### 10.2 Replicar (con implementación propia)

- **Modelo de anotaciones:** `uuid` por subrayado, `timestamp` por modificación, *tombstones* `removed`, fusión por elemento con último en ganar, `highlighted_text` + notas indexadas para búsqueda, `toc_family_titles` para agrupar por capítulo. Lo mejoramos con: un campo de dispositivo, `updated_at` del servidor (no del cliente) para evitar relojes desfasados, versión/seq para sincronización incremental, y **TextQuoteSelector** además del CFI.
- **Progreso:** `(usuario, dispositivo, libro, formato) → (cfi, pos_frac, epoch)` como Calibre, más "último dispositivo gana" para el salto entre dispositivos.
- **Exportación** a Markdown/JSON compatible con `calibre_annotation_collection` (es un JSON simple; generarlo no copia código).
- **Búsqueda tipo Calibre** en la UI (chips `autor:`, `serie:`, `tag:`) sobre Postgres.

### 10.3 Evitar

- Escribir en `metadata.db` por fuera, o correr `calibredb` local mientras `calibre-server` está activo.
- Tener la biblioteca viva en Google Drive o en un montaje de red/FUSE (rclone mount).
- Importar módulos de Calibre en nuestro proceso, o portar su código (GPL).
- Usar el visor/render de Calibre para nuestra app, o depender de sus CFI como formato canónico.
- Exponer el Content server directamente a internet o a la app; la app solo habla con **nuestra** API.
- Descargar por `/get/{fmt}` para calcular hashes (incrusta metadatos y cambia el archivo): leer del disco.
- Convertir PDFs.

### 10.4 Diseño del adaptador `CalibreLibrarySource`

```
                ┌──────────────────── Servidor (Docker compose) ─────────────────────┐
                │                                                                     │
 App / Web ───► │  FastAPI ── LibrarySource (interfaz)                                │
 Bot ─────────► │     │         └─ CalibreAdapter                                     │
                │     │              ├─ CatalogReader   (SQLite ro → Postgres)        │
                │     │              ├─ FileResolver    (books.path + data.name)      │
                │     │              ├─ CalibreWriter   (HTTP → calibre-server /cdb)  │
                │     │              └─ CalibreTools    (subprocesos: ebook-convert,  │
                │     │                                  fetch-ebook-metadata,        │
                │     │                                  ebook-meta)                  │
                │     ├─ Postgres: books_cache, highlights, progress, embeddings      │
                │     └─ Cola de trabajos (import, convert, fetch_metadata, sync)     │
                │                                                                     │
                │  calibre-server (único dueño) --listen-on 127.0.0.1                 │
                │     --enable-auth --userdb /config/users.sqlite                     │
                │     /library (disco local) ──► snapshot SQLite + rclone copy → Drive│
                └─────────────────────────────────────────────────────────────────────┘
```

**Identidad de libros:** clave externa `(calibre_library_uuid, calibre_book_uuid)`; guardar también `calibre_book_id` (para llamadas a la API) y, por formato, `sha256` del archivo en disco + `size` + `mtime`. Los subrayados se ligan a `(book_uuid, format, file_sha256)`; si el archivo cambia (p. ej. `embed_metadata` reescribe el OPF interno del EPUB), el CFI de los capítulos suele seguir siendo válido, pero conviene marcar "re-verificar anclas".

**CatalogReader (sincronización incremental):**
1. Cada N segundos (o tras un job de escritura propio): abrir `metadata.db` con `mode=ro`, `SELECT id, uuid, last_modified FROM books WHERE last_modified > :cursor`.
2. Para esos ids, leer `books`, autores (ordenados por `books_authors_link.id`), series, tags, identifiers, comments, languages, publisher, rating, `data` y columnas personalizadas relevantes (p. ej. `#leido`).
3. Upsert en Postgres; comparar el conjunto total de ids para detectar borrados.
4. Cerrar la conexión enseguida (no bloquear al escritor sin WAL). Alternativa sin acceso al archivo: `GET /ajax/search?query=last_modified:>…` + `/ajax/books?ids=…`.

**FileResolver:** `GET /api/books/{uuid}/file/{fmt}` en nuestra API → resuelve la ruta desde el caché de Postgres (actualizado por CatalogReader) y verifica que exista; si no, relee de SQLite. Sirve el archivo con `Range` y `ETag = sha256`. Portadas: `cover.jpg` + miniaturas propias (o `/get/thumb/{id}?sz=…` del servidor como atajo).

**CalibreWriter:**
- `add_book(file, metadata)` → `POST /cdb/add-book/{job}/n/{filename}` → `book_id` o `duplicates` → `POST /cdb/set-fields/{book_id}` con metadatos del bot/identify → disparar CatalogReader.
- `update_metadata(book_id, changes)` → `POST /cdb/set-fields`.
- `delete_book` → `POST /cdb/delete-books` (va a `.caltrash`).
- Autenticación: usuario dedicado `lectora-api` con escritura, Basic auth sobre `127.0.0.1` (o `--enable-local-write` si el servidor solo escucha en localhost y nada más corre en la máquina).
- Fijar la versión de Calibre en la imagen Docker y tener tests de contrato del adaptador (los endpoints no son estables entre versiones).

**CalibreTools (en la cola de trabajos, con timeouts):**
- `fetch-ebook-metadata --isbn … --opf --cover /tmp/c.jpg` → parsear OPF → `set-fields`.
- `ebook-convert in.azw3 out.epub` → `calibredb add_format` remoto (para tener EPUB como formato de lectura principal).
- Opcional: `ebook-meta` para leer metadatos de un archivo antes de añadirlo (deduplicación por ISBN/título).

**Respaldo:** job nocturno: `sqlite3 metadata.db ".backup /backup/metadata.db"` (consistente aunque el servidor esté corriendo) + `rclone copy /library drive:… --exclude metadata.db` + `rclone copy /backup/metadata.db …`, con versionado en Drive. Mismo trato para `full-text-search.db` y `.calnotes/`.

**Importación inicial de anotaciones de Calibre (opcional):** leer `annotations` (`annot_type='highlight'`, `removed` ausente), mapear `highlighted_text`, `notes`, `timestamp`, `toc_family_titles`; re-anclar en foliate-js buscando el texto en el capítulo `spine_index` y guardar el CFI resultante. No escribir de vuelta en Calibre salvo que se quiera mantener su visor (no es el caso).

**Detrás de la interfaz `LibrarySource`** (vision §7): la versión pública podrá cambiar `CalibreAdapter` por `OpdsAdapter` o `FolderAdapter` sin tocar la app, porque la app nunca ve endpoints ni ids de Calibre.

### 10.5 Ajustes a `vision-producto.md`

- §3.1: precisar que `calibredb` debe usarse **en modo remoto contra el `calibre-server`** (o la API `/cdb`), y que el respaldo debe partir de un snapshot consistente de SQLite.
- §4 ("mismas anclas CFI en las cuatro plataformas"): correcto entre clientes foliate-js; **no** asumir compatibilidad con los CFI del visor de Calibre.
- §10 (formatos): si se leen cómics con `ComicInfo.xml`, planear un parser propio en la importación (Calibre no lo lee por defecto).

---

## Fuentes

**Código (permalinks al commit `a5f438b`):** base `https://github.com/kovidgoyal/calibre/blob/a5f438bfa3feb463d855a7ce2282fab967e3e3da/`
- Esquema: [resources/metadata_sqlite.sql](https://github.com/kovidgoyal/calibre/blob/a5f438bfa3feb463d855a7ce2282fab967e3e3da/resources/metadata_sqlite.sql)
- Backend SQL, funciones, rutas, custom columns: [src/calibre/db/backend.py](https://github.com/kovidgoyal/calibre/blob/a5f438bfa3feb463d855a7ce2282fab967e3e3da/src/calibre/db/backend.py) (L453-485 conexión; L1502 custom columns; L1771-1815 rutas; L346-400 anotaciones)
- API en memoria: [src/calibre/db/cache.py](https://github.com/kovidgoyal/calibre/blob/a5f438bfa3feb463d855a7ce2282fab967e3e3da/src/calibre/db/cache.py) · locks: [src/calibre/db/locking.py](https://github.com/kovidgoyal/calibre/blob/a5f438bfa3feb463d855a7ce2282fab967e3e3da/src/calibre/db/locking.py) · constantes: [src/calibre/db/constants.py](https://github.com/kovidgoyal/calibre/blob/a5f438bfa3feb463d855a7ce2282fab967e3e3da/src/calibre/db/constants.py) · respaldo OPF: [src/calibre/db/backup.py](https://github.com/kovidgoyal/calibre/blob/a5f438bfa3feb463d855a7ce2282fab967e3e3da/src/calibre/db/backup.py)
- Fusión de anotaciones: [src/calibre/db/annotations.py](https://github.com/kovidgoyal/calibre/blob/a5f438bfa3feb463d855a7ce2282fab967e3e3da/src/calibre/db/annotations.py) · creación en el visor: [src/pyj/read_book/annotations.pyj](https://github.com/kovidgoyal/calibre/blob/a5f438bfa3feb463d855a7ce2282fab967e3e3da/src/pyj/read_book/annotations.pyj) · CFI: [src/pyj/read_book/cfi.pyj](https://github.com/kovidgoyal/calibre/blob/a5f438bfa3feb463d855a7ce2282fab967e3e3da/src/pyj/read_book/cfi.pyj) · exportación: [src/calibre/gui2/library/annotations.py](https://github.com/kovidgoyal/calibre/blob/a5f438bfa3feb463d855a7ce2282fab967e3e3da/src/calibre/gui2/library/annotations.py) · OPF: [src/calibre/ebooks/metadata/opf2.py](https://github.com/kovidgoyal/calibre/blob/a5f438bfa3feb463d855a7ce2282fab967e3e3da/src/calibre/ebooks/metadata/opf2.py)
- Content server: [srv/ajax.py](https://github.com/kovidgoyal/calibre/blob/a5f438bfa3feb463d855a7ce2282fab967e3e3da/src/calibre/srv/ajax.py), [srv/content.py](https://github.com/kovidgoyal/calibre/blob/a5f438bfa3feb463d855a7ce2282fab967e3e3da/src/calibre/srv/content.py), [srv/books.py](https://github.com/kovidgoyal/calibre/blob/a5f438bfa3feb463d855a7ce2282fab967e3e3da/src/calibre/srv/books.py), [srv/cdb.py](https://github.com/kovidgoyal/calibre/blob/a5f438bfa3feb463d855a7ce2282fab967e3e3da/src/calibre/srv/cdb.py), [srv/opds.py](https://github.com/kovidgoyal/calibre/blob/a5f438bfa3feb463d855a7ce2282fab967e3e3da/src/calibre/srv/opds.py), [srv/fts.py](https://github.com/kovidgoyal/calibre/blob/a5f438bfa3feb463d855a7ce2282fab967e3e3da/src/calibre/srv/fts.py), [srv/convert.py](https://github.com/kovidgoyal/calibre/blob/a5f438bfa3feb463d855a7ce2282fab967e3e3da/src/calibre/srv/convert.py), [srv/auth.py](https://github.com/kovidgoyal/calibre/blob/a5f438bfa3feb463d855a7ce2282fab967e3e3da/src/calibre/srv/auth.py), [srv/users.py](https://github.com/kovidgoyal/calibre/blob/a5f438bfa3feb463d855a7ce2282fab967e3e3da/src/calibre/srv/users.py), [srv/opts.py](https://github.com/kovidgoyal/calibre/blob/a5f438bfa3feb463d855a7ce2282fab967e3e3da/src/calibre/srv/opts.py), [srv/standalone.py](https://github.com/kovidgoyal/calibre/blob/a5f438bfa3feb463d855a7ce2282fab967e3e3da/src/calibre/srv/standalone.py), [srv/render_book.py](https://github.com/kovidgoyal/calibre/blob/a5f438bfa3feb463d855a7ce2282fab967e3e3da/src/calibre/srv/render_book.py)
- calibredb: [src/calibre/db/cli/main.py](https://github.com/kovidgoyal/calibre/blob/a5f438bfa3feb463d855a7ce2282fab967e3e3da/src/calibre/db/cli/main.py) y `cmd_*.py` en [src/calibre/db/cli/](https://github.com/kovidgoyal/calibre/tree/a5f438bfa3feb463d855a7ce2282fab967e3e3da/src/calibre/db/cli)
- Fuentes de metadatos: [identify.py](https://github.com/kovidgoyal/calibre/blob/a5f438bfa3feb463d855a7ce2282fab967e3e3da/src/calibre/ebooks/metadata/sources/identify.py), [covers.py](https://github.com/kovidgoyal/calibre/blob/a5f438bfa3feb463d855a7ce2282fab967e3e3da/src/calibre/ebooks/metadata/sources/covers.py), [update.py](https://github.com/kovidgoyal/calibre/blob/a5f438bfa3feb463d855a7ce2282fab967e3e3da/src/calibre/ebooks/metadata/sources/update.py), [amazon.py](https://github.com/kovidgoyal/calibre/blob/a5f438bfa3feb463d855a7ce2282fab967e3e3da/src/calibre/ebooks/metadata/sources/amazon.py), [google.py](https://github.com/kovidgoyal/calibre/blob/a5f438bfa3feb463d855a7ce2282fab967e3e3da/src/calibre/ebooks/metadata/sources/google.py), [openlibrary.py](https://github.com/kovidgoyal/calibre/blob/a5f438bfa3feb463d855a7ce2282fab967e3e3da/src/calibre/ebooks/metadata/sources/openlibrary.py), [customize/builtins.py](https://github.com/kovidgoyal/calibre/blob/a5f438bfa3feb463d855a7ce2282fab967e3e3da/src/calibre/customize/builtins.py), metadatos de cómics [ebooks/metadata/archive.py](https://github.com/kovidgoyal/calibre/blob/a5f438bfa3feb463d855a7ce2282fab967e3e3da/src/calibre/ebooks/metadata/archive.py)
- Conversión: [ebooks/conversion/plugins/](https://github.com/kovidgoyal/calibre/tree/a5f438bfa3feb463d855a7ce2282fab967e3e3da/src/calibre/ebooks/conversion/plugins) (en especial `comic_input.py`, `pdf_input.py`), [ebooks/conversion/plumber.py](https://github.com/kovidgoyal/calibre/blob/a5f438bfa3feb463d855a7ce2282fab967e3e3da/src/calibre/ebooks/conversion/plumber.py)
- Formatos del visor interno: [src/calibre/gui2/__init__.py](https://github.com/kovidgoyal/calibre/blob/a5f438bfa3feb463d855a7ce2282fab967e3e3da/src/calibre/gui2/__init__.py) (L727)
- Licencia: [LICENSE](https://github.com/kovidgoyal/calibre/blob/a5f438bfa3feb463d855a7ce2282fab967e3e3da/LICENSE), [COPYRIGHT](https://github.com/kovidgoyal/calibre/blob/a5f438bfa3feb463d855a7ce2282fab967e3e3da/COPYRIGHT)

**Manual oficial:**
- FAQ (formatos, carpetas, red/NAS, Google Drive, licencia, servidor en Linux): https://manual.calibre-ebook.com/faq.html
- Content server (usuarios por CLI, reverse proxy, `--url-prefix`): https://manual.calibre-ebook.com/server.html
- calibredb: https://manual.calibre-ebook.com/generated/en/calibredb.html
- calibre-server: https://manual.calibre-ebook.com/generated/en/calibre-server.html
- ebook-convert: https://manual.calibre-ebook.com/generated/en/ebook-convert.html · Conversión (PDF, cómics): https://manual.calibre-ebook.com/conversion.html
- fetch-ebook-metadata: https://manual.calibre-ebook.com/generated/en/fetch-ebook-metadata.html
- Interfaz y lenguaje de búsqueda: https://manual.calibre-ebook.com/gui.html#the-search-interface
- Bibliotecas virtuales: https://manual.calibre-ebook.com/virtual_libraries.html
- Visor y highlights: https://manual.calibre-ebook.com/viewer.html
- Esquema de URL `calibre://`: https://manual.calibre-ebook.com/url_scheme.html
- API de la base de datos: https://manual.calibre-ebook.com/db_api.html

**Foros (anecdóticos, mayormente 2011-2019):**
- Google Drive y Calibre (citado por el FAQ): https://www.mobileread.com/forums/showthread.php?t=205581
- Rendimiento en bibliotecas grandes: https://www.mobileread.com/forums/showthread.php?p=2228013 · https://www.mobileread.com/forums/showthread.php?p=1461347
- Servidor que no detecta cambios externos / Dropbox: https://www.mobileread.com/forums/showthread.php?p=2323776
- calibre-web y escritura en `metadata.db`: https://mobileread.com/forums/showthread.php?p=3807196
