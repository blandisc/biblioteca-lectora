import Foundation

/// La hendidura (HE): el texto pasa por una ranura, un pedazo a la vez.
/// Palabra por palabra (HE-A) o en frases cortas que respetan dónde respira
/// la oración (HE-B). Lo que dice la investigación: hasta unas 300–350 palabras
/// por minuto se entiende igual que leyendo normal, y una pausa en cada punto
/// quita casi toda la pérdida (Masson, 1983). Por eso el ritmo tiene tope y
/// cada oración termina con un respiro.
public enum Slit {
    public enum Unit: String, CaseIterable, Sendable {
        /// Una palabra a la vez, con su letra de enfoque (HE-A).
        case word
        /// Tres a cinco palabras, cortadas en comas y antes de «que», «y»… (HE-B).
        case phrase
    }

    /// Un pedazo del texto: lo que se ve en la ranura y dónde empieza en el
    /// texto original (en unidades UTF-16, como las cuenta JavaScript).
    public struct Chunk: Equatable, Sendable {
        public var text: String
        public var offset: Int
        public var words: Int
        public var endsSentence: Bool
        public var endsClause: Bool
    }

    /// Ritmo al empezar, y de cuánto a cuánto se puede mover.
    public static let defaultWordsPerMinute = 260
    public static let wordsPerMinuteRange = 200...400
    public static let wordsPerMinuteStep = 20

    /// Lo más largo que puede ser una frase, y desde cuántas palabras se corta
    /// antes de una palabra que abre otra idea.
    static let phraseMax = 5
    static let phraseMin = 3
    /// Respiros: al final de la oración y en una coma; y lo mínimo que una
    /// palabra suelta se queda en la ranura.
    static let sentencePause: TimeInterval = 0.45
    static let clausePause: TimeInterval = 0.15
    static let wordFloor: TimeInterval = 0.16
    /// Palabras largas: un poco más de tiempo por cada letra arriba de esto.
    static let longWord = 8
    static let longWordExtra: TimeInterval = 0.02

    /// Antes de estas palabras empieza otra idea: buen lugar para cortar una frase.
    static let openers: Set<String> = [
        "que", "y", "e", "o", "u", "pero", "sino", "aunque", "porque", "pues", "como", "cuando",
        "donde", "mientras", "para", "por", "con", "sin", "sobre", "entre", "hacia", "hasta",
        "and", "or", "but", "that", "which", "because", "when", "while", "with", "for",
    ]

    /// Corta el texto en pedazos. Los espacios y saltos de línea no cuentan.
    public static func chunks(_ text: String, unit: Unit) -> [Chunk] {
        let words = tokens(text)
        guard unit == .phrase else {
            return words.map { Chunk(text: $0.text, offset: $0.offset, words: 1,
                                     endsSentence: endsSentence($0.text), endsClause: endsClause($0.text)) }
        }
        var chunks: [Chunk] = []
        var current: [(text: String, offset: Int)] = []
        func close() {
            guard let first = current.first, let last = current.last else { return }
            chunks.append(Chunk(text: current.map(\.text).joined(separator: " "), offset: first.offset,
                                words: current.count, endsSentence: endsSentence(last.text),
                                endsClause: endsClause(last.text)))
            current = []
        }
        for (index, word) in words.enumerated() {
            current.append(word)
            let next = index + 1 < words.count ? words[index + 1].text : nil
            let opener = next.map { openers.contains(bare($0)) } ?? false
            if endsSentence(word.text) || endsClause(word.text) || current.count >= phraseMax
                || (current.count >= phraseMin && opener) {
                close()
            }
        }
        close()
        return chunks
    }

    /// Cuánto se queda un pedazo en la ranura a este ritmo.
    public static func duration(of chunk: Chunk, wordsPerMinute: Int) -> TimeInterval {
        let perWord = 60 / Double(max(wordsPerMinute, 1))
        let letters = chunk.text.filter(\.isLetter).count
        let extraLetters = chunk.words == 1 ? max(0, letters - longWord) : 0
        var seconds = max(wordFloor, perWord * Double(chunk.words)) + Double(extraLetters) * longWordExtra
        if chunk.endsSentence { seconds += sentencePause } else if chunk.endsClause { seconds += clausePause }
        return seconds
    }

    /// La letra en la que se fija el ojo (palabra por palabra): un poco antes de
    /// la mitad, contando solo letras; índice en `Character`s de la palabra.
    public static func focusIndex(of word: String) -> Int {
        let characters = Array(word)
        let letters = characters.indices.filter { characters[$0].isLetter || characters[$0].isNumber }
        guard !letters.isEmpty else { return 0 }
        let target = letters.count <= 1 ? 0 : letters.count <= 5 ? 1 : (letters.count - 1) * 35 / 100
        return letters[min(target, letters.count - 1)]
    }

    /// El pedazo que contiene una posición del texto (para volver a donde ibas).
    public static func index(atOffset offset: Int, in chunks: [Chunk]) -> Int {
        chunks.lastIndex { $0.offset <= offset } ?? 0
    }

    // MARK: - Palabras

    private static func tokens(_ text: String) -> [(text: String, offset: Int)] {
        var result: [(text: String, offset: Int)] = []
        var start: String.Index?
        for index in text.indices {
            if text[index].isWhitespace {
                if let begin = start {
                    result.append((String(text[begin..<index]), begin.utf16Offset(in: text)))
                    start = nil
                }
            } else if start == nil {
                start = index
            }
        }
        if let begin = start { result.append((String(text[begin...]), begin.utf16Offset(in: text))) }
        return result
    }

    private static func bare(_ word: String) -> String {
        word.lowercased().trimmingCharacters(in: .punctuationCharacters.union(.symbols))
    }

    private static func endsSentence(_ word: String) -> Bool {
        let trimmed = word.trimmingCharacters(in: CharacterSet(charactersIn: "»”\"’')]"))
        return trimmed.hasSuffix(".") || trimmed.hasSuffix("?") || trimmed.hasSuffix("!") || trimmed.hasSuffix("…")
    }

    private static func endsClause(_ word: String) -> Bool {
        let trimmed = word.trimmingCharacters(in: CharacterSet(charactersIn: "»”\"’')]"))
        return trimmed.hasSuffix(",") || trimmed.hasSuffix(";") || trimmed.hasSuffix(":")
    }
}
