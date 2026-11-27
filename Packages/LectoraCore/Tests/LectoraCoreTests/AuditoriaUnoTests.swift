import Foundation
@testable import LectoraCore
import XCTest

/// Auditoría 1 (27 nov 2026): fallas críticas y altas verificadas. Cada prueba falla si vuelve.
final class AuditoriaUnoTests: XCTestCase {
    private func tempDir(in base: URL = FileManager.default.temporaryDirectory) throws -> URL {
        let url = base.appendingPathComponent("auditoria-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    /// Deja el marcador de iCloud de `file` (como cuando iCloud lo desaloja).
    private func evict(_ file: URL) throws {
        try Data().write(to: CloudFile.placeholder(for: file))
    }

    private func names(in folder: URL) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).sorted()
    }

    // MARK: 1 · Juntar duplicados no tira lo que iCloud no ha bajado

    func testPlaceholderCountsAsPresent() throws {
        let dir = try tempDir()
        let book = dir.appendingPathComponent("Rayuela - Julio Cortázar.pdf")
        XCTAssertFalse(CloudFile.isPlaceholder(book))
        try evict(book)
        XCTAssertTrue(CloudFile.isPlaceholder(book), "Un «.x.icloud» es un archivo en la nube, no uno que falta")
        XCTAssertTrue(CloudFile.isTaken(book))
        XCTAssertEqual(CloudFile.realName(ofPlaceholder: ".Rayuela - Julio Cortázar.pdf.icloud"), "Rayuela - Julio Cortázar.pdf")
        XCTAssertNil(CloudFile.realName(ofPlaceholder: "cover.jpg"))
    }

    func testFolderWithUnmovedFilesIsNotDiscarded() {
        XCTAssertTrue(DuplicateFinder.canDiscardFolder(containing: ["cover.jpg", "metadata.opf", ".DS_Store"]))
        XCTAssertTrue(DuplicateFinder.canDiscardFolder(containing: [".cover.jpg.icloud", "metadata.opf"]))
        XCTAssertTrue(DuplicateFinder.canDiscardFolder(containing: []))
        XCTAssertFalse(DuplicateFinder.canDiscardFolder(containing: ["cover.jpg", ".Rayuela.pdf.icloud"]),
                       "Un formato que sigue en iCloud no se tira con la carpeta")
        XCTAssertFalse(DuplicateFinder.canDiscardFolder(containing: ["Rayuela.mobi", "metadata.opf"]))
    }

    // MARK: 2 · Los archivos de .lectora/ no se pisan sin bajar ni rotos

    private func decode(_ data: Data) -> [String: Int]? { try? JSONDecoder().decode([String: Int].self, from: data) }
    private func encode(_ table: [String: Int]) -> Data? { try? JSONEncoder().encode(table) }

