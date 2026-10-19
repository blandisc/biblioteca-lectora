# 02 · Servidores de biblioteca self-hosted y sus ecosistemas

> Investigación para **Biblioteca Lectora**. Fecha de corte: **19 de octubre de 2026**.
> Las estrellas y fechas de GitHub se tomaron de la API de búsqueda de GitHub ese día. Las versiones salen de las páginas de *releases* de cada repo. Donde la fuente es de la comunidad (foros, Lemmy) se indica, y lo no verificado va marcado como **(verificar)**.

---

## 0. Resumen ejecutivo

- **Ningún servidor existente cubre el ciclo completo** (conseguir → leer en apps nativas Apple → subrayar con anclas estables → exportar a Readwise → insights con LLM local). Todos se quedan en "catálogo + lector web + sincronizar progreso".
- **Los únicos que usan Calibre como catálogo son calibre-web, Calibre-Web-Automated (CWA), sus forks y COPS.** Kavita, Komga, Grimmory (ex-BookLore), Stump y Audiobookshelf tienen **su propia base de datos** y escanean carpetas. Si se adopta alguno de ellos, Calibre deja de ser la fuente de verdad o se duplica la biblioteca.
- **CWA es el mejor "pipeline de ingesta" del ecosistema Calibre** (carpeta de ingesta, conversión, EPUB fixer, metadatos con Hardcover, KOReader sync, Kobo sync, deduplicación). Pero es un monolito Flask con UI renderizada en servidor y **sin API pública**. Además, el *upstream* va lento y la comunidad ya mantiene un fork (Calibre-Web-NextGen).
- **El propio content server de Calibre tiene un API poco conocido** de progreso de lectura (CFI + `pos_frac`) y de anotaciones por usuario (`/book-get-annotations`, `/book-update-annotations`), además de `calibredb` remoto (`/cdb/cmd`). Eso permite **un único escritor** sobre `metadata.db`.
- **Recomendación:** construir **nuestra propia API (FastAPI) sobre Calibre**, como ya plantea `vision-producto.md`. Copiar *ideas* de CWA (no su código) y exponer los protocolos estándar como "adaptadores": **OPDS 1.2 + PSE**, **OPDS 2.0**, **KOReader sync (kosync)** y, más adelante, **Kobo sync**. Las anotaciones se guardan como **W3C Web Annotations** con selectores **EPUB CFI + TextQuote + Readium Locator**.

---

## 1. Tabla comparativa

Leyenda: ✅ nativo · 🟡 parcial / vía plugin / limitado · ❌ no · ? no documentado.

| Proyecto | Stack | Licencia | ★ (oct-2026) · última actividad | Usa Calibre DB | Metadatos | OPDS | KOReader sync | Kobo sync | Send-to-Kindle | Multiusuario / SSO | Highlights | Lector web | Apps móviles | API |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **calibre-web** | Python/Flask, SQLAlchemy | GPL-3.0 | 18.4k · v0.6.27 (ago-2026) | ✅ (lee y escribe `metadata.db`) | Google, Amazon, ComicVine, Douban, etc. | 1.2 | ❌ (plugin de terceros) | ✅ (proxy de la tienda Kobo, estado de lectura, Instapaper) | ✅ SMTP | ✅ LDAP, OAuth, reverse-proxy header | ❌ | 🟡 epub.js, pdf.js, comics | ❌ (Calibre Web Companion, de terceros) | ❌ |
| **Calibre-Web-Automated (CWA)** | Python/Flask (fork de calibre-web) + binarios de Calibre | GPL-3.0 | 6.4k · v4.0.8 (28-sep-2026) | ✅ | + Hardcover, ibdb, Kobo, LitRes; *metadata enforcement* en el archivo | 1.2 | ✅ (endpoint `/kosync`, MD5 parcial) | ✅ (+ Magic Shelves → Kobo) | ✅ + *Auto-Send* tras ingesta | ✅ OIDC | 🟡 (en NextGen, highlights Kobo/KOReader) | 🟡 (nuevo lector en el roadmap) | ❌ | ❌ (solo OPDS/kosync) |
| **Calibre-Web-NextGen** | fork de CWA | GPL-3.0 | 288 · activo (may-2026→) | ✅ | = CWA | 1.2 | ✅ + highlights | ✅ + canal de anotaciones | ✅ | ✅ | 🟡 | 🟡 | ❌ | ❌ |
| **Kavita** | C# .NET + Angular, SQLite | GPL-3.0 (+ Kavita+ de pago) | 11.9k · v0.9.1.4 (sep-2026) | ❌ | ComicInfo, EPUB OPF; Kavita+ (Hardcover, AniList, MAL) | 1.2 + PSE | ✅ (desde 0.8.7; todos los formatos desde 0.8.9) | ❌ ? | ❌ ? | ✅ roles, edad, OIDC | ✅ EPUB (export, Obsidian) | ✅ muy bueno (manga/webtoon, EPUB paginado) | 🟡 terceros (Paperback, Panels, Mihon) | ✅ REST/OpenAPI |
| **Komga** | Kotlin/Spring Boot, SQLite | MIT | 6.8k · 1.29.1 (14-oct-2026) | ❌ | ComicInfo, EPUB, *Notable Entities* | 1.2 (+PSE) y 2.0 | ✅ (`/koreader`, por capítulo) | ✅ (kepubify al vuelo) | ❌ | ✅ restricciones por edad y etiquetas, OAuth2 | ❌ ? | ✅ (lector EPUB basado en Readium) | 🟡 terceros (Komelia, Mihon, Paperback, Panels) | ✅ REST/OpenAPI, la mejor documentada |
| **Grimmory** (ex-BookLore) | Java/Spring Boot + Angular, MariaDB | AGPL-3.0 | 4.6k (creado mar-2026) · v3.5.0 (sep-2026) | ❌ | Google, Open Library, Amazon, Goodreads, Douban, Apple Books, Hardcover | ✅ (versión ?) | ✅ (+ `grimmory.koplugin`) | ✅ | ✅ email/Kindle | ✅ OIDC | ✅ en lector web | ✅ EPUB/PDF/cómic | ❌ | ✅ OpenAPI (desactivada por defecto) |
| **Audiobookshelf** (lado ebook) | Node.js + Vue/Nuxt, SQLite | GPL-3.0 | 14.7k · activo | ❌ | Audible, Google, Open Library, iTunes… | ❌ (FR) | ❌ (solo vía BookBridge) | ❌ | ✅ "send to e-reader" | ✅ | ❌ | 🟡 "soporte básico", progreso solo del ebook primario | ✅ oficiales (iOS/Android) | ✅ REST + Socket.IO |
| **Stump** | Rust (Axum, SeaORM) + React; Tauri; Expo | MIT (app Expo GPL-3.0) | 2.8k · v0.1.10 (sep-2026), beta | ❌ | ComicInfo, EPUB | 1.2 + PSE y 2.0 | ✅ | ✅ | ? | ✅ OIDC, edad | ✅ EPUB | ✅ | ✅ propia (Expo) + desktop Tauri | ✅ |
| **COPS** (fork mikespub) | PHP ≥ 8.4 | GPL-2.0 | 1.5k (seblucas, inactivo desde 2024); fork mikespub activo, 4.x | ✅ (solo lectura, más edición de EPUB) | (los de Calibre) | 1.2 (2.0 en el fork, **verificar**) | ❌ | ❌ | 🟡 | 🟡 básico | ❌ | 🟡 epub.js | ❌ | 🟡 `restapi` |
| **Ubooquity** | Java, cerrado (freeware) | Propietaria | — · 3.1.0 (empaquetado en NAS en 2026) | ❌ | básico | 1.2 + **PSE (lo inventó)** | ❌ | ❌ | ❌ | 🟡 | ❌ | 🟡 | ❌ | ❌ |
| **Readarr** | C# .NET (*arr) | GPL-3.0 | 3.5k · **archivado 27-jun-2025** | 🟡 (integración con Calibre) | Goodreads, ya muerto | — | — | — | — | — | — | — | — | ✅ *arr API |
| **LazyLibrarian** | Python | GPL-3.0 | GitLab (el espejo de GitHub está viejo) · activo | 🟡 importa con `calibredb` | Google, Open Library, Hardcover… | ✅ | ❌ | ❌ | ✅ email | 🟡 | ❌ | ❌ | ❌ | ✅ |
| **Kapowarr** (cómics) | Python/Flask | GPL-3.0 | 1.1k · activo (oct-2026) | ❌ | ComicVine | ❌ | — | — | — | 🟡 | — | ❌ | ❌ | ✅ |
| **Mylar3** (cómics) | Python | GPL-3.0 | 1.5k · último push mar-2026 | ❌ | ComicVine; escribe ComicInfo (ComicTagger) | 🟡 | — | — | — | 🟡 | — | ❌ | ❌ | ✅ |
| **Shelfmark** (antes *cwa-book-downloader*) | Python + TS/Vite | MIT | 4.0k · activo | → carpeta de ingesta de CWA/Grimmory | Hardcover, Open Library, Google | — | — | — | — | ✅ solicitudes con aprobación | — | — | — | ✅ API key |
| **KOReader sync server** (referencia) | Lua/OpenResty + Redis | AGPL-3.0 | 786 · activo (sep-2026) | — | — | — | ✅ *es* el protocolo | — | — | ✅ | ❌ | — | — | ✅ |

