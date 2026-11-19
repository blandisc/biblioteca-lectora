import Foundation
import XCTest

/// Reglas del sistema de diseño (docs/sistema-diseno.md), comprobadas sobre el
/// código de la app como texto, línea por línea (idea tomada de Orbital).
///
/// - Las pantallas usan tokens de `Theme` y piezas de `Components.swift`; nada a mano.
/// - Las piezas del sistema no conocen la app (reciben datos y avisan con acciones).
/// - Una acción principal y un ícono verde por pantalla; pantallas con scroll por la receta.
/// - Toda pieza está en el catálogo del documento, todo token se usa y toda
///   excepción (`// ds-exception: <motivo>`) está en la tabla «Excepciones».
final class DesignRulesTests: XCTestCase {
    struct Source {
        let path: String
        let lines: [String]
        var text: String { lines.joined(separator: "\n") }
    }

    /// Raíz del repositorio (este archivo vive en Packages/LectoraCore/Tests/LectoraCoreTests/).
    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    static func sources(_ folder: String) -> [Source] {
        let base = root.appendingPathComponent(folder)
        guard let walker = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) else { return [] }
        return walker.compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
            .sorted { $0.path < $1.path }
            .compactMap { url in
                guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
                let relative = String(url.path.dropFirst(root.path.count + 1))
                return Source(path: relative, lines: text.components(separatedBy: "\n"))
            }
    }

    /// Pantallas: todo lo que arma interfaz fuera del sistema de diseño.
    static var screens: [Source] {
        sources("App/Shared/Screens") + sources("App/Shared").filter {
            ["App/Shared/RootView.swift", "App/Shared/Reader/ReaderView.swift"].contains($0.path)
        }
    }

    static let doc = (try? String(contentsOf: root.appendingPathComponent("docs/sistema-diseno.md"), encoding: .utf8)) ?? ""

    /// Líneas que cumplen `pattern`, salvo comentarios y excepciones marcadas.
    func hits(_ pattern: String, in files: [Source]) -> [String] {
        let regex = try! NSRegularExpression(pattern: pattern)
        var out: [String] = []
        for file in files {
            for (index, line) in file.lines.enumerated() {
                let code = line.trimmingCharacters(in: .whitespaces)
                if code.hasPrefix("//") || line.contains("ds-exception:") { continue }
                let range = NSRange(line.startIndex..., in: line)
                if regex.firstMatch(in: line, range: range) != nil {
                    out.append("\(file.path):\(index + 1): \(code.prefix(140))")
                }
            }
        }
        return out
    }

    func check(_ problems: [String], _ rule: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(problems.isEmpty, "\(rule)\n" + problems.joined(separator: "\n"), file: file, line: line)
    }

    func testSourcesAreFound() {
        XCTAssertFalse(Self.screens.isEmpty, "No encontré las pantallas en \(Self.root.path)")
        XCTAssertFalse(Self.doc.isEmpty, "No encontré docs/sistema-diseno.md")
    }

    // MARK: Tokens

    func testScreensUseOnlyTokens() {
        let rules: [(String, String)] = [
            (#"(\.padding\(|spacing: |\.frame\(|cornerRadius: |lineWidth: |\.opacity\(|\.offset\()([^)]*[^A-Za-z_.0-9])?[1-9][0-9]*(\.[0-9]+)?"#,
             "Número suelto: usa un token de Theme"),
            (#"Color\(hex|Color\(red:|Color\.(white|black)\b"#, "Color a mano: usa un color de Theme"),
            (#"\.system\(size|Font\.custom"#, "Fuente a mano: usa una de Font (screenTitle, rowTitle…)"),
            (#"withAnimation\s*\{|withAnimation\((?!Theme\.Motion)"#, "Animación sin token: usa Theme.Motion"),
            (#"\.easeInOut\(duration|\.spring\(|\.snappy\("#, "Curva a mano: usa Theme.Motion"),
        ]
        for (pattern, rule) in rules {
            check(hits(pattern, in: Self.screens), rule)
        }
    }

    // MARK: Piezas del catálogo

    func testScreensUseCatalogPieces() {
        let rules: [(String, String)] = [
            (#"\.pickerStyle\(\.segmented\)"#, "Opciones en texto: usa FilterBar"),
            (#"ContentUnavailableView\("#, "Vacío: usa EmptyState"),
            (#"\.buttonStyle\(\.(borderedProminent|bordered)\)"#, "Botón: usa PrimaryButton o SecondaryButton"),
            (#"DateFormatter\(\)"#, "Fechas: usa .formatted(…) o NoteRow.day"),
            (#"\b(RoundedRectangle\(|Capsule\(\)|Circle\(\)|Ellipse\(\))"#, "Forma a mano: es una pieza de Components.swift"),
            (#"struct \w+: (ButtonStyle|LabelStyle)"#, "Estilo nuevo: va en Components.swift"),
        ]
        for (pattern, rule) in rules {
            check(hits(pattern, in: Self.screens), rule)
        }
    }

    /// Las piezas reciben datos y avisan con acciones; lo que necesita el estado de la app es una pantalla.
    func testDesignPiecesDontKnowTheApp() {
        let design = Self.sources("App/Shared/Design")
        check(hits(#"\b(AppModel|LibraryStore|NotesStore|SessionStore|AnnotationStore)\b|@EnvironmentObject"#, in: design),
              "Una pieza del sistema no conoce la app: recibe datos por parámetros")
    }

    // MARK: Recetas

    /// Una sola acción principal (PrimaryButton) y un solo ícono verde (AccentIconButton) por pantalla.
    func testOneMainActionPerScreen() {
        var problems: [String] = []
        for file in Self.screens {
            // Cada `struct` es una pantalla o una parte; se cuenta por bloque.
            var blocks: [String] = [""]
            for line in file.lines {
                if line.hasPrefix("struct ") || line.hasPrefix("private struct ") { blocks.append("") }
                blocks[blocks.count - 1] += line + "\n"
            }
            for block in blocks {
                let name = block.split(separator: "\n").first ?? ""
                let primary = block.components(separatedBy: "PrimaryButton(").count - 1
                let accent = block.components(separatedBy: "AccentIconButton(").count - 1
                if primary > 1 { problems.append("\(file.path) · \(name): \(primary) PrimaryButton") }
                if accent > 1 { problems.append("\(file.path) · \(name): \(accent) AccentIconButton") }
            }
        }
        check(problems, "Una acción principal y un ícono verde por pantalla")
    }

    /// Toda pantalla con scroll arma su contenido con `.screenContent()` (margen y aire del sistema).
    func testScrollingScreensUseTheRecipe() {
        let problems = Self.screens
            .filter { $0.text.contains("ScrollView {") && !$0.text.contains(".screenContent()") }
            .map(\.path)
        check(problems, "Pantalla con scroll sin la receta .screenContent()")
    }

    // MARK: Catálogo y documento

    /// Toda pieza pública de Components.swift está en el catálogo de docs/sistema-diseno.md.
    func testEveryPieceIsInTheCatalog() {
        let components = Self.sources("App/Shared/Design").filter { $0.path.hasSuffix("Components.swift") }
        let regex = try! NSRegularExpression(pattern: #"^struct (\w+)"#)
        var problems: [String] = []
        for file in components {
            for line in file.lines {
                let range = NSRange(line.startIndex..., in: line)
                guard let match = regex.firstMatch(in: line, range: range),
                      let nameRange = Range(match.range(at: 1), in: line) else { continue }
                let name = String(line[nameRange])
                if !Self.doc.contains("`\(name)`") { problems.append(name) }
            }
        }
        check(problems, "Pieza sin fila en el catálogo de docs/sistema-diseno.md")
    }

    /// Todo token de Theme se usa en algún lugar (si no, sobra).
    func testEveryTokenIsUsed() {
        let theme = Self.sources("App/Shared/Design").first { $0.path.hasSuffix("Theme.swift") }
        let all = Self.sources("App").map(\.text).joined(separator: "\n")
        let regex = try! NSRegularExpression(pattern: #"static (?:let|func) (\w+)"#)
        var problems: [String] = []
        for line in theme?.lines ?? [] {
            let range = NSRange(line.startIndex..., in: line)
            guard let match = regex.firstMatch(in: line, range: range),
                  let nameRange = Range(match.range(at: 1), in: line) else { continue }
            let name = String(line[nameRange])
            if all.components(separatedBy: ".\(name)").count < 2 { problems.append(name) }
        }
        check(problems, "Token sin uso: quítalo o úsalo")
    }

    /// Toda excepción marcada en el código tiene su motivo en la tabla «Excepciones».
    func testExceptionsAreDocumented() {
        let section = Self.doc.components(separatedBy: "## Excepciones").dropFirst().first ?? ""
        var problems: [String] = []
        for file in Self.sources("App") {
            for (index, line) in file.lines.enumerated() {
                guard let marker = line.range(of: "ds-exception:") else { continue }
                let reason = line[marker.upperBound...].trimmingCharacters(in: .whitespaces)
                if reason.isEmpty || !section.contains(reason) {
                    problems.append("\(file.path):\(index + 1): «\(reason)»")
                }
            }
        }
        check(problems, "Excepción sin motivo en la tabla «Excepciones» de docs/sistema-diseno.md")
    }

    // MARK: Decisiones de diseño

    /// 30 oct 2026: el lápiz rojo se fue; el verde hoja (accent) marca lo tuyo.
    func testNoRedPencilLeft() {
        check(hits(#"B8372A|E0675A|Theme\.pencil"#, in: Self.sources("App")), "El rojo lápiz ya no existe: usa Theme.accent")
    }

    /// 18 nov 2026: la app está en español aunque el dispositivo no: fechas y
    /// porcentajes con `Locale.gabinete` (`fecha.es(…)`, `valor.percentText`).
    func testDatesAndNumbersInSpanish() {
        check(hits(#"\.formatted\(\.dateTime|format: \.dateTime(?!.*locale)|format: \.percent"#, in: Self.sources("App")),
              "Fecha o porcentaje sin español: usa fecha.es(…) o valor.percentText")
    }

    /// 18 nov 2026: el avance que manda el lector (fraction, progress) puede ser NaN
    /// (foliate, secciones de dos páginas) y cerraba la app. Siempre por `readingFraction`.
    func testReaderFractionsAreChecked() {
        check(hits(#"\["(fraction|progress)"\] as\? Double(?!\)?\??\.readingFraction)"#, in: Self.sources("App")),
              "Avance del lector sin revisar: usa (body[\"fraction\"] as? Double)?.readingFraction")
    }

    /// 18 nov 2026: la cinta se iba al esconder los controles o cambiar la letra
    /// porque se comparaba el principio exacto de la página. Si un marcador está en
    /// la página lo dice reader.js (`bookmarksOnPage`), que compara contra toda la página.
    func testBookmarksComparedAgainstTheWholePage() {
        check(hits(#"\.marks\(cfi:|abs\(.*fraction.*\) < "#, in: Self.sources("App")),
              "Marcador comparado con el principio exacto o el avance: usa controller.bookmarksOnPage")
        let reader = (try? String(contentsOf: Self.root.appendingPathComponent("App/Resources/Reader/reader.js"), encoding: .utf8)) ?? ""
        XCTAssertTrue(reader.contains("collapse(pageCFI, true)"), "reader.js debe comparar el marcador con el final de la página")
    }

    /// 30 oct 2026: Cinzel solo para la marca y los rótulos (BrandMark, SectionLabel).
    func testRomanCapsOnlyForMarkAndLabels() {
        check(hits(#"\.brandMark|\.sectionLabel"#, in: Self.screens), "Cinzel solo a través de BrandMark y SectionLabel")
    }
}
