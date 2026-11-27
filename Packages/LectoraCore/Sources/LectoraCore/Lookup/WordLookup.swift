import Foundation

/// «Consultar» en el lector (SG-4): lo que se busca de una palabra o frase subrayada con el
/// dedo. La traducción y el diccionario son del sistema (en el teléfono); aquí vive lo que se
/// puede probar sin pantalla: limpiar lo elegido, el idioma y el resumen de Wikipedia.
public enum WordLookup {
    /// Más de esto ya es una frase: se traduce, pero no se busca en el diccionario ni en Wikipedia.
    public static let maxWordsForEntry = 4

    /// Lo elegido sin comillas, rayas ni puntuación en las orillas: «“astillero,”» → «astillero».
    public static func term(from selection: String) -> String {
        let edges = CharacterSet.punctuationCharacters.union(.symbols).union(.whitespacesAndNewlines)
        let collapsed = selection.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return collapsed.trimmingCharacters(in: edges)
    }

    /// Una entrada de diccionario o enciclopedia: pocas palabras y con letras.
    public static func isEntry(_ term: String) -> Bool {
        let words = term.split(separator: " ")
        return !words.isEmpty && words.count <= maxWordsForEntry && term.contains(where: \.isLetter)
    }

    /// El código de dos letras del idioma del libro («en-US» → «en», «spa» → «es»), o nil.
    public static func languageCode(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        let base = raw.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init) ?? ""
        let threeLetter = ["spa": "es", "eng": "en", "fra": "fr", "fre": "fr", "deu": "de", "ger": "de",
                           "ita": "it", "por": "pt", "cat": "ca", "lat": "la"]
        if let mapped = threeLetter[base] { return mapped }
        return base.count == 2 ? base : nil
    }

    /// Se traduce cuando el libro no está en español (o no se sabe en qué está).
    public static func needsTranslation(bookLanguage: String?) -> Bool {
        languageCode(bookLanguage) != "es"
    }
}

/// El primer párrafo de un artículo de Wikipedia.
public struct WikipediaSummary: Equatable, Sendable {
    public let title: String
    public let extract: String
    public let url: URL
}

/// Wikipedia en el idioma del libro, por su API pública de resúmenes. Sin llave ni cuenta.
public struct WikipediaClient: Sendable {
    let transport: any HTTPTransport

    public init(transport: any HTTPTransport = URLSession.shared) {
        self.transport = transport
    }

    /// La dirección del resumen de `term` en la Wikipedia de `language` (español si no se sabe).
    public static func summaryURL(for term: String, language: String?) -> URL? {
        let lang = WordLookup.languageCode(language) ?? "es"
        let title = term.replacingOccurrences(of: " ", with: "_")
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/?#")
        guard let encoded = title.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: "https://\(lang).wikipedia.org/api/rest_v1/page/summary/\(encoded)")
    }

    /// El resumen, o nil si no hay artículo, si es una página de desambiguación o si no hay red.
    public func summary(for term: String, language: String?) async -> WikipediaSummary? {
        guard WordLookup.isEntry(term), let url = Self.summaryURL(for: term, language: language) else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Gabinete/1.0 (app de lectura personal)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8
        guard let (data, response) = try? await transport.send(request), response.statusCode == 200 else { return nil }
        return Self.parse(data)
    }

    static func parse(_ data: Data) -> WikipediaSummary? {
        struct Page: Decodable {
            struct Links: Decodable {
                struct Link: Decodable { let page: URL }
                let mobile: Link?
                let desktop: Link?
            }
            let type: String?
            let title: String
            let extract: String?
            let content_urls: Links?
        }
        guard let page = try? JSONDecoder().decode(Page.self, from: data),
              page.type != "disambiguation",
              let extract = page.extract?.trimmingCharacters(in: .whitespacesAndNewlines), !extract.isEmpty,
              let url = page.content_urls?.mobile?.page ?? page.content_urls?.desktop?.page
        else { return nil }
        return WikipediaSummary(title: page.title, extract: extract, url: url)
    }
}
