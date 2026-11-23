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
        /// Entrada del índice del capítulo actual.
        var chapterHref: String? = nil
        /// Posición en «páginas» de foliate (ubicaciones de ~1,500 caracteres).
        var page: Int?
        var pageCount: Int?
        var excerpt: String?
    }

    @Published private(set) var title: String?

    /// Una entrada del índice del libro.
    struct ContentsEntry: Identifiable, Equatable {
        let id: Int
        let label: String
        let href: String?
        /// 0 = capítulo; 1, 2… = secciones dentro.
        let depth: Int
    }

    /// Un resultado de buscar en el libro: el texto alrededor y dónde está.
    struct SearchResult: Identifiable, Equatable {
        let id: Int
        let cfi: String
        let chapter: String
        let before: String
        let match: String
        let after: String
    }

    @Published private(set) var contents: [ContentsEntry] = []
    @Published private(set) var searchResults: [SearchResult] = []
    /// Búsqueda en curso (0 a 1), o `nil`.
    @Published private(set) var searchProgress: Double?
    @Published private(set) var searchedQuery = ""
    @Published private(set) var location: Location?
    /// CFI de los marcadores que caen en la página visible. Lo calcula reader.js
    /// comparando cada marcador con el principio y el final de la página, así
    /// la cinta sigue ahí aunque la página se vuelva a paginar (letra, controles).
    @Published private(set) var bookmarksOnPage: Set<String> = []
    @Published var errorMessage: String?
    /// Avisos que no impiden seguir leyendo (p. ej. un subrayado que no se guardó).
    @Published var notice: String?
    /// Subrayado que se tocó (CFI), para ofrecer borrarlo.
    @Published var tappedHighlight: String?
    /// Subrayado recién hecho al que se le está escribiendo una nota.
    @Published var noteTarget: Annotation?
    /// Subrayado que se lleva a una nota del Cuaderno.
    @Published var noteLinkTarget: Annotation?
    /// La sesión de lectura de este libro (se mide mientras lees).
    @Published private(set) var session: SessionTracker?

    /// Toque en la página, con la posición horizontal de 0 a 1.
    var onTap: ((Double) -> Void)?
    /// Nueva posición, ya asentada (un instante después de pasar página).
    var onPositionSettled: ((Location) -> Void)?
    private var settleTask: Task<Void, Never>?

    let schemeHandler = ReaderSchemeHandler()
    private(set) weak var webView: WKWebView?
    private var isReady = false
    private var pendingOpen: String?
    private var colorScript: String?
    private var bookmarksScript: String?
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
    func open(bookFile: URL, bookID: UUID? = nil, lastCFI: String? = nil) {
        schemeHandler.bookFile = bookFile
        self.bookID = bookID ?? AnnotationStore.bookID(for: bookFile)
        // Solo los libros del catálogo tienen sesiones (para el diario y la ficha).
        session = bookID.map { SessionTracker(bookID: $0) }
        let cfiArgument = lastCFI.map(Self.js) ?? "null"
        let script = "window.lectora.open('\(ReaderSchemeHandler.bookURL(for: bookFile).absoluteString)', \(cfiArgument))"
        if isReady { evaluate(script) } else { pendingOpen = script }
    }

    func next() { evaluate("window.lectora.next()") }
    func previous() { evaluate("window.lectora.prev()") }
    func goTo(fraction: Double) { evaluate("window.lectora.goToFraction(\(fraction))") }
    /// Ir a una entrada del índice, a un resultado o a un subrayado (href o CFI).
    func goTo(target: String) { evaluate("window.lectora.goTo(\(Self.js(target)))") }

    func search(_ query: String) {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        searchedQuery = text
        searchProgress = text.count >= 2 ? 0 : nil
        if text.count < 2 { searchResults = [] }
        evaluate("window.lectora.search(\(Self.js(text)))")
    }

    func clearSearch() {
        searchedQuery = ""
        searchResults = []
        searchProgress = nil
        evaluate("window.lectora.clearSearch()")
    }
    func setScrolled(_ scrolled: Bool) { evaluate("window.lectora.setFlow('\(scrolled ? "scrolled" : "paginated")')") }

    /// Colores del texto según el tema (hex CSS, p. ej. "#1C1B19").
    func setColors(text: String, link: String) {
        let script = "window.lectora.setStyle({ textColor: '\(text)', linkColor: '\(link)' })"
        colorScript = script
        if isReady { evaluate(script) }
    }

    /// Los marcadores del libro (sus CFI), para saber cuáles caen en la página.
    func setBookmarks(_ cfis: [String]) {
        guard let data = try? JSONSerialization.data(withJSONObject: cfis),
              let json = String(data: data, encoding: .utf8) else { return }
        let script = "window.lectora.setBookmarks(\(json))"
        bookmarksScript = script
        if isReady { evaluate(script) }
    }

    /// Tipografía (pila CSS) y tamaño relativo de la letra.
    func setFont(family: String, scale: Double) {
        let script = "window.lectora.setStyle({ fontFamily: \(Self.js(family)), fontScale: \(scale) })"
        fontScript = script
        if isReady { evaluate(script) }
    }

    // MARK: Subrayados

    /// Subraya la selección actual con lápiz y la guarda. Con `withNote`, abre la
    /// nota del subrayado; con `toNote`, la hoja para llevarlo a una nota del Cuaderno.
    func highlightSelection(withNote: Bool = false, toNote: Bool = false) {
        webView?.evaluateJavaScript("window.lectora.takeSelection()") { [weak self] result, _ in
            MainActor.assumeIsolated {
                guard let self, let bookID = self.bookID,
                      let selection = result as? [String: Any],
                      let cfi = selection["cfi"] as? String,
                      let text = selection["text"] as? String
                else { return }
                // El mismo pasaje subrayado dos veces es un solo subrayado.
                if let existing = AnnotationStore.shared.annotations(forBook: bookID).first(where: { $0.cfi == cfi }) {
                    if toNote { self.noteLinkTarget = existing }
                    return
                }
                let annotation = Annotation(
                    bookID: bookID, cfi: cfi, quote: text,
                    prefix: selection["prefix"] as? String, suffix: selection["suffix"] as? String,
                    color: "pencil"
                )
                do {
                    try AnnotationStore.shared.save(annotation)
                    self.evaluate("window.lectora.addHighlight(\(Self.js(cfi)))")
                    if withNote { self.noteTarget = annotation }
                    if toNote { self.noteLinkTarget = annotation }
                } catch {
                    self.notice = "No se pudo guardar el subrayado: \(error.localizedDescription)"
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

    /// «Llevar a una nota» desde un subrayado que ya existe.
    func sendToNote(cfi: String) {
        guard let bookID else { return }
        noteLinkTarget = AnnotationStore.shared.annotations(forBook: bookID).first { $0.cfi == cfi }
    }

    func removeHighlight(cfi: String) {
        if let bookID {
            for annotation in AnnotationStore.shared.annotations(forBook: bookID) where annotation.cfi == cfi {
                try? AnnotationStore.shared.delete(id: annotation.id)
            }
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

    /// Subrayados que llegaron sin posición (Calibre, Kindle): se buscan una
    /// vez por su cita; los que se encuentran se pintan y se guardan con su lugar.
    private func anchorPending() {
        guard let bookID else { return }
        var tried = Set(UserDefaults.standard.stringArray(forKey: Self.anchorTriedKey) ?? [])
        let pending = AnnotationStore.shared.annotations(forBook: bookID)
            .filter { $0.cfi == nil && !tried.contains($0.id.uuidString) }
        guard !pending.isEmpty,
              let data = try? JSONSerialization.data(withJSONObject: pending.map { ["id": $0.id.uuidString, "queries": QuoteAnchor.queries(for: $0.quote)] as [String: Any] }),
              let array = String(data: data, encoding: .utf8)
        else { return }
        pending.forEach { tried.insert($0.id.uuidString) }
        UserDefaults.standard.set(Array(tried), forKey: Self.anchorTriedKey)
        evaluate("window.lectora.anchor(\(array))")
    }

    /// v2 (22 nov 2026): con `QuoteAnchor` se vuelven a buscar los que no aparecieron antes.
    private static let anchorTriedKey = "subrayados.anclajeIntentado.v2"

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
            if let bookmarksScript { evaluate(bookmarksScript) }
            if let pendingOpen {
                evaluate(pendingOpen)
                self.pendingOpen = nil
            }
        case "opened":
            title = body["title"] as? String
            let entries = (body["toc"] as? [[String: Any]]) ?? []
            contents = entries.enumerated().compactMap { index, entry in
                guard let label = entry["label"] as? String, !label.isEmpty else { return nil }
                return ContentsEntry(id: index, label: label, href: entry["href"] as? String, depth: entry["depth"] as? Int ?? 0)
            }
            restoreHighlights()
            anchorPending()
        case "marks":
            bookmarksOnPage = Set(body["cfis"] as? [String] ?? [])
        case "relocate":
            // Un avance que no es número (NaN de foliate en secciones de dos páginas)
            // no mueve nada: se queda el último bueno.
            let fraction = (body["fraction"] as? Double)?.readingFraction ?? location?.fraction ?? 0
            location = Location(
                fraction: fraction,
                cfi: body["cfi"] as? String,
                chapter: body["chapter"] as? String,
                chapterHref: body["chapterHref"] as? String,
                page: (body["current"] as? Int).map { $0 + 1 },
                pageCount: body["total"] as? Int,
                excerpt: body["excerpt"] as? String
            )
            session?.pageShown(words: body["words"] as? Int ?? 0,
                               fraction: fraction,
                               jumped: body["jumped"] as? Bool ?? false)
            settleTask?.cancel()
            if let location {
                settleTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(1.5))
                    guard !Task.isCancelled else { return }
                    self?.onPositionSettled?(location)
                }
            }
        case "searchProgress":
            if (body["query"] as? String) == searchedQuery { searchProgress = (body["progress"] as? Double)?.readingFraction }
        case "searchResults":
            guard (body["query"] as? String) == searchedQuery else { break }
            searchProgress = nil
            searchResults = ((body["results"] as? [[String: Any]]) ?? []).enumerated().compactMap { index, item in
                guard let cfi = item["cfi"] as? String else { return nil }
                return SearchResult(id: index, cfi: cfi, chapter: item["chapter"] as? String ?? "",
                                    before: item["pre"] as? String ?? "", match: item["match"] as? String ?? "",
                                    after: item["post"] as? String ?? "")
            }
        case "anchored":
            guard let id = (body["id"] as? String).flatMap(UUID.init(uuidString:)), let cfi = body["cfi"] as? String,
                  var annotation = AnnotationStore.shared.annotation(id: id), annotation.cfi == nil else { break }
            annotation.cfi = cfi
            try? AnnotationStore.shared.save(annotation)
            evaluate("window.lectora.addHighlight(\(Self.js(cfi)))")
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
        let toNote = UIAction(title: "A una nota", image: UIImage(systemName: "note.text.badge.plus")) { [weak self] _ in
            MainActor.assumeIsolated { self?.controller?.highlightSelection(toNote: true) }
        }
        builder.insertChild(UIMenu(options: .displayInline, children: [underline, note, toNote]), atStartOfMenu: .root)
    }
    #else
    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        super.willOpenMenu(menu, with: event)
        let underline = NSMenuItem(title: "Subrayar", action: #selector(underlineSelection), keyEquivalent: "")
        underline.target = self
        let note = NSMenuItem(title: "Subrayar con nota", action: #selector(underlineWithNote), keyEquivalent: "")
        note.target = self
        let toNote = NSMenuItem(title: "Llevar a una nota", action: #selector(underlineToNote), keyEquivalent: "")
        toNote.target = self
        menu.insertItem(.separator(), at: 0)
        menu.insertItem(toNote, at: 0)
        menu.insertItem(note, at: 0)
        menu.insertItem(underline, at: 0)
    }

    @objc private func underlineSelection() { controller?.highlightSelection() }
    @objc private func underlineWithNote() { controller?.highlightSelection(withNote: true) }
    @objc private func underlineToNote() { controller?.highlightSelection(toNote: true) }
    #endif
}
