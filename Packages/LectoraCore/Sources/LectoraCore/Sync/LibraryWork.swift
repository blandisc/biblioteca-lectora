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
    /// Cómo quedó una pasada: lo que tocó, lo que había en `source` al recorrerla y cuánto de eso
    /// está en `destination` al terminar (la cuenta sale de la misma lectura: una nota creada justo
    /// después ya no hace fallar el «ni de menos ni de más», auditoría 5).
    public struct Pass: Equatable, Sendable {
        public var touched = 0
        public var expected = 0
        public var present = 0
        /// Lo que quedó en `destination` sin estar en `source` (auditoría 6, B3: «ni de más» no se
        /// comprobaba). En una copia que es toda de esta corrida, siempre 0 si salió bien.
        public var extra = 0
        /// Ni de menos ni de más.
        public var isComplete: Bool { present == expected && extra == 0 }
    }

    /// Los nombres que hay en una carpeta (rutas relativas), contando un marcador de iCloud como
    /// el archivo que representa: `.cover.jpg.icloud` es `cover.jpg`.
    public static func snapshot(of folder: URL) -> Set<String> {
        Set(entries(in: folder, keys: []).keys)
    }

    /// Deja `destination` igual a `source`: copia lo nuevo o cambiado (otro tamaño, o modificado
    /// desde `since`) y quita lo que ya no está en `source`. Úsalo solo con un destino que es una
    /// copia de esta corrida. Los marcadores de iCloud no se copian ni se borran, y cuentan como el
    /// archivo que representan (auditoría 5: un `cover.jpg` de verdad se borraba porque en el
    /// origen solo estaba su marcador). Solo se borra lo que `copied` dice que esta corrida puso
    /// ahí (lo que había en el origen al empezar o lo que copió); a `copied` se suma lo que copia.
    @discardableResult
    public static func sync(from source: URL, to destination: URL, since: Date, copied: inout Set<String>) throws -> Pass {
        let manager = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
        var pass = Pass()
        let sourceEntries = entries(in: source, keys: keys)
        for (relative, entry) in sourceEntries {
            pass.expected += 1
            let to = destination.appendingPathComponent(relative)
            // Un marcador del origen: lo que representa ya cuenta; no se copia el marcador vacío.
            guard let values = entry.values else {
                if isTaken(relative, in: destination) { pass.present += 1 }
                continue
            }
            let from = source.appendingPathComponent(relative)
            if values.isDirectory == true {
                if !manager.fileExists(atPath: to.path) {
                    try manager.createDirectory(at: to, withIntermediateDirectories: true)
                    pass.touched += 1
                }
                copied.insert(relative)
                pass.present += 1
                continue
            }
            let there = try? to.resourceValues(forKeys: Set(keys))
            let changed = there == nil || there?.fileSize != values.fileSize || (values.contentModificationDate ?? .distantPast) >= since
            if changed {
                try manager.createDirectory(at: to.deletingLastPathComponent(), withIntermediateDirectories: true)
                if there != nil { try manager.removeItem(at: to) }
                try manager.copyItem(at: from, to: to)
                pass.touched += 1
            }
            copied.insert(relative)
            pass.present += 1
        }
        // Lo que borraste durante la copia (una nota) tampoco se queda en la nueva; lo que no puso
        // esta corrida (lo que llega de iCloud a la carpeta nueva) no se toca.
        for (relative, entry) in entries(in: destination, keys: keys).sorted(by: { $0.key.count > $1.key.count })
        where sourceEntries[relative] == nil && entry.values != nil && copied.contains(relative) {
            try? manager.removeItem(at: destination.appendingPathComponent(relative))
            copied.remove(relative)
            pass.touched += 1
        }
        // Lo que sobra al terminar (no se pudo quitar o no era de esta corrida).
        pass.extra = entries(in: destination, keys: []).keys.filter { sourceEntries[$0] == nil }.count
        return pass
    }

    /// Lo mismo, con un destino que es entero de esta corrida (todo lo que tiene lo puso ella).
    @discardableResult
    public static func sync(from source: URL, to destination: URL, since: Date) throws -> Pass {
        var copied = snapshot(of: destination).union(snapshot(of: source))
        return try sync(from: source, to: destination, since: since, copied: &copied)
    }

    /// Pasa a `destination` solo los archivos de `written` (rutas que se escribieron en `source`):
    /// lo último antes de cambiar de carpeta, sin recorrer todo (auditoría 5, `WriteJournal`).
    /// Uno que ya no está en `source` se quita de la copia si esta corrida lo puso ahí.
    @discardableResult
    public static func copy(_ written: Set<String>, from source: URL, to destination: URL, copied: inout Set<String>) throws -> Int {
        let manager = FileManager.default
        var touched = 0
        let base = WriteJournal.canonical(source)
        for path in written.sorted() where path.hasPrefix(base + "/") {
            let relative = String(path.dropFirst(base.count + 1))
            guard CloudFile.realName(ofPlaceholder: (relative as NSString).lastPathComponent) == nil else { continue }
            let from = source.appendingPathComponent(relative), to = destination.appendingPathComponent(relative)
            var isFolder: ObjCBool = false
            if manager.fileExists(atPath: from.path, isDirectory: &isFolder) {
                guard !isFolder.boolValue else { continue }
                try manager.createDirectory(at: to.deletingLastPathComponent(), withIntermediateDirectories: true)
                if manager.fileExists(atPath: to.path) { try manager.removeItem(at: to) }
                try manager.copyItem(at: from, to: to)
                copied.insert(relative)
                touched += 1
            } else if copied.contains(relative), manager.fileExists(atPath: to.path) {
                try manager.removeItem(at: to)
                copied.remove(relative)
                touched += 1
            }
        }
        return touched
    }

    /// ¿Está ese nombre en la carpeta, como archivo o como su marcador de iCloud?
    private static func isTaken(_ relative: String, in folder: URL) -> Bool {
        CloudFile.isTaken(folder.appendingPathComponent(relative))
    }

    /// Lo de la carpeta por ruta relativa. Un marcador de iCloud entra con el nombre de lo que
    /// representa y sin valores (`values == nil`).
    private struct Entry {
        /// nil: es un marcador de iCloud.
        let values: URLResourceValues?
    }

    private static func entries(in folder: URL, keys: [URLResourceKey]) -> [String: Entry] {
        var result: [String: Entry] = [:]
        let base = folder.standardizedFileURL.resolvingSymlinksInPath().path
        guard let walker = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: keys) else { return result }
        for case let url as URL in walker {
            let path = url.standardizedFileURL.resolvingSymlinksInPath().path
            guard path.hasPrefix(base + "/") else { continue }
            let relative = String(path.dropFirst(base.count + 1))
            if let real = CloudFile.realName(ofPlaceholder: url.lastPathComponent) {
                let name = ((relative as NSString).deletingLastPathComponent as NSString).appendingPathComponent(real)
                if result[name] == nil { result[name] = Entry(values: nil) }
                continue
            }
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { continue }
            result[relative] = Entry(values: values)
        }
        return result
    }
}

