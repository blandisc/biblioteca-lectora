import LectoraCore
import SwiftUI

/// Sistema de diseño de Gabinete (Editorial con identidad neoclásica mínima).
///
/// **Regla:** las pantallas no usan números, colores ni fuentes sueltos. Todo
/// sale de estos tokens y de los componentes de `Components.swift`; las recetas
/// están en `docs/sistema-diseno.md`. `scripts/lint-design.sh` lo verifica en CI.
enum Theme {
    // MARK: Color — cada token tiene valor claro y oscuro

    /// Fondo de todas las pantallas: un solo papel.
    static let paper = Color(light: 0xF8F7F4, dark: 0x161514)
    /// Campos, filtro activo y botones secundarios.
    static let field = Color(light: 0xEFEDE8, dark: 0x242320)
    /// Texto principal.
    static let ink = Color(light: 0x1C1B19, dark: 0xECE9E2)
    /// Texto sobre tinta.
    static let onInk = Color(light: 0xFFFFFF, dark: 0x141413)
    /// Texto secundario.
    static let secondaryInk = Color(light: 0x6F6C65, dark: 0x9C988F)
    /// Texto terciario: folios y etiquetas pequeñas.
    static let tertiaryInk = Color(light: 0x837F78, dark: 0x7C7870)
    /// Pistas de progreso y separadores.
    static let track = Color(light: 0xE6E3DC, dark: 0x34322E)
    /// El papel hondo de Ajustes, debajo de sus tarjetas (AJ-D): se despegan sin sombras.
    static let sunken = Color(light: 0xF2F0EB, dark: 0x121110)
    /// Una tarjeta de Ajustes sobre el papel hondo.
    static let card = Color(light: 0xFFFFFF, dark: 0x1F1E1C)
    /// Verde botella (AC-3, 26 nov 2026): el único acento. Marca solo tres cosas: dónde
    /// estás (pestaña, filtro elegido), lo que avanzas (palabras, marca de la Mesa) y lo
    /// tuyo (subrayados, cinta, pendientes). Las acciones van en tinta. Solo lo pintan las
    /// piezas del sistema, nunca una pantalla (`DesignRulesTests`).
    static let accent = Color(light: Green.light, dark: Green.dark)
    /// Lo tuyo dentro y fuera del libro (subrayados, notas, marcador, la cita): el mismo
    /// verde, con nombre propio para que todo lo que marca apunte a un solo lugar.
    static let highlight = accent
    /// Letra sobre el verde (la tarjeta para compartir, la portada del dibujo de Ajustes).
    static let onAccent = Color(light: 0xFFFFFF, dark: 0x141413)
    /// Sombras y penumbras de objeto (portada sobre el papel, lomo, hoja que se dobla): negro
    /// en los dos modos, siempre con poca fuerza (`CoverArt.shadow`, `Reader.curlShadow`…).
    static let shade = Color.black

    /// El verde de Gabinete, escrito una sola vez (26 nov 2026). De aquí salen `accent`,
    /// `highlight`, `action`, el color del sistema (enlaces, «Listo», alertas), las etapas
    /// de lectura y los subrayados en el libro: cambiar el acento es cambiar estas dos
    /// líneas. Ningún otro lugar escribe un verde (`testOneGreenForEverything`).
    enum Green {
        static let light: UInt32 = 0x0F4A35
        static let dark: UInt32 = 0x4FB386
        /// El mismo verde como color CSS, para lo que se dibuja dentro del libro.
        static func css(dark: Bool) -> String {
            String(format: "#%06X", dark ? Green.dark : Green.light)
        }
    }
    /// Acción principal («Seguir leyendo», «Nota nueva»): el verde hondo en los dos modos,
    /// con letra clara. En oscuro antes era un bloque verde menta que gritaba (SD-1).
    static let action = Color(light: Green.light, dark: Green.light)
    /// Letra sobre la acción principal.
    static let onAction = Color(light: 0xF3EFE6, dark: 0xECE9E2)

    /// Etapas de una sesión de lectura: del gris (interrumpida) al verde pleno (inmersa).
    /// Todas salen del mismo verde con más o menos fuerza, así nunca vuelve otro tono.
    static func stage(_ stage: ReadingStage) -> Color {
        switch stage {
        case .interrupted: track
        case .skimming: accent.opacity(Emphasis.stageSkim)
        case .light: accent.opacity(Emphasis.stageLight)
        case .active: accent.opacity(Emphasis.stageActive)
        case .immersed: accent
        }
    }

    #if os(macOS)
    /// La letra de lo elegido en una tabla o una lista de la Mac: sobre el color de la
    /// selección, el blanco (o lo que pida el sistema), no la tinta del papel (MX-B).
    static let onSelection = Color(nsColor: .alternateSelectedControlTextColor)
    #endif

