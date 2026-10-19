# Biblioteca Lectora: visión de producto (v0.1)

> Documento de trabajo. Fecha: octubre 2026. Las suposiciones están marcadas con **[Supuesto]** y las preguntas abiertas están al final.

## 1. La tesis en una frase

**Tu biblioteca, tu servidor y tu cerebro en un solo lector.** Calibre te da control pero tiene mala experiencia de lectura. Kindle y Apple Books leen bien pero te encierran. Readwise saca valor de tus subrayados pero no gestiona libros. Nadie junta las tres cosas, y ese hueco es el producto.

## 2. Panorama del mercado

| Producto | En qué gana | En qué falla (tu oportunidad) |
|---|---|---|
| **Calibre / calibre-web** | Metadatos, conversión, control total | La experiencia de lectura es fea, no tiene app nativa buena y no saca insights |
| **Kindle** | Tipografía, sincronización, ecosistema | Cerrado, DRM, mal con tus EPUB, los subrayados quedan atrapados |
| **Apple Books** | Pulido nativo | Gestión de biblioteca pobre, sin API, sin insights |
| **Readwise Reader** | Subrayados, repaso espaciado, IA | Pensado para artículos. Lo de "biblioteca de libros" es secundario y no es tu servidor |
| **KOReader / Moon+ / Yomu / Readest** | Lectores potentes y abiertos | Interfaz técnica o sin capa de conocimiento |
| **Thorium (Readium)** | Estándares, accesibilidad | Solo escritorio, experiencia genérica |

**Conclusión:** la diferencia no estará en "otro lector EPUB". Estará en el **ciclo completo**: conseguir el libro (bot), leerlo (lector excelente), subrayar, que el modelo te devuelva algo (insights) y que eso se quede en tu sistema (Readwise / servidor).

## 3. Usuario objetivo

**Primario (v1): tú.** Un lector intenso y técnico, con un servidor propio y un bot de Telegram, que lee en iPhone y Mac y quiere ser dueño de sus datos.

**Secundario (si después se vuelve producto):** lectores de no ficción que ya pagan Readwise, usuarios de Calibre que odian su interfaz y la comunidad self-hosted (r/selfhosted, usuarios de calibre-web, Kavita o Audiobookshelf).

> Recomendación: **construye primero para ti (single-user, self-hosted)**. Es más rápido, evita problemas legales y de App Store (ver §9) y te da un producto real que luego puedes abrir.

## 4. Arquitectura conceptual

```
┌──────────── Clientes ────────────┐
│  iPhone / iPhone plegable        │
│  iPad · Mac · Web                │
└───────────────┬──────────────────┘
                │ API propia (REST/GraphQL + sync)
┌───────────────▼──────────────────┐        ┌──────────────┐
│     TU SERVIDOR (fuente de verdad)│◄──────►│ Bot Telegram │
│  · Archivos (EPUB/PDF)           │ misma  └──────────────┘
│  · Metadatos (Calibre DB/OPDS)   │ API / cola de trabajos
│  · Subrayados + progreso         │
│  · LLM local (Ollama) + vectores │
└───────────────┬──────────────────┘
                │ push de subrayados (v2 API)
         ┌──────▼──────┐
         │  Readwise   │  ← destino de conocimiento, no backend
         └─────────────┘
```

### Decisión clave: Readwise **no** debe ser el backend

Readwise es un servicio de **subrayados y repaso**. Su API pública sirve para exportar e importar subrayados (endpoint `v2/export` con paginación) y para manejar documentos de Reader, con límites de unos 20 req/min **[verificar en la documentación oficial]**. No está hecha para guardar y servir tu biblioteca de archivos, ni para metadatos estilo Calibre, ni para sincronizar la posición de lectura en tiempo real.

**Rol correcto:** Readwise funciona como **integración de primera clase**. Cada subrayado se envía a Readwise para que aparezca en tu Daily Review, y de forma opcional se importan los subrayados que ya tienes allí. Si Readwise cambia precios o API, tu app sigue funcionando.

### El bot de Telegram como "otro cliente"

El bot y la app no deben hablar entre sí. Los dos hablan con **el mismo servidor**:

