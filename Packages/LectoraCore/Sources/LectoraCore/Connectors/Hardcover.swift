import Foundation

/// Hardcover (arquitectura D5): de ida. Gabinete es la verdad; Hardcover, tu
/// registro de lectura. API GraphQL (en beta) con tu llave (hardcover.app › Ajustes › API).
///
/// Todo lo que toca su esquema está aquí, aislado: si Hardcover cambia, solo
/// cambia este archivo.
public struct HardcoverClient: Sendable {
    public static let endpoint = URL(string: "https://api.hardcover.app/v1/graphql")!
    /// Prefijo del identificador en el catálogo y en el OPF (`hardcover:123`).
    public static let identifierKey = "hardcover"

    /// Estados de Hardcover (`status_id`).
    public enum Status: Int, Sendable {
        case wantToRead = 1
        case reading = 2
        case read = 3
    }

    let token: String
    let transport: HTTPTransport

    public init(token: String, transport: HTTPTransport = URLSession.shared) {
        // Hardcover muestra la llave con «Bearer» delante: se acepta con o sin él.
        var token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if token.lowercased().hasPrefix("bearer ") { token = String(token.dropFirst(7)) }
        self.token = token
        self.transport = transport
    }

    func run(_ query: String, _ variables: [String: Any] = [:]) async throws -> [String: Any] {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Gabinete", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["query": query, "variables": variables])
        let (data, response) = try await transport.send(request)
        try ConnectorError.check(response, data)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ConnectorError.unexpected("Hardcover respondió algo que no entiendo")
        }
        if let errors = object["errors"] as? [[String: Any]], let first = errors.first {
            let message = (first["message"] as? String) ?? "error"
            if message.lowercased().contains("jwt") || message.lowercased().contains("auth") { throw ConnectorError.badKey }
            throw ConnectorError.server(status: 200, message: message)
        }
        return (object["data"] as? [String: Any]) ?? [:]
    }

    /// ¿Sirve la llave? Devuelve tu nombre de usuario.
    public func verify() async throws -> String {
        let data = try await run("query { me { id username } }")
        let me = (data["me"] as? [[String: Any]])?.first ?? (data["me"] as? [String: Any])
        guard let username = me?["username"] as? String else { throw ConnectorError.badKey }
        return username
    }

    /// Un libro encontrado en Hardcover.
    public struct Match: Sendable, Equatable {
        public var id: Int
        public var title: String
        public var authors: [String]
        public var pages: Int?
    }

    /// Busca tu libro: primero por ISBN, luego por título y autor. Se queda con
    /// el resultado solo si el título y el autor coinciden de verdad.
    public func find(title: String, authors: [String], isbn: String?) async throws -> Match? {
        var queries: [String] = []
        if let isbn, !isbn.isEmpty { queries.append(isbn) }
        queries.append(([title] + authors.prefix(1)).joined(separator: " "))
        for text in queries {
            let data = try await run(
                "query Buscar($q: String!) { search(query: $q, query_type: \"Book\", per_page: 5, page: 1) { results } }",
                ["q": text])
            let matches = Self.parseSearch(data)
            if let best = Self.best(matches, title: title, authors: authors) { return best }
        }
        return nil
    }

    static func parseSearch(_ data: [String: Any]) -> [Match] {
        let search = data["search"] as? [String: Any]
        var results = search?["results"]
        if let text = results as? String, let json = text.data(using: .utf8) {
            results = try? JSONSerialization.jsonObject(with: json)
        }
        let hits = ((results as? [String: Any])?["hits"] as? [[String: Any]]) ?? []
        return hits.compactMap { hit in
            guard let document = hit["document"] as? [String: Any],
                  let title = document["title"] as? String else { return nil }
            let id = (document["id"] as? Int) ?? (document["id"] as? String).flatMap(Int.init)
            guard let id else { return nil }
            return Match(id: id, title: title, authors: (document["author_names"] as? [String]) ?? [],
                         pages: document["pages"] as? Int)
        }
    }

    static func best(_ matches: [Match], title: String, authors: [String]) -> Match? {
        matches
            .map { ($0, TextMatch.titleSimilarity($0.title, title), authors.isEmpty ? 1 : TextMatch.sameAuthorScore($0.authors, authors)) }
            .filter { $0.1 >= 0.85 && $0.2 >= 0.6 }
            .max { $0.1 + $0.2 < $1.1 + $1.2 }?.0
    }

    /// Lo que se manda de un libro: su estado y su avance.
    public struct Update: Sendable, Equatable {
        public var bookID: Int
        public var status: Status
        /// 0 a 1.
        public var progress: Double
        public var pages: Int?
        public var startedAt: Date?
        public var finishedAt: Date?
        /// 0,5 a 5.
        public var rating: Double?

        public init(bookID: Int, status: Status, progress: Double, pages: Int?, startedAt: Date?, finishedAt: Date?, rating: Double?) {
            self.bookID = bookID
            self.status = status
            self.progress = progress
            self.pages = pages
            self.startedAt = startedAt
            self.finishedAt = finishedAt
            self.rating = rating
        }
    }

    /// Pone el libro en tu Hardcover con su estado y su avance. Idempotente:
    /// si ya estaba, lo actualiza.
    public func apply(_ update: Update) async throws {
        let day = { (date: Date?) in date.map { Self.day.string(from: $0) } }
        // 1. El libro en tu lista (o el que ya estaba).
        let existing = try await run(
            "query Mio($b: Int!) { me { user_books(where: {book_id: {_eq: $b}}) { id user_book_reads(order_by: {id: desc}, limit: 1) { id } } } }",
            ["b": update.bookID])
        let me = (existing["me"] as? [[String: Any]])?.first
        let userBook = (me?["user_books"] as? [[String: Any]])?.first
        var userBookID = userBook?["id"] as? Int
        var object: [String: Any] = ["status_id": update.status.rawValue]
        if let rating = update.rating { object["rating"] = rating }
        if let id = userBookID {
            _ = try await run("mutation Estado($id: Int!, $o: UserBookUpdateInput!) { update_user_book(id: $id, object: $o) { id error } }",
                              ["id": id, "o": object])
        } else {
            object["book_id"] = update.bookID
            let inserted = try await run("mutation Nuevo($o: UserBookCreateInput!) { insert_user_book(object: $o) { id error } }",
                                         ["o": object])
            userBookID = (inserted["insert_user_book"] as? [String: Any])?["id"] as? Int
        }
        guard let userBookID else { throw ConnectorError.unexpected("Hardcover no devolvió el libro") }

        // 2. La lectura: avance en páginas y fechas.
        var read: [String: Any] = [:]
        if let pages = update.pages, pages > 0 { read["progress_pages"] = Int((update.progress * Double(pages)).rounded()) }
        if let started = day(update.startedAt) { read["started_at"] = started }
        if let finished = day(update.finishedAt) { read["finished_at"] = finished }
        guard !read.isEmpty else { return }
        let readID = ((userBook?["user_book_reads"] as? [[String: Any]])?.first?["id"]) as? Int
        if let readID {
            _ = try await run("mutation Avance($id: Int!, $r: DatesReadInput!) { update_user_book_read(id: $id, object: $r) { id error } }",
                              ["id": readID, "r": read])
        } else {
            _ = try await run("mutation Lectura($ub: Int!, $r: DatesReadInput!) { insert_user_book_read(user_book_id: $ub, user_book_read: $r) { id error } }",
                              ["ub": userBookID, "r": read])
        }
    }

    static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// El estado que corresponde a un avance.
    public static func status(for progress: Double) -> Status {
        progress >= 0.99 ? .read : (progress > 0 ? .reading : .wantToRead)
    }
}
