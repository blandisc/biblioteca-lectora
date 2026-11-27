import XCTest
@testable import LectoraCore

/// Fallas de la auditoría «intenta romperla» (26 nov 2026). Cada prueba falla si la falla vuelve.
final class RompelaTests: XCTestCase {
    private func tempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("rompela-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    // MARK: C5 · Números enormes no cierran la app

    func testHugeNumbersNeverTrap() {
        for bad in [Double.infinity, -.infinity, .nan, 1e20, 1e300, -1, Double("99999999999999999999")!] {
            XCTAssertNil(Book.sanitizedSeriesIndex(bad), "\(bad)")
            let fields: [String: JSONValue] = ["title": .string("X"), "series_index": .number(bad), "calibre_id": .number(bad)]
            let book = Book(id: UUID(), fields: fields)
            XCTAssertNil(book?.seriesIndex, "\(bad)")
            XCTAssertNil(book?.calibreID, "\(bad)")
        }
        XCTAssertEqual(Book.sanitizedSeriesIndex(2.5), 2.5)
        XCTAssertEqual(Book.sanitizedSeriesIndex(0), 0)
        XCTAssertEqual(Book(id: UUID(), fields: ["title": .string("X"), "calibre_id": .number(12)])?.calibreID, 12)
        XCTAssertNil(Book(id: UUID(), fields: ["title": .string("X"), "calibre_id": .number(1.5)])?.calibreID)
    }

    func testHugeSeriesIndexFromOPFAndEditor() throws {
        let opf = """
        <package><metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
        <dc:title>Dune</dc:title><dc:identifier opf:scheme="calibre">1e300</dc:identifier>
        <meta name="calibre:series" content="Dune"/><meta name="calibre:series_index" content="1e300"/>
        </metadata></package>
        """
        let book = try XCTUnwrap(CalibreOPF.parse(Data(opf.utf8)))
        XCTAssertNil(book.seriesIndex)
        XCTAssertNil(book.calibreID)
        // Lo escrito a mano también pasa por el cleaner, y lo que se escribe al registro se puede codificar.
        let typed = MetadataCleaner.clean(Book(title: "Dune", series: "Dune", seriesIndex: .infinity), manual: true)
        XCTAssertNil(typed.seriesIndex)
        var raw = Book(title: "Dune", series: "Dune", seriesIndex: .infinity)
        raw.rating = .nan
        XCTAssertNoThrow(try JSONEncoder().encode(raw.changes(clock: HybridLogicalClock(node: "a"))))
        // Un número de intentos absurdo en la fila de trabajos tampoco cierra.
        XCTAssertNil(Book.sanitizedCalibreID(1e300))
    }

    // MARK: A1 · Solo se escriben los campos que cambiaron

    func testStaleCopyOnlyWritesWhatChanged() {
        let clock = HybridLogicalClock(node: "mac")
        let original = Book(title: "Rayuela", authors: ["Julio Cortázar"])
        XCTAssertEqual(original.changes(from: nil, clock: clock).count, original.changes(clock: clock).count)

        // El iPhone la marca como leída.
        var state = LibraryState()
        original.changes(clock: clock).forEach { state.apply($0) }
        var read = original
        read.readingStatus = .finished
        let later = HybridLogicalClock(node: "iphone") { HybridLogicalClock.systemMillis() + 1_000 }
        read.changes(from: original, clock: later).forEach { state.apply($0) }

        // La Mac, con su copia vieja y aún más tarde, solo agrega una etiqueta.
        let mac = HybridLogicalClock(node: "mac") { HybridLogicalClock.systemMillis() + 2_000 }
        var tagged = original
        tagged.tags = ["Novela"]
        let changes = tagged.changes(from: original, clock: mac)
        XCTAssertEqual(changes.map(\.field), ["tags"])
        changes.forEach { state.apply($0) }

        let merged = state.books().first
        XCTAssertEqual(merged?.readingStatus, .finished, "El «Leído» del otro dispositivo no se pierde")
        XCTAssertEqual(merged?.tags, ["Novela"])
        XCTAssertTrue(tagged.changes(from: tagged, clock: clock).isEmpty)
    }

    // MARK: C3 y C4 · Registro de cambios

    func testCorruptFileDoesNotEmptyTheLibrary() throws {
        let dir = try tempDir()
        let good = ChangeLog(directory: dir, deviceID: "bueno")
        try good.append(Book(title: "Rayuela").changes(clock: HybridLogicalClock(node: "bueno")))
        try Data("{roto\n".utf8).write(to: dir.appendingPathComponent("dañado.jsonl"))
        // Un archivo que no se puede leer (aquí, una carpeta con nombre de registro).
        let unreadable = dir.appendingPathComponent("nube.jsonl")
        try FileManager.default.createDirectory(at: unreadable, withIntermediateDirectories: true)

        let result = try good.readAll()
        var state = LibraryState()
        result.changes.forEach { state.apply($0) }
        XCTAssertEqual(state.books().map(\.title), ["Rayuela"])
        XCTAssertEqual(result.skippedLines, 1)
        XCTAssertEqual(result.skipped.map(\.lastPathComponent), ["nube.jsonl"])
    }

    func testEvictedOwnLogIsNotReplaced() throws {
        let dir = try tempDir()
        let log = ChangeLog(directory: dir, deviceID: "iphone")
        try Data().write(to: dir.appendingPathComponent(".iphone.jsonl.icloud"))
        XCTAssertEqual(log.ownPlaceholder.lastPathComponent, ".iphone.jsonl.icloud")
        XCTAssertThrowsError(try log.append(Book(title: "X").changes(clock: HybridLogicalClock(node: "iphone")))) {
            XCTAssertEqual($0 as? ChangeLogError, .ownLogNotDownloaded)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: log.ownFile.path), "No se crea un registro nuevo y corto")
    }

