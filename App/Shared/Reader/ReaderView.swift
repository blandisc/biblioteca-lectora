import SwiftUI
import WebKit

/// Pantalla de lectura. El WebView solo renderiza; la interfaz es nativa.
/// Tocar a la izquierda o a la derecha pasa de página, al centro muestra los
/// controles, y el toque largo selecciona texto para subrayar con lápiz.
struct ReaderView: View {
    let bookFile: URL
    /// Libro del catálogo; sus subrayados se guardan con este ID.
    var bookID: UUID? = nil
    @StateObject private var controller = ReaderController()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(AppearanceKeys.mode) private var mode: AppearanceMode = .system
    @State private var showsChrome = !LaunchOptions.hidesReaderChrome
    @State private var bookmarked = false
    @State private var showsAppearance = false
    @State private var noteText = ""
    @AppStorage(ReaderKeys.font) private var font: ReaderFont = .newYork
    @AppStorage(ReaderKeys.scale) private var scale = 1.0
    @AppStorage(ReaderKeys.theme) private var theme: ReaderTheme = .auto
    @AppStorage(ReaderKeys.autoNight) private var autoNight = true

    private var palette: ReaderPalette {
        ReaderPalette.resolve(theme, autoNight: autoNight, appIsDark: colorScheme == .dark)
    }

    private var title: String {
        controller.title ?? bookFile.deletingPathExtension().lastPathComponent
    }

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()
            ReaderWebView(controller: controller)
                .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .topTrailing) {
            if bookmarked {
                Ribbon()
                    .fill(Theme.pencil)
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
        .sheet(isPresented: $showsAppearance) {
            ReaderAppearanceSheet()
                .presentationDetents([.height(Theme.Size.appearanceSheet)])
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog("Subrayado", isPresented: Binding(
            get: { controller.tappedHighlight != nil },
            set: { if !$0 { controller.tappedHighlight = nil } }
        )) {
            Button("Borrar subrayado", role: .destructive) {
                if let cfi = controller.tappedHighlight { controller.removeHighlight(cfi: cfi) }
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
                if x < Theme.Reader.edgeZone {
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
            let resume = bookID.flatMap { LibraryStore.shared.position(for: $0)?.cfi }
            controller.open(bookFile: bookFile, bookID: bookID, lastCFI: resume)
        }
        .onChange(of: palette) { _, _ in applyStyle() }
        .onChange(of: font) { _, _ in applyStyle() }
        .onChange(of: scale) { _, _ in applyStyle() }
    }

    /// Controles de vidrio al tocar el centro (los dos estilos). Sin controles,
    /// el Editorial deja a la vista el capítulo y el porcentaje en pequeño.
    @ViewBuilder
    private var chrome: some View {
        ZStack {
            if !showsChrome {
                ReadingFolio(title: title, location: controller.location)
                    .transition(.opacity)
            }
            VStack(spacing: 0) {
                if showsChrome {
                    TopControls(bookmarked: $bookmarked, onClose: { dismiss() },
                                onAppearance: { showsAppearance = true })
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer(minLength: 0)
                if showsChrome {
                    BottomPanel(title: title, location: controller.location,
                                onSeek: { controller.goTo(fraction: $0) })
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    private func applyStyle() {
        controller.setColors(text: palette.text, link: palette.link)
        controller.setFont(family: font.css, scale: scale)
    }
}

private struct TopControls: View {
    @Binding var bookmarked: Bool
    let onClose: () -> Void
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
                Button {} label: {
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
                    withAnimation(.snappy) { bookmarked.toggle() }
                } label: {
                    Image(systemName: bookmarked ? "bookmark.fill" : "bookmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(bookmarked ? Theme.pencil : Theme.ink)
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

/// Panel inferior: el capítulo es el botón del índice, páginas en vez de
/// porcentaje y solo dos acciones grandes, Guiada y Escuchar.
private struct BottomPanel: View {
    let title: String
    let location: ReaderController.Location?
    let onSeek: (Double) -> Void
    @State private var dragValue: Double?

    private var fraction: Double { dragValue ?? location?.fraction ?? 0 }

    var body: some View {
        VStack(spacing: Theme.Space.s + Theme.Space.xxs) {
            HStack(alignment: .firstTextBaseline) {
                Button {} label: {
                    HStack(spacing: Theme.Space.xxs) {
                        Text(location?.chapter ?? title).lineLimit(1)
                        Image(systemName: "chevron.right").font(.caption.weight(.bold))
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .accessibilityLabel("Índice")
                Spacer()
                Text(fraction, format: .percent.precision(.fractionLength(0)))
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
                .padding(.top, -Theme.Space.s + Theme.Space.xxs)
            }
            HStack(spacing: Theme.Space.s) {
                Button {} label: {
                    Label("Guiada", systemImage: "text.viewfinder")
                        .frame(maxWidth: .infinity, minHeight: Theme.Size.tapTarget)
                        .background(Theme.field, in: Capsule())
                }
                Button {} label: {
                    Label("Escuchar", systemImage: "headphones")
                        .foregroundStyle(Theme.onInk)
                        .frame(maxWidth: .infinity, minHeight: Theme.Size.tapTarget)
                        .background(Theme.ink, in: Capsule())
                }
            }
            .font(.subheadline.weight(.medium))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, Theme.Space.l)
        .padding(.top, Theme.Space.m + Theme.Space.xxs)
        .padding(.bottom, Theme.Space.m)
        .glassPanel(cornerRadius: Theme.Radius.panel)
        .padding(.horizontal, Theme.Reader.chromeInset)
        .padding(.bottom, Theme.Space.s)
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
                .padding(.horizontal, Theme.Space.xxxl + Theme.Space.m)
                .padding(.top, Theme.Space.m + Theme.Space.xxs)
            Spacer()
            Text(location?.fraction ?? 0, format: .percent.precision(.fractionLength(0)))
                .monospacedDigit()
                .padding(.bottom, Theme.Space.xs + Theme.Space.xxs)
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
