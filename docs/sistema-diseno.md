# Sistema de diseño de Gabinete: la libreta del futuro

Cómo se vería una libreta fina en el futuro: la misma elegancia, con minimalismo tecnológico.
Precisión en vez de materiales: líneas finísimas, mucho aire, versalitas, cifras exactas y un
solo verde. Nada de cuero, hendidos ni costuras (decisión del 25 nov 2026; sistema elegido el
26 nov 2026 con AC-3, SD-1 a SD-8 y AJ-B).

Todo valor visual es un **token**; toda pieza repetida es un **componente**; toda pantalla
sigue una **receta**; toda regla tiene una **prueba** que falla si alguien la rompe. Lo nuevo
se arma con lo que ya hay: si falta algo, se agrega aquí primero.

## Las ocho reglas de la libreta

Cada regla dice lo que nota quien usa la app; la medida exacta vive en `Theme` con su nombre.

| # | Regla | Lo que notas | La cuida |
|---|---|---|---|
| 1 | **Un solo verde, y poco** | El verde botella marca solo dónde estás (pestaña, filtro elegido), lo que avanzas (palabras, la marca de la Mesa) y lo tuyo (subrayados, cinta, pendientes). Las acciones van en tinta | `testOnlyPiecesPaintTheAccent` |
| 2 | **Líneas finas en vez de cajas** | Las secciones se separan con una línea finísima y aire, no con tarjetas grises. La excepción es Ajustes: tarjetas blancas con su dibujo sobre un papel más hondo (AJ-D, 26 nov 2026) | `testScreensUseCatalogPieces` (sin formas a mano), `SectionHeader`, `SettingsCard`, `ScreenHeading` |
| 3 | **Rótulos en versalitas** | Toda sección se anuncia igual en el iPhone: mayúsculas chicas, espaciadas, con su línea a la derecha y, si hay, su acción al final. Las romanas (Cinzel) quedan para la marca, el «Nº» y el capítulo | `testCapsComeFromThePieces`, `testSectionsUseTheirHeader` |
| 4 | **Cifras exactas** | Cantidades, fechas y porcentajes no bailan: todas las cifras miden lo mismo | `testFiguresAreExact`, `testDatesAndNumbersInSpanish` |
| 5 | **Aire en una sola escala** | Todo espacio sale de 4 · 8 · 16 · 24 · 32 · 48, la escala común de la casa | `testSpacingKeepsTheHouseScale`, `tools/sistema-base` (SB-2) |
| 6 | **Botón principal oscuro en los dos modos** | «Seguir leyendo» y «Nota nueva» en verde fichero con letra clara, también en oscuro, con un filo finísimo | `testMainActionIsDarkInBothModes`, `testOneMainActionPerScreen` |
| 7 | **Te hablo de tú y digo qué pasó** | Los avisos dicen qué pasó en primera persona («No pude abrir el libro», nunca «No se pudo» ni «Aviso»), y su botón a dónde vuelves («Volver a la ficha»). Los botones dicen qué hacen: nunca «Cancelar», «OK» ni «Listo» a secas; salir sin cambiar es «Dejar como está». Mientras algo tarda, digo qué estoy haciendo | `testNoticesSayWhatHappened`, `testButtonsSayWhatTheyDo`, `testWaitingSaysWhat` |
| 8 | **Lo mismo se llama igual en el iPhone y la Mac** | Un libro está «Leyendo», «Por leer» o «Leído» por la misma regla en las dos; añadir libros, buscar datos, lo que haces con el texto elegido y los datos de un libro tienen un solo nombre y un solo ícono; los autores se separan con « & » | `testSameWordsOnBothPlatforms`, `ReadingStateTests` |

### Las reglas de la casa (interoperabilidad)

Gabinete cumple el sistema base común a todas las apps de Fernando
(`~/code/interoperabilidad/sistema-base`, copia en `tools/sistema-base/`, corre en CI):

| Regla | Qué exige | La cuida |
|---|---|---|
| SB-1 | Botones y avisos que dicen qué hacen («Crear nota», no «Crear» u «OK») | `tools/sistema-base/revisar.py` |
| SB-2 | Solo la escala 4 · 8 · 16 · 24 · 32 · 48 · 64. Desde el 26 nov 2026 Gabinete no arrastra nada heredado: se fueron el 12 y el 6 | `revisar.py`, `testSpacingKeepsTheHouseScale` |
| SB-3 | Ninguna letra de menos de 12 | `revisar.py`, `testNoTextUnderTwelve` |
| SB-4 | Todo lo que se toca responde en 44 × 44 | `revisar.py`, `Size.tapTarget` en cada pieza que se toca |
| D2-B | La negrita solo en el título más grande y en cifras; lo demás en seminegrita | `testBoldOnlyForTitlesAndFigures` |

## Regla

1. **Nada de la app usa números, colores, fuentes, esperas ni animaciones sueltos**: ni las
   pantallas, ni las piezas, ni el lector, ni la Mac. Usan `Theme.*`, las fuentes de `Font` de
   abajo y los componentes de `Design/Components.swift`. Desde SD-1 (26 nov 2026) la prueba y
   `scripts/lint-design.sh` leen la misma lista: todo `App/Shared` menos lo que diga
   `scripts/design-sources.txt` con su porqué (solo `Theme.swift`, donde nacen los tokens), y los
   mismos patrones de `scripts/design-patterns.txt`. `reader.js` también: sus letras y sus
   márgenes siguen la escala.
2. Si falta un token o un componente, **se agrega al sistema** (Theme / Components) con
   su nombre y su uso, y se documenta aquí. No se resuelve en la pantalla.
3. **Se comprueba solo**, en cada push: `DesignRulesTests` (en `swift test` de LectoraCore)
   lee el código de la app y falla si una pantalla usa un valor o una forma a mano, si
   una pieza no está en este catálogo, si un token sobra, o si se rompe una decisión de
   diseño (abajo, «Cómo se cuida»). `scripts/lint-design.sh` es la versión rápida local.
   Excepción puntual: `// ds-exception: <motivo>` en la línea, con el motivo en la tabla
   «Excepciones». Antes de agregar una, intenta un token o una pieza nueva.
4. Simetría: todo lo que tiene margen lo tiene igual a ambos lados (ver abajo).

## Tokens (`Design/Theme.swift`)

### Color (claro / oscuro)

| Token | Claro | Oscuro | Uso |
|---|---|---|---|
| `paper` | `#F8F7F4` | `#161514` | Fondo de todas las pantallas |
| `field` | `#EFEDE8` | `#242320` | Campos, filtro activo, botón secundario |
| `ink` | `#1C1B19` | `#ECE9E2` | Texto |
| `onInk` | `#FFFFFF` | `#141413` | Texto sobre tinta |
| `action` | = `Green.light` | = `Green.light` | La acción principal (`PrimaryButton`): el verde hondo en los dos modos (regla 6) |
| `onAction` | `#F3EFE6` | `#ECE9E2` | Letra sobre la acción principal |
| `secondaryInk` | `#6F6C65` | `#9C988F` | Texto secundario (contraste ≥ 4,5 sobre `paper`) |
| `tertiaryInk` | `#837F78` | `#7C7870` | Folios y etiquetas pequeñas (contraste ≥ 3 sobre `paper`) |
| `track` | `#E6E3DC` | `#34322E` | Pistas y separadores |
| `sunken` | `#F2F0EB` | `#121110` | El papel hondo de Ajustes, debajo de sus tarjetas (AJ-D, AJ-8) |
| `card` | `#FFFFFF` | `#1F1E1C` | Una tarjeta de Ajustes |
| `accent` | `#0F4A35` | `#4FB386` | Verde botella (AC-3, 26 nov 2026), el único acento: dónde estás, lo que avanzas y lo tuyo (regla 1). Solo lo pintan las piezas. Sale de `Theme.Green`, la única fuente del verde (26 nov 2026). También es el color del sistema (enlaces, «Listo», alertas), la tarjeta para compartir y la acción principal: **para cambiar el acento se cambian las dos líneas de `Theme.Green` y nada más** |
| `onAccent` | `#FFFFFF` | `#141413` | Letra sobre el verde: la tarjeta para compartir, la portada del dibujo de Ajustes |
| `highlight` | = `accent` | = `accent` | Lo tuyo: subrayados, marcadores, citas y enlaces de notas, en la app y dentro del libro (`reader.js` lo recibe de `Theme.Green.css`, nunca escribe un color). Todo apunta aquí |

