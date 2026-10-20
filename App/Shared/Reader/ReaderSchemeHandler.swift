import Foundation
import UniformTypeIdentifiers
import WebKit

/// Sirve el lector (HTML + foliate-js) y el libro abierto bajo `lectora://app/…`.
///
/// Usar un esquema propio en lugar de `file://` permite cargar módulos ES y
/// aplicar una Content-Security-Policy que bloquea los scripts de los libros.
final class ReaderSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "lectora"
    static let readerURL = URL(string: "lectora://app/reader.html")!

    /// URL del libro actual. Lleva la extensión real porque foliate-js la usa
    /// para distinguir formatos (p. ej. CBZ frente a EPUB, ambos ZIP).
    static func bookURL(for file: URL) -> URL {
        URL(string: "lectora://app/book.\(file.pathExtension.lowercased())")!
    }

    private let readerDirectory: URL?
    /// Archivo del libro actual (copia local dentro del contenedor de la app).
    var bookFile: URL?

    init(bundle: Bundle = .main) {
        readerDirectory = bundle.url(forResource: "Reader", withExtension: nil)
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }
        let fileURL: URL?
        if url.path.hasPrefix("/book.") {
            fileURL = bookFile
        } else {
            let relative = String(url.path.drop(while: { $0 == "/" }))
            fileURL = readerDirectory.flatMap { directory in
                let candidate = directory.appendingPathComponent(relative).standardizedFileURL
                // No permitir salir de la carpeta del lector con "../".
                return candidate.path.hasPrefix(directory.standardizedFileURL.path) ? candidate : nil
            }
        }
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": Self.mimeType(for: fileURL),
                "Content-Length": String(data.count),
                "Cache-Control": "no-store",
            ]
        )!
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

    static func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "js", "mjs": return "text/javascript"
        case "html": return "text/html"
        case "css": return "text/css"
        case "epub": return "application/epub+zip"
        case "cbz": return "application/vnd.comicbook+zip"
        case "fb2": return "application/x-fictionbook+xml"
        case "mobi", "azw3": return "application/x-mobipocket-ebook"
        default:
            return UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        }
    }
}
