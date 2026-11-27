import Foundation
@testable import LectoraCore
import XCTest

/// Auditoría 8 de pantallas (27 nov 2026): títulos en hebreo que revolvían su renglón, la cursiva
/// que quedaba en la vista previa, «Ordenar» mientras bajo de iCloud, el estante que se guardaba dos
/// veces, portadas repetidas, el autor «sin comparar» y textos que enseñaban sintaxis. Cada prueba
/// falla si vuelve.
final class AuditoriaOchoPantallasTests: XCTestCase {
    private func source(_ name: String, in folder: String = "App/Shared") -> String {
        DesignRulesTests.sources(folder).first { $0.path.hasSuffix("/" + name) }?.text ?? ""
    }

    // MARK: M2 · Un título en hebreo o árabe no revuelve su renglón

    func testIsolatedNamesKeepTheirDirection() {
        XCTAssertEqual("שלום עליכם".isolated, "\u{2068}שלום עליכם\u{2069}")
        let line = "\("שלום עליכם".isolated) · de 31 % a 36 %"
        XCTAssertTrue(line.hasPrefix("\u{2068}"), "El renglón empieza aislado: su dirección no cambia la del renglón")
        XCTAssertTrue(source("SessionSheet.swift", in: "App/Shared/Screens").contains("\"\\(title.isolated) · de \\(from) a \\(to)\""))
        XCTAssertTrue(source("ShelfBook.swift", in: "App/Shared/Model").contains("\"Nuevo · \\(author.isolated)\""))
    }

    // MARK: M3 · La vista previa quita la cursiva sin romper snake_case

    func testPreviewDropsItalicsButNotSnakeCase() {
        XCTAssertEqual(NoteMarkdown.previewLines(["Una *cursiva* y otra _cursiva_."]), ["Una cursiva y otra cursiva."])
        XCTAssertEqual(NoteMarkdown.previewLines(["**negrita** y *dos palabras*"]), ["negrita y dos palabras"])
        XCTAssertEqual(NoteMarkdown.previewLines(["la variable snake_case_name"]), ["la variable snake_case_name"])
        XCTAssertEqual(NoteMarkdown.previewLines(["5 * 3 * 2 = 30"]), ["5 * 3 * 2 = 30"])
        XCTAssertEqual(NoteMarkdown.previewLines(["2*3*4"]), ["2*3*4"])
        XCTAssertEqual(NoteMarkdown.previewLines(["un asterisco suelto *"]), ["un asterisco suelto *"])
        // El título no cambia: de él sale el nombre del archivo (auditoría 7).
        XCTAssertEqual(Note.title(of: "# Una *idea*"), "Una *idea*")
    }

    // MARK: M7 · Mientras bajo tu biblioteca de iCloud no ordeno

    func testTidyWaitsForICloud() {
        let store = source("LibraryStore.swift", in: "App/Shared/Library")
        guard let start = store.range(of: "func tidy() async -> TidyReport {") else { return XCTFail("Falta tidy()") }
        let body = store[start.upperBound...].prefix(600)
        // Y dice por qué no ordenó (auditoría 9, B5), no un informe vacío.
        XCTAssertTrue(body.contains("guard !waitingForCloud else {\n            report.notDone = EmptyCopy.tidyWhileDownloading"))
        let settings = source("SettingsScreen.swift", in: "App/Shared/Screens")
        XCTAssertTrue(settings.contains("LinkRow(title: \"Ordenar la biblioteca\") }\n                    // Mientras bajo tu biblioteca de iCloud, apagado; su razón va arriba, con las demás.\n                    .disabled(busy || model.cabinetChangeBlocked != nil)"))
        XCTAssertTrue(source("Components.swift", in: "App/Shared/Design").contains("ordenar la biblioteca o traer los libros de Calibre"),
                      "La razón dice que ordenar también espera")
    }

    // MARK: M8 · El mismo estante no se guarda dos veces

