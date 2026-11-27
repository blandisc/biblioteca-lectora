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
    /// el mismo, no hace nada.
    public static func move(_ from: URL, to: URL) throws {
        guard from.standardizedFileURL.path != to.standardizedFileURL.path else { return }
        if sameIgnoringCase(from, to) {
            let temporary = from.deletingLastPathComponent().appendingPathComponent(".gabinete-\(UUID().uuidString)")
            try FileManager.default.moveItem(at: from, to: temporary)
            try FileManager.default.moveItem(at: temporary, to: to)
        } else {
            try FileManager.default.moveItem(at: from, to: to)
        }
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
