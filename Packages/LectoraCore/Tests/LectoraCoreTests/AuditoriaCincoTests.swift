import Foundation
@testable import LectoraCore
import XCTest

/// Auditoría 5 (27 nov 2026): toda salida cierra su pantalla; las notas de Windows y los bloques de
/// código se leen bien; mover el Gabinete no borra lo tuyo, no deja copias a medias y no traba la
/// app; lo que editas mientras algo corre no se revierte. Cada prueba falla si vuelve.
final class AuditoriaCincoTests: XCTestCase {
    private func tempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("auditoria5-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func source(_ name: String) -> String {
        DesignRulesTests.sources("App/Shared").first { $0.path.hasSuffix("/" + name) }?.text ?? ""
    }

    /// El texto de una función de la app, de su firma a la siguiente función.
    private func body(of signature: String, in text: String) -> String {
        guard let start = text.range(of: signature) else { return "" }
        let rest = text[start.upperBound...]
        let ends = ["\n    func ", "\n    private func ", "\n    nonisolated ", "\n    @discardableResult", "\n    static "]
            .compactMap { rest.range(of: $0)?.lowerBound }
        return String(rest[..<(ends.min() ?? rest.endIndex)])
    }

    private var store: String { source("LibraryStore.swift") }

    // MARK: A1 · Toda salida de la bienvenida la cierra, aunque ya la hubieras visto

    func testEveryWelcomeExitClosesIt() {
        let welcome = source("WelcomeScreen.swift")
        let finish = body(of: "private func finish() {", in: welcome)
        XCTAssertTrue(finish.contains("seen = true") && finish.contains("dismiss()"),
                      "Salir anota que la viste y cierra la pantalla, sin esperar a que «vista» cambie")
        XCTAssertEqual(welcome.components(separatedBy: "seen = true").count - 1, 1, "Ninguna salida se queda en solo anotar")
        XCTAssertGreaterThanOrEqual(welcome.components(separatedBy: "finish()").count - 2, 3,
                                    "Readwise, «Ir a la biblioteca» del iPhone y las salidas de la Mac")
        XCTAssertTrue(welcome.contains("@Environment(\\.dismiss) private var dismiss"))
    }

    // MARK: M2 · Una nota con renglones de Windows (CRLF)

    func testWindowsLineEndings() {
        let id = UUID()
        let marker = NoteMarkdown.sessionMarker(id)
        let text = "# Lectura\r\n\(marker)\r\nMe gustó el final.\r\n"
        let note = Note(fileName: "lectura.md", text: text, modifiedAt: Date())
        XCTAssertEqual(NoteMarkdown.note(forSession: id, in: [note])?.fileName, "lectura.md", "La marca se encuentra")
        let editable = NoteMarkdown.editable(text)
        XCTAssertFalse(editable.text.contains("gabinete:sesion"), "La marca no sale en el editor")
        XCTAssertEqual(editable.text, "# Lectura\r\nMe gustó el final.\r\n", "Los renglones siguen con su final")
        XCTAssertEqual(NoteMarkdown.savedText(editable.text, restoring: editable.comments), text, "Al guardar queda como estaba")
        XCTAssertTrue(NoteMarkdown.isBlank("# \r\n\(marker)\r\n"))
        XCTAssertFalse(NoteMarkdown.searchText(text).contains("gabinete"))
        XCTAssertEqual(NoteMarkdown.blocks(text), [.heading("Lectura"), .paragraph("Me gustó el final.")])
        XCTAssertEqual(NoteMarkdown.appending("> cita", to: "# Uno\r\nTexto\r\n"), "# Uno\r\nTexto\r\n\r\n> cita\r\n")
    }

    // MARK: B2 · Los bloques de código siguen las reglas de CommonMark

    func testCodeFencesFollowCommonMark() {
        let marker = NoteMarkdown.sessionMarker(UUID())
        // Un «```» no cierra un bloque de «````».
        XCTAssertTrue(NoteMarkdown.markerLines("````\n```\n\(marker)\n````").isEmpty)
        // «```swift» abre, no cierra.
        XCTAssertTrue(NoteMarkdown.markerLines("```\n```swift\n\(marker)\n```").isEmpty)
        // «~~~» no cierra uno de «```».
        XCTAssertTrue(NoteMarkdown.markerLines("```\n~~~\n\(marker)\n```").isEmpty)
        // Cerrado bien, lo de después sí es la marca.
        XCTAssertEqual(NoteMarkdown.markerLines("````\ncódigo\n`````\n\(marker)").map(\.index), [3])
        XCTAssertEqual(NoteMarkdown.markerLines("```swift\nlet a = 1\n```  \n\(marker)").map(\.index), [3])
        // Con cuatro espacios no es cerca (es código con sangría).
        XCTAssertEqual(NoteMarkdown.markerLines("    ```\n\(marker)").map(\.index), [1])
    }

