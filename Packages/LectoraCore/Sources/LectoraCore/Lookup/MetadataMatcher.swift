import Foundation

/// Decide qué tanto se parece un candidato al libro, si se puede aplicar solo
/// y cómo se combinan los datos. Afinado con respuestas reales (scripts/sondeo).
public enum MetadataMatcher {
    /// Desde aquí (y con título y autor seguros) se aplica solo; debajo va a «Por revisar».
    public static let autoApplyThreshold = 0.85
    /// Debajo de esto el candidato ni se muestra.
    public static let minimumShown = 0.4

    // MARK: Puntaje

    public struct Match: Sendable {
        public var confidence: Double
        public var title: Double
        public var author: Double
        public var sameISBN: Bool
        public var notes: [MetadataCandidate.Note]
    }

    /// Palabras de libros *sobre* un libro: resúmenes, guías, estuches…
    private static let derivative: Set<String> = [
        "resumen", "summary", "analisis", "analysis", "study", "sparknotes", "cliffsnotes", "guia", "guide",
        "estuche", "trilogia", "boxed", "box", "coleccion", "collection", "obras", "completas", "workbook",
        "selections", "adaptation", "adaptacion", "comentario", "critica", "criticism", "readers",
    ]

    public static func match(_ candidate: MetadataCandidate, for book: Book) -> Match {
        let bookTitle = SeriesParser.split(book.title)?.title ?? book.title
        var title = max(TextMatch.titleSimilarity(bookTitle, candidate.title),
                        candidate.workTitle.map { TextMatch.titleSimilarity(bookTitle, $0) } ?? 0)
        if let subtitle = candidate.subtitle {
            title = max(title, TextMatch.titleSimilarity(bookTitle, candidate.title + ": " + subtitle))
        }
        // Archivo sin autor: «cervantes don-quijote» trae el autor en el título.
        if book.authors.isEmpty, let author = candidate.authors.first {
            let words = Set(TextMatch.tokens(bookTitle)), withAuthor = Set(TextMatch.tokens(candidate.title + " " + author))
            if words.count >= 2, words.isSubset(of: withAuthor) { title = max(title, 0.75) }
        }
        let author = TextMatch.sameAuthorScore(book.authors, candidate.authors)
        let bookISBN = book.identifiers["isbn"].flatMap(ISBN.normalized)
        let sameISBN = bookISBN.map { candidate.knownISBNs.contains($0) || candidate.isbn == $0 } ?? false

        var notes: [MetadataCandidate.Note] = []
        var score = 0.65 * title + 0.35 * author

        if sameISBN {
            // Un ISBN mal copiado (o reciclado) apunta a otro libro: solo cuenta si el título cuadra.
            if title >= 0.5 { score = 0.98; notes.append(.sameISBN) } else { notes.append(.conflictingISBN) }
        }
        let candidateWords = Set(TextMatch.words(candidate.title + " " + (candidate.workTitle ?? "")))
        let bookWords = Set(TextMatch.words(bookTitle))
        if !candidateWords.intersection(derivative).subtracting(bookWords).isEmpty {
            score -= 0.3
            notes.append(.notTheBook)
        }
        if let mine = book.language, let theirs = candidate.language, mine != theirs {
            score -= 0.1
            notes.append(.otherLanguage)
        }
        // Entre dos iguales, la obra con más ediciones es la de verdad (no un duplicado).
        score += min(0.04, log10(Double(candidate.editionCount ?? 0) + 1) * 0.015)
        if !sameISBN { score = min(score, 0.97) }

        notes.append(title >= 0.95 ? .sameTitle : (title >= 0.6 ? .similarTitle : .otherTitle))
        notes.append(author >= 0.8 ? .sameAuthor : (author == 0.5 ? .unknownAuthor : .otherAuthor))
        return Match(confidence: max(0, min(score, 0.99)), title: title, author: author, sameISBN: sameISBN, notes: notes)
    }

    public static func score(_ candidate: MetadataCandidate, for book: Book) -> Double {
        match(candidate, for: book).confidence
    }

