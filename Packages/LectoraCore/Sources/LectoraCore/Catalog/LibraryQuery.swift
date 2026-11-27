import Foundation

/// La búsqueda de la tabla de la Mac (MG-1): texto libre y filtros con nombre, como en
/// Calibre. `autor:cortázar serie:"el señor" etiqueta:historia idioma:es estado:leyendo`.
/// Sin acentos ni mayúsculas: «cortazar» encuentra «Cortázar». Las palabras que siguen a un
/// filtro son de ese filtro: `autor:julio cortázar` es el autor «Julio Cortázar» (UX-4e; antes
/// «cortázar» se buscaba aparte y, en Buscar, no salía ningún subrayado). Para buscar texto
/// junto con un filtro, las palabras van antes: `ciudad autor:cortázar`.
public struct LibraryQuery: Equatable, Sendable {
    public enum Field: String, CaseIterable, Sendable {
        case author, series, tag, language, publisher, status, isbn, title
    }

    public struct Filter: Equatable, Sendable {
        public var field: Field
        public var value: String
        /// Las palabras que siguieron al filtro (`autor:julio cortázar` → «cortazar»): cada una
        /// debe estar en el mismo dato o, si no, en el título, la serie o las etiquetas del libro.
        public var more: [String] = []

        public init(field: Field, value: String, more: [String] = []) {
            self.field = field
            self.value = value
            self.more = more
        }
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
            } else if !filters.isEmpty {
                filters[filters.count - 1].more.append(Self.fold(token))
            } else {
                words.append(Self.fold(token))
            }
        }
    }

    public func matches(_ book: Book) -> Bool {
        let haystack = Self.haystack(book)
        guard words.allSatisfy({ haystack.contains($0) }) else { return false }
        return matchesFilters(book)
    }

    static func haystack(_ book: Book) -> String {
        fold(([book.title, book.series ?? ""] + book.authors + book.tags).joined(separator: " "))
    }

    /// Solo los filtros con nombre (`autor:`, `serie:`…): en Buscar, los subrayados se quedan
    /// con los de los libros que cumplen los filtros.
    public func matchesFilters(_ book: Book) -> Bool {
        filters.allSatisfy { filter in
            let values = Self.values(of: filter.field, in: book).map(Self.fold)
            guard values.contains(where: { Self.contains($0, filter.value, as: filter.field) }) else { return false }
            guard !filter.more.isEmpty else { return true }
            // Las palabras de más, en el mismo dato («Julio Cortázar» o «Cortázar, Julio») o en el libro.
            let field = values.joined(separator: " "), book = Self.haystack(book)
            return filter.more.allSatisfy { field.contains($0) || book.contains($0) }
        }
    }

    /// `isbn:978-84-376-0494-7` encuentra el guardado sin guiones (y al revés), y uno de 10
    /// cifras al de 13 (auditoría de medios): se comparan solo las cifras.
    static func contains(_ value: String, _ wanted: String, as field: Field) -> Bool {
        guard field == .isbn else { return value.contains(wanted) }
        let digits = { (text: String) in text.uppercased().filter { $0.isNumber || $0 == "X" } }
        let (stored, query) = (digits(value), digits(wanted))
        if let left = ISBN.normalized(stored), let right = ISBN.normalized(query) { return left == right }
        return !query.isEmpty && stored.contains(query)
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