    // MARK: M1 · Cero preguntas no es «sin internet»

    private struct OfflineFetcher: MetadataFetching {
        func get(_ url: URL) async -> FetchResult { .failed }
    }

    func testNothingToAskIsNotUnreachable() async {
        let service = MetadataService(fetcher: OfflineFetcher())
        let result = await service.search(title: "", author: nil, isbn: nil, for: Book(title: ""))
        XCTAssertEqual(result.decision, .notFound)
        // «Sin título» sin ISBN no se busca en internet: va directo a revisar.
        let untitled = await service.lookup(Book(title: MetadataCleaner.untitled, authors: ["Anónimo"]))
        XCTAssertEqual(untitled.decision, .notFound)
        let offline = await service.lookup(Book(title: "Rayuela"))
        XCTAssertEqual(offline.decision, .unreachable)
    }

    // MARK: RB-6 · Otro tomo u otro subtítulo no es «Mismo título»

    private func candidate(_ title: String, subtitle: String? = nil, author: String) -> MetadataCandidate {
        MetadataCandidate(id: title, source: .openLibrary, title: title, subtitle: subtitle, authors: [author])
    }

    func testOtherVolumeGoesToReview() {
        let book = Book(title: "Dune: tomo diez", authors: ["Frank Herbert"])
        let dune = candidate("Dune", author: "Frank Herbert")
        let match = MetadataMatcher.match(dune, for: book)
        XCTAssertFalse(match.notes.contains(.sameTitle), "La razón no puede decir «Mismo título»")
        XCTAssertLessThan(match.confidence, MetadataMatcher.autoApplyThreshold)
        XCTAssertFalse(MetadataMatcher.shouldAutoApply(MetadataMatcher.rank([dune], for: book), for: book))

        for (mine, theirs) in [("Dune", "Dune: tomo diez"), ("Dune 2", "Dune"), ("Dune II", "Dune"), ("Dune, vol. 2", "Dune")] {
            let other = candidate(theirs, author: "Frank Herbert")
            let book = Book(title: mine, authors: ["Frank Herbert"])
            XCTAssertFalse(MetadataMatcher.shouldAutoApply(MetadataMatcher.rank([other], for: book), for: book), "\(mine) / \(theirs)")
        }
    }

