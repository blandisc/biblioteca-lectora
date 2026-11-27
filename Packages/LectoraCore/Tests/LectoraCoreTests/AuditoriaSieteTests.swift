import Foundation
@testable import LectoraCore
import XCTest

/// Auditoría 7 (27 nov 2026): Gabinete nunca cambia el nombre de tus notas por su cuenta; abrir la
/// ficha no borra cómo acomodaste las columnas; un movimiento a medias no deja carpetas escondidas;
/// lo que no entró dice por qué; lo pendiente se busca con calma; deshacer solo regresa lo suyo y
/// se puede rehacer. Cada prueba falla si vuelve.
final class AuditoriaSieteTests: XCTestCase {
    private func tempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("auditoria7-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func source(_ name: String, in folder: String = "App/Shared") -> String {
        DesignRulesTests.sources(folder).first { $0.path.hasSuffix("/" + name) }?.text ?? ""
    }

    /// El texto de una función, de su firma a la siguiente.
    private func body(of signature: String, in text: String) -> String {
        guard let start = text.range(of: signature) else { return "" }
        let rest = text[start.upperBound...]
        let ends = ["\n    func ", "\n    private func ", "\n    nonisolated ", "\n    @discardableResult", "\n    static ",
                    "\n    /// "]
            .compactMap { rest.range(of: $0)?.lowerBound }
        return String(rest[..<(ends.min() ?? rest.endIndex)])
    }

    private var store: String { source("LibraryStore.swift") }

    // MARK: A1 · Gabinete nunca cambia el nombre de tus notas por su cuenta

    func testNotesNeverRenameThemselves() throws {
        // El título se lee como siempre: su número y sus comillas de código son parte de él.
        XCTAssertEqual(Note.title(of: "# 1. Introducción\n\nTexto"), "1. Introducción")
        XCTAssertEqual(Note.title(of: "# Usa `git` a diario"), "Usa `git` a diario")
        XCTAssertEqual(Note.title(of: "# **Rulfo** y [[Pedro Páramo]]"), "Rulfo y Pedro Páramo")

        let folder = NoteFolder(url: try tempDir())
        // Una nota que ya tenías con ese nombre: guardarla sin cambiar el título no la renombra.
        try Data("# 1. Introducción\n\nHola".utf8).write(to: folder.file(for: "1. Introducción"))
        let saved = try folder.save(text: "# 1. Introducción\n\nHola, otra vez", fileName: "1. Introducción")
        XCTAssertEqual(saved.fileName, "1. Introducción")
        XCTAssertNotNil(folder.read(folder.file(for: "1. Introducción")))
        XCTAssertNil(folder.read(folder.file(for: "Introducción")), "No aparece con otro nombre")

        // Una nota hecha en Obsidian con un nombre distinto de su título se queda con el suyo.
        try Data("# Lo que pienso de Rulfo\n\nUno".utf8).write(to: folder.file(for: "rulfo"))
        XCTAssertEqual(try folder.save(text: "# Lo que pienso de Rulfo\n\nUno y dos", fileName: "rulfo").fileName, "rulfo")

        // Si tú cambias el título, sí se renombra (como siempre).
        XCTAssertEqual(try folder.save(text: "# 2. Desarrollo\n\nHola", fileName: "1. Introducción").fileName, "2. Desarrollo")
        XCTAssertNil(folder.read(folder.file(for: "1. Introducción")))

        // La regla está escrita en la guía del repo.
        let guide = (try? String(contentsOf: DesignRulesTests.root.appendingPathComponent("CLAUDE.md"), encoding: .utf8)) ?? ""
        XCTAssertTrue(guide.contains("Gabinete nunca cambia el nombre de tus notas por su cuenta"))
    }

    // MARK: B2 · La vista previa solo quita las marcas de una lista de verdad

    func testPreviewKeepsNumbersThatAreNotLists() {
        XCTAssertEqual(Note(fileName: "x", text: "# Historia\n1984. Fue el año en que lo leí").preview, "1984. Fue el año en que lo leí")
        XCTAssertEqual(Note(fileName: "x", text: "# Ideas\nLeí 3 libros.\n2026. Otro año").preview, "Leí 3 libros. 2026. Otro año")
        // Una lista sí se lee sin sus números, guiones ni casillas.
        XCTAssertEqual(Note(fileName: "x", text: "# Pendientes\n1. Leer\n2. Subrayar\n- [ ] Anotar").preview, "Leer Subrayar Anotar")
        XCTAssertEqual(Note(fileName: "x", text: "# Ideas\n```\nlet a = 1\n```\nUsa `git`").preview, "let a = 1 Usa git")
    }