- En Telegram escribes `/libro Sapiens`. El servidor descarga el libro, normaliza metadatos y lo agrega a la biblioteca. La app recibe un push: *"Sapiens está listo"* y lo descarga para leer sin conexión.
- En la app buscas un libro que no tienes y tocas "Conseguir". Se dispara **el mismo trabajo** que usa el bot.
- Desde el bot: `/progreso`, `/insights semana` o "mándame mis subrayados de X".

Eso implica refactorizar la lógica del bot a un **servicio o cola de trabajos** (por ejemplo `jobs/fetch_book`) que ambos invoquen.

## 5. Pilares de la experiencia ("inigualable")

### 5.1 Lectura que se siente premium
- Tipografía de verdad: separación silábica en español, justificado con buen espaciado, ligaduras, interlineado ajustable y fuentes curadas (Literata, Charter, Iowan, Atkinson para accesibilidad).
- Paso de página con física convincente, sin lag y con modo scroll continuo.
- Temas con intención: papel, sepia y noche OLED real, además de un modo "luz de vela" con temperatura cálida.
- Cero interfaz mientras lees: un toque muestra todo y otro lo esconde.

### 5.2 Diseño para el iPhone plegable **[Supuesto: "iPhone Duo" = el iPhone plegable]**
Los rumores apuntan a unas **5.3–5.5″ cerrado y unas 7.6–7.8″ abierto**. Hay que confirmarlo con las especificaciones oficiales de Apple.
- **Cerrado:** una columna, pensado para leer con una mano.
- **Abierto:** **doble página real**, como un libro físico. O bien un modo "estudio": libro a la izquierda y subrayados con insights a la derecha.
- **Continuidad:** al abrir o cerrar el teléfono no se pierde ni una línea de la posición.
- La misma lógica adaptativa sirve para iPad y Mac con ventanas redimensionables. Se diseña una vez con *size classes* y layouts adaptativos.

### 5.3 Biblioteca estilo Calibre, pero bonita
- Metadatos automáticos (Open Library, Google Books, ISBN) con portadas en alta resolución, corrección manual y edición por lotes.
- Series, autores, etiquetas, estanterías inteligentes ("no ficción sin terminar", "agregados por el bot este mes").
- Deduplicación y elección del mejor formato.
- Compatibilidad con tu biblioteca Calibre existente (leer `metadata.db` u OPDS) para no migrar a mano.

### 5.4 Subrayar y pensar (el diferenciador)
Al subrayar, el modelo local puede ofrecer:
| Momento | Insight |
|---|---|
| Al subrayar | "Explícame esto", "dame contexto", "¿qué contradice esta idea?" |
| Al terminar el capítulo | Resumen basado **en tus subrayados**, no en todo el texto |
| Entre libros | "Esta idea conecta con lo que subrayaste en *Pensar rápido, pensar despacio*" (búsqueda semántica sobre embeddings) |
| Semanal | Digest: temas recurrentes en lo que lees y preguntas para reflexionar |
| Repaso | Tarjetas generadas a partir de subrayados, que se sincronizan con Readwise |

**El modelo local, en dos niveles:**
1. **En el dispositivo** (Apple Foundation Models, disponible desde iOS/macOS 26 en equipos con Apple Intelligence): explicaciones rápidas, privadas, sin conexión y sin costo.
2. **En tu servidor** (Ollama u otro modelo de pesos abiertos): embeddings de toda tu biblioteca, conexiones entre libros y digests. La web usa este nivel.

## 6. Plataformas y stack recomendado

| Opción | Pros | Contras |
|---|---|---|
| **A. Nativo Apple (SwiftUI) + web aparte** ✅ | Mejor experiencia posible, acceso a Foundation Models, layouts del plegable y widgets | Dos bases de código de UI |
| B. React Native / Expo | Un solo código | El motor de lectura y la tipografía fina pelean con el framework; se siente "app web" |
| C. Flutter (+ flutter_readium) | Un solo código, hay wrapper de Readium | Menos nativo en Apple; Foundation Models vía puente |

**Recomendación: opción A.** El objetivo es "experiencia inigualable", y eso en Apple significa nativo.
- **iOS/iPadOS:** SwiftUI + **Readium Swift Toolkit** (EPUB, PDF, OPDS).
- **Mac:** Readium Swift no da soporte nativo a macOS, así que se usa **Mac Catalyst** o "Designed for iPad" en Apple Silicon. Una alternativa es renderizar con WebKit y un motor JS compartido.
- **Web:** TypeScript + Readium Web (`@readium/navigator`) o **foliate-js**. La web se trata como **compañera** (leer, gestionar biblioteca, ver insights), no como la experiencia principal.
- **Servidor:** una API propia (Python/FastAPI encaja si tu bot ya está en Python) + Postgres con pgvector + Ollama + almacenamiento de archivos. Calibre puede quedar detrás para conversión y metadatos.

