import Foundation

/// La búsqueda de la tabla de la Mac (MG-1): texto libre y filtros con nombre, como en
/// Calibre. `autor:cortázar serie:"el señor" etiqueta:historia idioma:es estado:leyendo`.
/// Sin acentos ni mayúsculas: «cortazar» encuentra «Cortázar».
public struct LibraryQuery: Equatable, Sendable {
    public enum Field: String, CaseIterable, Sendable {
        case author, series, tag, language, publisher, status, isbn, title
    }

    public struct Filter: Equatable, Sendable {
        public var field: Field
        public var value: String
    }

    /// Palabras sueltas: cada una debe aparecer en el título, el autor, la serie o las etiquetas.
    public var words: [String] = []
    public var filters: [Filter] = []

    public var isEmpty: Bool { words.isEmpty && filters.isEmpty }

    /// Nombres que se aceptan antes de los dos puntos, en español y en inglés.
    static let names: [String: Field] = [
        "autor": .author, "author": .author, "autora": .author,
        "serie": .series, "series": .series,
        "etiqueta": .tag, "etiquetas": .tag, "tag": .tag, "tags": .tag,
        "idioma": .language, "lang": .language, "language": .language,
        "editorial": .publisher, "publisher": .publisher,
        "estado": .status, "status": .status,
        "isbn": .isbn,
        "titulo": .title, "título": .title, "title": .title,
    ]

    public init(_ text: String) {
        for token in Self.tokens(text) {
            if let colon = token.firstIndex(of: ":"), colon != token.startIndex,
               let field = Self.names[Self.fold(String(token[..<colon]))] {
                let value = String(token[token.index(after: colon)...])
                if !value.isEmpty { filters.append(Filter(field: field, value: Self.fold(value))) }
            } else {
                words.append(Self.fold(token))
            }
        }
    }

    public func matches(_ book: Book) -> Bool {
        let haystack = Self.fold(([book.title, book.series ?? ""] + book.authors + book.tags).joined(separator: " "))
        guard words.allSatisfy({ haystack.contains($0) }) else { return false }
        return matchesFilters(book)
    }

    /// Solo los filtros con nombre (`autor:`, `serie:`…): en Buscar, los subrayados se quedan
    /// con los de los libros que cumplen los filtros.
    public func matchesFilters(_ book: Book) -> Bool {
        filters.allSatisfy { filter in
            Self.values(of: filter.field, in: book).contains { Self.fold($0).contains(filter.value) }
        }
    }

    /// Buscar en todo (SG-3): cada palabra aparece en alguno de los textos, en cualquier orden.
    /// «imperio otomano» encuentra «el Imperio de los sultanes otomanos». Sin palabras, nada.
    public func matches(text fields: [String?]) -> Bool {
        guard !words.isEmpty else { return false }
        let haystack = Self.fold(fields.compactMap { $0 }.joined(separator: " "))
        return words.allSatisfy { haystack.contains($0) }
    }

    static func values(of field: Field, in book: Book) -> [String] {
        switch field {
        case .author: book.authors
        case .series: book.series.map { [$0] } ?? []
        case .tag: book.tags
        case .language: book.language.map { [$0] + (languageNames[$0] ?? []) } ?? []
        case .publisher: book.publisher.map { [$0] } ?? []
        case .status: [book.readingStatus.rawValue] + (statusNames[book.readingStatus] ?? [])
        case .isbn: book.identifiers["isbn"].map { [$0] } ?? []
        case .title: [book.title]
        }
    }

    /// `estado:leyendo`, `estado:leido`, `estado:por leer`…
    static let statusNames: [ReadingStatus: [String]] = [
        .toRead: ["por leer", "pendiente"],
        .reading: ["leyendo"],
        .finished: ["leido", "terminado"],
        .abandoned: ["abandonado", "dejado"],
    ]

    /// `idioma:español` además de `idioma:es`.
    static let languageNames: [String: [String]] = [
        "es": ["espanol", "spanish"], "spa": ["espanol", "spanish"],
        "en": ["ingles", "english"], "eng": ["ingles", "english"],
        "fr": ["frances", "french"], "de": ["aleman", "german"],
        "it": ["italiano", "italian"], "pt": ["portugues", "portuguese"],
    ]

    /// Separa por espacios, respetando lo que va entre comillas (`serie:"el señor"`).
    static func tokens(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var quoted = false
        for character in text {
            if character == "\"" || character == "“" || character == "”" {
                quoted.toggle()
            } else if character.isWhitespace && !quoted {
                if !current.isEmpty { tokens.append(current) }
                current = ""
            } else {
                current.append(character)
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es"))
    }
}
