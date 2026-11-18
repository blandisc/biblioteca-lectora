import XCTest
@testable import LectoraCore

final class SessionTests: XCTestCase {
    let book = UUID()
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    /// Páginas seguidas de `words` palabras leídas a `wpm`.
    func pages(from start: Date, count: Int, words: Int = 250, wpm: Double = 230, fraction: Double = 0) -> [PageView] {
        var result: [PageView] = []
        var cursor = start
        let dwell = Double(words) / wpm * 60
        for i in 0..<count {
            let end = cursor.addingTimeInterval(dwell)
            result.append(PageView(start: cursor, end: end, words: words, fraction: fraction + Double(i) * 0.001))
            cursor = end
        }
        return result
    }

    func testSustainedReadingBecomesImmersed() throws {
        // 20 minutos seguidos: 5 ligera, 10 activa, 5 inmersa.
        let views = pages(from: t0, count: 19) // ~65 s por página
        let session = try XCTUnwrap(SessionClassifier().session(bookID: book, device: "iphone", pages: views))
        XCTAssertEqual(session.seconds(in: .light), 300, accuracy: 1)
        XCTAssertEqual(session.seconds(in: .active), 600, accuracy: 1)
        XCTAssertGreaterThan(session.seconds(in: .immersed), 300)
        XCTAssertEqual(session.words, 19 * 250)
        XCTAssertEqual(session.wordsPerMinute, 230)
        XCTAssertEqual(session.times(in: .interrupted), 0)
    }

    func testLeavingTheAppInterruptsAndRestartsTheStreak() throws {
        var views = pages(from: t0, count: 6)           // ~6.5 min
        let back = views.last!.end.addingTimeInterval(180) // 3 min fuera
        views += pages(from: back, count: 3)
        let session = try XCTUnwrap(SessionClassifier().session(bookID: book, device: "iphone", pages: views))
        XCTAssertEqual(session.times(in: .interrupted), 1)
        XCTAssertEqual(session.seconds(in: .interrupted), 180, accuracy: 1)
        // Al volver empieza otra vez ligera.
        XCTAssertEqual(session.segments.last?.stage, .light)
        XCTAssertEqual(session.longestStreak, 6.0 * 250 / 230 * 60, accuracy: 2)
    }

    func testStalledPageCountsOnlyAReasonableTime() throws {
        // Una página de 250 palabras abierta 10 minutos: se leen ~2.7 min, el resto es pausa.
        let view = PageView(start: t0, end: t0.addingTimeInterval(600), words: 250)
        let session = try XCTUnwrap(SessionClassifier().session(bookID: book, device: "iphone", pages: [view]))
        XCTAssertEqual(session.readingSeconds, 250.0 / 230 * 60 * 2.5, accuracy: 1)
        XCTAssertEqual(session.seconds(in: .interrupted), 600 - session.readingSeconds, accuracy: 1)
    }

    func testFlippingPagesIsSkimmingAndDoesNotCountWords() throws {
        let views = pages(from: t0, count: 10, words: 300, wpm: 1500)
        let session = try XCTUnwrap(SessionClassifier().session(bookID: book, device: "iphone", pages: views))
        XCTAssertEqual(session.segments.map(\.stage), [.skimming])
        XCTAssertEqual(session.words, 0)
        XCTAssertEqual(session.readingSeconds, 0)
    }

    func testGoingBackDoesNotAddWords() throws {
        var views = pages(from: t0, count: 3)
        views[1].forward = false
        let session = try XCTUnwrap(SessionClassifier().session(bookID: book, device: "iphone", pages: views))
        XCTAssertEqual(session.words, 500)
    }

    func testLogAndWeek() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let iphone = SessionLog(directory: folder, device: "iphone")
        let mac = SessionLog(directory: folder, device: "mac")
        let classifier = SessionClassifier()
        let a = try XCTUnwrap(classifier.session(bookID: book, device: "iphone", pages: pages(from: t0, count: 5)))
        let b = try XCTUnwrap(classifier.session(bookID: book, device: "mac", pages: pages(from: t0.addingTimeInterval(86_400), count: 5)))
        try iphone.append(a)
        try mac.append(b)
        try mac.append(b) // repetida: cuenta una vez
        let all = iphone.readAll()
        XCTAssertEqual(all.map(\.id), [a.id, b.id])
        let period = ReadingPeriod(all)
        XCTAssertEqual(period.words, a.words + b.words)
        XCTAssertEqual(period.days(), 2)
        XCTAssertEqual(period.books().first?.sessions, 2)
    }
}

