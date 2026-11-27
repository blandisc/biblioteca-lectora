import Foundation

/// Duplicados en toda la biblioteca (CB-3), como el complemento Find Duplicates de Calibre:
/// el mismo título (sin subtítulo ni artículo) con un autor parecido, o el mismo ISBN.
public enum DuplicateFinder {
    /// Una pareja que dijiste que no es el mismo libro: no se vuelve a proponer.
    public struct Pair: Hashable, Codable, Sendable {
        public let first: UUID
        public let second: UUID

        public init(_ a: UUID, _ b: UUID) {
            (first, second) = a.uuidString < b.uuidString ? (a, b) : (b, a)
        }
    }

    /// El título para comparar: sin acentos, sin subtítulo («: …», « (…)»), sin artículo inicial.
    public static func titleKey(_ title: String) -> String {
        var base = title
        for mark in [":", " (", " - ", " — ", "["] {
            if let range = base.range(of: mark), range.lowerBound > base.startIndex { base = String(base[..<range.lowerBound]) }
        }
        var words = CatalogRename.words(base)
        if words.count > 1, ["el", "la", "los", "las", "un", "una", "the", "a", "an"].contains(words[0]) {
            words.removeFirst()
        }
        return words.joined(separator: " ")
    }

    /// Los grupos de posibles duplicados (dos o más libros), sin las parejas descartadas.
    public static func groups(_ books: [Book], dismissed: Set<Pair> = []) -> [[Book]] {
        var parent = Dictionary(uniqueKeysWithValues: books.map { ($0.id, $0.id) })
        func root(_ id: UUID) -> UUID {
            var id = id
            while let up = parent[id], up != id { id = up }
            return id
        }
        func join(_ a: Book, _ b: Book) {
            guard !dismissed.contains(Pair(a.id, b.id)) else { return }
            parent[root(a.id)] = root(b.id)
        }
        let byTitle = Dictionary(grouping: books.filter { !titleKey($0.title).isEmpty }) { titleKey($0.title) }
        for bucket in byTitle.values where bucket.count > 1 {
            for (i, a) in bucket.enumerated() {
                for b in bucket[(i + 1)...] where sameAuthors(a, b) { join(a, b) }
            }
        }
        let byISBN = Dictionary(grouping: books.filter { $0.identifiers["isbn"] != nil }) { ISBN.normalized($0.identifiers["isbn"] ?? "") ?? "" }
        for (isbn, bucket) in byISBN where !isbn.isEmpty && bucket.count > 1 {
            for (i, a) in bucket.enumerated() {
                for b in bucket[(i + 1)...] { join(a, b) }
            }
        }
        return Dictionary(grouping: books) { root($0.id) }.values
            .filter { $0.count > 1 }
            .map { $0.sorted { ($0.addedAt ?? .distantPast) < ($1.addedAt ?? .distantPast) } }
            .sorted { $0[0].title.localizedStandardCompare($1[0].title) == .orderedAscending }
    }

    /// Algún autor en común (o parecido), o uno de los dos sin autor.
    static func sameAuthors(_ a: Book, _ b: Book) -> Bool {
        guard !a.authors.isEmpty, !b.authors.isEmpty else { return true }
        return a.authors.contains { x in
            b.authors.contains { y in
                CatalogRename.key(x) == CatalogRename.key(y) || CatalogRename.sameName(CatalogRename.words(x), CatalogRename.words(y))
                    || surname(x) == surname(y)
            }
        }
    }

    /// El apellido para comparar: lo que va antes de la coma («Cortázar, Julio») o la última palabra.
    static func surname(_ name: String) -> String {
        if let comma = name.firstIndex(of: ",") { return CatalogRename.key(String(name[..<comma])) }
        return CatalogRename.words(name).last ?? ""
    }

    /// Cuál conviene conservar: el que tiene más subrayados y avance; luego EPUB; luego el más antiguo.
    public static func preferred(_ group: [Book], highlights: [UUID: Int]) -> UUID? {
        group.max { a, b in
            let rank = { (book: Book) -> (Int, Int, Int, Double) in
                (highlights[book.id] ?? 0,
                 book.readingStatus == .toRead ? 0 : 1,
                 book.formats.first == "EPUB" ? 1 : 0,
                 -(book.addedAt?.timeIntervalSince1970 ?? 0))
            }
            return rank(a) < rank(b)
        }?.id
    }

    /// Los datos del que se queda, completados con los de los otros: lo que le falta, todas
    /// las etiquetas e identificadores, y el estado de lectura más avanzado.
    public static func merged(keep: Book, with others: [Book]) -> Book {
        var book = keep
        for other in others {
            if book.authors.isEmpty { book.authors = other.authors }
            if book.series == nil { book.series = other.series; book.seriesIndex = other.seriesIndex }
            if book.language == nil { book.language = other.language }
            if (book.publisher ?? "").isEmpty { book.publisher = other.publisher }
            if (book.published ?? "").isEmpty { book.published = other.published }
            if (book.summary ?? "").isEmpty { book.summary = other.summary }
            if book.rating == nil { book.rating = other.rating }
            for tag in other.tags where !book.tags.contains(where: { CatalogRename.key($0) == CatalogRename.key(tag) }) {
                book.tags.append(tag)
            }
            book.identifiers.merge(other.identifiers) { mine, _ in mine }
            if progress(other.readingStatus) > progress(book.readingStatus) { book.readingStatus = other.readingStatus }
            if let added = other.addedAt, added < (book.addedAt ?? .distantFuture) { book.addedAt = added }
        }
        return book
    }

    static func progress(_ status: ReadingStatus) -> Int {
        switch status {
        case .toRead: 0
        case .abandoned: 1
        case .reading: 2
        case .finished: 3
        }
    }
}