    /// Candidatos con su confianza, sin repetidos (la misma obra duplicada en
    /// Open Library cuenta una vez, completada con lo de sus copias), del más
    /// al menos probable.
    public static func rank(_ candidates: [MetadataCandidate], for book: Book) -> [MetadataCandidate] {
        var scored: [MetadataCandidate] = []
        for candidate in candidates {
            let result = match(candidate, for: book)
            guard result.confidence >= minimumShown else { continue }
            var copy = candidate
            copy.confidence = result.confidence
            copy.notes = result.notes
            scored.append(copy)
        }
        scored.sort(by: isMoreLikely)

        var result: [MetadataCandidate] = []
        for candidate in scored {
            if let index = result.firstIndex(where: { sameBook($0, candidate) }) {
                result[index] = merge(result[index], with: candidate)
            } else {
                result.append(candidate)
            }
        }
        return result
    }

    private static func isMoreLikely(_ a: MetadataCandidate, _ b: MetadataCandidate) -> Bool {
        if a.confidence != b.confidence { return a.confidence > b.confidence }
        return (a.editionCount ?? 0) > (b.editionCount ?? 0)
    }

    /// ¿Se aplica solo? Hace falta: confianza alta, título y autor seguros (o
    /// el mismo ISBN), y que no haya otro libro distinto casi igual de probable.
    public static func shouldAutoApply(_ ranked: [MetadataCandidate], for book: Book) -> Bool {
        guard let best = ranked.first, best.confidence >= autoApplyThreshold else { return false }
        let result = match(best, for: book)
        guard result.sameISBN || (result.title >= 0.95 && result.author >= 0.8) else { return false }
        // Otro libro distinto casi igual de probable: mejor preguntar. Otra
        // edición del mismo (mismo título, algún autor en común) no cuenta.
        let rivals = ranked.dropFirst().filter { $0.confidence >= best.confidence - 0.05 && !sameWork(best, $0) }
        return result.sameISBN || rivals.isEmpty
    }

    /// Mismo título y algún autor en común: otra edición (o un duplicado) del mismo libro.
    static func sameWork(_ a: MetadataCandidate, _ b: MetadataCandidate) -> Bool {
        let titles = [a.title, a.workTitle].compactMap { $0 }
        let others = [b.title, b.workTitle].compactMap { $0 }
        let sameTitle = titles.contains { x in others.contains { TextMatch.titleSimilarity(x, $0) >= 0.9 } }
        return sameTitle && TextMatch.sameAuthorScore(a.authors, b.authors) >= 0.5
    }

    /// Misma obra o mismo título y autor (Open Library tiene duplicados).
    static func sameBook(_ a: MetadataCandidate, _ b: MetadataCandidate) -> Bool {
        if let left = a.workKey, let right = b.workKey, left == right { return true }
        if let left = a.isbn, let right = b.isbn, left == right { return true }
        let sameWorkTitle = a.workTitle.map { TextMatch.fold($0) == TextMatch.fold(b.workTitle ?? "") } ?? false
        let sameTitle = sameWorkTitle || TextMatch.fold(TextMatch.mainTitle(a.title)) == TextMatch.fold(TextMatch.mainTitle(b.title))
        return sameTitle && TextMatch.sameAuthorScore(Array(a.authors.prefix(1)), Array(b.authors.prefix(1))) >= 0.8
    }

    /// Completa lo que le falte al primero con lo de otro que es el mismo libro
    /// (p. ej. la portada de un duplicado o la sinopsis de Google).
    public static func merge(_ best: MetadataCandidate, with other: MetadataCandidate) -> MetadataCandidate {
        var result = best
        if result.summary == nil { result.summary = other.summary }
        if result.publisher == nil { result.publisher = other.publisher }
        if result.published == nil { result.published = other.published }
        if result.isbn == nil { result.isbn = other.isbn }
        if result.language == nil { result.language = other.language }
        if result.series == nil { result.series = other.series; result.seriesIndex = other.seriesIndex }
        if result.subjects.isEmpty { result.subjects = other.subjects }
        var covers = result.covers
        for url in other.covers where !covers.contains(url) { covers.append(url) }
        result.coverURL = covers.first
        result.coverAlternatives = Array(covers.dropFirst())
        result.knownISBNs.formUnion(other.knownISBNs)
        return result
    }

    public static func enrich(_ best: MetadataCandidate, with others: [MetadataCandidate]) -> MetadataCandidate {
        others.filter { $0.id != best.id && sameBook(best, $0) }.reduce(best, merge)
    }

