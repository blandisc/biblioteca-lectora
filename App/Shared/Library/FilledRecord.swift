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
    /// Los identificadores que dejó el registro de internet (`openlibrary:`, `google:`): al
    /// deshacer se quitan (auditoría 1). Opcional: los archivos de antes no lo tienen.
    var identifiers: [AutoFill.IdentifierChange]? = nil
    /// El registro de internet de donde salió («openlibrary:OL46125W»): al deshacer se recuerda
    /// como rechazado y ya no se aplica solo.
    var record: Set<String>? = nil
    /// La huella de la portada que puse: al deshacer, solo se quita si sigue siendo esa (si la
    /// cambiaste después, la tuya se queda). Opcional: los archivos de antes no la tienen.
    var coverHash: String? = nil
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
        case .authors: text = ListText.join(book.authors, separator: " & ")
        case .published: text = book.published
        case .publisher: text = book.publisher
        case .language: text = book.language
        case .series: text = book.series.map { name in book.seriesIndex.flatMap(ShelfBook.number).map { "\(name) #\($0)" } ?? name }
        case .tags: text = ListText.join(book.tags, separator: ", ")
        case .isbn: text = book.identifiers["isbn"]
        case .summary: text = book.summary
        case .cover: text = nil
        }
        return text.flatMap { $0.isEmpty ? nil : $0 }
    }

    /// Devuelve el campo a como estaba.
    func restore(_ old: String?, in book: inout Book) {
        switch self {
        case .authors: book.authors = old.map { ListText.split($0, separator: " & ") } ?? []
        case .published: book.published = old
        case .publisher: book.publisher = old
        case .language: book.language = old
        case .series:
            guard let old else { book.series = nil; book.seriesIndex = nil; return }
            // El último « #» separa el número: una serie puede llevar «#» en su nombre.
            if let mark = old.range(of: " #", options: .backwards) {
                book.series = String(old[..<mark.lowerBound])
                book.seriesIndex = Book.sanitizedSeriesIndex(Double(old[mark.upperBound...]))
            } else {
                book.series = old
                book.seriesIndex = nil
            }
        case .tags: book.tags = old.map { ListText.split($0, separator: ", ") } ?? []
        case .isbn: book.identifiers["isbn"] = old
        case .summary: book.summary = old
        case .cover: break
        }
    }

    /// Para mostrar: el idioma con su nombre, la sinopsis recortada.
    func display(_ value: String?) -> String? {
        guard let value else { return nil }
        switch self {
        case .language: return BookFields.languageName(value)
        case .summary: return value.clipped(to: Theme.Lists.summaryLetters)
        case .series: return value.replacingOccurrences(of: " #", with: " · ")
        default: return value
        }
    }
}
