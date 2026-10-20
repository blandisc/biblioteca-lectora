import SwiftUI
import WebKit

/// Pantalla de lectura: el WebView solo renderiza; la interfaz es nativa.
struct ReaderView: View {
    let bookFile: URL
    @StateObject private var controller = ReaderController()
    @State private var showsChrome = true

    var body: some View {
        ZStack {
            ReaderWebView(controller: controller)
                .ignoresSafeArea(edges: .bottom)
            // Zonas de toque nativas: izquierda = atrás, centro = interfaz, derecha = adelante.
            // (Siguiente paso de la prueba S1: arrastre interrumpible que sigue al dedo.)
            HStack(spacing: 0) {
                Color.clear.contentShape(Rectangle()).onTapGesture { controller.previous() }
                Color.clear.contentShape(Rectangle()).onTapGesture { withAnimation { showsChrome.toggle() } }
                Color.clear.contentShape(Rectangle()).onTapGesture { controller.next() }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if showsChrome, let location = controller.location {
                ProgressFooter(location: location) { controller.goTo(fraction: $0) }
            }
        }
        .navigationTitle(controller.title ?? bookFile.deletingPathExtension().lastPathComponent)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(showsChrome ? .visible : .hidden, for: .navigationBar)
        #endif
        .alert("No se pudo abrir el libro", isPresented: .constant(controller.errorMessage != nil)) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(controller.errorMessage ?? "")
        }
        .onAppear { controller.open(bookFile: bookFile) }
    }
}

private struct ProgressFooter: View {
    let location: ReaderController.Location
    let onSeek: (Double) -> Void
    @State private var dragValue: Double?

    var body: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(get: { dragValue ?? location.fraction }, set: { dragValue = $0 }),
                in: 0...1,
                onEditingChanged: { editing in
                    if !editing, let value = dragValue {
                        onSeek(value)
                        dragValue = nil
                    }
                }
            )
            HStack {
                Text(location.chapter ?? "")
                    .lineLimit(1)
                Spacer()
                Text(location.fraction, format: .percent.precision(.fractionLength(0)))
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
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