    /// La Mac como mesa de trabajo (MG-1) y de papel (MX-B, 26 nov 2026): medidas de la
    /// ventana nativa, su barra lateral, la tabla y la ficha. Los controles son los de macOS,
    /// con el papel, la tinta y las letras de Gabinete.
    enum Mac {
        static let window = CGSize(width: 1100, height: 620)
        /// Al abrirla por primera vez: cabe la tabla con sus columnas y la ficha.
        static let defaultWindow = CGSize(width: 1360, height: 820)
        static let sidebar: CGFloat = 220
        static let sidebarMin: CGFloat = 180
        static let inspector: CGFloat = 320
        static let inspectorMin: CGFloat = 280
        static let inspectorCover = CGSize(width: 84, height: 126)
        static let rowCover = CGSize(width: 16, height: 24)
        static let coverColumn: CGFloat = 24
        static let titleColumn: CGFloat = 180
        /// Lo más que crecen el autor y la serie: lo que sobra en una ventana ancha va al título
        /// (auditoría 5: con la ficha abierta el título se quedaba en 120 y cortado y la serie
        /// crecía a 436).
        static let nameColumnMax: CGFloat = 240
        /// Debajo de este ancho de tabla, Etiquetas, Avance y Agregado piden poco y el título se
        /// queda con el espacio (auditoría 6: a 1100 el título quedaba casi en su mínimo y cortado).
        static let roomyTable: CGFloat = 1000
        /// Cuánto espera la tabla a que dejes de cambiar el ancho antes de volver a repartir sus
        /// columnas (auditoría 5): antes se rearmaba a cada paso y saltaba arriba.
        static let relayoutPause: Duration = .milliseconds(350)
        static let shortColumn: CGFloat = 72
        static let column: CGFloat = 110
        /// Lo más que se encoge una columna de la tabla antes de cortar con «…».
        static let narrowColumn: CGFloat = 48
        /// Lo más que se encogen el autor y la serie: el título cede antes que ellos (auditoría 3).
        static let nameColumn: CGFloat = 88
        /// Gabinete › Ajustes… (⌘,), en pestañas: el ancho; el alto es el de cada pestaña.
        static let settings: CGFloat = 560
        /// El alto de Reglas o de una conexión, abiertas desde una pestaña de Ajustes.
        static let settingsPage: CGFloat = 520
        /// Una nota o las portadas de internet abiertas desde la ficha.
        static let sheet = CGSize(width: 560, height: 560)
        /// El libro en la Mac va en una sola columna centrada, aunque la ventana sea ancha.
        static let readingColumns = 1
        /// La barra de avance de «Buscar datos» en lote (CB-4).
        static let batchProgress: CGFloat = 220
        /// Renombrar o fusionar un autor, una serie o una etiqueta (CB-2): su ancho; el alto es el
        /// de su contenido (con 220 fijos sobraban ~160 pt vacíos).
        static let catalogSheet: CGFloat = 420
        /// Lo más chica que puede ser la ventana de un libro.
        static let readerMin = CGSize(width: 520, height: 600)
        static let summary: CGFloat = 120
        /// La bienvenida en la Mac: su ancho; el alto es el de cada paso, hasta `sheetMax`.
        static let welcome: CGFloat = 560
        /// Lo más alta que es una hoja: cabe bajo la barra de la ventana más chica (`window`, 620).
        /// Antes la bienvenida medía 820 y salía más alta que la ventana (auditoría 2).
        static let sheetMax: CGFloat = 560
    }

    // MARK: Espacio — la escala común de interoperabilidad (SB-2): 4 · 8 · 16 · 24 · 32 · 48.
    // Sin 12 ni 6 desde el 26 nov 2026 (SD-2): el trinquete de Gabinete quedó en cero. Las
    // medidas con nombre también caen en la escala (SD-1, 26 nov 2026: 28, 10, 14 y 20 se
    // fueron al paso más cercano); lo vigilan `sistema-base.json` y `testSpacingKeepsTheHouseScale`.

    // MARK: La ventana (iPhone Duo y cualquier iPhone)

    /// La forma de la ventana (`WindowLayout`): con qué medidas una pantalla es un libro abierto, es
    /// baja o tiene una franja del sistema al costado. Nunca se pregunta qué aparato es.
    enum Window {
        /// Si los dos lados de la ventana miden al menos esto, es un libro abierto con pliegue a la
        /// mitad del lado largo (el iPhone Duo abierto: 669 × 951). Ningún iPhone de una pantalla
        /// llega: el más ancho mide 440.
        static let foldMinSide: CGFloat = 600
        /// Menos alto que esto, la ventana es baja (un iPhone acostado: 402 a 440; el Duo cerrado
        /// acostado: 466): encabezado de un renglón, el pie del libro delgado, portadas por alto.
        static let shortHeight: CGFloat = 500
        /// Lo que el sistema ocupa de un lado más que del otro para que sea una franja al costado
        /// (la hora y las pestañas del Duo cerrado, unos 84): las muescas de un iPhone acostado, iguales
        /// a los dos lados, no cuentan.
        static let stripMin: CGFloat = 24
        /// Lo más angosta que queda una página de un pliego (o una columna junto al pliegue): con
        /// menos, todo va en una sola página.
        static let minPage: CGFloat = 280
        /// En una ventana baja (sin pliegue), lo que se lleva la primera de dos columnas lado a lado.
        static let sideBySideShare: CGFloat = 0.45
        /// Lo más alta que es una portada de cuadrícula, como parte del alto de la ventana: en una
        /// pantalla baja caben más columnas en vez de portadas que se comen la pantalla.
        static let coverHeightShare: CGFloat = 0.4
        /// Lo que deja iOS alrededor de dos botones de texto en una barra (sus orillas, su vidrio y
        /// el aire entre ellos). Si no cabe, iOS esconde el segundo en su «•••»: entonces baja al pie
        /// (`.sheetActions`). Medido: en un iPhone 17 Pro sobran 114 y caben; en el Duo cerrado, 94 y no.
        static let barTextSlack: CGFloat = 104
    }

    enum Space {
        /// Medio paso, solo dentro de piezas chicas (dos renglones de una fila, un selector).
        static let xxs: CGFloat = 2 // sistema-base: ignora medio paso dentro de piezas chicas; nunca entre bloques
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
        // Medidas con nombre para lo que se repite fuera de la escala. Nunca se suman
        // tokens en una pantalla o pieza («s + xxs»): si hace falta otra medida, va aquí.
        /// Separación mínima: entre las letras del índice A–Z.
        static let hair: CGFloat = 1 // sistema-base: ignora separación de un punto entre las letras del índice A–Z
        /// Aire arriba y abajo de una fila de lista (libro, dato, sesión, resultado).
        static let rowY: CGFloat = 8
        /// Entre la portada (o la raya de una cita) y su texto.
        static let rowGap: CGFloat = 16
        /// Interior horizontal de un botón principal.
        static let buttonX: CGFloat = 24
        /// Lo que una lista con índice A–Z deja libre a su derecha, además del margen: la columna
        /// del índice (44) menos el margen (24), y aire. Sin esto las letras pisaban el orden y la
        /// orilla de las filas (auditoría 1, 27 nov 2026).
        static let letterIndex: CGFloat = 24
        /// El lomo de un libro abierto (el iPhone Duo abierto): lo que se deja libre a los dos lados
        /// del pliegue, en total. Nada se dibuja ahí: ni texto, ni portadas, ni hojas.
        static let fold: CGFloat = 48
        /// Margen lateral de toda pantalla. Igual a la izquierda y a la derecha, y el mismo
        /// del texto del libro (`Reader.textMargin`).
        static let gutter: CGFloat = 24
        /// Del área segura superior al título de la pantalla. En la Mac no hay título en el
        /// contenido (va en la barra de la ventana, regla 8) y la barra ya deja su aire (16): el
        /// contenido empieza ahí. Con 24 la Mesa, el Cuaderno y el Diario quedaban con un hueco de
        /// 40 a 50 pt bajo la barra (27 nov 2026).
        #if os(macOS)
        static let screenTop: CGFloat = 0
        #else
        static let screenTop: CGFloat = 24
        #endif
        /// En la Mac, lo que deja la barra de la ventana y no deja una hoja (la nota abierta desde la ficha).
        static let screenTopInSheet: CGFloat = 16
        /// Aire al final del contenido, antes del dock.
        static let screenBottom: CGFloat = 32
        /// El aire de una pantalla arriba y abajo juntos (`Spread` lo suma para saber si lo principal
        /// cabe arriba del pliegue).
        static let screenAir: CGFloat = screenTop + screenBottom
        /// Sangría de una entrada del índice del libro: un paso por nivel, hasta `Size.indentLevels`.
        static func indent(_ depth: Int) -> CGFloat {
            l * CGFloat(min(depth, Size.indentLevels))
        }
    }

