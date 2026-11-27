import Foundation

/// Mover carpetas sin perder nada (RB-2 y RB-5): no encima de lo que ya existe, no dentro de
/// sí misma, y aunque solo cambien mayúsculas (APFS e iCloud no las distinguen).
public enum FolderMove {
    public enum Problem: Equatable, Sendable {
        /// El destino está dentro del origen, o al revés: se copiaría sin fin.
        case insideItself
        /// Ya existe esa carpeta en el destino: nunca se pisa.
        case occupied(String)
    }

    /// Qué impide llevar las carpetas `folders` de `source` a `destination`.
    public static func problem(from source: URL, to destination: URL, folders: [String],
                               exists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }) -> Problem? {
        let from = components(source), to = components(destination)
        if to.starts(with: from) || from.starts(with: to) { return .insideItself }
        for folder in folders where exists(destination.appendingPathComponent(folder)) {
            return .occupied(folder)
        }
        return nil
    }

    public static func sameIgnoringCase(_ a: URL, _ b: URL) -> Bool {
        a.standardizedFileURL.path.compare(b.standardizedFileURL.path, options: [.caseInsensitive]) == .orderedSame
    }

    /// Mueve aunque solo cambien mayúsculas: pasa por un nombre temporal. Si es exactamente
    /// el mismo, no hace nada. Si el segundo paso falla (p. ej. ya existe otra carpeta con ese
    /// nombre en un disco que distingue mayúsculas), regresa al nombre de antes: nunca se queda
    /// escondida como `.gabinete-…` (auditoría 1).
    public static func move(_ from: URL, to: URL) throws {
        guard from.standardizedFileURL.path != to.standardizedFileURL.path else { return }
        if sameIgnoringCase(from, to) {
            let temporary = from.deletingLastPathComponent().appendingPathComponent(".gabinete-\(UUID().uuidString)")
            try FileManager.default.moveItem(at: from, to: temporary)
            do {
                try FileManager.default.moveItem(at: temporary, to: to)
            } catch {
                try? FileManager.default.moveItem(at: temporary, to: from)
                throw error
            }
        } else {
            try FileManager.default.moveItem(at: from, to: to)
        }
    }

    /// Lleva la carpeta de un libro (`Autor/Título (id)`) a `destination` cuando el autor solo
    /// cambia en mayúsculas («julio cortázar» → «Julio Cortázar»). Se mueve solo la carpeta del
    /// libro, nunca la del autor entera: los demás libros de ese autor siguen donde el catálogo
    /// dice (auditoría 1). Devuelve dónde quedó:
    /// - En un disco que distingue mayúsculas (el iPhone): en la carpeta de autor nueva (se crea
    ///   si falta) y la vieja se quita si se queda vacía.
    /// - En uno que no (la Mac, iCloud): las dos son la misma carpeta. Si el libro es lo único
    ///   que tiene, la carpeta del autor cambia de nombre; si hay otros, el libro se queda en
    ///   ella con el nombre que tiene en el disco.
    public static func moveBookFolder(_ from: URL, to destination: URL) throws -> URL {
        let manager = FileManager.default
        let oldAuthor = from.deletingLastPathComponent(), newAuthor = destination.deletingLastPathComponent()
        if oldAuthor.standardizedFileURL.path == newAuthor.standardizedFileURL.path {
            try move(from, to: destination)
            return destination
        }
        if sameItem(oldAuthor, newAuthor) {
            let others = ((try? manager.contentsOfDirectory(atPath: oldAuthor.path)) ?? [])
                .filter { $0 != from.lastPathComponent && $0 != ".DS_Store" }
            guard others.isEmpty else {
                let inPlace = oldAuthor.appendingPathComponent(destination.lastPathComponent)
                try move(from, to: inPlace)
                return inPlace
            }
            try move(oldAuthor, to: newAuthor)
            do {
                try move(newAuthor.appendingPathComponent(from.lastPathComponent), to: destination)
            } catch {
                try? move(newAuthor, to: oldAuthor)
                throw error
            }
            return destination
        }
        guard !manager.fileExists(atPath: destination.path) else { throw MoveError.occupied }
        let created = !manager.fileExists(atPath: newAuthor.path)
        try manager.createDirectory(at: newAuthor, withIntermediateDirectories: true)
        do {
            try manager.moveItem(at: from, to: destination)
        } catch {
            if created { try? manager.removeItem(at: newAuthor) }
            throw error
        }
        removeIfEmpty(oldAuthor)
        return destination
    }

    public enum MoveError: Error, Equatable {
        /// Ya hay otra carpeta con ese nombre: no se pisa.
        case occupied
    }

    /// ¿Las dos rutas son la misma carpeta en el disco? (En uno que no distingue mayúsculas,
    /// «julio cortázar» y «Julio Cortázar» lo son.)
    public static func sameItem(_ a: URL, _ b: URL) -> Bool {
        let key: Set<URLResourceKey> = [.fileResourceIdentifierKey]
        guard let left = (try? URL(fileURLWithPath: a.path).resourceValues(forKeys: key))?.fileResourceIdentifier,
              let right = (try? URL(fileURLWithPath: b.path).resourceValues(forKeys: key))?.fileResourceIdentifier
        else { return false }
        return left.isEqual(right)
    }

    /// Quita la carpeta si ya no tiene nada (aparte de `.DS_Store`).
    public static func removeIfEmpty(_ folder: URL) {
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return }
        if contents.allSatisfy({ $0 == ".DS_Store" }) { try? FileManager.default.removeItem(at: folder) }
    }

    /// Junta lo del disco con lo de este dispositivo: solo las claves que cambiaron aquí se
    /// escriben; lo que otro dispositivo guardó en las demás se queda (RB-3).
    public static func merge<K: Hashable, V>(disk: [K: V], mine: [K: V], changed: some Sequence<K>) -> [K: V] {
        var result = disk
        for key in changed { result[key] = mine[key] }
        return result
    }

    private static func components(_ url: URL) -> [String] {
        url.resolvingSymlinksInPath().standardizedFileURL.pathComponents.map { $0.lowercased() }
    }
}
