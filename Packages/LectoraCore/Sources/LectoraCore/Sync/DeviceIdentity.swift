import Foundation

/// El nombre de este dispositivo en los registros (`<id>.jsonl`). Nunca dos dispositivos con
/// el mismo (M7, auditoría de medios): el id se guarda junto a una huella del aparato que no
/// viaja en los respaldos ni con el Asistente de Migración (en la Mac, el número del equipo; en
/// el iPhone, una marca del llavero solo de este dispositivo). Si la huella cambia, este es otro
/// aparato con una copia de los ajustes del anterior: toma un id nuevo. Uno nuevo siempre es
/// seguro: los registros de todos se siguen leyendo.
public enum DeviceIdentity {
    public struct Stored: Equatable, Sendable {
        public var id: String?
        public var fingerprint: String?
        public init(id: String?, fingerprint: String?) {
            self.id = id
            self.fingerprint = fingerprint
        }
    }

    /// Qué id usar y qué guardar. `fingerprint` nil: no se pudo leer la huella (se queda el id).
    public static func resolve(_ stored: Stored, fingerprint: String?, makeID: () -> String = { UUID().uuidString }) -> Stored {
        guard let id = stored.id else { return Stored(id: makeID(), fingerprint: fingerprint) }
        guard let fingerprint else { return stored }
        // Guardado antes de la huella: es este aparato (se anota la huella desde hoy).
        guard let saved = stored.fingerprint else { return Stored(id: id, fingerprint: fingerprint) }
        return saved == fingerprint ? stored : Stored(id: makeID(), fingerprint: fingerprint)
    }

    /// El id que este aparato dejó de usar al resolver (para soltar lo que tenía tomado con él),
    /// o nil si sigue siendo el mismo o no tenía.
    public static func replaced(_ stored: Stored, by resolved: Stored) -> String? {
        guard let old = stored.id, old != resolved.id else { return nil }
        return old
    }
}
