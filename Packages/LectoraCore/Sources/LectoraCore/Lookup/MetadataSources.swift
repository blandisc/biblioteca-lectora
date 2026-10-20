import Foundation

/// Consultas y lectura de respuestas de las fuentes públicas de metadatos.
/// Sin red aquí: `MetadataService` hace las peticiones y este código arma las
/// URL y entiende las respuestas, para poder probarlo con respuestas reales
/// guardadas (Tests/…/Fixtures, bajadas con scripts/sondeo).
public enum OpenLibrary {
    static let fields = [
        "key", "title", "subtitle", "author_name", "author_alternative_name", "first_publish_year", "edition_count",
        "language", "subject", "cover_i", "isbn", "series_name", "series_position",
        "editions", "editions.key", "editions.title", "editions.subtitle", "editions.language", "editions.isbn",
        "editions.publisher", "editions.publish_date", "editions.cover_i",
    ].joined(separator: ",")

    /// Búsqueda general (`q`): encuentra la obra también por el título de una
    /// traducción («Fundación» → «Foundation»), cosa que `title=` no hace.
    /// Con `lang`, la edición que acompaña a cada obra es la de ese idioma.
    public static func searchURL(query: String, language: String?, limit: Int = 8) -> URL {
        url(["q": query], language: language, limit: limit)
    }

    /// Por ISBN: la obra que contiene esa edición, con esa edición.
    public static func searchURL(isbn: String) -> URL {
        url(["isbn": isbn], language: nil, limit: 3)
    }

    private static func url(_ params: [String: String], language: String?, limit: Int) -> URL {
        var components = URLComponents(string: "https://openlibrary.org/search.json")!
        var items = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        items.append(URLQueryItem(name: "limit", value: String(limit)))
        items.append(URLQueryItem(name: "fields", value: fields))
        // Open Library espera el código de dos letras («es»); con «spa» lo ignora (lo mostró el sondeo).
        if let language, language.count == 2 { items.append(URLQueryItem(name: "lang", value: language)) }
        components.queryItems = items
        return components.url!
    }

    /// Descripción de la obra (`/works/OL…W.json`), que la búsqueda no trae.
    public static func workURL(key: String) -> URL {
        URL(string: "https://openlibrary.org\(key).json")!
    }

    /// Ediciones de una obra, para elegir la mejor portada.
    public static func editionsURL(workKey: String) -> URL {
        URL(string: "https://openlibrary.org\(workKey)/editions.json?limit=60")!
    }

