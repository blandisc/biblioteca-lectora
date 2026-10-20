# Biblioteca Lectora: PRD v3.1 — el hub

> **Estado:** borrador para revisión · **Versión:** 3.1 · **Fecha:** 20 oct 2026 · **Alcance:** uso personal, diseñado para poder abrirse al público después.
>
> **Qué cambia en la v3.1:** la **v1 es solo iPhone (incluido el Duo) y iPad**. El Mac llega después (§5). El **iPad toma el rol de estación de administración**.
>
> **Qué cambió en la v3.0:** el producto se reorganiza como un **hub**. El núcleo es la app (biblioteca + lector + IA ligera); todo lo demás son **conectores**: nubes de almacenamiento, el bot, Readwise y los proveedores de IA. Las versiones anteriores siguen en el historial de git. Las investigaciones en [`investigacion/`](investigacion/) son el anexo técnico.

---

## 1. El producto en una frase

**Un Calibre moderno con el mejor lector del mercado:** organizas tu biblioteca y sus metadatos, tus libros viven seguros en tu nube y se descargan cuando los necesitas, tus subrayados se juntan en Readwise, y una IA sencilla te ayuda a entender y recordar lo que lees. Funciona **sin conexión** y se sincroniza al volver a tener internet. **No hay servidor.**

## 2. Modelo de hub

```
           FUENTES                        NÚCLEO (la app)                   DESTINOS
 ┌───────────────────────┐   ┌───────────────────────────────────┐   ┌──────────────────────┐
 │ ☁️ Biblioteca en       │◀─▶│ 📚 Biblioteca                      │──▶│ 🖍 Readwise           │
 │   iCloud Drive         │   │    metadatos, portadas, series,    │◀──│   hub de subrayados   │
 │                        │   │    estantes (el "Calibre")         │   │   (Kindle, Reader,    │
 │ 📥 Buzones de entrada   │──▶│                                    │   │    esta app)          │
 │   Google Drive         │   │ 📖 Lector                          │   └──────────────────────┘
 │   OneDrive             │   │    EPUB · PDF · cómics             │   ┌──────────────────────┐
 │   Archivos / Compartir │   │    iPhone Duo · lectura guiada     │──▶│ 🤖 IA en la nube      │
 │   Bot de Telegram (fut)│   │                                    │   │   (opcional: clave    │
 │   Calibre (migración)  │   │ ✨ IA ligera (en el dispositivo)    │   │    compatible OpenAI) │
 └───────────────────────┘   │                                    │   └──────────────────────┘
                             │ 💾 Copia local (offline-first)      │
                             └───────────────────────────────────┘
```

**Principios**
1. **La app no posee tus datos; los organiza.** Libros en tu nube, subrayados en Readwise, IA donde tú elijas.
2. **Offline-first.** Todo funciona sin conexión sobre una copia local; al volver a tener internet, se sincroniza.
3. **Cada conector es intercambiable** y se puede apagar. Si Readwise, una nube o un proveedor de IA desaparece, la app sigue funcionando.
4. **v1 solo en iPhone y iPad.** Ningún dispositivo es "servidor": cada uno hace lo que necesita, cuando lo necesita (§5).

## 3. Decisiones

### 3.1 Dónde vive la biblioteca: **iCloud Drive** (v1)
La biblioteca es **una carpeta visible en Archivos y Finder** (`iCloud Drive/Biblioteca Lectora/`):

```
Biblioteca Lectora/
  Libros/Autor/Título.epub        ← tus archivos, tal cual (también .pdf, .cbz…)
  .lectora/
    registro/iphone-7F3A.jsonl    ← cada dispositivo escribe SOLO su propio registro de cambios
    registro/mac-19C2.jsonl
    instantaneas/2026-10-20.json  ← resumen periódico para arrancar rápido
    portadas/{uuid}.jpg
    derivados/                    ← índices, OCR, miniaturas (se pueden regenerar)
```

