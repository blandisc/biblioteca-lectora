import Foundation

/// Nota libre del Gabinete: un archivo Markdown normal en `Gabinete/Notas/`,
/// legible con Obsidian o cualquier editor.
///
/// - La primera línea es el título («# El silencio en Rulfo» o sin «#»).
/// - `[[Pedro Páramo]]` enlaza un libro por su título, como en Obsidian.
/// - Una cita de un subrayado es un bloque `>` con el libro y el enlace al
///   pasaje (`gabinete://subrayado/<id>`).
public struct Note: Identifiable, Hashable, Sendable {
    /// Nombre del archivo sin «.md»; identifica la nota dentro de la carpeta.
    public var fileName: String
    public var text: String
    public var modifiedAt: Date

    public var id: String { fileName }

    public init(fileName: String, text: String, modifiedAt: Date = Date()) {
        self.fileName = fileName
        self.text = text
        self.modifiedAt = modifiedAt
    }

    /// La primera línea con texto, sin «#». Si no hay, el nombre del archivo.
    public var title: String {
        Self.title(of: text) ?? fileName
    }

    /// Las primeras líneas después del título, en texto plano (para la lista).
    public var preview: String {
        let lines = text.components(separatedBy: .newlines)
        let firstText = lines.firstIndex { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let body = lines.dropFirst((firstText ?? 0) + 1)
            .map { NoteMarkdown.plain($0) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return String(body.prefix(240))
    }

    /// Títulos de los libros enlazados con `[[ ]]`, en orden y sin repetir.
    public var bookLinks: [String] {
        NoteMarkdown.links(in: text)
    }

    /// ¿Enlaza este libro? Sin distinguir mayúsculas ni acentos.
    public func links(bookTitle: String) -> Bool {
        let key = NoteMarkdown.key(bookTitle)
        return bookLinks.contains { NoteMarkdown.key($0) == key }
    }

    static func title(of text: String) -> String? {
        for line in text.components(separatedBy: .newlines) {
            var trimmed = line.trimmingCharacters(in: .whitespaces)
            while trimmed.hasPrefix("#") { trimmed.removeFirst() }
            trimmed = NoteMarkdown.plain(trimmed)
            if !trimmed.isEmpty { return trimmed }
        }
        return nil
    }
}

/// Lo poco de Markdown que entiende Gabinete: enlaces a libros, citas y
/// enlaces a pasajes. Todo en texto plano para que funcione fuera de la app.
public enum NoteMarkdown {
    /// Esquema de los enlaces internos.
    public static let scheme = "gabinete"

    /// Enlace a un subrayado: vuelve al pasaje exacto.
    public static func passageURL(annotationID: UUID) -> URL {
        URL(string: "\(scheme)://subrayado/\(annotationID.uuidString)")!
    }

    /// Enlace a un libro por su título (lo que produce `[[Título]]` dentro de la app).
    public static func bookURL(title: String) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "libro"
        components.queryItems = [URLQueryItem(name: "titulo", value: title)]
        return components.url!
    }

    /// Qué abre un enlace de una nota.
    public enum Target: Equatable, Sendable {
        case book(title: String)
        case passage(annotationID: UUID)
    }

    public static func target(of url: URL) -> Target? {
        guard url.scheme == scheme else { return nil }
        switch url.host {
        case "libro":
            let title = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "titulo" }?.value
            return title.map { .book(title: $0) }
        case "subrayado":
            return UUID(uuidString: url.lastPathComponent).map { .passage(annotationID: $0) }
        default:
            return nil
        }
    }

    /// Cita de un subrayado, lista para añadir a una nota:
    ///
    ///     > Le apreté sus manos en señal de que lo haría…
    ///     > — [[Pedro Páramo]] · [ir al pasaje](gabinete://subrayado/…)
    public static func quote(_ text: String, bookTitle: String, annotationID: UUID) -> String {
        let lines = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
            .map { "> " + $0 }
        let source = "> — [[\(bookTitle)]] · [ir al pasaje](\(passageURL(annotationID: annotationID).absoluteString))"
        return (lines + [source]).joined(separator: "\n")
    }

    /// Añade un bloque al final de una nota, separado por una línea en blanco.
    public static func appending(_ block: String, to text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? block + "\n" : trimmed + "\n\n" + block + "\n"
    }

