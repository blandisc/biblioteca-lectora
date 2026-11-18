import Foundation

/// Readwise (arquitectura D4): el lugar central de tus subrayados, en las dos
/// direcciones. API v2 con tu llave (readwise.io/access_token).
///
/// - **De Gabinete a Readwise:** cada subrayado tuyo con su libro, nota, posición,
///   fecha y el enlace que vuelve al pasaje (`gabinete://subrayado/<id>`).
/// - **De Readwise a Gabinete:** lo nuevo desde la última vez (Kindle, Apple
///   Books…). Lo que nació en Gabinete (su enlace `gabinete://`) no se reimporta.
public struct ReadwiseClient: Sendable {
    public static let base = URL(string: "https://readwise.io/api/v2/")!
    public static let source = "readwise"
    /// Nombre de Gabinete como fuente en Readwise.
    public static let sourceType = "gabinete"

    let token: String
    let transport: HTTPTransport

    public init(token: String, transport: HTTPTransport = URLSession.shared) {
        self.token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        self.transport = transport
    }

    func request(_ path: String, method: String = "GET", query: [URLQueryItem] = [], body: Data? = nil) -> URLRequest {
        var components = URLComponents(url: Self.base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("Gabinete", forHTTPHeaderField: "User-Agent")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    /// ¿Sirve la llave? (204 si sí).
    public func verify() async throws {
        let (data, response) = try await transport.send(request("auth/"))
        try ConnectorError.check(response, data)
    }

    // MARK: Mandar

    /// Un subrayado como lo pide Readwise.
    public struct Outgoing: Sendable, Equatable {
        public var annotationID: UUID
        public var text: String
        public var title: String
        public var author: String?
        public var note: String?
        public var location: Int?
        public var highlightedAt: Date

        public init(annotationID: UUID, text: String, title: String, author: String?, note: String?, location: Int?, highlightedAt: Date) {
            self.annotationID = annotationID
            self.text = text
            self.title = title
            self.author = author
            self.note = note
            self.location = location
            self.highlightedAt = highlightedAt
        }

        var json: [String: Any] {
            var object: [String: Any] = [
                "text": String(text.prefix(8191)),
                "title": title,
                "source_type": ReadwiseClient.sourceType,
                "category": "books",
                "highlighted_at": ISO8601DateFormatter().string(from: highlightedAt),
                "highlight_url": NoteMarkdown.passageURL(annotationID: annotationID).absoluteString,
            ]
            if let author, !author.isEmpty { object["author"] = author }
            if let note, !note.isEmpty { object["note"] = String(note.prefix(8191)) }
            if let location { object["location"] = location; object["location_type"] = "order" }
            return object
        }
    }

    /// Manda subrayados; devuelve, por cada uno, el id que le dio Readwise.
    /// Readwise no duplica un subrayado con el mismo texto y libro: reintentar es seguro.
    public func send(_ highlights: [Outgoing]) async throws -> [UUID: String] {
        guard !highlights.isEmpty else { return [:] }
        let body = try JSONSerialization.data(withJSONObject: ["highlights": highlights.map(\.json)])
        let (data, response) = try await transport.send(request("highlights/", method: "POST", body: body))
        try ConnectorError.check(response, data)
        return Self.ids(from: data, for: highlights)
    }

    /// Readwise responde los libros tocados con sus `modified_highlights`; se
    /// emparejan con lo mandado por el enlace de cada subrayado o, si no viene,
    /// por orden.
    static func ids(from data: Data, for highlights: [Outgoing]) -> [UUID: String] {
        guard let books = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [:] }
        let ids = books.flatMap { ($0["modified_highlights"] as? [Any]) ?? [] }.map { "\($0)" }
        var result: [UUID: String] = [:]
        for (highlight, id) in zip(highlights, ids) { result[highlight.annotationID] = id }
        return result
    }

    public func update(id: String, text: String?, note: String?) async throws {
        var object: [String: Any] = [:]
        if let text { object["text"] = text }
        if let note { object["note"] = note }
        let body = try JSONSerialization.data(withJSONObject: object)
        let (data, response) = try await transport.send(request("highlights/\(id)/", method: "PATCH", body: body))
        try ConnectorError.check(response, data)
    }

    public func delete(id: String) async throws {
        let (data, response) = try await transport.send(request("highlights/\(id)/", method: "DELETE"))
        if response.statusCode == 404 { return } // ya no estaba
        try ConnectorError.check(response, data)
    }

    // MARK: Traer

    /// Un subrayado que vive en Readwise.
    public struct Incoming: Sendable, Equatable {
        public var id: String
        public var text: String
        public var note: String?
        public var highlightedAt: Date?
        public var updatedAt: Date?
        public var url: String?
        public var isDeleted: Bool
        public var bookTitle: String
        public var bookAuthor: String?
        public var bookSource: String?

        /// Nació en Gabinete (su enlace vuelve a Gabinete): no se reimporta.
        public var isFromGabinete: Bool {
            bookSource == ReadwiseClient.sourceType || (url?.hasPrefix(NoteMarkdown.scheme + "://") ?? false)
        }

        /// El subrayado de Gabinete al que apunta su enlace, si es uno nuestro.
        public var gabineteAnnotationID: UUID? {
            url.flatMap(URL.init(string:)).flatMap(NoteMarkdown.target(of:)).flatMap {
                if case .passage(let id) = $0 { return id } else { return nil }
            }
        }
    }

    /// Todo lo que cambió en Readwise desde `updatedAfter` (todo, la primera vez), página por página.
    public func export(updatedAfter: Date?) async throws -> [Incoming] {
        var cursor: String?
        var all: [Incoming] = []
        repeat {
            var query: [URLQueryItem] = []
            if let updatedAfter { query.append(URLQueryItem(name: "updatedAfter", value: ISO8601DateFormatter().string(from: updatedAfter))) }
            if let cursor { query.append(URLQueryItem(name: "pageCursor", value: cursor)) }
            let (data, response) = try await transport.send(request("export/", query: query))
            try ConnectorError.check(response, data)
            let page = try Self.parseExport(data)
            all += page.highlights
            cursor = page.next
        } while cursor != nil
        return all
    }

    static func parseExport(_ data: Data) throws -> (highlights: [Incoming], next: String?) {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ConnectorError.unexpected("Readwise respondió algo que no entiendo")
        }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        func date(_ value: Any?) -> Date? {
            guard let text = value as? String else { return nil }
            return iso.date(from: text) ?? plain.date(from: text)
        }
        var highlights: [Incoming] = []
        for book in (object["results"] as? [[String: Any]]) ?? [] {
            let title = (book["readable_title"] as? String) ?? (book["title"] as? String) ?? "Sin título"
            let author = book["author"] as? String
            let source = book["source"] as? String
            for item in (book["highlights"] as? [[String: Any]]) ?? [] {
                guard let id = item["id"].map({ "\($0)" }), let text = item["text"] as? String else { continue }
                let note = (item["note"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                highlights.append(Incoming(
                    id: id, text: text, note: note,
                    highlightedAt: date(item["highlighted_at"]), updatedAt: date(item["updated_at"]),
                    url: item["url"] as? String, isDeleted: (item["is_deleted"] as? Bool) ?? false,
                    bookTitle: title, bookAuthor: author, bookSource: source))
            }
        }
        let next = object["nextPageCursor"].flatMap { $0 is NSNull ? nil : "\($0)" }
        return (highlights, next)
    }
}

/// Qué hacer con lo que llegó de Readwise, frente a lo que ya tienes.
public enum ReadwiseMerge {
    public enum Action: Equatable, Sendable {
        /// Subrayado nuevo de otra fuente: se crea en tu Cuaderno.
        case create(ReadwiseClient.Incoming)
        /// Cambió en Readwise (texto o nota) uno que ya tienes.
        case update(annotationID: UUID, text: String, note: String?)
        /// Lo borraste en Readwise.
        case delete(annotationID: UUID)
    }

    /// Compara por `readwise_id` (y, para los nuestros, por el enlace al pasaje).
    /// Lo que nació en Gabinete solo trae cambios de nota o borrados, nunca un duplicado.
    public static func actions(incoming: [ReadwiseClient.Incoming], existing: [Annotation]) -> [Action] {
        var byReadwise: [String: Annotation] = [:]
        var byID: [UUID: Annotation] = [:]
        for annotation in existing {
            if let id = annotation.readwiseID { byReadwise[id] = annotation }
            byID[annotation.id] = annotation
        }
        var actions: [Action] = []
        for highlight in incoming {
            let match = byReadwise[highlight.id] ?? highlight.gabineteAnnotationID.flatMap { byID[$0] }
            if let match {
                if highlight.isDeleted {
                    actions.append(.delete(annotationID: match.id))
                } else if match.quote != highlight.text || (match.note ?? "") != (highlight.note ?? "") {
                    actions.append(.update(annotationID: match.id, text: highlight.text, note: highlight.note))
                }
            } else if !highlight.isDeleted, !highlight.isFromGabinete {
                actions.append(.create(highlight))
            }
        }
        return actions
    }

    /// El libro de tu biblioteca para un subrayado de Readwise: mismo título y autor.
    public static func book(for highlight: ReadwiseClient.Incoming, in books: [Book]) -> Book? {
        books
            .map { book -> (Book, Double) in
                let title = TextMatch.titleSimilarity(book.title, highlight.bookTitle)
                let author = highlight.bookAuthor.map { TextMatch.sameAuthorScore(book.authors, [$0]) } ?? 0.5
                return (book, title * 0.7 + author * 0.3)
            }
            .filter { $0.1 >= 0.8 }
            .max { $0.1 < $1.1 }?.0
    }

    /// Id estable de un libro que no está en tu biblioteca, para agrupar sus subrayados.
    public static func outsideBookID(title: String, author: String?) -> UUID {
        StableID.uuid(for: "readwise-libro|\(TextMatch.fold(title))|\(TextMatch.fold(author ?? ""))")
    }
}

/// Tus subrayados en el CSV que Readwise sabe importar: salida libre (D4).
public enum ReadwiseCSV {
    public static func export(_ rows: [(annotation: Annotation, title: String, author: String?)]) -> String {
        let iso = ISO8601DateFormatter()
        var lines = ["Highlight,Title,Author,URL,Note,Location,Date"]
        for row in rows {
            let fields = [
                row.annotation.quote, row.title, row.author ?? "",
                NoteMarkdown.passageURL(annotationID: row.annotation.id).absoluteString,
                row.annotation.note ?? "", "", iso.string(from: row.annotation.createdAt),
            ]
            lines.append(fields.map(escape).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func escape(_ field: String) -> String {
        "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
