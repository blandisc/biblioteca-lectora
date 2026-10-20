import Foundation
import LectoraCore

/// Busca un libro en Open Library y Google Books (APIs públicas, sin clave) y
/// devuelve los candidatos ordenados por confianza.
struct MetadataLookup {
    var session: URLSession = .shared

    func candidates(for book: Book) async -> [MetadataCandidate] {
        let isbn = book.identifiers["isbn"]
        let author = book.authors.first
        var found = await search(isbn: isbn, title: book.title, author: author, language: book.language)
        // Un ISBN que no aparece no impide buscar por título y autor.
        if found.isEmpty, isbn != nil {
            found = await search(isbn: nil, title: book.title, author: author, language: book.language)
        }
        var ranked = MetadataMatcher.rank(found, for: book)
        guard var best = ranked.first else { return [] }
        best = MetadataMatcher.enrich(best, with: Array(ranked.dropFirst()))
        // Open Library guarda la sinopsis en la obra, no en la búsqueda.
        if best.summary == nil, let key = ranked.first(where: { $0.source == .openLibrary })?.id.dropFirst(3),
           let data = await fetch(OpenLibrary.workURL(key: String(key))) {
            best.summary = OpenLibrary.workDescription(from: data)
        }
        ranked[0] = best
        return ranked
    }

    func download(_ url: URL) async -> Data? {
        guard let data = await fetch(url), data.count > 1_000 else { return nil }
        return data
    }

    private func search(isbn: String?, title: String, author: String?, language: String?) async -> [MetadataCandidate] {
        async let openLibrary = fetch(OpenLibrary.searchURL(isbn: isbn, title: title, author: author))
        async let google = fetch(GoogleBooks.searchURL(isbn: isbn, title: title, author: author, language: isbn == nil ? language : nil))
        let ol = await openLibrary.map(OpenLibrary.candidates) ?? []
        let gb = await google.map(GoogleBooks.candidates) ?? []
        return ol + gb
    }

    private func fetch(_ url: URL) async -> Data? {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("Lectora/0.1 (lector personal)", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return data
    }
}
