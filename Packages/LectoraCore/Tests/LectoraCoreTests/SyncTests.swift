import XCTest
@testable import LectoraCore

final class HybridLogicalClockTests: XCTestCase {
    func testTickIsMonotonicWhenWallClockStalls() {
        let clock = HybridLogicalClock(node: "a", now: { 1_000 })
        let first = clock.tick()
        let second = clock.tick()
        XCTAssertLessThan(first, second)
        XCTAssertEqual(second.counter, first.counter + 1)
    }

    func testTickIsMonotonicWhenWallClockGoesBackwards() {
        var time: Int64 = 5_000
        let clock = HybridLogicalClock(node: "a", now: { time })
        let first = clock.tick()
        time = 1_000
        XCTAssertLessThan(first, clock.tick())
    }

    func testReceiveOrdersLocalChangesAfterRemote() {
        let clock = HybridLogicalClock(node: "a", now: { 1_000 })
        let remote = HLC(wallMillis: 9_000, counter: 4, node: "b")
        clock.receive(remote)
        XCTAssertGreaterThan(clock.tick(), remote)
    }
}

final class LibraryStateTests: XCTestCase {
    private let bookID = UUID()

    private func change(_ wall: Int64, _ node: String, _ field: String, _ value: JSONValue) -> Change {
        Change(hlc: HLC(wallMillis: wall, counter: 0, node: node), entity: .book, entityID: bookID, field: field, value: value)
    }

    func testLastWriterWinsPerField() {
        var state = LibraryState()
        state.apply(change(1, "a", "title", .string("Viejo")))
        state.apply(change(2, "b", "title", .string("Nuevo")))
        state.apply(change(1, "a", "series", .string("Fundación")))
        let fields = state.fields(of: .book, id: bookID)
        XCTAssertEqual(fields?["title"], .string("Nuevo"))
        XCTAssertEqual(fields?["series"], .string("Fundación"))
    }

    func testApplyIsCommutativeAndIdempotent() {
        let changes = [
            change(3, "a", "title", .string("A")),
            change(3, "b", "title", .string("B")),
            change(1, "c", "tags", .array([.string("x")])),
            change(5, "a", "tags", .array([.string("y")])),
        ]
        var forward = LibraryState()
        forward.apply(changes)
        var backward = LibraryState()
        backward.apply(changes.reversed())
        backward.apply(changes)
        XCTAssertEqual(forward.entities, backward.entities)
        // Mismo milisegundo y contador: desempata el nodo ("b" > "a").
        XCTAssertEqual(forward.fields(of: .book, id: bookID)?["title"], .string("B"))
    }

    func testDeletedEntitiesAreHidden() {
        let clock = HybridLogicalClock(node: "a")
        var state = LibraryState()
        let annotation = Annotation(bookID: bookID, cfi: "epubcfi(/6/4!/4/2,/1:0,/1:5)", quote: "Hola")
        state.apply(annotation.changes(clock: clock))
        XCTAssertEqual(state.annotations(for: bookID).count, 1)
        state.apply(Annotation.deletion(id: annotation.id, clock: clock))
        XCTAssertTrue(state.annotations(for: bookID).isEmpty)
    }

    func testBookRoundTripsThroughChanges() {
        let clock = HybridLogicalClock(node: "a")
        let book = Book(
            title: "Cien años de soledad",
            authors: ["Gabriel García Márquez"],
            series: nil,
            tags: ["novela"],
            language: "es",
            identifiers: ["isbn": "9780307474728"],
            filePath: "Libros/García Márquez/Cien años de soledad.epub",
            readingStatus: .reading
        )
        var state = LibraryState()
        state.apply(book.changes(clock: clock))
        XCTAssertEqual(state.books(), [book])
    }
}

final class ChangeLogTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lectora-tests-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testTwoDevicesConvergeThroughSharedFolder() throws {
        let iphone = ChangeLog(directory: directory, deviceID: "iphone")
        let mac = ChangeLog(directory: directory, deviceID: "mac")
        let iphoneClock = HybridLogicalClock(node: "iphone")
        let macClock = HybridLogicalClock(node: "mac")

        let book = Book(title: "Sapiens", authors: ["Yuval Noah Harari"])
        try mac.append(book.changes(clock: macClock))
        let annotation = Annotation(bookID: book.id, cfi: nil, quote: "La revolución cognitiva")
        try iphone.append(annotation.changes(clock: iphoneClock))

        var fromIphone = LibraryState()
        fromIphone.apply(try iphone.readAll().changes)
        var fromMac = LibraryState()
        fromMac.apply(try mac.readAll().changes)

        XCTAssertEqual(fromIphone.entities, fromMac.entities)
        XCTAssertEqual(fromIphone.books().map(\.title), ["Sapiens"])
        XCTAssertEqual(fromIphone.annotations(for: book.id).map(\.quote), ["La revolución cognitiva"])
    }

    func testPartiallySyncedLineIsSkipped() throws {
        let log = ChangeLog(directory: directory, deviceID: "iphone")
        let clock = HybridLogicalClock(node: "iphone")
        try log.append(Book(title: "Rayuela").changes(clock: clock))
        // Simula un archivo que la nube todavía no terminó de bajar.
        let handle = try FileHandle(forWritingTo: log.ownFile)
        _ = try handle.seekToEnd()
        try handle.write(contentsOf: Data("{\"id\":\"trunc".utf8))
        try handle.close()

        let result = try log.readAll()
        XCTAssertEqual(result.skippedLines, 1)
        var state = LibraryState()
        state.apply(result.changes)
        XCTAssertEqual(state.books().map(\.title), ["Rayuela"])
    }
}