    func testSavedSearchIsNotOfferedTwice() {
        let shelf = SavedShelf(name: "Asimov", query: "autor:Asimov")
        XCTAssertEqual(SavedShelf.saved("autor:asimov", in: [shelf])?.id, shelf.id)
        XCTAssertEqual(SavedShelf.saved("  AUTOR:ÁSIMOV  ", in: [shelf])?.id, shelf.id)
        XCTAssertNil(SavedShelf.saved("autor:bradbury", in: [shelf]))
        XCTAssertNil(SavedShelf.saved("", in: [shelf]))
        let search = source("SearchScreen.swift", in: "App/Shared/Screens")
        XCTAssertTrue(search.contains("if let shelf = SavedShelf.saved(term, in: model.library.shelves) {"))
        XCTAssertTrue(search.contains("} else if !found.books.isEmpty {\n                TextAction(title: \"Guardar estos libros como estante\")"))
    }

    // MARK: M9 · Portadas de internet sin repetir

    func testCoverOptionsHaveNoRepeats() {
        let a = URL(string: "https://covers.openlibrary.org/b/id/123-L.jpg?default=false")!
        let b = URL(string: "http://covers.openlibrary.org/b/id/123-M.jpg")!
        let c = URL(string: "https://covers.openlibrary.org/b/id/456-L.jpg?default=false")!
        let g1 = URL(string: "https://books.google.com/books/publisher/content/images/frontcover/XYZ?fife=w800-h1200&source=gbs_api")!
        let g2 = URL(string: "https://books.google.com/books/content?id=XYZ&printsec=frontcover&img=1&zoom=1")!
        XCTAssertEqual(CoverDedupe.distinct([a, b, c, g1, g2]), [a, c, g1])
        // Ya bajadas: la misma imagen con otra dirección sale una vez, y la que ya tiene el libro no sale.
        let same = Data("imagen".utf8), other = Data("otra".utf8), current = Data("la actual".utf8)
        let d = URL(string: "https://example.com/d.jpg")!, e = URL(string: "https://example.com/e.jpg")!
        XCTAssertEqual(CoverDedupe.distinct([(url: a, data: same), (url: c, data: same), (url: d, data: current),
                                             (url: e, data: other), (url: g1, data: nil)], current: current), [a, e])
        // Mientras bajan, sin repetir por sus bytes (auditoría 9, B2: el tope va después).
        XCTAssertTrue(source("LibraryStore.swift", in: "App/Shared/Library").contains("collector.accept(url, data, rank: rank)"))
    }

    // MARK: B · El autor se compara aunque traiga acentos escritos aparte

    func testAuthorsWithCombiningMarksAreCompared() {
        let decomposed = "Josefina Pla\u{0301}"
        XCTAssertTrue(TextMatch.isLatin(decomposed))
        XCTAssertTrue(TextMatch.isLatin("Ñandutí g\u{0303}uasu"))
        XCTAssertEqual(TextMatch.sameAuthorScore([decomposed], ["Josefina Plá"]), 1)
        XCTAssertFalse(TextMatch.isLatin("Лев Толстой"), "Otra escritura sigue sin compararse")
    }

    // MARK: B · Textos en palabras, una sola salida y sin conteos de cero

    func testEmptyScreensSpeakInWords() {
        XCTAssertFalse(source("WelcomeScreen.swift", in: "App/Shared/Screens").contains("\"Ahora no\""),
                       "En Readwise, «Ahora no» hacía lo mismo que «Ir a la biblioteca»")
        let notebook = source("NotebookScreen.swift", in: "App/Shared/Screens")
        XCTAssertTrue(notebook.contains("case .notes where notes.isEmpty, .highlights where highlights.isEmpty:"), "Sin «0 notas»")
        let reader = source("ReaderView.swift", in: "App/Shared/Reader")
        XCTAssertTrue(reader.contains("justify: !dynamicTypeSize.isAccessibilitySize"), "Con la letra de accesibilidad, a la izquierda")
        let calibre = DesignRulesTests.sources("Packages/LectoraCore/Sources").first { $0.path.hasSuffix("CalibreLibrary.swift") }?.text ?? ""
        XCTAssertFalse(calibre.contains("no tiene metadata.db"))
    }
}
