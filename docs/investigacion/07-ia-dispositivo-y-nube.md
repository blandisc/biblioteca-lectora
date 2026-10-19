# 07 · IA en el dispositivo, en la nube y con tus suscripciones

> Investigación, 19 de octubre de 2026. Sustituye y amplía las secciones 3–4 de `05-ia-e-insights.md` para el escenario **sin servidor propio** (almacenamiento en iCloud / Readwise).
> **Alcance:** qué IA puede correr en un iPhone 17 Pro (12 GB) y en el plegable; Apple Foundation Models en iOS 26/27 y Private Cloud Compute; modelos abiertos con MLX / llama.cpp / Core AI; embeddings y búsqueda vectorial en el dispositivo; proveedores en la nube con clave propia (BYOK); qué se puede (y qué no) hacer con las **suscripciones** de ChatGPT, Claude, Grok y Gemini; y una arquitectura por niveles (*tiers*) para cada función de la app.

> **Nota metodológica.** Desde el entorno de investigación, muchos dominios oficiales (`openai.com`, `developers.openai.com`, `ai.google.dev`, `docs.x.ai`, `machinelearning.apple.com`, `help.openai.com`) **no resolvían por DNS**, así que se contrastaron con los fragmentos indexados de esas mismas páginas oficiales en el buscador. Sí pude abrir completas: la sesión 241 de WWDC26 (developer.apple.com), la página de acceso a PCC de Apple, la documentación de Claude (platform.claude.com, code.claude.com, support.claude.com) y GitHub.
> - ✅ = confirmado en la página oficial (abierta o en su fragmento indexado), con enlace.
> - ⚠️ = dato de terceros, contradictorio o no verificable hoy: **comprobar antes de programar**.
> Los precios cambian a menudo; todos son de octubre de 2026, por millón de tokens (MTok), en USD.

---

## Resumen ejecutivo

1. **En el iPhone, el modelo de Apple es la base y es gratis.** Foundation Models (iOS 26+) trae un modelo de unos 3B parámetros con **contexto de 8192 tokens** (Apple lo muestra en la sesión de WWDC26; en iOS 26.0 eran 4096). En iOS 27 el modelo se rehízo, **acepta imágenes**, cuenta tokens y expone un protocolo `LanguageModel` que permite enchufar otros modelos detrás de la misma API ✅. Incluye español ✅. Sirve para todo lo que trabaje sobre **un pasaje o un capítulo troceado**. No sirve para razonar sobre libros enteros ni para "conocimiento del mundo".
2. **Private Cloud Compute (PCC) es el "nivel 1" más atractivo:** un modelo de Apple mucho mayor, **32K de contexto, con razonamiento**, sin claves ni cuentas, y **sin coste para el desarrollador** si está en el App Store Small Business Program con menos de 2 M de descargas ✅. Hay límites diarios por usuario (más altos con iCloud+), sin cifra publicada ✅. Requiere un *entitlement* que se solicita a Apple ✅. **Duda clave:** si una app personal que no esté publicada en el App Store puede usarlo más allá de TestFlight o ad hoc ⚠️.
3. **Modelos abiertos en el iPhone 17 Pro: realistas hasta unos 4B parámetros a 4 bits.** Una app iOS ve unos **6 GB de RAM** con el *entitlement* de memoria ampliada (unos 8,6 GB en iOS 27, según pruebas de terceros ⚠️). Gemma 4 E2B va a 36–61 tok/s y Qwen 3.5 2B a unos 61 tok/s (MLX) en un iPhone 17 Pro ✅ (benchmark público). Qwen3.5-4B o Gemma 4 E4B caben (unos 3 GB). Un 8–9B (unos 5–6 GB) va justo y se calienta. **Aportan poco frente al modelo de Apple**, salvo en contexto largo (128K–262K nominal) y en control total. Lo dejaría como opción avanzada descargable.
4. **Embeddings y búsqueda vectorial en el dispositivo: viable para 1000–2000 libros, con planificación.** Una biblioteca así son unos **500 000 fragmentos**. Con EmbeddingGemma-300M (Core ML, unos 295 MB, en el Neural Engine) o Qwen3-Embedding-0.6B (Core AI, 1024 dimensiones truncables a 256) y vectores int8 de 256 dimensiones, el índice pesa **unos 130 MB** y una búsqueda exhaustiva tarda decenas de ms. **El cuello de botella es indexar** (unos 200 M tokens): hay que hacerlo por etapas (primero los libros abiertos, después de noche y enchufado con `BGProcessingTask`), y si se quiere, en el Mac. El índice se sincroniza por iCloud.
5. **BYOK (clave propia) es legal, sencillo y barato.** Un lector intenso (20 resúmenes de capítulo por semana, 50 explicaciones al día, digest semanal y RAG ocasional) gasta unos **4 M de tokens de entrada y 0,5 M de salida al mes**: **≈ 0,7 USD/mes** con Claude Haiku 5.5 o GPT-6 Luna, **≈ 5 USD** con Gemini 3.8 Flash y **≈ 13 USD** con Claude Sonnet 5.5 o GPT-6.1 Sol. Si las explicaciones van al modelo local, **todo baja a 0,25–5 USD/mes**. Ninguno de los cuatro grandes entrena con datos de la API por defecto ✅.
6. **Suscripciones: hay dos vías legítimas y "de lujo"; el resto viola los términos.**
   - **Claude Max (5x/20x):** desde octubre de 2026 incluye **100 o 200 USD al mes de créditos de API** ✅. El usuario los reclama, crea una API key y la pega en la app: es **BYOK pagado con la suscripción**. Pro no tiene créditos. **Usar el OAuth de claude.ai en apps de terceros está prohibido** ✅.
   - **ChatGPT Plus/Pro:** existe **"Sign in with ChatGPT" con uso del plan** (permiso `chatgpt.tokens.use.direct`, Responses API) ✅. Es autoservicio **solo para apps open-source que corren en la máquina del usuario**; las comerciales o alojadas pasan por un formulario ✅. Encaja si Biblioteca Lectora es open-source (sobre todo en el Mac); en iOS no está documentado ⚠️.
   - **SuperGrok y Google AI Pro:** **no existe vía oficial**. Las integraciones existentes reutilizan clientes OAuth ajenos y xAI/Google las bloquean o sancionan ✅/⚠️. Solo API key.
   - **Apple Intelligence + ChatGPT / "Extensions" de iOS 27:** no hay API para que una app de terceros enrute peticiones a ChatGPT o Claude por ahí. Solo funciona en la interfaz del sistema (Writing Tools, Siri). Las "Extensions" (Claude/Gemini en Apple Intelligence) **no se habían publicado** en septiembre de 2026 ⚠️.
7. **Integración inversa (que *su* ChatGPT o Claude lea nuestra biblioteca) sin servidor:** (a) **Readwise MCP**, oficial y alojado, ya da a Claude y ChatGPT acceso a los subrayados que sincronizamos; (b) un **servidor MCP local (stdio) incluido en la app de Mac**, para Claude Desktop y Codex, que usan la suscripción en el cliente oficial y por tanto son legítimos. Los conectores remotos de Claude o ChatGPT exigen una URL pública, es decir, un servidor.
8. **Arquitectura recomendada:** una sola capa en Swift sobre `LanguageModelSession` (Foundation Models), con proveedores intercambiables:
   - **Tier 0:** Apple on-device + (opcional) MLX.
   - **Tier 1:** PCC.
   - **Tier 2:** BYOK (Claude vía `ClaudeForFoundationModels`; OpenAI, xAI, OpenRouter y Gemini vía el adaptador Chat Completions de Apple o **AnyLanguageModel**).
   - **Tier 3:** créditos de Claude Max + Sign in with ChatGPT.

   **El antispoiler y la privacidad se aplican antes del modelo**: solo sale del dispositivo el texto anterior a la posición más avanzada de lectura y, en RAG, solo los fragmentos recuperados.

