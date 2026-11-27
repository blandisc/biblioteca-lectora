import Foundation
import XCTest
@testable import LectoraCore

final class WordLookupTests: XCTestCase {
    func testTermDropsPunctuationAtTheEdges() {
        XCTAssertEqual(WordLookup.term(from: "“astillero,”"), "astillero")
        XCTAssertEqual(WordLookup.term(from: "  Imperio\notomano. "), "Imperio otomano")
        XCTAssertEqual(WordLookup.term(from: "—skill—"), "skill")
        XCTAssertEqual(WordLookup.term(from: "rock-and-roll"), "rock-and-roll")
    }

    func testOnlyShortSelectionsAreEntries() {
        XCTAssertTrue(WordLookup.isEntry("skill"))
        XCTAssertTrue(WordLookup.isEntry("Imperio otomano"))
        XCTAssertFalse(WordLookup.isEntry("There are two different stories I could tell"))
        XCTAssertFalse(WordLookup.isEntry("1984"))
        XCTAssertFalse(WordLookup.isEntry(""))
    }

    func testLanguageCodes() {
        XCTAssertEqual(WordLookup.languageCode("en-US"), "en")
        XCTAssertEqual(WordLookup.languageCode("spa"), "es")
        XCTAssertEqual(WordLookup.languageCode("es_MX"), "es")
        XCTAssertNil(WordLookup.languageCode("und-xx-yyy"))
        XCTAssertNil(WordLookup.languageCode(nil))
        XCTAssertFalse(WordLookup.needsTranslation(bookLanguage: "es"))
        XCTAssertTrue(WordLookup.needsTranslation(bookLanguage: "en"))
        XCTAssertTrue(WordLookup.needsTranslation(bookLanguage: nil))
    }

    func testSummaryURLUsesTheBookLanguage() {
        XCTAssertEqual(WikipediaClient.summaryURL(for: "Imperio otomano", language: "es")?.absoluteString,
                       "https://es.wikipedia.org/api/rest_v1/page/summary/Imperio_otomano")
        XCTAssertEqual(WikipediaClient.summaryURL(for: "AC/DC", language: "en-GB")?.absoluteString,
                       "https://en.wikipedia.org/api/rest_v1/page/summary/AC%2FDC")
        XCTAssertEqual(WikipediaClient.summaryURL(for: "Castañeda", language: nil)?.host, "es.wikipedia.org")
    }

    func testSummaryReadsTheFirstParagraph() async {
        let body = #"{"type":"standard","title":"Habilidad","extract":"La habilidad es la aptitud…","content_urls":{"mobile":{"page":"https://es.m.wikipedia.org/wiki/Habilidad"}}}"#
        let client = WikipediaClient(transport: FakeTransport([(200, body)]))
        let summary = await client.summary(for: "habilidad", language: "es")
        XCTAssertEqual(summary?.title, "Habilidad")
        XCTAssertEqual(summary?.url.absoluteString, "https://es.m.wikipedia.org/wiki/Habilidad")
    }

    func testNoSummaryForDisambiguationMissingOrLongSelections() async {
        let disambiguation = #"{"type":"disambiguation","title":"Mercurio","extract":"Mercurio puede referirse a:","content_urls":{"mobile":{"page":"https://es.m.wikipedia.org/wiki/Mercurio"}}}"#
        let none = await WikipediaClient(transport: FakeTransport([(200, disambiguation)])).summary(for: "Mercurio", language: "es")
        XCTAssertNil(none)
        let missing = await WikipediaClient(transport: FakeTransport([(404, "{}")])).summary(for: "zzzz", language: "es")
        XCTAssertNil(missing)
        let transport = FakeTransport([])
        let long = await WikipediaClient(transport: transport).summary(for: "una frase larga de más de cuatro palabras", language: "es")
        XCTAssertNil(long)
        XCTAssertTrue(transport.requests.isEmpty, "Una frase larga no va a Wikipedia")
    }
}
