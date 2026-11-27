import Foundation
@testable import LectoraCore
import XCTest

/// Auditoría 4 (27 nov 2026): mientras ordeno o muevo tu Gabinete, lo que cambias no se pierde
/// ni se revierte; las notas guardan tus comentarios donde los pusiste; lo que iCloud no baja no
/// detiene la biblioteca para siempre. Cada prueba falla si vuelve.
final class AuditoriaCuatroTests: XCTestCase {
    private func tempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("auditoria4-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func source(_ folder: String, _ name: String) -> String {
        DesignRulesTests.sources(folder).first { $0.path.hasSuffix(name) }?.text ?? ""
    }

    /// El texto de una función de la app, de su firma a la siguiente función.
    private func body(of signature: String, in text: String) -> String {
        guard let start = text.range(of: signature) else { return "" }
        let rest = text[start.upperBound...]
        let ends = ["\n    func ", "\n    private func ", "\n    nonisolated ", "\n    @discardableResult"]
            .compactMap { rest.range(of: $0)?.lowerBound }
        return String(rest[..<(ends.min() ?? rest.endIndex)])
    }

    private var store: String { source("App/Shared/Library", "LibraryStore.swift") }

    // MARK: A1 · Un trabajo de toda la biblioteca a la vez

    func testOneLibraryWideWorkAtATime() {
        var lock = WorkLock()
        XCTAssertTrue(lock.begin(.tidying))
        for other in LibraryWork.allCases { XCTAssertFalse(lock.begin(other), "Mientras ordeno, \(other) no empieza") }
        lock.end(.moving)
        XCTAssertEqual(lock.current, .tidying, "Solo lo suelta quien lo tomó")
        lock.end(.tidying)
        XCTAssertFalse(lock.isBusy)
        for work in LibraryWork.allCases {
            XCTAssertTrue(work.reason.hasPrefix("Estoy "), "El porqué va en primera persona")
        }

        // Cada trabajo toma el candado; lo que añades espera su turno, lo demás no empieza.
        XCTAssertTrue(body(of: "func tidy() async -> TidyReport {", in: store).contains("lock.begin(.tidying)"))
        XCTAssertTrue(body(of: "func move(toCabinet destination: URL) async throws {", in: store).contains("try takeLock(.moving)"))
        XCTAssertTrue(body(of: "func migrateFromCalibre(", in: store).contains("lock.begin(.migrating)"))
        XCTAssertTrue(body(of: "func importFiles(_ urls: [URL]) async", in: store).contains("await self.waitForLock(.importing)"))
        XCTAssertTrue(body(of: "func merge(keep keepID: UUID, others otherIDs: [UUID]) throws -> MergeReport {", in: store)
            .contains("try ensureIdle()"))
        XCTAssertTrue(body(of: "func use(cabinet destination: URL) throws {", in: store).contains("try ensureIdle()"))
        XCTAssertTrue(body(of: "func useLocalCabinet() throws {", in: store).contains("try ensureIdle()"))
        XCTAssertFalse(store.contains("_ = await lastImport?.value"), "Mover no espera a una importación que espera al candado")
        // La interfaz lo dice con su porqué.
        let settings = source("App/Shared/Screens", "SettingsScreen.swift")
        XCTAssertTrue(settings.contains("model.library.busyReason"), "Ajustes dice por qué lo demás espera")
        XCTAssertTrue(source("App/Shared/Screens", "CalibreMigrationScreen.swift").contains(".disabled(busyReason != nil)"))
        XCTAssertTrue(source("App/Shared/Mac", "MacDuplicatesView.swift").contains(".disabled(library.busyReason != nil)"))
    }

    // MARK: A1 · Lo que editas mientras ordeno no se revierte

