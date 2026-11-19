import Foundation
#if canImport(SQLite3)
import SQLite3
#endif

/// Un libro de una biblioteca de Calibre, leído de su `metadata.db`.
public struct CalibreEntry: Sendable, Equatable {
    /// El libro como lo guarda Gabinete (con su número de Calibre).
    public var book: Book
    /// Carpeta del libro dentro de la biblioteca (`Autor/Título (id)`).
    public var folder: String
    /// Formatos: «EPUB» → «Autor/Título (id)/Título - Autor.epub».
    public var formats: [String: String]
    public var hasCover: Bool
    /// Subrayados del visor de Calibre (desde Calibre 5).
    public var annotations: [CalibreAnnotation]

    /// El formato que se lee en Gabinete: EPUB primero, luego los demás.
    public var preferredFile: String? {
        for format in CalibreLibrary.formatPreference {
            if let path = formats[format] { return path }
        }
        return formats.values.sorted().first
    }
}

/// Un subrayado o nota del visor de Calibre.
public struct CalibreAnnotation: Sendable, Equatable {
    public var text: String
    public var note: String?
    public var createdAt: Date?
}

/// Lee una biblioteca de Calibre sin tocarla: su `metadata.db` se copia y se
/// abre de solo lectura. Arquitectura D3: la migración es única y Gabinete
/// queda como dueño del catálogo.
public enum CalibreLibrary {
    public static let databaseName = "metadata.db"
    static let formatPreference = ["EPUB", "KEPUB", "AZW3", "MOBI", "PDF", "CBZ", "CBR", "FB2", "TXT"]

    public enum ReadError: LocalizedError {
        case notACalibreLibrary
        case unreadable(String)
        case unsupported

        public var errorDescription: String? {
            switch self {
            case .notACalibreLibrary: "Esa carpeta no es una biblioteca de Calibre: no tiene metadata.db."
            case .unreadable(let message): "No pude leer la biblioteca de Calibre: \(message)"
            case .unsupported: "Este dispositivo no puede leer bases de Calibre."
            }
        }
    }

    /// Todos los libros de la biblioteca en `folder`.
    public static func read(libraryAt folder: URL) throws -> [CalibreEntry] {
        let database = folder.appendingPathComponent(databaseName)
        guard FileManager.default.fileExists(atPath: database.path) else { throw ReadError.notACalibreLibrary }
        // Una copia: Calibre puede estar abierto y la base no se toca nunca.
        let copy = FileManager.default.temporaryDirectory.appendingPathComponent("calibre-\(UUID().uuidString).db")
        try FileManager.default.copyItem(at: database, to: copy)
        defer { try? FileManager.default.removeItem(at: copy) }
        return try readDatabase(at: copy)
    }

