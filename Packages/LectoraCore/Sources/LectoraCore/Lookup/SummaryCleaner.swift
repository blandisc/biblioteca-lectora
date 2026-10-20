import Foundation

/// Sinopsis legibles: sin HTML (Google), sin enlaces ni notas de fuente
/// (Open Library) y con párrafos separados por una línea en blanco.
public enum SummaryCleaner {
    public static func clean(_ raw: String) -> String? {
        var text = raw
        // HTML: saltos y párrafos a líneas; el resto de etiquetas fuera.
        text = text.replacingOccurrences(of: #"(?i)<br\s*/?>"#, with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(?i)</p>\s*<p[^>]*>"#, with: "\n\n", options: .regularExpression)
        text = text.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        for (entity, value) in ["&amp;": "&", "&quot;": "\"", "&#39;": "'", "&apos;": "'", "&lt;": "<", "&gt;": ">", "&nbsp;": " "] {
            text = text.replacingOccurrences(of: entity, with: value)
        }
        // Open Library: lo que sigue a una raya horizontal son notas («Contains:», fuentes…).
        if let rule = text.range(of: #"\n\s*-{3,}"#, options: .regularExpression) {
            text = String(text[..<rule.lowerBound])
        }
        // Referencias de Markdown: «[1]: https://…» y «([source][1])».
        text = text.replacingOccurrences(of: #"(?m)^\s*\[\d+\]:\s*\S+.*$"#, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\(\s*\[(source|fuente)\]\[\d+\]\s*\)"#, with: "",
                                         options: [.regularExpression, .caseInsensitive])
        // Enlaces: «[texto](url)» y «[texto][1]» → «texto».
        text = text.replacingOccurrences(of: #"\[([^\]]+)\]\((?:[^)]+)\)"#, with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\[([^\]]+)\]\[\d+\]"#, with: "$1", options: .regularExpression)
        // Párrafos: líneas sin espacios sobrantes, como mucho una línea en blanco.
        let paragraphs = text.components(separatedBy: .newlines)
            .map { $0.split(whereSeparator: { $0 == " " || $0 == "\t" }).joined(separator: " ") }
        text = paragraphs.joined(separator: "\n")
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // Muy cortas o que solo dicen de dónde vienen no sirven.
        guard text.count >= 40 else { return nil }
        return text
    }

    /// Idioma de la sinopsis («es», «en»…) si se puede saber.
    public static func language(of summary: String) -> String? {
        TextMatch.language(of: summary)
    }
}
