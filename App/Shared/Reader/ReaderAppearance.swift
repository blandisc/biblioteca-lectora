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
    /// Cómo se pasa la hoja en páginas.
    static let turn = "reader.turn"
    /// La hendidura: por frase o palabra por palabra, y a cuántas palabras por minuto.
    static let slitUnit = "reader.slitUnit"
    static let slitPace = "reader.slitPace"
}

/// Cómo se pasa la hoja en páginas (se elige en «Aa»).
enum ReaderTurnStyle: String, CaseIterable, Identifiable {
    /// La hoja se dobla con el dedo, papel mate, sin brillo.
    case matte
    /// La hoja se desliza de lado, como papel sobre la mesa.
    case slide
    /// El texto se desvanece y aparece el de la página nueva.
    case fade
    /// Cambia al instante.
    case none
    var id: Self { self }

    var name: String {
        switch self {
        case .matte: "Hoja"
        case .slide: "Deslizar"
        case .fade: "Fundido"
        case .none: "Sin animación"
        }
    }

    var symbol: String {
        switch self {
        case .matte: "book.pages"
        case .slide: "rectangle.portrait.on.rectangle.portrait"
        case .fade: "circle.lefthalf.filled"
        case .none: "bolt"
        }
    }
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

    /// Nombre corto para el mosaico.
    var short: String {
        switch self {
        case .sans: "SF"
        default: name
        }
    }

