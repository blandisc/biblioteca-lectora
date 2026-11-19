import Foundation

extension Double {
    /// El avance en el libro, listo para guardarse: entre 0 y 1, o `nil` si no es
    /// un número (NaN o infinito).
    ///
    /// foliate calcula el avance de una sección de dos páginas (la portada, por
    /// ejemplo) como 0 ÷ 0. Ese NaN llegaba al registro y la app se cerraba al
    /// convertirlo en «% leído» (18 nov 2026). Todo avance que llega del lector
    /// pasa por aquí.
    public var readingFraction: Double? {
        guard isFinite else { return nil }
        return Swift.min(1, Swift.max(0, self))
    }
}
