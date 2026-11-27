# Auditoría del sistema de diseño de Gabinete (iPhone y Mac)

Fecha: 26 nov 2026 · Copia revisada: `.claude/worktrees/gabinete-continuacion-verificacion-7f1ee5` (commit `cb0a649`) · Solo lectura: no se tocó ningún archivo del repo.

**Qué se revisó:** todo `App/Shared` (Screens, Mac, Reader, Design, Library, Model, RootView, AppModel, LectoraApp), `App/Resources/Reader/reader.js` y `reader.html`, contra `docs/sistema-diseno.md`, `Theme.swift`, `Components.swift`, `scripts/lint-design.sh`, `DesignRulesTests.swift` y `tools/sistema-base` (SB-1 a SB-4). Se buscó con grep archivo por archivo, sin muestreo. La carpeta `foliate/` (biblioteca de terceros) quedó fuera.

**Prioridad:** **Alta** = quien lee lo nota en el uso normal, o la misma cosa se comporta distinto en iPhone y en Mac. **Media** = se nota en algunas pantallas, o deja abierta una puerta para que el desorden vuelva. **Baja** = limpieza, o algo que solo se ve en casos raros o en modo de pruebas (DEBUG).

---

## 0. Por qué el lint pasa y aun así hay huecos

1. **No mira todos los archivos.** `scripts/lint-design.sh` deja fuera `AppModel.swift`, `LectoraApp.swift`, `LaunchOptions.swift`, `Library/*`, `Model/*` y, del lector, `PageCurl.swift`, `ReaderController.swift`, `SlitScreen.swift` y `AnnotationStore.swift`. Las pruebas de `DesignRulesTests` (`screens` + `pieces`, DesignRulesTests.swift:38-49) son todavía más cortas: dejan fuera **toda la Mac**, además de `LookupCard`, `SlitScreen`, `PageCurl` y `ReaderController`. Por eso en la Mac no corren la regla del verde, la de piezas del catálogo (vacíos del sistema, `borderedProminent`), la de fuentes ni la de animaciones.
2. **Los patrones se pueden esquivar:**
   - `Font\.custom` no detecta `.font(.custom(` (Components.swift:1337).
   - `Color\.(white|black)` no detecta `.black.opacity` (CoverView.swift:80, 90, 95).
   - Hay modificadores que ninguna regla mira: `.brightness(`, `.blur(`, `.rotationEffect(`, `lineLimit(n)`, `prefix(n)`, y aritmética de tokens con `*` (`Theme.Space.l * …`).
   - `Task.sleep(for: .seconds(1.5))` pasa porque solo se vigila `withAnimation`.
3. **La concordancia de cifras (`testCountsAgreeWithTheirNumber`) tiene tres huecos:**
   - `\\\([^)]*\)` no cruza paréntesis anidados, así que `\(ReadingFormat.words(x)) palabras` se escapa.
   - La lista de sustantivos no trae *días, resultados, estrellas, opciones, archivos, capítulos, grupos, encontrados*.
   - Descarta toda línea que contenga `== 1`.
4. **El revisor común (SB-2) solo vigila 10 nombres** de `Theme.Space` (`sistema-base.json` → `tokens.patron`). `gutter`, `rowY`, `rowGap`, `buttonX` y los márgenes de `Theme.Reader` no entran. Además `reader.js` no está declarado como fuente web, así que SB-2 y SB-3 no revisan el CSS del lector.

---

## 1. Valores sueltos que el lint no ve

### A1 · Alta · Las guardias no ven la Mac ni medio lector
- Archivos fuera de `lint-design.sh`: `App/Shared/AppModel.swift`, `LectoraApp.swift`, `LaunchOptions.swift`, `Library/*.swift` (7), `Model/*.swift` (4), `Reader/PageCurl.swift`, `Reader/ReaderController.swift`, `Reader/SlitScreen.swift`, `Reader/AnnotationStore.swift`, `Reader/ReaderSchemeHandler.swift`.
- Fuera de `DesignRulesTests` (screens/pieces): los 7 archivos de `Mac/`, `Reader/LookupCard.swift`, `Reader/SlitScreen.swift`.
- **Arreglo:** una sola lista de fuentes, la misma para el lint y para la prueba (por ejemplo `scripts/design-sources.txt`, o «todo `App/Shared` menos `Theme.swift` y la paleta de `ShelfBook`»). Que `testSourcesAreFound` falle si un `.swift` nuevo de `App/Shared` no está cubierto.

### A2 · Media · Cinzel escrita a mano
- `Components.swift:1337`: `.font(.custom("Cinzel", size: Theme.Size.artHubLetter, relativeTo: .title3))`, la «G» de `ConnectionsArt`. Rompe la regla «Cinzel solo por `BrandMark` y `SectionLabel`», y ni el lint ni `testRomanCapsOnlyForMarkAndLabels` la ven.
- **Arreglo:** un token `Font.hubLetter` en `Theme.swift`, y el patrón `\.custom\(` en las dos guardias.

### A3 · Media · Estilos del sistema fuera de la lista del documento
El documento dice: SF `.body`, `.subheadline`, `.footnote`, `.caption`. Se usan además:
- `.title3`: Components.swift:90 (acciones de `ScreenHeading`), :502 (`RoundIconButton`), :2713 (`OptionRow`); MiniPlayer.swift:46.
- `.title2`: ReaderAppearance.swift:406 (la «A» grande).
- `.headline`: MacBookInspector.swift:49 (título del libro), :96.
- `.callout`: MacLibraryWindow.swift:116; MacDuplicatesView.swift:66, :70.
- `.caption2` (11 pt) en íconos: Components.swift:632 (nube de iCloud), :2119 (palomita del pie), :2344 (`TrailingIconLabelStyle`). Es legal según la prueba, pero no tiene nombre.
- **Arreglo:** tokens `Font.icon` (= `.title3`) y `Font.badge` (= `.caption2.weight(.semibold)`), y en la Mac el título del libro en `.rowTitle` (ver C12). Prueba: lista blanca de estilos en `.font(` para pantallas, piezas y Mac.

### A4 · Baja · Pesos que derivan
- `subheadline.weight(.medium)` aparece 9 veces y `.semibold` 2.
- `caption.weight(.medium)` 9 y `.semibold` 2, además de `.caption.weight(isToday ? .semibold …)`.
- `footnote.weight(.semibold)` 5 y `.medium` 1.
- Para el mismo papel («etiqueta de acción») se usan medio y semi.
- **Arreglo:** dos tokens con nombre, `Font.action` (subheadline medium, que ya usan `TextAction`, `FilterBar` y `SegmentedChoice`) y `Font.tag` (caption medium).

