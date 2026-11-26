@testable import LectoraCore
import XCTest

/// La tabla de la Mac (MG-1): búsqueda con filtros y edición masiva.
final class LibraryAdminTests: XCTestCase {
    let rayuela = Book(title: "Rayuela", authors: ["Julio Cortázar"], tags: ["novela"], language: "es",
                       identifiers: ["isbn": "9788437604572"], readingStatus: .reading, publisher: "Cátedra")
    let bestiario = Book(title: "Bestiario", authors: ["Julio Cortázar"], tags: ["cuento", "Argentina"], language: "es")
    let braudel = Book(title: "El Mediterráneo", authors: ["Fernand Braudel"], series: "El Mediterráneo",
                       seriesIndex: 1, tags: ["historia"], language: "fr", readingStatus: .finished)

    func testFreeWordsIgnoreAccentsAndCase() {
        XCTAssertTrue(LibraryQuery("cortazar RAYUELA").matches(rayuela))
        XCTAssertFalse(LibraryQuery("cortazar historia").matches(rayuela))
        XCTAssertTrue(LibraryQuery("").isEmpty)
    }

    func testNamedFilters() {
        XCTAssertTrue(LibraryQuery("autor:cortázar").matches(bestiario))
        XCTAssertFalse(LibraryQuery("autor:braudel").matches(bestiario))
        XCTAssertTrue(LibraryQuery("etiqueta:argentina").matches(bestiario))
        XCTAssertTrue(LibraryQuery("serie:\"el mediterraneo\"").matches(braudel))
        XCTAssertTrue(LibraryQuery("idioma:francés").matches(braudel))
        XCTAssertTrue(LibraryQuery("idioma:es").matches(rayuela))
        XCTAssertTrue(LibraryQuery("estado:leyendo").matches(rayuela))
        XCTAssertTrue(LibraryQuery("estado:leido").matches(braudel))
        XCTAssertTrue(LibraryQuery("isbn:978843760").matches(rayuela))
        XCTAssertTrue(LibraryQuery("editorial:catedra autor:julio").matches(rayuela))
    }

    func testUnknownNameIsAWord() {
        // «hora:12» no es un filtro: se busca como texto.
        let query = LibraryQuery("hora:12")
        XCTAssertEqual(query.words, ["hora:12"])
        XCTAssertTrue(query.filters.isEmpty)
    }

    func testBulkEditTouchesOnlyWhatChanged() {
        let edit = BulkEdit(language: .some("es"), addTags: ["Latinoamérica"], removeTags: ["cuento"])
        let edited = edit.apply(to: bestiario)
        XCTAssertEqual(edited.title, "Bestiario")
        XCTAssertEqual(edited.authors, ["Julio Cortázar"])
        XCTAssertEqual(edited.tags, ["Argentina", "Latinoamérica"])
        XCTAssertEqual(edited.language, "es")
    }

    func testBulkEditDoesNotDuplicateTags() {
        let edited = BulkEdit(addTags: ["NOVELA", "clásico"]).apply(to: rayuela)
        XCTAssertEqual(edited.tags, ["novela", "clásico"])
    }

    func testClearingSeriesClearsItsNumber() {
        let edited = BulkEdit(series: .some(nil)).apply(to: braudel)
        XCTAssertNil(edited.series)
        XCTAssertNil(edited.seriesIndex)
        XCTAssertEqual(BulkEdit(series: .some("El Mediterráneo")).apply(to: braudel).seriesIndex, 1)
    }

    func testCommonValuesShowVarios() {
        XCTAssertEqual(BulkEdit.common([rayuela, bestiario]) { $0.authors }, ["Julio Cortázar"])
        XCTAssertNil(BulkEdit.common([rayuela, braudel]) { $0.authors })
        XCTAssertEqual(BulkEdit.sharedTags([rayuela, bestiario]), [])
        XCTAssertEqual(BulkEdit.list(" Borges,  Bioy Casares ,"), ["Borges", "Bioy Casares"])
    }
}
