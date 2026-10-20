import CryptoKit
import Foundation
import LectoraCore

/// Subrayados y notas en el registro de cambios de este dispositivo (LectoraCore).
/// Hoy vive en Application Support; con la sincronización (S3) la carpeta pasa a
/// iCloud Drive sin cambiar este código.
@MainActor
final class AnnotationStore {
    static let shared = AnnotationStore()

    private let log: ChangeLog
    private let clock: HybridLogicalClock
    private var state = LibraryState()

    init(directory: URL = AnnotationStore.defaultDirectory) {
        let device = Self.deviceID
        log = ChangeLog(directory: directory, deviceID: device)
        clock = HybridLogicalClock(node: device)
        if let result = try? log.readAll() {
            state.apply(result.changes)
            if let latest = state.latest { clock.receive(latest) }
        }
    }

    func annotations(forBook bookID: UUID) -> [Annotation] {
        state.annotations(for: bookID)
    }

    /// Guarda un subrayado nuevo o actualiza uno existente (mismo `id`).
    func save(_ annotation: Annotation) throws {
        let changes = annotation.changes(clock: clock)
        try log.append(changes)
        state.apply(changes)
    }

    func delete(id: UUID) throws {
        let change = Annotation.deletion(id: id, clock: clock)
        try log.append([change])
        state.apply(change)
    }

    static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Registro", isDirectory: true)
    }

    /// Identificador estable de este dispositivo para su archivo de registro.
    static var deviceID: String {
        let key = "registro.deviceID"
        if let id = UserDefaults.standard.string(forKey: key) { return id }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: key)
        return id
    }

    /// ID de libro provisional, derivado del nombre del archivo. Con el catálogo
    /// (S3/S4) cada libro tendrá su propio ID en LectoraCore.
    static func bookID(for file: URL) -> UUID {
        let digest = Array(SHA256.hash(data: Data(file.lastPathComponent.utf8)))
        return UUID(uuid: (digest[0], digest[1], digest[2], digest[3], digest[4], digest[5], digest[6], digest[7],
                           digest[8], digest[9], digest[10], digest[11], digest[12], digest[13], digest[14], digest[15]))
    }
}
