import Foundation
import XCTest
@testable import LectoraCore

final class SavedShelfTests: XCTestCase {
    func testShelfFillsItselfWithMatchingBooks() {
        let shelf = SavedShelf(name: "Historia en inglés", query: "etiqueta:historia idioma:en")
        XCTAssertTrue(shelf.contains(Book(title: "The Mediterranean", tags: ["Historia"], language: "en")))
        XCTAssertFalse(shelf.contains(Book(title: "El Mediterráneo", tags: ["Historia"], language: "es")))
        XCTAssertFalse(SavedShelf(name: "Vacío", query: "  ").contains(Book(title: "X")), "Sin búsqueda no hay libros")
    }

    func testSuggestedName() {
        XCTAssertEqual(SavedShelf.suggestedName(for: "etiqueta:historia idioma:en"), "Historia · En")
        XCTAssertEqual(SavedShelf.suggestedName(for: "autor:\"julio cortázar\" estado:leyendo"), "Julio cortázar · Leyendo")
    }

    func testRoundTrip() throws {
        let shelf = SavedShelf(name: " Para el viaje ", query: "etiqueta:viaje")
        XCTAssertEqual(shelf.name, "Para el viaje")
        let back = try JSONDecoder().decode([SavedShelf].self, from: JSONEncoder().encode([shelf]))
        XCTAssertEqual(back, [shelf])
    }
}
