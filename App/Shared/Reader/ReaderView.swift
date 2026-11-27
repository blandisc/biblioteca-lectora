import LectoraCore
import SwiftUI
import WebKit

/// Pantalla de lectura. El WebView solo renderiza; la interfaz es nativa.
/// Tocar a la izquierda o a la derecha pasa de página, al centro muestra los
/// controles, y el toque largo selecciona texto para subrayar con lápiz.
struct ReaderView: View {
    let bookFile: URL
    /// Libro del catálogo; sus subrayados se guardan con este ID.
    var bookID: UUID? = nil
    /// Abrir en este pasaje (desde «ir al pasaje» de una nota) y no donde lo dejaste.
    var startCFI: String? = nil
    @StateObject private var controller = ReaderController()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    /// El tamaño de texto de iOS: la letra del libro lo sigue, sobre lo que elijas en «Aa».
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @State private var showsSession = false
    /// El panel de abajo subido (con el pie y la sesión) o solo la tira.
    /// Hoja de herramientas abierta (índice, buscar o subrayados).
    @State private var tools: ReaderToolsSheet.Part?
    @AppStorage(AppearanceKeys.mode) private var mode: AppearanceMode = .system
    @State private var showsChrome = !LaunchOptions.hidesReaderChrome
    @ObservedObject private var library = LibraryStore.shared
    @State private var showsAppearance = false
    /// La hendidura (HE) a la vista, sobre el libro.
    @State private var slitting = false
    #if DEBUG
    @State private var demoStarted = false
    #endif
    @State private var noteText = ""
    @AppStorage(ReaderKeys.font) private var font: ReaderFont = .newYork
    @AppStorage(ReaderKeys.scale) private var scale = 1.0
    @AppStorage(ReaderKeys.theme) private var theme: ReaderTheme = .auto
    @AppStorage(ReaderKeys.autoNight) private var autoNight = true
    @AppStorage(ReaderKeys.flow) private var flow: ReaderFlow = .paged
    @AppStorage(ReaderKeys.footer) private var footer: ReaderFooter = .chapterTime
    @AppStorage(ReaderKeys.turn) private var turnStyle: ReaderTurnStyle = .matte
    @ObservedObject private var sessions = SessionStore.shared
    /// Ajustes: mostrar las palabras de la sesión en el panel del lector.
    @AppStorage(SessionKeys.counter) private var showsCounter = true

    private var palette: ReaderPalette {
        ReaderPalette.resolve(theme, autoNight: autoNight, appIsDark: colorScheme == .dark)
    }

    /// Título del catálogo (el de `[[ ]]` en las notas); si no, el del archivo.
    private var catalogTitle: String {
        bookID.flatMap { LibraryStore.shared.book(id: $0)?.title } ?? title
    }

    /// El título limpio de tu biblioteca; el del EPUB o el nombre del archivo solo
    /// si el libro no está en el catálogo. Antes, mientras cargaba, salía el nombre
    /// del archivo («Don Quijote de la Mancha - Miguel de Cervantes»).
    private var title: String {
        bookID.flatMap { LibraryStore.shared.book(id: $0)?.title }
            ?? controller.title ?? bookFile.deletingPathExtension().lastPathComponent
    }

