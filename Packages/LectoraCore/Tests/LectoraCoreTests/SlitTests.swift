import XCTest
@testable import LectoraCore

final class SlitTests: XCTestCase {
    private let text = "Así pues, ¿cuáles eran las verdaderas razones para mirar hacia Chipre? La idea más extendida, entonces, atribuía la decisión a Nasi."

    func testWordByWordKeepsEveryWordAndWhereItStarts() {
        let chunks = Slit.chunks(text, unit: .word)
        XCTAssertEqual(chunks.count, text.split(whereSeparator: \.isWhitespace).count)
        for chunk in chunks {
            let start = text.utf16.index(text.utf16.startIndex, offsetBy: chunk.offset)
            XCTAssertTrue(String(text[start...]).hasPrefix(chunk.text))
        }
    }

    func testPhrasesBreatheAtCommasAndSentenceEnds() {
        let chunks = Slit.chunks(text, unit: .phrase)
        XCTAssertEqual(chunks.first?.text, "Así pues,")
        XCTAssertTrue(chunks.contains { $0.text.hasSuffix("Chipre?") && $0.endsSentence })
        XCTAssertTrue(chunks.allSatisfy { $0.words <= 5 })
        // Nada se pierde: juntas, las frases son el texto.
        XCTAssertEqual(chunks.map(\.text).joined(separator: " "),
                       text.split(whereSeparator: \.isWhitespace).joined(separator: " "))
    }

    func testPhrasesCutBeforeAWordThatOpensAnotherIdea() {
        let chunks = Slit.chunks("las verdaderas razones para mirar hacia Chipre", unit: .phrase)
        XCTAssertEqual(chunks.first?.text, "las verdaderas razones")
    }

    func testEverySentenceEndsWithARest() {
        let plain = Slit.Chunk(text: "la idea", offset: 0, words: 2, endsSentence: false, endsClause: false)
        var end = plain
        end.endsSentence = true
        XCTAssertGreaterThan(Slit.duration(of: end, wordsPerMinute: 260), Slit.duration(of: plain, wordsPerMinute: 260))
    }

    func testPaceIsHeldWithinWhatResearchSupports() {
        XCTAssertLessThanOrEqual(Slit.wordsPerMinuteRange.upperBound, 400)
        XCTAssertTrue(Slit.wordsPerMinuteRange.contains(Slit.defaultWordsPerMinute))
        // A 260 ppm, diez palabras sin pausas tardan lo que dicen: ~2,3 s.
        let ten = Slit.Chunk(text: "", offset: 0, words: 10, endsSentence: false, endsClause: false)
        XCTAssertEqual(Slit.duration(of: ten, wordsPerMinute: 260), 600.0 / 260, accuracy: 0.01)
    }

    func testFocusLetterSitsJustBeforeTheMiddle() {
        XCTAssertEqual(Slit.focusIndex(of: "a"), 0)
        XCTAssertEqual(Slit.focusIndex(of: "idea"), 1)
        XCTAssertEqual(Slit.focusIndex(of: "«extendida,"), 3)
    }

    func testFindsTheChunkForAPosition() {
        let chunks = Slit.chunks(text, unit: .phrase)
        XCTAssertEqual(Slit.index(atOffset: 0, in: chunks), 0)
        XCTAssertEqual(Slit.index(atOffset: chunks[2].offset + 1, in: chunks), 2)
    }

    /// UX-8b: el título del capítulo iba pegado a la primera frase («Capítulo IEn un lugar…»).
    /// Un salto de renglón separa dos bloques: ningún pedazo los junta y el título respira.
    func testChapterTitleNeverRunsIntoTheFirstSentence() {
        let text = "Capítulo primero\nEn un lugar de la Mancha, de cuyo nombre\nno quiero acordarme."
        let phrases = Slit.chunks(text, unit: .phrase)
        XCTAssertEqual(phrases.first?.text, "Capítulo primero")
        XCTAssertEqual(phrases.first?.endsSentence, true, "el título termina con un respiro")
        XCTAssertTrue(phrases[1].text.hasPrefix("En un lugar"))
        XCTAssertFalse(phrases.contains { $0.text.contains("primero En") || $0.text.contains("nombre no") })
        let words = Slit.chunks(text, unit: .word)
        XCTAssertEqual(words[1].text, "primero")
        XCTAssertTrue(words[1].endsSentence)
        XCTAssertEqual(words[2].offset, ("Capítulo primero\n" as NSString).length)
    }
}

