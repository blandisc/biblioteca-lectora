import Foundation

/// Reglas tuyas para autores y etiquetas, como los mapas de Calibre: «Gabo» →
/// «Gabriel García Márquez», «Fiction» → «Ficción», «Libro electrónico» → nada.
/// Se aplican a lo que llega de archivos e internet, no a lo que escribes a mano.
public struct MetadataRules: Codable, Equatable, Sendable {
    public struct Rule: Codable, Hashable, Identifiable, Sendable {
        public var id: UUID
        /// Lo que aparece (sin importar mayúsculas ni acentos).
        public var from: String
        /// Por qué cambiarlo; vacío quita la etiqueta.
        public var to: String

        public init(id: UUID = UUID(), from: String, to: String) {
            self.id = id
            self.from = from
            self.to = to
        }
    }

    public var authors: [Rule]
    public var tags: [Rule]

    public init(authors: [Rule] = [], tags: [Rule] = []) {
        self.authors = authors
        self.tags = tags
    }

    public var isEmpty: Bool { authors.isEmpty && tags.isEmpty }

    /// Deshace en las reglas de ahora solo lo que hizo un cambio que las llevó de `before` a
    /// `after` (auditoría 7, M5): la regla que añadió se quita, la que cambió regresa como
    /// estaba, y solo si siguen como las dejó; la que quitó vuelve (auditoría 8, M1). Las que hiciste o cambiaste después se quedan;
    /// antes deshacer ponía todas las reglas de antes encima.
    public func undoing(from before: MetadataRules, after: MetadataRules) -> MetadataRules {
        MetadataRules(authors: Self.undoing(authors, before: before.authors, after: after.authors),
                      tags: Self.undoing(tags, before: before.tags, after: after.tags))
    }

    private static func undoing(_ current: [Rule], before: [Rule], after: [Rule]) -> [Rule] {
        let old = Dictionary(before.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let touched = Dictionary(after.filter { old[$0.id] != $0 }.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var result = current.compactMap { rule -> Rule? in
            guard let left = touched[rule.id], left == rule else { return rule }
            return old[rule.id]
        }
        // La que ese cambio quitó regresa (auditoría 8, M1): deshacer quita la que añadió, y
        // rehacer, que deshace el deshacer, la debe devolver. Solo si no la tienes ya; vuelve a su
        // lugar de antes.
        let kept = Set(after.map(\.id))
        for (index, rule) in before.enumerated() where !kept.contains(rule.id) && !result.contains(where: { $0.id == rule.id }) {
            result.insert(rule, at: min(index, result.count))
        }
        return result
    }

    public func apply(to book: Book) -> Book {
        guard !isEmpty else { return book }
        var book = book
        book.authors = Self.map(book.authors, with: authors, allowsRemoval: false)
        book.tags = Self.map(book.tags, with: tags, allowsRemoval: true)
        return book
    }

    private static func map(_ values: [String], with rules: [Rule], allowsRemoval: Bool) -> [String] {
        guard !rules.isEmpty else { return values }
        var seen = Set<String>()
        var result: [String] = []
        for value in values {
            let key = TextMatch.fold(value).trimmingCharacters(in: .whitespaces)
            var mapped: String? = value
            if let rule = rules.first(where: { TextMatch.fold($0.from).trimmingCharacters(in: .whitespaces) == key }) {
                let target = rule.to.trimmingCharacters(in: .whitespaces)
                mapped = target.isEmpty ? (allowsRemoval ? nil : value) : target
            }
            if let mapped, seen.insert(TextMatch.fold(mapped)).inserted { result.append(mapped) }
        }
        return result
    }
}
