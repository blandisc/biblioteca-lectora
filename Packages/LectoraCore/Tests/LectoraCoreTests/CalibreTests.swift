import XCTest
@testable import LectoraCore

final class CalibreTests: XCTestCase {
    private func sampleBook() -> Book {
        Book(
            id: UUID(uuidString: "8C1D2E3F-4A5B-4C6D-8E9F-0A1B2C3D4E5F")!,
            title: "Fundación e Imperio",
            authors: ["Isaac Asimov"],
            series: "Fundación",
            seriesIndex: 2,
            tags: ["Ciencia ficción", "Clásicos"],
            language: "es",
            identifiers: ["isbn": "9788497593069", "asin": "B00ABC1234"],
            publisher: "Debolsillo & Cía",
            published: "1952",
            summary: "<p>La segunda parte de la saga.</p>",
            rating: 4.5,
            calibreID: 12,
            addedAt: Date(timeIntervalSince1970: 1_760_000_000)
        )
    }

    func testOPFRoundTripsEverythingCalibreKeeps() throws {
        let book = sampleBook()
        let opf = CalibreOPF.write(book, hasCover: true)
        XCTAssertTrue(opf.contains(#"<meta name="calibre:series" content="Fundación"/>"#))
        XCTAssertTrue(opf.contains(#"<meta name="calibre:rating" content="9.0"/>"#))
        XCTAssertTrue(opf.contains("<dc:language>spa</dc:language>"))
        XCTAssertTrue(opf.contains(#"opf:file-as="Asimov, Isaac""#))
        XCTAssertTrue(opf.contains("Debolsillo &amp; Cía"))
        XCTAssertTrue(opf.contains(#"href="cover.jpg""#))
        XCTAssertTrue(opf.contains("<dc:date>1952-01-01T12:00:00+00:00</dc:date>"))

        let parsed = try XCTUnwrap(CalibreOPF.parse(Data(opf.utf8)))
        XCTAssertEqual(parsed.id, book.id)
        XCTAssertEqual(parsed.title, book.title)
        XCTAssertEqual(parsed.authors, book.authors)
        XCTAssertEqual(parsed.series, "Fundación")
        XCTAssertEqual(parsed.seriesIndex, 2)
        XCTAssertEqual(parsed.tags, book.tags)
        XCTAssertEqual(parsed.language, "es")
        XCTAssertEqual(parsed.identifiers, book.identifiers)
        XCTAssertEqual(parsed.publisher, "Debolsillo & Cía")
        XCTAssertEqual(parsed.published, "1952")
        XCTAssertEqual(parsed.summary, book.summary)
        XCTAssertEqual(parsed.rating, 4.5)
        XCTAssertEqual(parsed.calibreID, 12)
        XCTAssertEqual(parsed.addedAt, book.addedAt)
    }

    func testParsesARealCalibreOPF() throws {
        let opf = """
        <?xml version='1.0' encoding='utf-8'?>
        <package xmlns="http://www.idpf.org/2007/opf" unique-identifier="uuid_id" version="2.0">
            <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
                <dc:identifier opf:scheme="calibre" id="calibre_id">431</dc:identifier>
                <dc:identifier opf:scheme="uuid" id="uuid_id">0f9a7a8e-2b5c-4d1e-9f3a-6b7c8d9e0a1b</dc:identifier>
                <dc:title>Rayuela</dc:title>
                <dc:creator opf:file-as="Cortázar, Julio" opf:role="aut">Julio Cortázar</dc:creator>
                <dc:contributor opf:file-as="calibre" opf:role="bkp">calibre (7.6.0) [https://calibre-ebook.com]</dc:contributor>
                <dc:date>1963-06-28T05:00:00+00:00</dc:date>
                <dc:identifier opf:scheme="ISBN">9788437604572</dc:identifier>
                <dc:identifier opf:scheme="MOBI-ASIN">B004R1Q4EK</dc:identifier>
                <dc:language>spa</dc:language>
                <dc:subject>Novela</dc:subject>
                <meta name="calibre:rating" content="10"/>
                <meta name="calibre:timestamp" content="2021-03-14T18:22:05.123456+00:00"/>
                <meta name="calibre:title_sort" content="Rayuela"/>
            </metadata>
            <guide><reference type="cover" title="Portada" href="cover.jpg"/></guide>
        </package>
        """
        let book = try XCTUnwrap(CalibreOPF.parse(Data(opf.utf8)))
        XCTAssertEqual(book.title, "Rayuela")
        XCTAssertEqual(book.authors, ["Julio Cortázar"])
        XCTAssertEqual(book.calibreID, 431)
        XCTAssertEqual(book.id, UUID(uuidString: "0f9a7a8e-2b5c-4d1e-9f3a-6b7c8d9e0a1b"))
        XCTAssertEqual(book.identifiers["isbn"], "9788437604572")
        XCTAssertEqual(book.identifiers["asin"], "B004R1Q4EK")
        XCTAssertEqual(book.language, "es")
        XCTAssertEqual(book.published, "1963-06-28")
        XCTAssertEqual(book.rating, 5)
        XCTAssertNotNil(book.addedAt)
    }

    func testControlCharactersNeverBreakTheOPF() throws {
        var book = sampleBook()
        book.summary = "Uno\u{0C}dos\u{0B}tres"
        let parsed = try XCTUnwrap(CalibreOPF.parse(Data(CalibreOPF.write(book, hasCover: false).utf8)))
        XCTAssertEqual(parsed.summary, "Unodostres")
    }

    func testLayoutMatchesCalibreFolders() {
        XCTAssertEqual(CalibreLayout.folder(title: "¿Sueñan los androides?", authors: ["Philip K. Dick"], calibreID: 7),
                       "Philip K. Dick/¿Sueñan los androides_ (7)")
        XCTAssertEqual(CalibreLayout.fileName(title: "Rayuela", authors: ["Julio Cortázar"], fileExtension: "EPUB"),
                       "Rayuela - Julio Cortázar.epub")
        XCTAssertEqual(CalibreLayout.folder(title: "Sin autor", authors: [], calibreID: 1), "Desconocido/Sin autor (1)")
        XCTAssertEqual(CalibreLayout.sanitize("  a/b:c.  "), "a_b_c")
    }

    func testBookKeepsNewFieldsThroughChanges() {
        let book = sampleBook()
        var state = LibraryState()
        state.apply(book.changes(clock: HybridLogicalClock(node: "a")))
        let restored = state.books().first
        XCTAssertEqual(restored, book)
    }

    func testSortHelpers() {
        XCTAssertEqual(Book(title: "El nombre del viento").sortTitle, "nombre del viento")
        XCTAssertEqual(Book.authorSort("Gabriel García Márquez"), "Márquez, Gabriel García")
        XCTAssertEqual(Book.authorSort("Platón"), "Platón")
    }
}