---

## 1. En el dispositivo

### 1.1 Apple Foundation Models: iOS 26 → iOS 27

| Aspecto | iOS 26 (2025) | iOS 26.4 / iOS 27 (WWDC 2026) | Estado |
|---|---|---|---|
| Modelo en el dispositivo | ~3B parámetros, cuantizado a 2 bits | "Un modelo nuevo, rehecho desde cero, mejor en lógica y tool calling" | ✅ [sesión 241](https://developer.apple.com/videos/play/wwdc2026/241/) |
| Familia AFM 3 | — | *AFM 3 Core* (3B denso) y *AFM 3 Core Advanced* (20B disperso con 1–4B activos, en flash; multimodal). Hecho "en colaboración con Google". | Existencia ✅ [Apple ML Research](https://machinelearning.apple.com/research/introducing-third-generation-of-apple-foundation-models) (fragmento). **Si los desarrolladores acceden al 20B y en qué dispositivos: ⚠️ no consta.** |
| Ventana de contexto | 4096 tokens | API `contextSize` y `tokenCount(for:)` desde iOS 26.4. El ejemplo de Apple imprime **8192**. | ✅ sesión 241 |
| Entrada de imagen | No | **Sí** (`Attachment(UIImage/CGImage/URL…)`, cualquier tamaño; más imagen = más tokens) | ✅ sesión 241 |
| Herramientas del sistema | — | `OCRTool`, `BarcodeReaderTool` y una herramienta de **búsqueda en Spotlight para "RAG totalmente local"** | ✅ sesión 241 |
| Uso de tokens | — | `response.usage` (entrada, en caché, salida y razonamiento) | ✅ sesión 241 |
| Protocolo `LanguageModel` | — | `SystemLanguageModel` y `PrivateCloudComputeLanguageModel` lo cumplen. Apple publica como open source `CoreAILanguageModel` y `MLXLanguageModel`. Anthropic y Google publican paquetes Swift. Hay un paquete de utilidades con un modelo para **servidores Chat Completions**. | ✅ sesión 241 |
| Open source | — | El núcleo del framework será open source (también en Linux). SDK de Python y CLI `fm` en macOS 27. | ✅ sesión 241 |
| Idiomas | Los de Apple Intelligence, **español incluido** | Sin cambios anunciados | ✅ (2025) / ⚠️ lista de iOS 27 sin verificar. **Ojo:** el framework no está disponible si el *idioma del sistema* no está soportado ([foro de Apple](https://developer.apple.com/forums/thread/805378)). |
| Dispositivos | iPhone 15 Pro o posterior, M1 o posterior, Apple Intelligence activado | Ídem (+ watchOS 27 vía PCC) | ✅ |

**Implicaciones:**
- Con 8K de contexto entra **un pasaje con su contexto (2–3 páginas)** con holgura. Un **capítulo** (unos 8–15K tokens en español) necesita *map-reduce*: trozos de unos 5K, resúmenes parciales y una fusión final.
- Las imágenes abren la puerta a **explicar ilustraciones o páginas de cómic/PDF** en el dispositivo.
- El modelo sigue siendo pequeño: **no hay que pedirle hechos del mundo** ("¿quién era Kant?"). Esas preguntas van al tier 1 o 2.

### 1.2 Private Cloud Compute para terceros (iOS 27)

| Aspecto | Dato | Estado |
|---|---|---|
| Modelo | "El mismo que alimenta muchas funciones de Apple Intelligence; mucho más grande que el del dispositivo". **32 000 tokens de contexto**. **Razonamiento** con `ContextOptions(reasoningLevel: .light / .deep)`. | ✅ [sesión 241](https://developer.apple.com/videos/play/wwdc2026/241/) |
| Uso en código | `LanguageModelSession(model: PrivateCloudComputeLanguageModel(...))`: "una línea", con `@Generable` y tools sin cambios | ✅ |
| Cuenta y claves | Ninguna: "no account setup, no authentication, no API keys" | ✅ |
| Privacidad | "No prompts are ever stored", verificable por investigadores independientes | ✅ |
| Coste | **Sin coste de API en la nube** para desarrolladores con < 2 M de descargas *first-time* | ✅ |
| Elegibilidad | (1) App Store **Small Business Program**, (2) < 2 M descargas, (3) **entitlement PCC** asignado (se pide en `developer.apple.com/contact/request/private-cloud-compute/`) | ✅ [developer.apple.com/private-cloud-compute](https://developer.apple.com/private-cloud-compute) |
| Distribución | "Apps distribuidas en el App Store". Se puede probar en **TestFlight o ad hoc** (no cuentan como descargas). Si se supera el umbral, hay 6 meses para migrar. | ✅ |
| Cuotas | **Límites diarios por usuario** (más altos con iCloud+). Varían según la función, la complejidad y la demanda. Sin cifra publicada. En el futuro habrá "acceso ampliado de pago". | ✅ (sin números) |
| Errores de cuota | `LanguageModelError` permite reaccionar al acercarse al límite diario. Apple recomienda mostrar el estado de uso de forma persistente. | ⚠️ (resumen de terceros de la sesión 319) |
| Papeleo | Para entrar en el Small Business Program hace falta el Paid Applications Agreement (datos bancarios y fiscales), incluso solo para evaluar | ⚠️ [foro](https://developer.apple.com/forums/thread/842656) |

**Para Biblioteca Lectora:** PCC es ideal para resúmenes de capítulo completos, "story so far", digest semanal y respuestas RAG de 20–30K tokens. Es gratis, sin claves y con la mejor privacidad fuera del dispositivo.
- **Riesgo:** si la app es de uso personal y nunca se publica, depender de PCC con TestFlight o ad hoc es una zona gris (está pensado "para probar") ⚠️.
- **Recomendación:** solicitar el *entitlement* pronto. Si la app se publica en el App Store (aunque sea gratis y minoritaria), encaja de lleno.

### 1.3 Modelos abiertos en el iPhone: MLX, llama.cpp, Core AI

**Runtimes:**
- **MLX Swift** (`mlx-swift-lm`): el más rápido en GPU en las pruebas públicas. Es el `MLXLanguageModel` que Apple publica para el protocolo.
- **llama.cpp** (GGUF): muy portátil; `mmap` de los pesos.
- **Core AI**: sucesor de Core ML anunciado en WWDC26 para modelos grandes ⚠️ (detalles de terceros). Ya hay exportaciones comunitarias (p. ej., Qwen3-Embedding-0.6B-CoreAI).
- **LiteRT-LM** de Google.

**Benchmarks reales en iPhone 17 Pro** ([apple-silicon-llm-bench](https://github.com/john-rocky/apple-silicon-llm-bench), chat corto, decode):

| Modelo | Runtime | tok/s decode | Memoria |
|---|---|---|---|
| Qwen3 0.6B Q4 | MLX | 159 | 0,5 GB |
| Qwen3 0.6B INT4 | Core AI (GPU) | 193 | 0,2 GB |
| Gemma 4 E2B 4-bit | MLX-Swift | 36–49 | 3,0–4,6 GB |
| Gemma 4 E2B | LiteRT-LM | 61 (prefill 3500 tok/s) | 0,5 GB |
| Gemma 4 E2B Q4_K_M | llama.cpp | 39 | mmap |
| Qwen 3.5 2B | MLX-Swift | 61 (build debug) | 1,3 GB |

No hay mediciones públicas de 4B u 8B en el iPhone 17 Pro ⚠️. Otra prueba con Qwen3 1.7B reporta unos 40 tok/s y algo de *throttling* térmico en uso sostenido ⚠️ ([fuente](https://rickytakkar.com/blog_russet_mlx_benchmark.html)). **Mi estimación:** 4B a 4 bits ≈ 20–30 tok/s y 8B ≈ 10–15 tok/s, con calentamiento.

**Límite de memoria (lo que manda):**
- *Entitlement* `com.apple.developer.kernel.increased-memory-limit` ✅ ([doc](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.kernel.increased-memory-limit)). Apple no da cifra: hay que consultar `os_proc_available_memory()`.
- Medido por la comunidad: **unos 6 GB** en un iPhone 17 Pro Max de 12 GB ([foro](https://developer.apple.com/forums/thread/834805)); **unos 8,6 GB** con iOS 27 beta 3 en 17 Pro/Pro Max/Air ⚠️ ([iPhoneSoft](https://iphonesoft.fr/2026/07/20/ios-27-beta-3-modifie-plafond-ram-applications-jeux-8-6-go-disponibles)).

**Qué cabe (12 GB de RAM, unos 6–8 GB útiles para la app):**

| Modelo (2026) | Pesos a 4 bits | Contexto nominal | ¿iPhone 17 Pro? | Comentario |
|---|---|---|---|---|
| **Qwen3.5-0.8B / 2B** (mar. 2026, Apache 2.0) | < 2 GB | 262K | Sí, holgado | Muy multilingüe (201 idiomas ⚠️). Útil para clasificar o etiquetar. |
| **Qwen3.5-4B** | ~3 GB | 262K | **Sí** | El punto dulce local. KV cache: limitar a unos 16–32K reales. |
| **Gemma 4 E2B / E4B** (abr. 2026) | 1,5–3 GB (E4B ~4,4 GB en MLX en Mac) | 128K (E4B) ⚠️ | Sí | Buen español. Multimodal. |
| Llama 3.2 3B | ~2 GB | 128K | Sí | Superado por Qwen 3.5 y Gemma 4 |
| Phi-4-mini (3,8B) | ~2,3 GB | 128K | Sí | Más flojo en español ⚠️ |
| **Qwen3.5-9B / Qwen3-8B** | ~5–6 GB | 262K / 128K | **Justo**: solo con el límite ampliado y contexto corto; riesgo de *jetsam* | En iPad M5 o Mac sí |

**Tamaño de la app y descarga:** **no hay que incluir el modelo en el binario**.
- Descarga bajo demanda (Background Assets / `URLSession` en segundo plano) desde Hugging Face al contenedor de la app, excluido del backup de iCloud.
- Mostrar el tamaño (1,5–3 GB) y pedir Wi-Fi.
- Comprobar la RAM disponible antes de cargar el modelo.

**Batería y temperatura:** la generación sostenida en GPU calienta el teléfono y reduce los tok/s en minutos.
- Usar modelos locales para **ráfagas cortas** (explicar o definir).
- Las tareas largas (resumir 50 capítulos) van **de noche y enchufado** o en PCC.

**Ejecución en segundo plano:**
- **`BGProcessingTask`**: el sistema lo lanza cuando quiere (idealmente cargando y en reposo); la duración depende del sistema. Es lo indicado para **indexar embeddings y pre-resumir** por la noche ✅ (comportamiento conocido de la API).
- **`BGContinuedProcessingTask` (iOS 26):** continúa una tarea **iniciada por el usuario** al salir de la app, con progreso visible en la interfaz del sistema. **El acceso a GPU en segundo plano solo existe en iPad con M3 o posterior; en ningún iPhone** (respuesta de un ingeniero de DTS) ✅ ([foro](https://developer.apple.com/forums/thread/816774)). En iPhone, un trabajo con GPU en curso al pasar a segundo plano puede **abortar la app** ([whisper.cpp #3531](https://github.com/ggml-org/whisper.cpp/issues/3531)).
- **Conclusión:** en iPhone, la inferencia MLX en segundo plano debe ir por CPU/ANE (más lenta) o pausarse. Los embeddings en Core ML/ANE son mejores candidatos que un LLM en GPU para trabajo en segundo plano ⚠️ (hay que medirlo).
- No está claro si Foundation Models on-device corre en segundo plano sin restricciones ⚠️. Hay que medirlo.

**iPhone plegable ("Duo") y iPad:** se aplica lo mismo, siempre que el chip tenga Apple Intelligence.
- Detectar `SystemLanguageModel.default.availability` y la memoria en tiempo de ejecución, **nunca el modelo de dispositivo**.
- El iPad M3+ es el único que puede seguir con GPU en segundo plano.

### 1.4 Embeddings en el dispositivo

| Opción | Tamaño | Dimensión | Idiomas | Runtime | Estado |
|---|---|---|---|---|---|
| `NLContextualEmbedding` (NaturalLanguage, iOS 17+) | Viene con el sistema (descarga de assets) | `dimension` en tiempo de ejecución; vectores por token, hay que hacer *pooling* | Modelos por *script* (latino cubre es/en) | ANE | ✅ existe ([doc](https://developer.apple.com/documentation/naturallanguage/nlcontextualembedding)); ⚠️ calidad de recuperación no publicada |
| **EmbeddingGemma-300M** (Core ML) | ~295 MB INT8; 99,8 % de las operaciones en el ANE | 768 (Matryoshka 512/256/128) | 100+ | Core ML, iOS 26 | ✅ conversión comunitaria ([HF](https://huggingface.co/valindotai/embeddinggemma-300m-coreml)) |
| **Qwen3-Embedding-0.6B** (Core AI) | ~0,6B parámetros | 1024 (truncable a 256 manteniendo el ranking) | Multilingüe, con instrucciones | Core AI, iOS 27 | ✅ ([HF](https://huggingface.co/coreai-community/Qwen3-Embedding-0.6B-CoreAI)) |
| multilingual-e5-small | ~118 M | 384 | 100 | Core ML (conversión propia) | ⚠️ |
| Spotlight + herramienta de búsqueda de Foundation Models | — | — | — | Sistema | ✅ existe (sesión 241); ⚠️ sin control de chunking ni de filtro antispoiler |

**Recomendación:**
- **EmbeddingGemma-300M en Core ML** como modelo por defecto: corre en iOS 26, en el ANE (bajo consumo y apto para segundo plano) y es multilingüe.
- Qwen3-Embedding-0.6B en Core AI cuando el mínimo sea iOS 27, si las pruebas propias en español lo justifican.
- **Truncar a 256 dimensiones y cuantizar a int8.**
- **El mismo modelo en todas las plataformas**, para que el índice sea portátil entre iPhone, iPad y Mac. En la web: el mismo modelo en ONNX/WebGPU o sin búsqueda semántica.

**Búsqueda vectorial:**
- **sqlite-vec** (extensión C, tabla `vec0`, KNN por fuerza bruta; int8 y binario). Hay *bindings* Swift ([SQLiteVec](https://github.com/Get-Pally/SQLiteVec)). En iOS **hay que compilarla estáticamente**, porque el SQLite del sistema no carga extensiones; con GRDB hace falta un SQLite propio ⚠️. Referencia: 100K vectores × 384 dimensiones ≈ 68 ms en un M1 Pro.
- **USearch** (HNSW, *bindings* Swift; sub-ms a escala de millones) es la alternativa si la fuerza bruta se queda corta ⚠️.
- **Ojo:** `sqlite-vector` (sqliteai) es otro proyecto, con licencia Elastic 2.0.

**Dimensionado para 1000–2000 libros (es/en):**

| Magnitud | Cálculo | Resultado |
|---|---|---|
| Tokens por libro | ~90–110K palabras → ~130–150K tokens | ~140K |
| Fragmentos (400 tokens, solape 15 %) | 140K / 340 | ~400 por libro |
| Biblioteca de 1500 libros | 1500 × 400 | **~600 000 fragmentos** |
| Índice int8 de 256 dimensiones | 600K × 256 B | **~150 MB** (float32 de 1024 dim = 2,4 GB: descartado) |
| Búsqueda exhaustiva | 600K productos int8 con NEON | decenas de ms (estimación ⚠️) |
| Coste de indexar | ~210 M tokens. Con unos 2–5K tok/s en el ANE ⚠️ | **~12–30 horas de cómputo** |

**Estrategia de indexado:**
1. **Indexar a nivel de libro primero** (metadatos, sinopsis, subrayados y notas): minutos para toda la biblioteca. Basta para auto-etiquetado y conexiones entre libros.
2. **Texto completo de los libros que se están leyendo o ya se leyeron** (el RAG útil está ahí): al abrir cada libro, en segundo plano.
3. **El resto, de noche y enchufado** con `BGProcessingTask`, por lotes y reanudable.
4. **El Mac (cualquier Apple silicon) puede indexar por todos:** un modelo de 300M es ligero aunque el Mac "no pueda con LLM grandes". El índice se sincroniza como fichero SQLite por libro en iCloud Drive o como asset de CloudKit.
5. Alternativa en la nube (opt-in): embeddings por API (~0,02–0,15 USD/MTok ⚠️), unos 4–30 USD una sola vez. **Sale el texto completo de los libros**: solo con consentimiento explícito.

### 1.5 ¿Qué funciones son realistas en el dispositivo?

| Función | Apple on-device (8K) | MLX 4B | Comentario |
|---|---|---|---|
| Explicar / definir / traducir la selección | ✅ Excelente | ✅ | Pasaje + párrafos vecinos ≈ 1–2K tokens. Traducir es↔en bien. Las definiciones "del mundo" pueden alucinar → botón "ampliar con nube". |
| Auto-etiquetado (géneros, temas) | ✅ (adaptador `.contentTagging` + `@Generable`) | ✅ | Con sinopsis y primeras páginas |
| Flashcards y preguntas de reflexión por subrayado | ✅ | ✅ | — |
| "Tus ideas clave" (a partir de los subrayados) | ⚠️ Map-reduce si hay > 100 subrayados | ✅ (contexto mayor) | Calidad media; mejor en PCC o nube |
| Resumen de capítulo sin spoilers | ⚠️ Map-reduce (3–4 llamadas) | ⚠️ Lento y calienta | Calidad aceptable; PCC mejor |
| "Story so far" y lista de personajes | ⚠️ Incremental: un resumen por capítulo leído + fusión | ⚠️ | Funciona si se va guardando capítulo a capítulo |
| Conexiones entre libros (embeddings) | ✅ (embeddings + vecinos) | — | La explicación de *por qué* conectan: on-device ok |
| Digest semanal | ⚠️ Puede, con material pre-resumido | ⚠️ | Mejor en PCC o nube |
| Chat con la biblioteca (RAG con citas) | ⚠️ Solo preguntas acotadas (8K ≈ 8 fragmentos) | ⚠️ 16–32K | PCC (32K) o nube para respuestas buenas |
| Esquema previo para lectura rápida | ✅ por capítulo | ✅ | Títulos, primeras frases y palabras clave → esquema |

---

## 2. Nube con clave propia (BYOK)

### 2.1 Modelos y precios (octubre de 2026, USD/MTok)

| Proveedor | Modelo | Entrada | Caché (lectura) | Salida | Contexto | Estado |
|---|---|---|---|---|---|---|
| **Anthropic** | Claude Opus 5.5 | 4,00 | 0,20 | 20,00 | 1M | ✅ (tabla oficial cacheada al 6-10-2026) |
| | Claude Sonnet 5.5 | 2,00 | 0,20 | 10,00 | 1M | ✅ |
| | **Claude Haiku 5.5** | **0,10** | — | **0,50** (0,50/2,50 por encima de 100K) | 1M | ✅ |
| | Claude Fable 5.1 (tope de gama) | 10,00 | 0,25 | 50,00 | 1M | ✅ |
| **OpenAI** | GPT-6 Astra | 10,00 | 1,00 | 50,00 | — | ✅ [pricing](https://developers.openai.com/api/docs/pricing) (fragmento) |
| | GPT-6.1 Sol | 2,00 | 0,10 | 10,00 | 1,05M (×2 por encima de 272K) | ✅ [modelo](https://developers.openai.com/api/docs/models/gpt-6.1-sol) |
| | **GPT-6 Luna** | **0,10** | 0,01 | **0,50** | 1,05M (922K de entrada) | ✅ [modelo](https://developers.openai.com/api/docs/models/gpt-6-luna) |
| **Google** | **Gemini 3.8 Flash** | 0,75 (→ 1,50 desde el 1-1-2027) | 0,075 | 3,75 (→ 7,50) | 1M | ✅ [modelo](https://ai.google.dev/gemini-api/docs/models/gemini-3.8-flash) |
| | Gemini 3.5 Flash-Lite | 0,30 | — | 2,50 | 1M ⚠️ | ✅ [pricing](https://ai.google.dev/gemini-api/docs/pricing) |
| | Gemini 2.5 Flash-Lite | 0,10 | — | 0,40 | 1M | ✅ |
| | Gemini 3.1 Pro | ~2,00 | ~0,20 | ~12,00 | 1M | ⚠️ terceros |
| **xAI** | Grok 4.7 | 2,00 | 0,50 | 6,00 | 500K | ✅ [models](https://docs.x.ai/developers/models) (fragmento) |
| | Grok 4.3 | 1,25 | 0,20 | 2,50 | 1M | ✅ |
| **OpenRouter** | Todos los anteriores y modelos abiertos | precio del proveedor | — | — | — | Comisión del **5,5 % al comprar créditos** ⚠️. BYOK sin comisión hasta 25 000 USD/mes ⚠️ |

**Prompt caching:**
- Anthropic: automático o con `cache_control`; lectura ≈ 10 % del precio de entrada.
- OpenAI: automático (≈ 5–10 %).
- Gemini: caché explícita al 10 % + **almacenamiento por hora** (¡ojo con cachés olvidadas!).
- xAI: 25 % (Grok 4.7).

Para la app interesa cachear el **prefijo estable** (instrucciones + metadatos del libro + "story so far") y poner al final la pregunta o la selección.

**Batch (−50 %):** Anthropic, OpenAI y Gemini. Útil para pre-resumir capítulos de noche sin prisa.

### 2.2 Estimación de coste mensual (lector intenso)

| Uso | Volumen/mes | Entrada | Salida |
|---|---|---|---|
| Resúmenes de capítulo (20/semana) | 87 × (10K capítulo + 1K "story so far" + 0,5K instrucciones) | 1,0 M | 52K |
| Explicar / definir (50/día) | 1500 × 1,5K | 2,25 M | 375K |
| Digest semanal | 4 × 20K | 0,08 M | 6K |
| RAG "chat con mi biblioteca" | 30 × 12K (fragmentos) | 0,36 M | 24K |
| Flashcards, reflexión, etiquetas | 220 × 1K | 0,22 M | 60K |
| **Total** | | **≈ 3,9 M** | **≈ 0,52 M** |

| Modelo | Todo en la nube | Híbrido (explicar en el dispositivo; 1,7 M entrada / 0,15 M salida) |
|---|---|---|
| Claude Haiku 5.5 / GPT-6 Luna | **≈ 0,65 USD** | ≈ 0,25 USD |
| Gemini 3.5 Flash-Lite | ≈ 2,5 USD | ≈ 0,9 USD |
| Gemini 3.8 Flash (intro / 2027) | ≈ 4,9 / 9,8 USD | ≈ 1,8 / 3,7 USD |
| Grok 4.3 | ≈ 6,2 USD | ≈ 2,5 USD |
| Grok 4.7 | ≈ 11 USD | ≈ 4,3 USD |
| Claude Sonnet 5.5 / GPT-6.1 Sol | **≈ 13 USD** | ≈ 4,9 USD |
| Claude Opus 5.5 | ≈ 26 USD | ≈ 9,8 USD |

**Puntuales:**
- "Pregunta al libro entero" con el libro completo en contexto (~150K tokens): 0,30 USD con Sonnet 5.5; ~0,02–0,08 USD con Haiku 5.5 (se aplica la tarifa > 100K). Con caché, las preguntas siguientes cuestan un 90 % menos.
- Pre-resumir 1500 libros enteros en batch con un modelo barato: **~15–40 USD una sola vez** (pero sale todo el texto).

**Conclusión:** con un **modelo barato por defecto** (Haiku 5.5 / GPT-6 Luna / Flash) y el **modelo bueno solo bajo demanda** ("respuesta profunda"), el coste es irrelevante: < 2 USD/mes.

### 2.3 Privacidad de la API

| Proveedor | ¿Entrena con datos de la API? | Retención por defecto | ZDR | Fuente |
|---|---|---|---|---|
| Anthropic | **No** por defecto (solo con opt-in) | 30 días | Sí, en endpoints y modelos elegibles (no Fable/Mythos sin autorización) | ✅ [privacy.claude.com](https://privacy.claude.com/en/articles/7996868-is-my-data-used-for-model-training), [retención](https://platform.claude.com/docs/en/manage-claude/api-and-data-retention) |
| OpenAI | **No** desde el 1-3-2023 (salvo opt-in) | Hasta 30 días (abuso). En la Responses API, usar `store:false`. | Con aprobación | ✅ [data controls](https://developers.openai.com/api/docs/guides/your-data) |
| Google Gemini | **Nivel gratuito: SÍ** (y revisión humana). **De pago: no.** | Registro breve (abuso). La búsqueda con Google Search guarda 30 días. | Sí | ✅ [términos](https://ai.google.dev/gemini-api/terms) → **exigir una clave con facturación activa** |
| xAI | **No** sin permiso explícito | 30 días | Enterprise | ✅ [FAQ](https://docs.x.ai/developers/faq/security) |
| OpenRouter | Depende del proveedor final. Hay que activar el filtro de proveedores sin entrenamiento o ZDR. | — | Por proveedor | ⚠️ |

### 2.4 Guardar la clave y llamar desde la app (sin servidor)

- **Keychain** con `kSecClassGenericPassword`:
  - `kSecAttrSynchronizable = true`: **iCloud Keychain** la sincroniza al iPad y al Mac. Encaja con "sin servidor".
  - `kSecAttrAccessibleAfterFirstUnlock`, para poder usarla en tareas de segundo plano. Nunca en `UserDefaults` ni en iCloud KVS.
- **Es la clave del usuario, en su dispositivo.** Las advertencias de Anthropic y Apple ("no metas claves en el binario") se refieren a la clave **del desarrollador** empaquetada en la app. Aquí no aplica: el usuario pega la suya.
  - Si la app se publica y el desarrollador quisiera pagar él, Anthropic ofrece **App Attest** (`.appAttest(clientID:)`): tokens de 1 h por dispositivo, sin backend ✅ ([doc](https://platform.claude.com/docs/en/cli-sdks-libraries/libraries/apple-foundation-models)).
- **Llamadas directas** a `api.anthropic.com`, `api.openai.com`, `generativelanguage.googleapis.com`, `api.x.ai` u `openrouter.ai` desde `URLSession`.
- Buenas prácticas:
  - Validar la clave con una llamada barata.
  - Mostrar el gasto con los campos `usage`.
  - Permitir un **límite mensual en la app**, y recomendar al usuario un *spend limit* por workspace en la consola del proveedor.
- **Web:** no hay Keychain. Opciones: la clave en memoria de la sesión, o cifrada con passkey/WebCrypto en IndexedDB.
  - Anthropic admite llamadas desde el navegador con la cabecera `anthropic-dangerous-direct-browser-access` ⚠️; otros proveedores pueden bloquear CORS ⚠️.
  - Alternativa: la web solo con funciones on-device o sin IA.

---

## 3. Usar las SUSCRIPCIONES desde una app de terceros

### 3.1 Tabla de veredictos

| Suscripción | ¿Vía oficial para nuestra app? | Qué está permitido | Qué viola los términos |
|---|---|---|---|
| **Claude Pro** | **No** | API key de pago (BYOK) | Usar el OAuth de claude.ai, tokens de Claude Code o "Sign in with Claude" en apps de terceros |
| **Claude Max 5x / 20x** | **Sí, indirecta:** **100 / 200 USD/mes de créditos de API incluidos** (y Team: 20–100 USD por asiento, máx. 500) ✅ | El usuario vincula una organización de Console en claude.ai › Billing, crea una API key y la pega en la app: **BYOK pagado por su suscripción**. Cubre la API de Claude, el Agent SDK y Managed Agents. Caducan cada mes sin acumularse. Los compras por iOS también cuentan. | Ídem Pro |
| **ChatGPT Plus / Pro** (y Go según la ayuda) | **Sí, en preview:** **Sign in with ChatGPT + "use your ChatGPT plan"** ✅ | Permiso opcional del usuario (`chatgpt.tokens.use.direct` + scopes de la Responses API). Las peticiones elegibles van a `api.openai.com/v1/responses` con el token OAuth del usuario y descuentan del uso del plan. **Autoservicio para apps open-source que corren en la máquina del usuario.** Apps comerciales o alojadas: formulario de interés. | Reutilizar el `client_id` de Codex u otro; repartir tokens; hacer de intermediario de muchos usuarios |
| **SuperGrok / X Premium+** | **No** ✅/⚠️ | API key de xAI | Los plugins que reutilizan el `client_id` de Grok-CLI son "no oficiales". xAI aplica una *allowlist* y devuelve 403. |
| **Google AI Pro / Ultra** | **No** ✅ | API key de Gemini (de pago) | Usar el OAuth de Gemini CLI o Antigravity en software de terceros: "puede suponer la suspensión de la cuenta"; hubo baneos en febrero de 2026 |
| **ChatGPT dentro de Apple Intelligence** | **No hay API** | El usuario puede usar **Writing Tools** (con ChatGPT) sobre cualquier campo de texto de nuestra app (notas): es interfaz del sistema, no una API | — |
| **iOS 27 "Extensions"** (elegir Claude, Gemini… en Apple Intelligence) | **No publicado** a 14-9-2026; el entitlement no está abierto a terceros ⚠️ | Si llega, lo usará el sistema (Siri, Writing Tools), **no nuestras llamadas programáticas** | — |

### 3.2 Detalle por proveedor

**Anthropic (Claude).**
- Texto oficial ✅ ([code.claude.com, Legal and compliance](https://code.claude.com/docs/en/legal-and-compliance)): *"Anthropic does not permit third-party developers to offer Claude.ai login into their own applications, or to route requests through Free, Pro, or Max plan credentials on behalf of their users. Moreover, developers may not collect, store, or intermediate Claude.ai credentials or session tokens."* La aplicación de esta norma empezó en enero de 2026, con la aclaración legal del 19–20 de febrero de 2026 ([WinBuzzer](https://winbuzzer.com/2026/02/19/anthropic-bans-claude-subscription-oauth-in-third-party-apps-xcxwbn/)).
- Hubo un pool de "créditos programáticos" anunciado para el 15 de junio de 2026, **en pausa** ✅ ([support](https://support.claude.com/en/articles/15036540-use-the-claude-agent-sdk-with-your-claude-plan)). Esa página dice que el Agent SDK y "third-party apps" siguen usando los límites de la suscripción **cuando el usuario inicia sesión con su plan en herramientas permitidas**. Eso no autoriza a *nosotros* a ofrecer el login de Claude.
- **La vía de lujo es la de los créditos de Max** ✅ ([API credits for Max and Team](https://platform.claude.com/docs/en/about-claude/api-credits-for-subscribers)):
  - 100 USD/mes (Max 5x) cubren de sobra, cada mes, el uso intenso estimado: unos 0,65 USD con Haiku 5.5, unos 13 USD con Sonnet 5.5 y unos 26 USD con Opus 5.5.
  - Al agotarse, las peticiones fallan (nunca se cobra a la suscripción) salvo que haya créditos comprados.
- **Paquete oficial `ClaudeForFoundationModels`** (beta, iOS 27) ✅: `ClaudeLanguageModel` cumple `LanguageModel`, así que funciona con `LanguageModelSession`, `@Generable`, tools, streaming e imágenes; también *server tools* (web search). Las peticiones van directas a la API (Apple no las ve).
  - Autenticación: `.apiKey` (nuestro caso BYOK), `.appAttest` o `.proxied`.
  - Prompt caching automático; sin batch, sin Files ni token counting.

**OpenAI (ChatGPT).**
- Sign in with ChatGPT nació como beta de identidad en julio de 2026. En DevDay (29-9-2026) se añadió el **uso del plan** ✅ ([help](https://help.openai.com/en/articles/20001542-using-your-chatgpt-plan-in-other-apps-and-sites), [docs](https://developers.openai.com/siwc/token-sharing-open-source)). Detalles ✅ ([preview limitations](https://developers.openai.com/siwc/token-sharing-open-source/preview-limitations)):
  - Responses API con `store:false` y `stream:true`, sin `temperature`, `max_output_tokens` ni `previous_response_id`.
  - Sin file search ni MCP alojado.
  - Access token de 1 h y refresh de 30 días.
  - En Plus, el límite de 5 h es compartido con el resto de apps.
  - No da acceso a las conversaciones del usuario.
  - El usuario fija un tope semanal por app.
- El [DevKit oficial](https://github.com/openai/sign-in-with-chatgpt-devkit) es *"for developers building open-source apps that run on a user's own machine"*: Node, ejemplo en macOS y licencia no comercial.
- **Para nosotros:**
  - **Mac:** si el proyecto es open-source, encaja con la vía de autoservicio.
  - **iOS:** técnicamente es OAuth+PKCE con `ASWebAuthenticationSession` y llamadas HTTP. No he encontrado documentación que lo excluya ni que lo admita ⚠️ → **rellenar el formulario de interés** o preguntar.
  - Encaja con la abstracción (es la Responses API), pero **el adaptador Chat Completions de Apple no sirve**: hace falta un `LanguageModel` propio para Responses.

**xAI (Grok).**
- No hay programa oficial ⚠️ (no lo encontré en docs.x.ai).
- Las integraciones de Warp, OpenCode o LobeHub usan flujos *device-code*. Algunas se declaran "unofficial, not affiliated with xAI" y reportan **403 por allowlist** ([pi-xai-supergrok](https://cdn.jsdelivr.net/npm/pi-xai-supergrok@0.2.1/README.md)).
- **Recomendación:** solo API key.

**Google (Gemini).**
- La documentación de Gemini CLI: usar su OAuth con software de terceros *"is a violation of applicable terms… grounds for suspension"* ✅ ([geminicli.com](https://www.geminicli.com/docs/resources/tos-privacy)).
- No hay programa para apps ([foro](https://discuss.ai.google.dev/t/gemini-subscription-access-for-third-party-apps-is-a-sanctioned-program-planned/175577)).
- Solo API key de pago. Hay un paquete **Firebase AI Logic para Foundation Models** (preview), pero es facturación **del desarrollador** vía Firebase y App Check ✅ ([blog](https://firebase.blog/posts/2026/06/apple-foundation-models-gemini)). No sirve para BYOK.

### 3.3 Integración inversa: que la IA del usuario lea nuestra biblioteca

| Vía | Cómo | ¿Servidor? | ¿Usa la suscripción? | Legitimidad |
|---|---|---|---|---|
| **Readwise MCP** (oficial, alojado) | Sincronizamos los subrayados con Readwise (ya previsto). El usuario añade `https://mcp2.readwise.io/mcp` como conector en Claude (web, Desktop o móvil) o ChatGPT (Plus+). | No (lo pone Readwise) | **Sí** | ✅ [docs.readwise.io/tools/mcp](https://docs.readwise.io/tools/mcp). **La forma más barata de dar "chat con mis subrayados" con Claude o ChatGPT de suscripción.** Solo subrayados y notas, no el texto completo. |
| **MCP local (stdio) en la app de Mac** | La app de Mac incluye un binario `lectora-mcp` (o una extensión `.mcpb`) que expone herramientas: `buscar(q)`, `fragmentos(libro, hasta_posición)`, `subrayados`, `progreso`… sobre el índice local sincronizado por iCloud. | No | **Sí** (Claude Desktop con Pro/Max; Codex con ChatGPT) | ✅ El usuario usa el cliente oficial con su plan. Claude Desktop admite servidores locales en `claude_desktop_config.json` ([support](https://support.claude.com/en/articles/11503834)). ⚠️ Comprobar el soporte de MCP local en Codex en octubre de 2026. **ChatGPT web/app no admite MCP local.** |
| Conector remoto (Claude custom connector, ChatGPT Apps SDK / developer mode) | Servidor MCP con URL HTTPS pública + OAuth | **Sí** | Sí | ✅, pero rompe "sin servidor" (podría ser una Cloudflare Worker sobre datos exportados: fuera de alcance) |
| App Intents / Siri (iOS 27) | Exponer `AppEntity` (libros, subrayados) e intents ("¿qué subrayé sobre X?") | No | Siri de Apple (con Gemini por dentro) | ✅ App Intents. ⚠️ Que Siri o Extensions enruten a Claude/ChatGPT depende de Apple. |

**Antispoiler en la integración inversa:** el servidor MCP local solo debe devolver texto con `posición ≤ progreso_máximo`. Cuando la consulta va a un cliente externo, la herramienta **no ofrece** "dame el capítulo N" si el usuario no ha llegado.

---

## 4. Arquitectura recomendada por niveles

### 4.1 Capa de abstracción

```
LectoraAI (fachada por función: explain(), summarizeChapter(), ask()…)
   │  política: tier preferido, privacidad, presupuesto, conectividad, cuota PCC
   ▼
LanguageModelSession (Foundation Models, iOS/macOS 27)
   ├─ SystemLanguageModel                    ← tier 0 (on-device, gratis)
   ├─ MLXLanguageModel (Apple, open source)  ← tier 0b (opcional: Qwen3.5-4B / Gemma 4 E4B)
   ├─ PrivateCloudComputeLanguageModel       ← tier 1 (PCC, gratis con entitlement)
   ├─ ClaudeLanguageModel (.apiKey del Keychain) ← tier 2 / tier 3 (créditos Max)
   ├─ ChatCompletionsLanguageModel (utilidades de Apple) → OpenAI, xAI, OpenRouter, Gemini (endpoint compatible ⚠️)
   └─ ResponsesLanguageModel (propio)         ← tier 3 (Sign in with ChatGPT, plan)
```

- **Requisito de iOS 27 para el protocolo.** Para **iOS 26** (o como plan B si la API beta cambia) se puede usar **AnyLanguageModel** de Hugging Face ✅ ([repo](https://github.com/huggingface/AnyLanguageModel), v0.9.0 de julio de 2026). Es un sustituto directo de la API de Foundation Models (cambiando el `import`) con *backends* Core ML, MLX, llama.cpp, OpenAI, Anthropic, Gemini y Ollama, y los activa por *traits*.
- **Recomendación:** mínimo iOS 27 si la app sale en 2027 (todo nativo). Si no, AnyLanguageModel ahora y migrar después.
- **Selección de modelo por función** (configurable): "rápido/privado" (tier 0), "mejor calidad" (tier 1 → 2), "máxima" (tier 2, modelo top). Hay **fallback automático**: `.rateLimited`, cuota de PCC agotada o sin red → bajar de tier y avisar.
- **Contabilidad:** `response.usage` por llamada → gasto estimado por proveedor y mes en Ajustes.

### 4.2 Antispoiler y privacidad (se aplican *antes* del modelo)

1. **Frontera de lectura:** `progreso_máximo` por libro (CFI → offset global), sincronizado por iCloud. Todo el material que se envía a un modelo (fragmentos, resúmenes, lista de personajes) se filtra con `offset_fin ≤ progreso_máximo`.
2. **Artefactos derivados con fecha de corte:**
   - Los resúmenes de capítulo se generan solo cuando el capítulo está leído.
   - "Story so far" = fusión de los resúmenes de capítulos leídos.
   - La lista de personajes se extrae solo de fragmentos leídos (cada personaje con "aparece por primera vez en…").
3. **Instrucción al modelo:** *"Responde SOLO con el texto proporcionado. No uses conocimiento previo de esta obra; si no está en el texto, di que aún no aparece."* Los modelos grandes de la nube **conocen los clásicos**, así que hay que añadir una comprobación barata (on-device) que marque si la respuesta menciona nombres o hechos ausentes del contexto.
4. **Qué sale del dispositivo por tier:**
   - **Tier 0:** nada.
   - **Tier 1 (PCC):** el prompt, sin almacenamiento, verificable.
   - **Tier 2/3:** el prompt al proveedor (retención de unos 30 días, sin entrenamiento).
   - **Nunca** se envía el libro entero salvo acción explícita ("preguntar al libro completo", con aviso).
   - Indicador visible en cada respuesta: 📱 dispositivo / ☁︎ Apple PCC / 🔑 proveedor.

### 4.3 Mapa de funciones → tier

| Función | Tier por defecto | Escalado | Qué sale del dispositivo (si escala) | Notas antispoiler |
|---|---|---|---|---|
| Explicar / definir / traducir selección | **0** | 1 → 2 ("ampliar") | Selección + 1–2 párrafos vecinos | Solo texto anterior y la selección |
| Auto-etiquetado | **0** | 2 (barato, batch) | Metadatos + sinopsis | — |
| Flashcards / preguntas de reflexión | **0** | 1 | Subrayado + contexto | — |
| "Tus ideas clave" (libro) | **1** | 2 | Subrayados y notas del libro | Solo subrayados (ya leídos por definición) |
| Resumen de capítulo | **1** (32K) | 0 (map-reduce, sin conexión) / 2 | Texto del capítulo **leído** | Generar al terminar el capítulo; guardar |
| "Story so far" | **0** (fusión de resúmenes guardados) | 1 | Resúmenes de capítulos leídos | Por construcción |
| Lista de personajes | **0** incremental | 1 | Fragmentos leídos | Atributos con "visto hasta cap. N" |
| Conexiones entre libros | **0** (embeddings) | 1 (para explicar la conexión) | 2 fragmentos o subrayados | Solo fragmentos ≤ progreso de cada libro |
| Digest semanal | **1** | 2 | Subrayados, notas y resúmenes de la semana | — |
| Chat con mi biblioteca (RAG) | **1** | 2 (modelo top) / 0 (preguntas acotadas) | **Solo los k fragmentos recuperados** (≤ 20–30K tokens) | Filtro SQL antes de recuperar |
| Esquema previo para lectura rápida | **0** | 1 | Encabezados y primeras frases del capítulo **siguiente** | **Excepción deliberada:** el usuario pide un adelanto del capítulo que va a leer. Limitarlo a estructura y conceptos, sin desenlaces; avisarlo en la interfaz. |

### 4.4 RAG "chatea con mi biblioteca" sin servidor

1. **Ingesta en el dispositivo** (iPhone/iPad de noche, o el Mac):
   - EPUB → texto por capítulo → fragmentos de unos 400 tokens con `libro_id`, `capítulo`, `cfi_inicio`, `cfi_fin`, `offset_ini/fin` e idioma.
   - Embedding (EmbeddingGemma 256d int8) → SQLite + sqlite-vec, con **una base por libro** (`.lectora-index`) en iCloud Drive (sincronización incremental y borrado sencillo).
   - Además, un índice FTS5 (BM25) para búsqueda híbrida: los nombres propios en español se recuperan mejor con léxico.
2. **Consulta:**
   - Embedding de la pregunta en el dispositivo.
   - **Filtro** `offset_fin ≤ progreso_máximo(libro)` (y por libros, etiquetas o fechas si el usuario acota).
   - KNN (k = 40) + BM25 → fusión RRF → *rerank* on-device con el modelo de Apple ("¿es relevante? sí/no", `@Generable`) → top 8–15.
3. **Generación:**
   - Prompt = instrucciones + fragmentos numerados `[n] (Título, cap. X)` + pregunta.
   - Va al **tier elegido** (PCC: unos 25K tokens útiles; Claude o GPT: más). Solo salen esos fragmentos.
4. **Citas:**
   - Se exige `@Generable struct Respuesta { var texto: String; var citas: [Int] }`.
   - Cada `[n]` se resuelve localmente a su CFI → toque = abrir el libro en ese punto.
   - Con Claude se pueden usar además los *citations* nativos de documentos (fuera de Foundation Models, vía API directa) ⚠️.
5. **Sin conexión:** el mismo flujo con `SystemLanguageModel` y k = 6.

### 4.5 Plan de implementación sugerido

1. **MVP (iOS 26+):**
   - Tier 0 con Foundation Models para explicar, definir, traducir, etiquetar y crear flashcards.
   - BYOK de un proveedor (Claude con `ClaudeForFoundationModels` en iOS 27, o AnyLanguageModel en iOS 26).
   - Clave en iCloud Keychain.
2. **Fase 2:**
   - Embeddings + sqlite-vec por libro.
   - RAG con filtro de progreso.
   - Resúmenes incrementales y "story so far".
   - **Solicitar el entitlement de PCC** y añadir el tier 1.
3. **Fase 3:**
   - Créditos de Claude Max (es solo una API key: documentarlo en la interfaz: "¿Tienes Claude Max? Reclama tus 100 USD/mes de API aquí").
   - Sign in with ChatGPT (Mac open-source primero).
   - Servidor MCP local en el Mac.
   - Modelo MLX opcional descargable.
4. **Pendiente de Apple:** las Extensions de iOS 27 y las cifras de cuota de PCC. Revisar en cada beta.

---

## 5. Preguntas abiertas / verificar antes de programar

- ⚠️ ¿Acceso de desarrolladores a *AFM 3 Core Advanced* (20B) y en qué dispositivos? ¿Contexto exacto del modelo del dispositivo en iOS 27 (¿8192?) y lista de idiomas?
- ⚠️ Uso de PCC en una app personal no publicada (TestFlight o ad hoc "para pruebas") y cifras de cuota diaria.
- ⚠️ ¿Admite Sign in with ChatGPT (uso del plan) clientes iOS nativos open-source? ¿Qué modelos son elegibles?
- ⚠️ Límite real de RAM por app en iPhone 17 Pro con iOS 27 (`os_proc_available_memory`), velocidad de 4B y 8B, y si Foundation Models y Core ML embeddings rinden en `BGProcessingTask`.
- ⚠️ Precio de Gemini Pro actual y de los embeddings de Gemini/OpenAI; política de BYOK y ZDR de OpenRouter.
- ⚠️ Estado de las iOS 27 Extensions (Claude/Gemini en Apple Intelligence) después de septiembre de 2026.

---

## Fuentes

**Apple**
- WWDC26, sesión 241 *What's new in the Foundation Models framework* (transcripción leída): https://developer.apple.com/videos/play/wwdc2026/241/
- WWDC26, sesión 319 (PCC): https://developer.apple.com/videos/play/wwdc2026/319/ · documentación: https://developer.apple.com/documentation/foundationmodels/adding-server-side-intelligence-with-private-cloud-compute
- Acceso a PCC (elegibilidad y cuotas): https://developer.apple.com/private-cloud-compute
- Tercera generación de AFM: https://machinelearning.apple.com/research/introducing-third-generation-of-apple-foundation-models
- Entitlement de memoria: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.kernel.increased-memory-limit · foro sobre el límite de 6 GB: https://developer.apple.com/forums/thread/834805 · iOS 27 a 8,6 GB: https://iphonesoft.fr/2026/07/20/ios-27-beta-3-modifie-plafond-ram-applications-jeux-8-6-go-disponibles
- BGContinuedProcessingTask y GPU: https://developer.apple.com/forums/thread/816774 · https://developer.apple.com/forums/thread/807957 · https://github.com/ggml-org/whisper.cpp/issues/3531
- Restricción por idioma del sistema: https://developer.apple.com/forums/thread/805378
- NLContextualEmbedding: https://developer.apple.com/documentation/naturallanguage/nlcontextualembedding
- Extensions de iOS 27: https://www.macrumors.com/2026/05/05/ios-27-third-party-chatbots-apple-intelligence/ · https://www.macrumors.com/2026/06/15/three-unannounced-ios-27-features-are-still-coming/ · https://www.macrumors.com/2026/09/14/siri-can-be-swapped-out-for-claude-chatgpt-code-shows/
- Core AI (terceros): https://9to5mac.com/2026/03/01/apple-replacing-core-ml-with-modernized-core-ai-framework-for-ios-27-at-wwdc/

**Modelos locales y embeddings**
- Benchmarks en iPhone 17 Pro: https://github.com/john-rocky/apple-silicon-llm-bench · https://rickytakkar.com/blog_russet_mlx_benchmark.html
- Qwen3.5 small: https://artificialanalysis.ai/articles/qwen3-5-small-models
- Gemma 4 en iOS (MLX): https://www.ai.engineer/talks/a2muGkT4WD4-running-gemma-4-on-device-40-tokens · https://pyimagesearch.com/2026/07/20/running-gemma-4-locally-ollama-llama-cpp-mlx-and-more/
- EmbeddingGemma Core ML: https://huggingface.co/valindotai/embeddinggemma-300m-coreml · Qwen3-Embedding Core AI: https://huggingface.co/coreai-community/Qwen3-Embedding-0.6B-CoreAI
- sqlite-vec Swift: https://github.com/Get-Pally/SQLiteVec · comparativa: https://marcobambini.substack.com/p/the-state-of-vector-search-in-sqlite
- AnyLanguageModel: https://github.com/huggingface/AnyLanguageModel · https://www.infoq.com/news/2025/11/anylanguagemodel

**Anthropic**
- Claude for Foundation Models: https://platform.claude.com/docs/en/cli-sdks-libraries/libraries/apple-foundation-models · https://github.com/anthropics/ClaudeForFoundationModels
- Créditos de API de Max/Team: https://platform.claude.com/docs/en/about-claude/api-credits-for-subscribers
- Política de OAuth y credenciales: https://code.claude.com/docs/en/legal-and-compliance · https://support.claude.com/en/articles/15036540-use-the-claude-agent-sdk-with-your-claude-plan
- Cronología de la aplicación: https://winbuzzer.com/2026/02/19/anthropic-bans-claude-subscription-oauth-in-third-party-apps-xcxwbn/ · https://falcao.org/posts/anthropic-claude-access-crackdown-ecosystem-fallout/ · https://venturebeat.com/technology/anthropic-reinstates-openclaw-and-third-party-agent-usage-on-claude-subscriptions-with-a-catch
- Privacidad y retención: https://privacy.claude.com/en/articles/7996868-is-my-data-used-for-model-training · https://platform.claude.com/docs/en/manage-claude/api-and-data-retention
- Conectores remotos: https://support.claude.com/en/articles/11503834

**OpenAI**
- Precios: https://developers.openai.com/api/docs/pricing · GPT-6 Luna: https://developers.openai.com/api/docs/models/gpt-6-luna · GPT-6.1 Sol: https://developers.openai.com/api/docs/models/gpt-6.1-sol · changelog: https://developers.openai.com/api/docs/changelog
- Sign in with ChatGPT: https://developers.openai.com/siwc · https://developers.openai.com/siwc/token-sharing-open-source · https://developers.openai.com/siwc/token-sharing-open-source/preview-limitations · https://help.openai.com/en/articles/20001542-using-your-chatgpt-plan-in-other-apps-and-sites · https://github.com/openai/sign-in-with-chatgpt-devkit
- Datos de la API: https://developers.openai.com/api/docs/guides/your-data

**Google**
- Precios: https://ai.google.dev/gemini-api/docs/pricing · Gemini 3.8 Flash: https://ai.google.dev/gemini-api/docs/models/gemini-3.8-flash
- Términos (gratis vs. de pago): https://ai.google.dev/gemini-api/terms
- Gemini en Foundation Models (Firebase): https://firebase.blog/posts/2026/06/apple-foundation-models-gemini
- Gemini CLI y terceros: https://www.geminicli.com/docs/resources/tos-privacy · https://discuss.ai.google.dev/t/gemini-subscription-access-for-third-party-apps-is-a-sanctioned-program-planned/175577 · https://gigazine.net/gsc_news/en/20260224-google-gemini-openclaw-accounts-banned

**xAI**
- Modelos y precios: https://docs.x.ai/developers/models · https://docs.x.ai/developers/pricing
- Seguridad y datos: https://docs.x.ai/developers/faq/security
- Integraciones SuperGrok no oficiales: https://cdn.jsdelivr.net/npm/pi-xai-supergrok@0.2.1/README.md · https://lobehub.com/docs/usage/providers/supergrok

**Otros**
- OpenRouter (comisiones, terceros): https://www.truefoundry.com/blog/openrouter-byok-explained-cheaper-often-faster-and-changing
- Readwise MCP: https://docs.readwise.io/tools/mcp
- MCP en ChatGPT (terceros): https://hjarni.com/blog/how-to-use-mcp-with-chatgpt
