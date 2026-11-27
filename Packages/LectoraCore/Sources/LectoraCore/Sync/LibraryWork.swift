import Foundation

/// Un trabajo que ocupa a toda la biblioteca: mientras corre, los demás de esta lista esperan
/// o no empiezan (auditoría 4). Antes «Ordenar» podía correr junto a importar, juntar, mover el
/// Gabinete o traer de Calibre, y cada uno trabajaba sobre una copia vieja del otro.
public enum LibraryWork: String, Sendable, CaseIterable {
    case tidying, moving, migrating, importing

    /// Por qué no puedo hacer otra cosa ahora, en primera persona.
    public var reason: String {
        switch self {
        case .tidying: "Estoy ordenando tu biblioteca. Espera a que termine."
        case .moving: "Estoy moviendo tu Gabinete. Espera a que termine."
        case .migrating: "Estoy trayendo tu biblioteca de Calibre. Espera a que termine."
        case .importing: "Estoy añadiendo libros a tu biblioteca. Espera a que termine."
        }
    }
}

/// Un solo candado para toda la biblioteca: un trabajo a la vez.
public struct WorkLock: Sendable {
    public private(set) var current: LibraryWork?

    public init() {}

    public var isBusy: Bool { current != nil }

    /// Toma el candado si está libre. Devuelve false si otro trabajo lo tiene.
    public mutating func begin(_ work: LibraryWork) -> Bool {
        guard current == nil else { return false }
        current = work
        return true
    }

    /// Suelta el candado, solo si lo tiene ese trabajo.
    public mutating func end(_ work: LibraryWork) {
        if current == work { current = nil }
    }
}

/// Cuántos trabajos piden armar los libros al final (auditoría 4, M4): el primero que termina
/// no los vuelve a armar a medias mientras otro sigue.
public struct DeferCount: Sendable {
    public private(set) var count = 0

    public init() {}

    public var isActive: Bool { count > 0 }

    public mutating func begin() { count += 1 }

    /// Devuelve true cuando termina el último: es cuando se arman los libros.
    @discardableResult
    public mutating func end() -> Bool {
        count = max(0, count - 1)
        return count == 0
    }
}

/// Lo que cambió en una carpeta mientras se copiaba (auditoría 4, M5): al mover el Gabinete, lo
/// que guardaste durante la copia (la página, una sesión, una nota) se pasa a la copia antes de
/// borrar la vieja.
public enum FolderCatchUp {
    /// Deja `destination` igual a `source`: copia lo nuevo o cambiado (otro tamaño, o modificado
    /// desde `since`) y quita lo que ya no está en `source`. Úsalo solo con un destino que es una
    /// copia de esta corrida. Los marcadores de iCloud no se copian. Devuelve cuántos archivos tocó.
    @discardableResult
    public static func sync(from source: URL, to destination: URL, since: Date) throws -> Int {
        let manager = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
        var touched = 0
        let sourceFiles = files(in: source, keys: keys)
        for (relative, values) in sourceFiles {
            let from = source.appendingPathComponent(relative), to = destination.appendingPathComponent(relative)
            if values.isDirectory == true {
                if !manager.fileExists(atPath: to.path) {
                    try manager.createDirectory(at: to, withIntermediateDirectories: true)
                    touched += 1
                }
                continue
            }
            if CloudFile.realName(ofPlaceholder: from.lastPathComponent) != nil { continue }
            let there = try? to.resourceValues(forKeys: Set(keys))
            let changed = there == nil || there?.fileSize != values.fileSize || (values.contentModificationDate ?? .distantPast) >= since
            guard changed else { continue }
            try manager.createDirectory(at: to.deletingLastPathComponent(), withIntermediateDirectories: true)
            if there != nil { try manager.removeItem(at: to) }
            try manager.copyItem(at: from, to: to)
            touched += 1
        }
        // Lo que borraste durante la copia (una nota) tampoco se queda en la nueva.
        for (relative, _) in files(in: destination, keys: keys).sorted(by: { $0.key.count > $1.key.count })
        where sourceFiles[relative] == nil {
            try? manager.removeItem(at: destination.appendingPathComponent(relative))
            touched += 1
        }
        return touched
    }

    private static func files(in folder: URL, keys: [URLResourceKey]) -> [String: URLResourceValues] {
        var result: [String: URLResourceValues] = [:]
        let base = folder.standardizedFileURL.resolvingSymlinksInPath().path
        guard let walker = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: keys) else { return result }
        for case let url as URL in walker {
            let path = url.standardizedFileURL.resolvingSymlinksInPath().path
            guard path.hasPrefix(base + "/"), let values = try? url.resourceValues(forKeys: Set(keys)) else { continue }
            result[String(path.dropFirst(base.count + 1))] = values
        }
        return result
    }
}