### A5 · Alta · El título de pantalla no crece con el tamaño de letra
- `Theme.swift:532`: `Font.screenTitle = Font.system(size: 30, …)` es fijo. Todo lo demás (`bookTitle`, `rowTitle`, `prose`) sí sigue el tamaño de texto de iOS.
- `LectoraApp.swift:12-14` repite el 30 con `UIFont.systemFont(ofSize: 30)` para los títulos grandes, en un archivo que el lint no mira.
- **Arreglo:** `Font.system(.largeTitle, design: .serif, weight: .medium)`, o el 30 con `relativeTo: .largeTitle` vía `UIFontMetrics`. El tamaño, una sola vez en `Theme` (`Theme.Type.screenTitle`), y que `LectoraApp` lo lea de ahí.

### A6 · Media · Colores del sistema o sin token
- `.secondary`: MacBookInspector.swift:50, 52, 98. Debe ser `Theme.secondaryInk`.
- `.black.opacity(…)` en CoverView.swift:80, 90, 95. Es sombra de objeto y se justifica, pero no tiene nombre: `Theme.shadow`.
- `UIColor.systemBackground` como papel por omisión en PageCurl.swift:24, 587, 626 y ReaderController.swift:162. Antes de que llegue la paleta, la hoja se dibuja en blanco o negro del sistema y no en `paper`, lo que puede dar un destello en «Noche cálida». Por omisión debe ser `UIColor(Theme.paper)`.
- PageCurl.swift:373, 397, 643: `UIColor.black` para la sombra, la penumbra y el lomo. Es aceptable, pero merece un token `Theme.Reader.shade`.
- `Theme.accent` directo en la Mac: MacLibraryWindow.swift:101 (ícono del aviso), MacDuplicatesView.swift:62, 70. Regla 1: ninguna guardia lo ve.

### A7 · Media · La paleta del lector copia los colores de la app
- `ReaderAppearance.swift:179`: `paper` = `0xF8F7F4` / `#1C1B19`, copia a mano de `Theme.paper` / `Theme.ink` (claro).
- `:181`: `darkPaper` = `0x161514` (copia de `Theme.paper` oscuro), pero el texto `#DAD6CE` ≠ `Theme.ink` oscuro (`#ECE9E2`). En «Auto» de noche, el libro y la app no tienen la misma tinta.
- La excepción «paleta del lector» cubre colores propios del lector (Noche cálida, Negro), **no copias** de Theme. Si alguien cambia `Theme.paper`, el libro se queda con el color viejo.
- `:193`: la noche automática se decide con `hour >= 20 || hour < 7`, horas sueltas.
- **Arreglo:** que `Theme` exponga los hex como fuente única (igual que `Theme.Green`) y que `ReaderPalette.paper` y `.darkPaper` se armen desde ahí. Agregar `Theme.Reader.nightFrom` y `nightUntil`.

### A8 · Baja · Excepción que ya no se justifica
- `Components.swift:2634` (`SearchResultRow`, `// ds-exception: lo buscado`) arma a mano el verde con negritas. `Found.marked` (Components.swift:2880) hace exactamente eso y ya lo usan `QuoteBlock` y `NoteRow`.
- **Arreglo:** `Text(Found.marked(lead + match + tail, match))`, y quitar la excepción con su fila en la tabla «Excepciones».
- Las otras excepciones siguen justificadas: portada dibujada, fuente del lector, índice A–Z, segmentado de `Form`, portadas generadas y fondos propios del lector.

### A9 · Media · Números dentro de piezas que el patrón no mira
- `SeriesStack`: `.brightness(-0.1)` y `.brightness(-0.05)`, Components.swift:651, 653 → `Theme.CoverArt.stackShade1/2`.
- `EqualizerBars`: `[0.5, 1.0, 0.7]` y `.phaseAnimator([1.0, 0.4])`, Components.swift:2318, 2322 → `Theme.Size.equalizerBars`.
- `ScrubberBar`: `step = 0.01`, Components.swift:2264.
- CoverView.swift:141 (`0.9`) y :151 (`96`, `104`): medidas del dibujo, a `Theme.CoverArt`.
- Aritmética de tokens con `*`: `Theme.Space.l * CGFloat(min(depth, …))`, Components.swift:2615 (`ContentsRow`) → `Theme.Space.indent`. `testNoArithmeticBetweenTokens` solo mira `+ - /`.
- Tokens de espacio usados como tamaño: `icon.frame(height: Theme.Space.xl)` (Components.swift:216, `IconTile`) y `Hairline().frame(width: Theme.Space.xxxl)` (:1483, `Colophon`) → `Size.tileIcon` y `Size.colophonRule`.

### A10 · Media · Constantes locales escondidas en las pantallas
| Dónde | Valor | Token propuesto |
|---|---|---|
| LibraryScreen.swift:7 | `letterIndexMinimum = 15` | `Theme.Size.letterIndexMinimum` |
| ReaderAppearance.swift:413-414 | `scales 0.8...1.6`, `scaleStep 0.1` | `Theme.Reader.textScales`, `textScaleStep` |
| MiniPlayer.swift:26, 38 | `chapterProgress = 0.38`, texto fijo «Cap. VII · quedan 18 min» | datos reales o no mostrar (ver D10) |
| BookDetailScreen.swift:110 / :164 | `prefix(5)` sesiones / `prefix(3)` subrayados | `Theme.Reader.detailSessions`; reusar `foundHighlights` (= 3, el mismo «los primeros 3» de Buscar) |
| NoteScreen.swift:37, 40 | `prefix(20)`, `prefix(4)` | `Theme.Reader.linkSuggestions` |
| DiaryScreen.swift:121, 179, 222 | `prefix(2)`, `0.02`, `0.99` | nombrados en `Theme.Reader` o en LectoraCore |
| MesaScreen.swift:136 | `20 * 60` (sesión larga) | `Theme.Reader.longSession` |
| SearchScreen.swift:30, 42, 90, 99 | `term.count >= 2` (4 veces) | **choca** con `Theme.Reader.searchMinLetters = 3` (buscar en el libro) y con reader.js:879 (`< 2`). Un solo valor |
| ReaderToolsSheet.swift:231 | `300` (y en el texto «Los primeros 300») | igual a reader.js:896 y :908. `Theme.Reader.searchCap`, mandado al JS |
| SettingsScreen.swift:274 · CalibreMigrationScreen.swift:175 | `prefix(5)` · `prefix(10)` | `Theme.Reader.listPreview` (uno) |
| Model/CandidateText.swift:9 | `0.65` («Probable») | `MetadataMatcher.probable` en LectoraCore |

