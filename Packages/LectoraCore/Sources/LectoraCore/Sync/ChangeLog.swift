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

    /// El marcador que deja iCloud cuando desaloja el registro propio: `.<id>.jsonl.icloud`.
    public var ownPlaceholder: URL {
        directory.appendingPathComponent(".\(ownFile.lastPathComponent).icloud")
    }

    /// Agrega cambios al registro propio del dispositivo.
    ///
    /// Si iCloud desalojó el registro propio, pide bajarlo y lanza `ownLogNotDownloaded`:
    /// crear uno nuevo con solo lo reciente lo reemplazaría en todos los dispositivos.
    public func append(_ changes: [Change]) throws {
        guard !changes.isEmpty else { return }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: ownFile.path),
           FileManager.default.fileExists(atPath: ownPlaceholder.path) {
            try? FileManager.default.startDownloadingUbiquitousItem(at: ownFile)
            throw ChangeLogError.ownLogNotDownloaded
        }
        let encoder = Self.makeEncoder()
        var data = Data()
        for change in changes {
            data.append(try encoder.encode(change))
            data.append(0x0A)
        }
        try LineFile.append(data, to: ownFile)
    }

    /// Resultado de leer todos los registros.
    public struct ReadResult: Sendable {
        public var changes: [Change]
        /// Líneas que no se pudieron leer (p. ej. un archivo a medio sincronizar).
        /// Se ignoran; se volverán a leer completas en la siguiente pasada.
        public var skippedLines: Int
        /// Archivos que no se pudieron abrir (p. ej. uno de iCloud sin bajar estando
        /// sin conexión). Los demás sí se leen.
        public var skipped: [URL] = []
    }

    /// Lee los cambios de todos los dispositivos. Solo lanza si no se puede listar la carpeta:
    /// un archivo o una línea dañada se salta y se reporta, sin perder los demás.
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
        var skippedFiles: [URL] = []
        for file in files {
            guard let data = try? Data(contentsOf: file) else {
                skippedFiles.append(file)
                continue
            }
            for line in data.split(separator: 0x0A, omittingEmptySubsequences: true) {
                if let change = try? decoder.decode(Change.self, from: Data(line)) {
                    changes.append(change)
                } else {
                    skipped += 1
                }
            }
        }
        return ReadResult(changes: changes, skippedLines: skipped, skipped: skippedFiles)
    }
}

public enum ChangeLogError: Error, Equatable {
    /// El registro propio está en iCloud pero no en este dispositivo; ya se pidió bajarlo.
    case ownLogNotDownloaded
}

/// Archivos de una línea por registro (`.jsonl`): el registro de cambios y el de sesiones.
public enum LineFile {
    /// Agrega líneas al final. Si la última quedó cortada (la app se cerró a media escritura),
    /// primero termina esa línea: así la rota se pierde sola y la nueva no se pega a ella.
    public static func append(_ data: Data, to file: URL) throws {
        guard FileManager.default.fileExists(atPath: file.path) else {
            try data.write(to: file, options: .atomic)
            return
        }
        let handle = try FileHandle(forUpdating: file)
        defer { try? handle.close() }
        let end = try handle.seekToEnd()
        var payload = data
        if end > 0 {
            try handle.seek(toOffset: end - 1)
            if try handle.read(upToCount: 1) != Data([0x0A]) { payload.insert(0x0A, at: 0) }
            _ = try handle.seekToEnd()
        }
        try handle.write(contentsOf: payload)
    }
}

/// Lo que escribiste mientras el registro se leía en segundo plano (auditoría de medios): la
/// lectura no lo vio, así que se vuelve a aplicar encima de ella. Sin esto, «traer de iCloud»
/// reemplazaba el catálogo con una lectura vieja y lo recién guardado desaparecía hasta la
/// siguiente lectura (una edición, una posición, un marcador).
public struct WritesDuringRead: Sendable {
    private var open: [UUID: [Change]] = [:]

    public init() {}

    /// Empieza una lectura; devuelve con qué pedir luego lo escrito mientras tanto.
    public mutating func begin() -> UUID {
        let token = UUID()
        open[token] = []
        return token
    }

    /// Anota lo que se acaba de escribir en el registro (para cada lectura en curso).
    public mutating func note(_ changes: [Change]) {
        guard !changes.isEmpty else { return }
        for token in open.keys { open[token, default: []].append(contentsOf: changes) }
    }

    /// Termina la lectura: lo escrito desde que empezó, para aplicarlo encima.
    public mutating func end(_ token: UUID) -> [Change] {
        open.removeValue(forKey: token) ?? []
    }
}