    // MARK: M3 · Mover no borra lo tuyo ni lo que llega de iCloud

    func testCatchUpKeepsWhatItDidNotPut() throws {
        let base = try tempDir()
        let from = base.appendingPathComponent("viejo"), to = base.appendingPathComponent("nuevo")
        let book = "Borges/Ficciones (1)"
        for folder in [from, to] {
            try FileManager.default.createDirectory(at: folder.appendingPathComponent(book), withIntermediateDirectories: true)
        }
        // En el origen la portada sigue en iCloud (solo su marcador); en la copia está de verdad.
        try Data().write(to: from.appendingPathComponent("\(book)/.cover.jpg.icloud"))
        try Data("jpg".utf8).write(to: to.appendingPathComponent("\(book)/cover.jpg"))
        // A la carpeta nueva llegó de iCloud algo que esta corrida no puso.
        try Data("ajeno".utf8).write(to: to.appendingPathComponent("ajeno.md"))
        try Data().write(to: to.appendingPathComponent(".otro.md.icloud"))
        // Algo que esta corrida copió y luego borraste en el origen.
        try Data("x".utf8).write(to: to.appendingPathComponent("borrada.md"))
        var copied: Set<String> = ["Borges", book, "\(book)/cover.jpg", "borrada.md"]
        let pass = try FolderCatchUp.sync(from: from, to: to, since: Date(), copied: &copied)
        let exists = { FileManager.default.fileExists(atPath: to.appendingPathComponent($0).path) }
        XCTAssertTrue(exists("\(book)/cover.jpg"), "Una portada de verdad no se borra porque el origen solo tenga su marcador")
        XCTAssertTrue(exists("ajeno.md") && exists(".otro.md.icloud"), "Lo que no puso esta corrida no se toca")
        XCTAssertFalse(exists("borrada.md"), "Lo que borraste durante la copia no se queda")
        XCTAssertFalse(exists("\(book)/.cover.jpg.icloud"), "El marcador vacío no se copia")
        XCTAssertTrue(pass.isComplete, "El marcador cuenta como el archivo que representa: \(pass)")
        XCTAssertEqual(FolderCatchUp.snapshot(of: from), ["Borges", book, "\(book)/cover.jpg"])
    }

    // MARK: M4 · Una copia que falla se quita y la cuenta sale de la misma lectura

    func testFailedMoveCleansUpAndCountsOnce() throws {
        let move = body(of: "func move(toCabinet destination: URL) async throws {", in: store)
        XCTAssertTrue(move.contains("for folder in created { try? FileManager.default.removeItem(at: folder) }"),
                      "Si algo falla después de empezar a copiar, quito lo que esta corrida creó")
        XCTAssertTrue(move.contains(".filter { !FileManager.default.fileExists(atPath: $0.path) }"), "Solo lo que no estaba")
        XCTAssertFalse(move.contains("countItems"), "Ni contar aparte: una nota nueva entre copiar y contar hacía fallar")
        XCTAssertTrue(move.contains("expected += pass.expected") && move.contains("copied += pass.present"))
        guard let catchBlock = move.range(of: "} catch {"), let open = move.range(of: "open(cabinet: destination)") else {
            return XCTFail("Mover limpia si falla")
        }
        XCTAssertTrue(catchBlock.upperBound <= open.lowerBound, "Lo de esta corrida se quita solo si todavía no cambié de carpeta")

        // La cuenta es de la misma pasada: lo que llega después no la descuadra.
        let base = try tempDir()
        let from = base.appendingPathComponent("viejo"), to = base.appendingPathComponent("nuevo")
        try FileManager.default.createDirectory(at: from, withIntermediateDirectories: true)
        try Data("a".utf8).write(to: from.appendingPathComponent("a.md"))
        try FileManager.default.copyItem(at: from, to: to)
        var copied = FolderCatchUp.snapshot(of: to)
        let pass = try FolderCatchUp.sync(from: from, to: to, since: Date(), copied: &copied)
        try Data("b".utf8).write(to: from.appendingPathComponent("b.md"))
        XCTAssertEqual(pass, FolderCatchUp.Pass(touched: 0, expected: 1, present: 1))
    }

