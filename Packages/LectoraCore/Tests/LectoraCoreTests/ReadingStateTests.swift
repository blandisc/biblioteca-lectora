import LectoraCore
import XCTest

/// Regla 8 (SD-3, 26 nov 2026): un libro está en el mismo grupo en el iPhone y la Mac.
final class ReadingStateTests: XCTestCase {
    func testWhatYouMarkWinsThenProgress() {
        XCTAssertEqual(ReadingState(.toRead, progress: 0), .toRead)
        XCTAssertEqual(ReadingState(.toRead, progress: 0.3), .reading)
        XCTAssertEqual(ReadingState(.reading, progress: 0), .reading)
        XCTAssertEqual(ReadingState(.reading, progress: 1), .finished)
        XCTAssertEqual(ReadingState(.finished, progress: 0.2), .finished)
        XCTAssertEqual(ReadingState(.abandoned, progress: 0.5), .abandoned)
    }

    func testNamesAndActions() {
        XCTAssertEqual(ReadingState.allCases.map(\.group), ["Leyendo", "Por leer", "Leídos", "Abandonados"])
        XCTAssertEqual(ReadingState.reading.openAction, "Seguir leyendo")
        XCTAssertEqual(ReadingState.toRead.openAction, "Empezar a leer")
        XCTAssertEqual(Set(ReadingState.allCases.map(\.symbol)).count, ReadingState.allCases.count, "Un símbolo por estado")
        for state in ReadingState.allCases { XCTAssertEqual(ReadingState(state.status), state) }
    }

    func testAuthorsAndCounts() {
        XCTAssertEqual(BookFields.authors("García Márquez, Gabriel & Mutis, Álvaro"), ["García Márquez, Gabriel", "Mutis, Álvaro"])
        XCTAssertEqual(BookFields.authorsText(["A", "B"]), "A & B")
        XCTAssertEqual(LibraryAction.findData(count: 1), "Buscar datos en internet")
        XCTAssertEqual(LibraryAction.findData(count: 3), "Buscar datos de 3 libros")
        XCTAssertEqual(1.counted("libro", "libros"), "1 libro")
        XCTAssertEqual(Set(SelectionAction.allCases.map(\.symbol)).count, SelectionAction.allCases.count)
    }
}