    // El cuerpo va en tres partes: entero, el compilador de Xcode 26 no alcanzaba a revisarlo.
    var body: some View {
        lifecycle(alerts(tail(withOverlays
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { controller.session?.resume() } else { controller.session?.pause() }
            }
            .onDisappear { controller.session?.finish() })))
    }

    /// La página y lo que se le pone encima mientras lees.
    private var page: some View {
        ZStack {
            palette.background.ignoresSafeArea()
            // Tu página entra con un fundido corto cuando el libro ya se acomodó.
            // En continuo el texto corre hasta la orilla de arriba de la pantalla.
            ReaderWebView(controller: controller)
                .ignoresSafeArea(edges: flow == .scrolled ? [.top, .bottom] : .bottom)
                // El renglón (LG-B): lo demás en penumbra, en las mismas medidas que el libro.
                .overlay {
                    if let band = controller.guideBand {
                        GuideShade(band: band, paper: palette.background)
                            .ignoresSafeArea(edges: flow == .scrolled ? [.top, .bottom] : .bottom)
                            .transition(.opacity)
                    }
                }
                .animation(Theme.Motion.standard, value: controller.guideBand == nil)
                .opacity(controller.isSettled ? Theme.Emphasis.rest : 0)
            // Hasta que aparece la primera página: que se note que está trabajando.
            if !controller.isSettled && controller.errorMessage == nil {
                LoadingLine(text: "Abriendo el libro…", tone: palette.textColor)
                    .transition(.opacity)
            }
        }
        .animation(Theme.Motion.standard, value: controller.isSettled)
        .overlay(alignment: .topTrailing) {
            // Con los controles a la vista, la barra de estado ocupa el borde y la cinta
            // tapaba la batería: ahí lo dice el ícono relleno del marcador.
            // En continuo no: ahí el marcador es el hilo y la cinta junto a su renglón.
            if currentBookmark != nil && !showsChrome && controller.isSettled && flow != .scrolled {
                BookmarkRibbon()
                    .padding(.trailing, Theme.Space.gutter)
                    .ignoresSafeArea(edges: .top)
                    .transition(.move(edge: .top))
                    .accessibilityHidden(true)
            }
        }
        // Ni botones ni números hasta que el libro sabe en qué página estás.
        .overlay {
            if controller.isSettled { chrome.transition(.opacity) }
        }
        .animation(Theme.Motion.standard, value: controller.isSettled)
    }

    /// La página con su barra de búsqueda, la tarjeta de la sesión y sus hojas.
    private var withOverlays: some View {
        page
        // Con «Aa» abierta se ve la página como al leer: sin botones encima (ni otra «Aa»).
        .onChange(of: showsAppearance) { _, shown in
            if shown { withAnimation(Theme.Motion.standard) { showsChrome = false } }
        }
        #if os(iOS)
        .statusBarHidden(!showsChrome)
        #endif
        .preferredColorScheme(palette.scheme ?? mode.colorScheme)
        .sheet(item: $tools) { part in
            ReaderToolsSheet(controller: controller, bookID: bookID, part: part)
        }
        // Tras ir a un resultado: anterior y siguiente sin abrir otra vez la lista.
        .overlay(alignment: .bottom) {
            if let index = controller.searchIndex, !showsChrome, !showsSession, tools == nil,
               !controller.searchResults.isEmpty {
                let count = controller.searchResults.count
                SearchStepper(position: "\(index + 1) de \(count)", query: controller.searchedQuery,
                              canGoBack: index > 0, canGoForward: index < count - 1,
                              onBack: { controller.goToResult(index - 1) },
                              onForward: { controller.goToResult(index + 1) },
                              onList: { tools = .search },
                              onClose: { withAnimation(Theme.Motion.standard) { controller.clearSearch() } })
                    .padding(.horizontal, Theme.Reader.chromeInset)
                    .padding(.bottom, Theme.Reader.chromeInset)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Theme.Motion.sheet, value: controller.searchIndex == nil)
        .overlay(alignment: .bottom) {
            if showsSession, let session = controller.session {
                ZStack(alignment: .bottom) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { showsSession = false }
                        .accessibilityHidden(true)
                    SessionCard(tracker: session, bookTitle: catalogTitle) { showsSession = false }
                        // Entra donde estaba la tarjeta, creciendo apenas desde abajo; se va bajando.
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: Theme.Emphasis.pressedScale, anchor: .bottom))
                                .animation(Theme.Motion.sheet.delay(Theme.Motion.exitDuration)),
                            removal: .move(edge: .bottom).combined(with: .opacity)))
                }
            }
        }
        .animation(Theme.Motion.sheet, value: showsSession)
        // Con la guía puesta, tocar avanza el renglón; esto la quita. Abajo, junto al
        // folio: arriba tapaba el primer renglón.
        .overlay(alignment: .bottomTrailing) {
            if controller.guiding && !showsChrome {
                CloseButton(label: "Terminar el renglón", style: .glass) {
                    withAnimation(Theme.Motion.standard) { controller.stopGuide() }
                }
                .padding(.horizontal, Theme.Reader.chromeInset)
                .transition(.opacity)
            }
        }
        .overlay {
            if slitting {
                SlitScreen(controller: controller, paper: palette.background, ink: palette.textColor) {
                    withAnimation(Theme.Motion.standard) { slitting = false }
                }
                .transition(.opacity)
            }
        }
        .animation(Theme.Motion.standard, value: slitting)
        #if os(iOS)
        // Solo el botón de arriba cierra el libro: deslizar de la orilla pasa la hoja.
        .interactiveDismissDisabled()
        #endif
    }

    /// «Guiada» en la tarjeta (EN-1): el renglón o la hendidura, por frase o por palabra.
    private func guide(_ choice: GuideChoice) {
        withAnimation(Theme.Motion.standard) { showsChrome = false }
        switch choice {
        case .line:
            controller.startGuide()
        case .slit(let unit):
            controller.stopGuide()
            UserDefaults.standard.set(unit.rawValue, forKey: ReaderKeys.slitUnit)
            slitting = true
        }
    }
}