**Etapas de lectura** (`Theme.stage(_:)`): del gris al verde del acento, el mismo verde
a distinta intensidad (`Emphasis.stageSkim` 0,22 · `stageLight` 0,45 · `stageActive` 0,72 ·
inmersa, entero), así no queda ningún verde aparte (26 nov 2026):

| Etapa | Color |
|---|---|
| Interrumpida | `track` |
| Hojeo | `accent` al 22 % |
| Ligera | `accent` al 45 % |
| Activa | `accent` al 72 % |
| Inmersa | `accent` |

Los fondos del lector (Papel, Blanco, Noche cálida, Negro) viven en `ReaderPalette`.

### Espacio (`Theme.Space`, la escala común de la casa)

`xs 4 · s 8 · l 16 · xl 24 · xxl 32 · xxxl 48`, más `xxs 2`: medio paso solo dentro de piezas
chicas. Sin 12 ni 6 desde el 26 nov 2026 (SD-2): cada uso pasó a 16 o a 8. Desde SD-1 (26 nov 2026)
también los espacios con nombre (`gutter`, `rowY`… y los márgenes del lector) están en la escala, y
`sistema-base.json` los revisa por su nombre.

| Token | Valor | Uso |
|---|---|---|
| `gutter` | 24 | Margen lateral de toda pantalla, igual a ambos lados (era 28, fuera de la escala) |
| `screenTop` | 24 | Del área segura al título de pantalla |
| `screenBottom` | 32 | Aire antes del dock |
| `hair` | 1 | Entre las letras del índice A–Z |
| `rowY` | 8 | Aire arriba y abajo de una fila de lista |
| `rowGap` | 16 | Entre la portada (o la raya de una cita) y su texto |
| `buttonX` | 24 | Interior horizontal del botón principal |
| `indent(n)` | 16 × n | Sangría de un nivel del índice del libro |

**Nunca se suman tokens** («`s + xxs`», «`xl + xs`»): cada suma era un valor nuevo sin
nombre, y la misma separación salía distinta en cada pieza. Si hace falta otra medida,
se nombra aquí y en `Theme` (lo vigila `testNoArithmeticBetweenTokens`).

### Radio (`Theme.Radius`)

`swatch 2 · cover 3 · control 10 · tile 14 · panel 28 · inset 12` (inset: lo que va dentro de un panel, concéntrico)

### Tamaño (`Theme.Size`)

`tapTarget 44 · tapBleed 12 (lo que el toque de un ícono sobresale de su dibujo) · row 52 (fila de libreta) · tabMark 16 × 2 (el trazo del filtro elegido) · pageSwatch 78, swatchLine 3, swatchLines (las hojitas de Apariencia) · statusDot 6, statusDotLine 1 · equalizerHeight 12 · control 46 · coverHero 132 · coverDetail 168 · coverEditor 84 · coverRow 40 ·
coverMini 26 · letterIndex 18 · gridColumns 3 · hairline 0.5 · progress 2 · quoteRule 2 · selection 2 · accentButton 44 ·
stageBar 8 · stageBarThin 4 · footerPreview 64 · footerPicker 320 (el globo del pie) · deskMark 16 × 4 (el trazo verde del encabezado de la Mesa) · ghostLine 3 · scrubberKnob 14 · scrubberHeight 32 · scrubberReach 6 · excerptReach 60 (letras de contexto al encontrar algo en una nota) · dragSlop 6 · stageRow 26 · stageMark 16 · stageGap 1 · legendSwatch 8 · playRing 38 · equalizerBar 2 ·
textEditor 120 · ribbon 12×64 · appearanceSheet 584 (solo mientras se mide; luego la hoja mide su contenido) · turnPreview 18×24 · macReader 720×820 · weekChart 112 · yearChart 80 · weekBar 18 · dayCell 34 · shareCard 300×375 ·
coverAspect 2∶3 (toda portada) · indentLevels 3 (sangrías del índice)`

`Theme.Emphasis`: `secondary` (0,75) texto secundario sobre la marca (tarjeta para compartir); `glassText` (0,8) texto callado sobre el vidrio del lector (subió de 0,72: en Noche cálida quedaba justo en el mínimo de contraste); `scrubberTrack` (0,25) riel de la barra de avance;
`pressed` (0,85) y `pressedScale` (0,97) al tocar, `rest` (1) en reposo; `labelMinScale` (0,8) lo más que se achica una etiqueta corta; `ghost` (0,12) renglones y filo de la muestra del pie; `inGlass` (0,1) el círculo de un botón dentro del vidrio (`roundInGlass`: buscar y «Aa» en la tarjeta del lector); `actionEdge` (0,16) el filo de la acción principal; `folioMuted` (0,55) su pie sin dato; `knobGrow` (1,4) la perilla de la barra al arrastrar. Con controles, en páginas no hay franja detrás de los botones de arriba (arriba hay papel liso y el vidrio basta); en continuo, donde el texto corre por debajo, va la misma franja de papel que se desvanece del capítulo (decisión D3-B, 24 nov 2026).

`Theme.shade` (negro) es la única sombra: oscurece portadas, la vuelta de la hoja y el lomo; nunca `.black` suelto.

`Theme.Lists`: cuántos se enseñan antes de «Ver todos»: `desk` 6, `preview` 5, `detailSessions` 5, `longestSessions` 2,
`linkShelf` 20, `linkSuggestions` 4, `coverSources` 3, `coverOptions` 12 y `summaryLetters` 140 (letras de una sinopsis corta).

### Portada tipográfica (`Theme.CoverArt`)

La portada que se dibuja para un libro sin imagen se escala con su ancho: cada medida
es una fracción de ese ancho (`inset` 0,09 · `title` 0,14 · `author` 0,07 · `spine` 0,05 ·
`ribbon` 0,065 …), así se ve igual en una fila de 40 pt y en la ficha de 168 pt. Sus
esquinas (`spineRadius` 2, `edgeRadius` 4) imitan un libro: lomo casi recto, canto redondeado.
En la Mesa las portadas son nítidas (`crispCovers`, ME-1): un filo de media línea (`crispEdge`) y una sombra larga y tenue (`crispShadow`, `crispShadowRadius`, `crispShadowY`) en vez de la sombra de objeto.

### Identidad