    // MARK: Combinar

    /// Importación automática: solo llena lo que falta. Lo que trae el archivo
    /// (que suele venir de la editorial) y lo que escribiste no se toca. Los
    /// datos propios de una edición (editorial, ISBN) solo si es de tu idioma.
    public static func fillMissing(_ book: Book, from candidate: MetadataCandidate) -> Book {
        var book = book
        let sameLanguage = book.language == nil || candidate.language == nil || book.language == candidate.language
        if book.authors.isEmpty, let author = candidate.authors.first { book.authors = [author] }
        if book.published == nil { book.published = candidate.published }
        if book.language == nil { book.language = candidate.language }
        if book.tags.isEmpty { book.tags = candidate.subjects }
        if book.summary?.isEmpty ?? true, let summary = candidate.summary, summaryFits(summary, book: book) {
            book.summary = summary
        }
        if sameLanguage {
            if book.publisher == nil { book.publisher = candidate.publisher }
            if book.identifiers["isbn"] == nil, let isbn = candidate.isbn { book.identifiers["isbn"] = isbn }
        }
        if book.series == nil, let series = candidate.series {
            book.series = series
            book.seriesIndex = candidate.seriesIndex
        }
        return MetadataCleaner.clean(book)
    }

    /// Elegiste este candidato: sus datos reemplazan a los del libro. Se
    /// conservan identidad, archivo, estado, valoración y etiquetas tuyas, y la
    /// forma en que escribiste título y autor si son los mismos («Gabriel García
    /// Márquez» con acentos no se cambia por «Gabriel Garcia Marquez»).
    public static func replace(_ book: Book, with candidate: MetadataCandidate) -> Book {
        var book = book
        let current = SeriesParser.split(book.title)?.title ?? book.title
        book.title = betterSpelling(current, candidate.title)
        if let author = candidate.authors.first {
            if let mine = book.authors.first, TextMatch.sameAuthorScore([mine], [author]) == 1 {
                book.authors[0] = betterSpelling(mine, author)
            } else {
                book.authors = [author]
            }
        }
        book.publisher = candidate.publisher ?? book.publisher
        book.published = candidate.published ?? book.published
        book.language = candidate.language ?? book.language
        if let summary = candidate.summary, summaryFits(summary, book: book) { book.summary = summary }
        if book.tags.isEmpty { book.tags = candidate.subjects }
        if let isbn = candidate.isbn { book.identifiers["isbn"] = isbn }
        if let series = candidate.series {
            book.series = series
            book.seriesIndex = candidate.seriesIndex
        }
        return MetadataCleaner.clean(book)
    }

    /// El mismo texto escrito de dos formas: se queda la tuya, salvo que la otra
    /// tenga los acentos que a la tuya le faltan. Si no es el mismo, la otra.
    static func betterSpelling(_ mine: String, _ theirs: String) -> String {
        guard TextMatch.fold(mine) == TextMatch.fold(theirs) else { return theirs }
        let accents = { (text: String) in text.unicodeScalars.filter { $0.value > 0x7F && CharacterSet.letters.contains($0) }.count }
        let shouting = theirs == theirs.uppercased() && theirs != theirs.lowercased()
        return accents(theirs) > accents(mine) && !shouting ? theirs : mine
    }

    /// Una sinopsis en otro idioma no se pone sola en tu libro (luego la podrá
    /// traducir la IA); si no se sabe el idioma de alguno de los dos, sí.
    static func summaryFits(_ summary: String, book: Book) -> Bool {
        guard let language = book.language, let detected = TextMatch.language(of: summary) else { return true }
        return language == detected
    }

    // MARK: Compatibilidad

    static func tokens(_ text: String) -> [String] { TextMatch.tokens(text) }

    static func titleSimilarity(_ a: String, _ b: String, subtitle: String?) -> Double {
        let plain = TextMatch.titleSimilarity(a, b)
        guard let subtitle else { return plain }
        return max(plain, TextMatch.titleSimilarity(a, b + ": " + subtitle))
    }

    static func authorSimilarity(_ a: [String], _ b: [String]) -> Double {
        TextMatch.sameAuthorScore(a, b)
    }
}
