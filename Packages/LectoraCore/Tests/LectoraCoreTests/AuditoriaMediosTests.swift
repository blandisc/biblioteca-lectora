import Foundation
@testable import LectoraCore
import XCTest

/// Auditoría de medios y bajos de datos (27 nov 2026). Cada prueba falla si vuelve.
final class AuditoriaMediosTests: XCTestCase {
    private func tempDir(in base: URL = FileManager.default.temporaryDirectory) throws -> URL {
        let url = base.appendingPathComponent("medios-\(UUID().uuidString)")
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
        let end = rest.range(of: "\n    func ") ?? rest.range(of: "\n    private func ")
        return String(rest[..<(end?.lowerBound ?? rest.endIndex)])
    }

    // MARK: 1 · Cerrar el libro justo después de pasar de página no pierde la posición

    func testPositionIsSavedWhenLeaving() {
        let view = source("App/Shared/Reader", "ReaderView.swift")
        let controller = source("App/Shared/Reader", "ReaderController.swift")
        XCTAssertTrue(controller.contains("func flushPosition()"), "El lector guarda ya la posición que esperaba")
        XCTAssertTrue(controller.contains("self?.flushPosition()"), "Al asentarse, la posición sale por el mismo camino")
        let disappear = view.components(separatedBy: ".onDisappear {").dropFirst().first ?? ""
        XCTAssertTrue(disappear.prefix(120).contains("controller.flushPosition()"), "Al cerrar el libro se guarda la posición")
        let phase = view.components(separatedBy: ".onChange(of: scenePhase)").dropFirst().first ?? ""
        XCTAssertTrue(phase.prefix(400).contains("controller.flushPosition()"), "Al salir de la app se guarda la posición")
    }

    // MARK: 2 · Traer de iCloud no tira lo que guardaste mientras se leía

    func testWritesDuringReadAreReapplied() {
        let clock = HybridLogicalClock(node: "iphone")
        let book = UUID()
        let old = Change(hlc: clock.tick(), entity: .book, entityID: book, field: "title", value: .string("Rayuela"))
        var writes = WritesDuringRead()
        let before = Change(hlc: clock.tick(), entity: .book, entityID: book, field: "rating", value: .number(3))
        writes.note([before])
        let token = writes.begin()
        // Mientras se lee el registro (en segundo plano), cambias la valoración.
        let during = Change(hlc: clock.tick(), entity: .book, entityID: book, field: "rating", value: .number(5))
        writes.note([during])
        let stale = [old, before]
        var state = LibraryState()
        state.apply(stale + writes.end(token))
        XCTAssertEqual(state.fields(of: .book, id: book)?["rating"], .number(5), "Lo que guardaste durante la lectura se queda")
        XCTAssertEqual(writes.end(token), [], "Al terminar, la lectura ya no guarda nada")
        writes.note([during])
        XCTAssertEqual(writes.end(token), [])

        let store = source("App/Shared/Library", "LibraryStore.swift")
        XCTAssertTrue(store.contains("writesDuringRead.begin()") && store.contains("writesDuringRead.end(token)"))
        XCTAssertEqual(store.components(separatedBy: "log.append(").count - 1, 1,
                       "Todo lo que escribe la biblioteca pasa por appendToLog (lo anota para las lecturas en curso)")
    }

    // MARK: 3 · Otra obra con el mismo título y un subtítulo no se completa sola

    private func candidate(_ title: String, subtitle: String? = nil, work: String? = nil, author: String) -> MetadataCandidate {
        var candidate = MetadataCandidate(id: title + (subtitle ?? ""), source: .openLibrary, title: title, subtitle: subtitle,
                                          authors: [author])
        candidate.workTitle = work
        return candidate
    }