Neoclásico mínimo: del mundo grecorromano solo las mayúsculas romanas, el
interpunto «·» y el aire. El gabinete (el portaetiquetas de latón de un cajón)
vive en el ícono; en la app solo queda su color. Verde con mesura: la acción
principal oscura y, como mucho, **un** ícono de acción en verde por pantalla (`AccentIconButton`).
El modo oscuro se queda neutro; solo cambia el verde.
Ícono en `App/Resources/Assets.xcassets/AppIcon.appiconset`: verde fichero
(claro), tinta (oscuro) y tintado; los PNG se generan desde el diseño del lienzo.

### Tipografía (`Font`)

| Token | Fuente | Uso |
|---|---|---|
| `.screenTitle` | New York `Letter.screenTitle` (30) medium, crece con el tamaño de texto (`.screenTitleFont()`, y `UIFont.screenTitle` en los títulos grandes del sistema) | Título de pantalla |
| `.bookTitle` | New York 28 medium | Libro protagonista (Mesa, ficha), títulos de estado vacío |
| `.rowTitle` | New York 17 | Títulos en filas, citas |
| `.quote` | New York 17 itálica | «Donde lo dejaste» |
| `.prose` | New York 16 | Sinopsis |
| `.brandMark` | Cinzel 16, espaciado `Tracking.brandMark` | «GABINETE» en la Mesa |
| `Tracking.caps` | 1,6 de espaciado en versalitas de texto | La fecha de la Mesa, «DONDE LO DEJASTE» |
| `.sectionLabel` | Cinzel 12 medium, mayúsculas, `Tracking.sectionLabel` | Rótulos de sección |
| Sistema | SF (`.body`, `.subheadline`, `.footnote`, `.caption`) | Toda la interfaz |
| `.icon`, `.largeGlyph`, `.badge`, `.hubLetter` | SF para íconos: de botón, grande, insignia chica (11, solo en íconos) y la letra del centro de Apariencia | Íconos |

Regla de oro: **New York para lo que es del libro, SF para la interfaz, Cinzel
solo para la marca y los rótulos** (nunca para títulos de pantalla ni texto
largo). Cinzel (OFL) va en `App/Resources/Fonts`.

### Movimiento (`Theme.Motion`)

`standard` (snappy 0.25 s) para cambios de estado; `press` (0.15 s) al tocar; `select` (resorte corto) al elegir una opción;
`sheet` (0.35 s) cuando una hoja cambia de alto; `exit` (0.12 s): lo que se va, se va rápido y antes de que lo demás
se acomode; lo que entra espera `enterDelay` a que se abra su lugar, en cascada (`stagger`), y queda quieto en `enterSettle`;
`equalizer(alto)` para las barras de audio sonando (cada una a su ritmo).

## Componentes (`Design/Components.swift`)