    func testOtherBookOfTheSeriesGoesToReview() {
        let book = Book(title: "Fundación", authors: ["Isaac Asimov"])
        let other = candidate("Fundación e Imperio", author: "Isaac Asimov")
        XCTAssertFalse(MetadataMatcher.match(other, for: book).notes.contains(.sameTitle))
        XCTAssertFalse(MetadataMatcher.shouldAutoApply(MetadataMatcher.rank([other], for: book), for: book))
    }

    func testOtherSubtitleGoesToReview() {
        let book = Book(title: "Historia de Roma: la república", authors: ["Indro Montanelli"])
        let other = candidate("Historia de Roma", subtitle: "el imperio", author: "Indro Montanelli")
        let match = MetadataMatcher.match(other, for: book)
        XCTAssertFalse(match.notes.contains(.sameTitle))
        XCTAssertLessThan(match.confidence, MetadataMatcher.autoApplyThreshold)
    }

    func testExactTitleStillAutoApplies() {
        for (mine, theirs, subtitle) in [("Dune", "Dune", nil), ("Dune: tomo diez", "Dune", "tomo diez"),
                                         ("Sapiens", "Sapiens", "De animales a dioses"),
                                         ("Sapiens: De animales a dioses", "Sapiens", nil as String?)] {
            let book = Book(title: mine, authors: ["Frank Herbert"])
            let match = candidate(theirs, subtitle: subtitle, author: "Frank Herbert")
            XCTAssertTrue(MetadataMatcher.match(match, for: book).notes.contains(.sameTitle), mine)
            XCTAssertTrue(MetadataMatcher.shouldAutoApply(MetadataMatcher.rank([match], for: book), for: book), mine)
        }
    }

    // MARK: MetadataCleaner

    func testColonIsNotSpaced() {
        let book = MetadataCleaner.clean(Book(title: "Ciencia/Ficción 🚀: antología", authors: ["Anónimo"]))
        XCTAssertEqual(book.title, "Ciencia/Ficción 🚀: antología")
        XCTAssertEqual(MetadataCleaner.cleanTitle("Ciencia/Ficción 🚀: antología"), "Ciencia/Ficción 🚀: antología")
        XCTAssertEqual(OpenLibrary.cleanEditionTitle("Ciencia/Ficción 🚀: antología"), "Ciencia/Ficción 🚀: antología")
    }

    func testEmptyTitleIsUntitledAndAnonymousIsKept() {
        for name in ["a03.epub", "b3.epub", "3f9a2c71d0e4b5a6.epub"] {
            let book = MetadataCleaner.clean(Book(title: "  ", authors: ["Anónimo"]), fileName: name)
            XCTAssertEqual(book.title, "Sin título", name)
            XCTAssertEqual(book.authors, ["Anónimo"])
        }
        let named = MetadataCleaner.clean(Book(title: ""), fileName: "cervantes_don-quijote.epub")
        XCTAssertEqual(named.title, "cervantes don-quijote")
        XCTAssertEqual(MetadataCleaner.cleanAuthors(["Desconocido", "Unknown"]), [])
    }

    // MARK: B1 · Nombres de archivo en bytes

    func testFileNameFitsInBytes() {
        let family = "👨‍👩‍👧‍👦"
        let name = CalibreLayout.sanitize(String(repeating: family, count: 100))
        XCTAssertLessThanOrEqual(name.utf8.count, CalibreLayout.byteLimit)
        XCTAssertTrue(name.allSatisfy { $0 == Character(family) }, "No se parte un emoji a la mitad")
        XCTAssertFalse(name.isEmpty)
        let file = CalibreLayout.fileName(title: String(repeating: family, count: 100), authors: ["Ana"], fileExtension: "epub")
        XCTAssertLessThanOrEqual(file.utf8.count, 255)
        XCTAssertEqual(CalibreLayout.sanitize("Rayuela"), "Rayuela")
    }

