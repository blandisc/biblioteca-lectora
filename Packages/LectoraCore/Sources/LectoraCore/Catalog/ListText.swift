import Foundation

/// Una lista como texto que se puede volver a separar sin partir nada: «Pérez & Hijos»
/// o «Ciencia, ficción» dentro de un elemento se escapan con «\».
public enum ListText {
    public static func join(_ items: [String], separator: String) -> String {
        items.map { $0.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: separator, with: "\\" + separator) }
            .joined(separator: separator)
    }

    /// Lo contrario de `join`. Un texto sin escapes (guardado antes) se separa como siempre.
    public static func split(_ text: String, separator: String) -> [String] {
        guard !separator.isEmpty, !text.isEmpty else { return text.isEmpty ? [] : [text] }
        var items: [String] = [], current = ""
        var rest = Substring(text)
        while !rest.isEmpty {
            if rest.hasPrefix("\\" + separator) {
                current += separator
                rest = rest.dropFirst(separator.count + 1)
            } else if rest.hasPrefix("\\\\") {
                current += "\\"
                rest = rest.dropFirst(2)
            } else if rest.hasPrefix(separator) {
                items.append(current)
                current = ""
                rest = rest.dropFirst(separator.count)
            } else {
                current.append(rest.removeFirst())
            }
        }
        items.append(current)
        return items
    }
}

extension String {
    /// A lo más `limit` letras, cortado entre palabras y con «…» (auditoría 7): la vista previa de
    /// una nota se cortaba a media palabra y sin «…». Un texto que cabe se queda igual; una sola
    /// palabra más larga que el límite sí se corta, también con «…».
    public func clipped(to limit: Int) -> String {
        guard count > limit, limit > 0 else { return self }
        let head = prefix(limit)
        let cut = self[head.endIndex].isWhitespace ? head[...] : head[..<(head.lastIndex(where: \.isWhitespace) ?? head.endIndex)]
        let words = cut.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ",;:.-–—")))
        return (words.isEmpty ? String(head) : words) + "…"
    }
}