    // MARK: M5 · Lo encontrado mientras muevo no se pierde

    func testLookupWaitsWhileMoving() {
        let identify = body(of: "func identify(_ bookID: UUID, askAlways: Bool = false) async -> MetadataService.Decision? {", in: store)
        guard let busy = identify.range(of: "catch LibraryError.busy {") else { return XCTFail("identify distingue «ocupado»") }
        XCTAssertTrue(identify[busy.upperBound...].prefix(400).contains("setPending(bookID, true)"), "Se queda pendiente")
        XCTAssertFalse(identify.contains("(try? update(completed"), "Ya no se traga el error")
        let safe = body(of: "func completeSafeReviews(_ ids: [UUID]) async -> ReviewUndo {", in: store)
        XCTAssertFalse(safe.contains("(try? update(filledIn"), "En lote tampoco: si no se guarda, se queda en «Por revisar»")
    }

    // MARK: M6 · Después de esperar a internet, se guarda sobre el libro de ahora

    func testNoStaleBookSavedAfterAwait() {
        // Regla: dentro de una función, lo que se guarda con `update(x)` se leyó después del último
        // `await` anterior. Hardcover guardaba el libro leído antes de preguntar y revertía tus cambios.
        var problems: [String] = []
        let call = try! NSRegularExpression(pattern: #"(?<![\w.])(?:library\.|self\.|model\.library\.)?update\((\w+)\s*[,)]"#)
        for file in DesignRulesTests.sources("App/Shared") {
            let text = file.text
            let functions = text.components(separatedBy: "\n    func ").dropFirst()
                + text.components(separatedBy: "\n    private func ").dropFirst()
            for function in functions {
                let ns = function as NSString
                for match in call.matches(in: function, range: NSRange(location: 0, length: ns.length)) {
                    let name = ns.substring(with: match.range(at: 1))
                    let before = ns.substring(to: match.range.location)
                    guard let lastAwait = before.range(of: "await ", options: .backwards) else { continue }
                    let after = before[lastAwait.upperBound...]
                    let declared = try! NSRegularExpression(pattern: #"\b(let|var)\s+\#(name)\b"#)
                    let since = String(after)
                    if declared.firstMatch(in: since, range: NSRange(since.startIndex..., in: since)) == nil {
                        problems.append("\(file.path): update(\(name)) guarda una copia de antes de un await")
                    }
                }
            }
        }
        XCTAssertEqual(problems, [])
        let hardcover = body(of: "private func sendProgress(_ job: Job, client: HardcoverClient) async throws {", in: source("Connectors.swift"))
        XCTAssertTrue(hardcover.contains("if var current = library.book(id: id) {"))
    }

    // MARK: M7 · Lo que cambias mientras ordeno o traigo de Calibre pasa por el mismo índice

    func testEditsDuringLongWorkUseItsIndex() throws {
        let update = body(of: "func update(_ edited: Book, cover newCover: Data? = nil, spelling index: SpellingIndex? = nil) throws -> Book {", in: store)
        XCTAssertTrue(update.contains("let index = index ?? activeSpelling"))
        XCTAssertTrue(body(of: "func tidy() async -> TidyReport {", in: store).contains("activeSpelling = index"))
        XCTAssertTrue(store.contains("activeSpelling = spelling"), "También al traer de Calibre")

        // Por qué: un índice que ya leyó la carpeta no sabe de la que se creó por fuera…
        let root = try tempDir()
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Borges/Ficciones (1)"), withIntermediateDirectories: true)
        let index = SpellingIndex(root: root)
        XCTAssertEqual(index.spelling(of: "borges, jorge luis/x"), "borges, jorge luis/x")
        _ = try FolderMove.moveBookFolder(root.appendingPathComponent("Borges/Ficciones (1)"),
                                          to: root.appendingPathComponent("Borges, Jorge Luis/Ficciones (1)"), index: index)
        // …pero si el cambio pasó por él, lo sabe y no hace una gemela.
        XCTAssertEqual(index.spelling(of: "borges, jorge luis/Ficciones (1)"), "Borges, Jorge Luis/Ficciones (1)")
    }

    // MARK: M8 · La última pasada al mover no traba la app y no deja nada fuera

    func testJournalCopiesWhatWasWrittenDuringTheWalk() throws {
        let base = try tempDir()
        let from = base.appendingPathComponent("viejo/Notas"), to = base.appendingPathComponent("nuevo/Notas")
        try FileManager.default.createDirectory(at: from, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: to.deletingLastPathComponent(), withIntermediateDirectories: true)
        let notes = NoteFolder(url: from)
        let doomed = try notes.save(text: "# Borrar\n")
        try FileManager.default.copyItem(at: from, to: to)
        var copied = FolderCatchUp.snapshot(of: to)

        let journal = WriteJournal()
        let shared = WriteJournal.shared
        shared.begin()
        defer { shared.end() }
        _ = shared.drain()
        let fresh = try notes.save(text: "# Nueva\n")
        try notes.delete(fileName: doomed.fileName)
        try LineFile.append(Data("uno\n".utf8), to: from.appendingPathComponent("registro.jsonl"))
        let written = shared.drain()
        XCTAssertEqual(written.count, 3, "Notas, borrados y registros quedan anotados: \(written)")
        XCTAssertEqual(try FolderCatchUp.copy(written, from: from, to: to, copied: &copied), 3)
        XCTAssertEqual(FolderCatchUp.snapshot(of: to), FolderCatchUp.snapshot(of: from), "La copia queda igual: \(fresh.fileName) llega y la borrada se va")
        XCTAssertEqual(FolderCatchUp.snapshot(of: to).count, 2)
        // Fuera de un movimiento no se anota nada.
        journal.note(from.appendingPathComponent("x"))
        XCTAssertTrue(journal.drain().isEmpty)

        let move = body(of: "func move(toCabinet destination: URL) async throws {", in: store)
        guard let walk = move.range(of: "for folder in catchUp {"), let detached = move.range(of: "Task.detached", options: .backwards, range: move.startIndex..<walk.lowerBound),
              let last = move.range(of: "let written = journal.drain()"), let remember = move.range(of: "CabinetLocation.remember(destination)") else {
            return XCTFail("El recorrido va en segundo plano y lo último copia lo anotado")
        }
        XCTAssertTrue(detached.upperBound <= walk.lowerBound && walk.upperBound <= last.lowerBound && last.upperBound <= remember.lowerBound)
        XCTAssertFalse(move[last.upperBound..<remember.lowerBound].contains("await"), "Nada se cuela entre lo último y el cambio")
        XCTAssertTrue(move[last.upperBound..<remember.lowerBound].contains("FolderCatchUp.copy(written"))
    }

    // MARK: B1 · La tabla de la Mac no salta arriba mientras cambias el ancho

    func testMacTableRelaysOutOnceTheWidthSettles() {
        let table = source("MacBookTable.swift")
        XCTAssertTrue(table.contains(".task(id: widthStep) {") && table.contains("try? await Task.sleep(for: Theme.Mac.relayoutPause)"),
                      "Se rearma cuando el ancho se queda quieto")
        XCTAssertFalse(table.contains(".id(TableLayoutKey(inspector: showsInspector, widthStep: widthStep))"), "No a cada paso")
        XCTAssertTrue(table.contains("rows.first { visibleRows.contains($0.id) }"), "Vuelve a la primera fila que veías")
    }

    // MARK: B3 · Si no pude leer el registro, no se vacía la biblioteca

    func testUnreadableLogKeepsTheLibrary() {
        let apply = body(of: "private func apply(_ changes: [Change]?, notDownloaded: [URL] = []) {", in: store)
        XCTAssertTrue(apply.contains("if let changes { fresh.apply(changes) } else { fresh = state }"))
    }

    // MARK: Pantallas de la auditoría 5

    func testAddingBooksWaitsForICloudEverywhere() {
        // Todo «Añadir libros» pasa por `addBooks()`, que no deja mientras bajo tu biblioteca.
        let model = source("AppModel.swift")
        XCTAssertTrue(body(of: "func addBooks() {", in: model).contains("guard addBooksBlocked == nil else { return }"))
        XCTAssertTrue(model.contains("library.waitingForCloud ? EmptyCopy.addWhileDownloading : nil"))
        var direct: [String] = []
        for file in DesignRulesTests.sources("App/Shared") {
            for (number, line) in file.lines.enumerated() where line.contains("importing = true") || line.contains("importingBooks = true") {
                let allowed = file.path.hasSuffix("AppModel.swift") || line.contains("if model.addBooksBlocked == nil")
                if !allowed { direct.append("\(file.path):\(number + 1)") }
            }
        }
        XCTAssertEqual(direct, [], "Ninguna entrada abre el selector por su cuenta")
        XCTAssertTrue(source("LibraryScreen.swift").contains("if model.addBooksBlocked == nil {"), "El «+» no sale mientras bajo")
        XCTAssertTrue(source("MacBookTable.swift").contains(".disabled(library.waitingForCloud)"))
        XCTAssertTrue(source("LectoraApp.swift").contains(".disabled(model.addBooksBlocked != nil)"), "Archivo › Añadir libros… (⌘O)")
        XCTAssertTrue(source("MacBookTable.swift").contains("guard !urls.isEmpty, model.addBooksBlocked == nil"), "Arrastrar tampoco")
        // Y mientras bajo no digo «0 libros».
        XCTAssertTrue(source("LibraryScreen.swift").contains("if !(model.shelf.isEmpty && model.library.waitingForCloud) {"))
        XCTAssertTrue(source("MacBookTable.swift").contains("library.books.isEmpty && library.waitingForCloud ? nil"))
    }

    func testCloudNoticeHasItsOwnWords() {
        let giveUp = body(of: "private func giveUpOnCloud() {", in: store)
        XCTAssertTrue(giveUp.contains("!books.isEmpty") && giveUp.contains("noticeTitle = Self.cloudGaveUpTitle"),
                      "Sin libros lo dice el vacío; con libros, el aviso tiene su título")
        XCTAssertTrue(source("RootView.swift").contains("noticeAlert(library.noticeTitle"))
        XCTAssertFalse(store.contains("Te enseño lo que ya llegó"), "Dice cuántos llegaron")
    }

    func testDisabledRowsLookDisabled() {
        for name in ["LinkRow", "OptionRow"] {
            let piece = DesignRulesTests.piece(name)
            XCTAssertTrue(piece.contains("@Environment(\\.isEnabled) private var isEnabled")
                          && piece.contains("isEnabled ? Theme.ink : Theme.secondaryInk"), "\(name): apagada se ve apagada")
        }
    }

    func testLibraryWideEditsWaitTheirTurn() {
        for signature in ["func rename(_ rename: CatalogRename) -> CatalogChange {", "func renumber(series: String) -> CatalogChange {"] {
            XCTAssertTrue(body(of: signature, in: store).contains("change.refused = current.reason"), signature)
        }
        XCTAssertTrue(body(of: "func applyRulesToLibrary() -> Int {", in: store).contains("guard lock.current == nil"))
        let sheet = source("MacCatalogSheet.swift")
        XCTAssertTrue(sheet.contains("if let reason = library.busyReason {") && sheet.contains("@ObservedObject var library: LibraryStore"))
        XCTAssertTrue(source("MacDuplicatesView.swift").contains("if let reason = library.busyReason, !groups.isEmpty {"),
                      "El porqué se ve, no solo al pasar el ratón")
        XCTAssertFalse(source("Components.swift").contains("Con varios elegidos, lo que cambies aquí lo aplico a todos."),
                       "Sin nada elegido no hablo de varios")
    }

    func testCloudStatesCanBeSimulated() throws {
        XCTAssertTrue(source("LaunchOptions.swift").contains("forKey: \"screenshot.cloud\""))
        let script = try String(contentsOf: DesignRulesTests.root.appendingPathComponent("scripts/screenshots.sh"), encoding: .utf8)
        XCTAssertTrue(script.contains("-screenshot.cloud downloading"))
    }

    // MARK: Regla 16 · Las reglas están escritas

    func testRulesAreWritten() throws {
        let design = try String(contentsOf: DesignRulesTests.root.appendingPathComponent("docs/sistema-diseno.md"), encoding: .utf8)
        XCTAssertTrue(design.contains("toda salida cierra la pantalla"))
        XCTAssertTrue(design.contains("`testEveryWelcomeExitClosesIt`"))
        let architecture = try String(contentsOf: DesignRulesTests.root.appendingPathComponent("docs/arquitectura.md"), encoding: .utf8)
        XCTAssertTrue(architecture.contains("Lo que guardas se guarda sobre lo de ahora"))
    }
}
