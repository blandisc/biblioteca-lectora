# Sistema de diseño de Gabinete

Un solo estilo (Editorial): papel, tipografía y un verde escaso para la acción y tus marcas, sobre
componentes nativos de Apple. Todo valor visual es un **token**; toda pieza repetida es
un **componente**; toda pantalla sigue una **receta**.

## Regla

1. Las pantallas (`App/Shared/Screens/`, `Reader/ReaderView.swift`) **no usan números,
   colores ni fuentes sueltos**. Usan `Theme.*`, las fuentes de `Font` de abajo y los
   componentes de `Design/Components.swift`.
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
| `brand` | `#24332B` | `#8FBFA4` | Marca: botón principal, avance, pestaña elegida, el «+» de la Biblioteca (verde fichero) |
| `onBrand` | `#FFFFFF` | `#141413` | Texto sobre la marca |
| `secondaryInk` | `#6F6C65` | `#9C988F` | Texto secundario (contraste ≥ 4,5 sobre `paper`) |
| `tertiaryInk` | `#837F78` | `#7C7870` | Folios y etiquetas pequeñas (contraste ≥ 3 sobre `paper`) |
| `track` | `#E6E3DC` | `#34322E` | Pistas y separadores |
| `accent` | `#3D6B55` | `#8FBFA4` | Verde hoja, **solo tus marcas y avisos**: subrayado, nota, cinta, audio sonando, pendientes, índice A–Z, el «+» (antes `pencil`, rojo) |

**Etapas de lectura** (`Theme.stage(_:)`), del gris al verde fichero; se distinguen por
claridad, y en oscuro la más intensa es la más clara:

| Etapa | Claro | Oscuro |
|---|---|---|
| Interrumpida | `#D9D6CF` | `#4A4844` |
| Hojeo | `#CFDDD4` | `#3B5546` |
| Ligera | `#8FBFA4` | `#5E8B73` |
| Activa | `#3D6B55` | `#8FBFA4` |
| Inmersa | `#24332B` | `#B9DCC6` |

Los fondos del lector (Papel, Blanco, Noche cálida, Negro) viven en `ReaderPalette`.

### Espacio (`Theme.Space`, escala de 4 pt)

`xxs 2 · xs 4 · s 8 · m 12 · l 16 · xl 24 · xxl 32 · xxxl 48`

| Token | Valor | Uso |
|---|---|---|
| `gutter` | 28 | Margen lateral de toda pantalla, igual a ambos lados |
| `screenTop` | 24 | Del área segura al título de pantalla |
| `screenBottom` | 32 | Aire antes del dock |
| `chipInset` | 20 (`gutter − s`) | Interior de una fila de filtros que llega al borde: su primer texto cae en el margen |
| `hair` | 1 | Entre las letras del índice A–Z |
| `inline` | 6 | Entre un ícono y su texto; dentro de piezas pequeñas (leyendas, barras) |
| `rowY` | 10 | Aire arriba y abajo de una fila de lista |
| `rowGap` | 14 | Entre la portada (o la raya de una cita) y su texto |
| `buttonX` | 20 | Interior horizontal del botón principal |

**Nunca se suman tokens** («`s + xxs`», «`xl + xs`»): cada suma era un valor nuevo sin
nombre, y la misma separación salía distinta en cada pieza. Si hace falta otra medida,
se nombra aquí y en `Theme` (lo vigila `testNoArithmeticBetweenTokens`).

### Radio (`Theme.Radius`)

`swatch 2 · cover 3 · chip 8 · control 10 · tile 14 · capsule 22 · panel 28 · inset 12` (inset: lo que va dentro de un panel, concéntrico)

### Tamaño (`Theme.Size`)