- **Descarga bajo demanda gratis:** iCloud muestra los libros "en la nube" y el sistema los baja al abrirlos. La app puede liberar espacio en el iPhone sin borrarlos de la nube.
- **Sin corrupción:** nunca hay una base de datos dentro de la nube. Cada dispositivo escribe solo su propio registro (JSONL) y lee los de los demás. La base local (SQLite) es una **vista** que se reconstruye combinando los registros. Es el mismo principio de Git y Obsidian.
- **Conflictos:** gana el cambio más reciente por campo (con relojes híbridos); los subrayados se combinan por UUID y los borrados se marcan (tombstones). Nunca se pierde un subrayado.
- **Si borras la app,** tu biblioteca sigue en tu iCloud como carpetas normales, y Calibre o cualquier lector puede abrirla.

**Google Drive y OneDrive en la v1 son "buzones" y fuentes de importación:** conectas tu cuenta, eliges una carpeta, y todo lo que caiga ahí se importa a la biblioteca. El bot de Telegram, cuando lo construyamos, dejará los libros en ese buzón: así no necesita hablar con la app.
**En la v2:** Google Drive y OneDrive también como **ubicación de la biblioteca** (mismo formato de carpetas y registros), para usuarios fuera de Apple o para la web.

| Limitación conocida | Mitigación |
|---|---|
| La web no puede leer iCloud Drive | La web queda para la última fase. Opciones: espejo en CloudKit o biblioteca en Google Drive (v2) |
| Google Drive en modo "prueba" pide reautorizar cada 7 días | Solo afecta al buzón; publicar la app requiere la auditoría de Google (fase pública) |
| Espacio en iCloud | Es tu cuenta; la app muestra cuánto ocupa la biblioteca |

### 3.2 Readwise como hub de subrayados *[06]*
- **La app guarda una copia ligera** de cada subrayado: texto, posición exacta, nota y color. Así funciona sin conexión y sabe dónde pintarlo.
- **Readwise es el hub:** todo subrayado de la app se envía (API v2, con un enlace que vuelve al pasaje). De Readwise se traen los **subrayados de Kindle** (anclados dentro de tus EPUB por ASIN, título y cita), los de **Reader** y las ediciones que hagas allá.
- **Reader:** importar los EPUB y PDF originales que tengas ahí, subrayados en ambos sentidos para libros vinculados y progreso de Reader hacia la app.
- Si dejas Readwise, no pierdes nada: la copia local se exporta a Markdown o JSON.

### 3.3 IA: dispositivo primero, cualquier proveedor compatible con OpenAI después *[07]*

| Nivel | Qué | Costo | Para qué |
|---|---|---|---|
| **Dispositivo** (predeterminado) | Modelo de Apple en el iPhone y el iPad | Gratis, nada sale del dispositivo | Definir, explicar, traducir, etiquetar, flashcards, preguntas de reflexión, pre-lectura |
| **Nube (opcional)** | **Un conector "compatible con OpenAI"**: pegas una URL y una clave | Centavos al mes | Resúmenes de capítulo, "lo que va hasta aquí", digest semanal, "tus ideas clave", preguntas a tu biblioteca |

**Configuración recomendada: DeepSeek V4 Flash vía OpenRouter**, con estas preferencias en cada petición:

```json
"provider": { "data_collection": "deny", "zdr": true, "ignore": ["deepseek"] }
```

