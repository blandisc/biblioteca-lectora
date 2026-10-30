import Foundation
import LectoraCore

/// Las notas del Gabinete (`Gabinete/Notas/*.md`). Lee la carpeta al arrancar,
/// al volver a la app y al cambiar de Gabinete; escribe cada nota al guardarla.
@MainActor
final class NotesStore: ObservableObject {
    static let shared = NotesStore()

    @Published private(set) var notes: [Note] = []
    private(set) var folder: NoteFolder

    init(folder: URL? = nil) {
        self.folder = NoteFolder(url: folder ?? CabinetLocation.notes(in: LibraryStore.shared.cabinet))
        reload()
    }

    /// Cambió la carpeta del Gabinete (Ajustes › Gabinete).
    func use(cabinet: URL) {
        let url = CabinetLocation.notes(in: cabinet)
        guard url != folder.url else { return }
        folder = NoteFolder(url: url)
        reload()
    }

    func reload() {
        notes = folder.all()
    }

    /// Al volver a la app: pide a iCloud las notas que falten y vuelve a leer.
    func refreshFromCloud() {
        let url = folder.url
        Task.detached(priority: .utility) { [weak self] in
            CloudFiles.requestSmallFiles(in: url)
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await self?.reload(ifStillAt: url)
        }
    }

    private func reload(ifStillAt url: URL) {
        guard folder.url == url else { return }
        reload()
    }

    func note(fileName: String) -> Note? {
        notes.first { $0.fileName == fileName }
    }

    /// Notas que enlazan un libro con `[[Título]]`.
    func notes(linking bookTitle: String) -> [Note] {
        notes.filter { $0.links(bookTitle: bookTitle) }
    }

    /// Guarda una nota (nueva si `fileName` es nil). Una nota vacía (o solo «#») no se guarda;
    /// si ya existía, se borra. Devuelve la nota guardada.
    @discardableResult
    func save(text: String, fileName: String?) throws -> Note? {
        if text.trimmingCharacters(in: CharacterSet(charactersIn: "#").union(.whitespacesAndNewlines)).isEmpty {
            if let fileName { try delete(fileName: fileName) }
            return nil
        }
        let note = try folder.save(text: text, fileName: fileName)
        reload()
        return note
    }

    func delete(fileName: String) throws {
        try folder.delete(fileName: fileName)
        reload()
    }

    /// Añade la cita de un subrayado al final de una nota (o crea una nueva con ese título).
    @discardableResult
    func add(_ annotation: Annotation, bookTitle: String, to fileName: String?, newTitle: String? = nil) throws -> Note? {
        let quote = NoteMarkdown.quote(annotation.quote, bookTitle: bookTitle, annotationID: annotation.id)
        var text = fileName.flatMap { note(fileName: $0)?.text } ?? "# \(newTitle ?? bookTitle)\n"
        text = NoteMarkdown.appending(quote, to: text)
        if let note = annotation.note, !note.isEmpty { text += "\n" + note + "\n" }
        return try save(text: text, fileName: fileName)
    }
}
