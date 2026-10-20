import Foundation

/// Identifica una entidad dentro de la biblioteca.
public struct EntityKey: Hashable, Sendable {
    public var kind: EntityKind
    public var id: UUID

    public init(kind: EntityKind, id: UUID) {
        self.kind = kind
        self.id = id
    }
}

/// Valor vigente de un campo y la marca del cambio que lo fijó.
public struct FieldValue: Hashable, Sendable {
    public var hlc: HLC
    public var value: JSONValue
}

/// Estado combinado de todos los registros de cambios.
///
/// `apply` es conmutativo, asociativo e idempotente: el resultado no depende
/// del orden en que lleguen los cambios ni de si llegan repetidos. Eso es lo
/// que permite sincronizar sin servidor sobre una nube de archivos.
public struct LibraryState: Sendable {
    public private(set) var entities: [EntityKey: [String: FieldValue]] = [:]
    /// Mayor marca HLC vista; sirve para ajustar el reloj local.
    public private(set) var latest: HLC?

    public init() {}

    public mutating func apply(_ change: Change) {
        let key = EntityKey(kind: change.entity, id: change.entityID)
        var fields = entities[key, default: [:]]
        if let current = fields[change.field], current.hlc >= change.hlc {
            return
        }
        fields[change.field] = FieldValue(hlc: change.hlc, value: change.value)
        entities[key] = fields
        if latest.map({ change.hlc > $0 }) ?? true {
            latest = change.hlc
        }
    }

    public mutating func apply<S: Sequence>(_ changes: S) where S.Element == Change {
        for change in changes { apply(change) }
    }

    public func fields(of kind: EntityKind, id: UUID) -> [String: JSONValue]? {
        entities[EntityKey(kind: kind, id: id)]?.mapValues(\.value)
    }

    public func isDeleted(_ kind: EntityKind, id: UUID) -> Bool {
        entities[EntityKey(kind: kind, id: id)]?[Change.deletedField]?.value.boolValue == true
    }

    /// IDs vivos (no borrados) de un tipo de entidad.
    public func ids(of kind: EntityKind) -> [UUID] {
        entities.keys
            .filter { $0.kind == kind && !isDeleted(kind, id: $0.id) }
            .map(\.id)
    }
}
