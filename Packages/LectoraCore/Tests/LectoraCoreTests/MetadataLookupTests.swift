import XCTest
@testable import LectoraCore

/// Búsqueda de metadatos con respuestas reales de Open Library (bajadas con
/// scripts/sondeo y guardadas en Fixtures/).
final class MetadataLookupTests: XCTestCase {
    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    private func ranked(_ name: String, for book: Book) throws -> [MetadataCandidate] {
        MetadataMatcher.rank(OpenLibrary.candidates(from: try fixture(name)), for: book)
    }

    // MARK: Libros reales

    func testTranslationUsesTheSpanishEdition() throws {
        // La obra es «Foundation»; la edición en español, «Fundación».
        let book = Book(title: "Fundación", authors: ["Isaac Asimov"], language: "es")
        let list = try ranked("ol-fundacion", for: book)
        let best = try XCTUnwrap(list.first)
        XCTAssertEqual(best.title, "Fundación")
        XCTAssertEqual(best.workTitle, "Foundation")
        XCTAssertEqual(best.language, "es")
        XCTAssertEqual(best.published, "1951")
        XCTAssertTrue(best.subjects.contains("Ciencia ficción"), "\(best.subjects)")
        // «Foundation Trilogy» no es un nombre de serie para la edición en español.
        XCTAssertNil(best.series)
        XCTAssertTrue(MetadataMatcher.shouldAutoApply(list, for: book))
        // «Segunda fundación» es otro libro: muy por debajo.
        XCTAssertLessThan(list.first { $0.title.hasPrefix("Segunda") }?.confidence ?? 0, 0.8)
    }

    func testDoubleSurnameMatches() throws {
        // El archivo dice «Miguel de Cervantes»; Open Library, «Miguel de Cervantes Saavedra».
        let book = Book(title: "Don Quijote de la Mancha", authors: ["Miguel de Cervantes"], language: "es")
        let list = try ranked("ol-quijote", for: book)
        XCTAssertTrue(MetadataMatcher.shouldAutoApply(list, for: book))
        XCTAssertEqual(list.first?.editionCount, 1595, "La obra de verdad, no un duplicado")
        let filled = MetadataMatcher.fillMissing(book, from: try XCTUnwrap(list.first))
        XCTAssertEqual(filled.authors, ["Miguel de Cervantes"], "Tu forma del nombre se respeta")
    }

    func testDirtyFileStillMatches() throws {
        let book = MetadataCleaner.clean(Book(title: "CIEN AÑOS DE SOLEDAD", authors: ["García Márquez, Gabriel"], language: "es"))
        let list = try ranked("ol-cien-anos", for: book)
        XCTAssertTrue(MetadataMatcher.shouldAutoApply(list, for: book))
        XCTAssertEqual(list.first?.published, "1967")
        XCTAssertTrue(list.first?.subjects.contains("Realismo mágico") ?? false)
    }

    func testSubtitleInTheFile() throws {
        let book = Book(title: "Sapiens: De animales a dioses", authors: ["Yuval Noah Harari"], language: "es")
        let list = try ranked("ol-sapiens", for: book)
        XCTAssertEqual(list.first?.title, "Sapiens")
        XCTAssertTrue(MetadataMatcher.shouldAutoApply(list, for: book))
        // «Resumen de Sapiens» se reconoce como un libro sobre el libro.
        if let summary = list.first(where: { $0.title.contains("Resumen") }) {
            XCTAssertTrue(summary.notes?.contains(.notTheBook) ?? false)
        }
    }

    func testNoAuthorGoesToReview() throws {
        // Solo «Rayuela»: lo más probable es Cortázar, pero sin autor no se aplica solo.
        let book = Book(title: "Rayuela", language: "es")
        let list = try ranked("ol-solo-titulo", for: book)
        XCTAssertEqual(list.first?.authors.first, "Julio Cortázar")
        XCTAssertFalse(MetadataMatcher.shouldAutoApply(list, for: book))
        XCTAssertTrue(list.first?.notes?.contains(.unknownAuthor) ?? false)
    }

