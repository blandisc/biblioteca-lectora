import Foundation
@testable import LectoraCore
import XCTest

/// Auditoría 9 (27 nov 2026), código: traer de Calibre o añadir un libro nunca borra la carpeta que
/// llegó de otro aparato; una búsqueda en curso no escribe en el Gabinete nuevo; una nota no queda
/// junto a su gemela en mayúsculas; un estante es el mismo en cualquier orden; lo de dentro de un
/// bloque de código no es título. Cada prueba falla si vuelve.
final class AuditoriaNueveTests: XCTestCase {
    private func tempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("auditoria9-\(UUID().uuidString)")
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

    private func text(_ url: URL) -> String? {
        (try? Data(contentsOf: url)).map { String(decoding: $0, as: UTF8.self) }
    }

    // MARK: M1 · Nunca borro una carpeta que no puse yo

    func testNewFolderNeverReplacesOrRemovesOneThatArrives() throws {
        let manager = FileManager.default
        let author = try tempDir().appendingPathComponent("Julio Cortázar")
        try manager.createDirectory(at: author, withIntermediateDirectories: true)
        let target = author.appendingPathComponent("Rayuela (1)")

        // Mientras copio, iCloud baja la carpeta de otro aparato con ese nombre.
        XCTAssertThrowsError(try FolderMove.placeNew(target) { work in
            try manager.createDirectory(at: work, withIntermediateDirectories: false)
            try Data("mío".utf8).write(to: work.appendingPathComponent("libro.epub"))
            try manager.createDirectory(at: target, withIntermediateDirectories: false)
            try Data("del otro aparato".utf8).write(to: target.appendingPathComponent("libro.epub"))
        }) { XCTAssertEqual($0 as? FolderMove.MoveError, .occupied) }
        XCTAssertEqual(text(target.appendingPathComponent("libro.epub")), "del otro aparato", "La de otro aparato se queda como estaba")
        XCTAssertEqual(try manager.contentsOfDirectory(atPath: author.path), ["Rayuela (1)"], "Sin carpeta de trabajo de sobra")

        // Falla a media copia: solo se quita la de trabajo.
        let other = author.appendingPathComponent("Bestiario (2)")
        XCTAssertThrowsError(try FolderMove.placeNew(other) { work in
            try manager.createDirectory(at: work, withIntermediateDirectories: false)
            throw CocoaError(.fileWriteUnknown)
        })
        XCTAssertFalse(manager.fileExists(atPath: other.path))
        XCTAssertEqual(try manager.contentsOfDirectory(atPath: author.path), ["Rayuela (1)"])

        // Ya ocupada antes de empezar: ni se arma.
        var filled = false
        XCTAssertThrowsError(try FolderMove.placeNew(target) { _ in filled = true })
        XCTAssertFalse(filled)

        // Bien: queda en su lugar con lo que armé.
        try FolderMove.placeNew(other, empty: true) { work in
            try Data("mío".utf8).write(to: work.appendingPathComponent("libro.epub"))
        }
        XCTAssertEqual(text(other.appendingPathComponent("libro.epub")), "mío")
        XCTAssertEqual(try manager.contentsOfDirectory(atPath: author.path).sorted(), ["Bestiario (2)", "Rayuela (1)"])
    }