    /// Títulos enlazados con `[[Título]]` o `[[Título|texto]]`.
    public static func links(in text: String) -> [String] {
        var result: [String] = []
        var seen = Set<String>()
        var rest = text[...]
        while let open = rest.range(of: "[["), let close = rest[open.upperBound...].range(of: "]]") {
            let inside = rest[open.upperBound..<close.lowerBound]
            let target = inside.split(separator: "|", maxSplits: 1).first.map(String.init) ?? ""
            let title = target.trimmingCharacters(in: .whitespaces)
            if !title.isEmpty, !title.contains("\n"), seen.insert(key(title)).inserted {
                result.append(title)
            }
            rest = rest[close.upperBound...]
        }
        return result
    }

    /// `[[Título]]` → enlace Markdown normal con el esquema de Gabinete, para
    /// mostrarlo con `AttributedString(markdown:)`.
    public static func resolvingLinks(_ line: String) -> String {
        var output = ""
        var rest = line[...]
        while let open = rest.range(of: "[["), let close = rest[open.upperBound...].range(of: "]]") {
            output += rest[..<open.lowerBound]
            let inside = rest[open.upperBound..<close.lowerBound]
            let parts = inside.split(separator: "|", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if let title = parts.first, !title.isEmpty {
                let label = parts.count > 1 ? parts[1] : title
                output += "[\(escaped(label))](\(bookURL(title: title).absoluteString))"
            } else {
                output += rest[open.lowerBound..<close.upperBound]
            }
            rest = rest[close.upperBound...]
        }
        return output + rest
    }

    /// Texto plano de una línea: sin `#`, `>`, `[[ ]]`, enlaces ni énfasis.
    public static func plain(_ line: String) -> String {
        var text = line.trimmingCharacters(in: .whitespaces)
        while text.hasPrefix("#") || text.hasPrefix(">") {
            text.removeFirst()
            text = text.trimmingCharacters(in: .whitespaces)
        }
        if text.hasPrefix("- ") || text.hasPrefix("* ") { text.removeFirst(2) }
        // [[Título|texto]] → texto; [[Título]] → Título
        var output = ""
        var rest = text[...]
        while let open = rest.range(of: "[["), let close = rest[open.upperBound...].range(of: "]]") {
            output += rest[..<open.lowerBound]
            let parts = rest[open.upperBound..<close.lowerBound].split(separator: "|", maxSplits: 1)
            output += parts.last.map(String.init) ?? ""
            rest = rest[close.upperBound...]
        }
        output += rest
        // [texto](url) → texto
        while let open = output.range(of: "["),
              let middle = output[open.upperBound...].range(of: "]("),
              let close = output[middle.upperBound...].range(of: ")") {
            let label = output[open.upperBound..<middle.lowerBound]
            output.replaceSubrange(open.lowerBound..<close.upperBound, with: label)
        }
        return output.replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    /// Bloques de una nota para mostrarla: título, párrafos y citas.
    public enum Block: Equatable, Sendable {
        case heading(String)
        case paragraph(String)
        case quote(String)
    }

    /// Divide el texto en bloques. Las líneas `>` seguidas forman una cita; las
    /// líneas de texto seguidas, un párrafo (con sus saltos de línea).
    public static func blocks(_ text: String) -> [Block] {
        var blocks: [Block] = []
        var paragraph: [String] = []
        var quote: [String] = []
        func flush() {
            if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: "\n"))) }
            if !quote.isEmpty { blocks.append(.quote(quote.joined(separator: "\n"))) }
            paragraph = []
            quote = []
        }
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                flush()
            } else if line.hasPrefix("#") {
                flush()
                blocks.append(.heading(line.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)))
            } else if line.hasPrefix(">") {
                if !paragraph.isEmpty { flush() }
                quote.append(line.dropFirst().trimmingCharacters(in: .whitespaces))
            } else {
                if !quote.isEmpty { flush() }
                paragraph.append(raw)
            }
        }
        flush()
        return blocks
    }

    /// Lo que se está escribiendo después de un `[[` sin cerrar al final del
    /// texto (para sugerir libros), o `nil`.
    public static func openLinkQuery(in text: String) -> String? {
        guard let open = text.range(of: "[[", options: .backwards) else { return nil }
        let query = text[open.upperBound...]
        guard !query.contains("]]"), !query.contains("\n"), query.count <= 60 else { return nil }
        return String(query)
    }

    /// Cierra el `[[` abierto al final del texto con el título elegido.
    public static func completingLink(in text: String, with title: String) -> String {
        guard let open = text.range(of: "[[", options: .backwards) else { return text }
        return String(text[..<open.lowerBound]) + "[[\(title)]] "
    }

    /// Clave para comparar títulos: sin mayúsculas, acentos ni espacios de más.
    static func key(_ title: String) -> String {
        title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func escaped(_ label: String) -> String {
        label.replacingOccurrences(of: "[", with: "\\[").replacingOccurrences(of: "]", with: "\\]")
    }
}