### A11 · Baja · Tiempos sueltos
- ReaderController.swift:553 `Task.sleep(.seconds(1.5))` (cuándo se da por asentada la posición) → `Theme.Reader.positionSettle`.
- Solo en DEBUG o en capturas (aceptable, pero sin nombre): MacBookTable.swift:64, MacLibraryWindow.swift:208, SettingsScreen.swift:123, ReaderView.swift:545-597 y :980.
- Fuera de la interfaz (sin efecto visual): SessionStore.swift:54, NotesStore.swift:35, LibraryStore.swift:185 (3 s), CabinetLocation.swift:135 (0,5 s), Connectors.swift:182 (60 s).

### A12 · Media · La escala de la casa (SB-2) incumplida con otro nombre
- `Theme.Space.gutter 28`, `rowY 10`, `rowGap 14`, `buttonX 20` (Theme.swift:115-121).
- `Theme.Reader.pageMarginTop 12`, `fadeDrift 12`, `textMargin 28`, `folioFadeDrop 20`, `panelInset = textMargin - chromeInset` (= 12, aritmética **dentro** de Theme, :354).
- Ninguno está en 0 · 4 · 8 · 16 · 24 · 32 · 48 · 64, y el revisor no los ve porque `sistema-base.json` solo vigila `xxs|xs|s|m|l|xl|xxl|xxxl|hair|inline`. La nota «_» de ese archivo sigue diciendo que «los espacios 2, 6 y 12 se quedan con trinquete», y `m` e `inline` ya no existen.
- **Arreglo, se decide:**
  - (a) declararlos en `sistema-base.json → excepciones` con su porqué (el margen de 28 es una decisión de diseño), o
  - (b) moverlos a la escala (28→24 o 32, 10→8, 14→16, 20→16 o 24).
  En cualquier caso, ampliar `tokens.patron` a todo `static let …: CGFloat` de `Space`, y actualizar la nota.

### A13 · Media · El lector web (reader.js) tiene ~40 números propios
- **SB-3 roto:** el separador de página en continuo usa `font: 500 0.72rem/1` (reader.js:47). Con el tamaño base son ≈ 11,5 px, menos que el mínimo de 12. El revisor no lo ve por dos razones: `CSS_LETRA` solo busca `font-size:` (no el atajo `font:`) y `reader.js` no está declarado como fuente.
- **Dos opacidades para la misma tinta tenue:** el separador usa `${textColor}a6` (65 %) y la línea `38` (22 %), con un respaldo `rgba(128,128,128,…)` (reader.js:42-43). El folio de la app usa `Emphasis.folio` 0,74.
- **Valores que la app ya nombra o debería mandar:**
  - `lineHeight: 1.45` (:11): el documento lo cita, `Theme` no.
  - `margin: 48` (:27): por omisión, distinto de `pageMarginTop`/`Bottom`.
  - `maxInlineSize: 720` (:15).
  - `fontFamily: 'Literata, …'` (:14): Literata no está en `App/Resources/Fonts`.
- **Lápiz:** `stroke-width '1.6'` (:130) y `width: 1.5` (:886), dos gruesos. Al dibujar: `520 / 140 / 1.1 / 0.85` y `cubic-bezier(0.33, 1, 0.68, 1)` (:519-520).
- **Movimiento:** `glide` de 260 ms con curva cúbica (:396). Es casi `Motion.standard` (0,25 s), pero está duplicado.
- **Marcador en continuo:** `tab = 10`, `h = lineHeight * 1.25`, `0.84`, y paradas del degradado `0.7 / 0.55` (:546, :551-553, :566).
- **Capítulo:** `1.45em`, `1.25`, `0.3em`, `1em`, `1.4em`, `❦ 0.7em` con opacidad `0.5`, letra capital `3.3em / 0.85 / 500`, `padding .06em .08em` (:300-317).
- **Esperas:** `1500`, `600`, `80` ms (:811, :850, :858). `pullThreshold 64` (:188), `160`, `1500`, `80`, `3` (:225, :268, :289, :291).
- **Búsqueda:** `text.length < 2` (:879) contra `searchMinLetters = 3` en Swift; tope de `300` (:896, :908).
- **Arreglo:** un bloque `tokens` en reader.js que la app manda con `setStyle` (desde `Theme.Reader`/`Theme.Emphasis`). Una prueba que falle si reader.js trae un número fuera de ese bloque, como ya se hace con los colores en `testOneGreenForEverything`. Y declarar reader.js en `sistema-base.json` como fuente web.

---

## 2. Patrones repetidos que deberían ser pieza o receta

### B1 · Alta · Tres maneras de anunciar una sección (choca con la regla 3)
- La regla 3 dice: «Toda sección se anuncia igual: mayúsculas chicas, espaciadas, con su línea a la derecha» (`RuledLabel`).
- En la práctica, `RuledLabel` solo vive dentro de `QuoteBlock` y `EmptyState` (Components.swift:784, 858). Todas las secciones de las pantallas usan `SectionLabel` (Cinzel, sin línea): **unos 35 usos**, en ReaderAppearance.swift:306, 342, 357 · LookupCard.swift:96 · CalibreMigrationScreen.swift:106, 124, 154, 165 · ReaderView.swift:724, 1038 · SearchScreen.swift:113, 127, 193 · MesaScreen.swift:86, 116 · ReaderToolsSheet.swift:192, 247, 266 · NotebookScreen.swift:152 · ReviewScreen.swift:74 · DiaryScreen.swift:124, 166, 190, 209, 231, 259, 314 · BookDetailScreen.swift:99, 125, 158 · SessionSheet.swift:32, 126, 210 · NoteLinkSheet.swift:26, 58.
- Una tercera forma, texto `.caption` gris hecho a mano: ReviewScreen.swift:142 («Tus datos ahora»), :167 («Encontrados en internet»), :259 («Portada»), :274 («Lo que cambia»). Y `PeriodStepper` alterna las dos (DiaryScreen.swift:259).
- Se nota en la misma Mesa: «DONDE LO DEJASTE» (SF con línea) junto a «ESTA SEMANA» y «EN LA MESA» (Cinzel sin línea).
- **Arreglo:** una pieza `SectionHeader(title:) { trailing }` (= `RuledLabel` con algo opcional a la derecha), en todas las secciones. `SectionLabel` queda solo para «Nº 7» y la marca. Prueba: `SectionLabel(` prohibido en `Screens/` salvo «Nº».

