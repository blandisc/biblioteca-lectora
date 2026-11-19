import Foundation

/// Un marcador: la cinta del lector en una página. Vive en el registro de la
/// biblioteca, así que viaja entre tus dispositivos.
public struct Bookmark: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var bookID: UUID
    public var cfi: String
    /// Avance en el libro (0 a 1), para reconocer la página aunque cambie la letra.
    public var fraction: Double
    /// Las primeras palabras de la página.
    public var excerpt: String?
    public var createdAt: Date

    public init(id: UUID = UUID(), bookID: UUID, cfi: String, fraction: Double, excerpt: String?, createdAt: Date = Date()) {
        self.id = id
        self.bookID = bookID
        self.cfi = cfi
        self.fraction = fraction
        self.excerpt = excerpt
        self.createdAt = createdAt
    }

    enum Field {
        static let bookID = "book_id"
        static let cfi = "cfi"
        static let fraction = "fraction"
        static let excerpt = "excerpt"
        static let createdAt = "created_at"
    }

    public init?(id: UUID, fields: [String: JSONValue]) {
        guard let bookID = fields[Field.bookID]?.stringValue.flatMap(UUID.init(uuidString:)),
              let cfi = fields[Field.cfi]?.stringValue else { return nil }
        self.init(id: id, bookID: bookID, cfi: cfi, fraction: fields[Field.fraction]?.doubleValue ?? 0,
                  excerpt: fields[Field.excerpt]?.stringValue,
                  createdAt: Date(timeIntervalSince1970: fields[Field.createdAt]?.doubleValue ?? 0))
    }

    public func changes(clock: HybridLogicalClock) -> [Change] {
        [
            (Field.bookID, JSONValue.string(bookID.uuidString)),
            (Field.cfi, .string(cfi)),
            (Field.fraction, .number(fraction)),
            (Field.excerpt, excerpt.map(JSONValue.string) ?? .null),
            (Field.createdAt, .number(createdAt.timeIntervalSince1970)),
        ].map { Change(hlc: clock.tick(), entity: .bookmark, entityID: id, field: $0.0, value: $0.1) }
    }

    public static func deletion(id: UUID, clock: HybridLogicalClock) -> Change {
        Change(hlc: clock.tick(), entity: .bookmark, entityID: id, field: Change.deletedField, value: .bool(true))
    }

    /// ¿Marca esta página? (mismo lugar, aunque el CFI de la página cambie con el tamaño de letra).
    public func marks(cfi other: String?, fraction otherFraction: Double) -> Bool {
        if let other, other == cfi { return true }
        return abs(fraction - otherFraction) < 0.002
    }
}

extension LibraryState {
    /// Marcadores vivos de un libro, en el orden del libro.
    public func bookmarks(for bookID: UUID) -> [Bookmark] {
        ids(of: .bookmark)
            .compactMap { id in fields(of: .bookmark, id: id).flatMap { Bookmark(id: id, fields: $0) } }
            .filter { $0.bookID == bookID }
            .sorted { $0.fraction < $1.fraction }
    }
}
