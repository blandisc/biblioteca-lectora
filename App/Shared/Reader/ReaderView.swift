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
    @Environment(\.scenePhase) private var scenePhase
    @State private var showsSession = false
    /// El panel de abajo subido (con el pie y la sesión) o solo la tira.
    @State private var panelExpanded = false
    /// Hoja de herramientas abierta (índice, buscar o subrayados).
    @State private var tools: ReaderToolsSheet.Part?
    @AppStorage(AppearanceKeys.mode) private var mode: AppearanceMode = .system
    @State private var showsChrome = !LaunchOptions.hidesReaderChrome
    @ObservedObject private var library = LibraryStore.shared
    @State private var showsAppearance = false
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

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()
            ReaderWebView(controller: controller)
                .ignoresSafeArea(edges: .bottom)
            // Hasta que aparece la primera página: que se note que está trabajando.
            if controller.location == nil && controller.errorMessage == nil {
                VStack(spacing: Theme.Space.s) {
                    ProgressView()
                    Text("Abriendo el libro…").font(.footnote)
                }
                .foregroundStyle(palette.textColor)
                .tint(palette.textColor)
                .transition(.opacity)
                .accessibilityElement(children: .combine)
            }
        }
        .animation(Theme.Motion.standard, value: controller.location == nil)
        .overlay(alignment: .topTrailing) {
            // Con los controles a la vista, la barra de estado ocupa el borde y la cinta
            // tapaba la batería: ahí lo dice el ícono relleno del marcador.
            if currentBookmark != nil && !showsChrome {
                Ribbon()
                    .fill(Theme.accent)
                    .frame(width: Theme.Size.ribbon.width, height: Theme.Size.ribbon.height)
                    .padding(.trailing, Theme.Space.gutter)
                    .ignoresSafeArea(edges: .top)
                    .transition(.move(edge: .top))
                    .accessibilityHidden(true)
            }
        }
        .overlay { chrome }
        // Al esconder los controles, la próxima vez el panel sale como tira.
        .onChange(of: showsChrome) { _, shown in if !shown { panelExpanded = false } }
        #if os(iOS)
        .statusBarHidden(!showsChrome)
        #endif
        .preferredColorScheme(palette.scheme ?? mode.colorScheme)
        .sheet(item: $tools) { part in
            ReaderToolsSheet(controller: controller, bookID: bookID, part: part)
        }
        .overlay(alignment: .bottom) {
            if showsSession, let session = controller.session {
                ZStack(alignment: .bottom) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { showsSession = false }
                        .accessibilityHidden(true)
                    SessionCard(tracker: session, bookTitle: catalogTitle) { showsSession = false }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(Theme.Motion.standard, value: showsSession)
        #if os(iOS)
        // Solo el botón de arriba cierra el libro: deslizar de la orilla pasa la hoja.
        .interactiveDismissDisabled()
        #endif
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { controller.session?.resume() } else { controller.session?.pause() }
        }
        .onDisappear { controller.session?.finish() }
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
                    case .note: controller.highlightSelection(withNote: true)
                    case .toNote: controller.highlightSelection(toNote: true)
                    case .copy: controller.copySelection()
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
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
        .sheet(item: $controller.noteLinkTarget) { annotation in
            NoteLinkSheet(annotation: annotation, bookTitle: catalogTitle) { saved in
                controller.notice = "Se guardó en «\(saved.title)»."
            }
        }
        .alert("Nota", isPresented: Binding(
            get: { controller.noteTarget != nil },
            set: { if !$0 { controller.noteTarget = nil } }
        )) {
            TextField("Escribe tu nota", text: $noteText)
            Button("Guardar") { controller.saveNote(noteText); noteText = "" }
            Button("Cancelar", role: .cancel) { noteText = "" }
        } message: {
            Text(controller.noteTarget.map { "«\($0.quote)»" } ?? "")
        }
        .alert("No se pudo abrir el libro", isPresented: .constant(controller.errorMessage != nil)) {
            Button("OK", role: .cancel) { dismiss() }
        } message: {
            Text(controller.errorMessage ?? "")
        }
        .alert("Aviso", isPresented: Binding(
            get: { controller.notice != nil },
            set: { if !$0 { controller.notice = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(controller.notice ?? "")
        }
        .onAppear {
            applyStyle()
            // Sin capturar la vista: el controlador no debe retenerse a sí mismo.
            let chrome = $showsChrome
            controller.onTap = { [weak controller] x in
                // En continuo, como en Libros de Apple, tocar solo muestra u oculta los controles.
                if ReaderFlow.current == .scrolled {
                    withAnimation(Theme.Motion.standard) { chrome.wrappedValue.toggle() }
                } else if x < Theme.Reader.edgeZone {
                    controller?.previous()
                } else if x > 1 - Theme.Reader.edgeZone {
                    controller?.next()
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
                controller.search("Mancha")
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
        .onChange(of: flow) { _, _ in applyStyle() }
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
                             onFooter: {
                                 // Tocar el pie abre el panel ya subido: ahí se elige qué dice.
                                 panelExpanded = true
                                 withAnimation(Theme.Motion.standard) { showsChrome = true }
                             }) { EmptyView() }
                .transition(.opacity)
            }
            VStack(spacing: 0) {
                if showsChrome {
                    TopControls(bookmarked: currentBookmark != nil, onBookmark: toggleBookmark, onClose: { dismiss() },
                                onSearch: { tools = .search },
                                onAppearance: { showsAppearance = true })
                        .transition(.opacity)
                }
                Spacer(minLength: 0)
                if showsChrome {
                    BottomPanel(title: title, location: controller.location,
                                expanded: $panelExpanded,
                                options: footerOptions, footer: $footer,
                                paper: palette.background, ink: palette.textColor,
                                session: showsCounter ? controller.session : nil,
                                onSession: { withAnimation(Theme.Motion.standard) { showsChrome = false }; showsSession = true },
                                onContents: { tools = .contents },
                                onSeek: { controller.goTo(fraction: $0) })
                        .transition(.move(edge: .bottom).combined(with: .opacity))
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
            guard let bookID, let seconds = sessions.remaining(forBook: bookID, progress: fraction) else { return nil }
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
    /// Para revisar animaciones en video (`-screenshot.demo turns|flow`): pasa
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

    private func applyStyle() {
        controller.setColors(text: palette.text, link: palette.link)
        controller.setFont(family: font.css, scale: scale)
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
    let onSearch: () -> Void
    let onAppearance: () -> Void

    var body: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "chevron.down")
                    .font(.body.weight(.semibold))
                    .frame(width: Theme.Size.tapTarget, height: Theme.Size.tapTarget)
                    .glassCircle()
            }
            .accessibilityLabel("Cerrar libro")
            Spacer()
            HStack(spacing: 0) {
                Button(action: onSearch) {
                    Image(systemName: "magnifyingglass")
                        .font(.body.weight(.semibold))
                        .frame(width: Theme.Size.control, height: Theme.Size.tapTarget)
                }
                .accessibilityLabel("Buscar en el libro")
                Button(action: onAppearance) {
                    Text("Aa")
                        .font(.body.weight(.semibold))
                        .frame(width: Theme.Size.control, height: Theme.Size.tapTarget)
                }
                .accessibilityLabel("Apariencia")
                Button {
                    withAnimation(Theme.Motion.standard) { onBookmark() }
                } label: {
                    Image(systemName: bookmarked ? "bookmark.fill" : "bookmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(bookmarked ? Theme.accent : Theme.ink)
                        .frame(width: Theme.Size.control, height: Theme.Size.tapTarget)
                }
                .accessibilityLabel(bookmarked ? "Quitar marcador" : "Añadir marcador")
            }
            .padding(.horizontal, Theme.Space.xs)
            .glassPanel(cornerRadius: Theme.Radius.capsule)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, Theme.Reader.chromeInset)
    }
}

/// Panel de abajo al tocar el centro. Primero una tira mínima: la barra para
/// saltar y, debajo, el capítulo (abre el índice) y la página. Subiéndola con
/// el dedo (o tocando su rayita) aparece lo demás: qué dice el pie y la sesión.
private struct BottomPanel: View {
    let title: String
    let location: ReaderController.Location?
    @Binding var expanded: Bool
    let options: [FooterOption]
    @Binding var footer: ReaderFooter
    /// El papel y la tinta del libro: las muestras del pie se ven como la página.
    let paper: Color
    let ink: Color
    let session: SessionTracker?
    let onSession: () -> Void
    let onContents: () -> Void
    let onSeek: (Double) -> Void
    @State private var dragValue: Double?
    /// Cuántas veces ya se asomó el panel para decir que se sube (solo las primeras).
    @AppStorage(ReaderKeys.panelHints) private var hints = 0
    @State private var peek: CGFloat = 0

    private var fraction: Double { dragValue ?? location?.fraction ?? 0 }

    /// La página a la que apunta la barra (la de ahora o la del arrastre).
    private var page: Int? {
        guard let count = location?.pageCount, count > 0 else { return nil }
        guard let dragValue else { return location?.page }
        return min(count, max(1, Int((dragValue * Double(count)).rounded(.up))))
    }

    private var position: String {
        guard let page, let count = location?.pageCount else { return fraction.percentText }
        return dragValue == nil ? "\(page) de \(count)" : "Pág. \(page) · \(fraction.percentText)"
    }

    var body: some View {
        VStack(spacing: 0) {
            // La rayita: dice que se sube; tocarla también la sube o la baja.
            Button { withAnimation(Theme.Motion.sheet) { expanded.toggle() } } label: {
                Grabber()
                    .frame(maxWidth: .infinity, minHeight: Theme.Space.xl)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(expanded ? "Bajar el panel" : "Subir el panel")

            // Barra propia, fina y editorial: lo leído en tinta, una perilla chica.
            ScrubberBar(value: fraction, enabled: location != nil,
                        onChange: { dragValue = $0 },
                        onEnd: {
                            if let value = dragValue { onSeek(value) }
                            dragValue = nil
                        })
                .sensoryFeedback(.selection, trigger: fraction.percentText)
                .accessibilityLabel("Avance en el libro")
                .accessibilityValue(position)

            HStack(spacing: Theme.Space.m) {
                Button(action: onContents) {
                    HStack(spacing: Theme.Space.xs) {
                        Label(location?.chapter ?? title, systemImage: "list.bullet")
                            .lineLimit(1)
                        // La flecha dice que se toca, igual que en la línea de la sesión.
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.ink.opacity(Theme.Emphasis.glassText))
                    }
                        .frame(minHeight: Theme.Size.tapTarget)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Índice")
                .accessibilityValue(location?.chapter ?? title)
                Spacer(minLength: 0)
                // Quieto: la página. Arrastrando: a qué página y porcentaje vas.
                // Quieta, la sesión (la página ya está en el pie del libro): tocarla abre su tarjeta.
                if dragValue == nil, let session {
                    SessionLine(tracker: session, compact: true, action: onSession)
                        .transition(.opacity)
                } else if dragValue != nil || !expanded {
                Label(position, systemImage: "doc.text")
                    .monospacedDigit()
                    .foregroundStyle(dragValue == nil ? Theme.secondaryInk : Theme.ink)
                    .contentTransition(.numericText())
                    .animation(Theme.Motion.press, value: position)
                    .lineLimit(1)
                    .layoutPriority(1)
                    .transition(.opacity)
                }
            }
            .font(.footnote.weight(.medium))
            .labelStyle(QuietIconLabelStyle())

            if expanded {
                VStack(alignment: .leading, spacing: Theme.Space.s) {
                    SectionLabel(text: "Pie de página", tone: Theme.ink.opacity(Theme.Emphasis.glassText))
                    Grid(horizontalSpacing: Theme.Space.s, verticalSpacing: Theme.Space.s) {
                        ForEach(Array(stride(from: 0, to: options.count, by: 2)), id: \.self) { row in
                            GridRow {
                                ForEach(Array(options[row..<min(row + 2, options.count)].enumerated()), id: \.element.id) { offset, option in
                            Button { footer = option.kind } label: {
                                FooterPreview(symbol: option.kind.symbol, text: option.text, paper: paper, ink: ink,
                                              available: option.available, selected: option.kind == footer)
                            }
                            .buttonStyle(PressableStyle())
                            .accessibilityAddTraits(option.kind == footer ? .isSelected : [])
                            // Los cuatro entran igual: suben un poco y aparecen, uno tras otro.
                            .transition(.opacity.combined(with: .offset(y: Theme.Space.s))
                                .animation(Theme.Motion.sheet.delay(Theme.Motion.stagger * Double(row + offset))))
                                }
                            }
                        }
                    }
                }
                // Aire de grupo arriba; el rótulo, pegado a sus muestras.
                .padding(.top, Theme.Space.s)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
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
        .padding(.horizontal, Theme.Space.l)
        .padding(.bottom, Theme.Space.m)
        .glassPanel(cornerRadius: Theme.Radius.panel)
        // Todo el panel es suyo: un toque en su aire no llega a la página de abajo
        // (que lo tomaría como «ocultar controles»).
        .contentShape(Rectangle())
        .onTapGesture {}
        .offset(y: peek)
        .task {
            // Las primeras veces se asoma hacia arriba y regresa: hay más abajo de la barra.
            guard !expanded, hints < Theme.Reader.panelHints else { return }
            hints += 1
            try? await Task.sleep(for: .seconds(Theme.Reader.panelHintDelay))
            withAnimation(Theme.Motion.select) { peek = -Theme.Space.l }
            try? await Task.sleep(for: .seconds(Theme.Reader.panelHintHold))
            withAnimation(Theme.Motion.select) { peek = 0 }
        }
        .padding(.horizontal, Theme.Reader.chromeInset)
        .sensoryFeedback(.selection, trigger: footer)
        .sensoryFeedback(.impact(weight: .light), trigger: expanded)
        // Subir o bajar con el dedo, desde cualquier parte del panel menos la barra.
        .simultaneousGesture(
            DragGesture(minimumDistance: Theme.Size.panelSwipe)
                .onEnded { value in
                    guard dragValue == nil, abs(value.translation.height) > abs(value.translation.width) else { return }
                    withAnimation(Theme.Motion.sheet) { expanded = value.translation.height < 0 }
                }
        )
    }
}

/// Al tocar un subrayado: una tarjeta de vidrio con la cita y cuatro acciones
/// (nota, llevar a una nota, copiar, borrar), en lugar del menú del sistema.
private struct HighlightCard: View {
    enum Action { case note, toNote, copy, delete, close }
    let annotation: Annotation
    let perform: (Action) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            // La cita y la ✕ en un renglón, sin aire de sobra: la ✕ conserva su
            // área de toque pero no empuja la tarjeta hacia abajo.
            HStack(alignment: .center, spacing: Theme.Space.m) {
                QuoteBlock(text: annotation.quote, note: annotation.note, italic: true)
                    .lineLimit(Theme.Reader.highlightLines)
                Spacer(minLength: 0)
                Button { perform(.close) } label: {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.secondaryInk)
                        .frame(width: Theme.Size.tapTarget, height: Theme.Size.tapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cerrar")
                .padding(.vertical, -Theme.Space.s)
            }
            HStack(spacing: Theme.Space.s) {
                action(.note, annotation.note == nil ? "Nota" : "Editar nota", "square.and.pencil")
                action(.toNote, "A una nota", "note.text.badge.plus")
                action(.copy, "Copiar", "doc.on.doc")
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
    enum Action { case underline, note, toNote, copy }
    let perform: (Action) -> Void

    var body: some View {
        HStack(spacing: Theme.Space.s) {
            Button { perform(.underline) } label: {
                IconTile(symbol: "pencil.line", title: "Subrayar", prominent: true)
            }
            .buttonStyle(PressableStyle())
            item(.note, "Nota", "square.and.pencil")
            item(.toNote, "A una nota", "note.text.badge.plus")
            item(.copy, "Copiar", "doc.on.doc")
        }
        .padding(Theme.Space.s)
        .glassPanel(cornerRadius: Theme.Radius.panel)
        .padding(.horizontal, Theme.Reader.chromeInset)
        .padding(.bottom, Theme.Reader.chromeInset)
    }

    private func item(_ kind: Action, _ title: String, _ symbol: String) -> some View {
        Button { perform(kind) } label: { IconTile(symbol: symbol, title: title) }
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

/// Editorial sin controles: capítulo arriba y, abajo, el pie que elijas
/// (tiempo para terminar el capítulo o el libro, página o porcentaje). Tocando
/// el pie se abre un globo con las opciones, cada una con su dato de ahora.
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
    /// Tocar el pie: abre el panel con sus opciones.
    let onFooter: () -> Void
    /// El contador de palabras, en el mismo renglón que el pie.
    @ViewBuilder var counter: Counter

    var body: some View {
        VStack(spacing: 0) {
            // Capítulo y pie, cada uno centrado en el margen del texto: ni más
            // arriba ni más abajo, sin huecos. En continuo el capítulo sube, pegado
            // bajo la isla: se mide desde la orilla segura, que en cada iPhone
            // termina justo debajo de la isla (o de la muesca, o de la barra de estado),
            // y la franja de papel se acorta con él: queda más texto a la vista.
            Text(location?.chapter ?? title)
                .lineLimit(1)
                // Al cambiar de capítulo, un fundido corto, no un salto de letras.
                .contentTransition(.opacity)
                .animation(Theme.Motion.standard, value: location?.chapter)
                .padding(.horizontal, Theme.Reader.folioInset)
                .frame(maxWidth: .infinity, minHeight: paper == nil ? Theme.Reader.pageMarginTop : Theme.Reader.folioTop)
                .background { band(.top) }
                .allowsHitTesting(false)
            Spacer()
            ZStack {
                Button(action: onFooter) {
                    Text(footerText)
                        .monospacedDigit()
                        .lineLimit(1)
                        .padding(.horizontal, Theme.Space.m)
                        .frame(minHeight: Theme.Size.tapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .animation(Theme.Motion.standard, value: footerText)
                .contentTransition(.opacity)
                .accessibilityLabel("Pie de página")
                .accessibilityValue(footerText)
                .accessibilityHint("Elige qué dice")
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
                if edge == .bottom { fadeEdge(paper, toward: .top) }
                paper
                if edge == .top { fadeEdge(paper, toward: .bottom) }
            }
            // Sólido hasta la orilla del folio y el desvanecido ya fuera de él:
            // el texto nunca se asoma detrás del capítulo ni del pie.
            .padding(edge == .top ? .bottom : .top, -Theme.Reader.folioFade)
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    /// El papel se aclara pronto y luego despacio (curva, no recta): la letra
    /// se sigue leyendo mientras se va, en vez de quedar medio tapada.
    private func fadeEdge(_ paper: Color, toward edge: VerticalEdge) -> some View {
        let steps = Theme.Reader.folioFadeSteps
        let stops = (0...steps).map { step in
            let at = Double(step) / Double(steps), left = 1 - at
            return Gradient.Stop(color: paper.opacity(left * left), location: at)
        }
        return LinearGradient(stops: stops,
                              startPoint: edge == .bottom ? .top : .bottom, endPoint: edge == .bottom ? .bottom : .top)
            .frame(height: Theme.Reader.folioFade)
    }
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