    // MARK: Radio

    enum Radius {
        /// Esquinas de una portada.
        static let cover: CGFloat = 3
        /// Botones y campos.
        static let control: CGFloat = 10
        /// Tarjetas pequeñas (opciones de la hoja «Aa»).
        static let tile: CGFloat = 14
        /// La marca de la opción elegida dentro de un selector (el mosaico menos su borde).
        static let segment: CGFloat = 10
        /// Paneles de vidrio del lector.
        static let panel: CGFloat = 28
        /// Lo que va dentro de un panel a su orilla (16): el radio del panel menos esa orilla, para que las esquinas se vean concéntricas.
        static let inset: CGFloat = 12
        /// Muestra de color de una leyenda.
        static let swatch: CGFloat = 2
    }

    // MARK: Tamaño

    enum Size {
        /// Área mínima de toque (HIG y SB-4).
        static let tapTarget: CGFloat = 44
        /// Renglones de una etiqueta que con la letra más grande ya no cabe en uno (un mosaico,
        /// una fila de libro, el libro sobre la tarjeta del lector).
        static let labelLines = 2
        /// El título de un libro en una ventana baja (ficha, Mesa): a lo más tres renglones y luego
        /// «…» tras una palabra entera, para que su botón se vea sin desplazar.
        static let titleLinesShort = 3
        /// Lo que el área de toque de un ícono (44) sobresale de su dibujo: se compensa para
        /// que el botón no empuje lo de al lado.
        static let tapBleed: CGFloat = 12
        /// Alto de una fila de ajustes o de opciones: aire de libreta, cómoda de tocar.
        static let row: CGFloat = 52
        /// El trazo verde bajo el filtro elegido.
        static let tabMark = CGSize(width: 16, height: 2)
        /// Las hojitas de muestra de Apariencia (Sistema, Claro, Oscuro).
        static let pageSwatch: CGFloat = 78
        /// Ajustes (AJ-D): el alto del dibujo de cada tarjeta y lo que va en él.
        static let settingsArt: CGFloat = 150
        static let artPage = CGSize(width: 200, height: 124)
        static let artSummary: CGFloat = 118
        static let artBook = CGSize(width: 52, height: 78)
        static let artArrow: CGFloat = 72
        static let artSynopsis: CGFloat = 84
        static let artNode: CGFloat = 46
        static let artHub: CGFloat = 58
        static let artHubLetter: CGFloat = 20
        static let artWire: CGFloat = 44
        /// El ícono de cada carpeta en el árbol de Tu Gabinete y dónde cuelga su guía.
        static let artTreeIcon: CGFloat = 18
        static let artTreeGuide: CGFloat = 9
        /// Los renglones de la hojita de Lectura, a lo largo de la página.
        static let artLines: [CGFloat] = [1, 1, 0.86, 1, 0.62]
        /// Renglones de esa hojita: grueso y largo de cada uno (fracción del ancho).
        static let swatchLine: CGFloat = 3
        static let swatchLines: [CGFloat] = [1, 0.8, 0.55]
        /// Punto de estado (conectado o no) y de pendiente.
        static let statusDot: CGFloat = 6
        /// Renglones que puede ocupar el conteo de una lista antes de cortarse.
        static let countLines = 2
        /// Filo del punto de estado hueco.
        static let statusDotLine: CGFloat = 1
        /// Alto de las barras del ecualizador (audio sonando).
        static let equalizerHeight: CGFloat = 12
        /// Alto de botones; ancho de botones redondos.
        static let control: CGFloat = 46
        static let coverHero: CGFloat = 132
        /// La portada de la Mesa en una ventana baja (un iPhone acostado, el Duo cerrado acostado).
        static let coverHeroShort: CGFloat = 88
        static let coverDetail: CGFloat = 168
        static let coverRow: CGFloat = 40
        static let coverMini: CGFloat = 26
        static let coverEditor: CGFloat = 84
        /// Alto mínimo de un campo de texto largo (sinopsis).
        static let textEditor: CGFloat = 120
        /// Columnas de la cuadrícula de portadas.
        static let gridColumns = 3
        /// Con la letra más grande: dos columnas y el título bajo la portada en hasta tres renglones.
        static let gridColumnsLarge = 2
        /// Lo más ancha que crece una portada de la cuadrícula (con la letra más grande,
        /// `coverCellWidestLarge`). En una pantalla ancha (el iPhone Duo abierto, un iPhone
        /// acostado) caben más columnas en vez de portadas enormes; en un iPhone de pie
        /// siguen siendo tres (o dos), porque ninguna llega a esta medida.
        static let coverCellWidest: CGFloat = 150
        static let coverCellWidestLarge: CGFloat = 240

