import Foundation

/// Busca un libro en internet y decide qué hacer con lo que encuentra.
///
/// Orden de búsqueda (se detiene en cuanto hay un candidato seguro):
/// 1. ISBN válido → la obra que contiene esa edición.
/// 2. Título y autor, pidiendo la edición en el idioma del libro.
/// 3. Solo el título (por si el autor del archivo está mal).
/// Con clave de Google Books, también se pregunta ahí. Al final, la sinopsis
/// de la obra del mejor candidato.
public struct MetadataService: Sendable {
    public enum Decision: Equatable, Sendable {
        /// Es claramente el mismo libro: se completa solo.
        case apply
        /// Hay candidatos pero no es seguro: a «Por revisar».
        case review
        /// Ninguna fuente lo tiene.
        case notFound
        /// No se pudo preguntar (sin internet o fuentes caídas): se intenta después.
        case unreachable
    }

    public struct Result: Sendable {
        public var candidates: [MetadataCandidate]
        public var decision: Decision
    }

    private let fetcher: MetadataFetching
    private let googleKey: String?

    public init(fetcher: MetadataFetching = HTTPFetcher(), googleKey: String? = nil) {
        self.fetcher = fetcher
        self.googleKey = googleKey.flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 }
    }

    /// Búsqueda automática (al importar) o pedida desde la ficha.
    public func lookup(_ book: Book) async -> Result {
        let isbn = book.identifiers["isbn"].flatMap(ISBN.normalized)
        let title = TextMatch.mainTitle(SeriesParser.split(book.title)?.title ?? book.title)
        let author = book.authors.first.flatMap { TextMatch.nameParts($0).isEmpty ? nil : $0 }
        return await search(book: book, isbn: isbn, title: title.isEmpty ? book.title : title, author: author)
    }

    /// Búsqueda con otros datos («Buscar con otro título o autor»). El puntaje
    /// se calcula contra lo que escribiste, no contra los datos del archivo.
    public func search(title: String, author: String?, isbn: String?, for book: Book) async -> Result {
        var query = book
        query.title = title
        query.authors = author.map { [$0] } ?? []
        query.identifiers["isbn"] = isbn
        let validISBN = isbn.flatMap(ISBN.normalized)
        return await search(book: query, isbn: validISBN, title: title, author: author)
    }

    private func search(book: Book, isbn: String?, title: String, author: String?) async -> Result {
        var found: [MetadataCandidate] = []
        var asked = 0, failed = 0

        func ask(_ url: URL, parse: (Data) -> [MetadataCandidate]) async {
            asked += 1
            switch await fetcher.get(url) {
            case .ok(let data): found += parse(data)
            case .notFound: break
            case .failed: failed += 1
            }
        }
        func settled() -> Bool { MetadataMatcher.shouldAutoApply(MetadataMatcher.rank(found, for: book), for: book) }

        if let isbn {
            await ask(OpenLibrary.searchURL(isbn: isbn)) { OpenLibrary.candidates(from: $0) }
            if let key = googleKey {
                await ask(GoogleBooks.searchURL(isbn: isbn, title: title, author: nil, language: nil, apiKey: key), parse: GoogleBooks.candidates)
            }
        }
        let hasTitle = !title.trimmingCharacters(in: .whitespaces).isEmpty
        if hasTitle, !settled() {
            let query = ([title] + (author.map { [$0] } ?? [])).joined(separator: " ")
            await ask(OpenLibrary.searchURL(query: query, language: book.language)) { OpenLibrary.candidates(from: $0, language: book.language) }
            if let key = googleKey {
                await ask(GoogleBooks.searchURL(isbn: nil, title: title, author: author, language: book.language, apiKey: key),
                          parse: GoogleBooks.candidates)
            }
        }
        if hasTitle, !settled(), author != nil {
            await ask(OpenLibrary.searchURL(query: title, language: book.language)) { OpenLibrary.candidates(from: $0, language: book.language) }
        }

        var ranked = MetadataMatcher.rank(found, for: book)
        if ranked.isEmpty {
            return Result(candidates: [], decision: failed == asked ? .unreachable : .notFound)
        }
        ranked = Array(ranked.prefix(6))
        ranked[0] = await withSummary(ranked[0], for: book)
        let decision: Decision = MetadataMatcher.shouldAutoApply(ranked, for: book) ? .apply : .review
        return Result(candidates: ranked, decision: decision)
    }

    /// Sinopsis de la obra (Open Library la guarda aparte de la búsqueda).
    public func withSummary(_ candidate: MetadataCandidate, for book: Book) async -> MetadataCandidate {
        guard candidate.summary == nil, let key = candidate.workKey,
              let data = await fetcher.get(OpenLibrary.workURL(key: key)).data else { return candidate }
        var result = candidate
        result.summary = OpenLibrary.workDescription(from: data)
        return result
    }

    /// La primera portada que sirva (que exista y no sea una miniatura).
    public func cover(for candidate: MetadataCandidate) async -> Data? {
        var fallback: Data?
        for url in candidate.covers {
            guard let data = await fetcher.get(url).data else { continue }
            switch CoverCheck.evaluate(data) {
            case .good: return data
            case .small: if fallback == nil { fallback = data }
            case .unusable: continue
            }
        }
        return fallback
    }
}

/// ¿Sirve esta imagen como portada? Afinado con el sondeo: en Open Library
/// las grandes miden ~500 px de alto; algunas son miniaturas de 128 px.
public enum CoverCheck {
    public enum Verdict: Equatable { case good, small, unusable }

    public static func evaluate(_ data: Data) -> Verdict {
        guard data.count > 2_000 else { return .unusable }
        guard let size = ImageSize.read(data) else { return data.count > 15_000 ? .good : .small }
        let ratio = Double(size.width) / Double(size.height)
        // Una portada es vertical; algo cuadrado o apaisado es otra cosa (un logo, un aviso).
        guard size.height >= 120, ratio > 0.45, ratio < 0.9 else { return .unusable }
        return size.height >= 300 ? .good : .small
    }
}

/// Ancho y alto de un JPEG o PNG leyendo solo la cabecera.
enum ImageSize {
    static func read(_ data: Data) -> (width: Int, height: Int)? {
        let bytes = [UInt8](data.prefix(64 * 1024))
        if bytes.count > 24, bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            let width = Int(bytes[16]) << 24 | Int(bytes[17]) << 16 | Int(bytes[18]) << 8 | Int(bytes[19])
            let height = Int(bytes[20]) << 24 | Int(bytes[21]) << 16 | Int(bytes[22]) << 8 | Int(bytes[23])
            return (width, height)
        }
        guard bytes.count > 4, bytes[0] == 0xFF, bytes[1] == 0xD8 else { return nil }
        var index = 2
        while index + 9 < bytes.count {
            guard bytes[index] == 0xFF else { index += 1; continue }
            let marker = bytes[index + 1]
            let length = Int(bytes[index + 2]) << 8 | Int(bytes[index + 3])
            // SOF0–SOF15 salvo DHT (C4), JPG (C8) y DAC (CC): ahí vienen las medidas.
            if (0xC0...0xCF).contains(marker), ![0xC4, 0xC8, 0xCC].contains(marker) {
                let height = Int(bytes[index + 5]) << 8 | Int(bytes[index + 6])
                let width = Int(bytes[index + 7]) << 8 | Int(bytes[index + 8])
                return (width, height)
            }
            index += 2 + max(length, 0)
        }
        return nil
    }
}
