import Foundation
@testable import LectoraCore
import XCTest

/// Auditoría 8 (27 nov 2026): el libro que lees no se cierra porque cambie de carpeta; mientras
/// bajo tu biblioteca de iCloud no muevo ni cambio de Gabinete; rehacer devuelve lo que deshacer
/// quitó; mover nunca toca la carpeta de otro aparato; una nota que cambias a un título ocupado se
/// llama «Ideas 2». Cada prueba falla si vuelve.
final class AuditoriaOchoTests: XCTestCase {
    private func tempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("auditoria8-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func source(_ name: String, in folder: String = "App/Shared") -> String {
        DesignRulesTests.sources(folder).first { $0.path.hasSuffix("/" + name) }?.text ?? ""
    }

    /// El texto de una función, de su firma a la siguiente.
    private func body(of signature: String, in text: String) -> String {
        guard let start = text.range(of: signature) else { return "" }
        let rest = text[start.upperBound...]
        let ends = ["\n    func ", "\n    private func ", "\n    nonisolated ", "\n    @discardableResult", "\n    static ",
                    "\n    /// "]
            .compactMap { rest.range(of: $0)?.lowerBound }
        return String(rest[..<(ends.min() ?? rest.endIndex)])
    }

    private var store: String { source("LibraryStore.swift") }

    // MARK: A1 y M6 · El libro que lees no se cierra porque cambie de carpeta

    func testReaderStaysOpenWhenItsFolderMoves() {
        // Se decide por si la biblioteca lo tiene, con el archivo de ahora.
        XCTAssertEqual(ReaderOpening.restoredWindow(waitingForCloud: false, inLibrary: true, fileExists: true, inCloud: false), .keep)
        XCTAssertEqual(ReaderOpening.restoredWindow(waitingForCloud: false, inLibrary: true, fileExists: false, inCloud: true), .keep,
                       "Su archivo sigue en iCloud: lo bajo, no cierro la ventana")
        XCTAssertEqual(ReaderOpening.restoredWindow(waitingForCloud: false, inLibrary: nil, fileExists: false, inCloud: true), .keep)
        XCTAssertEqual(ReaderOpening.restoredWindow(waitingForCloud: true, inLibrary: true, fileExists: false, inCloud: false), .wait)
        XCTAssertEqual(ReaderOpening.restoredWindow(waitingForCloud: false, inLibrary: false, fileExists: true, inCloud: false), .close)
        XCTAssertEqual(ReaderOpening.restoredWindow(waitingForCloud: false, inLibrary: nil, fileExists: false, inCloud: false), .close)

        // Una vez, al abrirse, y solo para las ventanas que la Mac restaura.
        let window = source("MacReaderWindow.swift", in: "App/Shared/Mac")
        XCTAssertTrue(window.contains(".task { await openOnce() }"))
        XCTAssertFalse(window.contains(".task(id: available)"), "Ya no se mira en cada vuelta")
        XCTAssertFalse(window.contains("fileExists(atPath: book.url.path)"), "Ni la ruta de cuando lo abriste")
        let once = body(of: "private func openOnce() async {", in: window)
        XCTAssertTrue(once.contains("guard file == nil else { return }"))
        XCTAssertTrue(once.contains("guard !model.openedWindows.contains(book) else {"), "Lo que abriste tú no se revisa")
        XCTAssertTrue(once.contains("inCloud: CloudFile.isPlaceholder(url)"))
        XCTAssertTrue(window.contains("model.library.fileURL(for: $0)"), "El archivo de ahora, de la biblioteca")
        let root = source("RootView.swift")
        guard let mark = root.range(of: "model.openedWindows.insert(book)"),
              let open = root.range(of: "openWindow(id: MacReaderWindow.id, value: book)") else {
            return XCTFail("Las ventanas que abres se anotan")
        }
        XCTAssertTrue(mark.upperBound <= open.lowerBound)

        // El lector abierto sigue al archivo a su carpeta nueva; un marcador de iCloud no está bajado.
        XCTAssertTrue(source("ReaderView.swift", in: "App/Shared/Reader").contains("controller.follow(bookFile: file)"))
        XCTAssertTrue(source("ReaderController.swift", in: "App/Shared/Reader").contains("func follow(bookFile: URL) {"))
        XCTAssertTrue(body(of: "static func isDownloaded(_ url: URL) -> Bool {", in: source("CabinetLocation.swift"))
            .contains("if CloudFile.isPlaceholder(url) { return false }"))

        // La regla está escrita en el sistema de diseño.
        let doc = (try? String(contentsOf: DesignRulesTests.root.appendingPathComponent("docs/sistema-diseno.md"), encoding: .utf8)) ?? ""
        XCTAssertTrue(doc.contains("el libro que lees no se cierra porque cambie de carpeta"))
    }