    func testSideFileWaitsForICloud() throws {
        let file = try tempDir().appendingPathComponent("estantes.json")
        try evict(file)
        let outcome = SideFile.persist(["nuevo": 1], keys: ["nuevo"], at: file, decode: decode, encode: encode)
        guard case .postponed = outcome else { return XCTFail("Se escribió encima de un archivo sin bajar") }
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path), "No se crea uno nuevo con solo lo de hoy")
    }

    func testSideFileNeverOverwritesWhatItCannotRead() throws {
        let file = try tempDir().appendingPathComponent("reglas.json")
        let broken = Data("{a medio sincronizar".utf8)
        try broken.write(to: file)
        let outcome = SideFile.persist(["nuevo": 1], keys: ["nuevo"], at: file, decode: decode, encode: encode)
        guard case .postponed = outcome else { return XCTFail("Se pisó un archivo que no se pudo leer") }
        XCTAssertEqual(try Data(contentsOf: file), broken)
    }

    func testSideFileKeepsWhatOthersSaved() throws {
        let file = try tempDir().appendingPathComponent("por-revisar.json")
        guard case .written(let first) = SideFile.persist(["a": 1], keys: ["a"], at: file, decode: decode, encode: encode)
        else { return XCTFail("Sin archivo, se crea") }
        XCTAssertEqual(first, ["a": 1])
        try XCTUnwrap(encode(["a": 1, "b": 2])).write(to: file)
        guard case .written(let merged) = SideFile.persist(["a": 5], keys: ["a"], at: file, decode: decode, encode: encode)
        else { return XCTFail("Debió escribir") }
        XCTAssertEqual(merged, ["a": 5, "b": 2])
        XCTAssertEqual(decode(try Data(contentsOf: file)), ["a": 5, "b": 2])
    }

    // MARK: 3 · El diario no se reemplaza si iCloud lo desalojó

    func testEvictedSessionLogIsNotReplaced() throws {
        let dir = try tempDir()
        let log = SessionLog(directory: dir, device: "iphone")
        try evict(log.ownFile)
        XCTAssertEqual(log.ownPlaceholder.lastPathComponent, ".iphone.jsonl.icloud")
        let session = ReadingSession(id: UUID(), bookID: UUID(), device: "iphone", start: Date(), end: Date().addingTimeInterval(600),
                                     words: 900, readingSeconds: 600, fromFraction: 0.1, toFraction: 0.2,
                                     segments: [], longestStreak: 600)
        XCTAssertThrowsError(try log.append(session)) {
            XCTAssertEqual($0 as? ChangeLogError, .ownLogNotDownloaded)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: log.ownFile.path), "No se crea un diario nuevo y corto")
    }

    // MARK: Regla: tampoco las notas

    func testNotesNeverWriteOverAnEvictedNote() throws {
        let folder = NoteFolder(url: try tempDir())
        try evict(folder.file(for: "Ideas"))
        let fresh = try folder.save(text: "# Ideas\notra")
        XCTAssertEqual(fresh.fileName, "Ideas 2", "Una nota nueva no toma el nombre de una que está en la nube")
        XCTAssertThrowsError(try folder.save(text: "# Ideas\nencima", fileName: "Ideas")) {
            XCTAssertEqual($0 as? NoteFolderError, .notDownloaded)
        }
        XCTAssertEqual(try folder.seed(["# Ideas\nmuestra"]).count, 0, "La muestra no se escribe encima")
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.file(for: "Ideas").path))
    }

    // MARK: 4 · Cambiar solo mayúsculas del autor

    /// «Autor/Título (id)/archivo», como la biblioteca.
    private func makeBook(_ root: URL, author: String, title: String) throws -> URL {
        let folder = root.appendingPathComponent(author).appendingPathComponent(title)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data(title.utf8).write(to: folder.appendingPathComponent("libro.epub"))
        return folder
    }

    private func isCaseSensitive(_ dir: URL) throws -> Bool {
        try Data().write(to: dir.appendingPathComponent("prueba"))
        defer { try? FileManager.default.removeItem(at: dir.appendingPathComponent("prueba")) }
        return !FileManager.default.fileExists(atPath: dir.appendingPathComponent("PRUEBA").path)
    }

    /// Comprueba el cambio de mayúsculas en `base`: dos libros del mismo autor, uno tras otro.
    private func checkCaseOnlyRename(in base: URL) throws {
        let root = try tempDir(in: base)
        let rayuela = try makeBook(root, author: "julio cortázar", title: "Rayuela (1)")
        let cuentos = try makeBook(root, author: "julio cortázar", title: "Bestiario (2)")
        let newAuthor = root.appendingPathComponent("Julio Cortázar")

        let first = try FolderMove.moveBookFolder(rayuela, to: newAuthor.appendingPathComponent("Rayuela (1)"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: first.appendingPathComponent("libro.epub").path))
        // El otro libro sigue donde el catálogo dice (antes se movía la carpeta entera del autor).
        XCTAssertTrue(FileManager.default.fileExists(atPath: cuentos.appendingPathComponent("libro.epub").path),
                      "El segundo libro no puede quedar con su ruta vieja rota")
        let second = try FolderMove.moveBookFolder(cuentos, to: newAuthor.appendingPathComponent("Bestiario (2)"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: second.appendingPathComponent("libro.epub").path))
        XCTAssertFalse(names(in: root).contains { $0.hasPrefix(".gabinete-") }, "Nada se queda escondido")
        // En cualquier disco, los dos se quedan en la carpeta que ya existe, con su nombre del
        // disco: nunca dos carpetas que solo cambian en mayúsculas (auditoría 2).
        XCTAssertEqual(names(in: root), ["julio cortázar"])
        XCTAssertEqual(names(in: root.appendingPathComponent("julio cortázar")), ["Bestiario (2)", "Rayuela (1)"])
        XCTAssertEqual(first.deletingLastPathComponent().lastPathComponent, "julio cortázar")
        XCTAssertEqual(second.deletingLastPathComponent().lastPathComponent, "julio cortázar")

        // Un solo libro del autor: en cualquier disco, la carpeta queda con las mayúsculas nuevas.
        let solo = try makeBook(root, author: "jorge luis borges", title: "Ficciones (3)")
        let placed = try FolderMove.moveBookFolder(solo, to: root.appendingPathComponent("Jorge Luis Borges/Ficciones (3)"))
        XCTAssertEqual(placed.deletingLastPathComponent().lastPathComponent, "Jorge Luis Borges")
        XCTAssertTrue(names(in: root).contains("Jorge Luis Borges"))
        XCTAssertFalse(names(in: root).contains("jorge luis borges"))
    }

    func testCaseOnlyAuthorRenameMovesOnlyTheBook() throws {
        try checkCaseOnlyRename(in: FileManager.default.temporaryDirectory)
    }

    /// En un disco que distingue mayúsculas (como el iPhone). Se corre con
    /// `LECTORA_CASE_SENSITIVE_DIR=/Volumes/…` (un disco «APFS sensible a mayúsculas»).
    func testCaseOnlyAuthorRenameOnCaseSensitiveDisk() throws {
        guard let path = ProcessInfo.processInfo.environment["LECTORA_CASE_SENSITIVE_DIR"] else {
            throw XCTSkip("Sin disco sensible a mayúsculas (LECTORA_CASE_SENSITIVE_DIR)")
        }
        let base = URL(fileURLWithPath: path)
        XCTAssertTrue(try isCaseSensitive(try tempDir(in: base)))
        try checkCaseOnlyRename(in: base)

        // Ya existen «julio cortázar/» y «Julio Cortázar/»: el libro entra a la que existe.
        let root = try tempDir(in: base)
        let old = try makeBook(root, author: "julio cortázar", title: "Rayuela (1)")
        _ = try makeBook(root, author: "Julio Cortázar", title: "Bestiario (2)")
        let placed = try FolderMove.moveBookFolder(old, to: root.appendingPathComponent("Julio Cortázar/Rayuela (1)"))
        XCTAssertEqual(names(in: root), ["Julio Cortázar"])
        XCTAssertEqual(names(in: placed.deletingLastPathComponent()), ["Bestiario (2)", "Rayuela (1)"])

        // Si el segundo paso falla, la carpeta regresa a su nombre: nunca queda `.gabinete-…`.
        let other = try tempDir(in: base)
        let lower = other.appendingPathComponent("a"), upper = other.appendingPathComponent("A")
        try FileManager.default.createDirectory(at: lower, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: upper, withIntermediateDirectories: true)
        try Data().write(to: upper.appendingPathComponent("ocupado"))
        XCTAssertThrowsError(try FolderMove.move(lower, to: upper))
        XCTAssertEqual(names(in: other), ["A", "a"])
    }

    // MARK: 5 · Deshacer lo que se completó solo no vuelve a aplicarse solo

    func testUndoingAutoFillForgetsTheRecord() {
        let original = Book(title: "Rayuela", authors: ["Julio Cortázar"])
        let candidate = MetadataCandidate(id: "ol:/works/OL1W", source: .openLibrary, title: "Rayuela",
                                          authors: ["Julio Cortázar"], publisher: "Sudamericana", workKey: "/works/OL1W")
        let filled = MetadataMatcher.fillMissing(original, from: candidate)
        XCTAssertEqual(filled.identifiers["openlibrary"], "OL1W")
        let changes = AutoFill.identifierChanges(from: original, to: filled)
        XCTAssertEqual(changes, [AutoFill.IdentifierChange(scheme: "openlibrary", old: nil, new: "OL1W")])

        // Sin deshacer el registro, la siguiente búsqueda lo reconoce como el mismo y lo vuelve a poner.
        XCTAssertTrue(MetadataMatcher.match(candidate, for: filled).notes.contains(.sameRecord))

        var undone = filled
        undone.publisher = nil
        AutoFill.undo(changes, in: &undone)
        XCTAssertNil(undone.identifiers["openlibrary"], "Deshacer quita también el registro de internet")
        XCTAssertFalse(MetadataMatcher.match(candidate, for: undone).notes.contains(.sameRecord))

        // Y si vuelve a salir, ya no se aplica solo: va a «Por revisar».
        let declined = AutoFill.recordKeys(candidate)
        XCTAssertEqual(declined, ["openlibrary:OL1W"])
        XCTAssertFalse(AutoFill.allowsAutoApply(candidate, declined: declined))
        let other = MetadataCandidate(id: "ol:/works/OL2W", source: .openLibrary, title: "Rayuela", workKey: "/works/OL2W")
        XCTAssertTrue(AutoFill.allowsAutoApply(other, declined: declined))

        // Un identificador que cambiaste a mano después se respeta.
        var mine = filled
        mine.identifiers["openlibrary"] = "OL9W"
        AutoFill.undo(changes, in: &mine)
        XCTAssertEqual(mine.identifiers["openlibrary"], "OL9W")
    }

    // MARK: 6 · Guardar una ficha vieja solo escribe lo que cambiaste

    func testStaleEditorOnlyWritesWhatYouChanged() {
        var loaded = Book(title: "Rayuela", authors: ["Julio Cortázar"], identifiers: ["isbn": "9788437604572"])
        loaded.rating = 3.5
        // Mientras la ficha estaba abierta, llegó una sinopsis y otro dispositivo la marcó como leída.
        var current = loaded
        current.summary = "Una novela"
        current.readingStatus = .finished
        current.identifiers["openlibrary"] = "OL1W"
        current.filePath = "Julio Cortázar/Rayuela (1)/Rayuela - Julio Cortázar.epub"

        // La ficha de la Mac redondea la valoración: 3.5 se lee como 4 aunque no la toques.
        var baseline = loaded
        baseline.rating = 4
        var edited = baseline
        edited.title = "Rayuela (edición crítica)"
        edited.tags = ["Novela"]

        let saved = Book.applyingEdits(from: edited, loaded: baseline, onto: current)
        XCTAssertEqual(saved.title, "Rayuela (edición crítica)")
        XCTAssertEqual(saved.tags, ["Novela"])
        XCTAssertEqual(saved.summary, "Una novela", "Lo que llegó mientras tanto no se pisa")
        XCTAssertEqual(saved.readingStatus, .finished)
        XCTAssertEqual(saved.rating, 3.5, "La valoración que no tocaste no se redondea")
        XCTAssertEqual(saved.identifiers, ["isbn": "9788437604572", "openlibrary": "OL1W"])
        XCTAssertEqual(saved.filePath, current.filePath)

        // Lo que sí cambiaste gana, también borrar un dato.
        var cleared = baseline
        cleared.identifiers["isbn"] = nil
        cleared.rating = nil
        let second = Book.applyingEdits(from: cleared, loaded: baseline, onto: current)
        XCTAssertNil(second.identifiers["isbn"])
        XCTAssertNil(second.rating)
        XCTAssertEqual(second.identifiers["openlibrary"], "OL1W")
    }

    // MARK: Regla: quien escribe en la carpeta sabe de iCloud

    /// Los archivos de la carpeta se escriben por `ChangeLog`, `SessionLog`, `NoteFolder` o
    /// `SideFile`, que no pisan lo que iCloud no ha bajado. Fuera de ellos solo se escriben
    /// la portada, el metadata.opf (salen del catálogo) y lo que exportas tú.
    func testCabinetWritersKnowAboutICloud() {
        let allowed = ["cover.write(to:", "jpeg.write(to:", "CalibreOPF.write(", "ReadwiseCSV.export("]
        var problems: [String] = []
        for file in DesignRulesTests.sources("App/Shared") {
            for (index, line) in file.lines.enumerated() where line.contains(".write(to:") || line.contains("FileHandle(forWritingTo:") {
                let code = line.trimmingCharacters(in: .whitespaces)
                guard !code.hasPrefix("//"), !allowed.contains(where: { line.contains($0) }) else { continue }
                problems.append("\(file.path):\(index + 1): \(code)")
            }
        }
        XCTAssertTrue(problems.isEmpty, "Escribe en la carpeta con SideFile (o ChangeLog, SessionLog, NoteFolder):\n"
                      + problems.joined(separator: "\n"))
        let store = DesignRulesTests.sources("App/Shared/Library").first { $0.path.hasSuffix("LibraryStore.swift") }
        XCTAssertTrue(store?.text.contains("SideFile.persist(") ?? false)
    }
}
