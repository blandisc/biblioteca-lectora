# 05 · IA, insights y capa de conocimiento

> Investigación, 19 de octubre de 2026. Complementa `docs/vision-producto.md` (v0.2).
> **Alcance:** qué hace la competencia, la API de Readwise, Apple Foundation Models (iOS 26 / iOS 27), modelos locales para el servidor, el catálogo de funciones de IA de Biblioteca Lectora, la arquitectura RAG con citas a CFI, y los temas de copyright y privacidad.

> **Nota metodológica (importante).** Desde el entorno de investigación, los dominios `readwise.io`, `docs.readwise.io`, `dev.to` y otros devolvieron errores de DNS o de proxy, así que **no pude abrir las páginas oficiales de la API de Readwise directamente**. Los datos de la API se contrastaron con los fragmentos indexados de las páginas oficiales (`readwise.io/api_deets`, `readwise.io/reader_api`), con clientes de código abierto (pyreadwise) y con lo que ya conocía de la API. Cada dato lleva una marca:
> - ✅ confirmado en un fragmento de la página oficial o en varias fuentes coherentes;
> - ⚠️ dato conocido o de terceros que **hay que verificar** en la página oficial antes de programar.
>
> Lo mismo aplica a las novedades de WWDC 2026: las páginas de sesión de Apple confirman los temas, pero varias cifras (por ejemplo, el contexto de 32K) vienen de resúmenes de terceros.

---

## Resumen ejecutivo

1. **Nadie combina "mi biblioteca + mi servidor + IA local sin spoilers + citas exactas".** Kindle ya lanzó *Ask this Book* y *Story So Far* (sin spoilers, pero en la nube de Amazon y sin opción de exclusión para autores). Readwise Reader tiene Ghostreader (OpenAI, centrado en artículos). NotebookLM tiene las mejores citas, pero en la nube de Google. **El hueco es la IA privada con anclas exactas (EPUB CFI) que funcione igual en las cuatro plataformas.**
2. **Readwise es un destino de subrayados excelente y barato de integrar.** La creación es `POST /api/v2/highlights/` con `Authorization: Token …`. El campo `highlight_url` permite que cada subrayado en Readwise **enlace de vuelta a la app** (universal link con el CFI) y sirve para actualizarlo si se reenvía. El límite es de 240 peticiones por minuto, o 20 por minuto en los listados. La API de Reader (v3) **no crea subrayados**, solo documentos.
3. **Apple Foundation Models sirve para tareas cortas por subrayado, no para libros enteros.** El modelo en el dispositivo tiene unos 3B parámetros y una ventana de **4096 tokens** (instrucciones, prompt y respuesta juntos). Tiene `@Generable`, tool calling, español y exige iOS/macOS 26 o posterior. En iOS 27 (WWDC 2026) llegan un modelo en el dispositivo nuevo con entrada de imagen, un modelo en **Private Cloud Compute** (32K de contexto y razonamiento, gratis para el Small Business Program, según terceros) y el **protocolo `LanguageModel`**. Este protocolo permite **enchufar nuestro propio servidor Ollama como proveedor** detrás de la misma API Swift, y es la pieza arquitectónica más interesante.
4. **Para el servidor:** de LLM, Qwen3 (8B, 14B o 30B-A3B MoE) o Gemma 4 (E4B, 12B, 26B MoE), ambos con licencia Apache 2.0. De embeddings, **Qwen3-Embedding-0.6B** o **bge-m3** (ambos multilingües y en Ollama). En un Mac mini con 24–32 GB o en una GPU de 12–16 GB funciona todo el catálogo.
5. **Antispoiler por construcción:** cada fragmento (*chunk*) guarda su posición. Toda consulta filtra `posición ≤ progreso_actual` **en SQL, antes de llegar al modelo**. Los resúmenes y los prefijos de "contextual retrieval" se generan solo con texto anterior. Al modelo se le prohíbe usar su conocimiento previo del libro.
6. **Uso personal ≈ bajo riesgo; versión pública = otro producto.** Usar en privado libros propios es defendible. Publicar la app exige quitar el bot de obtención de libros, no compartir índices entre usuarios, no entrenar con textos y respetar las cuotas de cita. El conflicto entre Amazon y la Authors Guild por *Ask this Book* es la referencia del riesgo reputacional.

---

## 1. Competencia: qué hacen y qué opinan los usuarios

### 1.1 Tabla comparativa

| Producto | Funciones de IA y conocimiento (2025–2026) | Dónde corre | Lo que gusta | Lo que molesta |
|---|---|---|---|---|
| **Readwise Reader · Ghostreader** | Prompts por documento, párrafo y palabra (definir, simplificar, preguntar, resumir). Prompts personalizables con variables (título, subrayados, selección). Prompts automáticos: auto-resumen y auto-etiquetado al guardar. | Nube (históricamente modelos de OpenAI) | Resúmenes al guardar, definir en contexto, interfaz multiplataforma | Precio (unos 10 USD al mes), centrado en artículos y no en libros, sin "regenerar" en algunos flujos, falta de filtros |
| **Readwise (clásico) · Daily Review** | Resurgimiento diario de subrayados con repetición espaciada, *Mastery* (flashcards y cloze) y correo diario. Importa de Kindle, Apple Books, Kobo, Snipd, etc. | Nube | "Unos minutos al día" para recordar lo leído; es el estándar de facto | Precio, revisión que se vuelve rutina, poca "inteligencia" sobre conexiones |
| **Readwise MCP / CLI (2026)** | Servidor MCP alojado (`mcp2.readwise.io/mcp`) que cubre Readwise y Reader: búsqueda en toda la biblioteca, triage y organización desde cualquier IA. CLI desde marzo de 2026. | Nube + tu agente | Abre tu historial de lectura a cualquier LLM | Requiere nube y suscripción |
| **Kindle · Recaps** (abr. 2025) | Resúmenes de series generados con GenAI y revisados por moderadores | Nube de Amazon | Útil entre tomos de una saga | Desconfianza por alucinaciones de trama (Reddit) |
| **Kindle · Ask this Book** (dic. 2025) | Seleccionas texto y preguntas sobre trama, personajes o temas. Respuestas **limitadas a lo ya leído**. Primero en iOS (EE. UU.), luego en dispositivos y Android en 2026. | Nube de Amazon | Spoiler-free "en general" según pruebas de Kindlepreneur | **Siempre activo, sin opción de exclusión para autores ni editoriales**. La Authors Guild lo considera un producto derivado que requiere derechos aparte. |
| **Kindle · Story So Far** | Resumen "hasta donde vas" para miles de títulos de ficción | Nube | Retomar un libro tras una pausa | Mismo debate de derechos |
| **Apple Books** (iOS 27) | Narración de audiolibros con IA, metas de lectura con *coaching* e integración con el nuevo Siri. Sin chat con el libro ni insights de subrayados. | Apple | Pulido nativo | Sin API ni exportación seria de subrayados |
| **Kobo** | Anunció *AI recaps* de unas 150 palabras, privadas, sin entrenar con ellas y **con opción de exclusión para autores**. FAQ actualizada en abril de 2026, sin fecha de lanzamiento. | Nube | Enfoque respetuoso con autores | Aún no disponible |
| **Snipd** (podcasts) | IA que genera "snips" (subrayados de audio), capítulos, chat por episodio, pestaña de "libros mencionados", AI DJ (2026). Exporta a Readwise. | Nube | Chat por episodio, captura con un toque | Dependencia del servicio |
| **Glasp** | Subrayador web/PDF, resúmenes con IA, chat por página, "IA personal" sobre tus subrayados, conector MCP. App nueva en 2026. | Nube | Social y gratis | **Subrayados públicos por defecto en el plan gratuito** |
| **Matter** | Read-later con TTS HD y "AI Co-Reader" en Premium (unos 12,99 USD al mes) | Nube | Lectura cómoda y audio | Precio, solo artículos |
| **Shortform / Blinkist** | Resúmenes de libros hechos por personas (Shortform añade análisis); Blinkist Pro con funciones de IA | Nube | Rapidez | No es *tu* lectura ni tus subrayados |
| **Heptabase** | Pizarras visuales, chat con tarjetas seleccionadas, *AI Tutor* (v1.88, mar. 2026), preguntas sugeridas y referencias en respuestas. Extrae subrayados de PDF con enlace a la página. | Nube | Conexiones visuales y enlaces a la fuente | Curva de aprendizaje, precio |
| **Obsidian + plugins** | Plugin oficial de Readwise (sincronización continua y plantillas Jinja2), plugin de Kindle directo (My Clippings o login), "Tag to Readwise" (inverso). IA vía plugins de terceros (búsqueda semántica local). | Local | Control total, Markdown | Montaje manual; la IA depende de plugins |
| **NotebookLM** | Hasta unas 50 fuentes por cuaderno, **citas en línea clicables**, Audio y Video Overviews, flashcards y quizzes | Nube de Google | **Las citas son el estándar de oro de confianza** | Nube, límites por plan, no es un lector |
| **Fabric** | Espacio de trabajo con IA: todo lo guardado se vuelve buscable y conectado, asistente multi-modelo | Nube | "Qué pasa después de leer" | Sin vista de lectura dedicada |
| **Recall** | Resúmenes, grafo de conocimiento automático por palabras clave, quizzes y **repetición espaciada de resúmenes**, correo semanal, API y MCP | Nube | Conexiones automáticas, repaso semanal | Funciones clave de pago; plan gratis limitado |
| **Elicit** | Asistente de investigación académica: revisión sistemática PRISMA 2020, extracción tabular, API y MCP (2026) | Nube | Trazabilidad paso a paso | Precisión real menor que la anunciada en estudios independientes (p. ej., sensibilidad del 37,9 % en Lau et al., 2025) |

