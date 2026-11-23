import XCTest
@testable import LectoraCore

final class QuoteAnchorTests: XCTestCase {
    /// 19 nov 2026: el subrayado de muestra «de Readwise» terminaba en punto y el libro
    /// decía «astillero,»: no se anclaba. Sin la puntuación final, sí.
    func testFinalPunctuationIsDropped() {
        let queries = QuoteAnchor.queries(for: "Llegó al pueblo con el viento del astillero.")
        XCTAssertEqual(queries.first, "Llegó al pueblo con el viento del astillero.")
        XCTAssertTrue(queries.contains("Llegó al pueblo con el viento del astillero"))
    }

    func testCurlyQuotesAndSpacesAreStraightened() {
        let queries = QuoteAnchor.queries(for: "  «It’s   a truth»\nuniversally acknowledged…")
        XCTAssertTrue(queries.contains("«It's a truth» universally acknowledged..."))
        XCTAssertTrue(queries.contains("It's a truth» universally acknowledged"))
    }

    func testLongQuoteEndsWithItsOpening() {
        let quote = "uno dos tres cuatro cinco seis siete ocho nueve diez once doce trece catorce quince."
        XCTAssertEqual(QuoteAnchor.queries(for: quote).last,
                       "uno dos tres cuatro cinco seis siete ocho nueve diez once doce")
    }

    func testShortOrRepeatedQueriesAreSkipped() {
        XCTAssertEqual(QuoteAnchor.queries(for: "Sí."), [])
        XCTAssertEqual(QuoteAnchor.queries(for: "una cita sin nada raro").count, 1)
    }
}