`tapTarget 44 · control 46 · coverHero 132 · coverDetail 168 · coverEditor 84 · coverRow 40 ·
coverMini 26 · letterIndex 18 · gridColumns 3 · hairline 0.5 · progress 2 · quoteRule 2 · selection 2 · accentButton 44 ·
stageBar 8 · stageBarThin 4 · footerPreview 64 · footerPicker 320 (el globo del pie) · ghostLine 3 · scrubberKnob 14 · scrubberHeight 32 · scrubberReach 6 · excerptReach 60 (letras de contexto al encontrar algo en una nota) · dragSlop 6 · panelSwipe 24 · stageRow 26 · stageMark 16 · stageGap 1 · legendSwatch 8 · playRing 38 · equalizerBar 2 ·
textEditor 120 · ribbon 12×64 · appearanceSheet 584 (solo mientras se mide; luego la hoja mide su contenido) · grabber 36×5 · turnPreview 18×24 · macReader 720×820 · weekChart 112 · yearChart 80 · weekBar 18 · dayCell 34 · shareCard 300×375 ·
coverAspect 2∶3 (toda portada) · indentLevels 3 (sangrías del índice)`

`Theme.Emphasis`: `secondary` (0,75) texto secundario sobre la marca (tarjeta para compartir); `glassText` (0,8) texto callado sobre el vidrio del lector (subió de 0,72: en Noche cálida quedaba justo en el mínimo de contraste); `scrubberTrack` (0,25) riel de la barra de avance;
`pressed` (0,85) y `pressedScale` (0,97) al tocar, `rest` (1) en reposo; `labelMinScale` (0,8) lo más que se achica una etiqueta corta; `ghost` (0,12) renglones y filo de la muestra del pie; `folioMuted` (0,55) su pie sin dato; `knobGrow` (1,4) la perilla de la barra al arrastrar. Con controles, en páginas no hay franja detrás de los botones de arriba (arriba hay papel liso y el vidrio basta); en continuo, donde el texto corre por debajo, va la misma franja de papel que se desvanece del capítulo (decisión D3-B, 24 nov 2026).

### Portada tipográfica (`Theme.CoverArt`)

La portada que se dibuja para un libro sin imagen se escala con su ancho: cada medida
es una fracción de ese ancho (`inset` 0,09 · `title` 0,14 · `author` 0,07 · `spine` 0,05 ·
`ribbon` 0,065 …), así se ve igual en una fila de 40 pt y en la ficha de 168 pt. Sus
esquinas (`spineRadius` 2, `edgeRadius` 4) imitan un libro: lomo casi recto, canto redondeado.

### Identidad

Neoclásico mínimo: del mundo grecorromano solo las mayúsculas romanas, el
interpunto «·» y el aire. El gabinete (el portaetiquetas de latón de un cajón)
vive en el ícono; en la app solo queda su color. Verde con mesura: la acción
principal y, como mucho, **un** ícono de acción en verde por pantalla (`AccentIconButton`).
El modo oscuro se queda neutro; solo cambia el verde.
Ícono en `App/Resources/Assets.xcassets/AppIcon.appiconset`: verde fichero
(claro), tinta (oscuro) y tintado; los PNG se generan desde el diseño del lienzo.

### Tipografía (`Font`)