### 1.2 Patrones que se repiten (lo que aman y lo que odian)

> No encontré hilos de Reddit indexables recientes con opiniones detalladas. La síntesis sale de reseñas, App Store, AlternativeTo, la cobertura de prensa sobre Kindle y los foros citados. Conviene validarla con una búsqueda manual en r/kindle, r/ereader, r/PKMS y r/ObsidianMD.

**Aman:**
- **Resurgimiento** (Daily Review): es la función más citada como "lo que hace que valga la pena subrayar".
- **IA en contexto y con un toque:** definir, simplificar y explicar sin salir del texto (Ghostreader, Ask this Book).
- **Retomar un libro tras una pausa** (Recaps, Story So Far).
- **Citas verificables** (NotebookLM, Heptabase): la confianza sube cuando puedes saltar al texto original.
- **Exportar a su sistema** (Obsidian, Notion): que los subrayados no queden atrapados.

**Odian:**
- **Spoilers y alucinaciones de trama** (desconfianza en Recaps).
- **Insights genéricos** que podrían salir de la contraportada.
- **Privacidad:** subrayados públicos por defecto (Glasp) y datos de lectura en la nube.
- **Suscripciones apiladas** (Readwise, Matter, Blinkist…).
- **Falta de control para autores** (Ask this Book): es un riesgo reputacional si la app se hace pública.
- **IA "pegada"** que ensucia la interfaz de lectura.

**Lecciones de diseño para Biblioteca Lectora:**
1. La IA vive en un **panel lateral o hoja inferior** que se invoca; nunca interrumpe la lectura.
2. **Toda respuesta lleva citas clicables** (CFI) o declara que no las tiene.
3. **Antispoiler verificable:** se muestra "Usando texto hasta el 43 % · cap. 12".
4. **Personal antes que genérico:** los insights se alimentan de *tus* subrayados, notas e historial.
5. **Local por defecto**, y la nube (PCC u otro proveedor) solo con permiso explícito.

---

## 2. API de Readwise en detalle

### 2.1 Autenticación ✅
- Token personal en `https://readwise.io/access_token`.
- Cabecera: `Authorization: Token <TOKEN>`.
- Comprobación: `GET https://readwise.io/api/v2/auth/` devuelve `204` si el token es válido. ⚠️ (dato conocido; verificar)
- El mismo token sirve para la API de Readwise (v2) y la de Reader (v3).

### 2.2 Límites de uso ✅
- Base: **240 peticiones por minuto por token**.
- **Highlight LIST** y **Book LIST**: **20 por minuto**.
- Si se excede, responde `429` con la cabecera `Retry-After` (segundos).
- Reader v3: **20 por minuto** confirmado en DELETE. Varias fuentes de terceros indican 20 por minuto en general y **50 por minuto en create/update**. ⚠️

### 2.3 Crear subrayados: `POST https://readwise.io/api/v2/highlights/`
Cuerpo: `{"highlights": [ {...}, {...} ]}`. Admite **lotes**: se envían varios subrayados en una sola petición.

| Campo | Tipo / límite | Uso en Biblioteca Lectora | Estado |
|---|---|---|---|
| `text` | **obligatorio**, máx. 8191 caracteres | Texto subrayado (si es más largo, se trunca y el texto completo va en la nota) | ✅ |
| `title` | máx. 511 | Título del libro (de Calibre) | ✅ campo / ⚠️ límite |
| `author` | máx. 1024 | Autor(es) de Calibre | ✅ campo / ⚠️ límite |
| `image_url` | máx. 2047 | Portada servida por tu servidor (URL pública o firmada) | ⚠️ |
| `source_url` | máx. 2047 | **URL estable del libro** (`https://lectora.tu-dominio/libro/{calibre_id}`). Forma parte de la clave de deduplicación. | ✅ campo / ⚠️ límite |
| `source_type` | 3–64 caracteres, identificador de tu app | `biblioteca_lectora` | ✅ campo (ej. `my_app`) / ⚠️ límite |
| `category` | `books`, `articles`, `tweets`, `podcasts` | `books` | ✅ |
| `note` | máx. 8191 | Nota del usuario. Readwise interpreta `.etiqueta` al inicio de la nota como **tag inline**. | ✅ campo / ⚠️ tags inline |
| `location` | entero | Posición ordinal del subrayado (ver 2.6) | ✅ (ej. oficial `"location": 3`) |
| `location_type` | `page`, `order`, `time_offset` | `order` (o `page` si hay paginación estable) | ✅ `page` en ejemplo oficial / ⚠️ resto de valores |
| `highlighted_at` | ISO 8601 | Fecha del subrayado | ✅ |
| `highlight_url` | máx. 4095 | **Enlace profundo de vuelta** (`https://lectora.tu-dominio/h/{highlight_uuid}`). *"Reuse that URL to update a previously created highlight"*. | ✅ |

