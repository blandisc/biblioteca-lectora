import Foundation

/// Saca la serie que tiendas y archivos meten en el título:
/// «Juego de tronos (Canción de hielo y fuego 1)», «Dune (Dune, #1)»,
/// «El nombre del viento [Crónica del asesino de reyes 01]».
public enum SeriesParser {
    public struct Result: Equatable {
        public var title: String
        public var series: String
        public var index: Double?
    }

    private static let pattern = try! NSRegularExpression(pattern: #"""
    ^(?<title>.+?)\s*[\(\[]\s*(?<series>[^\(\)\[\]]+?)[\s,]*(?:#|n\.?\s?º\s*|nº\s*|no\.\s*|núm\.\s*|libro\s+|book\s+|vol\.?\s*|volumen\s+|volume\s+|tomo\s+|parte\s+|part\s+)?(?<index>\d{1,3}(?:[.,]\d)?)\s*[\)\]]\s*$
    """#, options: [.caseInsensitive])

    public static func split(_ title: String) -> Result? {
        let range = NSRange(title.startIndex..., in: title)
        guard let match = pattern.firstMatch(in: title, range: range),
              let titleRange = Range(match.range(withName: "title"), in: title),
              let seriesRange = Range(match.range(withName: "series"), in: title),
              let indexRange = Range(match.range(withName: "index"), in: title) else { return nil }
        let main = title[titleRange].trimmingCharacters(in: .whitespaces)
        let series = String(title[seriesRange]).trimmingCharacters(in: CharacterSet(charactersIn: " ,-–:"))
        // «(Edición conmemorativa 50 aniversario)» no es una serie.
        let notSeries = #"(?i)edici[oó]n|edition|aniversario|anniversary|ilustrad|illustrated|spanish|english|español|inglés"#
        guard series.range(of: notSeries, options: .regularExpression) == nil else { return nil }
        guard !main.isEmpty, series.count >= 2,
              series.rangeOfCharacter(from: .letters) != nil,
              let index = Double(title[indexRange].replacingOccurrences(of: ",", with: ".")) else { return nil }
        return Result(title: main, series: series, index: index)
    }
}