- **Por qué no la API de DeepSeek directa:** según análisis de terceros, guarda los datos **en China** y no deja claro si entrena con ellos.
- **Por qué sí el modelo:** DeepSeek **publicó los pesos de V4 Flash con licencia MIT** en Hugging Face (build 0731; según una fuente, V4.1 Flash del 17 oct también ⚠️). Por eso lo sirven otros proveedores fuera de China: OpenRouter lista unos 12 para V4.1 Flash.
- `data_collection: "deny"` usa solo proveedores que **no guardan ni entrenan** con tus datos.
- `zdr: true` exige **cero retención**.
- `ignore: ["deepseek"]` excluye el servidor de DeepSeek.
- Si ningún proveedor cumple, la petición **falla en lugar de mandarte a uno que no cumple**, y la app usa el modelo del dispositivo.
- **Costo:** en OpenRouter, V4 Flash aparece entre ~0.01 y 0.14 USD por millón de tokens de entrada, según la versión y la fuente ⚠️. Para un lector intenso: **centavos a menos de 1 USD al mes**. Se apaga el modo "pensar" para no pagar tokens de razonamiento.
- **Agnóstico:** el mismo conector sirve para OpenAI, Groq, Together o un Ollama propio. Claude y Gemini entran con su propio conector cuando se quiera.
- **Reglas fijas:** nunca se envía texto posterior a tu posición más lejana (antispoiler); solo salen los fragmentos necesarios; un ícono en cada respuesta indica dónde se procesó (📱 o ☁︎); tus **notas personales** se pueden excluir del envío.

### 3.4 Lector: motor por formato *[03, 04]*
| Formato | Motor |
|---|---|
| EPUB, MOBI, AZW3, FB2 | foliate-js en WKWebView (fork fijado), con interfaz y gestos 100 % nativos en SwiftUI |
| PDF | PDFKit nativo, subrayados en una capa propia |
| Cómics (CBZ, CBR, CB7, CBT) | Lector nativo en Swift con libarchive; `ComicInfo.xml` para manga y dobles páginas |

### 3.5 Una sola app SwiftUI para iPhone y iPad (Mac después)
Mismo código y misma biblioteca. El iPhone y el Duo son para leer; el **iPad** también es la estación de administración (§5). El código se escribe multiplataforma desde el día uno (sin APIs exclusivas de iOS en el núcleo), así que agregar el Mac nativo después es sobre todo trabajo de interfaz.

## 4. Experiencia: la UI como hub
- **Inicio:** "Seguir leyendo", llegadas recientes (del buzón o de Reader), subrayados destacados de la semana.
- **Biblioteca:** cuadrícula o lista, series, autores, estantes inteligentes, filtros. Cada libro muestra su estado: ☁️ en la nube, ⬇️ descargado, 📖 leyendo.
- **Conexiones:** una pantalla con el estado de cada conector: iCloud ✅ sincronizado hace 2 min · Readwise ✅ 3 subrayados pendientes · Buzón de Drive ✅ · IA: dispositivo + OpenRouter. Aquí se conectan y desconectan.
- **Sin conexión:** todo funciona. Un indicador discreto muestra los cambios pendientes, que se envían solos al reconectar.

## 5. Plataformas en la v1: iPhone e iPad

**Regla:** ningún dispositivo es requisito ni hace de servidor. Cada uno trabaja sobre su copia local y sincroniza por iCloud Drive.

| Rol | iPhone / iPhone Duo | iPad |
|---|---|---|
| **Leer** | ✅ Experiencia principal; Duo con doble página y poses | ✅ Doble página en horizontal, Split View, modo estudio (libro + notas) |
| **Administrar la biblioteca** | Edición libro por libro, metadatos automáticos | ✅ **Estación de administración:** vista de tabla con columnas (en ancho regular), **selección múltiple y edición masiva**, editor de portadas, duplicados. Con teclado y trackpad se siente como un Calibre de escritorio |
| **Migrar desde Calibre** | Posible, pero incómodo | ✅ Recomendado. Abres la carpeta de Calibre desde Archivos (Google Drive aparece ahí con su app) y la app lee `metadata.db` en solo lectura. 1,000–2,000 libros se importan por lotes y se pueden reanudar; las tareas largas siguen en segundo plano con `BGContinuedProcessingTask` (iOS 26) |
| **Trabajo pesado** (OCR, índices, metadatos masivos) | Bajo demanda: solo el libro que abres; lo demás de noche y cargando | Igual, con más memoria y batería. Los resultados se comparten vía `.lectora/derivados/` para no repetirlos |
| **Respaldo** | — | Exportar la biblioteca a Google Drive u OneDrive desde la app (manual o al abrirla, si hace días que no se respalda) |