**Deduplicación ✅:** si coinciden `title`, `author`, `text` y `source_url` (incluidos nulos), la petición no crea un duplicado. Reutilizar `highlight_url` **actualiza** el subrayado existente. Usar un `highlight_url` único por subrayado es, por tanto, la clave de idempotencia ideal.

**Respuesta ⚠️:** devuelve una lista de libros con `id` y `modified_highlights` (los IDs de los subrayados en Readwise). Hay que **guardar ese ID** en nuestra tabla para editar o borrar después.

### 2.4 Otros endpoints v2

| Endpoint | Para qué | Estado |
|---|---|---|
| `GET /api/v2/export/` con `updatedAfter`, `ids`, `pageCursor` | Exportación completa o incremental de libros y subrayados anidados. Patrón: primera carga sin parámetros, paginando con `nextPageCursor`; después, `updatedAfter=<último sync>`. **Útil para importar a nuestra base los subrayados de Kindle y Apple Books** y alimentar los insights de toda la biblioteca. | ✅ |
| `includeDeleted` en export | Detectar borrados | ⚠️ (solo en fuentes de terceros) |
| `GET /api/v2/highlights/` (`page_size` hasta 1000, `page`, `book_id`, `updated__gt/lt`, `highlighted_at__gt/lt`) | Listado (20 por minuto) | ⚠️ parámetros |
| `GET/PATCH/DELETE /api/v2/highlights/{id}/` | Detalle, edición (`text`, `note`, `location`, `url`, `color`) y borrado | ⚠️ |
| `GET /api/v2/books/` (`category`, `source`, `updated__gt`, `last_highlight_at__gt`…) | Libros (20 por minuto) | ⚠️ parámetros |
| `GET/POST /api/v2/highlights/{id}/tags/` y `PATCH/DELETE …/tags/{tag_id}` | Etiquetas de subrayado | ⚠️ |
| `GET/POST /api/v2/books/{id}/tags/` y `DELETE …/tags/{tag_id}` | Etiquetas de libro (pyreadwise implementa add/delete) | ✅ por cliente |
| `GET /api/v2/review/` | Subrayados de la Daily Review más reciente (`404 Review not found` si no hay) | ✅ |
| `POST /api/v2/review/complete/` | Marcar la Daily Review como completada | ✅ (changelog) |

### 2.5 API de Reader (v3): `https://readwise.io/api/v3/…`

| Endpoint | Capacidad | Estado |
|---|---|---|
| `POST /api/v3/save/` | Guarda un documento: `url` (obligatorio), `html`, `should_clean_html`, `title`, `author`, `summary`, `published_date`, `image_url`, `location` (`new`, `later`, `archive`, `feed`), `category` (`article`, `email`, `rss`, `highlight`, `note`, `pdf`, `epub`, `tweet`, `video`), `saved_using`, `tags`, `notes` | ✅ campos principales (pyreadwise) / ⚠️ lista completa |
| `GET /api/v3/list/` | Lista documentos: `id`, `updatedAfter`, `location`, `category`, `tag`, `pageCursor`, `withHtmlContent`. **Los subrayados de Reader aparecen como documentos `category=highlight` con `parent_id`.** | ⚠️ |
| `PATCH /api/v3/update/{id}/` | Actualiza metadatos y ubicación | ⚠️ |
| `DELETE /api/v3/delete/{id}/` | Borra (20 por minuto) | ✅ |
| `GET /api/v3/tags/` | Lista etiquetas | ⚠️ |

**Conclusión:** la API de Reader **no sirve para crear subrayados dentro de un documento**. Para nosotros sirve en dos casos: (a) enviar artículos desde el bot de Telegram a Reader; (b) leer los subrayados hechos en Reader para traerlos a nuestra base. **El canal de subrayados de libros es la v2.**

### 2.6 Cómo enlazar de vuelta a la posición exacta
- **`highlight_url`** = universal link `https://lectora.tu-dominio/h/{uuid}`. En iOS y macOS abre la app (Associated Domains) y en la web, el lector web. El servidor resuelve `uuid → (calibre_id, cfi)`. **No conviene meter el CFI en bruto en la URL**: los CFI son largos, tienen caracteres especiales y cambian si se re-procesa el EPUB. Un UUID es estable y permite re-anclar.
- **`location`** debe ser un entero monótono que ordene los subrayados en Readwise. Opciones:
  - `location_type: "order"` con `location = spine_index * 1_000_000 + char_offset_en_capítulo`, que ordena perfectamente.
  - `location_type: "page"` con un número de "página virtual" (p. ej., cada 1024 caracteres, como las *locations* de foliate-js). Readwise lo muestra como "Page N", algo más legible.
- **`source_url`** estable por libro: así Readwise agrupa bien los subrayados de un mismo libro aunque cambie el título en Calibre. ⚠️ Probar si cambiar el título crea un libro nuevo en Readwise.

### 2.7 Diseño de sincronización (servidor)
```
highlights (tabla propia) ──trigger──► readwise_outbox (pendiente)
worker (cada 30 s o por evento):
  - agrupa hasta ~100 pendientes por petición → POST /api/v2/highlights/
  - guarda readwise_highlight_id y readwise_book_id
  - edición  → PATCH /highlights/{id}/   (o re-POST con el mismo highlight_url)
  - borrado  → DELETE /highlights/{id}/
  - 429 → respetar Retry-After; backoff exponencial; idempotencia por highlight_url
import (cada noche): GET /export/?updatedAfter=… → tabla external_highlights
  (Kindle, Apple Books, Snipd…) → entran en embeddings e insights de toda la biblioteca
```
- **Readwise es destino, no fuente de verdad** (coherente con la visión v0.2). Si el token falla, la cola espera.
- Opcional: el **MCP oficial de Readwise** permite que un agente externo (Claude, etc.) consulte tu historial. No hace falta para la app, pero confirma que el ecosistema avanza en esa dirección.

---

## 3. Apple Foundation Models

### 3.1 Estado en iOS 26 / macOS 26 (lanzado en 2025)
| Aspecto | Dato | Fuente |
|---|---|---|
| Modelo | ~3B parámetros, en el dispositivo, cuantizado; inferencia gratis y sin conexión | Apple ML Research, documentación |
| Ventana de contexto | **4096 tokens** en total (instrucciones + prompt + historial + definiciones de herramientas + respuesta). Consultable en tiempo de ejecución con `SystemLanguageModel.contextSize`. Error `exceededContextWindowSize` si se pasa. | Varias fuentes coherentes |
| Tokens por carácter | Unos 3–4 caracteres por token en idiomas latinos; **en español, unos 1000–1200 tokens por página** | Foros de Apple |
| API | `LanguageModelSession(instructions:)`, `respond(to:)`, `streamResponse`, **guided generation** con `@Generable` y `@Guide` (salida tipada en Swift, incluso en streaming parcial), **tool calling** (protocolo `Tool`), adaptador `.contentTagging`, *adapters* entrenables, `SystemLanguageModel.default.availability` | Documentación de Apple |
| Idiomas | Los de Apple Intelligence: **incluye español**, inglés, francés, alemán, italiano, portugués, chino, japonés, coreano, danés, neerlandés, noruego, sueco, turco y vietnamita. Catalán no. | Apple ML Research, comunidad de Apple |
| Dispositivos | iPhone 15 Pro o posterior (A17 Pro+), iPad y Mac con M1+, iOS/iPadOS/macOS 26 o posterior, Apple Intelligence activado. **macOS: sí, nativo** (Apple silicon). | Varias fuentes |
| Bueno para | Resumir textos cortos, extraer, clasificar, etiquetar, reescribir, generar preguntas o flashcards de un pasaje, definir en contexto, salida estructurada | Apple y guías |
| Malo para | **Conocimiento del mundo** ("¿quién es X?"), hechos exactos, matemáticas, código, razonamiento largo, textos largos (por el límite de 4K). Alucina si se le pide conocimiento que no está en el prompt. | Guías y foros |

