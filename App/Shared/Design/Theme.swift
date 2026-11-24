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
        /// Folio sin controles: margen lateral del capítulo.
        static let folioInset: CGFloat = 60
        /// Pasar la hoja: lo que tarda una vuelta completa (segundos); si ya va a
        /// medias, solo lo que falta. Nunca menos de `turnMinimum`.
        static let turnDuration: TimeInterval = 0.42
        /// La tarjeta de un subrayado muestra hasta estas líneas de la cita.
        static let highlightLines = 4
        static let turnMinimum: TimeInterval = 0.14
        /// Fundido: un poco más lento que la hoja, y el texto se corre estos puntos.
        static let fadeDuration: TimeInterval = 0.5
        static let fadeDrift: CGFloat = 14
        /// La hoja de muestra en «Aa»: pausa entre vueltas (s), cuánto se desliza (fracción de su ancho) y sus renglones.
        static let previewPause: TimeInterval = 0.7
        static let previewReturn: TimeInterval = 0.35
        static let previewSlide: CGFloat = 1.2
        static let previewLines = 5
        static let previewLastLine = 4
        /// El revés doblado de la hoja de muestra (fracción de lo que ya pasó) y su sombra.
        static let previewFold: CGFloat = 0.5
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
        static let curlShadow: Float = 0.55
        static let curlShowThrough: CGFloat = 0.05
        /// Resolución del dibujo de la hoja mientras se dobla (2×: fluido y nítido).
        static let curlScale: CGFloat = 2
        /// Deslizar: la sombra de la hoja que se mueve.
        static let slideShadow: Float = 0.18
        static let slideShadowRadius: CGFloat = 14
        /// El revés de la hoja que se dobla: el mismo papel con esta fracción de su
        /// luz (más oscuro, como papel a contraluz; UIKit le suma su propio brillo).
        static let pageBack: CGFloat = 0.82
        /// La vibración al pasar a la página siguiente: muy ligera (0 a 1).
        static let turnHaptic: CGFloat = 0.45
        /// Aire arriba y abajo del texto en páginas: deja el capítulo y el pie
        /// sobre papel limpio. El capítulo y el pie van centrados en él y el texto
        /// respeta la orilla de abajo (antes 76, con mucho hueco arriba).
        static let pageMarginTop: CGFloat = 40
        /// Abajo más aire: el pie y el contador van ahí, sobre la orilla del iPhone.
        static let pageMarginBottom: CGFloat = 68
        /// En continuo, el papel bajo el folio se desvanece en este alto.
        static let folioFade: CGFloat = 24
        /// Cuánto sobresale la franja de papel del folio hacia el texto (en continuo):
        /// la parte sólida es lo que sobra después del desvanecido.
        static let folioBand: CGFloat = 40
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
        /// Al tocar: se hunde un poco y se apaga apenas, sin cambiar de color.
        static let pressedScale = 0.97
        /// En reposo: tamaño y opacidad completos.
        static let rest = 1.0
        static let pressed = 0.85
        /// Folio del lector (capítulo y porcentaje): el color del texto del libro,
        /// un poco apagado, para que se lea sobre cualquier fondo sin competir.
        static let folio = 0.74
        /// Franja de papel detrás de los botones de arriba del lector: casi
        /// opaca, para que el texto se adivine detrás.
        static let chromeBand = 0.82
        /// Una etiqueta corta se achica hasta este tamaño antes de cortarse.
        static let labelMinScale: CGFloat = 0.8
    }

    // MARK: Movimiento

    enum Motion {
        static let standard = Animation.snappy(duration: 0.25)
        static let press = Animation.easeOut(duration: 0.15)
        /// Una hoja que cambia de alto: despacio y sin rebote.
        static let sheet = Animation.smooth(duration: 0.35)
        /// La hoja de muestra de «Aa»: una vuelta, o un cambio en seco.
        static let pageTurn = Animation.easeInOut(duration: Reader.turnDuration)
        static let instant = Animation.linear(duration: 0)
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
