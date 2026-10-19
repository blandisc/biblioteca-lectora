# 03 · Investigación: apps lectoras de libros y PDF (estado a octubre 2026)

> Documento de investigación para **Biblioteca Lectora**. Objetivo: entender qué hace que una app de lectura sea "la mejor del mercado", qué es table-stakes, qué diferencia y qué errores evitar.
> Método: búsqueda web (prensa, fichas de App Store/Play, changelogs de GitHub, foros MobileRead/HN/LWN, agregadores de reseñas). Reddit casi no aparece indexado en los buscadores disponibles; donde cito sentimiento de comunidad viene sobre todo de MobileRead, Hacker News, LWN y agregadores de reseñas.
> **Nivel de confianza:** marco con ⚠️ los datos que solo provienen de agregadores, que tienen fechas contradictorias o que salen de conocimiento general previo y no pude volver a verificar en esta pasada.

---

## 0. Resumen ejecutivo

1. **El listón de la lectura "pura" lo ponen Apple Books y Kindle** (tipografía, animación de página, sincronización invisible). El de la **potencia** lo ponen KOReader, Moon+ Reader y Readest. El del **conocimiento** (subrayar → repasar → pensar) lo ponen Readwise Reader, MarginNote y LiquidText. **Ninguna app junta las tres cosas** y además respeta una biblioteca propia (Calibre). Ese es el hueco.
2. **La IA dentro del libro ya es mainstream en 2026:** Kindle tiene *Recaps* (abril 2025), *Story So Far* y *Ask this Book* (respuestas sin spoilers hasta tu posición). Google lleva libros de Play Books a Gemini Notebook con citas (agosto 2026). Readwise tiene Ghostreader "global" y MCP. **La característica clave es que respeta la posición de lectura (spoiler-free)** y que cita el pasaje. Biblioteca Lectora puede hacerlo **en local, con tus propios subrayados**, y sin la restricción de "solo libros comprados en la tienda".
3. **Readest es el competidor directo más cercano** (usa foliate-js, es multiplataforma y open source, con Calibre/OPDS, sync con KOReader y export a Readwise). Su ritmo de releases en 2026 es altísimo (TTS premium, escritura a mano, quote cards, sync con Notion, Audiobookshelf). Merece la pena estudiarlo línea a línea porque comparte motor con nuestra decisión técnica.
4. **Las quejas que más se repiten en todo el mercado:** sincronización que pierde subrayados o posición, export de subrayados capado (Kindle trunca al 10–20 %), PDFs feos o lentos, bibliotecas grandes lentas, la tienda o los anuncios metidos en la experiencia (Kobo), paywalls por suscripción (LiquidText, PDF Expert, Speechify) y curvas de aprendizaje brutales (KOReader).
5. **Los momentos mágicos** son pequeños y sensoriales: abrir el libro exactamente donde lo dejaste en otro dispositivo, una nota al pie que aparece en un popover sin perder el sitio, un "¿quién era este personaje?" respondido sin spoilers, el subrayado que vuelve semanas después en un repaso, y el audio que pasa a texto sin perder la frase.

---

## 1. Fichas por app

Formato: **Plataformas · Modelo de negocio · Destacado · Lo que aman · Quejas principales**.