    func testTidyReadsEachBookFreshAndEditsApplyToCurrentState() {
        let tidy = body(of: "func tidy() async -> TidyReport {", in: store)
        XCTAssertTrue(tidy.contains("guard let book = current(id)"), "Cada libro se vuelve a leer justo antes de ordenarlo")
        XCTAssertFalse(tidy.contains("for (number, book) in books.enumerated()"), "Ya no se ordena una copia vieja")
        let update = body(of: "func update(_ edited: Book, cover newCover: Data? = nil, spelling index: SpellingIndex? = nil) throws -> Book {", in: store)
        XCTAssertTrue(update.contains("guard let original = current(edited.id)"), "Se compara con lo más reciente del registro")
        XCTAssertTrue(update.contains("book.filePath = original.filePath"), "Una edición vieja no regresa el libro a su carpeta vieja")
        XCTAssertTrue(update.contains("if lock.current == .moving { throw LibraryError.busy(.moving) }"))
        let repairs = body(of: "private func recordRepairs(", in: store)
        XCTAssertTrue(repairs.contains("current(id)"), "Las correcciones al abrir tampoco usan la lista vieja")
        XCTAssertTrue(store.contains("if lock.current != .tidying { repairPathCase() }"))
        // Lo que tú cambias se ve ya; solo lo del trabajo largo espera a armarse.
        XCTAssertTrue(store.contains("if !deferringBooks.isActive || !bulkWriting { books = state.books() }"))
    }

    // MARK: M4 · Armar los libros al final, con cuenta

    func testDeferringBooksIsCounted() {
        var count = DeferCount()
        count.begin()
        count.begin()
        XCTAssertFalse(count.end(), "El primero que termina no arma los libros mientras el otro sigue")
        XCTAssertTrue(count.isActive)
        XCTAssertTrue(count.end(), "El último sí")
        XCTAssertFalse(count.isActive)
        XCTAssertTrue(count.end(), "De más no baja de cero")
        XCTAssertTrue(store.contains("private var deferringBooks = DeferCount()"))
        XCTAssertFalse(store.contains("deferringBooks = true"), "Ya no se prende y apaga a mano")
    }

    // MARK: M5 · Lo que guardas mientras muevo el Gabinete viaja con él