### 3.2 Novedades de WWDC 2026 (iOS 27 / macOS 27)
Fuentes: sesión 241 *What's new in the Foundation Models framework*, sesión 339 *Bring an LLM provider to the Foundation Models framework*, guía WWDC26 de iOS y resúmenes de terceros.

| Novedad | Detalle | Fiabilidad |
|---|---|---|
| **Nuevo modelo en el dispositivo** | "Más inteligente, mejor en lógica y tool calling", **acepta imágenes** (visión) | ✅ sesión 241 |
| **`PrivateCloudComputeLanguageModel`** | El mismo modelo de servidor que usa Apple Intelligence. **32K de contexto** y razonamiento ajustable (`reasoningLevel` en `contextOptions`). Sin cuenta ni autenticación. Cambiar al servidor es "una línea". | Existencia ✅ / 32K ⚠️ terceros |
| **Coste de PCC** | Gratis ("no cloud API cost") para apps del **App Store Small Business Program con menos de 2 M de descargas** | ✅ guía WWDC26 |
| **Protocolos `LanguageModel` y `LanguageModelExecutor`** | Capa de abstracción: la misma `LanguageModelSession` puede usar el modelo en el dispositivo, PCC, Claude (paquete `ClaudeForFoundationModels` 0.1.0), Gemini, MLX o Core AI. **También un proveedor propio.** | ✅ sesión 339 |
| Gestión de contexto, búsqueda semántica integrada, herramientas del sistema (OCR, códigos de barras, búsqueda vía Spotlight), *Dynamic Profiles* para agentes, framework de **Evaluations**, CLI `fm` | — | ✅ temas de la sesión / ⚠️ detalles |
| Uso de tokens por respuesta | Propiedad `usage` en la respuesta (beta) | ⚠️ terceros |
| Código abierto del framework y SDK de Python | Anunciado | ⚠️ |

### 3.3 Implicaciones para Biblioteca Lectora
1. **Tier "dispositivo" = micro-tareas sobre un subrayado o un párrafo** (≤ unos 2500 tokens de entrada). Va instantáneo, sin conexión, privado y gratis.
2. **El protocolo `LanguageModel` permite escribir *una sola* capa de IA en Swift:** `LectoraServerModel: LanguageModel` habla con nuestro FastAPI/Ollama. La app elige el ejecutor según la tarea, la conectividad y los ajustes de privacidad: `SystemLanguageModel` → `LectoraServerModel` → (opcional) `PrivateCloudComputeLanguageModel`. `@Generable` y las herramientas funcionan igual con los tres. ⚠️ Es una API beta en iOS 27; si cambia, el plan B es una capa propia con la misma forma.
3. **PCC no es "local".** Es privado según Apple (sin retención y verificable), pero el texto sale del dispositivo. Por la tesis del producto ("tu servidor"), **PCC queda como opción explícita y desactivada por defecto**, útil cuando no hay acceso al servidor (de viaje).
4. **iPhone Duo (plegable):** si comparte la generación de chip del iPhone 17 Pro, tendrá Apple Intelligence. Hay que comprobar `availability` siempre en tiempo de ejecución y no por modelo de dispositivo.
5. **Web:** no tiene Foundation Models; todo va al servidor.
6. **Presupuesto de tokens en el dispositivo (plantilla):** instrucciones ~300 · contexto (párrafo anterior + subrayado + párrafo siguiente) ~800 · metadatos (título, autor, capítulo) ~50 · respuesta máx. ~500. Sobra margen para `@Generable`.

```swift
@Generable
struct ExplicacionSubrayado {
    @Guide(description: "Explicación en 2-3 frases, en el idioma del libro")
    var explicacion: String
    @Guide(description: "Términos difíciles con definición breve", .maximumCount(3))
    var terminos: [Termino]
    @Guide(description: "Una pregunta de reflexión personal")
    var preguntaReflexion: String
}
```

---

## 4. Modelos locales en el servidor

### 4.1 LLM generativos (open-weight, español + inglés)

| Modelo | Tamaños útiles | Licencia | Notas para nuestro caso |
|---|---|---|---|
| **Qwen3** (y sucesores 3.5/3.6) | 4B, 8B, 14B, **30B-A3B (MoE)** | Apache 2.0 | El más recomendado para trabajo multilingüe. El MoE 30B-A3B es rápido (3B activos) con calidad de unos 30B. Tiene modo *thinking* que se puede desactivar: desactivarlo en resúmenes y traducción, activarlo en "contraargumentos". Las versiones 3.5 traen hasta 256K de contexto (⚠️ verificar por tamaño). |
| **Gemma 4** (abr. 2026) | E2B, E4B, 12B, **26B MoE**, 31B denso | **Apache 2.0** (Gemma 3 tenía licencia propia) | La cobertura multilingüe más amplia de la familia Gemma. Está en Ollama y LM Studio (QAT). |
| Mistral Small 3.x / Ministral 3 | 24B / 3B–8B | Apache 2.0 | Fuerte en idiomas europeos y con contexto largo |
| gpt-oss-20b | 20B (MoE) | Apache 2.0 | Eficiente en memoria; menos probado en español literario |

**Recomendación por defecto:** `qwen3:14b` o `gemma4:12b` para resúmenes, preguntas y respuestas e insights. `qwen3:30b-a3b` o `gemma4:26b` si hay 24 GB o más. Un modelo pequeño (`qwen3:4b` o `gemma4:e4b`) para generar el contexto de cada chunk durante la indexación masiva, donde la velocidad importa más.

### 4.2 Embeddings multilingües (para pgvector)

| Modelo | Dimensiones | Contexto | Tamaño | Notas |
|---|---|---|---|---|
| **Qwen3-Embedding-0.6B** | 1024 (MRL: reducible) | 32K | ~640 MB | Familia nº 1 en MTEB multilingüe (8B: 70,58, jun. 2025). La 0.6B es la mejor relación calidad/coste. Necesita una *instruction* en la consulta. |
| Qwen3-Embedding-4B / 8B | 2560 / 4096 (MRL) | 32–40K | 2,5–8 GB | Si sobra GPU. pgvector indexa HNSW hasta 2000 dimensiones con `vector` y hasta 4000 con `halfvec`: **usar MRL a 1024**. |
| **bge-m3** | 1024 | 8K | ~1,2 GB | Denso + disperso + multivector. Muy usado en búsqueda híbrida multilingüe. Ollama solo expone el denso. |
| EmbeddingGemma-300M | 768 (MRL a 128) | 2K | ~300 MB | El más ligero. Podría correr **en el dispositivo** (Core ML/MLX) para búsqueda semántica sin conexión. Calidad multilingüe menor (61,15). |
| multilingual-e5-large | 1024 | 512 | ~1,1 GB | Clásico y fiable, pero de contexto corto |