        /// Columnas de la cuadrícula de portadas para un ancho: al menos las de siempre
        /// (`gridColumns`, o `gridColumnsLarge` con la letra más grande) y las que hagan falta para
        /// que ninguna portada pase de `coverCellWidest` de ancho ni de `Window.coverHeightShare` del
        /// alto de la ventana (`height`, 0 si no se sabe), con `Space.l` entre ellas (`CoverColumns`).
        /// En la Mac, como siempre: las que quepan de `coverCellWidest`.
        static func gridColumns(fitting width: CGFloat, height: CGFloat = 0, large: Bool) -> Int {
            let fewest = large ? Size.gridColumnsLarge : Size.gridColumns
            let widest = large ? Size.coverCellWidestLarge : Size.coverCellWidest
            #if os(macOS)
            guard width > 0 else { return fewest }
            return max(fewest, Int((width + Space.l) / (widest + Space.l)))
            #else
            return CoverColumns.count(width: width, height: height, fewest: fewest, widest: widest, gap: Space.l,
                                      heightShare: Window.coverHeightShare, aspect: coverAspect)
            #endif
        }
        static let coverCaptionLinesLarge = 3
        /// Columnas de las letras en «Aa» (una sola con la letra más grande).
        static let fontColumns = 2
        static let hairline: CGFloat = 0.5
        static let progress: CGFloat = 2
        static let quoteRule: CGFloat = 2
        /// Área de toque del botón de acento («+» de la Biblioteca).
        static let accentButton: CGFloat = 44
        /// Borde de la opción elegida (portada en la cuadrícula).
        static let selection: CGFloat = 2
        /// Cinta del marcador en el lector.
        static let ribbon = CGSize(width: 12, height: 64)
        /// Alto de la hoja «Aa» mientras se mide (luego mide lo que su contenido).
        static let appearanceSheet: CGFloat = 584
        /// La hoja chiquita que enseña cada estilo de pasar la hoja en «Aa».
        static let turnPreview = CGSize(width: 18, height: 24)
        /// Barra de etapas de una sesión.
        static let stageBar: CGFloat = 8
        /// La barra de etapas fina, en la tarjeta de la sesión del lector: del grueso de una línea, no de un bloque.
        static let stageBarThin: CGFloat = 4
        /// Muestra del pie en el panel del lector: un recorte de la parte de abajo de la página.
        static let footerPreview: CGFloat = 64
        /// El trazo verde con que acaba la línea del encabezado de la Mesa.
        static let deskMark = CGSize(width: 16, height: 4)
        /// Ancho del globo que sale al tocar el pie: dos muestras por renglón.
        static let footerPicker: CGFloat = 320
        /// Renglón fantasma de esa muestra.
        static let ghostLine: CGFloat = 3
        /// Perilla de la barra de avance del lector.
        static let scrubberKnob: CGFloat = 14
        /// Alto de la barra de avance: la perilla cómoda de arrastrar sin dejar un hueco.
        static let scrubberHeight: CGFloat = 32
        /// Lo que el área de toque de la barra sobresale de su alto (32 + 2 × 6 = 44).
        static let scrubberReach: CGFloat = 6
        /// Al buscar en notas: letras de contexto antes y después de lo encontrado.
        static let excerptReach = 60
        /// Lo que se mueve el dedo antes de saber si arrastra la barra (de lado) o sube el panel.
        static let dragSlop: CGFloat = 6
        /// Alto de una fila de la gráfica de etapas, y de su marca.
        static let stageRow: CGFloat = 26
        /// La gráfica de etapas entera: una fila por etapa.
        static func stageChart(rows: Int) -> CGFloat { Size.stageRow * CGFloat(rows) }
        static let stageMark: CGFloat = 16
        /// Muestra de color en la leyenda de etapas.
        static let legendSwatch: CGFloat = 8
        /// Separación entre las etapas de la barra.
        static let stageGap: CGFloat = 1
        /// Botón de reproducir del mini reproductor, con su anillo de avance.
        static let playRing: CGFloat = 38
        /// Barras del ecualizador (audio sonando): su grueso y el alto de cada una.
        static let equalizerBar: CGFloat = 2
        static let equalizerBars: [CGFloat] = [0.5, 1, 0.7]
        /// Dónde empieza un anillo de avance: arriba, como las manecillas.
        static let ringStart = Angle.degrees(-90)
        /// Alto de las barras de la semana y del año en el diario.
        static let weekChart: CGFloat = 112
        static let yearChart: CGFloat = 80
        /// Ancho de una barra de la semana.
        static let weekBar: CGFloat = 18
        /// Día del calendario del mes.
        static let dayCell: CGFloat = 34
        /// Tarjeta para compartir una sesión.
        static let shareCard = CGSize(width: 300, height: 375)
        /// Ventana mínima del lector en el Mac.
        static let macReader = CGSize(width: 720, height: 820)
        /// Lo más ancho que corre un renglón del libro (unas 66 letras): en una ventana ancha
        /// el texto se queda en esta medida, centrado, y no se estira de orilla a orilla (MX-B).
        static let readingMeasure: CGFloat = 640
        /// Lo más ancha que es una tarjeta de vidrio del lector: la columna del libro con el aire
        /// de adentro de la tarjeta. En la Mac la tarjeta ya no cruza toda la ventana (auditoría).
        static let readingPanel: CGFloat = readingMeasure + 2 * Reader.panelInset
        /// Un renglón cómodo de pantalla (ficha, nota, Cuaderno, Diario, Ajustes…) se mide en letras,
        /// no en puntos: unas 68 letras del texto normal (7,4 pt cada una en promedio con el tamaño de
        /// siempre); crece con el tamaño de texto de iOS (`ReadingColumn`). En el Duo abierto de pie el
        /// renglón ya no corre 100 letras; ningún iPhone de pie llega a esta medida.
        static let readingLine: CGFloat = 504
        /// Proporción de toda portada: ancho entre alto (2 : 3).
        static let coverAspect: CGFloat = 2.0 / 3.0
        /// Niveles de sangría del índice del libro; más hondo ya no se mete.
        static let indentLevels = 3
    }

    // MARK: Portada tipográfica (proporciones del ancho de la portada)

