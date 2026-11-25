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
    static let brand = Color(light: 0x24332B, dark: 0x8FBFA4)
    /// Texto sobre la marca.
    static let onBrand = Color(light: 0xFFFFFF, dark: 0x141413)
    /// Texto secundario.
    static let secondaryInk = Color(light: 0x6F6C65, dark: 0x9C988F)
    /// Texto terciario: folios y etiquetas pequeñas.
    static let tertiaryInk = Color(light: 0x837F78, dark: 0x7C7870)
    /// Pistas de progreso y separadores.
    static let track = Color(light: 0xE6E3DC, dark: 0x34322E)
    /// Verde hoja: tus marcas y avisos (subrayados, notas, cinta, audio sonando,
    /// pendientes). Sutil y escaso.
    static let accent = Color(light: 0x3D6B55, dark: 0x8FBFA4)

    /// Etapas de una sesión de lectura: del gris (interrumpida) al verde fichero
    /// (inmersa). Se distinguen por claridad; en oscuro, la más intensa es la más clara.
    static func stage(_ stage: ReadingStage) -> Color {
        switch stage {
        case .interrupted: Color(light: 0xD9D6CF, dark: 0x4A4844)
        case .skimming: Color(light: 0xCFDDD4, dark: 0x3B5546)
        case .light: Color(light: 0x8FBFA4, dark: 0x5E8B73)
        case .active: Color(light: 0x3D6B55, dark: 0x8FBFA4)
        case .immersed: Color(light: 0x24332B, dark: 0xB9DCC6)
        }
    }

    // MARK: Espacio — escala de 4 pt

    enum Space {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
        // Medidas con nombre para lo que se repite fuera de la escala. Nunca se suman
        // tokens en una pantalla o pieza («s + xxs»): si hace falta otra medida, va aquí.
        /// Separación mínima: entre las letras del índice A–Z.
        static let hair: CGFloat = 1
        /// Entre un ícono y su texto, y dentro de piezas pequeñas (leyendas, barras).
        static let inline: CGFloat = 6
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
        /// Interior lateral de una fila de filtros que llega al borde: con el aire
        /// de cada filtro (`s`), su primer texto cae justo en el margen.
        static let chipInset: CGFloat = gutter - s
    }

    // MARK: Radio

    enum Radius {
        /// Esquinas de una portada.
        static let cover: CGFloat = 3
        /// Filtros y etiquetas.
        static let chip: CGFloat = 8
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
        /// Cápsula de controles de 44 pt de alto.
        static let capsule: CGFloat = 22
        /// Muestra de color de una leyenda.
        static let swatch: CGFloat = 2
    }

    // MARK: Tamaño

    enum Size {
        /// Área mínima de toque (HIG).
        static let tapTarget: CGFloat = 44
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
        /// Renglón fantasma de esa muestra.
        static let ghostLine: CGFloat = 3
        /// Perilla de la barra de avance del lector.
        static let scrubberKnob: CGFloat = 14
        /// Alto de la barra de avance: la perilla cómoda de arrastrar sin dejar un hueco.
        static let scrubberHeight: CGFloat = 32
        /// Lo que se mueve el dedo antes de saber si arrastra la barra (de lado) o sube el panel.
        static let dragSlop: CGFloat = 6
        /// Lo que hay que subir o bajar el dedo sobre el panel para abrirlo o cerrarlo.
        static let panelSwipe: CGFloat = 24
        /// Alto de una fila de la gráfica de etapas, y de su marca.
        static let stageRow: CGFloat = 26
        static let stageMark: CGFloat = 16
        /// Muestra de color en la leyenda de etapas.
        static let legendSwatch: CGFloat = 8
        /// La rayita del panel del lector que dice «se sube».
        static let grabber = CGSize(width: 36, height: 5)
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
        /// Folio sin controles: margen lateral del capítulo.
        static let folioInset: CGFloat = 60
        /// Pasar la hoja: la fuerza del resorte (`TurnMotion`) que la lleva hasta el
        /// final o de regreso; con 15, una vuelta desde quieta tarda unos 0,55 s y,
        /// al soltar, sigue con la velocidad del dedo (nunca más de `turnSpeedLimit`
        /// anchos por segundo). Se da por terminada a `turnRest` del final.
        static let turnSpring = 15.0
        static let turnSpeedLimit: CGFloat = 4
        static let turnRest: CGFloat = 0.004
        /// Con el dedo, la vuelta completa es lo que hay del toque a la orilla contraria,
        /// pero nunca menos de esta fracción del ancho (si tocas cerca del lomo).
        static let turnReach: CGFloat = 0.5
        /// La tarjeta de un subrayado muestra hasta estas líneas de la cita.
        static let highlightLines = 4
        /// Fundido: un resorte más suave que la hoja. Es un relevo: el texto de antes
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
        /// Las primeras veces que sale el panel se asoma hacia arriba: hay más.
        static let panelHints = 3
        static let panelHintDelay: TimeInterval = 0.45
        static let panelHintHold: TimeInterval = 0.3
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
        /// Aire arriba y abajo del texto en páginas: deja el capítulo y el pie
        /// sobre papel limpio. El capítulo y el pie van centrados en él y el texto
        /// respeta la orilla de abajo (antes 76, con mucho hueco arriba).
        static let pageMarginTop: CGFloat = 40
        /// Abajo más aire: el pie y el contador van ahí, sobre la orilla del iPhone.
        static let pageMarginBottom: CGFloat = 68
        /// En continuo, el papel es sólido hasta la orilla del folio y después se
        /// desvanece hacia el texto en este alto, con una
        /// curva de `folioFadeSteps` tramos (se aclara pronto: la letra se sigue viendo).
        static let folioFade: CGFloat = 56
        static let folioFadeSteps = 6
        /// En continuo, el alto del renglón del capítulo bajo la orilla segura (en
        /// páginas es `pageMarginTop`): más chico, el capítulo sube hacia la isla.
        static let folioTop: CGFloat = 18
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
        static let glassText = 0.72
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
        /// El pie de una muestra que aún no tiene dato: más apagado que el folio.
        static let folioMuted = 0.55
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
    /// Título de un libro protagonista (Mesa, ficha).
    static let bookTitle = Font.system(size: 28, weight: .medium, design: .serif)
    /// Título en filas y citas.
    static let rowTitle = Font.system(size: 17, design: .serif)
    /// Citas y «Donde lo dejaste».
    static let quote = Font.system(size: 17, design: .serif).italic()
    /// Sinopsis y textos largos del libro.
    static let prose = Font.system(size: 16, design: .serif)
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
