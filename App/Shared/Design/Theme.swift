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
    /// Marca: verde fichero (en oscuro, verde claro). Acción principal, avance
    /// y pestaña elegida; el gabinete del ícono hecho color.
    static let brand = Color(light: 0x24332B, dark: Green.dark)
    /// Texto sobre la marca.
    static let onBrand = Color(light: 0xFFFFFF, dark: 0x141413)
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

    /// El verde de Gabinete, escrito una sola vez (26 nov 2026). De aquí salen `accent`,
    /// `highlight`, las etapas de lectura y el color de los subrayados en el libro. Ningún
    /// otro archivo escribe un verde (`testOneGreenForEverything`).
    enum Green {
        static let light: UInt32 = 0x0F4A35
        static let dark: UInt32 = 0x4FB386
        /// El mismo verde como color CSS, para lo que se dibuja dentro del libro.
        static func css(dark: Bool) -> String {
            String(format: "#%06X", dark ? Green.dark : Green.light)
        }
    }
    /// Acción principal («Seguir leyendo», «Nota nueva»): verde fichero en los dos modos,
    /// con letra clara. En oscuro antes era un bloque verde menta que gritaba (SD-1).
    static let action = Color(light: 0x24332B, dark: 0x24332B)
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

    // MARK: Espacio — la escala común de interoperabilidad (SB-2): 4 · 8 · 16 · 24 · 32 · 48.
    // Sin 12 ni 6 desde el 26 nov 2026 (SD-2): el trinquete de Gabinete quedó en cero.

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
        static let rowY: CGFloat = 10
        /// Entre la portada (o la raya de una cita) y su texto.
        static let rowGap: CGFloat = 14
        /// Interior horizontal de un botón principal.
        static let buttonX: CGFloat = 20
        /// Margen lateral de toda pantalla. Igual a la izquierda y a la derecha.
        static let gutter: CGFloat = 28
        /// Del área segura superior al título de la pantalla.
        static let screenTop: CGFloat = 24
        /// Aire al final del contenido, antes del dock.
        static let screenBottom: CGFloat = 32
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
        static let coverDetail: CGFloat = 168
        static let coverRow: CGFloat = 40
        static let coverMini: CGFloat = 26
        static let coverEditor: CGFloat = 84
        /// Alto mínimo de un campo de texto largo (sinopsis).
        static let textEditor: CGFloat = 120
        /// Ancho del índice A–Z.
        static let letterIndex: CGFloat = 18
        /// Columnas de la cuadrícula de portadas.
        static let gridColumns = 3
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
        static let stageMark: CGFloat = 16
        /// Muestra de color en la leyenda de etapas.
        static let legendSwatch: CGFloat = 8
        /// Separación entre las etapas de la barra.
        static let stageGap: CGFloat = 1
        /// Botón de reproducir del mini reproductor, con su anillo de avance.
        static let playRing: CGFloat = 38
        /// Barras del ecualizador (audio sonando).
        static let equalizerBar: CGFloat = 2
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
        /// Lomo: sombra del borde izquierdo, nunca menor que `spineMin` puntos.
        static let spine: CGFloat = 0.05
        static let spineMin: CGFloat = 3
        static let spineShade = 0.28
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
    }

    // MARK: Lector

    enum Reader {
        /// Toques en la página: izquierda (atrás) y derecha (adelante) son
        /// franjas iguales; el centro muestra los controles.
        static let edgeZone = 0.28
        /// Margen de los controles de vidrio, igual arriba y abajo, izquierda y derecha.
        static let chromeInset: CGFloat = 16
        /// Los botones de arriba suben esto hacia la isla, sin tocarla.
        static let chromeLift: CGFloat = 8
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
        static let textMargin: CGFloat = 28
        /// Lo de adentro de la tarjeta de abajo, a esto del vidrio: así su contenido empieza
        /// en la misma línea que el texto del libro.
        static let panelInset: CGFloat = textMargin - chromeInset
        /// El texto normal de iOS con el tamaño de siempre: lo que crezca sobre esto
        /// (Ajustes › Pantalla › Tamaño del texto) crece también la letra del libro.
        static let textBase: CGFloat = 17
        /// Al abrir, el libro se da por acomodado cuando lleva esto sin cambiar de página.
        static let openSettle: TimeInterval = 0.25
        /// La tarjeta de un subrayado muestra hasta estas líneas de la cita.
        static let highlightLines = 4
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
        static let fadeDrift: CGFloat = 12
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
        /// Aire arriba del texto en páginas, bajo la orilla segura: arriba ya no va el
        /// capítulo, así que el texto empieza justo debajo de la isla (antes 40).
        static let pageMarginTop: CGFloat = 12
        /// Abajo más aire: el pie y el contador van ahí, sobre la orilla del iPhone.
        static let pageMarginBottom: CGFloat = 68
        /// En continuo, el papel es sólido hasta la orilla del folio y después se
        /// desvanece hacia el texto en este alto, con una
        /// curva de `folioFadeSteps` tramos (se aclara pronto: la letra se sigue viendo).
        static let folioFade: CGFloat = 56
        static let folioFadeSteps = 6
        /// En continuo, cuánto más abajo empieza el desvanecido del pie: el papel sólido
        /// llega justo arriba del pie y deja más texto a la vista (25 nov 2026).
        static let folioFadeDrop: CGFloat = 20
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
        static let slitContext = 4
        /// Lo que hay que deslizar el dedo para regresar o adelantar un pedazo.
        static let slitSwipe: CGFloat = 24
        /// El lomo del libro: sombra en la orilla izquierda de la hoja, su ancho y
        /// qué tan oscura empieza en papel claro y en papel oscuro.
        static let spineWidth: CGFloat = 26
        static let spineShadeLight: CGFloat = 0.07
        static let spineShadeDark: CGFloat = 0.3
    }

    // MARK: Énfasis

    enum Emphasis {
        /// Texto secundario sobre la marca (tarjeta para compartir).
        static let secondary = 0.75
        /// Texto callado sobre el vidrio del lector: el gris fijo se pierde ahí.
        static let glassText = 0.8
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

extension Font {
    /// Título de pantalla («Biblioteca», «Cuaderno»).
    static let screenTitle = Font.system(size: 30, weight: .medium, design: .serif)
    /// Título de un libro protagonista (Mesa, ficha). Los de abajo siguen el
    /// tamaño de texto de iOS (28, 17 y 16 pt con el tamaño de siempre).
    static let bookTitle = Font.system(.title, design: .serif, weight: .medium)
    /// Título en filas y citas.
    static let rowTitle = Font.system(.body, design: .serif)
    /// Citas y «Donde lo dejaste».
    static let quote = Font.system(.body, design: .serif).italic()
    /// Sinopsis y textos largos del libro.
    static let prose = Font.system(.callout, design: .serif)
    /// «GABINETE» arriba de la Mesa, como una inscripción.
    static let brandMark = Font.custom("Cinzel", size: 16, relativeTo: .footnote)
    /// Rótulo de sección en mayúsculas romanas («EN LA MESA»).
    static let sectionLabel = Font.custom("Cinzel", size: 12, relativeTo: .caption).weight(.medium)
}

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
            .frame(width: Theme.Size.tapTarget, height: Theme.Size.tapTarget)
            .background(Theme.ink.opacity(Theme.Emphasis.inGlass), in: Circle())
            .contentShape(Circle())
    }

    /// Botón redondo de vidrio: Liquid Glass en iOS/macOS 26, material en versiones anteriores.
    @ViewBuilder
    func glassCircle() -> some View {
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