    /// La portada dibujada para libros sin imagen se escala con su ancho: cada
    /// medida es una fracción de ese ancho, así se ve igual en la fila y en la ficha.
    enum CoverArt {
        static let inset: CGFloat = 0.09
        static let gap: CGFloat = 0.05
        static let title: CGFloat = 0.14
        static let author: CGFloat = 0.07
        static let authorTop: CGFloat = 0.06
        static let authorTracking: CGFloat = 0.6
        static let titleMinScale: CGFloat = 0.7
        /// Los pasos de la letra del título dibujado cuando su palabra más ancha no cabe (`WholeWordsText`).
        static let titleScales: [CGFloat] = [1, 0.9, 0.8, 0.7]
        /// Lomo: sombra del borde izquierdo, nunca menor que `spineMin` puntos.
        static let spine: CGFloat = 0.05
        static let spineMin: CGFloat = 3
        static let spineShade = 0.28
        /// Las portadas de atrás de una pila de serie, cada una un poco más en sombra.
        static let stackNear = -0.05
        static let stackFar = -0.1
        /// Cinta de «estás leyendo»: ancho, de dónde cuelga y cuánto sobresale.
        static let ribbon: CGFloat = 0.065
        static let ribbonMin: CGFloat = 5
        static let ribbonX: CGFloat = 0.88
        static let ribbonRise: CGFloat = 3
        static let ribbonOverhang: CGFloat = 22
        static let ribbonClear: CGFloat = 0.1
        static let ribbonShade = 0.2
        /// Esquinas: lomo casi recto, canto un poco redondeado.
        static let spineRadius: CGFloat = 2
        static let edgeRadius: CGFloat = 4
        static let edgeLine = 0.12
        static let line: CGFloat = 1.2
        static let thinLine: CGFloat = 1
        /// Sombra de la portada como objeto sobre el papel.
        static let shadow = 0.28
        static let shadowRadius: CGFloat = 7
        static let shadowY: CGFloat = 6
        /// Portada nítida (Mesa, ME-1): un filo de media línea que la recorta del papel y una
        /// sombra larga y tenue que apenas la despega, sin efecto de objeto.
        static let crispEdge = 0.14
        static let crispShadow = 0.16
        static let crispShadowRadius: CGFloat = 16
        static let crispShadowY: CGFloat = 14
        static let windmill = CGSize(width: 0.55, height: 0.6)
        static let circles = CGSize(width: 0.6, height: 0.3)
        static let circlesOverlap: CGFloat = 0.12
        static let rings: CGFloat = 0.5
        static let ringGap: CGFloat = 0.1
        static let ringDot: CGFloat = 0.07
        /// Una portada que no es 2∶3 (cuadrada, apaisada) cabe entera en el marco, sin estirarse
        /// ni recortarse, sobre ella misma desenfocada (UX-2e). Hasta `fitTolerance` de diferencia
        /// llena el marco, como siempre; el desenfoque es esta fracción del ancho.
        static let fitTolerance: CGFloat = 0.08
        static let fitBlur: CGFloat = 0.12
    }

    // MARK: Lector

