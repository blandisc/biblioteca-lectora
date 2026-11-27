import Foundation

/// Las columnas guardadas de una tabla de la Mac (`TableColumnCustomization`, que se guarda como
/// JSON). Al quitar los anchos que ya no caben, el orden en que pusiste las columnas se queda
/// (auditoría 7, M1): antes se perdía junto con los anchos.
public enum ColumnLayout {
    /// La clave del orden de las columnas en lo que guarda SwiftUI.
    static let orderKey = "columnOrder"

    /// `fresh` (las columnas sin anchos) con el orden de columnas de `old`. Si algo no se puede
    /// leer, `fresh` tal cual: nunca una tabla rota.
    public static func keepingOrder(of old: Data, in fresh: Data) -> Data {
        guard let saved = try? JSONSerialization.jsonObject(with: old) as? [String: Any],
              let order = saved[orderKey],
              var clean = try? JSONSerialization.jsonObject(with: fresh) as? [String: Any] else { return fresh }
        clean[orderKey] = order
        return (try? JSONSerialization.data(withJSONObject: clean, options: [.sortedKeys])) ?? fresh
    }
}
