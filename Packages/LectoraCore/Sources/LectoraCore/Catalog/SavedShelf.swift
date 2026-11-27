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
    /// El idioma con su nombre: «idioma:en» → «Inglés», no «En».
    public static func suggestedName(for query: String) -> String {
        parts(of: query).map { part in part.field == .language ? part.value : capitalized(part.value) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    /// Lo que reúne un estante dicho en palabras, para quien no escribió la búsqueda
    /// («autor:asimov serie:fundación» → «de Asimov · serie Fundación»). En el estante se leía
    /// «AUTOR:ASIMOV SERIE:FUNDACIÓN» y se partía a media palabra con la letra grande.
    public static func describe(_ query: String) -> String {
        parts(of: query).map { part in
            let value = capitalized(part.value)
            switch part.field {
            case .author: return "de \(value)"
            case .series: return "serie \(value)"
            case .tag: return "etiqueta \(value)"
            case .language: return "en \(part.value.lowercased())"
            case .publisher: return "editorial \(value)"
            case .status: return value
            case .isbn: return "ISBN \(part.value)"
            case .title: return "título «\(part.value)»"
            case nil: return "con «\(part.value)»"
            }
        }
        .joined(separator: " · ")
    }

    /// Los filtros de la búsqueda con su valor tal como se escribió; las palabras que siguen a un
    /// filtro son de ese filtro, como en `LibraryQuery`.
    static func parts(of query: String) -> [(field: LibraryQuery.Field?, value: String)] {
        var parts: [(field: LibraryQuery.Field?, value: String)] = []
        for token in LibraryQuery.tokens(query) {
            if let colon = token.firstIndex(of: ":"), colon != token.startIndex,
               let field = LibraryQuery.names[LibraryQuery.fold(String(token[..<colon]))] {
                let value = String(token[token.index(after: colon)...])
                guard !value.isEmpty else { continue }
                parts.append((field, field == .language ? BookFields.languageName(value) : value))
            } else if let last = parts.last {
                parts[parts.count - 1].value = "\(last.value) \(token)"
            } else {
                parts.append((nil, token))
            }
        }
        return parts
    }

    private static func capitalized(_ value: String) -> String {
        value.prefix(1).uppercased() + value.dropFirst()
    }
}