    enum Reader {
        /// Toques en la página: izquierda (atrás) y derecha (adelante) son
        /// franjas iguales; el centro muestra los controles.
        static let edgeZone = 0.28
        /// Cuántas veces sigo al libro que cambió de carpeta mientras bajaba de iCloud, antes de abrirlo.
        static let followAttempts = 3
        /// Margen de los controles de vidrio, igual arriba y abajo, izquierda y derecha.
        static let chromeInset: CGFloat = 16
        /// Los botones de arriba suben esto hacia la isla, sin tocarla.
        static let chromeLift: CGFloat = 8
        /// Donde no hay isla ni hora arriba (el iPhone Duo cerrado lleva la hora al costado),
        /// los botones de arriba no suben: quedan a esto de la orilla de la pantalla, sin
        /// salirse (`ReaderView.chromeTop`).
        static let chromeEdge: CGFloat = 4
        /// Pasar la hoja: la fuerza del resorte (`TurnMotion`) que la lleva hasta el
        /// final o de regreso; con 15, una vuelta desde quieta tarda unos 0,55 s y,
        /// al soltar, sigue con la velocidad del dedo (nunca más de `turnSpeedLimit`
        /// anchos por segundo). Se da por terminada a `turnRest` del final.
        static let turnSpring = 15.0
        static let turnSpeedLimit: CGFloat = 4
        static let turnRest: CGFloat = 0.004
        /// Si un cuadro llega tarde, el resorte avanza a lo más esto: la hoja sigue
        /// desde donde iba, sin brincar al final.
        static let turnFrameCap: TimeInterval = 0.034
        /// Deslizar: un resorte con más fuerza que la hoja; sin ella, los últimos
        /// milímetros llegaban casi quietos. Igual en las dos direcciones.
        static let slideSpring = 19.0
        /// Con el dedo, la vuelta completa es lo que hay del toque a la orilla contraria,
        /// pero nunca menos de esta fracción del ancho (si tocas cerca del lomo).
        static let turnReach: CGFloat = 0.5
        /// Buscar en el libro: empieza sola cuando dejas de escribir esto, desde estas letras.
        static let searchPause: TimeInterval = 0.5
        static let searchMinLetters = 3
        /// Cuántas búsquedas recientes se guardan por libro.
        static let recentSearches = 5
        /// Pestaña Buscar: libros abiertos hace poco, subrayados antes de «Ver los N»,
        /// y la pausa tras la que lo que escribiste queda entre las recientes.
        static let recentBooks = 3
        static let foundHighlights = 3
        static let searchRemember: TimeInterval = 1.2
        /// El texto del libro a esta distancia de las orillas, en páginas y en continuo y
        /// en todo iPhone; el contenido de la tarjeta de abajo empieza en la misma línea
        /// (`chromeInset` + `panelInset`).
        static let textMargin: CGFloat = 24
        /// El renglón del libro, en letras de la letra que elegiste (unas 68: 32 veces su alto), en
        /// el iPhone y el Duo; con más ancho, aire a los lados o dos páginas, nunca renglones de 100.
        static let lineEms = 32.0
        /// Lo más angosta que queda una columna del libro (unas 35 letras): si dos páginas no caben
        /// así (la letra más grande), el libro va en una sola página.
        static let minLineEms = 16.0
        /// La letra del libro antes de tu tamaño: la de la página web (16 px), que «Aa» escala.
        static let pageEm: CGFloat = 16
        /// Lo de adentro de la tarjeta de abajo, a esto del vidrio: así su contenido empieza
        /// en la misma línea que el texto del libro.
        static let panelInset: CGFloat = textMargin - chromeInset
        /// La posición se da por asentada cuando el libro lleva esto quieto (para guardarla).
        static let positionSettle: Duration = .milliseconds(1500)
        /// La barra de avance con VoiceOver: cuánto mueve cada deslizar (1 %).
        static let scrubStep = 0.01
        /// El texto normal de iOS con el tamaño de siempre: lo que crezca sobre esto
        /// (Ajustes › Pantalla › Tamaño del texto) crece también la letra del libro.
        static let textBase: CGFloat = 17
        /// Al abrir, el libro se da por acomodado cuando lleva esto sin cambiar de página.
        static let openSettle: TimeInterval = 0.25
        /// La tarjeta de un subrayado muestra hasta estas líneas de la cita.
        static let highlightLines = 4
        /// El resumen de Wikipedia en la tarjeta «Consultar».
        static let lookupLines = 5
        /// Fundido: el mismo resorte que la hoja (con menos fuerza duraría más el
        /// momento sin texto a mitad del relevo). Es un relevo: el texto de antes
        /// se va en la primera `fadeSpan` de la vuelta y el nuevo llega en la última,
        /// cada uno corrido `fadeDrift` puntos hacia donde vas.
        static let fadeSpring = 15.0
        static let fadeSpan = 0.6
        /// Al cambiar entre páginas y continuo, relevo: la página de antes se va en
        /// `flowOut` y, ya acomodada, la nueva llega en `flowIn` subiendo `flowRise` puntos.
        static let flowOut: TimeInterval = 0.24
        static let flowIn: TimeInterval = 0.45
        static let flowRise: CGFloat = 6
        /// La nueva empieza a llegar a este tiempo, cuando la de antes ya casi se fue.
        static let flowHandoff: TimeInterval = 0.16
        /// Lo más que se espera a que el lector acomode el libro al cambiar de forma
        /// (si avisa antes, no se espera de más).
        static let flowSettle: TimeInterval = 0.7
        static let fadeDrift: CGFloat = 8
        /// La hoja de muestra en «Aa»: pausa entre vueltas (s) y sus renglones. La
        /// primera vuelta se adelanta `previewLead` (sale a 0,15 s de elegirla).
        static let previewPause: TimeInterval = 1
        static let previewLead: TimeInterval = 0.85
        /// La muestra se mueve con la curva de la real pero más despacio (`previewPace`
        /// de su fuerza): en un mosaico chico, a la velocidad real no se alcanza a ver.
        /// `previewTurn` es el tiempo que le toca a cada vuelta.
        static let previewPace = 0.6
        static let previewTurn: TimeInterval = 1.2
        static let previewLines = 5
        static let previewLastLine = 4
        /// La sombra de la hoja de muestra (la doblada y la que se desliza).
        static let previewShadow = 0.35
        /// Con el dedo: pasa si soltaste después de esta fracción del ancho…
        static let turnCommit = 0.3
        /// …o si la aventaste más rápido que esto (puntos por segundo).
        static let turnFling: CGFloat = 450
        /// Hoja mate: el radio del doblez (fracción del ancho), la inclinación de
        /// la esquina (radianes), la fuerza de la sombra y lo que se transparenta
        /// del texto en el revés.
        static let curlRadius: CGFloat = 0.16
        static let curlTilt = 0.1
        static let curlShadow: Float = 0.42
        static let curlShowThrough: CGFloat = 0.22
        /// Cuánto crece la máscara de la hoja doblada (píxeles): tapa el filo brillante.
        static let curlMaskGrow = 1.5
        /// Lo que se abre la tinta del revés (píxeles de la foto, a 2×).
        static let curlShowThroughBlur = 0.9
        /// Resolución del dibujo de la hoja mientras se dobla (2×: fluido y nítido).
        static let curlScale: CGFloat = 2
        /// Deslizar: la sombra de la hoja que se mueve.
        static let slideShadow: Float = 0.18
        static let slideShadowRadius: CGFloat = 14
        /// La página de abajo empieza con esta sombra y se aclara mientras la de
        /// arriba se va (la hoja es opaca: nunca se leen dos textos a la vez).
        static let slideDim = 0.08
        /// El revés de la hoja que se dobla: el mismo papel con esta fracción de su
        /// luz (más oscuro, como papel a contraluz; UIKit le suma su propio brillo).
        static let pageBack: CGFloat = 0.93
        /// La vibración al pasar a la página siguiente: muy ligera (0 a 1).
        static let turnHaptic: CGFloat = 0.45
        /// Aire arriba del texto en páginas, bajo la orilla segura: el primer renglón queda
        /// debajo de los botones de arriba (cerrar y marcador, que bajan `tapTarget` −
        /// `chromeLift` de la orilla), nunca tapado por ellos (UX-1a; antes 16).
        static let pageMarginTop: CGFloat = 48
        /// Abajo más aire: el pie y el contador van ahí, sobre la orilla del iPhone.
        static let pageMarginBottom: CGFloat = 64
        /// En continuo, el papel es sólido hasta la orilla del folio y después se
        /// desvanece hacia el texto en este alto, con una
        /// curva de `folioFadeSteps` tramos (se aclara pronto: la letra se sigue viendo).
        static let folioFade: CGFloat = 56
        static let folioFadeSteps = 6
        /// En continuo, cuánto más abajo empieza el desvanecido del pie: el papel sólido
        /// llega justo arriba del pie y deja más texto a la vista (25 nov 2026).
        static let folioFadeDrop: CGFloat = 24
        /// En continuo el texto corre hasta la orilla de la pantalla y se desvanece
        /// desde ahí hasta esto por debajo de la orilla segura (la isla).
        static let topFade: CGFloat = 24
        /// En continuo, el marcador cae estos renglones debajo del desvanecido de
        /// arriba: así el hilo y la cinta se ven enteros, no medio borrados (26 nov 2026).
        static let bookmarkLinesBelowFade = 2
        /// En continuo, el largo de la rayita bajo el pie que se llena con el capítulo.
        static let chapterLine: CGFloat = 64
        /// Lectura guiada (LG-B): en continuo, a qué altura de la pantalla se queda
        /// la guía; y qué tanto se apaga lo que no es el renglón.
        static let guideAnchor = 0.38
        static let guideShade = 0.72
        /// La hendidura: el aire arriba y abajo del pedazo que se lee, y cuántos
        /// pedazos se asoman antes y después.
        static let slitPadding: CGFloat = 16
        /// Alto de lo que se lee en la hendidura: dos renglones de `.bookTitle`, por frase o por palabra.
        static let slitHeight: CGFloat = 72
        static let slitContext = 4
        /// Lo que hay que deslizar el dedo para regresar o adelantar un pedazo.
        static let slitSwipe: CGFloat = 24
        /// El lomo del libro: sombra en la orilla izquierda de la hoja, su ancho y
        /// qué tan oscura empieza en papel claro y en papel oscuro.
        static let spineWidth: CGFloat = 26
        static let spineShadeLight: CGFloat = 0.07
        static let spineShadeDark: CGFloat = 0.3
    }

