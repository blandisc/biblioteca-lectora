import Foundation
@testable import LectoraCore
import XCTest

/// Auditoría 3 (27 nov 2026): «Ordenar» y abrir la app no se congelan aunque tengas miles de
/// libros, y lo que espera a iCloud no se pierde ni se queda atrás. Cada prueba falla si vuelve.
final class AuditoriaTresTests: XCTestCase {
    private func tempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("auditoria3-\(UUID().uuidString)")
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
        let ends = ["\n    func ", "\n    private func ", "\n    nonisolated "].compactMap { rest.range(of: $0)?.lowerBound }
        return String(rest[..<(ends.min() ?? rest.endIndex)])
    }

    /// Una biblioteca de `books` libros repartidos en `authors` autores, con un archivo cada uno.
    private func makeLibrary(books: Int, authors: Int) throws -> (root: URL, paths: [String]) {
        let root = try tempDir()
        var paths: [String] = []
        for number in 0..<books {
            let folder = "Autor \(number % authors)/Libro \(number) (\(number + 1))"
            let url = root.appendingPathComponent(folder)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: url.appendingPathComponent("libro.epub").path, contents: Data("x".utf8))
            paths.append(folder + "/libro.epub")
        }
        return (root, paths)
    }

    // MARK: 1 · «Ordenar» con 5,000 libros y 1,500 autores no congela la app

    func testDiskSpellingWithIndexIsFastWithThousandsOfBooks() throws {
        let (root, paths) = try makeLibrary(books: 5_000, authors: 1_500)
        // La mitad con otras mayúsculas (como las guardaba una versión anterior).
        let asked = paths.enumerated().map { $0.offset.isMultiple(of: 2) ? $0.element : $0.element.uppercased() }
        let index = SpellingIndex(root: root)
        let start = Date()
        let spelled = asked.map { FolderMove.diskSpelling(of: $0, in: root, index: index) }
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertEqual(spelled, paths, "Cada ruta sale con el nombre que tiene en el disco")
        XCTAssertLessThan(elapsed, 2, "5,000 rutas con un índice: antes cada una listaba a los 1,500 autores")
        // Cada carpeta se lee una vez: la raíz, cada autor y cada libro que hubo que buscar.
        XCTAssertLessThanOrEqual(index.listings, 1 + 1_500 + 2_500)
    }

    func testIndexForgetsWhatMoved() throws {
        let root = try tempDir()
        let index = SpellingIndex(root: root)
        XCTAssertEqual(FolderMove.diskSpelling(of: "Julio Cortázar/Rayuela (1)", in: root, index: index), "Julio Cortázar/Rayuela (1)")
        let real = try FolderMove.createFolder("julio cortázar/Rayuela (1)", in: root, index: index)
        XCTAssertEqual(real, "julio cortázar/Rayuela (1)")
        // Lo recién creado se ve: el índice olvidó lo que había leído de esas carpetas.
        XCTAssertEqual(FolderMove.diskSpelling(of: "JULIO CORTÁZAR/Bestiario (2)", in: root, index: index), "julio cortázar/Bestiario (2)")
        let moved = try FolderMove.moveBookFolder(root.appendingPathComponent("julio cortázar/Rayuela (1)"),
                                                  to: root.appendingPathComponent("Jorge Luis Borges/Ficciones (1)"), index: index)
        XCTAssertEqual(moved.lastPathComponent, "Ficciones (1)")
        XCTAssertEqual(FolderMove.diskSpelling(of: "jorge luis borges/ficciones (1)", in: root, index: index),
                       "Jorge Luis Borges/Ficciones (1)")
    }

    // MARK: 2 · Abrir la app con miles de libros sin bajar no la congela

    func testRepairAtLoadIsOnePassOverTheDisk() throws {
        let (root, paths) = try makeLibrary(books: 1_000, authors: 300)
        var table: [Int: String] = [:]
        for (number, path) in paths.enumerated() { table[number] = path }
        // 5,000 libros cuyo autor no está en el disco con ninguna mayúscula (siguen en otra parte).
        for number in 0..<5_000 { table[10_000 + number] = "Nadie \(number)/Libro (\(number))/libro.epub" }
        // Uno guardado con otras mayúsculas: ese sí se corrige.
        table[1] = paths[1].lowercased()
        let start = Date()
        let fixes = FolderMove.repairedSpellings(of: table, in: root)
        XCTAssertLessThan(Date().timeIntervalSince(start), 2, "Antes: 5,000 libros sin bajar tardaban 18 s")
        // En un disco que distingue mayúsculas (el iPhone) se corrige; en uno que no, ya se abre así.
        let sensitive = !FileManager.default.fileExists(atPath: root.appendingPathComponent(paths[1].lowercased()).path)
        XCTAssertEqual(fixes, sensitive ? [1: paths[1]] : [:], "Solo se corrige el que está con otras mayúsculas")
    }

    func testRepairRunsOffTheMainThreadAndSavesOnce() {
        let store = source("App/Shared/Library", "LibraryStore.swift")
        let repair = body(of: "private func repairPathCase() {", in: store)
        XCTAssertTrue(repair.contains("Task.detached"), "Las rutas se revisan fuera del hilo de la interfaz")
        XCTAssertTrue(repair.contains("FolderMove.repairedSpellings(of:"), "Con un solo índice para todos los libros")
        let save = body(of: "private func recordRepairs(", in: store)
        XCTAssertFalse(save.contains("record("), "Las correcciones se guardan juntas, no libro por libro")
        XCTAssertEqual(save.components(separatedBy: "books = state.books()").count - 1, 1, "Los libros se arman una vez")
        let tidy = body(of: "func tidy() async -> TidyReport {", in: store)
        XCTAssertTrue(tidy.contains("SpellingIndex(root: root)") && tidy.contains("spelling: index"),
                      "«Ordenar» lee el disco una vez por carpeta")
        XCTAssertTrue(tidy.contains("deferringBooks = true") && tidy.contains("await Task.yield()"),
                      "«Ordenar» arma los libros al final y deja responder a la interfaz")
        let migrate = body(of: "func migrateFromCalibre(", in: store)
        XCTAssertTrue(migrate.contains("index: spelling") && migrate.contains("deferringBooks = true"),
                      "Traer de Calibre tampoco lee el disco ni arma los libros en cada uno")
        XCTAssertFalse(migrate.contains("books.contains(where:"), "El número libre se busca en un conjunto")
    }

    // MARK: 3 · Mover el Gabinete no deja atrás lo que esperaba a iCloud

    func testMoveWritesPendingFirst() {
        let store = source("App/Shared/Library", "LibraryStore.swift")
        let move = body(of: "func move(toCabinet destination: URL) async throws {", in: store)
        guard let download = move.range(of: "downloadAll(in: folders)"), let retry = move.range(of: "retryWaitingFiles()"),
              let guardPending = move.range(of: "guard !hasWaitingFiles, !pendingWrites.has(SessionStore.pendingName) else { throw LocationError.pendingChanges }"),
              let copy = move.range(of: "coordinatedCopy") else {
            return XCTFail("Mover baja lo de iCloud, escribe lo pendiente y no mueve si algo sigue esperando")
        }
        XCTAssertTrue(download.upperBound <= retry.lowerBound && retry.upperBound <= guardPending.lowerBound
                      && guardPending.upperBound <= copy.lowerBound)
        XCTAssertTrue(move.contains("SessionStore.shared.writePending()"), "También las sesiones que esperaban")
        XCTAssertTrue(store.contains("\"Todavía estoy guardando en tu Gabinete"), "Te lo digo en primera persona")
    }

    // MARK: 4 · Juntar duplicados: las lápidas antes de mover subrayados y marcadores

    func testMergeWritesTombstonesBeforeMovingAnything() {
        let store = source("App/Shared/Library", "LibraryStore.swift")
        let merge = body(of: "func merge(keep keepID: UUID, others otherIDs: [UUID]) throws -> MergeReport {", in: store)
        guard let tombstones = merge.range(of: "try recordNow("), let position = merge.range(of: "savePosition("),
              let highlights = merge.range(of: "AnnotationStore.shared.save("), let bookmarks = merge.range(of: "addBookmark(") else {
            return XCTFail("Juntar escribe las lápidas y luego pasa posición, subrayados y marcadores")
        }
        XCTAssertTrue(tombstones.upperBound <= position.lowerBound && tombstones.upperBound <= highlights.lowerBound
                      && tombstones.upperBound <= bookmarks.lowerBound, "Si la lápida falla, nada se movió a medias")
        XCTAssertEqual(merge.components(separatedBy: "recordNow(").count - 1, 1, "Todas las lápidas de una vez")
    }

    // MARK: 5 · Tu registro sin bajar no es una biblioteca vacía

    func testPlaceholderLogIsReportedNotSkipped() throws {
        let directory = try tempDir()
        let log = ChangeLog(directory: directory, deviceID: "iphone")
        let other = ChangeLog(directory: directory, deviceID: "mac")
        try other.append([Change(hlc: HLC(wallMillis: 1, counter: 0, node: "mac"), entity: .book, entityID: UUID(),
                                 field: "title", value: .string("Rayuela"))])
        try Data().write(to: log.ownPlaceholder)
        let result = try log.readAll()
        XCTAssertEqual(result.changes.count, 1, "Lo del otro sí se lee")
        XCTAssertEqual(result.notDownloaded.map(\.lastPathComponent), ["iphone.jsonl"], "El propio sin bajar se reporta")
        XCTAssertEqual(result.skipped.map(\.lastPathComponent), ["iphone.jsonl"])
        XCTAssertFalse(result.isComplete)
        let store = source("App/Shared/Library", "LibraryStore.swift")
        XCTAssertTrue(store.contains("notDownloaded: result?.notDownloaded ?? []"), "La biblioteca pide bajarlo y vuelve a leer")
        XCTAssertTrue(store.contains("if !notDownloaded.isEmpty, !books.isEmpty { return }"), "Mientras, no se quita nada")
        let root = source("App/Shared", "RootView.swift")
        XCTAssertTrue(root.contains("!model.library.waitingForCloud"), "Bajando tu biblioteca no es la bienvenida")
    }

    // MARK: 6 · Guardar la posición con el registro sin bajar no se vuelve cada vez más lento

    func testPendingChangesOnlyAppend() throws {
        let pending = PendingWrites(directory: try tempDir())
        // Lo de antes (una lista entera) se sigue leyendo.
        pending.set(["antes"], "registro.json")
        let start = Date()
        for number in 0..<2_000 { XCTAssertTrue(pending.appendLines(["página \(number)"], "registro.json")) }
        XCTAssertLessThan(Date().timeIntervalSince(start), 2, "Cada guardado solo agrega su renglón")
        // Un renglón cortado (la app se cerró a media escritura) se salta; lo siguiente no se pega.
        let lines = pending.directory.appendingPathComponent("registro.jsonl")
        let handle = try FileHandle(forWritingTo: lines)
        _ = try handle.seekToEnd()
        try handle.write(contentsOf: Data("\"cort".utf8))
        try handle.close()
        pending.appendLines(["última"], "registro.json")
        let read = pending.lines("registro.json", as: String.self)
        XCTAssertEqual(read.count, 2_002)
        XCTAssertEqual(read.first, "antes")
        XCTAssertEqual(read.last, "última")
        XCTAssertEqual(pending.names, ["registro.json"], "Se reintenta con su mismo nombre")
        XCTAssertTrue(pending.has("registro.json"))
        pending.removeLines("registro.json")
        XCTAssertTrue(pending.isEmpty)
        let store = source("App/Shared/Library", "LibraryStore.swift")
        let keep = body(of: "private func appendOrKeep(_ changes: [Change]) {", in: store)
        XCTAssertTrue(keep.contains("appendLines(changes"), "Lo pendiente crece por renglones")
        XCTAssertFalse(keep.contains("pendingWrites.set("), "Ya no se reescribe todo en cada página")
    }

    // MARK: 7 · La marca de la sesión no se ve ni se borra al escribir la nota

    func testEditorHidesCommentsAndPutsThemBack() {
        let id = UUID()
        let note = "# Rayuela, 3 de noviembre\n\(NoteMarkdown.sessionMarker(id))\n\nSesión de 20 min.\n"
        let editable = NoteMarkdown.editable(note)
        XCTAssertFalse(editable.text.contains("<!--"), "El editor nunca enseña un comentario")
        XCTAssertEqual(NoteMarkdown.restoringComments(editable.comments, in: editable.text), note, "Al guardar vuelve igual")
        // Escribiste encima (y hasta borraste el título): la marca sigue ahí y no se repite.
        let rewritten = NoteMarkdown.restoringComments(editable.comments, in: "Otra cosa")
        XCTAssertEqual(rewritten, "\(NoteMarkdown.sessionMarker(id))\nOtra cosa")
        XCTAssertEqual(NoteMarkdown.restoringComments(editable.comments, in: rewritten), rewritten)
        let saved = Note(fileName: "a.md", text: rewritten, modifiedAt: Date())
        XCTAssertEqual(NoteMarkdown.note(forSession: id, in: [saved])?.fileName, "a.md")
        // Tocada por otro editor (espacios, minúsculas): se sigue encontrando.
        let touched = Note(fileName: "b.md", text: "#  x\n  <!--gabinete:sesion   \(id.uuidString.lowercased())-->", modifiedAt: Date())
        XCTAssertEqual(NoteMarkdown.note(forSession: id, in: [touched])?.fileName, "b.md")
        XCTAssertNil(NoteMarkdown.note(forSession: UUID(), in: [saved, touched]))
        // Buscar «sesion» o «gabinete» no encuentra la nota por su marca escondida.
        XCTAssertFalse(NoteMarkdown.searchText(note).localizedCaseInsensitiveContains("gabinete"))
        let screen = source("App/Shared/Screens", "NoteScreen.swift")
        XCTAssertTrue(screen.contains("NoteMarkdown.editable(existing.text)") && screen.contains("NoteMarkdown.editable(ref.draft"),
                      "La nota y el borrador de la sesión se abren sin comentarios")
        XCTAssertFalse(screen.contains("text = existing.text"), "El editor nunca recibe la nota cruda")
        XCTAssertTrue(screen.contains("NoteMarkdown.restoringComments(hidden, in: text)"), "Al guardar vuelven")
        let search = source("App/Shared/Screens", "SearchScreen.swift")
        XCTAssertTrue(search.contains("NoteMarkdown.searchText($0.text)"))
    }

    // MARK: 8 · Saltar de un libro a otro no pierde la última página del primero

    func testOpeningAnotherBookSavesThePreviousPosition() {
        let controller = source("App/Shared/Reader", "ReaderController.swift")
        let open = body(of: "func open(bookFile: URL", in: controller)
        XCTAssertTrue(open.contains("flushPosition()"), "Antes de abrir otro libro se guarda la posición del anterior")
        XCTAssertFalse(open.contains("unsavedLocation = nil"), "Ya no se tira")
        XCTAssertTrue(controller.contains("saveUnsaved = onPositionSettled"), "Se guarda en su libro, no en el nuevo")
    }

    // MARK: 9 · Un id nuevo suelta los trabajos que tenía tomados con el de antes

    func testNewDeviceIDReleasesOldClaims() {
        let board = JobBoard(lease: 600, settle: 0)
        let clock = HybridLogicalClock(node: "nuevo")
        var state = LibraryState()
        let now = Date()
        state.apply(board.enqueue(kind: "readwise", target: "a", in: state, clock: clock, now: now))
        let id = JobBoard.jobID(kind: "readwise", target: "a")
        state.apply(board.claim(id, device: "viejo", clock: clock, now: now))
        XCTAssertTrue(board.claimable(in: state, device: "nuevo", now: now).isEmpty, "El fantasma lo tiene")
        state.apply(board.release(claimsOf: "viejo", in: state, clock: clock))
        XCTAssertEqual(board.claimable(in: state, device: "nuevo", now: now).map(\.id), [id], "Se retoma ya, sin esperar")
        XCTAssertTrue(board.release(claimsOf: "viejo", in: state, clock: clock).isEmpty, "Una sola vez")

        let stored = DeviceIdentity.Stored(id: "viejo", fingerprint: "a")
        let resolved = DeviceIdentity.resolve(stored, fingerprint: "b", makeID: { "nuevo" })
        XCTAssertEqual(DeviceIdentity.replaced(stored, by: resolved), "viejo")
        XCTAssertNil(DeviceIdentity.replaced(stored, by: DeviceIdentity.resolve(stored, fingerprint: "a")))
        let store = source("App/Shared/Library", "LibraryStore.swift")
        XCTAssertTrue(store.contains("jobBoard.release(claimsOf: previous"), "La biblioteca las suelta al tomar trabajos")
    }
}
