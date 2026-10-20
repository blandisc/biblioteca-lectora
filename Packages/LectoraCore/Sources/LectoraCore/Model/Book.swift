import Foundation

/// Libro de la biblioteca (vista materializada a partir de `LibraryState`).
public struct Book: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var authors: [String]
    public var series: String?
    public var seriesIndex: Double?
    public var tags: [String]
    public var language: String?
    /// Identificadores externos: `isbn`, `asin`, `calibre`, `goodreads`…
    public var identifiers: [String: String]
    /// Ruta del archivo relativa a la carpeta de la biblioteca.
    public var filePath: String?
    public var readingStatus: ReadingStatus
    public var publisher: String?
    /// Fecha de publicación en ISO 8601 («2004» o «2004-05-01»).
    public var published: String?
    /// Sinopsis; puede traer HTML sencillo, como en Calibre.
    public var summary: String?
    /// Valoración de 0 a 5 estrellas (Calibre guarda 0–10).
    public var rating: Double?
    /// Número de libro en una biblioteca de Calibre: da nombre a la carpeta `Título (id)`.
    public var calibreID: Int?
    /// SHA-256 del archivo, para reconocer duplicados.
    public var fileHash: String?
    public var addedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        authors: [String] = [],
        series: String? = nil,
        seriesIndex: Double? = nil,
        tags: [String] = [],
        language: String? = nil,
        identifiers: [String: String] = [:],
        filePath: String? = nil,
        readingStatus: ReadingStatus = .toRead,
        publisher: String? = nil,
        published: String? = nil,
        summary: String? = nil,
        rating: Double? = nil,
        calibreID: Int? = nil,
        fileHash: String? = nil,
        addedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.authors = authors
        self.series = series
        self.seriesIndex = seriesIndex
        self.tags = tags
        self.language = language
        self.identifiers = identifiers
        self.filePath = filePath
        self.readingStatus = readingStatus
        self.publisher = publisher
        self.published = published
        self.summary = summary
        self.rating = rating
        self.calibreID = calibreID
        self.fileHash = fileHash
        self.addedAt = addedAt
    }

    /// Carpeta del libro relativa a la biblioteca («Autor/Título (12)»).
    public var folderPath: String? {
        filePath.map { ($0 as NSString).deletingLastPathComponent }
    }

    /// Título para ordenar: sin artículo inicial en español o inglés.
    public var sortTitle: String {
        let articles = ["el ", "la ", "los ", "las ", "un ", "una ", "the ", "a ", "an "]
        let lower = title.lowercased()
        if let article = articles.first(where: { lower.hasPrefix($0) }), title.count > article.count {
            return String(title.dropFirst(article.count))
        }
        return title
    }

    /// «Apellido, Nombre» del primer autor, como el `author_sort` de Calibre.
    public static func authorSort(_ name: String) -> String {
        let parts = name.split(separator: " ")
        guard parts.count > 1, !name.contains(",") else { return name }
        return "\(parts.last!), \(parts.dropLast().joined(separator: " "))"
    }
}

public enum ReadingStatus: String, Codable, Sendable, CaseIterable {
    case toRead = "to_read"
    case reading
    case finished
    case abandoned
}

extension Book {
    enum Field {
        static let title = "title"
        static let authors = "authors"
        static let series = "series"
        static let seriesIndex = "series_index"
        static let tags = "tags"
        static let language = "language"
        static let identifiers = "identifiers"
        static let filePath = "file_path"
        static let readingStatus = "reading_status"
        static let publisher = "publisher"
        static let published = "published"
        static let summary = "summary"
        static let rating = "rating"
        static let calibreID = "calibre_id"
        static let fileHash = "file_hash"
        static let addedAt = "added_at"
    }

    /// Construye el libro a partir de sus campos; `nil` si no tiene título.
    public init?(id: UUID, fields: [String: JSONValue]) {
        guard let title = fields[Field.title]?.stringValue else { return nil }
        var identifiers: [String: String] = [:]
        if case .object(let object)? = fields[Field.identifiers] {
            for (key, value) in object {
                if let string = value.stringValue { identifiers[key] = string }
            }
        }
        self.init(
            id: id,
            title: title,
            authors: fields[Field.authors]?.stringArrayValue ?? [],
            series: fields[Field.series]?.stringValue,
            seriesIndex: fields[Field.seriesIndex]?.doubleValue,
            tags: fields[Field.tags]?.stringArrayValue ?? [],
            language: fields[Field.language]?.stringValue,
            identifiers: identifiers,
            filePath: fields[Field.filePath]?.stringValue,
            readingStatus: fields[Field.readingStatus]?.stringValue.flatMap(ReadingStatus.init(rawValue:)) ?? .toRead,
            publisher: fields[Field.publisher]?.stringValue,
            published: fields[Field.published]?.stringValue,
            summary: fields[Field.summary]?.stringValue,
            rating: fields[Field.rating]?.doubleValue,
            calibreID: fields[Field.calibreID]?.doubleValue.map { Int($0) },
            fileHash: fields[Field.fileHash]?.stringValue,
            addedAt: fields[Field.addedAt]?.doubleValue.map(Date.init(timeIntervalSince1970:))
        )
    }

    /// Cambios que describen el libro completo (para altas e importaciones).
    public func changes(clock: HybridLogicalClock) -> [Change] {
        var fields: [(String, JSONValue)] = [
            (Field.title, .string(title)),
            (Field.authors, .array(authors.map(JSONValue.string))),
            (Field.tags, .array(tags.map(JSONValue.string))),
            (Field.identifiers, .object(identifiers.mapValues(JSONValue.string))),
            (Field.readingStatus, .string(readingStatus.rawValue)),
        ]
        fields.append((Field.series, series.map(JSONValue.string) ?? .null))
        fields.append((Field.seriesIndex, seriesIndex.map(JSONValue.number) ?? .null))
        fields.append((Field.language, language.map(JSONValue.string) ?? .null))
        fields.append((Field.filePath, filePath.map(JSONValue.string) ?? .null))
        fields.append((Field.publisher, publisher.map(JSONValue.string) ?? .null))
        fields.append((Field.published, published.map(JSONValue.string) ?? .null))
        fields.append((Field.summary, summary.map(JSONValue.string) ?? .null))
        fields.append((Field.rating, rating.map(JSONValue.number) ?? .null))
        fields.append((Field.calibreID, calibreID.map { JSONValue.number(Double($0)) } ?? .null))
        fields.append((Field.fileHash, fileHash.map(JSONValue.string) ?? .null))
        fields.append((Field.addedAt, addedAt.map { JSONValue.number($0.timeIntervalSince1970) } ?? .null))
        return fields.map { field, value in
            Change(hlc: clock.tick(), entity: .book, entityID: id, field: field, value: value)
        }
    }
}

extension LibraryState {
    /// Libros vivos, ordenados por título.
    public func books() -> [Book] {
        ids(of: .book)
            .compactMap { id in fields(of: .book, id: id).flatMap { Book(id: id, fields: $0) } }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }
}
