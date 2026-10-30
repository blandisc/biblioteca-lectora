import XCTest
@testable import LectoraCore

final class NotesTests: XCTestCase {
    let text = """
    # El silencio en Rulfo

    Comala no se describe: se oye. En [[Pedro Páramo]] nadie explica nada.
    Lo mismo pasa en [[Bestiario|los cuentos de Cortázar]] y otra vez en [[pedro paramo]].

    > Vine a Comala porque me dijeron que acá vivía mi padre.
    > — [[Pedro Páramo]] · [ir al pasaje](gabinete://subrayado/0D3C3C8E-3A3B-4C67-9E1F-2B0C1E1E2A10)
    """

    func testTitleAndPreview() {
        let note = Note(fileName: "x", text: text)
        XCTAssertEqual(note.title, "El silencio en Rulfo")
        XCTAssert(note.preview.hasPrefix("Comala no se describe: se oye. En Pedro Páramo nadie explica nada. Lo mismo pasa en los cuentos de Cortázar"))
        XCTAssertEqual(Note(fileName: "Vacía", text: "\n\n").title, "Vacía")
    }

    func testBookLinks() {
        let note = Note(fileName: "x", text: text)
        // «pedro paramo» es el mismo libro que «Pedro Páramo».
        XCTAssertEqual(note.bookLinks, ["Pedro Páramo", "Bestiario"])
        XCTAssert(note.links(bookTitle: "PEDRO PÁRAMO"))
        XCTAssert(!note.links(bookTitle: "Rayuela"))
    }

    func testBlocks() {
        let blocks = NoteMarkdown.blocks(text)
        XCTAssertEqual(blocks.count, 3)
        XCTAssertEqual(blocks[0], .heading("El silencio en Rulfo"))
        if case .quote(let quote) = blocks[2] {
            XCTAssert(quote.hasPrefix("Vine a Comala"))
        } else {
            XCTFail("Falta la cita")
        }
    }

    func testLinksInsideTheApp() throws {
        let line = NoteMarkdown.resolvingLinks("En [[Pedro Páramo]] y [[Bestiario|Cortázar]].")
        XCTAssert(line.contains("[Pedro Páramo](gabinete://libro?titulo=Pedro%20P%C3%A1ramo)"))
        XCTAssert(line.contains("[Cortázar](gabinete://libro?titulo=Bestiario)"))
        let url = try XCTUnwrap(URL(string: "gabinete://libro?titulo=Pedro%20P%C3%A1ramo"))
        XCTAssertEqual(NoteMarkdown.target(of: url), .book(title: "Pedro Páramo"))
        let id = UUID()
        XCTAssertEqual(NoteMarkdown.target(of: NoteMarkdown.passageURL(annotationID: id)), .passage(annotationID: id))
    }

    func testQuoteFromHighlight() {
        let id = UUID()
        let quote = NoteMarkdown.quote("Le apreté sus manos.", bookTitle: "Pedro Páramo", annotationID: id)
        XCTAssertEqual(quote, "> Le apreté sus manos.\n> — [[Pedro Páramo]] · [ir al pasaje](gabinete://subrayado/\(id.uuidString))")
        let note = NoteMarkdown.appending(quote, to: "# Rulfo\n\nIdea.\n\n")
        XCTAssertEqual(note, "# Rulfo\n\nIdea.\n\n" + quote + "\n")
    }

    func testSuggestBookWhileTyping() {
        XCTAssertEqual(NoteMarkdown.openLinkQuery(in: "Lo mismo en [[Cort"), "Cort")
        XCTAssertEqual(NoteMarkdown.openLinkQuery(in: "Ya cerrado [[Rayuela]] y más"), nil)
        XCTAssertEqual(NoteMarkdown.completingLink(in: "Lo mismo en [[Cort", with: "Bestiario"), "Lo mismo en [[Bestiario]] ")
    }

    func testFilesInFolder() throws {
        let folder = NoteFolder(url: FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true))
        defer { try? FileManager.default.removeItem(at: folder.url) }

        let first = try folder.save(text: "# Ideas: sueltas / varias\n\nUna.")
        XCTAssertEqual(first.fileName, "Ideas sueltas varias")
        let second = try folder.save(text: "# Ideas: sueltas / varias\n\nOtra.")
        XCTAssertEqual(second.fileName, "Ideas sueltas varias 2")

        // Cambiar el título renombra el archivo.
        let renamed = try folder.save(text: "# Lecturas de noviembre\n\nUna.", fileName: first.fileName)
        XCTAssertEqual(renamed.fileName, "Lecturas de noviembre")
        XCTAssert(FileManager.default.fileExists(atPath: folder.file(for: "Lecturas de noviembre").path))
        XCTAssert(!FileManager.default.fileExists(atPath: folder.file(for: "Ideas sueltas varias").path))

        // Lo que no es .md se queda como está.
        try Data("{}".utf8).write(to: folder.url.appendingPathComponent("config.json"))
        XCTAssertEqual(folder.all().count, 2)

        try folder.delete(fileName: renamed.fileName)
        XCTAssertEqual(folder.all().map(\.fileName), ["Ideas sueltas varias 2"])
    }
}
