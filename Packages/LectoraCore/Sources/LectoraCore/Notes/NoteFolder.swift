import Foundation

/// La carpeta `Gabinete/Notas/`: un archivo `.md` por nota. El nombre del
/// archivo sale del título; si cambias el título, el archivo se renombra (y solo entonces).
public struct NoteFolder: Sendable {
    public let url: URL
    public static let fileExtension = "md"

    public init(url: URL) {
        self.url = url
    }

    /// Todas las notas, la más reciente primero. Solo `.md` de primer nivel;
    /// lo demás que haya en la carpeta (de Obsidian, por ejemplo) se respeta.
    public func all() -> [Note] {
        let manager = FileManager.default
        let files = (try? manager.contentsOfDirectory(
            at: url, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])) ?? []
        return files
            .filter { $0.pathExtension.lowercased() == Self.fileExtension }
            .compactMap(read)
            .sorted { $0.modifiedAt > $1.modifiedAt }
    }

    public func read(_ file: URL) -> Note? {
        guard let data = try? Data(contentsOf: file) else { return nil }
        let text = String(decoding: data, as: UTF8.self)
        let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        return Note(fileName: file.deletingPathExtension().lastPathComponent, text: text, modifiedAt: modified ?? .distantPast)
    }

    public func file(for fileName: String) -> URL {
        url.appendingPathComponent(fileName).appendingPathExtension(Self.fileExtension)
    }

    /// Guarda el texto. Si la nota ya existía (`fileName`) y su título cambió,
    /// se renombra el archivo cuando el nombre nuevo está libre. Devuelve la nota guardada.
    ///
    /// Una nota que iCloud no ha bajado nunca se pisa (auditoría 1): guardar sobre ella lanza
    /// `notDownloaded` y pide bajarla, y una nota nueva no toma el nombre de una que está en la nube.
    @discardableResult
    public func save(text: String, fileName: String? = nil) throws -> Note {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let wanted = Self.fileName(forTitle: Note.title(of: text) ?? "")
        var name: String
        if let fileName {
            if CloudFile.isPlaceholder(file(for: fileName)) {
                CloudFile.requestDownload(file(for: fileName))
                throw NoteFolderError.notDownloaded
            }
            name = fileName
            if wanted != fileName, titleChanged(in: fileName, to: wanted),
               let target = renameTarget(from: fileName, to: wanted) {
                do {
                    try FileManager.default.moveItem(at: file(for: fileName), to: file(for: target))
                    WriteJournal.shared.note(file(for: fileName))
                    name = target
                } catch {
                    // Si no se pudo renombrar, lo que escribiste no se pierde (auditoría de medios):
                    // se queda con su nombre; si su archivo ya no está, va con el nombre nuevo.
                    if !FileManager.default.fileExists(atPath: file(for: fileName).path) { name = freeName(wanted) }
                }
            }
        } else {
            name = freeName(wanted)
        }
        let destination = file(for: name)
        try Data(text.utf8).write(to: destination, options: .atomic)
        WriteJournal.shared.note(destination)
        return Note(fileName: name, text: text, modifiedAt: Date())
    }

    /// ¿Cambiaste el título? Gabinete nunca cambia el nombre de tus notas por su cuenta (auditoría 7):
    /// el archivo se renombra solo si el título que tenía en la carpeta da otro nombre. Una nota con
    /// un nombre distinto de su título (hecha en Obsidian, o «Ideas 2») se queda con el suyo; si no
    /// puedo leer lo que había, cuenta como cambiado (lo de antes).
    private func titleChanged(in fileName: String, to wanted: String) -> Bool {
        guard let data = try? Data(contentsOf: file(for: fileName)) else { return true }
        return Self.fileName(forTitle: Note.title(of: String(decoding: data, as: UTF8.self)) ?? "") != wanted
    }

    /// El nombre nuevo cuando tú cambias el título: el del título o, si ya hay otra nota con ese
    /// nombre, el siguiente libre («Ideas 2», auditoría 8, M4). Antes se quedaba con el nombre viejo
    /// y ya nunca se renombraba. Si solo cambian mayúsculas, nil: en el disco es el mismo archivo.
    private func renameTarget(from fileName: String, to wanted: String) -> String? {
        if wanted.lowercased() == fileName.lowercased() { return nil }
        guard CloudFile.isTaken(file(for: wanted)) else { return wanted }
        return freeName(wanted)
    }

    /// Notas de muestra que se escriben una sola vez: la que ya existe con ese título se
    /// queda como está. Sembrar dos veces no duplica nada (antes «El silencio en Rulfo 2»).
    /// Devuelve las que escribió.
    @discardableResult
    public func seed(_ texts: [String]) throws -> [Note] {
        // Las que están en iCloud sin bajar también cuentan (por su nombre de archivo).
        let waiting = ((try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? [])
            .compactMap(CloudFile.realName(ofPlaceholder:))
            .filter { ($0 as NSString).pathExtension.lowercased() == Self.fileExtension }
            .map { NoteMarkdown.key(($0 as NSString).deletingPathExtension) }
        let titles = Set(all().map { NoteMarkdown.key($0.title) } + waiting)
        return try texts
            .filter { !titles.contains(NoteMarkdown.key(Note.title(of: $0) ?? "")) }
            .map { try save(text: $0) }
    }

    public func delete(fileName: String) throws {
        try FileManager.default.removeItem(at: file(for: fileName))
        WriteJournal.shared.note(file(for: fileName))
    }

    /// Nombre de archivo válido en iCloud, Windows y Calibre: sin `/ \ : * ? " < > |`.
    public static func fileName(forTitle title: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:*?\"<>|").union(.newlines).union(.controlCharacters)
        let cleaned = title.unicodeScalars.map { forbidden.contains($0) ? " " : String($0) }.joined()
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        let short = String(cleaned.prefix(100))
        return short.isEmpty ? "Sin título" : short
    }

    /// «Ideas», «Ideas 2», «Ideas 3»…
    private func freeName(_ base: String) -> String {
        var name = base
        var number = 2
        while CloudFile.isTaken(file(for: name)) {
            name = "\(base) \(number)"
            number += 1
        }
        return name
    }
}

public enum NoteFolderError: Error, Equatable {
    /// La nota está en iCloud pero no en este dispositivo; ya se pidió bajarla.
    case notDownloaded
}