    /// Portadas de las ediciones, de la mejor a la peor: en tu idioma, con ISBN
    /// (ediciones modernas, con arte de la editorial) y recientes. Las de
    /// ejemplares viejos escaneados en bibliotecas (tela lisa, etiquetas de
    /// código de barras) quedan al final.
    public static func editionCovers(from data: Data, language: String?, title: String? = nil) -> [URL] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = root["entries"] as? [[String: Any]] else { return [] }
        // Novelas gráficas, lecturas graduadas, resúmenes: otra cosa con el mismo nombre.
        let derivative = ["grafica", "graphic", "comic", "resumen", "summary", "readers", "level", "adaptacion",
                          "adaptation", "guia", "study", "workbook", "extraits", "abridged"]
        let scored: [(score: Double, cover: Int)] = entries.compactMap { entry in
            guard let cover = (entry["covers"] as? [Int])?.first(where: { $0 > 0 }) else { return nil }
            let codes = (entry["languages"] as? [[String: Any]] ?? []).compactMap { ($0["key"] as? String)?.components(separatedBy: "/").last }
            let languages = codes.compactMap(MetadataCleaner.cleanLanguage)
            let editionTitle = [entry["title"] as? String, entry["subtitle"] as? String].compactMap { $0 }.joined(separator: " ")
            // El título de la edición delata el idioma aunque no esté anotado:
            // sin idioma y con otro título («Aşk ve Gurur», «Les Misérables») no sirve.
            let sameTitle = title.map { TextMatch.titleSimilarity($0, editionTitle) >= 0.9 } ?? false
            var score = sameTitle ? 2.0 : 0
            if let language {
                if languages.contains(language) { score += 4 } else if !languages.isEmpty || !sameTitle { score -= 3 }
            }
            if TextMatch.words(editionTitle).contains(where: { word in derivative.contains(word) }) { score -= 4 }
            if !((entry["isbn_13"] as? [String]) ?? []).isEmpty { score += 1.5 } else if entry["isbn_10"] != nil { score += 1 }
            if let year = (entry["publish_date"] as? String).flatMap(year).flatMap(Int.init) {
                score += year >= 2000 ? 1 : (year >= 1980 ? 0.5 : 0)
            }
            return (score, cover)
        }
        // Solo las que convencen; si ninguna, se queda la de la edición que trajo la búsqueda.
        return scored.filter { $0.score > 0 }.sorted { $0.score > $1.score }.prefix(4).compactMap { coverURL(id: $0.cover) }
    }

    /// Portada por número; `default=false` da 404 en vez de una imagen vacía.
    public static func coverURL(id: Int) -> URL? {
        id > 0 ? URL(string: "https://covers.openlibrary.org/b/id/\(id)-L.jpg?default=false") : nil
    }

    /// - Parameter language: idioma del libro. Una edición en otro idioma no
    ///   presta sus datos (título, editorial, ISBN, portada): se usan los de la obra.
    public static func candidates(from data: Data, language: String? = nil) -> [MetadataCandidate] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let docs = root["docs"] as? [[String: Any]] else { return [] }
        return docs.compactMap { candidate(from: $0, language: language) }
    }

    static func candidate(from doc: [String: Any], language preferred: String? = nil) -> MetadataCandidate? {
        guard let workTitle = doc["title"] as? String, let key = doc["key"] as? String else { return nil }
        var edition = ((doc["editions"] as? [String: Any])?["docs"] as? [[String: Any]])?.first ?? [:]
        if let preferred, let code = (edition["language"] as? [String])?.first,
           let editionLanguage = MetadataCleaner.cleanLanguage(code), editionLanguage != preferred {
            edition = [:]
        }
        let editionCount = doc["edition_count"] as? Int ?? 0

        // Título y datos de la edición (en tu idioma); si no hay, los de la obra.
        let language = ((edition["language"] as? [String])?.first
            ?? (doc["language"] as? [String]).flatMap { $0.count == 1 ? $0.first : nil }).flatMap(MetadataCleaner.cleanLanguage)
        let editionTitle = (edition["title"] as? String).map { cleanEditionTitle($0, language: language) }
        let cleanWorkTitle = cleanEditionTitle(workTitle, language: language)
        // «Hobbit, The (Unwin Books) by Tolkien, J. R. R. (June 1, 1966) Paperback»: mejor el de la obra.
        let usableEditionTitle = editionTitle.flatMap { title in
            title.isEmpty || title.count > cleanWorkTitle.count + 30 ? nil : title
        }
        let title = usableEditionTitle ?? cleanWorkTitle
        let editionISBNs = (edition["isbn"] as? [String] ?? []).compactMap(ISBN.normalized)
        // Cualquier ISBN de la obra sirve para reconocerla: otra edición del mismo libro.
        let workISBNs = (doc["isbn"] as? [String] ?? []).compactMap(ISBN.normalized)

        // Año: el de la obra si es una obra con historia; el de la edición si no.
        let editionYear = (edition["publish_date"] as? [String])?.first.flatMap(year)
        let workYear = (doc["first_publish_year"] as? Int).map(String.init)
        let published = editionCount >= 5 ? (workYear ?? editionYear) : (editionYear ?? workYear)

        // Serie: solo si se entiende en el idioma de la edición («Harry Potter»
        // sí; «A Song of Ice and Fire» para «Juego de tronos», no).
        var series: String?, seriesIndex: Double?
        if let name = (doc["series_name"] as? [String])?.first, !name.isEmpty {
            let isNeutral = Set(TextMatch.tokens(name)).isSubset(of: Set(TextMatch.tokens(title)))
            if TextMatch.fold(title) == TextMatch.fold(workTitle) || isNeutral {
                series = name
                seriesIndex = (doc["series_position"] as? [String])?.first.flatMap { Double($0) }
            }
        }
        if series == nil, let parsed = SeriesParser.split((edition["title"] as? String) ?? "") {
            series = parsed.series
            seriesIndex = parsed.index
        }

        // La portada de la obra suele ser la del original: para una traducción
        // («Le Petit Prince» para «El principito») mejor la tipográfica de Lectora.
        let isTranslation = preferred != nil && TextMatch.fold(workTitle) != TextMatch.fold(title)
        let workCover = isTranslation ? nil : doc["cover_i"] as? Int
        let covers = [edition["cover_i"] as? Int, workCover].compactMap { $0.flatMap(coverURL) }
        return MetadataCandidate(
            id: "ol:" + key + ((edition["key"] as? String).map { "|" + $0 } ?? ""),
            source: .openLibrary,
            title: SeriesParser.split(title)?.title ?? title,
            subtitle: (edition["subtitle"] as? String) ?? (doc["subtitle"] as? String),
            authors: authors(doc["author_name"] as? [String] ?? [], alternatives: doc["author_alternative_name"] as? [String] ?? []),
            publisher: ((edition["publisher"] as? [String])?.first ?? (doc["publisher"] as? [String]).flatMap { $0.count == 1 ? $0.first : nil })
                .flatMap(cleanPublisher),
            published: published,
            isbn: editionISBNs.first,
            language: language,
            subjects: GenreMap.genres(from: doc["subject"] as? [String] ?? []),
            series: series,
            seriesIndex: seriesIndex,
            coverURL: covers.first,
            workKey: key,
            workTitle: workTitle,
            editionCount: editionCount,
            coverAlternatives: Array(covers.dropFirst()),
            knownISBNs: Set(editionISBNs + workISBNs)
        )
    }

    /// Autores en alfabeto latino: «Лев Толстой» → «Leo Tolstoy» si Open
    /// Library conoce esa forma. El orden se respeta (el primero es el autor;
    /// suelen seguir traductores e ilustradores).
    static func authors(_ names: [String], alternatives: [String]) -> [String] {
        latinAuthors(names, alternatives: alternatives).map { shouting($0) ? $0.lowercased().capitalized : $0 }
    }

    private static func latinAuthors(_ names: [String], alternatives: [String]) -> [String] {
        names.map { name in
            guard !isLatin(name) else { return name }
            let latin = alternatives.filter { isLatin($0) && $0.contains(" ") }
            // La forma más repetida suele ser la más común («Leo Tolstoy»).
            let counts = Dictionary(latin.map { (TextMatch.fold($0), 1) }, uniquingKeysWith: +)
            return latin.max { (counts[TextMatch.fold($0)] ?? 0) < (counts[TextMatch.fold($1)] ?? 0) } ?? name
        }
    }

    static func isLatin(_ text: String) -> Bool { TextMatch.isLatin(text) }

    /// «[Peralta]» → «Peralta»; «PLAZA & JANES EDITORES» → «Plaza & Janes Editores»;
    /// «CreateSpace…» o «LibriVox» → sin editorial.
    static func cleanPublisher(_ name: String) -> String? {
        var trimmed = name.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("["), trimmed.hasSuffix("]") { trimmed = String(trimmed.dropFirst().dropLast()) }
        trimmed = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: " ,;:"))
        // Reimpresiones sin editorial de verdad (y audiolibros de LibriVox): mejor sin dato.
        let folded = TextMatch.fold(trimmed)
        guard !trimmed.isEmpty, !["createspace", "independently published", "librivox", "lulu", "smashwords",
                                   "kindle direct", "createspace independent"].contains(where: folded.contains) else { return nil }
        return shouting(trimmed) ? trimmed.lowercased().capitalized : trimmed
    }

    static func shouting(_ text: String) -> Bool {
        text.filter(\.isLetter).count > 3 && text == text.uppercased() && text != text.lowercased()
    }

    /// «Don Quijote de la Mancha.» → sin punto; «El Mesías de Dune / Dune
    /// Messiah» → solo el primero; «FICCIONES» → «Ficciones».
    static func cleanEditionTitle(_ title: String, language: String? = nil) -> String {
        var cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let slash = cleaned.range(of: " / ") ?? cleaned.range(of: "/"), cleaned.distance(from: cleaned.startIndex, to: slash.lowerBound) > 3 {
            cleaned = String(cleaned[..<slash.lowerBound])
        }
        cleaned = cleaned.replacingOccurrences(of: " :", with: ":").trimmingCharacters(in: CharacterSet(charactersIn: " .,;:"))
        return MetadataCleaner.cleanTitle(cleaned, language: language)
    }

    static func year(_ date: String) -> String? {
        guard let range = date.range(of: #"\b(1[5-9]|20)\d{2}\b"#, options: .regularExpression) else { return nil }
        return String(date[range])
    }

    /// La descripción puede venir como texto o como `{ "value": … }`.
    public static func workDescription(from data: Data) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let raw = (root["description"] as? String) ?? ((root["description"] as? [String: Any])?["value"] as? String)
        return raw.flatMap(SummaryCleaner.clean)
    }
}

