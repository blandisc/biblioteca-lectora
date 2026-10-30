import Foundation
import LectoraCore

/// Un dato que Lectora completó sola desde internet, para poder revisarlo y
/// deshacerlo después (como «Revisar metadatos descargados» de Calibre).
struct FilledChange: Codable, Hashable {
    var field: FilledField
    var old: String?
    var new: String?
}

struct FilledRecord: Codable, Hashable {
    var date: Date
    var changes: [FilledChange]
}

/// Los campos que se completan solos (nunca el título: ese no se toca).
enum FilledField: String, Codable, CaseIterable, Hashable {
    case authors, published, publisher, language, series, tags, isbn, summary, cover

    var label: String {
        switch self {
        case .authors: "Autor"
        case .published: "Publicado"
        case .publisher: "Editorial"
        case .language: "Idioma"
        case .series: "Serie"
        case .tags: "Géneros"
        case .isbn: "ISBN"
        case .summary: "Sinopsis"
        case .cover: "Portada"
        }
    }

    /// El valor como texto (para comparar, mostrar y guardar).
    func value(in book: Book) -> String? {
        let text: String?
        switch self {
        case .authors: text = book.authors.joined(separator: " & ")
        case .published: text = book.published
        case .publisher: text = book.publisher
        case .language: text = book.language
        case .series: text = book.series.map { name in book.seriesIndex.map { "\(name) #\(ShelfBook.number($0))" } ?? name }
        case .tags: text = book.tags.joined(separator: ", ")
        case .isbn: text = book.identifiers["isbn"]
        case .summary: text = book.summary
        case .cover: text = nil
        }
        return text.flatMap { $0.isEmpty ? nil : $0 }
    }

    /// Devuelve el campo a como estaba.
    func restore(_ old: String?, in book: inout Book) {
        switch self {
        case .authors: book.authors = old?.components(separatedBy: " & ") ?? []
        case .published: book.published = old
        case .publisher: book.publisher = old
        case .language: book.language = old
        case .series:
            guard let old else { book.series = nil; book.seriesIndex = nil; return }
            let parts = old.components(separatedBy: " #")
            book.series = parts[0]
            book.seriesIndex = parts.count > 1 ? Double(parts[1]) : nil
        case .tags: book.tags = old?.components(separatedBy: ", ") ?? []
        case .isbn: book.identifiers["isbn"] = old
        case .summary: book.summary = old
        case .cover: break
        }
    }

    /// Para mostrar: el idioma con su nombre, la sinopsis recortada.
    func display(_ value: String?) -> String? {
        guard let value else { return nil }
        switch self {
        case .language: return MetadataCandidate.languageName(value)
        case .summary: return value.count > 140 ? String(value.prefix(140)) + "…" : value
        case .series: return value.replacingOccurrences(of: " #", with: " · ")
        default: return value
        }
    }
}
