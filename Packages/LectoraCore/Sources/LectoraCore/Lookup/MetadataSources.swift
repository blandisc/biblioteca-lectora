import Foundation

/// Consultas y lectura de respuestas de las fuentes públicas de metadatos.
/// Sin red aquí: la app hace las peticiones y este código arma las URL y
/// entiende las respuestas, para poder probarlo con respuestas guardadas.
public enum OpenLibrary {
    /// `search.json` por ISBN o por título y autor.
    public static func searchURL(isbn: String?, title: String, author: String?) -> URL {
        var components = URLComponents(string: "https://openlibrary.org/search.json")!
        var items = [URLQueryItem(name: "limit", value: "5"),
                     URLQueryItem(name: "fields", value: "key,title,subtitle,author_name,first_publish_year,publish_date,isbn,publisher,language,subject,cover_i,cover_edition_key,series_name,series_position")]
        if let isbn {
            items.append(URLQueryItem(name: "isbn", value: isbn))
        } else {
            items.append(URLQueryItem(name: "title", value: title))
            if let author { items.append(URLQueryItem(name: "author", value: author)) }
        }
        components.queryItems = items
        return components.url!
    }

    /// Descripción de la obra (`/works/OL…W.json`), que la búsqueda no trae.
    public static func workURL(key: String) -> URL {
        URL(string: "https://openlibrary.org\(key).json")!
    }

    public static func candidates(from data: Data) -> [MetadataCandidate] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let docs = root["docs"] as? [[String: Any]] else { return [] }
        return docs.compactMap { doc in
            guard let title = doc["title"] as? String else { return nil }
            let isbns = doc["isbn"] as? [String] ?? []
            let coverURL = (doc["cover_i"] as? Int).flatMap {
                URL(string: "https://covers.openlibrary.org/b/id/\($0)-L.jpg")
            }
            let languages = doc["language"] as? [String] ?? []
            return MetadataCandidate(
                id: "ol:" + (doc["key"] as? String ?? title),
                source: .openLibrary,
                title: title,
                subtitle: doc["subtitle"] as? String,
                authors: doc["author_name"] as? [String] ?? [],
                publisher: (doc["publisher"] as? [String])?.first,
                published: (doc["first_publish_year"] as? Int).map(String.init),
                isbn: isbns.first { $0.count == 13 } ?? isbns.first,
                language: languages.first,
                subjects: Array((doc["subject"] as? [String] ?? []).prefix(8)),
                series: (doc["series_name"] as? [String])?.first,
                seriesIndex: (doc["series_position"] as? [String])?.first.flatMap(Double.init),
                coverURL: coverURL
            )
        }
    }

    /// La descripción puede venir como texto o como `{ "value": … }`.
    public static func workDescription(from data: Data) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let text = root["description"] as? String { return text }
        return (root["description"] as? [String: Any])?["value"] as? String
    }
}

public enum GoogleBooks {
    public static func searchURL(isbn: String?, title: String, author: String?, language: String?) -> URL {
        var components = URLComponents(string: "https://www.googleapis.com/books/v1/volumes")!
        let query: String
        if let isbn {
            query = "isbn:\(isbn)"
        } else {
            query = "intitle:\(title)" + (author.map { " inauthor:\($0)" } ?? "")
        }
        var items = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "maxResults", value: "5"),
                     URLQueryItem(name: "printType", value: "books")]
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
            let isbn13 = identifiers.first { $0["type"] as? String == "ISBN_13" }?["identifier"] as? String
            let isbn10 = identifiers.first { $0["type"] as? String == "ISBN_10" }?["identifier"] as? String
            let links = info["imageLinks"] as? [String: Any] ?? [:]
            let image = (links["extraLarge"] ?? links["large"] ?? links["medium"] ?? links["thumbnail"]) as? String
            return MetadataCandidate(
                id: "gb:" + (item["id"] as? String ?? title),
                source: .googleBooks,
                title: title,
                subtitle: info["subtitle"] as? String,
                authors: info["authors"] as? [String] ?? [],
                publisher: info["publisher"] as? String,
                published: info["publishedDate"] as? String,
                summary: info["description"] as? String,
                isbn: isbn13 ?? isbn10,
                language: info["language"] as? String,
                subjects: info["categories"] as? [String] ?? [],
                coverURL: image.flatMap(largerCover)
            )
        }
    }

    /// Las miniaturas de Google vienen en http y chicas: https y sin el doblez.
    static func largerCover(_ link: String) -> URL? {
        let secure = link.replacingOccurrences(of: "http://", with: "https://")
            .replacingOccurrences(of: "&edge=curl", with: "")
            .replacingOccurrences(of: "zoom=1", with: "zoom=0")
        return URL(string: secure)
    }
}
