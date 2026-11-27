import Foundation
@testable import LectoraCore
import XCTest

/// Auditoría 4, pantallas (27 nov 2026): la tabla de la Mac con la ficha, los vacíos que siguen a
/// iCloud y los textos que se leían mal. Cada prueba falla si vuelve.
final class AuditoriaCuatroPantallasTests: XCTestCase {
    private func source(_ name: String) -> String {
        DesignRulesTests.ui.first { $0.path.hasSuffix("/" + name) }?.text ?? ""
    }

    // MARK: U1 · B1 · La tabla de la Mac reparte sus columnas al cambiar de ancho y no pierde dónde ibas

    func testMacTableRelaysOutAndKeepsYourPlace() {
        let table = source("MacBookTable.swift")
        XCTAssertTrue(table.contains("@SceneStorage(\"mac.columnas.ficha\")") && table.contains("columnCustomization: $narrowColumns"),
                      "Cada tabla guarda sus columnas aparte: la de la ficha no toma los anchos de la ancha")
        XCTAssertTrue(table.contains(".id(TableLayoutKey(inspector: showsInspector, widthStep: settledStep))")
                      && table.contains(".onGeometryChange(for: Int.self) { Int($0.size.width / Theme.Mac.column) }"),
                      "Al cambiar el ancho (ventana o ficha) la tabla vuelve a repartir sus columnas")
        XCTAssertTrue(table.components(separatedBy: "max: Theme.Mac.nameColumnMax").count - 1 == 2,
                      "Autor y serie tienen tope: lo que sobra va al título (auditoría 5)")
        XCTAssertTrue(table.contains("scroller.scrollTo(id, anchor: firstVisible == nil ? .center : .top)"), "Al volver a armarse, regresa a donde ibas")
        XCTAssertTrue(table.contains("hiddenSortLine") && table.contains("\"por \\(column.name)\""),
                      "Un orden por una columna que no se ve se dice en la barra")
    }

    // MARK: U3 · Hardcover dice en palabras dónde guarda su número

    func testHardcoverFooterSpeaksWords() {
        let screen = source("ConnectorScreen.swift")
        XCTAssertFalse(screen.contains("hardcover:…") || screen.contains("en el OPF"), "Ni la clave cruda ni el nombre del formato")
        XCTAssertTrue(screen.contains("guardo su número de Hardcover en los datos del libro, también en los que lee Calibre"))
    }

    // MARK: U4 · Ir a la letra no se lee como otro orden

    func testLetterJumpIsNotASort() {
        let jump = DesignRulesTests.piece("LetterJumpMenu")
        XCTAssertFalse(jump.contains("text: \"A–Z\""), "«A–Z ⌄» junto a «TÍTULO ⇅» se leía como un orden")
        XCTAssertTrue(jump.contains("text: \"Letra\"") && jump.contains("accessibilityLabel(\"Ir a la letra\")"))
    }

    // MARK: U6 · La cifra de una fila no se separa de su flecha

    func testRowValueKeepsItsChevron() {
        let row = DesignRulesTests.piece("LinkRow")
        XCTAssertTrue(row.contains("if chevron, value != nil || status != nil { chevronMark }"),
                      "Con un valor, la flecha va pegada a él (con la letra más grande bajaban por separado)")
        XCTAssertEqual(row.components(separatedBy: "{ chevronMark }").count - 1, 2, "La flecha sale una sola vez por fila")
    }

    // MARK: U7 · Sin libros no hay nada que ordenar

    func testEmptyLibraryHasNoSort() {
        let screen = source("LibraryScreen.swift")
        guard let sort = screen.range(of: "SortMenu(options: LibrarySort.allCases") else { return XCTFail("La Biblioteca ordena") }
        let before = screen[..<sort.lowerBound].suffix(160)
        XCTAssertTrue(before.contains("if !books.isEmpty {"), "El orden solo sale con libros a la vista")
    }

    // MARK: U8 · Los dos botones del resumen caben en un renglón

    func testSessionSummaryButtonsFitOneRow() {
        let sheet = source("SessionSheet.swift")
        XCTAssertFalse(sheet.contains("\"Cerrar el resumen\""), "No cabía en medio ancho y los botones iban uno bajo otro")
        XCTAssertTrue(sheet.contains("PrimaryButton(title: \"Cerrar resumen\", fillsWidth: true)"))
    }
}
