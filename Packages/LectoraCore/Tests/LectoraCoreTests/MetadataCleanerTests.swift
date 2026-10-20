import XCTest
@testable import LectoraCore

final class MetadataCleanerTests: XCTestCase {
    func testTitlesLoseStoreJunk() {
        XCTAssertEqual(MetadataCleaner.cleanTitle("Rayuela (Spanish Edition)"), "Rayuela")
        XCTAssertEqual(MetadataCleaner.cleanTitle("Dune [epub]"), "Dune")
        XCTAssertEqual(MetadataCleaner.cleanTitle("CIEN AÑOS DE SOLEDAD"), "Cien Años De Soledad")
        XCTAssertEqual(MetadataCleaner.titleFromFileName("pedro_paramo_v2.epub"), "pedro paramo")
    }

    func testAuthorsAreNormalized() {
        XCTAssertEqual(MetadataCleaner.cleanAuthors(["Cortázar, Julio"]), ["Julio Cortázar"])
        XCTAssertEqual(MetadataCleaner.cleanAuthors(["Isaac Asimov & Robert Silverberg"]), ["Isaac Asimov", "Robert Silverberg"])
        XCTAssertEqual(MetadataCleaner.cleanAuthors(["Unknown", "Borges", "borges"]), ["Borges"])
    }

    func testLanguagesAndDates() {
        XCTAssertEqual(MetadataCleaner.cleanLanguage("spa"), "es")
        XCTAssertEqual(MetadataCleaner.cleanLanguage("en-US"), "en")
        XCTAssertEqual(MetadataCleaner.cleanLanguage("Spanish"), "es")
        XCTAssertEqual(MetadataCleaner.cleanDate("1963-06-28T05:00:00+00:00"), "1963-06-28")
        XCTAssertEqual(MetadataCleaner.cleanDate("1952-01-01"), "1952")
        XCTAssertNil(MetadataCleaner.cleanDate("desconocida"))
    }

    func testCleanBookFallsBackToFileName() {
        let book = MetadataCleaner.clean(Book(title: "  ", identifiers: ["isbn": "978-84-376-0457-2"]), fileName: "la_tregua.epub")
        XCTAssertEqual(book.title, "la tregua")
        XCTAssertEqual(book.identifiers["isbn"], "9788437604572")
    }
}
