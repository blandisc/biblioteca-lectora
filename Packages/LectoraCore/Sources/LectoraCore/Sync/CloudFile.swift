import Foundation

/// Archivos que iCloud todavía no baja (auditoría 1, 27 nov 2026). Cuando iCloud desaloja un
/// archivo deja en su lugar un marcador `.nombre.icloud`: para `fileExists` el archivo «no
/// está», pero sí existe y tiene datos en la nube. Lo que no se ha bajado nunca se pisa ni
/// se borra: se pide bajarlo y se espera.
public enum CloudFile {
    /// El marcador de iCloud de un archivo: `.<nombre>.icloud` en su misma carpeta.
    public static func placeholder(for file: URL) -> URL {
        file.deletingLastPathComponent().appendingPathComponent(".\(file.lastPathComponent).icloud")
    }

    /// El archivo está en iCloud pero no en este dispositivo.
    public static func isPlaceholder(_ file: URL) -> Bool {
        !FileManager.default.fileExists(atPath: file.path)
            && FileManager.default.fileExists(atPath: placeholder(for: file).path)
    }

    /// Hay algo con ese nombre: el archivo o su marcador de iCloud. Para elegir un nombre libre.
    public static func isTaken(_ file: URL) -> Bool {
        FileManager.default.fileExists(atPath: file.path) || FileManager.default.fileExists(atPath: placeholder(for: file).path)
    }

    /// El nombre real de un marcador (`.Rayuela.pdf.icloud` → `Rayuela.pdf`), o nil si no lo es.
    public static func realName(ofPlaceholder name: String) -> String? {
        guard name.hasPrefix("."), name.hasSuffix(".icloud"), name.count > ".icloud".count + 1 else { return nil }
        return String(name.dropFirst().dropLast(".icloud".count))
    }

    /// Pide a iCloud que lo baje (sin esperar). Fuera de iCloud no hace nada.
    public static func requestDownload(_ file: URL) {
        try? FileManager.default.startDownloadingUbiquitousItem(at: file)
    }
}

/// Los archivos JSON de `.lectora/` (reglas, estantes, por revisar…): se escriben solo las
/// claves que cambiaron, encima de lo que hay en el disco (RB-3), y nunca encima de un archivo
/// que iCloud no ha bajado o que no se pudo leer (auditoría 1): ese cambio espera.
public enum SideFile {
    public enum Outcome<K: Hashable, V> {
        /// Se escribió: lo del disco junto con lo de este dispositivo.
        case written([K: V])
        /// No se escribió: el archivo está en iCloud sin bajar (ya se pidió) o no se pudo leer.
        /// El cambio queda pendiente en la app y se reintenta en el siguiente guardado.
        case postponed
    }

    /// Junta lo del disco con `mine` en las claves `keys` y lo escribe.
    public static func persist<K: Hashable, V>(_ mine: [K: V], keys: some Sequence<K>, at url: URL,
                                               decode: (Data) -> [K: V]?, encode: ([K: V]) -> Data?) -> Outcome<K, V> {
        let disk: [K: V]
        if FileManager.default.fileExists(atPath: url.path) {
            guard let data = try? Data(contentsOf: url), let decoded = decode(data) else { return .postponed }
            disk = decoded
        } else if FileManager.default.fileExists(atPath: CloudFile.placeholder(for: url).path) {
            CloudFile.requestDownload(url)
            return .postponed
        } else {
            disk = [:]
        }
        let merged = FolderMove.merge(disk: disk, mine: mine, changed: keys)
        guard let data = encode(merged) else { return .postponed }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } catch {
            return .postponed
        }
        return .written(merged)
    }
}