    // MARK: Cuántos se enseñan

    /// Cuántas cosas cabe enseñar de una lista antes de «Ver todo» o de cortar con «…».
    enum Lists {
        /// La pila de la Mesa: lo más reciente, sin el libro que lees.
        static let desk = 6
        /// Nombres en un aviso o un informe («Sin archivo: a, b, c…»).
        static let preview = 5
        /// Las sesiones más recientes en la ficha de un libro.
        static let detailSessions = 5
        /// Las sesiones más largas del periodo en el Diario.
        static let longestSessions = 2
        /// Libros para enlazar a una nota: sin buscar, los primeros de la biblioteca; al buscar, los que se proponen.
        static let linkShelf = 20
        static let linkSuggestions = 4
        /// Libros encontrados de los que se piden portadas, y portadas para elegir.
        static let coverSources = 3
        static let coverOptions = 12
        /// Cuántas se bajan como mucho para llegar a `coverOptions` distintas (auditoría 9, B2).
        static let coverDownloads = 24
        /// La sinopsis recortada en lo que se completó solo.
        static let summaryLetters = 140
        /// Subrayados y notas de un libro en la ficha de la Mac, antes de «Leer» para ver el resto.
        static let inspectorItems = 3
        /// Tus subrayados del capítulo en la página de margen del libro (Duo abierto, en continuo).
        static let marginNotes = 3
        /// Filtros que van en fila con la letra más grande; con más, el elegido y su menú (`FilterBar`).
        static let filtersInline = 3
    }

    // MARK: Énfasis

    enum Emphasis {
        /// Texto secundario sobre la marca (tarjeta para compartir).
        static let secondary = 0.75
        /// Texto callado sobre el vidrio del lector: el gris fijo se pierde ahí.
        static let glassText = 0.8
        /// La página de al lado mientras un panel ocupa la otra (`SidePanel`): se sigue viendo.
        static let panelShade = 0.12
        /// Riel de la barra de avance: tinta tenue que sí se ve sobre el vidrio.
        static let scrubberTrack = 0.25
        /// Al tocar: se hunde un poco y se apaga apenas, sin cambiar de color.
        static let pressedScale = 0.97
        /// En reposo: tamaño y opacidad completos.
        static let rest = 1.0
        static let pressed = 0.85
        /// Folio del lector (capítulo y porcentaje): el color del texto del libro,
        /// un poco apagado, para que se lea sobre cualquier fondo sin competir.
        static let folio = 0.74
        /// Renglones insinuados y filo de la muestra del pie: la tinta del libro, casi invisible.
        static let ghost = 0.12
        /// Fuerza del verde en cada etapa de lectura (hojeo, ligera, activa).
        static let stageSkim = 0.22
        static let stageLight = 0.45
        static let stageActive = 0.72
        /// Filo finísimo de la acción principal: la despega del papel oscuro.
        static let actionEdge = 0.16
        /// Fondo de un botón redondo dentro del vidrio (buscar y letra en la tarjeta del lector).
        static let inGlass = 0.1
        /// El pie de una muestra que aún no tiene dato: más apagado que el folio.
        static let folioMuted = 0.55
        /// Lo que se asoma alrededor de lo que lees (antes y después de la hendidura).
        static let aside = 0.3
        /// La perilla de la barra de avance crece así al arrastrarla.
        static let knobGrow = 1.4
        /// Lo más bajo que llega una barra del ecualizador al moverse.
        static let equalizerLow = 0.4
        /// Una etiqueta corta se achica hasta este tamaño antes de cortarse.
        static let labelMinScale: CGFloat = 0.8
    }

    // MARK: Movimiento

    enum Motion {
        static let standard = Animation.snappy(duration: 0.25)
        static let press = Animation.easeOut(duration: 0.15)
        /// Elegir una opción: un resorte corto, con un rebote apenas visible.
        static let select = Animation.spring(response: 0.35, dampingFraction: 0.7)
        /// Entre un elemento y el siguiente cuando entran en cascada (los mosaicos del pie).
        static let stagger: Double = 0.04
        /// Una hoja que cambia de alto: despacio y sin rebote.
        static let sheet = Animation.smooth(duration: 0.35)
        /// Lo que se deja a una hoja para terminar de cambiar de alto.
        static let sheetSettle: Double = 0.6
        /// Lo que se va: rápido y antes de que lo demás se acomode, para que nada
        /// se cruce con algo que todavía se está desvaneciendo.
        static let exit = Animation.easeOut(duration: exitDuration)
        static let exitDuration: Double = 0.12
        /// Lo que entra espera a que se abra su lugar, y queda quieto en `enterSettle`
        /// (lo que sigue, como la muestra de la hoja, empieza a moverse después).
        static let enterDelay: Double = 0.1
        static let enterSettle: Double = 0.55
        /// Barras de audio sonando: cada una a su ritmo según su alto.
        static func equalizer(_ height: Double) -> Animation {
            .easeInOut(duration: 0.45 + height * 0.2)
        }
    }
}

// MARK: Tipografía — New York para lo que es del libro, SF para la interfaz,
// Cinzel (mayúsculas romanas) solo para la marca y los rótulos de sección

