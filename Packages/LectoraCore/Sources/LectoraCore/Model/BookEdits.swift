import Foundation

extension Book {
    /// Guardar una ficha que se abrió hace rato (auditoría 1): solo lo que cambiaste en ella
    /// (`edited` distinto de `loaded`, como estaba al abrirla) se pone sobre el libro de ahora
    /// (`current`). Lo demás se queda como está ahora, aunque otro dispositivo o la búsqueda en
    /// internet lo haya cambiado mientras tanto. Los identificadores se juntan uno por uno.
    /// El archivo, la carpeta, el número de Calibre y la huella siempre son los de `current`.
    public static func applyingEdits(from edited: Book, loaded: Book, onto current: Book) -> Book {
        var book = current
        func take<T: Equatable>(_ field: WritableKeyPath<Book, T>) {
            if edited[keyPath: field] != loaded[keyPath: field] { book[keyPath: field] = edited[keyPath: field] }
        }
        take(\.title)
        take(\.authors)
        take(\.series)
        take(\.seriesIndex)
        take(\.tags)
        take(\.language)
        take(\.readingStatus)
        take(\.publisher)
        take(\.published)
        take(\.summary)
        take(\.rating)
        for scheme in Set(edited.identifiers.keys).union(loaded.identifiers.keys)
        where edited.identifiers[scheme] != loaded.identifiers[scheme] {
            book.identifiers[scheme] = edited.identifiers[scheme]
        }
        return book
    }
}