### B2 · Alta · Encabezado de sección con algo a la derecha, hecho a mano
- BookDetailScreen.swift:124-133: «Notas» con «Nota nueva», hecho con `Text().fontWeight(.medium).frame(minHeight:)` en vez de `TextAction`.
- BookDetailScreen.swift:157-163: «Subrayados» con `Text("\(count)")`.
- ReviewScreen.swift:73-77: «Se completaron solos» con «Todo bien».
- SessionSheet.swift:31-44: «Esta sesión» con ✕.
- SearchScreen.swift:191-198: una función `section()` local.
- ReaderToolsSheet.swift:247 y :266.
- **Arreglo:** el mismo `SectionHeader` de B1, con `trailing`.

### B3 · Alta · La alerta de error está copiada 13 veces
Siempre el mismo `Binding(get: { error != nil }, set: …)` con un botón de cancelar y `Text(error ?? "")`:
- MacBookInspector.swift:31 · MetadataEditorView.swift:129 · BookDetailScreen.swift:235 · CalibreMigrationScreen.swift:48 · ConnectorScreen.swift:32 · NoteLinkSheet.swift:45 · NoteScreen.swift:74 · ReviewScreen.swift:324, 457 · SettingsScreen.swift:169 · WelcomeScreen.swift:87 · ReaderView.swift:299.
- Lo mismo para los avisos: ReaderView.swift:304 · SessionSheet.swift:105, 166 · DiaryScreen.swift:332 · RootView.swift:71 · SettingsScreen.swift:161 · RulesScreen.swift:64.
- **Arreglo:** dos modificadores en Components, `.errorAlert(_ title:, message: $error, back: "Volver a …")` y `.noticeAlert(_ title:, message: $notice, back:)`. Prueba: `.alert(` prohibido en pantallas fuera de ellos (salvo los que piden un texto: nota, estante).

### B4 · Media · «Cargando» armado a mano
- `HStack { ProgressView(); Text(…) }` en BookDetailScreen.swift:198-202, ReviewScreen.swift:150-157, SettingsScreen.swift:196-200, WelcomeScreen.swift:163 y ConnectorScreen.swift:62.
- `ProgressView()` sin texto (SB-1: «una carga dice qué carga»): ReviewScreen.swift:264, 296 · ReaderView.swift:92 · CalibreMigrationScreen.swift:67 · Components.swift:1712.
- **Arreglo:** una pieza `LoadingLine(text:)`, con el texto obligatorio.

### B5 · Media · El botón ✕ de cerrar, copiado
- Tres copias idénticas (footnote semibold, `secondaryInk`, 44, `padding(.vertical, -s)`): LookupCard.swift:36-45 · ReaderView.swift:847-856 · SessionSheet.swift:34-44.
- Dos en vidrio: SlitScreen.swift:43-49 · ReaderView.swift:173-182.
- **Arreglo:** `CloseButton(label:, style: .plain | .glass)`, con el nombre de lo que cierra («Cerrar la consulta»).

### B6 · Media · Filas de libro hechas a mano
- Título en serif con detalle en `.footnote`, fuera de `BookRow`: CalibreMigrationScreen.swift:166-169 · NotebookScreen.swift:157-160 (libros de Readwise) · ReviewScreen.swift:248 · ReaderAppearance.swift:315-316 · MacDuplicatesView.swift:63-68.
- `BookRow` con la flecha (chevron) a mano: ReviewScreen.swift:86-88.
- **Arreglo:** `TitleDetailRow(title:, detail:)` (lo que no es un `ShelfBook`) y `BookRow(…, chevron: true)`.

### B7 · Media · Cuatro implementaciones del plural
- `Int.counted` (Components.swift:1866), `count()` local en SearchScreen.swift:202, `count()` en `CabinetArt` (Components.swift:1420) y `part()` en `LectoraCore BatchLookup.summary`.
- Además ~15 «`x == 1 ? "1 …" : "\(x) …"`» escritos a mano (lista en D1).
- **Arreglo:** mover `counted` a LectoraCore (lo usan la app y el paquete), borrar las otras y ampliar la prueba (ver §0).

### B8 · Media · Renombrar y borrar un estante, dos veces
- La alerta de renombrar está copiada: MacLibraryWindow.swift:218-230 y SavedShelfScreen.swift:61-69. Borrar: el iPhone confirma y la Mac no (C9).
- **Arreglo:** `.renameShelfAlert(...)` y `.deleteShelfConfirmation(...)` junto a `saveShelfAlert` (SavedShelfScreen.swift:83-114).

### B9 · Media · El vacío obliga a usar el ícono «+»
- `EmptyState` siempre pone `systemImage: "plus"` (Components.swift:863). DiaryScreen.swift:49 sale como «＋ Seguir leyendo *Título*»: un «+» para seguir leyendo.
- La Mac no usa `EmptyState` sino `ContentUnavailableView` (MacBookTable.swift:31, 34 · MacBookInspector.swift:21 · MacDuplicatesView.swift:38).
- **Arreglo:** `EmptyState(…, systemImage: String? = nil)`, y en la Mac un `MacEmptyState` que envuelva `ContentUnavailableView` con el mismo texto que el iPhone.

### B10 · Baja · El conteo de una lista, sin CountLine
- `Text(.footnote)` en SavedShelfScreen.swift:28-31 y SearchScreen.swift:144-147 (resumen de resultados). La Mac usa `.navigationSubtitle`, que es lo nativo.
- **Arreglo:** `CountLine` en el iPhone.

### B11 · Baja · «Sin título» repetido 7 veces
- NotebookScreen.swift:67, 134 · SearchScreen.swift:210 · SessionSheet.swift:154 · DiaryScreen.swift:310 · Connectors.swift:241, 408.
- **Arreglo:** `Annotation.displayTitle(shelf:)`.

### B12 · Baja · Formato de fecha corta sin nombre
- `.day().month(.abbreviated).year()` en MacBookRow.swift:34 y MacDuplicatesView.swift:84; día y mes en SearchScreen.swift:211.
- **Arreglo:** `Date.FormatStyle.esShort`, junto a `es(_:)`.

### B13 · Baja · El menú «Editar» de la barra, tres veces igual
- BookDetailScreen.swift:69 · NoteScreen.swift:52 · SavedShelfScreen.swift:50.
- **Arreglo:** una receta en el documento (no hace falta una pieza).

---

## 3. iPhone y Mac: la misma idea hecha distinto

