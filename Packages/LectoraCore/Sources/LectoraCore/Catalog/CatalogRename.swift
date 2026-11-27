import Foundation

/// Ordenar autores, series y etiquetas en toda la biblioteca (CB-2), como el administrador de
/// Calibre: renombrar un valor, o fusionarlo con otro que ya existe, en todos sus libros de
/// una vez. Renombrar a un nombre que ya está es fusionar.
public struct CatalogRename: Equatable, Sendable {
    public enum Field: String, Sendable, CaseIterable {
        case author, series, tag
    }

    public var field: Field
    /// Los valores que se van (sin importar mayúsculas ni acentos).
    public var from: [String]
    /// Lo que queda en su lugar.
    public var to: String

    public init(field: Field, from: [String], to: String) {
        self.field = field
        self.from = from
        self.to = to.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Si el libro tiene alguno de los valores que se van.
    public func touches(_ book: Book) -> Bool {
        let keys = Set(from.map(Self.key))
        return Self.values(field, in: book).contains { keys.contains(Self.key($0)) }
    }

    /// El libro con el valor cambiado; sin repetir si ya tenía el nuevo. Con la serie, el
    /// número del tomo se conserva.
    public func apply(to book: Book) -> Book {
        guard !to.isEmpty, touches(book) else { return book }
        let keys = Set(from.map(Self.key))
        var book = book
        switch field {
        case .author: book.authors = Self.replace(book.authors, keys, with: to)
        case .tag: book.tags = Self.replace(book.tags, keys, with: to)
        case .series: book.series = to
        }
        return book
    }

    static func replace(_ values: [String], _ keys: Set<String>, with new: String) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values {
            let mapped = keys.contains(key(value)) ? new : value
            if seen.insert(key(mapped)).inserted { result.append(mapped) }
        }
        return result
    }

    public static func values(_ field: Field, in book: Book) -> [String] {
        switch field {
        case .author: book.authors
        case .series: book.series.map { [$0] } ?? []
        case .tag: book.tags
        }
    }

    /// Para comparar nombres: sin mayúsculas, acentos ni espacios en las orillas.
    public static func key(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Posibles repetidos

    /// Los otros valores que parecen el mismo: «Cortázar, Julio», «julio cortazar» y
    /// «J. Cortázar» para «Julio Cortázar». Sirve para proponer la fusión.
    public static func lookalikes(of value: String, among values: [String]) -> [String] {
        let mine = words(value)
        guard !mine.isEmpty else { return [] }
        return values.filter { other in
            key(other) != key(value) && sameName(mine, words(other))
        }
    }

    /// Las palabras del nombre sin acentos, puntos ni comas, en cualquier orden.
    static func words(_ text: String) -> [String] {
        key(text).components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
    }

    /// Las mismas palabras, o las de uno son iniciales de las del otro («j cortazar» ~ «julio cortazar»).
    static func sameName(_ a: [String], _ b: [String]) -> Bool {
        Set(a) == Set(b) || abbreviates(a, b) || abbreviates(b, a)
    }

    /// `short` es `long` con alguna palabra en inicial («j cortazar» de «julio cortazar»).
    static func abbreviates(_ short: [String], _ long: [String]) -> Bool {
        // Una sola palabra en común no basta («Julio» no es «Julio Cortázar»).
        guard short.count >= 2, long.count == short.count else { return false }
        var pool = long
        for word in short {
            if let exact = pool.firstIndex(of: word) {
                pool.remove(at: exact)
            } else if word.count == 1, let initial = pool.firstIndex(where: { $0.hasPrefix(word) && $0.count > 1 }) {
                pool.remove(at: initial)
            } else {
                return false
            }
        }
        // Al menos una palabra completa tiene que coincidir (no solo iniciales).
        return short.contains { $0.count > 1 && long.contains($0) }
    }

    // MARK: Renumerar una serie

    /// Los tomos 1, 2, 3… en el orden que ya tenían (los que no tenían número, al final y
    /// por título). Devuelve solo los libros cuyo número cambia.
    public static func renumber(_ books: [Book]) -> [Book] {
        let ordered = books.sorted { a, b in
            switch (a.seriesIndex, b.seriesIndex) {
            case let (x?, y?) where x != y: return x < y
            case (.some, nil): return true
            case (nil, .some): return false
            default: return a.title.localizedStandardCompare(b.title) == .orderedAscending
            }
        }
        return ordered.enumerated().compactMap { offset, book in
            let number = Double(offset + 1)
            guard book.seriesIndex != number else { return nil }
            var book = book
            book.seriesIndex = number
            return book
        }
    }
}