/// Google Books. Sin clave, la cuota diaria compartida suele estar agotada
/// (lo confirmó el sondeo: «Quota exceeded … Queries per day»), así que solo
/// se usa con una clave propia (gratis en Google Cloud), desde Ajustes.
public enum GoogleBooks {
    public static func searchURL(isbn: String?, title: String, author: String?, language: String?, apiKey: String) -> URL {
        var components = URLComponents(string: "https://www.googleapis.com/books/v1/volumes")!
        let query: String
        if let isbn {
            query = "isbn:\(isbn)"
        } else {
            query = "intitle:\(title)" + (author.map { " inauthor:\($0)" } ?? "")
        }
        var items = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "maxResults", value: "8"),
                     URLQueryItem(name: "printType", value: "books"), URLQueryItem(name: "key", value: apiKey)]
        if let language { items.append(URLQueryItem(name: "langRestrict", value: language)) }
        components.queryItems = items
        return components.url!
    }

    public static func candidates(from data: Data) -> [MetadataCandidate] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = root["items"] as? [[String: Any]] else { return [] }
        return items.compactMap { item in
            guard let info = item["volumeInfo"] as? [String: Any], let title = info["title"] as? String else { return nil }
            let identifiers = info["industryIdentifiers"] as? [[String: Any]] ?? []
            let isbns = identifiers.compactMap { ($0["identifier"] as? String).flatMap(ISBN.normalized) }
            let links = info["imageLinks"] as? [String: Any] ?? [:]
            let image = (links["thumbnail"] ?? links["smallThumbnail"]) as? String
            let id = item["id"] as? String
            let covers = [id.flatMap(largeCover), image.flatMap(secureThumbnail)].compactMap { $0 }
            let year = (info["publishedDate"] as? String).flatMap(OpenLibrary.year)
            return MetadataCandidate(
                id: "gb:" + (id ?? title),
                source: .googleBooks,
                title: MetadataCleaner.cleanTitle(title, language: (info["language"] as? String).flatMap(MetadataCleaner.cleanLanguage)),
                subtitle: info["subtitle"] as? String,
                authors: info["authors"] as? [String] ?? [],
                publisher: info["publisher"] as? String,
                published: year,
                summary: (info["description"] as? String).flatMap(SummaryCleaner.clean),
                isbn: isbns.first { $0.hasPrefix("97") },
                language: (info["language"] as? String).flatMap(MetadataCleaner.cleanLanguage),
                subjects: GenreMap.genres(from: info["categories"] as? [String] ?? []),
                coverURL: image == nil ? nil : covers.first,
                coverAlternatives: image == nil ? nil : Array(covers.dropFirst()),
                knownISBNs: Set(isbns)
            )
        }
    }

    /// Portada grande de la editorial (cuando existe).
    static func largeCover(_ id: String) -> URL? {
        URL(string: "https://books.google.com/books/publisher/content/images/frontcover/\(id)?fife=w800-h1200&source=gbs_api")
    }

    /// Miniatura en https y sin el doblez de página.
    static func secureThumbnail(_ link: String) -> URL? {
        URL(string: link.replacingOccurrences(of: "http://", with: "https://").replacingOccurrences(of: "&edge=curl", with: ""))
    }
}