**Recomendación:** **Qwen3-Embedding-0.6B a 1024 dimensiones** (o bge-m3) + **reranker** (`Qwen3-Reranker-0.6B` o `bge-reranker-v2-m3`) sobre los 30–50 mejores candidatos. **Fijar el modelo y la versión en la base** (`embedding_model`, `embedding_dim`) para poder re-indexar sin mezclar espacios vectoriales.

### 4.3 Hardware

| Perfil | Ejemplo | Qué corre | Experiencia |
|---|---|---|---|
| Mínimo (solo CPU, 16 GB RAM) | Mini PC N100/Ryzen | `qwen3:4b` / `gemma4:e4b` + embeddings 0.6B | Indexar un libro tarda minutos. Las respuestas, unos 5–10 tokens por segundo. Aceptable para trabajos nocturnos (digest), lento para chat. |
| **Recomendado** | **Mac mini M4 con 24–32 GB** o PC con RTX 3060/4060 Ti de 12–16 GB | `qwen3:14b` / `gemma4:12b` (Q4, ~9 GB) + embeddings + reranker | Chat fluido (~20–40 tokens por segundo). Indexa un libro de 100k palabras en unos minutos. |
| Holgado | RTX 3090/4090 (24 GB) o Mac de 48–64 GB | `qwen3:30b-a3b` / `gemma4:26b` / `31b` | Calidad cercana a modelos comerciales medianos en resumen y preguntas |

Reglas prácticas: un modelo de Q4 ocupa ≈ 0,6 × los miles de millones de parámetros en GB, más la caché KV del contexto. Con `OLLAMA_KEEP_ALIVE` y `OLLAMA_MAX_LOADED_MODELS=2` se mantienen cargados el LLM y el de embeddings. **Probar con tus propios libros en español** antes de decidir: no hay benchmark público de resumen literario en español.

---

## 5. Catálogo de funciones de IA

### 5.0 Principios transversales
- **Tier D (dispositivo):** Foundation Models. **Tier S (servidor):** Ollama. **Tier C (nube opcional):** PCC u otro proveedor, desactivado por defecto.
- **Frontera antispoiler:** `limite = posición_de_lectura_máxima_alcanzada` (no la actual: si el usuario vuelve atrás, ya leyó lo posterior). Se guarda como `(spine_index, char_offset)` además del CFI. **Toda recuperación de texto filtra por `pos ≤ limite` en SQL.** Hay un modo "relectura" que quita el límite si el libro ya está terminado.
- **Instrucción antispoiler en el prompt:** *"Responde solo con el texto proporcionado. No uses conocimiento previo sobre este libro, su autor ni adaptaciones. Si la respuesta requiere información posterior, di que aún no aparece."* Es necesaria porque los LLM conocen los libros famosos: el filtro SQL no basta por sí solo.
- **Citas obligatorias:** el servidor numera los fragmentos `[F1]…[Fn]`. El modelo responde con `@Generable` o JSON `{respuesta, citas:[id]}`, el servidor **valida que cada cita exista en el conjunto recuperado** y la convierte en CFI.
- **Caché:** todo resultado se guarda con hash de (función, entrada, modelo, versión del prompt) para no recalcular.
- **Idioma:** se responde en el idioma de la interfaz; las citas, en el idioma original.

### 5.1 Por subrayado (o selección)

| Función | Tier | Entradas | Salida | Privacidad / antispoiler |
|---|---|---|---|---|
| **Definir** (palabra o expresión en contexto) | D | Palabra + oración + título | Definición contextual, registro, etimología breve. Puede apoyarse en el diccionario del sistema. | Local. Sin riesgo de spoiler. |
| **Explicar / simplificar** | D (S si el pasaje es largo) | Subrayado + ±1 párrafo | 2–3 frases + términos | Local |
| **Contexto** ("¿quién es este personaje?", "¿a qué se refiere?") | S (RAG) | Subrayado + fragmentos anteriores relevantes (`pos ≤ límite`) | Explicación con citas a apariciones anteriores | Servidor propio. Filtro SQL + instrucción. |
| **Contraargumentos / otra perspectiva** (ensayo y no ficción) | S (modelo con *thinking*) | Subrayado + resumen del argumento del capítulo hasta aquí | 2–3 objeciones razonadas, marcadas como "generado, no del libro" | En no ficción se puede permitir conocimiento general del modelo, avisándolo |
| **Traducir** | D | Selección | Traducción | Local |
| **Etiquetado automático** | D (`.contentTagging`) | Subrayado + nota | 1–3 etiquetas de tu vocabulario existente (vía herramienta `listarEtiquetas`) | Local. Se sincroniza a Readwise como tags. |
| **Pregunta de reflexión** | D | Subrayado + nota | Una pregunta personal ("¿Dónde has visto esto en tu trabajo?") | Local |
| **Crear flashcard** | D | Subrayado | Q/A o cloze (`@Generable struct Flashcard`) | Local |
| **"Esto conecta con…"** | S | Embedding del subrayado vs. subrayados de otros libros | 1–3 subrayados relacionados de tu biblioteca, con enlace | Servidor. Solo usa *tus subrayados* de otros libros (ya leídos), no texto completo no leído. |

### 5.2 Por capítulo

| Función | Tier | Notas |
|---|---|---|
| **Resumen al terminar el capítulo** | S (D posible con map-reduce, pero lento) | Se dispara al cruzar el final del capítulo. Se guarda y sirve de base para "Story so far". |
| **"Lo que va hasta aquí"** (recap al retomar tras X días) | S | Compone los resúmenes de capítulos ya leídos + el último resumen parcial. Nunca más allá del límite. |
| **Personajes y conceptos hasta aquí** | S | Extracción estructurada por capítulo leído (`{nombre, descripción, primera_aparición_cfi}`), con fusión incremental. Es el glosario sin spoilers. |
| **Preguntas de comprensión** | S → la tarjeta va a SRS | 3 preguntas por capítulo, opcionales |

### 5.3 Por libro (al terminar o bajo demanda)
- **Tus ideas clave:** síntesis de *tus subrayados y notas* (no del libro entero). Es más personal y barato, y nunca hay spoiler porque solo incluye lo que subrayaste.
- **Resumen completo** (solo con el libro terminado).
- **Mapa de argumentos** (no ficción): tesis, apoyos, objeciones, como JSON → diagrama en la app.
- **"Libro en una página"**: exportable a Markdown y Obsidian, y opcionalmente como *note* del libro en Readwise.
- **Recomendaciones de tu biblioteca:** libros no leídos de Calibre cercanos en embedding a tus subrayados favoritos (usa embeddings de metadatos o sinopsis, sin abrir el libro).

### 5.4 Toda la biblioteca
- **Conexiones semánticas:** grafo de subrayados (k-NN en pgvector, umbral de similitud) para descubrir "temas puente" entre libros.
- **Temas en el tiempo:** clustering mensual de subrayados (HDBSCAN sobre embeddings) + etiqueta generada por el LLM. Muestra cómo cambian tus intereses ("en 2026 subrayaste mucho sobre atención y tecnología").
- **Contradicciones:** pares de subrayados similares en tema pero opuestos en postura (el LLM clasifica pares candidatos). Es un insight de alto valor.
- **Incluir subrayados importados** de Readwise (Kindle, Apple Books, Snipd): la capa de conocimiento cubre toda tu lectura, no solo la de esta app.

