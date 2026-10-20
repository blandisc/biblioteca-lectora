import Foundation

/// Nombres de carpetas y archivos como los pone Calibre, para que la carpeta de
/// la biblioteca sea también una biblioteca de Calibre:
///
///     Autor/Título (12)/Título - Autor.epub
///     Autor/Título (12)/cover.jpg
///     Autor/Título (12)/metadata.opf
public enum CalibreLayout {
    /// Calibre limita cada parte del nombre a 100 caracteres fuera de Windows.
    static let pathLimit = 100

    public static let coverFileName = "cover.jpg"
    public static let opfFileName = "metadata.opf"

    public static func folder(title: String, authors: [String], calibreID: Int) -> String {
        let author = sanitize(authors.first ?? "Desconocido", limit: pathLimit)
        let book = sanitize(title, limit: pathLimit)
        return "\(author)/\(book) (\(calibreID))"
    }

    public static func fileName(title: String, authors: [String], fileExtension: String) -> String {
        let base = sanitize("\(title) - \(authors.first ?? "Desconocido")", limit: pathLimit)
        return fileExtension.isEmpty ? base : "\(base).\(fileExtension.lowercased())"
    }

    /// Quita lo que no puede ir en un nombre de archivo, como `sanitize_file_name` de Calibre.
    public static func sanitize(_ name: String, limit: Int = pathLimit) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\?<>:*|\"").union(.controlCharacters)
        var cleaned = String(name.unicodeScalars.map { forbidden.contains($0) ? "_" : Character($0) })
        cleaned = cleaned.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        if cleaned.count > limit { cleaned = String(cleaned.prefix(limit)) }
        cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: " ."))
        return cleaned.isEmpty ? "_" : cleaned
    }
}
