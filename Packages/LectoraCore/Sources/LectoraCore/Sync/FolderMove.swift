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

    /// Lleva la carpeta de un libro (`Autor/Título (id)`) a `destination` (otro título, otro
    /// autor o solo otras mayúsculas). Se mueve solo la carpeta del libro, nunca la del autor
    /// entera: los demás libros de ese autor siguen donde el catálogo dice (auditoría 1). Nunca
    /// deja dos carpetas hermanas que solo cambian en mayúsculas, en ningún disco (auditoría 2):
    /// iCloud no las distingue y en la Mac una se renombraría sola. Devuelve dónde quedó:
    /// - Si ya hay una carpeta de autor con ese nombre sin contar mayúsculas, el libro entra a
    ///   ella con el nombre que tiene en el disco.
    /// - Si esa carpeta es la suya y el libro es lo único que tiene, la carpeta del autor cambia
    ///   de nombre (por un nombre temporal) y queda con las mayúsculas nuevas.
    /// - Si no hay ninguna, se crea con el nombre pedido.
    public static func moveBookFolder(_ from: URL, to destination: URL) throws -> URL {
        let manager = FileManager.default
        let oldAuthor = from.deletingLastPathComponent()
        let parent = destination.deletingLastPathComponent().deletingLastPathComponent()
        let wanted = destination.deletingLastPathComponent().lastPathComponent
        let bookName = destination.lastPathComponent
        // La carpeta de autor del libro, con el nombre que tiene en el disco.
        let ownName = oldAuthor.deletingLastPathComponent().standardizedFileURL.path == parent.standardizedFileURL.path
            ? existingName(of: oldAuthor) : nil

        guard let twin = existingSpelling(of: wanted, in: parent, preferring: ownName) else {
            // Ninguna carpeta de autor se llama así: se crea con el nombre pedido.
            let target = parent.appendingPathComponent(wanted).appendingPathComponent(bookName)
            guard !CloudFile.isTaken(target) else { throw MoveError.occupied }
            let author = target.deletingLastPathComponent()
            try manager.createDirectory(at: author, withIntermediateDirectories: true)
            do {
                try manager.moveItem(at: from, to: target)
            } catch {
                removeIfEmpty(author)
                throw error
            }
            removeIfEmpty(oldAuthor)
            return target
        }
        let author = parent.appendingPathComponent(twin)
        guard twin == ownName else {
            // Otra carpeta del mismo autor: el libro entra a ella, con su nombre del disco.
            let target = author.appendingPathComponent(bookName)
            guard !CloudFile.isTaken(target) else { throw MoveError.occupied }
            try manager.moveItem(at: from, to: target)
            removeIfEmpty(oldAuthor)
            return target
        }
        let inPlace = author.appendingPathComponent(bookName)
        let others = ((try? manager.contentsOfDirectory(atPath: author.path)) ?? [])
            .filter { $0 != from.lastPathComponent && $0 != ".DS_Store" }
        guard twin != wanted, others.isEmpty else {
            // Su propia carpeta: se queda en ella (los demás libros del autor no se mueven).
            try move(from, to: inPlace)
            return inPlace
        }
        // Es lo único que tiene: la carpeta del autor toma las mayúsculas nuevas.
        let renamed = parent.appendingPathComponent(wanted)
        try move(author, to: renamed)
        do {
            try move(renamed.appendingPathComponent(from.lastPathComponent), to: renamed.appendingPathComponent(bookName))
        } catch {
            try? move(renamed, to: author)
            throw error
        }
        return renamed.appendingPathComponent(bookName)
    }

    /// El nombre de una carpeta hija de `parent` que se llama `name` sin contar mayúsculas, tal
    /// como está en el disco (nil si no hay). Si hay varias (un disco que distingue mayúsculas
    /// con gemelas viejas), gana la que se llama exactamente así, luego `preferring`.
    public static func existingSpelling(of name: String, in parent: URL, preferring: String? = nil,
                                        foldersOnly: Bool = true) -> String? {
        let manager = FileManager.default
        let matches = ((try? manager.contentsOfDirectory(atPath: parent.path)) ?? []).filter { entry in
            var isFolder: ObjCBool = false
            return entry.compare(name, options: [.caseInsensitive]) == .orderedSame
                && manager.fileExists(atPath: parent.appendingPathComponent(entry).path, isDirectory: &isFolder)
                && (isFolder.boolValue || !foldersOnly)
        }.sorted()
        if matches.contains(name) { return name }
        if let preferring, matches.contains(preferring) { return preferring }
        return matches.first
    }

    /// La ruta `Autor/Título (id)[/archivo]` dentro de `root` con el nombre que cada parte ya tiene en
    /// el disco (sin contar mayúsculas). Así el catálogo guarda la ruta real, también en la Mac,
    /// donde `createDirectory` usaría sin avisar la carpeta que ya existe (auditoría 2).
    public static func diskSpelling(of relative: String, in root: URL) -> String {
        var folder = root
        var parts: [String] = []
        for part in relative.split(separator: "/").map(String.init) {
            let real = existingSpelling(of: part, in: folder, foldersOnly: false) ?? part
            parts.append(real)
            folder.appendPathComponent(real)
        }
        return parts.joined(separator: "/")
    }

    /// Crea `relative` dentro de `root` sin hacer una gemela que solo cambie en mayúsculas.
    /// Devuelve la ruta que quedó en el disco: esa es la que se guarda en el catálogo.
    @discardableResult
    public static func createFolder(_ relative: String, in root: URL) throws -> String {
        let real = diskSpelling(of: relative, in: root)
        try FileManager.default.createDirectory(at: root.appendingPathComponent(real, isDirectory: true),
                                                withIntermediateDirectories: true)
        return real
    }

    /// El nombre con que está en el disco (en la Mac, la ruta puede venir con otras mayúsculas).
    private static func existingName(of folder: URL) -> String? {
        existingSpelling(of: folder.lastPathComponent, in: folder.deletingLastPathComponent(), preferring: folder.lastPathComponent)
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