### 5.5 Reflexión, repaso y flashcards
- **Algoritmo de repetición: FSRS** (moderno, de código abierto, usado por Anki). Tablas `cards` y `reviews`.
- Fuentes de tarjetas: (1) subrayado tal cual (estilo Readwise), (2) cloze generado, (3) Q/A generada, (4) pregunta de reflexión, que no se puntúa y se responde escribiendo, y esa respuesta se convierte en nota.
- **Convivencia con Readwise:** si el usuario usa la Daily Review de Readwise, nuestra app no la duplica. Muestra solo flashcards y reflexiones propias, y puede leer `GET /api/v2/review/` para mostrar el repaso del día dentro de la app y marcarlo con `/review/complete/`.
- **Widget e intent** (App Intents): "Subrayado del día" en la pantalla de inicio y en la pantalla exterior del Duo.

### 5.6 "Chatea con mi biblioteca" (con citas)
- **Ámbitos:** "este libro (hasta donde voy)", "libros terminados", "mis subrayados", "toda la biblioteca leída".
- **Flujo:** consulta → reescritura (el LLM pequeño genera de 1 a 3 sub-consultas) → búsqueda híbrida (vector + texto completo) con filtro de ámbito y límite → RRF → reranker → los 8–12 mejores fragmentos con `[F#]` → LLM → respuesta con citas → la app pinta chips "cap. 7 · 34 %" que abren el CFI.
- **Herramientas** (tool calling): `buscarEnLibro`, `buscarSubrayados`, `listarLibros(filtro)`, `obtenerResumenCapítulo`. Con el protocolo `LanguageModel`, la misma conversación funciona en el dispositivo (consultas cortas sobre subrayados, con índice local) o en el servidor.
- **Respuesta honesta:** si el reranker no supera el umbral, responde "No encuentro esto en lo que has leído".

### 5.7 Digest semanal por Telegram
- **Trabajo programado en el servidor** (domingo por la tarde): libros con progreso esta semana, X subrayados, 3 subrayados destacados (por similitud con tus temas o por notas largas), 1 conexión entre libros, 1 pregunta de reflexión, 3 tarjetas pendientes, y "sigue con…" (libro más cercano a terminarse).
- Formato: Markdown de Telegram con enlaces universales a cada subrayado. **Botones inline**: "Recordar", "Ya lo sé" (alimentan FSRS) y "Responder reflexión" (la respuesta del chat se guarda como nota).
- **Privacidad:** el contenido pasa por los servidores de Telegram (los chats de bot no tienen cifrado de extremo a extremo). Hay una opción "digest mínimo", que envía solo un enlace y no el texto.
- Comandos: `/digest`, `/subrayados <libro>`, `/pregunta <texto>` (RAG sobre tus subrayados).

### 5.8 Matriz resumen de tiers

| Función | Dispositivo | Servidor | Funciona sin conexión |
|---|---|---|---|
| Definir, explicar, traducir, etiquetar, flashcard, reflexión | ✅ | respaldo | ✅ |
| Contexto con RAG, contraargumentos, "conecta con" | — | ✅ | ❌ (salvo índice local de subrayados) |
| Resúmenes de capítulo y libro, personajes | — | ✅ | ❌ (se leen de la caché sin conexión) |
| Biblioteca: temas, contradicciones, chat | — | ✅ | ❌ |
| Digest | — | ✅ | n/a |

---

## 6. Arquitectura RAG

### 6.1 Ingesta (al entrar un libro en Calibre o al abrirlo por primera vez)
1. **Extracción con anclas:** el EPUB se parsea en el servidor **con el mismo código de CFI que el cliente**. Se recomienda ejecutar el módulo `epubcfi.js` de foliate-js en un *worker* de Node, o portarlo, porque coherencia de CFI entre cliente y servidor es crítica. Por cada elemento de bloque (`p`, `h*`, `li`, `blockquote`) se guardan `spine_index`, `char_offset_inicio`, texto y **CFI de rango**. Formatos no EPUB (MOBI/AZW3/FB2): o bien conversión a EPUB con `ebook-convert` de Calibre (guardando el EPUB derivado como canónico para las anclas), o bien el parser de foliate-js.
2. **Chunking jerárquico:**
   - Fragmentos *hijo* de **unos 350–500 tokens**, respetando párrafos, con **1 párrafo de solapamiento**.
   - Fragmento *padre* = sección o capítulo (para dar contexto ampliado al LLM si hace falta).
   - Cada fragmento guarda `cfi_inicio`, `cfi_fin`, `spine_index`, `pos_inicio` y `pos_fin` (posición global en caracteres), `capitulo_titulo` y `orden`.
3. **Contextual retrieval sin spoilers:** el método de Anthropic (anteponer a cada fragmento 50–100 tokens de contexto antes de indexar) reduce los fallos de recuperación un 49 % combinado con BM25, y hasta un 67 % con reranker. **Adaptación clave:** el contexto se genera **solo con el título, el capítulo y el resumen de lo anterior**, nunca con el libro entero, porque si no el prefijo filtraría información futura dentro de fragmentos tempranos.
4. **Embeddings** del texto contextualizado + **`tsvector`** (configuración `spanish` o `english` según el idioma del libro, con `unaccent`).
5. Coste: un libro de 100k palabras son ≈ 140k tokens ≈ 300–400 fragmentos. Con el modelo de embeddings 0.6B en GPU, segundos; en CPU, unos minutos. La contextualización con un LLM de 4B es lo más lento, así que va en cola nocturna.

### 6.2 Esquema (Postgres + pgvector)
```sql
CREATE TABLE book_chunks (
  id            bigserial PRIMARY KEY,
  book_id       int NOT NULL,          -- Calibre id
  file_hash     text NOT NULL,         -- si cambia el archivo, re-indexar
  ord           int NOT NULL,
  spine_index   int NOT NULL,
  pos_start     int NOT NULL,          -- offset global en caracteres
  pos_end       int NOT NULL,
  cfi_start     text NOT NULL,
  cfi_end       text NOT NULL,
  chapter_title text,
  lang          regconfig NOT NULL,    -- 'spanish' | 'english'
  text          text NOT NULL,
  context       text,                  -- prefijo generado (sin spoilers)
  tsv           tsvector GENERATED ALWAYS AS (to_tsvector(lang, coalesce(context,'') || ' ' || text)) STORED,
  embedding     vector(1024),
  embed_model   text NOT NULL
);
CREATE INDEX ON book_chunks USING hnsw (embedding vector_cosine_ops);
CREATE INDEX ON book_chunks USING gin (tsv);
CREATE INDEX ON book_chunks (book_id, pos_end);

CREATE TABLE reading_progress (
  user_id int, book_id int,
  cfi_current text, pos_current int,
  pos_max int,                          -- frontera antispoiler
  finished_at timestamptz,
  PRIMARY KEY (user_id, book_id)
);

CREATE TABLE highlights (
  id uuid PRIMARY KEY, user_id int, book_id int,
  cfi_range text, pos_start int, pos_end int,
  text text, note text, color text, created_at timestamptz, updated_at timestamptz,
  embedding vector(1024),
  readwise_id bigint, readwise_synced_at timestamptz
);
```
> La función `to_tsvector` con un `regconfig` variable debe envolverse en una función `IMMUTABLE` para usarla en una columna generada; como alternativa, se rellena por trigger.

