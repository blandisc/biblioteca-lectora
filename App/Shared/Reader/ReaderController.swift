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
        /// Palabras que faltan para terminar el capítulo (para «6 min para terminar el capítulo»).
        var chapterWordsLeft: Int? = nil
        /// Lo leído del capítulo, de 0 a 1 (la rayita bajo el pie en continuo).
        var chapterDone: Double? = nil
        /// Palabras que faltan para terminar el libro, estimadas por su largo.
        var bookWordsLeft: Int? = nil
    }

    @Published private(set) var title: String?
    /// El idioma del libro según el EPUB («en», «es-MX»…): de él salen la traducción y Wikipedia.
    @Published private(set) var language: String?
    /// Lo elegido para «Consultar» (SG-4): abre la tarjeta con traducción, Wikipedia y diccionario.
    @Published var lookup: String?

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
        /// La página del libro donde cae (como la cuenta el pie) y su lugar de 0 a 1.
        let page: Int?
        let fraction: Double
    }

    private static func searchResults(_ items: [[String: Any]], from start: Int) -> [SearchResult] {
        items.enumerated().compactMap { index, item in
            guard let cfi = item["cfi"] as? String else { return nil }
            return SearchResult(id: start + index, cfi: cfi, chapter: item["chapter"] as? String ?? "",
                                before: item["pre"] as? String ?? "", match: item["match"] as? String ?? "",
                                after: item["post"] as? String ?? "", page: item["page"] as? Int,
                                fraction: (item["fraction"] as? Double)?.readingFraction ?? 0)
        }
    }

    @Published private(set) var contents: [ContentsEntry] = []
    @Published private(set) var searchResults: [SearchResult] = []
    /// Búsqueda en curso (0 a 1), o `nil`.
    @Published private(set) var searchProgress: Double?
    @Published private(set) var searchedQuery = ""
    /// El resultado al que fuiste desde la lista: la barrita de la página sigue desde ahí.
    @Published var searchIndex: Int?
    @Published private(set) var location: Location?
    /// El libro ya sabe en qué página estás: al abrir, foliate acomoda el libro y
    /// avisa varias páginas seguidas («Página 23», luego «Página 27»). Hasta que deja
    /// de moverse no se ve ni la página ni un número.
    @Published private(set) var isSettled = false
    private var openSettle: Task<Void, Never>?
    /// Lo que dice el folio (capítulo y pie): mientras la hoja da vuelta se queda
    /// la página de antes; cambia cuando la nueva ya está a la vista, no antes.
    @Published private(set) var folioLocation: Location?
    /// La hoja está dando vuelta (lo marca `ReaderPagesController`).
    var isTurning = false { didSet { if !isTurning { folioLocation = location } } }
    /// CFI de los marcadores que caen en la página visible. Lo calcula reader.js
    /// comparando cada marcador con el principio y el final de la página, así
    /// la cinta sigue ahí aunque la página se vuelva a paginar (letra, controles).
    @Published private(set) var bookmarksOnPage: Set<String> = []
    @Published var errorMessage: String?
    /// Un subrayado que no se guardó: no impide seguir leyendo.
    @Published var saveError: String?
    /// Algo que salió bien y conviene saber (el pasaje quedó en una nota).
    @Published var notice: String?
    /// Subrayado que se tocó (CFI), para ofrecer borrarlo.
    @Published var tappedHighlight: String?
    /// Hay texto seleccionado: aparece la barra propia de la selección.
    @Published var hasSelection = false
    /// Subrayado recién hecho al que se le está escribiendo una nota.
    @Published var noteTarget: Annotation?
    /// Subrayado que se lleva a una nota del Cuaderno.
    @Published var noteLinkTarget: Annotation?
    /// La sesión de lectura de este libro (se mide mientras lees).
    @Published private(set) var session: SessionTracker?

    /// Toque en la página, con la posición horizontal de 0 a 1.
    var onTap: ((Double) -> Void)?
    /// Lectura guiada, el renglón (LG-B): si está puesta y dónde va la guía
    /// (arriba y alto, en puntos de la vista del libro). `nil` mientras se busca.
    @Published private(set) var guiding = false
    @Published private(set) var guideBand: ClosedRange<CGFloat>?
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
    private var flowScript: String?
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
        isSettled = false
        self.bookID = bookID ?? AnnotationStore.bookID(for: bookFile)
        // Solo los libros del catálogo tienen sesiones (para el diario y la ficha).
        session = bookID.map { SessionTracker(bookID: $0) }
        let cfiArgument = lastCFI.map(Self.js) ?? "null"
        let script = "window.lectora.open('\(ReaderSchemeHandler.bookURL(for: bookFile).absoluteString)', \(cfiArgument))"
        if isReady { evaluate(script) } else { pendingOpen = script }
    }

    func next() { turn(forward: true) }
    func previous() { turn(forward: false) }

    #if os(iOS)
    /// Las hojas del lector (la página que se dobla con el dedo).
    weak var pages: ReaderPagesController? { didSet { updateCurl() } }
    /// Color del papel, para la hoja que da vuelta.
    var pageBackground = UIColor(Theme.paper) { didSet { pages?.paper = pageBackground } }
    /// Cómo se pasa la hoja en páginas (se elige en «Aa»).
    var turnStyle: ReaderTurnStyle = .matte { didSet { updateCurl() } }
    #endif
    /// En páginas (no en continuo) se pasa como una hoja que da vuelta.
    private var isScrolled = false
    /// Con texto seleccionado no se dobla la hoja: el dedo está moviendo la selección.
    private var isSelecting = false
    private var atStart = false
    private var atEnd = false

    func canTurn(forward: Bool) -> Bool { forward ? !atEnd : !atStart }

    private func updateCurl() {
        #if os(iOS)
        pages?.drags = !isScrolled && !isSelecting
        // Con «reducir movimiento», la hoja no se mueve: se funde (o cambia al instante).
        let calm: ReaderTurnStyle = turnStyle == .none ? .none : .fade
        pages?.style = UIAccessibility.isReduceMotionEnabled ? calm : turnStyle
        pages?.paper = pageBackground
        pages?.spine = !isScrolled
        #endif
    }

    private func turn(forward: Bool) {
        #if os(iOS)
        if !isScrolled, let pages {
            pages.turn(forward: forward)
            return
        }
        if forward, canTurn(forward: true) { turnedForward() }
        #endif
        evaluate(forward ? "window.lectora.next()" : "window.lectora.prev()")
    }

    #if os(iOS)
    private let turnFeedback = UIImpactFeedbackGenerator(style: .soft)

    /// Un toque muy leve en la mano al pasar a la página siguiente (se apaga en «Aa»).
    func turnedForward() {
        guard UserDefaults.standard.object(forKey: ReaderKeys.haptics) as? Bool ?? true else { return }
        turnFeedback.impactOccurred(intensity: Theme.Reader.turnHaptic)
    }
    #endif

    /// Pasa de página sin animación y avisa si de verdad se movió.
    func turnInstantly(forward: Bool, done: @escaping (Bool) -> Void) {
        guard let webView else { done(false); return }
        webView.callAsyncJavaScript("return await window.lectora.turn(dir)",
                                    arguments: ["dir": forward ? 1 : -1], in: nil, in: .page) { result in
            done(((try? result.get()) as? Bool) ?? false)
        }
    }
    func goTo(fraction: Double) { evaluate("window.lectora.goToFraction(\(fraction))") }

    // MARK: Lectura guiada

    func startGuide() {
        guiding = true
        evaluate("window.lectora.guideStart(\(Theme.Reader.guideAnchor))")
    }
    /// Un renglón más (`forward`) o uno menos.
    func stepGuide(forward: Bool) { evaluate("window.lectora.guideStep(\(forward ? 1 : -1))") }
    func stopGuide() {
        guiding = false
        guideBand = nil
        evaluate("window.lectora.guideStop()")
    }

    /// La hendidura: el texto desde la página que ves hasta el fin del capítulo
    /// (o, con `nextChapter`, el capítulo siguiente entero). `nil` si no hay más.
    func slitText(nextChapter: Bool = false) async -> String? {
        guard let webView else { return nil }
        let script = nextChapter ? "return await window.lectora.slitNextSection()" : "return window.lectora.slitText()"
        let value = try? await webView.callAsyncJavaScript(script, contentWorld: .page)
        return (value as? [String: Any])?["text"] as? String
    }
    /// Al salir de la hendidura: el libro queda en el pedazo donde ibas.
    func slitGoTo(offset: Int) { evaluate("window.lectora.slitGoTo(\(offset))") }
    /// Ir a una entrada del índice, a un resultado o a un subrayado (href o CFI).
    func goTo(target: String) { evaluate("window.lectora.goTo(\(Self.js(target)))") }

    func search(_ query: String) {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        searchedQuery = text
        searchProgress = text.count >= 2 ? 0 : nil
        searchResults = []
        searchIndex = nil
        evaluate("window.lectora.search(\(Self.js(text)))")
    }

    /// Ir a un resultado de la búsqueda (por su lugar en la lista).
    func goToResult(_ index: Int) {
        guard searchResults.indices.contains(index) else { return }
        searchIndex = index
        goTo(target: searchResults[index].cfi)
    }

    func clearSearch() {
        searchIndex = nil
        searchedQuery = ""
        searchResults = []
        searchProgress = nil
        evaluate("window.lectora.clearSearch()")
    }
    /// Lo que ocupan arriba la isla y la barra de estado.
    private static var safeTop: CGFloat {
        #if os(iOS)
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        return (windows.first { $0.isKeyWindow } ?? windows.first)?.safeAreaInsets.top ?? 0
        #else
        0
        #endif
    }

    /// Páginas o continuo. Se guarda para mandarlo cuando el lector esté listo.
    func setScrolled(_ scrolled: Bool) {
        let changed = isReady && flowScript != nil && scrolled != isScrolled
        isScrolled = scrolled
        updateCurl()
        #if os(iOS)
        let curl = "true" // en el iPhone la página se dobla; en la Mac se desliza
        #else
        let curl = "false"
        #endif
        // En continuo el texto llega hasta la orilla de la pantalla (sin margen arriba);
        // el principio del capítulo sí empieza debajo de la isla.
        let top = scrolled ? 0 : Int(Theme.Reader.pageMarginTop)
        let scrollTop = Int(Self.safeTop + Theme.Reader.pageMarginTop)
        let script = "window.lectora.setStyle({ flow: '\(scrolled ? "scrolled" : "paginated")', curl: \(curl), "
            + "margin: \(top), marginBottom: \(Int(Theme.Reader.pageMarginBottom)), "
            + "scrollTop: \(scrollTop), textMargin: \(Int(Theme.Reader.textMargin)) })"
        flowScript = script
        guard isReady else { return }
        #if os(iOS)
        // Cambiar de forma con la página de antes desvaneciéndose encima, sin brinco.
        if changed, let pages {
            pages.dissolve { [weak self] settled in
                guard let self, let webView = self.webView else { settled(); return }
                self.evaluate(script)
                // La foto se va cuando el libro ya está acomodado, no a un tiempo fijo.
                webView.callAsyncJavaScript("await window.lectora.settled(ms)",
                                            arguments: ["ms": Theme.Reader.flowSettle.milliseconds],
                                            in: nil, in: .page) { _ in settled() }
            }
            return
        }
        #endif
        evaluate(script)
    }

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

    /// En continuo, el renglón que se lee arriba (un par de renglones bajo el desvanecido): su CFI y el
    /// texto que sigue. Es lo que guarda el marcador (MC-E1). `nil` si no hay renglón.
    func readingLine(_ done: @escaping (_ cfi: String, _ excerpt: String?) -> Void) {
        let y = Double(Self.safeTop + Theme.Reader.topFade)
        webView?.callAsyncJavaScript("return window.lectora.readingLine(y, lines)",
                                     arguments: ["y": y, "lines": Theme.Reader.bookmarkLinesBelowFade],
                                     in: nil, in: .page) { result in
            MainActor.assumeIsolated {
                guard case .success(let value) = result, let line = value as? [String: Any],
                      let cfi = line["cfi"] as? String else { return }
                done(cfi, line["excerpt"] as? String)
            }
        }
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
                    self.saveError = error.localizedDescription
                }
            }
        }
    }

    /// Copia el texto seleccionado y suelta la selección.
    func copySelection() {
        webView?.evaluateJavaScript("window.lectora.takeSelection()") { result, _ in
            MainActor.assumeIsolated {
                guard let text = (result as? [String: Any])?["text"] as? String else { return }
                #if os(iOS)
                UIPasteboard.general.string = text
                #else
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                #endif
            }
        }
    }

    /// «Consultar»: suelta la selección y abre la tarjeta con lo elegido.
    func lookUpSelection() {
        webView?.evaluateJavaScript("window.lectora.takeSelection()") { [weak self] result, _ in
            MainActor.assumeIsolated {
                guard let text = (result as? [String: Any])?["text"] as? String else { return }
                let term = WordLookup.term(from: text)
                guard !term.isEmpty else { return }
                self?.hasSelection = false
                self?.lookup = term
            }
        }
    }

    /// Suelta la selección sin hacer nada.
    func clearSelection() {
        evaluate("window.lectora.takeSelection()")
    }

    func saveNote(_ note: String) {
        guard var annotation = noteTarget else { return }
        noteTarget = nil
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        annotation.note = trimmed
        try? AnnotationStore.shared.save(annotation)
    }

    /// El subrayado que tocaste, para la tarjeta con sus acciones.
    var tappedAnnotation: Annotation? {
        guard let bookID, let cfi = tappedHighlight else { return nil }
        return AnnotationStore.shared.annotations(forBook: bookID).first { $0.cfi == cfi }
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
        MainActor.assumeIsolated {
            guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
            handle(type: type, body: body)
        }
    }

    private func handle(type: String, body: [String: Any]) {
        switch type {
        case "ready":
            isReady = true
            if let colorScript { evaluate(colorScript) }
            if let fontScript { evaluate(fontScript) }
            if let flowScript { evaluate(flowScript) }
            if let bookmarksScript { evaluate(bookmarksScript) }
            if let pendingOpen {
                evaluate(pendingOpen)
                self.pendingOpen = nil
            }
        case "opened":
            title = body["title"] as? String
            language = body["language"] as? String
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
            atStart = body["atStart"] as? Bool ?? false
            atEnd = body["atEnd"] as? Bool ?? false
            location = Location(
                fraction: fraction,
                cfi: body["cfi"] as? String,
                chapter: body["chapter"] as? String,
                chapterHref: body["chapterHref"] as? String,
                page: (body["current"] as? Int).map { $0 + 1 },
                pageCount: body["total"] as? Int,
                excerpt: body["excerpt"] as? String,
                chapterWordsLeft: body["chapterLeft"] as? Int,
                chapterDone: body["chapterDone"] as? Double,
                bookWordsLeft: body["bookLeft"] as? Int
            )
            if !isTurning { folioLocation = location }
            if !isSettled {
                openSettle?.cancel()
                openSettle = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(Theme.Reader.openSettle))
                    guard !Task.isCancelled else { return }
                    self?.isSettled = true
                }
            }
            session?.pageShown(words: body["words"] as? Int ?? 0,
                               fraction: fraction,
                               jumped: body["jumped"] as? Bool ?? false)
            settleTask?.cancel()
            if let location {
                settleTask = Task { [weak self] in
                    try? await Task.sleep(for: Theme.Reader.positionSettle)
                    guard !Task.isCancelled else { return }
                    self?.onPositionSettled?(location)
                }
            }
        case "searchProgress":
            if (body["query"] as? String) == searchedQuery { searchProgress = (body["progress"] as? Double)?.readingFraction }
        case "searchFound":
            // Lo que se va encontrando, capítulo por capítulo: siempre al final de la lista.
            guard (body["query"] as? String) == searchedQuery else { break }
            searchResults += Self.searchResults(body["results"] as? [[String: Any]] ?? [], from: searchResults.count)
        case "searchResults":
            guard (body["query"] as? String) == searchedQuery else { break }
            searchResults = Self.searchResults(body["results"] as? [[String: Any]] ?? [], from: 0)
            // Al terminar, queda entre las búsquedas recientes de este libro.
            if searchedQuery.count >= 2, let bookID { _ = RecentSearches.add(searchedQuery, count: searchResults.count, for: bookID) }
            searchProgress = nil
        case "anchored":
            guard let id = (body["id"] as? String).flatMap(UUID.init(uuidString:)), let cfi = body["cfi"] as? String,
                  var annotation = AnnotationStore.shared.annotation(id: id), annotation.cfi == nil else { break }
            annotation.cfi = cfi
            try? AnnotationStore.shared.save(annotation)
            evaluate("window.lectora.addHighlight(\(Self.js(cfi)))")
        case "guide":
            if let top = body["top"] as? Double, let height = body["height"] as? Double {
                guideBand = CGFloat(top)...CGFloat(top + height)
            } else {
                guideBand = nil
            }
        case "guideTurn":
            (body["dir"] as? Int ?? 1) > 0 ? next() : previous()
        case "tap":
            if let x = body["x"] as? Double { onTap?(x) }
        case "selecting":
            isSelecting = body["active"] as? Bool ?? false
            hasSelection = isSelecting
            updateCurl()
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
    /// Sin el menú negro del sistema: la barra de selección es de Gabinete
    /// (Subrayar, Nota, A una nota, Copiar), abajo, como la del subrayado.
    override func buildMenu(with builder: any UIMenuBuilder) {
        super.buildMenu(with: builder)
        guard builder.system == UIMenuSystem.context else { return }
        let menus: [UIMenu.Identifier] = [.standardEdit, .lookup, .learn, .share, .replace, .spelling,
                                          .spellingPanel, .spellingOptions, .substitutions, .transformations,
                                          .speech, .format, .textStyle, .autoFill]
        for menu in menus { builder.remove(menu: menu) }
        // Lo que WebKit agregue por su cuenta (traducir, etc.) también se va.
        for child in builder.menu(for: .root)?.children ?? [] {
            if let menu = child as? UIMenu { builder.remove(menu: menu.identifier) }
        }
        builder.replaceChildren(ofMenu: .root) { _ in [] }
    }
    #else
    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        super.willOpenMenu(menu, with: event)
        let underline = NSMenuItem(title: SelectionAction.highlight.title, action: #selector(underlineSelection), keyEquivalent: "")
        underline.target = self
        let note = NSMenuItem(title: SelectionAction.note.title, action: #selector(underlineWithNote), keyEquivalent: "")
        note.target = self
        let toNote = NSMenuItem(title: SelectionAction.toNote.title, action: #selector(underlineToNote), keyEquivalent: "")
        toNote.target = self
        let lookUp = NSMenuItem(title: SelectionAction.lookup.title, action: #selector(lookUpSelection), keyEquivalent: "")
        lookUp.target = self
        menu.insertItem(.separator(), at: 0)
        menu.insertItem(lookUp, at: 0)
        menu.insertItem(toNote, at: 0)
        menu.insertItem(note, at: 0)
        menu.insertItem(underline, at: 0)
    }

    @objc private func underlineSelection() { controller?.highlightSelection() }
    @objc private func underlineWithNote() { controller?.highlightSelection(withNote: true) }
    @objc private func underlineToNote() { controller?.highlightSelection(toNote: true) }
    @objc private func lookUpSelection() { controller?.lookUpSelection() }
    #endif
}
