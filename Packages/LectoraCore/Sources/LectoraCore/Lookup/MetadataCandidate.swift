import Foundation

/// Un posible libro encontrado en internet para completar o corregir los datos.
///
/// En Open Library un candidato es una *obra* (lo común a todas sus ediciones:
/// autor, año original, géneros, sinopsis) vista a través de la *edición* que
/// mejor corresponde a tu libro (título en tu idioma, editorial, ISBN, portada).
public struct MetadataCandidate: Identifiable, Hashable, Codable, Sendable {
    public enum Source: String, Codable, Sendable, CaseIterable {
        case openLibrary = "Open Library"
        case googleBooks = "Google Books"
    }

    /// Por qué se parece (o no) a tu libro; se muestra al elegir.
    public enum Note: String, Codable, Sendable {
        case sameISBN, sameTitle, similarTitle, otherTitle
        case sameAuthor, otherAuthor, unknownAuthor
        case otherLanguage, notTheBook, conflictingISBN
    }

    public var id: String
    public var source: Source
    public var title: String
    public var subtitle: String?
    public var authors: [String]
    public var publisher: String?
    /// Año de la primera publicación de la obra (o fecha de la edición si no se sabe).
    public var published: String?
    public var summary: String?
    public var isbn: String?
    public var language: String?
    /// Géneros en español (ya traducidos con `GenreMap`).
    public var subjects: [String]
    public var series: String?
    public var seriesIndex: Double?
    /// La mejor portada; `coverAlternatives` por si esa no sirve.
    public var coverURL: URL?
    /// 0–1: qué tan seguro es que sea el mismo libro (lo calcula `MetadataMatcher`).
    public var confidence: Double

    // Campos agregados después: opcionales para leer «Por revisar» guardado antes.
    /// Clave de la obra en Open Library («/works/OL…W»).
    public var workKey: String?
    /// Título original de la obra («Foundation» para «Fundación»).
    public var workTitle: String?
    /// Cuántas ediciones tiene la obra: las obras «de verdad» tienen muchas;
    /// los duplicados y las guías de estudio, una o dos.
    public var editionCount: Int?
    public var coverAlternatives: [URL]?
    public var notes: [Note]?

    /// Todos los ISBN conocidos de la edición (para reconocer el tuyo); no se guarda.
    public var knownISBNs: Set<String> = []

    private enum CodingKeys: String, CodingKey {
        case id, source, title, subtitle, authors, publisher, published, summary, isbn, language, subjects
        case series, seriesIndex, coverURL, confidence, workKey, workTitle, editionCount, coverAlternatives, notes
    }

    public init(id: String, source: Source, title: String, subtitle: String? = nil, authors: [String] = [],
                publisher: String? = nil, published: String? = nil, summary: String? = nil, isbn: String? = nil,
                language: String? = nil, subjects: [String] = [], series: String? = nil, seriesIndex: Double? = nil,
                coverURL: URL? = nil, confidence: Double = 0, workKey: String? = nil, workTitle: String? = nil,
                editionCount: Int? = nil, coverAlternatives: [URL]? = nil, knownISBNs: Set<String> = []) {
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
        self.workKey = workKey
        self.workTitle = workTitle
        self.editionCount = editionCount
        self.coverAlternatives = coverAlternatives
        self.knownISBNs = knownISBNs
    }

    /// Portadas a probar, en orden.
    public var covers: [URL] {
        var seen = Set<URL>()
        return ([coverURL].compactMap { $0 } + (coverAlternatives ?? [])).filter { seen.insert($0).inserted }
    }
}
