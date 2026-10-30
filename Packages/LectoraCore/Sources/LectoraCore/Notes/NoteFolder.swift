import Foundation

/// La carpeta `Gabinete/Notas/`: un archivo `.md` por nota. El nombre del
/// archivo sale del título; si cambias el título, el archivo se renombra.
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
    @discardableResult
    public func save(text: String, fileName: String? = nil) throws -> Note {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let wanted = Self.fileName(forTitle: Note.title(of: text) ?? "")
        var name: String
        if let fileName {
            name = fileName
            if wanted != fileName, !FileManager.default.fileExists(atPath: file(for: wanted).path) {
                try FileManager.default.moveItem(at: file(for: fileName), to: file(for: wanted))
                name = wanted
            }
        } else {
            name = freeName(wanted)
        }
        let destination = file(for: name)
        try Data(text.utf8).write(to: destination, options: .atomic)
        return Note(fileName: name, text: text, modifiedAt: Date())
    }

    public func delete(fileName: String) throws {
        try FileManager.default.removeItem(at: file(for: fileName))
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
        while FileManager.default.fileExists(atPath: file(for: name).path) {
            name = "\(base) \(number)"
            number += 1
        }
        return name
    }
}