extension Theme {
    /// Tamaños de letra con nombre (lo demás sigue los estilos de iOS).
    enum Letter {
        /// El título de pantalla con el tamaño de texto de siempre; crece con él (`.largeTitle`).
        static let screenTitle: CGFloat = 30
        /// El título de pantalla en una ventana baja: crece con el texto (`.title2`).
        static let screenTitleShort: CGFloat = 22
        /// Hasta dónde crece la letra dentro de una forma de medida fija (los dibujos de Ajustes,
        /// los círculos de 44 del lector): más grande ya no cabría en ella.
        static let fixedShapeLargest: DynamicTypeSize = .xxxLarge
        /// Los dibujos de Ajustes (`SettingsArt`) no crecen: son ilustraciones de medida fija
        /// y lo que dicen está también en sus filas y en lo que lee VoiceOver.
        static let drawingLargest: DynamicTypeSize = .large
        /// Hasta dónde crece la letra de lo que flota sobre el libro (la tarjeta de abajo, la barra
        /// de lo elegido, la tarjeta del subrayado) o queda fijo al pie de una lista (`BottomBar`):
        /// con AX5 la tarjeta tapaba casi media página y la barra de «Por revisar», media lista.
        static let readerChromeLargest: DynamicTypeSize = .accessibility1
    }
}

extension Font {
    /// Título de pantalla («Biblioteca», «Cuaderno»), al tamaño ya escalado (`ScreenTitle`).
    static func screenTitle(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .serif)
    }
    /// Título de un libro protagonista (Mesa, ficha). Los de abajo siguen el
    /// tamaño de texto de iOS (28, 17 y 16 pt con el tamaño de siempre).
    static let bookTitle = Font.system(.title, design: .serif, weight: .medium)
    /// Título en filas y citas.
    static let rowTitle = Font.system(.body, design: .serif)
    /// Citas y «Donde lo dejaste».
    static let quote = Font.system(.body, design: .serif).italic()
    /// Sinopsis y textos largos del libro.
    static let prose = Font.system(.callout, design: .serif)
    /// Un bloque de código de una nota: de ancho fijo y con sus renglones (auditoría 6).
    static let code = Font.system(.callout, design: .monospaced)
    /// «GABINETE» arriba de la Mesa, como una inscripción.
    static let brandMark = Font.custom("Cinzel", size: 16, relativeTo: .footnote)
    /// Rótulo de sección en mayúsculas romanas («EN LA MESA»).
    static let sectionLabel = Font.custom("Cinzel", size: 12, relativeTo: .caption).weight(.medium)
    /// La «G» de Gabinete al centro del dibujo de Conexiones: la marca, no un rótulo.
    static let hubLetter = Font.custom("Cinzel", size: Theme.Size.artHubLetter, relativeTo: .title3)
    /// Íconos de acción (encabezados, botones redondos, opciones).
    static let icon = Font.title3
    /// La «A» grande del tamaño de letra en «Aa».
    static let largeGlyph = Font.title2
    /// Íconos chicos sobre otra cosa (la nube de iCloud, la palomita, la flecha de un orden).
    /// Mide 11: nunca para texto (SB-3).
    static let badge = Font.caption2.weight(.semibold)
}

#if os(iOS)
extension UIFont {
    /// Los títulos grandes del sistema (Ajustes, formularios) iguales a `Font.screenTitle`,
    /// y que crecen con el tamaño de texto.
    static var screenTitle: UIFont {
        let base = UIFont.systemFont(ofSize: Theme.Letter.screenTitle, weight: .medium)
        let serif = base.fontDescriptor.withDesign(.serif).map { UIFont(descriptor: $0, size: Theme.Letter.screenTitle) } ?? base
        return UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: serif)
    }
}
#endif

extension Theme {
    /// Espaciado de letras de la marca y los rótulos romanos (proporción del tamaño).
    enum Tracking {
        static let brandMark: CGFloat = 6.7
        static let sectionLabel: CGFloat = 2.9
        /// Versalitas de texto (la fecha de la Mesa, «DONDE LO DEJASTE»).
        static let caps: CGFloat = 1.6
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    /// Color que cambia solo con el modo claro u oscuro.
    init(light: UInt32, dark: UInt32) {
        #if os(iOS)
        self.init(uiColor: UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
        #else
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(Color(hex: isDark ? dark : light))
        })
        #endif
    }
}

extension View {
    /// Botón redondo dentro del vidrio: ícono o «Aa» en un círculo apenas marcado, de 44 pt.
    func roundInGlass() -> some View {
        self.font(.body.weight(.semibold))
            // El círculo mide 44: con la letra más grande, «Aa» se volvía «…».
            .dynamicTypeSize(...Theme.Letter.fixedShapeLargest)
            .frame(width: Theme.Size.tapTarget, height: Theme.Size.tapTarget)
            .background(Theme.ink.opacity(Theme.Emphasis.inGlass), in: Circle())
            .contentShape(Circle())
    }

    /// Botón redondo de vidrio: Liquid Glass en iOS/macOS 26, material en versiones anteriores.
    @ViewBuilder
    func glassCircle() -> some View {
        dynamicTypeSize(...Theme.Letter.fixedShapeLargest).glassCircleSurface()
    }

    @ViewBuilder
    private func glassCircleSurface() -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, macOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: .circle)
        } else {
            self.background(.ultraThinMaterial, in: Circle())
        }
        #else
        self.background(.ultraThinMaterial, in: Circle())
        #endif
    }

    /// `clipped`: lo de adentro se recorta a la forma del vidrio (un panel que crece
    /// no deja ver su contenido nuevo fuera de él mientras se anima).
    @ViewBuilder
    func glassPanel(cornerRadius: CGFloat, clipped: Bool) -> some View {
        if clipped {
            clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)).glassPanel(cornerRadius: cornerRadius)
        } else {
            glassPanel(cornerRadius: cornerRadius)
        }
    }

    /// Superficie de vidrio con esquinas redondeadas para barras flotantes.
    @ViewBuilder
    func glassPanel(cornerRadius: CGFloat) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, macOS 26.0, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        #else
        self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        #endif
    }
}