    // MARK: A2 · Mientras bajo tu biblioteca de iCloud no muevo ni cambio de Gabinete

    func testCabinetStaysPutWhileDownloading() {
        let guardLine = "guard !waitingForCloud else { throw LocationError.downloadingLibrary }"
        XCTAssertTrue(body(of: "func move(toCabinet destination: URL) async throws {", in: store).contains(guardLine))
        XCTAssertTrue(body(of: "func use(cabinet destination: URL) throws {", in: store).contains(guardLine))
        XCTAssertTrue(body(of: "func useLocalCabinet() throws {", in: store).contains(guardLine))
        XCTAssertTrue(store.contains("case .downloadingLibrary:\n                EmptyCopy.cabinetWhileDownloading"))

        let settings = source("SettingsScreen.swift", in: "App/Shared/Screens")
        XCTAssertEqual(settings.components(separatedBy: ".disabled(busy || model.cabinetChangeBlocked != nil)").count - 1, 3,
                       "«Mover a iCloud Drive u otra carpeta», «Volver a la carpeta de este dispositivo» y «Ordenar la biblioteca» se ven apagados")
        XCTAssertTrue(settings.contains("if let blocked = model.cabinetChangeBlocked ?? model.addBooksBlocked, !busy {\n                ReasonLine(blocked)"),
                      "Y dicen por qué, completo")
        XCTAssertTrue(source("AppModel.swift").contains("library.waitingForCloud ? EmptyCopy.cabinetWhileDownloading : nil"))
    }

    // MARK: M1 · Rehacer devuelve la regla que deshacer quitó

    func testRedoRestoresTheRulesUndoRemoved() {
        let kept = MetadataRules.Rule(from: "Borges", to: "Jorge Luis Borges")
        let added = MetadataRules.Rule(from: "J. Cortázar", to: "Julio Cortázar")
        let before = MetadataRules(authors: [kept])
        let after = MetadataRules(authors: [kept, added])
        // Deshacer quita la que añadió…
        let undone = after.undoing(from: before, after: after)
        XCTAssertEqual(undone.authors, [kept])
        // …y rehacer (deshacer el deshacer: de lo de antes de deshacer a lo de después) la devuelve.
        let redone = undone.undoing(from: after, after: undone)
        XCTAssertEqual(redone.authors, [kept, added])
        // Si ya la tienes otra vez, no se repite.
        XCTAssertEqual(after.undoing(from: after, after: undone).authors, [kept, added])
        // Y vuelve a su lugar de antes.
        let first = MetadataRules.Rule(from: "Gabo", to: "Gabriel García Márquez")
        let withBoth = MetadataRules(authors: [first, kept])
        XCTAssertEqual(MetadataRules(authors: [kept]).undoing(from: withBoth, after: MetadataRules(authors: [kept])).authors, [first, kept])
    }

    // MARK: M2 · Poner las carpetas en su lugar no traba la app ni pierde lo que guardas

