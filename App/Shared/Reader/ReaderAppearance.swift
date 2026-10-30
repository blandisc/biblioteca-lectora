import SwiftUI

/// Preferencias de lectura de la hoja «Aa».
enum ReaderKeys {
    static let font = "reader.font"
    static let scale = "reader.scale"
    static let theme = "reader.theme"
    static let autoNight = "reader.autoNight"
}

/// Pocas tipografías y buenas, todas incluidas en iOS y macOS.
enum ReaderFont: String, CaseIterable, Identifiable {
    case newYork, charter, iowan, sans
    var id: Self { self }

    var name: String {
        switch self {
        case .newYork: "New York"
        case .charter: "Charter"
        case .iowan: "Iowan"
        case .sans: "San Francisco"
        }
    }

    var detail: String {
        switch self {
        case .newYork: "La serif de Apple"
        case .charter: "Clásica y compacta"
        case .iowan: "Cálida, de libro"
        case .sans: "Sin serifas, muy legible"
        }
    }

    /// Pila de fuentes CSS para el WebView.
    var css: String {
        switch self {
        case .newYork: "ui-serif, 'New York', Georgia, serif"
        case .charter: "Charter, 'Bitstream Charter', Georgia, serif"
        case .iowan: "'Iowan Old Style', Georgia, serif"
        case .sans: "-apple-system, system-ui, sans-serif"
        }
    }

    func preview(size: CGFloat) -> Font {
        switch self {
        case .newYork: .system(size: size, design: .serif)
        case .charter: .custom("Charter", size: size)
        case .iowan: .custom("Iowan Old Style", size: size)
        case .sans: .system(size: size)
        }
    }
}

/// Fondo de la página. «Auto» sigue el modo claro u oscuro de la app.
enum ReaderTheme: String, CaseIterable, Identifiable {
    case auto, paper, white, night, black
    var id: Self { self }

    var title: String {
        switch self {
        case .auto: "Auto"
        case .paper: "Papel"
        case .white: "Blanco"
        case .night: "Noche cálida"
        case .black: "Negro"
        }
    }
}

/// Colores resueltos de la página para un tema.
struct ReaderPalette: Equatable {
    var background: Color
    var text: String
    var link: String
    /// Modo de la interfaz sobre la página; `nil` deja el de la app.
    var scheme: ColorScheme?

    static let paper = ReaderPalette(background: Color(hex: 0xF8F7F4), text: "#1C1B19", link: "#3D6B55", scheme: .light)
    static let white = ReaderPalette(background: Color(hex: 0xFFFFFF), text: "#1C1B19", link: "#3D6B55", scheme: .light)
    static let darkPaper = ReaderPalette(background: Color(hex: 0x161514), text: "#DAD6CE", link: "#8FBFA4", scheme: .dark)
    static let night = ReaderPalette(background: Color(hex: 0x2B2420), text: "#E8D9C4", link: "#8FBFA4", scheme: .dark)
    static let black = ReaderPalette(background: Color(hex: 0x000000), text: "#BDB8AE", link: "#8FBFA4", scheme: .dark)

    static func resolve(_ theme: ReaderTheme, autoNight: Bool, appIsDark: Bool, now: Date = Date()) -> ReaderPalette {
        switch theme {
        case .paper: return .paper
        case .white: return .white
        case .night: return .night
        case .black: return .black
        case .auto:
            let hour = Calendar.current.component(.hour, from: now)
            if autoNight && (hour >= 20 || hour < 7) { return .night }
            var palette = appIsDark ? ReaderPalette.darkPaper : .paper
            palette.scheme = nil
            return palette
        }
    }
}

/// Hoja «Aa»: tipografía, tamaño, fondo y noche cálida automática.
struct ReaderAppearanceSheet: View {
    @AppStorage(ReaderKeys.font) private var font: ReaderFont = .newYork
    @AppStorage(ReaderKeys.scale) private var scale = 1.0
    @AppStorage(ReaderKeys.theme) private var theme: ReaderTheme = .auto
    @AppStorage(ReaderKeys.autoNight) private var autoNight = true

    private let columns = [GridItem(.flexible(), spacing: Theme.Space.s), GridItem(.flexible(), spacing: Theme.Space.s)]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l + Theme.Space.xxs) {
            LazyVGrid(columns: columns, spacing: Theme.Space.s) {
                ForEach(ReaderFont.allCases) { item in
                    Button { font = item } label: {
                        VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                            Text("Aa").font(item.preview(size: Theme.Space.xl))
                            Text(item.name).font(.subheadline.weight(.medium))
                            Text(item.detail).font(.caption).foregroundStyle(Theme.secondaryInk)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Theme.Space.m)
                        .background(Theme.field, in: RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous)
                                .strokeBorder(item == font ? Theme.ink : .clear, lineWidth: Theme.Size.quoteRule)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(item == font ? .isSelected : [])
                }
            }

            HStack(spacing: Theme.Space.m) {
                Button { scale = max(0.8, scale - 0.05) } label: { Text("A").font(.footnote) }
                    .accessibilityLabel("Letra más chica")
                Slider(value: $scale, in: 0.8...1.6, step: 0.05)
                    .accessibilityLabel("Tamaño de letra")
                Button { scale = min(1.6, scale + 0.05) } label: { Text("A").font(.title2) }
                    .accessibilityLabel("Letra más grande")
            }
            .buttonStyle(.plain)

            HStack {
                ForEach(ReaderTheme.allCases) { item in
                    Button { theme = item } label: {
                        VStack(spacing: Theme.Space.xs + Theme.Space.xxs) {
                            swatch(for: item)
                                .frame(width: Theme.Size.tapTarget, height: Theme.Size.tapTarget)
                                .overlay {
                                    Circle().strokeBorder(item == theme ? Theme.ink : Theme.track,
                                                          lineWidth: item == theme ? Theme.Size.quoteRule : Theme.Size.hairline)
                                }
                            Text(item.title)
                                .font(.caption)
                                .foregroundStyle(item == theme ? Theme.ink : Theme.secondaryInk)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(item == theme ? .isSelected : [])
                }
            }

            Toggle("Noche cálida al atardecer", isOn: $autoNight)
                .disabled(theme != .auto)
        }
        .foregroundStyle(Theme.ink)
        .padding(Theme.Space.xl)
    }

    @ViewBuilder
    private func swatch(for item: ReaderTheme) -> some View {
        switch item {
        case .auto:
            Circle().fill(LinearGradient(colors: [Color(hex: 0xF8F7F4), Color(hex: 0x161514)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay { Text("A").font(.rowTitle.weight(.medium)).foregroundStyle(Theme.secondaryInk) }
        default:
            let palette = ReaderPalette.resolve(item, autoNight: false, appIsDark: false)
            Circle().fill(palette.background)
                .overlay {
                    Text("Aa").font(.rowTitle.weight(.medium))
                        .foregroundStyle(Color(hex: UInt32(palette.text.dropFirst(), radix: 16) ?? 0x1C1B19))
                }
        }
    }
}
