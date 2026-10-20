import Foundation

/// Un posible libro encontrado en internet para completar o corregir los datos.
public struct MetadataCandidate: Identifiable, Hashable, Codable, Sendable {
    public enum Source: String, Codable, Sendable, CaseIterable {
        case openLibrary = "Open Library"
        case googleBooks = "Google Books"
    }

    public var id: String
    public var source: Source
    public var title: String
    public var subtitle: String?
    public var authors: [String]
    public var publisher: String?
    public var published: String?
    public var summary: String?
    public var isbn: String?
    public var language: String?
    public var subjects: [String]
    public var series: String?
    public var seriesIndex: Double?
    public var coverURL: URL?
    /// 0–1: qué tan seguro es que sea el mismo libro (lo calcula `MetadataMatcher`).
    public var confidence: Double

    public init(id: String, source: Source, title: String, subtitle: String? = nil, authors: [String] = [],
                publisher: String? = nil, published: String? = nil, summary: String? = nil, isbn: String? = nil,
                language: String? = nil, subjects: [String] = [], series: String? = nil, seriesIndex: Double? = nil,
                coverURL: URL? = nil, confidence: Double = 0) {
        self.id = id
        self.source = source
        self.title = title
        self.subtitle = subtitle
        self.authors = authors
        self.publisher = publisher
        self.published = published
        self.summary = summary
        self.isbn = isbn
        self.language = language
        self.subjects = subjects
        self.series = series
        self.seriesIndex = seriesIndex
        self.coverURL = coverURL
        self.confidence = confidence
    }
}
