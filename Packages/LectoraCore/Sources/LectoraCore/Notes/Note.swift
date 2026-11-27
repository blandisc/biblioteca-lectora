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

    /// Las primeras líneas después del título, en texto plano (para la lista). Solo aquí se quitan
    /// las cercas, las comillas de código y las marcas de una lista (auditoría 7: en el título
    /// cambiaban el nombre del archivo).
    public var preview: String {
        let lines = text.components(separatedBy: .newlines)
        let firstText = lines.firstIndex { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let body = Array(lines.dropFirst((firstText ?? 0) + 1))
        return String(NoteMarkdown.previewLines(body).filter { !$0.isEmpty }.joined(separator: " ").prefix(240))
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

    /// El título: la primera línea con texto, sin `#`. De él sale el nombre del archivo, así que
    /// se lee siempre igual (auditoría 7): «# 1. Introducción» es «1. Introducción» y «`git`»
    /// conserva sus comillas. Si cambiara la forma de leerlo, tus notas cambiarían de nombre solas
    /// y se romperían sus enlaces en Obsidian.
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

    /// Añade un bloque al final de una nota, separado por una línea en blanco, con el mismo final
    /// de renglón que ya usa la nota (auditoría 5).
    public static func appending(_ block: String, to text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let separator = lines(text).separator
        let added = lines(block).lines.joined(separator: separator)
        return trimmed.isEmpty ? added + separator : trimmed + separator + separator + added + separator
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

    /// Texto plano de una línea: sin `#`, `>`, `[[ ]]`, enlaces ni énfasis. Es la forma de leer el
    /// título y no cambia (auditoría 7): de ella sale el nombre del archivo de la nota. Lo que solo
    /// sirve para la vista previa (cercas, comillas de código, listas) va en `previewLines`.
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

    /// Las líneas del cuerpo de una nota en texto plano, para la vista previa: sin cercas de
    /// código («``` código…» en el Cuaderno, auditoría 6), sin comillas de código, sin la casilla
    /// de una tarea y sin las marcas de una lista. Un número solo es de una lista si al lado hay
    /// otro renglón de lista (auditoría 7): «1984. Fue el año» solo es un párrafo tuyo.
    public static func previewLines(_ lines: [String]) -> [String] {
        let bullet = #"^(?:[-*+])\s+(?:\[[ xX]\]\s+)?"#
        let number = #"^\d{1,9}[.)]\s+(?:\[[ xX]\]\s+)?"#
        func unquoted(_ line: String) -> String {
            var text = line.trimmingCharacters(in: .whitespaces)
            while text.hasPrefix(">") { text = text.dropFirst().trimmingCharacters(in: .whitespaces) }
            return text
        }
        let bare = lines.map(unquoted)
        func isItem(_ index: Int) -> Bool {
            bare.indices.contains(index)
                && (bare[index].range(of: bullet, options: .regularExpression) != nil
                    || bare[index].range(of: number, options: .regularExpression) != nil)
        }
        return lines.indices.map { index in
            if fence(lines[index]) != nil { return "" }
            var text = bare[index]
            if let marker = text.range(of: bullet, options: .regularExpression) {
                text.removeSubrange(marker)
            } else if let marker = text.range(of: number, options: .regularExpression), isItem(index - 1) || isItem(index + 1) {
                text.removeSubrange(marker)
            }
            return plain(text).replacingOccurrences(of: "`", with: "")
        }
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

    /// Los renglones de la nota y con qué terminan (auditoría 5): una nota de Windows u otro editor
    /// termina sus renglones en «\r\n» (o «\r»), que para Swift es un solo carácter; partir solo en
    /// «\n» no la partía y la marca se veía en el editor. Al volver a juntarla se usa el mismo final.
    static func lines(_ text: String) -> (lines: [String], separator: String) {
        let split = rows(text)
        return (split.map(\.text), split.lazy.map(\.ending).first { !$0.isEmpty } ?? "\n")
    }

    /// Un renglón y con qué termina («» el último). Con renglones mezclados (unos «\r\n», otros
    /// «\n») cada uno conserva el suyo al volver a juntarlos (auditoría 6, B1: todos quedaban con
    /// el del primero y la nota cambiaba entera al guardar).
    struct Row: Equatable {
        var text: String
        var ending: String
    }

    static func rows(_ text: String) -> [Row] {
        var rows: [Row] = []
        var current = ""
        for character in text {
            if character == "\r\n" || character == "\n" || character == "\r" {
                rows.append(Row(text: current, ending: String(character)))
                current = ""
            } else {
                current.append(character)
            }
        }
        rows.append(Row(text: current, ending: ""))
        return rows
    }

    /// Vuelve a juntar los renglones, cada uno con su final; el último no lleva final aunque lo
    /// tuviera (así quitar el último renglón no deja uno de más).
    static func joined(_ rows: [Row]) -> String {
        rows.enumerated().map { $0.element.text + ($0.offset == rows.count - 1 ? "" : $0.element.ending) }.joined()
    }

    /// El final de renglón de la nota (el primero que usa; «\n» si no tiene).
    public static func lineEnding(of text: String) -> String {
        lines(text).separator
    }

    /// Añade un párrafo tuyo (la nota de un subrayado) al final, con el final de renglón de la nota
    /// (auditoría 6, B1: se le ponía «\n» a una nota de Windows).
    public static func appendingParagraph(_ paragraph: String, to text: String) -> String {
        let ending = lineEnding(of: text)
        return text + ending + lines(paragraph).lines.joined(separator: ending) + ending
    }

    /// Una cerca de bloque de código (CommonMark): tres o más «`» o «~» seguidas, con hasta tres
    /// espacios antes. La de «`» no lleva otra «`» en su texto (`info`).
    static func fence(_ line: String) -> (mark: Character, length: Int, info: Substring)? {
        let indent = line.prefix { $0 == " " }.count
        guard indent <= 3 else { return nil }
        let text = line.dropFirst(indent)
        guard let mark = text.first, mark == "`" || mark == "~" else { return nil }
        let length = text.prefix { $0 == mark }.count
        guard length >= 3 else { return nil }
        let info = text.dropFirst(length)
        if mark == "`", info.contains("`") { return nil }
        return (mark, length, info)
    }

    /// Las marcas de sesión de la nota, con su renglón. Nunca dentro de un bloque de código
    /// (```` ``` ```` o `~~~`): ahí lo que parece una marca es texto tuyo. El bloque lo cierra solo
    /// una cerca del mismo signo, igual de larga o más y sin texto después, como en CommonMark
    /// (auditoría 5: «```swift» o «```» dentro de un bloque de «````» lo cerraban).
    static func markerLines(_ text: String) -> [(index: Int, line: String)] {
        var open: (mark: Character, length: Int)?
        var found: [(Int, String)] = []
        for (index, line) in lines(text).lines.enumerated() {
            if let current = open {
                if let close = fence(line), close.mark == current.mark, close.length >= current.length,
                   close.info.allSatisfy({ $0 == " " || $0 == "\t" }) {
                    open = nil
                }
                continue
            }
            if let start = fence(line) {
                open = (start.mark, start.length)
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
        let kept = rows(text).enumerated().filter { !hidden.contains($0.offset) }.map(\.element)
        return (joined(kept), markers.map { $0.line.trimmingCharacters(in: .whitespaces) })
    }

    /// Vuelve a poner las marcas que se quitaron para editar: debajo del título, donde la deja la
    /// nota de la sesión, o, sin título, al principio. Las que ya estén no se repiten. Lo demás
    /// de la nota no se mueve.
    public static func restoringComments(_ comments: [String], in text: String) -> String {
        let present = Set(markerLines(text).map { $0.line.trimmingCharacters(in: .whitespaces) })
        let missing = comments.filter { !present.contains($0) }
        guard !missing.isEmpty else { return text }
        var split = rows(text)
        let separator = lineEnding(of: text)
        let at = split.first?.text.trimmingCharacters(in: .whitespaces).hasPrefix("#") == true ? 1 : 0
        if at == split.count, at > 0 { split[at - 1].ending = separator }
        split.insert(contentsOf: missing.map { Row(text: $0, ending: separator) }, at: at)
        return joined(split)
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
        joined(rows(text).filter { !isComment($0.text) })
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
        /// Un bloque de código (entre cercas ```` ``` ```` o `~~~`), tal cual, con sus renglones
        /// (auditoría 6: se juntaba en un solo renglón como párrafo).
        case code(String)
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
        var code: (mark: Character, length: Int, lines: [String])?
        for raw in lines(text).lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            // Dentro de un bloque de código todo es suyo, hasta su cerca (como en `markerLines`).
            if let open = code {
                if let close = fence(raw), close.mark == open.mark, close.length >= open.length,
                   close.info.allSatisfy({ $0 == " " || $0 == "\t" }) {
                    blocks.append(.code(open.lines.joined(separator: "\n")))
                    code = nil
                } else {
                    code?.lines.append(raw)
                }
                continue
            }
            if let start = fence(raw) {
                flush()
                code = (start.mark, start.length, [])
                continue
            }
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
        // Un bloque sin cerrar llega hasta el final de la nota (CommonMark).
        if let open = code { blocks.append(.code(open.lines.joined(separator: "\n"))) }
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
