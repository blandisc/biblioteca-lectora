import Foundation
@testable import LectoraCore
import XCTest

final class FolderMoveTests: XCTestCase {
    private func temporaryFolder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("folder-move-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testRefusesToMoveInsideItself() {
        let cabinet = URL(fileURLWithPath: "/Users/fer/Gabinete")
        XCTAssertEqual(FolderMove.problem(from: cabinet, to: cabinet.appendingPathComponent("Notas"), folders: [], exists: { _ in false }), .insideItself)
        XCTAssertEqual(FolderMove.problem(from: cabinet, to: URL(fileURLWithPath: "/Users/fer"), folders: [], exists: { _ in false }), .insideItself)
        XCTAssertEqual(FolderMove.problem(from: cabinet, to: URL(fileURLWithPath: "/users/FER/gabinete/x"), folders: [], exists: { _ in false }), .insideItself)
        XCTAssertEqual(FolderMove.problem(from: cabinet, to: URL(fileURLWithPath: "/Users/fer/iCloud/Gabinete"), folders: [], exists: { _ in false }), nil)
    }

    func testNeverOverwritesAnExistingFolder() throws {
        let source = try temporaryFolder(), destination = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: source); try? FileManager.default.removeItem(at: destination) }
        try FileManager.default.createDirectory(at: destination.appendingPathComponent("Notas"), withIntermediateDirectories: true)
        XCTAssertEqual(FolderMove.problem(from: source, to: destination, folders: ["Biblioteca", "Notas"]), .occupied("Notas"))
    }

    func testRenamesWhenOnlyCaseChanges() throws {
        let root = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: root) }
        let old = root.appendingPathComponent("gabriel garcía márquez")
        try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true)
        try Data("libro".utf8).write(to: old.appendingPathComponent("a.epub"))
        let new = root.appendingPathComponent("Gabriel García Márquez")
        try FolderMove.move(old, to: new)
        let names = try FileManager.default.contentsOfDirectory(atPath: root.path)
        XCTAssertEqual(names, ["Gabriel García Márquez"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: new.appendingPathComponent("a.epub").path))
    }

    func testMergeKeepsWhatOtherDevicesSaved() {
        let disk = ["estante B": 2, "estante A": 1]
        let mine = ["estante A": 10]
        XCTAssertEqual(FolderMove.merge(disk: disk, mine: mine, changed: ["estante A"]), ["estante A": 10, "estante B": 2])
        XCTAssertEqual(FolderMove.merge(disk: disk, mine: [:], changed: ["estante A"]), ["estante B": 2])
    }
}
