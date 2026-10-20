import Foundation
import LectoraCore
import WebKit

/// Estado y comandos del lector. Recibe los eventos de `reader.js`.
@MainActor
final class ReaderController: NSObject, ObservableObject, WKScriptMessageHandler {
    struct Location: Equatable {
        var fraction: Double
        var cfi: String?
        var chapter: String?
        /// Posición en «páginas» de foliate (ubicaciones de ~1,500 caracteres).
        var page: Int?
        var pageCount: Int?
    }

    @Published private(set) var title: String?
    @Published private(set) var location: Location?
    @Published private(set) var errorMessage: String?
    /// Subrayado que se tocó (CFI), para ofrecer borrarlo.
    @Published var tappedHighlight: String?
    /// Subrayado recién hecho al que se le está escribiendo una nota.
    @Published var noteTarget: Annotation?

    /// Toque en la página, con la posición horizontal de 0 a 1.
    var onTap: ((Double) -> Void)?

    let schemeHandler = ReaderSchemeHandler()
    private(set) weak var webView: WKWebView?
    private var isReady = false
    private var pendingOpen: String?
    private var colorScript: String?
    private var fontScript: String?
    private var bookID: UUID?

    func makeWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(schemeHandler, forURLScheme: ReaderSchemeHandler.scheme)
        // Sin ciclo de retención: el controlador solo guarda el WebView de forma débil.
        configuration.userContentController.add(self, name: "lectora")
        let webView = LectoraWebView(frame: .zero, configuration: configuration)
        webView.controller = self
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
        bookID = AnnotationStore.bookID(for: bookFile)
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

    /// Tipografía (pila CSS) y tamaño relativo de la letra.
    func setFont(family: String, scale: Double) {
        let script = "window.lectora.setStyle({ fontFamily: \(Self.js(family)), fontScale: \(scale) })"
        fontScript = script
        if isReady { evaluate(script) }
    }

    // MARK: Subrayados

    /// Subraya la selección actual con lápiz y la guarda. Con `withNote`, abre la nota.
    func highlightSelection(withNote: Bool = false) {
        webView?.evaluateJavaScript("window.lectora.takeSelection()") { [weak self] result, _ in
            MainActor.assumeIsolated {
                guard let self, let bookID = self.bookID,
                      let selection = result as? [String: Any],
                      let cfi = selection["cfi"] as? String,
                      let text = selection["text"] as? String
                else { return }
                let annotation = Annotation(
                    bookID: bookID, cfi: cfi, quote: text,
                    prefix: selection["prefix"] as? String, suffix: selection["suffix"] as? String,
                    color: "pencil"
                )
                do {
                    try AnnotationStore.shared.save(annotation)
                    self.evaluate("window.lectora.addHighlight(\(Self.js(cfi)))")
                    if withNote { self.noteTarget = annotation }
                } catch {
                    self.errorMessage = "No se pudo guardar el subrayado: \(error.localizedDescription)"
                }
            }
        }
    }

    func saveNote(_ note: String) {
        guard var annotation = noteTarget else { return }
        noteTarget = nil
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        annotation.note = trimmed
        try? AnnotationStore.shared.save(annotation)
    }

    func removeHighlight(cfi: String) {
        if let bookID, let annotation = AnnotationStore.shared.annotations(forBook: bookID).first(where: { $0.cfi == cfi }) {
            try? AnnotationStore.shared.delete(id: annotation.id)
        }
        evaluate("window.lectora.removeHighlight(\(Self.js(cfi)))")
    }

    private func restoreHighlights() {
        guard let bookID else { return }
        let values = AnnotationStore.shared.annotations(forBook: bookID).compactMap(\.cfi)
        guard !values.isEmpty,
              let data = try? JSONSerialization.data(withJSONObject: values),
              let array = String(data: data, encoding: .utf8)
        else { return }
        evaluate("window.lectora.setHighlights(\(array))")
    }

    /// Literal de cadena JavaScript seguro.
    private static func js(_ string: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [string]),
              let array = String(data: data, encoding: .utf8)
        else { return "''" }
        return String(array.dropFirst().dropLast())
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
            if let fontScript { evaluate(fontScript) }
            if let pendingOpen {
                evaluate(pendingOpen)
                self.pendingOpen = nil
            }
        case "opened":
            title = body["title"] as? String
            restoreHighlights()
        case "relocate":
            location = Location(
                fraction: body["fraction"] as? Double ?? 0,
                cfi: body["cfi"] as? String,
                chapter: body["chapter"] as? String,
                page: (body["current"] as? Int).map { $0 + 1 },
                pageCount: body["total"] as? Int
            )
        case "tap":
            if let x = body["x"] as? Double { onTap?(x) }
        case "annotation":
            tappedHighlight = body["cfi"] as? String
        case "error":
            errorMessage = body["message"] as? String
        default:
            break
        }
    }
}

/// WebView del lector con «Subrayar» y «Nota» en el menú de selección del sistema.
final class LectoraWebView: WKWebView {
    weak var controller: ReaderController?

    #if os(iOS)
    override func buildMenu(with builder: any UIMenuBuilder) {
        super.buildMenu(with: builder)
        guard builder.system == UIMenuSystem.context else { return }
        let underline = UIAction(title: "Subrayar", image: UIImage(systemName: "pencil.line")) { [weak self] _ in
            MainActor.assumeIsolated { self?.controller?.highlightSelection() }
        }
        let note = UIAction(title: "Nota", image: UIImage(systemName: "square.and.pencil")) { [weak self] _ in
            MainActor.assumeIsolated { self?.controller?.highlightSelection(withNote: true) }
        }
        builder.insertChild(UIMenu(options: .displayInline, children: [underline, note]), atStartOfMenu: .root)
    }
    #else
    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        super.willOpenMenu(menu, with: event)
        let underline = NSMenuItem(title: "Subrayar", action: #selector(underlineSelection), keyEquivalent: "")
        underline.target = self
        let note = NSMenuItem(title: "Subrayar con nota", action: #selector(underlineWithNote), keyEquivalent: "")
        note.target = self
        menu.insertItem(.separator(), at: 0)
        menu.insertItem(note, at: 0)
        menu.insertItem(underline, at: 0)
    }

    @objc private func underlineSelection() { controller?.highlightSelection() }
    @objc private func underlineWithNote() { controller?.highlightSelection(withNote: true) }
    #endif
}