    func testCatchUpCopiesWhatChangedDuringTheCopy() throws {
        let base = try tempDir()
        let from = base.appendingPathComponent("viejo"), to = base.appendingPathComponent("nuevo")
        let log = from.appendingPathComponent(".lectora/registro/iphone.jsonl")
        try FileManager.default.createDirectory(at: log.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("uno\n".utf8).write(to: log)
        try Data("# Borrar\n".utf8).write(to: from.appendingPathComponent("borrar.md"))
        try FileManager.default.copyItem(at: from, to: to)
        let started = Date().addingTimeInterval(-2)
        // Mientras se copiaba: una página más, una nota nueva y una borrada.
        try Data("uno\ndos\n".utf8).write(to: log)
        try Data("# Nueva\n".utf8).write(to: from.appendingPathComponent("nueva.md"))
        try FileManager.default.removeItem(at: from.appendingPathComponent("borrar.md"))
        XCTAssertGreaterThan(try FolderCatchUp.sync(from: from, to: to, since: started), 0)
        XCTAssertEqual(try String(contentsOf: to.appendingPathComponent(".lectora/registro/iphone.jsonl"), encoding: .utf8), "uno\ndos\n")
        XCTAssertTrue(FileManager.default.fileExists(atPath: to.appendingPathComponent("nueva.md").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: to.appendingPathComponent("borrar.md").path))
        XCTAssertEqual(CloudFile.countItems(in: from), CloudFile.countItems(in: to))

        let move = body(of: "func move(toCabinet destination: URL) async throws {", in: store)
        guard let copy = move.range(of: "coordinatedCopy"), let catchUp = move.range(of: "FolderCatchUp.sync"),
              let remember = move.range(of: "CabinetLocation.remember(destination)"),
              let last = move.range(of: "for folder in Self.catchUpFolders") else {
            return XCTFail("Mover pasa a la copia lo que cambió mientras copiaba")
        }
        XCTAssertTrue(copy.upperBound <= catchUp.lowerBound && last.upperBound <= remember.lowerBound)
        XCTAssertTrue(move.contains("guard copiedCount == expectedCount"), "La copia se comprueba exacta")
        XCTAssertFalse(move.contains("copiedCount >= expectedCount"))
    }

    // MARK: M1 · Tus comentarios y bloques de código se quedan donde los pusiste

    func testEditorHidesOnlyTheSessionMarker() {
        let id = UUID()
        let marker = NoteMarkdown.sessionMarker(id)
        let note = """
        # Rayuela, 3 de noviembre
        \(marker)

        Sesión de 20 min.
        <!-- mi comentario -->

        ```
        <!-- gabinete:sesion \(UUID().uuidString) -->
        <!-- dentro del código -->
        ```
        """
        let editable = NoteMarkdown.editable(note)
        XCTAssertFalse(editable.text.contains(marker), "La marca de la sesión no se ve")
        XCTAssertTrue(editable.text.contains("Sesión de 20 min.\n<!-- mi comentario -->"), "Tu comentario se queda en su lugar")
        XCTAssertTrue(editable.text.contains("```\n<!-- gabinete:sesion"), "Lo de un bloque de código es texto tuyo")
        XCTAssertEqual(editable.comments, [marker])
        XCTAssertEqual(NoteMarkdown.restoringComments(editable.comments, in: editable.text), note, "Al guardar queda igual")
        // Una nota sin marca no se toca.
        let plain = "# Ideas\n<!-- tuyo -->\ntexto"
        XCTAssertEqual(NoteMarkdown.editable(plain).text, plain)
        XCTAssertTrue(NoteMarkdown.editable(plain).comments.isEmpty)
        // La marca dentro de un bloque de código no cuenta como la de la sesión.
        let fenced = Note(fileName: "c.md", text: "# x\n```\n\(marker)\n```", modifiedAt: Date())
        XCTAssertNil(NoteMarkdown.note(forSession: id, in: [fenced]))
    }

    // MARK: M2 · Vaciar la nota de una sesión la borra

    func testClearingASessionNoteDeletesIt() {
        let marker = NoteMarkdown.sessionMarker(UUID())
        XCTAssertEqual(NoteMarkdown.savedText("", restoring: [marker]), "", "Vacía: no vuelve la marca")
        XCTAssertEqual(NoteMarkdown.savedText("#  \n", restoring: [marker]), "")
        XCTAssertTrue(NoteMarkdown.isBlank("# \n\(marker)\n"), "Solo la marca no es una nota")
        XCTAssertFalse(NoteMarkdown.isBlank("# Algo"))
        XCTAssertEqual(NoteMarkdown.savedText("# Algo", restoring: [marker]), "# Algo\n\(marker)")
        XCTAssertTrue(source("App/Shared/Screens", "NoteScreen.swift").contains("NoteMarkdown.savedText(text, restoring: hidden)"))
        XCTAssertTrue(source("App/Shared/Library", "NotesStore.swift").contains("if NoteMarkdown.isBlank(text) {"))
    }

    // MARK: M3 · Un registro sin bajar no detiene la biblioteca

    func testPartialLogsApplyAdditivelyAndTheWaitEnds() {
        // Lo que ya tenías se queda; lo que sí bajó se suma.
        let clock = HybridLogicalClock(node: "mac")
        let kept = UUID(), arrived = UUID()
        var state = LibraryState()
        state.apply(Change(hlc: clock.tick(), entity: .book, entityID: kept, field: "title", value: .string("Rayuela")))
        var fresh = state
        fresh.apply([Change(hlc: clock.tick(), entity: .book, entityID: arrived, field: "title", value: .string("Ficciones"))])
        XCTAssertEqual(Set(fresh.ids(of: .book)), [kept, arrived])

        let apply = body(of: "private func apply(_ changes: [Change]?, notDownloaded: [URL] = []) {", in: store)
        XCTAssertTrue(apply.contains("if !notDownloaded.isEmpty { fresh = state }"), "Se suma a lo que ya tenías")
        XCTAssertFalse(apply.contains("!books.isEmpty { return }\n        var fresh"), "Ya no se descarta todo lo que bajó")
        XCTAssertTrue(apply.contains("loadReviews()"), "Reglas, estantes y «Por revisar» también")
        let giveUp = body(of: "private func giveUpOnCloud() {", in: store)
        XCTAssertTrue(giveUp.contains("waitingForCloud = false") && giveUp.contains("cloudGaveUp = true")
                      && giveUp.contains("notice = Self.cloudGaveUpNotice"), "Dejo de esperar y te lo digo")
        XCTAssertTrue(body(of: "private func waitForLogs(_ notDownloaded: [URL]) {", in: store).contains("self.giveUpOnCloud()"))
        XCTAssertTrue(store.contains("static let cloudGaveUpNotice = \"Todavía no baja de iCloud"))
        let open = body(of: "private func open(cabinet: URL) {", in: store)
        XCTAssertTrue(open.contains("rereadTask?.cancel()") && open.contains("waitingForCloud = false"),
                      "Otro Gabinete no se queda esperando lo del anterior")
    }

    // MARK: B2 · El informe de «Ordenar» no se pierde al salir de Ajustes

    func testTidyReportLivesInTheStore() {
        XCTAssertTrue(store.contains("@Published var tidyReport: TidyReport?"))
        XCTAssertTrue(body(of: "func tidy() async -> TidyReport {", in: store).contains("tidyReport = report"))
        let settings = source("App/Shared/Screens", "SettingsScreen.swift")
        XCTAssertFalse(settings.contains("@State private var tidyReport"), "Ya no vive en la pantalla")
        XCTAssertTrue(settings.contains("model.library.tidyReport"))
    }

    // MARK: B4 · Mover libros no vuelve a leer la carpeta de todos los autores

    func testRelocatingBooksUpdatesTheIndexInPlace() throws {
        let root = try tempDir()
        var books: [URL] = []
        for number in 0..<200 {
            let book = root.appendingPathComponent("Autor \(number)/Libro (\(number))")
            try FileManager.default.createDirectory(at: book, withIntermediateDirectories: true)
            books.append(book)
        }
        let index = SpellingIndex(root: root)
        XCTAssertEqual(index.spelling(of: "AUTOR 0/libro (0)"), "Autor 0/Libro (0)")
        for (number, book) in books.enumerated() {
            let moved = try FolderMove.moveBookFolder(book, to: root.appendingPathComponent("Nuevo \(number)/Libro (\(number))"), index: index)
            XCTAssertEqual(moved.lastPathComponent, "Libro (\(number))")
            // Se ve lo nuevo y ya no lo viejo, sin volver a leer la raíz.
            XCTAssertEqual(index.spelling(of: "NUEVO \(number)/libro (\(number))"), "Nuevo \(number)/Libro (\(number))")
        }
        XCTAssertEqual(index.listings(of: root), 1, "Antes, cada libro movido volvía a leer a todos los autores")
        XCTAssertTrue(index.matches("Autor 5", in: root).isEmpty, "La carpeta vieja (vacía) ya no está en el índice")
        // Lo mismo que leería un índice nuevo.
        let fresh = SpellingIndex(root: root)
        XCTAssertEqual(index.matches("nuevo 7", in: root), fresh.matches("nuevo 7", in: root))
        // Crear una carpeta tampoco vuelve a leer la raíz.
        let real = try FolderMove.createFolder("otro autor/Libro (999)", in: root, index: index)
        XCTAssertEqual(real, "otro autor/Libro (999)")
        XCTAssertEqual(index.matches("OTRO AUTOR", in: root), ["otro autor"])
        XCTAssertEqual(index.listings(of: root), 1)
    }

    // MARK: Regla 16 · La regla está escrita

    func testRuleIsWritten() throws {
        let docs = DesignRulesTests.root.appendingPathComponent("docs/arquitectura.md")
        let text = try String(contentsOf: docs, encoding: .utf8)
        XCTAssertTrue(text.contains("Mientras ordeno o muevo tu Gabinete, lo que cambias no se pierde ni se revierte"))
    }
}
