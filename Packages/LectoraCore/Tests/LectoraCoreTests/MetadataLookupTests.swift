import XCTest
@testable import LectoraCore

final class MetadataLookupTests: XCTestCase {
    private let googleJSON = Data(#"""
    {"items":[{"id":"abc","volumeInfo":{"title":"Rayuela","authors":["Julio Cortázar"],"publisher":"Alfaguara",
     "publishedDate":"1963-06-28","description":"Una novela abierta.","language":"es",
     "industryIdentifiers":[{"type":"ISBN_10","identifier":"8437604575"},{"type":"ISBN_13","identifier":"9788437604572"}],
     "categories":["Fiction"],"imageLinks":{"thumbnail":"http://books.google.com/books/content?id=abc&zoom=1&edge=curl"}}},
     {"id":"zzz","volumeInfo":{"title":"Guía de Rayuela","authors":["Otro Autor"]}}]}
    """#.utf8)

    private let openLibraryJSON = Data(#"""
    {"docs":[{"key":"/works/OL1W","title":"Rayuela","author_name":["Julio Cortázar"],"first_publish_year":1963,
     "isbn":["8437604575","9788437604572"],"publisher":["Cátedra"],"language":["spa"],"cover_i":12345,
     "subject":["Novela argentina"]}]}
    """#.utf8)

    func testParsesGoogleBooks() throws {
        let candidates = GoogleBooks.candidates(from: googleJSON)
        XCTAssertEqual(candidates.count, 2)
        let first = try XCTUnwrap(candidates.first)
        XCTAssertEqual(first.isbn, "9788437604572")
        XCTAssertEqual(first.summary, "Una novela abierta.")
        XCTAssertEqual(first.coverURL?.absoluteString, "https://books.google.com/books/content?id=abc&zoom=0")
    }

    func testParsesOpenLibrary() throws {
        let first = try XCTUnwrap(OpenLibrary.candidates(from: openLibraryJSON).first)
        XCTAssertEqual(first.published, "1963")
        XCTAssertEqual(first.isbn, "9788437604572")
        XCTAssertEqual(first.coverURL?.absoluteString, "https://covers.openlibrary.org/b/id/12345-L.jpg")
        XCTAssertEqual(OpenLibrary.workDescription(from: Data(#"{"description":{"value":"Texto"}}"#.utf8)), "Texto")
    }

    func testScoresAndRanks() {
        let book = Book(title: "Rayuela", authors: ["Julio Cortázar"])
        let ranked = MetadataMatcher.rank(GoogleBooks.candidates(from: googleJSON), for: book)
        XCTAssertEqual(ranked.first?.title, "Rayuela")
        XCTAssertGreaterThanOrEqual(ranked.first!.confidence, MetadataMatcher.autoApplyThreshold)
        // Otro autor y otro título: por debajo de lo que se aplica solo.
        XCTAssertTrue(ranked.dropFirst().allSatisfy { $0.confidence < MetadataMatcher.autoApplyThreshold })

        let withISBN = Book(title: "Archivo raro", identifiers: ["isbn": "978-84-376-0457-2"])
        XCTAssertEqual(MetadataMatcher.score(ranked[0], for: withISBN), 0.98)
    }

    func testTitleSimilarityIgnoresAccentsArticlesAndSubtitles() {
        XCTAssertEqual(MetadataMatcher.titleSimilarity("La sombra del viento", "Sombra del Viento", subtitle: nil), 1)
        XCTAssertEqual(MetadataMatcher.titleSimilarity("Sapiens De animales a dioses", "Sapiens",
                                                       subtitle: "De animales a dioses"), 1)
        XCTAssertLessThan(MetadataMatcher.titleSimilarity("Rayuela", "Guía de Rayuela", subtitle: nil), 1)
    }

    func testFillMissingKeepsWhatTheFileBrought() {
        let book = Book(title: "Rayuela", authors: ["Julio Cortázar"], publisher: "Sudamericana")
        let candidate = MetadataMatcher.enrich(GoogleBooks.candidates(from: googleJSON)[0],
                                               with: OpenLibrary.candidates(from: openLibraryJSON))
        let filled = MetadataMatcher.fillMissing(book, from: candidate)
        XCTAssertEqual(filled.publisher, "Sudamericana")
        XCTAssertEqual(filled.summary, "Una novela abierta.")
        XCTAssertEqual(filled.identifiers["isbn"], "9788437604572")
        XCTAssertEqual(filled.published, "1963-06-28")
    }

    func testReplaceKeepsIdentityAndFile() {
        let id = UUID()
        let book = Book(id: id, title: "rayuela final", filePath: "X/rayuela (3)/r.epub", calibreID: 3)
        let replaced = MetadataMatcher.replace(book, with: GoogleBooks.candidates(from: googleJSON)[0])
        XCTAssertEqual(replaced.id, id)
        XCTAssertEqual(replaced.title, "Rayuela")
        XCTAssertEqual(replaced.calibreID, 3)
        XCTAssertEqual(replaced.filePath, "X/rayuela (3)/r.epub")
    }
}