    func testOtherWorkWithSubtitleIsNotAutoApplied() {
        let sapiens = Book(title: "Sapiens", authors: ["Yuval Noah Harari"])
        let hunger = Book(title: "Los juegos del hambre", authors: ["Suzanne Collins"])
        let cases: [(Book, MetadataCandidate)] = [
            (sapiens, candidate("Sapiens: A Graphic History", author: "Yuval Noah Harari")),
            (sapiens, candidate("Sapiens", subtitle: "A Graphic History", author: "Yuval Noah Harari")),
            (sapiens, candidate("Sapiens: La novela gráfica", author: "Yuval Noah Harari")),
            (hunger, candidate("Los juegos del hambre: En llamas", author: "Suzanne Collins")),
            (hunger, candidate("Los juegos del hambre. Trilogía", author: "Suzanne Collins")),
        ]
        for (book, other) in cases {
            let label = other.title + (other.subtitle.map { ": " + $0 } ?? "")
            let match = MetadataMatcher.match(other, for: book)
            // Con el subtítulo en su propio título no es «Mismo título»; con una palabra de otra
            // forma del libro («gráfica», «trilogía») dice que no es el libro.
            XCTAssertTrue(!match.notes.contains(.sameTitle) || match.notes.contains(.notTheBook), label)
            let ranked = MetadataMatcher.rank([other], for: book)
            XCTAssertFalse(MetadataMatcher.shouldAutoApply(ranked, for: book), label)
            XCTAssertFalse(MetadataMatcher.isSafeSuggestion(ranked), "«Completar los muy probables» tampoco: \(label)")
        }
        // El subtítulo aparte de una edición sí es el mismo libro (y su obra con tu título también).
        let edition = candidate("Sapiens", subtitle: "De animales a dioses", author: "Yuval Noah Harari")
        XCTAssertTrue(MetadataMatcher.shouldAutoApply(MetadataMatcher.rank([edition], for: sapiens), for: sapiens))
        let sameWork = candidate("Sapiens: De animales a dioses", work: "Sapiens", author: "Yuval Noah Harari")
        XCTAssertTrue(MetadataMatcher.match(sameWork, for: sapiens).notes.contains(.sameTitle))
        let spanish = candidate("Sapiens (Spanish Edition)", author: "Yuval Noah Harari")
        XCTAssertTrue(MetadataMatcher.match(spanish, for: sapiens).notes.contains(.sameTitle), "Lo de entre paréntesis no es subtítulo")
    }

    // MARK: 4 · Una línea cortada no se pega a la siguiente

