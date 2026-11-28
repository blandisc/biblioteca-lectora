# Sistema de diseño de Gabinete: la libreta del futuro

Cómo se vería una libreta fina en el futuro: la misma elegancia, con minimalismo tecnológico.
Precisión en vez de materiales: líneas finísimas, mucho aire, versalitas, cifras exactas y un
solo verde. Nada de cuero, hendidos ni costuras (decisión del 25 nov 2026; sistema elegido el
26 nov 2026 con AC-3, SD-1 a SD-8 y AJ-B).

Todo valor visual es un **token**; toda pieza repetida es un **componente**; toda pantalla
sigue una **receta**; toda regla tiene una **prueba** que falla si alguien la rompe. Lo nuevo
se arma con lo que ya hay: si falta algo, se agrega aquí primero.

## Las nueve reglas de la libreta

Cada regla dice lo que nota quien usa la app; la medida exacta vive en `Theme` con su nombre.

| # | Regla | Lo que notas | La cuida |
|---|---|---|---|
| 1 | **Un solo verde, y poco** | El verde botella marca solo dónde estás (pestaña, filtro elegido y, en la Mac, lo elegido en la tabla y la barra lateral), lo que avanzas (palabras, la marca de la Mesa) y lo tuyo (subrayados, cinta, pendientes). Las acciones van en tinta, también las de un formulario o una hoja («Elegir de Fotos», «Elegir archivo») y los controles de la barra de la ventana en la Mac (el menú de filtros salía verde sin ningún filtro puesto: verde solo con uno puesto, auditoría 4): las recetas no las tiñen y solo un interruptor prendido va en verde (`AccentSwitchStyle`, auditoría de medios). Es el mismo verde en todos lados | `testOnlyPiecesPaintTheAccent`, `testOneGreenForEverything` |
| 2 | **Líneas finas en vez de cajas** | Las secciones se separan con una línea finísima y aire, no con tarjetas grises. La excepción es Ajustes: tarjetas blancas con su dibujo sobre un papel más hondo (AJ-D, 26 nov 2026) | `testScreensUseCatalogPieces` (sin formas a mano), `SectionHeader`, `SettingsCard`, `ScreenHeading` |
| 3 | **Rótulos en versalitas** | Toda sección se anuncia igual en el iPhone: mayúsculas chicas, espaciadas, con su línea a la derecha y, si hay, su acción al final; en un formulario (Editar datos, Reglas, Conexiones), su rótulo es `CapsText`, no el gris del sistema (auditoría de medios). Las romanas (Cinzel) quedan para la marca, el «Nº» y el capítulo. Un nombre en árabe, hebreo u otra escritura que une sus letras va sin espaciar, como se escribe (UX-1c) | `testCapsComeFromThePieces`, `testSectionsUseTheirHeader` |
| 4 | **Cifras exactas** | Cantidades, fechas y porcentajes no bailan: todas las cifras miden lo mismo. Y se dicen bien en español: «1 libro», «1 día de 7», «noviembre de 2026» en minúscula; un conteo cuenta lo que ves (con un filtro, los libros de ese filtro) | `testFiguresAreExact`, `testDatesAndNumbersInSpanish`, `testCountsAgreeWithTheirNumber` |
| 5 | **Aire en una sola escala** | Todo espacio sale de 4 · 8 · 16 · 24 · 32 · 48, la escala común de la casa | `testSpacingKeepsTheHouseScale`, `tools/sistema-base` (SB-2) |
| 6 | **Botón principal oscuro en los dos modos** | «Seguir leyendo» y «Nota nueva» en verde fichero con letra clara, también en oscuro, con un filo finísimo | `testMainActionIsDarkInBothModes`, `testOneMainActionPerScreen` |
| 7 | **Te hablo de tú y digo qué pasó** | Los avisos dicen qué pasó en primera persona («No pude abrir el libro», nunca «No se pudo» ni «Aviso»), y su botón a dónde vuelves («Volver a la ficha»). Los botones dicen qué hacen: nunca «Cancelar», «OK» ni «Listo» a secas; salir sin cambiar es «Dejar como está», y toda pregunta trae su botón para quedarse (`role: .cancel`, «Conservar la nota», «Seguir conectado»), nunca el «Cancelar» del sistema, y siempre a la vista: la pregunta es un aviso al centro (`.question`), nunca un globo que lo esconde (auditoría 8). Lo que hago lo digo yo: «Borro tu llave», «Copio tus libros», «Anoto cada sesión», nunca «Se borra», «Se copian» ni «Se anota» (auditoría de medios y 3). Mientras algo tarda, digo qué estoy haciendo; y un vacío dice lo que de verdad pasa: mientras bajo tu biblioteca de iCloud no digo «Todavía no hay libros» ni ofrezco añadirlos (te llevaba a importarlos dos veces) en ninguna pantalla, y si dejé de esperar te lo digo y te dejo añadir o volver a la bienvenida (`LibraryEmptyKind`, auditoría 4). Mientras bajo tu biblioteca de iCloud no traigo ni añado libros por ningún lado, ni muevo, ni cambio de carpeta, ni ordeno tu Gabinete: ninguna entrada lo ofrece (el «+», la barra y el menú de la Mac, arrastrar, la bienvenida, Ajustes, «Mover a iCloud Drive u otra carpeta», «Volver a la carpeta de este dispositivo» y Traer de Calibre se ven apagados y dicen por qué), la biblioteca misma se niega aunque algo se lo pida, y no digo «0 libros» (auditorías 5, 6 y 8); cada aviso trae su propio título y lo que no se puede tocar se ve apagado, también un botón (`PrimaryButton`, `SecondaryButton`, `TextAction`: «Elige los libros» seguía en tinta, auditoría 8). Lo que ya hiciste no se ofrece otra vez: una búsqueda guardada como estante dice dónde quedó. Y toda salida cierra la pantalla: el botón que dice que te lleva a otro lado te lleva, aunque ya hubieras pasado por ahí (auditoría 5: «Volver a la bienvenida» te dejaba atrapado). Lo que no entiende la app tampoco sale crudo: un error del lector web se dice en español («No pude leer el archivo de este libro», nunca «Load failed»), y una ventana de un libro que ya no está no se vuelve a abrir sola: se cierra y abre la biblioteca (auditoría 7); pero el libro que lees no se cierra porque cambie de carpeta (lo identificas, cambias su autor, ordenas o mueves el Gabinete) ni porque su archivo siga en iCloud: lo bajo y sigues leyendo (auditoría 8) | `testNoticesSayWhatHappened`, `testReaderErrorsInSpanish`, `testRestoredReaderOfAMissingBookCloses`, `testReaderStaysOpenWhenItsFolderMoves`, `testCabinetStaysPutWhileDownloading`, `testButtonsSayWhatTheyDo`, `testWaitingSaysWhat`, `testEveryWelcomeExitClosesIt`, `testAddingBooksWaitsForICloudEverywhere`, `testNothingComesInWhileDownloading` |
| 8 | **Lo mismo se llama igual en el iPhone y la Mac** | Un libro está «Leyendo», «Por leer» o «Leído» por la misma regla en las dos; añadir libros, buscar datos, lo que haces con el texto elegido y los datos de un libro tienen un solo nombre y un solo ícono; los autores se separan con « & »; un idioma se dice por su nombre («Español», nunca «es») y Buscar se llama igual en la pestaña, el título y su campo («Buscar en…»). Y cada cosa se dice una vez: en la Mac el nombre de la pantalla va en la barra de la ventana, no repetido en el contenido, y lo que se abre dentro (el Diario desde la Mesa) pone el suyo; Ajustes se abre con ⌘, en pestañas, sin engrane dentro de una pantalla (MX-B). Y cada dispositivo se llama por su nombre: lo que se ve en los tres dice «En este iPhone», «En este iPad» o «En esta Mac» según dónde estás, con su dibujo, nunca «iPhone» fijo (`DeviceKind`, auditoría 2). En la Mac, «Todos los libros» se llama igual en la barra lateral y en la de la ventana. Y dos textos nunca se pegan: lo que tecleas no se suma a un nombre ya escrito (el campo empieza vacío y lo propuesto o el nombre de ahora va de pista, también al renombrar en la Mac) y el título del capítulo no se junta con su primera frase (UX-7, UX-8b). Y se habla en palabras, no en lo que entiende la máquina: nunca una ruta («Notas/x.md»), la búsqueda cruda de un estante («autor:asimov» → «de Asimov», `SavedShelf.describe`) ni el marcado de una nota («# Ideas» en un pasaje encontrado) ni el nombre de su formato («Markdown»: son notas que abre también Obsidian, auditoría 3), ni cómo se escribe un enlace o un filtro («[[», «autor:») ni el nombre de un archivo («metadata.db»): se dice en palabras (auditoría 8). Un nombre tuyo en hebreo o árabe junto a cifras o a «·» no revuelve su renglón: va aislado (`.isolated`, auditoría 8); en la Mac los filtros de la búsqueda tienen su menú con nombre (auditoría de medios) | `testSameWordsOnBothPlatforms`, `ReadingStateTests`, `testMacSaysTheNameOnce`, `testTextsNeverRunTogether`, `testPeopleReadWordsNotSyntax` |
| 9 | **Cabe con la letra más grande y se toca con el dedo** | Con la letra más grande de iOS (AX5) nada se sale de la pantalla ni se parte a media palabra con guion («Wake-/field», auditoría 8): un título que no cabe va primero en dos renglones, luego un poco más chico (`WholeWordsText`: hasta tres pasos y, con la letra grande, nunca menos que la normal) y al final termina en «…», nunca a media palabra con guion; un renglón de código corre de lado y el pie de una portada pone el estado y el autor uno bajo otro antes que dejar «Nuevo ·…»; los títulos crecen, lo que va lado a lado se pone uno bajo otro y los nombres usan dos renglones en vez de cortarse o achicarse, y las muestras que se comparan («Aa» en cada letra) miden lo mismo; un texto que no cabe ni en dos dice su versión corta (el pie del lector: «3 min para el capítulo», luego «3 min»; la pista de Buscar: «Buscar»); lo que flota sobre el libro (su tarjeta, la barra de lo elegido) o queda fijo al pie de una lista (`BottomBar`) tiene tope de letra (`Letter.readerChromeLargest`) y no tapa media página, y la muestra «Aa» de cada fondo cabe en su círculo, todos a la misma altura; un conteo deja su aire bajo los filtros, y el punto de una fila va a la altura de su primer renglón; una hoja con dos botones de texto lleva su título debajo de ellos, donde sí cabe, y con la letra más grande el segundo («Guardar cambios», «Ir a la biblioteca») baja entero al pie en vez de esconderse en el «•••» de iOS (`.sheetActions`, auditoría 3); dos botones lado a lado miden lo mismo y van en un renglón, o uno bajo otro (`ButtonPair`); un conteo nunca separa una cifra de su palabra ni un renglón deja el «·» colgando (`DotLine`); una hoja que abre a media pantalla se desplaza y crece a todo lo alto, así sus botones de abajo siempre se alcanzan (con la letra más grande abre ya a todo lo alto), y en la Mac ninguna hoja es más alta que la ventana más chica (`Mac.sheetMax`) y cada una mide su contenido, sin quedar medio vacía: lo de abajo, como «Ir a la biblioteca» en la bienvenida, queda a la vista (auditoría 2). Lo que va en fila y no cabe (filtros) baja entero al renglón de abajo, y si ni solo cabe, usa dos renglones; lo que flota sobre una lista (el índice A–Z) le deja su lugar y no tapa nada: empieza debajo del orden, las filas le dejan su columna y con la letra más grande no sale; una portada de otra forma cabe entera en su marco. Todo lo que se toca responde en 44 × 44 aunque se dibuje chico (SB-4); en el lector, ningún botón tapa el primer renglón ni se sale por arriba, aunque la pantalla no tenga isla (el iPhone Duo cerrado lleva la hora al costado). Cabe en cualquier pantalla del iPhone, acostado y en el Duo cerrado o abierto, sin preguntar qué aparato es (lo dice la forma de la ventana, `WindowLayout`): nada cruza el pliegue (el texto se queda en un renglón cómodo de unas 68 letras, `ReadingColumn`, y lo que va en dos partes pone cada una en su página, `Spread`, `FoldSplit`, `.sidePanel`); en una pantalla baja el encabezado es de un renglón y se ve al menos un libro entero (las portadas ponen más columnas en vez de crecer, por ancho y por alto: `CoverColumns`); lo que va pegado a la franja del sistema le deja su aire, y una hoja enseña su título aunque iOS ponga la hora al costado (`LargeSheetTitle`); cada hoja y pantalla completa dice dónde van las barras (`duoBars()`, iPhone Duo 27 nov 2026). En la Mac, lo largo de la tabla y de la ficha (también lo escrito en sus campos) se corta con «…» en vez de partirse o salirse: las columnas se encogen hasta `Mac.narrowColumn` antes que correr de lado bajo la ficha, con la ficha abierta solo van las de más peso y el título cede antes que el autor y la serie (`Mac.nameColumn`); en la ficha lo escrito va en tinta y su pista, más callada (`.fieldPrompt`), y la tarjeta del libro mide lo que su columna (`Size.readingPanel`), centrada (MX-B, UX-3b, auditoría de medios); en la tabla ancha el título se queda con lo que sobra y las columnas de a lado tienen tope, una columna sin dato dice «—» y, angosta, la fecha va en cifras («26/11/26»). Nada se lee a medias: un texto cortado siempre termina en «…», entre palabras (la vista previa de una nota se cortaba a media palabra), y la razón de un botón apagado siempre se lee completa, en los renglones que haga falta (`ReasonLine`; en Ajustes de la Mac se cortaba en uno, auditoría 7) | `testFitsLargeTextAndFingers` |

### Las reglas de la casa (interoperabilidad)

Gabinete cumple el sistema base común a todas las apps de Fernando
(`~/code/interoperabilidad/sistema-base`, copia en `tools/sistema-base/`, corre en CI):

| Regla | Qué exige | La cuida |
|---|---|---|
| SB-1 | Botones y avisos que dicen qué hacen («Crear nota», no «Crear» u «OK») | `tools/sistema-base/revisar.py` |
| SB-2 | Solo la escala 4 · 8 · 16 · 24 · 32 · 48 · 64. Desde el 26 nov 2026 Gabinete no arrastra nada heredado: se fueron el 12 y el 6 | `revisar.py`, `testSpacingKeepsTheHouseScale` |
| SB-3 | Ninguna letra de menos de 12 | `revisar.py`, `testNoTextUnderTwelve` |
| SB-4 | Todo lo que se toca responde en 44 × 44 | `revisar.py`, `testFitsLargeTextAndFingers` (regla 9) |
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
| `onSelection` | del sistema | del sistema | Solo en la Mac: la letra de una fila elegida en la tabla, sobre el verde de la selección (`MacCell`, MX-B); blanca, 4,7 : 1 sobre el verde en oscuro |

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
| `screenTop` | 24 (Mac 0) | Del área segura al título de pantalla. En la Mac no hay título en el contenido y la barra de la ventana ya deja su aire: el contenido empieza ahí (con 24 quedaba un hueco de 40 a 50 pt) |
| `screenTopInSheet` | 16 | En la Mac, el aire de arriba de una hoja con scroll (la nota abierta desde la ficha), donde no hay barra que lo deje |
| `screenBottom` | 32 | Aire antes del dock |
| `hair` | 1 | Entre las letras del índice A–Z |
| `letterIndex` | 24 | Lo que la lista deja libre a su derecha para el índice A–Z (su columna de 44 menos el margen, y aire) |
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

`tapTarget 44 (`.sizeTarget()` lo da a lo que se ve chico) · labelLines 2 (renglones de una etiqueta con la letra más grande) · tapBleed 12 (lo que el toque de un ícono sobresale de su dibujo) · row 52 (fila de libreta) · tabMark 16 × 2 (el trazo del filtro elegido) · pageSwatch 78, swatchLine 3, swatchLines (las hojitas de Apariencia) · statusDot 6, statusDotLine 1 · equalizerHeight 12 · control 46 · coverHero 132 · coverDetail 168 · coverEditor 84 · coverRow 40 ·
coverMini 26 · gridColumns 3 (con la letra más grande, `gridColumnsLarge` 2 y el título en `coverCaptionLinesLarge` 3 renglones; son las de menos: en una pantalla ancha caben las que quepan sin que una portada pase de `coverCellWidest` 150, o `coverCellWidestLarge` 240) · fontColumns 2 (las letras de «Aa») · hairline 0.5 · progress 2 · quoteRule 2 · selection 2 · accentButton 44 ·
stageBar 8 · stageBarThin 4 · footerPreview 64 · footerPicker 320 (el globo del pie) · deskMark 16 × 4 (el trazo verde del encabezado de la Mesa) · ghostLine 3 · scrubberKnob 14 · scrubberHeight 32 · scrubberReach 6 · excerptReach 60 (letras de contexto al encontrar algo en una nota) · dragSlop 6 · stageRow 26 · stageMark 16 · stageGap 1 · legendSwatch 8 · playRing 38 · equalizerBar 2 ·
textEditor 120 · ribbon 12×64 · appearanceSheet 584 (solo mientras se mide; luego la hoja mide su contenido) · turnPreview 18×24 · macReader 720×820 (solo la ventana del libro, nunca una hoja) · readingMeasure 640 (lo más ancho que corre un renglón del libro en la Mac, unas 66 letras, centrado; MX-B) · readingPanel (esa columna con el aire de adentro de una tarjeta de vidrio: lo más ancha que es la tarjeta del lector) · screenMeasure (esa columna con el margen de pantalla a cada lado: lo más ancha que es una pantalla de texto en el iPhone, centrada; solo la alcanza el Duo abierto o un iPhone acostado) · weekChart 112 · yearChart 80 · weekBar 18 · dayCell 34 · shareCard 300×375 ·
coverAspect 2∶3 (toda portada) · indentLevels 3 (sangrías del índice)`

`Theme.CoverArt.fitTolerance` (0,08) cuánto puede apartarse una imagen de 2∶3 y todavía llenar el marco; `fitBlur` (0,12 del ancho) el desenfoque detrás de una portada que cabe entera (UX-2e).

`Theme.Emphasis`: `secondary` (0,75) texto secundario sobre la marca (tarjeta para compartir); `glassText` (0,8) texto callado sobre el vidrio del lector (subió de 0,72: en Noche cálida quedaba justo en el mínimo de contraste); `scrubberTrack` (0,25) riel de la barra de avance;
`pressed` (0,85) y `pressedScale` (0,97) al tocar, `rest` (1) en reposo; `labelMinScale` (0,8) lo más que se achica una etiqueta corta; `ghost` (0,12) renglones y filo de la muestra del pie; `inGlass` (0,1) el círculo de un botón dentro del vidrio (`roundInGlass`: buscar y «Aa» en la tarjeta del lector); `actionEdge` (0,16) el filo de la acción principal; `folioMuted` (0,55) su pie sin dato; `knobGrow` (1,4) la perilla de la barra al arrastrar. Con controles, en páginas no hay franja detrás de los botones de arriba (arriba hay papel liso y el vidrio basta); en continuo, donde el texto corre por debajo, va la misma franja de papel que se desvanece del capítulo (decisión D3-B, 24 nov 2026).

`Theme.shade` (negro) es la única sombra: oscurece portadas, la vuelta de la hoja y el lomo; nunca `.black` suelto.

`Theme.Lists`: cuántos se enseñan antes de «Ver todos»: `desk` 6, `preview` 5, `detailSessions` 5, `longestSessions` 2,
`linkShelf` 20, `linkSuggestions` 4, `coverSources` 3, `coverOptions` 12 y `summaryLetters` 140 (letras de una sinopsis corta) e `inspectorItems` 3 (subrayados y notas de un libro en la ficha de la Mac).

### Portada tipográfica (`Theme.CoverArt`)

La portada que se dibuja para un libro sin imagen se escala con su ancho: cada medida
es una fracción de ese ancho (`inset` 0,09 · `title` 0,14 · `author` 0,07 · `spine` 0,05 ·
`ribbon` 0,065 …), así se ve igual en una fila de 40 pt y en la ficha de 168 pt. Si la palabra más larga del título no cabe, su letra baja por `titleScales` (1 · 0,9 · 0,8 · 0,7) antes que partirse. Sus
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
| `Letter.fixedShapeLargest` | Hasta `.xxxLarge` | Tope de la letra dentro de una forma de 44: `roundInGlass`, `glassCircle`, `IconButton`, `AccentIconButton` |
| `Letter.drawingLargest` | `.large` | Los dibujos de Ajustes (`SettingsArt`) no crecen: lo que dicen está en sus filas y en VoiceOver |
| `Letter.readerChromeLargest` | `.accessibility1` | Tope de lo que flota sobre el libro (tarjeta de abajo, barra de lo elegido, tarjeta del subrayado) y de lo fijo al pie de una lista (`BottomBar`): con AX5 tapaba casi media página |
| `.bookTitle` | New York 28 medium | Libro protagonista (Mesa, ficha), títulos de estado vacío |
| `.rowTitle` | New York 17 | Títulos en filas, citas |
| `.quote` | New York 17 itálica | «Donde lo dejaste» |
| `.prose` | New York 16 | Sinopsis |
| `.code` | SF Mono 16 | Bloques de código de una nota (`NoteBody`), con sus renglones |
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
| `.formScreen()` | Receta de formulario: el papel de la app de fondo, no el gris del sistema; botones en tinta (regla 1) y los interruptores prendidos en verde (`AccentSwitchStyle`) | Conexiones, Reglas, Editar datos, Buscar con otros datos |
| `.pushedScreen(título)` | Receta de pantalla empujada u hoja: papel, título en línea, controles del contenido en tinta (interruptores en verde, `AccentSwitchStyle`); los botones de la barra de vidrio, en tinta como en iOS 26. `bar: false`: una hoja sin barra que se cierra con la ✕ de su encabezado (Ajustes, UX-6b) | Ficha, serie, nota, Diario, Por revisar, Lector › herramientas, Sesión, Llevar a una nota, Traer de Calibre, Bienvenida |
| `.inlineTitle(título)` | Título pequeño en la barra (lo usan `.pushedScreen` y los formularios empujados) | Conexión |
| `.sheetTitle(título)` | Título de una hoja con dos botones de texto en la barra: va debajo de ellos, en grande, porque en medio no cabe (UX-3a). En `.pushedScreen` es `sheet: true` | Editar datos, Buscar con otros datos, Portada |
| `.question(título)` | Toda pregunta antes de hacer algo: un aviso al centro con la acción y su botón para quedarse a la vista (regla 7). `confirmationDialog` no: en iOS 26 sale como globo y esconde ese botón (auditoría 8) | Borrar una nota o un estante, desconectar, ordenar, mover el Gabinete, lotes de Por revisar |
| `.screenContent()` | Margen `gutter`, aire `screenTop`/`screenBottom` (en una ventana baja, `Space.s` arriba), tinta; el texto en el renglón cómodo (`ReadingColumn`; `wide: true` en Mesa, Biblioteca y cada página de un `Spread`, donde mandan las portadas o la página ya mide lo suyo) | Todo contenido con scroll |
| `WindowLayout` · `.measuresWindow()` | La forma de la ventana (del paquete, con su prueba): el pliegue (si los dos lados miden `Window.foldMinSide` o más, a la mitad del lado largo), si es baja (`Window.shortHeight`) y si el sistema ocupa una franja a un costado. La miden la raíz de las pestañas, el libro y la bienvenida; ninguna pantalla pregunta qué aparato es | Duo cerrado y abierto, iPhone acostado |
| `Spread` | El pliego: lo principal y su acompañante, una bajo otra en un iPhone de pie (como siempre), lado a lado en una ventana baja (`Window.sideBySideShare`) y cada una en su página con el Duo abierto y acostado, nunca sobre el lomo | Mesa, ficha |
| `ReadingColumn` · `.readingColumn()` | El renglón cómodo: unas 68 letras del texto normal (`Size.readingLine`), que crecen con el tamaño de texto de iOS, centrado; si cruzaría el pliegue, se queda en la página izquierda. En la Mac no cambia nada | `.screenContent()`, `.formScreen()`, nota |
| `.sidePanel(isPresented:)` · `.sidePanel(item:)` · `SheetDismiss` · `PanelClose` | Una hoja que, con el Duo abierto y acostado, se abre en una página (la otra a la vista, atenuada; tocarla cierra) y nunca sobre el pliegue; en lo demás, la hoja de siempre. Abierto desde una pantalla empujada (la ficha en lista | detalle), sube a la raíz (`PanelHost`): encima de la ficha iOS regresaba a la lista. Lo de adentro se cierra con `SheetDismiss`, no con `dismiss` | «Aa», herramientas, Resumen, Editar datos, Portada, Ajustes |
| `FoldSplit` · `FoldPlaceholder` | La raíz de una pestaña: en un iPhone, la pila de siempre; con el Duo abierto y acostado, la lista en la página izquierda y lo que tocas en la derecha (`NavigationSplitView` con la lista justo hasta el pliegue, que sin pliegue se pliega solo a una pila) | Biblioteca, Cuaderno, Buscar |
| `LargeSheetTitle` | El título grande de una hoja: con una franja del sistema al costado (Duo cerrado) va bajo la barra, no a su lado, porque iOS lo escondía | Editar datos, Elegir portada |
| `DotLine` | Partes unidas con « · » en un renglón; si no caben, una bajo otra y sin el punto (nunca un «Fundación ·» colgando) | Serie de la ficha |
| `GuideBand` | El renglón de la lectura guiada con su página: con dos páginas, la penumbra cubre también la otra | Lector |
| `.duoBars()` | Dónde van las barras en el iPhone Duo (DUO-1): cada pestaña (en la `TabView` misma iOS no lo lee), el lector, la bienvenida y cada hoja lo declaran; mientras no se decida, no cambia nada. Ojo: iOS 27.2 no lo respeta siempre (al abrir el libro regresa la franja y se queda) | Toda presentación del iPhone |
| `ScreenHeading` | Título serif + acciones a la derecha y una línea finísima debajo (SD-3); sus acciones son `IconButton` o `AccentIconButton` (en una hoja, su `CloseButton`), y con la letra más grande bajan bajo el título (SD-4) | Biblioteca, Cuaderno, Buscar, Ajustes |
| `AdaptiveStack` | Lo que va lado a lado y, con la letra de accesibilidad de iOS (AX1–AX5), uno bajo otro; con el tamaño de siempre y en la Mac es el `HStack` de antes (SD-4) | Encabezados, conteo y orden, nombre y campo, opciones en fila, tarjeta y barras del lector |
| `IconButton` | Ícono de acción en tinta que se toca en 44 aunque se dibuje chico (`.sizeTarget()`) | Engrane del Cuaderno, lista o portadas de la Biblioteca |
| `PrimaryButton` | Acción principal en `action`, oscura en los dos modos, con filo finísimo (una por pantalla) | «Seguir leyendo», «Leer», estado vacío |
| `TextAction` | Acción de texto en tinta, que se toca en 44 (las acciones no van en verde) | «Darlos por buenos», «Ver los N subrayados», «Borrar recientes», «Crear nota» |
| `BottomBar` | Lo que se queda fijo abajo de una lista mientras eliges, sobre el papel con su línea finísima arriba (`safeAreaInset`): al final de una lista larga no se veía. Su letra tiene tope (`Letter.readerChromeLargest`): con AX5 llenaba media lista | «Mantener los datos de N libros» en Por revisar › Elegir varios |
| `BarButton` | Botón de texto de la barra («Dejar como está», «Guardar cambios», «Volver al libro»), en tinta: iOS los pintaba de verde | Toda barra con texto |
| `SheetActions` · `.sheetActions(leave:confirm:)` · `SheetAction` | Las dos salidas de texto de una hoja: con la letra de siempre en la barra; con la de accesibilidad la de salir se queda arriba y la otra baja entera a `BottomBar` (`PrimaryButton`, o `QuietButton` con `quiet` si es saltar), porque iOS la guardaba en su «•••» (auditoría 3). Ninguna hoja pone dos botones de texto en su barra a mano | Editar datos, Buscar con otros datos, Portada, Bienvenida |
| `ButtonPair` | Botones de texto lado a lado del mismo ancho y en un renglón; si alguno no cabe entero en su parte, uno bajo otro (nunca uno partido en dos junto a otro de un renglón, auditoría 3) | Sesión terminada |
| `BarMenu` | El menú de la barra de una pantalla («Editar»), en tinta: iOS lo pintaba de verde | Ficha, nota, estante |
| `AccentSwitchStyle` | El interruptor prendido en verde (lo tuyo) dentro de una pantalla en tinta; lo ponen las recetas | `.formScreen()`, `.pushedScreen()` |
| `UndoNotice` | Lo que acabo de hacer en lote, en una línea, con «Deshacer» a la derecha (abajo con la letra más grande) y una línea finísima debajo (UX-5) | Por revisar |
| `CapsText` | Versalitas de interfaz: mayúsculas chicas, espaciadas (`Tracking.caps`) y con cifras exactas. Toda versalita sale de aquí | Fecha de la Mesa, conteos, rótulos |
| `SectionHeader` | Rótulo de sección: `CapsText` y una línea finísima hasta la orilla; a la derecha, opcional, una acción de texto o un ✕ (`CloseButton`), que nunca se parte en renglones: si no cabe, baja a su propio renglón (`testFitsLargeTextAndFingers`). El único rótulo de sección de la app (regla 3) | «Donde lo dejaste», secciones de la ficha y de Por revisar, vacíos, Sesión |
| `CountLine` | El conteo de una lista en versalitas y, a la derecha, cómo se ordena; con la letra más grande deja su aire bajo los filtros. Todo conteo de una lista sale de aquí | Biblioteca, Cuaderno, serie, estante |
| `SortMenu` | Menú para elegir el orden, en versalitas de tinta con su flecha | Biblioteca, Cuaderno › Subrayados |
| `ToggleRow` | Interruptor en una fila de libreta (`Size.row`), en verde | Ajustes › Lectura |
| `FieldRow` | Campo de texto en una fila: nombre a la izquierda, lo escrito a la derecha | Ajustes › Clave de Google Books |
| `LabeledField` | Campo de un formulario con su nombre arriba aunque ya tenga valor, y la pista adentro (UX-3a); en la Mac, con su borde (sin él se leía como texto fijo) | Editar datos (iPhone), Reglas |
| `.oneLine()` | Un renglón que termina en «…» si no cabe (regla 9): todo campo de la ficha de la Mac | Ficha de la Mac, juntar en la Mac |
| `.spaced(_:_:)` | Letras espaciadas solo si la escritura lo aguanta (`String.isSpaceable`): el árabe y el hebreo van juntos (UX-1c). Todo espaciado sale de aquí | `CapsText`, `SectionLabel`, `BrandMark`, portada tipográfica |
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
| `FilterBar` | Opciones en texto; la elegida en tinta con un trazo verde debajo (`Size.tabMark`) que se desliza; sin píldoras (SD-3). Lo que no cabe baja entero al renglón de abajo, nunca se corta en la orilla (UX-2b) | Filtros de Biblioteca, partes del Cuaderno, Diario |
| `ShelfCover` / `CoverView` | Portada real o tipográfica, con lomo; una imagen que no es 2∶3 (más de `CoverArt.fitTolerance`) va en `FittedCover` | Toda portada |
| `FittedCover` | Una imagen de portada entera en el marco 2∶3, sin estirarse ni recortarse, sobre sí misma desenfocada (`CoverArt.fitBlur`); toda portada que llega de fuera pasa por aquí (UX-2e) | Portadas cuadradas o apaisadas, candidatos de internet, elegir portada, Editar datos |
| `DuplicateMark` | «Posible duplicado» con su ícono (`Duplicates`, los mismos de la Mac) bajo un libro que parece estar dos veces (UX-2d) | Biblioteca (portadas y lista) |
| `SeriesStack` | Pila de portadas de una serie | Biblioteca |
| `CoverCell` + `CoverGrid` | Celda y cuadrícula de 3 columnas (2 con la letra más grande), y más si sobra: las que quepan sin que una portada pase de `Size.coverCellWidest` ni de `Window.coverHeightShare` del alto de la ventana (`CoverColumns`, redondea hacia arriba): en una ventana baja se ve un libro entero | Biblioteca, Mesa, Elegir portada |
| `BookRow` | Portada pequeña + título serif + detalle + extra | Lista, serie, Buscar, Cuaderno |
| `WholeWordsText` | Un título que nunca se parte a media palabra: si su palabra más ancha no cabe a lo ancho, la letra baja un paso (el tamaño de iOS, o `CoverArt.titleScales` en la portada dibujada) hasta que cabe entera, como mucho `maxSteps` pasos y nunca por debajo de `.large` desde una letra de accesibilidad; en ese piso, un renglón que termina en «…». Mide las palabras con sus marcas (la negrita de lo buscado) (auditorías 8 y 9) | Todo título de libro o de nota: portadas, filas, la ficha, la Mesa, las notas |
| `QuoteBlock` | Cita con raya de lápiz, etiqueta y nota; `hanging`: sin raya, rótulo en versalitas con línea fina y la comilla de apertura colgada en verde (ME-2) | «Donde lo dejaste» (hanging), subrayados |
| `TurnPreview` | Hoja chiquita (`Size.turnPreview`) que pasa con su estilo en bucle y la misma curva que la real (`TurnMotion`); las dos hojas se turnan, sin salto más despacio que la real (`Reader.previewPace`); la Hoja es una esquina que se dobla (`Reader.previewPause`, `previewLead`, `previewTurn`, `previewShadow`, `previewLines`) | Estilos de la hoja en «Aa» |
| `SegmentedChoice` | Opciones lado a lado; la elegida en papel sobre el carril (`Radius.segment`), la marca se desliza | Páginas o Continuo en «Aa» |
| `SessionLine` | La sesión en una línea verde que abre su tarjeta | Panel del lector |
| `ScrubberBar` | Barra de avance del lector: riel fino, lo leído en tinta, perilla chica que crece al arrastrar; se toca en 44 pt de alto | Panel del lector |
| `GuideShade` | Lectura guiada, el renglón (LG-B): el papel del libro al `Reader.guideShade` (72 %) sobre todo menos el renglón que lees (solo su texto: las orillas de `Reader.textMargin` siguen en penumbra para que no asome la sombra de la página); la guía viaja con `Motion.select` | Lector |
| `LookupCard` | «Consultar» (SG-4): al elegir texto, la palabra en serif, su traducción al español con el traductor de Apple (sola si los idiomas ya están descargados; si no, botón «Traducir»), el primer párrafo de Wikipedia en el idioma del libro (`Reader.lookupLines` 5) y el diccionario del sistema; vidrio como la tarjeta del subrayado | Lector, barra de selección |
| `SlitText` | La hendidura: el pedazo que se lee en `.bookTitle`; palabra por palabra (HE-A) con su letra de enfoque en `highlight`, fija al centro; por frase (HE-B), centrado. El título del capítulo pasa solo, con su respiro, antes de la primera frase (UX-8b) | Hendidura |
| `ChapterLine` | En continuo, bajo el pie: rayita corta (`Reader.chapterLine` 64) con la tinta del libro que se llena con lo leído del capítulo; quieta (SC-C) | Pie del lector |
| `FooterPreview` | Muestra del pie: recorte chico de la parte de abajo de la página (papel, dos renglones fantasma y el pie tal cual, con su letra), sin nombre debajo (lo lee VoiceOver); filo de tinta y palomita si está elegido | Tarjeta del lector |
| `IconTile` | Mosaico chico: ícono arriba, nombre abajo; borde si está elegido; en tinta si es la acción principal | Estilo de la hoja, tarjeta de un subrayado, barra de selección |
| `FactRow` | Etiqueta / valor con línea fina y cifras exactas | Ficha del libro |
| `EmptyState` | `SectionHeader` con lo que falta, explicación y acción opcional con su ícono; los textos que se repiten salen de `EmptyCopy`. El vacío de un filtro dice que nada coincide (no que no hay libros) y ofrece «Ver todos los libros» (`testScreensUseCatalogPieces`) | Toda lista vacía |
| `LibraryEmptyState`, `LibraryEmptyKind` | El vacío de una biblioteca sin libros, que sigue a iCloud (auditoría 4): «Bajando tu biblioteca» sin botón mientras bajo la tuya; «Tu biblioteca no ha bajado» con «Añadir libros» y «Volver a la bienvenida» si dejé de esperar; «Todavía no hay libros» con «Añadir libros» si de verdad está vacía. En la Mac, `MacEmptyState(library:)` con la misma regla | Mesa, Biblioteca y la tabla de la Mac |
| `MacEmptyState`, `.macMainAction()`, `.macToolbarInk()` | En la Mac: el vacío con las mismas palabras (`EmptyCopy`) y el botón principal en `action`; el vacío de una sección lleva «Ver todos los libros»; los controles de la barra de la ventana van en tinta (`.macToolbarInk`), en verde solo con un filtro puesto | Tabla, ficha y duplicados de la Mac |
| `MacCell` | Una celda de la tabla de la Mac (MX-B): un renglón que se corta con «…», el título del libro en New York y lo demás en la letra de la interfaz, en tinta o secundario; en la letra de la selección (`Theme.onSelection`) cuando la fila está elegida | Tabla de la Mac |
| `.macPaper()`, `.macSidebarPaper()`, `.macWindowPaper()` | La Mac de papel (MX-B): la tabla y las listas sobre `paper` sin franjas, la barra lateral sobre `sunken` y la barra de la ventana en `paper`; los controles siguen siendo los de macOS | Ventana de la biblioteca, duplicados, Ajustes |
| `LoadingLine` | Mientras algo tarda: la ruedita chica y qué estoy haciendo, en tinta secundaria («Buscando en internet…») | Ficha, Por revisar, Ajustes, Bienvenida, Conexiones, Calibre, Lector |
| `CloseButton` | El ✕ que cierra, en 44 y con su nombre para VoiceOver («Cerrar la tarjeta»); `.plain` o `.glass` | Consultar, tarjeta del subrayado, lectura guiada, Sesión, Hendidura |
| `TitleDetailRow` | Título en tinta y su detalle en gris debajo, en una fila de libreta | Calibre, Readwise, Por revisar, Apariencia |
| `ChoiceMark` | La palomita verde de lo elegido (o el círculo vacío) | Duplicados de la Mac, opciones |
| `LanguagePicker`, `StatusPicker` | Elegir idioma (con su nombre: «Español») y estado de lectura (`ReadingState`) iguales en el iPhone y la Mac | Editar datos, ficha de la Mac |
| `SaveShelfAlert`, `RenameShelfAlert`, `DeleteShelfConfirmation` | Guardar, renombrar y borrar una estantería: las mismas palabras en el iPhone y la Mac. El campo del nombre empieza vacío con el nombre propuesto (o el de ahora) de pista; vacío, se queda ese (UX-7) | Biblioteca, estantería, barra lateral de la Mac |
| `.errorAlert`, `.noticeAlert` | Aviso de un solo botón: el título dice qué pasó en primera persona («No pude abrir el libro»), el botón a dónde vuelves («Volver a la ficha») | Todo aviso de error o de algo que terminó |
| `LinkRow` | Fila de libreta (`Size.row`): título, valor, flecha y línea finísima debajo; con `marked` o `status`, su punto | «Por revisar», Ajustes |
| `ReasonLine` | Por qué algo está apagado, en gris y entero: baja a los renglones que haga falta, también dentro de un formulario de la Mac (auditoría 7) | Ajustes, Reglas, la bienvenida, Traer de Calibre, la tabla y la ficha de la Mac |
| `StatTrio` | Tres cifras grandes con su rótulo en versalitas, centradas | Diario |
| `ThinProgress`, `Hairline`, `LetterIndex` | Progreso, separador, índice A–Z (en tinta; la columna entera se toca y se recorre con el dedo en 44 de ancho, como en Contactos; su letra tiene tope y, si no caben las 27, enseña una de cada dos o tres, pero VoiceOver lo ajusta letra por letra por las 27; empieza debajo del conteo, la lista le deja `Space.letterIndex` y con la letra más grande no sale, `LetterIndex.shows`) | — |
| `LetterJumpMenu` | «Ir a la letra…» junto al orden: con la letra más grande el índice A–Z no cabe y este menú salta a cualquier letra con libros | Biblioteca › lista por título |
| `MiniPlayer` | Reproductor sobre el dock; escondido hasta que haya audio (`Features.audiobook`, UX-8a) | Raíz (apagado) |
| `BrandMark` | «GABINETE» en Cinzel, centrado (o a la izquierda) | Bienvenida, dentro de `DeskHeader` |
| `DeskHeader` | Encabezado de la Mesa: «GABINETE» a la izquierda, la fecha de hoy en versalitas a la derecha y una línea finísima que acaba en un trazo verde (`Size.deskMark`); MT-F, 25 nov 2026 | Arriba de la Mesa |
| `SectionLabel` | Mayúsculas romanas pequeñas (Cinzel, `Font.sectionLabel`), solo para el número y el capítulo; las secciones van con `SectionHeader` | «Nº 7» en la ficha, el capítulo sobre la tarjeta del lector |
| `AccentIconButton` | Ícono de acción en `accent` (verde botella, se distingue de la tinta), sin fondo: el único acento verde de una pantalla | «+» de la Biblioteca y del Cuaderno |
| `SecondaryButton`, `LinkRow` | Acción secundaria a lo ancho; fila que lleva a otra pantalla | «Por revisar» |
| `QuietButton` | Salida discreta, solo texto, bajo opciones que importan más | «Empezar sin libros» en la bienvenida |
| `CandidateRow`, `CandidateCover` | Libro encontrado en internet: probabilidad y razones en palabras | Elegir los datos |
| `CompareRow` | Dato nuevo frente al tuyo («Antes: …»), con «Deshacer» opcional | Vista previa, lo completado |
| `NoteRow` | Nota: título serif, dos líneas sin su marcado (también el pasaje encontrado al buscar), fecha y libros enlazados en `accent` | Cuaderno › Notas, ficha › Notas, «Llevar a una nota» |
| `NoteBody` | Nota leída: título, párrafos `.prose`, citas con raya `accent`; `[[Libro]]` y «ir al pasaje» como enlaces | Nota |
| `PressableStyle`, `TrailingIconLabelStyle` | Respuesta al toque; etiqueta con el ícono después («Recientes ⇅») | Todo botón del sistema; órdenes |
| `ReaderPillButton` | Botón en cápsula del panel del lector; el destacado en tinta | «Escuchar» (apagado hasta el audiolibro; la lectura guiada va junto a «Aa») |
| `PlayRingButton`, `EqualizerBars` | Reproducir con el avance en anillo; barras de audio sonando | Mini reproductor (apagado) |
| `StatTrio` | Tres números en serif con su leyenda, que baja a un segundo renglón si no cabe («LIBROS TERMINADOS», UX-4c) | Sesión actual, resumen, ficha › Lectura, Diario |
| `StageBar`, `StageLegend` | La sesión como barra de etapas; leyenda con minutos | Resumen al cerrar, ficha, Diario |
| `StageChart` | Etapas en el tiempo, una fila por etapa (Swift Charts) | Sesión actual, una sesión pasada |
| `WordCounter` | Contador de palabras de la sesión, en verde | Lector, abajo a la izquierda |
| `FlowRow` | Fila que baja a otra línea si no cabe | Leyendas |
| `WeekBars` | Una barra por día (lunes a domingo), partida en etapas; hoy en tinta | Mesa › Esta semana, Diario › Semana |
| `MonthCalendar` | El mes como calendario, con el renglón L M M J V S D arriba (del lunes al domingo, UX-4b): más oscuro cuanto más leíste; hoy con anillo. Huecos y días salen de `MonthGrid` (LectoraCore), cada celda con su identidad: el día 1 no desaparece aunque el mes empiece en domingo | Diario › Mes |
| `YearBars` | Una barra por mes; el actual en verde | Diario › Año |
| `SessionRow` | Una sesión en una lista: cuándo, palabras, avance y duración | Diario, ficha › Lectura |
| `OptionRow` | Opción para elegir: ícono, título, explicación; la elegida con borde y marca verdes | Bienvenida |
| `ContentsRow` | Entrada del índice del libro, con sangría por nivel y punto verde donde vas | Lector › Índice |
| `SearchResultRow` | Resultado de buscar en el libro: texto alrededor, lo buscado en verde y negritas, su página a la derecha | Lector › Buscar |
| `SearchChapterHeading` | Capítulo en los resultados de buscar, con cuántas veces aparece | Lector › Buscar |
| `HereMark` | Raya verde «Aquí vas · pág. N» entre resultados | Lector › Buscar |
| `RecentSearchRow` | Búsqueda reciente: tocarla la repite; a la derecha cuántos resultados tuvo | Lector › Buscar |
| `SearchStepper` | Barrita de vidrio «‹ 4 de 23 · «palabra» ›» sobre la página, con ✕ | Lector |
| `SearchField` | Campo de búsqueda sobre `field`, con lupa y borrar; nunca `.searchable` (en Buscar quedaba escondido); con la letra más grande, su pista corta («Buscar») | Buscar, Lector › Buscar |
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
    .pushedScreen(bar: false)                                      // sin barra: la ✕ va en el encabezado
}
```
La ✕ para cerrar va en el encabezado, junto al título (`ScreenHeading { CloseButton(label: "Cerrar Ajustes", style: .glass) }`),
y se va con él al deslizar: en la barra, la cápsula «Cerrar Ajustes» flotaba sobre las tarjetas
y apretaba el título (UX-6b, 27 nov 2026).

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

## La Mac (MG-1 y MX-B, 26 nov 2026)

En la Mac, Gabinete es una app de Mac: la mesa de trabajo de tu biblioteca. Vive en
`App/Shared/Mac/` y usa los controles de macOS (tabla, ficha a la derecha, búsqueda en la barra,
menús), porque es lo que se espera ahí. Desde MX-B (26 nov 2026) es **toda de papel, como el
iPhone**: los mismos controles, vestidos con el papel, la tinta y las letras de Gabinete, en claro y
en oscuro:

- **Papel:** la tabla, las listas y la ficha sobre `paper`, sin las franjas ni el blanco del sistema
  (`.macPaper()`); la barra lateral sobre el papel hondo (`sunken`, `.macSidebarPaper()`); la barra
  de la ventana y la de Ajustes en `paper` (`.macWindowPaper()`). El aviso de «Buscando datos» abajo,
  también en papel con su `Hairline`.
- **Letras:** el título del libro en New York (`rowTitle`) en la tabla, la ficha y los duplicados; lo
  demás en la letra de la interfaz, en tinta o `secondaryInk` (`MacCell`). Lo largo se corta con «…»
  en un renglón (la ficha: el título en dos, regla 9); al pasar el puntero se lee completo.
- **El nombre una vez (regla 8):** el nombre de la sección va solo en la barra de la ventana. La
  Mesa, el Cuaderno y Buscar son las pantallas del iPhone sin su encabezado grande (`ScreenHeading` y
  `DeskHeader` no lo dibujan en la Mac; sus acciones, como «Nota nueva», suben a la barra). Sin
  engrane: Ajustes es Gabinete › Ajustes… (⌘,).
- **Ajustes en pestañas:** Apariencia, Lectura, Gabinete, Datos y Conexiones, cada una con su
  tarjeta de siempre (`SettingsCard`, sin su rótulo: la pestaña ya lo dice) sobre el papel hondo. La
  ventana mide `Theme.Mac.settings` de ancho y toma el alto de cada pestaña; Reglas y las conexiones
  abren en una hoja de `Theme.Mac.settingsPage` de alto, con «Volver a Ajustes» (empujadas dentro de
  la pestaña, su flecha se metía entre las pestañas y marcaba otra). Sin «Listo»: se cierra con ⌘W.
- **Hojas que caben:** ninguna hoja pasa de `Mac.sheetMax` (560) de alto, que cabe bajo la barra de
  la ventana más chica (`Mac.window`, 620). La bienvenida mide `Mac.welcome` de ancho y el alto de su
  paso, con «Volver al paso anterior» e «Ir a la biblioteca» al pie (`QuietButton`); antes medía
  820 en una ventana de 672 y su barra de abajo quedaba fuera, sin cómo saltarla (auditoría 2).
- **Leer cómodo:** en una ventana ancha el libro va en una columna centrada de
  `Size.readingMeasure` (640 pt, unas 66 letras); el renglón ya no se estira de orilla a orilla
  (`Mac.readingColumns`, una). La tarjeta de abajo, la barra de lo elegido y la del subrayado miden
  lo que esa columna (`Size.readingPanel`), centradas: antes cruzaban toda la ventana.

| Parte | Qué es | Archivo |

| Parte | Qué es | Archivo |
|---|---|---|
| Barra lateral | Leer (Mesa, Cuaderno), la biblioteca por estado (todos, leyendo, por leer, leídos, por revisar, sin portada) con su cuenta, y Explorar por autor, serie, etiqueta o idioma | `MacLibraryWindow` |
| Por revisar | La misma pantalla del iPhone (UX-5, 27 nov 2026): cada libro abre «Elige los datos»; «Completar los N muy probables» y «Elegir varios» › «Mantener los datos de N libros» resuelven en lote, con confirmación y «Deshacer». Antes solo se veía la lista en la tabla, sin manera de resolverla | `ReviewScreen` |
| Tabla | `Table` nativa: ordenar por columna, elegir columnas (clic derecho en el encabezado; idioma, valoración, editorial, publicado e ISBN empiezan escondidas), selección múltiple, doble clic abre el libro, arrastrar archivos importa | `MacBookTable`, `MacBookRow` |
| Búsqueda | En la barra de la ventana, «Buscar en la biblioteca», con filtros como Calibre: `autor:` `serie:` `etiqueta:` `idioma:` `editorial:` `estado:` `isbn:` `título:` (`LibraryQuery`, con sus pruebas). Los filtros tienen su menú con nombre junto a la búsqueda («Por autor», «Por serie»…), que los escribe; la pista ya no los enseña crudos | `MacBookTable` |
| Ficha | `inspector` a la derecha: con un libro, su portada con «Seguir leyendo» (o «Empezar a leer», el mismo botón que el doble clic) y «Portada» (una imagen de tu Mac o una de internet, como en el iPhone), sus primeros subrayados y notas (`Lists.inspectorItems`; un clic abre el subrayado en su página o la nota en su hoja) y todos sus datos; con varios, lo que escribas se aplica a todos y lo que dejes en blanco no cambia (`BulkEdit`, con sus pruebas) | `MacBookInspector` |
| Libro abierto | Cada libro en su propia ventana, con su nombre en la barra: lees con la biblioteca al lado y puedes tener varios abiertos. ⌘W lo cierra | `MacReaderWindow` |
| Menús | Archivo › Añadir libros… (⌘O) y Gabinete › Ajustes… (⌘,), como en toda app de Mac | `LectoraApp` |
| Ordenar autores, series y etiquetas | Clic derecho en la barra lateral › «Renombrar o juntar…»: la hoja dice «Renombrar o juntar «Nombre»», el campo empieza vacío con el nombre de ahora de pista y la hoja mide lo que su contenido (`Mac.catalogSheet` es solo su ancho); escribir un nombre que ya existe es juntar, y los parecidos («Cortázar, Julio», «J. Cortázar») vienen marcados. En series, «Renumerar tomos 1, 2, 3…». ⌘Z deshace. Con autores y etiquetas queda la regla para lo que importes después (CB-2) | `MacCatalogSheet`, `CatalogRename` |
| Estantes | Búsquedas guardadas que se llenan solas (CB-1). En la Mac, «Guardar como estante» en la barra de la tabla y la sección Estantes en la barra lateral (clic derecho: renombrar o borrar). En el iPhone, «Guardar estos libros como estante» en Buscar, y cada estante como renglón en la Biblioteca. Viven en la carpeta (`.lectora/estantes.json`) | `SavedShelf`, `SavedShelfScreen` |
| Buscar datos en lote | Clic derecho en «Todos los libros» › «Buscar datos de N libros incompletos» (los que no tienen portada, sinopsis, ISBN, editorial o año), o en cualquier vista para todos sus libros; también el botón de la barra con varios elegidos. Uno tras otro con pausa (`BatchLookup.pause`); lo seguro se completa, lo dudoso va a Por revisar. Abajo, «Buscando datos · 7 de 14» con «Detener búsqueda» y al final el resumen (CB-4) | `MacBatchBar`, `BatchLookup` |
| Posibles duplicados | En la Mac, «Posibles duplicados» en la barra lateral (solo si hay): mismo título con autor parecido, o el mismo ISBN. Cada grupo con sus libros (autor, formatos, subrayados, avance, fecha); se queda por omisión el que tiene subrayados o avance, luego el EPUB. «Juntar en uno…» pide confirmación y dice qué pasa: el que se queda gana los formatos que no tenía en su misma carpeta, sus datos se completan, subrayados y marcadores pasan a él, y lo repetido va a la Papelera. «No son el mismo» no lo vuelve a proponer (`.lectora/no-duplicados.json`). La tabla muestra todos los formatos («EPUB · PDF») (CB-3) | `MacDuplicatesView`, `DuplicateFinder` |
| Buscar en todo | En la barra lateral (Leer): la misma pantalla Buscar del iPhone, con libros, subrayados y notas (SG-3). La búsqueda de la barra de la tabla sigue siendo solo de libros | `MacLibraryWindow`, `SearchScreen` |

Aquí no aplican las recetas del iPhone (`FilterBar`, `SearchField`, `PrimaryButton`): en la Mac
mandan la búsqueda de la barra, el botón del sistema (con el acento) y los formularios agrupados.
Sí aplican los tokens, los colores y las letras: las medidas de la ventana están en `Theme.Mac` y
`scripts/lint-design.sh` revisa también estos archivos. Mesa, Cuaderno y Buscar son las mismas
pantallas del iPhone, sin su encabezado. Lo elegido en la tabla y la barra lateral va en el verde de
Gabinete, con su letra (`Theme.onSelection`): el color `AccentColor` del catálogo
(`ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME`) tiene exactamente los valores de `Theme.Green`, y
`testOneGreenForEverything` falla si cambia o si aparece otro verde en el catálogo (27 nov 2026; antes
salía el azul del sistema). Si en Ajustes del Sistema eliges un color de acento propio, manda el tuyo.
Todo formulario de la Mac va agrupado, como la ficha (`.formScreen()`).

## iPhone Duo (27 nov 2026)

El Duo es el iPhone que se dobla. Cerrado, su pantalla de afuera mide 466 × 678 de pie (678 × 466 acostada) y
iOS pone las pestañas y la hora en una franja al costado. Abierto, la de adentro mide 669 × 951 de pie o
951 × 669 acostada, con el pliegue a la mitad (de lado a lado de pie, de arriba abajo acostada). Gabinete no
pregunta qué aparato es: cada pantalla lee la forma de la ventana (`WindowLayout`, en el paquete y con sus
pruebas) y usa las mismas piezas, así un iPhone de pie no cambia y un iPhone acostado gana lo mismo que el Duo.

- **La forma de la ventana** (`WindowLayout`, la mide `.measuresWindow()` en la raíz): hay **pliegue** si los dos
  lados miden `Window.foldMinSide` (600) o más (ningún iPhone de una pantalla llega); es **baja** con menos de
  `Window.shortHeight` (500) de alto; tiene **franja** si el sistema ocupa `Window.stripMin` más de un lado que
  del otro. iOS no dice dónde está el pliegue (`UIHingeInteraction` solo dice si está abierto): se deduce.
- **Las piezas:** `ReadingColumn` (el renglón cómodo, ~68 letras, nunca sobre el pliegue), `Spread` (Mesa y
  ficha: una bajo otra, lado a lado si es baja, una por página con pliegue), `FoldSplit` (Biblioteca,
  Cuaderno, Buscar: lista | detalle con pliegue), `.sidePanel` (las hojas, en una página con pliegue),
  `CoverColumns` (las portadas por ancho y por alto), el encabezado compacto (en una ventana baja, el título de
  pantalla más chico y con menos aire: `Letter.screenTitleShort`), `LargeSheetTitle`, `DotLine` y, en el
  lector, `ReaderSpread` (cuántas páginas, sus márgenes y el lomo) y el pie delgado de un renglón.
- **El libro:** acostado y abierto, dos páginas centradas en el pliegue, con lomo de verdad (`2 × Reader.textMargin`)
  aunque haya franja; cerrado de pie, los márgenes de cada lado son los suyos (con márgenes iguales la columna
  quedaba angosta). En continuo con pliegue, el texto va en la página izquierda y la derecha es su margen (el
  título y el capítulo); de pie y abierto, una columna cómoda (`Reader.lineEms`, unas 32 letras de ancho de
  página) que cruza el pliegue de lado a lado, que ahí no corta renglones. La lectura guiada sombrea por página.
  Las herramientas y «Aa» se abren en la página derecha y el libro sigue a la vista. En una ventana baja, el
  pie es una línea delgada (capítulo, barra, página y herramientas).
- **Al doblar o desdoblar** la app no se rearma: sigues en la misma pantalla y en la misma página (lo mismo
  que al girar; se revisa con `-screenshot.turn landscape -screenshot.turnAfter 8`).
- **Las otras opciones** viven en `enum Duo` (`LaunchOptions.swift`), apagadas; cada una se prueba en Debug con
  su argumento: `-duo.bars below` (pestañas abajo y hora arriba, `duoBars()`), `-duo.book page` (acostado y
  abierto, una sola página grande), `-duo.margin left` (en continuo, el texto a la derecha y el margen a la
  izquierda), `-duo.tall top` (de pie y abierto, el libro en la mitad de arriba), `-duo.panes one` (una
  pantalla a la vez también abierto), `-duo.tools sheet` (herramientas como hoja) y `-duo.footer card` (la
  tarjeta de siempre también en una ventana baja).
- **Simulador:** «Gabinete Duo» (iPhone Duo, iOS 27.2). `xcrun simctl` no dobla el aparato, pero
  `scripts/duo/duopose.m` sí: llama al servicio de pruebas de SpringBoard que mueve la bisagra
  (`xcrun simctl spawn <udid> duopose -position=open|closed -deviceOrientation=… -duration=0 -wait`) y fija
  también la orientación de verdad. La pantalla de afuera es `--display=primary` y la de adentro,
  `--display=primary-1`. `scripts/duo-estudio.sh todos comparar` toma cada pantalla en los cuatro modos y en
  un iPhone normal, con la hoja de contactos en `/tmp/gabinete-duo-estudio/ronda-N/index.html`.

## Simetría

Medida en las capturas del simulador (píxeles → puntos) y en el código:

- Margen lateral: 24 pt a ambos lados en todas las pantallas (`gutter`). Las filas que
  se desplazan (`FilterBar`) llegan al borde y alinean su primer texto con el margen.
- Título de pantalla: misma altura en Biblioteca, Cuaderno y Buscar (antes Buscar usaba
  el título del sistema, 35 pt más abajo y con 16–20 pt de margen).
- Lector: los botones de arriba suben `Reader.chromeLift` (8 pt) hacia la isla, nunca más de lo que hay de orilla segura; sin isla (el iPhone Duo cerrado, un iPhone acostado) quedan a `Reader.chromeEdge` (4 pt) de la orilla (`ReaderView.chromeTop`). Los controles de vidrio tienen el mismo margen (`Reader.chromeInset`, 16 pt)
  arriba y abajo; las zonas de toque izquierda y derecha son franjas iguales
  (`Reader.edgeZone`, 28 %). El revés de la hoja es el mismo papel con `Reader.pageBack` (93 %, papel y no cartón) de su luz. El lomo del libro es
  una sombra de `Reader.spineWidth` (26 pt) en la orilla izquierda, `Reader.spineShadeLight`
  (7 %) en papel claro y `Reader.spineShadeDark` (30 %) en oscuro; al pasar a la página
  siguiente, una vibración de `Reader.turnHaptic` (0,45), que se apaga en «Aa».
  La letra del libro sigue el tamaño de texto de iOS (`Reader.textBase`) además de lo que elijas en «Aa»; los títulos de libro, filas, citas y textos del libro también lo siguen, y las muestras del pie crecen con él. El texto va a `Reader.textMargin` (24 pt) de las orillas en páginas y en continuo y en todo iPhone, con 1,45 de aire entre renglones que el estilo del libro no cambia (D1-B y D2-B, 24 nov 2026): todos los renglones a la misma distancia, aunque el libro traiga su propio aire en sus clases, letras de otra fuente o llamadas de nota (25 nov 2026, `testLinesAreEvenlySpaced`); el contenido de la tarjeta de abajo empieza en esa misma línea. En páginas, el texto deja `Reader.pageMarginTop` (48 pt) arriba, debajo de los botones de cerrar y del marcador (antes 16: el primer renglón quedaba bajo ellos, UX-1a; lo cuida `testFitsLargeTextAndFingers`), y `Reader.pageMarginBottom` (64 pt) abajo, (abajo hasta la orilla de la pantalla);
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
| `testFormsUseThePaper` | Decisión del 19 nov 2026: todo `Form` lleva `.formScreen()`; desde el 27 nov 2026 la receta lo agrupa en la Mac y ninguna pantalla elige su estilo |
| `testNoPromisesOfFutureFeatures` | Decisión del 19 nov 2026: ningún texto dice «pronto» ni «próximamente»; lo que no funciona no se muestra. Desde UX-8a (27 nov 2026), tampoco en las capturas: lo que llega después vive tras `Features`, apagado en el código, y ningún botón visible tiene la acción vacía (el mini reproductor, «Guiada» y «Escuchar» no hacían nada) |
| `testTextColorsAreReadable` | Decisión del 19 nov 2026: sobre `paper`, tinta y secundario ≥ 4,5 : 1; terciario y verde ≥ 3 : 1, en claro y oscuro |
| `testPageTurnNeverFreezesOrJumps` | Auditoría del 24 nov 2026: al pasar la hoja, nada se queda quieto a media vuelta ni brinca al final (la vuelta usa la foto que ya dio WebKit; un cuadro tarde avanza a lo más `Reader.turnFrameCap`) |
| `testLinesAreEvenlySpaced` | Decisión del 25 nov 2026: todos los renglones de un párrafo a la misma distancia, aunque el libro traiga su propio aire, letras de otra fuente o llamadas de nota |
| `testReadingNeverVibratesByItself` | Decisión del 24 nov 2026: leyendo, nada vibra porque la página avanzó; solo lo que haces tú (con «Vibrar al pasar de página» apagado, la barra de avance vibraba en cada hoja) |
| `testNoTextUnderTwelve` | Sistema base de la casa (SB-3), 24 nov 2026: ninguna letra de menos de 12 pt; `.caption2` (11) solo en íconos |
| `testRomanCapsOnlyForMarkAndLabels` | Decisión del 30 oct 2026: Cinzel solo por `BrandMark` y `SectionLabel` |
| `testOnlyPiecesPaintTheAccent` | Regla 1 (26 nov 2026): ninguna pantalla usa el verde directo; las acciones van en tinta (`TextAction`); `.formScreen()` y `.pushedScreen()` tiñen en tinta y solo los interruptores van en verde (auditoría de medios) |
| `testCapsComeFromThePieces` | Regla 3: las versalitas salen de `CapsText`, `SectionHeader` o `CountLine`, nunca a mano |
| `testSectionsUseTheirHeader` | Regla 3 (SD-2, 26 nov 2026): toda sección se anuncia con `SectionHeader` y su acción va dentro, no en un `HStack` a mano; `SectionLabel` solo para el «Nº» y el capítulo |
| `testFitsLargeTextAndFingers` | Regla 9 y SB-4 (SD-4, 26 nov 2026): nada usa `.fixedSize()` (solo los dibujos `…Art`, con tope de letra); los títulos y las letras propias crecen (`@ScaledMetric`, `relativeTo:`); encabezados, conteos, campos, opciones en fila y la tarjeta y barras del lector usan `AdaptiveStack`; las acciones de un encabezado son `IconButton` o `AccentIconButton`, toda pieza con un botón mide 44, y el índice A–Z se toca en 44, va en tinta, tiene tope de letra, cabe en su alto y quien lo pone le deja su columna, lo empieza bajo el conteo y lo esconde con la letra más grande (auditoría 1); `WrapRows` le da el renglón entero a lo que no cabe solo, y los filtros pueden usar dos renglones; `StatTrio` pone una cifra bajo otra con la letra más grande; toda hoja con `.medium` también tiene `.large` y se desplaza, y «Sesión terminada» abre a todo lo alto con la letra más grande; en la Mac ninguna medida de hoja pasa de `Mac.sheetMax`, que cabe bajo la barra de `Mac.window`, y `Size.macReader` es solo de la ventana del libro (auditoría 2); en la Mac toda celda de la tabla es `MacCell`, que corta con «…» en un renglón (MX-B), y sus columnas se encogen hasta `Mac.narrowColumn`; con la ficha abierta, solo las de más peso y autor y serie con `Mac.nameColumn`; los campos de la ficha, en tinta con su pista `.fieldPrompt`; las salidas de una hoja van con `.sheetActions`, botones lado a lado en `ButtonPair`, el conteo con cada cifra pegada a su palabra, el punto de una fila con `@ScaledMetric` y el índice A–Z con su instrucción en la pista (auditoría 3); en «Aa» nada se achica y las muestras van en la misma caja; lo que flota sobre el libro tiene tope de letra y de ancho (auditoría de medios) |
| `testFiguresAreExact` | Regla 4: toda pieza que enseña cifras las pone del mismo ancho |
| `testOneGreenForEverything` | Un solo verde: ningún color con tono verde se escribe fuera de `Theme.Green` (ni en `Theme.swift`, ni en pantallas, piezas o el libro), `action` y el color del sistema salen de él, `reader.js` no escribe ningún color, y en el catálogo solo vale `AccentColor` con los valores de `Theme.Green` |
| `testSpacingKeepsTheHouseScale` | Regla 5 y SB-2 de la casa: sin 12 ni 6, y nada heredado en `sistema-base.json` |
| `testMainActionIsDarkInBothModes` | Regla 6: `Theme.action` igual y oscuro en los dos modos, y `PrimaryButton` lo usa |
| `testBoldOnlyForTitlesAndFigures` | D2-B de la casa: negrita solo en el título más grande y en cifras |
| `testEveryScreenFollowsARecipe` | Toda pantalla usa `.screen()`, `.pushedScreen()` o `.formScreen()`, así lo nuevo nace con la forma de la app |
| `testNoticesSayWhatHappened` | Regla 7 (SD-2, 26 nov 2026): todo aviso sale de `.errorAlert` o `.noticeAlert` (a mano solo si pide escribir), su título tiene tres palabras o más y dice qué pasó, y nada dice «No se pudo», «Se borra», «Se copian» ni «Se guarda en» |
| `testButtonsSayWhatTheyDo` | Regla 7 y SB-1: ningún botón dice solo «Cancelar», «OK», «Listo», «Cerrar», «Seguir»…; toda ✕ es `CloseButton` con su nombre; toda pregunta (`.question`, `alert`) trae su botón con `role: .cancel`, y ninguna es `confirmationDialog`: en iOS 26 sale como globo y lo esconde (auditoría 8) |
| `testWaitingSaysWhat` | Regla 7: ninguna pantalla enseña una ruedita sola; `LoadingLine` dice qué estoy haciendo |
| `testSameWordsOnBothPlatforms` | Regla 8 (SD-3, 26 nov 2026): estados, acciones de la biblioteca, lo que haces con el texto, «Sin título» y la fecha corta salen de un solo lugar, y el iPhone y la Mac los usan; el dispositivo («En este iPhone», su dibujo, dónde queda la carpeta) sale de `DeviceKind`, y un texto solo nombra el iPhone si habla también de la Mac (auditoría 2) |
| `testTextsNeverRunTogether` | Regla 8 (UX-7 y UX-8b, 27 nov 2026): dos datos seguidos llevan algo en medio; un campo de un aviso empieza vacío con lo propuesto de pista («CorCortázar» al guardar un estante) y ninguna hoja escribe su campo al aparecer (renombrar en la Mac); la hendidura arma su texto bloque por bloque, con un salto entre el título del capítulo y su primera frase |
| `testNamesKeepTheirDirection` | Regla 8 (auditoría 8, 27 nov 2026): un título, autor o serie junto a cifras, «·» o «…» va aislado (`.isolated`): en hebreo o árabe revolvía su renglón |
| `testPeopleReadWordsNotSyntax` | Regla 8 (auditoría de medios, 27 nov 2026): ni rutas de archivo, ni la búsqueda cruda de un estante, ni el marcado de una nota, ni filtros `x:` en la pista de un buscador |
| `testMacSaysTheNameOnce` | Regla 8 (MX-B, 26 nov 2026): en la Mac `ScreenHeading` y `DeskHeader` no repiten el título en el contenido (va en la barra de la ventana), el engrane de Ajustes solo existe en el iPhone y Ajustes de la Mac va en pestañas; la ventana no le pone nombre por fuera a la Mesa, el Cuaderno ni Buscar, así lo que se abre dentro dice el suyo (27 nov 2026) |
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

- **Renglón (LG-B):** lo demás en penumbra (`GuideShade`). Tocar baja un renglón; tocar en la orilla izquierda (`Reader.edgeZone`) lo regresa. En páginas la guía baja por la página y al pasar del último renglón la hoja da vuelta sola; en continuo la guía se queda a `Reader.guideAnchor` (38 %) de la pantalla y lo que sube es el texto. El círculo de vidrio con ✕ arriba a la izquierda la quita: todo lo del lector se cierra ahí, como el libro y la hendidura (antes la guía se cerraba abajo a la derecha y la hendidura arriba a la izquierda).
- **Hendidura (HE-B por frase, HE-A por palabra):** `SlitScreen`, el texto desde la página que ves hasta el fin del capítulo pasa por una ranura entre dos `Hairline`, con `Reader.slitContext` pedazos antes y después a `Emphasis.aside`. Abajo, en una sola fila, frase o palabra a la izquierda (`FilterBar`, como en toda la app) y el ritmo a la derecha (con la letra más grande, debajo), de 200 a 400 palabras/min (empieza en 260; la investigación no respalda más). Cada oración termina con un respiro, y entre bloques (el título del capítulo y su primera frase, dos párrafos) hay un salto: nunca pasan juntos (UX-8b). Tocar pausa; deslizar regresa o adelanta. Al cerrar, el libro queda donde ibas. El corte y los tiempos viven en `LectoraCore/Guided/Slit.swift`, con sus pruebas (`SlitTests`).