### 1.1 Apple Books
- **Plataformas:** iPhone, iPad, Mac, Vision Pro (y CarPlay para audiolibros). Sin Android, Windows ni web.
- **Modelo:** gratis; ingresos por la tienda de libros y audiolibros.
- **Destacado:** la animación de página más pulida del mercado (curl, slide, scroll), integración con el sistema (VoiceOver, Dynamic Type, Live Text, Shortcuts), objetivos de lectura con rachas, colecciones, "Want to Read". Desde 2023 ofrece audiolibros con **narración digital (IA)** ([Macworld](https://www.macworld.com/article/1447641/apple-books-ai-narration-audiobooks.html), [iMore](https://imore.com/apple/this-new-apple-feature-uses-ai-to-narrate-books-but-not-everyone-is-convinced)).
- **Lo que aman:** "pulido, con animaciones suaves y un modo nocturno agradable" ([getbookshelves](https://getbookshelves.app/guides/best-epub-reader-iphone-ipad/), [iGeeksBlog](https://www.igeeksblog.com/best-ebook-reader-ipad-iphone-apps/)). Cero fricción para EPUB sin DRM vía AirDrop o Archivos.
- **Quejas:** **no hay export ni API de subrayados**, ni acceso desde Windows o Android; personalización limitada (~14 fuentes, sin fuentes propias en iOS) ([getbookshelves](https://getbookshelves.app/guides/best-epub-reader-iphone-ipad/)). Historial largo de problemas de sync de EPUB/PDF personales ligados a iCloud Drive: libros que desaparecen, anotaciones perdidas o texto invisible ([TidBITS](https://tidbits.com/2016/03/30/ibooks-with-icloud-drive-is-unreliable-and-confusing/), [kith.org](https://www.kith.org/jed/2018/12/09/apple-books-files-gone-missing/), [MobileRead](https://www.mobileread.com/forums/showthread.php?p=4243493)). Con iOS 26, los ajustes de transición de página pasaron a Ajustes del sistema y hay reportes de que no se aplicaban a libros con ajuste propio ⚠️ ([yomotherboard](https://yomotherboard.com/question/ios-26-update-changed-my-apple-books-settings-any-solutions/)). Gestión de biblioteca pobre para colecciones grandes.

### 1.2 Kindle (app y e-readers)
- **Plataformas:** e-readers Kindle (Paperwhite, Colorsoft, Scribe), iOS, Android, Mac/PC, Cloud Reader web.
- **Modelo:** tienda de Amazon, Kindle Unlimited y Prime Reading.
- **Destacado:**
  - **X-Ray** (personajes, términos y lugares con sus apariciones), **Word Wise** (glosas encima de palabras difíciles), **Vocabulary Builder**, **Page Flip** (miniaturas con la página actual "fijada", desde 2016) ([TechCrunch](https://techcrunch.com/?p=1344485), [InfoDocket](https://www.infodocket.com/2016/06/28/amazon-introduces-page-flip-a-new-ebook-and-exploration-and-navigation-feature-for-kindle-devices-and-apps/)), Whispersync (posición, notas y audio con Audible), popular highlights.
  - **IA:** **Recaps**, resúmenes de los libros anteriores de una saga, lanzado el 2 de abril de 2025 solo en EE. UU. y en inglés, con aviso de spoilers y moderación humana ([About Amazon](https://www.aboutamazon.com/md/news/books-and-authors/kindle-recaps-feature-ebook-series-refreshers), [Thurrott](https://www.thurrott.com/?p=319397), [Gigazine](https://wbgsv0a.gigazine.net/gsc_news/en/20250407-kindle-recaps)). **Story So Far** resume el libro *hasta donde vas*, sin spoilers ([Shopifreaks](https://www.shopifreaks.com/amazon-rolls-out-its-ai-story-so-far-recap-feature-to-kindle-devices-and-the-ios-app-to-help-readers-catch-up/), [Android Authority](https://www.androidauthority.com/amazon-kindle-story-so-far-ask-this-book-3603120)). **Ask this Book** responde preguntas de trama, personajes y temas, limitado a tu posición o al libro completo si lo eliges. Se invoca desde el menú o al seleccionar texto. Las respuestas **no se pueden copiar ni compartir** y solo funciona con libros comprados o prestados. Empezó en iOS EE. UU. (las fuentes discrepan entre diciembre 2025 y 2026) ⚠️ ([Tom's Guide](https://www.tomsguide.com/computing/e-readers/amazon-adds-ai-chatbot-to-the-kindle-app-which-offers-spoiler-free-answers-about-your-ebooks), [Business Standard](https://www.business-standard.com/technology/tech-news/amazon-kindle-ask-this-book-feature-spoiler-free-answers-125121600444_1.html)).
  - Kindle Scribe 2026: "Send to Alexa", "Refine writing" y búsqueda en lenguaje natural sobre cuadernos ([the-ebook-reader](https://blog.the-ebook-reader.com/2026/02/12/new-kindle-scribes-getting-send-to-alexa-feature-and-more-ai-tools/), [About Amazon](https://www.aboutamazon.com/md/news/devices/kindle-scribe-gen-ai-notebook)). Kindle Translate (beta, para autores) ([ALLi](https://selfpublishingadvice.org/tag/amazon-kindle-translate/)).
  - La app de iOS tiene funciones que los e-readers no tienen ([Engadget](https://engadget.com/2202142/kindle-app-features-ios-has-ereader-still-doesnt-have), [SlashGear](https://www.slashgear.com/2240743/ios-kindle-app-features-better-than-amazon-e-reader/)).
- **Lo que aman:** Whispersync "simplemente funciona", la tipografía (Bookerly y ajustes de márgenes), X-Ray en sagas largas y la pareja Kindle + Audible.
- **Quejas:** ecosistema cerrado; **límite de export de subrayados ("copyright export limit", ~10–20 % del libro) que trunca subrayados o los deja solo con su posición** ([Readwise Help](https://help.readwise.io/article/47-why-are-my-kindle-highlights-truncated-ellipses), [HN](https://hn.nuxt.dev/item/49424758)). Los libros personales vía Send to Kindle se convierten (EPUB → KFX) con fallos de formato ([Adobe Community](https://community.adobe.com/t5/indesign-discussions/indesign-to-reflowable-epub-footnotes-first-line-appears-with-a-space-before-on-the-kindle/m-p/13470446/highlight/true), [Take Control](https://www.takecontrolbooks.com/your-kindle-can-finally-read-epub-files/)). El Authors Guild protestó porque no hay opt-out para Ask this Book.

### 1.3 Kobo (Rakuten)
- **Plataformas:** e-readers Kobo, iOS, Android y Web Reader (con subrayados desde finales de 2025).
- **Modelo:** tienda y Kobo Plus (Read, Listen o Read & Listen, ~US$7.99–9.99 al mes ⚠️ [subger](https://subger.com/en/service/kobo-plus)).
- **Destacado:** app rediseñada con modo noche y sleep timer para audio; en 2026 llegan una home nueva en iOS, Kobo Remote y la **sincronización automática con StoryGraph** (junio 2026) ([Kobo blog](https://www.kobo.com/blog/product-features), [Kobo news](https://us.kobobooks.com/blogs/news/new-kobo-app-ereader-features), [Buttondown](https://buttondown.com/nodunayo/archive/the-one-woman-dev-team-diaries-225/)). Integración con OverDrive/Libby en los e-readers y estadísticas "Reading Life".
- **Lo que aman:** apertura (EPUB nativo, Adobe DRM, bibliotecas públicas), hardware y comunidad de modding (KOReader y NickelMenu).
- **Quejas:** app móvil con la tienda y las recomendaciones ocupando la pantalla ([the-ebook-reader](https://blog.the-ebook-reader.com/?p=23879)). **Sin export nativo de subrayados**; Readwise solo sincroniza libros comprados en Kobo y los sideloaded requieren extracción manual ([Readwise docs](https://docs.readwise.io/readwise/docs/importing-highlights/kobo), [myereader](https://myereader.substack.com/p/kobo-and-organising-annotations-through)). Se perdió la integración con Pocket cuando Pocket cerró.

### 1.4 Google Play Books
- **Plataformas:** Android, iOS y web.
- **Modelo:** tienda; subida gratuita de hasta 1.000 EPUB/PDF sin DRM (~100 MB por archivo) ([Shelly Palmer](https://shellypalmer.com/?p=52858), [TuttoAndroid](https://www.tuttoandroid.net/news/google-play-books-gli-utenti-possono-caricare-ora-file-fino-a-100-mb-178690/)).
- **Destacado:** "cloud locker" gratuito con sync de progreso, notas y subrayados; export de notas a Google Docs; Bubble Zoom para cómics; Read Aloud. **IA:** el código de una beta (nov. 2025) muestra un botón "Ask Gemini" en el menú de selección ([Android Authority](https://www.androidauthority.com/google-play-books-ask-gemini-apk-teardown-3624252)); en agosto 2026, "Expert Intelligence" en Gemini Notebook permite preguntar sobre más de 100.000 libros comprados, con respuestas apoyadas en el libro y **citas en línea** ([Gigazine](https://gigazine.net/gsc_news/en/20260828-expert-intelligence-gemini/), [Tom's Guide](https://www.tomsguide.com/ai/google-gemini/google-just-gave-gemini-access-to-your-ebooks-7-prompts-for-readers-and-students), [Slashdot](https://tech.slashdot.org/story/26/08/27/2358220/)).
- **Lo que aman:** gratis, multiplataforma y sin configurar nada.
- **Quejas:** no se pueden volver a descargar los archivos subidos ⚠️, algunas subidas se quedan "procesando" para siempre, personalización tipográfica mínima, gestión de biblioteca básica ([gHacks](https://www.ghacks.net/?p=89471), [GoodEReader](https://goodereader.com/blog/tag/google-play-books-upload)).

### 1.5 KOReader
- **Plataformas:** Kindle, Kobo, PocketBook, reMarkable, Cervantes, Android y Linux (escritorio). No hay app de iOS.
- **Modelo:** open source (AGPL), gratis. Lanza versiones con nombre (2025.04 "Full Moon", 2026.03 "Snowflake", 2026.07.x) ([GitHub](https://github.com/koreader/koreader), [F-Droid](https://f-droid.org/en/packages/org.koreader.launcher.fdroid/), [Releasebot](https://releasebot.io/updates/koreader)).
- **Destacado:** motor CREngine con **hyphenation real por diccionarios**, control tipográfico total y style tweaks CSS; **reflow de PDF/DjVu escaneados** y recorte automático de márgenes; gestos 100 % configurables; diccionarios StarDict; Wikipedia; traducción; **estadísticas de lectura muy ricas** (tiempo por página, calendario, ETA); Vocabulary Builder; Progress sync (servidor propio); export de subrayados (Markdown, JSON, Joplin, Readwise...); integración con Calibre por Wi-Fi; OPDS; Wallabag; plugins ([wiki](https://github.com/koreader/koreader/wiki/)). Tiene plugins de terceros (Storyteller, BookFusion) ([BookFusion docs](https://docs.bookfusion.com/docs/KOReader/koreader-release-notes)).
- **Lo que aman:** velocidad ("más rápido que el firmware de serie en el mismo hardware"), PDFs académicos legibles en 6", tipografía, gestos y estadísticas ([dsebastien](https://www.dsebastien.net/koreader/), [LWN](https://lwn.net/Articles/891494), [HN](https://brianlovin.com/hn/43539103)).
- **Quejas:** curva de aprendizaje empinada, "árbol de menús laberíntico", "un caos con todo y el fregadero" ([MobileRead](https://www.mobileread.com/forums/showthread.php?p=4080057), [LWN](https://lwn.net/Articles/891494)). Interfaz fea fuera de e-ink.
- **Lección para nosotros:** la potencia de KOReader con valores por defecto de Apple. Copiar sus *capacidades* (estadísticas, hyphenation, gestos, vocabulario), no su UI.

### 1.6 Readest ⭐ (competidor más cercano)
- **Plataformas:** macOS, Windows, Linux, Android, iOS/iPadOS y web. Hecho con Next.js 16 + Tauri v2; se presenta como "reescritura moderna de Foliate" y **usa foliate-js** ([GitHub](https://github.com/readest/readest)).
- **Modelo:** AGPL-3.0 y donaciones; **en 2026 añadió planes Plus/Pro** (p. ej., voces premium "Readest Voice") ([releases](https://github.com/readest/readest/releases)).
- **Destacado:** EPUB, PDF, MOBI, AZW3, FB2, CBZ, TXT, HTML y Markdown; paginado o scroll; regla de lectura, modo párrafo y lectura rápida; **Parallel Read** (dos libros lado a lado); búsqueda en el libro y en la estantería; diccionarios importables (Yomitan, RDICT), Wikipedia; traducción DeepL/Yandex o proveedores propios con biblioteca de prompts; TTS multilingüe; **read-along con EPUB 3 Media Overlays o con MP3/M4B sin DRM**; OPDS y Calibre; **sync con KOReader**; export a Readwise y Hardcover; VoiceOver, TalkBack, NVDA y Orca.
  - Releases 2026 (ago–oct): narración de audiolibros sincronizada con el texto, sync iCloud, hub de notas, Audiobookshelf (streaming y offline), **sync con Notion**, headers y footers configurables, importación de ReadEra, estantes configurables con tags masivos, animaciones de página para PDF y cómics, TTS frase a frase con A-B repeat, resaltado de diálogos, **escritura a mano o dibujo en la página**, **quote cards como imagen**, widgets ([releases](https://github.com/readest/readest/releases)).
  - Roadmap: resumen con IA y estadísticas avanzadas.
- **Lo que aman:** gratis, sin límite de libros, "la más agradable de las alternativas gratuitas" ([getbookshelves](https://getbookshelves.app/guides/best-epub-reader-iphone-ipad/), [MakeTechEasier](https://maketecheasier.com/readest-ebook-reader)). Sync entre plataformas.
- **Quejas:** cambios de política del cloud sync generaron desconfianza; bugs de selección de texto (el cursor salta a la página anterior) y parsing de TTS con la puntuación ⚠️ ([marlvel.ai](https://marlvel.ai/apps/readest-ebook-reader/reviews)). La sensación "web" (Tauri) no llega al pulido nativo de Apple Books.
- **Lección:** demuestra que foliate-js aguanta un producto completo, y también dónde duele (selección de texto y rendimiento). Nuestro diferencial frente a Readest: **shell nativo SwiftUI, servidor propio como fuente de verdad, capa de conocimiento (LLM local y repaso)**.

### 1.7 Foliate (GNOME)
- **Plataformas:** Linux (GTK4/libadwaita), con soporte para móviles Linux.
- **Modelo:** GPL, gratis.
- **Destacado:** desde 3.0 usa su propio motor (**foliate-js**); paginado multicolumna (más de 2 columnas), alterna paginado/scroll con Ctrl+M; copiar con cita o con **CFI**; TTS con resaltado por palabra; OPDS; predicción de tiempo de lectura; Wikipedia y Wiktionary ([OMG! Ubuntu](https://www.omgubuntu.co.uk/2023/11/foliate-ebook-app-major-update), [AlternativeTo](https://alternativeto.net/news/2023/11/foliate-3-0-has-been-ported-to-gtk4-and-comes-with-many-new-features-and-enhancements), [Debian](https://packages-pkgmirror-csail.debian.org/sv/sid/foliate)).
- **Lo que aman:** la estética limpia y nativa de GNOME, y que es rápido.
- **Quejas:** PDF experimental, perdió CBR y CB7; regresiones al portar (OPDS y diccionarios llegaron después).
- **foliate-js (nuestro motor candidato):** MIT; paginador por CSS multi-column con animación slide, header y footer; renderer fixed-layout aparte (FXL, CBZ, PDF vía PDF.js); CFI robusto; overlayer SVG para subrayados; generador de SSML para TTS; búsqueda que ignora diacríticos. **Limitaciones declaradas:** API inestable y sin releases; sin scroll continuo real; paginador "lento"; búsqueda "muy lenta" (hay que cargar resultados de forma incremental); sin libros mixtos (reflow + FXL); sin EPUB con scripts; la desofuscación de fuentes necesita contexto seguro ([foliate-js](https://github.com/johnfactotum/foliate-js)).

### 1.8 Thorium Reader (EDRLab)
- **Plataformas:** Windows, macOS y Linux; **app de iOS desde 2025**. EBSCO migra a Thorium en 2026 ([Buffalo Libraries](https://library.buffalo.edu/news/stories/2026/05/ebsco-update.html)).
- **Modelo:** open source (sin ánimo de lucro, Readium); soporte de LCP DRM para bibliotecas.
- **Destacado:** **referente de accesibilidad**: JAWS, NVDA, Narrator y VoiceOver; read-aloud con resaltado; atajos configurables; DAISY 2.02; función "¿dónde estoy?" con el rastro de encabezados ([EDRLab a11y](https://thorium.edrlab.org/en/th3/500_accessibility/)). Desde 3.3 hay que activar el modo lector de pantalla a mano.
- **Lo que aman:** fidelidad a EPUB 3 y FXL, y la accesibilidad.
- **Quejas:** UI "de escritorio" poco refinada; gestión de biblioteca básica.

### 1.9 Yomu
- **Plataformas:** iPhone, iPad y Mac.
- **Modelo:** gratis con anuncios; Pro (pago único ~US$7.99 ⚠️) para biblioteca iCloud, documentos ilimitados y sin anuncios ([App Store vía AppFollow](https://apps.appfollow.io/ios/yomu-ebook-reader/562211012?country=us), [getbookshelves](https://getbookshelves.app/guides/best-epub-reader-iphone-ipad/)).
- **Destacado:** EPUB, MOBI, AZW3, CBZ/CBR y PDF; importación desde iCloud, Dropbox, Google Drive, **OPDS y Calibre**; widgets con citas subrayadas; diseño **Liquid Glass**; nota de 4,8 con ~1.600 reseñas.
- **Lo que aman:** limpieza, "se siente Apple", sin distracciones.
- **Quejas:** poca personalización (sin márgenes exactos ni temas por libro); anuncios en la versión gratuita.
- **Lección:** el listón estético en iOS para lectores "de terceros" con Calibre.

### 1.10 BookFusion
- **Plataformas:** iOS, iPadOS, macOS, Android, web y **plugin de KOReader** (junio 2026) ([BookFusion docs](https://docs.bookfusion.com/docs/KOReader/koreader-release-notes)).
- **Modelo:** freemium (gratis hasta 10 libros en la nube; planes de ~US$1.99 a 9.99 al mes) ([pricing](https://www.bookfusion.com/reading/pricing)).
- **Destacado:** biblioteca en la nube con **plugin de Calibre**, sync de progreso y subrayados, multiventana en iPad y Mac, widgets, export a Obsidian y Readwise.
- **Lo que aman:** ser "el puente Calibre ↔ móvil" sin montar servidor.
- **Quejas:** precio y almacenamiento para bibliotecas grandes; lector menos pulido que Apple Books ([MobileRead](https://www.mobileread.com/forums/showthread.php?p=4346276)).

### 1.11 Readwise Reader
- **Plataformas:** web, iOS, Android, Mac y Windows (desktop); modo e-ink en Android (Boox, Daylight).
- **Modelo:** suscripción (~US$9.99 al mes en plan anual; 30 días de prueba) ([aisotools](https://aisotools.com/blog/readwise-reader-review-2026)).
- **Destacado:** bandeja única (artículos, newsletters, RSS, EPUB, PDF, YouTube); **Ghostreader** (definir, resumir, traducir, preguntar con contexto) ([docs](https://docs.readwise.io/reader)); en 2025 reescribió EPUB, que antes trataba como "artículos muy largos" y ahora carga por capítulo con una vista long-form ([update jun-2025](https://readwise.io/reader/update-june2025)); TTS de EPUB en Android (feb. 2026); en ago-2026 llegan **Global Ghostreader, Readwise 2.0, chat móvil, mejor búsqueda y MCP** ([update ago-2026](https://readwise.io/reader/update-aug2026), [changelog](https://docs.readwise.io/changelog)). Repaso diario con spaced repetition (Readwise clásico).
- **Lo que aman:** subrayar algo y *volver a verlo* (el repaso diario), export a Obsidian, Notion o Logseq, y los atajos de teclado.
- **Quejas:** EPUB históricamente débil (los enlaces del TOC no navegaban, no hay agrupación por capítulo) ([outlinersoftware](https://outlinersoftware.com/topics/viewt/9903)); precio; no es un lector de libros "de sofá".
- **Para nosotros:** destino de integración (push de subrayados), no competencia directa.

### 1.12 Moon+ Reader (Android)
- **Modelo:** gratis con anuncios; Pro de pago único (~€5,49) ([NextPit](https://www.nextpit.de/ebook-reader-beste-apps), [Technipages](https://www.technipages.com/moon-reader-pro-complete-guide)).
- **Destacado:** personalización extrema; **5 modos de auto-scroll** (persiana, píxel, línea, página) con velocidad en tiempo real; **dual page con modo automático para plegables**; título del capítulo en el borde superior en modo dual ([APKMirror 6.0/6.7/7.1](https://www.apkmirror.com/apk/moon/moon-reader/moon-reader-7-1-release)); TTS ("agita para hablar"), estadísticas, sync de posición vía Dropbox o Drive, PDF con formularios y anotación a mano ([MobileRead wiki](https://wiki.mobileread.com/wiki/Moon+_Reader)).
- **Lo que aman:** "todo se puede configurar", gestos y animaciones de página realistas.
- **Quejas:** UI recargada y anticuada; anuncios en la versión gratuita; sync frágil.
- **Lección para iPhone Duo:** el **auto dual-page al desplegar** ya existe en Android. Es table-stakes para plegables.

### 1.13 Lithium (Android)
- **Modelo:** gratis sin anuncios; Pro para sync en Drive y temas propios ([APKMirror](https://www.apkmirror.com/apk/faultexception/lithium-epub-reader), [Softpedia](https://mobile.softpedia.com/apk/lithium-epub-reader/)).
- **Destacado:** minimalismo Material, detección automática de libros, paginado/scroll. Solo EPUB.
- **Quejas:** desarrollo lento (última versión de enero 2025), poca personalización y un solo formato ([tecnobits](https://tecnobits.net/?p=80762)).
- **Lección:** lo minimal y sin anuncios se ama, pero estancarse mata.

### 1.14 ReadEra
- **Plataformas:** Android (fuerte) e iOS (débil, 3,1★ ⚠️).
- **Modelo:** gratis sin anuncios ni registro (hay una edición Premium) ([AppFollow](https://appfollow.io/ios/readera-book-reader-pdf-epub/1669188337?country=us), [AlternativeTo](https://www.alternativeto.net/software/readera/about/)).
- **Destacado:** abre casi todo (EPUB, PDF, DJVU, DOCX, FB2, MOBI, CHM, ZIP); detecta duplicados; colecciones ("Por leer", "Favoritos"); funciona offline.
- **Lo que aman:** rapidez y que gestiona bien el almacenamiento externo.
- **Quejas:** la versión de iOS está muy por debajo de la de Android.

### 1.15 Marvin (legacy, iOS)
- Lector EPUB de iOS (Appstafarian/Kobo), **abandonado de facto** pero aún venerado en MobileRead ([AlternativeTo](https://alternativeto.net/software/marvin-classic/?p=4)) ⚠️.
- **Por qué importa:** fue el "KOReader con estética iOS": **Deep View** (personajes, lugares y conceptos al estilo X-Ray, generados del propio libro y de Wikipedia), **export de anotaciones a Evernote o HTML**, tipografía muy fina, gestos configurables, estadísticas, Calibre Content Server/OPDS y **ajuste de brillo deslizando el dedo por el margen**. Muchos lectores de iOS siguen buscando "el sucesor de Marvin" (el vacío que deja Marvin es una oportunidad).

### 1.16 Librera Reader
- **Plataformas:** Android; open source (GPL-3.0) en F-Droid, y Pro en Play con Google Drive ([F-Droid](https://f-droid.org/en/packages/com.foobnix.pro.pdf.reader/)).
- **Destacado:** formatos de todo tipo (PDF, DjVu, EPUB, CBZ/CBR, DOCX); auto-scroll "Musician's mode"; TTS; OPDS; anotación de PDF; RTL.
- **Quejas:** UI densa y poco moderna.
- **Lección:** el *modo músico* (scroll a velocidad constante para partituras o lectura manos libres) es un nicho real.

### 1.17 PocketBook Reader (app)
- **Plataformas:** iOS y Android, más los e-readers PocketBook.
- **Modelo:** gratis; PocketBook Cloud gratuito.
- **Destacado:** 26 formatos de libro y audio; **reflow de PDF**; TTS; OPDS; **escáner de ISBN**; sync de biblioteca, posición, notas y marcadores entre móvil y e-ink; Dropbox y Google Drive ([App Store vía appshunter](https://appshunter.io/ios/app/805488884), [PocketBook CH](https://pocketbook.ch/en-ch/news/unlock-the-full-potential-of-your-pocketbook-ch)).
- **Quejas:** UI irregular y bugs de login con Drive.

### 1.18 Boox NeoReader
- **Plataformas:** solo dispositivos Onyx Boox (Android e-ink).
- **Destacado:** el mejor PDF en e-ink: **recorte, reflow, OCR**, división de página, anotación con stylus en el margen, TTS, auto-page-turn ([Boox](https://shop.boox.com/en-au/blogs/news/6-tips-for-productive-ebook-reading-with-neoreader), [the-ebook-reader](https://blog.the-ebook-reader.com/2024/08/05/onyx-boox-neo-reader-pdf-features-review-video/)). La IA vive en otras apps del sistema (AI Assistant, transcripción).
- **Quejas:** inconsistencia de UI y firmware, privacidad (servidores en China) ⚠️.
- **Lección:** para PDFs serios hacen falta **recorte de márgenes, modo columna y reflow**.

### 1.19 Storyteller (ebook + audiolibro sincronizados)
- **Plataformas:** servidor self-hosted (Docker) + apps de iOS y Android ("Storyteller Reader", también para Mac y Vision Pro) + plugin de KOReader ([App Store](https://apps.apple.com/app/storyteller-reader/id6474467720), [RuntimeWire](https://runtimewire.com/article/storyteller-v3-ctc-aligner-immersive-reading)).
- **Modelo:** open source y gratis; hay hosting gestionado de terceros (ElfHosted).
- **Destacado:** toma un EPUB y su audiolibro, **los alinea con forced alignment** (v3: alineador CTC) y genera un **EPUB 3 con Media Overlays**, legible en cualquier lector compatible (Readest, Thorium, BookFusion…). La app permite pasar de audio a texto con un toque y **doble tap en una frase para que el audio arranque desde ahí**. v2 añadió biblioteca, importación por carpetas y OIDC ([Tildes](https://tildes.net/~books/1q2s/storyteller_v2_is_now_available), [HN](https://hn.nuxt.dev/item/49497854)).
- **Lección clave:** encaja perfecto con nuestra arquitectura (servidor propio). **Que Biblioteca Lectora lea Media Overlays desde el día 1** nos da Whispersync-for-Voice sin Amazon.

### 1.20 Speechify / ElevenReader (TTS)
- **Speechify:** iOS, Android, web, Chrome y Mac. Suscripción Premium (~US$139 al año); la versión gratis limita la velocidad a 1,5x y Premium llega a 5x. Ofrece texto resaltado que sigue la voz, resúmenes con IA y OCR de fotos ([Roborhythms](https://www.roborhythms.com/speechify-review-2026/)). Quejas: precio, tácticas de suscripción y renovaciones agresivas ([Kimola](https://kimola.com/reports/exclusive-insight-speechify-user-feedback-analysis-report-app-store-us-156083), [Trustpilot](https://www.trustpilot.com/review/speechify.com?page=6)).
- **ElevenReader (ElevenLabs):** lee EPUB, PDF, DOCX, web y escaneos con más de 1.000 voces; más de 200.000 audiolibros narrados por IA; detecta los capítulos siguientes en web novels. La versión gratis incluye 10 h al mes; Ultra cuesta ~US$11 al mes o US$99 al año (offline y sin límite, con tope diario) ⚠️ con precios cambiantes ([ElevenLabs docs](https://elevenlabs.io/docs/it/help-center/product/mobile-apps/eleven-reader/what-is-eleven-reader), [tooldirectory](https://tooldirectory.ai/tools/elevenreader), [blog](https://elevenreader.io/blog/best-pricing-more-value)).
- **Lección:** la calidad de voz neural ya es "audiolibro aceptable". En Apple, las voces Premium/Enhanced de AVSpeechSynthesizer y Personal Voice son gratis y offline. Un plan "voz premium" (como Readest Voice) se puede añadir más tarde.

### 1.21 MarginNote 4
- **Plataformas:** iPad, iPhone y Mac.
- **Modelo:** suscripción o compra (freemium).
- **Destacado:** **un extracto es a la vez subrayado, nodo de mapa mental y flashcard** ("Card Axis"); mapas mentales, outliner y canvas; Study Sets que mezclan PDF, EPUB, vídeo y audio; comparar dos documentos; capa de escritura a mano; OCR; **flashcards con FSRS**; IA ([App Store](https://apps.apple.com/us/app/marginnote-4-ai-notes-mindmap/id1531657269), [mergeek](https://mergeek.com/en/latest/GeY0RWNqPoLAbMKa)).
- **Quejas:** curva de aprendizaje y documentación pobre; no importa el TOC del PDF como mapa inicial ([foro](https://forum.marginnote.com/t/mn4-need-import-bookmark-table-of-content-from-pdf/9368)).
- **Lección:** "un subrayado = muchos usos" (repaso, mapa, nota). FSRS como algoritmo de repaso.

### 1.22 LiquidText
- **Plataformas:** iPad, iPhone, Mac y Windows.
- **Modelo:** suscripción por niveles.
- **Destacado:** **pellizcar el documento para colapsar** secciones y ver páginas lejanas juntas; arrastrar extractos a un workspace infinito con **enlaces bidireccionales** al origen; muy usado en derecho ([Capterra](https://www.capterra.ca/reviews/1033403/liquid-text), [GetApp](https://www.getapp.com/collaboration-software/a/liquid-text/)).
- **Quejas:** precio confuso y caro, funciones clave en el plan superior, inestabilidad y (según algunas reseñas) sin modo oscuro ([mwm.ai](https://mwm.ai/apps/liquidtext/922765270)).
- **Lección:** el **link de vuelta al pasaje exacto** desde cualquier nota es mágico.

### 1.23 PDF Expert (Readdle)
- **Plataformas:** iPhone, iPad y Mac.
- **Modelo:** suscripción (~US$79.99 al año) o licencia vitalicia (US$140–199 según la fuente) ⚠️ ([Sweet Bits](https://thesweetbits.com/pdf-expert-review/), [TechRadar](https://www.techradar.com/reviews/readdle-pdf-expert)).
- **Destacado:** el PDF más fluido de Apple; anotación, edición, formularios, firmas, OCR y comparación de versiones; asistente IA (resumen y preguntas).
- **Quejas:** paso a suscripción ([The Sweet Setup](https://thesweetsetup.com/pdf-expert-releases-version-7-switches-to-subscription-model/)) y la IA no incluida en la vitalicia.
- **Lección:** para PDF en Apple, **PDFKit nativo** es el listón de fluidez (zoom, selección, anotación con Pencil). PDF.js dentro de WKWebView difícilmente lo iguala.

### 1.24 Zotero (lector)
- **Plataformas:** escritorio (Win, Mac y Linux), iOS/iPadOS, Android (beta) y web.
- **Modelo:** open source; almacenamiento de pago.
- **Destacado:** desde Zotero 7, el lector anota PDF, **EPUB** y snapshots web (highlight, underline, nota, imagen; ink y texto solo en PDF); en iOS sincroniza anotaciones de EPUB con el escritorio; citas y bibliografía ([Zotero 7](https://www.zotero.org/blog/zotero-7/), [iOS EPUB](https://www.zotero.org/blog/ios-epub-snapshot-annotation-and-pdf-metadata-retrieval/)).
- **Lección:** el "add note from annotations" (convertir subrayados en una nota estructurada con enlaces de vuelta) es un patrón excelente para nuestras "notas de libro".

### 1.25 StoryGraph y Bookly (tracking)
- **StoryGraph:** web, iOS y Android. Gratis + Plus (~US$4.99 al mes ⚠️). Estadísticas y gráficos ricos, recomendaciones por mood y ritmo, importación de Goodreads, independiente de Amazon. **Sync automático con Kobo (junio 2026)** ([unstar](https://unstar.app/blog/goodreads-storygraph-fable-hardcover-bookly-reading-tracker-apps-ranked-2026), [bestwriting](https://bestwriting.com/goodreads-alternatives)).
- **Bookly:** iOS y Android; freemium. **Temporizador de sesiones**, objetivos, recordatorios, informes semanales, mensuales y anuales, ratings con medias estrellas o personalizados ([bibliolifestyle](https://bibliolifestyle.com/best-book-tracking-apps-for-readers/)).
- **Hardcover** (alternativa con API abierta) ya integra Readest.
- **Lección:** el tracking vive **fuera** del lector y obliga a registrar a mano. Si nuestro lector **mide sesiones automáticamente** (como KOReader) y además exporta a StoryGraph/Hardcover, eliminamos esa fricción.

---

## 2. Catálogo de funciones de experiencia de lectura

Leyenda: **[T]** table-stakes (su ausencia se nota y genera quejas) · **[D]** diferenciador (hace que te elijan) · **[M]** momento mágico potencial · **[N]** nicho o avanzado (opcional). Entre paréntesis, quién lo hace mejor.

### 2.1 Tipografía y maquetación
| Función | Nivel | Notas / referentes |
|---|---|---|
| Tamaño de fuente, interlineado y márgenes | T | Todos. Márgenes **exactos** por número: Kindle (2025), KOReader, Moon+. Yomu sale criticado por no tenerlos. |
| Selección de fuentes de calidad (serif y sans, incluida una para dislexia) | T | Apple Books (~14), Kindle (Bookerly, Amazon Ember, OpenDyslexic). |
| **Fuentes propias** (importar TTF/OTF) | D | KOReader, Moon+, Readest (descarga bajo demanda en 2026). Apple Books no lo permite en iOS: queja frecuente. |
| Justificación + **hyphenation real** (diccionarios por idioma, incluido español) | T→D | KOReader (diccionarios Liang). En web: CSS `hyphens:auto` + `lang` correcto. Sin guiones, la justificación crea "ríos" en el texto: queja típica en apps web. |
| Respetar el CSS del editor vs. "forzar mis ajustes" (por libro) | D | KOReader (style tweaks), Readest. Toggle "estilo del editor" en Apple Books. |
| Ajustes **por libro** vs. globales | D | Moon+, KOReader. Yomu falla aquí. |
| Columnas: 1 o 2 automáticas según el ancho; **dual-page al desplegar un plegable** | T (plegables) | Moon+ "auto dual page for foldables"; Foliate, más de 2 columnas. **Clave para el iPhone Duo.** |
| Column gap, header y footer configurables (título, capítulo, páginas restantes, reloj, batería) | D | KOReader (status bar presets), Readest (2026). |
| Ancho máximo de línea (medida) en pantallas grandes | T | Imprescindible en iPad y Mac; foliate-js `max-inline-size`. |
| Peso de fuente, contraste y espaciado entre letras y palabras | N | KOReader (font weight), Kindle (bold). |
| Capitulares, small caps, ligaduras y kerning | N | Afinar con OpenType features. |
| Soporte vertical / RTL / CJK (ruby) | N | KOReader, Readest, Apple Books. |

### 2.2 Paginación vs. scroll
| Función | Nivel | Notas |
|---|---|---|
| Modo paginado y modo scroll, cambiables sin recargar | T | foliate-js lo soporta. Ojo: **no tiene scroll continuo entre capítulos** (limitación declarada). |
| Scroll continuo entre capítulos | D | Readwise long-form, Apple Books scroll. Hay que implementarlo encima de foliate-js. |
| Números de página **estables** (page-list del editor / "páginas reales") | D | Kindle "real page numbers", KOReader (Stable pages). Útil para clubes de lectura y citas. |
| Ubicación robusta (CFI) que no se rompe al cambiar la fuente | T | Base de una sync fiable. foliate-js CFI. |
| "Tiempo restante en el capítulo / en el libro" basado en tu velocidad | T→D | Kindle, KOReader, Foliate. |
| Auto-scroll / auto-page-turn (manos libres) | N | Moon+ (5 modos), Librera (Musician's mode), NeoReader. |
| Modo párrafo / regla de lectura / lectura rápida (RSVP) | N | Readest. |

### 2.3 Animaciones de cambio de página
| Función | Nivel | Notas |
|---|---|---|
| Slide suave a 60/120 fps | T | ProMotion; foliate-js `animated`. |
| Page curl realista que sigue el dedo | D (emocional) | Apple Books, Moon+. Muy amado por una parte del público y odiado por otra; siempre debe ser opcional. |
| Sin animación (instantáneo) | T | Lectores de e-ink y amantes de la velocidad. |
| Animación también en PDF y cómics | D | Readest (2026). |
| **Interacción interrumpible**: el swipe sigue el dedo y se puede cancelar | T | Si el swipe no "se pega" al dedo, la app se siente web. **Riesgo principal de WKWebView**: hay que resolver los gestos en nativo o con JS muy afinado. |

### 2.4 Temas y color
| Función | Nivel | Notas |
|---|---|---|
| Claro, sepia, oscuro y negro OLED | T | Todos. |
| Temas personalizados (fondo y texto) y separados para biblioteca y lector | D | Readest 2026, Moon+. |
| Cambio automático con el sistema o por horario | T | |
| Smart invert de imágenes en modo oscuro (PDF y EPUB) | D | Readest (2026, PDF smart invert). |
| Brillo y calidez en la app (deslizando el margen) | M | Marvin, Moon+, KOReader (frontlight). |
| Respetar los colores de las ilustraciones (no invertir fotos) | T | |

### 2.5 Gestos e interacción
| Función | Nivel | Notas |
|---|---|---|
| Zonas de toque configurables (izquierda/derecha, modo zurdo) | T | KOReader y Moon+ como referencia. |
| Botones de volumen para pasar página | T (iOS: limitado) | Muy pedido; en iOS solo es posible con trucos. |
| Gestos personalizados (doble tap, pellizco = tamaño de fuente, swipe vertical = brillo) | D | KOReader. |
| Teclado completo y atajos personalizables (Mac y iPad) | T (Mac) | Readest (2026), Thorium. |
| Apple Pencil: subrayar arrastrando y escribir en el margen | D | MarginNote, LiquidText, PDF Expert; Readest añadió escritura a mano. |
| Mando o clicker Bluetooth para pasar página | N | Moon+, KOReader. |
| Modo "una mano" en el iPhone Duo plegado | D | |

### 2.6 Navegación y comprensión
| Función | Nivel | Notas |
|---|---|---|
| TOC jerárquico con progreso por capítulo | T | Readwise falló aquí (enlaces del TOC rotos). |
| **Popups de notas al pie** (y volver al sitio exacto) | T→M | Apple Books, KOReader, foliate-js `footnotes.js`. Momento mágico cuando funciona con notas al final del libro mal marcadas. |
| Historial "volver atrás" tras saltar a un enlace | T | Barra de "Volver a pág. X" (Kindle). |
| **Page Flip / vista de miniaturas** sin perder tu sitio | D | Kindle. |
| Scrubber / barra de progreso con marcas de capítulos | T | |
| Diccionario al tocar (offline, monolingüe y bilingüe, importable) | T | Kindle, Apple (diccionarios del sistema), KOReader (StarDict), Readest (Yomitan). |
| Wikipedia en línea | T→D | Kindle, KOReader, Readest. |
| Traducción de selección; traducción de párrafo o libro en paralelo | D | Readest (DeepL/Yandex/LLM, 2026), Apple Translation framework (on-device). |
| **X-Ray**: personajes, lugares y términos con sus apariciones | D | Kindle, Marvin Deep View. Con un LLM local se puede generar **sin spoilers** (solo hasta tu posición). |
| **Recap "la historia hasta ahora"** sin spoilers | D→M | Kindle Story So Far / Recaps. |
| **"Pregúntale al libro"** con citas a pasajes y sin spoilers | D→M | Kindle Ask this Book, Gemini Expert Intelligence (con citas), Readwise Ghostreader. |
| Word Wise (glosas sobre palabras difíciles) | N | Kindle. Muy útil para leer en otro idioma. |
| Vocabulary builder con repaso | D | Kindle, KOReader. |
| Abrir dos libros o dos ubicaciones a la vez (split) | D | Readest Parallel Read, MarginNote. **Ideal para iPad y el iPhone Duo desplegado.** |

### 2.7 Subrayados, notas y export
| Función | Nivel | Notas |
|---|---|---|
| Subrayar con un gesto (sin menú intermedio), varios colores y estilos (highlight, underline, tachado) | T | Readest "instant mode", Kindle. |
| Subrayado que cruza páginas | T | KOReader (multi-page highlight). Fallo frecuente en apps web. |
| Notas con texto enriquecido; etiquetas | D | Readwise (tags), Readest (writing workspace). |
| Panel de anotaciones filtrable (por color, capítulo, etiqueta) | T | Readest (filtro por color al exportar). |
| **Export sin límites** a Markdown, JSON o CSV, Readwise, Obsidian, Notion y Hardcover | D | KOReader, Readest. **Kindle capa el export**: aquí tenemos un argumento de venta. |
| Copiar con cita (autor, libro, página o CFI) y deep link de vuelta al pasaje | D→M | Foliate (copiar con cita o CFI), LiquidText (enlaces bidireccionales). |
| Subrayados populares | N | Kindle (requiere red social). |
| Anotar PDF (texto, tinta, formas) y que se vea fuera de la app (anotaciones estándar PDF) | T (PDF) | PDF Expert, Zotero. |
| Notas de libro: resumen generado de mis subrayados | D | Zotero "nota desde anotaciones", Readwise. |
| **Repaso espaciado de subrayados** (FSRS) | D→M | Readwise Daily Review, MarginNote FSRS. |

### 2.8 Búsqueda
| Función | Nivel | Notas |
|---|---|---|
| Búsqueda en el libro con contexto, ignorando acentos | T | foliate-js (lenta; hay que mostrar resultados de forma progresiva). |
| Búsqueda en toda la biblioteca (texto completo) | D | Readest (estantería); el servidor con Postgres FTS es nuestra ventaja. |
| Búsqueda **semántica** ("dónde hablaba de X") en libros y subrayados | D→M | Nadie lo hace bien en local; pgvector. |
| Buscar en mis notas y subrayados | T | |

### 2.9 Estadísticas y objetivos
| Función | Nivel | Notas |
|---|---|---|
| Progreso (%) y tiempo restante | T | |
| Tiempo de lectura diario, rachas y objetivo diario o anual | T | Apple Books (Reading Goals), Kindle, Bookly. |
| Estadísticas profundas: velocidad, sesiones, calendario, tiempo por libro o página | D | KOReader (el mejor), Moon+, StoryGraph. |
| "Year in review" compartible | D/M | StoryGraph, Spotify Wrapped como patrón. |
| Sync de tracking con StoryGraph, Hardcover o Goodreads | D | Kobo → StoryGraph (2026), Readest → Hardcover. |

### 2.10 TTS y audio
| Función | Nivel | Notas |
|---|---|---|
| TTS con resaltado de palabra o frase, velocidad, voz, sleep timer y controles en la pantalla de bloqueo | T | Apple Books (VoiceOver), Readest, Moon+. |
| Voces neuronales de calidad (on-device u online) | D | ElevenReader, Speechify, Readest Voice; voces Premium de iOS gratis. |
| Detectar idioma por párrafo y cambiar de voz | D | Readest. |
| TTS en segundo plano con pantalla apagada y CarPlay | T (iOS) | |
| **EPUB 3 Media Overlays** (read-along con audio real) | D→M | Storyteller, Readest, Thorium, Apple Books. |
| **Sync audiolibro ↔ ebook** (pasar de escuchar a leer en la misma frase) | M | Kindle Whispersync for Voice (con Audible), Storyteller (self-hosted), Readest (2026). |
| Integración con Audiobookshelf | D | Readest (2026). Encaja con un servidor propio. |
| Frase a frase, A-B repeat (aprender idiomas) | N | Readest (2026). |

### 2.11 Accesibilidad
| Función | Nivel | Notas |
|---|---|---|
| VoiceOver completo (lectura continua, rotor por encabezados y enlaces) | T | Thorium y Apple Books como referentes. **Riesgo en WKWebView**: hay que asegurar que el contenido del iframe sea accesible y que la paginación no rompa la lectura continua. |
| Dynamic Type / escalado de la UI | T | |
| Fuentes para dislexia (OpenDyslexic, Atkinson Hyperlegible), interletrado amplio | T→D | Kindle (OpenDyslexic). |
| "Bionic reading" (negrita en la primera parte de la palabra) | N | Polémico; la evidencia científica es débil. Hacerlo opcional. No se verificó que Moon+ lo tenga ([búsqueda](https://github.com/simatheone/bionic-reader)). |
| Alto contraste, reducción de movimiento, sin parpadeos | T | Respetar `prefers-reduced-motion` y Reduce Motion. |
| "¿Dónde estoy?" (rastro de encabezados) | D | Thorium. |
| Teclado completo, Switch Control y Voice Control | T (Mac) | |

### 2.12 Sync, offline y biblioteca
| Función | Nivel | Notas |
|---|---|---|
| Sync de posición, subrayados, marcadores y ajustes entre dispositivos | T | El principal motivo de abandono cuando falla. |
| **Resolución de conflictos visible** ("estás más adelante en el iPad, ¿saltar a la pág. 212?") | M | Kindle "furthest page read". |
| Offline real: el libro descargado funciona sin red; las notas se encolan | T | |
| Sync con KOReader (kosync) | D | Readest. Permite usar un e-reader con KOReader como cliente más. |
| Biblioteca grande (>5.000 libros) fluida: portadas en caché, búsqueda instantánea | T | Queja habitual en Calibre-web, BookFusion y Apple Books. |
| Estantes y colecciones manuales + inteligentes (filtros: autor, serie, etiqueta, estado) | T→D | Readest (bulk tagging), Calibre. |
| Series ordenadas con "siguiente de la serie" | D | Kindle, Calibre (metadatos de serie). |
| Detección de duplicados | N | ReadEra. |
| OPDS y Calibre como fuente | D | Yomu, Readest, KOReader. |
| Importar desde otras apps (anotaciones de Kindle, Apple Books, KOReader, ReadEra) | D | Readest importa ReadEra (2026). **Excelente para captar usuarios.** |

### 2.13 Compartir y social
| Función | Nivel | Notas |
|---|---|---|
| **Compartir una cita como imagen bonita** (tipografía del libro, portada, colores) | D→M | Kindle (share quote), Readest (quote cards 2026), Readwise. |
| Widgets con la cita del día o el libro actual | D | Yomu, Readest Android. |
| Compartir un deep link al pasaje | D | |

### 2.14 PDF y cómics
| Función | Nivel | Notas |
|---|---|---|
| PDF fluido: zoom, selección de texto y anotación con Pencil | T | PDF Expert (PDFKit). **Recomendación: PDFKit nativo en Apple, no PDF.js.** |
| Recorte automático de márgenes, modo columna, reflow | D | KOReader, NeoReader. |
| OCR de PDFs escaneados (Live Text / Vision) | D | NeoReader, PDF Expert, MarginNote. |
| Cómics: modo panel a panel (guided view), doble página, RTL para manga | D | Kindle (Panel View), Play Books (Bubble Zoom), Readest. |
| Webtoon / scroll vertical | N | Apple Books (webtoons). |

### 2.15 IA y conocimiento (la capa que nos diferencia)
| Función | Nivel 2026 | Referentes |
|---|---|---|
| Definir o explicar una selección en contexto | T (en apps premium) | Ghostreader, Ask Gemini. |
| Recap sin spoilers hasta tu posición | D | Kindle. |
| Q&A sobre el libro con citas | D | Kindle, Gemini Notebook. |
| Q&A sobre **toda tu biblioteca y tus subrayados** | **D fuerte (casi nadie)** | Readwise chat (2026), parcialmente. |
| Insights de tus subrayados (temas recurrentes, conexiones entre libros) | **D fuerte** | Nadie en local. |
| Privacidad: IA local, sin entrenar con tus datos | D | Argumento de venta contra Amazon y Google. |

---

## 3. Momentos mágicos (por qué la gente se enamora de una app)

1. **"Continúa donde lo dejaste" en otro dispositivo, al instante y sin preguntar** (Kindle Whispersync). Es la emoción básica del ecosistema.
2. **Pasar de escuchar en el coche a leer en el sofá en la misma frase** (Whispersync for Voice, Storyteller). Readest lo está persiguiendo en 2026.
3. **La nota al pie que aparece en un popover** y desaparece sin perder el sitio.
4. **"¿Quién era este?"**: tocar un nombre y ver quién es *sin spoilers* (X-Ray, Story So Far, Ask this Book).
5. **El subrayado que vuelve**: un repaso diario que te devuelve una frase de hace meses (Readwise). Es lo que mantiene a la gente pagando Readwise.
6. **Un PDF académico que de repente es legible** en el móvil (KOReader reflow o recorte).
7. **Que el libro se sienta un libro**: page curl, tipografía con guiones, márgenes generosos y portada a toda pantalla al abrir (Apple Books).
8. **La cita compartida que queda preciosa** (quote cards).
9. **Desplegar el plegable y que aparezcan dos páginas enfrentadas** como un libro físico (Moon+ en Android; en el iPhone Duo puede ser *el* momento de la demo).
10. **"Te faltan 12 minutos para terminar el capítulo"**: permiso para seguir leyendo antes de dormir.
11. **El resumen anual de lectura** con estadísticas propias (StoryGraph, Wrapped).
12. **Todo es mío**: export completo en Markdown, sin límites ni truncados (lo contrario a Kindle).

---

## 4. Quejas comunes que hay que evitar (anti-patrones)

| Anti-patrón | Ejemplos reales | Mitigación en Biblioteca Lectora |
|---|---|---|
| **Sync que pierde subrayados o posición**, o que retrocede la posición | Apple Books + iCloud Drive ([TidBITS](https://tidbits.com/2016/03/30/ibooks-with-icloud-drive-is-unreliable-and-confusing/)); Readest (desconfianza tras cambios del cloud sync) | Servidor como fuente de verdad; anotaciones como **log append-only con IDs estables (UUID)**, merge por elemento (no por archivo), "furthest read" + confirmación, tombstones para borrados, backups. Las anotaciones se ligan al libro con **hash del archivo + CFI + texto citado** (para reanclar si cambia la edición). |
| Export capado o trampa de datos | Kindle (límite de 10–20 %) ([Readwise](https://help.readwise.io/article/47-why-are-my-kindle-highlights-truncated-ellipses)); Kobo sin export nativo; Apple Books sin API | Export total (MD, JSON, CSV), API abierta y push a Readwise. |
| PDFs feos, lentos o con selección rota | Foliate y foliate-js ("PDF experimental"), Google Play Books | PDFKit nativo en Apple; PDF.js solo en web; recorte y reflow como añadido. |
| Biblioteca grande lenta | Calibre-web, apps que escanean carpetas | Paginación en el servidor, miniaturas precalculadas, índice local (SQLite/SwiftData) y FTS en el servidor. |
| Tienda o anuncios dentro de la experiencia | Kobo (recomendaciones en la home), versiones gratis con anuncios de Moon+ y Yomu | Sin tienda; la home es "seguir leyendo". |
| Curva de aprendizaje y ajustes infinitos | KOReader, MarginNote, Moon+ | Valores por defecto excelentes + "Ajustes avanzados" plegados; presets ("Libro clásico", "Noche", "Estudio"). |
| Sensación "web" (scroll elástico raro, selección torpe, gestos que no siguen al dedo) | Readest (bugs de selección), apps Electron y Tauri | Gestos y animaciones en nativo; WKWebView solo para el render; menú de selección nativo (UIEditMenuInteraction). |
| Suscripciones agresivas o paywalls sorpresa | LiquidText, PDF Expert, Speechify, ElevenReader | (Uso personal ahora.) Si se publica: precio claro y funciones locales sin muro. |
| IA que hace spoilers o no cita | Recaps de Kindle (con aviso) | Contexto limitado a la posición actual y citas con enlace al pasaje. |
| Conversión que rompe el formato | Send to Kindle (EPUB → KFX) | Leer el EPUB original; nunca convertir para leer. |
| Ajustes que no se aplican o cambian tras actualizar | Apple Books en iOS 26 | Migraciones de ajustes testeadas; ajustes por libro visibles. |
| Abandono del desarrollo | Marvin, Lithium | (Proyecto personal: arquitectura simple y dependencias mínimas.) |

---

## 5. Implicaciones para Biblioteca Lectora (recomendaciones)

**MVP de lectura (table-stakes que no se pueden fallar):**
1. Paginado con slide interrumpible a 120 Hz + scroll; tipografía con hyphenation en español (`lang` + `hyphens:auto`, valorar Hyphenopoly si WebKit no basta), justificación, márgenes y ancho de línea, 4–6 fuentes curadas + fuentes propias, temas claro/sepia/oscuro/OLED.
2. Footnote popovers, TOC, barra de progreso, "tiempo restante en el capítulo", historial de saltos.
3. Subrayado instantáneo multicolor, notas, panel filtrable, export Markdown + push a Readwise.
4. Diccionario del sistema (UIReferenceLibraryViewController), traducción on-device (Translation framework), Wikipedia.
5. Sync de posición y anotaciones contra el servidor con resolución de conflictos visible, y offline.
6. VoiceOver correcto, Dynamic Type en la UI, Reduce Motion.
7. Dual-page automático al desplegar el iPhone Duo y en iPad horizontal.
8. PDF con PDFKit en Apple.

**Diferenciadores (v1–v2):**
- **Ask / Recap / X-Ray sin spoilers con LLM local**, con citas que enlazan al pasaje (RAG por capítulo hasta la posición actual).
- **Insights de subrayados entre libros** y **repaso espaciado (FSRS)** en la app.
- **Media Overlays + Storyteller** en el servidor → read-along con audiolibros propios; valorar Audiobookshelf.
- Estadísticas al nivel de KOReader + resumen anual; sync con Hardcover o StoryGraph.
- Quote cards como imagen; widgets de la cita del día.
- Búsqueda semántica en toda la biblioteca.
- Compatibilidad **kosync** para que un Kindle/Kobo con KOReader sea otro cliente.

**Riesgos técnicos detectados con foliate-js** (ver §1.7): sin scroll continuo entre capítulos, paginador y búsqueda lentos, API inestable (conviene fijar un commit y hacer un fork), EPUB mixtos no soportados, y la desofuscación de fuentes requiere contexto seguro (servir el libro por un `WKURLSchemeHandler` propio). Readest es la prueba de que se puede construir un producto completo encima y una fuente de parches y patrones (selección de texto, TTS, paginación de PDF).

---

## 6. Fuentes principales

- Kindle IA: [About Amazon – Recaps](https://www.aboutamazon.com/md/news/books-and-authors/kindle-recaps-feature-ebook-series-refreshers) · [Thurrott](https://www.thurrott.com/?p=319397) · [Tom's Guide – Ask this Book](https://www.tomsguide.com/computing/e-readers/amazon-adds-ai-chatbot-to-the-kindle-app-which-offers-spoiler-free-answers-about-your-ebooks) · [Business Standard](https://www.business-standard.com/technology/tech-news/amazon-kindle-ask-this-book-feature-spoiler-free-answers-125121600444_1.html) · [Shopifreaks – Story So Far](https://www.shopifreaks.com/amazon-rolls-out-its-ai-story-so-far-recap-feature-to-kindle-devices-and-the-ios-app-to-help-readers-catch-up/) · [Android Authority](https://www.androidauthority.com/amazon-kindle-story-so-far-ask-this-book-3603120) · [the-ebook-reader (jun-2026)](https://blog.the-ebook-reader.com/2026/06/09/new-story-so-far-feature-rolling-out-to-kindle-ereaders-and-apps/) · [Engadget](https://engadget.com/2202142/kindle-app-features-ios-has-ereader-still-doesnt-have)
- Kindle export: [Readwise Help](https://help.readwise.io/article/47-why-are-my-kindle-highlights-truncated-ellipses) · [HN](https://hn.nuxt.dev/item/49424758)
- Google: [Android Authority teardown](https://www.androidauthority.com/google-play-books-ask-gemini-apk-teardown-3624252) · [Gigazine](https://gigazine.net/gsc_news/en/20260828-expert-intelligence-gemini/) · [Tom's Guide](https://www.tomsguide.com/ai/google-gemini/google-just-gave-gemini-access-to-your-ebooks-7-prompts-for-readers-and-students)
- Kobo: [Kobo blog](https://www.kobo.com/blog/product-features) · [Kobo news](https://us.kobobooks.com/blogs/news/new-kobo-app-ereader-features) · [Readwise Kobo docs](https://docs.readwise.io/readwise/docs/importing-highlights/kobo)
- Apple Books: [getbookshelves](https://getbookshelves.app/guides/best-epub-reader-iphone-ipad/) · [Macworld](https://www.macworld.com/article/1447641/apple-books-ai-narration-audiobooks.html) · [TidBITS](https://tidbits.com/2016/03/30/ibooks-with-icloud-drive-is-unreliable-and-confusing/)
- Readest: [GitHub](https://github.com/readest/readest) · [Releases](https://github.com/readest/readest/releases) · [marlvel.ai reviews](https://marlvel.ai/apps/readest-ebook-reader/reviews)
- foliate-js / Foliate: [foliate-js](https://github.com/johnfactotum/foliate-js) · [OMG! Ubuntu](https://www.omgubuntu.co.uk/2023/11/foliate-ebook-app-major-update)
- KOReader: [GitHub](https://github.com/koreader/koreader) · [Wiki](https://github.com/koreader/koreader/wiki/) · [LWN](https://lwn.net/Articles/891494) · [dsebastien](https://www.dsebastien.net/koreader/) · [Releasebot](https://releasebot.io/updates/koreader)
- Thorium: [EDRLab accesibilidad](https://thorium.edrlab.org/en/th3/500_accessibility/)
- Storyteller: [RuntimeWire](https://runtimewire.com/article/storyteller-v3-ctc-aligner-immersive-reading) · [Tildes v2](https://tildes.net/~books/1q2s/storyteller_v2_is_now_available) · [App Store](https://apps.apple.com/app/storyteller-reader/id6474467720)
- Readwise Reader: [docs](https://docs.readwise.io/reader) · [jun-2025](https://readwise.io/reader/update-june2025) · [ago-2026](https://readwise.io/reader/update-aug2026) · [changelog](https://docs.readwise.io/changelog)
- Otros: [Yomu](https://apps.appfollow.io/ios/yomu-ebook-reader/562211012?country=us) · [BookFusion pricing](https://www.bookfusion.com/reading/pricing) · [Moon+ (Technipages)](https://www.technipages.com/moon-reader-pro-complete-guide) · [Librera F-Droid](https://f-droid.org/en/packages/com.foobnix.pro.pdf.reader/) · [PocketBook](https://pocketbook.ch/en-ch/news/unlock-the-full-potential-of-your-pocketbook-ch) · [NeoReader](https://shop.boox.com/en-au/blogs/news/6-tips-for-productive-ebook-reading-with-neoreader) · [MarginNote](https://apps.apple.com/us/app/marginnote-4-ai-notes-mindmap/id1531657269) · [LiquidText Capterra](https://www.capterra.ca/reviews/1033403/liquid-text) · [PDF Expert](https://thesweetbits.com/pdf-expert-review/) · [Zotero 7](https://www.zotero.org/blog/zotero-7/) · [Speechify](https://www.roborhythms.com/speechify-review-2026/) · [ElevenReader](https://elevenlabs.io/docs/it/help-center/product/mobile-apps/eleven-reader/what-is-eleven-reader) · [Trackers 2026](https://unstar.app/blog/goodreads-storygraph-fable-hardcover-bookly-reading-tracker-apps-ranked-2026)

> **Limitaciones de esta investigación:** el fetch directo de muchas webs (App Store, prensa, Reddit) falló por DNS en el entorno; los datos vienen de los extractos del buscador y de GitHub (sí accesible). Reddit casi no se pudo consultar directamente. Los precios y las fechas marcados con ⚠️ deben verificarse antes de usarlos en decisiones.