| Token | Fuente | Uso |
|---|---|---|
| `.screenTitle` | New York 30 medium | Título de pantalla |
| `.bookTitle` | New York 28 medium | Libro protagonista (Mesa, ficha), títulos de estado vacío |
| `.rowTitle` | New York 17 | Títulos en filas, citas |
| `.quote` | New York 17 itálica | «Donde lo dejaste» |
| `.prose` | New York 16 | Sinopsis |
| `.brandMark` | Cinzel 16, espaciado `Tracking.brandMark` | «GABINETE» en la Mesa |
| `.sectionLabel` | Cinzel 12 medium, mayúsculas, `Tracking.sectionLabel` | Rótulos de sección |
| Sistema | SF (`.body`, `.subheadline`, `.footnote`, `.caption`) | Toda la interfaz |

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
| `.formScreen()` | Receta de formulario: el papel de la app de fondo, no el gris del sistema; botones e interruptores en `accent` (con la marca, casi negra en claro, parecían texto) | Ajustes, Conexiones, Reglas, Editar datos, Buscar con otros datos |
| `.pushedScreen(título)` | Receta de pantalla empujada u hoja: papel, título en línea, controles del contenido en `accent`; los botones de la barra de vidrio, en tinta como en iOS 26 | Ficha, serie, nota, Diario, Por revisar, Lector › herramientas, Sesión, Llevar a una nota, Traer de Calibre, Bienvenida |
| `.inlineTitle(título)` | Título pequeño en la barra (lo usan `.pushedScreen` y los formularios empujados) | Conexión, Editar datos, Buscar con otros datos |
| `.screenContent()` | Margen `gutter`, aire `screenTop`/`screenBottom`, tinta | Todo contenido con scroll |
| `ScreenHeading` | Título serif + acciones a la derecha | Cada pantalla |
| `PrimaryButton` | Acción principal en tinta (una por pantalla) | «Seguir leyendo», «Leer», estado vacío |
| `RoundIconButton` | Botón redondo secundario | Audiolibro |
| `FilterBar` | Opciones en texto; la activa con fondo `field` | Filtros de Biblioteca, secciones del Cuaderno |
| `ShelfCover` / `CoverView` | Portada real o tipográfica, con lomo | Toda portada |
| `SeriesStack` | Pila de portadas de una serie | Biblioteca |
| `CoverCell` + `CoverGrid` | Celda y cuadrícula de 3 columnas | Biblioteca, Mesa |
| `BookRow` | Portada pequeña + título serif + detalle + extra | Lista, serie, Buscar, Cuaderno |
| `QuoteBlock` | Cita con raya de lápiz, etiqueta y nota | «Donde lo dejaste», subrayados |
| `TurnPreview` | Hoja chiquita (`Size.turnPreview`) que pasa con su estilo en bucle y la misma curva que la real (`TurnMotion`); las dos hojas se turnan, sin salto más despacio que la real (`Reader.previewPace`); la Hoja es una esquina que se dobla (`Reader.previewPause`, `previewLead`, `previewTurn`, `previewShadow`, `previewLines`) | Estilos de la hoja en «Aa» |
| `SegmentedChoice` | Opciones lado a lado; la elegida en papel sobre el carril (`Radius.segment`), la marca se desliza | Páginas o Continuo en «Aa» |
| `Grabber` | Rayita de un panel que se sube | Panel del lector |
| `SessionLine` | La sesión en una línea verde que abre su tarjeta | Panel del lector |
| `ScrubberBar` | Barra de avance del lector: riel fino, lo leído en tinta, perilla chica que crece al arrastrar; se toca en 44 pt de alto | Panel del lector |
| `FooterPreview` | Muestra del pie: recorte de la página (papel, tres renglones fantasma y el pie tal cual, con su letra) y su nombre debajo; filo de tinta y palomita si está elegido | Tarjeta del lector |
| `IconTile` | Mosaico chico: ícono arriba, nombre abajo; borde si está elegido; en tinta si es la acción principal | Estilo de la hoja, tarjeta de un subrayado, barra de selección |
| `FactRow` | Etiqueta / valor con línea fina | Ficha del libro |
| `EmptyState` | Título, explicación y acción opcional | Toda lista vacía |
| `ThinProgress`, `Hairline`, `LetterIndex` | Progreso, separador, índice A–Z | — |
| `MiniPlayer` | Reproductor sobre el dock | Raíz |
| `BrandMark` | «GABINETE» en Cinzel, centrado | Arriba de la Mesa |
| `SectionLabel` | Rótulo en mayúsculas romanas pequeñas (Cinzel, `Font.sectionLabel`) | «EN LA MESA», «SE COMPLETARON SOLOS», «Nº 7» en la ficha |
| `AccentIconButton` | Ícono de acción en `accent` (verde hoja, se distingue de la tinta), sin fondo: el único acento verde de una pantalla | «+» de la Biblioteca y del Cuaderno |
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
| `WordCounter` | Contador de palabras de la sesión, en verde hoja | Lector, abajo a la izquierda |
| `FlowRow` | Fila que baja a otra línea si no cabe | Leyendas |
| `WeekBars` | Una barra por día (lunes a domingo), partida en etapas; hoy en tinta | Mesa › Esta semana, Diario › Semana |
| `MonthCalendar` | El mes como calendario: más oscuro cuanto más leíste; hoy con anillo | Diario › Mes |
| `YearBars` | Una barra por mes; el actual en verde hoja | Diario › Año |
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

**Pantalla raíz de pestaña**
```swift
NavigationStack {
    ScrollView {
        VStack(alignment: .leading, spacing: 0) {
            ScreenHeading(title: "…") { /* acciones */ }
            FilterBar(…).padding(.top, Theme.Space.m)        // opcional
            /* contenido */.padding(.top, Theme.Space.l)
        }
        .screenContent()
    }
    .screen()
}
```

