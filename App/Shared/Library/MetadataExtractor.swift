import Foundation
import PDFKit
import WebKit

/// Lo que trae el archivo de un libro.
struct ExtractedMetadata {
    var title: String?
    var authors: [String] = []
    var language: String?
    var publisher: String?
    var published: String?
    var summary: String?
    var tags: [String] = []
    var series: String?
    var seriesIndex: Double?
    var isbn: String?
    /// Imagen tal como viene (JPEG o PNG).
    var cover: Data?
}

/// Lee los datos de EPUB, MOBI, AZW3, FB2 y CBZ con el mismo motor del lector
/// (foliate-js, en un WebView invisible) y los de PDF con PDFKit.
@MainActor
final class MetadataExtractor: NSObject, WKNavigationDelegate {
    /// Un libro dañado puede no terminar nunca de abrirse: después de esto se
    /// importa con los datos del nombre del archivo.
    nonisolated static let timeout: Duration = .seconds(20)

    private let schemeHandler = ReaderSchemeHandler()
    /// La preparación del WebView se comparte: dos llamadas no crean dos WebViews.
    private var ready: Task<WKWebView, Error>?
    private var loading: CheckedContinuation<Void, Error>?

    /// `LibraryStore` llama de una en una (importaciones en fila).
    func extract(from file: URL) async throws -> ExtractedMetadata {
        if file.pathExtension.lowercased() == "pdf" {
            return await Task.detached(priority: .userInitiated) { Self.pdfMetadata(file) }.value
        }
        let webView = try await readyWebView()
        schemeHandler.bookFile = file
        let url = ReaderSchemeHandler.bookURL(for: file).absoluteString
        let result: Any?
        do {
            result = try await withThrowingTaskGroup(of: Any?.self) { group in
                group.addTask { @MainActor in
                    try await webView.callAsyncJavaScript("return await window.lectora.extract(url)",
                                                          arguments: ["url": url], contentWorld: .page)
                }
                group.addTask {
                    try await Task.sleep(for: Self.timeout)
                    throw CancellationError()
                }
                let first = try await group.next() ?? nil
                group.cancelAll()
                return first
            }
        } catch {
            // Se rehace el WebView: el anterior puede seguir atorado con ese libro.
            ready = nil
            throw error
        }
        guard let values = result as? [String: Any] else { return ExtractedMetadata() }
        var metadata = ExtractedMetadata()
        metadata.title = values["title"] as? String
        metadata.authors = values["authors"] as? [String] ?? []
        metadata.language = values["language"] as? String
        metadata.publisher = values["publisher"] as? String
        metadata.published = values["published"] as? String
        metadata.summary = values["description"] as? String
        metadata.tags = values["subjects"] as? [String] ?? []
        metadata.series = values["series"] as? String
        metadata.seriesIndex = values["seriesIndex"] as? Double
        metadata.isbn = values["isbn"] as? String
        if let dataURL = values["cover"] as? String, let comma = dataURL.firstIndex(of: ",") {
            metadata.cover = Data(base64Encoded: String(dataURL[dataURL.index(after: comma)...]))
        }
        return metadata
    }

    private func readyWebView() async throws -> WKWebView {
        if let ready { return try await ready.value }
        let task = Task { @MainActor in try await self.makeWebView() }
        ready = task
        do {
            return try await task.value
        } catch {
            ready = nil
            throw error
        }
    }

    private func makeWebView() async throws -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(schemeHandler, forURLScheme: ReaderSchemeHandler.scheme)
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 320, height: 480), configuration: configuration)
        webView.navigationDelegate = self
        try await withCheckedThrowingContinuation { continuation in
            loading = continuation
            webView.load(URLRequest(url: ReaderSchemeHandler.readerURL))
        }
        // El módulo del lector puede tardar un instante más que la página.
        _ = try await webView.callAsyncJavaScript("""
            await new Promise((resolve, reject) => {
                const start = Date.now()
                const check = () => window.lectora?.extract ? resolve(true)
                    : Date.now() - start > 10000 ? reject(new Error('El lector no cargó'))
                    : setTimeout(check, 50)
                check()
            })
            return true
            """, contentWorld: .page)
        return webView
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loading?.resume()
        loading = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loading?.resume(throwing: error)
        loading = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        loading?.resume(throwing: error)
        loading = nil
    }

    nonisolated static func pdfMetadata(_ file: URL) -> ExtractedMetadata {
        var metadata = ExtractedMetadata()
        guard let document = PDFDocument(url: file) else { return metadata }
        let attributes = document.documentAttributes ?? [:]
        metadata.title = attributes[PDFDocumentAttribute.titleAttribute] as? String
        if let author = attributes[PDFDocumentAttribute.authorAttribute] as? String {
            metadata.authors = author.components(separatedBy: CharacterSet(charactersIn: ";&"))
        }
        if let keywords = attributes[PDFDocumentAttribute.keywordsAttribute] as? [String] {
            metadata.tags = keywords
        }
        if let page = document.page(at: 0) {
            metadata.cover = CoverImaging.jpeg(from: page.thumbnail(of: CGSize(width: 800, height: 1200), for: .mediaBox))
        }
        return metadata
    }
}
