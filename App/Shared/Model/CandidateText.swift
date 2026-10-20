import Foundation
import LectoraCore

/// Cómo se le explica un candidato a una persona: en palabras, no en porcentajes.
extension MetadataCandidate {
    /// «Muy probable», «Probable» o «Dudoso».
    var verdict: String {
        if confidence >= MetadataMatcher.autoApplyThreshold { return "Muy probable" }
        if confidence >= 0.65 { return "Probable" }
        return "Dudoso"
    }

    /// Por qué: «Mismo ISBN», «Mismo título y autor», «Otro autor», «Edición en inglés»…
    var reasons: String {
        let notes = Set(notes ?? [])
        var parts: [String] = []
        if notes.contains(.sameISBN) {
            parts.append("Mismo ISBN")
        } else if notes.contains(.sameTitle), notes.contains(.sameAuthor) {
            parts.append("Mismo título y autor")
        } else {
            if notes.contains(.sameTitle) { parts.append("Mismo título") }
            if notes.contains(.similarTitle) { parts.append("Título parecido") }
            if notes.contains(.otherTitle) { parts.append("Otro título") }
            if notes.contains(.sameAuthor) { parts.append("mismo autor") }
            if notes.contains(.otherAuthor) { parts.append("otro autor") }
            if notes.contains(.unknownAuthor) { parts.append("sin autor para comparar") }
        }
        if notes.contains(.conflictingISBN) { parts.append("tu ISBN es de otro libro") }
        if notes.contains(.notTheBook) { parts.append("parece una guía o un resumen") }
        if notes.contains(.otherLanguage), let language { parts.append("edición en \(Self.languageName(language))") }
        let text = parts.joined(separator: ", ")
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    /// «es» → «español».
    static func languageName(_ code: String) -> String {
        Locale(identifier: "es").localizedString(forLanguageCode: code) ?? code
    }
}
