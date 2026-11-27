#if os(macOS)
import LectoraCore
import SwiftUI

/// Un libro como renglón de la tabla de la Mac (MG-1): lo que se ve y la llave para ordenar
/// cada columna (sin acentos ni mayúsculas, así «Ángel» va con la A).
struct MacBookRow: Identifiable {
    let book: Book
    let shelf: ShelfBook
    let state: ReadingState
    let hasCover: Bool
    let inReview: Bool

    var id: UUID { book.id }
    var title: String { book.title }
    var author: String { shelf.author }
    var seriesLabel: String {
        guard let series = book.series else { return "" }
        return book.seriesIndex.flatMap(ShelfBook.number).map { "\(series) · \($0)" } ?? series
    }
    var tagsLabel: String { book.tags.joined(separator: ", ") }
    var language: String { book.language.map(BookFields.languageName) ?? "" }
    /// «EPUB · PDF» si tiene varios formatos (CB-3).
    var format: String { book.formats.joined(separator: " · ") }
    var progress: Double { shelf.progress }
    var progressLabel: String { progress > 0 ? progress.percentText : "" }
    var rating: Double { book.rating ?? 0 }
    /// De 0 a 5 estrellas: una valoración negativa o rara de un OPF no cierra la app (B3).
    var stars: String { String(repeating: "★", count: starCount) }
    var starCount: Int { min(5, max(0, rating.safeInt ?? 0)) }
    var added: Date { book.addedAt ?? .distantPast }
    var addedLabel: String { book.addedAt?.esShort ?? "" }
    var publisher: String { book.publisher ?? "" }
    var published: String { book.published ?? "" }
    var isbn: String { book.identifiers["isbn"] ?? "" }
    var stateLabel: String { state.name }

    var titleKey: String { Self.fold(book.sortTitle) }
    var authorKey: String { Self.fold(shelf.authorSort) }
    /// La serie y luego su número: «el mediterraneo 0001.0».
    var seriesKey: String {
        guard let series = book.series else { return "\u{10FFFF}" }
        return Self.fold(series) + String(format: " %08.2f", book.seriesIndex ?? 0)
    }
    /// Ordenar por la columna de la portada junta los que no tienen.
    var coverKey: Int { hasCover ? 0 : 1 }
    var tagsKey: String { Self.fold(tagsLabel) }
    var publisherKey: String { Self.fold(publisher) }

    init(book: Book, shelf: ShelfBook, hasCover: Bool, inReview: Bool) {
        self.book = book
        self.shelf = shelf
        self.hasCover = hasCover
        self.inReview = inReview
        state = shelf.state
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es"))
    }
}
#endif