    func testCyrillicAuthorIsUnknownNotDifferent() throws {
        // «Лев Толстой» no se puede comparar con «León Tolstói»: no se descarta, se pregunta.
        let book = Book(title: "Anna Karenina", authors: ["León Tolstói"], language: "es")
        let list = try ranked("ol-karenina", for: book)
        let best = try XCTUnwrap(list.first)
        XCTAssertEqual(best.language, "es")
        XCTAssertFalse(best.notes?.contains(.otherAuthor) ?? true)
        XCTAssertGreaterThan(best.confidence, 0.75)
    }

    func testTransliteratedAuthor() throws {
        let book = Book(title: "Crimen y castigo", authors: ["Fiódor Dostoievski"], language: "es")
        let list = try ranked("ol-crimen-castigo", for: book)
        XCTAssertTrue(MetadataMatcher.shouldAutoApply(list, for: book))
    }

    func testSeriesFromTheTitleAndTheSpanishTitle() throws {
        let book = MetadataCleaner.clean(Book(title: "Juego de tronos (Canción de hielo y fuego 1)",
                                              authors: ["George R. R. Martin"], language: "es"))
        XCTAssertEqual(book.title, "Juego de tronos")
        XCTAssertEqual(book.series, "Canción de hielo y fuego")
        XCTAssertEqual(book.seriesIndex, 1)
        let list = try ranked("ol-juego-tronos", for: book)
        XCTAssertEqual(list.first?.title, "Juego de tronos")
        XCTAssertTrue(MetadataMatcher.shouldAutoApply(list, for: book))
        // Tu serie en español no se cambia por «A Song of Ice and Fire».
        XCTAssertEqual(MetadataMatcher.fillMissing(book, from: list[0]).series, "Canción de hielo y fuego")
    }

    func testSameTitleOtherLanguage() throws {
        // «Dune» en español: la edición de Plaza & Janés, no la de Berkley.
        let book = Book(title: "Dune", authors: ["Frank Herbert"], language: "es")
        let list = try ranked("ol-dune-es", for: book)
        XCTAssertEqual(list.first?.language, "es")
        XCTAssertEqual(list.first?.publisher, "Plaza & Janes Editores, S.A.")
        XCTAssertTrue(MetadataMatcher.shouldAutoApply(list, for: book))
        XCTAssertEqual(list.first?.series, "Dune", "Un nombre que se entiende en cualquier idioma")
    }

    func testEnglishSummaryIsNotPutOnASpanishBook() throws {
        let book = Book(title: "El nombre del viento", authors: ["Patrick Rothfuss"], language: "es")
        var candidate = MetadataCandidate(id: "x", source: .openLibrary, title: "El nombre del viento", authors: ["Patrick Rothfuss"])
        candidate.summary = OpenLibrary.workDescription(from: try fixture("ol-obra-nombre-viento"))
        XCTAssertTrue(candidate.summary?.hasPrefix("The Name of the Wind, also called") ?? false, "Sin asteriscos de Markdown")
        XCTAssertNil(MetadataMatcher.fillMissing(book, from: candidate).summary)

        let quijote = try XCTUnwrap(OpenLibrary.workDescription(from: try fixture("ol-obra-quijote")))
        XCTAssertFalse(quijote.contains("*"))
        let spanish = Book(title: "Don Quijote de la Mancha", language: "es")
        var withSummary = candidate
        withSummary.summary = quijote
        XCTAssertNotNil(MetadataMatcher.fillMissing(spanish, from: withSummary).summary)
    }