**Coordinación sin servidor:** los trabajos pesados se anotan en el registro compartido. Un dispositivo "toma" un trabajo (lo marca con su nombre y hora) y, si no lo termina en un tiempo razonable, otro lo retoma.

### 5.1 El Mac, más adelante
- **Puente gratis mientras tanto:** la app de iPad corre en los Mac con Apple Silicon ("Designed for iPad") vía TestFlight, sin trabajo extra. Sirve para leer y administrar en pantalla grande antes de tener la versión nativa.
- **Mac nativo (fase posterior):** tabla tipo Calibre completa con columnas configurables y reglas de normalización, importación masiva arrastrando carpetas, trabajo pesado mientras está encendido (OCR, índice semántico de toda la biblioteca, resúmenes por lote), respaldo programado, y un servidor MCP local para que Claude Desktop consulte tu biblioteca.

## 6. Catálogo de funcionalidades

**P0** = MVP · **P1** = v1 completa · **P2** = después · **P3** = algún día. El detalle de cada función está en *[03 §2]* y *[05 §5]*.

### 6.1 Biblioteca (el "Calibre")
| Función | P |
|---|---|
| Migración desde Calibre (iPad, recomendado): metadatos, portadas, series, etiquetas, identificadores, anotaciones; pantalla de revisión | P0 |
| Importar: Compartir y Archivos, arrastrar en iPad (Split View), **buzones en Google Drive y OneDrive** | P0 / P1 |
| Catálogo: autores, series con número, etiquetas, idioma, ISBN, ASIN, valoración, estado de lectura | P0 |
| **Tabla de administración en el iPad** con selección múltiple y edición masiva | P0 |
| Metadatos y portadas automáticos (Open Library, Google Books, Hardcover) con fusión y elección manual | P0 |
| Descarga bajo demanda y liberar espacio por dispositivo | P0 |
| Búsqueda con sintaxis (`autor:x serie:y`) y estantes inteligentes | P1 |
| Duplicados, editor de portadas, reglas de normalización | P1 |
| Exportar la biblioteca y respaldo a Google Drive u OneDrive | P1 |
| Biblioteca en Google Drive u OneDrive (además de iCloud) | P2 |

### 6.2 Lector
| Función | P |
|---|---|
| EPUB: paginado interrumpible a 120 Hz + scroll, tipografía con guiones en español e inglés, fuentes y temas, notas al pie en popover, TOC, búsqueda, "te faltan N min" | P0 |
| PDF con PDFKit: zoom, selección, subrayado | P0 |
| **iPhone Duo:** doble página al desplegar, conservando la frase | P0 |
| Diccionario, traducción en el dispositivo, Wikipedia | P0 / P1 |
| Duo: pose libro, pose mesa, modo estudio | P1 |
| **Lectura guiada:** marcador por línea, foco por frase, lectura con voz | P1 |
| Cómics y manga (de derecha a izquierda, dobles páginas sobre la bisagra) | P1 |
| TTS con voces del sistema | P1 |
| OCR de PDFs escaneados, recorte de márgenes | P1 |
| RSVP, pre-lectura con IA, webtoon, page curl, scroll entre capítulos | P2 |

### 6.3 Subrayados y Readwise
| Función | P |
|---|---|
| Subrayado instantáneo, colores, notas, etiquetas, panel filtrable | P0 |
| Envío a Readwise con enlace de vuelta al pasaje | P0 |
| **Subrayados de Kindle (vía Readwise) anclados dentro de tus EPUB** | P0 |
| Export ilimitado a Markdown y JSON | P0 |
| Reader: importar originales, subrayados en ambos sentidos, progreso | P1 |
| Daily Review de Readwise en la app y en el widget | P2 |
| Quote cards como imagen | P2 |