    /// Pantallas 9, punto 6: si la app se cierra a media copia, la carpeta de trabajo de un libro
    /// nuevo no se queda para siempre. Solo se va la de nombre exacto, vieja y sin trabajo en curso;
    /// lo demás se queda, y la escondida nunca cuenta como libro suelto al ordenar.
    func testNewFolderLeftoversGoAway() throws {
        let manager = FileManager.default
        let library = try tempDir()
        let author = library.appendingPathComponent("Julio Cortázar")
        let lonely = library.appendingPathComponent("Clarice Lispector")
        try manager.createDirectory(at: author.appendingPathComponent("Rayuela (1)"), withIntermediateDirectories: true)
        try manager.createDirectory(at: lonely, withIntermediateDirectories: true)
        let old = Date().addingTimeInterval(-2 * FolderMove.newLeftoverAge)
        func work(_ folder: URL, _ name: String, age: Date?) throws -> URL {
            let url = folder.appendingPathComponent(name)
            try manager.createDirectory(at: url, withIntermediateDirectories: false)
            let file = url.appendingPathComponent("libro.epub")
            try Data("a medias".utf8).write(to: file)
            if let age {
                for item in [file, url] {
                    try manager.setAttributes([.creationDate: age, .modificationDate: age], ofItemAtPath: item.path)
                }
            }
            return url
        }
        let stale = FolderMove.newPrefix + UUID().uuidString
        let staleAlone = FolderMove.newPrefix + UUID().uuidString
        let fresh = FolderMove.newPrefix + UUID().uuidString
        _ = try work(author, stale, age: old)
        _ = try work(lonely, staleAlone, age: old)
        _ = try work(author, fresh, age: nil)
        _ = try work(author, FolderMove.newPrefix + "nada", age: old)
        _ = try work(library, stale, age: old)

        // Mientras un trabajo de toda la biblioteca corre, nada se toca.
        XCTAssertEqual(FolderMove.removeNewLeftovers(in: library, busy: true), [])
        XCTAssertTrue(manager.fileExists(atPath: author.appendingPathComponent(stale).path))

        let removed = FolderMove.removeNewLeftovers(in: library, busy: false)
        XCTAssertEqual(Set(removed), [stale, "Julio Cortázar/\(stale)", "Clarice Lispector/\(staleAlone)"])
        let left = Set(try manager.contentsOfDirectory(atPath: author.path))
        XCTAssertEqual(left, ["Rayuela (1)", fresh, FolderMove.newPrefix + "nada"],
                       "La reciente (una copia que sigue), la de otro nombre y el libro se quedan")
        XCTAssertFalse(manager.fileExists(atPath: lonely.path), "La carpeta de autor que quedó vacía también se va")

        // Al ordenar, una carpeta escondida no es un libro suelto.
        XCTAssertTrue(store.contains("title.hasDirectoryPath && !title.lastPathComponent.hasPrefix(\".\")"))
        XCTAssertTrue(store.contains("FolderMove.removeNewLeftovers(in: library, busy: busy)"), "Se limpia al abrir la biblioteca")
    }

    func testCalibreAndAddBookOnlyRemoveWhatTheyPlaced() {
        let migrate = body(of: "func migrateFromCalibre(", in: store)
        XCTAssertTrue(migrate.contains("FolderMove.placeNew(target)"), "Traer de Calibre copia a una carpeta de trabajo")
        XCTAssertFalse(migrate.contains("copyItem(at: from, to: to)"), "Nunca directo al destino")
        XCTAssertTrue(migrate.contains("if placed { try? FileManager.default.removeItem(at: to) }"))
        XCTAssertTrue(migrate.contains("catch FolderMove.MoveError.occupied where attempt < Self.placeAttempts"),
                      "Si se ocupa, el siguiente número libre")
        XCTAssertTrue(migrate.contains("Self.calibreFolderTaken"), "Y si no, el libro se reporta como no traído")
        let add = body(of: "func importFile(", in: store)
        XCTAssertTrue(add.contains("FolderMove.placeNew(folderURL, empty: true)"), "Añadir un libro, igual")
        XCTAssertTrue(add.contains("if placed { try? FileManager.default.removeItem(at: folderURL) }"))
    }