    var detail: String {
        switch self {
        case .newYork: "La serif de Apple"
        case .charter: "Clásica y compacta"
        case .iowan: "Cálida, de libro"
        case .sans: "Sin serifas, nítida"
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

    /// La muestra «Aa» de cada letra, del mismo tamaño en las cuatro: `fixedSize` porque una
    /// fuente propia con `size:` crece con la letra de iOS y la del sistema no.
    func preview(size: CGFloat) -> Font {
        switch self {
        case .newYork: .system(size: size, design: .serif) // ds-exception: fuente del lector
        case .charter: .custom("Charter", fixedSize: size) // ds-exception: fuente del lector
        case .iowan: .custom("Iowan Old Style", fixedSize: size) // ds-exception: fuente del lector
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
    /// Modo de la interfaz sobre la página (los botones y las hojas del lector).
    var scheme: ColorScheme

    /// El color del texto para pintarlo en la app (muestras de «Aa»).
    var textColor: Color { Color(hex: UInt32(text.dropFirst(), radix: 16) ?? 0) } // ds-exception: paleta del lector

    static let paper = ReaderPalette(background: Color(hex: 0xF8F7F4), text: "#1C1B19", link: Theme.Green.css(dark: false), scheme: .light) // ds-exception: paleta del lector
    static let white = ReaderPalette(background: Color(hex: 0xFFFFFF), text: "#1C1B19", link: Theme.Green.css(dark: false), scheme: .light) // ds-exception: paleta del lector
    static let darkPaper = ReaderPalette(background: Color(hex: 0x161514), text: "#DAD6CE", link: Theme.Green.css(dark: true), scheme: .dark) // ds-exception: paleta del lector
    static let night = ReaderPalette(background: Color(hex: 0x2B2420), text: "#E8D9C4", link: Theme.Green.css(dark: true), scheme: .dark) // ds-exception: paleta del lector
    static let black = ReaderPalette(background: Color(hex: 0x000000), text: "#BDB8AE", link: Theme.Green.css(dark: true), scheme: .dark) // ds-exception: paleta del lector

    /// `appIsDark` es el modo que manda (`SystemAppearance.isDark(mode:)`). Los fondos de día
    /// (Papel y Blanco) siguen al modo oscuro con su par de noche, como en Libros de Apple:
    /// antes, con «Papel» elegido, el libro se quedaba en claro con iOS en oscuro (UX-1b).
    /// Noche cálida y Negro son de noche siempre.
    static func resolve(_ theme: ReaderTheme, autoNight: Bool, appIsDark: Bool, now: Date = Date()) -> ReaderPalette {
        switch theme {
        case .paper: return appIsDark ? .darkPaper : .paper
        case .white: return appIsDark ? .black : .white
        case .night: return .night
        case .black: return .black
        case .auto:
            let hour = Calendar.current.component(.hour, from: now)
            if autoNight && (hour >= 20 || hour < 7) { return .night }
            return appIsDark ? .darkPaper : .paper
        }
    }
}

/// El claro u oscuro que manda en el lector: el de Ajustes › Apariencia o, con «Sistema», el
/// de iOS (o de la Mac). Se lee de la escena o del sistema y no de la vista: el lector le pone su
/// modo a su pantalla y, leído de ahí, se quedaba pegado en claro aunque iOS pasara a oscuro (UX-1b).
@MainActor
final class SystemAppearance: ObservableObject {
    static let shared = SystemAppearance()
    @Published private(set) var isSystemDark = false
    #if os(iOS)
    private var registration: (any UITraitChangeRegistration)?
    #else
    private var observer: NSObjectProtocol?
    #endif

    private init() {}

    /// Oscuro según lo que elegiste en Apariencia.
    func isDark(mode: AppearanceMode) -> Bool {
        switch mode {
        case .light: false
        case .dark: true
        case .system: isSystemDark
        }
    }

    /// Empieza a seguir al sistema (una vez; el lector lo llama al abrir).
    func start() {
        #if os(iOS)
        guard registration == nil,
              let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
        isSystemDark = scene.traitCollection.userInterfaceStyle == .dark
        registration = scene.registerForTraitChanges([UITraitUserInterfaceStyle.self]) { [weak self] (scene: UIWindowScene, _: UITraitCollection) in
            self?.isSystemDark = scene.traitCollection.userInterfaceStyle == .dark
        }
        #else
        guard observer == nil else { return }
        read()
        observer = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.read() }
        }
        #endif
    }

    #if os(macOS)
    private func read() {
        isSystemDark = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    }
    #endif
}

/// Hoja «Aa»: tipografía, páginas o continuo, tamaño, fondo y noche cálida automática.
struct ReaderAppearanceSheet: View {
    @AppStorage(ReaderKeys.font) private var font: ReaderFont = .newYork
    @AppStorage(ReaderKeys.scale) private var scale = 1.0
    @AppStorage(ReaderKeys.theme) private var theme: ReaderTheme = .auto
    @AppStorage(ReaderKeys.autoNight) private var autoNight = true
    @AppStorage(ReaderKeys.flow) private var flow: ReaderFlow = .paged
    @AppStorage(ReaderKeys.haptics) private var haptics = true
    @AppStorage(ReaderKeys.turn) private var turnStyle: ReaderTurnStyle = .matte
    /// El modo de la app: con «Automático», el tema sigue al claro u oscuro de iOS.
    @AppStorage(AppearanceKeys.mode) private var mode: AppearanceMode = .system
    @ObservedObject private var system = SystemAppearance.shared
    @Environment(\.dynamicTypeSize) private var typeSize
    /// El alto de la hoja «Aa»: el de su contenido. Para cambiarlo animado se pasa
    /// de un alto al otro (como al arrastrarla); asignado directo, iOS lo cambia de golpe.
    @State private var detent = PresentationDetent.height(Theme.Size.appearanceSheet)
    @State private var detents: Set<PresentationDetent> = [.height(Theme.Size.appearanceSheet)]
    @State private var measured = false
    /// Ya se abrió la hoja: lo que aparezca de aquí en adelante entra animado.
    @State private var opened = false
    /// La fila de la hoja ocupa su lugar / ya se desvaneció (se va en dos tiempos).
    @State private var turnsShown = ReaderFlow.current == .paged
    @State private var turnsFaded = false

    private var palette: ReaderPalette {
        ReaderPalette.resolve(theme, autoNight: autoNight, appIsDark: system.isDark(mode: mode))
    }

    var body: some View {
        sized
            // Toda la hoja toma el tema que eliges: papel, tinta y mosaicos.
            .environment(\.colorScheme, palette.scheme)
            .presentationBackground(palette.background)
            .animation(Theme.Motion.standard, value: theme)
            .animation(Theme.Motion.standard, value: font)
            .sensoryFeedback(.selection, trigger: scale)
            .sensoryFeedback(.selection, trigger: theme)
            .sensoryFeedback(.selection, trigger: font)
            .sensoryFeedback(.selection, trigger: turnStyle)
            .onAppear { opened = true }
            .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var sized: some View {
        if typeSize.isAccessibilitySize {
            // Con la letra más grande no cabe en una hoja a su medida: va a todo lo alto y se desplaza.
            ScrollView { content }
                .presentationDetents([.large])
        } else {
            content
                // Nunca se aprieta: mientras la hoja cambia de alto, los textos que se
                // encogen para caber (los de «Fondo») se achicaban y volvían a crecer.
                .fixedSize(horizontal: false, vertical: true)
                // La hoja mide lo que mide su contenido: sin espacio muerto abajo.
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { resize(to: $0) }
                // Pegado arriba, aunque la hoja aún no tenga su alto nuevo: lo de arriba nunca
                // baja; al crecer, la hoja sube y lo nuevo aparece desde abajo.
                .frame(minHeight: 0, maxHeight: .infinity, alignment: .top)
                .presentationDetents(detents, selection: $detent)
        }
    }

    private func resize(to height: CGFloat) {
        let target = PresentationDetent.height(height)
        guard target != detent else { return }
        // Al abrir, sin animación: la hoja sale ya con su alto.
        guard measured else { measured = true; detents = [target]; detent = target; return }
        detents = [detent, target]
        Task { @MainActor in
            withAnimation(Theme.Motion.sheet) { detent = target }
            try? await Task.sleep(for: .seconds(Theme.Motion.sheetSettle))
            if detent == target { detents = [target] }
        }
    }

    /// Dos tiempos, para que nada se cruce: al irse, la fila se desvanece en su
    /// lugar y después se cierra el hueco (y la hoja «Aa» se acorta) con la misma
    /// curva; al volver, se abre el hueco y los mosaicos entran solos en cascada.
    private func moveTurns(_ shows: Bool) {
        if shows {
            turnsFaded = false
            withAnimation(Theme.Motion.sheet) { turnsShown = true }
            return
        }
        withAnimation(Theme.Motion.exit) { turnsFaded = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Theme.Motion.exitDuration))
            guard !showsTurns else { return }
            withAnimation(Theme.Motion.sheet) { turnsShown = false }
            turnsFaded = false
        }
    }

    private var showsTurnsHere: Bool {
        #if os(iOS)
        true
        #else
        false
        #endif
    }

    private var showsTurns: Bool {
        #if os(iOS)
        flow == .paged
        #else
        false
        #endif
    }


    /// Dos columnas de letras; con la letra más grande, una sola («Ne…», «Sa…» se cortaban).
    private var fontColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: Theme.Space.s), count: typeSize.isAccessibilitySize ? 1 : Theme.Size.fontColumns)
    }

    private var content: some View {
        // Más aire entre secciones (Letra, Página, Fondo) que dentro de cada una.
        VStack(alignment: .leading, spacing: Theme.Space.xl) {
            // Letra: cuatro mosaicos 2×2 con su «Aa», su nombre y qué la hace distinta.
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                SectionHeader("Letra")
                LazyVGrid(columns: fontColumns, spacing: Theme.Space.s) {
                    ForEach(ReaderFont.allCases) { item in
                        Button { font = item } label: {
                            HStack(spacing: Theme.Space.s) {
                                // La muestra mide lo mismo en los cuatro mosaicos: el mismo tamaño
                                // en la misma caja, crezca o no el nombre de al lado.
                                Text("Aa")
                                    .font(item.preview(size: Theme.Space.xl))
                                    .lineLimit(1)
                                    .frame(width: Theme.Size.tapTarget, height: Theme.Size.tapTarget)
                                // Nombre y detalle en dos renglones si no caben («Clásica y compa…»).
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(item.name).font(.subheadline.weight(.medium)).lineLimit(Theme.Size.labelLines)
                                    Text(item.detail).font(.caption).foregroundStyle(Theme.secondaryInk).lineLimit(Theme.Size.labelLines)
                                }
                                .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Theme.Space.l)
                            .padding(.vertical, Theme.Space.s)
                            .background(Theme.field, in: RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous)
                                    .strokeBorder(item == font ? Theme.ink : .clear, lineWidth: Theme.Size.quoteRule)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(item.name)
                        .accessibilityAddTraits(item == font ? .isSelected : [])
                    }
                }
                sizeRow
            }

            // Página: páginas o continuo y, en páginas, cómo se pasa la hoja. La
            // hoja «Aa» cambia de alto con la misma curva que se abre o cierra el
            // hueco, así lo de abajo no se mueve en la pantalla. Al irse, la fila se
            // desvanece rápido, antes de que el carril le pase encima; al volver,
            // primero se abre su lugar y luego entran los mosaicos en cascada.
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                SectionHeader("Página")
                SegmentedChoice(options: ReaderFlow.allCases, selection: $flow) { item in
                    Label(item.name, systemImage: item.symbol)
                }
                VStack(spacing: 0) {
                    if turnsShown && showsTurnsHere {
                        TurnStylePicker(selection: $turnStyle, entering: opened)
                            .opacity(turnsFaded ? 0 : Theme.Emphasis.rest)
                            .transition(.identity)
                    }
                }
            }
            .onChange(of: showsTurns) { _, shows in moveTurns(shows) }

            VStack(alignment: .leading, spacing: Theme.Space.s) {
            SectionHeader("Fondo")
            // Con la letra más grande, un fondo bajo otro, con su nombre al lado.
            AdaptiveStack {
                ForEach(ReaderTheme.allCases) { item in
                    Button { theme = item } label: {
                        swatchLayout {
                            swatch(for: item)
                                .frame(width: Theme.Size.tapTarget, height: Theme.Size.tapTarget)
                                .overlay {
                                    Circle().strokeBorder(item == theme ? Theme.ink : Theme.track,
                                                          lineWidth: item == theme ? Theme.Size.quoteRule : Theme.Size.hairline)
                                }
                            Text(item.title)
                                .font(.caption)
                                .foregroundStyle(item == theme ? Theme.ink : Theme.secondaryInk)
                                // Dos renglones antes que achicarse: «Noche cálida» salía más chica que las demás.
                                .lineLimit(Theme.Size.labelLines)
                                .multilineTextAlignment(typeSize.isAccessibilitySize ? .leading : .center)
                        }
                        .frame(maxWidth: .infinity, alignment: typeSize.isAccessibilitySize ? .leading : .center)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(item == theme ? .isSelected : [])
                }
            }

            }

            VStack(alignment: .leading, spacing: Theme.Space.s) {
            Toggle("Noche cálida al atardecer", isOn: $autoNight)
                .disabled(theme != .auto)
                .font(.subheadline)
                .tint(Theme.accent)
            #if os(iOS)
            Toggle("Vibrar al pasar de página", isOn: $haptics)
                .font(.subheadline)
                .tint(Theme.accent)
            #endif
            }
        }
        .foregroundStyle(Theme.ink)
        // Abajo ya hay la orilla del iPhone: sin margen extra, sin espacio muerto.
        .padding([.horizontal, .top], Theme.Space.xl)
    }


    private var swatchLayout: AnyLayout {
        typeSize.isAccessibilitySize ? AnyLayout(HStackLayout(spacing: Theme.Space.l)) : AnyLayout(VStackLayout(spacing: Theme.Space.s))
    }

    private var sizeRow: some View {
            HStack(spacing: Theme.Space.l) {
                Button { scale = max(Self.scales.lowerBound, scale - Self.scaleStep) } label: { Text("A").font(.footnote).sizeTarget() }
                    .accessibilityLabel("Letra más chica")
                sizeSlider
                    .accessibilityLabel("Tamaño de letra")
                Button { scale = min(Self.scales.upperBound, scale + Self.scaleStep) } label: { Text("A").font(.largeGlyph).sizeTarget() }
                    .accessibilityLabel("Letra más grande")
            }
            .buttonStyle(.plain)
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
            // Mitad papel de día, mitad papel de noche, con su «Aa» en cada tinta:
            // dice que sigue al claro u oscuro de iOS.
            let day = ReaderPalette.paper, night = ReaderPalette.darkPaper
            ZStack {
                Circle().fill(day.background)
                Text("Aa").font(.rowTitle.weight(.medium)).foregroundStyle(day.textColor)
                ZStack {
                    Circle().fill(night.background)
                    Text("Aa").font(.rowTitle.weight(.medium)).foregroundStyle(night.textColor)
                }
                .mask { HStack(spacing: 0) { Spacer(minLength: 0).frame(maxWidth: .infinity); Rectangle() } }
            }
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

/// Cómo se pasa la hoja: cuatro mosaicos con una hoja chiquita; la elegida pasa
/// en bucle con su estilo, para verlo sin leer. Si la fila aparece con la hoja ya
/// abierta (al volver a «Páginas»), los mosaicos suben un poco y aparecen uno tras
/// otro, igual que los del pie, y la muestra elegida empieza a pasar cuando ya
/// están quietos: nunca se mueven dos cosas a la vez en el mismo mosaico.
private struct TurnStylePicker: View {
    @Binding var selection: ReaderTurnStyle
    @State private var appeared: Bool
    @State private var settled: Bool

    init(selection: Binding<ReaderTurnStyle>, entering: Bool) {
        _selection = selection
        _appeared = State(initialValue: !entering)
        _settled = State(initialValue: !entering)
    }

    var body: some View {
        // Con la letra más grande, un estilo bajo otro, cada uno con su nombre entero.
        AdaptiveStack(spacing: Theme.Space.s) {
            ForEach(Array(ReaderTurnStyle.allCases.enumerated()), id: \.element) { index, item in
                Button { selection = item } label: {
                    IconTile(title: item.name, selected: item == selection) {
                        TurnPreview(style: item, active: item == selection && settled)
                            // Al elegirla (o al quedar quieta), empieza su vuelta desde cero.
                            .id([item == selection, settled])
                    }
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Pasar la hoja: \(item.name)")
                .accessibilityAddTraits(item == selection ? .isSelected : [])
                .opacity(appeared ? Theme.Emphasis.rest : 0)
                .offset(y: appeared ? 0 : Theme.Space.s)
                .animation(Theme.Motion.sheet.delay(Theme.Motion.enterDelay + Theme.Motion.stagger * Double(index)),
                           value: appeared)
            }
        }
        .animation(Theme.Motion.select, value: selection)
        .onAppear { appeared = true }
        .task {
            guard !settled else { return }
            try? await Task.sleep(for: .seconds(Theme.Motion.enterSettle))
            settled = true
        }
    }
}