    // MARK: M1 · Abrir la ficha no borra cómo acomodaste las columnas

    func testColumnsKeepTheirOrderAndEachTableItsStep() {
        let old = Data(#"{"columnOrder":[{"base":{"explicit":{"_0":"autor"}}},{"base":{"explicit":{"_0":"titulo"}}}],"perColumnState":[{"base":{"explicit":{"_0":"autor"}}},{"visibility":{"visible":{}},"width":{"_0":300}}]}"#.utf8)
        let fresh = Data(#"{"perColumnState":[{"base":{"explicit":{"_0":"autor"}}},{"visibility":{"visible":{}}}]}"#.utf8)
        let kept = try? JSONSerialization.jsonObject(with: ColumnLayout.keepingOrder(of: old, in: fresh)) as? [String: Any]
        XCTAssertNotNil(kept?["columnOrder"], "El orden en que pusiste las columnas se queda")
        XCTAssertFalse(String(decoding: ColumnLayout.keepingOrder(of: old, in: fresh), as: UTF8.self).contains("300"), "Los anchos se van")
        XCTAssertEqual(ColumnLayout.keepingOrder(of: Data("roto".utf8), in: fresh), fresh, "Si no lo puedo leer, la tabla limpia")

        let table = source("MacBookTable.swift")
        XCTAssertTrue(table.contains("@SceneStorage(\"mac.columnas.ficha.paso\") private var savedNarrowStep"), "Un paso por tabla")
        XCTAssertTrue(table.contains("if next.widthStep < savedNarrowStep { narrowColumns = Self.withoutWidths(narrowColumns) }"))
        XCTAssertTrue(table.contains("if next.widthStep < savedStep { columns = Self.withoutWidths(columns) }"))
        XCTAssertFalse(table.contains("keepingVisibility"), "Ya no se quita el orden con los anchos")
        XCTAssertTrue(body(of: "static func withoutWidths(", in: table).contains("ColumnLayout.keepingOrder(of: saved, in: clean)"))
    }

    // MARK: M2 · Un movimiento a medias no deja carpetas escondidas para siempre

    func testLeftoverCopiesAreRemoved() throws {
        let destination = try tempDir()
        let manager = FileManager.default
        let mine = UUID().uuidString, fresh = UUID().uuidString, old = UUID().uuidString
        let names = [".gabinete-copia-\(mine)-Biblioteca", ".gabinete-copia-\(mine)-Notas", ".gabinete-copia-\(fresh)-Notas",
                     ".gabinete-copia-\(old)-Biblioteca", ".gabinete-copia-nada-Biblioteca", ".gabinete-copia-\(mine)-Fotos",
                     "Biblioteca", ".gabinete-copia-\(mine)-Biblioteca-2"]
        for name in names {
            try manager.createDirectory(at: destination.appendingPathComponent(name), withIntermediateDirectories: true)
        }
        let longAgo = Date().addingTimeInterval(-2 * StagedMove.othersAge)
        try manager.setAttributes([.creationDate: longAgo, .modificationDate: longAgo],
                                  ofItemAtPath: destination.appendingPathComponent(".gabinete-copia-\(old)-Biblioteca").path)
        let removed = StagedMove.removeLeftovers(in: destination, folders: ["Biblioteca", "Notas"], mine: [mine])
        XCTAssertEqual(Set(removed), [".gabinete-copia-\(mine)-Biblioteca", ".gabinete-copia-\(mine)-Notas", ".gabinete-copia-\(old)-Biblioteca"])
        let left = Set(try manager.contentsOfDirectory(atPath: destination.path))
        XCTAssertTrue(left.contains(".gabinete-copia-\(fresh)-Notas"), "La de otro aparato que podría estar copiando ahora se queda")
        XCTAssertTrue(left.isSuperset(of: ["Biblioteca", ".gabinete-copia-nada-Biblioteca", ".gabinete-copia-\(mine)-Fotos",
                                           ".gabinete-copia-\(mine)-Biblioteca-2"]), "Solo el nombre exacto de trabajo")

        // Al abrir la app y antes de mover, en el Gabinete en uso y donde este aparato copiaba.
        XCTAssertTrue(body(of: "init(root: URL = LibraryStore.defaultRoot) {", in: store).contains("removeLeftoverCopies()"))
        let cleanup = body(of: "private func removeLeftoverCopies() {", in: store)
        XCTAssertTrue(cleanup.contains("[cabinet] + pending.compactMap(\\.destination)") && cleanup.contains("StagedMove.removeLeftovers("))
        let move = body(of: "func move(toCabinet destination: URL) async throws {", in: store)
        guard let remember = move.range(of: "CabinetLocation.rememberStaging(token: staged.token, destination: destination)"),
              let clean = move.range(of: "StagedMove.removeLeftovers(in: destination, folders: topFolders, mine: earlier)"),
              let copy = move.range(of: "LibraryStore.coordinatedCopy(from: from, to: to)") else {
            return XCTFail("Mover anota su carpeta de trabajo y limpia el destino antes de copiar")
        }
        XCTAssertTrue(remember.upperBound <= copy.lowerBound && clean.upperBound <= copy.lowerBound)
        XCTAssertTrue(move.contains("defer { CabinetLocation.forgetStaging(tokens: [staged.token]) }"))
        XCTAssertTrue(move.contains("guard missing.isEmpty else {"), "Sin su carpeta de trabajo no se da por hecho ni se borra la tuya")
    }

    // MARK: M6 · Si no puedo regresar lo que puse, lo quito

    func testTakeBackRemovesWhatItCannotReturn() throws {
        let destination = try tempDir()
        let staged = StagedMove(destination: destination, folders: ["Biblioteca"])
        try FileManager.default.createDirectory(at: staged.staging("Biblioteca"), withIntermediateDirectories: true)
        XCTAssertEqual(try staged.place(), ["Biblioteca"])
        // Algo ocupó la carpeta de trabajo: regresarla falla.
        try Data("estorbo".utf8).write(to: staged.staging("Biblioteca"))
        staged.takeBack(["Biblioteca"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.appendingPathComponent("Biblioteca").path),
                       "Lo que puso esta corrida no se queda como un Gabinete a medias")
    }

    // MARK: B1 · Poner las carpetas en su lugar avisa a iCloud

    func testPlaceCoordinatesTheMove() {
        let work = source("LibraryWork.swift", in: "Packages/LectoraCore/Sources")
        let place = body(of: "public func place() throws -> [String] {", in: work)
        XCTAssertTrue(place.contains("try Self.coordinatedMove(from: staging(folder), to: target)") && !place.contains("manager.moveItem"))
        XCTAssertTrue(body(of: "public func takeBack(_ placed: [String]) {", in: work).contains("Self.coordinatedMove(from: target, to: staging(folder))"))
        let move = body(of: "static func coordinatedMove(from source: URL, to target: URL) throws {", in: work)
        XCTAssertTrue(move.contains("options: .forMoving") && move.contains("coordinator.item(at: from, didMoveTo: to)"))
    }

    // MARK: M3 · Lo que no entró dice por qué

    func testImportFailuresSayWhy() {
        let lines = ImportFailure.lines([
            .unreadable(name: "roto.epub"), .refused(reason: "Estoy ordenando tu biblioteca. Espera a que termine."),
            .stillDownloading(title: "Rayuela"), .unreadable(name: "vacío.pdf"),
            .refused(reason: "Estoy ordenando tu biblioteca. Espera a que termine."), .stillDownloading(title: "Ficciones"),
        ], preview: 3)
        XCTAssertEqual(lines, [
            "2 archivos no entraron a tu biblioteca: «roto.epub», «vacío.pdf». No los pude abrir como libros.",
            "No añadí 2 archivos. Estoy ordenando tu biblioteca. Espera a que termine.",
            "Todavía estoy bajando de iCloud archivos de 2 libros: «Rayuela», «Ficciones». Vuelve a intentarlo en un momento.",
        ])
        XCTAssertEqual(ImportFailure.lines([.refused(reason: "Estoy bajando."), .refused(reason: "Estoy bajando.")], preview: 3),
                       ["No añadí 2 archivos. Estoy bajando."], "Nunca «No los pude abrir» si no fue eso")
        let model = source("AppModel.swift")
        XCTAssertTrue(model.contains("ImportFailure.lines(failures.map(Self.importFailure), preview: Theme.Lists.preview)"))
        XCTAssertFalse(model.contains("No los pude abrir como libros"))
    }

    // MARK: M4 · Lo pendiente se busca con calma, una vuelta a la vez

    func testPendingLookupsRetryCalmly() {
        let retry = body(of: "func retryPendingLookups() async {", in: store)
        XCTAssertTrue(retry.contains("if let lookupRetry { return await lookupRetry.value }"), "Una vuelta a la vez")
        XCTAssertTrue(retry.contains("try? await Task.sleep(for: BatchLookup.pause)"), "Con pausa entre libros")
        XCTAssertTrue(retry.contains("!Task.isCancelled"), "Se puede detener")
        XCTAssertTrue(body(of: "func stopBatch() {", in: store).contains("stopPendingLookups()"))
        XCTAssertTrue(body(of: "private func releaseLock(_ work: LibraryWork) {", in: store).contains("lookupRetry == nil"))
    }

    // MARK: M5 · Deshacer un renombre solo quita las reglas que puso

    func testUndoRevertsOnlyItsRules() {
        let kept = MetadataRules.Rule(from: "Borges", to: "Jorge Luis Borges")
        let changedBefore = MetadataRules.Rule(from: "cuento", to: "Cuento")
        var changedAfter = changedBefore
        changedAfter.to = "Cuentos"
        let added = MetadataRules.Rule(from: "J. Cortázar", to: "Julio Cortázar")
        let addedTag = MetadataRules.Rule(from: "scifi", to: "Ciencia ficción")
        let before = MetadataRules(authors: [kept], tags: [changedBefore])
        let after = MetadataRules(authors: [kept, added], tags: [changedAfter, addedTag])
        // Después del cambio: hiciste una regla nueva y cambiaste a mano la etiqueta que añadió.
        let yours = MetadataRules.Rule(from: "Rulfo", to: "Juan Rulfo")
        var editedTag = addedTag
        editedTag.to = "Sci-fi"
        let now = MetadataRules(authors: [kept, added, yours], tags: [changedAfter, editedTag])
        let undone = now.undoing(from: before, after: after)
        XCTAssertEqual(undone.authors, [kept, yours], "La que añadió se va; la tuya se queda")
        XCTAssertEqual(undone.tags, [changedBefore, editedTag], "La que cambió regresa; la que cambiaste después se queda")

        let restore = body(of: "func restore(_ change: CatalogChange) -> CatalogChange {", in: store)
        XCTAssertTrue(restore.contains("rules.undoing(from: change.rulesBefore, after: change.rulesAfter)"))
        XCTAssertFalse(restore.contains("saveRules(change.rulesBefore)"), "Ya no se ponen todas las de antes encima")
        XCTAssertTrue(body(of: "func rename(_ rename: CatalogRename) -> CatalogChange {", in: store).contains("change.rulesAfter = learned"))
    }

    // MARK: B3 · Lo que deshaces se puede rehacer

    func testUndoRegistersRedo() {
        let window = source("MacLibraryWindow.swift")
        let perform = body(of: "private func perform(_ change: CatalogChange, named name: String, in undoManager: UndoManager) {", in: window)
        XCTAssertTrue(perform.contains("undoManager.registerUndo(withTarget: self)"), "Al deshacer se anota cómo rehacer")
        XCTAssertTrue(perform.contains("store.perform(done, named: name, in: undoManager)"), "Y rehacer se puede deshacer otra vez")
        XCTAssertFalse(window.contains("DispatchQueue.main.async { store.registerUndo"), "Volver a anotarlo como nuevo borraba lo de rehacer")
        let restore = body(of: "func restore(_ change: CatalogChange) -> CatalogChange {", in: store)
        XCTAssertTrue(restore.contains("undone.originals.append(current)") && restore.contains("undone.changed.append(saved)"),
                      "Lo deshecho es otro cambio: deshacerlo es rehacer")
        XCTAssertTrue(body(of: "func restoreWhenFree(_ change: CatalogChange, named name: String) -> PendingRestore {", in: store)
            .contains("await withCheckedContinuation { self.lockWaiters.append($0) }"), "Ocupado, lo hago en cuanto termine")
    }
}
