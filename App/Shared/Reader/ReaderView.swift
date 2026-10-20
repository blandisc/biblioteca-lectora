import SwiftUI
import WebKit

/// Pantalla de lectura. El WebView solo renderiza; la interfaz es nativa.
/// Tocar a la izquierda o a la derecha pasa de página, al centro muestra los
/// controles, y el toque largo selecciona texto para subrayar con lápiz.
struct ReaderView: View {
    let bookFile: URL
    @StateObject private var controller = ReaderController()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(AppearanceKeys.style) private var style: DesignStyle = .editorial
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
                    .frame(width: 12, height: 64)
                    .padding(.trailing, 28)
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
                .presentationDetents([.height(440)])
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
        .onAppear {
            applyStyle()
            controller.onTap = { x in
                if x < 0.28 {
                    controller.previous()
                } else if x > 0.72 {
                    controller.next()
                } else {
                    withAnimation(.snappy(duration: 0.25)) { showsChrome.toggle() }
                }
            }
            controller.open(bookFile: bookFile)
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
            if style == .editorial && !showsChrome {
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
                    .frame(width: 44, height: 44)
                    .glassCircle()
            }
            .accessibilityLabel("Cerrar libro")
            Spacer()
            HStack(spacing: 0) {
                Button {} label: {
                    Image(systemName: "magnifyingglass")
                        .font(.body.weight(.semibold))
                        .frame(width: 46, height: 44)
                }
                .accessibilityLabel("Buscar en el libro")
                Button(action: onAppearance) {
                    Text("Aa")
                        .font(.body.weight(.semibold))
                        .frame(width: 46, height: 44)
                }
                .accessibilityLabel("Apariencia")
                Button {
                    withAnimation(.snappy) { bookmarked.toggle() }
                } label: {
                    Image(systemName: bookmarked ? "bookmark.fill" : "bookmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(bookmarked ? Theme.pencil : Theme.ink)
                        .frame(width: 46, height: 44)
                }
                .accessibilityLabel(bookmarked ? "Quitar marcador" : "Añadir marcador")
            }
            .padding(.horizontal, 4)
            .glassPanel(cornerRadius: 22)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 16)
        .padding(.top, 8)
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
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Button {} label: {
                    HStack(spacing: 3) {
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
                .padding(.top, -6)
            }
            HStack(spacing: 8) {
                Button {} label: {
                    Label("Guiada", systemImage: "text.viewfinder")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Theme.ink.opacity(0.07), in: Capsule())
                }
                Button {} label: {
                    Label("Escuchar", systemImage: "headphones")
                        .foregroundStyle(Theme.onInk)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Theme.ink, in: Capsule())
                }
            }
            .font(.subheadline.weight(.medium))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .glassPanel(cornerRadius: 28)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
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
                .padding(.horizontal, 60)
                .padding(.top, 14)
            Spacer()
            Text(location?.fraction ?? 0, format: .percent.precision(.fractionLength(0)))
                .monospacedDigit()
                .padding(.bottom, 6)
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
