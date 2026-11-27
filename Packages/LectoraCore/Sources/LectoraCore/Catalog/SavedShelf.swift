import Foundation

/// Un estante (CB-1): una búsqueda guardada con nombre, como las bibliotecas virtuales de
/// Calibre. «Historia del Mediterráneo» = `etiqueta:historia mediterráneo`. Se llena solo con
/// los libros que cumplen, en la Mac y en el iPhone; no mueve ningún archivo.
public struct SavedShelf: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    /// Lo que se escribe en el buscador, con sus filtros (`autor:`, `serie:`, `estado:`…).
    public var query: String

    public init(id: UUID = UUID(), name: String, query: String) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.query = query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func contains(_ book: Book) -> Bool {
        let parsed = LibraryQuery(query)
        return !parsed.isEmpty && parsed.matches(book)
    }

    /// Un nombre para proponer al guardar: la búsqueda sin los nombres de los filtros
    /// («etiqueta:historia idioma:en» → «Historia · En»).
    public static func suggestedName(for query: String) -> String {
        LibraryQuery.tokens(query)
            .map { token -> String in
                let value = token.split(separator: ":", maxSplits: 1).last.map(String.init) ?? token
                return value.prefix(1).uppercased() + value.dropFirst()
            }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}
