# Biblioteca Lectora: visión de producto (v0.2)

> Documento de trabajo, octubre 2026.
> ⚠️ **Actualizado por [`PRD.md`](PRD.md)** tras la investigación profunda. Hay dos correcciones importantes. (1) §3.1: `calibredb` no puede correr junto al `calibre-server`, así que todas las escrituras pasan por el servidor (PRD D2). (2) §4: foliate-js queda solo para EPUB; PDF usa PDFKit/pdf.js y los cómics, un lector nativo (PRD D4).
>
> **Cambios desde v0.1:** se confirman el contexto (Calibre + Google Drive, uso personal, iPhone Pro), la investigación de las guías oficiales del iPhone Duo, el soporte nativo para macOS y la decisión del motor de lectura.

## 0. Contexto confirmado

| Tema | Respuesta |
|---|---|
| Biblioteca actual | **Calibre**, con la biblioteca en Google Drive para no perder libros |
| Dispositivo principal | iPhone Pro de última generación (compatible con Apple Intelligence) |
| Plataformas | **iPhone, iPhone Duo, iPad, macOS nativo y web** |
| Alcance | **Uso personal** ahora; más adelante, versión pública quitando módulos |

## 1. La tesis en una frase

**Tu biblioteca, tu servidor y tu cerebro en un solo lector.** Calibre te da control pero tiene mala experiencia de lectura. Kindle y Apple Books leen bien pero te encierran. Readwise saca valor de los subrayados pero no gestiona libros. Nadie cubre el ciclo completo: conseguir el libro (bot), leerlo, subrayar, recibir insights y que todo se quede en tu sistema.

## 2. Panorama del mercado

| Producto | En qué gana | En qué falla (tu oportunidad) |
|---|---|---|
| **Calibre / calibre-web** | Metadatos, conversión, control total | Lectura fea, sin app nativa buena, sin insights |
| **Kindle** | Tipografía, sincronización | Cerrado, DRM, los subrayados quedan atrapados |
| **Apple Books** | Pulido nativo | Gestión de biblioteca pobre, sin API, sin insights |
| **Readwise Reader** | Subrayados, repaso, IA | Pensado para artículos; no es tu servidor |
| **Readest / KOReader / Yomu** | Lectores abiertos y potentes | Sin capa de conocimiento personal ni integración con tu bot |

## 3. Arquitectura

```
┌────────────────────────── Clientes ───────────────────────────┐
│  App Apple (SwiftUI multiplataforma)          Web (TypeScript)│
│  iPhone · iPhone Duo · iPad · Mac nativo                      │
│        └──── Motor de lectura compartido (foliate-js) ────┘   │
└───────────────────────────────┬───────────────────────────────┘
                                │ API propia + sincronización
┌───────────────────────────────▼───────────────────────────────┐
│                     TU SERVIDOR (fuente de verdad)            │
│  API (FastAPI)  ◄──────────────►  Bot de Telegram             │
│     │                cola de trabajos compartida              │
│     ├─ Adaptador Calibre (calibredb / content server)         │
│     ├─ Postgres + pgvector: subrayados, progreso, embeddings  │
│     └─ LLM local (Ollama)                                     │
└──────┬─────────────────────────────────────────┬──────────────┘
       │ respaldo programado (rclone, 1 vía)     │ push de subrayados
  ┌────▼─────────┐                         ┌─────▼────┐
  │ Google Drive │                         │ Readwise │
  └──────────────┘                         └──────────┘
```

### 3.1 Calibre + Google Drive: cambiar de "sincronizar" a "respaldar"
**Riesgo real:** tener la biblioteca *viva* de Calibre dentro de una carpeta sincronizada con Drive es una causa conocida de corrupción. Hay reportes de que Drive renombra carpetas, que choca con Calibre mientras escribe en `metadata.db` y que da errores de "archivo no sincronizable" al editar metadatos.