Repos: [calibre-web](https://github.com/janeczku/calibre-web) · [CWA](https://github.com/crocodilestick/Calibre-Web-Automated) · [Calibre-Web-NextGen](https://github.com/new-usemame/Calibre-Web-NextGen) · [Kavita](https://github.com/Kareadita/Kavita) · [Komga](https://github.com/gotson/komga) · [Grimmory](https://github.com/grimmory-tools/grimmory) · [Audiobookshelf](https://github.com/advplyr/audiobookshelf) · [Stump](https://github.com/stumpapp/stump) · [COPS (mikespub)](https://github.com/mikespub-org/seblucas-cops) · [Readarr](https://github.com/Readarr/Readarr) · [LazyLibrarian (GitLab)](https://gitlab.com/LazyLibrarian/LazyLibrarian) · [Kapowarr](https://github.com/Casvt/Kapowarr) · [Mylar3](https://github.com/mylar3/mylar3) · [Shelfmark](https://github.com/calibrain/shelfmark) · [koreader-sync-server](https://github.com/koreader/koreader-sync-server)

---

## 2. Fichas por proyecto

### 2.1 calibre-web
- **Qué es:** UI web sobre una biblioteca Calibre existente. Lee y **escribe directamente** `metadata.db` con su propio ORM. Usa `ebook-convert` de Calibre para convertir.
- **Fuertes:** proyecto muy maduro (18.4k ★). Kobo sync real: el Kobo se apunta al servidor (`api_endpoint`), y este responde al protocolo de la tienda y redirige al servidor de Kobo lo que no conoce. Envío por SMTP (Kindle), OPDS, LDAP/OAuth/reverse-proxy, estanterías, permisos por usuario. La v0.6.26 añadió Instapaper en Kobo sync y edición masiva; la v0.6.27 (ago-2026), extracción de metadatos de MOBI y login por cabecera de proxy con secreto compartido ([releases](https://github.com/janeczku/calibre-web/releases)).
- **Débiles:** UI anticuada, sin API pública y sin KOReader sync nativo. Escribe en `metadata.db` sin pasar por Calibre (riesgo de concurrencia si Calibre desktop o `calibredb` escriben a la vez). El mantenedor principal tiene poco tiempo.
- **Para copiar:** el **proxy de Kobo** (responder lo propio y reenviar lo desconocido a la tienda oficial) y la "magic link" para iniciar sesión en e-readers.

### 2.2 Calibre-Web-Automated (CWA)
- **Qué es:** fork de calibre-web en un solo contenedor con los binarios de Calibre, pensado para "no tener que abrir nunca Calibre desktop" ([README](https://github.com/crocodilestick/Calibre-Web-Automated)).
- **Funciones clave:**
  - **Carpeta de ingesta** `/cwa-book-ingest` (27 formatos). Vigila con `inotify` o por *polling* en NFS/SMB. Borra el archivo tras importar e incluye un botón "Library Refresh" para reprocesar.
  - **Conversión automática** a EPUB (o MOBI/AZW3/KEPUB/PDF) con reglas por formato.
  - **EPUB Fixer** (basado en *kindle-epub-fix*): corrige encoding, NCX, `lang` y CSS para que Amazon Send-to-Kindle acepte el archivo.
  - **Metadata enforcement:** lo que se edita en la UI se **escribe dentro del archivo**, así el dispositivo y la biblioteca coinciden.
  - **Metadatos al ingerir**, con proveedores en orden y *fallback*: **Hardcover** (token), ibdb, Kobo, LitRes.
  - **KOReader sync integrado** (`/kosync`, MD5 parcial calculado automáticamente, Basic Auth con las cuentas de CWA). El progreso fluye KOReader → CWA → Kobo. En la v4.0.7 (sep-2026) el progreso de KOReader **también se envía a Hardcover**.
  - **Auto-Send** por email tras la ingesta, con retraso configurable para que primero terminen metadatos y fixer.
  - **Detección de duplicados** (SQL + *fuzzy*), Magic Shelves (estanterías por reglas, sincronizables a Kobo), estadísticas con exportación CSV, OIDC con mapeo de grupos.
- **Estado:** v4.0.8 (28-sep-2026). Hubo una pausa larga entre la v4.0.6 (feb-2026) y la v4.0.7. La comunidad creó **Calibre-Web-NextGen** (may-2026), que publica rápido los PR pendientes y añade **sincronización de highlights** de Kobo (canal de *reading services*) y KOReader ([NextGen](https://github.com/new-usemame/Calibre-Web-NextGen)). Otro fork, **autocaliweb**, se mudó a Codeberg y archivó GitHub.
- **Débiles:** monolito Flask/Jinja heredado, sin API REST, una sola biblioteca por instancia y lector web flojo (el nuevo lector está en el roadmap). El ritmo depende de una sola persona.
- **Ecosistema:** **Shelfmark** (búsqueda y solicitud de descargas que deja los archivos en la carpeta de ingesta) y **Calibre Web Companion** (app Flutter para Android).

### 2.3 Kavita
- **Stack:** .NET + Angular, SQLite. Licencia GPL-3.0. **Kavita+** es una suscripción de pago para metadatos externos, recomendaciones y *scrobbling* ([README](https://github.com/Kareadita/Kavita)).
- **Fuertes:** probablemente el **mejor lector web** del grupo para cómics y manga (webtoon, doble página, continuo) y bueno para EPUB (páginas virtuales). **Anotaciones y highlights en EPUB** que guardan contexto, capítulo y página, con exportación e importador para **Obsidian** ([wiki EPUB reader](https://wiki.kavitareader.com/guides/readers/epub/)). Listas de lectura (importa CBL), *smart filters*, estadísticas y diario de lectura (v0.8.9, ene-2026). OPDS 1.2 + PSE y **KOReader sync bidireccional** desde la v0.8.7, extendido a PDF y archivos en la v0.8.9 ([wiki KOReader](https://wiki.kavitareader.com/guides/3rdparty/koreader/)). La v0.9.1 (ago-2026) añadió log de auditoría, recomendaciones de Hardcover y *scrobbling* a AniList, MAL y Hardcover ([releases](https://github.com/Kareadita/Kavita/releases)).
- **Débiles:** no usa Calibre. La wiki misma desaconseja la sincronización automática con KOReader porque "puede deshacer progreso". Hay un caso reportado de errores 400 en la v0.8.9.1 ([issue #4518](https://github.com/Kareadita/Kavita/issues/4518)). Los metadatos ricos son de pago. Sin Kobo sync documentado. En may-2026 corrigió una vulnerabilidad crítica que afectaba a todas las versiones previas.
- **Para copiar:** exportar anotaciones a Markdown/Obsidian, guardar el **contexto alrededor del highlight**, el diario de lectura y el *scrobbling* a servicios externos (Hardcover).

### 2.4 Komga
- **Stack:** Kotlin + Spring Boot, SQLite. **MIT**. 6.8k ★, solo 12 issues abiertos (muy bien mantenido) ([repo](https://github.com/gotson/komga)).
- **Fuertes:** la **API REST mejor diseñada** del grupo, con un ecosistema enorme de clientes de terceros (Komelia, Mihon/Tachiyomi, Paperback, Panels, KOReader). OPDS **v1 y v2**. **Kobo Sync** (solo EPUB, convertido a KEPUB al vuelo con kepubify) y **KOReader Sync** (`/koreader`, la API key va como usuario y requiere *hashing* de archivos activado). Lector EPUB basado en el modelo Readium, con progreso guardado como *locator*. Importa listas CBL. La v1.29 (oct-2026) trajo *Notable Entities* (metadatos extensibles por libro), OAuth2 y la nueva **NextUI** ([releases](https://github.com/gotson/komga/releases)).
- **Limitación importante:** en Kobo con EPUB normal y en KOReader **el progreso se sincroniza a nivel de capítulo**, no dentro del capítulo ([guía Kobo](https://komga.org/docs/guides/kobo), [guía KOReader](https://komga.org/docs/guides/koreader)). La razón es que traducir entre XPointer (KOReader), los *spans* de KEPUB y el locator de Readium es difícil.
- **Para copiar:** API-first con OpenAPI, roles finos (`KOBO_SYNC`, `KOREADER_SYNC`, `FILE_DOWNLOAD`), kepubify en el momento de la descarga en lugar de guardar duplicados y una sola licencia MIT.

### 2.5 Grimmory (antes BookLore)
- **Historia:** BookLore (Java/Angular, muy popular en 2025) **cerró en marzo de 2026**: el autor borró repo, web y Discord tras conflictos sobre código generado con IA, licencias y la comunidad ([Lemmy: "Booklore is officially dead"](https://deddit.petersanchez.com/g/selfhosted@lemmy.world/p/3CFT1zkTgLn5SnY9hR-Booklore-is-officially-dead), [AUR](https://aur.archlinux.org/packages/booklore)). Hoy existe un `booklore-app/booklore` con 1.3k ★, pero la comunidad y los contribuidores pasaron a **Grimmory** ([repo](https://github.com/grimmory-tools/grimmory), 4.6k ★ en 7 meses).
- **Fuertes:** UI moderna, **BookDrop** (carpeta vigilada → metadatos → **cola de revisión** antes de importar), *smart shelves*, muchos proveedores de metadatos (OpenLibrary y Apple Books añadidos en la v3.4.0), Kobo + KOReader sync con su propio plugin `grimmory.koplugin`, lector web con highlights y envío a Kindle. Soporta ebooks, cómics y audiolibros, OIDC y OpenAPI. Ya hay un servidor MCP de la comunidad ([grimmory-mcp](https://github.com/bannert1337/grimmory-mcp)).
- **Débiles:** no usa Calibre, requiere MariaDB y JVM (consumo de memoria) y su gobernanza es joven. Las releases de septiembre de 2026 son mayormente de **seguridad** (control de acceso en `/api/v1/settings`, EPUB malicioso que agota CPU) ([releases](https://github.com/grimmory-tools/grimmory/releases)).
- **Para copiar:** la **cola de revisión de ingesta** (no importar a ciegas) y `DISK_TYPE=NETWORK`, que desactiva operaciones destructivas en montajes de red.

### 2.6 Audiobookshelf (lado ebook)
- **Fuertes:** apps móviles oficiales, **API REST + Socket.IO** muy usadas por terceros y una comunidad grande (14.7k ★).
- **Ebooks:** la documentación oficial lo llama **"soporte básico"**: EPUB, PDF, CBR/CBZ, MOBI/AZW3 (en estos dos sin progreso) y progreso solo del **ebook primario** del item. Recomienda usar calibre-web para uso serio de ebooks ([docs ebooks](https://www.audiobookshelf.org/docs/documentation/libraries/book-library/ebooks)). Tiene "send to e-reader" por email. Sin OPDS ni highlights.
- **Para copiar:** el *push* de progreso en tiempo real por WebSocket.

### 2.7 Stump
- **Stack:** **Rust** (Axum + SeaORM) + React, desktop con Tauri y app móvil propia con Expo. MIT. Beta (v0.1.x) ([README](https://github.com/stumpapp/stump)).
- **Fuertes:** el **soporte de protocolos más completo**: OPDS 1.2 **con PSE** y **OPDS 2.0**, Kobo + KOReader sync, OIDC, anotaciones EPUB. Es ligero.
- **Débiles:** sigue en beta. En sep-2026 publicó tres releases seguidas por seguridad, entre ellas una escalada de permisos y metadatos visibles entre bibliotecas ([releases](https://github.com/stumpapp/stump/releases)). No usa Calibre.
- **Para copiar:** separar el núcleo (Rust) de los clientes y servir OPDS 1.2 y 2.0 en paralelo.

### 2.8 Readarr y sucesores
- **Readarr fue retirado y su repo archivado** (último push el 27-jun-2025). Motivo: metadatos (Goodreads) inutilizables y la migración a Open Library estancada ([anuncio replicado](https://piefed.jeena.net/post/195134)).
- **Sucesores:** **bookshelf** (fork de *pennydreadful* con imagen de metadatos de Hardcover), **Chaptarr** (fork muy modificado y polémico), el proxy de metadatos **rreading-glasses** ([repo](https://github.com/blampe/rreading-glasses), 1.6k ★), **Shelfmark** y LazyLibrarian ([hilo de reemplazos](https://piefed.jeena.net/post/332893), [DietPi](https://dietpi.com/forum/t/readarr-has-been-retired-what-about-lazylibrarian-instead/24105)).
- **Lección:** **no depender de una sola fuente de metadatos.** Hardcover se convirtió en la fuente de facto de 2025-2026, con Open Library y Google como *fallback*.

### 2.9 LazyLibrarian
- Python, GPL-3.0, vive en **GitLab** (el espejo de GitHub no se actualiza desde 2022). Gestiona ebooks, audiolibros, revistas y cómics, importa a Calibre con `calibredb`, ofrece OPDS y notifica por **Telegram**, Discord y email. Tiene descarga directa y "black hole". Su configuración es compleja.
- **Para copiar:** la importación vía `calibredb` (respeta los bloqueos de Calibre) y los notificadores enchufables.

### 2.10 Ubooquity
- Java, **código cerrado** (freeware). La versión 3.1.0 está empaquetada en NAS ASUSTOR (actualizado may-2026). **Creó OPDS-PSE**, el estándar de facto para el *streaming* de páginas de cómics. Su desarrollo es lento y no es buena base. Hoy su valor es histórico.

### 2.11 COPS
- PHP, GPL-2.0. El original (seblucas) está inactivo desde 2024. El **fork mikespub** está activo (4.x, PHP 8.4+) ([README](https://github.com/mikespub-org/seblucas-cops)). Es un servidor OPDS/HTML **ligerísimo** sobre `metadata.db` (solo lectura), con soporte de varias bibliotecas, `restapi` y edición de metadatos y portadas de EPUB.
- **Para copiar:** la idea de un **OPDS de solo lectura directamente sobre `metadata.db`**: barato, sin estado y seguro.

### 2.12 Kapowarr y Mylar3 (cómics)
- **Kapowarr** ([repo](https://github.com/Casvt/Kapowarr)): Python, GPL-3.0, UI estilo *arr. Monitoriza volúmenes, usa ComicVine, descarga de DDL (GetComics, Pixeldrain, Mega) y torrents, y renombra y extrae automáticamente. Activo.
- **Mylar3** ([repo](https://github.com/mylar3/mylar3)): el veterano. Python, ComicVine, NZB, torrents y DDL. **Escribe ComicInfo.xml** con ComicTagger. Ritmo más lento (último push mar-2026).
- **Para copiar:** el modelo **serie → volumen → número** con monitorización. Escribir ComicInfo.xml en la ingesta para que cualquier lector (Panels, Chunky, KOReader, Komga) lea bien los metadatos.

### 2.13 Otros relevantes
- **BookBridge** ([releases](https://newreleases.io/project/github/cporcellijr/bookbridge/release/v7.1.0)): un "pegamento" que sincroniza progreso y, desde la v7.x, **highlights** entre KOReader (plugin BridgeSync), CWA (vía Kobo), Audiobookshelf, Storyteller, Grimmory, Readest y Hardcover. **Que exista demuestra el hueco:** nadie sincroniza anotaciones de verdad, así que alguien construyó un puente.
- **Readest** ([repo](https://github.com/readest/readest), 25.4k ★): lector multiplataforma basado en **foliate-js** (el mismo motor que elegimos) con KOReader sync y OPDS. Es la referencia de UX de lectura a vigilar.
- **Codex** (servidor de cómics con OPDS 2.0) y **Suwayomi** (manga) aparecen como soportados por ComicInfo, pero quedan fuera de nuestro alcance.

---

## 3. Flujos con bots de Telegram

| Proyecto / patrón | Qué hace | Notas |
|---|---|---|
| **DIY → carpeta de ingesta de CWA** | El bot recibe un documento y lo guarda en la carpeta vigilada. CWA convierte, completa metadatos e importa. | Es el patrón más común en la comunidad. No hay un proyecto canónico para esto. |
| [qcgzxw/ebook-sender-bot](https://github.com/qcgzxw/ebook-sender-bot) (65 ★) | Telegram → email "Send to Kindle". | Python. Representa al género de bots "Send to Kindle" ([artículo de Genbeta](https://www.genbeta.com/herramientas/como-enviar-ebooks-tu-kindle-telegram)). |
| [calibre2telegram](https://hub.docker.com/r/asturbike/calibre2telegram) | Busca en una biblioteca Calibre local y envía el libro por email o chat. Lista blanca `ALLOWED_CHAT_IDS`. | Sin actualizar desde hace más de un año. |
| [tgbook](https://github.com/usagitoneko97/tgbook) | `/book` busca en Calibre y `/book-get` devuelve el archivo; también añade libros a LazyLibrarian. | C++, juguete (0 ★), pero tiene la forma correcta de comandos. |
| [kpub](https://pkg.go.dev/github.com/spacesedan/kpub) | Sesión de usuario de Telegram (no bot) que vigila chats, convierte a KEPUB y sube a Dropbox para Kobo. | Usa sesión de usuario (MTProto): sin el límite de 20 MB. |
| LazyLibrarian / Shelfmark | Notificaciones (Telegram) y solicitudes con aprobación. | El roadmap de CWA incluye notificaciones por Telegram, Gotify y ntfy. |

**Dato técnico clave:** la Bot API pública solo deja **descargar archivos de hasta 20 MB** (`getFile`) y subir hasta 50 MB. Con el **servidor local de la Bot API** ([tdlib/telegram-bot-api](https://github.com/tdlib/telegram-bot-api)) las descargas no tienen límite de tamaño, las subidas llegan a 2000 MB y `getFile` devuelve la ruta local. Para PDFs y cómics (fácilmente de 50 a 300 MB) **conviene desplegar el servidor local de la Bot API** junto al nuestro ([issue #671](https://github.com/tdlib/telegram-bot-api/issues/671)).

---

## 4. Estándares y protocolos

### 4.1 OPDS 1.2 (Atom)
- Catálogos en Atom/XML con *feeds* de navegación y de adquisición, más búsqueda vía OpenSearch. **Lo soporta casi todo:** KOReader, Panels, Chunky, KyBook, Moon+, Thorium, Readest y la propia Calibre.
- Facetas y paginación con `rel="next"`. Es un **mínimo obligatorio** para interoperar.

### 4.2 OPDS 2.0 (JSON)
- JSON basado en el **Readium Web Publication Manifest**, con colecciones `navigation`, `publications`, `groups` y `facets`, enlaces de adquisición (incluida la indirecta), búsqueda con URI templates y un **Authentication Document** (OPDS Auth 1.0) ([spec](https://drafts.opds.io/opds-2.0)). Sigue en estado de *draft*, pero es estable en la práctica.
- Lo soportan Thorium, las apps Readium, Readest, Komga, Stump y Codex. La adopción es menor que la de 1.2.
- **Ventaja para nosotros:** es JSON y se parece a lo que nuestra API ya devolverá, así que nos sale casi gratis si modelamos el catálogo con la forma del manifiesto Readium.

### 4.3 OPDS-PSE (Page Streaming Extension)
- Extensión no oficial creada por Ubooquity y hoy mantenida en [anansi-project/opds-pse](https://github.com/anansi-project/opds-pse/blob/master/README.md). Añade a cada entrada de OPDS 1.x:
  - un enlace `rel="http://vaemendis.net/opds-pse/stream"` con plantilla `…?page={pageNumber}&width={maxWidth}`;
  - `pse:count` (número de páginas);
  - en la **v1.2**, `pse:lastRead` y `pse:lastReadDate` para retomar la lectura desde el servidor.
- Permite leer un cómic **sin descargar el CBZ** completo. Lo soportan KOReader (desde 2022), Panels, Chunky y otros. **No tiene equivalente en OPDS 2.0** (allí se usaría un manifiesto Readium de tipo *divina*/imágenes).
- Kavita, Komga y Stump lo implementan. Para cómics en el iPhone es de alto valor y barato.

### 4.4 KOReader sync (kosync)
- **Endpoints** (servidor de referencia [koreader-sync-server](https://github.com/koreader/koreader-sync-server)):
  - `POST /users/create`
  - `GET /users/auth`
  - `PUT /syncs/progress`
  - `GET /syncs/progress/:document`
  - `GET /healthcheck`
  - Cabeceras `x-auth-user` y `x-auth-key`, donde la clave es el **MD5 de la contraseña calculado en el cliente**. `Accept: application/vnd.koreader.v1+json`.
- **Payload:** `document` (hash), `progress`, `percentage`, `device`, `device_id` y `timestamp` en la respuesta. Según el [plugin kosync](https://github.com/koreader/koreader/blob/master/plugins/kosync.koplugin/main.lua), `progress` es un **XPointer** en documentos *reflowable* (EPUB) y un **número de página** en documentos paginados (PDF/CBZ).
- **Identidad del documento:** por defecto, el **MD5 parcial binario**: se leen 1024 bytes en los *offsets* `1024 << 2i` con i = −1…10 y se calcula el MD5 de esos trozos. Alternativa: MD5 del nombre de archivo. **Consecuencia:** el servidor tiene que calcular y guardar el MD5 parcial de cada archivo (CWA lo hace en la ingesta) y **cualquier reescritura del archivo cambia el hash** (*metadata enforcement*, EPUB fixer). Hay que guardar el historial de hashes.
- **Estrategia de conflicto:** el cliente compara `timestamp` (o el porcentaje si no lo hay) y pregunta al usuario o sincroniza en silencio, según su configuración.
- **Limitaciones:** solo sincroniza progreso, sin highlights. KOReader admite **un solo servidor de sync**. Traducir un XPointer a EPUB CFI no es trivial (por eso Komga sincroniza por capítulo).

### 4.5 Kobo sync
- No es un estándar: es **ingeniería inversa de la API de la tienda Kobo**. El Kobo se configura con `api_endpoint=https://servidor/kobo/<token>` en `Kobo eReader.conf`. Endpoints relevantes:
  - `/v1/initialization`
  - `/v1/library/sync` (paginado con *sync tokens*)
  - `/v1/library/{id}/metadata`
  - `/v1/library/{id}/state` (progreso y estado de lectura)
  - descarga de KEPUB
  - el canal aparte de *reading services* para anotaciones.

  Lo que el servidor no sabe responder **se reenvía a la tienda oficial**.
- **Detalles que muerden:**
  - El progreso dentro del capítulo solo existe en **KEPUB** (los `span` `koboSpan` que inserta kepubify). Con EPUB normal se pierde la posición dentro del capítulo ([guía Komga](https://komga.org/docs/guides/kobo)).
  - Si se reenvían a la nube de Kobo las peticiones de anotaciones de libros cargados por el usuario, **el Kobo borra los highlights** (corregido en NextGen; relacionado con calibre-web#2610) ([notas NextGen](https://newreleases.io/project/github/new-usemame/Calibre-Web-NextGen/release/v4.1.39)).
- **Coste/beneficio para nosotros:** alto coste y solo sirve si el usuario tiene Kobo. Va como **fase tardía**.

### 4.6 ComicInfo.xml
- XML dentro del CBZ (heredado de ComicRack): `Series`, `Number`, `Volume`, `Title`, `Writer`, `Penciller`, `Publisher`, `Year/Month`, `PageCount`, `LanguageISO`, `Manga` (dirección de lectura `YesAndRightToLeft`), `<Pages>` con `Type="FrontCover"`, `DoublePage`, etc. La versión de referencia es la **2.0**; la **2.1 está en draft**. La gobierna [anansi-project/comicinfo](https://github.com/anansi-project/comicinfo), con soporte de Komga, Kavita, Codex, Stump y Mylar.
- **Para nosotros:** leerlo al ingerir cómics y **escribirlo** cuando enriquecemos metadatos. Calibre no lo gestiona bien: guarda el CBZ como un formato más y los metadatos de cómic quedan pobres, así que nos conviene una tabla propia de metadatos de cómic.

### 4.7 EPUB CFI
- Especificación IDPF/W3C (*EPUB Canonical Fragment Identifiers 1.1*). Su forma es `epubcfi(/6/4!/4/2/1:12)`: un paso por el spine, luego `!` y un camino dentro del documento XHTML con *offset* de carácter. Admite rangos.
- **Es el ancla que usan Calibre, foliate-js, epub.js y Readium** (como `partialCfi`). Es nuestro formato canónico de posición en EPUB.
- **Cuidado:** distintos motores generan CFI ligeramente distintos (si incluyen o no la aserción de ID, cómo cuentan los nodos de texto). Convertir CFI ↔ XPointer de KOReader es un problema conocido ([petición en Zotero](https://forums.zotero.org/discussion/128415/fr-unified-annotation-cfi-for-koreader-calibre-zotero-edit)). Por eso **se guarda siempre también la cita textual** (ver 4.8).

### 4.8 W3C Web Annotation Data Model
- Recomendación W3C (2017): `Annotation { body, target { source, selector[] } }` con selectores combinables:
  - `FragmentSelector` (con `conformsTo` = EPUB CFI o `page=N` para PDF);
  - **`TextQuoteSelector` (`prefix` / `exact` / `suffix`)**;
  - `TextPositionSelector`.
- Es el **modelo correcto para guardar highlights portables**. Si el CFI se rompe (nueva edición del archivo, otro motor), el `TextQuoteSelector` permite volver a anclar por búsqueda difusa. Readwise también trabaja con texto y ubicación, no con CFI.

### 4.9 Readium Web Publication Manifest y Locator
- **RWPM**: manifiesto JSON (`metadata`, `readingOrder`, `resources`, `toc`) que representa EPUB, PDF, audiolibros y cómics (*divina*) de forma uniforme. Es la base de OPDS 2.0.
- **Locator** ([modelo](https://github.com/readium/architecture/tree/master/models/locators)): `href`, `type`, `title`, `locations { fragments, progression, totalProgression, position, … }` y `text { before, highlight, after }`.
- Es el formato de progreso que usan los toolkits Readium (Swift, Kotlin, TS) y Komga. **Encaja con el Web Annotation** (el campo `text` equivale a TextQuote) y con foliate-js (que da CFI y fracción).

### 4.10 Bonus: API del content server de Calibre
Lo encontramos leyendo `src/calibre/srv/*.py`:
- `GET /ajax/books`, `/ajax/book/{id}`, `/ajax/search`, `/interface-data/*`: catálogo en JSON.
- `GET/POST /book-get-last-read-position/…` y `/book-set-last-read-position/{lib}/{id}/{fmt}`: guardan `{device, cfi, pos_frac}` **por usuario**.
- `GET /book-get-annotations/{lib}/{id-fmt}` y `POST /book-update-annotations/{lib}/{id}/{fmt}`: highlights y marcadores por usuario (`user_type='web'`). La **fusión** se hace por `uuid` y `timestamp`, y el orden por CFI ([calibre/db/annotations.py](https://github.com/kovidgoyal/calibre/blob/master/src/calibre/db/annotations.py)).
- `/cdb/cmd/{which}`: backend de **`calibredb --with-library http://host:puerto#lib`**. Permite que **todas las escrituras pasen por un único proceso (el server)**, en lugar de varios procesos tocando `metadata.db`.
- `/opds`: OPDS 1.x básico.

Fuente: [calibre/srv/books.py](https://github.com/kovidgoyal/calibre/blob/master/src/calibre/srv/books.py), [ajax.py](https://github.com/kovidgoyal/calibre/blob/master/src/calibre/srv/ajax.py), [cdb.py](https://github.com/kovidgoyal/calibre/blob/master/src/calibre/srv/cdb.py).

**Implicación:** podemos **reflejar** nuestros highlights en la tabla de anotaciones de Calibre para que el visor de Calibre desktop los muestre, sin escribir SQL a mano. Hay que **verificar** el formato exacto de CFI que espera Calibre: guarda `start_cfi`/`end_cfi` relativos al ítem del spine junto con `spine_index`.

---

## 5. Funciones que vale la pena copiar

1. **Carpeta de ingesta vigilada + cola de trabajos** (CWA). Añadirle la **cola de revisión** de Grimmory BookDrop: el bot de Telegram propone "¿es este libro?" con portada y metadatos, y el usuario confirma con un botón inline.
2. **EPUB Fixer** antes de enviar a Kindle (CWA, basado en *kindle-epub-fix*), para evitar rechazos de Send-to-Kindle.
3. **Metadata enforcement**: escribir los metadatos dentro del archivo para que los dispositivos externos coincidan. Hay que **guardar el historial de hashes** porque rompe kosync.
4. **Proveedores de metadatos en cadena con *fallback***: Hardcover → Open Library → Google → Amazon/Apple Books, con modos "rellenar huecos" o "sobrescribir".
5. **Kepubify al momento de descargar** (Komga/CWA 4.0.7) en lugar de guardar KEPUBs duplicados.
6. **Endpoint kosync integrado** que reutiliza las cuentas del servidor (CWA, Komga) y calcula el MD5 parcial en la ingesta.
7. ***Scrobbling* de progreso a Hardcover** (CWA 4.0.7, Kavita+). En nuestro caso el destino natural es **Readwise** para highlights, más Hardcover para el estado "leyendo/leído".
8. **Exportar anotaciones a Markdown/Obsidian con contexto** (Kavita).
9. **Magic/Smart Shelves** por reglas (CWA, Grimmory) y su sincronización a dispositivos.
10. **Detección de duplicados** fuzzy + ISBN (CWA). Crítico si el bot trae el mismo libro dos veces.
11. **Roles finos por capacidad** (`KOBO_SYNC`, `KOREADER_SYNC`, `FILE_DOWNLOAD`) (Komga), pensando en la versión pública.
12. **OPDS-PSE** para cómics: abrir un CBZ de 200 MB en el iPhone sin descargarlo.
13. ***Push* de progreso por WebSocket** (Audiobookshelf). En Apple se complementa con notificaciones silenciosas.
14. **Magic link** para iniciar sesión en dispositivos sin teclado (calibre-web/CWA).
15. **API-first con OpenAPI** (Komga, Grimmory). Esto hizo que el ecosistema de clientes de terceros de Komga floreciera.
16. **Modo de almacenamiento en red** que desactiva operaciones destructivas (Grimmory `DISK_TYPE=NETWORK`).
17. **Servidor MCP** encima de la biblioteca (existe uno para Grimmory). Encaja con el LLM local: "pregúntale a tu biblioteca".

---

## 6. Huecos que nadie cubre (nuestra oportunidad)

1. **Anotaciones portables de verdad.** Todos sincronizan *progreso*. Los highlights se quedan atrapados en el lector web de cada servidor (Kavita, Grimmory, Stump) o dependen de puentes frágiles (BookBridge, NextGen). Nadie usa **W3C Web Annotation con varios selectores (CFI + TextQuote + Locator)** para que un highlight sobreviva a un cambio de motor o de edición del archivo.
2. **De subrayado a conocimiento.** Ninguno tiene embeddings, búsqueda semántica sobre highlights, resúmenes, preguntas tipo "¿qué dije sobre X?", repaso espaciado ni digest semanal. Lo más cercano es exportar a Obsidian (Kavita).
3. **Readwise como ciudadano de primera.** Ningún servidor exporta a Readwise de forma nativa.
4. **App nativa Apple de calidad conectada a un servidor propio.** Los clientes son web/PWA (Komga NextUI, Kavita), Expo (Stump), Vue/Capacitor (Audiobookshelf) o de terceros solo para cómics (Panels, Paperback). **Ninguno hace macOS nativo ni layouts para plegables (iPhone Duo).**
5. **Conseguir el libro como parte del producto.** Hoy la cadena Shelfmark/LazyLibrarian → carpeta → CWA → notificación son 3 o 4 herramientas pegadas. **Bot ↔ app ↔ cola de trabajos única, con *push* "listo para leer"**, no existe integrado.
6. **Calibre como fuente de verdad *con* una API moderna.** Los que respetan Calibre (calibre-web, CWA, COPS) no tienen API REST. Los que tienen buena API (Komga, Kavita, Grimmory) ignoran Calibre.
7. **Progreso unificado entre formatos y dispositivos con precisión dentro del capítulo.** Komga y Kobo solo llegan al nivel de capítulo con EPUB. Kavita desaconseja su propio sync automático. Un modelo **Locator + CFI** con **traducción a XPointer** (para KOReader) sería diferencial.
8. **PDF y cómics de primera clase con highlights.** Casi nadie anota PDFs (anclas por página y rectángulo) ni cómics (por panel), y nadie los sincroniza.
9. **Privacidad e IA local.** Ninguno integra un LLM local (Ollama) sobre la biblioteca propia.

---

## 7. Recomendaciones de arquitectura de servidor

### 7.1 Decisión: ¿construir sobre CWA o Kavita, o una API propia sobre Calibre?

| Opción | Pros | Contras | Veredicto |
|---|---|---|---|
| **A. API propia (FastAPI) sobre Calibre** | Calibre sigue siendo el catálogo (requisito del usuario). Controlamos el modelo de anotaciones y la IA. Licencia libre de elegir. Se pueden publicar módulos más adelante. | Hay que reimplementar ingesta, OPDS y kosync. | ✅ **Recomendada** |
| B. Fork de CWA | Ingesta, Kobo y kosync ya hechos. | Monolito Flask + Jinja sin API. GPL-3.0 contagia todo el servidor. El upstream es lento y ya hay forks compitiendo. Escribe en `metadata.db` por su cuenta. | ❌ como base; ✅ como **fuente de ideas** |
| C. Kavita / Komga / Grimmory como backend | Excelente API (Komga). Lectores y protocolos ya hechos. | **No usan Calibre**: doble catálogo, doble metadatos, choque con la decisión de producto. El modelo de anotaciones es suyo. Stacks .NET/JVM ajenos al nuestro. | ❌ |
| D. Híbrido: API propia + CWA al lado como "consola de admin" | Dan su UI de ingesta y Kobo sync "gratis" desde el día 1. | **Dos escritores** sobre `metadata.db` (CWA y nuestro `calibredb`). Duplicidad de usuarios y progreso. | 🟡 Solo como **puente temporal**, con CWA en modo lectura o como única vía de ingesta. |

**Recomendación:** opción **A**, inspirada en CWA, Komga y Grimmory:

```
                ┌──────────── Adaptadores de protocolo ─────────────┐
 Apps Apple ───►│ API REST propia (OpenAPI)  · WebSocket de progreso │
 Web        ───►│ OPDS 1.2 + PSE  · OPDS 2.0 (RWPM)                  │◄── KOReader, Panels, Thorium, Readest
 KOReader   ───►│ /kosync (users/auth, syncs/progress)               │
 Kobo (fase 3)─►│ /kobo/<token>/v1/... (proxy a la tienda)           │
                └───────────────┬────────────────────────────────────┘
                                │
     ┌──────────────────────────▼──────────────────────────────┐
     │ Núcleo de dominio                                        │
     │  • Catálogo (lectura): metadata.db en solo lectura o     │
     │    /ajax/* del content server                            │
     │  • Escrituras: SOLO vía calibredb → content server       │
     │    (/cdb), serializadas por la cola de trabajos          │
     │  • Postgres: usuarios, progreso (Locator+CFI), anotac.   │
     │    (W3C WA), hashes de archivo (sha256 + MD5 parcial     │
     │    KOReader + historial), metadatos de cómic,            │
     │    embeddings (pgvector)                                 │
     │  • Cola (arq / RQ / Celery): fetch → fix → convert →     │
     │    metadata → dedupe → review → import → notify          │
     └───────┬───────────────────┬──────────────────┬──────────┘
             │                   │                  │
    Bot Telegram (+ servidor   Readwise /       Ollama (insights,
    local de la Bot API)       Hardcover        resúmenes, MCP)
```

### 7.2 Protocolos por fase

| Fase | Protocolo / función | Motivo |
|---|---|---|
| **MVP** | API REST propia + OpenAPI; progreso como **Readium Locator + EPUB CFI + `totalProgression`**; anotaciones como **W3C Web Annotation** (FragmentSelector CFI / `page=` + **TextQuoteSelector**) | Es el núcleo diferencial; foliate-js produce CFI y fracción |
| **MVP** | Ingesta (bot → carpeta o cola) con fixer, conversión, metadatos (Hardcover → OpenLibrary → Google) y dedupe; escritura vía `calibredb` remoto | El ciclo "/libro X → listo para leer" |
| **MVP** | Envío a Kindle por SMTP (con EPUB fixer) | Barato y muy usado |
| **Fase 2** | **OPDS 1.2 + PSE** (puede ser de solo lectura directo sobre `metadata.db`, estilo COPS) | Interoperar con KOReader, Panels, Chunky; cómics en streaming |
| **Fase 2** | **kosync** con MD5 parcial calculado en la ingesta e historial de hashes; traducción XPointer ↔ CFI "lo mejor posible" con *fallback* a `percentage` | Cubre e-ink sin escribir apps |
| **Fase 2** | Exportar a Readwise (push) y a Markdown/Obsidian; espejo opcional a las anotaciones de Calibre (`/book-update-annotations`) | Que los subrayados nunca queden atrapados |
| **Fase 3** | **OPDS 2.0** (sale casi gratis si el catálogo ya se modela como RWPM) | Thorium, Readest, Readium y la versión pública |
| **Fase 3** | **Kobo sync** (proxy de tienda, KEPUB al descargar, *no* reenviar anotaciones de libros propios) | Solo si hay un Kobo en casa; es caro de mantener |
| **Fase 3** | Servidor **MCP** sobre biblioteca y highlights | Para el LLM local y para Claude |

### 7.3 Decisiones concretas
1. **Identidad del libro:** `calibre_id` + `format` + `sha256` actual + **historial de hashes** (sha256 y MD5 parcial de KOReader). Un highlight se liga al *libro y formato*, no al hash, y se vuelve a anclar con TextQuote si el archivo cambia.
2. **Un solo escritor** sobre `metadata.db`: la cola de trabajos llama a `calibredb --with-library http://localhost:8080#lib`. Las lecturas van por SQLite en modo `?mode=ro` o por `/ajax/*`. Esto es coherente con la sección 3.1 de `vision-producto.md`.
3. **Cómics:** tabla propia con los campos de ComicInfo, porque Calibre se queda corto. Leer ComicInfo en la ingesta y escribirlo cuando se enriquecen los metadatos. Generar miniaturas y dimensiones de página en la ingesta (sirve para PSE y para el lector nativo).
4. **Telegram:** desplegar **`telegram-bot-api` en modo local** para quitar el límite de 20 MB. Lista blanca de `chat_id`. Los botones inline confirman metadatos (la "cola de revisión").
5. **Licencia:** si no se copia código de CWA ni de Grimmory (GPL/AGPL), se puede elegir licencia libremente. Para la futura versión pública, **evitar mezclar código GPL** en el núcleo. Inspirarse en el diseño, no copiar código. Komga (MIT) y Stump (MIT) sí permiten reutilizar código con atribución.
6. **Seguridad desde el día 1:** en 2026, Kavita, Stump, Grimmory y CWA publicaron fixes críticos (escalada de permisos, EPUB malicioso que agota CPU, tokens de Kobo). Por eso conviene validar y limitar los archivos ingeridos (zip-bombs, XML externo), separar los tokens por dispositivo y revocarlos.
7. **Plan B pragmático:** si el MVP se retrasa, se puede correr **CWA** temporalmente **solo** como canal de ingesta y Kobo/kosync, con nuestra API en **solo lectura** sobre la misma biblioteca. Hay que migrar en cuanto nuestra cola de escritura esté lista, para no tener dos escritores.

---

## 8. Fuentes

- calibre-web: https://github.com/janeczku/calibre-web · releases: https://github.com/janeczku/calibre-web/releases
- Calibre-Web-Automated: https://github.com/crocodilestick/Calibre-Web-Automated · releases: https://github.com/crocodilestick/Calibre-Web-Automated/releases
- Calibre-Web-NextGen: https://github.com/new-usemame/Calibre-Web-NextGen · notas v4.1.39: https://newreleases.io/project/github/new-usemame/Calibre-Web-NextGen/release/v4.1.39
- Discusión sobre el estado de CWA: https://piefed.nullspace.lol/post/247145
- autocaliweb: https://github.com/gelbphoenix/autocaliweb
- Kavita: https://github.com/Kareadita/Kavita · releases: https://github.com/Kareadita/Kavita/releases · KOReader: https://wiki.kavitareader.com/guides/3rdparty/koreader/ · OPDS: https://wiki.kavitareader.com/guides/features/opds/ · Lector EPUB: https://wiki.kavitareader.com/guides/readers/epub/ · v0.8.9: https://opencollective.com/kavita/updates/v0-8-9-new-stats-pages-journal-style-reading-50x-faster-scanner-and-so-much-more · issue #4518: https://github.com/Kareadita/Kavita/issues/4518
- Komga: https://github.com/gotson/komga · releases: https://github.com/gotson/komga/releases · Kobo: https://komga.org/docs/guides/kobo · KOReader: https://komga.org/docs/guides/koreader
- Grimmory: https://github.com/grimmory-tools/grimmory · releases: https://github.com/grimmory-tools/grimmory/releases · plugin KOReader: https://github.com/grimmory-tools/grimmory.koplugin · MCP: https://github.com/bannert1337/grimmory-mcp
- Cierre de BookLore: https://deddit.petersanchez.com/g/selfhosted@lemmy.world/p/3CFT1zkTgLn5SnY9hR-Booklore-is-officially-dead · https://aur.archlinux.org/packages/booklore · https://lemmy.klein.ruhr/post/218663
- Audiobookshelf: https://github.com/advplyr/audiobookshelf · ebooks: https://www.audiobookshelf.org/docs/documentation/libraries/book-library/ebooks · app: https://github.com/advplyr/audiobookshelf-app
- Stump: https://github.com/stumpapp/stump · releases: https://github.com/stumpapp/stump/releases
- COPS: https://github.com/seblucas/cops · https://github.com/mikespub-org/seblucas-cops
- Ubooquity: https://vaemendis.github.io/ubooquity-doc/ · https://www.asustor.com/en/app_central/app_detail?id=1190
- Readarr: https://github.com/Readarr/Readarr · anuncio de retiro: https://piefed.jeena.net/post/195134 · reemplazos: https://piefed.jeena.net/post/332893 · https://dietpi.com/forum/t/readarr-has-been-retired-what-about-lazylibrarian-instead/24105 · rreading-glasses: https://github.com/blampe/rreading-glasses
- LazyLibrarian: https://gitlab.com/LazyLibrarian/LazyLibrarian
- Kapowarr: https://github.com/Casvt/Kapowarr · Mylar3: https://github.com/mylar3/mylar3
- Shelfmark: https://github.com/calibrain/shelfmark
- BookBridge: https://newreleases.io/project/github/cporcellijr/bookbridge/release/v7.1.0 · https://newreleases.io/project/github/cporcellijr/bookbridge/release/v6.5.0
- Readest: https://github.com/readest/readest · foliate-js: https://github.com/johnfactotum/foliate-js · kepubify: https://github.com/pgaskin/kepubify
- Telegram: https://github.com/qcgzxw/ebook-sender-bot · https://hub.docker.com/r/asturbike/calibre2telegram · https://github.com/usagitoneko97/tgbook · https://pkg.go.dev/github.com/spacesedan/kpub · https://github.com/tdlib/telegram-bot-api · https://github.com/tdlib/telegram-bot-api/issues/671 · https://www.genbeta.com/herramientas/como-enviar-ebooks-tu-kindle-telegram
- KOReader sync: https://github.com/koreader/koreader-sync-server · plugin: https://github.com/koreader/koreader/blob/master/plugins/kosync.koplugin/main.lua
- OPDS 2.0: https://drafts.opds.io/opds-2.0 · OPDS-PSE: https://github.com/anansi-project/opds-pse · librería Go con PSE 1.2: https://pkg.go.dev/github.com/ophymx/opds
- ComicInfo: https://github.com/anansi-project/comicinfo
- Readium Locator: https://github.com/readium/architecture/tree/master/models/locators · toolkits: https://github.com/readium/swift-toolkit · https://github.com/readium/ts-toolkit
- EPUB CFI: https://idpf.org/epub/linking/cfi/ · CFI entre apps: https://forums.zotero.org/discussion/128415/fr-unified-annotation-cfi-for-koreader-calibre-zotero-edit
- W3C Web Annotation Data Model: https://www.w3.org/TR/annotation-model/
- Calibre content server (código): https://github.com/kovidgoyal/calibre/blob/master/src/calibre/srv/books.py · https://github.com/kovidgoyal/calibre/blob/master/src/calibre/srv/ajax.py · https://github.com/kovidgoyal/calibre/blob/master/src/calibre/srv/cdb.py · https://github.com/kovidgoyal/calibre/blob/master/src/calibre/db/annotations.py
