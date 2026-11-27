import Foundation

/// Lo que guardé mientras iCloud bajaba un archivo del Gabinete (auditoría 2): reglas,
/// estantes, «Por revisar», sesiones, la posición de lectura… Vive en el dispositivo
/// (`Application Support/pendientes/<gabinete>/<archivo>.json`), nunca dentro de la carpeta,
/// así que sobrevive a cerrar la app y nunca se escribe en el diario de otro Gabinete.
public struct PendingWrites: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// Lo pendiente de un Gabinete: cada uno tiene su propia carpeta.
    public static func forCabinet(_ cabinet: URL, base: URL = defaultBase) -> PendingWrites {
        PendingWrites(directory: base.appendingPathComponent(cabinetID(cabinet), isDirectory: true))
    }

    /// `Application Support/pendientes`.
    public static var defaultBase: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("pendientes", isDirectory: true)
    }

    /// Un nombre estable para la carpeta de un Gabinete (FNV-1a de su ruta, sin mayúsculas).
    public static func cabinetID(_ cabinet: URL) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in cabinet.standardizedFileURL.path.lowercased().utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return String(hash, radix: 16)
    }

    private func url(_ name: String) -> URL {
        directory.appendingPathComponent(name.hasSuffix(".json") ? name : name + ".json")
    }

    /// Los archivos que tienen algo pendiente (con su nombre en la carpeta, p. ej. «reglas.json»).
    public var names: [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []).filter { $0.hasSuffix(".json") }.sorted()
    }

    public var isEmpty: Bool { names.isEmpty }

    public func has(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: url(name).path)
    }

    public func value<T: Decodable>(_ name: String, as type: T.Type = T.self) -> T? {
        (try? Data(contentsOf: url(name))).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }

    /// Guarda lo pendiente (nil lo quita). Devuelve si quedó guardado.
    @discardableResult
    public func set<T: Encodable>(_ value: T?, _ name: String) -> Bool {
        guard let value else {
            try? FileManager.default.removeItem(at: url(name))
            return true
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(value).write(to: url(name), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    /// Una clave que cambió aquí y su valor (nil: la quitaste).
    struct Entry<K: Codable, V: Codable>: Codable {
        var key: K
        var value: V?
    }

    /// Las claves que esperan y sus valores.
    public func table<K: Codable & Hashable, V: Codable>(_ name: String, as type: [K: V].Type = [K: V].self)
        -> (keys: Set<K>, values: [K: V]) {
        let entries = value(name, as: [Entry<K, V>].self) ?? []
        var values: [K: V] = [:]
        for entry in entries { values[entry.key] = entry.value }
        return (Set(entries.map(\.key)), values)
    }

    public func setTable<K: Codable & Hashable, V: Codable>(_ name: String, keys: Set<K>, values: [K: V]) {
        set(keys.isEmpty ? nil : keys.map { Entry(key: $0, value: values[$0]) }, name)
    }
}

extension SideFile {
    /// Como `persist`, pero lo que no se pudo escribir se guarda en el dispositivo (`pending`) y
    /// se junta en el siguiente intento, aunque la app se haya cerrado entre tanto (auditoría 2).
    /// Devuelve la tabla que vale ahora y si quedó escrita en la carpeta.
    public static func persist<K: Codable & Hashable, V: Codable>(
        _ mine: [K: V], keys: some Sequence<K>, at url: URL, pending: PendingWrites,
        decode: (Data) -> [K: V]?, encode: ([K: V]) -> Data?
    ) -> (table: [K: V], written: Bool) {
        let name = url.lastPathComponent
        let changed = Set(keys)
        let waiting = pending.table(name, as: [K: V].self)
        // Lo que esperaba gana sobre la memoria (tras cerrar la app, la memoria no lo tiene),
        // salvo lo que acabas de cambiar.
        var current = mine
        for key in waiting.keys where !changed.contains(key) { current[key] = waiting.values[key] }
        let all = changed.union(waiting.keys)
        switch persist(current, keys: all, at: url, decode: decode, encode: encode) {
        case .written(let merged):
            pending.set(String?.none, name)
            return (merged, true)
        case .postponed:
            pending.setTable(name, keys: all, values: current)
            return (current, false)
        }
    }
}