    // MARK: B2 · Un descarte no vuelve por un tercero

    func testDismissedPairStaysApartWithAThirdBook() {
        let a = Book(title: "Rayuela", authors: ["Julio Cortázar"])
        let b = Book(title: "Rayuela", authors: ["Julio Cortázar"])
        let c = Book(title: "Rayuela", authors: ["Julio Cortázar"])
        let groups = DuplicateFinder.groups([a, b, c], dismissed: [DuplicateFinder.Pair(a.id, b.id)])
        for group in groups {
            let ids = Set(group.map(\.id))
            XCTAssertFalse(ids.contains(a.id) && ids.contains(b.id), "A y B no vuelven a salir juntos")
        }
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(DuplicateFinder.groups([a, b, c]).first?.count, 3)
    }

    // MARK: B4 · Listas como texto, de ida y vuelta

    func testListTextRoundTrip() {
        let lists: [([String], String)] = [
            (["Pérez & Hijos", "Ana"], " & "), (["Ciencia, ficción", "Novela"], ", "),
            (["a\\", "b"], " & "), (["\\ & x"], " & "), (["Ana"], " & "), ([], ", "), ([""], ", "),
        ]
        for (items, separator) in lists where !(items == [""]) {
            XCTAssertEqual(ListText.split(ListText.join(items, separator: separator), separator: separator), items, "\(items)")
        }
        XCTAssertEqual(ListText.split("Ana & Luis", separator: " & "), ["Ana", "Luis"], "Lo guardado antes se sigue leyendo")
        XCTAssertEqual(ListText.join(["Ana", "Luis"], separator: " & "), "Ana & Luis", "Sin escapes no cambia nada")
    }

    // MARK: Revisar el archivo antes de importar

    func testBookFileCheck() {
        let zip = Data("PK\u{3}\u{4}resto".utf8)
        XCTAssertEqual(BookFileCheck.problem(fileExtension: "epub", header: Data(), size: 0), "Está vacío.")
        XCTAssertNil(BookFileCheck.problem(fileExtension: "EPUB", header: zip, size: 100))
        XCTAssertNil(BookFileCheck.problem(fileExtension: "cbz", header: zip, size: 100))
        XCTAssertEqual(BookFileCheck.problem(fileExtension: "epub", header: Data("hola".utf8), size: 4), "No es un EPUB que pueda abrir.")

        XCTAssertNil(BookFileCheck.problem(fileExtension: "pdf", header: Data("%PDF-1.7".utf8), size: 8))
        let junk = Data(repeating: 0x20, count: 1024) + Data("%PDF-1.4".utf8)
        XCTAssertNil(BookFileCheck.problem(fileExtension: "pdf", header: junk, size: junk.count))
        let tooFar = Data(repeating: 0x20, count: 1025) + Data("%PDF-1.4".utf8)
        XCTAssertEqual(BookFileCheck.problem(fileExtension: "pdf", header: tooFar, size: tooFar.count), "No es un PDF que pueda abrir.")

        let mobi = Data(repeating: 0, count: 60) + Data("BOOKMOBI".utf8)
        XCTAssertNil(BookFileCheck.problem(fileExtension: "mobi", header: mobi, size: mobi.count))
        XCTAssertNil(BookFileCheck.problem(fileExtension: "azw3", header: mobi, size: mobi.count))
        XCTAssertNotNil(BookFileCheck.problem(fileExtension: "mobi", header: Data("BOOKMOBI".utf8), size: 8))

        let fb2 = Data("<?xml version=\"1.0\"?>\n<FictionBook xmlns=\"x\">".utf8)
        XCTAssertNil(BookFileCheck.problem(fileExtension: "fb2", header: fb2, size: fb2.count))
        XCTAssertNotNil(BookFileCheck.problem(fileExtension: "fb2", header: Data("<html>".utf8), size: 6))
        XCTAssertNotNil(BookFileCheck.problem(fileExtension: "docx", header: zip, size: 100))
    }
}