### 6.4 IA
| Función | Dónde | P |
|---|---|---|
| Definir, explicar, traducir una selección | 📱 | P1 |
| Etiquetado automático, flashcards, pregunta de reflexión | 📱 | P1 |
| "Tus ideas clave" al terminar un libro | 📱 / ☁︎ | P1 |
| Resumen de capítulo y "lo que va hasta aquí" (sin spoilers) | ☁︎ (📱 por partes, lento) | P1 |
| Conector compatible con OpenAI (OpenRouter, DeepSeek, OpenAI, Groq, Ollama) con preferencias de privacidad | Ajustes | P1 |
| "Esto conecta con…": subrayados relacionados entre libros (índice semántico local) | 📱 | P2 |
| Digest semanal | ☁︎ | P2 |
| Preguntarle a tu biblioteca, con citas clicables | Índice 📱 + ☁︎ | P2 |
| Personajes sin spoilers, mapa de argumentos | ☁︎ | P3 |

### 6.5 Plataforma
| Función | P |
|---|---|
| Sincronización offline-first con registros por dispositivo; conflictos visibles ("vas más adelante en el iPad, ¿saltar?") | P0 |
| Pantalla de Conexiones con el estado de cada conector | P0 |
| Accesibilidad: VoiceOver, Dynamic Type, Reduce Motion, fuentes para dislexia | P0 |
| Estadísticas: tiempo, racha, velocidad (incluida la de la lectura guiada) | P1 |
| iPad: varias ventanas, atajos de teclado, trackpad | P1 |
| Mac ("Designed for iPad" como puente; nativo después) | P2 / P3 |
| Widgets, App Intents, Siri | P2 |
| Web de solo lectura | P3 |
| **Bot de Telegram** (deja libros en el buzón) | Diferido |

## 7. Análisis crítico: qué es viable y qué no

| Pieza | Veredicto | Comentario |
|---|---|---|
| Lector + metadatos | ✅ Viable | El riesgo es de **calidad**: que se sienta premium. Se prueba primero (S1) |
| Biblioteca en iCloud Drive + descarga bajo demanda | ✅ Viable | El sistema operativo hace la parte difícil |
| **Sync offline-first sobre una nube de archivos** | ⚠️ Viable, pero **es la pieza más difícil** | Registros por dispositivo + vista local. Requiere diseño cuidadoso y pruebas intensivas (S3). Un error aquí pierde datos |
| Readwise como hub | ✅ Viable | Con copia local. La API de Reader es reciente (subrayados desde sep 2026) y puede cambiar |
| Subrayados de Kindle dentro de tus EPUB | ⚠️ Viable con margen de error | El emparejamiento por cita puede fallar con ediciones distintas; se muestran como "sin anclar" en lugar de perderse |
| IA en el dispositivo + DeepSeek vía OpenRouter | ✅ Viable y barato | Verificar precios y proveedores antes de fijarlos |
| Agnóstico de nube | ⚠️ Viable por etapas | Cada nube es una integración aparte: iCloud primero; Drive y OneDrive como buzón en la v1 y como biblioteca en la v2 |
| Web | ⚠️ Difícil sin servidor | Al final, de solo lectura |
| Administración tipo Calibre en iPad | ✅ Viable | SwiftUI `Table` y selección múltiple funcionan en iPad con ancho regular; es menos potente que una tabla de Mac, suficiente para la v1 |
| Migrar 2,000 libros desde el iPad | ⚠️ Viable | Depende de que la app de Google Drive entregue los archivos por Archivos; por lotes y reanudable |
| Competencia | ⚠️ | Readest ya cubre parte. La diferencia: gestión de biblioteca real, Duo, lectura guiada, Readwise como hub |

## 8. Fases

