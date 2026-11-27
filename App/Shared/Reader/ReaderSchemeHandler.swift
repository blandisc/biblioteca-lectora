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

    /// Pedidos en curso: uno que WebKit detuvo ya no recibe nada (si no, WebKit lanza una excepción).
    private var running = Set<ObjectIdentifier>()

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
                // No permitir salir de la carpeta del lector con "../". Se comparan carpetas
                // enteras: con texto, «…/Reader» también aceptaba «…/ReaderX» (B9).
                return Self.isInside(candidate, directory) ? candidate : nil
            }
        }
        guard let fileURL else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        // M10: el libro entero (un PDF puede pesar cientos de MB) se lee fuera del hilo de la
        // pantalla y mapeado del disco, no copiado a memoria; antes la app se congelaba al abrirlo.
        let id = ObjectIdentifier(urlSchemeTask)
        running.insert(id)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let data = try? Data(contentsOf: fileURL, options: .mappedIfSafe)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.running.remove(id) != nil else { return }
                guard let data else {
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
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        running.remove(ObjectIdentifier(urlSchemeTask))
    }

    /// ¿`file` está dentro de `folder`? Compara carpeta por carpeta, no el texto de la ruta.
    static func isInside(_ file: URL, _ folder: URL) -> Bool {
        let parts = file.standardizedFileURL.pathComponents
        let base = folder.standardizedFileURL.pathComponents
        return parts.count > base.count && Array(parts.prefix(base.count)) == base
    }

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
