import Foundation

/// Deshacer lo que se completó solo desde internet sin que vuelva a aplicarse solo (auditoría 1).
///
/// `MetadataMatcher.fillMissing` también deja en el libro el registro de donde salió
/// (`openlibrary:`, `google:`). Si al deshacer se quedara, la siguiente búsqueda lo reconoce como
/// «el mismo registro» (0.98) y lo vuelve a poner en silencio. Por eso: el registro se quita y se
/// recuerda como rechazado; si vuelve a salir, va a «Por revisar» en vez de aplicarse solo.
public enum AutoFill {
    /// Un identificador que cambió al completar: `old` es nil si el libro no lo tenía.
    public struct IdentifierChange: Codable, Hashable, Sendable {
        public var scheme: String
        public var old: String?
        public var new: String?

        public init(scheme: String, old: String?, new: String?) {
            self.scheme = scheme
            self.old = old
            self.new = new
        }
    }

    /// Los identificadores que cambiaron de `before` a `after`, salvo los de `excluding` (el ISBN
    /// se lleva como un dato más, con su propio «deshacer»).
    public static func identifierChanges(from before: Book, to after: Book,
                                         excluding: Set<String> = ["isbn"]) -> [IdentifierChange] {
        Set(before.identifiers.keys).union(after.identifiers.keys)
            .subtracting(excluding)
            .sorted()
            .compactMap { scheme in
                let old = before.identifiers[scheme], new = after.identifiers[scheme]
                return old == new ? nil : IdentifierChange(scheme: scheme, old: old, new: new)
            }
    }

    /// Los devuelve a como estaban. Si después cambiaste uno a mano, el tuyo se respeta.
    public static func undo(_ changes: [IdentifierChange], in book: inout Book) {
        for change in changes where book.identifiers[change.scheme] == change.new {
            book.identifiers[change.scheme] = change.old
        }
    }

    /// El registro de un candidato como texto («openlibrary:OL46125W»), para recordarlo.
    public static func recordKeys(_ candidate: MetadataCandidate) -> Set<String> {
        Set(candidate.identifiers.map { "\($0.key):\($0.value)" })
    }

    /// ¿Se puede aplicar solo? No, si es un registro que ya deshiciste en este libro.
    public static func allowsAutoApply(_ candidate: MetadataCandidate, declined: Set<String>) -> Bool {
        recordKeys(candidate).isDisjoint(with: declined)
    }
}
