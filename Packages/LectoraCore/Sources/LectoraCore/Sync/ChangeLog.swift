import Foundation

/// Registro de cambios en una carpeta (p. ej. `Biblioteca Lectora/.lectora/registro/`).
///
/// Cada dispositivo escribe solo `<deviceID>.jsonl` (un cambio por línea) y lee
/// los archivos de todos. Como nunca hay dos escritores sobre el mismo archivo,
/// la nube (iCloud Drive, Google Drive…) no puede generar conflictos de edición.
///
/// La coordinación con iCloud (`NSFileCoordinator`) vive en la capa de la app;
/// este tipo solo hace E/S de archivos para poder probarse en cualquier plataforma.
public struct ChangeLog: Sendable {
    public let directory: URL
    public let deviceID: String

    public init(directory: URL, deviceID: String) {
        self.directory = directory
        self.deviceID = deviceID
    }

    public var ownFile: URL {
        directory.appendingPathComponent("\(deviceID).jsonl")
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    /// Agrega cambios al registro propio del dispositivo.
    public func append(_ changes: [Change]) throws {
        guard !changes.isEmpty else { return }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = Self.makeEncoder()
        var data = Data()
        for change in changes {
            data.append(try encoder.encode(change))
            data.append(0x0A)
        }
        if FileManager.default.fileExists(atPath: ownFile.path) {
            let handle = try FileHandle(forWritingTo: ownFile)
            defer { try? handle.close() }
            _ = try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } else {
            try data.write(to: ownFile, options: .atomic)
        }
    }

    /// Resultado de leer todos los registros.
    public struct ReadResult: Sendable {
        public var changes: [Change]
        /// Líneas que no se pudieron leer (p. ej. un archivo a medio sincronizar).
        /// Se ignoran; se volverán a leer completas en la siguiente pasada.
        public var skippedLines: Int
    }

    /// Lee los cambios de todos los dispositivos.
    public func readAll() throws -> ReadResult {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return ReadResult(changes: [], skippedLines: 0)
        }
        let files = try FileManager.default
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "jsonl" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        let decoder = JSONDecoder()
        var changes: [Change] = []
        var skipped = 0
        for file in files {
            let data = try Data(contentsOf: file)
            for line in data.split(separator: 0x0A, omittingEmptySubsequences: true) {
                if let change = try? decoder.decode(Change.self, from: Data(line)) {
                    changes.append(change)
                } else {
                    skipped += 1
                }
            }
        }
        return ReadResult(changes: changes, skippedLines: skipped)
    }
}
