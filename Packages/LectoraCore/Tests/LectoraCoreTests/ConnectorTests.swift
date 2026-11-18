import Foundation
import XCTest
@testable import LectoraCore

/// Respuestas escritas a mano, y lo que se pidió.
final class FakeTransport: HTTPTransport, @unchecked Sendable {
    var responses: [(Int, String)]
    private(set) var requests: [URLRequest] = []

    init(_ responses: [(Int, String)]) { self.responses = responses }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let (status, body) = responses.isEmpty ? (200, "{}") : responses.removeFirst()
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (Data(body.utf8), response)
    }
}

final class ReadwiseTests: XCTestCase {
    func testSendsHighlightsWithPassageLinkAndReadsTheirIDs() async throws {
        let transport = FakeTransport([(200, #"[{"id": 1, "title": "Rayuela", "modified_highlights": [987]}]"#)])
        let client = ReadwiseClient(token: " abc ", transport: transport)
        let id = UUID()
        let result = try await client.send([.init(annotationID: id, text: "Andábamos sin buscarnos", title: "Rayuela",
                                                  author: "Julio Cortázar", note: "La Maga", location: 12, highlightedAt: Date())])
        XCTAssertEqual(result[id], "987")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Token abc")
        XCTAssertEqual(request.httpMethod, "POST")
        let body = try XCTUnwrap(request.httpBody.flatMap { try JSONSerialization.jsonObject(with: $0) as? [String: Any] })
        let first = try XCTUnwrap((body["highlights"] as? [[String: Any]])?.first)
        XCTAssertEqual(first["source_type"] as? String, "gabinete")
        XCTAssertEqual(first["highlight_url"] as? String, "gabinete://subrayado/\(id.uuidString)")
    }

    func testBadKeyIsExplained() async {
        let client = ReadwiseClient(token: "x", transport: FakeTransport([(401, "")]))
        do {
            try await client.verify()
            XCTFail("Debía fallar")
        } catch {
            XCTAssertEqual(error as? ConnectorError, .badKey)
        }
    }

    func testExportFollowsPagesAndKnowsWhatCameFromGabinete() async throws {
        let mine = UUID()
        let page1 = """
        {"count": 3, "nextPageCursor": "abc", "results": [
          {"title": "Sapiens", "readable_title": "Sapiens", "author": "Yuval Noah Harari", "source": "kindle",
           "highlights": [{"id": 1, "text": "Somos animales", "note": "", "updated_at": "2026-11-01T10:00:00Z", "is_deleted": false}]}
        ]}
        """
        let page2 = """
        {"count": 3, "nextPageCursor": null, "results": [
          {"title": "Rayuela", "author": "Julio Cortázar", "source": "gabinete",
           "highlights": [{"id": 2, "text": "Andábamos", "note": "nota nueva", "url": "gabinete://subrayado/\(mine.uuidString)"}]}
        ]}
        """
        let transport = FakeTransport([(200, page1), (200, page2)])
        let incoming = try await ReadwiseClient(token: "t", transport: transport).export(updatedAfter: nil)
        XCTAssertEqual(incoming.map(\.id), ["1", "2"])
        XCTAssertFalse(incoming[0].isFromGabinete)
        XCTAssertNil(incoming[0].note)
        XCTAssertTrue(incoming[1].isFromGabinete)
        XCTAssertEqual(incoming[1].gabineteAnnotationID, mine)
        XCTAssertEqual(transport.requests.last?.url?.query, "pageCursor=abc")

        // Lo de Kindle se crea; lo nuestro solo trae el cambio de nota, sin duplicarse.
        let book = UUID()
        let existing = [Annotation(id: mine, bookID: book, cfi: "epubcfi(/6/4)", quote: "Andábamos", note: nil, readwiseID: nil)]
        let actions = ReadwiseMerge.actions(incoming: incoming, existing: existing)
        XCTAssertEqual(actions, [.create(incoming[0]), .update(annotationID: mine, text: "Andábamos", note: "nota nueva")])
    }

    func testDeletedInReadwiseIsDeletedHere() {
        let annotation = Annotation(bookID: UUID(), cfi: nil, quote: "x", readwiseID: "5", source: "readwise")
        let gone = ReadwiseClient.Incoming(id: "5", text: "x", note: nil, highlightedAt: nil, updatedAt: nil, url: nil,
                                           isDeleted: true, bookTitle: "Libro", bookAuthor: nil, bookSource: "kindle")
        XCTAssertEqual(ReadwiseMerge.actions(incoming: [gone], existing: [annotation]), [.delete(annotationID: annotation.id)])
    }

    func testMatchesTheBookInYourLibrary() {
        let books = [Book(title: "Sapiens: De animales a dioses", authors: ["Yuval Noah Harari"]),
                     Book(title: "Rayuela", authors: ["Julio Cortázar"])]
        let highlight = ReadwiseClient.Incoming(id: "1", text: "x", note: nil, highlightedAt: nil, updatedAt: nil, url: nil,
                                                isDeleted: false, bookTitle: "Sapiens", bookAuthor: "Yuval Noah Harari", bookSource: "kindle")
        XCTAssertEqual(ReadwiseMerge.book(for: highlight, in: books)?.title, "Sapiens: De animales a dioses")
        XCTAssertEqual(ReadwiseMerge.outsideBookID(title: "Libro", author: "A"), ReadwiseMerge.outsideBookID(title: "LIBRO", author: "a"))
    }

    func testCSVForReadwiseImport() {
        let annotation = Annotation(bookID: UUID(), cfi: nil, quote: "Dijo \"hola\", y se fue", note: "nota")
        let csv = ReadwiseCSV.export([(annotation, "Rayuela", "Julio Cortázar")])
        XCTAssertTrue(csv.hasPrefix("Highlight,Title,Author,URL,Note,Location,Date\n"))
        XCTAssertTrue(csv.contains(#""Dijo ""hola"", y se fue","Rayuela","Julio Cortázar""#))
    }
}

final class HardcoverTests: XCTestCase {
    func testTokenWithOrWithoutBearer() async throws {
        let transport = FakeTransport([(200, #"{"data": {"me": [{"id": 1, "username": "blandisc"}]}}"#)])
        let name = try await HardcoverClient(token: "Bearer xyz", transport: transport).verify()
        XCTAssertEqual(name, "blandisc")
        XCTAssertEqual(transport.requests.first?.value(forHTTPHeaderField: "Authorization"), "Bearer xyz")
    }

    func testSearchKeepsOnlyARealMatch() async throws {
        let results = #"{"hits": [{"document": {"id": 11, "title": "Rayuela", "author_names": ["Julio Cortázar"], "pages": 600}}, {"document": {"id": 12, "title": "Rayuela: guía de lectura", "author_names": ["Otro"]}}]}"#
        // Hardcover a veces manda los resultados como texto JSON.
        let escaped = results.replacingOccurrences(of: "\"", with: "\\\"")
        let transport = FakeTransport([(200, "{\"data\": {\"search\": {\"results\": \"\(escaped)\"}}}")])
        let match = try await HardcoverClient(token: "t", transport: transport)
            .find(title: "Rayuela", authors: ["Julio Cortázar"], isbn: nil)
        XCTAssertEqual(match, .init(id: 11, title: "Rayuela", authors: ["Julio Cortázar"], pages: 600))
    }

    func testGraphQLErrorsAreReported() async {
        let transport = FakeTransport([(200, #"{"errors": [{"message": "Could not verify JWT"}]}"#)])
        do {
            _ = try await HardcoverClient(token: "t", transport: transport).verify()
            XCTFail("Debía fallar")
        } catch {
            XCTAssertEqual(error as? ConnectorError, .badKey)
        }
    }

    func testStatusFollowsProgress() {
        XCTAssertEqual(HardcoverClient.status(for: 0), .wantToRead)
        XCTAssertEqual(HardcoverClient.status(for: 0.4), .reading)
        XCTAssertEqual(HardcoverClient.status(for: 1), .read)
    }

    func testApplyCreatesTheBookThenItsRead() async throws {
        let transport = FakeTransport([
            (200, #"{"data": {"me": [{"user_books": []}]}}"#),
            (200, #"{"data": {"insert_user_book": {"id": 77, "error": null}}}"#),
            (200, #"{"data": {"insert_user_book_read": {"id": 5, "error": null}}}"#),
        ])
        try await HardcoverClient(token: "t", transport: transport).apply(
            .init(bookID: 11, status: .reading, progress: 0.5, pages: 600, startedAt: Date(timeIntervalSince1970: 0), finishedAt: nil, rating: nil))
        XCTAssertEqual(transport.requests.count, 3)
        let last = try XCTUnwrap(transport.requests.last?.httpBody.flatMap { try JSONSerialization.jsonObject(with: $0) as? [String: Any] })
        let read = try XCTUnwrap((last["variables"] as? [String: Any])?["r"] as? [String: Any])
        XCTAssertEqual(read["progress_pages"] as? Int, 300)
        XCTAssertEqual(read["started_at"] as? String, "1970-01-01")
    }
}
