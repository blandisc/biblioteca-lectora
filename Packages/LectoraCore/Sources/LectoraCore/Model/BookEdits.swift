import Foundation

extension Book {
    /// Guardar una ficha que se abrió hace rato (auditoría 1): solo lo que cambiaste en ella
    /// (`edited` distinto de `loaded`, como estaba al abrirla) se pone sobre el libro de ahora
    /// (`current`). Lo demás se queda como está ahora, aunque otro dispositivo o la búsqueda en
    /// internet lo haya cambiado mientras tanto. Los identificadores se juntan uno por uno.
    /// El archivo, la carpeta, el número de Calibre y la huella siempre son los de `current`.
    public static func applyingEdits(from edited: Book, loaded: Book, onto current: Book) -> Book {
        merging(edited, loaded: loaded, onto: current) { _, _ in true }
    }

    /// Deshacer un cambio de toda la biblioteca (renombrar un autor, renumerar una serie) sobre el
    /// libro de ahora (auditoría 6, M3): solo los datos que ese cambio tocó (`original` → `changed`)
    /// regresan a `original`, y solo si siguen como ese cambio los dejó. Lo que cambiaste después,
    /// en ese dato o en otro, se queda. Antes se escribía el libro viejo entero encima.
    public static func revertingEdits(to original: Book, from changed: Book, onto current: Book) -> Book {
        merging(original, loaded: changed, onto: current) { changedValue, currentValue in changedValue == currentValue }
    }

    private static func merging(_ edited: Book, loaded: Book, onto current: Book,
                                when allowed: (AnyHashable, AnyHashable) -> Bool) -> Book {
        var book = current
        func take<T: Hashable>(_ field: WritableKeyPath<Book, T>) {
            if edited[keyPath: field] != loaded[keyPath: field],
               allowed(AnyHashable(loaded[keyPath: field]), AnyHashable(current[keyPath: field])) {
                book[keyPath: field] = edited[keyPath: field]
            }
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
        where edited.identifiers[scheme] != loaded.identifiers[scheme]
            && allowed(AnyHashable(loaded.identifiers[scheme]), AnyHashable(current.identifiers[scheme])) {
            book.identifiers[scheme] = edited.identifiers[scheme]
        }
        return book
    }
}