### C1 · Alta · Los estados de lectura tienen dos vocabularios y dos reglas
- **iPhone, filtros:** «Todos · En curso · Sin empezar · Series · Sin descargar» (LibraryOptions.swift:30-34). «En curso» = `isReading`; «Sin empezar» = `progress == 0`.
- **Mac, barra lateral:** «Todos los libros · Leyendo · Por leer · Leídos · Por revisar · Sin portada» (MacLibraryWindow.swift:144-149). El estado sale de `MacBookRow.swift:57-60`, que mezcla `readingStatus` y avance.
- **Editor de los dos:** «Por leer / Leyendo / Leído / Abandonado».
- **Consecuencias:**
  - Un libro marcado «Leyendo» sin avance sale «Sin empezar» en el iPhone y «Leyendo» en la Mac.
  - «Abandonado» no tiene filtro en ningún lado.
  - En la Mac no se puede filtrar por serie ni por «sin descargar», y en el iPhone no se puede filtrar por «Por revisar» ni por «Sin portada».
- **Arreglo:** un solo `ReadingState` en LectoraCore (nombre y regla), y los mismos filtros en los dos.

### C2 · Alta · Editar los datos de un libro funciona distinto
iPhone `MetadataEditorView` contra Mac `MacBookInspector`:

| Concepto | iPhone | Mac |
|---|---|---|
| Separador de autores | «&» (MetadataEditorView.swift:59, 164) | comas (MacBookInspector.swift:59, `BulkEdit.list`) |
| Secciones | Libro · **Publicación** · **Tu biblioteca** · Sinopsis | Libro · **Edición** · **Tu lectura** · Sinopsis |
| Etiquetas | en «Tu biblioteca» | en «Libro» |
| Idioma | selector Español/Inglés | texto libre «es, en, fr…» |
| Fecha | «Año o fecha (AAAA-MM-DD)» | «2016 o 2016-05-01» |
| Valoración | `RatingPicker` (estrellas verdes) | selector con «★★★» |
| Portada | de Fotos, de un archivo o de internet | no se puede cambiar |
| ISBN | se guarda tal cual | se filtran dígitos y X |
| Salir | «Descartar cambios» / «Guardar» | «Deshacer cambios» / «Guardar» |
| Error | «Seguir editando» | «Volver a la ficha» |

- El caso más grave es el separador: un autor como «García Márquez, Gabriel» escrito en la Mac se parte en dos autores.
- **Arreglo:** un `BookDraft` compartido en LectoraCore (campos, orden, separador y validación), y que los dos formularios lo pinten con los mismos rótulos.

### C3 · Alta · En la Mac, «Por revisar» no deja resolver nada
- `MacSection.review` solo filtra la tabla (MacLibraryWindow.swift:148 → MacBookTable).
- En la Mac no existen `ReviewScreen` ni `CandidatesScreen`, ni hay grep que los encuentre en `Mac/`. Así que no se puede elegir entre los libros encontrados, ni ver «Se completaron solos», ni deshacer lo completado.
- **Arreglo:** cuando el libro elegido está por revisar, el inspector muestra los `CandidateRow` y `CompareRow`. Las piezas ya existen.

### C4 · Alta · La ficha del libro es otra cosa en la Mac
- **iPhone (`BookDetailScreen`):** portada grande, Nº de ficha, «Leer/Seguir leyendo», sinopsis, `FactRow`, Lectura (`StatTrio`, `StageBar`, sesiones), Notas que lo enlazan y Subrayados.
- **Mac (`MacBookInspector`):** solo el formulario. No hay botón para leer (solo doble clic o «Abrir» en el menú contextual), ni notas, ni subrayados, ni tiempo leído.
- **Arreglo:** arriba del formulario del inspector, un bloque «Ficha» con las mismas piezas (`PrimaryButton`, `StatTrio`, `NoteRow`, `QuoteBlock`), o dos pestañas «Ficha · Editar».

### C5 · Media · Vacíos con otra pieza y otras palabras
- Mac: «Nada aquí» (MacBookTable.swift:31), «Elige un libro» (MacBookInspector.swift:21), «Sin duplicados» (MacDuplicatesView.swift:38).
- iPhone, para el mismo estado: «Nada por aquí» (LibraryScreen.swift:79).
- Dentro del propio iPhone, la biblioteca vacía se llama «Tu biblioteca está vacía» en la Mesa (MesaScreen.swift:23) y «Todavía no hay libros» en la Biblioteca (LibraryScreen.swift:76).
- **Arreglo:** textos de vacío en un solo lugar (`EmptyCopy.noBooks` …) que usen las dos plataformas.

### C6 · Media · Agregar libros tiene cinco nombres
- iPhone: «Añadir libro» (LibraryScreen.swift:46), «Añadir libros» (MesaScreen.swift:25), «Toca + para añadir» (:77), «Añadiendo 3 de 32…» (LibraryStore.swift:64).
- Mac: «Importar libros» (MacBookTable.swift:47), «Importar libros…» (LectoraApp.swift:30).
- **Arreglo:** un verbo. Recomiendo «Añadir libros» en los dos, con «…» en el menú de la Mac.

### C7 · Media · Buscar datos: cinco nombres y dos íconos
- iPhone: «Buscar datos en internet» (ícono `globe`, BookDetailScreen.swift:71) y «Elegir portada de internet» (:72).
- Mac: «Buscar datos» (`wand.and.stars`, MacBookTable.swift:52), «Buscar datos para los N» (:138), «Buscar portada y datos» y «…para los N» (MacBookInspector.swift:125), «Buscar datos de N libros incompletos…» (MacLibraryWindow.swift:266).
- `globe` en la Mac significa «Idiomas» (MacLibraryWindow.swift:178).
- **Arreglo:** «Buscar datos en internet» con un solo símbolo; con varios libros, «Buscar datos de 3 libros».

### C8 · Media · La Mac no dice qué está haciendo
- En el iPhone, el avance de la importación («Añadiendo…») y «Buscando datos en internet…» se ven en la `CountLine` (LibraryScreen.swift:118-121).
- En la Mac, la tabla no tiene `CountLine`, y el botón del inspector «Buscar portada y datos» corre en silencio (MacBookInspector.swift:125-128). Solo la búsqueda en lote tiene barra (`MacBatchBar`).
- **Arreglo:** `MacBatchBar` también para importar y para buscar los datos de un solo libro.

### C9 · Media · Borrar un estante: el iPhone pregunta y la Mac no
- iPhone: confirmación con «Tus libros se quedan donde están…» (SavedShelfScreen.swift:70-78).
- Mac: borra al instante (MacLibraryWindow.swift:166-169).
- **Arreglo:** usar la misma confirmación (B8).