extension ReaderView {
    /// Lo último del cuerpo del lector: subrayados, selección, notas y avisos.
    fileprivate func tail(_ content: some View) -> some View {
        content
        .sheet(isPresented: $showsAppearance) {
            ReaderAppearanceSheet()
        }
        .overlay(alignment: .bottom) {
            if let annotation = controller.tappedAnnotation {
                ZStack(alignment: .bottom) {
                    // Tocar fuera cierra la tarjeta.
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { controller.tappedHighlight = nil }
                        .accessibilityHidden(true)
                    HighlightCard(annotation: annotation) { action in
                        act(on: annotation, action)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .overlay(alignment: .bottom) {
            if controller.hasSelection && controller.tappedAnnotation == nil {
                SelectionBar { action in
                    switch action {
                    case .underline: controller.highlightSelection()
                    case .lookUp: controller.lookUpSelection()
                    case .note: controller.highlightSelection(withNote: true)
                    case .toNote: controller.highlightSelection(toNote: true)
                    case .copy: controller.copySelection()
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottom) {
            if let term = controller.lookup {
                ZStack(alignment: .bottom) {
                    // Tocar fuera cierra la tarjeta, como la del subrayado.
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { controller.lookup = nil }
                        .accessibilityHidden(true)
                    LookupCard(term: term, bookLanguage: controller.language) { controller.lookup = nil }
                        .id(term)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(Theme.Motion.standard, value: controller.lookup)
        .onChange(of: controller.lookup) { _, term in
            if term != nil { showsChrome = false }
        }
        .animation(Theme.Motion.standard, value: controller.hasSelection)
        .sensoryFeedback(.selection, trigger: controller.hasSelection)
        .onChange(of: controller.hasSelection) { _, selecting in
            if selecting { showsChrome = false }
        }
        .animation(Theme.Motion.standard, value: controller.tappedHighlight)
        // La tarjeta del subrayado va sola: sin los controles encima.
        .onChange(of: controller.tappedHighlight) { _, cfi in
            if cfi != nil { showsChrome = false }
        }
    }

    /// Notas, avisos y errores.
    fileprivate func alerts(_ content: some View) -> some View {
        content
        .sheet(item: $controller.noteLinkTarget) { annotation in
            NoteLinkSheet(annotation: annotation, bookTitle: catalogTitle) { saved in
                controller.notice = "Quedó en «\(saved.title)»."
            }
        }
        .alert("Tu nota sobre el pasaje", isPresented: Binding(
            get: { controller.noteTarget != nil },
            set: { if !$0 { controller.noteTarget = nil } }
        )) {
            TextField("Escribe tu nota", text: $noteText)
            Button("Guardar la nota") { controller.saveNote(noteText); noteText = "" }
            Button("Descartar la nota", role: .cancel) { noteText = "" }
        } message: {
            Text(controller.noteTarget.map { "«\($0.quote)»" } ?? "")
        }
        .errorAlert("No pude abrir el libro", message: $controller.errorMessage, back: "Volver a la biblioteca") { dismiss() }
        .errorAlert("No pude guardar el subrayado", message: $controller.saveError, back: "Seguir leyendo")
        .noticeAlert("Llevé el pasaje a tu nota", message: $controller.notice, back: "Seguir leyendo")
    }

    /// Al abrir y cuando cambia la letra, el tema o el modo: se lo dice al libro.
    fileprivate func lifecycle(_ content: some View) -> some View {
        content
        .onAppear {
            applyStyle()
            // Sin capturar la vista: el controlador no debe retenerse a sí mismo.
            let chrome = $showsChrome
            let reader = controller
            reader.onTap = { [weak reader] x in
                // Con la guía del renglón: tocar avanza; en la orilla izquierda, regresa.
                if reader?.guiding == true {
                    reader?.stepGuide(forward: x >= Theme.Reader.edgeZone)
                    return
                }
                // En continuo, como en Libros de Apple, tocar solo muestra u oculta los controles.
                if ReaderFlow.current == .scrolled {
                    withAnimation(Theme.Motion.standard) { chrome.wrappedValue.toggle() }
                } else if x < Theme.Reader.edgeZone {
                    reader?.previous()
                } else if x > 1 - Theme.Reader.edgeZone {
                    reader?.next()
                } else {
                    withAnimation(Theme.Motion.standard) { chrome.wrappedValue.toggle() }
                }
            }
            if let bookID {
                controller.onPositionSettled = { location in
                    LibraryStore.shared.savePosition(
                        .init(cfi: location.cfi, fraction: location.fraction, excerpt: location.excerpt),
                        for: bookID)
                }
            }
            let resume = startCFI ?? bookID.flatMap { LibraryStore.shared.position(for: $0)?.cfi }
            // En iCloud Drive el libro puede no estar en el dispositivo: primero se baja.
            let file = bookFile
            Task { @MainActor in
                guard await CloudFiles.ensureDownloaded(file) else {
                    controller.errorMessage = "No pude bajar el libro de iCloud. Revisa tu conexión e inténtalo de nuevo."
                    return
                }
                controller.open(bookFile: file, bookID: bookID, lastCFI: resume)
            }
        }
        // Capturas automáticas: el índice o una búsqueda, ya con el libro abierto.
        .onChange(of: controller.contents) { _, contents in
            guard tools == nil, !contents.isEmpty else { return }
            switch LaunchOptions.screen {
            case "contents": tools = .contents
            case "marks": tools = .highlights
            case "appearance": showsAppearance = true
            case "booksearch":
                controller.search(UserDefaults.standard.string(forKey: "screenshot.query") ?? "Mancha")
                tools = .search
            default: break
            }
            #if DEBUG
            runDemo()
            #endif
        }
        .onChange(of: bookmarkCFIs, initial: true) { _, cfis in controller.setBookmarks(cfis) }
        .onChange(of: palette) { _, _ in applyStyle() }
        .onChange(of: font) { _, _ in applyStyle() }
        .onChange(of: scale) { _, _ in applyStyle() }
        .onChange(of: dynamicTypeSize) { _, _ in applyStyle() }
        .onChange(of: flow) { _, _ in
            controller.stopGuide()
            applyStyle()
        }
        .onChange(of: turnStyle) { _, _ in applyStyle() }
    }

    /// Controles de vidrio al tocar el centro (los dos estilos). Sin controles,
    /// el Editorial deja a la vista el capítulo y el porcentaje en pequeño.
    @ViewBuilder
    private var chrome: some View {
        ZStack {
            if !showsChrome {
                ReadingFolio(title: title, location: controller.folioLocation, footerText: footerText,
                             color: palette.textColor,
                             paper: flow == .scrolled ? palette.background : nil,
                             pagePaper: palette.background,
                             options: footerOptions, footer: $footer) { EmptyView() }
                .transition(.opacity)
            }
            VStack(spacing: 0) {
                if showsChrome {
                    TopControls(bookmarked: currentBookmark != nil, onBookmark: toggleBookmark, onClose: { dismiss() })
                        #if os(iOS)
                        .padding(.top, -Theme.Reader.chromeLift)
                        #else
                        // En la Mac, debajo de la barra de la ventana, no junto a sus botones.
                        .padding(.top, Theme.Space.s)
                        #endif
                        // En continuo el texto corre bajo los botones: detrás va la misma
                        // franja de papel que usa el capítulo al leer, y se desvanece.
                        .background(alignment: .top) {
                            if flow == .scrolled {
                                VStack(spacing: 0) {
                                    palette.background
                                    paperFade(palette.background, toward: .bottom)
                                }
                                .padding(.bottom, -Theme.Reader.folioFade)
                                .ignoresSafeArea(edges: .top)
                                .allowsHitTesting(false)
                            }
                        }
                        .transition(.opacity)
                }
                Spacer(minLength: 0)
                if showsChrome {
                    BottomPanel(title: title, location: controller.location,
                                session: showsCounter ? controller.session : nil,
                                onSession: openSession,
                                onContents: { tools = .contents },
                                onSearch: { tools = .search },
                                onAppearance: { showsAppearance = true },
                                onGuide: { guide($0) },
                                onSeek: { controller.goTo(fraction: $0) },
                                onReturn: { origin in
                                    if let cfi = origin.cfi { controller.goTo(target: cfi) } else { controller.goTo(fraction: origin.fraction) }
                                })
                        // Sube al aparecer; al irse se desvanece rápido en su lugar: así, al
                        // volverse «Esta sesión», nunca se leen las dos tarjetas encimadas.
                        .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity),
                                                removal: .opacity.animation(Theme.Motion.exit)))
                }
            }
        }
    }

    /// Lo que diría el pie con cada opción: el dato grande y su leyenda
    /// («9 min» · «para terminar el capítulo»). `nil` si aún no hay con qué calcularlo.
    private func footerParts(_ kind: ReaderFooter) -> (value: String, caption: String)? {
        let fraction = controller.folioLocation?.fraction ?? 0
        switch kind {
        case .chapterTime:
            guard let words = controller.folioLocation?.chapterWordsLeft else { return nil }
            let perMinute = sessions.usualWordsPerMinute ?? SessionStore.defaultWordsPerMinute
            let seconds = Double(words) / perMinute * 60
            return (seconds < 60 ? "Menos de 1 min" : ReadingFormat.duration(seconds), "para terminar el capítulo")
        case .bookTime:
            // Con tus sesiones en este libro, a tu ritmo en él; mientras no hay, por su largo.
            let estimate = controller.folioLocation?.bookWordsLeft.map { words in
                Double(words) / (sessions.usualWordsPerMinute ?? SessionStore.defaultWordsPerMinute) * 60
            }
            guard let seconds = bookID.flatMap({ sessions.remaining(forBook: $0, progress: fraction) }) ?? estimate
            else { return nil }
            return (seconds < 60 ? "Menos de 1 min" : ReadingFormat.duration(seconds), "para terminar el libro")
        case .page:
            guard let page = controller.folioLocation?.page, let count = controller.folioLocation?.pageCount, count > 0 else { return nil }
            return ("Página \(page)", "de \(count)")
        case .percent:
            return (fraction.percentText, "del libro")
        }
    }

    /// Las opciones del pie, cada una con lo que diría ahora mismo.
    private var footerOptions: [FooterOption] {
        ReaderFooter.allCases.map { kind in
            guard let parts = footerParts(kind) else {
                return FooterOption(kind: kind, text: "Calculando…", available: false)
            }
            // En la muestra, la versión corta del pie: cabe entera en medio panel.
            let short = parts.caption.replacingOccurrences(of: "para terminar", with: "para")
            return FooterOption(kind: kind, text: kind == .percent ? parts.value : "\(parts.value) \(short)",
                                available: true)
        }
    }

    /// El pie según lo que elegiste; si no hay con qué calcularlo, el porcentaje.
    private var footerText: String {
        if footer == .percent { return (controller.folioLocation?.fraction ?? 0).percentText }
        guard let parts = footerParts(footer) else { return (controller.folioLocation?.fraction ?? 0).percentText }
        return "\(parts.value) \(parts.caption)"
    }

    /// El marcador de la página que se ve, si tiene: el que reader.js ve dentro
    /// de la página, o el recién puesto mientras reader.js contesta.
    private var currentBookmark: Bookmark? {
        guard let bookID, let location = controller.location else { return nil }
        return library.bookmarks(for: bookID).first {
            controller.bookmarksOnPage.contains($0.cfi) || $0.cfi == location.cfi
        }
    }

    /// Los CFI de los marcadores del libro, para mandarlos a reader.js.
    private var bookmarkCFIs: [String] {
        bookID.map { library.bookmarks(for: $0).map(\.cfi) } ?? []
    }

    private func toggleBookmark() {
        guard let bookID, let location = controller.location else { return }
        if let mark = currentBookmark {
            library.removeBookmark(id: mark.id)
        } else if flow == .scrolled {
            // En continuo se marca el renglón que lees arriba: ahí cuelgan el hilo y la cinta.
            controller.readingLine { cfi, excerpt in
                library.addBookmark(Bookmark(bookID: bookID, cfi: cfi, fraction: location.fraction,
                                             excerpt: excerpt ?? location.excerpt))
            }
        } else if let cfi = location.cfi {
            library.addBookmark(Bookmark(bookID: bookID, cfi: cfi, fraction: location.fraction, excerpt: location.excerpt))
        }
    }

    private func act(on annotation: Annotation, _ action: HighlightCard.Action) {
        controller.tappedHighlight = nil
        guard let cfi = annotation.cfi else { return }
        switch action {
        case .note:
            noteText = annotation.note ?? ""
            controller.noteTarget = annotation
        case .toNote:
            controller.sendToNote(cfi: cfi)
        case .copy:
            #if os(iOS)
            UIPasteboard.general.string = annotation.quote
            #else
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(annotation.quote, forType: .string)
            #endif
        case .delete:
            controller.removeHighlight(cfi: cfi)
        case .close:
            break
        }
    }

    #if DEBUG
    /// Para revisar animaciones en video (`-screenshot.demo turns|flow|aa|guide|slit|slitWord|contents|lookup|selection`): pasa
    /// páginas o cambia de modo solo, sin tocar la pantalla. Solo en Debug.
    private func runDemo() {
        guard !demoStarted, let demo = LaunchOptions.demo else { return }
        demoStarted = true
        Task { @MainActor in
            // Que el libro termine de pintarse antes de empezar.
            try? await Task.sleep(for: .seconds(6))
            switch demo {
            case "turns":
                for forward in [true, true, true, false, true, false] {
                    forward ? controller.next() : controller.previous()
                    try? await Task.sleep(for: .seconds(1.5))
                }
            case "aa":
                showsAppearance = true
            case "guide":
                // El renglón: se pone y baja tres renglones.
                guide(.line)
                for _ in 0..<3 {
                    try? await Task.sleep(for: .seconds(1.2))
                    controller.stepGuide(forward: true)
                }
            case "slit", "slitWord":
                guide(.slit(demo == "slit" ? .phrase : .word))
            case "contents":
                tools = .contents
            case "selection":
                // La barra de selección, sin tener que elegir texto con el dedo.
                controller.hasSelection = true
            case "lookup":
                // «Consultar» con la palabra de `-screenshot.query` (por omisión, «agency»).
                controller.lookup = UserDefaults.standard.string(forKey: "screenshot.query") ?? "agency"
            case "bookmark":
                // Marca el renglón de arriba (en continuo, hilo y cinta) y lo deja a la vista.
                if currentBookmark == nil { toggleBookmark() }
            case "bookmarkOff":
                // Con el marcador ya puesto: lo quita a los tres segundos (para ver cómo se recoge).
                while !controller.isSettled { try? await Task.sleep(for: .seconds(0.5)) }
                try? await Task.sleep(for: .seconds(3))
                if currentBookmark != nil { toggleBookmark() }
            case "stepper":
                // Busca, va al cuarto resultado (barrita en la página) y luego abre Buscar vacío (recientes).
                withAnimation(Theme.Motion.standard) { showsChrome = false }
                controller.search(UserDefaults.standard.string(forKey: "screenshot.query") ?? "imperio")
                try? await Task.sleep(for: .seconds(8))
                controller.goToResult(UserDefaults.standard.integer(forKey: "screenshot.result"))
                try? await Task.sleep(for: .seconds(6))
                controller.clearSearch()
                tools = .search
            case "session":
                withAnimation(Theme.Motion.standard) { showsChrome = true }
                try? await Task.sleep(for: .seconds(1.5))
                openSession()
                try? await Task.sleep(for: .seconds(2))
                showsSession = false
            case "flow":
                showsAppearance = true
                for _ in 0..<4 {
                    try? await Task.sleep(for: .seconds(2.5))
                    flow = flow == .paged ? .scrolled : .paged
                }
            default: break
            }
        }
    }
    #endif

    /// Cuánto agranda iOS el texto normal (1 con el tamaño de siempre).
    private static var systemTextScale: Double {
        #if os(iOS)
        let base = Theme.Reader.textBase
        return UIFontMetrics(forTextStyle: .body).scaledValue(for: base) / base
        #else
        1
        #endif
    }

    /// La tarjeta de abajo se vuelve «Esta sesión»: una se desvanece en su lugar y,
    /// ya ida, la otra crece apenas desde abajo.
    private func openSession() {
        withAnimation(Theme.Motion.sheet) { showsChrome = false; showsSession = true }
    }

    private func applyStyle() {
        controller.setColors(text: palette.text, link: palette.link)
        controller.setFont(family: font.css, scale: scale * Self.systemTextScale)
        controller.setScrolled(flow == .scrolled)
        #if os(iOS)
        controller.pageBackground = UIColor(palette.background)
        controller.turnStyle = turnStyle
        #endif
    }
}

private struct TopControls: View {
    let bookmarked: Bool
    let onBookmark: () -> Void
    let onClose: () -> Void

    var body: some View {
        // Arriba solo cerrar y el marcador; buscar y letra van en la tarjeta de abajo (BB-C, 25 nov 2026).
        HStack {
            // En la Mac el libro se cierra con el botón rojo de su ventana (o ⌘W): la flecha
            // de iOS chocaba con los botones de la ventana.
            #if os(iOS)
            Button(action: onClose) {
                Image(systemName: "chevron.down")
                    .font(.body.weight(.semibold))
                    .frame(width: Theme.Size.tapTarget, height: Theme.Size.tapTarget)
                    .glassCircle()
            }
            .accessibilityLabel("Cerrar libro")
            #endif
            Spacer()
            Button {
                withAnimation(Theme.Motion.standard) { onBookmark() }
            } label: {
                BookmarkGlyph(on: bookmarked)
                    .glassCircle()
            }
            .accessibilityLabel(bookmarked ? "Quitar marcador" : "Añadir marcador")
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, Theme.Reader.chromeInset)
    }
}

/// Lo que se elige en «Guiada».
enum GuideChoice {
    case line
    case slit(Slit.Unit)
}

/// Panel de abajo al tocar el centro: el capítulo (abre el índice), buscar y «Aa»,
/// la barra para saltar y la página con la sesión. No se sube: qué dice el pie se
/// elige tocando el pie mientras lees (26 nov 2026).
private struct BottomPanel: View {
    let title: String
    let location: ReaderController.Location?
    let session: SessionTracker?
    let onSession: () -> Void
    let onContents: () -> Void
    let onSearch: () -> Void
    let onAppearance: () -> Void
    let onGuide: (GuideChoice) -> Void
    let onSeek: (Double) -> Void
    let onReturn: (ReaderController.Location) -> Void
    @State private var dragValue: Double?
    /// Dónde estabas antes de saltar con la barra: un toque de más ya no te pierde.
    @State private var origin: ReaderController.Location?


    private var fraction: Double { dragValue ?? location?.fraction ?? 0 }

    /// La página a la que apunta la barra (la de ahora o la del arrastre).
    private var page: Int? {
        guard let count = location?.pageCount, count > 0 else { return nil }
        guard let dragValue else { return location?.page }
        return min(count, max(1, Int((dragValue * Double(count)).rounded(.up))))
    }

    private var position: String {
        guard let page, let count = location?.pageCount else { return fraction.percentText }
        return dragValue == nil ? "Pág. \(page) de \(count)" : "Pág. \(page) · \(fraction.percentText)"
    }

    private func returnTitle(_ origin: ReaderController.Location) -> String {
        if let page = origin.page { return "Volver a la pág. \(page)" }
        return "Volver al \(origin.fraction.percentText)"
    }

    /// «1. Ulcinj, Albania…» → «Capítulo 1» encima y «Ulcinj, Albania…» como título.
    /// Si el capítulo no trae número, encima va el libro.
    private var heading: (eyebrow: String, title: String) {
        guard let chapter = location?.chapter else { return ("", title) }
        if let match = chapter.firstMatch(of: /^\s*(\d+|[IVXLCDM]+)[.:)]?\s+(.+)$/) {
            return ("Capítulo \(match.1)", String(match.2))
        }
        return (title, chapter)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // El capítulo, completo y con la letra del libro; encima, su número (o el
            // libro, si el capítulo no lo trae). Tocarlo abre el índice. Con la letra más
            // grande, buscar, «Aa» y «Guiada» bajan bajo el capítulo (antes «Aa» era «…»).
            AdaptiveStack(spacing: Theme.Space.s) {
            Button(action: onContents) {
                VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                    SectionLabel(text: heading.eyebrow, tone: Theme.ink.opacity(Theme.Emphasis.glassText))
                    Text(heading.title)
                        .font(.rowTitle)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .contentTransition(.opacity)
                }
                .frame(maxWidth: .infinity, minHeight: Theme.Size.tapTarget, alignment: .leading)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Índice")
            .accessibilityValue(location?.chapter ?? title)

                // Buscar y letra, junto al capítulo: al alcance del pulgar y sin hacer crecer la tarjeta.
                HStack(spacing: Theme.Space.s) {
                    Button(action: onSearch) {
                        Image(systemName: "magnifyingglass")
                            .roundInGlass()
                    }
                    .accessibilityLabel("Buscar en el libro")
                    Button(action: onAppearance) {
                        Text("Aa").roundInGlass()
                    }
                    .accessibilityLabel("Apariencia")
                    // Lectura guiada (EN-1): el renglón o la hendidura.
                    Menu {
                        Button { onGuide(.line) } label: { Label("Renglón", systemImage: "text.line.first.and.arrowtriangle.forward") }
                        Button { onGuide(.slit(.phrase)) } label: { Label("Hendidura por frase", systemImage: "text.word.spacing") }
                        Button { onGuide(.slit(.word)) } label: { Label("Hendidura por palabra", systemImage: "character.cursor.ibeam") }
                    } label: {
                        Image(systemName: "text.viewfinder").roundInGlass()
                    }
                    .menuStyle(.button)
                    .accessibilityLabel("Lectura guiada")
                }
            }

            // Barra propia, fina y editorial: lo leído en tinta, una perilla chica.
            ScrubberBar(value: fraction, enabled: location != nil,
                        onChange: { dragValue = $0 },
                        onEnd: {
                            if let value = dragValue {
                                if origin == nil { origin = location }
                                onSeek(value)
                            }
                            dragValue = nil
                        })
                .zIndex(1)
                .sensoryFeedback(.selection, trigger: fraction.percentText) { _, _ in dragValue != nil }
                .accessibilityLabel("Avance en el libro")
                .accessibilityValue(position)

            // La página (arrastrando: a cuál vas) y, a la derecha, las palabras de la
            // sesión. Todo en gris y sin íconos: lo que manda es el capítulo.
            // Con la letra más grande, una bajo otra («Pág. 1…» y «0 pal…» se cortaban).
            AdaptiveStack(spacing: 0) {
                Text(position)
                    .monospacedDigit()
                    .foregroundStyle(dragValue == nil ? Theme.ink.opacity(Theme.Emphasis.glassText) : Theme.ink)
                    .contentTransition(.numericText())
                    .animation(Theme.Motion.press, value: position)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                // Tras saltar con la barra, volver a donde ibas (como en Libros de Apple).
                if let origin, dragValue == nil {
                    Button {
                        onReturn(origin)
                        withAnimation(Theme.Motion.standard) { self.origin = nil }
                    } label: {
                        Label(returnTitle(origin), systemImage: "arrow.uturn.backward")
                            .lineLimit(1)
                            .frame(minHeight: Theme.Size.tapTarget)
                            .contentShape(Rectangle())
                    }
                    .transition(.opacity)
                } else if let session {
                    SessionLine(tracker: session, compact: true, action: onSession)
                }
            }
            .animation(Theme.Motion.standard, value: origin == nil)
            .font(.footnote)
            .frame(minHeight: Theme.Size.tapTarget)
            // La página va pegada a su barra, no a media fila de ella.
            .padding(.top, -Theme.Size.tapBleed)

            if Features.audiobook {
                HStack(spacing: Theme.Space.s) {
                    ReaderPillButton(title: "Guiada", systemImage: "text.viewfinder") {}
                    ReaderPillButton(title: "Escuchar", systemImage: "headphones", prominent: true) {}
                }
                .padding(.top, Theme.Space.s)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.ink)
        // Vidrio a `chromeInset` de la orilla y lo de adentro a `Reader.panelInset` del vidrio:
        // empieza en la misma línea que el texto del libro (`Reader.textMargin`).
        .padding(.horizontal, Theme.Reader.panelInset)
        .padding(.vertical, Theme.Reader.panelInset)
        // Lo de adentro no se asoma fuera del vidrio mientras la tarjeta crece.
        .glassPanel(cornerRadius: Theme.Radius.panel, clipped: true)
        // Todo el panel es suyo: un toque en su aire no llega a la página de abajo
        // (que lo tomaría como «ocultar controles»).
        .contentShape(Rectangle())
        .onTapGesture {}
        .padding(.horizontal, Theme.Reader.chromeInset)
    }
}

/// Al tocar un subrayado: una tarjeta de vidrio con la cita y cuatro acciones
/// (nota, llevar a una nota, copiar, borrar), en lugar del menú del sistema.
private struct HighlightCard: View {
    enum Action { case note, toNote, copy, delete, close }
    let annotation: Annotation
    let perform: (Action) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            // La cita y la ✕ en un renglón, sin aire de sobra: la ✕ conserva su
            // área de toque pero no empuja la tarjeta hacia abajo.
            HStack(alignment: .center, spacing: Theme.Space.l) {
                QuoteBlock(text: annotation.quote, note: annotation.note, italic: true)
                    .lineLimit(Theme.Reader.highlightLines)
                Spacer(minLength: 0)
                CloseButton(label: "Cerrar el subrayado") { perform(.close) }
                    .padding(.vertical, -Theme.Space.s)
            }
            AdaptiveStack(spacing: Theme.Space.s) {
                action(.note, annotation.note == nil ? SelectionAction.note.title : "Editar nota", SelectionAction.note.symbol)
                action(.toNote, SelectionAction.toNote.title, SelectionAction.toNote.symbol)
                action(.copy, SelectionAction.copy.title, SelectionAction.copy.symbol)
                action(.delete, "Borrar", "trash")
            }
        }
        .padding(Theme.Space.l)
        .glassPanel(cornerRadius: Theme.Radius.panel)
        .padding(.horizontal, Theme.Reader.chromeInset)
        .padding(.bottom, Theme.Reader.chromeInset)
    }

    private func action(_ kind: Action, _ title: String, _ symbol: String) -> some View {
        Button { perform(kind) } label: {
            IconTile(symbol: symbol, title: title)
        }
        .buttonStyle(PressableStyle())
    }
}

/// Al seleccionar texto: una barra de vidrio abajo, en lugar del menú negro
/// del sistema. «Subrayar», lo que más se usa, va primero y en tinta.
private struct SelectionBar: View {
    enum Action { case underline, lookUp, note, toNote, copy }
    let perform: (Action) -> Void

    var body: some View {
        // Con la letra más grande, una acción bajo otra, cada una con su nombre entero.
        AdaptiveStack(spacing: Theme.Space.s) {
            Button { perform(.underline) } label: {
                IconTile(symbol: SelectionAction.highlight.symbol, title: SelectionAction.highlight.title, prominent: true)
            }
            .buttonStyle(PressableStyle())
            item(.lookUp, .lookup)
            item(.note, .note)
            item(.toNote, .toNote)
            item(.copy, .copy)
        }
        .padding(Theme.Space.s)
        .glassPanel(cornerRadius: Theme.Radius.panel)
        .padding(.horizontal, Theme.Reader.chromeInset)
        .padding(.bottom, Theme.Reader.chromeInset)
    }

    private func item(_ kind: Action, _ shared: SelectionAction) -> some View {
        Button { perform(kind) } label: { IconTile(symbol: shared.symbol, title: shared.title) }
            .buttonStyle(PressableStyle())
    }
}

/// Una opción del pie con lo que diría ahora («9 min» · «para terminar el capítulo»).
struct FooterOption: Identifiable {
    let kind: ReaderFooter
    /// El pie tal como se leerá en la página.
    let text: String
    /// Falso mientras no hay con qué calcularlo (tiempo del libro al empezar).
    let available: Bool
    var id: ReaderFooter { kind }
}

/// Editorial sin controles: arriba nada (el papel se desvanece) y, abajo, el pie que elijas
/// (tiempo para terminar el capítulo o el libro, página o porcentaje). Tocando
/// el pie se abre un globo con las cuatro muestras, cada una como se leerá (no la tarjeta).
/// En páginas, el texto deja aire arriba y abajo (`Reader.pageMarginTop` y `pageMarginBottom`): el folio
/// queda sobre papel limpio. En continuo, el texto pasa por debajo: una franja
/// de papel sólido tapa lo que queda detrás y solo su orilla se desvanece.
private struct ReadingFolio<Counter: View>: View {
    let title: String
    let location: ReaderController.Location?
    let footerText: String
    /// El color del texto del libro: el folio se lee sobre cualquier fondo
    /// (papel, noche cálida, negro), no con el gris de la app.
    let color: Color
    /// En continuo, el papel: va detrás del folio para que el texto no se cruce.
    var paper: Color? = nil
    /// El papel del libro (en los dos modos): de él sale el desvanecido de arriba.
    let pagePaper: Color
    /// Tocar el pie abre un globo con sus opciones, sin la tarjeta: la página sigue a la vista.
    let options: [FooterOption]
    @Binding var footer: ReaderFooter
    @State private var choosing = false
    /// El contador de palabras, en el mismo renglón que el pie.
    @ViewBuilder var counter: Counter

    var body: some View {
        VStack(spacing: 0) {
            // Arriba no hay capítulo: solo el papel que se desvanece desde la orilla de
            // la pantalla. En continuo el texto llega hasta arriba y ahí se va; en
            // páginas el texto empieza justo debajo de la isla.
            Color.clear
                .frame(height: paper == nil ? Theme.Reader.pageMarginTop : Theme.Reader.topFade)
                .background {
                    paperFade(paper ?? pagePaper, toward: .bottom, height: nil)
                        .ignoresSafeArea(edges: .top)
                }
                .allowsHitTesting(false)
            Spacer()
            ZStack {
                Button { choosing = true } label: {
                    VStack(spacing: Theme.Space.xs) {
                        Text(footerText)
                            .monospacedDigit()
                            .lineLimit(1)
                        // En continuo, dónde vas en el capítulo: sin barra ni punto en la orilla.
                        if paper != nil, let done = location?.chapterDone {
                            ChapterLine(done: done, ink: color)
                        }
                    }
                        .padding(.horizontal, Theme.Space.l)
                        .frame(minHeight: Theme.Size.tapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .animation(Theme.Motion.standard, value: footerText)
                .contentTransition(.opacity)
                .accessibilityLabel("Pie de página")
                .accessibilityValue(footerText)
                .accessibilityHint("Elige qué dice")
                #if DEBUG
                .task {
                    // Demo «footer»: abre el globo del pie para capturarlo sin tocar la pantalla.
                    guard UserDefaults.standard.string(forKey: "screenshot.demo") == "footer" else { return }
                    try? await Task.sleep(for: .seconds(4))
                    choosing = true
                }
                #endif
                .popover(isPresented: $choosing, arrowEdge: .bottom) {
                    FooterPicker(options: options, selection: $footer, paper: pagePaper, ink: color) { choosing = false }
                        .presentationCompactAdaptation(.popover)
                }
                HStack {
                    counter
                    Spacer()
                }
                .padding(.leading, Theme.Reader.chromeInset)
            }
            .frame(maxWidth: .infinity, minHeight: Theme.Reader.pageMarginBottom)
            .background { band(.bottom) }
        }
        // La hoja llega hasta abajo: el pie va en su margen, hasta la orilla.
        .ignoresSafeArea(.container, edges: .bottom)
        .font(.caption.weight(.medium))
        .foregroundStyle(color.opacity(Theme.Emphasis.folio))
    }

    /// Papel sólido detrás del folio (hasta la orilla de la pantalla) y una
    /// orilla corta que se desvanece hacia el texto.
    @ViewBuilder
    private func band(_ edge: VerticalEdge) -> some View {
        if let paper {
            VStack(spacing: 0) {
                if edge == .bottom { paperFade(paper, toward: .top) }
                paper
                if edge == .top { paperFade(paper, toward: .bottom) }
            }
            // Sólido hasta la orilla del folio y el desvanecido ya fuera de él:
            // el texto nunca se asoma detrás del capítulo ni del pie.
            .padding(edge == .top ? .bottom : .top, -Theme.Reader.folioFade)
            // Abajo, el desvanecido baja un poco más: el sólido acaba justo arriba del pie.
            .padding(.top, edge == .bottom ? Theme.Reader.folioFadeDrop : 0)
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

}

/// El globo del pie: cuatro recortes chicos de la parte de abajo de la página, dos por
/// renglón, cada uno como se leerá; tocar uno lo elige y cierra.
private struct FooterPicker: View {
    let options: [FooterOption]
    @Binding var selection: ReaderFooter
    let paper: Color
    let ink: Color
    let done: () -> Void

    private let columns = [GridItem(.flexible(), spacing: Theme.Space.s), GridItem(.flexible(), spacing: Theme.Space.s)]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            SectionHeader("Abajo de la página")
            LazyVGrid(columns: columns, spacing: Theme.Space.s) {
                ForEach(options) { option in
                    Button {
                        selection = option.kind
                        done()
                    } label: {
                        FooterPreview(name: option.kind.name, text: option.text, paper: paper, ink: ink,
                                      available: option.available, selected: option.kind == selection)
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityAddTraits(option.kind == selection ? .isSelected : [])
                }
            }
        }
        .padding(Theme.Space.l)
        .frame(width: Theme.Size.footerPicker)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// El papel se aclara pronto y luego despacio (curva, no recta): la letra
/// se sigue leyendo mientras se va, en vez de quedar medio tapada. Sin `height`,
/// ocupa todo el alto que le den.
private func paperFade(_ paper: Color, toward edge: VerticalEdge, height: CGFloat? = Theme.Reader.folioFade) -> some View {
        let steps = Theme.Reader.folioFadeSteps
        let stops = (0...steps).map { step in
            let at = Double(step) / Double(steps), left = 1 - at
            return Gradient.Stop(color: paper.opacity(left * left), location: at)
        }
        return LinearGradient(stops: stops,
                              startPoint: edge == .bottom ? .top : .bottom, endPoint: edge == .bottom ? .bottom : .top)
            .frame(height: height)
}

#if os(iOS)
/// El lector dentro de sus hojas: la página se dobla con el dedo.
private struct ReaderWebView: UIViewControllerRepresentable {
    let controller: ReaderController
    func makeUIViewController(context: Context) -> ReaderPagesController {
        let pages = ReaderPagesController(webView: controller.makeWebView(), reader: controller)
        controller.pages = pages
        return pages
    }
    func updateUIViewController(_ pages: ReaderPagesController, context: Context) {}
}
#else
private struct ReaderWebView: NSViewRepresentable {
    let controller: ReaderController
    func makeNSView(context: Context) -> WKWebView { controller.makeWebView() }
    func updateNSView(_ webView: WKWebView, context: Context) {}
}
#endif