**Recomendación:**
- La biblioteca de Calibre vive en **disco local del servidor**.
- Un respaldo programado de **una sola vía** (`rclone sync` o `rclone copy` a Drive, por ejemplo cada noche y con versionado) mantiene tu seguridad sin el riesgo de corrupción.
- La app **nunca escribe directo** en `metadata.db`. Las lecturas se hacen por el content server de Calibre o leyendo la base en modo solo lectura. Las escrituras de metadatos pasan por `calibredb`, que respeta los bloqueos de Calibre.
- Los subrayados, el progreso y los embeddings van en **una base propia** (Postgres) y se ligan al libro por el ID de Calibre más un hash del archivo. Calibre sigue siendo el catálogo; tu base es la memoria.

### 3.2 Readwise: destino, no backend
Su API sirve para subrayados y repaso, no para servir archivos ni metadatos. Cada subrayado se envía a Readwise para tu Daily Review; si Readwise cambia, tu app sigue funcionando.

### 3.3 El bot de Telegram como otro cliente
La lógica del bot se pasa a un **servicio de trabajos compartido** (`fetch_book`, `import_to_calibre`, `notify`). El bot y la app lo invocan igual. Los flujos quedan así:
- `/libro X` en Telegram → el libro entra a Calibre y la app recibe un push: "listo para leer".
- "Conseguir" en la app → se dispara el mismo trabajo.
- Desde el bot se puede pedir el digest semanal de insights o "mándame mis subrayados de X".

## 4. Decisión técnica central: un solo motor de lectura para las 4 plataformas

Hallazgo: **Readium Swift no soporta macOS nativo** (solo iOS/iPadOS; para Mac habría que usar Catalyst o "Designed for iPad"). Como quieres **Mac nativo + web**, tener dos motores (Readium en Apple y otro en web) implica dos paginaciones distintas y **anclas de subrayados que no coinciden** entre plataformas.

**Recomendación: shell nativo + motor compartido**
- **Shell 100 % nativo en SwiftUI** (un target multiplataforma para iOS, iPadOS y macOS reales, no Catalyst): biblioteca, navegación, ajustes, panel de insights, gestos, Duo y widgets.
- **Motor de lectura: foliate-js** dentro de `WKWebView` en Apple y directo en la web. Soporta EPUB, MOBI, AZW3, FB2, CBZ y PDF (experimental vía PDF.js). Readest lo usa en producción en macOS e iOS.
- **Por qué no se nota "web":** Apple Books también renderiza EPUB con WebKit. Lo que da la sensación premium son el shell, la tipografía, las transiciones y los gestos nativos, y eso queda en SwiftUI.
- **Beneficio clave:** las mismas anclas (EPUB CFI) en las cuatro plataformas. Subrayas en el iPhone y aparece exacto en el Mac y la web.
- **Puntos técnicos a cuidar** (según el README de foliate-js): WebKit obliga a `allow-scripts` en el iframe, así que no se ejecutan scripts del libro. Además, la desofuscación de fuentes usa Web Crypto, que requiere un contexto seguro: hay que servir el motor con un *URL scheme handler* propio o incluir SHA-1 en JS.

Alternativa descartada: Readium en iOS + Catalyst en Mac + Readium Web. Da más pulido "de fábrica" en iOS, pero el Mac no sería nativo y habría dos motores que mantener.

## 5. iPhone Duo: lo que dicen las guías oficiales de Apple

El iPhone Duo se anunció el 9 de septiembre de 2026 y sale a la venta el 23 de octubre. Apple publicó la página *Designing for iPhone Duo* en las HIG y una serie de Tech Talks. Estas son las reglas que aplican a una app de lectura:

### 5.1 Reglas de la plataforma
- **Decidir con size classes, nunca con la orientación ni con el idiom.** La pantalla exterior se comporta como cualquier iPhone (compact horizontal). La interior es **regular × regular**, como un iPad, y **no respeta las orientaciones soportadas**.
- **Evitar `UIScreen.main`**, que es ambiguo con dos pantallas y quedará deprecado. Hay que usar el entorno o `window.windowScene.screen`.
- **Safe areas asimétricas:** en la pantalla exterior la cámara está siempre presente y las barras (toolbars, tab bars) se colocan **en vertical, en el borde**. No hay que asumir márgenes iguales a ambos lados.
- **Reserved regions (iOS 27.1):** `proxy.reservedRegions(kind: .division)` devuelve la bisagra y `.occlusion` devuelve la cámara FaceTime. La bisagra solo está *activa* cuando el teléfono está doblado; con `.includeInactive` se puede saber de antemano que existe.
- **ArrangementView (iOS 27.1):** un contenedor entre la navegación y el contenido, con dos estilos. `.split` (principal | secundario) sirve para contenido que nunca debe taparse. `.overlay` (primer plano sobre fondo) sirve para controles sobre contenido.
- **Poses:** libro (doblado a medias), mesa (apoyado; la región de arriba es para ver y la de abajo para tocar) y abierto plano. Hay que probarlas todas, más Split View en ambos lados.
- **No desplazar contenido de scroll continuo** a través de la bisagra; el scroll ya se adapta solo.
- **Herramientas:** Xcode 27.1, SDK de iOS 27.1, simulador iPhone Duo en Device Hub (abrir, cerrar, rotar, doblar) y el skill "App Resizability" de Xcode.

### 5.2 Cómo se traduce al lector
| Pose / pantalla | Experiencia |
|---|---|
| **Cerrado** (exterior, compact) | Una columna para leer con una mano. Los controles van en la barra vertical que pone el sistema junto a la cámara. |
| **Abierto plano** (interior, regular) | Por defecto, **doble página real**. Como hay una región `.division` (aunque esté inactiva), el lector elige un número par de columnas: dos páginas. |
| **Pose libro** (bisagra activa) | Cada página ocupa exactamente una mitad, alineada a la región `.division`. **El teléfono se convierte en un libro físico.** El paso de página es un gesto de hojear. |
| **Pose mesa** | Arriba el texto (lectura a distancia, ideal con TTS o leyendo en la mesa). Abajo los controles: página, reproducción de TTS, nota rápida. |
| **Modo estudio** | `ArrangementView(.split)`: libro a la izquierda y subrayados con insights a la derecha. Ningún lado tapa al otro. |
| **Panel de insights rápido** | `.overlay` con `overlayArrangementZIndex`: colapsado cuando está encima del texto y expandido cuando hay espacio al lado. |
| **Biblioteca** | `NavigationSplitView` + `TabView` con `.defaultTabBarPlacement(.sidebar)` en la pantalla interior. |
| **Continuidad** | Al abrir o cerrar se conserva el **CFI exacto**: la misma frase queda arriba, sin saltos. |

El modo scroll continuo **no** se parte en la bisagra; solo el modo paginado usa las mitades. Esto sigue la regla de Apple.

La misma lógica adaptativa resuelve el **iPad** (regular, doble página en horizontal, Split View y Stage Manager) y el **Mac** (ventanas redimensionables). Se diseña una vez.

## 6. Plataformas y stack

| Capa | Tecnología |
|---|---|
| App Apple | **SwiftUI multiplataforma** (iOS/iPadOS/macOS nativo), SDK de iOS 27.1 para Duo, SwiftData como caché local |
| Motor de lectura | foliate-js en `WKWebView`, con un puente JS ↔ Swift para eventos de selección, CFI y paginación |
| IA en dispositivo | **Apple Foundation Models**: compatible con tu iPhone Pro, en español desde la versión 26.1, sin conexión y sin costo; disponible también en Mac |
| Web | TypeScript (Next.js o SvelteKit) + foliate-js; la IA viene del servidor |
| Servidor | FastAPI (Python, encaja con Calibre y con bots típicos) + Postgres/pgvector + Ollama + adaptador de Calibre |
| Sincronización | Progreso y subrayados como eventos con marca de tiempo, para fusionar sin conflictos entre dispositivos |

### IA en dos niveles
1. **En el dispositivo** (Foundation Models): "explícame esto", contexto de un pasaje y definiciones. Es instantáneo y privado.
2. **En el servidor** (Ollama + embeddings): conexiones entre libros, "conversa con tu biblioteca" y digest semanal. La web y el bot usan este nivel.

## 7. De uso personal a público: diseñar los "cortes" desde hoy

Para poder quitar cosas después sin reescribir, cada integración va detrás de una interfaz y una *feature flag*:

| Módulo | Personal | Público |
|---|---|---|
| `LibrarySource` | Calibre en tu servidor | Calibre, OPDS, carpeta local, iCloud ("trae tu biblioteca") |
| `Acquisition` (bot/descargas) | ✅ Activo | ❌ Fuera de la app (riesgo con App Store y derechos de autor) |
| `KnowledgeSink` | Readwise | Readwise, Obsidian, Markdown |
| `AIProvider` | Foundation Models + tu Ollama | Foundation Models + servidor opcional |
| Autenticación | Token único | Cuentas multiusuario |

**Distribución personal:** iOS por Xcode o TestFlight (testers internos); Mac firmado y notarizado fuera de la App Store; web detrás de un acceso privado (Tailscale o Cloudflare Access).

## 8. Fases

**Fase 0: Fundación del servidor**
- Mover la biblioteca de Calibre a disco local y montar el respaldo con rclone a Drive.
- API: catálogo (desde Calibre), descarga, progreso y subrayados.
- Refactor del bot a la cola de trabajos compartida.

**Fase 1: Lector diario en iPhone**
- Shell SwiftUI con biblioteca, foliate-js en WKWebView y tipografía cuidada.
- Subrayados y progreso sincronizados; envío a Readwise; push cuando el bot agrega un libro.

**Fase 2: iPhone Duo + iPad + Mac**
- Doble página, pose libro, pose mesa y modo estudio con `ArrangementView`.
- El mismo target multiplataforma en Mac, con menús, atajos de teclado y varias ventanas.

**Fase 3: Inteligencia**
- "Explícame esto" con Foundation Models.
- Embeddings, conexiones entre libros y digest semanal (en la app y por Telegram).

**Fase 4: Web compañera**
- Biblioteca, lectura e insights desde cualquier navegador.

**Fase 5 (opcional): Versión pública** con los cortes del §7.

## 9. Riesgos

| Riesgo | Mitigación |
|---|---|
| Corrupción de Calibre por Drive | Biblioteca local + respaldo de una vía (§3.1) |
| Las APIs del Duo (iOS 27.1) son nuevas y pueden cambiar | Empezar por size classes y contenedores estándar; las APIs de reserved regions y ArrangementView van detrás de `if #available` |
| La calidad de foliate-js en WKWebView | Hacer primero un *spike* de una semana: paginación, selección, CFI y rendimiento en un libro largo |
| Bot y App Store en la versión pública | Módulo `Acquisition` removible (§7) |
| Alcance excesivo | Fases estrictas; el MVP es servidor + iPhone |

## 10. Siguientes decisiones
1. ¿En qué lenguaje está tu bot de Telegram y dónde corre el servidor (VPS, casa, NAS)? ¿Tiene GPU para Ollama?
2. ¿Qué formatos lees: solo EPUB, o también PDF y cómics?
3. ¿Lees más en español, inglés o ambos?
4. ¿Hacemos primero el *spike* técnico (foliate-js en una app SwiftUI) o primero la API del servidor?

---
**Fuentes**
- Apple Tech Talk: [Prepare your app for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111461/)
- Apple Tech Talk: [Strike a Pose with Adaptive Layouts on iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111463/)
- HIG: [Designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo)
- [Apple finally folded (Muzli, fechas del evento)](https://muz.li/blog/apple-event-2026-iphone-duo-designers/)
- [foliate-js](https://github.com/johnfactotum/foliate-js) · [Readest vs Foliate](https://readest.com/compare/readest-vs-foliate)
- [Readium Projects](https://readium.org/development/projects) · [flutter_readium (nota sobre macOS)](https://github.com/Notalib/flutter_readium)
- [Apple Intelligence: idiomas y dispositivos](https://support.apple.com/en-mt/121115) · [Foundation Models (9to5Mac)](https://9to5mac.com/2025/09/29/apple-intelligence-ios-26-models-developers/)
- MobileRead sobre Calibre en Google Drive: [hilo 1](https://www.mobileread.com/forums/showthread.php?p=2770892), [hilo 2](https://www.mobileread.com/forums/showthread.php?p=3154349)
