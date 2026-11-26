import Foundation

/// Edición masiva en la Mac (MG-1): lo que cambias en la ficha con varios libros elegidos
/// se aplica a todos. Lo que dejas igual (`nil`) no se toca; las etiquetas se agregan o se
/// quitan sin borrar las demás de cada libro.
public struct BulkEdit: Equatable, Sendable {
    public var authors: [String]?
    /// `.some(nil)` quita la serie; `nil` no la toca.
    public var series: String??
    public var language: String??
    public var publisher: String??
    public var readingStatus: ReadingStatus?
    public var addTags: [String] = []
    public var removeTags: [String] = []

    public init(authors: [String]? = nil, series: String?? = nil, language: String?? = nil,
                publisher: String?? = nil, readingStatus: ReadingStatus? = nil,
                addTags: [String] = [], removeTags: [String] = []) {
        self.authors = authors
        self.series = series
        self.language = language
        self.publisher = publisher
        self.readingStatus = readingStatus
        self.addTags = addTags
        self.removeTags = removeTags
    }

    public var isEmpty: Bool {
        authors == nil && series == nil && language == nil && publisher == nil && readingStatus == nil
            && addTags.isEmpty && removeTags.isEmpty
    }

    public func apply(to book: Book) -> Book {
        var book = book
        if let authors { book.authors = authors }
        if let series {
            if book.series != series { book.seriesIndex = nil }
            book.series = series
        }
        if let language { book.language = language }
        if let publisher { book.publisher = publisher }
        if let readingStatus { book.readingStatus = readingStatus }
        let removed = Set(removeTags.map(Self.key))
        var tags = book.tags.filter { !removed.contains(Self.key($0)) }
        for tag in addTags where !tags.contains(where: { Self.key($0) == Self.key(tag) }) {
            tags.append(tag)
        }
        book.tags = tags
        return book
    }

    /// El valor que comparten todos los libros, o `nil` si alguno es distinto («Varios»).
    public static func common<Value: Equatable>(_ books: [Book], _ value: (Book) -> Value) -> Value? {
        guard let first = books.first.map(value) else { return nil }
        return books.dropFirst().allSatisfy { value($0) == first } ? first : nil
    }

    /// Las etiquetas que tienen todos los libros elegidos.
    public static func sharedTags(_ books: [Book]) -> [String] {
        guard let first = books.first else { return [] }
        return first.tags.filter { tag in books.allSatisfy { $0.tags.contains { key($0) == key(tag) } } }
    }

    /// Una lista escrita a mano («Borges, Bioy Casares») en sus partes.
    public static func list(_ text: String) -> [String] {
        text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    static func key(_ tag: String) -> String {
        tag.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