### C10 · Media · Las acciones sobre el texto elegido se llaman distinto
- iPhone: «Subrayar · Consultar · Nota · A una nota · Copiar» (ReaderView.swift:888-894). En la tarjeta de un subrayado: «Nota/Editar nota · A una nota · Copiar · Borrar» (:859-862).
- Mac: «Subrayar · Subrayar con nota · Llevar a una nota · Consultar en Gabinete» (ReaderController.swift:623-629).
- Dentro del iPhone, el Cuaderno dice «Llevar a una nota» (NotebookScreen.swift:119).
- **Arreglo:** un `enum SelectionAction` con su título y su símbolo, el mismo en los dos menús.

### C11 · Media · Las pantallas del iPhone dentro de la Mac llevan el título dos veces
- Mesa, Cuaderno y Buscar se muestran con `.navigationTitle` (MacLibraryWindow.swift:70-73) y además su `ScreenHeading` o `DeskHeader`: el nombre aparece en la barra de la ventana y otra vez en serif.
- La barra lateral dice «Buscar en todo» y la pantalla «Buscar».
- El engrane del Cuaderno abre Ajustes como hoja (NotebookScreen.swift:40, 65), cuando la Mac ya tiene Gabinete › Ajustes… ⌘, (LectoraApp.swift:48).
- **Arreglo:** en macOS, `ScreenHeading` sin título (solo las acciones) o sin `navigationTitle`; esconder el engrane en la Mac; usar un solo nombre, «Buscar».

### C12 · Media · La Mac no usa las fuentes del sistema de diseño
- Título del libro en `.headline` (MacBookInspector.swift:49), mientras el iPhone usa `.bookTitle` y `.rowTitle` («New York para lo que es del libro»).
- `.callout` en `MacBatchBar` y en los duplicados; `.secondary` del sistema.
- La tabla y los formularios nativos están bien, pero el nombre del libro debería verse igual en las dos.
- **Arreglo:** `.rowTitle` para los títulos de libro en la Mac, y `Theme.secondaryInk`.

### C13 · Baja · Íconos con dos significados
- `book`: la Mesa y «Leyendo» (MacLibraryWindow.swift:139, 145; RootView.swift:102).
- `books.vertical`: Biblioteca, «Todos los libros» y **cada** estante (:144, :158).
- `bookmark`: «Por leer» (:146), pero en el lector es el marcador.
- `photo`: «Sin portada», la columna de portada y «Elegir de Fotos».
- `pencil`: «Escribir a mano», «Renombrar estante», «Escribir» una nota y la nota de un subrayado.
- `plus`: «Más rápido» en la hendidura (SlitScreen.swift:172).
- Es el caso que pone de ejemplo la regla 16 de la casa.

### C14 · Baja · Mayúsculas y forma del estado
- «Leído» (MacBookRow.swift:9) contra «leído» y «empezado» (MacDuplicatesView.swift:83); «Leídos» en la barra lateral.

---

## 4. Textos

### D1 · Alta · Cifras que no concuerdan (o que esquivan `counted`)
**Errores que se ven hoy:**
- MesaScreen.swift:131: «… · \(days()) días» → «1 días».
- Components.swift:2809: VoiceOver dice «Buscar otra vez «x», 1 resultados».
- Components.swift:1533: VoiceOver dice «1 estrellas».
- «… palabras» sin concordar: Components.swift:2062 (`SessionLine`), :2504 (`SessionRow`); SessionSheet.swift:15, :244; MesaScreen.swift:131; DiaryScreen.swift:172 («palabras/min», bien) y :280.
- MacCatalogSheet.swift:48: «se juntan en un solo \(fieldNoun)» → «un solo serie», «un solo etiqueta».

**Escritas a mano con `== 1 ?`** (correctas hoy, fuera de la regla): AppModel.swift:134 · Components.swift:2760 · ReviewScreen.swift:105, 116 · DiaryScreen.swift:194, 280 · NotebookScreen.swift:78, 80 · RulesScreen.swift:57 · WelcomeScreen.swift:194 · ReaderToolsSheet.swift:226, 232 · BookDetailScreen.swift:177 · CalibreMigrationScreen.swift:155.

**Cifra sola, sin sustantivo** (nadie sabe qué cuenta): BookDetailScreen.swift:160 · NotebookScreen.swift:144 · Components.swift:2752 · LibraryScreen.swift:60, 70 (en `LinkRow` se entiende); MacBookInspector.swift:125, 136 («Aplicar a los 3»); MacBookTable.swift:138 («para los 3»).

**Arreglo:** usar `counted` en todos, mover el helper a LectoraCore y arreglar la prueba (§0.3). Añadir *días, resultados, estrellas, opciones, archivos, capítulos, grupos, encontrados*; permitir paréntesis anidados; quitar la excepción de `== 1`.

### D2 · Media · Botones genéricos que esquivan SB-1
- «Seguir» (WelcomeScreen.swift:166, 212): es «Continuar» con otra palabra.
- «Atrás» (:73), «Empezar» (:128).
- «Cerrar»: CalibreMigrationScreen.swift:42 y NoteLinkSheet.swift:43; también como nombre para VoiceOver en LookupCard.swift:44, ReaderView.swift:855 y SessionSheet.swift:42.
- «Abrir» (MacBookTable.swift:136), «Buscar» (ReviewScreen.swift:397), «Usar» (BookDetailScreen.swift:225).
- «Guardar» a secas: ReaderView.swift:294, MetadataEditorView.swift:116, MacBookInspector.swift:136.
- «Está bien» como acción principal (ReviewScreen.swift:438).
- «Listo» como `PrimaryButton` (SessionSheet.swift:156, WelcomeScreen.swift:236). La receta acepta «Listo» en la barra, no como la acción principal.
- «Aplicar a los N» empieza con una palabra prohibida.
- **Arreglo:** agregar «Seguir», «Atrás», «Empezar», «Cerrar», «Abrir», «Usar», «Guardar», «Está bien» a una lista propia de Gabinete (en `sistema-base.json`, o como prueba en `DesignRulesTests`) y reescribir. Por ejemplo: «Guardar cambios», «Usar esta portada», «Guardar la nota», «Elegir dónde vive», «Cerrar la consulta».

### D3 · Media · Títulos de alerta que no dicen qué pasó
- «No se pudo» (SettingsScreen.swift:169).
- «Aviso» (ReaderView.swift:304).
- «Nota»: como aviso de éxito en SessionSheet.swift:105, 166 y DiaryScreen.swift:332, y también como la alerta para escribir una nota (ReaderView.swift:289).
- «Importación» (RootView.swift:71).
- «No se pudo cambiar» (BookDetailScreen.swift:235) → «No se pudo cambiar la portada».
- **Arreglo:** que `.errorAlert` y `.noticeAlert` (B3) pidan el título, con una prueba que rechace «Aviso», «Nota», «No se pudo» y «Error».