/// Mover el Gabinete copia a carpetas de trabajo hermanas y solo al final las pone en su lugar
/// (auditoría 6, M1). Antes se copiaba directo a `Biblioteca` y `Notas`: si iCloud bajaba ahí las
/// de otro aparato a media copia, se contaban como de esta corrida y, si algo fallaba, se borraban.
/// Las carpetas de trabajo son solo de esta corrida (nadie más conoce su nombre): todo lo que hay
/// dentro es suyo y quitarlas nunca toca lo de otro.
public struct StagedMove: Sendable {
    public let destination: URL
    public let folders: [String]
    public let token: String

    public init(destination: URL, folders: [String], token: String = UUID().uuidString) {
        self.destination = destination
        self.folders = folders
        self.token = token
    }

    public enum Failure: Error, Equatable {
        /// Mientras copiaba llegó a la carpeta otra con ese nombre (p. ej. de otro aparato): no se pisa.
        case occupied(String)
    }

    /// La carpeta de trabajo de `folder` (`.gabinete-copia-<token>-Biblioteca`), escondida.
    public func staging(_ folder: String) -> URL {
        destination.appendingPathComponent(".gabinete-copia-\(token)-\(folder)", isDirectory: true)
    }

    /// Dónde va, mientras se copia, una ruta relativa al Gabinete («Biblioteca/.lectora»).
    public func staged(_ relative: String) -> URL {
        let parts = relative.split(separator: "/", maxSplits: 1).map(String.init)
        let top = staging(parts[0])
        return parts.count > 1 ? top.appendingPathComponent(parts[1]) : top
    }

    /// Pone cada carpeta de trabajo en su lugar, sin pisar nada, y devuelve las que puso. Si una ya
    /// está ocupada, las que ya puso regresan a su carpeta de trabajo y falla: el destino queda
    /// como estaba.
    @discardableResult
    public func place() throws -> [String] {
        let manager = FileManager.default
        var placed: [String] = []
        for folder in folders where manager.fileExists(atPath: staging(folder).path) {
            let target = destination.appendingPathComponent(folder, isDirectory: true)
            do {
                guard !CloudFile.isTaken(target) else { throw Failure.occupied(folder) }
                // `moveItem` no reemplaza: si llegó justo ahora, también falla.
                try Self.coordinatedMove(from: staging(folder), to: target)
                placed.append(folder)
            } catch {
                takeBack(placed)
                if CloudFile.isTaken(target) { throw Failure.occupied(folder) }
                throw error
            }
        }
        return placed
    }

    /// Regresa a su carpeta de trabajo lo que `place` puso (solo eso: lo demás no es de esta corrida).
    /// Si no puede regresarla, la quita (auditoría 7, M6): es de esta corrida, y dejarla haría que
    /// el destino pareciera un Gabinete a medias. Lo tuyo sigue en el origen.
    public func takeBack(_ placed: [String]) {
        for folder in placed.reversed() {
            let target = destination.appendingPathComponent(folder, isDirectory: true)
            do {
                try Self.coordinatedMove(from: target, to: staging(folder))
            } catch {
                try? FileManager.default.removeItem(at: target)
            }
        }
    }

