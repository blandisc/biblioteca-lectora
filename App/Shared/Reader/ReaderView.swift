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
    @AppStorage(SessionKeys.counter) private var showsCounter = true
    @State private var showsSession = false
    /// Hoja de herramientas abierta (índice, buscar o subrayados).
    @State private var tools: ReaderToolsSheet.Part?
    @AppStorage(AppearanceKeys.mode) private var mode: AppearanceMode = .system
    @State private var showsChrome = !LaunchOptions.hidesReaderChrome
    @ObservedObject private var library = LibraryStore.shared
    @State private var showsAppearance = false
    @State private var noteText = ""
    @AppStorage(ReaderKeys.font) private var font: ReaderFont = .newYork
    @AppStorage(ReaderKeys.scale) private var scale = 1.0
    @AppStorage(ReaderKeys.theme) private var theme: ReaderTheme = .auto
    @AppStorage(ReaderKeys.autoNight) private var autoNight = true
    @AppStorage(ReaderKeys.flow) private var flow: ReaderFlow = .paged

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
        #if os(iOS)
        .statusBarHidden(!showsChrome)
        #endif
        .preferredColorScheme(palette.scheme ?? mode.colorScheme)
        .sheet(item: $tools) { part in
            ReaderToolsSheet(controller: controller, bookID: bookID, part: part)
        }
        .sheet(isPresented: $showsSession) {
            if let session = controller.session {
                SessionSheet(tracker: session, bookTitle: catalogTitle, fraction: controller.location?.fraction ?? 0)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { controller.session?.resume() } else { controller.session?.pause() }
        }
        .onDisappear { controller.session?.finish() }
        .sheet(isPresented: $showsAppearance) {
            ReaderAppearanceSheet()
                .presentationDetents([.height(Theme.Size.appearanceSheet)])
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog("Subrayado", isPresented: Binding(
            get: { controller.tappedHighlight != nil },
            set: { if !$0 { controller.tappedHighlight = nil } }
        )) {
            Button("Llevar a una nota") {
                if let cfi = controller.tappedHighlight { controller.sendToNote(cfi: cfi) }
            }
            Button("Borrar subrayado", role: .destructive) {
                if let cfi = controller.tappedHighlight { controller.removeHighlight(cfi: cfi) }
            }
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
        }
        .onChange(of: bookmarkCFIs, initial: true) { _, cfis in controller.setBookmarks(cfis) }
        .onChange(of: palette) { _, _ in applyStyle() }
        .onChange(of: font) { _, _ in applyStyle() }
        .onChange(of: scale) { _, _ in applyStyle() }
        .onChange(of: flow) { _, _ in applyStyle() }
    }

    /// Controles de vidrio al tocar el centro (los dos estilos). Sin controles,
    /// el Editorial deja a la vista el capítulo y el porcentaje en pequeño.
    @ViewBuilder
    private var chrome: some View {
        ZStack {
            if !showsChrome {
                ReadingFolio(title: title, location: controller.location)
                    .transition(.opacity)
                if showsCounter, let session = controller.session {
                    SessionCounter(tracker: session) { showsSession = true }
                        .transition(.opacity)
                }
            }
            VStack(spacing: 0) {
                if showsChrome {
                    TopControls(bookmarked: currentBookmark != nil, onBookmark: toggleBookmark, onClose: { dismiss() },
                                onSearch: { tools = .search },
                                onAppearance: { showsAppearance = true })
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer(minLength: 0)
                if showsChrome {
                    BottomPanel(title: title, location: controller.location,
                                onContents: { tools = .contents },
                                onSeek: { controller.goTo(fraction: $0) })
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
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

    private func applyStyle() {
        controller.setColors(text: palette.text, link: palette.link)
        controller.setFont(family: font.css, scale: scale)
        controller.setScrolled(flow == .scrolled)
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
        .padding(.top, Theme.Space.s)
    }
}

/// Panel inferior: el capítulo es el botón del índice y páginas en vez de
/// porcentaje. Guiada y Escuchar aparecen cuando llegue el audiolibro.
private struct BottomPanel: View {
    let title: String
    let location: ReaderController.Location?
    let onContents: () -> Void
    let onSeek: (Double) -> Void
    @State private var dragValue: Double?

    private var fraction: Double { dragValue ?? location?.fraction ?? 0 }

    var body: some View {
        VStack(spacing: Theme.Space.rowY) {
            HStack(alignment: .firstTextBaseline) {
                Button(action: onContents) {
                    HStack(spacing: Theme.Space.xxs) {
                        Text(location?.chapter ?? title).lineLimit(1)
                        Image(systemName: "chevron.right").font(.caption.weight(.bold))
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .accessibilityLabel("Índice")
                Spacer()
                Text((fraction).percentText)
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(Theme.secondaryInk)
            }
            Slider(
                value: Binding(get: { fraction }, set: { dragValue = $0 }),
                in: 0...1,
                onEditingChanged: { editing in
                    if !editing, let value = dragValue {
                        onSeek(value)
                        dragValue = nil
                    }
                }
            )
            .disabled(location == nil)
            if let page = location?.page, let count = location?.pageCount, count > 0 {
                HStack {
                    Text("Pág. \(page)")
                    Spacer()
                    Text("de \(count)")
                }
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(Theme.secondaryInk)
                .padding(.top, -Theme.Space.inline)
            }
            if Features.audiobook {
                HStack(spacing: Theme.Space.s) {
                    ReaderPillButton(title: "Guiada", systemImage: "text.viewfinder") {}
                    ReaderPillButton(title: "Escuchar", systemImage: "headphones", prominent: true) {}
                }
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, Theme.Space.l)
        .padding(.top, Theme.Space.rowGap)
        .padding(.bottom, Theme.Space.m)
        .glassPanel(cornerRadius: Theme.Radius.panel)
        .padding(.horizontal, Theme.Reader.chromeInset)
        .padding(.bottom, Theme.Space.s)
    }
}

/// Contador de la sesión, abajo a la izquierda, a la altura del porcentaje.
private struct SessionCounter: View {
    @ObservedObject var tracker: SessionTracker
    let action: () -> Void

    var body: some View {
        VStack {
            Spacer()
            HStack {
                WordCounter(words: tracker.words, action: action)
                Spacer()
            }
        }
        .padding(.leading, Theme.Reader.chromeInset)
    }
}

/// Editorial sin controles: capítulo arriba y porcentaje abajo, en pequeño.
private struct ReadingFolio: View {
    let title: String
    let location: ReaderController.Location?

    var body: some View {
        VStack {
            Text(location?.chapter ?? title)
                .lineLimit(1)
                .padding(.horizontal, Theme.Reader.folioInset)
                .padding(.top, Theme.Reader.folioTop)
            Spacer()
            Text((location?.fraction ?? 0).percentText)
                .monospacedDigit()
                .padding(.bottom, Theme.Space.inline)
        }
        .font(.caption)
        .foregroundStyle(Theme.tertiaryInk)
        .allowsHitTesting(false)
    }
}

#if os(iOS)
private struct ReaderWebView: UIViewRepresentable {
    let controller: ReaderController
    func makeUIView(context: Context) -> WKWebView { controller.makeWebView() }
    func updateUIView(_ webView: WKWebView, context: Context) {}
}
#else
private struct ReaderWebView: NSViewRepresentable {
    let controller: ReaderController
    func makeNSView(context: Context) -> WKWebView { controller.makeWebView() }
    func updateNSView(_ webView: WKWebView, context: Context) {}
}
#endif