## 7. MVP y fases

**Fase 0: Fundación (2–3 semanas)**
- API del servidor: listar libros, descargar archivo, metadatos, guardar progreso y subrayados.
- Refactor del bot a un servicio de trabajos compartido.

**Fase 1: "Lo uso todos los días" (iOS)**
- Biblioteca sincronizada con el servidor, lectura sin conexión, lector EPUB con buena tipografía.
- Subrayados y notas sincronizados con el servidor y enviados a Readwise.
- Push al llegar un libro desde Telegram.

**Fase 2: Inteligencia**
- "Explícame esto" con el modelo en el dispositivo.
- Embeddings y conexiones entre libros en el servidor; digest semanal (en la app y por Telegram).

**Fase 3: Experiencia plegable + Mac + Web**
- Doble página y modo estudio; Mac por Catalyst; web compañera.

**Fase 4 (opcional): Producto público**
- Multiusuario, onboarding "conecta tu servidor / tu Calibre", modelo de precios.

**Métricas que importan (aunque seas el único usuario):** minutos leídos por semana, libros terminados, subrayados por libro y **% de subrayados que vuelves a ver** (la verdadera prueba del valor de los insights).

## 8. Funciones "wow" para considerar
- **Conversa con el libro**, con citas que llevan a la página exacta.
- **Mapa de ideas** de tu biblioteca: un grafo con los temas que más subrayas.
- **Lectura híbrida**: TTS de alta calidad que continúa donde te quedaste, por ejemplo al subirte al coche.
- **Widget / Live Activity**: progreso del libro actual y "la cita de hoy".
- **Atajos y App Intents**: "Siri, ¿qué subrayé ayer?"

## 9. Riesgos

| Riesgo | Mitigación |
|---|---|
| **Legal / App Store:** si el bot descarga libros de fuentes sin licencia, Apple rechazará una app pública que lo integre | Para uso personal: distribuye por TestFlight o build propio. Para producto público: plantéalo como "trae tu propia biblioteca" (OPDS, Calibre, archivos propios) y deja la descarga fuera de la app |
| Dependencia de Readwise | Usarlo solo como destino; la fuente de verdad es tu servidor |
| El motor de lectura consume todo el tiempo | Usar Readium/foliate en lugar de escribir un motor desde cero |
| Foundation Models: idiomas y dispositivos limitados | El servidor sirve como respaldo; español ya está soportado |
| Alcance excesivo | Fases estrictas; el MVP es solo iOS + servidor |

## 10. Preguntas abiertas (necesito tus respuestas)
1. **¿Qué corre hoy en tu servidor?** ¿Calibre, calibre-web, una carpeta de EPUB? ¿En qué lenguaje está el bot?
2. **"iPhone Duo"**: ¿te refieres al iPhone plegable o a otra cosa (por ejemplo, tener dos dispositivos a la vez)?
3. **¿Uso personal o producto para el mercado?** Esto cambia el tema legal, multiusuario y precios.
4. **¿Qué modelo local tienes en mente?** ¿Ya usas Ollama u otro en el servidor? ¿Qué GPU o RAM tiene?
5. **Formatos:** ¿solo EPUB, o también PDF, cómics (CBZ) y artículos web?
6. **¿Lees más en español, inglés o ambos?** Influye en la separación silábica y en el modelo.

---
Fuentes: [Readium Projects](https://readium.org/development/projects) · [flutter_readium (nota sobre macOS)](https://github.com/Notalib/flutter_readium) · [Apple Foundation Models (9to5Mac)](https://9to5mac.com/2025/09/29/apple-intelligence-ios-26-models-developers/) · [iPhone Fold: rumores (AppleInsider)](https://appleinsider.com/articles/26/04/24/iphone-fold-or-iphone-ultra-what-to-expect-from-the-folding-iphone) · [Readwise MCP (referencia de la API)](https://github.com/arnaldo-delisio/readwise-mcp-enhanced)