    func testGenresFromRealSubjects() throws {
        let subjects = { (name: String) throws -> [String] in
            let root = try JSONSerialization.jsonObject(with: try self.fixture(name)) as? [String: Any]
            let docs = root?["docs"] as? [[String: Any]]
            return docs?.first?["subject"] as? [String] ?? []
        }
        XCTAssertEqual(GenreMap.genres(from: try subjects("ol-dune-es")), ["Ciencia ficción"])
        XCTAssertEqual(GenreMap.genres(from: try subjects("ol-pride-en")), ["Romance"])
        let sapiens = GenreMap.genres(from: try subjects("ol-sapiens"))
        XCTAssertTrue(sapiens.contains("Historia"), "\(sapiens)")
        XCTAssertFalse(sapiens.contains("Cómic"), "Las adaptaciones a cómic no cuentan")
        XCTAssertEqual(GenreMap.genres(from: ["Accessible book", "Protected DAISY", "In library"]), [])
    }

    func testTitleCaseIsCleaned() throws {
        let book = Book(title: "Homo Deus: Breve historia del mañana", authors: ["Yuval Noah Harari"], language: "es")
        let list = try ranked("ol-homo-deus", for: book)
        XCTAssertTrue(MetadataMatcher.shouldAutoApply(list, for: book))
        XCTAssertFalse(list.contains { $0.title == $0.title.uppercased() }, "Nada en MAYÚSCULAS")
        XCTAssertEqual(MetadataMatcher.replace(book, with: list[0]).title, "Homo Deus: Breve historia del mañana")
    }

    // MARK: Reglas

    func testISBN() {
        XCTAssertEqual(ISBN.normalized("978-84-376-0457-2"), "9788437604572")
        XCTAssertEqual(ISBN.normalized("8437604575"), "9788437604572")
        XCTAssertNil(ISBN.normalized("9788437604573"), "Dígito de control mal")
        XCTAssertNil(ISBN.normalized("urn:uuid:1234"))
        XCTAssertTrue(ISBN.same("0-8044-2957-X", "9780804429573"))
    }

    func testISBNOfAnotherBookIsNotTrusted() {
        let book = Book(title: "El túnel", authors: ["Ernesto Sabato"], identifiers: ["isbn": "9780000000002"])
        let wrong = MetadataCandidate(id: "x", source: .openLibrary, title: "Kitab Jurumiyyah", knownISBNs: ["9780000000002"])
        let result = MetadataMatcher.match(wrong, for: book)
        XCTAssertFalse(result.sameISBN && result.confidence > 0.5)
        XCTAssertTrue(result.notes.contains(.conflictingISBN))
        XCTAssertFalse(MetadataMatcher.shouldAutoApply([wrong], for: book))
    }

    func testNames() {
        XCTAssertEqual(TextMatch.sameAuthorScore(["Fiódor Dostoievski"], ["Fyodor Dostoyevsky"]), 1)
        XCTAssertEqual(TextMatch.sameAuthorScore(["J.R.R. Tolkien"], ["J. R. R. Tolkien"]), 1)
        XCTAssertEqual(TextMatch.sameAuthorScore(["Liu Cixin"], ["Cixin Liu"]), 1)
        XCTAssertEqual(TextMatch.sameAuthorScore(["Lev Tolstói"], ["León Tolstoi"]), 0.8)
        XCTAssertEqual(TextMatch.sameAuthorScore(["Isaac Asimov"], ["Isaac Newton"]), 0)
        XCTAssertEqual(TextMatch.sameAuthorScore([], ["Isaac Newton"]), 0.5)
    }

    func testSeriesParser() {
        XCTAssertEqual(SeriesParser.split("Dune (Dune Chronicles, #1)"), .init(title: "Dune", series: "Dune Chronicles", index: 1))
        XCTAssertEqual(SeriesParser.split("El nombre del viento [Crónica del asesino de reyes 01]")?.index, 1)
        XCTAssertNil(SeriesParser.split("1984 (Edición conmemorativa 70 aniversario)"))
        XCTAssertNil(SeriesParser.split("Fahrenheit 451"))
    }