### D4 · Media · La app habla con dos voces
- **Primera persona:** «No encontré» (LibraryStore.swift:23, ReviewScreen.swift:113, 164), «No pude bajar…» (ReaderView.swift:351, LibraryStore.swift:25), «Leo sus datos, les busco portada» (MesaScreen.swift:24), «Revisé…», «No borré nada» (SettingsScreen.swift:272-277), «Datos que tomé de internet porque estaba seguro» (ReviewScreen.swift:78).
- **Impersonal:** «No se pudo guardar», «Se guardó», «Se copian tus libros… se comprueba… se borra» (SettingsScreen.swift:258), «Se juntó» (MacDuplicatesView.swift:114).
- Ajustes mezcla las dos en la misma pantalla.
- El trato de **tú** es constante: no aparece ningún «usted», «elija» o «toque», bien.
- **Arreglo:** elegir una voz y escribirla en la guía de textos. Recomiendo la primera persona, que ya es la mayoría y suena a «la libreta que te ayuda».

### D5 · Media · Cancelar y volver sin un patrón
- **Salir sin guardar:** «Descartar cambios» (MetadataEditorView.swift:113), «Dejar como está» (MacCatalogSheet.swift:78, MacLibraryWindow.swift:229, SavedShelfScreen.swift:68), «Dejar sin guardar» (SavedShelfScreen.swift:100), «Dejar la portada» (BookDetailScreen.swift:222), «Descartar la nota» (ReaderView.swift:295).
- **Revertir:** «Deshacer cambios» (Mac), «Deshacer todo» (ReviewScreen.swift:442), «Deshacer» (`CompareRow`).
- **Tras un error:** «Volver a …» 12 veces, «Seguir editando» 2, «Elegir otra portada/nota».
- SB-1 lo permite, pero falta una receta. Propuesta: cancelar = «Dejar …» (lo que proteges), error = «Volver a …», revertir = «Deshacer …».

### D6 · Media · Un mismo término con dos significados
- «Marcas» es la pestaña que junta «Marcadores» y «Subrayados» (ReaderToolsSheet.swift:10, 241). En la tarjeta y en el Cuaderno se dice «subrayados».
- «Ficha» es el inspector en la Mac (MacBookTable.swift:55) y el «Nº de ficha» en el iPhone.
- «Leer» (BookDetailScreen.swift:43, con `isReading`) contra «Empezar a leer» (MesaScreen.swift:73, con `progress > 0`): el mismo libro puede decir «Seguir leyendo» en una pantalla y «Leer» en la otra.
- Ajustes › Datos: «Open Library y Google» en el dibujo (SettingsScreen.swift:83) y «Open Library y Google Books» en la fila de abajo (:86).
- «Gabinete» y «biblioteca» se usan como sinónimos («Tu biblioteca está vacía» / «Ya hay 1 libro en tu Gabinete»).

### D7 · Baja · Puntos suspensivos y mayúsculas
- En la Mac, «…» debería marcar solo lo que abre otra ventana o pregunta algo. «Buscar datos de N libros incompletos…» (MacLibraryWindow.swift:266) empieza de inmediato.
- «6 a Por revisar» (LectoraCore BatchLookup) lleva la mayúscula a media frase.

### D8 · Baja · Riesgo de texto en inglés
- No encontré textos propios en inglés.
- El riesgo es `error.localizedDescription` del sistema mostrado tal cual: MacBookInspector.swift:165, 169 · MacDuplicatesView.swift:120 · ReaderController.swift:379 · AppModel.swift:110 · SettingsScreen.swift:143, 266 · MetadataEditorView.swift:173 · BookDetailScreen.swift:262. Con el dispositivo en inglés, esos mensajes salen en inglés dentro de una app en español.
- **Arreglo:** traducir los errores conocidos (`LibraryError` ya lo hace) y, para los demás, poner un texto propio con el detalle en una segunda línea.

### D9 · Baja · Interfaz que no hace nada (detrás de una bandera)
- `MiniPlayer` muestra «Cap. VII · quedan 18 min» y un avance de 0,38 fijos, y el botón +30 no hace nada (MiniPlayer.swift:26, 38, 45).
- `ReaderPillButton` «Guiada» y «Escuchar» con acciones vacías `{}` (ReaderView.swift:810-811).
- Solo se ven con `LaunchOptions.listening` (LaunchOptions.swift:32), pero contradicen «lo que no funciona no se muestra».
- **Arreglo:** marcarlos `#if DEBUG` o borrarlos.

---

## 5. Accesibilidad

### E1 · Alta · Lugares que se tocan con menos de 44 pt
- Acciones de `ScreenHeading` sin marco: el cambio lista/portadas de la Biblioteca (LibraryScreen.swift:39-44) y el engrane del Cuaderno (NotebookScreen.swift:40). Solo responde el ícono, de unos 24 pt. El «+» (`AccentIconButton`) sí mide 44, así que en el mismo encabezado uno responde y el otro no.
- `LetterIndex`: cada letra mide 18 de ancho por unos 13 de alto (Components.swift:879-884), y además va en verde siendo una acción (regla 1).
- La ✕ de `SearchField` (Components.swift:2688) no tiene marco.
- **Arreglo:** que `ScreenHeading` envuelva cada acción en el `.sizeTarget()` que ya existe (ReaderAppearance.swift:505), movido a Components, y la ✕ con `Size.tapTarget`. Prueba: dentro de `ScreenHeading { }` solo `AccentIconButton` o un `IconButton` nuevo.

### E2 · Alta · Cosas que no crecen con el tamaño de letra
- `Font.screenTitle` fijo en 30 (A5).
- Alturas fijas con texto adentro: `SettingsArt` (150, con «1 248 palabras», Components.swift:1216), `dayCell` 34 del calendario, `stageRow` 26, `footerPreview` 64 con el pie en la letra del libro, y `Size.appearanceSheet` 584.
- `IconTile` y la etiqueta corta usan `.lineLimit(1)` con `minimumScaleFactor(0.8)`: con letra grande, la etiqueta **se achica** en vez de crecer.
- `BookRow` trunca título y detalle a una línea (Components.swift:718, 722).
- **Arreglo:** usar `@ScaledMetric` en los tamaños que contienen texto (`dayCell`, `stageRow`, `settingsArt`) y permitir 2 líneas en `BookRow` desde `.accessibility1`.