| Componente | Qué es | Dónde |
|---|---|---|
| `.screen()` | Receta de pantalla raíz: papel, sin barra de navegación, destinos de libro y serie | Mesa, Biblioteca, Cuaderno |
| `.formScreen()` | Receta de formulario: el papel de la app de fondo, no el gris del sistema; botones e interruptores en `accent` (con la marca, casi negra en claro, parecían texto) | Conexiones, Reglas, Editar datos, Buscar con otros datos |
| `.pushedScreen(título)` | Receta de pantalla empujada u hoja: papel, título en línea, controles del contenido en `accent`; los botones de la barra de vidrio, en tinta como en iOS 26 | Ficha, serie, nota, Diario, Por revisar, Lector › herramientas, Sesión, Llevar a una nota, Traer de Calibre, Bienvenida |
| `.inlineTitle(título)` | Título pequeño en la barra (lo usan `.pushedScreen` y los formularios empujados) | Conexión, Editar datos, Buscar con otros datos |
| `.screenContent()` | Margen `gutter`, aire `screenTop`/`screenBottom`, tinta | Todo contenido con scroll |
| `ScreenHeading` | Título serif + acciones a la derecha y una línea finísima debajo (SD-3) | Biblioteca, Cuaderno, Buscar, Ajustes |
| `PrimaryButton` | Acción principal en `action`, oscura en los dos modos, con filo finísimo (una por pantalla) | «Seguir leyendo», «Leer», estado vacío |
| `TextAction` | Acción de texto en tinta, que se toca en 44 (las acciones no van en verde) | «Todo bien», «Ver los N subrayados», «Borrar recientes», «Crear nota» |
| `CapsText` | Versalitas de interfaz: mayúsculas chicas, espaciadas (`Tracking.caps`) y con cifras exactas. Toda versalita sale de aquí | Fecha de la Mesa, conteos, rótulos |
| `SectionHeader` | Rótulo de sección: `CapsText` y una línea finísima hasta la orilla; a la derecha, opcional, una acción de texto o un ✕ (`CloseButton`). El único rótulo de sección de la app (regla 3) | «Donde lo dejaste», secciones de la ficha y de Por revisar, vacíos, Sesión |
| `CountLine` | El conteo de una lista en versalitas y, a la derecha, cómo se ordena | Biblioteca, Cuaderno |
| `SortMenu` | Menú para elegir el orden, en versalitas de tinta con su flecha | Biblioteca, Cuaderno › Subrayados |
| `ToggleRow` | Interruptor en una fila de libreta (`Size.row`), en verde | Ajustes › Lectura |
| `FieldRow` | Campo de texto en una fila: nombre a la izquierda, lo escrito a la derecha | Ajustes › Clave de Google Books |
| `HelpText` | Ayuda de una línea bajo una sección; lo largo detrás de «Más» (AJ-2) | Ajustes |
| `StatusDot` | Punto lleno en verde (conectado, pendiente) o hueco en gris | `LinkRow` |
| `PageSwatchPicker`, `PageTone` | Elegir entre hojitas de papel que se ven como el resultado; la elegida con filo verde (AJ-1) | Ajustes › Apariencia |
| `SettingsCard` | Ajustes (AJ-D): rótulo en `CapsText`, tarjeta `card` con borde `track` sobre el papel hondo (`sunken`), su dibujo arriba y sus filas abajo; la ayuda (`HelpText`) debajo | Ajustes |
| `SettingsArt` | El lugar del dibujo de una tarjeta: `Size.settingsArt` (150) de alto, en papel, con una raya abajo | Ajustes |
| `ReadingArt` | Lectura: una hoja con renglones, el contador de palabras y la tarjetita del resumen; apagas uno y se va del dibujo (AJ-6) | Ajustes › Lectura |
| `BookDataArt` | Datos de los libros: libro sin datos → la fuente → el libro con portada y sinopsis | Ajustes › Datos de los libros |
| `CabinetArt` | Tu Gabinete (TG-1): la carpeta por dentro como en el Finder; arriba dónde vive (este iPhone, iCloud Drive con sus carpetas, otra carpeta) y adentro Biblioteca y Notas con sus cifras | Ajustes › Tu Gabinete |
| `ConnectionsArt` | Conexiones: tu Gabinete al centro y un hilo a cada servicio, verde al conectarlo | Ajustes › Conexiones |
| `Colophon` | La firma al final: «GABINETE», una línea corta y la versión (AJ-3) | Ajustes |
| `BookmarkRibbon` | La cinta verde del marcador colgando de la esquina de la hoja | Lector, en páginas |
| `BookmarkGlyph` | El ícono del marcador en 44: relleno y en verde si la página está marcada | Lector, arriba a la derecha |
| `RatingPicker` | Cinco estrellas en verde (lo tuyo); tocar la misma la quita; cada una se toca en 44 | Editar datos |
| `RoundIconButton` | Botón redondo secundario | Audiolibro |
| `FilterBar` | Opciones en texto; la elegida en tinta con un trazo verde debajo (`Size.tabMark`) que se desliza; sin píldoras (SD-3) | Filtros de Biblioteca, partes del Cuaderno |
| `ShelfCover` / `CoverView` | Portada real o tipográfica, con lomo | Toda portada |
| `SeriesStack` | Pila de portadas de una serie | Biblioteca |
| `CoverCell` + `CoverGrid` | Celda y cuadrícula de 3 columnas | Biblioteca, Mesa |
| `BookRow` | Portada pequeña + título serif + detalle + extra | Lista, serie, Buscar, Cuaderno |
| `QuoteBlock` | Cita con raya de lápiz, etiqueta y nota; `hanging`: sin raya, rótulo en versalitas con línea fina y la comilla de apertura colgada en verde (ME-2) | «Donde lo dejaste» (hanging), subrayados |
| `TurnPreview` | Hoja chiquita (`Size.turnPreview`) que pasa con su estilo en bucle y la misma curva que la real (`TurnMotion`); las dos hojas se turnan, sin salto más despacio que la real (`Reader.previewPace`); la Hoja es una esquina que se dobla (`Reader.previewPause`, `previewLead`, `previewTurn`, `previewShadow`, `previewLines`) | Estilos de la hoja en «Aa» |
| `SegmentedChoice` | Opciones lado a lado; la elegida en papel sobre el carril (`Radius.segment`), la marca se desliza | Páginas o Continuo en «Aa» |
| `SessionLine` | La sesión en una línea verde que abre su tarjeta | Panel del lector |
| `ScrubberBar` | Barra de avance del lector: riel fino, lo leído en tinta, perilla chica que crece al arrastrar; se toca en 44 pt de alto | Panel del lector |
| `GuideShade` | Lectura guiada, el renglón (LG-B): el papel del libro al `Reader.guideShade` (72 %) sobre todo menos el renglón que lees; la guía viaja con `Motion.select` | Lector |
| `LookupCard` | «Consultar» (SG-4): al elegir texto, la palabra en serif, su traducción al español con el traductor de Apple (sola si los idiomas ya están descargados; si no, botón «Traducir»), el primer párrafo de Wikipedia en el idioma del libro (`Reader.lookupLines` 5) y el diccionario del sistema; vidrio como la tarjeta del subrayado | Lector, barra de selección |
| `SlitText` | La hendidura: el pedazo que se lee en `.bookTitle`; palabra por palabra (HE-A) con su letra de enfoque en `highlight`, fija al centro; por frase (HE-B), centrado | Hendidura |
| `ChapterLine` | En continuo, bajo el pie: rayita corta (`Reader.chapterLine` 64) con la tinta del libro que se llena con lo leído del capítulo; quieta (SC-C) | Pie del lector |
| `FooterPreview` | Muestra del pie: recorte chico de la parte de abajo de la página (papel, dos renglones fantasma y el pie tal cual, con su letra), sin nombre debajo (lo lee VoiceOver); filo de tinta y palomita si está elegido | Tarjeta del lector |
| `IconTile` | Mosaico chico: ícono arriba, nombre abajo; borde si está elegido; en tinta si es la acción principal | Estilo de la hoja, tarjeta de un subrayado, barra de selección |
| `FactRow` | Etiqueta / valor con línea fina y cifras exactas | Ficha del libro |
| `EmptyState` | `SectionHeader` con lo que falta, explicación y acción opcional con su ícono; los textos que se repiten salen de `EmptyCopy` | Toda lista vacía |
| `MacEmptyState`, `.macMainAction()` | En la Mac: el vacío con las mismas palabras (`EmptyCopy`) y el botón principal en `action` | Tabla, ficha y duplicados de la Mac |
| `LoadingLine` | Mientras algo tarda: la ruedita chica y qué estoy haciendo, en tinta secundaria («Buscando en internet…») | Ficha, Por revisar, Ajustes, Bienvenida, Conexiones, Calibre, Lector |
| `CloseButton` | El ✕ que cierra, en 44 y con su nombre para VoiceOver («Cerrar la tarjeta»); `.plain` o `.glass` | Consultar, tarjeta del subrayado, lectura guiada, Sesión, Hendidura |
| `TitleDetailRow` | Título en tinta y su detalle en gris debajo, en una fila de libreta | Calibre, Readwise, Por revisar, Apariencia |
| `ChoiceMark` | La palomita verde de lo elegido (o el círculo vacío) | Duplicados de la Mac, opciones |
| `LanguagePicker`, `StatusPicker` | Elegir idioma (con su nombre: «Español») y estado de lectura (`ReadingState`) iguales en el iPhone y la Mac | Editar datos, ficha de la Mac |
| `SaveShelfAlert`, `RenameShelfAlert`, `DeleteShelfConfirmation` | Guardar, renombrar y borrar una estantería: las mismas palabras en el iPhone y la Mac | Biblioteca, estantería, barra lateral de la Mac |
| `.errorAlert`, `.noticeAlert` | Aviso de un solo botón: el título dice qué pasó en primera persona («No pude abrir el libro»), el botón a dónde vuelves («Volver a la ficha») | Todo aviso de error o de algo que terminó |
| `LinkRow` | Fila de libreta (`Size.row`): título, valor, flecha y línea finísima debajo; con `marked` o `status`, su punto | «Por revisar», Ajustes |
| `StatTrio` | Tres cifras grandes con su rótulo en versalitas, centradas | Diario |
| `ThinProgress`, `Hairline`, `LetterIndex` | Progreso, separador, índice A–Z | — |
| `MiniPlayer` | Reproductor sobre el dock | Raíz |
| `BrandMark` | «GABINETE» en Cinzel, centrado (o a la izquierda) | Bienvenida, dentro de `DeskHeader` |
| `DeskHeader` | Encabezado de la Mesa: «GABINETE» a la izquierda, la fecha de hoy en versalitas a la derecha y una línea finísima que acaba en un trazo verde (`Size.deskMark`); MT-F, 25 nov 2026 | Arriba de la Mesa |
| `SectionLabel` | Mayúsculas romanas pequeñas (Cinzel, `Font.sectionLabel`), solo para el número y el capítulo; las secciones van con `SectionHeader` | «Nº 7» en la ficha, el capítulo sobre la tarjeta del lector |
| `AccentIconButton` | Ícono de acción en `accent` (verde botella, se distingue de la tinta), sin fondo: el único acento verde de una pantalla | «+» de la Biblioteca y del Cuaderno |
| `SecondaryButton`, `LinkRow` | Acción secundaria a lo ancho; fila que lleva a otra pantalla | «Por revisar» |
| `QuietButton` | Salida discreta, solo texto, bajo opciones que importan más | «Empezar sin libros» en la bienvenida |
| `CandidateRow`, `CandidateCover` | Libro encontrado en internet: probabilidad y razones en palabras | Elegir los datos |
| `CompareRow` | Dato nuevo frente al tuyo («Antes: …»), con «Deshacer» opcional | Vista previa, lo completado |
| `NoteRow` | Nota: título serif, dos líneas, fecha y libros enlazados en `accent` | Cuaderno › Notas, ficha › Notas, «Llevar a una nota» |
| `NoteBody` | Nota leída: título, párrafos `.prose`, citas con raya `accent`; `[[Libro]]` y «ir al pasaje» como enlaces | Nota |
| `PressableStyle`, `TrailingIconLabelStyle` | Respuesta al toque; etiqueta con el ícono después («Recientes ⇅») | Todo botón del sistema; órdenes |
| `ReaderPillButton` | Botón en cápsula del panel del lector; el destacado en tinta | «Guiada», «Escuchar» |
| `PlayRingButton`, `EqualizerBars` | Reproducir con el avance en anillo; barras de audio sonando | Mini reproductor |
| `StatTrio` | Tres números en serif con su leyenda | Sesión actual, resumen, ficha › Lectura, Diario |
| `StageBar`, `StageLegend` | La sesión como barra de etapas; leyenda con minutos | Resumen al cerrar, ficha, Diario |
| `StageChart` | Etapas en el tiempo, una fila por etapa (Swift Charts) | Sesión actual, una sesión pasada |
| `WordCounter` | Contador de palabras de la sesión, en verde | Lector, abajo a la izquierda |
| `FlowRow` | Fila que baja a otra línea si no cabe | Leyendas |
| `WeekBars` | Una barra por día (lunes a domingo), partida en etapas; hoy en tinta | Mesa › Esta semana, Diario › Semana |
| `MonthCalendar` | El mes como calendario: más oscuro cuanto más leíste; hoy con anillo | Diario › Mes |
| `YearBars` | Una barra por mes; el actual en verde | Diario › Año |
| `SessionRow` | Una sesión en una lista: cuándo, palabras, avance y duración | Diario, ficha › Lectura |
| `OptionRow` | Opción para elegir: ícono, título, explicación; la elegida con borde y marca verdes | Bienvenida |
| `ContentsRow` | Entrada del índice del libro, con sangría por nivel y punto verde donde vas | Lector › Índice |
| `SearchResultRow` | Resultado de buscar en el libro: texto alrededor, lo buscado en verde y negritas, su página a la derecha | Lector › Buscar |
| `SearchChapterHeading` | Capítulo en los resultados de buscar, con cuántas veces aparece | Lector › Buscar |
| `HereMark` | Raya verde «Aquí vas · pág. N» entre resultados | Lector › Buscar |
| `RecentSearchRow` | Búsqueda reciente: tocarla la repite; a la derecha cuántos resultados tuvo | Lector › Buscar |
| `SearchStepper` | Barrita de vidrio «‹ 4 de 23 · «palabra» ›» sobre la página, con ✕ | Lector |
| `SearchField` | Campo de búsqueda sobre `field`, con lupa y borrar; nunca `.searchable` (en Buscar quedaba escondido) | Buscar, Lector › Buscar |
| `ShareCard`, `ShareSessionButton` | Tarjeta verde fichero de una sesión, para compartir como imagen | Resumen al cerrar, una sesión pasada |
| `CoverChoiceRow`, `CoverChoiceCell` | Portadas para elegir (fila o cuadrícula); la elegida con borde `selection` | Vista previa, ficha › Elegir portada |

