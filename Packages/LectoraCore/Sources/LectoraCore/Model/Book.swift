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
        readingStatus: ReadingStatus = .toRead
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
            readingStatus: fields[Field.readingStatus]?.stringValue.flatMap(ReadingStatus.init(rawValue:)) ?? .toRead
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
