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
    /// Con `index`, lo que cambió en el disco se vuelve a leer la próxima vez (auditoría 3).
    public static func moveBookFolder(_ from: URL, to destination: URL, index: SpellingIndex? = nil) throws -> URL {
        let manager = FileManager.default
        let oldAuthor = from.deletingLastPathComponent()
        let parent = destination.deletingLastPathComponent().deletingLastPathComponent()
        let wanted = destination.deletingLastPathComponent().lastPathComponent
        let bookName = destination.lastPathComponent
        defer {
            for folder in [parent, oldAuthor, destination.deletingLastPathComponent(), from] { index?.forget(folder) }
        }
        // La carpeta de autor del libro, con el nombre que tiene en el disco.
        let ownName = oldAuthor.deletingLastPathComponent().standardizedFileURL.path == parent.standardizedFileURL.path
            ? existingName(of: oldAuthor) : nil

        guard let twin = existingSpelling(of: wanted, in: parent, preferring: ownName, index: index) else {
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
    /// con gemelas viejas), gana la que se llama exactamente así, luego `preferring`. Con
    /// `index`, la carpeta se lee una sola vez en toda la operación (auditoría 3).
    public static func existingSpelling(of name: String, in parent: URL, preferring: String? = nil,
                                        foldersOnly: Bool = true, index: SpellingIndex? = nil) -> String? {
        let index = index ?? SpellingIndex(root: parent)
        let matches = index.matches(name, in: parent, foldersOnly: foldersOnly)
        if matches.contains(name) { return name }
        if let preferring, matches.contains(preferring) { return preferring }
        return matches.first
    }

    /// La ruta `Autor/Título (id)[/archivo]` dentro de `root` con el nombre que cada parte ya tiene en
    /// el disco (sin contar mayúsculas). Así el catálogo guarda la ruta real, también en la Mac,
    /// donde `createDirectory` usaría sin avisar la carpeta que ya existe (auditoría 2). Para muchas
    /// rutas seguidas («Ordenar», abrir la app, traer de Calibre) pasa un mismo `index`: cada
    /// carpeta se lee una vez, no una por libro (auditoría 3).
    public static func diskSpelling(of relative: String, in root: URL, index: SpellingIndex? = nil) -> String {
        let index = index.flatMap { $0.root.standardizedFileURL == root.standardizedFileURL ? $0 : nil }
            ?? SpellingIndex(root: root)
        return index.spelling(of: relative)
    }

    /// Una ruta del catálogo guardada con otras mayúsculas que las del disco (en un disco que las
    /// distingue, como el del iPhone, el libro «no está»): la ruta real, o nil si la guardada
    /// sirve o no hay nada parecido. Solo mira el disco si la guardada no está: es barato al abrir.
    public static func repairedSpelling(of relative: String, in root: URL, index: SpellingIndex? = nil) -> String? {
        guard !CloudFile.isTaken(root.appendingPathComponent(relative)) else { return nil }
        let real = diskSpelling(of: relative, in: root, index: index)
        return real != relative && CloudFile.isTaken(root.appendingPathComponent(real)) ? real : nil
    }

    /// Las rutas de muchos libros a la vez (al abrir la biblioteca), con un solo índice: las que
    /// hay que corregir → la ruta real. Un libro cuyo autor no está en el disco con ninguna
    /// mayúscula se salta sin leer nada más. Sin estado de la app: se puede correr fuera del hilo
    /// de la interfaz (auditoría 3: con 5,000 libros sin bajar tardaba 18 s en el hilo principal).
    public static func repairedSpellings<Key: Hashable>(of paths: [Key: String], in root: URL) -> [Key: String] {
        let index = SpellingIndex(root: root)
        var result: [Key: String] = [:]
        for (key, path) in paths {
            if let real = repairedSpelling(of: path, in: root, index: index) { result[key] = real }
        }
        return result
    }

    /// Junta las carpetas de autor gemelas que dejó una versión anterior en un disco que distingue
    /// mayúsculas («julio cortázar/» y «Julio Cortázar/»; en iCloud chocan). Los libros pasan a la
    /// que tiene más; uno que ya exista allá con el mismo nombre se queda donde está (nunca se
    /// pisa). Devuelve lo que se movió: `Autor/Título (id)` de antes → el de ahora.
    @discardableResult
    public static func mergeTwinFolders(in root: URL) -> [String: String] {
        let manager = FileManager.default
        let entries = ((try? manager.contentsOfDirectory(atPath: root.path)) ?? []).filter { name in
            var isFolder: ObjCBool = false
            return !name.hasPrefix(".") && manager.fileExists(atPath: root.appendingPathComponent(name).path, isDirectory: &isFolder)
                && isFolder.boolValue
        }
        var moved: [String: String] = [:]
        for twins in Dictionary(grouping: entries, by: { $0.lowercased() }).values where twins.count > 1 {
            let children = { (name: String) in
                ((try? manager.contentsOfDirectory(atPath: root.appendingPathComponent(name).path)) ?? []).filter { $0 != ".DS_Store" }
            }
            // La que tiene más libros se queda; si empatan, la primera en orden.
            guard let keep = twins.sorted().max(by: { children($0).count < children($1).count }) else { continue }
            for twin in twins where twin != keep {
                for child in children(twin) {
                    let from = root.appendingPathComponent(twin).appendingPathComponent(child)
                    let to = root.appendingPathComponent(keep).appendingPathComponent(child)
                    guard !CloudFile.isTaken(to), (try? manager.moveItem(at: from, to: to)) != nil else { continue }
                    moved["\(twin)/\(child)"] = "\(keep)/\(child)"
                }
                removeIfEmpty(root.appendingPathComponent(twin))
            }
        }
        return moved
    }

    /// Crea `relative` dentro de `root` sin hacer una gemela que solo cambie en mayúsculas.
    /// Devuelve la ruta que quedó en el disco: esa es la que se guarda en el catálogo.
    @discardableResult
    public static func createFolder(_ relative: String, in root: URL, index: SpellingIndex? = nil) throws -> String {
        let real = diskSpelling(of: relative, in: root, index: index)
        try FileManager.default.createDirectory(at: root.appendingPathComponent(real, isDirectory: true),
                                                withIntermediateDirectories: true)
        index?.forget(path: real)
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

/// Los nombres que hay en el disco, carpeta por carpeta, leídos una sola vez por operación
/// (auditoría 3). Antes cada ruta volvía a listar la carpeta de la biblioteca (todos los
/// autores) y la de su autor: «Ordenar» con 5,000 libros y 1,500 autores congelaba la app ~20 s.
/// Úsalo para una sola operación en un solo hilo; lo que se mueva con `FolderMove` (pasándole
/// el índice) se olvida y se vuelve a leer.
public final class SpellingIndex {
    public let root: URL
    /// Carpeta (ruta exacta) → nombre en minúsculas → los nombres del disco que se llaman así.
    private var folders: [String: [String: [String]]] = [:]
    /// La misma carpeta sin contar mayúsculas → sus rutas exactas leídas (para olvidar rápido).
    private var spellings: [String: Set<String>] = [:]
    /// Ruta real de `root` (en la Mac, `/private/var/…`), para el camino rápido.
    private lazy var realRoot: String? = Self.realPath(root.path)
    /// Cuántas carpetas se han leído (para las pruebas: una vez cada una, no una por libro).
    public private(set) var listings = 0

    public init(root: URL) {
        self.root = root
    }

    /// Los nombres hijos de `folder` que se llaman `name` sin contar mayúsculas.
    public func matches(_ name: String, in folder: URL, foldersOnly: Bool = false) -> [String] {
        let key = folder.standardizedFileURL.path
        let table: [String: [String]]
        if let cached = folders[key] {
            table = cached
        } else {
            listings += 1
            let names = (try? FileManager.default.contentsOfDirectory(atPath: key)) ?? []
            table = Dictionary(grouping: names, by: { $0.lowercased() }).mapValues { $0.sorted() }
            folders[key] = table
            spellings[key.lowercased(), default: []].insert(key)
        }
        let found = table[name.lowercased()] ?? []
        guard foldersOnly else { return found }
        return found.filter { entry in
            var isFolder: ObjCBool = false
            return FileManager.default.fileExists(atPath: folder.appendingPathComponent(entry).path, isDirectory: &isFolder)
                && isFolder.boolValue
        }
    }

    /// `diskSpelling` con este índice. Camino rápido: si la ruta existe con esas mismas letras
    /// (la ruta real del disco lo confirma), no se lista nada. Si una parte no está con ninguna
    /// mayúscula, lo de abajo tampoco: se deja como se pidió sin leer más carpetas.
    public func spelling(of relative: String) -> String {
        if let realRoot, let real = Self.realPath(root.appendingPathComponent(relative).path),
           real == realRoot + "/" + relative {
            return relative
        }
        var folder = root
        var parts: [String] = []
        var missing = false
        for part in relative.split(separator: "/").map(String.init) {
            let found = missing ? [] : matches(part, in: folder)
            let real = found.contains(part) ? part : found.first ?? part
            missing = missing || found.isEmpty
            parts.append(real)
            folder.appendPathComponent(real)
        }
        return parts.joined(separator: "/")
    }

    /// Olvida lo leído de esa carpeta (con cualquier mayúscula): cambió en el disco.
    public func forget(_ folder: URL) {
        for key in spellings.removeValue(forKey: folder.standardizedFileURL.path.lowercased()) ?? [] {
            folders[key] = nil
        }
    }

    /// Olvida `root` y cada carpeta de la ruta `relative`.
    public func forget(path relative: String) {
        var folder = root
        forget(folder)
        for part in relative.split(separator: "/") {
            folder.appendPathComponent(String(part))
            forget(folder)
        }
    }

    public func forgetAll() {
        folders = [:]
        spellings = [:]
    }

    private static func realPath(_ path: String) -> String? {
        guard let resolved = realpath(path, nil) else { return nil }
        defer { free(resolved) }
        return String(cString: resolved)
    }
}