**Consulta con frontera antispoiler (esquema):**
```sql
WITH lim AS (SELECT pos_max FROM reading_progress WHERE user_id=$1 AND book_id=$2),
vec AS (
  SELECT id, row_number() OVER (ORDER BY embedding <=> $3) r
  FROM book_chunks, lim WHERE book_id=$2 AND pos_end <= lim.pos_max
  ORDER BY embedding <=> $3 LIMIT 40),
fts AS (
  SELECT id, row_number() OVER (ORDER BY ts_rank(tsv, q) DESC) r
  FROM book_chunks, lim, websearch_to_tsquery('spanish', $4) q
  WHERE book_id=$2 AND pos_end <= lim.pos_max AND tsv @@ q LIMIT 40)
SELECT id, sum(1.0/(60+r)) AS rrf FROM (SELECT * FROM vec UNION ALL SELECT * FROM fts) u
GROUP BY id ORDER BY rrf DESC LIMIT 30;   -- → reranker → top 8-12
```
> Con filtros muy selectivos, HNSW puede devolver pocos resultados. Conviene activar `hnsw.iterative_scan` (pgvector ≥ 0.8) o, por libro (pocos cientos de filas), hacer un escaneo exacto sin índice, que es suficientemente rápido.

### 6.3 Generación y citas
1. El servidor construye el contexto: `[F1] (Cap. 3 «Título», 12 %) texto…`.
2. Instrucciones: responder solo con los fragmentos, citar `[F#]` tras cada afirmación y no usar conocimiento previo del libro.
3. Salida estructurada (JSON schema en Ollama: `format`) → `{ "respuesta": "...", "citas": [{"f": 3, "cita_textual": "..."}] }`.
4. **Validación:** cada `f` debe existir y `cita_textual` debe aparecer (*fuzzy match*) en el fragmento. Si falla, se reintenta o se quita la cita. Con el offset de la cita textual dentro del fragmento se **calcula un CFI preciso del pasaje citado**, no solo del fragmento.
5. La app renderiza los chips de cita; al tocar uno, el lector navega al CFI y **resalta temporalmente** el rango.

### 6.4 Índice en el dispositivo (opcional, fase 2)
- Embeddings de **tus subrayados** (no de libros completos) con EmbeddingGemma-300M o con la búsqueda semántica integrada que Apple anunció en iOS 27 (⚠️ por confirmar la API). Así se puede usar "conecta con…" y "chat con mis subrayados" sin conexión, con el modelo en el dispositivo.

---

## 7. Copyright y privacidad

> No es asesoría legal. Las leyes varían (UE/España, México, EE. UU.) y conviene una revisión profesional antes de cualquier versión pública.

### 7.1 Uso personal (situación actual)
- **Procesar con IA libros que posees, en tu servidor y para ti**, es el escenario de menor riesgo: no hay distribución ni comunicación pública. En España, el límite de **copia privada** cubre a personas físicas, para uso privado y sin intervención de terceros (con condiciones). Índices, embeddings y resúmenes privados encajan en ese espíritu. En la UE, la excepción de **minería de textos y datos** (Directiva 2019/790, art. 4) también apoya el análisis automatizado de obras con acceso lícito. ⚠️ Revisar la aplicabilidad exacta.
- **DRM:** **eludir medidas tecnológicas** es ilícito en la mayoría de jurisdicciones (DMCA §1201 en EE. UU., art. 6 de la Directiva 2001/29 en la UE y su transposición española, reforma de 2020 de la LFDA en México), aunque el uso sea privado. La app **no debe incluir ni sugerir herramientas de eliminación de DRM**. Debe trabajar solo con archivos sin DRM (compras sin DRM, dominio público, documentos propios).
- **El bot de Telegram "consigue libros":** es el punto más delicado. Para uso personal es decisión del usuario. **En una versión pública debe desaparecer** o limitarse a fuentes legales (Project Gutenberg, Standard Ebooks, la propia biblioteca del usuario o préstamo bibliotecario).
- **Modelos:** Qwen3 y Gemma 4 tienen licencia Apache 2.0, sin restricciones relevantes para uso personal ni comercial. Apple FM está sujeto a las Acceptable Use Requirements de Apple.

### 7.2 Si la app se hace pública
| Riesgo | Mitigación |
|---|---|
| Que la app se perciba como "chatbot sobre libros con copyright" (el caso Ask this Book y la Authors Guild) | La IA opera **solo sobre archivos que el usuario aporta**. No hay catálogo propio. Cada índice es **por usuario**, nunca compartido ni cacheado entre usuarios. |
| Reproducción excesiva en las respuestas | Limitar las citas textuales (p. ej., ≤ 300 caracteres por cita y ≤ 3 citas por respuesta). No permitir "dame el capítulo 3 completo". |
| Entrenamiento con textos de usuarios | Política explícita de **no entrenar ni ajustar modelos** con contenido de usuarios (como prometen Kobo y Recall) |
| Resúmenes compartibles | No se generan páginas públicas de resúmenes de libros |
| App Store Review 5.2 (propiedad intelectual) y 5.1 (privacidad) | Sin descargas de libros de terceros. *Privacy manifest*. Declarar el uso de IA y de servidores. |
| RGPD | Los datos de lectura revelan ideología, salud y religión (posibles **categorías especiales**, art. 9). Minimización, cifrado, exportación y borrado, DPA con los proveedores, sin analítica de contenido. |
| AI Act (UE) | Una app que usa modelos de propósito general como desplegador tiene obligaciones de **transparencia** (indicar que el contenido es generado por IA), no las de alto riesgo |
| Términos de Readwise | Cada usuario usa **su propio token**. Respetar los límites de uso. No revender datos. |
| Telegram | Es una plataforma de terceros sin cifrado de extremo a extremo en bots. Hay que avisar al usuario y ofrecer el modo mínimo. |

### 7.3 Privacidad técnica (ya, en uso personal)
- Todo el tráfico va por **HTTPS + autenticación propia** (o Tailscale/WireGuard hacia el servidor doméstico). Ollama **nunca expuesto** a Internet; solo lo usa la API interna.
- **Matriz de salida de datos visible en Ajustes:** Dispositivo (nada sale) · Tu servidor · Readwise (solo subrayados y notas) · Telegram (digest) · PCC o nube (desactivado).
- Registros del servidor **sin texto de prompts** por defecto. Copias de seguridad cifradas (rclone crypt) si van a Drive.
- Los embeddings permiten reconstruir parcialmente el texto: hay que tratarlos con la misma sensibilidad que el texto original.

---

## 8. Hoja de ruta sugerida

| Fase | Entregable |
|---|---|
| **F1** | Subrayados con CFI + sincronización con Readwise (outbox, `highlight_url`, universal links) + Definir, Explicar y Traducir en el dispositivo |
| **F2** | Ingesta y chunking en el servidor + "Contexto sin spoilers" + resumen al terminar el capítulo + "lo que va hasta aquí" |
| **F3** | Chat con el libro y la biblioteca con citas, importación del export de Readwise, "conecta con…" |
| **F4** | FSRS y flashcards, digest de Telegram con botones, temas en el tiempo, contradicciones |
| **F5** | Proveedor `LanguageModel` propio (iOS 27), índice de subrayados en el dispositivo, PCC opcional |

**Pruebas de evaluación (desde F2):** un conjunto de 30 preguntas en 3 libros (2 en español y 1 en inglés), con la respuesta esperada y la posición límite. Métricas: exactitud, **tasa de spoilers** (el objetivo es 0), validez de las citas y latencia. El framework *Evaluations* de iOS 27 y la CLI `fm` pueden servir en el lado del dispositivo.

