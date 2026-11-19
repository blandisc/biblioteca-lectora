# Continuar el trabajo (paquete de la sesión del 18–19 nov 2026)

Para retomar en el Mac con Claude Code: abre esta carpeta y di
«Lee docs/continuar.md y sigue». Todo lo de esta sesión está en la rama `app-esqueleto`.

## Cómo trabajar aquí
- Reglas: `CLAUDE.md`, `docs/sistema-diseno.md` (obligatorio), `docs/entrega.md` (cómo
  decir «listo»), `docs/arquitectura.md` (decisiones D1–D8 y fases; manda sobre el PRD).
- Antes de subir: `swift test --package-path Packages/LectoraCore` (incluye
  `DesignRulesTests`) y `scripts/lint-design.sh`.
- En el Mac ya se puede lo que la nube no podía: `brew install xcodegen`,
  `./scripts/fetch-foliate.sh`, `xcodegen generate`, abrir `Lectora.xcodeproj` y correr en
  el simulador o en tu iPhone. Capturas: `./scripts/screenshots.sh out/prueba`
  (opciones de arranque en `App/Shared/LaunchOptions.swift`).
- CI (`.github/workflows/ci.yml`): núcleo y compilación iPhone/Mac en cada push. Las
  capturas (`capturas.yml`) ahora son solo a mano, para no llenar el correo.
- Commits en español; terminan con las líneas `Co-Authored-By` y `Claude-Session`.

## Dónde quedó
Fase A (cerrar la app de iPhone) casi completa. Hecho y en verde en CI hasta `80d836d`:
coordinación entre dispositivos (JobBoard, D7), sesiones y diario, notas en el Cuaderno,
herramientas del lector (índice, buscar, subrayados), Readwise de ida y vuelta y Hardcover
de ida (sin probar contra los servicios reales), migración de Calibre, bienvenida.

Último trabajo (`4173da4` + arreglo `9193c9c`, CI pendiente al empaquetar):
1. Subrayados sin posición (Calibre, Kindle vía Readwise) se anclan buscando su cita al
   abrir el libro: `reader.js` `anchor(items)`, `ReaderController.anchorPending()`
   (intentados en UserDefaults `subrayados.anclajeIntentado`).
2. Marcadores guardados en el registro (`LectoraCore/Model/Bookmark.swift`,
   `EntityKind.bookmark`, `LibraryStore` add/remove), cinta en el lector y la sección
   Lector › Marcas (`ReaderToolsSheet`).
3. Audiolibro escondido: `Features.audiobook` (Guiada, Escuchar, audífonos de la Mesa,
   mini reproductor) hasta la fase C.

## Verificado en el Mac (18 nov 2026, noche)
- Simulador propio «Gabinete» (iPhone 17 Pro, adelgazado con simslim). Compilación en
  `/tmp/dd-gabinete`. Para tocar la pantalla sirve la herramienta del panel de simulador
  de Claude Code; AXe falla en el simulador adelgazado.
- Arreglado: la app se cerraba la primera vez que abrías un libro desde el principio
  (foliate da NaN en secciones de dos páginas; ahora todo avance pasa por
  `readingFraction`). La cinta ahora se decide en reader.js comparando el marcador con
  toda la página (`setBookmarks` / `bookmarksOnPage`). La prueba de Hardcover ya no
  depende de la zona horaria.
- Visto en claro y oscuro: poner y quitar la cinta, que siga al agrandar y achicar la
  letra, Lector › Marcas, y sin botones de audiolibro (Mesa y ficha).
- Resuelto el 19 nov: con los controles abiertos la cinta ya no se dibuja (tapaba la
  batería; ahí lo dice el ícono relleno del marcador). Pendiente: el subrayado de muestra «de Readwise» no se ancla porque su cita termina
  en punto y el libro dice «astillero,»: ¿anclar ignorando la puntuación final?

## Pulida visual (19 nov 2026)
Pasada pantalla por pantalla en el simulador, en claro y oscuro (capturas con
`-screenshot.screen`; ahora también `settings`, `marks` y `appearance`). Arreglado:
- Buscar no tenía dónde escribir (el campo de `.searchable` quedaba escondido): ahora
  `SearchField` bajo el título.
- Ajustes y los demás formularios salían en el gris frío del sistema y sus botones, casi
  negros en claro, parecían texto: `.formScreen()` (papel y acciones en verde hoja). El
  título grande es ahora igual a los demás (New York 30 medium).
- Grises de texto con poco contraste (secundario 4,35 y terciario 2,75 : 1): ajustados.
- 35 medidas armadas sumando tokens: ahora tienen nombre (`inline`, `rowY`, `rowGap`…).
- Porcentajes: la Mesa decía «2 %» y el lector «3%» del mismo libro; todo sale de
  `percentText` («3 %»).
- «Donde lo dejaste» ya no empieza con el título del capítulo; «Listo para leer» ya no
  aparece junto a un libro empezado; el índice A–Z solo con 15 libros o más; la
  explicación de «Por revisar» solo si hay libros dudosos; puntos suspensivos dobles en
  Lector › Buscar; el «+» verde va al final del encabezado (Cuaderno) y Ajustes usa un
  engrane; sin «Pronto…» ni «Próximamente».
Cada regla tiene su prueba en `DesignRulesTests` y su fila en `docs/sistema-diseno.md`.

## Primero, al llegar al Mac
1. Ver que CI del último commit de `app-esqueleto` pasó.
2. Con un EPUB que tenga subrayados de Calibre: que se pinten al abrir (no probado aún).
3. Probar Readwise y Hardcover con tus llaves reales (Ajustes › Conexiones). Es lo único
   de la fase A que solo se ha probado contra respuestas escritas a mano.
4. Migración con tu `metadata.db` real (Ajustes › Gabinete › Traer de Calibre).
5. Hecho el 19 nov: instalada en el iPhone de Fer (Release, identificador
   `mx.iracheta.gabinete`, equipo B7KRCF776Z, el mismo de Orbital). Para reinstalar:
   `xcodebuild build -project Lectora.xcodeproj -scheme Lectora_iOS -configuration Release
   -destination 'id=<udid>' -derivedDataPath /tmp/dd-gabinete-release -allowProvisioningUpdates`
   y `xcrun devicectl device install app --device <udid> /tmp/dd-gabinete-release/Build/Products/Release-iphoneos/Gabinete.app`.

## Lo que sigue (propuesto)
- «Buscar en todo»: notas y subrayados además de libros.
- Editor de notas con formato en vivo.
- Fase B: el Mac como administrador (tabla tipo Calibre), convivencia con Calibre,
  Kindle (`My Clippings.txt`, enviar a Kindle), web servida por el Mac (D8).

## Lienzos y sistema de diseño (artifacts de claude.ai)
- Identidad: https://claude.ai/artifact/68U8tq9yioAXrcS4iQKGAm
- Diario de lectura: https://claude.ai/artifact/EFtPKrZotji3c7J7vqMVmN
- Sistema de diseño: https://claude.ai/artifact/UyHzDh55DSnZ8WH6HDg8Ng

Identidad cerrada: v2 con toques verdes sutiles (brand en botón principal, avance y
pestaña; accent verde hoja), Cinzel solo en la marca y los rótulos, oscuro neutro. No
reabrir.
