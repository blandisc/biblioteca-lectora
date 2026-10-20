import Foundation
import LectoraCore

// Sondeo: corre la búsqueda de metadatos de la app (la misma de LectoraCore)
// contra Open Library real con el corpus de scripts/sondeo y escribe un
// informe en Markdown. Lo ejecuta la CI (.github/workflows/sondeo.yml).
//
// Uso: lectora-sondeo corpus.json informe.md [carpeta-de-portadas]

struct Case: Decodable {
    struct Expect: Decodable {
        var author: String?
        var title: String?
        var series: String?
        var found: Bool?
        var review: Bool?
    }
    var id: String
    var title: String
    var authors: [String]
    var language: String?
    var isbn: String?
    var expect: Expect
}

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    print("Uso: lectora-sondeo corpus.json informe.md")
    exit(2)
}
let corpus = try JSONDecoder().decode([Case].self, from: Data(contentsOf: URL(fileURLWithPath: arguments[1])))
let service = MetadataService(fetcher: HTTPFetcher())
var rows: [String] = []
var details: [String] = []
var passed = 0

func fold(_ text: String) -> String {
    text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
}

for item in corpus {
    let started = Date()
    let book = MetadataCleaner.clean(Book(title: item.title, authors: item.authors, language: item.language,
                                          identifiers: item.isbn.map { ["isbn": $0] } ?? [:]))
    let result = await service.lookup(book)
    let best = result.candidates.first
    var coverNote = "—"
    if let best, result.decision != .notFound {
        if let data = await service.cover(for: best, language: book.language, title: book.title) {
            coverNote = "\(data.count / 1024) KB"
            // Las portadas elegidas, para verlas (tercer argumento: carpeta).
            if arguments.count >= 4 {
                let folder = URL(fileURLWithPath: arguments[3], isDirectory: true)
                try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try? data.write(to: folder.appendingPathComponent("\(item.id).jpg"))
            }
        } else {
            coverNote = "sin portada"
        }
    }
    let seconds = Date().timeIntervalSince(started)

    // ¿Cumple lo esperado?
    var problems: [String] = []
    let expect = item.expect
    if expect.found == false {
        if result.decision == .apply { problems.append("aplicó un libro que no existe") }
    } else if expect.review == true {
        if result.decision == .apply { problems.append("debía ir a revisar") }
    } else {
        if result.decision != .apply { problems.append("no se aplicó solo (\(result.decision))") }
        if let author = expect.author, let found = best?.authors.first, !fold(found).contains(fold(author).split(separator: " ").last.map(String.init) ?? "") {
            problems.append("autor \(found)")
        }
    }
    if let title = expect.title, let found = best.map({ MetadataMatcher.fillMissing(book, from: $0).title }), fold(found) != fold(title) {
        problems.append("título \(found)")
    }
    if let series = expect.series {
        let filled = best.map { MetadataMatcher.fillMissing(book, from: $0) }
        if filled?.series.map(fold)?.contains(fold(series)) != true { problems.append("serie \(filled?.series ?? "—")") }
    }
    if problems.isEmpty { passed += 1 }

    let decision: String
    switch result.decision {
    case .apply: decision = "aplica"
    case .review: decision = "revisar"
    case .notFound: decision = "no está"
    case .unreachable: decision = "sin red"
    }
    let status: String = problems.isEmpty ? "✅" : "❌ " + problems.joined(separator: "; ")
    let bestName: String = best.map { "\($0.title) — \($0.authors.first ?? "?")" } ?? "—"
    let confidence: String = best.map { String(format: "%.2f", $0.confidence) } ?? "—"
    let genres: String = best?.subjects.joined(separator: ", ") ?? "—"
    var cells: [String] = [status, "`\(item.id)`", decision, bestName, confidence]
    cells.append(best?.published ?? "—")
    cells.append(best?.publisher ?? "—")
    cells.append(best?.language ?? "—")
    cells.append(genres)
    cells.append(coverNote)
    cells.append(String(format: "%.1f s", seconds))
    rows.append("| " + cells.map { $0.replacingOccurrences(of: "|", with: "/") }.joined(separator: " | ") + " |")

    var block = "### \(item.id): \(item.title) — \(item.authors.joined(separator: ", "))\n\n"
    for candidate in result.candidates.prefix(4) {
        block += "- **\(candidate.title)** (\(candidate.workTitle ?? "")) — \(candidate.authors.prefix(2).joined(separator: ", ")) · "
        block += "\(String(format: "%.2f", candidate.confidence)) · \((candidate.notes ?? []).map(\.rawValue).joined(separator: ", ")) · "
        block += "ed. \(candidate.editionCount ?? 0) · \(candidate.series ?? "") \(candidate.seriesIndex.map { String($0) } ?? "")\n"
    }
    if let summary = best?.summary {
        block += "\n> " + String(summary.prefix(280)).replacingOccurrences(of: "\n", with: " ") + "\n"
    }
    details.append(block)
    print(item.id, decision, problems)
    fflush(stdout)
}

let header = """
# Sondeo de metadatos

\(passed) de \(corpus.count) casos como se esperaba. Fuente: Open Library.

| | Caso | Decisión | Mejor candidato | Conf. | Año | Editorial | Idioma | Géneros | Portada | Tiempo |
|---|---|---|---|---|---|---|---|---|---|---|

"""
let report = header + rows.joined(separator: "\n") + "\n\n## Candidatos\n\n" + details.joined(separator: "\n")
try report.write(toFile: arguments[2], atomically: true, encoding: .utf8)
print("\(passed)/\(corpus.count)")