    func testTornLineIsNotGluedToTheNext() throws {
        let dir = try tempDir()
        let log = ChangeLog(directory: dir, deviceID: "mac")
        let clock = HybridLogicalClock(node: "mac")
        let book = UUID()
        try log.append([Change(hlc: clock.tick(), entity: .book, entityID: book, field: "title", value: .string("Rayuela"))])
        // La app se cerró a media escritura: media línea sin salto al final.
        let handle = try FileHandle(forWritingTo: log.ownFile)
        _ = try handle.seekToEnd()
        try handle.write(contentsOf: Data(#"{"entity":"book","fie"#.utf8))
        try handle.close()
        try log.append([Change(hlc: clock.tick(), entity: .book, entityID: book, field: "rating", value: .number(4))])
        let read = try log.readAll()
        XCTAssertEqual(read.changes.map(\.field), ["title", "rating"], "La línea nueva se lee entera")
        XCTAssertEqual(read.skippedLines, 1, "Solo se pierde la línea cortada")
        XCTAssertTrue(source("Packages/LectoraCore/Sources/LectoraCore/Sessions", "SessionLog.swift").contains("LineFile.append("),
                      "El diario de sesiones escribe igual")
    }

    // MARK: 5 · Mover el Gabinete no cuenta como copiado lo que sigue en iCloud

    func testWaitingFilesAreNotCountedAsCopied() throws {
        let dir = try tempDir()
        let folder = dir.appendingPathComponent("Biblioteca/Julio Cortázar/Rayuela (1)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: folder.appendingPathComponent("cover.jpg"))
        try Data().write(to: CloudFile.placeholder(for: folder.appendingPathComponent("Rayuela.epub")))
        let library = dir.appendingPathComponent("Biblioteca")
        XCTAssertEqual(CloudFile.countItems(in: library), 3, "Dos carpetas y la portada; el marcador no es un libro")
        XCTAssertEqual(CloudFile.waiting(in: library).map(\.lastPathComponent), ["Rayuela.epub"])
        let store = source("App/Shared/Library", "LibraryStore.swift")
        XCTAssertTrue(store.contains("throw LocationError.stillInCloud"), "Si no baja, no se mueve nada")
    }

    // MARK: 6 · Los subrayados siguen a los libros juntados en cadena

    func testChainedMergesAreFollowed() {
        let (x, y, z, w) = (UUID(), UUID(), UUID(), UUID())
        XCTAssertEqual(Set(DuplicateFinder.absorbed(into: z, table: [z: [y], y: [x]])), [x, y], "X→Y→Z: lo de X es de Z")
        XCTAssertEqual(DuplicateFinder.absorbed(into: w, table: [:]), [])
        // Dos dispositivos juntando al revés: no se repite sin fin ni se incluye a sí mismo.
        XCTAssertEqual(Set(DuplicateFinder.absorbed(into: z, table: [z: [y], y: [z, x], x: [y]])), [x, y])
        XCTAssertTrue(source("App/Shared/Library", "LibraryStore.swift").contains("DuplicateFinder.absorbed(into: id"))
    }

    // MARK: 7 y 10 · Deshacer en lote sigue con todos y no quita lo que no puso

    func testBatchUndoContinuesAndOnlyUndoesItsOwn() {
        let store = source("App/Shared/Library", "LibraryStore.swift")
        let undo = body(of: "func undo(_ batch: ReviewUndo) throws {", in: store)
        XCTAssertFalse(undo.isEmpty)
        XCTAssertFalse(undo.contains("try undoAllFilled"), "Un error en un libro no detiene a los demás")
        XCTAssertTrue(undo.contains("batch.recorded[id]"), "Solo se deshace lo que anotó este lote")
        XCTAssertTrue(undo.contains("throw UndoFailed"), "Al final se dice qué libros no se pudieron")
        let cover = body(of: "func undoFilled(_ field: FilledField, for bookID: UUID) throws {", in: store)
        XCTAssertTrue(cover.contains("isStillFilledCover"), "Una portada que cambiaste después no se borra")
        XCTAssertTrue(cover.contains("incompleteCache = nil") && body(of: "func update(_ edited: Book", in: store).contains("incompleteCache = nil"),
                      "Poner o quitar una portada vuelve a calcular «le faltan datos»")
    }

    // MARK: 8 · Un respaldo en otro aparato no escribe en el registro del primero

    func testCopiedSettingsTakeAFreshDeviceID() {
        let fresh = { "nuevo" }
        let first = DeviceIdentity.resolve(.init(id: nil, fingerprint: nil), fingerprint: "mac-1", makeID: fresh)
        XCTAssertEqual(first, .init(id: "nuevo", fingerprint: "mac-1"))
        let same = DeviceIdentity.Stored(id: "A", fingerprint: "mac-1")
        XCTAssertEqual(DeviceIdentity.resolve(same, fingerprint: "mac-1", makeID: fresh), same, "El mismo aparato conserva su id")
        XCTAssertEqual(DeviceIdentity.resolve(same, fingerprint: "mac-2", makeID: fresh), .init(id: "nuevo", fingerprint: "mac-2"),
                       "Los ajustes copiados a otra Mac o iPhone toman un id nuevo")
        XCTAssertEqual(DeviceIdentity.resolve(.init(id: "A", fingerprint: nil), fingerprint: "mac-1", makeID: fresh),
                       .init(id: "A", fingerprint: "mac-1"), "Lo de antes de la huella se queda con su id")
        XCTAssertEqual(DeviceIdentity.resolve(same, fingerprint: nil, makeID: fresh), same, "Sin huella ahora, no se decide nada")
        let store = source("App/Shared/Reader", "AnnotationStore.swift")
        XCTAssertTrue(store.contains("DeviceIdentity.resolve("), "El id del registro pasa por la huella del aparato")
    }

    // MARK: 9 · Una nota renombrada no se pierde si el renombre falla

    func testRenamedNoteSurvivesAFailedRename() throws {
        let folder = NoteFolder(url: try tempDir())
        let note = try folder.save(text: "# Ideas\n\nPrimera")
        // Su archivo se borró en otro dispositivo mientras la editabas: el renombre falla.
        try FileManager.default.removeItem(at: folder.file(for: note.fileName))
        let saved = try folder.save(text: "# Ideas nuevas\n\nLo que escribí", fileName: note.fileName)
        XCTAssertEqual(saved.fileName, "Ideas nuevas")
        XCTAssertEqual(folder.read(folder.file(for: "Ideas nuevas"))?.text, "# Ideas nuevas\n\nLo que escribí")
    }

    // MARK: 11 · `isbn:` con o sin guiones

    func testISBNQueryIgnoresHyphens() {
        let book = Book(title: "Rayuela", identifiers: ["isbn": "9788437604947"])
        let hyphens = Book(title: "Ficciones", identifiers: ["isbn": "978-84-206-3378-2"])
        XCTAssertTrue(LibraryQuery("isbn:978-84-376-0494-7").matches(book))
        XCTAssertTrue(LibraryQuery("isbn:84-376-0494-X").matches(book) || LibraryQuery("isbn:8437604947").matches(book),
                      "El de 10 cifras encuentra al de 13")
        XCTAssertTrue(LibraryQuery("isbn:9788420633782").matches(hyphens))
        XCTAssertTrue(LibraryQuery("isbn:84376").matches(book), "Un pedazo también")
        XCTAssertFalse(LibraryQuery("isbn:978-84-206-3378-2").matches(book))
    }

    // MARK: 12 y M4 · Juntar conserva dónde ibas, los marcadores y la huella de los archivos

    func testMergeKeepsPositionBookmarksAndHashes() {
        let now = Date()
        XCTAssertEqual(DuplicateFinder.furthest([nil, .init(fraction: 0.4, updatedAt: now)]), 1, "El que se queda no tenía: la del otro")
        XCTAssertEqual(DuplicateFinder.furthest([.init(fraction: 0.6, updatedAt: now), .init(fraction: 0.4, updatedAt: now)]), 0)
        XCTAssertEqual(DuplicateFinder.furthest([.init(fraction: 0.4, updatedAt: now.addingTimeInterval(-60)),
                                                 .init(fraction: 0.4, updatedAt: now)]), 1, "Empate: la más reciente")
        XCTAssertNil(DuplicateFinder.furthest([nil, nil]))

        let mark = Bookmark(bookID: UUID(), cfi: "epubcfi(/6/4!/4/2)", fraction: 0.42, excerpt: "En un lugar")
        let keep = UUID()
        let moved = mark.moved(to: keep)
        XCTAssertEqual(moved.bookID, keep)
        XCTAssertNotEqual(moved.cfi, mark.cfi, "El CFI de otro archivo no sirve en este")
        XCTAssertEqual(Bookmark.approximateFraction(moved.cfi), 0.42)
        XCTAssertEqual(moved.excerpt, "En un lugar")
        XCTAssertNil(Bookmark.approximateFraction(mark.cfi))

        var other = Book(title: "Rayuela", fileHash: "pdf-hash")
        other.extraHashes = ["mobi-hash"]
        let merged = DuplicateFinder.merged(keep: Book(title: "Rayuela", fileHash: "epub-hash"), with: [other])
        XCTAssertTrue(merged.hasFile(hash: "pdf-hash") && merged.hasFile(hash: "mobi-hash") && merged.hasFile(hash: "epub-hash"),
                      "Volver a importar el PDF que juntaste se reconoce")
        // Viaja en el registro.
        let clock = HybridLogicalClock(node: "mac")
        var state = LibraryState()
        state.apply(merged.changes(clock: clock))
        XCTAssertEqual(state.books().first?.extraHashes, ["pdf-hash", "mobi-hash"])
        // Un libro sin huellas extra no escribe un cambio nuevo al editarse.
        let plain = Book(title: "Ficciones")
        XCTAssertFalse(plain.changes(clock: clock).contains { $0.field == "extra_hashes" })
    }

    // MARK: 13 · Un archivo de `.lectora/` dañado te lo digo, una vez

    func testDamagedSideFileIsReported() throws {
        let dir = try tempDir()
        let file = dir.appendingPathComponent("estantes.json")
        let decode = { (data: Data) in try? JSONDecoder().decode([String: Int].self, from: data) }
        XCTAssertFalse(SideFile.isDamaged(file, decode: decode), "Sin archivo no está dañado")
        try Data("{\"a\": 1}".utf8).write(to: file)
        XCTAssertFalse(SideFile.isDamaged(file, decode: decode))
        try Data("{\"a\": ".utf8).write(to: file)
        XCTAssertTrue(SideFile.isDamaged(file, decode: decode))
        let notice = SideFile.damagedNotice("estantes.json")
        XCTAssertTrue(notice.hasPrefix("No puedo leer tus estantes"), notice)
        XCTAssertTrue(notice.contains("no lo toqué"))
        let store = source("App/Shared/Library", "LibraryStore.swift")
        XCTAssertTrue(store.contains("damagedNoticed.insert("), "El aviso sale una vez por archivo, no en cada intento")
    }

    // MARK: 14 · Rutas con otras mayúsculas: se corrigen al abrir y «Ordenar» junta las gemelas

    func testWrongCasePathIsRepairedAtLoad() throws {
        let root = try tempDir()
        let folder = root.appendingPathComponent("Julio Cortázar/Rayuela (1)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: folder.appendingPathComponent("Rayuela.epub"))
        XCTAssertNil(FolderMove.repairedSpelling(of: "Julio Cortázar/Rayuela (1)/Rayuela.epub", in: root), "La buena no se toca")
        XCTAssertNil(FolderMove.repairedSpelling(of: "Borges/Ficciones (2)/Ficciones.epub", in: root), "Lo que no hay, tampoco")
        let store = source("App/Shared/Library", "LibraryStore.swift")
        XCTAssertTrue(store.contains("repairPathCase()"), "Se corrige al abrir la biblioteca")
        XCTAssertTrue(body(of: "func tidy() -> TidyReport {", in: store).contains("FolderMove.mergeTwinFolders(in: root)"),
                      "«Ordenar» junta las gemelas que quedaron de antes")
    }

    func testWrongCasePathIsRepairedOnCaseSensitiveDisk() throws {
        let root = try tempDir(in: try caseSensitiveBase())
        let folder = root.appendingPathComponent("Julio Cortázar/Rayuela (1)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: folder.appendingPathComponent("Rayuela.epub"))
        XCTAssertEqual(FolderMove.repairedSpelling(of: "julio cortázar/Rayuela (1)/Rayuela.epub", in: root),
                       "Julio Cortázar/Rayuela (1)/Rayuela.epub")
    }

    func testTwinFoldersAreMergedOnCaseSensitiveDisk() throws {
        let root = try tempDir(in: try caseSensitiveBase())
        for relative in ["Julio Cortázar/Rayuela (1)", "Julio Cortázar/Bestiario (2)", "julio cortázar/Final del juego (3)",
                         "julio cortázar/Rayuela (1)"] {
            let folder = root.appendingPathComponent(relative)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try Data(relative.utf8).write(to: folder.appendingPathComponent("libro.epub"))
        }
        let moved = FolderMove.mergeTwinFolders(in: root)
        XCTAssertEqual(moved, ["julio cortázar/Final del juego (3)": "Julio Cortázar/Final del juego (3)"])
        let kept = try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("Julio Cortázar").path).sorted()
        XCTAssertEqual(kept, ["Bestiario (2)", "Final del juego (3)", "Rayuela (1)"])
        // La que ya existía allá se queda donde estaba: nunca se pisa.
        let rayuela = root.appendingPathComponent("julio cortázar/Rayuela (1)/libro.epub")
        XCTAssertEqual(try String(contentsOf: rayuela, encoding: .utf8), "julio cortázar/Rayuela (1)")
    }

    private func caseSensitiveBase() throws -> URL {
        guard let path = ProcessInfo.processInfo.environment["LECTORA_CASE_SENSITIVE_DIR"] else {
            throw XCTSkip("Sin disco sensible a mayúsculas (LECTORA_CASE_SENSITIVE_DIR)")
        }
        return URL(fileURLWithPath: path)
    }

    // MARK: 17 · La hendidura respeta los <br> de un bloque

    func testSlitBreaksAtLineBreaks() {
        let reader = (try? String(contentsOf: DesignRulesTests.root.appendingPathComponent("App/Resources/Reader/reader.js"),
                                  encoding: .utf8)) ?? ""
        let slit = reader.components(separatedBy: "const slitTextOf").dropFirst().first?.prefix(1200) ?? ""
        XCTAssertTrue(slit.contains("NodeFilter.SHOW_ELEMENT") && slit.contains("'BR'"),
                      "reader.js: un <br> dentro de un párrafo es un salto en la hendidura")
    }
}