**Lista de libros:** `LazyVStack(spacing: 0) { ForEach { NavigationLink(value: book) { BookRow(book: book) }.buttonStyle(.plain) } }`

**Cuadrícula:** `CoverGrid { ForEach { NavigationLink(value: book) { CoverCell(book: book) }.buttonStyle(PressableStyle()) } }`

**Pantalla empujada u hoja (ficha, serie, herramientas del lector):**
```swift
ScrollView { VStack(alignment: .leading, spacing: Theme.Space.xl) { … }.screenContent() }
    .pushedScreen("Título")          // papel y título en línea; «Listo» en tinta, como iOS
    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Listo") { dismiss() } } }
```
Una hoja lleva además `.presentationDetents([.medium, .large])` o `[.large]`.

**Formulario (Ajustes, Conexiones, Editar datos):** `Form { Section("…") { … } }.formScreen()`,
y `.inlineTitle("…")` si es empujado. Nunca otro fondo ni otro color de botones.

**Vacío:** siempre `EmptyState` con qué falta y cómo resolverlo; con acción si existe.

## Simetría

Medida en las capturas del simulador (píxeles → puntos) y en el código:

- Margen lateral: 28 pt a ambos lados en todas las pantallas (`gutter`). Las filas que
  se desplazan (`FilterBar`) llegan al borde y alinean su primer texto con el margen.
- Título de pantalla: misma altura en Biblioteca, Cuaderno y Buscar (antes Buscar usaba
  el título del sistema, 35 pt más abajo y con 16–20 pt de margen).
