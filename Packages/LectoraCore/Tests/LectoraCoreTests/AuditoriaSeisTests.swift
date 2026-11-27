import Foundation
@testable import LectoraCore
import XCTest

/// Auditoría 6 (27 nov 2026): mientras bajo de iCloud no traigo ni añado libros por ningún lado;
/// mover el Gabinete nunca borra lo de otro aparato; deshacer nunca deja las cosas a medias; la
/// tabla de la Mac no se arma a cada fila ni se corre de lado; las notas conservan sus renglones y
/// sus bloques de código. Cada prueba falla si vuelve.
final class AuditoriaSeisTests: XCTestCase {
    private func tempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("auditoria6-\(UUID().uuidString)")
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
        let ends = ["\n    func ", "\n    private func ", "\n    nonisolated ", "\n    @discardableResult", "\n    static ",
                    "\n    /// "]
            .compactMap { rest.range(of: $0)?.lowerBound }
        return String(rest[..<(ends.min() ?? rest.endIndex)])
    }

    private var store: String { source("LibraryStore.swift") }

    // MARK: A1 · Mientras bajo de iCloud no traigo ni añado libros por ningún lado

    func testNothingComesInWhileDownloading() {
        // La biblioteca misma se niega, con su porqué, aunque algo se lo pida.
        let importFiles = body(of: "func importFiles(_ urls: [URL]) async -> [Result<ImportOutcome, Error>] {", in: store)
        XCTAssertTrue(importFiles.contains("guard !waitingForCloud else { return urls.map { _ in .failure(LibraryError.downloadingFromCloud) } }"))
        XCTAssertTrue(importFiles.contains("if self.waitingForCloud {"), "También si empezó a bajar mientras esperaba su turno")
        let migrate = body(of: "func migrateFromCalibre(", in: store)
        guard let refuse = migrate.range(of: "guard !waitingForCloud else {"), let lock = migrate.range(of: "lock.begin(.migrating)") else {
            return XCTFail("Traer de Calibre se niega mientras bajo")
        }
        XCTAssertTrue(refuse.upperBound <= lock.lowerBound)
        XCTAssertTrue(migrate.contains("reason: EmptyCopy.addWhileDownloading"))
        XCTAssertTrue(store.contains("case .downloadingFromCloud: EmptyCopy.addWhileDownloading"))
        // Toda entrada a Traer de Calibre se apaga y dice por qué.
        var silent: [String] = []
        for file in DesignRulesTests.sources("App/Shared") where file.text.contains("migratingCalibre = true") {
            if !file.text.contains("addBooksBlocked") { silent.append(file.path) }
        }
        XCTAssertEqual(silent, [], "Cada entrada a Calibre sabe que estoy bajando tu biblioteca")
        XCTAssertTrue(source("SettingsScreen.swift").contains(".disabled(busy || model.addBooksBlocked != nil)"))
        let welcome = source("WelcomeScreen.swift")
        XCTAssertTrue(welcome.contains("blocked: model.addBooksBlocked,") && welcome.contains(".disabled(blocked != nil)"))
        let calibre = source("CalibreMigrationScreen.swift")
        XCTAssertTrue(calibre.contains("ChooseStep(blocked: model.addBooksBlocked)"))
        XCTAssertTrue(calibre.contains("busyReason: model.library.busyReason ?? model.addBooksBlocked"), "El plan saldría de una lista a medias")
        XCTAssertTrue(source("Components.swift").contains("para añadir libros o traer los de Calibre."))
    }

    // MARK: M5 · Ningún «Añadir» se queda callado

    func testAddingSaysWhyItWaits() {
        let model = source("AppModel.swift")
        let add = body(of: "func addBooks() {", in: model)
        XCTAssertTrue(add.contains("library.explain(EmptyCopy.addWhileDownloadingTitle, reason)"), "«Seguir leyendo» sin libro también lo dice")
        XCTAssertTrue(body(of: "func continueReading() {", in: model).contains("addBooks()"))
        let library = source("LibraryScreen.swift")
        XCTAssertTrue(library.contains(".disabled(model.addBooksBlocked != nil)") && library.contains("if let blocked = model.addBooksBlocked, !model.shelf.isEmpty {"),
                      "El «+» se ve apagado y con libros a la vista digo por qué")
        XCTAssertTrue(source("MacBookTable.swift").contains("library.explain(EmptyCopy.addWhileDownloadingTitle, reason)"), "Arrastrar también")
    }

    // MARK: U5 y BAJO · Sin libros porque no han bajado: sin «0 libros», filtros ni vista

    func testEmptyCloudLibraryShowsOnlyItsState() {
        let library = source("LibraryScreen.swift")
        XCTAssertTrue(library.contains("model.shelf.isEmpty && (model.library.waitingForCloud || model.library.cloudGaveUp)"))
        XCTAssertEqual(library.components(separatedBy: "if !cloudEmpty {").count - 1, 3, "La vista, los filtros y la cuenta")
        XCTAssertTrue(store.contains("if simulated == \"gaveUp\" { giveUpOnCloud() }"), "La captura enseña el aviso de verdad")
        XCTAssertFalse(store.contains("\"Tu biblioteca no ha bajado de iCloud\""), "El título dice lo mismo que el aviso: algo sí llegó")
    }

    // MARK: A2 y U1 · La tabla de la Mac no se arma a cada fila ni se corre de lado

    func testMacTableDoesNotRebuildPerRow() {
        let table = source("MacBookTable.swift")
        XCTAssertFalse(table.contains("@State private var visibleRows"), "Las filas a la vista no son estado observado")
        XCTAssertTrue(table.contains("final class VisibleRows") && table.contains(".onAppear { visible.ids.insert(row.id) }"))
        XCTAssertTrue(table.contains("final class RowCache") && table.contains("let rows = currentRows()"), "Filtrar y ordenar, solo si algo cambió")
        XCTAssertEqual(table.components(separatedBy: ".sorted(using: sortOrder)").count - 1, 1, "Se ordena en un solo lugar: la caché")
        // La primera fila a la vista se anota antes de rearmar, no después (las celdas ya se fueron).
        guard let anchor = table.range(of: "visible.anchor = currentRows()"), let set = table.range(of: "layout = next") else {
            return XCTFail("Se anota dónde ibas y luego se rearma")
        }
        XCTAssertTrue(anchor.upperBound <= set.lowerBound)
        XCTAssertTrue(table.contains("let firstVisible = visible.anchor"))
        // Abrir la ficha rearma una sola vez: la tabla elige con la ficha ya quieta.
        XCTAssertTrue(table.contains("if tableLayout.inspector {") && !table.contains("if showsInspector {"))
        XCTAssertFalse(table.contains("settledStep"))
        // Volver a donde ibas nunca la corre de lado.
        XCTAssertFalse(table.contains("anchor: .top") || table.contains("anchor: .center") || table.contains(": .center : .top"))
        XCTAssertTrue(table.contains("static let middleLeading = UnitPoint(x: 0, y: 0.5)") && table.contains(".topLeading"))
        // Más angosta que la última vez: los anchos guardados se vuelven a repartir.
        XCTAssertTrue(table.contains("if next.widthStep < savedStep {") && table.contains("Self.keepingVisibility(of: columns)"))
        // Angosta: el título se queda con el espacio.
        XCTAssertEqual(table.components(separatedBy: "roomy ?").count - 1, 3, "Etiquetas, Avance y Agregado piden poco")
    }

    // MARK: M1 · Mover el Gabinete nunca borra lo que llega de otro aparato

    func testStagedMoveNeverTouchesArrivals() throws {
        let destination = try tempDir()
        let staged = StagedMove(destination: destination, folders: ["Biblioteca", "Notas"])
        for folder in ["Biblioteca", "Notas"] {
            try FileManager.default.createDirectory(at: staged.staging(folder), withIntermediateDirectories: true)
            try Data("mío".utf8).write(to: staged.staging(folder).appendingPathComponent("mio.md"))
        }
        XCTAssertEqual(staged.staged("Biblioteca/.lectora").path, staged.staging("Biblioteca").appendingPathComponent(".lectora").path)
        // Mientras copiaba, iCloud bajó las «Notas» de otro aparato.
        let arrived = destination.appendingPathComponent("Notas")
        try FileManager.default.createDirectory(at: arrived, withIntermediateDirectories: true)
        try Data("ajeno".utf8).write(to: arrived.appendingPathComponent("ajena.md"))
        XCTAssertThrowsError(try staged.place()) { error in
            XCTAssertEqual(error as? StagedMove.Failure, .occupied("Notas"))
        }
        staged.discard()
        let exists = { FileManager.default.fileExists(atPath: destination.appendingPathComponent($0).path) }
        XCTAssertTrue(exists("Notas/ajena.md"), "Lo que llegó de otro aparato no se toca")
        XCTAssertFalse(exists("Notas/mio.md"))
        XCTAssertFalse(exists("Biblioteca"), "Lo que ya había puesto regresó y se quitó: queda como estaba")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: destination.path).sorted(), ["Notas"])

        // Sin nadie más, las dos quedan en su lugar.
        let clean = try tempDir()
        let ok = StagedMove(destination: clean, folders: ["Biblioteca", "Notas"])
        for folder in ["Biblioteca", "Notas"] {
            try FileManager.default.createDirectory(at: ok.staging(folder), withIntermediateDirectories: true)
        }
        XCTAssertEqual(try ok.place(), ["Biblioteca", "Notas"])
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: clean.path).sorted(), ["Biblioteca", "Notas"])

        let move = body(of: "func move(toCabinet destination: URL) async throws {", in: store)
        XCTAssertTrue(move.contains("to = staged.staging(folder)") && move.contains("LibraryStore.coordinatedCopy(from: from, to: to)"),
                      "Se copia a la carpeta de trabajo")
        XCTAssertTrue(move.contains("to = staged.staged(folder)"), "Los repasos también van a la de trabajo")
        XCTAssertTrue(move.contains("placed = try staged.place()") && move.contains("staged.takeBack(placed)") && move.contains("staged.discard()"))
        XCTAssertFalse(move.contains("let created"), "Ya no se borra lo que no estaba al empezar")
        guard let place = move.range(of: "placed = try staged.place()"), let remember = move.range(of: "CabinetLocation.remember(destination)"),
              let last = move.range(of: "let written = journal.drain()") else { return XCTFail("Al final se pone en su lugar") }
        XCTAssertTrue(last.upperBound <= place.lowerBound && place.upperBound <= remember.lowerBound)
        XCTAssertFalse(move[last.upperBound..<remember.lowerBound].contains("await"))
    }

    // MARK: B3 · La copia se comprueba ni de menos ni de más

    func testCopyCheckSeesExtras() throws {
        let base = try tempDir()
        let from = base.appendingPathComponent("origen"), to = base.appendingPathComponent("copia")
        try FileManager.default.createDirectory(at: from, withIntermediateDirectories: true)
        try Data("a".utf8).write(to: from.appendingPathComponent("a.md"))
        try FileManager.default.copyItem(at: from, to: to)
        try Data("de más".utf8).write(to: to.appendingPathComponent("sobra.md"))
        // En una copia que es toda de esta corrida, lo que sobra se quita y la cuenta cuadra.
        let pass = try FolderCatchUp.sync(from: from, to: to, since: .distantFuture)
        XCTAssertEqual(pass.extra, 0)
        XCTAssertTrue(pass.isComplete)
        // Si algo sobra y no es suyo, la cuenta lo ve: ya no es exacta.
        try Data("ajeno".utf8).write(to: to.appendingPathComponent("ajeno.md"))
        var mine: Set<String> = ["a.md"]
        let other = try FolderCatchUp.sync(from: from, to: to, since: .distantFuture, copied: &mine)
        XCTAssertEqual(other.extra, 1)
        XCTAssertFalse(other.isComplete)
        XCTAssertFalse(store.contains("// Exacta: ni de menos ni de más."), "El comentario decía más de lo que se comprobaba")
    }

    // MARK: M2 · Lo que no guardé por un trabajo largo dice «espera» y se repite al terminar

    func testBusyLookupIsNotOfflineAndRetries() {
        var progress = BatchLookup.Progress(total: 2)
        progress.record(.busy)
        XCTAssertEqual(progress.pending, 1, "Ocupado queda pendiente, no hecho")
        XCTAssertEqual(progress.done, 0)
        let identify = body(of: "func identify(_ bookID: UUID, askAlways: Bool = false) async -> MetadataService.Decision? {", in: store)
        guard let busy = identify.range(of: "catch LibraryError.busy {") else { return XCTFail("identify distingue «ocupado»") }
        XCTAssertTrue(identify[busy.upperBound...].prefix(500).contains("return .busy"))
        XCTAssertEqual(identify.components(separatedBy: "return .unreachable").count - 1, 1, "Solo sin internet es «sin conexión»")
        let release = body(of: "private func releaseLock(_ work: LibraryWork) {", in: store)
        XCTAssertTrue(release.contains("await self?.retryPendingLookups()"), "Al terminar, se busca de nuevo")
        XCTAssertTrue(body(of: "func retryPendingLookups() async {", in: store).contains("decision == .busy"))
        let review = source("ReviewScreen.swift")
        XCTAssertTrue(review.contains("busyReason = decision == .busy") && review.contains("En cuanto termine, lo vuelvo a buscar solo."))
    }

    // MARK: M3 · Deshacer nunca deja las cosas a medias

    func testRevertTouchesOnlyWhatTheChangeDid() {
        let original = Book(title: "Ficciones", authors: ["Borges"], series: "Obras", seriesIndex: 3, tags: ["cuento"])
        var changed = original
        changed.authors = ["Jorge Luis Borges"]
        changed.seriesIndex = 1
        // Después del cambio: le pusiste valoración y corregiste el número de tomo a mano.
        var current = changed
        current.rating = 4
        current.seriesIndex = 2
        current.title = "Ficciones (1944)"
        let reverted = Book.revertingEdits(to: original, from: changed, onto: current)
        XCTAssertEqual(reverted.authors, ["Borges"], "Lo que el cambio tocó y sigue igual regresa")
        XCTAssertEqual(reverted.seriesIndex, 2, "Lo que cambiaste después en ese dato se queda")
        XCTAssertEqual(reverted.rating, 4, "Y lo demás que cambiaste, también")
        XCTAssertEqual(reverted.title, "Ficciones (1944)")

        let restore = body(of: "func restore(_ change: CatalogChange) -> String? {", in: store)
        guard let check = restore.range(of: "if let current = lock.current { return current.reason }"),
              let first = restore.range(of: "update(") ?? restore.range(of: "saveRules(") else {
            return XCTFail("Deshacer mira el candado antes de tocar nada")
        }
        XCTAssertTrue(check.upperBound <= first.lowerBound)
        XCTAssertTrue(restore.contains("Book.revertingEdits(to: original, from: changed, onto: current)"))
        XCTAssertFalse(restore.contains("try? update(original)"), "Ya no se escribe el libro viejo entero encima")
        for signature in ["func rename(_ rename: CatalogRename) -> CatalogChange {", "func renumber(series: String) -> CatalogChange {"] {
            XCTAssertTrue(body(of: signature, in: store).contains("change.changed.append(try update("), signature)
        }
        // El ⌘Z rechazado se queda para después.
        let window = source("MacLibraryWindow.swift")
        let register = body(of: "func registerUndo(_ change: CatalogChange, named name: String, in undoManager: UndoManager?) {", in: window)
        XCTAssertTrue(register.contains("guard let refused = store.restore(change) else { return }")
                      && register.contains("store.registerUndo(change, named: name, in: undoManager)"))
        XCTAssertFalse(source("MacCatalogSheet.swift").contains("store.restore(change)"), "Las dos entradas usan el mismo deshacer")
        XCTAssertFalse(window.contains("MainActor.assumeIsolated { store.restore(change) }"))
    }

    // MARK: B4 · Deshacer una portada mientras muevo no la borra antes de fallar

    func testUndoCoverChecksTheLockFirst() {
        let undo = body(of: "func undoFilled(_ field: FilledField, for bookID: UUID) throws {", in: store)
        guard let check = undo.range(of: "try ensureCanEdit()"), let remove = undo.range(of: "removeItem(at: url)") else {
            return XCTFail("Se mira el candado antes de quitar la portada")
        }
        XCTAssertTrue(check.upperBound <= remove.lowerBound)
    }

    // MARK: M4 · Lo que no hice, te digo por qué

    func testRefusalsAreSaid() {
        let window = source("MacLibraryWindow.swift")
        let renumber = body(of: "private func renumber(_ series: String) {", in: window)
        XCTAssertTrue(renumber.contains("if let refused = change.refused {") && renumber.contains("library.explain(\"No renumeré los tomos\", refused)"))
        XCTAssertTrue(window.contains("library.explain(\"No renombré el autor\", refused)"), "El renombre de las capturas tampoco se calla")
        var silent: [String] = []
        for file in DesignRulesTests.sources("App/Shared") {
            for (number, line) in file.lines.enumerated()
            where (line.contains("library.renumber(series:") || line.contains("library.rename(CatalogRename")) && !line.contains("let ") && !line.contains("if let") {
                silent.append("\(file.path):\(number + 1)")
            }
        }
        XCTAssertEqual(silent, [], "Nadie tira la respuesta: si dice que no, se dice por qué")
    }

    // MARK: M6 · Quitar una carpeta vacía pone al día el índice

    func testRemovingAnEmptyFolderUpdatesTheIndex() throws {
        let root = try tempDir()
        let author = root.appendingPathComponent("Borges")
        try FileManager.default.createDirectory(at: author, withIntermediateDirectories: true)
        let index = SpellingIndex(root: root)
        XCTAssertEqual(index.matches("borges", in: root), ["Borges"])
        FolderMove.removeIfEmpty(author, index: index)
        XCTAssertFalse(FileManager.default.fileExists(atPath: author.path))
        XCTAssertEqual(index.matches("borges", in: root), [], "El índice ya no ve la carpeta quitada")
        XCTAssertEqual(index.listings(of: root), 1, "Sin volver a leer la carpeta entera")
        XCTAssertTrue(store.contains("FolderMove.removeIfEmpty(newFolder.deletingLastPathComponent(), index: index)"))
        XCTAssertTrue(store.contains("FolderMove.removeIfEmpty(to.deletingLastPathComponent(), index: spelling)"))
    }

    // MARK: B1 · Renglones mezclados: cada uno con su final

    func testMixedLineEndingsKeepTheirOwn() {
        let marker = NoteMarkdown.sessionMarker(UUID())
        let text = "# Lectura\r\n\(marker)\nUno\r\nDos\nTres"
        let editable = NoteMarkdown.editable(text)
        XCTAssertEqual(editable.text, "# Lectura\r\nUno\r\nDos\nTres", "Cada renglón conserva su final")
        XCTAssertEqual(NoteMarkdown.savedText(editable.text, restoring: editable.comments), "# Lectura\r\n\(marker)\r\nUno\r\nDos\nTres")
        XCTAssertEqual(NoteMarkdown.searchText("A\r\n<!-- x -->\nB\nC"), "A\r\nB\nC")
        XCTAssertEqual(NoteMarkdown.restoringComments([marker], in: "# Solo"), "# Solo\n\(marker)", "Sin final, el de siempre")
        XCTAssertEqual(NoteMarkdown.appendingParagraph("Mi nota", to: "# Uno\r\n\r\n> cita\r\n"), "# Uno\r\n\r\n> cita\r\n\r\nMi nota\r\n",
                       "La nota de un subrayado lleva el final de la nota")
        XCTAssertTrue(source("NotesStore.swift").contains("NoteMarkdown.appendingParagraph(note, to: text)"))
        XCTAssertFalse(source("NotesStore.swift").contains("text += \"\\n\""))
    }

    // MARK: U2 y U3 · Los bloques de código se leen como código y no se ven en las vistas previas

    func testCodeBlocksKeepTheirLines() {
        let text = "# Ideas\n```swift\nlet a = 1\n\n  let b = 2\n```\nDespués"
        XCTAssertEqual(NoteMarkdown.blocks(text), [.heading("Ideas"), .code("let a = 1\n\n  let b = 2"), .paragraph("Después")])
        // Lo que parece título o cita dentro del bloque es código.
        XCTAssertEqual(NoteMarkdown.blocks("~~~\n# no\n> tampoco\n~~~"), [.code("# no\n> tampoco")])
        // Sin cerrar, llega hasta el final.
        XCTAssertEqual(NoteMarkdown.blocks("Uno\n````\ncódigo"), [.paragraph("Uno"), .code("código")])
        let note = Note(fileName: "ideas.md", text: "# Ideas\n```\ncódigo\n```\n- uno\n2. dos\n- [x] tres\nUsa `git`")
        XCTAssertEqual(note.preview, "código uno dos tres Usa git", "Sin cercas, guiones, números ni casillas")
        let components = source("Components.swift")
        XCTAssertTrue(components.contains("case .code(let code):") && components.contains(".font(.code)"))
        XCTAssertTrue(source("Theme.swift").contains("static let code = Font.system(.callout, design: .monospaced)"))
    }

    // MARK: BAJO de pantallas

    func testSmallScreenFixes() {
        XCTAssertTrue(DesignRulesTests.piece("SectionHeader").contains("if typeSize.isAccessibilitySize {"), "Con AX5 la raya va debajo")
        XCTAssertFalse(source("Components.swift").contains("\"Elige uno en la tabla"), "«Elige» no se repite")
        XCTAssertTrue(source("RulesScreen.swift").contains("\"Cambié \\(count.counted(\"libro\", \"libros\"))."))
        XCTAssertTrue(source("MacBookInspector.swift").contains(".macPaper()"), "La ficha de la Mac es de papel")
    }

    // MARK: B5 · Ninguna prueba mide el reloj con un tope apretado

    func testNoTightWallClockAsserts() throws {
        var tight: [String] = []
        let pattern = try NSRegularExpression(pattern: #"timeIntervalSince\(\w+\),\s*(\d+(?:\.\d+)?)"#)
        let tests = DesignRulesTests.root.appendingPathComponent("Packages/LectoraCore/Tests/LectoraCoreTests")
        for name in try FileManager.default.contentsOfDirectory(atPath: tests.path) where name.hasSuffix(".swift") {
            let text = try String(contentsOf: tests.appendingPathComponent(name), encoding: .utf8)
            for match in pattern.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                let limit = Double((text as NSString).substring(with: match.range(at: 1))) ?? 0
                if limit < 10 { tight.append("\(name): \(limit) s") }
            }
        }
        XCTAssertEqual(tight, [], "Cuenta el trabajo (lo leído, lo escrito), no los segundos: en una Mac ocupada falla")
    }

    // MARK: Regla 16 · Las reglas están escritas

    func testRulesAreWritten() throws {
        let design = try String(contentsOf: DesignRulesTests.root.appendingPathComponent("docs/sistema-diseno.md"), encoding: .utf8)
        XCTAssertTrue(design.contains("no traigo ni añado libros por ningún lado") && design.contains("`testNothingComesInWhileDownloading`"))
        let architecture = try String(contentsOf: DesignRulesTests.root.appendingPathComponent("docs/arquitectura.md"), encoding: .utf8)
        XCTAssertTrue(architecture.contains("Deshacer tampoco deja las cosas a medias"))
        XCTAssertTrue(architecture.contains("`StagedMove`"))
    }
}
