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

    /// Los archivos de la carpeta (y sus subcarpetas) que siguen en iCloud sin bajar, con su
    /// nombre real. Copiar la carpeta así copiaría marcadores vacíos, no los libros.
    public static func waiting(in folder: URL) -> [URL] {
        let walker = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil)
        var result: [URL] = []
        while let url = walker?.nextObject() as? URL {
            if let name = realName(ofPlaceholder: url.lastPathComponent) {
                result.append(url.deletingLastPathComponent().appendingPathComponent(name))
            }
        }
        return result
    }

    /// Cuántos archivos y carpetas hay de verdad (sin contar los marcadores de iCloud): para
    /// comprobar que una copia quedó completa.
    public static func countItems(in folder: URL) -> Int {
        let walker = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil)
        var count = 0
        while let url = walker?.nextObject() as? URL {
            if realName(ofPlaceholder: url.lastPathComponent) == nil { count += 1 }
        }
        return count
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

    /// El archivo está en el dispositivo y se lee, pero no se entiende (dañado o escrito por
    /// otra versión): no es esperar a iCloud, así que no se arregla solo.
    public static func isDamaged<K, V>(_ url: URL, decode: (Data) -> [K: V]?) -> Bool {
        guard let data = try? Data(contentsOf: url) else { return false }
        return decode(data) == nil
    }

    /// Lo que te digo, una vez, si un archivo de `.lectora/` no se puede leer: tus cambios
    /// esperan en el dispositivo y el archivo no se toca.
    public static func damagedNotice(_ fileName: String) -> String {
        let what = [
            "estantes.json": "tus estantes",
            "reglas.json": "tus reglas de autores y etiquetas",
            "por-revisar.json": "lo que tienes en «Por revisar»",
            "completados.json": "lo que completé solo",
            "no-duplicados.json": "los libros que marcaste como distintos",
            "por-buscar.json": "los libros que me faltan por buscar",
            "rechazados.json": "los datos de internet que deshiciste",
        ][fileName] ?? "un archivo de tu Gabinete"
        return "No puedo leer \(what) en la carpeta de tu Gabinete (.lectora/\(fileName)) y no lo toqué. "
            + "Lo que cambies lo guardo en este dispositivo; si lo abres en otro aparato, revisa que el archivo esté completo."
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
