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

    /// Sin el ancho guardado de esas columnas (`ids`); lo demás (otros anchos, lo escondido, el
    /// orden) se queda. SwiftUI guarda el ancho de cada columna en cuanto arma la tabla, no solo
    /// cuando la cambias tú: las que piden más o menos según el ancho de la tabla se quedaban con
    /// el de la tabla angosta (auditoría 7: a 1400, «Agregado» en 70 y cortada).
    public static func withoutWidths(of ids: Set<String>, in saved: Data) -> Data {
        guard var object = try? JSONSerialization.jsonObject(with: saved) as? [String: Any],
              var states = object["perColumnState"] as? [Any] else { return saved }
        for index in stride(from: 0, to: states.count - 1, by: 2) {
            guard let key = states[index] as? [String: Any],
                  let id = ((key["base"] as? [String: Any])?["explicit"] as? [String: Any])?["_0"] as? String,
                  ids.contains(id), var state = states[index + 1] as? [String: Any] else { continue }
            state["currentWidth"] = nil
            states[index + 1] = state
        }
        object["perColumnState"] = states
        return (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? saved
    }

    /// Lo que suman los anchos que guardaste a mano (`currentWidth`) de las columnas a la vista.
    /// SwiftUI guarda `perColumnState` como [columna, estado, columna, estado…]. Si no se puede
    /// leer, 0: nada que no quepa.
    public static func storedWidth(of saved: Data) -> Double {
        guard let object = try? JSONSerialization.jsonObject(with: saved) as? [String: Any],
              let states = object["perColumnState"] as? [Any] else { return 0 }
        return states.enumerated().filter { $0.offset % 2 == 1 }.reduce(0) { total, entry in
            guard let state = entry.element as? [String: Any], let width = state["currentWidth"] as? Double else { return total }
            let hidden = (state["visibility"] as? [String: Any])?["hidden"] != nil
            return hidden ? total : total + width
        }
    }

    /// Los anchos guardados ya no caben en `available` (auditoría 7): solo entonces se quitan. Antes
    /// se quitaban en cuanto la tabla se hacía un poco más angosta, aunque cupieran.
    public static func overflows(_ saved: Data, in available: Double) -> Bool {
        storedWidth(of: saved) > available
    }
}
