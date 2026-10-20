import SwiftUI

/// Tokens de la versión elegida (v7, «Nativo con oficio»).
/// Ver docs/diseno.md.
enum Theme {
    /// Fondo agrupado cálido (en lugar del gris frío del sistema).
    static let groupedBackground = Color(hex: 0xF2F1EE)
    /// Papel de la página de lectura.
    static let paper = Color(hex: 0xFBFAF7)
    /// Superficie de tarjetas y listas.
    static let surface = Color.white
    /// Tinta: texto principal y botones principales.
    static let ink = Color(hex: 0x1C1B19)
    /// Texto secundario.
    static let secondaryInk = Color(hex: 0x77746D)
    /// Pista de las barras de progreso.
    static let track = Color(hex: 0xE6E3DC)
    /// Lápiz rojo: reservado para tus marcas (subrayados, notas, cinta).
    static let pencil = Color(hex: 0xB8372A)

    static let cardRadius: CGFloat = 22
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
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
