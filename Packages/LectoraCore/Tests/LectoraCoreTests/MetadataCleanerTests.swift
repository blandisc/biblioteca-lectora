import XCTest
@testable import LectoraCore

final class MetadataCleanerTests: XCTestCase {
    func testTitlesLoseStoreJunk() {
        XCTAssertEqual(MetadataCleaner.cleanTitle("Rayuela (Spanish Edition)"), "Rayuela")
        XCTAssertEqual(MetadataCleaner.cleanTitle("Dune [epub]"), "Dune")
        XCTAssertEqual(MetadataCleaner.cleanTitle("CIEN AÑOS DE SOLEDAD", language: "es"), "Cien años de soledad")
        XCTAssertEqual(MetadataCleaner.cleanTitle("PRIDE AND PREJUDICE", language: "en"), "Pride and Prejudice")
        XCTAssertEqual(MetadataCleaner.cleanTitle("SPQR"), "SPQR")
        XCTAssertEqual(MetadataCleaner.titleFromFileName("pedro_paramo_v2.epub"), "pedro paramo")
    }

    func testAuthorsAreNormalized() {
        XCTAssertEqual(MetadataCleaner.cleanAuthors(["Cortázar, Julio"]), ["Julio Cortázar"])
        XCTAssertEqual(MetadataCleaner.cleanAuthors(["Isaac Asimov & Robert Silverberg"]), ["Isaac Asimov", "Robert Silverberg"])
        XCTAssertEqual(MetadataCleaner.cleanAuthors(["Unknown", "Borges", "borges"]), ["Borges"])
        XCTAssertEqual(MetadataCleaner.cleanAuthors(["Martin Luther King, Jr."]), ["Martin Luther King, Jr."])
    }

    func testLanguagesAndDates() {
        XCTAssertEqual(MetadataCleaner.cleanLanguage("spa"), "es")
        XCTAssertEqual(MetadataCleaner.cleanLanguage("en-US"), "en")
        XCTAssertEqual(MetadataCleaner.cleanLanguage("Spanish"), "es")
        XCTAssertEqual(MetadataCleaner.cleanDate("1963-06-28T05:00:00+00:00"), "1963-06-28")
        // Medianoche de España guardada en UTC por Calibre: es el 1 de enero.
        XCTAssertEqual(MetadataCleaner.cleanDate("2003-12-31T23:00:00+00:00"), "2004")
        XCTAssertEqual(MetadataCleaner.cleanDate("1952-01-01"), "1952")
        XCTAssertNil(MetadataCleaner.cleanDate("desconocida"))
    }

    func testManualEditsAreRespected() {
        let typed = Book(title: "HHhH", tags: (1...10).map { "t\($0)" }, published: "mayo de 2004")
        let book = MetadataCleaner.clean(typed, manual: true)
        XCTAssertEqual(book.title, "HHhH")
        XCTAssertEqual(book.tags.count, 10)
        XCTAssertEqual(book.published, "mayo de 2004")
    }

    func testCleanBookFallsBackToFileName() {
        let book = MetadataCleaner.clean(Book(title: "  ", identifiers: ["isbn": "978-84-376-0457-2"]), fileName: "la_tregua.epub")
        XCTAssertEqual(book.title, "la tregua")
        XCTAssertEqual(book.identifiers["isbn"], "9788437604572")
    }

    func testRulesMapAuthorsAndTags() {
        let rules = MetadataRules(
            authors: [.init(from: "gabo", to: "Gabriel García Márquez")],
            tags: [.init(from: "Fiction", to: "Ficción"), .init(from: "Libro electrónico", to: "")]
        )
        let book = Book(title: "x", authors: ["Gabo", "Gabriel García Márquez"],
                        tags: ["fiction", "Ficción", "libro electronico", "Cuento"])
        let mapped = rules.apply(to: book)
        XCTAssertEqual(mapped.authors, ["Gabriel García Márquez"], "Sin repetir")
        XCTAssertEqual(mapped.tags, ["Ficción", "Cuento"], "Vacío quita la etiqueta")
        XCTAssertEqual(MetadataRules().apply(to: book), book)
        let empty = MetadataRules(authors: [.init(from: "Gabo", to: "")])
        XCTAssertEqual(empty.apply(to: book).authors, book.authors, "Un autor no se borra")
    }
}