**Fase 0: Pruebas técnicas (2–3 semanas)**
- S1 · Lector: foliate-js en SwiftUI con gestos nativos, guiones en español, VoiceOver, libro de 1,000 páginas. *Salida:* se siente como Apple Books en un test a ciegas contigo.
- S2 · PDF: PDFKit con 500 páginas y 300 subrayados.
- S3 · **Sync:** registros JSONL en iCloud Drive con 3 dispositivos, sin conexión, con conflictos; 2,000 libros y 10,000 subrayados; prueba de "nunca pierde un subrayado".
- S4 · Calibre en iPad: abrir tu biblioteca desde Archivos (Google Drive), leer `metadata.db` e importar 100 libros por lotes.
- S5 · Readwise y Reader: las 9 pruebas con tu token, incluido el emparejamiento de Kindle.
- S6 · IA: modelo de Apple en español + OpenRouter con `zdr` y `data_collection: deny`.

**Fase 1: MVP (8–10 semanas):** P0 de biblioteca, lector, subrayados y plataforma, en **iPhone y iPad**. *Salida:* dejas de usar Calibre, Apple Books y Kindle para tus libros.

**Fase 2: Diferenciadores (6–8 semanas):** lectura guiada, Duo completo, cómics, Reader, IA P1, buzones de Google Drive y OneDrive.

**Fase 3:** IA P2 (conexiones, digest, preguntas a tu biblioteca) y estadísticas.

**Fase 4:** **Mac nativo**, bot de Telegram (vía buzón), Google Drive y OneDrive como biblioteca, web.

**Fase 5 (opcional):** versión pública.

## 9. Preguntas abiertas
1. ¿Tus libros de Calibre tienen el **ASIN** de Amazon? Facilita anclar los subrayados de Kindle.
2. ¿Cuántos son **PDF y cómics**? Define cuánto pesa la prioridad de OCR y cómics.
3. ¿Usas la Daily Review de Readwise? Define si la app tiene repaso propio.
4. Nombre del producto ("Biblioteca Lectora" es provisional).

---
**Fuentes nuevas de esta versión:**
- [DeepSeek-V4-Flash en Hugging Face (licencia MIT)](https://huggingface.co/deepseek-ai/DeepSeek-V4-Flash) · [Release 0731](https://huggingface.co/blog/ResterChed/deepseek-v4-flash-official-release) · [V4 Flash vision weights, MIT](https://www.digitalapplied.com/blog/deepseek-v4-flash-vision-weights-mit) · [V4.1-Flash-1017 (Tech Insider)](https://tech-insider.org/deepseek-v4-1-flash-1017-mit-license-update-2026/)
- [OpenRouter: V4 Flash 0731](https://openrouter.ai/deepseek/deepseek-v4-flash-0731) · [OpenRouter: V4.1 Flash 1017](https://openrouter.ai/deepseek/deepseek-v4.1-flash-1017) · [OpenRouter ProviderPreferences (`data_collection`, `zdr`)](https://openrouter.ai/docs/agent-sdk/typescript/models/providerpreferences) · [Pydantic AI: OpenRouter (`only`, `ignore`)](https://pydantic.dev/docs/ai/api/models/openrouter/)
- [Privacidad de DeepSeek en 2026](https://deepseekai.guide/guides/deepseek-privacy/) · [Is DeepSeek safe for business data](https://sagnikbhattacharya.com/blog/is-deepseek-safe-business-data)

**Investigaciones (anexo técnico):** [01 Calibre](investigacion/01-calibre.md) · [02 Servidores de biblioteca](investigacion/02-servidores-biblioteca.md) · [03 Lectores](investigacion/03-lectores.md) · [04 PDF y cómics](investigacion/04-pdf-y-comics.md) · [05 IA e insights](investigacion/05-ia-e-insights.md) · [06 Reader y Readwise](investigacion/06-readwise-reader.md) · [07 IA en dispositivo y nube](investigacion/07-ia-dispositivo-y-nube.md)
