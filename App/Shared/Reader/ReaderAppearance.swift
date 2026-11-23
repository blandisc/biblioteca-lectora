import SwiftUI

/// Preferencias de lectura de la hoja «Aa».
enum ReaderKeys {
    static let font = "reader.font"
    static let scale = "reader.scale"
    static let theme = "reader.theme"
    static let autoNight = "reader.autoNight"
    static let flow = "reader.flow"
    /// Qué dice el pie de la página (tocándolo se elige).
    static let footer = "reader.footer"
    /// Una vibración muy ligera al pasar a la página siguiente.
    static let haptics = "reader.haptics"
}

/// Lo que dice abajo, en el pie de la página, mientras lees.
enum ReaderFooter: String, CaseIterable, Identifiable {
    case chapterTime, bookTime, page, percent
    var id: Self { self }

    /// Cómo se llama en el menú del pie.
    var name: String {
        switch self {
        case .chapterTime: "Tiempo del capítulo"
        case .bookTime: "Tiempo del libro"
        case .page: "Página"
        case .percent: "Porcentaje"
        }
    }
}

/// Cómo se avanza en el libro: de página en página (deslizando de lado) o
/// continuo, hacia abajo y sin cortes, de un capítulo al siguiente.
enum ReaderFlow: String, CaseIterable, Identifiable {
    case paged, scrolled
    var id: Self { self }

    var name: String {
        switch self {
        case .paged: "Páginas"
        case .scrolled: "Continuo"
        }
    }

    var detail: String {
        switch self {
        case .paged: "Deslizas de lado"
        case .scrolled: "Bajas sin cortes"
        }
    }

    var symbol: String {
        switch self {
        case .paged: "book.pages"
        case .scrolled: "scroll"
        }
    }

    /// Leer el modo fuera de una vista (los toques en la página).
    static var current: ReaderFlow {
        UserDefaults.standard.string(forKey: ReaderKeys.flow).flatMap(ReaderFlow.init) ?? .paged
    }
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
        case .newYork: .system(size: size, design: .serif) // ds-exception: fuente del lector
        case .charter: .custom("Charter", size: size) // ds-exception: fuente del lector
        case .iowan: .custom("Iowan Old Style", size: size) // ds-exception: fuente del lector
        case .sans: .system(size: size) // ds-exception: fuente del lector
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

    /// El color del texto para pintarlo en la app (muestras de «Aa»).
    var textColor: Color { Color(hex: UInt32(text.dropFirst(), radix: 16) ?? 0) } // ds-exception: paleta del lector

    static let paper = ReaderPalette(background: Color(hex: 0xF8F7F4), text: "#1C1B19", link: "#3D6B55", scheme: .light) // ds-exception: paleta del lector
    static let white = ReaderPalette(background: Color(hex: 0xFFFFFF), text: "#1C1B19", link: "#3D6B55", scheme: .light) // ds-exception: paleta del lector
    static let darkPaper = ReaderPalette(background: Color(hex: 0x161514), text: "#DAD6CE", link: "#8FBFA4", scheme: .dark) // ds-exception: paleta del lector
    static let night = ReaderPalette(background: Color(hex: 0x2B2420), text: "#E8D9C4", link: "#8FBFA4", scheme: .dark) // ds-exception: paleta del lector
    static let black = ReaderPalette(background: Color(hex: 0x000000), text: "#BDB8AE", link: "#8FBFA4", scheme: .dark) // ds-exception: paleta del lector

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

/// Hoja «Aa»: tipografía, páginas o continuo, tamaño, fondo y noche cálida automática.
struct ReaderAppearanceSheet: View {
    @AppStorage(ReaderKeys.font) private var font: ReaderFont = .newYork
    @AppStorage(ReaderKeys.scale) private var scale = 1.0
    @AppStorage(ReaderKeys.theme) private var theme: ReaderTheme = .auto
    @AppStorage(ReaderKeys.autoNight) private var autoNight = true
    @AppStorage(ReaderKeys.flow) private var flow: ReaderFlow = .paged
    @AppStorage(ReaderKeys.haptics) private var haptics = true
    /// El modo de la app: con «Automático», el tema sigue al claro u oscuro de iOS.
    @Environment(\.colorScheme) private var appScheme

    private let columns = [GridItem(.flexible(), spacing: Theme.Space.s), GridItem(.flexible(), spacing: Theme.Space.s)]

    private var palette: ReaderPalette {
        ReaderPalette.resolve(theme, autoNight: autoNight, appIsDark: appScheme == .dark)
    }

