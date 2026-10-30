import Foundation

/// Comparar títulos y nombres como lo haría una persona: sin acentos, sin
/// artículos, sin subtítulos ni series, y tolerando transliteraciones
/// («Dostoievski» / «Dostoyevsky») y apellidos dobles («Cervantes Saavedra»).
enum TextMatch {
    private static let stopWords: Set<String> = [
        "el", "la", "los", "las", "lo", "un", "una", "unos", "unas", "de", "del", "y", "e", "o", "en", "a", "al",
        "the", "an", "of", "and", "to", "in", "on", "for", "le", "les", "des", "du", "et",
    ]
    /// Partículas de nombres que no distinguen a una persona.
    private static let nameParticles: Set<String> = [
        "de", "del", "la", "las", "los", "y", "e", "van", "von", "der", "den", "da", "di", "du", "le", "jr", "sr",
    ]

    static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil)
    }

    static func words(_ text: String) -> [String] {
        fold(text).components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
    }

    static func tokens(_ text: String) -> [String] {
        words(text).filter { !stopWords.contains($0) }
    }

    /// Título sin subtítulo («Sapiens: De animales…» → «Sapiens») ni serie
    /// entre paréntesis o corchetes.
    static func mainTitle(_ title: String) -> String {
        var main = title.replacingOccurrences(of: #"\s*[\(\[][^\)\]]*[\)\]]"#, with: "", options: .regularExpression)
        // «. » solo después de una frase («Homo deus. Breve historia…»), no de «Dr.» o «St.».
        for (separator, minimum) in [(":", 2), (" - ", 2), (" – ", 2), (" — ", 2), (". ", 5)] {
            if let range = main.range(of: separator), main.distance(from: main.startIndex, to: range.lowerBound) >= minimum {
                main = String(main[..<range.lowerBound])
            }
        }
        return main.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 0–1. Compara el título completo y el principal de ambos y se queda con
    /// el mejor: «Sapiens» = «Sapiens: De animales a dioses».
    static func titleSimilarity(_ a: String, _ b: String) -> Double {
        let options = [(a, b), (mainTitle(a), mainTitle(b)), (a, mainTitle(b)), (mainTitle(a), b)]
        return options.map { setSimilarity(Set(tokens($0.0)), Set(tokens($0.1))) }.max() ?? 0
    }

    private static func setSimilarity(_ left: Set<String>, _ right: Set<String>) -> Double {
        guard !left.isEmpty, !right.isEmpty else { return 0 }
        if left == right { return 1 }
        // Palabras casi iguales cuentan («tolstoi» / «tolstoy», «mañana» / «manana»).
        var shared = 0.0
        for word in left where right.contains(word) || right.contains(where: { close(word, $0) }) { shared += 1 }
        let union = Double(left.count + right.count) - shared
        let jaccard = shared / union
        // Uno contenido en el otro («Rayuela» y «Rayuela (edición conmemorativa)»)
        // vale menos que igual: puede ser otro libro («Guía de Rayuela»).
        let containment = shared / Double(min(left.count, right.count))
        return max(jaccard, containment * 0.6)
    }

    // MARK: Personas

    /// Palabras que identifican a una persona: sin iniciales ni partículas.
    static func nameParts(_ name: String) -> [String] {
        // «J.R.R. Tolkien» y «J. R. R. Tolkien» dan lo mismo.
        words(name).filter { $0.count > 1 && !nameParticles.contains($0) }
    }

    /// 1: la misma persona; 0.8: mismo apellido con otro nombre de pila (o una
    /// transliteración que no se reconoce: «Lev» / «León»); 0.5: no se puede
    /// saber; 0: otra persona.
    static func sameAuthorScore(_ a: [String], _ b: [String]) -> Double {
        // «Лев Толстой» o «刘慈欣» no se pueden comparar con «León Tolstói»: no se sabe.
        let left = a.filter(isLatin).map(nameParts).filter { !$0.isEmpty }
        let right = b.filter(isLatin).map(nameParts).filter { !$0.isEmpty }
        guard !left.isEmpty, !right.isEmpty else { return 0.5 }
        var best = 0.0
        for x in left {
            for y in right { best = max(best, personScore(x, y)) }
        }
        return best
    }

    /// Coincide el apellido (la última palabra de uno aparece en el otro); el
    /// nombre de pila, si ambos lo traen, confirma.
    static func personScore(_ x: [String], _ y: [String]) -> Double {
        let (short, long) = x.count <= y.count ? (x, y) : (y, x)
        guard let surname = short.last else { return 0 }
        let hasSurname = long.contains { close(surname, $0) }
        // «Liu Cixin» / «Cixin Liu»: el orden cambia.
        let sameSet = Set(short).isSubset(of: Set(long))
        guard hasSurname || sameSet else { return 0 }
        guard short.count > 1, let first = short.first else { return 1 }
        let firstMatches = long.contains { close(first, $0) || $0.hasPrefix(first) || first.hasPrefix($0) }
        return firstMatches ? 1 : 0.8
    }

    /// Escrito en alfabeto latino (con acentos y letras como ñ, ç, ø).
    static func isLatin(_ text: String) -> Bool {
        let letters = text.unicodeScalars.filter(CharacterSet.letters.contains)
        guard !letters.isEmpty else { return false }
        return letters.allSatisfy { $0.value < 0x0250 || (0x1E00...0x1EFF).contains($0.value) }
    }

    /// Dos palabras que probablemente son la misma, con alguna letra distinta.
    static func close(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        let longest = max(a.count, b.count)
        guard longest >= 5, abs(a.count - b.count) <= 2 else { return false }
        return Double(distance(a, b)) / Double(longest) <= 0.25
    }

    /// Distancia de Levenshtein.
    static func distance(_ a: String, _ b: String) -> Int {
        let x = Array(a), y = Array(b)
        if x.isEmpty { return y.count }
        if y.isEmpty { return x.count }
        var previous = Array(0...y.count)
        var current = [Int](repeating: 0, count: y.count + 1)
        for i in 1...x.count {
            current[0] = i
            for j in 1...y.count {
                let cost = x[i - 1] == y[j - 1] ? 0 : 1
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
            }
            swap(&previous, &current)
        }
        return previous[y.count]
    }

    // MARK: Idioma de un texto

    /// Idioma probable de un texto largo («es», «en» u otro), por palabras frecuentes.
    static func language(of text: String) -> String? {
        let sample = words(String(text.prefix(1_500)))
        guard sample.count >= 12 else { return nil }
        let common: [String: Set<String>] = [
            "es": ["el", "la", "los", "las", "que", "de", "y", "en", "un", "una", "por", "con", "para", "su", "es", "se", "del", "como"],
            "en": ["the", "and", "of", "to", "is", "in", "that", "his", "her", "with", "for", "this", "was", "as", "by", "on"],
            "pt": ["o", "os", "as", "que", "de", "e", "em", "um", "uma", "com", "para", "seu", "nao", "do", "da"],
            "fr": ["le", "les", "des", "et", "est", "une", "dans", "qui", "pour", "pas", "sur", "du", "il"],
            "de": ["der", "die", "das", "und", "ist", "nicht", "mit", "sich", "auf", "ein", "eine", "dem", "den"],
            "nl": ["het", "een", "van", "en", "zijn", "niet", "met", "voor", "dat", "op", "aan", "over", "tot"],
            "it": ["il", "di", "che", "e", "la", "per", "un", "una", "non", "sono", "della", "nel", "gli"],
            // Catalán: se parece al español; lo delatan «i», «amb», «els», «és».
            "ca": ["i", "amb", "els", "per", "es", "dels", "seva", "perque", "als", "aquest", "aquesta", "pero", "historia"],
        ]
        let scores = common.mapValues { set in sample.filter(set.contains).count }
        guard let best = scores.max(by: { $0.value < $1.value }), best.value >= 4 else { return nil }
        return best.key
    }
}