    func testSummaryCleaner() {
        let html = "<p>Una novela <b>abierta</b>.</p><p>Se puede leer en dos órdenes &amp; más.</p>"
        XCTAssertEqual(SummaryCleaner.clean(html), "Una novela abierta.\n\nSe puede leer en dos órdenes & más.")
        let markdown = "*Rayuela* es la segunda novela de Cortázar ([source][1]).\r\n\r\n----------\r\nContiene: notas\n[1]: https://es.wikipedia.org"
        XCTAssertEqual(SummaryCleaner.clean(markdown), "Rayuela es la segunda novela de Cortázar .")
        XCTAssertNil(SummaryCleaner.clean("Sin datos."))
    }

    func testReplaceKeepsYourSpellingAndIdentity() {
        let id = UUID()
        let book = Book(id: id, title: "Cien años de soledad", authors: ["Gabriel García Márquez"],
                        filePath: "X/Cien (3)/c.epub", rating: 5, calibreID: 3)
        let candidate = MetadataCandidate(id: "c", source: .openLibrary, title: "Cien Anos De Soledad",
                                          authors: ["Gabriel Garcia Marquez"], publisher: "Diana", published: "1967")
        let replaced = MetadataMatcher.replace(book, with: candidate)
        XCTAssertEqual(replaced.id, id)
        XCTAssertEqual(replaced.title, "Cien años de soledad")
        XCTAssertEqual(replaced.authors, ["Gabriel García Márquez"])
        XCTAssertEqual(replaced.publisher, "Diana")
        XCTAssertEqual(replaced.calibreID, 3)
        XCTAssertEqual(replaced.rating, 5)
        XCTAssertEqual(replaced.filePath, "X/Cien (3)/c.epub")
    }

    func testOldReviewFilesStillLoad() throws {
        // «Por revisar» guardado antes de los campos nuevos.
        let old = #"[{"id":"gb:1","source":"Google Books","title":"Rayuela","authors":["Julio Cortázar"],"subjects":[],"confidence":0.7}]"#
        let decoded = try JSONDecoder().decode([MetadataCandidate].self, from: Data(old.utf8))
        XCTAssertEqual(decoded.first?.title, "Rayuela")
        XCTAssertNil(decoded.first?.workKey)
    }