    /// Quita las carpetas de trabajo (solo esas: lo demás del destino no es de esta corrida).
    public func discard() {
        for folder in folders { try? FileManager.default.removeItem(at: staging(folder)) }
    }

    /// Mueve una carpeta avisándole a iCloud y al proveedor de archivos (auditoría 7, B1): así
    /// la ven moverse en vez de ver una que se borra y otra que aparece.
    static func coordinatedMove(from source: URL, to target: URL) throws {
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var moveError: Error?
        coordinator.coordinate(writingItemAt: source, options: .forMoving,
                               writingItemAt: target, options: .forReplacing, error: &coordinationError) { from, to in
            do {
                try FileManager.default.moveItem(at: from, to: to)
                coordinator.item(at: from, didMoveTo: to)
            } catch {
                moveError = error
            }
        }
        if let error = coordinationError ?? moveError { throw error }
    }

    /// El principio del nombre de toda carpeta de trabajo.
    public static let prefix = ".gabinete-copia-"
    /// Lo que espero antes de quitar la carpeta de trabajo de una corrida que no es de este
    /// aparato: otro aparato podría estar copiando ahora mismo al mismo lugar de iCloud.
    public static let othersAge: TimeInterval = 24 * 60 * 60

    /// El token de una carpeta de trabajo de una de esas carpetas, o nil si el nombre no es
    /// exactamente `.gabinete-copia-<token>-<carpeta>` (con un token de verdad).
    public static func token(ofLeftover name: String, folders: [String]) -> String? {
        guard name.hasPrefix(prefix) else { return nil }
        let rest = name.dropFirst(prefix.count)
        let token = String(rest.prefix(36))
        guard UUID(uuidString: token) != nil else { return nil }
        let folder = rest.dropFirst(36)
        guard folder.hasPrefix("-"), folders.contains(String(folder.dropFirst())) else { return nil }
        return token
    }

    /// Quita las carpetas de trabajo que dejó un movimiento que no terminó (la app se cerró a
    /// media copia, auditoría 7, M2): solo las de nombre exacto de trabajo; nada más del destino.
    /// Las de `mine` (corridas de este aparato, que ya no corren) se van ya; las de otro aparato,
    /// cuando llevan `othersAge` sin tocarse. Devuelve los nombres que quitó.
    @discardableResult
    public static func removeLeftovers(in destination: URL, folders: [String], mine: Set<String>,
                                       now: Date = Date()) -> [String] {
        let manager = FileManager.default
        let names = (try? manager.contentsOfDirectory(atPath: destination.path)) ?? []
        var removed: [String] = []
        for name in names.sorted() {
            guard let token = token(ofLeftover: name, folders: folders) else { continue }
            let url = destination.appendingPathComponent(name, isDirectory: true)
            if !mine.contains(token) {
                let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
                let touched = [values?.creationDate, values?.contentModificationDate].compactMap { $0 }.max() ?? now
                guard now.timeIntervalSince(touched) >= othersAge else { continue }
            }
            if (try? manager.removeItem(at: url)) != nil { removed.append(name) }
        }
        return removed
    }
}

/// Lo que la app escribe en el Gabinete mientras se mueve (auditoría 5): el registro, las
/// sesiones, las notas y los archivos de `.lectora`. Así la última pasada antes de cambiar de
/// carpeta copia solo eso, en el hilo de la interfaz y sin recorrer todo; el recorrido grande va
/// en segundo plano. Fuera de un movimiento no guarda nada.
public final class WriteJournal: @unchecked Sendable {
    public static let shared = WriteJournal()

    private let lock = NSLock()
    private var depth = 0
    private var paths = Set<String>()

    public init() {}

    /// Empieza a anotar (un movimiento a la vez; se pueden anidar).
    public func begin() {
        lock.lock(); defer { lock.unlock() }
        depth += 1
    }

    /// Anota un archivo escrito, movido o borrado.
    public func note(_ url: URL) {
        lock.lock(); defer { lock.unlock() }
        guard depth > 0 else { return }
        paths.insert(Self.canonical(url))
    }

    /// Lo anotado hasta ahora, y lo olvida (sigue anotando).
    public func drain() -> Set<String> {
        lock.lock(); defer { lock.unlock() }
        let out = paths
        paths = []
        return out
    }

    /// Deja de anotar y devuelve lo que faltaba.
    @discardableResult
    public func end() -> Set<String> {
        lock.lock(); defer { lock.unlock() }
        depth = max(0, depth - 1)
        let out = paths
        if depth == 0 { paths = [] }
        return out
    }

    /// La ruta real, también de un archivo que ya no existe (se resuelve su carpeta): en la Mac
    /// `/var/…` y `/private/var/…` son la misma.
    public static func canonical(_ url: URL) -> String {
        let standard = url.standardizedFileURL
        let parent = standard.deletingLastPathComponent().resolvingSymlinksInPath().path
        return (parent as NSString).appendingPathComponent(standard.lastPathComponent)
    }
}
