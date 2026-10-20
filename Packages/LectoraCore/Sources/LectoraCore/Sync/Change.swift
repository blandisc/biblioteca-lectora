import Foundation

/// Tipo de entidad de la biblioteca.
public enum EntityKind: String, Codable, Sendable, CaseIterable {
    case book
    case annotation
    case progress
    case shelf
}

/// Un cambio atómico: "el campo `field` de la entidad `entityID` vale `value`".
///
/// Cada dispositivo solo agrega cambios a su propio registro. El estado de la
/// biblioteca es el resultado de combinar todos los registros: por cada campo
/// gana el cambio con la marca HLC mayor (last-writer-wins por campo).
public struct Change: Hashable, Codable, Sendable {
    public var id: UUID
    public var hlc: HLC
    public var entity: EntityKind
    public var entityID: UUID
    public var field: String
    public var value: JSONValue

    public init(id: UUID = UUID(), hlc: HLC, entity: EntityKind, entityID: UUID, field: String, value: JSONValue) {
        self.id = id
        self.hlc = hlc
        self.entity = entity
        self.entityID = entityID
        self.field = field
        self.value = value
    }

    /// Campo reservado para borrados lógicos (tombstones).
    public static let deletedField = "_deleted"
}
