import Foundation
import WebKit

/// Estado y comandos del lector. Recibe los eventos de `reader.js`.
@MainActor
final class ReaderController: NSObject, ObservableObject, WKScriptMessageHandler {
    struct Location: Equatable {
        var fraction: Double
        var cfi: String?
        var chapter: String?
    }

    @Published private(set) var title: String?
    @Published private(set) var location: Location?
    @Published private(set) var selection: (cfi: String, text: String)?
    @Published private(set) var errorMessage: String?

    let schemeHandler = ReaderSchemeHandler()
    private(set) weak var webView: WKWebView?
    private var isReady = false
    private var pendingOpen: String?
    private var colorScript: String?

    func makeWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(schemeHandler, forURLScheme: ReaderSchemeHandler.scheme)
        // Sin ciclo de retención: el controlador solo guarda el WebView de forma débil.
        configuration.userContentController.add(self, name: "lectora")
        let webView = WKWebView(frame: .zero, configuration: configuration)
        #if os(iOS)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        #else
        webView.setValue(false, forKey: "drawsBackground")
        #endif
        #if DEBUG
        if #available(iOS 16.4, macOS 13.3, *) { webView.isInspectable = true }
        #endif
        webView.load(URLRequest(url: ReaderSchemeHandler.readerURL))
        self.webView = webView
        return webView
    }

    /// Abre un libro (copia local) y, si existe, vuelve a la última posición.
    func open(bookFile: URL, lastCFI: String? = nil) {
        schemeHandler.bookFile = bookFile
        let cfiArgument = lastCFI.map { "'\($0.replacingOccurrences(of: "'", with: "\\'"))'" } ?? "null"
        let script = "window.lectora.open('\(ReaderSchemeHandler.bookURL(for: bookFile).absoluteString)', \(cfiArgument))"
        if isReady { evaluate(script) } else { pendingOpen = script }
    }

    func next() { evaluate("window.lectora.next()") }
    func previous() { evaluate("window.lectora.prev()") }
    func goTo(fraction: Double) { evaluate("window.lectora.goToFraction(\(fraction))") }
    func setScrolled(_ scrolled: Bool) { evaluate("window.lectora.setFlow('\(scrolled ? "scrolled" : "paginated")')") }

    /// Colores del texto según el tema (hex CSS, p. ej. "#1C1B19").
    func setColors(text: String, link: String) {
        let script = "window.lectora.setStyle({ textColor: '\(text)', linkColor: '\(link)' })"
        colorScript = script
        if isReady { evaluate(script) }
    }

    private func evaluate(_ script: String) {
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    nonisolated func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        MainActor.assumeIsolated { handle(type: type, body: body) }
    }

    private func handle(type: String, body: [String: Any]) {
        switch type {
        case "ready":
            isReady = true
            if let colorScript { evaluate(colorScript) }
            if let pendingOpen {
                evaluate(pendingOpen)
                self.pendingOpen = nil
            }
        case "opened":
            title = body["title"] as? String
        case "relocate":
            location = Location(
                fraction: body["fraction"] as? Double ?? 0,
                cfi: body["cfi"] as? String,
                chapter: body["chapter"] as? String
            )
        case "selection":
            if let cfi = body["cfi"] as? String, let text = body["text"] as? String {
                selection = (cfi, text)
            }
        case "error":
            errorMessage = body["message"] as? String
        default:
            break
        }
    }
}