    var body: some View {
        content
            // Toda la hoja toma el tema que eliges: papel, tinta y mosaicos.
            .environment(\.colorScheme, palette.scheme ?? appScheme)
            .presentationBackground(palette.background)
            .animation(Theme.Motion.standard, value: theme)
            .animation(Theme.Motion.standard, value: font)
            .sensoryFeedback(.selection, trigger: scale)
            .sensoryFeedback(.selection, trigger: theme)
            .sensoryFeedback(.selection, trigger: font)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            ReaderSample(font: font, scale: scale, palette: palette)

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

            HStack(spacing: Theme.Space.s) {
                ForEach(ReaderFlow.allCases) { item in
                    Button { flow = item } label: {
                        HStack(spacing: Theme.Space.s) {
                            Image(systemName: item.symbol).font(.body)
                            VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                                Text(item.name).font(.subheadline.weight(.medium))
                                Text(item.detail).font(.caption).foregroundStyle(Theme.secondaryInk)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Theme.Space.m)
                        .background(Theme.field, in: RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous)
                                .strokeBorder(item == flow ? Theme.ink : .clear, lineWidth: Theme.Size.quoteRule)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(item == flow ? .isSelected : [])
                }
            }

            HStack(spacing: Theme.Space.m) {
                Button { scale = max(Self.scales.lowerBound, scale - Self.scaleStep) } label: { Text("A").font(.footnote) }
                    .accessibilityLabel("Letra más chica")
                sizeSlider
                    .accessibilityLabel("Tamaño de letra")
                Button { scale = min(Self.scales.upperBound, scale + Self.scaleStep) } label: { Text("A").font(.title2) }
                    .accessibilityLabel("Letra más grande")
            }
            .buttonStyle(.plain)

            HStack {
                ForEach(ReaderTheme.allCases) { item in
                    Button { theme = item } label: {
                        VStack(spacing: Theme.Space.inline) {
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
                                .minimumScaleFactor(Theme.Emphasis.labelMinScale)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(item == theme ? .isSelected : [])
                }
            }

            Toggle("Noche cálida al atardecer", isOn: $autoNight)
                .disabled(theme != .auto)
            #if os(iOS)
            Toggle("Vibrar al pasar de página", isOn: $haptics)
            #endif
        }
        .foregroundStyle(Theme.ink)
        .padding(Theme.Space.xl)
    }

    /// Los tamaños de letra: nueve niveles, cada uno con su marca en la barra.
    private static let scales = 0.8...1.6
    private static let scaleStep = 0.1

    /// La barra del tamaño, con una marca por nivel (iOS 26 las dibuja en la
    /// raya; antes, la barra sola).
    @ViewBuilder
    private var sizeSlider: some View {
        if #available(iOS 26, macOS 26, *) {
            Slider(value: $scale, in: Self.scales, step: Self.scaleStep) {
                Text("Tamaño de letra")
            } tick: { value in
                SliderTick(value)
            }
        } else {
            Slider(value: $scale, in: Self.scales, step: Self.scaleStep)
        }
    }

    @ViewBuilder
    private func swatch(for item: ReaderTheme) -> some View {
        switch item {
        case .auto:
            Circle().fill(LinearGradient(colors: [ReaderPalette.paper.background, ReaderPalette.darkPaper.background],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay { Text("A").font(.rowTitle.weight(.medium)).foregroundStyle(Theme.secondaryInk) }
        default:
            let palette = ReaderPalette.resolve(item, autoNight: false, appIsDark: false)
            Circle().fill(palette.background)
                .overlay {
                    Text("Aa").font(.rowTitle.weight(.medium))
                        .foregroundStyle(palette.textColor)
                }
        }
    }
}

/// Un párrafo de muestra arriba de los ajustes: cambia en vivo con la letra,
/// el tamaño y el tema, como se verá en el libro.
private struct ReaderSample: View {
    let font: ReaderFont
    let scale: Double
    let palette: ReaderPalette

    var body: some View {
        Text("En un lugar de la Mancha, de cuyo nombre no quiero acordarme, no ha mucho tiempo que vivía un hidalgo de los de lanza en astillero, adarga antigua, rocín flaco y galgo corredor.")
            .font(font.preview(size: Theme.Reader.sampleSize * scale))
            .lineSpacing(Theme.Reader.sampleLeading)
            .foregroundStyle(palette.textColor)
            // El párrafo sigue de largo y se desvanece abajo, sin «…».
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Space.l)
            .frame(height: Theme.Reader.sampleHeight, alignment: .top)
            .clipped()
            .mask {
                LinearGradient(stops: [.init(color: .black, location: 0),
                                       .init(color: .black, location: Theme.Reader.sampleFadeStart),
                                       .init(color: .clear, location: 1)],
                               startPoint: .top, endPoint: .bottom)
            }
            .background(palette.background, in: RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous)
                    .strokeBorder(Theme.track, lineWidth: Theme.Size.hairline)
            }
            .accessibilityLabel("Muestra del texto")
    }
}