    #if canImport(SQLite3)
    static func readDatabase(at url: URL) throws -> [CalibreEntry] {
        var handle: OpaquePointer?
        guard sqlite3_open_v2(url.path, &handle, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db = handle else {
            throw ReadError.unreadable("no se abre la base")
        }
        defer { sqlite3_close(db) }

        func rows(_ sql: String) throws -> [[String?]] {
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw ReadError.unreadable(String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(statement) }
            var result: [[String?]] = []
            let columns = sqlite3_column_count(statement)
            while sqlite3_step(statement) == SQLITE_ROW {
                result.append((0..<columns).map { index in
                    sqlite3_column_text(statement, index).map { String(cString: $0) }
                })
            }
            return result
        }

        /// «libro → [valores]» de una tabla de enlace, en su orden.
        func linked(_ sql: String) throws -> [Int: [String]] {
            var map: [Int: [String]] = [:]
            for row in try rows(sql) {
                guard let book = row[0].flatMap(Int.init), let value = row[1], !value.isEmpty else { continue }
                map[book, default: []].append(value)
            }
            return map
        }

        let tables = Set(try rows("SELECT name FROM sqlite_master WHERE type='table'").compactMap { $0[0] })
        guard tables.contains("books") else { throw ReadError.notACalibreLibrary }

        let authors = try linked("SELECT l.book, a.name FROM books_authors_link l JOIN authors a ON a.id = l.author ORDER BY l.id")
        let tags = try linked("SELECT l.book, t.name FROM books_tags_link l JOIN tags t ON t.id = l.tag ORDER BY l.id")
        let series = try linked("SELECT l.book, s.name FROM books_series_link l JOIN series s ON s.id = l.series")
        let publishers = try linked("SELECT l.book, p.name FROM books_publishers_link l JOIN publishers p ON p.id = l.publisher")
        let languages = try linked("SELECT l.book, g.lang_code FROM books_languages_link l JOIN languages g ON g.id = l.lang_code ORDER BY l.item_order")
        let ratings = try linked("SELECT l.book, r.rating FROM books_ratings_link l JOIN ratings r ON r.id = l.rating")
        let comments = try linked("SELECT book, text FROM comments")
        var identifiers: [Int: [String: String]] = [:]
        for row in try rows("SELECT book, type, val FROM identifiers") {
            guard let book = row[0].flatMap(Int.init), let type = row[1], let value = row[2] else { continue }
            identifiers[book, default: [:]][type.lowercased() == "amazon" ? "asin" : type.lowercased()] = value
        }
        var formats: [Int: [String: String]] = [:]
        var annotations: [Int: [CalibreAnnotation]] = [:]

        let books = try rows("SELECT id, title, timestamp, pubdate, series_index, path, uuid, has_cover FROM books ORDER BY id")
        var paths: [Int: String] = [:]
        for row in books { if let id = row[0].flatMap(Int.init), let path = row[5] { paths[id] = path } }
        for row in try rows("SELECT book, format, name FROM data") {
            guard let book = row[0].flatMap(Int.init), let format = row[1]?.uppercased(), let name = row[2], let folder = paths[book] else { continue }
            formats[book, default: [:]][format] = "\(folder)/\(name).\(format.lowercased())"
        }
        if tables.contains("annotations") {
            for row in try rows("SELECT book, timestamp, annot_data FROM annotations WHERE annot_type = 'highlight'") {
                guard let book = row[0].flatMap(Int.init), let json = row[2]?.data(using: .utf8),
                      let data = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
                      (data["removed"] as? Bool) != true,
                      let text = data["highlighted_text"] as? String, !text.isEmpty else { continue }
                let note = (data["notes"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                let created = row[1].flatMap(Double.init).map(Date.init(timeIntervalSince1970:))
                annotations[book, default: []].append(CalibreAnnotation(text: text, note: note, createdAt: created))
            }
        }

        return books.compactMap { row in
            guard let id = row[0].flatMap(Int.init), let title = row[1], let path = row[5] else { return nil }
            var ids = identifiers[id] ?? [:]
            if let uuid = row[6] { ids["calibre"] = uuid }
            let published = row[3].flatMap { $0.hasPrefix("0101") ? nil : CalibreOPF.ourDate($0.replacingOccurrences(of: " ", with: "T")) }
            let book = Book(
                title: title,
                authors: authors[id] ?? [],
                series: series[id]?.first,
                seriesIndex: series[id] == nil ? nil : row[4].flatMap(Double.init),
                tags: tags[id] ?? [],
                language: languages[id]?.first.map(CalibreOPF.iso639_1),
                identifiers: ids,
                publisher: publishers[id]?.first,
                published: published,
                summary: comments[id]?.first,
                rating: ratings[id]?.first.flatMap(Double.init).map { $0 / 2 },
                calibreID: id,
                addedAt: row[2].flatMap { CalibreOPF.parseTimestamp($0.replacingOccurrences(of: " ", with: "T")) }
            )
            return CalibreEntry(book: book, folder: path, formats: formats[id] ?? [:],
                                hasCover: row[7] == "1", annotations: annotations[id] ?? [])
        }
    }
    #else
    static func readDatabase(at url: URL) throws -> [CalibreEntry] { throw ReadError.unsupported }
    #endif
}

/// Qué traer de Calibre y qué no, antes de copiar nada.
public struct CalibreMigrationPlan: Sendable {
    /// Libros a traer.
    public var toImport: [CalibreEntry]
    /// Ya están en tu Gabinete (mismo libro de Calibre, o mismo título y autor y formato).
    public var alreadyHere: [CalibreEntry]
    /// Sin ningún archivo que se pueda leer.
    public var withoutFiles: [CalibreEntry]

    public var covers: Int { toImport.filter(\.hasCover).count }
    public var series: Int { Set(toImport.compactMap(\.book.series)).count }
    public var annotations: Int { toImport.reduce(0) { $0 + $1.annotations.count } }

    public init(entries: [CalibreEntry], existing: [Book]) {
        let uuids = Set(existing.compactMap { $0.identifiers["calibre"] })
        let keys = Set(existing.map { Self.key($0) })
        var toImport: [CalibreEntry] = []
        var alreadyHere: [CalibreEntry] = []
        var withoutFiles: [CalibreEntry] = []
        for entry in entries {
            if let uuid = entry.book.identifiers["calibre"], uuids.contains(uuid) {
                alreadyHere.append(entry)
            } else if keys.contains(Self.key(entry.book)) {
                alreadyHere.append(entry)
            } else if entry.preferredFile == nil {
                withoutFiles.append(entry)
            } else {
                toImport.append(entry)
            }
        }
        self.toImport = toImport
        self.alreadyHere = alreadyHere
        self.withoutFiles = withoutFiles
    }

    static func key(_ book: Book) -> String {
        TextMatch.fold(book.title) + "|" + TextMatch.fold(book.authors.first ?? "")
    }
}
