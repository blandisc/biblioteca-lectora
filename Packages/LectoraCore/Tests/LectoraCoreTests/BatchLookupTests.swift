import Foundation
import XCTest
@testable import LectoraCore

final class BatchLookupTests: XCTestCase {
    func testWhatNeedsData() {
        var complete = Book(title: "Rayuela", identifiers: ["isbn": "9788437604572"], publisher: "Cátedra",
                            published: "1963", summary: "Una novela.")
        XCTAssertFalse(BatchLookup.needsData(complete, hasCover: true))
        XCTAssertTrue(BatchLookup.needsData(complete, hasCover: false), "Sin portada")
        complete.summary = ""
        XCTAssertTrue(BatchLookup.needsData(complete, hasCover: true), "Sin sinopsis")
    }

    func testProgressTally() {
        var progress = BatchLookup.Progress(total: 5)
        for decision: MetadataService.Decision in [.apply, .apply, .review, .notFound] { progress.record(decision) }
        XCTAssertFalse(progress.finished)
        progress.record(.unreachable)
        XCTAssertTrue(progress.finished)
        XCTAssertEqual(progress.done, 4)
        XCTAssertEqual(progress.summary, "2 completados · 1 por revisar · 1 sin encontrar · 1 pendiente sin internet")
        XCTAssertEqual(BatchLookup.Progress(total: 0).summary, "Nada que cambiar")
    }
}