## Recetas

Toda pantalla nueva se arma con una de estas recetas y solo con piezas del catálogo. Si algo
no sale con ellas, se agrega una pieza o un token aquí primero; nunca se resuelve en la pantalla.

**Pestaña (Biblioteca, Cuaderno, Buscar)**
```swift
NavigationStack {
    ScrollView {
        VStack(alignment: .leading, spacing: 0) {
            ScreenHeading(title: "…") { /* acciones; el AccentIconButton, al final */ }
            FilterBar(…).padding(.top, Theme.Space.s)            // si hay partes
            CountLine(text: "32 libros · …") { SortMenu(…) }     // si es una lista
            /* contenido */.padding(.top, Theme.Space.l)
        }
        .screenContent()
    }
    .screen()
}
```

**Lista de libros:** `LazyVStack(spacing: 0) { ForEach { NavigationLink(value: book) { BookRow(book: book) }.buttonStyle(.plain) } }`

**Cuadrícula:** `CoverGrid { ForEach { NavigationLink(value: book) { CoverCell(book: book) }.buttonStyle(PressableStyle()) } }`

**Ajustes en tarjetas ilustradas (AJ-D, 26 nov 2026):**
```swift
NavigationStack {
    ScrollView {
        VStack(alignment: .leading, spacing: 0) {
            ScreenHeading(title: "Ajustes")
            SettingsCard(title: "Lectura", help: "Una línea.", more: "Lo largo.") {
                ReadingArt(…)                                      // el dibujo de lo que controla
            } content: {
                ToggleRow(…) · LinkRow(…) · FieldRow(…)            // filas de Size.row con su línea
            }
            Colophon(version: …)                                   // si es la última hoja
        }
        .screenContent()
    }
    .background(Theme.sunken.ignoresSafeArea())                    // el papel hondo
    .pushedScreen()
    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Listo") { dismiss() } } }
}
```

**Pantalla empujada u hoja (ficha, serie, herramientas del lector):**
```swift
ScrollView { VStack(alignment: .leading, spacing: Theme.Space.xl) { … }.screenContent() }
    .pushedScreen("Título")          // papel y título en línea; «Listo» en tinta, como iOS
    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Listo") { dismiss() } } }
```
Una hoja lleva además `.presentationDetents([.medium, .large])` o `[.large]`.

**Formulario del sistema (Conexiones, Editar datos):** `Form { Section("…") { … } }.formScreen()`,
y `.inlineTitle("…")` si es empujado. Nunca otro fondo ni otro color de botones. Para opciones
propias de Gabinete, mejor la hoja de libreta.

**Vacío:** siempre `EmptyState` con qué falta y cómo resolverlo; con acción si existe.

**Antes de dar por terminada una pantalla nueva**
1. ¿Sale de una receta y solo de piezas del catálogo?
2. ¿El verde marca solo dónde estás, lo que avanzas o lo tuyo? Las acciones, en tinta.
3. ¿Cada sección tiene su `SectionHeader` y se separa con línea y aire, no con cajas?
4. ¿Las cifras salen de una pieza con cifras exactas?
5. ¿Todo espacio es un token de la escala; todo lo que se toca, 44?
6. ¿Una sola acción principal, oscura?
7. `swift test --filter DesignRulesTests`, `scripts/lint-design.sh` y `tools/sistema-base/revisar.py` en verde.

## La Mac (MG-1, 26 nov 2026)

En la Mac, Gabinete es una app de Mac: la mesa de trabajo de tu biblioteca. Vive en
`App/Shared/Mac/` y usa los controles de macOS tal cual, porque es lo que se espera ahí:

| Parte | Qué es | Archivo |
|---|---|---|
| Barra lateral | Leer (Mesa, Cuaderno), la biblioteca por estado (todos, leyendo, por leer, leídos, por revisar, sin portada) con su cuenta, y Explorar por autor, serie, etiqueta o idioma | `MacLibraryWindow` |
| Tabla | `Table` nativa: ordenar por columna, elegir columnas (clic derecho en el encabezado; idioma, valoración, editorial, publicado e ISBN empiezan escondidas), selección múltiple, doble clic abre el libro, arrastrar archivos importa | `MacBookTable`, `MacBookRow` |
| Búsqueda | En la barra de la ventana, con filtros como Calibre: `autor:` `serie:` `etiqueta:` `idioma:` `editorial:` `estado:` `isbn:` `título:` (`LibraryQuery`, con sus pruebas) | `MacBookTable` |
| Ficha | `inspector` a la derecha: con un libro, todos sus datos; con varios, lo que escribas se aplica a todos y lo que dejes en blanco no cambia (`BulkEdit`, con sus pruebas) | `MacBookInspector` |
| Libro abierto | Cada libro en su propia ventana, con su nombre en la barra: lees con la biblioteca al lado y puedes tener varios abiertos. ⌘W lo cierra | `MacReaderWindow` |
| Menús | Archivo › Añadir libros… (⌘O) y Gabinete › Ajustes… (⌘,), como en toda app de Mac | `LectoraApp` |
| Ordenar autores, series y etiquetas | Clic derecho en la barra lateral › «Renombrar o juntar…»: escribir un nombre que ya existe es juntar, y los parecidos («Cortázar, Julio», «J. Cortázar») vienen marcados. En series, «Renumerar tomos 1, 2, 3…». ⌘Z deshace. Con autores y etiquetas queda la regla para lo que importes después (CB-2) | `MacCatalogSheet`, `CatalogRename` |
| Estantes | Búsquedas guardadas que se llenan solas (CB-1). En la Mac, «Guardar como estante» en la barra de la tabla y la sección Estantes en la barra lateral (clic derecho: renombrar o borrar). En el iPhone, «Guardar estos libros como estante» en Buscar, y cada estante como renglón en la Biblioteca. Viven en la carpeta (`.lectora/estantes.json`) | `SavedShelf`, `SavedShelfScreen` |
| Buscar datos en lote | Clic derecho en «Todos los libros» › «Buscar datos de N libros incompletos» (los que no tienen portada, sinopsis, ISBN, editorial o año), o en cualquier vista para todos sus libros; también el botón de la barra con varios elegidos. Uno tras otro con pausa (`BatchLookup.pause`); lo seguro se completa, lo dudoso va a Por revisar. Abajo, «Buscando datos · 7 de 14» con «Detener búsqueda» y al final el resumen (CB-4) | `MacBatchBar`, `BatchLookup` |
| Posibles duplicados | En la Mac, «Posibles duplicados» en la barra lateral (solo si hay): mismo título con autor parecido, o el mismo ISBN. Cada grupo con sus libros (autor, formatos, subrayados, avance, fecha); se queda por omisión el que tiene subrayados o avance, luego el EPUB. «Juntar en uno…» pide confirmación y dice qué pasa: el que se queda gana los formatos que no tenía en su misma carpeta, sus datos se completan, subrayados y marcadores pasan a él, y lo repetido va a la Papelera. «No son el mismo» no lo vuelve a proponer (`.lectora/no-duplicados.json`). La tabla muestra todos los formatos («EPUB · PDF») (CB-3) | `MacDuplicatesView`, `DuplicateFinder` |
| Buscar en todo | En la barra lateral (Leer): la misma pantalla Buscar del iPhone, con libros, subrayados y notas (SG-3). La búsqueda de la barra de la tabla sigue siendo solo de libros | `MacLibraryWindow`, `SearchScreen` |

Aquí no aplican las recetas del iPhone (`FilterBar`, `SearchField`, `PrimaryButton`): en la Mac
mandan la búsqueda de la barra, el botón del sistema (con el acento) y los formularios agrupados.
Sí aplican los tokens: las medidas de la ventana están en `Theme.Mac` y `scripts/lint-design.sh`
revisa también estos archivos. Mesa y Cuaderno son las mismas pantallas del iPhone.

## Simetría

Medida en las capturas del simulador (píxeles → puntos) y en el código:

- Margen lateral: 24 pt a ambos lados en todas las pantallas (`gutter`). Las filas que
  se desplazan (`FilterBar`) llegan al borde y alinean su primer texto con el margen.
- Título de pantalla: misma altura en Biblioteca, Cuaderno y Buscar (antes Buscar usaba
  el título del sistema, 35 pt más abajo y con 16–20 pt de margen).
- Lector: los controles de vidrio tienen el mismo margen (`Reader.chromeInset`, 16 pt)
  arriba y abajo; las zonas de toque izquierda y derecha son franjas iguales
  (`Reader.edgeZone`, 28 %). El revés de la hoja es el mismo papel con `Reader.pageBack` (93 %, papel y no cartón) de su luz. El lomo del libro es
  una sombra de `Reader.spineWidth` (26 pt) en la orilla izquierda, `Reader.spineShadeLight`
  (7 %) en papel claro y `Reader.spineShadeDark` (30 %) en oscuro; al pasar a la página
  siguiente, una vibración de `Reader.turnHaptic` (0,45), que se apaga en «Aa».
  La letra del libro sigue el tamaño de texto de iOS (`Reader.textBase`) además de lo que elijas en «Aa»; los títulos de libro, filas, citas y textos del libro también lo siguen, y las muestras del pie crecen con él. El texto va a `Reader.textMargin` (24 pt) de las orillas en páginas y en continuo y en todo iPhone, con 1,45 de aire entre renglones que el estilo del libro no cambia (D1-B y D2-B, 24 nov 2026): todos los renglones a la misma distancia, aunque el libro traiga su propio aire en sus clases, letras de otra fuente o llamadas de nota (25 nov 2026, `testLinesAreEvenlySpaced`); el contenido de la tarjeta de abajo empieza en esa misma línea. En páginas, el texto deja `Reader.pageMarginTop` (16 pt) arriba, justo debajo de la isla, y `Reader.pageMarginBottom` (64 pt) abajo, (abajo hasta la orilla de la pantalla);
  el capítulo y el pie van centrados en ese margen, y el contador de palabras en el mismo
  renglón que el pie; en continuo, una franja de papel sólido
  es sólido hasta la orilla del folio (el texto nunca se asoma detrás) y se desvanece en `Reader.folioFade` (56 pt) ya fuera de él con una curva (`Reader.folioFadeSteps`); abajo empieza `Reader.folioFadeDrop` (24 pt) más abajo, con el sólido justo arriba del pie (25 nov 2026): la letra se sigue leyendo mientras se va. Arriba ya no va el capítulo (25 nov 2026): solo el papel que se desvanece desde la orilla de la pantalla; en continuo el texto corre hasta arriba y se va en ese desvanecido (hasta `Reader.topFade` bajo la isla; el marcador cae `Reader.bookmarkLinesBelowFade` (2) renglones más abajo para que el desvanecido no lo borre, 26 nov 2026); sin la barra de desplazamiento del sistema y sin punto: bajo el pie, una rayita fina se llena con lo leído del capítulo (SC-C, 26 nov 2026), y el principio de cada capítulo empieza debajo de la isla. El folio
  usa la tinta del libro a `Emphasis.folio` (74 %). El marcador: en páginas marca la hoja con la cinta de la esquina; en continuo marca el renglón que lees arriba y se ve como un hilo en el aire entre renglones, casi invisible a la izquierda y verde al llegar al margen, donde se dobla en una cinta chica que viaja con el texto (MC-E1, 25 nov 2026; al marcar, la cinta cae y el hilo se dibuja; al quitarlo, el hilo se recoge hacia la cinta y la cinta sube). Tocando el centro, arriba quedan solo cerrar y el marcador, cada uno en su círculo de vidrio, y abajo sale la tarjeta, que ya no se sube (26 nov 2026) (el capítulo, con buscar, «Aa» y «Guiada» a su derecha; completo con su número encima en `SectionLabel`, que abre el índice, y a su derecha buscar y «Aa» (BB-C, 25 nov 2026); la barra, que se toca en 44 pt de alto aunque se vea fina (`Size.scrubberReach`); la página y las palabras en gris, sin íconos; tras saltar con la barra, en lugar de las palabras, «Volver a la pág. N» para regresar a donde ibas);
  Qué dice el pie se elige solo tocando el pie mientras lees: sale un globo «Abajo de la página» con cuatro `FooterPreview` chicos (como se leerá). Tocando el
  contador, la tarjeta de abajo se desvanece en su lugar (`Motion.exit`) y, ya ida, «Esta sesión» crece apenas desde abajo (nunca dos tarjetas encimadas); sale la tarjeta «Esta sesión» (números, etapas y «Escribir sobre ella»), no una hoja.
