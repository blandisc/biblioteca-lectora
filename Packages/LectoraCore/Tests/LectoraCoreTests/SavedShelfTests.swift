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
        XCTAssertEqual(SavedShelf.suggestedName(for: "etiqueta:historia idioma:en"), "Historia · Inglés")
        XCTAssertEqual(SavedShelf.suggestedName(for: "autor:\"julio cortázar\" estado:leyendo"), "Julio cortázar · Leyendo")
    }

    /// Auditoría de medios (27 nov 2026): el estante enseñaba su búsqueda cruda
    /// («AUTOR:ASIMOV SERIE:FUNDACIÓN»); ahora la dice en palabras.
    func testDescribeSaysTheQueryInWords() {
        XCTAssertEqual(SavedShelf.describe("autor:asimov serie:fundación"), "de Asimov · serie Fundación")
        XCTAssertEqual(SavedShelf.describe("autor:julio cortázar idioma:es"), "de Julio cortázar · en español")
        XCTAssertEqual(SavedShelf.describe("ciudad etiqueta:viaje"), "con «ciudad» · etiqueta Viaje")
        XCTAssertEqual(SavedShelf.describe("estado:leyendo"), "Leyendo")
        XCTAssertFalse(SavedShelf.describe("autor:asimov serie:fundación").contains(":"))
    }

    func testRoundTrip() throws {
        let shelf = SavedShelf(name: " Para el viaje ", query: "etiqueta:viaje")
        XCTAssertEqual(shelf.name, "Para el viaje")
        let back = try JSONDecoder().decode([SavedShelf].self, from: JSONEncoder().encode([shelf]))
        XCTAssertEqual(back, [shelf])
    }
}