    func testPlacingRunsOffTheMainThreadInOrder() {
        let move = body(of: "func move(toCabinet destination: URL) async throws {", in: store)
        XCTAssertTrue(move.contains("try await Task.detached(priority: .userInitiated) { try staged.place() }.value"))
        XCTAssertFalse(move.contains("placed = try staged.place()"), "Ya no en el hilo de la interfaz")
        XCTAssertTrue(move.contains("await Task.detached(priority: .userInitiated) { staged.takeBack(placed) }.value"))
        guard let place = move.range(of: "{ try staged.place() }"),
              let late = move.range(of: "let late = journal.drain()"),
              let copy = move.range(of: "try FolderCatchUp.copy(late, from: from, to: to"),
              let remember = move.range(of: "try CabinetLocation.remember(destination)"),
              let open = move.range(of: "open(cabinet: destination)") else {
            return XCTFail("Lo que guardaste mientras las ponía en su lugar se copia antes del cambio")
        }
        XCTAssertTrue(place.upperBound <= late.lowerBound && late.upperBound <= copy.lowerBound
                      && copy.upperBound <= remember.lowerBound && remember.upperBound <= open.lowerBound)
        // Entre la última copia y el cambio no se suelta el hilo.
        XCTAssertFalse(move[late.lowerBound..<remember.lowerBound].contains("await"))
    }

    // MARK: M3 · Regresar lo que puse nunca toca la carpeta de otro aparato

    func testTakeBackOnlyTouchesItsOwnFolder() throws {
        let destination = try tempDir()
        let manager = FileManager.default
        let staged = StagedMove(destination: destination, folders: ["Biblioteca", "Notas"])
        for folder in staged.folders {
            try manager.createDirectory(at: staged.staging(folder), withIntermediateDirectories: true)
            try Data("mío".utf8).write(to: staged.staging(folder).appendingPathComponent("mio.txt"))
        }
        let placed = try staged.place()
        XCTAssertEqual(placed, ["Biblioteca", "Notas"])

        // iCloud renombró la mía a «Biblioteca 2» y la de otro aparato llegó como «Biblioteca».
        try manager.moveItem(at: destination.appendingPathComponent("Biblioteca"), to: destination.appendingPathComponent("Biblioteca 2"))
        try manager.createDirectory(at: destination.appendingPathComponent("Biblioteca"), withIntermediateDirectories: true)
        try Data("del otro".utf8).write(to: destination.appendingPathComponent("Biblioteca/otro.txt"))

        staged.takeBack(placed)
        XCTAssertTrue(manager.fileExists(atPath: destination.appendingPathComponent("Biblioteca/otro.txt").path), "La del otro aparato se queda")
        XCTAssertFalse(manager.fileExists(atPath: destination.appendingPathComponent("Biblioteca 2").path), "La mía regresa, con su nombre nuevo")
        XCTAssertFalse(manager.fileExists(atPath: destination.appendingPathComponent("Notas").path))
        XCTAssertTrue(manager.fileExists(atPath: staged.staging("Biblioteca").appendingPathComponent("mio.txt").path))
        XCTAssertTrue(manager.fileExists(atPath: staged.staging("Notas").appendingPathComponent("mio.txt").path))

        // Una carpeta sin la marca de esta corrida nunca se toca.
        let other = StagedMove(destination: destination, folders: ["Biblioteca"])
        other.takeBack(["Biblioteca"])
        XCTAssertTrue(manager.fileExists(atPath: destination.appendingPathComponent("Biblioteca/otro.txt").path))

        // Ya en su lugar, la marca no se queda en tu carpeta.
        let fresh = try tempDir()
        let done = StagedMove(destination: fresh, folders: ["Notas"])
        try manager.createDirectory(at: done.staging("Notas"), withIntermediateDirectories: true)
        try done.place()
        XCTAssertTrue(manager.fileExists(atPath: fresh.appendingPathComponent("Notas/\(StagedMove.markerName)").path))
        done.finish()
        XCTAssertFalse(manager.fileExists(atPath: fresh.appendingPathComponent("Notas/\(StagedMove.markerName)").path))
        XCTAssertTrue(store.contains("staged.finish()\n        open(cabinet: destination)"))
    }

    // MARK: M4 · Cambiar el título a uno que ya tiene otra nota

