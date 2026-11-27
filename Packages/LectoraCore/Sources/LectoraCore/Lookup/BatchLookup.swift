import Foundation

/// Buscar datos para muchos libros a la vez (CB-4): cuáles hacen falta, cuánto esperar entre
/// búsquedas para no saturar Open Library, y la cuenta de cómo va.
public enum BatchLookup {
    /// Entre un libro y el siguiente: Open Library pide no pasar de unas cuantas por segundo.
    public static let pause: Duration = .seconds(1)
    /// Tantos libros seguidos sin respuesta y se da por hecho que no hay internet.
    public static let unreachableLimit = 3

    /// Le falta algo que internet suele tener: portada, sinopsis, ISBN, editorial o año.
    public static func needsData(_ book: Book, hasCover: Bool) -> Bool {
        !hasCover || (book.summary ?? "").isEmpty || book.identifiers["isbn"] == nil
            || (book.publisher ?? "").isEmpty || (book.published ?? "").isEmpty
    }

    /// Cómo va una búsqueda en lote.
    public struct Progress: Equatable, Sendable {
        public var total: Int
        public var done = 0
        /// Se completaron solos (era claramente el mismo libro).
        public var applied = 0
        /// Quedaron en «Por revisar».
        public var review = 0
        public var notFound = 0
        /// No se pudieron buscar (sin internet): quedan pendientes y se reintentan solos.
        public var pending = 0
        public var stopped = false

        public init(total: Int) { self.total = total }

        public var finished: Bool { stopped || done + pending >= total }

        public mutating func record(_ decision: MetadataService.Decision?) {
            done += 1
            switch decision {
            case .apply: applied += 1
            case .review: review += 1
            case .notFound: notFound += 1
            case .unreachable: done -= 1; pending += 1
            case nil: break
            }
        }

        /// «22 completados · 6 por revisar · 3 sin encontrar».
        public var summary: String {
            let parts = [applied.countedIfAny("completado", "completados"),
                         review.countedIfAny("por revisar", "por revisar"),
                         notFound.countedIfAny("sin encontrar", "sin encontrar"),
                         pending.countedIfAny("pendiente sin internet", "pendientes sin internet")].compactMap { $0 }
            return parts.isEmpty ? "Nada que cambiar" : parts.joined(separator: " · ")
        }
    }
}
