import Foundation
import XCTest
@testable import LectoraCore

final class CatalogRenameTests: XCTestCase {
    func testMergingAuthorsKeepsOthersAndDoesNotRepeat() {
        let rename = CatalogRename(field: .author, from: ["Cortázar, Julio", "J. Cortazar"], to: "Julio Cortázar")
        let book = Book(title: "Rayuela", authors: ["cortázar, julio", "Julio Cortázar", "Aurora Bernárdez"])
        XCTAssertTrue(rename.touches(book))
        XCTAssertEqual(rename.apply(to: book).authors, ["Julio Cortázar", "Aurora Bernárdez"])
        XCTAssertFalse(rename.touches(Book(title: "Ficciones", authors: ["Jorge Luis Borges"])))
    }

    func testRenamingATagAndASeries() {
        let tag = CatalogRename(field: .tag, from: ["Fiction"], to: "Ficción")
        XCTAssertEqual(tag.apply(to: Book(title: "X", tags: ["fiction", "Novela"])).tags, ["Ficción", "Novela"])
        let series = CatalogRename(field: .series, from: ["El señor de los anillos"], to: "The Lord of the Rings")
        let book = Book(title: "Las dos torres", series: "El Señor de los Anillos", seriesIndex: 2)
        let renamed = series.apply(to: book)
        XCTAssertEqual(renamed.series, "The Lord of the Rings")
        XCTAssertEqual(renamed.seriesIndex, 2, "El número del tomo se conserva")
    }

    func testEmptyNameChangesNothing() {
        let rename = CatalogRename(field: .author, from: ["Borges"], to: "  ")
        let book = Book(title: "Ficciones", authors: ["Borges"])
        XCTAssertEqual(rename.apply(to: book), book)
    }

    func testLookalikeNames() {
        let all = ["Julio Cortázar", "Cortázar, Julio", "J. Cortazar", "Julio", "Julio Torri", "Cortázar"]
        XCTAssertEqual(CatalogRename.lookalikes(of: "Julio Cortázar", among: all), ["Cortázar, Julio", "J. Cortazar"])
        XCTAssertEqual(CatalogRename.lookalikes(of: "Gabriel García Márquez",
                                                among: ["García Márquez, Gabriel", "G. G. Márquez", "Gabriel Márquez"]),
                       ["García Márquez, Gabriel", "G. G. Márquez"], "Con menos palabras no es el mismo")
    }

    func testRenumberKeepsOrderAndPutsUnnumberedLast() {
        let a = Book(title: "Tomo uno", seriesIndex: 1)
        let b = Book(title: "Tomo tres", seriesIndex: 3.5)
        let c = Book(title: "Anexo")
        let changed = CatalogRename.renumber([c, b, a])
        XCTAssertEqual(changed.map(\.title), ["Tomo tres", "Anexo"], "El tomo uno ya era 1")
        XCTAssertEqual(changed.map(\.seriesIndex), [2, 3])
    }
}
