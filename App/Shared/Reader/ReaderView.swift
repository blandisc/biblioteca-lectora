import SwiftUI
import WebKit

/// Pantalla de lectura. El WebView solo renderiza; la interfaz es nativa.
/// - Nativo (v7): controles de vidrio que aparecen al tocar el centro.
/// - Editorial (v5): capítulo y porcentaje siempre a la vista, en pequeño;
///   al tocar el centro, una barra de papel sin vidrio.
struct ReaderView: View {
    let bookFile: URL
    @StateObject private var controller = ReaderController()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(AppearanceKeys.style) private var style: DesignStyle = .native
    @AppStorage(AppearanceKeys.mode) private var mode: AppearanceMode = .system
    @State private var showsChrome = true
    @State private var bookmarked = false

    private var title: String {
        controller.title ?? bookFile.deletingPathExtension().lastPathComponent
    }

    var body: some View {
        ZStack {
            (style == .editorial ? Theme.Editorial.paper : Theme.paper).ignoresSafeArea()
            ReaderWebView(controller: controller)
                .ignoresSafeArea(edges: .bottom)
            // Zonas de toque nativas: izquierda = atrás, centro = controles, derecha = adelante.
            // (Siguiente paso de la prueba S1: arrastre interrumpible que sigue al dedo.)
            HStack(spacing: 0) {
                Color.clear.contentShape(Rectangle()).onTapGesture { controller.previous() }
                Color.clear.contentShape(Rectangle()).onTapGesture {
                    withAnimation(.snappy(duration: 0.25)) { showsChrome.toggle() }
                }
                Color.clear.contentShape(Rectangle()).onTapGesture { controller.next() }
            }
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
        .preferredColorScheme(mode.colorScheme)
        .alert("No se pudo abrir el libro", isPresented: .constant(controller.errorMessage != nil)) {
            Button("OK", role: .cancel) { dismiss() }
        } message: {
            Text(controller.errorMessage ?? "")
        }
        .onAppear {
            applyColors()
            controller.open(bookFile: bookFile)
        }
        .onChange(of: colorScheme) { _, _ in applyColors() }
    }

    @ViewBuilder
    private var chrome: some View {
        switch style {
        case .native:
            VStack(spacing: 0) {
                if showsChrome {
                    TopControls(bookmarked: $bookmarked, onClose: { dismiss() })
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer(minLength: 0)
                if showsChrome {
                    BottomPanel(title: title, location: controller.location,
                                onSeek: { controller.goTo(fraction: $0) })
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        case .editorial:
            EditorialReaderChrome(
                title: title, location: controller.location, showsControls: showsChrome,
                bookmarked: $bookmarked, onClose: { dismiss() },
                onSeek: { controller.goTo(fraction: $0) }
            )
        }
    }

    private func applyColors() {
        let colors = Theme.readerCSS(dark: colorScheme == .dark)
        controller.setColors(text: colors.text, link: colors.link)
    }
}

private struct TopControls: View {
    @Binding var bookmarked: Bool
    let onClose: () -> Void

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
                    Text("Aa")
                        .font(.body.weight(.semibold))
                        .frame(width: 48, height: 44)
                }
                .accessibilityLabel("Apariencia")
                Button {
                    withAnimation(.snappy) { bookmarked.toggle() }
                } label: {
                    Image(systemName: bookmarked ? "bookmark.fill" : "bookmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(bookmarked ? Theme.pencil : Theme.ink)
                        .frame(width: 48, height: 44)
                }
                .accessibilityLabel(bookmarked ? "Quitar marcador" : "Añadir marcador")
            }
            .glassPanel(cornerRadius: 22)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

private struct BottomPanel: View {
    let title: String
    let location: ReaderController.Location?
    let onSeek: (Double) -> Void
    @State private var dragValue: Double?

    private var fraction: Double { dragValue ?? location?.fraction ?? 0 }

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(location?.chapter ?? title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Text(fraction, format: .percent.precision(.fractionLength(0)))
                    .font(.subheadline)
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
            HStack {
                ReaderTool(title: "Índice", systemImage: "list.bullet")
                ReaderTool(title: "Buscar", systemImage: "magnifyingglass")
                ReaderTool(title: "Guiada", systemImage: "text.viewfinder")
                ReaderTool(title: "Escuchar", systemImage: "headphones")
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .glassPanel(cornerRadius: 28)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}

private struct ReaderTool: View {
    let title: String
    let systemImage: String

    var body: some View {
        Button {} label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage).font(.title3)
                Text(title).font(.caption2.weight(.medium))
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Lector Editorial (v5): folio y capítulo en pequeño; controles de papel al tocar.
private struct EditorialReaderChrome: View {
    let title: String
    let location: ReaderController.Location?
    let showsControls: Bool
    @Binding var bookmarked: Bool
    let onClose: () -> Void
    let onSeek: (Double) -> Void
    @State private var dragValue: Double?

    private var fraction: Double { dragValue ?? location?.fraction ?? 0 }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text(location?.chapter ?? title)
                    .font(.caption)
                    .foregroundStyle(Theme.tertiaryInk)
                    .lineLimit(1)
                    .padding(.horizontal, 90)
                if showsControls {
                    HStack(spacing: 18) {
                        Button("Listo", action: onClose)
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryInk)
                        Spacer()
                        Button {} label: { Text("Aa").font(.body.weight(.medium)) }
                            .accessibilityLabel("Apariencia")
                        Button {
                            withAnimation(.snappy) { bookmarked.toggle() }
                        } label: {
                            Image(systemName: bookmarked ? "bookmark.fill" : "bookmark")
                                .foregroundStyle(bookmarked ? Theme.pencil : Theme.ink)
                        }
                        .accessibilityLabel(bookmarked ? "Quitar marcador" : "Añadir marcador")
                    }
                    .transition(.opacity)
                }
            }
            .frame(minHeight: 44)
            .padding(.horizontal, 24)
            .background(showsControls ? Theme.Editorial.paper : .clear)

            Spacer(minLength: 0)

            if showsControls {
                VStack(spacing: 10) {
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
                    HStack {
                        ForEach(["Índice", "Buscar", "Guiada", "Escuchar"], id: \.self) { tool in
                            Button(tool) {}
                                .font(.footnote)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .background(Theme.Editorial.paper)
                .overlay(alignment: .top) { Rectangle().fill(Theme.track).frame(height: 0.5) }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Text(fraction, format: .percent.precision(.fractionLength(0)))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(Theme.tertiaryInk)
                .frame(maxWidth: .infinity, minHeight: 28)
                .background(showsControls ? Theme.Editorial.paper : .clear)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.ink)
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
