import Foundation

/// Cómo buscar en el libro la cita de un subrayado que llegó sin posición (Calibre,
/// Kindle vía Readwise). Las citas de fuera rara vez coinciden letra por letra con el
/// EPUB: terminan en «.» donde el libro dice «,», traen comillas o apóstrofos curvos, o
/// cortan a media palabra. Se prueba de la más exacta a la más suelta y gana la primera
/// que aparece en el libro.
public enum QuoteAnchor {
    /// Lo más corto que vale la pena buscar: menos letras dan falsos positivos.
    public static let minimumLength = 12
    /// Palabras del principio de la cita para el último intento.
    public static let openingWords = 12
    /// Largo máximo de una búsqueda (foliate busca por capítulo; más largo no ayuda).
    public static let maximumLength = 300

    /// Búsquedas a intentar, en orden y sin repetir.
    public static func queries(for quote: String) -> [String] {
        let spaced = quote.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let plain = straightened(spaced)
        let trimmed = trimmingEdges(plain)
        let words = trimmed.split(separator: " ")
        let opening = words.count > openingWords ? trimmingEdges(words.prefix(openingWords).joined(separator: " ")) : ""
        var out: [String] = []
        for candidate in [spaced, plain, trimmed, opening] {
            let query = String(candidate.prefix(maximumLength))
            if query.count >= minimumLength, !out.contains(query) { out.append(query) }
        }
        return out
    }

    /// Comillas y apóstrofos curvos a rectos, como los escriben la mayoría de los EPUB y Kindle.
    static func straightened(_ text: String) -> String {
        var out = text
        for (curly, straight) in [("’", "'"), ("‘", "'"), ("“", "\""), ("”", "\""), ("…", "...")] {
            out = out.replacingOccurrences(of: curly, with: straight)
        }
        return out
    }

    /// Sin puntuación ni comillas al principio y al final («astillero.» → «astillero»).
    static func trimmingEdges(_ text: String) -> String {
        let edges = CharacterSet.punctuationCharacters.union(.symbols).union(.whitespaces)
        return text.trimmingCharacters(in: edges)
    }
}
