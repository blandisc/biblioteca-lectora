import CryptoKit
import Foundation
import LectoraCore

/// Subrayados y notas en el registro de cambios de este dispositivo (LectoraCore).
/// Hoy vive en Application Support; con la sincronización (S3) la carpeta pasa a
/// iCloud Drive sin cambiar este código.
@MainActor
final class AnnotationStore: ObservableObject {
    static let shared = AnnotationStore()

    /// Cambia con cada subrayado guardado o borrado, para refrescar el Cuaderno.
    @Published private(set) var revision = 0

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

    /// Libros que se juntaron en este, también en otro dispositivo (RB-3): sus subrayados
    /// son de este. Lo pone la biblioteca.
    var mergedIDs: (UUID) -> [UUID] = { _ in [] }

    func annotations(forBook bookID: UUID) -> [Annotation] {
        ([bookID] + mergedIDs(bookID)).flatMap { state.annotations(for: $0) }
    }

    /// Todos los subrayados, del más reciente al más antiguo.
    func allAnnotations() -> [Annotation] {
        state.ids(of: .annotation)
            .compactMap { id in state.fields(of: .annotation, id: id).flatMap { Annotation(id: id, fields: $0) } }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// Avisa de cada cambio (antes, después) a quien lo necesite: los conectores
    /// mandan a Readwise las notas editadas y los borrados.
    var onChange: ((_ before: Annotation?, _ after: Annotation?) -> Void)?

    func annotation(id: UUID) -> Annotation? {
        state.fields(of: .annotation, id: id).flatMap { Annotation(id: id, fields: $0) }
    }

    /// Guarda un subrayado nuevo o actualiza uno existente (mismo `id`).
    func save(_ annotation: Annotation) throws {
        let before = self.annotation(id: annotation.id)
        // Solo lo que cambió: cambiar el color aquí no pisa la nota que se escribió en otro dispositivo (RB-3).
        let previous = Dictionary((before?.changes(clock: clock) ?? []).map { ($0.field, $0.value) }, uniquingKeysWith: { a, _ in a })
        let changes = annotation.changes(clock: clock).filter { previous[$0.field] != $0.value }
        guard !changes.isEmpty else { return }
        try log.append(changes)
        state.apply(changes)
        revision += 1
        onChange?(before, annotation)
    }

    func delete(id: UUID) throws {
        let before = annotation(id: id)
        let change = Annotation.deletion(id: id, clock: clock)
        try log.append([change])
        state.apply(change)
        revision += 1
        onChange?(before, nil)
    }

    nonisolated static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Registro", isDirectory: true)
    }

    /// Identificador estable de este dispositivo para su archivo de registro. Va con la huella
    /// del aparato (`DeviceFingerprint`): un respaldo restaurado en otro iPhone, o la Mac nueva
    /// del Asistente de Migración, toman uno nuevo en vez de escribir en el registro del otro (M7).
    nonisolated static let deviceID: String = {
        let defaults = UserDefaults.standard
        let (idKey, fingerprintKey) = ("registro.deviceID", "registro.deviceFingerprint")
        let stored = DeviceIdentity.Stored(id: defaults.string(forKey: idKey), fingerprint: defaults.string(forKey: fingerprintKey))
        let resolved = DeviceIdentity.resolve(stored, fingerprint: DeviceFingerprint.current())
        if resolved != stored {
            defaults.set(resolved.id, forKey: idKey)
            defaults.set(resolved.fingerprint, forKey: fingerprintKey)
        }
        return resolved.id ?? UUID().uuidString
    }()

    /// ID de libro provisional, derivado del nombre del archivo. Con el catálogo
    /// (S3/S4) cada libro tendrá su propio ID en LectoraCore.
    nonisolated static func bookID(for file: URL) -> UUID {
        let digest = Array(SHA256.hash(data: Data(file.lastPathComponent.utf8)))
        return UUID(uuid: (digest[0], digest[1], digest[2], digest[3], digest[4], digest[5], digest[6], digest[7],
                           digest[8], digest[9], digest[10], digest[11], digest[12], digest[13], digest[14], digest[15]))
    }
}
