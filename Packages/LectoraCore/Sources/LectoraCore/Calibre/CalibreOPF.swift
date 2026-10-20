import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

/// El `metadata.opf` que Calibre guarda junto a cada libro. Con estos archivos,
/// Calibre puede reconstruir su base de datos («Restaurar base de datos»), y
/// nosotros podemos leer una biblioteca de Calibre aunque falte `metadata.db`.
public enum CalibreOPF {
    // MARK: Escribir

    public static func write(_ book: Book, hasCover: Bool) -> String {
        var lines: [String] = []
        func add(_ line: String) { lines.append("        " + line) }

        if let calibreID = book.calibreID {
            add(#"<dc:identifier opf:scheme="calibre" id="calibre_id">\#(calibreID)</dc:identifier>"#)
        }
        add(#"<dc:identifier opf:scheme="uuid" id="uuid_id">\#(book.id.uuidString.lowercased())</dc:identifier>"#)
        add("<dc:title>\(escape(book.title))</dc:title>")
        for author in book.authors {
            add(#"<dc:creator opf:file-as="\#(escape(Book.authorSort(author)))" opf:role="aut">\#(escape(author))</dc:creator>"#)
        }
        if let published = book.published, let date = calibreDate(published) {
            add("<dc:date>\(date)</dc:date>")
        }
        if let summary = book.summary, !summary.isEmpty {
            add("<dc:description>\(escape(summary))</dc:description>")
        }
        if let publisher = book.publisher, !publisher.isEmpty {
            add("<dc:publisher>\(escape(publisher))</dc:publisher>")
        }
        for (scheme, value) in book.identifiers.sorted(by: { $0.key < $1.key }) where !["calibre", "uuid"].contains(scheme) {
            add(#"<dc:identifier opf:scheme="\#(escape(opfScheme(scheme)))">\#(escape(value))</dc:identifier>"#)
        }
        if let language = book.language {
            add("<dc:language>\(escape(iso639_2(language)))</dc:language>")
        }
        for tag in book.tags {
            add("<dc:subject>\(escape(tag))</dc:subject>")
        }
        if let series = book.series, !series.isEmpty {
            add(#"<meta name="calibre:series" content="\#(escape(series))"/>"#)
            add(#"<meta name="calibre:series_index" content="\#(format(book.seriesIndex ?? 1))"/>"#)
        }
        if let rating = book.rating, rating > 0 {
            add(#"<meta name="calibre:rating" content="\#(format(rating * 2))"/>"#)
        }
        if let addedAt = book.addedAt {
            add(#"<meta name="calibre:timestamp" content="\#(timestamp(addedAt))"/>"#)
        }
        add(#"<meta name="calibre:title_sort" content="\#(escape(book.sortTitle))"/>"#)

        let guide = hasCover
            ? "\n    <guide>\n        <reference type=\"cover\" title=\"Cover\" href=\"\(CalibreLayout.coverFileName)\"/>\n    </guide>"
            : ""
        return """
        <?xml version='1.0' encoding='utf-8'?>
        <package xmlns="http://www.idpf.org/2007/opf" unique-identifier="uuid_id" version="2.0">
            <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
        \(lines.joined(separator: "\n"))
            </metadata>\(guide)
        </package>

        """
    }

    // MARK: Leer

    /// Lee un `metadata.opf` de Calibre (o el OPF de un EPUB). `nil` si no tiene título.
    public static func parse(_ data: Data) -> Book? {
        let reader = OPFReader()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = false
        parser.delegate = reader
        guard parser.parse() || !reader.titles.isEmpty, let title = reader.titles.first else { return nil }

        var identifiers: [String: String] = [:]
        var uuid: UUID?
        var calibreID: Int?
        for (scheme, value) in reader.identifiers {
            switch scheme.lowercased() {
            case "uuid": uuid = UUID(uuidString: value)
            case "calibre": calibreID = Int(value)
            case "": continue
            default: identifiers[ourScheme(scheme)] = value
            }
        }
        return Book(
            id: uuid ?? UUID(),
            title: title,
            authors: reader.authors,
            series: reader.meta["calibre:series"],
            seriesIndex: reader.meta["calibre:series_index"].flatMap(Double.init),
            tags: reader.subjects,
            language: reader.languages.first.map(iso639_1),
            identifiers: identifiers,
            publisher: reader.publisher,
            published: reader.date.flatMap(ourDate),
            summary: reader.description,
            rating: reader.meta["calibre:rating"].flatMap(Double.init).map { $0 / 2 },
            calibreID: calibreID,
            addedAt: reader.meta["calibre:timestamp"].flatMap(parseTimestamp)
        )
    }

    // MARK: Conversiones

    private static let languages = ["es": "spa", "en": "eng", "fr": "fra", "de": "deu", "it": "ita", "pt": "por", "ca": "cat", "la": "lat"]

    static func iso639_2(_ code: String) -> String {
        languages[code.lowercased()] ?? code.lowercased()
    }

    static func iso639_1(_ code: String) -> String {
        let lower = code.lowercased()
        if let short = languages.first(where: { $0.value == lower })?.key { return short }
        return lower.count > 2 && lower.contains("-") ? String(lower.prefix(2)) : lower
    }

    private static func opfScheme(_ scheme: String) -> String {
        switch scheme.lowercased() {
        case "isbn": "ISBN"
        case "asin", "amazon": "AMAZON"
        case "google": "GOOGLE"
        default: scheme.uppercased()
        }
    }

    private static func ourScheme(_ scheme: String) -> String {
        switch scheme.lowercased() {
        case "amazon", "mobi-asin", "asin": "asin"
        default: scheme.lowercased()
        }
    }

    /// «2004» → «2004-01-01T00:00:00+00:00»; «2004-05-01» → «2004-05-01T00:00:00+00:00».
    private static func calibreDate(_ published: String) -> String? {
        let parts = published.split(separator: "-").map(String.init)
        guard let year = parts.first, year.count == 4, Int(year) != nil else { return nil }
        let month = parts.count > 1 ? parts[1] : "01"
        let day = parts.count > 2 ? String(parts[2].prefix(2)) : "01"
        return "\(year)-\(month)-\(day)T00:00:00+00:00"
    }

    private static func ourDate(_ date: String) -> String? {
        let day = String(date.prefix(10))
        guard day.count >= 4 else { return nil }
        if day.hasSuffix("-01-01") { return String(day.prefix(4)) }
        return day
    }

    private static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private static func parseTimestamp(_ value: String) -> Date? {
        // Calibre escribe microsegundos («…05.123456+00:00»); se descartan.
        let trimmed = value.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: trimmed)
    }

    private static func format(_ number: Double) -> String {
        String(format: "%.1f", number)
    }

    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

/// Recorre el OPF y junta los campos de `<metadata>`.
private final class OPFReader: NSObject, XMLParserDelegate {
    var titles: [String] = []
    var authors: [String] = []
    var subjects: [String] = []
    var languages: [String] = []
    var identifiers: [(String, String)] = []
    var meta: [String: String] = [:]
    var publisher: String?
    var description: String?
    var date: String?

    private var text = ""
    private var attributes: [String: String] = [:]

    private func local(_ name: String) -> String {
        name.split(separator: ":").last.map(String.init) ?? name
    }

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String] = [:]) {
        text = ""
        var normalized: [String: String] = [:]
        for (key, value) in attributes { normalized[local(key)] = value }
        self.attributes = normalized
        if local(name) == "meta", let key = normalized["name"], let content = normalized["content"] {
            meta[key] = content
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        defer { text = "" }
        guard !value.isEmpty else { return }
        switch local(name) {
        case "title": titles.append(value)
        case "creator":
            let role = attributes["role"] ?? "aut"
            if role == "aut" { authors.append(value) }
        case "subject": subjects.append(value)
        case "language": languages.append(value)
        case "identifier": identifiers.append((attributes["scheme"] ?? "", value))
        case "publisher": publisher = publisher ?? value
        case "description": description = description ?? value
        case "date": date = date ?? value
        default: break
        }
    }
}
