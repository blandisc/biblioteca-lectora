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