- Pasar la hoja (se elige en «Aa», en páginas): Hoja (mate, se dobla con el dedo; radio
  `Reader.curlRadius` 16 % del ancho, esquina inclinada `Reader.curlTilt`, sombra
  `Reader.curlShadow`, el texto se transparenta en el revés como a contraluz, `Reader.curlShowThrough` 22 % y apenas suave (`Reader.curlShowThroughBlur`); sin filo blanco (`Reader.curlMaskGrow`), dibujada a
  `Reader.curlScale` 2×), Deslizar (sombra `Reader.slideShadow` y `Reader.slideShadowRadius`),
  Fundido y Sin animación. La hoja se mueve con un resorte sin rebote (`TurnMotion`, fuerza
  `Reader.turnSpring`, unos 0,45 s desde quieta; el fundido, `Reader.fadeSpring`; deslizar, `Reader.slideSpring`, más firme, igual en las dos direcciones; un cuadro tarde avanza a lo más `Reader.turnFrameCap`, sin brinco): al soltar sigue
  con la velocidad del dedo (hasta `Reader.turnSpeedLimit`); con el dedo pasa después de
  `Reader.turnCommit` (30 % de lo que hay del toque a la orilla, al menos `Reader.turnReach` del ancho; la hoja va bajo el dedo desde que tocas, en las dos direcciones, y no espera a que el lector pinte la página; con un toque sí la espera, para no destapar papel liso) o al aventarla más rápido que `Reader.turnFling`.
  Nunca se leen dos textos encimados: al deslizar, la hoja es opaca y la de abajo sale de la
  sombra (`Reader.slideDim`); el fundido es un relevo (el texto de antes se va en la primera
  `Reader.fadeSpan` y el nuevo llega en la última, corridos `Reader.fadeDrift`).
  Antes de animar se espera a que WebKit pinte la página nueva. Al cambiar entre páginas y continuo,
  relevo: la página de antes se va (`Reader.flowOut`) y la nueva llega subiendo apenas (`Reader.flowIn`, `Reader.flowRise`), con un traslape corto (`Reader.flowHandoff`) cuando el lector avisa que ya acomodó el libro (o a lo más `Reader.flowSettle`). Al abrir un libro no se ven la página, los controles ni un número hasta que el libro deja de acomodarse (`Reader.openSettle` sin cambiar de página); luego la página entra con un fundido corto.
- Al seleccionar texto: barra de vidrio abajo (Subrayar en tinta, Nota, A una nota, Copiar), sin el
  menú negro del sistema.
- Buscar en el libro: empieza sola al dejar de escribir (`Reader.searchPause`, desde `Reader.searchMinLetters` letras); mientras busca dice cuánto lleva y los resultados aparecen abajo conforme llegan; van juntos por capítulo (`SearchChapterHeading`), cada uno con su página, y «Aquí vas» (`HereMark`) marca dónde lees; sin resultados, `EmptyState` explica que buscó sin importar acentos ni mayúsculas; al deslizar la lista se esconde el teclado. Antes de escribir, las últimas `Reader.recentSearches` búsquedas de ese libro (`RecentSearchRow`), guardadas solo en el dispositivo. Al ir a un resultado queda sobre la página `SearchStepper`: anterior, siguiente, el centro reabre la lista y la ✕ termina la búsqueda; se esconde mientras están los controles.
- Pestaña Buscar: busca en títulos, autores y series, en tus subrayados y en tus notas, en secciones (Libros, Tus subrayados, Tus notas; de subrayados, los primeros `Reader.foundHighlights` y «Ver los N»); lo buscado va en verde y negritas (`Found`, `QuoteBlock(match:)`, `NoteRow(match:)`). Vacía, tus búsquedas recientes y los `Reader.recentBooks` libros que abriste hace poco; el teclado no se abre solo. Lo escrito queda entre las recientes tras `Reader.searchRemember` sin escribir.
- Al tocar un subrayado: tarjeta de vidrio con la cita (hasta `Reader.highlightLines` líneas) y
  cuatro acciones en mosaicos: Nota, A una nota, Copiar, Borrar.
- Ajustes del lector («Aa»): sin muestra; la página de atrás ya cambia en vivo. Toda la hoja
  toma el tema elegido. La barra del tamaño tiene nueve niveles con su marca y un toque
  de vibración en cada uno.
- Cuadrículas: columnas iguales (`GridItem(.flexible())` ×3) con 16 pt entre columnas
  y 24 pt entre filas.

## Cómo se cuida

`Packages/LectoraCore/Tests/LectoraCoreTests/DesignRulesTests.swift` lee el código de la
app como texto, línea por línea (como en Orbital), y corre en CI con `swift test`:

| Prueba | Qué exige |
|---|---|
| `testScreensUseOnlyTokens` | Sin números (también decimales, sombras, escalas y proporciones), colores, fuentes, esperas, animaciones ni curvas a mano en ningún archivo de `App/Shared` (pantallas, piezas, lector y Mac); los patrones viven en `scripts/design-patterns.txt` y las exclusiones en `scripts/design-sources.txt`, que lee también el lint (SD-1, 26 nov 2026) |
| `testScreensUseCatalogPieces` | Sin segmentados, `.searchable`, vacíos del sistema, botones `bordered`, `DateFormatter`, formas ni estilos nuevos en las pantallas: son piezas de `Components.swift` |
| `testDesignPiecesDontKnowTheApp` | Las piezas de `Design/` no conocen `AppModel` ni los almacenes: reciben datos y avisan con acciones |
| `testOneMainActionPerScreen` | Una `PrimaryButton` y un `AccentIconButton` por pantalla, como mucho |
| `testSkippingIsNeverTheMainAction` | Saltar o no hacer nada («Ahora no», «Empezar sin…») nunca es `PrimaryButton`: va en `QuietButton` |
| `testScrollingScreensUseTheRecipe` | Toda pantalla con scroll usa `.screenContent()` |
| `testEveryPieceIsInTheCatalog` | Toda pieza de `Components.swift` tiene fila en el catálogo de arriba |
| `testEveryTokenIsUsed` | Ningún token de `Theme` sobra |
| `testExceptionsAreDocumented` | Toda `ds-exception` tiene su motivo en «Excepciones» |
| `testNoRedPencilLeft` | Decisión del 30 oct 2026: el rojo lápiz se fue; lo tuyo va en verde |
| `testDatesAndNumbersInSpanish` | Decisión del 18 nov 2026: fechas y porcentajes en español aunque el dispositivo no lo esté (`fecha.es(…)`, `percentText`); desde el 19 nov, todo porcentaje sale de `percentText` («57 %», con espacio que no se parte) |
| `testCountsAgreeWithTheirNumber` | Las cifras concuerdan con lo que cuentan: «1 libro», nunca «1 libros». Toda cifra con su sustantivo sale de `n.counted("libro", "libros")` (26 nov 2026) |
| `testNoArithmeticBetweenTokens` | Decisión del 19 nov 2026: ninguna medida se arma sumando tokens; se nombra en `Theme` |
| `testAccentActionGoesLast` | Decisión del 19 nov 2026: el ícono verde de un encabezado va siempre al final, a la derecha |
| `testPushedScreensUseTheRecipe` | Decisión del 22 nov 2026: ninguna pantalla arma a mano su fondo, su título en línea ni el color de los botones de la barra (van en tinta, como en iOS 26); usa `.screen()`, `.pushedScreen()` o `.formScreen()` |
| `testFormsUseThePaper` | Decisión del 19 nov 2026: todo `Form` lleva `.formScreen()` |
| `testNoPromisesOfFutureFeatures` | Decisión del 19 nov 2026: ningún texto dice «pronto» ni «próximamente»; lo que no funciona no se muestra |
| `testTextColorsAreReadable` | Decisión del 19 nov 2026: sobre `paper`, tinta y secundario ≥ 4,5 : 1; terciario y verde ≥ 3 : 1, en claro y oscuro |
| `testPageTurnNeverFreezesOrJumps` | Auditoría del 24 nov 2026: al pasar la hoja, nada se queda quieto a media vuelta ni brinca al final (la vuelta usa la foto que ya dio WebKit; un cuadro tarde avanza a lo más `Reader.turnFrameCap`) |
| `testLinesAreEvenlySpaced` | Decisión del 25 nov 2026: todos los renglones de un párrafo a la misma distancia, aunque el libro traiga su propio aire, letras de otra fuente o llamadas de nota |
| `testReadingNeverVibratesByItself` | Decisión del 24 nov 2026: leyendo, nada vibra porque la página avanzó; solo lo que haces tú (con «Vibrar al pasar de página» apagado, la barra de avance vibraba en cada hoja) |
| `testNoTextUnderTwelve` | Sistema base de la casa (SB-3), 24 nov 2026: ninguna letra de menos de 12 pt; `.caption2` (11) solo en íconos |
| `testRomanCapsOnlyForMarkAndLabels` | Decisión del 30 oct 2026: Cinzel solo por `BrandMark` y `SectionLabel` |
| `testOnlyPiecesPaintTheAccent` | Regla 1 (26 nov 2026): ninguna pantalla usa el verde directo; las acciones van en tinta (`TextAction`) |
| `testCapsComeFromThePieces` | Regla 3: las versalitas salen de `CapsText`, `SectionHeader` o `CountLine`, nunca a mano |
| `testSectionsUseTheirHeader` | Regla 3 (SD-2, 26 nov 2026): toda sección se anuncia con `SectionHeader` y su acción va dentro, no en un `HStack` a mano; `SectionLabel` solo para el «Nº» y el capítulo |
| `testFiguresAreExact` | Regla 4: toda pieza que enseña cifras las pone del mismo ancho |
| `testOneGreenForEverything` | Un solo verde: ningún color con tono verde se escribe fuera de `Theme.Green` (ni en `Theme.swift`, ni en pantallas, piezas o el libro), `action` y el color del sistema salen de él, y `reader.js` no escribe ningún color |
| `testSpacingKeepsTheHouseScale` | Regla 5 y SB-2 de la casa: sin 12 ni 6, y nada heredado en `sistema-base.json` |
| `testMainActionIsDarkInBothModes` | Regla 6: `Theme.action` igual y oscuro en los dos modos, y `PrimaryButton` lo usa |
| `testBoldOnlyForTitlesAndFigures` | D2-B de la casa: negrita solo en el título más grande y en cifras |
| `testEveryScreenFollowsARecipe` | Toda pantalla usa `.screen()`, `.pushedScreen()` o `.formScreen()`, así lo nuevo nace con la forma de la app |
| `testNoticesSayWhatHappened` | Regla 7 (SD-2, 26 nov 2026): todo aviso sale de `.errorAlert` o `.noticeAlert` (a mano solo si pide escribir), su título tiene tres palabras o más y dice qué pasó, y nada dice «No se pudo» |
| `testButtonsSayWhatTheyDo` | Regla 7 y SB-1: ningún botón dice solo «Cancelar», «OK», «Listo», «Cerrar», «Seguir»…; toda ✕ es `CloseButton` con su nombre |
| `testWaitingSaysWhat` | Regla 7: ninguna pantalla enseña una ruedita sola; `LoadingLine` dice qué estoy haciendo |
| `testSameWordsOnBothPlatforms` | Regla 8 (SD-3, 26 nov 2026): estados, acciones de la biblioteca, lo que haces con el texto, «Sin título» y la fecha corta salen de un solo lugar, y el iPhone y la Mac los usan |
| `ReadingStateTests` | Regla 8: lo que marcas manda y luego el avance; un nombre y un símbolo por estado; autores con « & » |

Cuando se decide algo de diseño que no debe volver a romperse, se vuelve una prueba con
su fecha. Lo que se entrega se reporta como dice [entrega.md](entrega.md).

## Excepciones

| Motivo | Dónde | Por qué |
|---|---|---|
| control nativo de Form | Reglas | Dentro de un `Form` del sistema, el segmentado nativo es lo esperado; `FilterBar` es para el contenido de una pantalla |
| portada dibujada | `CoverView` | La letra de la portada tipográfica es una fracción de su ancho (`Theme.CoverArt`), no un tamaño de la interfaz |
| fuente del lector | Lector › «Aa» | La muestra de cada fuente es la fuente que vas a leer, al tamaño que elegiste |
| índice A–Z | `LetterIndex` | Las 27 letras van en columna a la orilla, como el índice de Contactos: a 12 pt no caben en un iPhone chico |
| portadas generadas | `CoverStyle.generated` | Las doce cubiertas de los libros sin portada son colores de libro, no acentos: una de ellas es verde a propósito |
| paleta del lector | `ReaderPalette` | Los fondos del lector son sus propios tokens: el texto viaja como color CSS a la página |

### Lectura guiada (26 nov 2026: LG-B, AV-1, HE-A y HE-B, EN-1)

«Guiada», el tercer botón junto a buscar y «Aa» en la tarjeta de abajo, abre un menú:

- **Renglón (LG-B):** lo demás en penumbra (`GuideShade`). Tocar baja un renglón; tocar en la orilla izquierda (`Reader.edgeZone`) lo regresa. En páginas la guía baja por la página y al pasar del último renglón la hoja da vuelta sola; en continuo la guía se queda a `Reader.guideAnchor` (38 %) de la pantalla y lo que sube es el texto. El círculo de vidrio con ✕ arriba a la derecha la quita.
- **Hendidura (HE-B por frase, HE-A por palabra):** `SlitScreen`, el texto desde la página que ves hasta el fin del capítulo pasa por una ranura entre dos `Hairline`, con `Reader.slitContext` pedazos antes y después a `Emphasis.aside`. Frase o palabra se cambia arriba (`SegmentedChoice`); el ritmo, abajo, de 200 a 400 palabras/min (empieza en 260; la investigación no respalda más). Cada oración termina con un respiro. Tocar pausa; deslizar regresa o adelanta. Al cerrar, el libro queda donde ibas. El corte y los tiempos viven en `LectoraCore/Guided/Slit.swift`, con sus pruebas (`SlitTests`).