    func testRenamingToATakenTitleUsesTheNextName() throws {
        let folder = NoteFolder(url: try tempDir())
        try Data("# Ideas\n\nLas de antes".utf8).write(to: folder.file(for: "Ideas"))
        try Data("# Plan\n\nUno".utf8).write(to: folder.file(for: "Plan"))
        let saved = try folder.save(text: "# Ideas\n\nUno", fileName: "Plan")
        XCTAssertEqual(saved.fileName, "Ideas 2", "Tú cambiaste el título: la nota se llama como él, sin pisar la otra")
        XCTAssertNil(folder.read(folder.file(for: "Plan")))
        XCTAssertEqual(folder.read(folder.file(for: "Ideas"))?.text, "# Ideas\n\nLas de antes")
        // Guardarla otra vez sin cambiar el título no la vuelve a renombrar.
        XCTAssertEqual(try folder.save(text: "# Ideas\n\nUno y dos", fileName: "Ideas 2").fileName, "Ideas 2")
        // Solo mayúsculas: en el disco es el mismo archivo, se queda.
        try Data("# notas\n\nx".utf8).write(to: folder.file(for: "notas"))
        XCTAssertEqual(try folder.save(text: "# Notas\n\nx", fileName: "notas").fileName, "notas")
    }

    // MARK: M5 · Una sola fila de consultas

    func testBatchStopsTheRetry() {
        let many = body(of: "func lookUpMany(_ ids: [UUID]) {", in: store)
        guard let stop = many.range(of: "stopPendingLookups()"), let task = many.range(of: "batchTask = Task {") else {
            return XCTFail("El lote detiene la vuelta de lo pendiente antes de empezar")
        }
        XCTAssertTrue(stop.upperBound <= task.lowerBound)
        XCTAssertTrue(many.contains("await self.retryPendingLookups()"), "Y la vuelta sigue al terminar el lote")
    }

    // MARK: B1 · Una cerca de código no es el título

    func testFenceIsNotTheTitle() throws {
        XCTAssertEqual(Note.title(of: "```swift\nlet a = 1\n```\n"), "let a = 1")
        XCTAssertEqual(Note.title(of: "~~~\n# Ideas\n~~~"), "Ideas")
        XCTAssertEqual(Note.title(of: "\n```\n1. Introducción"), "1. Introducción", "Los números de la lista se quedan")
        XCTAssertNil(Note.title(of: "```\n```"))
        // Una nota que ya tenías así no cambia de nombre sola.
        let folder = NoteFolder(url: try tempDir())
        try Data("```swift\nlet a = 1\n```".utf8).write(to: folder.file(for: "codigo"))
        XCTAssertEqual(try folder.save(text: "```swift\nlet a = 1\n```\nmás", fileName: "codigo").fileName, "codigo")
    }

    // MARK: B2 · «Ya lo estoy buscando»

    func testCandidatesWaitForTheSearchAlreadyRunning() {
        let screen = source("ReviewScreen.swift", in: "App/Shared/Screens")
        let run = body(of: "private func run(_ ask: Ask) async -> MetadataService.Decision? {", in: screen)
        XCTAssertTrue(run.contains("if model.library.identifying.contains(bookID) {")
                      && run.contains("await model.library.waitUntilSearched(bookID)"))
        XCTAssertTrue(screen.contains("LoadingLine(text: alreadySearching ? Self.alreadySearchingLine"))
        XCTAssertTrue(store.contains("for await searching in $identifying.values where !searching.contains(bookID) { return }"))
    }

    // MARK: B3 · Esperar a que la biblioteca esté libre se puede dejar

    func testWaitingForIdleIsCancellable() {
        let wait = body(of: "func waitUntilIdle() async {", in: store)
        XCTAssertTrue(wait.contains("withTaskCancellationHandler") && wait.contains("!Task.isCancelled"))
        XCTAssertTrue(wait.contains("self?.idleWaiters.removeValue(forKey: id)?.resume()"))
        XCTAssertTrue(body(of: "private func releaseLock(_ work: LibraryWork) {", in: store).contains("idle.values.forEach { $0.resume() }"))
    }
}
