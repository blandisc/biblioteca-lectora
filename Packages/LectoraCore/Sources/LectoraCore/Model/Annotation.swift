import Foundation

/// Subrayado o nota. Se ancla con varios selectores para poder re-anclarse
/// si cambia el archivo o el motor de render (W3C Web Annotation).
public struct Annotation: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var bookID: UUID
    /// EPUB CFI de rango (foliate-js).
    public var cfi: String?
    /// Texto citado exacto, más contexto para re-anclar.
    public var quote: String
    public var prefix: String?
    public var suffix: String?
    public var color: String
    public var note: String?
    public var createdAt: Date
    /// ID del subrayado en Readwise, una vez enviado (o el que traía, si vino de allá).
    public var readwiseID: String?
    /// De dónde vino: `nil` si lo hiciste en Gabinete; «calibre» si vino de su visor;
    /// «readwise» si llegó de allá (Kindle, Apple Books…), y eso no se vuelve a mandar.
    public var source: String?
    /// Título y autor del libro tal como venían, para los que no están en tu biblioteca.
    public var bookTitle: String?
    public var bookAuthor: String?

    public init(
        id: UUID = UUID(),
        bookID: UUID,
        cfi: String?,
        quote: String,
        prefix: String? = nil,
        suffix: String? = nil,
        color: String = "yellow",
        note: String? = nil,
        createdAt: Date = Date(),
        readwiseID: String? = nil,
        source: String? = nil,
        bookTitle: String? = nil,
        bookAuthor: String? = nil
    ) {
        self.id = id
        self.bookID = bookID
        self.cfi = cfi
        self.quote = quote
        self.prefix = prefix
        self.suffix = suffix
        self.color = color
        self.note = note
        self.createdAt = createdAt
        self.readwiseID = readwiseID
        self.source = source
        self.bookTitle = bookTitle
        self.bookAuthor = bookAuthor
    }

    /// Tuyo para mandar a Readwise: hecho en Gabinete o traído de Calibre (no llegó de Readwise).
    public var isOwn: Bool { source != "readwise" }
}

extension Annotation {
    enum Field {
        static let bookID = "book_id"
        static let cfi = "cfi"
        static let quote = "quote"
        static let prefix = "prefix"
        static let suffix = "suffix"
        static let color = "color"
        static let note = "note"
        static let createdAt = "created_at"
        static let readwiseID = "readwise_id"
        static let source = "source"
        static let bookTitle = "book_title"
        static let bookAuthor = "book_author"
    }

    public init?(id: UUID, fields: [String: JSONValue]) {
        guard
            let bookID = fields[Field.bookID]?.stringValue.flatMap(UUID.init(uuidString:)),
            let quote = fields[Field.quote]?.stringValue
        else { return nil }
        self.init(
            id: id,
            bookID: bookID,
            cfi: fields[Field.cfi]?.stringValue,
            quote: quote,
            prefix: fields[Field.prefix]?.stringValue,
            suffix: fields[Field.suffix]?.stringValue,
            color: fields[Field.color]?.stringValue ?? "yellow",
            note: fields[Field.note]?.stringValue,
            createdAt: Date(timeIntervalSince1970: fields[Field.createdAt]?.doubleValue ?? 0),
            readwiseID: fields[Field.readwiseID]?.stringValue,
            source: fields[Field.source]?.stringValue,
            bookTitle: fields[Field.bookTitle]?.stringValue,
            bookAuthor: fields[Field.bookAuthor]?.stringValue
        )
    }

    public func changes(clock: HybridLogicalClock) -> [Change] {
        let fields: [(String, JSONValue)] = [
            (Field.bookID, .string(bookID.uuidString)),
            (Field.cfi, cfi.map(JSONValue.string) ?? .null),
            (Field.quote, .string(quote)),
            (Field.prefix, prefix.map(JSONValue.string) ?? .null),
            (Field.suffix, suffix.map(JSONValue.string) ?? .null),
            (Field.color, .string(color)),
            (Field.note, note.map(JSONValue.string) ?? .null),
            (Field.createdAt, .number(createdAt.timeIntervalSince1970)),
            (Field.readwiseID, readwiseID.map(JSONValue.string) ?? .null),
            (Field.source, source.map(JSONValue.string) ?? .null),
            (Field.bookTitle, bookTitle.map(JSONValue.string) ?? .null),
            (Field.bookAuthor, bookAuthor.map(JSONValue.string) ?? .null),
        ]
        return fields.map { field, value in
            Change(hlc: clock.tick(), entity: .annotation, entityID: id, field: field, value: value)
        }
    }

    /// Cambio que borra el subrayado (tombstone; nunca se elimina del registro).
    public static func deletion(id: UUID, clock: HybridLogicalClock) -> Change {
        Change(hlc: clock.tick(), entity: .annotation, entityID: id, field: Change.deletedField, value: .bool(true))
    }
}

extension LibraryState {
    /// Subrayados vivos de un libro.
    public func annotations(for bookID: UUID) -> [Annotation] {
        ids(of: .annotation)
            .compactMap { id in fields(of: .annotation, id: id).flatMap { Annotation(id: id, fields: $0) } }
            .filter { $0.bookID == bookID }
            .sorted { $0.createdAt < $1.createdAt }
    }
}
