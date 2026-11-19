import Foundation
import SQLite3
import XCTest
@testable import LectoraCore

/// Una biblioteca de Calibre pequeña, con el esquema real (las tablas que se leen).
final class CalibreLibraryTests: XCTestCase {
    var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(folder.appendingPathComponent("metadata.db").path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }
        let sql = """
        CREATE TABLE books (id INTEGER PRIMARY KEY, title TEXT, sort TEXT, timestamp TIMESTAMP, pubdate TIMESTAMP,
          series_index REAL, author_sort TEXT, isbn TEXT, lccn TEXT, path TEXT, flags INTEGER, uuid TEXT, has_cover BOOL, last_modified TIMESTAMP);
        CREATE TABLE authors (id INTEGER PRIMARY KEY, name TEXT, sort TEXT, link TEXT);
        CREATE TABLE books_authors_link (id INTEGER PRIMARY KEY, book INTEGER, author INTEGER);
        CREATE TABLE tags (id INTEGER PRIMARY KEY, name TEXT);
        CREATE TABLE books_tags_link (id INTEGER PRIMARY KEY, book INTEGER, tag INTEGER);
        CREATE TABLE series (id INTEGER PRIMARY KEY, name TEXT, sort TEXT);
        CREATE TABLE books_series_link (id INTEGER PRIMARY KEY, book INTEGER, series INTEGER);
        CREATE TABLE publishers (id INTEGER PRIMARY KEY, name TEXT, sort TEXT);
        CREATE TABLE books_publishers_link (id INTEGER PRIMARY KEY, book INTEGER, publisher INTEGER);
        CREATE TABLE languages (id INTEGER PRIMARY KEY, lang_code TEXT);
        CREATE TABLE books_languages_link (id INTEGER PRIMARY KEY, book INTEGER, lang_code INTEGER, item_order INTEGER);
        CREATE TABLE ratings (id INTEGER PRIMARY KEY, rating INTEGER);
        CREATE TABLE books_ratings_link (id INTEGER PRIMARY KEY, book INTEGER, rating INTEGER);
        CREATE TABLE comments (id INTEGER PRIMARY KEY, book INTEGER, text TEXT);
        CREATE TABLE identifiers (id INTEGER PRIMARY KEY, book INTEGER, type TEXT, val TEXT);
        CREATE TABLE data (id INTEGER PRIMARY KEY, book INTEGER, format TEXT, uncompressed_size INTEGER, name TEXT);
        CREATE TABLE annotations (id INTEGER PRIMARY KEY, book INTEGER, format TEXT, user_type TEXT, user TEXT,
          timestamp REAL, annot_id TEXT, annot_type TEXT, annot_data TEXT, searchable_text TEXT);
        INSERT INTO books VALUES (1, 'Fundación', 'Fundación', '2023-04-01 12:34:56.123456+00:00', '1951-06-01 12:00:00+00:00',
          1.0, 'Asimov, Isaac', '', '', 'Isaac Asimov/Fundacion (1)', 0, 'uuid-1', 1, '');
        INSERT INTO books VALUES (2, 'Sin archivo', 'Sin archivo', '2023-04-02 10:00:00+00:00', '0101-01-01 00:00:00+00:00',
          1.0, '', '', '', 'Desconocido/Sin archivo (2)', 0, 'uuid-2', 0, '');
        INSERT INTO authors VALUES (1, 'Isaac Asimov', 'Asimov, Isaac', '');
        INSERT INTO books_authors_link VALUES (1, 1, 1);
        INSERT INTO tags VALUES (1, 'Ciencia ficción');
        INSERT INTO books_tags_link VALUES (1, 1, 1);
        INSERT INTO series VALUES (1, 'Fundación', 'Fundación');
        INSERT INTO books_series_link VALUES (1, 1, 1);
        INSERT INTO publishers VALUES (1, 'Debolsillo', 'Debolsillo');
        INSERT INTO books_publishers_link VALUES (1, 1, 1);
        INSERT INTO languages VALUES (1, 'spa');
        INSERT INTO books_languages_link VALUES (1, 1, 1, 0);
        INSERT INTO ratings VALUES (1, 8);
        INSERT INTO books_ratings_link VALUES (1, 1, 1);
        INSERT INTO comments VALUES (1, 1, '<p>La caída del Imperio.</p>');
        INSERT INTO identifiers VALUES (1, 1, 'isbn', '9788497593793');
        INSERT INTO identifiers VALUES (2, 1, 'amazon', 'B00XYZ');
        INSERT INTO data VALUES (1, 1, 'PDF', 100, 'Fundacion - Isaac Asimov');
        INSERT INTO data VALUES (2, 1, 'EPUB', 100, 'Fundacion - Isaac Asimov');
        INSERT INTO annotations VALUES (1, 1, 'EPUB', 'local', 'viewer', 1700000000, 'a1', 'highlight',
          '{"highlighted_text": "La violencia es el último recurso del incompetente.", "notes": "Salvor Hardin", "spine_index": 3}', '');
        INSERT INTO annotations VALUES (2, 1, 'EPUB', 'local', 'viewer', 1700000001, 'a2', 'highlight',
          '{"highlighted_text": "Borrado", "removed": true}', '');
        INSERT INTO annotations VALUES (3, 1, 'EPUB', 'local', 'viewer', 1700000002, 'a3', 'bookmark', '{"title": "Marcador"}', '');
        """
        XCTAssertEqual(sqlite3_exec(db, sql, nil, nil, nil), SQLITE_OK)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    func testReadsEverythingAGabineteBookNeeds() throws {
        let entries = try CalibreLibrary.read(libraryAt: folder)
        XCTAssertEqual(entries.count, 2)
        let fundacion = try XCTUnwrap(entries.first)
        XCTAssertEqual(fundacion.book.title, "Fundación")
        XCTAssertEqual(fundacion.book.authors, ["Isaac Asimov"])
        XCTAssertEqual(fundacion.book.series, "Fundación")
        XCTAssertEqual(fundacion.book.seriesIndex, 1)
        XCTAssertEqual(fundacion.book.tags, ["Ciencia ficción"])
        XCTAssertEqual(fundacion.book.language, "es")
        XCTAssertEqual(fundacion.book.publisher, "Debolsillo")
        XCTAssertEqual(fundacion.book.published, "1951-06-01")
        XCTAssertEqual(fundacion.book.rating, 4)
        XCTAssertEqual(fundacion.book.calibreID, 1)
        XCTAssertEqual(fundacion.book.identifiers["isbn"], "9788497593793")
        XCTAssertEqual(fundacion.book.identifiers["asin"], "B00XYZ")
        XCTAssertEqual(fundacion.book.identifiers["calibre"], "uuid-1")
        XCTAssertNotNil(fundacion.book.addedAt)
        XCTAssertTrue(fundacion.hasCover)
        // El EPUB se prefiere al PDF.
        XCTAssertEqual(fundacion.preferredFile, "Isaac Asimov/Fundacion (1)/Fundacion - Isaac Asimov.epub")
        // Solo los subrayados vivos.
        XCTAssertEqual(fundacion.annotations.map(\.text), ["La violencia es el último recurso del incompetente."])
        XCTAssertEqual(fundacion.annotations.first?.note, "Salvor Hardin")
        XCTAssertNil(entries[1].book.published)
    }

    func testPlanSkipsWhatIsAlreadyHereAndBooksWithoutFiles() throws {
        let entries = try CalibreLibrary.read(libraryAt: folder)
        XCTAssertEqual(CalibreMigrationPlan(entries: entries, existing: []).toImport.count, 1)
        let plan = CalibreMigrationPlan(entries: entries, existing: [])
        XCTAssertEqual(plan.withoutFiles.map(\.book.title), ["Sin archivo"])
        XCTAssertEqual(plan.covers, 1)
        XCTAssertEqual(plan.series, 1)
        XCTAssertEqual(plan.annotations, 1)
        // Ya migrado antes (mismo uuid de Calibre): no se repite.
        let again = CalibreMigrationPlan(entries: entries, existing: [Book(title: "Otro título", identifiers: ["calibre": "uuid-1"])])
        XCTAssertEqual(again.alreadyHere.count, 1)
        XCTAssertTrue(again.toImport.isEmpty)
    }

    func testNotACalibreFolder() {
        XCTAssertThrowsError(try CalibreLibrary.read(libraryAt: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
    }
}
