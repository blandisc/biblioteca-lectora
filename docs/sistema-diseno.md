# Sistema de diseño de Lectora

Un solo estilo (Editorial): papel, tipografía y el lápiz rojo para tus marcas, sobre
componentes nativos de Apple. Todo valor visual es un **token**; toda pieza repetida es
un **componente**; toda pantalla sigue una **receta**.

## Regla

1. Las pantallas (`App/Shared/Screens/`, `Reader/ReaderView.swift`) **no usan números,
   colores ni fuentes sueltos**. Usan `Theme.*`, las fuentes de `Font` de abajo y los
   componentes de `Design/Components.swift`.
2. Si falta un token o un componente, **se agrega al sistema** (Theme / Components) con
   su nombre y su uso, y se documenta aquí. No se resuelve en la pantalla.
3. `scripts/lint-design.sh` lo verifica en cada push (CI, paso «Sistema de diseño»).
   Excepción puntual: comentario `// lint-design: permitido` con el porqué.
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
| `secondaryInk` | `#77746D` | `#9C988F` | Texto secundario |
| `tertiaryInk` | `#9A968D` | `#6F6C65` | Folios y etiquetas pequeñas |
| `track` | `#E6E3DC` | `#34322E` | Pistas y separadores |
| `accent` | `#3D6B55` | `#8FBFA4` | Verde hoja, **solo tus marcas y avisos**: subrayado, nota, cinta, audio sonando, pendientes, índice A–Z (antes `pencil`, rojo) |

Los fondos del lector (Papel, Blanco, Noche cálida, Negro) viven en `ReaderPalette`.

### Espacio (`Theme.Space`, escala de 4 pt)

`xxs 2 · xs 4 · s 8 · m 12 · l 16 · xl 24 · xxl 32 · xxxl 48`

| Token | Valor | Uso |
|---|---|---|
| `gutter` | 28 | Margen lateral de toda pantalla, igual a ambos lados |
| `screenTop` | 24 | Del área segura al título de pantalla |
| `screenBottom` | 32 | Aire antes del dock |

### Radio (`Theme.Radius`)

`cover 3 · chip 8 · control 10 · tile 14 · capsule 22 · panel 28`

### Tamaño (`Theme.Size`)

`tapTarget 44 · control 46 · coverHero 132 · coverDetail 168 · coverEditor 84 · coverRow 40 ·
coverMini 26 · gridColumns 3 · hairline 0.5 · progress 2 · quoteRule 2 · selection 2 · accentButton 44`

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

`standard` (snappy 0.25 s) para cambios de estado; `press` (0.15 s) al tocar.

## Componentes (`Design/Components.swift`)

| Componente | Qué es | Dónde |
|---|---|---|
| `.screen()` | Receta de pantalla raíz: papel, sin barra de navegación, destinos de libro y serie | Mesa, Biblioteca, Cuaderno |
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
| `FactRow` | Etiqueta / valor con línea fina | Ficha del libro |
| `EmptyState` | Título, explicación y acción opcional | Toda lista vacía |
| `ThinProgress`, `Hairline`, `LetterIndex` | Progreso, separador, índice A–Z | — |
| `MiniPlayer` | Reproductor sobre el dock | Raíz |
| `BrandMark` | «GABINETE» en Cinzel, centrado | Arriba de la Mesa |
| `SectionLabel` | Rótulo en mayúsculas romanas pequeñas (Cinzel, `Font.sectionLabel`) | «EN LA MESA», «SE COMPLETARON SOLOS», «Nº 7» en la ficha |
| `AccentIconButton` | Ícono de acción en `brand`, sin fondo: el único acento verde de una pantalla | «+» de la Biblioteca |
| `SecondaryButton`, `LinkRow` | Acción secundaria a lo ancho; fila que lleva a otra pantalla | «Por revisar» |
| `CandidateRow`, `CandidateCover` | Libro encontrado en internet: probabilidad y razones en palabras | Elegir los datos |
| `CompareRow` | Dato nuevo frente al tuyo («Antes: …»), con «Deshacer» opcional | Vista previa, lo completado |
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

**Pantalla empujada (ficha, serie):** `ScrollView { … .screenContent() }.background(Theme.paper.ignoresSafeArea())` con título en línea.

**Vacío:** siempre `EmptyState` con qué falta y cómo resolverlo; con acción si existe.

## Simetría

Medida en las capturas del simulador (píxeles → puntos) y en el código:

- Margen lateral: 28 pt a ambos lados en todas las pantallas (`gutter`). Las filas que
  se desplazan (`FilterBar`) llegan al borde y alinean su primer texto con el margen.
- Título de pantalla: misma altura en Biblioteca, Cuaderno y Buscar (antes Buscar usaba
  el título del sistema, 35 pt más abajo y con 16–20 pt de margen).
- Lector: los controles de vidrio tienen el mismo margen (`Reader.chromeInset`, 16 pt)
  arriba y abajo; las zonas de toque izquierda y derecha son franjas iguales
  (`Reader.edgeZone`, 28 %).
- Cuadrículas: columnas iguales (`GridItem(.flexible())` ×3) con 16 pt entre columnas
  y 24 pt entre filas.
