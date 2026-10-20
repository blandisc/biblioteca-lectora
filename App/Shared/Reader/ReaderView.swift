import SwiftUI
import WebKit

/// Pantalla de lectura (v7-Lector): papel a sangre y controles de vidrio que
/// aparecen al tocar el centro. El WebView solo renderiza; la interfaz es nativa.
struct ReaderView: View {
    let bookFile: URL
    @StateObject private var controller = ReaderController()
    @Environment(\.dismiss) private var dismiss
    @State private var showsChrome = true
    @State private var bookmarked = false

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
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
        .overlay(alignment: .top) {
            if showsChrome {
                TopControls(bookmarked: $bookmarked, onClose: { dismiss() })
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottom) {
            if showsChrome {
                BottomPanel(title: controller.title ?? bookFile.deletingPathExtension().lastPathComponent,
                            location: controller.location,
                            onSeek: { controller.goTo(fraction: $0) })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        #if os(iOS)
        .statusBarHidden(!showsChrome)
        #endif
        .alert("No se pudo abrir el libro", isPresented: .constant(controller.errorMessage != nil)) {
            Button("OK", role: .cancel) { dismiss() }
        } message: {
            Text(controller.errorMessage ?? "")
        }
        .onAppear { controller.open(bookFile: bookFile) }
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
