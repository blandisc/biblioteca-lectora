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
    static let secondaryInk = Color(light: 0x77746D, dark: 0x9C988F)
    /// Texto terciario: folios y etiquetas pequeñas.
    static let tertiaryInk = Color(light: 0x9A968D, dark: 0x6F6C65)
    /// Pistas de progreso y separadores.
    static let track = Color(light: 0xE6E3DC, dark: 0x34322E)
    /// Verde hoja: tus marcas y avisos (subrayados, notas, cinta, audio sonando,
    /// pendientes). Sutil y escaso.
    static let accent = Color(light: 0x3D6B55, dark: 0x8FBFA4)

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
        /// Filtros y etiquetas.
        static let chip: CGFloat = 8
        /// Botones y campos.
        static let control: CGFloat = 10
        /// Tarjetas pequeñas (opciones de la hoja «Aa»).
        static let tile: CGFloat = 14
        /// Paneles de vidrio del lector.
        static let panel: CGFloat = 28
        /// Cápsula de controles de 44 pt de alto.
        static let capsule: CGFloat = 22
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
        /// Alto de la hoja «Aa».
        static let appearanceSheet: CGFloat = 440
    }

    // MARK: Lector

    enum Reader {
        /// Toques en la página: izquierda (atrás) y derecha (adelante) son
        /// franjas iguales; el centro muestra los controles.
        static let edgeZone = 0.28
        /// Margen de los controles de vidrio, igual arriba y abajo, izquierda y derecha.
        static let chromeInset: CGFloat = 16
    }

    // MARK: Énfasis

    enum Emphasis {
        /// Lo que no se puede tocar mientras otra cosa está en curso.
        static let dimmed = 0.4
        static let full = 1.0
    }

    // MARK: Movimiento

    enum Motion {
        static let standard = Animation.snappy(duration: 0.25)
        static let press = Animation.easeOut(duration: 0.15)
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