    func testCoverCheck() {
        func png(width: Int, height: Int, padding: Int = 3_000) -> Data {
            var bytes: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13, 0x49, 0x48, 0x44, 0x52]
            for value in [width, height] { bytes += [UInt8(value >> 24 & 0xFF), UInt8(value >> 16 & 0xFF), UInt8(value >> 8 & 0xFF), UInt8(value & 0xFF)] }
            return Data(bytes + [UInt8](repeating: 0, count: padding))
        }
        XCTAssertEqual(CoverCheck.evaluate(png(width: 317, height: 500)), .good)
        XCTAssertEqual(CoverCheck.evaluate(png(width: 128, height: 201)), .small)
        XCTAssertEqual(CoverCheck.evaluate(png(width: 500, height: 500)), .unusable, "Cuadrada: no es una portada")
        XCTAssertEqual(CoverCheck.evaluate(Data(count: 43)), .unusable, "La imagen vacía de 1×1")
    }

    func testEditionCoversPreferModernEditionsInYourLanguage() {
        let json = Data(#"""
        {"entries":[
          {"covers":[1],"languages":[{"key":"/languages/spa"}],"publish_date":"1951"},
          {"covers":[2],"languages":[{"key":"/languages/eng"}],"isbn_13":["9780000000001"],"publish_date":"2010"},
          {"covers":[3],"languages":[{"key":"/languages/spa"}],"isbn_13":["9788466331845"],"publish_date":"2016"},
          {"covers":[-1],"languages":[{"key":"/languages/spa"}]}
        ]}
        """#.utf8)
        let covers = OpenLibrary.editionCovers(from: json, language: "es", title: "Bestiario")
        XCTAssertEqual(covers.first, OpenLibrary.coverURL(id: 3), "Moderna, en español y con ISBN")
        XCTAssertEqual(covers, [OpenLibrary.coverURL(id: 3), OpenLibrary.coverURL(id: 1)],
                       "Ni la de inglés ni la de número -1")
        let unlabeled = Data(#"{"entries":[{"covers":[7],"title":"Aşk ve Gurur","isbn_13":["9786050000000"]}]}"#.utf8)
        XCTAssertEqual(OpenLibrary.editionCovers(from: unlabeled, language: "es", title: "Orgullo y prejuicio"), [],
                       "Sin idioma y con otro título: no")
    }

    func testGoogleFeedLikeCalibre() throws {
        let xml = Data(#"""
        <?xml version="1.0" encoding="UTF-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom" xmlns:dc="http://purl.org/dc/terms">
          <id>http://www.google.com/books/feeds/volumes</id>
          <entry>
            <id>http://www.google.com/books/feeds/volumes/AbC123</id>
            <title type="text">Cien años de soledad</title>
            <link rel="http://schemas.google.com/books/2008/thumbnail" type="image/x-unknown"
                  href="http://books.google.com/books/content?id=AbC123&amp;printsec=frontcover&amp;img=1&amp;zoom=5&amp;edge=curl&amp;source=gbs_api"/>
            <dc:creator>Gabriel García Márquez</dc:creator>
            <dc:date>2007-03-01</dc:date>
            <dc:description>Una de las obras más importantes de la literatura en lengua española, con la historia de la familia Buendía.</dc:description>
            <dc:identifier>AbC123</dc:identifier>
            <dc:identifier>ISBN:8420471836</dc:identifier>
            <dc:identifier>ISBN:9788420471839</dc:identifier>
            <dc:language>es</dc:language>
            <dc:publisher>Alfaguara</dc:publisher>
            <dc:subject>Fiction / Magical Realism</dc:subject>
            <dc:title>Cien años de soledad</dc:title>
            <dc:title>Edición conmemorativa</dc:title>
          </entry>
        </feed>
        """#.utf8)
        let candidate = try XCTUnwrap(GoogleFeed.candidates(from: xml).first)
        XCTAssertEqual(candidate.identifiers, ["google": "AbC123"])
        XCTAssertEqual(candidate.title, "Cien años de soledad")
        XCTAssertEqual(candidate.subtitle, "Edición conmemorativa")
        XCTAssertEqual(candidate.authors, ["Gabriel García Márquez"])
        XCTAssertEqual(candidate.isbn, "9788420471839")
        XCTAssertEqual(candidate.published, "2007")
        XCTAssertEqual(candidate.language, "es")
        XCTAssertEqual(candidate.publisher, "Alfaguara")
        XCTAssertTrue(candidate.summary?.hasPrefix("Una de las obras") ?? false)
        XCTAssertTrue(candidate.coverURL?.absoluteString.contains("frontcover/AbC123") ?? false)
        XCTAssertTrue(candidate.coverAlternatives?.first?.absoluteString.contains("zoom=1") ?? false)
        XCTAssertTrue(GoogleFeed.searchURL(isbn: nil, title: "Cien años de soledad", author: "Gabriel García Márquez")
            .absoluteString.contains("intitle:cien"))
    }

    func testIdentifiersAreStoredAndRecognized() throws {
        let book = Book(title: "Rayuela", language: "es")
        let list = try ranked("ol-solo-titulo", for: book)
        let filled = MetadataMatcher.fillMissing(book, from: try XCTUnwrap(list.first))
        XCTAssertEqual(filled.identifiers["openlibrary"], "OL14860424W", "Como lo guarda Calibre en el OPF")
        // La próxima vez es el mismo registro: se aplica solo aunque no tenga autor.
        let again = try ranked("ol-solo-titulo", for: filled)
        XCTAssertTrue(again.first?.notes?.contains(.sameRecord) ?? false)
        XCTAssertTrue(MetadataMatcher.shouldAutoApply(again, for: filled))
        XCTAssertTrue(CalibreOPF.write(filled, hasCover: false).contains(#"opf:scheme="OPENLIBRARY">OL14860424W"#))
    }

    func testBestSummaryIsInYourLanguageAndWhole() {
        let book = Book(title: "La casa de los espíritus", language: "es")
        let dutch = "Roman over een Chileense politicus en zijn gezin tot de militaire coup een einde maakt aan de democratie in het land."
        let broken = "En esta edici n cr tica se re ne una serie de investigadores con miras plurales, pero unidos por una l cida adhesi n."
        let short = "Estamos especializados en publicar textos en español."
        let good = "La saga de una poderosa familia de terratenientes latinoamericanos, contada a lo largo de cuatro generaciones con humor y magia."
        XCTAssertTrue(SummaryCleaner.isBroken(broken))
        XCTAssertFalse(SummaryCleaner.isBroken(good))
        XCTAssertEqual(MetadataMatcher.bestSummary([dutch, broken, short, good], for: book), good)
        XCTAssertNil(MetadataMatcher.bestSummary([dutch, broken, short], for: book))
        let catalan = "De l'autor de Sàpiens, la història apassionant del present i del futur de la humanitat, amb els reptes que ens esperen."
        XCTAssertNil(MetadataMatcher.bestSummary([catalan], for: book), "El catalán no pasa por español")
    }

    // MARK: Servicio (con red simulada)

    private struct FakeFetcher: MetadataFetching {
        var responses: [String: FetchResult]
        func get(_ url: URL) async -> FetchResult {
            responses.first { url.absoluteString.contains($0.key) }?.value ?? .notFound
        }
    }

    func testServiceAppliesAndFetchesTheSummary() async throws {
        let fetcher = FakeFetcher(responses: [
            "search.json": .ok(try fixture("ol-quijote")),
            "/works/": .ok(try fixture("ol-obra-quijote")),
        ])
        let book = Book(title: "Don Quijote de la Mancha", authors: ["Miguel de Cervantes"], language: "es")
        let result = await MetadataService(fetcher: fetcher).lookup(book)
        XCTAssertEqual(result.decision, .apply)
        XCTAssertNotNil(result.candidates.first?.summary)
    }

    func testServiceWithoutInternetIsNotNotFound() async {
        let book = Book(title: "Rayuela", authors: ["Julio Cortázar"])
        let offline = await MetadataService(fetcher: FakeFetcher(responses: ["openlibrary": .failed, "google": .failed])).lookup(book)
        XCTAssertEqual(offline.decision, .unreachable)
        let empty = Data(#"{"numFound":0,"docs":[]}"#.utf8)
        let missing = await MetadataService(fetcher: FakeFetcher(responses: ["openlibrary": .ok(empty)])).lookup(book)
        XCTAssertEqual(missing.decision, .notFound)
    }

    func testServiceTriesTitleAloneWhenTheAuthorIsWrong() async throws {
        // Con autor equivocado no hay nada; solo con el título aparece Vargas Llosa: a revisar.
        let empty = Data(#"{"numFound":0,"docs":[]}"#.utf8)
        let byTitle = Data(#"""
        {"docs":[{"key":"/works/OL1W","title":"La ciudad y los perros","author_name":["Mario Vargas Llosa"],
          "edition_count":90,"first_publish_year":1963}]}
        """#.utf8)
        let fetcher = FakeFetcher(responses: ["Garc%C3%ADa": .ok(empty), "q=La%20ciudad%20y%20los%20perros&": .ok(byTitle)])
        let book = Book(title: "La ciudad y los perros", authors: ["Gabriel García Márquez"], language: "es")
        let result = await MetadataService(fetcher: fetcher).lookup(book)
        XCTAssertEqual(result.decision, .review)
        XCTAssertEqual(result.candidates.first?.authors, ["Mario Vargas Llosa"])
        XCTAssertTrue(result.candidates.first?.notes?.contains(.otherAuthor) ?? false)
    }
}
