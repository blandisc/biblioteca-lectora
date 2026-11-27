import Foundation
@testable import LectoraCore
import XCTest

/// Auditoría 2 (27 nov 2026): fallas altas verificadas. Cada prueba falla si vuelve.
final class AuditoriaDosTests: XCTestCase {
    private func tempDir(in base: URL = FileManager.default.temporaryDirectory) throws -> URL {
        let url = base.appendingPathComponent("auditoria2-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func names(in folder: URL) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).filter { $0 != ".DS_Store" }.sorted()
    }

    /// Carpetas hermanas que solo cambian en mayúsculas (en iCloud chocan): nunca debe haber.
    static func twins(in folder: URL) -> [String] {
        let entries = ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
        return Dictionary(grouping: entries, by: { $0.lowercased() }).values.filter { $0.count > 1 }.flatMap { $0 }.sorted()
    }

    private func makeBook(_ root: URL, _ relative: String) throws -> URL {
        let folder = root.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data(relative.utf8).write(to: folder.appendingPathComponent("libro.epub"))
        return folder
    }

    // MARK: 1 · El catálogo guarda la ruta que de verdad hay en el disco

    /// Importar o traer de Calibre un libro de «Julio Cortázar» cuando el disco ya tiene
    /// «julio cortázar/»: entra a esa carpeta y la ruta es la del disco (en la Mac, antes, el
    /// catálogo decía «Julio Cortázar/…» y el iPhone no encontraba el libro).
    private func checkNewFolderUsesDiskSpelling(in base: URL) throws {
        let root = try tempDir(in: base)
        _ = try makeBook(root, "julio cortázar/Rayuela (1)")
        let wanted = "Julio Cortázar/Bestiario (2)"
        XCTAssertEqual(FolderMove.diskSpelling(of: wanted, in: root), "julio cortázar/Bestiario (2)")
        let real = try FolderMove.createFolder(wanted, in: root)
        XCTAssertEqual(real, "julio cortázar/Bestiario (2)", "La ruta del catálogo es la del disco")
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(real).path))
        XCTAssertEqual(names(in: root), ["julio cortázar"])
        XCTAssertEqual(names(in: root.appendingPathComponent("julio cortázar")), ["Bestiario (2)", "Rayuela (1)"])
        // También el nivel del libro y del archivo.
        XCTAssertEqual(FolderMove.diskSpelling(of: "JULIO CORTÁZAR/rayuela (1)/LIBRO.EPUB", in: root),
                       "julio cortázar/Rayuela (1)/libro.epub")
        // Lo que no existe se queda como se pidió.
        XCTAssertEqual(FolderMove.diskSpelling(of: "Jorge Luis Borges/Ficciones (3)", in: root), "Jorge Luis Borges/Ficciones (3)")
        XCTAssertEqual(Self.twins(in: root), [])
    }

    func testNewFolderUsesDiskSpelling() throws {
        try checkNewFolderUsesDiskSpelling(in: FileManager.default.temporaryDirectory)
    }

    func testNewFolderUsesDiskSpellingOnCaseSensitiveDisk() throws {
        try checkNewFolderUsesDiskSpelling(in: try caseSensitiveBase())
    }

    // MARK: 2 · Corregir las mayúsculas de un autor no deja dos carpetas gemelas

    /// Dos libros de «julio cortázar»; corriges las mayúsculas de uno: en ningún disco aparece
    /// «Julio Cortázar/» al lado (en iCloud chocarían y la Mac renombraría una).
    private func checkNoTwinsWhenFixingCase(in base: URL) throws {
        let root = try tempDir(in: base)
        let rayuela = try makeBook(root, "julio cortázar/Rayuela (1)")
        let bestiario = try makeBook(root, "julio cortázar/Bestiario (2)")
        let placed = try FolderMove.moveBookFolder(rayuela, to: root.appendingPathComponent("Julio Cortázar/Rayuela (1)"))
        XCTAssertEqual(Self.twins(in: root), [], "Nunca dos carpetas que solo cambian en mayúsculas")
        XCTAssertEqual(names(in: root), ["julio cortázar"])
        XCTAssertEqual(placed.deletingLastPathComponent().lastPathComponent, "julio cortázar",
                       "El libro se queda con el nombre del disco")
        XCTAssertTrue(FileManager.default.fileExists(atPath: placed.appendingPathComponent("libro.epub").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: bestiario.appendingPathComponent("libro.epub").path))

        // Ya solo: el que se queda solo sí cambia la carpeta del autor (por un nombre temporal).
        try FileManager.default.removeItem(at: placed)
        let alone = try FolderMove.moveBookFolder(bestiario, to: root.appendingPathComponent("Julio Cortázar/Bestiario (2)"))
        XCTAssertEqual(names(in: root), ["Julio Cortázar"])
        XCTAssertEqual(alone.deletingLastPathComponent().lastPathComponent, "Julio Cortázar")
        XCTAssertTrue(FileManager.default.fileExists(atPath: alone.appendingPathComponent("libro.epub").path))

        // Otro autor que no existe: se crea, sin gemelas.
        let borges = try makeBook(root, "Julio Cortázar/Ficciones (3)")
        let moved = try FolderMove.moveBookFolder(borges, to: root.appendingPathComponent("Jorge Luis Borges/Ficciones (3)"))
        XCTAssertEqual(moved.deletingLastPathComponent().lastPathComponent, "Jorge Luis Borges")
        XCTAssertEqual(Self.twins(in: root), [])
    }

    func testNoTwinsWhenFixingCase() throws {
        try checkNoTwinsWhenFixingCase(in: FileManager.default.temporaryDirectory)
    }

    func testNoTwinsWhenFixingCaseOnCaseSensitiveDisk() throws {
        try checkNoTwinsWhenFixingCase(in: try caseSensitiveBase())
    }

    private func caseSensitiveBase() throws -> URL {
        guard let path = ProcessInfo.processInfo.environment["LECTORA_CASE_SENSITIVE_DIR"] else {
            throw XCTSkip("Sin disco sensible a mayúsculas (LECTORA_CASE_SENSITIVE_DIR)")
        }
        return URL(fileURLWithPath: path)
    }

    // MARK: 3 · Lo que guardo mientras iCloud baja no se pierde aunque cierres la app

    private func decode(_ data: Data) -> [String: Int]? { try? JSONDecoder().decode([String: Int].self, from: data) }
    private func encode(_ table: [String: Int]) -> Data? { try? JSONEncoder().encode(table) }

    func testPendingSideFileSurvivesClosingTheApp() throws {
        let cabinet = try tempDir()
        let file = cabinet.appendingPathComponent("Biblioteca/.lectora/estantes.json")
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: CloudFile.placeholder(for: file))
        let pending = PendingWrites.forCabinet(cabinet, base: try tempDir())

        let first = SideFile.persist(["nuevo": 1, "viejo": 7], keys: ["nuevo", "viejo"], at: file, pending: pending,
                                     decode: decode, encode: encode)
        XCTAssertFalse(first.written)
        XCTAssertEqual(first.table, ["nuevo": 1, "viejo": 7])
        // Quitas uno mientras espera.
        _ = SideFile.persist(["nuevo": 1], keys: ["viejo"], at: file, pending: pending, decode: decode, encode: encode)
        XCTAssertFalse(pending.isEmpty, "Lo pendiente se guarda en el dispositivo")

        // Cierras la app: la memoria ya no lo tiene, el dispositivo sí.
        let reopened = SideFile.persist([String: Int](), keys: [], at: file, pending: pending, decode: decode, encode: encode)
        XCTAssertFalse(reopened.written)
        XCTAssertEqual(reopened.table, ["nuevo": 1], "Tras cerrar la app, lo pendiente sigue ahí")

        // iCloud baja el archivo con lo de otro dispositivo: se junta y ya no queda nada pendiente.
        try FileManager.default.removeItem(at: CloudFile.placeholder(for: file))
        try XCTUnwrap(encode(["otro": 2, "viejo": 7])).write(to: file)
        let done = SideFile.persist([String: Int](), keys: [], at: file, pending: pending, decode: decode, encode: encode)
        XCTAssertTrue(done.written)
        XCTAssertEqual(done.table, ["nuevo": 1, "otro": 2])
        XCTAssertEqual(decode(try Data(contentsOf: file)), ["nuevo": 1, "otro": 2])
        XCTAssertTrue(pending.isEmpty)
        // Y nada de esto vive dentro del Gabinete.
        XCTAssertFalse(pending.directory.path.hasPrefix(cabinet.path))
    }

    func testPendingBelongsToItsCabinet() throws {
        let base = try tempDir()
        let mac = PendingWrites.forCabinet(URL(fileURLWithPath: "/Users/fer/iCloud/Gabinete"), base: base)
        let other = PendingWrites.forCabinet(URL(fileURLWithPath: "/Users/fer/Documentos/Gabinete"), base: base)
        XCTAssertNotEqual(mac.directory, other.directory)
        XCTAssertEqual(mac.directory, PendingWrites.forCabinet(URL(fileURLWithPath: "/Users/fer/iCloud/Gabinete/"), base: base).directory,
                       "El mismo Gabinete siempre encuentra lo suyo")
        let session = ["s1"]
        mac.set(session, "sesiones.json")
        XCTAssertEqual(mac.value("sesiones.json", as: [String].self), session)
        XCTAssertNil(other.value("sesiones.json", as: [String].self), "Lo de un Gabinete no se escribe en el diario de otro")
        mac.set([String]?.none, "sesiones.json")
        XCTAssertTrue(mac.isEmpty)
    }

    // MARK: Reglas (D2)

    /// Nada que guardes se tira en silencio: el registro se escribe con `appendOrKeep` (espera en
    /// el dispositivo) o comprobando si se pudo (y si no, no se tira nada).
    func testNothingIsDroppedWhenTheLogCannotBeWritten() {
        var problems: [String] = []
        for file in DesignRulesTests.sources("App/Shared") {
            for (index, line) in file.lines.enumerated() {
                let code = line.trimmingCharacters(in: .whitespaces)
                if code.hasPrefix("try? log.append") || code.hasPrefix("try? self.log.append") {
                    problems.append("\(file.path):\(index + 1): \(code)")
                }
            }
        }
        XCTAssertTrue(problems.isEmpty, "Si el registro no se puede escribir, el cambio espera (appendOrKeep):\n"
                      + problems.joined(separator: "\n"))
        let store = DesignRulesTests.sources("App/Shared/Library").first { $0.path.hasSuffix("LibraryStore.swift") }
        XCTAssertTrue(store?.text.contains("pending: pendingWrites") ?? false, "Lo de .lectora/ que espera se guarda en el dispositivo")
        let sessions = DesignRulesTests.sources("App/Shared/Library").first { $0.path.hasSuffix("SessionStore.swift") }
        XCTAssertTrue(sessions?.text.contains("PendingWrites.forCabinet") ?? false, "Las sesiones pendientes van con su Gabinete")
    }

    /// Las carpetas de los libros se crean con `FolderMove.createFolder` o `moveBookFolder`, que
    /// usan el nombre que ya está en el disco: nunca una gemela que solo cambia en mayúsculas.
    func testBookFoldersAreCreatedWithoutTwins() {
        let allowed = ["CabinetLocation.notes", "root.deletingLastPathComponent()", "at: destination",
                       "at: local"]
        var problems: [String] = []
        for file in DesignRulesTests.sources("App/Shared") {
            for (index, line) in file.lines.enumerated() where line.contains("createDirectory(") {
                let code = line.trimmingCharacters(in: .whitespaces)
                guard !code.hasPrefix("//"), !allowed.contains(where: { line.contains($0) }) else { continue }
                problems.append("\(file.path):\(index + 1): \(code)")
            }
        }
        XCTAssertTrue(problems.isEmpty, "Crea la carpeta de un libro con FolderMove.createFolder:\n" + problems.joined(separator: "\n"))
        let store = DesignRulesTests.sources("App/Shared/Library").first { $0.path.hasSuffix("LibraryStore.swift") }
        XCTAssertGreaterThanOrEqual(store?.text.components(separatedBy: "FolderMove.createFolder(").count ?? 0, 3,
                                    "Importar y traer de Calibre crean con FolderMove.createFolder")
    }
}