### E3 · Media · Nombres para VoiceOver que no concuerdan o no dicen nada
- «1 estrellas» y «1 resultados» (D1).
- `RatingPicker` no dice cuál está puesta: falta `.accessibilityValue` o `.isSelected` en la elegida.
- `ThinProgress` se llama «Progreso» (Components.swift:758). Mejor «Leído».
- Tres ✕ dicen solo «Cerrar».
- Las estrellas de la Mac son texto «★★★» (MacBookRow.swift:32, MacBookInspector.swift:76). VoiceOver lee «estrella negra» tres veces; falta «3 estrellas».
- El punto de «Por revisar» (`LinkRow(marked:)`) está escondido para VoiceOver (`StatusDot` con `accessibilityHidden`), así que quien no ve no se entera de que hay algo pendiente.

### E4 · Media · «Elegido» sin el rasgo `.isSelected`
- `IconTile` tiene `selected` pero no pone el rasgo (Components.swift:207-231). Solo lo agrega quien la usa (ReaderAppearance.swift:486), así que cualquier uso nuevo queda mudo.
- `RatingPicker`: igual que en E3.
- Bien: `FilterBar`, `SegmentedChoice`, `PageSwatchPicker`, `CoverChoiceCell`, `OptionRow`, el pie y los duplicados de la Mac sí lo tienen.
- **Arreglo:** que el rasgo vaya dentro de la pieza, con una prueba: «toda pieza con `selected` lleva `.isSelected`».

### E5 · Baja · Más guardias por acercar
- Lo buscado en verde y negritas está bien, no depende solo del color.
- `CompareRow` pinta «Deshacer» en verde (Components.swift:1635): es una acción y debería ir en tinta (regla 1).

---

## 6. Cómo cerrar los huecos (regla 16: cada regla con su prueba)

Sin reglas nuevas para quien usa la app: se trata de que las seis que ya existen se cumplan en todos los archivos.

1. **Una sola lista de archivos** para `lint-design.sh` y `DesignRulesTests`: todo `App/Shared` menos `Theme.swift`. Cubre la Mac, `SlitScreen`, `LookupCard`, `PageCurl` y `ReaderController` (A1).
2. **Patrones que hay que agregar:** `\.custom\(`, `\.(black|white)\b` fuera de `CoverStyle`, `\.(brightness|blur)\([^)]*\d`, `\.font\(\.(title|title2|title3|headline|callout|largeTitle)\b`, `\.foregroundStyle\(\.(secondary|primary|tertiary)\)`, `ContentUnavailableView` y `borderedProminent` en Mac/, `Theme\.\w+\.\w+\s*\*`, y `Task\.sleep\(for: \.seconds\(\d` fuera de `#if DEBUG`.
3. **`testCountsAgreeWithTheirNumber`:** paréntesis anidados, más sustantivos y sin la excepción de `== 1` (D1).
4. **`sistema-base.json`:** patrón de tokens para todo `Space`, reader.js como fuente web y la nota «_» al día (A12, A13).
5. **Una prueba nueva para el lector web:** sin números fuera del bloque `tokens` en reader.js (A13).
6. **Paridad iPhone–Mac:** que las mismas acciones (`SelectionAction`, `ReadingState`, `BookDraft`, `EmptyCopy`) salgan de un solo enum en LectoraCore. Así la prueba compara títulos en lugar de cadenas sueltas (C1, C2, C5, C10).

---

## 7. Cuántos hallazgos hay

| Categoría | Grupos | Lugares (aprox.) | Alta / Media / Baja |
|---|---|---|---|
| 1. Valores sueltos (A1-A13) | 13 | ~150 | 2 / 9 / 2 |
| 2. Patrones repetidos (B1-B13) | 13 | ~95 | 3 / 6 / 4 |
| 3. iPhone y Mac (C1-C14) | 14 | ~70 | 4 / 8 / 2 |
| 4. Textos (D1-D9) | 9 | ~85 | 1 / 5 / 3 |
| 5. Accesibilidad (E1-E5) | 5 | ~25 | 2 / 2 / 1 |
| **Total** | **54** | **~425** | **12 / 30 / 12** |

## 8. Los 15 que más se notan

1. **C1** · Estados de lectura con dos vocabularios y dos reglas: «En curso / Sin empezar» en el iPhone, «Leyendo / Por leer» en la Mac; el mismo libro cae en grupos distintos.
2. **C2** · Editar datos: autores separados con «&» en el iPhone y con comas en la Mac, además de otras secciones, otro control de idioma y otras estrellas.
3. **B1** · Las secciones se anuncian de tres formas (Cinzel sin línea en unos 35 lugares, versalitas con línea y texto gris a mano), contra la regla 3.
4. **C3** · En la Mac, «Por revisar» solo filtra la tabla: no se pueden elegir los datos encontrados ni deshacer lo completado.
5. **C4** · La ficha de la Mac es solo un formulario: no tiene botón para leer, ni notas, ni subrayados, ni lectura.
6. **A1** · El lint y las pruebas no miran la Mac, la hendidura, la consulta ni el pase de hoja, y por eso el verde, los vacíos del sistema y las fuentes sueltas de la Mac pasan.
7. **D1** · «1 días» en la Mesa, «1 resultados» y «1 estrellas» para VoiceOver, y unos 15 plurales escritos a mano; la prueba tiene tres huecos.
8. **E1** · El engrane del Cuaderno, el cambio lista/portadas y la ✕ de buscar responden en menos de 44 pt, y el índice A–Z en 18 × 13.
9. **A5/E2** · El título de cada pantalla no crece con el tamaño de letra (30 fijo, repetido en `LectoraApp`).
10. **B3 + D3** · La alerta de error está copiada 13 veces, y hay títulos como «No se pudo», «Aviso», «Nota» o «Importación».
11. **C6 + C7** · «Añadir» contra «Importar» libros, y «Buscar datos» con cinco nombres y dos íconos.
12. **C9** · En la Mac, borrar un estante no pide confirmación; en el iPhone sí.
13. **A13** · El separador de página del lector web mide unos 11,5 px (menos que el mínimo de 12) y reader.js trae unos 40 números propios que la app no controla.
14. **A12** · El margen de 28 y los aires de 10, 14 y 20 rompen la escala de la casa bajo otro nombre; `sistema-base.json` no los vigila y su nota está desactualizada.
15. **C10** · El menú del texto elegido: «Nota / A una nota / Consultar» en el iPhone, «Subrayar con nota / Llevar a una nota / Consultar en Gabinete» en la Mac.
