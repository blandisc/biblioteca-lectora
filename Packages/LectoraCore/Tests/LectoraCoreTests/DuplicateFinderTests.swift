import Foundation
import XCTest
@testable import LectoraCore

final class DuplicateFinderTests: XCTestCase {
    func testTitleKeyIgnoresSubtitleArticleAndAccents() {
        XCTAssertEqual(DuplicateFinder.titleKey("Rayuela"), DuplicateFinder.titleKey("rayuela (Edición conmemorativa)"))
        XCTAssertEqual(DuplicateFinder.titleKey("El Mediterráneo: y el mundo mediterráneo"), "mediterraneo")
        XCTAssertEqual(DuplicateFinder.titleKey("The Hobbit"), DuplicateFinder.titleKey("Hobbit"))
    }

    func testFindsSameTitleWithLookalikeAuthorsOrSameISBN() {
        let a = Book(title: "Rayuela", authors: ["Julio Cortázar"], filePath: "a/Rayuela.epub")
        let b = Book(title: "Rayuela (Cátedra)", authors: ["Cortázar, Julio"], filePath: "b/Rayuela.pdf")
        let other = Book(title: "Rayuela", authors: ["Otra Persona"])
        let c = Book(title: "Hopscotch", authors: ["Julio Cortazar"], identifiers: ["isbn": "978-0-394-75284-6"])
        let d = Book(title: "Rayuela", authors: ["Julio Cortázar"], identifiers: ["isbn": "9780394752846"])
        let groups = DuplicateFinder.groups([a, b, other, c, d])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(Set(groups[0].map(\.id)), [a.id, b.id, c.id, d.id], "Por título y autor, y por ISBN")
        XCTAssertFalse(groups[0].contains { $0.id == other.id }, "Mismo título con otro autor no es duplicado")
    }

    func testDismissedPairsAreNotProposedAgain() {
        let a = Book(title: "Ficciones", authors: ["Borges"])
        let b = Book(title: "Ficciones", authors: ["Jorge Luis Borges"])
        XCTAssertEqual(DuplicateFinder.groups([a, b]).count, 1)
        XCTAssertTrue(DuplicateFinder.groups([a, b], dismissed: [DuplicateFinder.Pair(b.id, a.id)]).isEmpty)
    }

    func testMergedKeepsMineAndFillsTheRest() {
        let keep = Book(title: "Rayuela", authors: ["Julio Cortázar"], tags: ["Novela"], readingStatus: .toRead, summary: "Mía")
        let other = Book(title: "Rayuela", tags: ["novela", "Argentina"], identifiers: ["isbn": "1"],
                         readingStatus: .finished, publisher: "Cátedra", summary: "Otra")
        let merged = DuplicateFinder.merged(keep: keep, with: [other])
        XCTAssertEqual(merged.summary, "Mía")
        XCTAssertEqual(merged.publisher, "Cátedra")
        XCTAssertEqual(merged.tags, ["Novela", "Argentina"])
        XCTAssertEqual(merged.identifiers["isbn"], "1")
        XCTAssertEqual(merged.readingStatus, .finished)
    }

    func testPreferredKeepsTheOneWithHighlightsThenEPUB() {
        let pdf = Book(title: "X", filePath: "x.pdf")
        let epub = Book(title: "X", filePath: "x.epub")
        XCTAssertEqual(DuplicateFinder.preferred([pdf, epub], highlights: [:]), epub.id)
        XCTAssertEqual(DuplicateFinder.preferred([pdf, epub], highlights: [pdf.id: 3]), pdf.id)
    }

    func testExtraFilesTravelInTheRegistry() {
        var book = Book(title: "Rayuela", filePath: "Julio Cortázar/Rayuela (1)/Rayuela - Julio Cortázar.epub")
        book.extraFiles = ["Rayuela - Julio Cortázar.pdf"]
        XCTAssertEqual(book.formats, ["EPUB", "PDF"])
        var state = LibraryState()
        state.apply(book.changes(clock: HybridLogicalClock(node: "prueba")))
        XCTAssertEqual(state.books().first?.extraFiles, ["Rayuela - Julio Cortázar.pdf"])
        state.apply([Book.deletion(id: book.id, clock: HybridLogicalClock(node: "prueba"))])
        XCTAssertTrue(state.books().isEmpty, "Juntar borra el otro del registro")
    }
}
