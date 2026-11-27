import Foundation

/// Revisa, antes de importar, que el archivo sea de verdad del formato que dice su extensión.
public enum BookFileCheck {
    /// `nil` si el archivo parece sano; si no, la razón en una frase corta.
    /// - Parameter header: los primeros bytes del archivo (bastan 4 KB).
    public static func problem(fileExtension: String, header: Data, size: Int) -> String? {
        guard size > 0, !header.isEmpty else { return "Está vacío." }
        let bytes = [UInt8](header.prefix(4096))
        func has(_ text: String, at offset: Int) -> Bool {
            let marker = Array(text.utf8)
            return bytes.count >= offset + marker.count && Array(bytes[offset..<offset + marker.count]) == marker
        }
        func contains(_ text: String, within limit: Int) -> Bool {
            let marker = Array(text.utf8), window = Array(bytes.prefix(limit))
            guard window.count >= marker.count else { return false }
            return (0...(window.count - marker.count)).contains { Array(window[$0..<$0 + marker.count]) == marker }
        }
        switch fileExtension.lowercased() {
        case "epub": return has("PK\u{3}\u{4}", at: 0) ? nil : "No es un EPUB que se pueda abrir."
        case "cbz": return has("PK\u{3}\u{4}", at: 0) ? nil : "No es un CBZ que se pueda abrir."
        // Algunos PDF traen basura antes de la marca; los lectores aceptan hasta 1 KB.
        case "pdf": return contains("%PDF-", within: 1024 + 5) ? nil : "No es un PDF que se pueda abrir."
        case "mobi": return has("BOOKMOBI", at: 60) ? nil : "No es un MOBI que se pueda abrir."
        case "azw3": return has("BOOKMOBI", at: 60) ? nil : "No es un AZW3 que se pueda abrir."
        case "fb2": return contains("<FictionBook", within: 4096) ? nil : "No es un FB2 que se pueda abrir."
        default: return "Ese formato no se puede leer."
        }
    }
}
