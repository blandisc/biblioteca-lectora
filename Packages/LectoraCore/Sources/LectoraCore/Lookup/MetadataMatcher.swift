import Foundation

/// Decide qué tanto se parece un candidato al libro y cómo se combinan los datos.
public enum MetadataMatcher {
    /// Desde aquí se aplica solo; debajo va a «Por revisar».
    public static let autoApplyThreshold = 0.85
    /// Debajo de esto el candidato ni se muestra.
    public static let minimumShown = 0.35

    // MARK: Puntaje

    public static func score(_ candidate: MetadataCandidate, for book: Book) -> Double {
        if let isbn = book.identifiers["isbn"], let other = candidate.isbn,
           MetadataCleaner.cleanISBN(isbn) == MetadataCleaner.cleanISBN(other) {
            return 0.98
        }
        let title = titleSimilarity(book.title, candidate.title, subtitle: candidate.subtitle)
        let author = authorSimilarity(book.authors, candidate.authors)
        return min(0.95, 0.6 * title + 0.4 * author)
    }

    /// Candidatos con su confianza, sin repetidos, del más al menos probable.
    public static func rank(_ candidates: [MetadataCandidate], for book: Book) -> [MetadataCandidate] {
        var seen = Set<String>()
        return candidates
            .map { candidate -> MetadataCandidate in
                var scored = candidate
                scored.confidence = score(candidate, for: book)
                return scored
            }
            .filter { $0.confidence >= minimumShown }
            .sorted { $0.confidence > $1.confidence }
            .filter { candidate in
                let key = candidate.isbn ?? "\(candidate.source.rawValue)|\(tokens(candidate.title).joined(separator: " "))"
                return seen.insert(key).inserted
            }
    }

    /// Completa lo que le falte al mejor candidato con otros que sean el mismo
    /// libro (p. ej. la sinopsis de Google y la portada de Open Library).
    public static func enrich(_ best: MetadataCandidate, with others: [MetadataCandidate]) -> MetadataCandidate {
        var result = best
        let sameBook = others.filter {
            $0.id != best.id && ($0.isbn != nil && $0.isbn == best.isbn
                || titleSimilarity(best.title, $0.title, subtitle: nil) > 0.9 && authorSimilarity(best.authors, $0.authors) > 0.9)
        }
        for other in sameBook {
            if result.summary == nil { result.summary = other.summary }
            if result.coverURL == nil { result.coverURL = other.coverURL }
            if result.publisher == nil { result.publisher = other.publisher }
            if result.published == nil { result.published = other.published }
            if result.isbn == nil { result.isbn = other.isbn }
            if result.language == nil { result.language = other.language }
            if result.series == nil { result.series = other.series; result.seriesIndex = other.seriesIndex }
            if result.subjects.isEmpty { result.subjects = other.subjects }
        }
        return result
    }

    // MARK: Combinar

    /// Importación automática: solo llena lo que falta. Lo que trae el archivo
    /// (que suele venir de la editorial) y lo que escribiste no se toca.
    public static func fillMissing(_ book: Book, from candidate: MetadataCandidate) -> Book {
        var book = book
        if book.authors.isEmpty { book.authors = candidate.authors }
        if book.publisher == nil { book.publisher = candidate.publisher }
        if book.published == nil { book.published = candidate.published }
        if book.summary?.isEmpty ?? true { book.summary = candidate.summary }
        if book.language == nil { book.language = candidate.language }
        if book.tags.isEmpty { book.tags = candidate.subjects }
        if book.identifiers["isbn"] == nil, let isbn = candidate.isbn { book.identifiers["isbn"] = isbn }
        if book.series == nil, let series = candidate.series {
            book.series = series
            book.seriesIndex = candidate.seriesIndex
        }
        return MetadataCleaner.clean(book)
    }

    /// Elegiste este candidato en «Por revisar»: sus datos reemplazan a los del
    /// libro. Se conservan identidad, archivo, estado, valoración y etiquetas tuyas.
    public static func replace(_ book: Book, with candidate: MetadataCandidate) -> Book {
        var book = book
        book.title = candidate.title
        if !candidate.authors.isEmpty { book.authors = candidate.authors }
        book.publisher = candidate.publisher ?? book.publisher
        book.published = candidate.published ?? book.published
        book.summary = candidate.summary ?? book.summary
        book.language = candidate.language ?? book.language
        if book.tags.isEmpty { book.tags = candidate.subjects }
        if let isbn = candidate.isbn { book.identifiers["isbn"] = isbn }
        if let series = candidate.series {
            book.series = series
            book.seriesIndex = candidate.seriesIndex
        }
        return MetadataCleaner.clean(book)
    }

    // MARK: Parecido de textos

    private static let stopWords: Set<String> = ["el", "la", "los", "las", "un", "una", "de", "del", "y", "e",
                                                 "the", "a", "an", "of", "and", "to", "in"]

    static func tokens(_ text: String) -> [String] {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && !stopWords.contains($0) }
    }

    /// 0–1. Cuenta como igual si uno es el otro más un subtítulo.
    static func titleSimilarity(_ a: String, _ b: String, subtitle: String?) -> Double {
        let left = Set(tokens(a)), right = Set(tokens(b))
        guard !left.isEmpty, !right.isEmpty else { return 0 }
        if left == right { return 1 }
        if let subtitle, Set(tokens(b + " " + subtitle)) == left { return 1 }
        let shared = Double(left.intersection(right).count)
        let jaccard = shared / Double(left.union(right).count)
        let containment = shared / Double(min(left.count, right.count))
        return max(jaccard, containment * 0.9)
    }

    /// 1 si coincide algún apellido; 0.5 si falta información; 0 si no coinciden.
    static func authorSimilarity(_ a: [String], _ b: [String]) -> Double {
        let left = Set(a.compactMap { tokens($0).last }), right = Set(b.compactMap { tokens($0).last })
        guard !left.isEmpty, !right.isEmpty else { return 0.5 }
        return left.isDisjoint(with: right) ? 0 : 1
    }
}
