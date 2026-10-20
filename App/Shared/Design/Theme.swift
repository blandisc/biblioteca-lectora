import SwiftUI

/// Tokens de color. Cada uno tiene versión clara y oscura. Ver docs/diseno.md.
enum Theme {
    // MARK: Compartidos por los dos estilos

    /// Tinta: texto principal, botón principal y barras de progreso.
    static let ink = Color(light: 0x1C1B19, dark: 0xECE9E2)
    /// Texto sobre un fondo de tinta (botón principal).
    static let onInk = Color(light: 0xFFFFFF, dark: 0x141413)
    /// Texto secundario.
    static let secondaryInk = Color(light: 0x77746D, dark: 0x9C988F)
    /// Texto terciario (folios, etiquetas pequeñas).
    static let tertiaryInk = Color(light: 0x9A968D, dark: 0x6F6C65)
    /// Pista de las barras de progreso y separadores.
    static let track = Color(light: 0xE6E3DC, dark: 0x34322E)
    /// Lápiz rojo: reservado para tus marcas (subrayados, notas, cinta).
    static let pencil = Color(light: 0xB8372A, dark: 0xE0675A)

    // MARK: Nativo (v7)

    /// Fondo agrupado cálido (en lugar del gris frío del sistema).
    static let groupedBackground = Color(light: 0xF2F1EE, dark: 0x121211)
    /// Superficie de tarjetas y listas.
    static let surface = Color(light: 0xFFFFFF, dark: 0x1E1D1B)
    /// Papel de la página de lectura.
    static let paper = Color(light: 0xFBFAF7, dark: 0x171615)

    static let cardRadius: CGFloat = 22

    // MARK: Editorial (v5)

    enum Editorial {
        /// Un solo papel para todo: biblioteca, inicio y lector.
        static let paper = Color(light: 0xF8F7F4, dark: 0x161514)
        /// Campos (búsqueda, notas).
        static let field = Color(light: 0xEFEDE8, dark: 0x242320)
        static let buttonRadius: CGFloat = 10
    }

    /// Colores del texto del libro para el WebView (CSS).
    static func readerCSS(dark: Bool) -> (text: String, link: String) {
        dark ? ("#DAD6CE", "#E0675A") : ("#1C1B19", "#B8372A")
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

extension Font {
    /// Títulos en New York, la serif del sistema.
    static func serifTitle(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
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