---

## 9. Fuentes

**Readwise**
- Readwise API (oficial): https://readwise.io/api_deets
- Reader API (oficial): https://readwise.io/reader_api
- Ghostreader, prompts personalizados: https://docs.readwise.io/reader/guides/ghostreader/custom-prompts · referencia: https://docs.readwise.io/reader/guides/ghostreader/reference · visión general: https://docs.readwise.io/reader/guides/ghostreader/overview
- Changelog: https://docs.readwise.io/changelog · https://readwise.io/changelog
- MCP oficial: https://readwise.io/mcp · https://docs.readwise.io/tools/mcp · https://github.com/readwiseio/readwise-mcp · CLI: https://docs.readwise.io/tools/cli
- Webhooks: https://docs.readwise.io/readwise/docs/webhooks
- Cliente pyreadwise (código revisado): https://github.com/rwxd/pyreadwise · https://rwxd.github.io/pyreadwise/readwise-api/
- Conector de Microsoft (campos de creación): https://learn.microsoft.com/en-us/connectors/readwiseip/
- Notas de terceros sobre `includeDeleted` y sincronización incremental: https://github.com/memrynote/memry/issues/1415
- Plugins de Obsidian: https://community.obsidian.md/plugins/readwise-official · https://community.obsidian.md/plugins/obsidian-kindle-plugin · https://community.obsidian.md/plugins/tag-to-readwise
- Opiniones: https://alternativeto.net/software/readwise-reader/about · https://apps.apple.com/us/app/readwise-reader/id1567599761

**Kindle, Kobo, Apple Books**
- Ask this Book: https://gizmodo.com/kindle-ask-this-book-ai-2000699503 · https://kindlepreneur.com/amazon-ask-this-book/ · https://writerbeware.blog/2025/12/12/kindles-new-gen-ai-powered-ask-this-book-feature-raises-rights-concerns/ · https://news.slashdot.org/story/25/12/12/2046226/ · https://www.tomsguide.com/computing/e-readers/amazon-adds-ai-chatbot-to-the-kindle-app-which-offers-spoiler-free-answers-about-your-ebooks
- Recaps y Story So Far: https://techcrunch.com/2025/04/03/amazon-kindles-new-feature-uses-ai-to-generate-recaps-for-books-in-a-series · https://www.aboutamazon.com/news/books-and-authors/kindle-recaps-feature-ebook-series-refreshers · https://mobilesyrup.com/2025/04/07/amazon-using-ai-to-recap-books-on-kindle/ · https://bgr.com/2192985/kindle-cool-new-feature-story-so-far-june/
- Kobo, AI recaps: https://goodereader.com/blog/digital-publishing/kobo-plans-to-use-ai-in-their-self-publishing-platform · https://rakuten.today/blog/rakuten-kobos-push-for-smarter-more-personal-reading.html
- Apple Books en iOS 27: https://goodereader.com/blog/e-book-news/apple-books-gets-a-few-new-features-in-ios-27

**Otros competidores**
- Snipd: https://www.fastcompany.com/91498696/the-best-ai-podcast-summary-tools-to-save-time-and-find-highlights-in-2026 · https://bibigpt.co/blog/posts/snipd-2026-update-vs-bibigpt-podcast-youtube-ai
- Glasp: https://glasp.co/ · https://read.glasp.co/p/the-highlights-by-glasp-april-2026
- Heptabase, roadmap: https://wiki.heptabase.com/roadmap
- Matter: https://apps.apple.com/us/app/matter-read-listen-learn/id1501592184
- Blinkist y Shortform: https://www.befreed.ai/blog/blinkist-review-2026 · https://www.asianefficiency.com/productivity/best-ai-reading-summarizing-books/
- NotebookLM: https://nicolleweeks.substack.com/p/12-powerful-ways-to-use-notebooklm · https://timewell.jp/en/columns/notebooklm-update
- Fabric: https://fabric.so/features/reader · https://fabric.so/comparison/best-read-it-later-app
- Recall: https://www.recall.it/about · https://www.recall.it/faq · https://tooliverse.ai/tools/recall
- Elicit: https://orion.elicit.com/blog · https://fast.io/resources/elicit-ai-review-2026/

**Apple Foundation Models**
- Documentación: https://developer.apple.com/documentation/foundationmodels
- Apple ML Research, actualización de 2025: https://machinelearning.apple.com/research/apple-foundation-models-2025-updates
- WWDC26, sesión 241: https://developer.apple.com/videos/play/wwdc2026/241/ · sesión 339: https://developer.apple.com/videos/play/wwdc2026/339/ · guía iOS: https://developer.apple.com/wwdc26/guides/ios/ · guía macOS: https://developer.apple.com/wwdc26/guides/macos/
- Resúmenes de terceros: https://dev.to/arshtechpro/wwdc-2026-apples-new-server-llm-on-private-cloud-compute-whats-in-it-for-developers-2edd · https://dev.to/hariharanjagan/whats-new-in-apples-foundation-models-framework-at-wwdc-2026-5227 · https://www.callstack.com/blog/on-device-ai-after-wwdc-2026-whats-new · https://blakecrosley.com/blog/foundation-models-image-input-ios-27 · https://www.techtimes.com/articles/318039/20260609/wwdc-2026-developer-tools-foundation-models-now-swaps-ai-providers-without-code-changes.htm
- Límites y uso: https://www.natashatherobot.com/p/apple-foundation-models · https://artemnovichkov.com/blog/tracking-token-usage-in-foundation-models · https://peterfriese.dev/blog/2026/hybrid-ai-apple-foundation-models-gemini
- Idiomas de Apple Intelligence: https://communities.apple.com/es/thread/256292697 · https://9to5mac.com/2024/09/18/apple-intelligence-language-support/

**Modelos locales y RAG**
- Gemma 4: https://blog.google/innovation-and-ai/technology/developers-tools/gemma-4/ · https://codersera.com/blog/gemma-4-complete-guide-2026/
- LLM locales por VRAM: https://www.morphllm.com/best-ollama-models · https://klymentiev.com/blog/best-local-llm · https://insiderllm.com/guides/best-local-llms-translation/ · https://huggingface.co/blog/daya-shankar/open-source-llm-models-to-run-locally
- Embeddings: https://www.morphllm.com/ollama-embedding-models · https://www.bentoml.com/blog/a-guide-to-open-source-embedding-models · Qwen3 Embedding (paper): https://arxiv.org/pdf/2506.05176
- Contextual Retrieval (Anthropic): https://www.anthropic.com/news/contextual-retrieval · resumen: https://www.infoq.com/news/2024/09/anthropic-contextual-retrieval/
- pgvector (HNSW, iterative scan, halfvec): https://github.com/pgvector/pgvector
- foliate-js (CFI): https://github.com/johnfactotum/foliate-js
- FSRS: https://github.com/open-spaced-repetition

**Copyright y privacidad**
- Copia privada en España: https://osborneclarke.com/insights/the-private-copying-exception-under-spanish-law
- Directiva 2019/790 (TDM, art. 4): https://eur-lex.europa.eu/eli/dir/2019/790/oj
- Rechazo de la Authors Guild a Ask this Book: https://writerbeware.blog/2025/12/12/kindles-new-gen-ai-powered-ask-this-book-feature-raises-rights-concerns/