final class JobBoardTests: XCTestCase {
    let board = JobBoard(lease: 600, settle: 45)
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    func testSameJobOnBothDevicesIsOneJob() {
        var state = LibraryState()
        let iphone = HybridLogicalClock(node: "iphone")
        let mac = HybridLogicalClock(node: "mac")
        state.apply(board.enqueue(kind: "readwise.subrayado", target: "A", in: state, clock: iphone, now: t0))
        // El Mac aún no lo veía y lo anota también: mismo id.
        let fromMac = board.enqueue(kind: "readwise.subrayado", target: "A", in: LibraryState(), clock: mac, now: t0)
        state.apply(fromMac)
        XCTAssertEqual(JobBoard.jobs(in: state).count, 1)
        XCTAssertEqual(fromMac.first?.entityID, JobBoard.jobID(kind: "readwise.subrayado", target: "A"))
    }

    func testEarliestClaimWinsAndWaitsToSettle() throws {
        var state = LibraryState()
        let iphone = HybridLogicalClock(node: "iphone")
        let mac = HybridLogicalClock(node: "mac")
        state.apply(board.enqueue(kind: "hardcover.avance", target: "libro", in: state, clock: iphone, now: t0))
        let id = JobBoard.jobID(kind: "hardcover.avance", target: "libro")
        state.apply(board.claim(id, device: "mac", clock: mac, now: t0.addingTimeInterval(1)))
        state.apply(board.claim(id, device: "iphone", clock: iphone, now: t0.addingTimeInterval(2)))
        let job = try XCTUnwrap(JobBoard.job(id: id, in: state))
        XCTAssertEqual(board.owner(of: job, now: t0.addingTimeInterval(3)), "mac")
        // Todavía no: la toma tiene que asentarse.
        XCTAssertTrue(board.runnable(in: state, device: "mac", now: t0.addingTimeInterval(10)).isEmpty)
        XCTAssertEqual(board.runnable(in: state, device: "mac", now: t0.addingTimeInterval(60)).map(\.id), [id])
        XCTAssertTrue(board.runnable(in: state, device: "iphone", now: t0.addingTimeInterval(60)).isEmpty)
        // El Mac se apaga sin terminar: la toma vence y el iPhone lo retoma.
        XCTAssertEqual(board.owner(of: job, now: t0.addingTimeInterval(601.5)), "iphone")
        // Terminado: nadie más lo hace.
        state.apply(board.complete(id, device: "mac", clock: mac))
        XCTAssertTrue(board.runnable(in: state, device: "iphone", now: t0.addingTimeInterval(601.5)).isEmpty)
        XCTAssertTrue(board.claimable(in: state, device: "iphone", now: t0.addingTimeInterval(601.5)).isEmpty)
    }

    func testFailureBacksOff() throws {
        var state = LibraryState()
        let clock = HybridLogicalClock(node: "iphone")
        state.apply(board.enqueue(kind: "readwise.subrayado", target: "B", in: state, clock: clock, now: t0))
        let id = JobBoard.jobID(kind: "readwise.subrayado", target: "B")
        state.apply(board.claim(id, device: "iphone", clock: clock, now: t0))
        let job = try XCTUnwrap(JobBoard.job(id: id, in: state))
        state.apply(board.fail(job, device: "iphone", error: "Sin conexión", clock: clock, now: t0))
        XCTAssertTrue(board.claimable(in: state, device: "iphone", now: t0.addingTimeInterval(30)).isEmpty)
        XCTAssertEqual(board.claimable(in: state, device: "iphone", now: t0.addingTimeInterval(61)).count, 1)
        XCTAssertEqual(JobBoard.job(id: id, in: state)?.lastError, "Sin conexión")
    }
}