- Lector: los controles de vidrio tienen el mismo margen (`Reader.chromeInset`, 16 pt)
  arriba y abajo; las zonas de toque izquierda y derecha son franjas iguales
  (`Reader.edgeZone`, 28 %). El revés de la hoja es el mismo papel con `Reader.pageBack` (93 %, papel y no cartón) de su luz. El lomo del libro es
  una sombra de `Reader.spineWidth` (26 pt) en la orilla izquierda, `Reader.spineShadeLight`
  (7 %) en papel claro y `Reader.spineShadeDark` (30 %) en oscuro; al pasar a la página
  siguiente, una vibración de `Reader.turnHaptic` (0,45), que se apaga en «Aa».
  La letra del libro sigue el tamaño de texto de iOS (`Reader.textBase`) además de lo que elijas en «Aa»; los títulos de libro, filas, citas y textos del libro también lo siguen, y las muestras del pie crecen con él. El texto va a `Reader.textMargin` (28 pt) de las orillas en páginas y en continuo y en todo iPhone, con 1,45 de aire entre renglones que el estilo del libro no cambia (D1-B y D2-B, 24 nov 2026): todos los renglones a la misma distancia, aunque el libro traiga su propio aire en sus clases, letras de otra fuente o llamadas de nota (25 nov 2026, `testLinesAreEvenlySpaced`); el contenido de la tarjeta de abajo empieza en esa misma línea. En páginas, el texto deja `Reader.pageMarginTop` (12 pt) arriba, justo debajo de la isla, y `Reader.pageMarginBottom` (68 pt) abajo, (abajo hasta la orilla de la pantalla);
  el capítulo y el pie van centrados en ese margen, y el contador de palabras en el mismo
  renglón que el pie; en continuo, una franja de papel sólido
  es sólido hasta la orilla del folio (el texto nunca se asoma detrás) y se desvanece en `Reader.folioFade` (56 pt) ya fuera de él con una curva (`Reader.folioFadeSteps`); abajo empieza `Reader.folioFadeDrop` (20 pt) más abajo, con el sólido justo arriba del pie (25 nov 2026): la letra se sigue leyendo mientras se va. Arriba ya no va el capítulo (25 nov 2026): solo el papel que se desvanece desde la orilla de la pantalla; en continuo el texto corre hasta arriba y se va en ese desvanecido (hasta `Reader.topFade` bajo la isla), y el principio de cada capítulo empieza debajo de la isla. El folio
  usa la tinta del libro a `Emphasis.folio` (74 %). Tocando el centro sale la tarjeta (`Grabber`; el capítulo completo con su número encima en `SectionLabel`, que abre el índice; la barra, que se toca en 44 pt de alto aunque se vea fina (`Size.scrubberReach`); la página y las palabras en gris, sin íconos; tras saltar con la barra, en lugar de las palabras, «Volver a la pág. N» para regresar a donde ibas);
  subiéndola aparece «El pie dice» con cuatro `FooterPreview` (como se leerá). Tocando el pie mientras lees sale solo un globo con esas cuatro muestras, sin la tarjeta (25 nov 2026). Tocando el
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
  relevo: la página de antes se va (`Reader.flowOut`) y la nueva llega subiendo apenas (`Reader.flowIn`, `Reader.flowRise`), con un traslape corto (`Reader.flowHandoff`) cuando el lector avisa que ya acomodó el libro (o a lo más `Reader.flowSettle`). Al abrir un libro no se ven la página, los controles ni un número hasta que el libro deja de acomodarse (`Reader.openSettle` sin cambiar de página); luego la página entra con un fundido corto. Las primeras `Reader.panelHints` veces el panel se asoma hacia arriba (`panelHintDelay`, `panelHintHold`); al arrastrarlo, el panel va bajo el dedo hacia donde puede ir y cede con resistencia (`Reader.panelResistance`) hacia donde no; lo de adentro se recorta a su vidrio; los mosaicos del pie entran en cascada (`Motion.stagger`).
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
| `testScreensUseOnlyTokens` | Sin números (también decimales, sombras, escalas y proporciones), colores, fuentes, animaciones ni curvas a mano en las pantallas **ni dentro de las piezas** (`Design/`, «Aa» del lector); desde el 22 nov 2026 |
| `testScreensUseCatalogPieces` | Sin segmentados, `.searchable`, vacíos del sistema, botones `bordered`, `DateFormatter`, formas ni estilos nuevos en las pantallas: son piezas de `Components.swift` |
| `testDesignPiecesDontKnowTheApp` | Las piezas de `Design/` no conocen `AppModel` ni los almacenes: reciben datos y avisan con acciones |
| `testOneMainActionPerScreen` | Una `PrimaryButton` y un `AccentIconButton` por pantalla, como mucho |
| `testSkippingIsNeverTheMainAction` | Saltar o no hacer nada («Ahora no», «Empezar sin…») nunca es `PrimaryButton`: va en `QuietButton` |
| `testScrollingScreensUseTheRecipe` | Toda pantalla con scroll usa `.screenContent()` |
| `testEveryPieceIsInTheCatalog` | Toda pieza de `Components.swift` tiene fila en el catálogo de arriba |
| `testEveryTokenIsUsed` | Ningún token de `Theme` sobra |
| `testExceptionsAreDocumented` | Toda `ds-exception` tiene su motivo en «Excepciones» |
| `testNoRedPencilLeft` | Decisión del 30 oct 2026: el rojo lápiz se fue; lo tuyo va en verde hoja |
| `testDatesAndNumbersInSpanish` | Decisión del 18 nov 2026: fechas y porcentajes en español aunque el dispositivo no lo esté (`fecha.es(…)`, `percentText`); desde el 19 nov, todo porcentaje sale de `percentText` («57 %», con espacio que no se parte) |
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

Cuando se decide algo de diseño que no debe volver a romperse, se vuelve una prueba con
su fecha. Lo que se entrega se reporta como dice [entrega.md](entrega.md).

## Excepciones

| Motivo | Dónde | Por qué |
|---|---|---|
| control nativo de Form | Ajustes › Apariencia, Reglas | Dentro de un `Form` del sistema, el segmentado nativo es lo esperado; `FilterBar` es para el contenido de una pantalla |
| portada dibujada | `CoverView` | La letra de la portada tipográfica es una fracción de su ancho (`Theme.CoverArt`), no un tamaño de la interfaz |
| fuente del lector | Lector › «Aa» | La muestra de cada fuente es la fuente que vas a leer, al tamaño que elegiste |
| índice A–Z | `LetterIndex` | Las 27 letras van en columna a la orilla, como el índice de Contactos: a 12 pt no caben en un iPhone chico |
| paleta del lector | `ReaderPalette` | Los fondos del lector son sus propios tokens: el texto viaja como color CSS a la página |
