import Foundation

/// Reglas para «pulir» los datos de un libro antes de guardarlo. Son las mismas
/// para lo que trae el archivo, lo que llega de internet y lo que escribes tú.
public enum MetadataCleaner {
    /// - Parameter manual: datos escritos a mano. Se respetan mayúsculas, número
    ///   de etiquetas y fechas tal cual; solo se quitan espacios sobrantes.
    public static func clean(_ book: Book, fileName: String? = nil, manual: Bool = false) -> Book {
        var book = book
        if manual {
            book.title = collapseSpaces(book.title)
            book.authors = book.authors.map(collapseSpaces).filter { !$0.isEmpty }
            book.tags = cleanTags(book.tags)
            book.series = book.series.map(collapseSpaces).flatMap { $0.isEmpty ? nil : $0 }
            if book.series == nil { book.seriesIndex = nil }
            book.published = book.published.map { cleanDate($0) ?? collapseSpaces($0) }
            if let isbn = book.identifiers["isbn"] { book.identifiers["isbn"] = cleanISBN(isbn) }
            return book
        }
        var title = cleanTitle(book.title, language: book.language.flatMap(cleanLanguage))
        if title.isEmpty, let fileName { title = titleFromFileName(fileName) }
        book.title = title.isEmpty ? "Sin título" : title
        book.authors = cleanAuthors(book.authors)
        book.language = book.language.flatMap(cleanLanguage)
        book.published = book.published.flatMap(cleanDate)
        book.tags = Array(cleanTags(book.tags).prefix(8))
        book.series = book.series.map(collapseSpaces).flatMap { $0.isEmpty ? nil : $0 }
        if book.series == nil { book.seriesIndex = nil }
        book.publisher = book.publisher.map(collapseSpaces).flatMap { $0.isEmpty ? nil : $0 }
        if let isbn = book.identifiers["isbn"] {
            book.identifiers["isbn"] = cleanISBN(isbn)
        }
        return book
    }

    /// Quita lo que las tiendas y los archivos le agregan al título.
    public static func cleanTitle(_ title: String, language: String? = nil) -> String {
        var cleaned = title
        let junk = [
            #"\((Spanish|English) Edition\)"#, #"\(Edición española\)"#, #"\[(epub|mobi|pdf|azw3?)\]"#,
            #"\((epub|mobi|pdf)\)"#, #"[ _-]v\d+(\.\d+)?$"#, #" - Copy$"#, #" - copia$"#,
        ]
        for pattern in junk {
            cleaned = cleaned.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
        }
        cleaned = collapseSpaces(cleaned).trimmingCharacters(in: CharacterSet(charactersIn: " -_.,:;"))
        // TODO EN MAYÚSCULAS (de tiendas y archivos): en español solo va mayúscula
        // al inicio («Cien años de soledad»); en inglés, en cada palabra.
        // Las siglas cortas («SPQR», «IT») se respetan.
        let letters = cleaned.filter(\.isLetter)
        if letters.count > 5, cleaned == cleaned.uppercased(), cleaned != cleaned.lowercased() {
            if language == "en" {
                cleaned = cleaned.lowercased().capitalized
            } else {
                let lower = cleaned.lowercased()
                cleaned = lower.prefix(1).uppercased() + lower.dropFirst()
            }
        }
        return cleaned
    }

    /// «cervantes_don-quijote» → «cervantes don quijote».
    public static func titleFromFileName(_ fileName: String) -> String {
        let base = (fileName as NSString).deletingPathExtension
        return cleanTitle(base.replacingOccurrences(of: "[_]+", with: " ", options: .regularExpression))
    }

    /// «Cortázar, Julio» → «Julio Cortázar»; sin repetidos ni «Desconocido».
    public static func cleanAuthors(_ authors: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in authors.flatMap({ $0.components(separatedBy: " & ") }) {
            var name = collapseSpaces(raw)
            let parts = name.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            // «Martin Luther King, Jr.» y «Planeta, S.A.» no se invierten.
            let suffixes: Set<String> = ["jr", "jr.", "sr", "sr.", "ii", "iii", "iv", "s.a.", "s.l.", "inc.", "ltd."]
            if parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty, !suffixes.contains(parts[1].lowercased()),
               !parts[1].contains(" ") || parts[0].split(separator: " ").count == 1 {
                name = "\(parts[1]) \(parts[0])"
            }
            let key = name.lowercased()
            guard !name.isEmpty, !["unknown", "desconocido", "anónimo"].contains(key), seen.insert(key).inserted else { continue }
            result.append(name)
        }
        return result
    }

    /// «spa», «es-MX», «Spanish» → «es».
    public static func cleanLanguage(_ language: String) -> String? {
        let lower = language.lowercased().trimmingCharacters(in: .whitespaces)
        let names = ["spanish": "es", "español": "es", "castellano": "es", "english": "en", "inglés": "en"]
        if let code = names[lower] { return code }
        let short = CalibreOPF.iso639_1(lower)
        if short.count == 2 { return short }
        let prefix = short.split(separator: "-").first.map(String.init) ?? short
        return prefix.count == 2 ? prefix : (short.isEmpty ? nil : short)
    }

    /// Fechas a «AAAA» o «AAAA-MM-DD»; descarta lo que no sea fecha.
    public static func cleanDate(_ date: String) -> String? {
        let trimmed = date.trimmingCharacters(in: .whitespaces)
        if trimmed.contains("T"), let day = CalibreOPF.calendarDay(trimmed) {
            return day.hasSuffix("-01-01") ? String(day.prefix(4)) : day
        }
        guard let match = trimmed.range(of: #"^\d{4}(-\d{2}(-\d{2})?)?"#, options: .regularExpression) else { return nil }
        let value = String(trimmed[match])
        if value.hasSuffix("-01-01") { return String(value.prefix(4)) }
        if value.count == 7 { return value + "-01" }
        return value
    }

    public static func cleanTags(_ tags: [String]) -> [String] {
        var seen = Set<String>()
        return tags
            .flatMap { $0.components(separatedBy: CharacterSet(charactersIn: ",;/")) }
            .map(collapseSpaces)
            .filter { !$0.isEmpty && $0.count <= 40 }
            .filter { seen.insert($0.lowercased()).inserted }
    }

    /// Solo dígitos (y X final); si no tiene 10 o 13, se deja como venía.
    public static func cleanISBN(_ isbn: String) -> String {
        let digits = isbn.uppercased().filter { $0.isNumber || $0 == "X" }
        return [10, 13].contains(digits.count) ? digits : isbn
    }

    static func collapseSpaces(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