    /// Regla 16: en ningún `catch` se borra algo que quizá no es de esta corrida. Solo se quita lo de
    /// trabajo (`staging`, `work`) o lo que lleva su marca (`mine`); lo demás, con su bandera.
    func testNoCatchRemovesWhatMightNotBeMine() throws {
        let pattern = try NSRegularExpression(
            pattern: #"catch[^{\n]*\{\n(?:[ \t]*//[^\n]*\n)*[ \t]*try\? FileManager\.default\.removeItem\(at: (\w+)"#)
        var found: [String] = []
        for file in DesignRulesTests.sources("App/Shared") + DesignRulesTests.sources("Packages/LectoraCore/Sources") {
            let range = NSRange(file.text.startIndex..., in: file.text)
            for match in pattern.matches(in: file.text, range: range) {
                guard let name = Range(match.range(at: 1), in: file.text).map({ String(file.text[$0]) }) else { continue }
                if !["staging", "work", "mine"].contains(name) { found.append("\(file.path): removeItem(at: \(name))") }
            }
        }
        XCTAssertEqual(found, [], "Un catch borra algo que pudo llegar de otro aparato: bórralo solo si lo pusiste tú")
    }

    // MARK: M3 · Una búsqueda en curso no escribe en el Gabinete nuevo

    func testSearchInFlightDoesNotWriteIntoTheNewCabinet() {
        let open = body(of: "private func open(cabinet: URL) {", in: store)
        XCTAssertTrue(open.contains("haltBatch()"), "Abrir otro Gabinete detiene el lote")
        let identify = body(of: "func identify(_ bookID: UUID, askAlways: Bool = false) async", in: store)
        guard let guardLine = identify.range(of: "guard stillHere(bookID, in: cabinet) else { return nil }"),
              let firstWrite = identify.range(of: "setPending(") else {
            return XCTFail("identify: al volver de internet mira que sea el mismo Gabinete y que el libro siga")
        }
        XCTAssertTrue(guardLine.upperBound <= firstWrite.lowerBound, "Antes de escribir «por buscar» o «por revisar»")
        XCTAssertEqual(identify.components(separatedBy: "guard stillHere(bookID, in: cabinet)").count - 1, 2,
                       "También después de bajar la portada")
        XCTAssertTrue(store.contains("root == cabinet && book(id: bookID) != nil"))
        // Lo mismo en las demás búsquedas que vuelven de internet (regla 16).
        XCTAssertTrue(body(of: "func search(title: String", in: store).contains("guard stillHere(bookID, in: cabinet)"))
        XCTAssertTrue(body(of: "func apply(_ candidate: MetadataCandidate", in: store).contains("guard stillHere(bookID, in: cabinet)"))
        XCTAssertTrue(body(of: "func setCover(_ url: URL", in: store).contains("stillHere(bookID, in: cabinet)"))
    }

    // MARK: M4 · Una nota nunca queda junto a su gemela en mayúsculas

    func testFreeNoteNameIgnoresCaseAndUnicodeForms() {
        // La lista de la carpeta, como la leería un iPhone (que distingue mayúsculas).
        let taken: Set<String> = Set(["Ideas", "Canción"].map(NoteFolder.nameKey))
        XCTAssertEqual(NoteFolder.freeName("ideas", taken: taken), "ideas 2")
        XCTAssertEqual(NoteFolder.freeName("IDEAS", taken: taken), "IDEAS 2")
        // «Canción» con la tilde aparte (NFD) es la misma que con la letra con tilde (NFC).
        let decomposed = "Canción".decomposedStringWithCanonicalMapping
        XCTAssertNotEqual(Array(decomposed.unicodeScalars), Array("Canción".precomposedStringWithCanonicalMapping.unicodeScalars))
        XCTAssertEqual(NoteFolder.freeName(decomposed, taken: taken), decomposed + " 2")
        XCTAssertEqual(NoteFolder.freeName("Otra", taken: taken), "Otra")
    }

    func testNoteNamesCountPlaceholdersInAnyCase() throws {
        let folder = NoteFolder(url: try tempDir())
        try Data().write(to: folder.url.appendingPathComponent(".IDEAS.md.icloud"))
        try Data("x".utf8).write(to: folder.url.appendingPathComponent("Rulfo.md"))
        XCTAssertEqual(folder.takenNames(), ["ideas", "rulfo"])
        XCTAssertEqual(try folder.save(text: "# ideas").fileName, "ideas 2", "La que sigue en iCloud también cuenta")
        let renamed = try folder.save(text: "# rulfo\notra", fileName: "ideas 2")
        XCTAssertEqual(renamed.fileName, "rulfo 2")
    }

    func testNoteNamesOnACaseSensitiveDisk() throws {
        guard let path = ProcessInfo.processInfo.environment["LECTORA_CASE_SENSITIVE_DIR"] else {
            throw XCTSkip("Sin disco sensible a mayúsculas (LECTORA_CASE_SENSITIVE_DIR)")
        }
        let url = URL(fileURLWithPath: path).appendingPathComponent("notas-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        let folder = NoteFolder(url: url)
        try folder.save(text: "# Ideas")
        XCTAssertEqual(try folder.save(text: "# ideas").fileName, "ideas 2", "No «ideas.md» junto a «Ideas.md»")
        try folder.save(text: "# Otra")
        XCTAssertEqual(try folder.save(text: "# IDEAS", fileName: "Otra").fileName, "IDEAS 3")
        let names = try FileManager.default.contentsOfDirectory(atPath: url.path).map { $0.lowercased() }
        XCTAssertEqual(names.count, Set(names).count, "Ninguna gemela en mayúsculas")
    }

    // MARK: B2 · Doce portadas distintas, sin esperar a todas

    func testCoverLimitCountsAfterRemovingRepeats() {
        let url = { (n: Int) in URL(string: "https://covers.openlibrary.org/b/id/\(n)-L.jpg")! }
        var collector = CoverDedupe.Collector(limit: 3, current: Data("actual".utf8))
        XCTAssertFalse(collector.accept(url(1), Data("actual".utf8), rank: 0), "La que ya tiene no cuenta")
        XCTAssertTrue(collector.accept(url(3), Data("c".utf8), rank: 3), "La que baja primero se enseña ya")
        XCTAssertFalse(collector.accept(url(4), Data("c".utf8), rank: 4), "Bytes repetidos no cuentan")
        XCTAssertFalse(collector.accept(url(5), nil, rank: 5), "La que no bajó tampoco")
        XCTAssertTrue(collector.accept(url(2), Data("b".utf8), rank: 2))
        XCTAssertFalse(collector.isFull, "Las repetidas no llenan el tope")
        XCTAssertTrue(collector.accept(url(6), Data("f".utf8), rank: 6))
        XCTAssertTrue(collector.isFull)
        XCTAssertFalse(collector.accept(url(7), Data("g".utf8), rank: 7))
        XCTAssertEqual(collector.accepted.map(\.url), [url(2), url(3), url(6)], "En su orden de preferencia")

        let options = body(of: "func coverOptions(for bookID: UUID, found:", in: store)
        XCTAssertTrue(options.contains("prefix(Theme.Lists.coverDownloads)"), "Bajo más que 12 para llegar a 12 distintas")
        XCTAssertTrue(options.contains("CoverDedupe.Collector(limit: Theme.Lists.coverOptions"))
        XCTAssertTrue(options.contains("CoverImaging.remember(data, for: url)"), "Lo bajado se pasa a la cuadrícula")
        XCTAssertTrue(body(of: "func setCover(_ url: URL", in: store).contains("CoverImaging.remembered(url)"),
                      "Y no se baja otra vez al elegirla")
    }

    // MARK: B6 · Un estante es el mismo en cualquier orden

    func testSavedShelfIgnoresOrder() {
        let shelf = SavedShelf(name: "Historia en inglés", query: "historia idioma:en")
        XCTAssertEqual(SavedShelf.saved("idioma:en historia", in: [shelf]), shelf)
        XCTAssertEqual(SavedShelf.saved("  IDIOMA:en   Historia ", in: [shelf]), shelf)
        let two = SavedShelf(name: "Dos", query: "etiqueta:viaje autor:cortázar")
        XCTAssertEqual(SavedShelf.saved("autor:cortazar etiqueta:viaje", in: [two]), two)
        XCTAssertNil(SavedShelf.saved("idioma:es historia", in: [shelf]))
        XCTAssertNil(SavedShelf.saved("historia", in: [shelf]))
    }

    // MARK: B8 · Lo de dentro de un bloque de código no es título

    func testTitleSkipsTheWholeFencedBlock() {
        XCTAssertEqual(Note.title(of: "```swift\nlet a = 1\n```\n# Mis ideas\nTexto"), "Mis ideas")
        XCTAssertEqual(Note.title(of: "````\n```\nno\n````\nSí"), "Sí", "Un «```» no cierra un bloque de «````»")
        XCTAssertNil(Note.title(of: "```\nsolo código\n```"))
        XCTAssertEqual(Note(fileName: "Mi nota", text: "```\nsolo código\n```").title, "Mi nota", "Sin texto fuera, el de siempre")
        XCTAssertNil(Note.title(of: "```\nsin cerrar\nnunca"))
        XCTAssertEqual(Note(fileName: "x", text: "```\nlet a = 1\n```\nIdeas\nDespués").preview, "Después",
                       "La vista previa empieza después del título")
    }

    // MARK: Lo demás: B1, B5, B7, B9, B10

    func testSmallerFixes() {
        // B1: el libro que cambió de carpeta mientras bajaba se abre de su carpeta de ahora.
        let reader = source("ReaderView.swift", in: "App/Shared/Reader")
        guard let wait = reader.range(of: "await CloudFiles.ensureDownloaded(file)"),
              let reread = reader.range(of: "let now = currentFile ?? bookFile") else {
            return XCTFail("ReaderView: vuelve a leer el archivo después de bajarlo")
        }
        XCTAssertTrue(wait.upperBound <= reread.lowerBound)

        // B5: «Ordenar» que no ordenó dice por qué.
        let tidy = body(of: "func tidy() async -> TidyReport {", in: store)
        XCTAssertTrue(tidy.contains("report.notDone = EmptyCopy.tidyWhileDownloading"))
        XCTAssertTrue(tidy.components(separatedBy: "tidyReport = report").count - 1 >= 2, "Y la pantalla lo enseña")
        XCTAssertTrue(source("SettingsScreen.swift", in: "App/Shared/Screens").contains("if let notDone = report.notDone { return notDone }"))

        // B7: detener el lote a mano deja retomar lo pendiente.
        let stop = body(of: "func stopBatch() {", in: store)
        XCTAssertTrue(stop.contains("haltBatch()") && stop.contains("await self?.retryPendingLookups()"))
        XCTAssertTrue(body(of: "func move(toCabinet destination: URL)", in: store).contains("haltBatch()"),
                      "Mover el Gabinete detiene sin retomar")

        // B9: solo cuenta los subrayados que sí se guardaron.
        XCTAssertTrue(store.contains("if saved { report.annotations += 1 }"))
        XCTAssertFalse(store.contains("report.annotations += 1\n                }"), "Nada de contar a ciegas")

        // B10: con iCloud a medias, traer de Calibre se puede, pero lo digo antes.
        let calibre = source("CalibreMigrationScreen.swift", in: "App/Shared/Screens")
        XCTAssertTrue(calibre.contains("cloudIncomplete: model.library.cloudGaveUp"))
        XCTAssertTrue(calibre.contains("ReasonLine(EmptyCopy.calibreWhileCloudIncomplete)"))
        XCTAssertFalse(calibre.contains(".disabled(busyReason != nil || cloudIncomplete)"), "No se bloquea")
        XCTAssertTrue(source("Components.swift", in: "App/Shared/Design")
            .contains("Parte de tu biblioteca no ha bajado de iCloud; podría traer libros que ya tienes. Luego los juntas en Duplicados."))
    }
}
