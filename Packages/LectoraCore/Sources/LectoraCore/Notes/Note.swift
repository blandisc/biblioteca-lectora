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
        if isComment(text) { return "" }
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

    /// La marca de la nota de una sesión de lectura: un comentario que no se ve (ni en Gabinete
    /// ni en Obsidian) y viaja con el archivo. Así cualquier dispositivo encuentra la misma nota;
    /// antes cada uno recordaba la suya y una sesión podía acabar con dos notas.
    public static func sessionMarker(_ id: UUID) -> String {
        "<!-- gabinete:sesion \(id.uuidString) -->"
    }

    /// La nota de esa sesión, si ya existe en la carpeta. Aguanta espacios y mayúsculas de más
    /// en la marca (un editor de afuera pudo tocarla).
    public static func note(forSession id: UUID, in notes: [Note]) -> Note? {
        let wanted = id.uuidString.lowercased()
        return notes.first { note in
            markerLines(note.text).contains { sessionID(inMarker: $0.line) == wanted }
        }
    }

    /// El id (en minúsculas) de una línea que es la marca de una sesión, o nil.
    static func sessionID(inMarker line: String) -> String? {
        guard isComment(line) else { return nil }
        let words = line.lowercased().replacingOccurrences(of: "<!--", with: " ").replacingOccurrences(of: "-->", with: " ")
            .split(whereSeparator: \.isWhitespace)
        return words.count == 2 && words[0] == "gabinete:sesion" ? String(words[1]) : nil
    }

    /// ¿Es la marca de una sesión? (Cualquier otro comentario es tuyo.)
    public static func isSessionMarker(_ line: String) -> Bool {
        sessionID(inMarker: line) != nil
    }

    /// Las marcas de sesión de la nota, con su renglón. Nunca dentro de un bloque de código
    /// (```` ``` ```` o `~~~`): ahí lo que parece una marca es texto tuyo.
    static func markerLines(_ text: String) -> [(index: Int, line: String)] {
        var fence: String?
        var found: [(Int, String)] = []
        for (index, line) in text.components(separatedBy: "\n").enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let open = fence {
                if trimmed.hasPrefix(open) { fence = nil }
                continue
            }
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                fence = String(trimmed.prefix(3))
                continue
            }
            if isSessionMarker(line) { found.append((index, line)) }
        }
        return found
    }

    /// Lo que se escribe en el editor: la nota sin la marca de su sesión, que no se ve y no se
    /// debe poder borrar sin querer (auditoría 3: borrar la marca hacía una segunda nota para la
    /// misma sesión). Solo esa marca: tus comentarios y tus bloques de código se quedan como los
    /// escribiste, en su lugar (auditoría 4). Devuelve también las marcas, para volver a ponerlas
    /// al guardar (`restoringComments`).
    public static func editable(_ text: String) -> (text: String, comments: [String]) {
        let markers = markerLines(text)
        guard !markers.isEmpty else { return (text, []) }
        let hidden = Set(markers.map(\.index))
        let kept = text.components(separatedBy: "\n").enumerated().filter { !hidden.contains($0.offset) }.map(\.element)
        return (kept.joined(separator: "\n"), markers.map { $0.line.trimmingCharacters(in: .whitespaces) })
    }

    /// Vuelve a poner las marcas que se quitaron para editar: debajo del título, donde la deja la
    /// nota de la sesión, o, sin título, al principio. Las que ya estén no se repiten. Lo demás
    /// de la nota no se mueve.
    public static func restoringComments(_ comments: [String], in text: String) -> String {
        let present = Set(markerLines(text).map { $0.line.trimmingCharacters(in: .whitespaces) })
        let missing = comments.filter { !present.contains($0) }
        guard !missing.isEmpty else { return text }
        var lines = text.components(separatedBy: "\n")
        let at = lines.first?.trimmingCharacters(in: .whitespaces).hasPrefix("#") == true ? 1 : 0
        lines.insert(contentsOf: missing, at: at)
        return lines.joined(separator: "\n")
    }

    /// Lo que se guarda al terminar de escribir. Si dejaste la nota vacía (o solo «#»), vacío:
    /// la nota se borra aunque fuera la de una sesión; antes la marca volvía y la nota se quedaba
    /// (auditoría 4, M2).
    public static func savedText(_ text: String, restoring comments: [String]) -> String {
        isBlank(text) ? "" : restoringComments(comments, in: text)
    }

    /// Una nota sin nada tuyo: vacía, solo «#» o solo la marca de su sesión.
    public static func isBlank(_ text: String) -> Bool {
        editable(text).text.trimmingCharacters(in: CharacterSet(charactersIn: "#").union(.whitespacesAndNewlines)).isEmpty
    }

    /// El texto en que se busca: sin comentarios, así «sesion» o «gabinete» no encuentran las
    /// notas de sesión por su marca escondida (auditoría 3). Los comentarios no se ven al leer.
    public static func searchText(_ text: String) -> String {
        text.components(separatedBy: "\n").filter { !isComment($0) }.joined(separator: "\n")
    }

    /// Un comentario de Markdown en un renglón (`<!-- … -->`): no se enseña.
    public static func isComment(_ line: String) -> Bool {
        let text = line.trimmingCharacters(in: .whitespaces)
        return text.hasPrefix("<!--") && text.hasSuffix("-->")
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
            } else if isComment(line) {
                continue
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
