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

    /// Una tabla de `scripts/`: renglones «valor⇥porqué», sin comentarios (#). La leen
    /// también `scripts/lint-design.sh`, así la prueba y el lint miran lo mismo.
    static func table(_ name: String) -> [(String, String)] {
        let text = (try? String(contentsOf: root.appendingPathComponent("scripts/\(name)"), encoding: .utf8)) ?? ""
        return text.components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty && !$0.hasPrefix("#") }
            .map { line in
                let parts = line.components(separatedBy: "\t")
                return (parts[0], parts.dropFirst().joined(separator: "\t"))
            }
    }

    /// Lo que no miran las guardias, cada cosa con su porqué (`scripts/design-sources.txt`).
    static let excluded = table("design-sources.txt")

    /// Todo lo que arma la app (26 nov 2026, SD-1): todo `App/Shared` menos lo excluido con
    /// su porqué. Antes cada prueba tenía su propia lista corta y la Mac, la hendidura, la
    /// consulta y el pase de hoja quedaban fuera; un archivo nuevo queda vigilado solo.
    static var ui: [Source] {
        sources("App/Shared").filter { file in !excluded.contains { file.path.hasPrefix($0.0) } }
    }

    /// Pantallas: lo que arma una vista entera con piezas del catálogo (iPhone y Mac).
    static var screens: [Source] {
        let whole = ["App/Shared/RootView.swift", "App/Shared/Reader/ReaderView.swift",
                     "App/Shared/Reader/LookupCard.swift", "App/Shared/Reader/SlitScreen.swift"]
        return ui.filter { $0.path.hasPrefix("App/Shared/Screens/") || $0.path.hasPrefix("App/Shared/Mac/") || whole.contains($0.path) }
    }

    /// Piezas del sistema y del lector: tampoco usan valores sueltos (22 nov 2026: la
    /// regla solo miraba las pantallas y dentro de las piezas quedaban 20 números sin nombre).
    static var pieces: [Source] {
        let names = Set(screens.map(\.path))
        return ui.filter { !names.contains($0.path) }
    }

    static let doc = (try? String(contentsOf: root.appendingPathComponent("docs/sistema-diseno.md"), encoding: .utf8)) ?? ""

    /// Líneas que cumplen `pattern`, salvo comentarios y excepciones marcadas.
    func hits(_ pattern: String, in files: [Source]) -> [String] {
        let regex = try! NSRegularExpression(pattern: pattern)
        var out: [String] = []
        for file in files {
            var debug = 0
            for (index, line) in file.lines.enumerated() {
                let code = line.trimmingCharacters(in: .whitespaces)
                // Lo de `#if DEBUG` (capturas y demos) no llega a quien usa la app.
                if code.hasPrefix("#if") { if debug > 0 || code == "#if DEBUG" { debug += 1 }; continue }
                if code.hasPrefix("#endif"), debug > 0 { debug -= 1; continue }
                if debug > 0 || code.hasPrefix("//") || line.contains("ds-exception:") { continue }
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
        XCTAssertFalse(Self.table("design-patterns.txt").isEmpty, "No encontré scripts/design-patterns.txt")
        // Cada exclusión existe y dice por qué; el lint mira la misma lista y los mismos patrones.
        var problems = Self.excluded.filter { path, reason in
            reason.isEmpty || !FileManager.default.fileExists(atPath: Self.root.appendingPathComponent(path).path)
        }.map { "\($0.0): sin porqué o ya no existe" }
        let lint = (try? String(contentsOf: Self.root.appendingPathComponent("scripts/lint-design.sh"), encoding: .utf8)) ?? ""
        for name in ["design-sources.txt", "design-patterns.txt"] where !lint.contains(name) {
            problems.append("scripts/lint-design.sh no lee \(name)")
        }
        check(problems, "Las guardias miran todo App/Shared salvo lo excluido con su porqué")
    }

    // MARK: Tokens

    /// Números, colores, fuentes, animaciones y esperas: los patrones de
    /// `scripts/design-patterns.txt`, sobre todo lo que arma la app (iPhone y Mac).
    func testScreensUseOnlyTokens() {
        for (rule, pattern) in Self.table("design-patterns.txt") {
            check(hits(pattern, in: Self.ui), rule)
        }
    }

    /// 19 nov 2026: había 35 medidas armadas a mano sumando tokens («s + xxs», «xl + xs»)
    /// que daban valores fuera de la escala y distintos para lo mismo. Si hace falta
    /// otra medida, se nombra en `Theme` (como `rowY` o `inline`); nunca se suma.
    func testNoArithmeticBetweenTokens() {
        let files = Self.sources("App").filter { !$0.path.hasSuffix("Design/Theme.swift") }
        check(hits(#"Theme\.(Space|Size|Radius|Reader)\.\w+\s*[-+/*]\s*(Theme\.|\d|CGFloat\()"#, in: files),
              "Medida sumada a mano: nómbrala en Theme y úsala")
    }

    /// 19 nov 2026: en la Biblioteca el «+» verde iba al final y en el Cuaderno antes
    /// de otro ícono. El acento de un encabezado va siempre al final (a la derecha).
    func testAccentActionGoesLast() {
        var problems: [String] = []
        for file in Self.screens {
            for (index, line) in file.lines.enumerated() where line.contains("AccentIconButton(") {
                let next = file.lines.dropFirst(index + 1)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .first { !$0.isEmpty && !$0.hasPrefix("//") } ?? "}"
                if !next.hasPrefix("}") { problems.append("\(file.path):\(index + 1)") }
            }
        }
        check(problems, "El AccentIconButton va al final del encabezado")
    }

    /// 19 nov 2026: «Pronto, también…» en Buscar y «IA en la nube · Próximamente» en
    /// Ajustes. Nada en la app promete lo que todavía no hace (ver `Features`).
    ///
    /// UX-8a (27 nov 2026): el mini reproductor, «Guiada» y «Escuchar» salían en las capturas
    /// (`-screenshot.listening`) y no hacían nada. Lo que llega después vive tras `Features`,
    /// apagado en el código para todos (no lo prende una opción de arranque), y ningún botón
    /// visible tiene la acción vacía.
    func testNoPromisesOfFutureFeatures() {
        check(hits(#"(?i)"[^"]*\b(pronto|próximamente|coming soon)\b[^"]*""#, in: Self.sources("App")),
              "Texto que promete algo que no hace: escóndelo hasta que funcione")
        let options = Self.ui.first { $0.path.hasSuffix("LaunchOptions.swift") }?.text ?? ""
        let flags = options.components(separatedBy: "enum Features").dropFirst().first ?? ""
        var problems = flags.components(separatedBy: "\n")
            .filter { $0.contains("static ") && !$0.contains("= false") }
            .map { "LaunchOptions.swift: \($0.trimmingCharacters(in: .whitespaces)) — lo que no funciona va apagado en el código" }
        if flags.isEmpty { problems.append("LaunchOptions.swift: falta `enum Features`") }
        // Un botón con la acción vacía solo dentro de un `if Features.…`, o en una pieza que solo se
        // enseña desde ahí (el mini reproductor).
        let planned = ["MiniPlayer(", "ReaderPillButton(", "\"headphones\""]
        for file in Self.ui where !file.path.hasSuffix("Design/Components.swift") {
            var depth = 0, gatedAt: [Int] = []
            for (index, line) in file.lines.enumerated() {
                let code = line.trimmingCharacters(in: .whitespaces)
                if code.hasPrefix("//") { continue }
                let opens = line.filter { $0 == "{" }.count, closes = line.filter { $0 == "}" }.count
                if code.hasPrefix("if "), code.contains("Features."), opens > closes { gatedAt.append(depth) }
                let gated = !gatedAt.isEmpty
                let empty = line.range(of: #"(Button|ReaderPillButton|RoundIconButton|IconButton|TextAction)\b[^{]*\{\s*\}"#, options: .regularExpression) != nil
                    && !line.contains("role: .cancel")
                let isPlanned = planned.contains { line.contains($0) } && !code.hasPrefix("struct ")
                let inPlannedPiece = file.path.hasSuffix("MiniPlayer.swift")
                if !gated, (empty && !inPlannedPiece) || isPlanned {
                    problems.append("\(file.path):\(index + 1): \(code.prefix(120))")
                }
                depth += opens - closes
                while let last = gatedAt.last, depth <= last { gatedAt.removeLast() }
            }
        }
        check(problems, "Se ve algo que no funciona: escóndelo tras `Features` (apagado) hasta que funcione")
    }

    /// 19 nov 2026: los formularios (Ajustes, Conexiones…) salían en el gris frío del
    /// sistema, no en el papel de la app. Todo `Form` lleva `.formScreen()`.
    /// 22 nov 2026: cada pantalla empujada u hoja armaba a mano su fondo y su título, y las
    /// acciones de la barra salían unas en verde y otras en tinta (en iOS 26 van en tinta). Todas usan su receta:
    /// `.screen()` (pestaña), `.pushedScreen()` (empujada u hoja) o `.formScreen()` (formulario).
    func testPushedScreensUseTheRecipe() {
        check(hits(#"\.navigationBarTitleDisplayMode\(|\.background\(Theme\.paper\.ignoresSafeArea|\.toolbar\(\.hidden, for: \.navigationBar\)|Button\("[^"]+"\)[^\n]*\.foregroundStyle\(Theme\.accent\)"#,
                   in: Self.screens),
              "Fondo, título o color de la barra a mano: usa .screen(), .pushedScreen() o .formScreen()")
    }

    func testFormsUseThePaper() {
        let problems = Self.screens.filter { file in
            file.lines.filter { $0.trimmingCharacters(in: .whitespaces) == "Form {" }.count
                > file.lines.filter { $0.contains(".formScreen()") }.count
        }.map(\.path)
        check(problems, "Form sin .formScreen(): usa la receta de formulario")
        // 27 nov 2026: en la Mac, Reglas y las conexiones salían en columnas, más anchas que Ajustes.
        // La receta los agrupa a todos, como la ficha; ninguna pantalla elige su estilo.
        let components = Self.sources("App/Shared/Design").first { $0.path.hasSuffix("Components.swift") }?.text ?? ""
        let recipe = components.components(separatedBy: "func formScreen()").dropFirst().first?.components(separatedBy: "\n    }").first ?? ""
        if !recipe.contains(".formStyle(.grouped)") { XCTFail("formScreen no agrupa el formulario") }
        check(hits(#"\.formStyle\("#, in: Self.screens), "Estilo de formulario a mano: lo pone .formScreen()")
    }

    /// 19 nov 2026: el gris secundario (4,35 : 1) y el terciario (2,75 : 1) no se
    /// leían bien sobre el papel. Texto contra `paper`, en claro y en oscuro: tinta y
    /// secundario ≥ 4,5; terciario y verde ≥ 3 (WCAG).
    func testTextColorsAreReadable() {
        let theme = Self.sources("App/Shared/Design").first { $0.path.hasSuffix("Theme.swift") }?.text ?? ""
        func pair(_ name: String) -> (UInt32, UInt32)? {
            if name == "accent" {
                // El verde vive en `Theme.Green` (un solo lugar desde el 26 nov 2026).
                let green = try! NSRegularExpression(pattern: #"static let (light|dark): UInt32 = 0x([0-9A-F]{6})"#)
                var found: [String: UInt32] = [:]
                for match in green.matches(in: theme, range: NSRange(theme.startIndex..., in: theme)) {
                    if let key = Range(match.range(at: 1), in: theme), let hex = Range(match.range(at: 2), in: theme) {
                        found[String(theme[key])] = UInt32(theme[hex], radix: 16)
                    }
                }
                guard let light = found["light"], let dark = found["dark"] else { return nil }
                return (light, dark)
            }
            let regex = try! NSRegularExpression(pattern: "static let \(name) = Color\\(light: 0x([0-9A-F]{6}), dark: 0x([0-9A-F]{6})\\)")
            guard let match = regex.firstMatch(in: theme, range: NSRange(theme.startIndex..., in: theme)),
                  let light = Range(match.range(at: 1), in: theme), let dark = Range(match.range(at: 2), in: theme)
            else { return nil }
            return (UInt32(theme[light], radix: 16)!, UInt32(theme[dark], radix: 16)!)
        }
        func luminance(_ hex: UInt32) -> Double {
            func linear(_ value: UInt32) -> Double {
                let channel = Double(value & 0xFF) / 255
                return channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
            }
            let red: Double = linear(hex >> 16), green: Double = linear(hex >> 8), blue: Double = linear(hex)
            return 0.2126 * red + 0.7152 * green + 0.0722 * blue
        }
        func contrast(_ a: UInt32, _ b: UInt32) -> Double {
            let (x, y) = (luminance(a), luminance(b))
            return (max(x, y) + 0.05) / (min(x, y) + 0.05)
        }
        guard let paper = pair("paper") else { return XCTFail("No encontré Theme.paper") }
        var problems: [String] = []
        for (name, minimum) in [("ink", 4.5), ("secondaryInk", 4.5), ("tertiaryInk", 3.0), ("accent", 3.0)] {
            guard let color = pair(name) else { problems.append("\(name): no lo encontré"); continue }
            for (mode, text, background) in [("claro", color.0, paper.0), ("oscuro", color.1, paper.1)]
            where contrast(text, background) < minimum {
                problems.append("\(name) en \(mode): \(String(format: "%.2f", contrast(text, background))) < \(minimum)")
            }
        }
        check(problems, "Texto que no se lee bien sobre el papel")
    }

    // MARK: Piezas del catálogo

    func testScreensUseCatalogPieces() {
        let rules: [(String, String)] = [
            (#"\.pickerStyle\(\.segmented\)"#, "Opciones en texto: usa FilterBar"),
            (#"ContentUnavailableView\("#, "Vacío: usa EmptyState (en la Mac, MacEmptyState)"),
            (#"\.buttonStyle\(\.(borderedProminent|bordered)\)"#, "Botón: usa PrimaryButton o SecondaryButton (en la Mac, .macMainAction())"),
            (#"DateFormatter\(\)"#, "Fechas: usa .formatted(…) o NoteRow.day"),
            (#"\b(RoundedRectangle\(|Capsule\(\)|Circle\(\)|Ellipse\(\))"#, "Forma a mano: es una pieza de Components.swift"),
            (#"struct \w+: (ButtonStyle|LabelStyle)"#, "Estilo nuevo: va en Components.swift"),
        ]
        for (pattern, rule) in rules {
            check(hits(pattern, in: Self.screens), rule)
        }
        // 19 nov 2026: en Buscar, el campo de `.searchable` quedaba escondido y no había dónde escribir.
        // En la Mac, la búsqueda vive en la barra de la ventana, como en toda app de Mac.
        check(hits(#"\.searchable\("#, in: Self.screens.filter { !$0.path.hasPrefix("App/Shared/Mac/") }),
              "Búsqueda: usa SearchField bajo el título")
        // 27 nov 2026: un filtro sin libros decía que no había ninguno y ahí quedaba. El vacío de un
        // filtro trae su salida a todos los libros, en el iPhone y en la Mac.
        var exits: [String] = []
        for file in Self.screens {
            for (index, line) in file.lines.enumerated() where line.contains("EmptyCopy.noMatch(") {
                let call = file.lines[index..<min(index + 3, file.lines.count)].joined()
                if !call.contains("EmptyCopy.showAll") { exits.append("\(file.path):\(index + 1)") }
            }
        }
        check(exits, "Un filtro vacío ofrece volver a todos (EmptyCopy.showAll)")
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

    /// 22 nov 2026: «Empezar sin libros» y «Ahora no» eran el botón oscuro de la
    /// bienvenida y pesaban más que añadir libros o conectar Readwise. Saltar o no
    /// hacer nada nunca es la acción principal: va en `QuietButton`.
    func testSkippingIsNeverTheMainAction() {
        check(hits(#"PrimaryButton\(title:[^\n]*"(Ahora no|Saltar|Omitir|Cancelar|Más tarde|Después|Empezar sin[^"]*)""#,
                   in: Self.screens),
              "Saltar o no hacer nada como PrimaryButton: usa QuietButton")
    }

    /// Toda pantalla con scroll arma su contenido con `.screenContent()` (margen y aire del sistema).
    func testScrollingScreensUseTheRecipe() {
        let problems = Self.screens
            .filter { $0.text.contains("ScrollView {") && !$0.text.contains(".screenContent(") }
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
        // 19 nov 2026: la Mesa decía «2 % leído» y el lector «3%» del mismo libro.
        // Todo porcentaje en pantalla sale de percentText / percentNumber.
        let screensAndPieces = Self.sources("App").filter { !$0.path.hasSuffix("Library/Connectors.swift") }
        check(hits(#"\* *100\b(?!.*percentNumber)"#, in: screensAndPieces).filter { !$0.contains("var percentNumber") },
              "Porcentaje armado a mano: usa valor.percentText")
        // UX-4a (26 nov 2026): el Diario decía «Noviembre De 2026». En español el mes va en minúscula.
        check(hits(#"\.capitalized"#, in: Self.sources("App")),
              "Mayúsculas a cada palabra (.capitalized): «noviembre de 2026» va en minúscula")
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

    /// 24 nov 2026: al deslizar, la hoja se volvía transparente mientras se iba y en el
    /// fundido los dos textos se mezclaban: a media vuelta se leían dos páginas encimadas.
    /// Al pasar de página nunca se leen dos textos a la vez: deslizar mueve papel opaco
    /// (solo se aclara la sombra de abajo) y el fundido es un relevo (`TurnMotion`).
    func testPagesNeverShowTwoTextsAtOnce() {
        let curl = Self.sources("App/Shared/Reader").first { $0.path.hasSuffix("PageCurl.swift") }?.text ?? ""
        let components = Self.sources("App/Shared/Design").first { $0.path.hasSuffix("Components.swift") }?.text ?? ""
        func branch(_ text: String, _ start: String, _ end: String) -> String {
            guard let from = text.range(of: start), let to = text.range(of: end, range: from.upperBound..<text.endIndex) else { return "" }
            return String(text[from.upperBound..<to.lowerBound])
        }
        let slide = branch(curl, "case .slide:\n            // La hoja de arriba", "case .matte:")
        XCTAssertFalse(slide.isEmpty, "No encontré cómo se desliza la hoja en PageCurl.swift")
        XCTAssertFalse(slide.contains("cover?.alpha") || slide.contains("incoming?.alpha"),
                       "Deslizar: la hoja que se mueve es opaca; aclara la sombra de abajo (turn.dim), no la hoja")
        let fade = branch(curl, "case .fade:\n            // Relevo", "case .slide:")
        XCTAssertTrue(fade.contains("TurnMotion.fadeOut") && fade.contains("TurnMotion.fadeIn"),
                      "Fundido: relevo con TurnMotion.fadeOut y fadeIn, no los dos textos a la vez")
        // Páginas ↔ continuo: el libro cambia de lugar; también es relevo, no fundido encimado.
        let dissolve = branch(curl, "func dissolve(", "// MARK: La vuelta")
        XCTAssertTrue(dissolve.contains("Theme.Reader.flowOut") && dissolve.contains("Theme.Reader.flowIn"),
                      "Páginas ↔ continuo: la página de antes se va (flowOut) y luego llega la nueva (flowIn)")
        let preview = branch(components, "case .slide:\n            // Opaca", "case .none:")
        XCTAssertTrue(preview.contains("TurnMotion.fadeOut") && !preview.contains("opacity(Theme.Emphasis.rest - p)\n"),
                      "La muestra de «Aa» se mueve igual que la hoja de verdad (TurnMotion)")
    }

    /// 24 nov 2026 (auditoría, T1): la Hoja se quedaba quieta ~120 ms a media vuelta y
    /// brincaba al final. Se fotografiaba otra vez toda la vista (lento) tirando la foto
    /// que WebKit ya había dado, y el resorte recuperaba el tiempo perdido de un salto.
    func testPageTurnNeverFreezesOrJumps() {
        let curl = Self.sources("App/Shared/Reader").first { $0.path.hasSuffix("PageCurl.swift") }?.text ?? ""
        XCTAssertFalse(curl.contains("takeSnapshot(with: nil) { _, _ in\n                DispatchQueue.main.async { self.prepare"),
                       "La vuelta se arma con la foto que entrega WebKit, no tirándola y fotografiando otra vez")
        XCTAssertTrue(curl.contains("Theme.Reader.turnFrameCap"),
                      "Un cuadro tarde no hace brincar la hoja: el resorte avanza a lo más turnFrameCap")
    }

    /// 24 nov 2026: al subir el capítulo en continuo, el desvanecido quedó encima de él
    /// y el primer renglón se leía detrás del título. El papel es sólido hasta la orilla
    /// del folio y se desvanece ya fuera: la franja se alarga justo lo que mide el desvanecido.
    func testTextNeverShowsBehindTheFolio() {
        let reader = Self.sources("App/Shared/Reader").first { $0.path.hasSuffix("ReaderView.swift") }?.text ?? ""
        XCTAssertTrue(reader.contains(".padding(edge == .top ? .bottom : .top, -Theme.Reader.folioFade)")
                      && reader.contains("height: CGFloat? = Theme.Reader.folioFade"),
                      "Continuo: la franja de papel del folio sobresale lo mismo que su desvanecido (folioFade)")
    }

    /// 25 nov 2026: en «Agentes del imperio» unos renglones quedaban más separados que otros:
    /// las clases del libro (`p.normal { line-height: 1.3 !important }`) le ganaban a nuestro
    /// aire, y una letra de otra fuente (ć) o una llamada de nota agrandaban su renglón.
    /// Todos los renglones de un párrafo van a la misma distancia, traiga el libro lo que traiga.
    func testLinesAreEvenlySpaced() {
        let reader = (try? String(contentsOf: Self.root.appendingPathComponent("App/Resources/Reader/reader.js"), encoding: .utf8)) ?? ""
        XCTAssertTrue(reader.contains(":root :is(p, li, blockquote, dd):not(#lectora-even)"),
                      "reader.js: el aire entre renglones debe ganarle a las clases del libro")
        XCTAssertTrue(reader.contains("evenLines(doc)") && reader.contains("setProperty('line-height', '0', 'important')"),
                      "reader.js: lo que va dentro del renglón (letras de otra fuente, notas) no debe agrandarlo")
    }

    /// 24 nov 2026: con «Vibrar al pasar de página» apagado, el iPhone seguía vibrando en cada
    /// hoja: la barra de avance vibraba cada vez que cambiaba el porcentaje. Leyendo, nada
    /// vibra porque la página se movió; solo lo que haces tú (arrastrar la barra, elegir algo).
    func testReadingNeverVibratesByItself() {
        check(hits(#"sensoryFeedback\(.*trigger: .*(fraction|location|percent|page)(?!.*\{ _, _ in)"#,
                   in: Self.sources("App/Shared/Reader")),
              "Una vibración que sigue al avance del libro necesita su condición ({ _, _ in … }): si no, vibra con cada página")
    }

    /// 24 nov 2026 (sistema base de la casa, SB-3): ninguna letra de menos de 12 pt.
    /// `.caption2` mide 11: solo para íconos.
    func testNoTextUnderTwelve() {
        var problems: [String] = []
        for file in Self.sources("App") {
            for (index, line) in file.lines.enumerated()
            where (line.contains(".caption2") || line.contains(".font(.badge)")) && !line.contains("ds-exception:") && !line.contains("static let badge") {
                let around = file.lines[max(0, index - 1)...index].joined()
                if !around.contains("Image(") && !around.contains(".icon") {
                    problems.append("\(file.path):\(index + 1): \(line.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
        // 26 nov 2026 (SD-1): en el libro, el separador de página medía 0,72rem (≈ 11,5 px). Lo que
        // reader.js escribe en rem o px mide al menos 12 px (1rem = 16 px); en em, al menos 0,75 de la letra del libro.
        let size = try! NSRegularExpression(pattern: #"font(?:-size)?:\s*(?:[0-9]{3}\s+)?([0-9.]+)(rem|px|em)\b"#)
        for (index, line) in Self.readerScript.components(separatedBy: "\n").enumerated() {
            for match in size.matches(in: line, range: NSRange(line.startIndex..., in: line)) {
                guard let number = Range(match.range(at: 1), in: line), let unit = Range(match.range(at: 2), in: line),
                      let amount = Double(line[number]) else { continue }
                let pixels = line[unit] == "px" ? amount : amount * 16
                if pixels < 12 { problems.append("reader.js:\(index + 1): \(line.trimmingCharacters(in: .whitespaces))") }
            }
        }
        check(problems, "Letra de 11 pt (.caption2, Font.badge) en un texto: el mínimo es 12 (.caption); es solo para íconos")
    }

    /// 30 oct 2026: Cinzel solo para la marca y los rótulos (BrandMark, SectionLabel).
    func testRomanCapsOnlyForMarkAndLabels() {
        check(hits(#"\.brandMark|\.sectionLabel"#, in: Self.screens), "Cinzel solo a través de BrandMark y SectionLabel")
    }

    // MARK: Libreta del futuro (26 nov 2026, SD-1 a SD-8)

    /// El cuerpo de una pieza de Components.swift, de su `struct` a la siguiente.
    static func piece(_ name: String) -> String {
        let text = sources("App/Shared/Design").first { $0.path.hasSuffix("Components.swift") }?.text ?? ""
        guard let start = text.range(of: "struct \(name)") else { return "" }
        let rest = text[start.upperBound...]
        let end = rest.range(of: "\nstruct ")?.lowerBound ?? rest.endIndex
        return String(rest[..<end])
    }

    /// Regla 1, un solo verde y poco: el verde marca dónde estás, lo que avanzas y lo tuyo,
    /// y solo lo pintan las piezas. Una pantalla que lo usa directo lo está gastando en
    /// una acción («Todo bien», «Crear», «Listo» salían en verde): las acciones van en tinta.
    func testOnlyPiecesPaintTheAccent() {
        check(hits(#"Theme\.accent"#, in: Self.screens),
              "Verde en una pantalla: las acciones van en tinta (TextAction) y lo tuyo sale de una pieza")
        // Auditoría de medios (27 nov 2026): las recetas teñían de verde todo botón de su contenido
        // («Elegir de Fotos», «Elegir archivo»). Las acciones van en tinta; los interruptores
        // prendidos, en verde, por su pieza (`AccentSwitchStyle`).
        let components = Self.sources("App/Shared/Design").first { $0.path.hasSuffix("Components.swift") }!.text
        var recipes: [String] = []
        for name in ["func screen()", "func formScreen", "func pushedScreen"] {
            let body = components.components(separatedBy: name).dropFirst().first?.components(separatedBy: "\n    }").first ?? ""
            if body.contains("tint(Theme.accent)") || !body.contains("tint(Theme.ink)") || !body.contains("AccentSwitchStyle()") {
                recipes.append("\(name): sus botones salen en verde (usa .tint(Theme.ink) y .toggleStyle(AccentSwitchStyle()))")
            }
        }
        // Los botones de texto de una barra salían en verde: van con BarButton, en tinta.
        let barButtons = Self.screens.filter { $0.path.hasPrefix("App/Shared/Screens/") }.flatMap { file in
            file.lines.enumerated().compactMap { index, line -> String? in
                guard line.contains("ToolbarItem(") else { return nil }
                let near = file.lines[index..<min(index + 3, file.lines.count)].joined()
                return near.range(of: #"(?<![A-Za-z])Button\("#, options: .regularExpression) != nil
                    ? "\(file.path):\(index + 1): botón de la barra sin BarButton" : nil
            }
        }
        // Auditoría 4 (27 nov 2026): en la Mac el menú de filtros de la barra salía verde sin ningún
        // filtro puesto. Todo menú de la barra de la ventana va en tinta (`macToolbarInk`), en verde
        // solo con un filtro puesto.
        let macMenus = Self.screens.filter { $0.path.hasPrefix("App/Shared/Mac/") }.flatMap { file -> [String] in
            var inToolbar = false
            return file.lines.enumerated().compactMap { index, line -> String? in
                if line.contains(".toolbar {") { inToolbar = true }
                guard inToolbar, line.trimmingCharacters(in: .whitespaces).hasPrefix("Menu {") else { return nil }
                let near = file.lines[index..<min(index + 12, file.lines.count)].joined()
                return near.contains(".macToolbarInk(") ? nil : "\(file.path):\(index + 1): menú de la barra sin macToolbarInk"
            }
        }
        if !components.contains("func macToolbarInk(active: Bool = false)") || !components.contains("tint(active ? Theme.accent : Theme.ink)") {
            recipes.append("macToolbarInk: el control de la barra no va en tinta")
        }
        check(recipes + barButtons + macMenus + hits(#"Menu\("Editar"\)"#, in: Self.screens).map { "\($0) — usa BarMenu(title:)" },
              "Una receta (o un menú de la barra) pinta de verde las acciones de su pantalla")
    }

    /// Regla 3, rótulos en versalitas: toda versalita sale de `CapsText` (o de una pieza
    /// del catálogo), con su tamaño, su espaciado y cifras exactas. Nada de armarlas a mano.
    func testCapsComeFromThePieces() {
        check(hits(#"Tracking\.caps|textCase\(\.uppercase\)"#, in: Self.screens),
              "Versalitas armadas a mano: usa CapsText, SectionHeader o CountLine")
        // UX-1c (26 nov 2026): el rótulo en árabe salía con sus letras separadas. Todo espaciado
        // sale de `.spaced(_:_:)`, que no separa las escrituras que unen sus letras.
        check(hits(#"\.tracking\(|\.kerning\("#, in: Self.ui).filter { !$0.contains("tracking(text.isSpaceable") },
              "Letras espaciadas a mano: usa .spaced(cantidad, texto), que respeta el árabe y el hebreo")
    }

    /// Regla 3 (SD-2, 26 nov 2026): toda sección se anuncia con `SectionHeader`, con su línea
    /// y su acción al final. Las romanas de `SectionLabel` quedan para el «Nº» de la ficha y
    /// el capítulo del lector; antes 35 secciones las usaban sin línea, distintas a las demás.
    func testSectionsUseTheirHeader() {
        let roman = hits(#"SectionLabel\("#, in: Self.ui).filter { !$0.contains("Nº") && !$0.contains("eyebrow") }
        check(roman, "Rótulo de sección con SectionLabel: usa SectionHeader (las romanas, solo «Nº» y capítulo)")
        let handMade = Self.screens.flatMap { file in
            zip(file.lines, file.lines.dropFirst()).compactMap { line, next in
                line.contains("HStack") && (next.contains("CapsText(") || next.contains("SectionHeader(")) ? "\(file.path): \(next)" : nil
            }
        }
        check(handMade, "Rótulo con su acción armado en un HStack: usa SectionHeader(title:) { acción }")
        // Auditoría de medios (27 nov 2026): los formularios del iPhone (Editar datos, Reglas,
        // Conexiones) anunciaban sus secciones con el gris del sistema. También van en versalitas.
        let phone = Self.screens.filter { $0.path.hasPrefix("App/Shared/Screens/") }
        let systemHeaders = hits(#"Section\(("|\w+\.\w+\.rawValue)"#, in: phone) + phone.flatMap { file in
            zip(file.lines, file.lines.dropFirst()).compactMap { line, next in
                line.contains("header: {") && next.trimmingCharacters(in: .whitespaces).hasPrefix("Text(") ? "\(file.path): \(next)" : nil
            }
        }
        check(systemHeaders, "Sección de formulario con el rótulo del sistema: usa header: { CapsText(text:) }")
    }

    /// Regla 9 (SD-4, 26 nov 2026): con la letra más grande de iOS (AX5) nada se sale de la
    /// pantalla ni se parte a media palabra, y todo lo que se toca responde en 44 × 44 (SB-4).
    /// Antes la Mesa decía «GABI / NETE», Ajustes se corría a la izquierda («ARIENCIA»), «Aa» se
    /// volvía «…», y el engrane, lista o portadas, la ✕ de buscar y el índice A–Z respondían en 13 a 24 pt.
    func testFitsLargeTextAndFingers() {
        let components = Self.sources("App/Shared/Design").first { $0.path.hasSuffix("Components.swift") }!
        // Cada pieza de Components.swift con su nombre (de un `struct` al siguiente).
        var pieces: [(name: String, body: String, start: Int)] = []
        for (index, line) in components.lines.enumerated() {
            if let range = line.range(of: #"^(private )?struct \w+"#, options: .regularExpression) {
                let name = line[range].split(separator: " ").last.map(String.init) ?? ""
                pieces.append((name, "", index))
            }
            if !pieces.isEmpty { pieces[pieces.count - 1].body += line + "\n" }
        }
        func owner(_ line: Int) -> String { pieces.last { $0.start <= line }?.name ?? "" }

        // 1. Nada se fija a su ancho: `.fixedSize()` empuja la pantalla de lado con la letra grande.
        //    Solo los dibujos de Ajustes (las piezas `…Art`), cuya letra tiene tope (`SettingsArt`).
        var problems = hits(#"\.fixedSize\(\)"#, in: Self.ui).filter { hit in
            guard hit.hasPrefix(components.path), let number = Int(hit.split(separator: ":")[1]) else { return true }
            return !owner(number - 1).hasSuffix("Art")
        }
        if !(pieces.first { $0.name == "SettingsArt" }?.body.contains("dynamicTypeSize(...") ?? false) {
            problems.append("SettingsArt: su letra no tiene tope y el dibujo es de medida fija")
        }
        check(problems, "Ancho fijo con .fixedSize(): con la letra más grande se sale de la pantalla (usa .layoutPriority(1) o AdaptiveStack)")
        // La acción de un rótulo de sección no se parte en renglones: baja entera si no cabe.
        let header = pieces.first { $0.name == "SectionHeader" }?.body ?? ""
        check(header.contains("ViewThatFits") && header.contains("trailing.fixedSize(horizontal: true") ? [] : ["SectionHeader"],
              "La acción de SectionHeader se parte en renglones: debe bajar entera a su propio renglón cuando no cabe")

        // 2. Los títulos de pantalla crecen con la letra de iOS, y toda letra propia también.
        let theme = Self.sources("App/Shared/Design").first { $0.path.hasSuffix("Theme.swift") }!
        var titles = theme.lines.filter { $0.contains("Font.custom(") && !$0.contains("relativeTo:") }
        if !(pieces.first { $0.name == "ScreenTitleFont" }?.body.contains("@ScaledMetric") ?? false) { titles.append("ScreenTitleFont sin @ScaledMetric") }
        if !theme.text.contains("UIFontMetrics(forTextStyle: .largeTitle).scaledFont") { titles.append("UIFont.screenTitle no crece") }
        titles += hits(#"\.font\(\.screenTitle\("#, in: Self.ui).filter { !$0.contains("screenTitle(size)") }
        check(titles, "Letra que no crece con el tamaño de texto de iOS (relativeTo:, @ScaledMetric o .screenTitleFont())")

        // 3. Lo que va lado a lado se apila con la letra grande, y los nombres no se cortan en un renglón.
        let adaptive = ["ScreenHeading", "DeskHeader", "CountLine", "FieldRow", "LinkRow", "SegmentedChoice", "PageSwatchPicker", "StatTrio"]
            .filter { name in !(pieces.first { $0.name == name }?.body.contains("AdaptiveStack") ?? false) }
            .map { "\($0) no usa AdaptiveStack" }
        let grows = ["IconTile", "BookRow", "NoteRow", "CoverGrid", "CapsText"]
            .filter { name in !(pieces.first { $0.name == name }?.body.contains("isAccessibilitySize") ?? false) }
            .map { "\($0) no cambia con la letra grande" }
        let reader = Self.ui.first { $0.path.hasSuffix("Reader/ReaderView.swift") }?.text ?? ""
        let card = ["struct BottomPanel", "struct HighlightCard", "struct SelectionBar"].filter { name in
            guard let start = reader.range(of: name) else { return true }
            let rest = reader[start.upperBound...]
            return !rest[..<(rest.range(of: "\nstruct ")?.lowerBound ?? rest.range(of: "\nprivate struct ")?.lowerBound ?? rest.endIndex)].contains("AdaptiveStack")
        }.map { "ReaderView \($0) no usa AdaptiveStack" }
        check(adaptive + grows + card, "Fila que no se acomoda con la letra más grande")

        // 4. Todo lo que se toca responde en 44: las acciones de un encabezado son IconButton o
        //    AccentIconButton (o la ✕ de una hoja, `CloseButton`, UX-6b), y toda pieza con un botón
        //    usa una medida de 44 (o es grande de por sí).
        var touch: [String] = []
        for file in Self.screens {
            var depth = 0
            for (index, line) in file.lines.enumerated() {
                if depth == 0, line.contains("ScreenHeading(title:"), line.hasSuffix("{") { depth = 1; continue }
                guard depth > 0 else { continue }
                if line.contains("Button"), !line.contains("IconButton("), !line.contains("CloseButton(") { touch.append("\(file.path):\(index + 1): \(line.trimmingCharacters(in: .whitespaces))") }
                depth += line.filter { $0 == "{" }.count - line.filter { $0 == "}" }.count
            }
        }
        // Los de la barra del sistema (`BarButton`, `BarMenu`) los mide iOS: su cápsula ya es de 44.
        let bigByNature: Set = ["PageSwatchPicker", "CoverChoiceCell", "SaveShelfAlert", "RenameShelfAlert", "DeleteShelfConfirmation",
                                "BarButton", "BarMenu"]
        let measure = #"tapTarget|sizeTarget|accentButton|scrubberReach|Size\.control|Size\.row|IconTile|PrimaryButton|TextAction|QuietButton|CloseButton|roundInGlass"#
        for piece in pieces where !bigByNature.contains(piece.name) {
            let touches = piece.body.range(of: #"Button\s*[({]|\.onTapGesture|\.gesture\(|Menu \{"#, options: .regularExpression) != nil
            if touches && piece.body.range(of: measure, options: .regularExpression) == nil { touch.append("\(piece.name): se toca sin medir 44") }
        }
        let index = pieces.first { $0.name == "LetterIndex" }?.body ?? ""
        if !index.contains("tapTarget") { touch.append("LetterIndex: cada letra se toca en menos de 44") }
        if index.contains("Theme.accent") { touch.append("LetterIndex en verde: es una acción, va en tinta (regla 1)") }
        check(touch, "Algo se toca en menos de 44 × 44 (SB-4)")

        // 4b. Auditoría 1 (27 nov 2026): el índice A–Z pisaba «TÍTULO ⇅» y la orilla de las filas, y con
        //     AX5 corría de la barra de estado a la de pestañas tapando los nombres. Lo que flota sobre
        //     una lista le deja su lugar: el índice tiene tope de letra y cabe en su alto (enseña menos
        //     letras), y toda pantalla que lo pone lo esconde con la letra más grande, le deja libre su
        //     columna (`Space.letterIndex`) y lo empieza debajo de su conteo.
        var overlay: [String] = []
        if !index.contains("dynamicTypeSize(...") { overlay.append("LetterIndex: su letra crece sin tope") }
        if !index.contains("ViewThatFits(in: .vertical)") { overlay.append("LetterIndex: si no caben las 27 letras se sale de su alto") }
        if !index.contains("isAccessibilitySize") { overlay.append("LetterIndex: no dice que con la letra más grande no se enseña") }
        // Auditoría 3: VoiceOver leía la instrucción como si fuera la letra elegida. El cómo va en la pista.
        if !index.contains(".accessibilityHint(") || index.contains(#"accessibilityValue(spoken ?? "Desliza"#) {
            overlay.append("LetterIndex: la instrucción va en accessibilityValue, no en accessibilityHint")
        }
        for file in Self.screens where file.text.contains("LetterIndex {") {
            if !file.text.contains("LetterIndex.shows(at:") { overlay.append("\(file.path): enseña el índice A–Z con la letra más grande") }
            if !file.text.contains("Theme.Space.letterIndex") { overlay.append("\(file.path): la lista no le deja libre su columna al índice A–Z") }
            if file.text.range(of: #"LetterIndex \{[\s\S]*?\.padding\(\.top, \w+Top\)"#, options: .regularExpression) == nil {
                overlay.append("\(file.path): el índice A–Z no empieza debajo del conteo y el orden")
            }
        }
        check(overlay, "Algo flota sobre la lista y tapa lo que hay debajo")

        // 5. En la Mac (MX-B, 26 nov 2026) lo largo de la tabla se corta con «…» en un renglón: toda
        //    celda es `MacCell`, que lo hace; antes eran `Text` sueltos que podían partirse.
        var mac = hits(#"TableColumn\(.*\{ \(row: MacBookRow\) in Text\("#, in: Self.ui.filter { $0.path.hasPrefix("App/Shared/Mac/") })
        let cell = pieces.first { $0.name == "MacCell" }?.body ?? ""
        if !cell.contains(".lineLimit(1)") || !cell.contains(".truncationMode(.tail)") { mac.append("MacCell: no corta con «…» en un renglón") }
        check(mac, "Celda de la tabla de la Mac sin cortar con «…»: usa MacCell")

        // 6. UX-3b (26 nov 2026): en la ficha de la Mac un título largo se salía del campo. Todo
        //    campo de la Mac corta con «…» (`.oneLine()`).
        let fields = Self.ui.filter { $0.path.hasPrefix("App/Shared/Mac/") }.flatMap { file in
            file.lines.indices.compactMap { index -> String? in
                guard file.lines[index].contains("TextField(") else { return nil }
                let statement = file.lines[index...min(index + 1, file.lines.count - 1)].joined()
                return statement.contains(".oneLine()") || statement.contains("axis: .vertical") ? nil : "\(file.path):\(index + 1)"
            }
        }
        check(fields, "Campo de la Mac que no corta con «…»: agrégale .oneLine()")
        // Auditoría 3: en la ficha de la Mac las pistas («2016 o 2016-05-01») salían del mismo gris que
        // los datos. Lo escrito va en tinta (`oneLine`) y la pista, más callada (`.fieldPrompt`).
        var prompts = hits(#"TextField\([^\n]*prompt: Text\("#, in: Self.ui.filter { $0.path.hasPrefix("App/Shared/Mac/") })
        if !Self.sources("App/Shared/Design").contains(where: { $0.text.contains("lineLimit(1).truncationMode(.tail).foregroundStyle(Theme.ink)") }) {
            prompts.append("oneLine: lo escrito no va en tinta")
        }
        check(prompts, "Pista de un campo de la Mac del mismo color que un dato: usa .fieldPrompt")
        // Auditoría 3: con la ficha abierta, «Formato» quedaba cortada sin «…» y la tabla corría de lado.
        // Con la ficha abierta la tabla lleva solo sus columnas de más peso, y el autor y la serie no
        // bajan de `Mac.nameColumn` (el título cede antes).
        let macTable = Self.screens.first { $0.path.hasSuffix("Mac/MacBookTable.swift") }?.text ?? ""
        var columns: [String] = []
        if !macTable.contains("if tableLayout.inspector {") { columns.append("MacBookTable: con la ficha abierta enseña todas las columnas") }
        if macTable.components(separatedBy: "min: Theme.Mac.nameColumn").count - 1 < 2 { columns.append("MacBookTable: autor y serie se encogen más que el título") }
        check(columns, "Tabla de la Mac que no cabe junto a la ficha")

        // 7. UX-2e: una portada cuadrada o apaisada se estiraba al llenar el marco 2∶3. Solo
        //    `FittedCover` y la portada que ya es 2∶3 (`CoverView`) llenan; lo demás cabe entero.
        let fill = hits(#"scaledToFill\(\)|aspectRatio\(contentMode: \.fill\)"#, in: Self.ui)
            .filter { !$0.hasPrefix("App/Shared/Design/CoverView.swift") && !(owner(Int($0.split(separator: ":")[1]).map { $0 - 1 } ?? 0) == "FittedCover" && $0.hasPrefix(components.path)) }
        check(fill, "Imagen que llena su marco y se recorta o estira: usa FittedCover")

        // 8. UX-4c: «LIBROS TERMI…». La leyenda de StatTrio baja a un segundo renglón; los filtros
        //    (UX-2b, «Si…») bajan enteros al renglón de abajo en vez de cortarse en la orilla.
        var wrap: [String] = []
        if !Self.piece("StatTrio").contains("labelLines") { wrap.append("StatTrio: su leyenda se corta en un renglón") }
        if Self.piece("FilterBar").contains("ScrollView(.horizontal") || !Self.piece("FilterBar").contains("WrapRows") { wrap.append("FilterBar: las opciones se cortan en la orilla") }
        // Auditoría 1: «Posibles duplicad». Lo que es más ancho que un renglón entero recibe ese
        // ancho y parte su texto; con la medida ideal se cortaba aunque bajara de renglón.
        if !Self.piece("WrapRows").contains("sizeThatFits(ProposedViewSize(width: width") { wrap.append("WrapRows: una opción más ancha que el renglón se corta") }
        if Self.piece("FilterBar").contains(".lineLimit(") { wrap.append("FilterBar: una opción no puede usar dos renglones") }
        // Auditoría 3: «1 SERIE · / 3 LIBROS» y «Ir a la / letra…» con un «Abc» enorme. Cada cifra va
        // pegada a su palabra y cada par baja entero, sin el «·» colgando; el salto a una letra es corto.
        if !Self.piece("CountLine").contains("u{00A0}") || !Self.piece("CountLine").contains("ViewThatFits") {
            wrap.append("CountLine: una cifra se separa de su palabra o el «·» queda colgando")
        }
        let jump = Self.piece("LetterJumpMenu")
        if jump.contains("textformat") || jump.contains("Ir a la letra…\"") { wrap.append("LetterJumpMenu: su rótulo no cabe en un renglón con la letra más grande") }
        // El punto de «Por revisar» crece con la letra y va al centro de su primer renglón.
        let link = Self.piece("LinkRow")
        if !link.contains("@ScaledMetric") || link.contains(#"Text(verbatim: " ")"#) { wrap.append("LinkRow: su punto no crece con la letra o cae en la línea de base") }
        check(wrap, "Texto que se corta en vez de bajar de renglón")

        // 10. UX-3a: «Editar datos» no se veía: con dos botones de texto en la barra, iOS esconde el
        //     título de en medio. Esas hojas usan `.sheetTitle` (o `.pushedScreen(…, sheet: true)`).
        let hidden = Self.screens.flatMap { file in
            file.lines.indices.compactMap { index -> String? in
                let line = file.lines[index]
                guard line.range(of: #"\.inlineTitle\("[^"]+"\)|\.pushedScreen\("[^"]+"\)"#, options: .regularExpression) != nil else { return nil }
                let next = file.lines[index..<min(index + 10, file.lines.count)].joined()
                return next.contains("cancellationAction") && next.contains("confirmationAction") ? "\(file.path):\(index + 1)" : nil
            }
        }
        check(hidden, "Hoja con dos botones de texto y el título en medio, donde iOS lo esconde: usa .sheetTitle")

        // 10b. Auditoría 3 (27 nov 2026): con AX5, «Guardar cambios» y «Ir a la biblioteca» se iban al
        //      «•••» de iOS y la hoja quedaba sin cómo guardar ni saltar. Las dos salidas de texto de una
        //      hoja van con `.sheetActions`, que con la letra grande baja la segunda, entera, al pie.
        var folded: [String] = []
        for file in Self.screens {
            for (index, line) in file.lines.enumerated() where line.contains("ToolbarItem(placement: .cancellationAction)") {
                let next = file.lines[index..<min(index + 8, file.lines.count)].joined()
                if next.contains("BarButton(") && (next.contains(".confirmationAction") || next.contains(".primaryAction")) {
                    folded.append("\(file.path):\(index + 1)")
                }
            }
        }
        let actions = Self.piece("SheetActions")
        if !actions.contains("isAccessibilitySize") || !actions.contains("BottomBar") {
            folded.append("SheetActions: con la letra más grande no baja la segunda salida al pie")
        }
        check(folded, "Hoja con dos botones de texto en la barra: usa .sheetActions, que con AX5 no los esconde en «•••»")

        // 11. Auditoría 2 (27 nov 2026): «Sesión terminada» era media hoja que no se desplazaba; con
        //     AX5 o en un iPhone SE sus dos botones quedaban fuera, sin cómo llegar. Toda hoja que
        //     se abre a media pantalla se desplaza y puede crecer a todo lo alto; sus botones lado
        //     a lado se apilan con la letra grande.
        var sheets: [String] = []
        for file in Self.screens + Self.pieces {
            for (index, line) in file.lines.enumerated() where line.contains(".presentationDetents(") && line.contains(".medium") {
                if !line.contains(".large") { sheets.append("\(file.path):\(index + 1): media hoja sin .large") }
                if !file.text.contains("ScrollView") { sheets.append("\(file.path):\(index + 1): media hoja que no se desplaza") }
            }
        }
        let summary = Self.screens.first { $0.path.hasSuffix("SessionSheet.swift") }?.text ?? ""
        if let start = summary.range(of: "struct SessionSummarySheet") {
            let body = summary[start.upperBound...].components(separatedBy: "\nstruct ").first ?? ""
            if body.contains("HStack") { sheets.append("SessionSummarySheet: lo que va lado a lado no usa AdaptiveStack") }
            if !body.contains("isAccessibilitySize ? [.large]") { sheets.append("SessionSummarySheet: con la letra más grande no abre a todo lo alto") }
        }
        // Auditoría 3: «Cerrar el resumen» se partía en dos renglones junto a «Escribir sobre ella» en
        // uno. Botones de texto lado a lado van en `ButtonPair`: del mismo ancho en un renglón, o uno
        // bajo otro.
        for file in Self.screens {
            for (index, line) in file.lines.enumerated() where line.contains("AdaptiveStack") || line.contains("HStack") {
                let next = file.lines[(index + 1)..<min(index + 3, file.lines.count)].joined()
                let buttons = ["PrimaryButton(", "SecondaryButton(", "QuietButton("].map { next.components(separatedBy: $0).count - 1 }.reduce(0, +)
                if buttons > 1 { sheets.append("\(file.path):\(index + 1): botones de texto lado a lado sin ButtonPair") }
            }
        }
        if !Self.piece("ButtonPair").contains("sizeThatFits(.unspecified).width <= part") {
            sheets.append("ButtonPair: no comprueba que cada botón quepa entero en su parte")
        }
        check(sheets, "Hoja que deja fuera lo de abajo con la letra más grande o en un iPhone chico")

        // 12. Auditoría 2: la bienvenida de la Mac medía 820 de alto en una ventana de 672, así que
        //     su barra de abajo («Volver al paso anterior», «Ir a la biblioteca») quedaba fuera y no
        //     había cómo saltarla. Ninguna hoja de la Mac pasa de `Mac.sheetMax`, que cabe bajo la
        //     barra de la ventana más chica; la medida del lector es solo para su ventana.
        let theme12 = Self.sources("App/Shared/Design").first { $0.path.hasSuffix("Theme.swift") }!.text
        func macHeight(_ name: String) -> Double? {
            let pattern = #"static let \#(name)(: CGFloat = ([0-9.]+)| = CGSize\(width: [0-9.]+, height: ([0-9.]+)\))"#
            guard let match = try! NSRegularExpression(pattern: pattern).firstMatch(in: theme12, range: NSRange(theme12.startIndex..., in: theme12)) else { return nil }
            for group in [2, 3] { if let range = Range(match.range(at: group), in: theme12) { return Double(theme12[range]) } }
            return nil
        }
        var mac12: [String] = []
        let sheetMax = macHeight("sheetMax") ?? .infinity
        let macToolbar = 52.0 // la barra de la ventana: título y herramientas juntos
        if sheetMax + macToolbar > (macHeight("window") ?? 0) { mac12.append("Mac.sheetMax no cabe bajo la barra de la ventana más chica") }
        for name in ["sheet", "settingsPage"] where (macHeight(name) ?? .infinity) > sheetMax {
            mac12.append("Mac.\(name) mide más que Mac.sheetMax")
        }
        mac12 += hits(#"Size\.macReader"#, in: Self.ui.filter { !$0.path.hasSuffix("LectoraApp.swift") })
        let welcome = Self.screens.first { $0.path.hasSuffix("WelcomeScreen.swift") }?.text ?? ""
        if !welcome.contains("WelcomeExits(") || !welcome.contains("min(contentHeight, Theme.Mac.sheetMax)") {
            mac12.append("WelcomeScreen: en la Mac no tiene sus salidas a la vista o pasa de Mac.sheetMax")
        }
        // Auditoría 3: «Sesión terminada» medía siempre `Mac.sheetMax` y quedaba medio vacía. Una hoja
        // de la Mac mide su contenido, con tope en `Mac.sheetMax`.
        mac12 += hits(#"height: Theme\.Mac\.sheetMax\)"#, in: Self.screens)
            .map { "\($0) — alto fijo: mide el contenido con min(contentHeight, Theme.Mac.sheetMax)" }
        check(mac12, "Hoja de la Mac más alta que la ventana: lo de abajo queda fuera")

        // 9. UX-1a: el primer renglón del libro quedaba bajo los botones de arriba. El aire de
        //    arriba alcanza para el botón entero (`tapTarget` − `chromeLift`).
        let theme9 = Self.sources("App/Shared/Design").first { $0.path.hasSuffix("Theme.swift") }!.text
        func value(_ name: String) -> Double {
            guard let range = theme9.range(of: #"static let \#(name): CGFloat = [0-9.]+"#, options: .regularExpression) else { return 0 }
            return Double(theme9[range].split(separator: " ").last ?? "") ?? 0
        }
        XCTAssertGreaterThanOrEqual(value("pageMarginTop"), value("tapTarget") - value("chromeLift"),
                                    "Reader.pageMarginTop: los botones de arriba tapan el primer renglón")

        // 10. Auditoría de medios (27 nov 2026): en «Aa», «Noche cálida» se achicaba para caber y
        //     «Clásica y compa…» se cortaba; las muestras «Aa» medían distinto con la letra grande.
        //     Lo que no cabe usa dos renglones (nunca se achica) y cada muestra va en la misma caja.
        let appearance = Self.ui.first { $0.path.hasSuffix("Reader/ReaderAppearance.swift") }!
        var aa = hits(#"minimumScaleFactor"#, in: [appearance])
        if !appearance.text.contains(#"Text("Aa")"#) || appearance.text.components(separatedBy: #"Text("Aa")"#)[1]
            .prefix(400).range(of: "frame(width: Theme.Size.tapTarget, height: Theme.Size.tapTarget)") == nil {
            aa.append("ReaderAppearance: la muestra «Aa» de cada letra no va en la misma caja")
        }
        // Una fuente propia con `size:` crece con la letra de iOS y la del sistema no: Charter salía
        // enorme junto a un «Aa» chico de New York. La muestra usa `fixedSize:`.
        aa += hits(#"\.custom\("[^"]+", size: size\)"#, in: [appearance])
        check(aa, "Etiquetas que se achican o muestras de distinto tamaño en «Aa»")

        // 11. Auditoría de medios: lo que flota sobre el libro no tapa media página con la letra más
        //     grande (tope `Letter.readerChromeLargest`) y en una ventana ancha mide lo que la
        //     columna del libro (`Size.readingPanel`), centrado; en la Mac la tarjeta cruzaba la ventana.
        var floating: [String] = []
        let readerView = Self.ui.first { $0.path.hasSuffix("Reader/ReaderView.swift") }!.text
        for piece in ["private struct BottomPanel", "private struct HighlightCard", "private struct SelectionBar"] {
            let body = readerView.components(separatedBy: piece).dropFirst().first?.components(separatedBy: "\nprivate struct").first ?? ""
            if !body.contains("frame(maxWidth: Theme.Size.readingPanel)") || !body.contains("dynamicTypeSize(...Theme.Letter.readerChromeLargest)") {
                floating.append("\(piece): sin tope de ancho o de letra")
            }
        }
        // Las columnas de la tabla de la Mac se encogen y cortan con «…» antes que correr de lado.
        let table = Self.ui.first { $0.path.hasSuffix("Mac/MacBookTable.swift") }?.text ?? ""
        if table.contains(".width(min: Theme.Mac.column)") || table.contains(".width(min: Theme.Mac.shortColumn)") {
            floating.append("MacBookTable: una columna no se encoge (usa min: Theme.Mac.narrowColumn, ideal: …)")
        }
        check(floating, "Lo que flota en el lector o la tabla de la Mac no cabe")

        // 12. Auditoría 7 (27 nov 2026): en Ajustes de la Mac el porqué de «Traer mi biblioteca de
        //     Calibre» apagado se cortaba en un renglón, y la vista previa de una nota se cortaba a
        //     media palabra y sin «…». Una razón de botón apagado siempre se lee completa
        //     (`ReasonLine`, que baja de renglón también en un formulario de la Mac); un texto
        //     cortado siempre termina en «…», entre palabras (`String.clipped(to:)`).
        let reason = pieces.first { $0.name == "ReasonLine" }?.body ?? ""
        var cut = hits(#"Text\((blocked|reason|busyReason|model\.addBooksBlocked|library\.busyReason|model\.library\.busyReason)\)"#, in: Self.ui)
        if !reason.contains(".fixedSize(horizontal: false, vertical: true)") || !reason.contains(".lineLimit(nil)") {
            cut.append("ReasonLine: no baja de renglón")
        }
        // Cortar a mano (`prefix(n)` y «…» pegado) parte la palabra; y la vista previa de las notas.
        cut += hits(#"\.prefix\([^)]*\)\)? *\+ *"…""#, in: Self.ui)
        let note = Self.sources("Packages/LectoraCore/Sources").first { $0.path.hasSuffix("Notes/Note.swift") }?.text ?? ""
        if !note.contains(".clipped(to: Self.previewLetters)") { cut.append("Note.preview no corta entre palabras con «…»") }
        check(cut, "Un texto que se lee a medias: la razón de algo apagado va entera (ReasonLine) y lo cortado, entre palabras y con «…» (clipped(to:))")

        // 13. iPhone Duo (27 nov 2026). Cerrado, la hora va al costado y arriba no hay isla: los
        //     botones de arriba del lector subían `chromeLift` y se salían por arriba, cortados.
        //     Suben solo lo que hay de orilla segura (`chromeTop`), y aun sin isla dejan libre el
        //     primer renglón.
        var duo = hits(#"padding\(\.top, -Theme\.Reader\.chromeLift\)"#, in: Self.ui)
            .map { "\($0) — sube aunque no haya isla: usa chromeTop" }
        if !readerView.contains("max(Theme.Reader.chromeEdge - safeTop, -Theme.Reader.chromeLift)") {
            duo.append("ReaderView.chromeTop: los botones de arriba no miran la orilla segura")
        }
        if value("pageMarginTop") < value("tapTarget") + value("chromeEdge") {
            duo.append("Reader.pageMarginTop: sin isla, los botones de arriba tapan el primer renglón")
        }
        //     Ninguna pantalla pregunta qué aparato es: todas leen la forma de la ventana
        //     (`WindowLayout`) y usan las piezas comunes. Ni banderas del Duo ni clase de tamaño en las
        //     pantallas (la Mesa en dos columnas preguntaba `horizontalSizeClass`).
        //     (Las otras opciones del lector, `Duo.` en Debug, no preguntan el aparato: cambian la decisión.)
        for file in Self.screens {
            for (index, line) in file.lines.enumerated() where !line.trimmingCharacters(in: .whitespaces).hasPrefix("//") {
                if line.contains("horizontalSizeClass") || (file.path.contains("/Screens/") && line.contains("Duo.")) {
                    duo.append("\(file.path):\(index + 1): pregunta el aparato; usa WindowLayout y las piezas de Layout.swift")
                }
            }
        }
        //     El texto no cruza de orilla a orilla ni el pliegue: `screenContent` y `formScreen` se
        //     quedan en el renglón cómodo (`ReadingColumn`); solo Mesa, Biblioteca y cada página de un
        //     pliego (`Spread`) usan todo el ancho, por sus portadas.
        let recipes = Self.ui.first { $0.path.hasSuffix("Design/Components.swift") }!.text
        let layout = Self.ui.first { $0.path.hasSuffix("Design/Layout.swift") }?.text ?? ""
        let content = recipes.components(separatedBy: "struct ScreenContent").dropFirst().first?.components(separatedBy: "\n}").first ?? ""
        if !content.contains("ReadingColumn(active: !wide)") { duo.append("ScreenContent: no se queda en el renglón cómodo") }
        let form = recipes.components(separatedBy: "func formScreen(").dropFirst().first?.components(separatedBy: "\n    }").first ?? ""
        if !form.contains(".readingColumn()") { duo.append("formScreen: no se queda en el renglón cómodo") }
        if !layout.contains("widthBeforeFold(") { duo.append("ReadingColumn: el renglón cruza el pliegue") }
        let wide = hits(#"\.screenContent\(wide: true\)"#, in: Self.ui)
            .filter { hit in !["MesaScreen.swift", "LibraryScreen.swift", "Design/Layout.swift"].contains { hit.hasPrefix("App/Shared/") && hit.contains($0) } }
        duo += wide.map { "\($0) — a todo lo ancho solo Mesa, Biblioteca y las páginas de un pliego" }
        //     La cuadrícula pone las columnas que quepan por ancho y por alto (`CoverColumns`): en una
        //     ventana baja se ve un libro entero, no tres portadas enormes.
        if !recipes.contains("Theme.Size.gridColumns(fitting: width, height: window.size.height") {
            duo.append("CoverGrid: columnas fijas o sin mirar el alto; en una pantalla baja no se ve un libro entero")
        }
        //     Lo que en un iPhone es una hoja, con el pliegue se abre en una página y se cierra con
        //     `SheetDismiss` (con `dismiss` el panel no se iría).
        for file in Self.ui where file.text.contains(".sidePanel(") {
            for name in ["MetadataEditorView", "CoverPickerSheet", "SettingsScreen", "ReaderToolsSheet", "SessionSummarySheet"]
            where file.text.contains("\(name)(") {
                let owner = Self.ui.first { $0.text.contains("struct \(name):") }
                if let owner, owner.text.contains("@Environment(\\.dismiss)") {
                    duo.append("\(owner.path): \(name) se abre como panel y se cierra con dismiss; usa SheetDismiss")
                }
            }
        }
        //     Un panel abierto desde una pantalla empujada (la ficha en lista | detalle) sube a la raíz:
        //     encima de la ficha, iOS regresaba a la lista y el panel no se veía (ronda 1). Y la lista
        //     llega justo al pliegue (con solo el ancho ideal, iOS la dejaba en un tercio).
        if !layout.contains("@Environment(\\.isPresented) private var pushed") || !layout.contains("PanelHostLayer(host: host)") {
            duo.append("SidePanel: el panel de una pantalla empujada no sube a la raíz")
        }
        //     Con eso solo, UIKit la topaba en un tercio de la ventana y la ficha cruzaba el pliegue
        //     (ronda 1, medido en las capturas): el ancho se fija también en su columna de UIKit.
        if !layout.contains("navigationSplitViewColumnWidth(min: sidebar, ideal: sidebar, max: sidebar)")
            || !layout.contains(".background(PrimaryColumnWidth(width: sidebar))")
            || !layout.contains("split.maximumPrimaryColumnWidth = width") {
            duo.append("FoldSplit: la lista no llega al pliegue")
        }
        //     Lo que se lee de un vistazo va en dos partes (`Spread`): la pregunta y su respuesta en la
        //     bienvenida, la gráfica y sus libros en el Diario; así, acostado se ve el botón y con el Duo
        //     abierto ninguna página queda vacía.
        for name in ["WelcomeScreen", "DiaryScreen", "MesaScreen", "BookDetailScreen"]
        where !(Self.screens.first { $0.path.hasSuffix("\(name).swift") }?.text.contains("Spread(") ?? false) {
            duo.append("\(name): una sola columna; va en dos partes con Spread")
        }
        //     Ninguna hoja del iPhone se abre al centro, encima del pliegue: toda va con `.sidePanel`,
        //     que con el Duo abierto la pone en una página (ronda 1: Traer de Calibre, «A una nota» y las
        //     de Por revisar salían sobre el lomo). Fuera: la Mac y el diccionario del sistema.
        for file in Self.ui where !file.path.contains("/Mac/") && !file.path.hasSuffix("Design/Layout.swift")
            && !file.path.hasSuffix("LookupCard.swift") {
            var macOnly = false
            for (index, line) in file.lines.enumerated() {
                let code = line.trimmingCharacters(in: .whitespaces)
                if code.hasPrefix("#if os(macOS)") || code.hasPrefix("#else") { macOnly = code.hasPrefix("#if os(macOS)") || (code.hasPrefix("#else") && !macOnly) }
                if code.hasPrefix("#endif") { macOnly = false }
                if !macOnly, !code.hasPrefix("//"), code.contains(".sheet(") {
                    duo.append("\(file.path):\(index + 1): hoja de iOS al centro; usa .sidePanel")
                }
            }
        }
        //     En el lector, la lectura guiada sigue la página del renglón (con dos páginas, la otra en
        //     penumbra) y la serie de la ficha no deja un «·» colgando al partirse.
        let readerJS = (try? String(contentsOf: Self.root.appendingPathComponent("App/Resources/Reader/reader.js"), encoding: .utf8)) ?? ""
        if !readerJS.contains("visiblePages(") { duo.append("reader.js: la guía no sabe en qué página va el renglón") }
        if !(Self.screens.first { $0.path.hasSuffix("BookDetailScreen.swift") }?.text.contains("DotLine(") ?? false) {
            duo.append("BookDetailScreen: la serie se une con « · » a mano; usa DotLine")
        }
        //     Una hoja enseña su título aunque iOS ponga la hora al costado, y sus dos salidas se miden
        //     contra el ancho de verdad (en el Duo cerrado «Ir a la biblioteca» se iba al «•••»).
        if !recipes.contains("struct LargeSheetTitle") { duo.append("Sin LargeSheetTitle: el título de una hoja se esconde junto a la franja") }
        if !(pieces.first { $0.name == "SheetActions" }?.body.contains("fitsInBar") ?? false) {
            duo.append("SheetActions: no mide si sus dos botones caben en la barra")
        }
        //     Cada hoja y cada pantalla completa del iPhone declara `duoBars()`: iOS le pregunta a lo
        //     que va hasta arriba de cada presentación, y una que no lo diga regresa la franja (DUO-1).
        for file in Self.ui where !file.path.contains("/Mac/") {
            var macOnly = 0
            for (index, line) in file.lines.enumerated() {
                let code = line.trimmingCharacters(in: .whitespaces)
                if code.hasPrefix("#if os(macOS)") { macOnly += 1 }
                if code.hasPrefix("#endif") || code.hasPrefix("#else"), macOnly > 0 { macOnly -= 1 }
                guard macOnly == 0, !code.hasPrefix("//"),
                      line.contains(".sheet(") || line.contains(".fullScreenCover(") else { continue }
                var depth = 0, body = ""
                for next in file.lines[index...] {
                    body += next
                    depth += next.filter { $0 == "{" }.count - next.filter { $0 == "}" }.count
                    if depth <= 0 && next.contains("}") { break }
                }
                if !body.contains("duoBars()") { duo.append("\(file.path):\(index + 1): \(code.prefix(100))") }
            }
        }
        check(duo, "No cabe en el iPhone Duo (cerrado o abierto)")

        // 14. Auditoría 8 (27 nov 2026): con AX5 salía «Wake-/field», «Los detec-/tives» y
        //     «conquista-/dores», y en una nota `joined(sepa-/rator:`. Nada se parte a media palabra:
        //     todo título de libro o de nota es `WholeWordsText` (si su palabra más ancha no cabe, la
        //     letra baja un paso), el código corre de lado y el pie de una portada no deja «·» colgando.
        var split: [String] = []
        let whole = Self.piece("WholeWordsText")
        if !whole.contains("ViewThatFits(in: .horizontal)") || !whole.contains("WordWidthLayout") || !whole.contains("titleScales") {
            split.append("WholeWordsText: no baja la letra cuando su palabra más ancha no cabe")
        }
        // Auditoría 9 (M2, B3): primero dos renglones, luego un poco más chico (como mucho tres pasos y,
        // con la letra grande, nunca menos que la normal) y al final «…»; las palabras se miden con sus marcas.
        if !whole.contains("static let maxSteps = 3") || !whole.contains("$0 >= .large") || !whole.contains("prefix(maxSteps + 1)") {
            split.append("WholeWordsText: la letra baja sin piso (con AX5 el título quedaba diminuto)")
        }
        if !whole.contains(".lineLimit(1).truncationMode(.tail)") || !whole.contains("floor.") {
            split.append("WholeWordsText: en el piso el título no termina en «…»")
        }
        if !whole.contains("Self.words(text)") || whole.contains("Text(verbatim: $0)") {
            split.append("WholeWordsText: mide las palabras sin sus marcas (la negrita de lo buscado)")
        }
        for name in ["CoverCell", "BookRow", "NoteRow", "TitleDetailRow", "NoteBody", "CandidateRow"] where !Self.piece(name).contains("WholeWordsText(") {
            split.append("\(name): su título puede partirse a media palabra")
        }
        if !(Self.sources("App/Shared/Design").first { $0.path.hasSuffix("CoverView.swift") }?.text ?? "").contains("WholeWordsText(title)") {
            split.append("CoverView: el título de la portada dibujada puede partirse")
        }
        // Fuera de la Mac (allá se corta con «…» en un renglón), un título nunca va en un `Text` suelto.
        split += hits(#"\bText\((book|live|candidate)\??\.title\)|\bText\((bookTitle|term)\)"#,
                      in: Self.ui.filter { !$0.path.hasPrefix("App/Shared/Mac/") })
        let code = Self.piece("NoteBody")
        if !code.contains("ScrollView(.horizontal)") || !code.contains(".fixedSize(horizontal: true, vertical: false)") {
            split.append("NoteBody: un renglón de código se parte en vez de correr de lado")
        }
        if !Self.piece("CoverCell").contains("components(separatedBy: \" · \")") {
            split.append("CoverCell: «Nuevo ·…» con la letra grande; el estado y el autor no bajan a su renglón")
        }
        // Ronda 1 del Duo: en Ajustes › Apariencia, lado a lado con AX5 salía «Sis-/tema».
        if !Self.piece("PageSwatchPicker").contains(".fixedSize(horizontal: true, vertical: false)") {
            split.append("PageSwatchPicker: el nombre de cada hojita puede partirse a media palabra")
        }
        check(split, "Una palabra partida a media palabra con la letra grande (regla 9)")

        // 15. Auditoría 8: en Aa › Fondo la muestra «Aa» salía «…» con AX5 y el círculo de «Noche
        //     cálida» quedaba más arriba. La muestra tiene tope de letra y los círculos van arriba.
        if !appearance.text.contains("swatch(for: item)\n                                // El «Aa» cabe en su círculo de 44: con AX5 salía «…» (auditoría 8).\n                                .dynamicTypeSize(...Theme.Letter.fixedShapeLargest)")
            || !appearance.text.contains("AdaptiveStack(rowAlignment: .top) {\n                ForEach(ReaderTheme.allCases)") {
            XCTFail("Aa › Fondo: la muestra «Aa» no tiene tope o los círculos no van arriba")
        }
        // Lo fijo al pie de una lista (`BottomBar`) tiene tope de letra, como lo que flota sobre el libro.
        if !Self.piece("BottomBar").contains("dynamicTypeSize(...Theme.Letter.readerChromeLargest)") {
            XCTFail("BottomBar: con AX5 la barra fija llena media lista")
        }
        // 16. Auditoría 8: con la guía de renglón asomaba una franja gris en la orilla izquierda,
        //     a la altura del renglón. Solo se aclara el texto; las orillas siguen en penumbra.
        if !Self.piece("GuideShade").contains("?? Theme.Reader.textMargin...") {
            XCTFail("GuideShade: el renglón se aclara de orilla a orilla y asoma la sombra de la página")
        }
    }

    /// Regla 4, números exactos: cantidades, fechas y porcentajes con cifras del mismo ancho
    /// en toda pieza que los enseña, para que no bailen al cambiar.
    func testFiguresAreExact() {
        let problems = ["CapsText", "FactRow", "LinkRow", "StatTrio", "RecentSearchRow"]
            .filter { !Self.piece($0).contains(".monospacedDigit()") }
        check(problems, "Pieza que enseña cifras sin .monospacedDigit()")
    }

    /// Regla 5 y sistema base de la casa (SB-2, interoperabilidad): el espacio sale de la
    /// escala común 4 · 8 · 16 · 24 · 32 · 48. Gabinete arrastraba 12 y 6 con trinquete;
    /// el 26 nov 2026 la cuenta llegó a cero y ya no puede volver a subir.
    func testSpacingKeepsTheHouseScale() {
        let config = (try? String(contentsOf: Self.root.appendingPathComponent("sistema-base.json"), encoding: .utf8)) ?? ""
        let data = Data(config.utf8)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let inherited = json?["heredado"] as? [String: [String: Int]] ?? [:]
        var problems = inherited.flatMap { rule, files in files.map { "\(rule): \($0.key) (\($0.value))" } }
        problems += hits(#"static let (m|inline): CGFloat"#, in: Self.sources("App/Shared/Design"))
        // 26 nov 2026 (SD-1): el margen de 28 y los aires de 10, 14 y 20 rompían la escala con
        // otro nombre. Toda medida de `Theme.Space` y todo margen del lector cae en la escala.
        let scale: Set<Double> = [0, 4, 8, 16, 24, 32, 48, 64]
        let theme = Self.sources("App/Shared/Design").first { $0.path.hasSuffix("Theme.swift") }?.lines ?? []
        let margins = ["chromeInset", "chromeLift", "chromeEdge", "textMargin", "pageMarginTop", "pageMarginBottom", "folioFadeDrop", "topFade", "slitPadding"]
        let value = try! NSRegularExpression(pattern: #"static let (\w+): CGFloat = (-?[0-9.]+)"#)
        var inSpace = false
        for (index, line) in theme.enumerated() {
            if line.contains("enum Space {") { inSpace = true }
            if inSpace, line.hasPrefix("    }") { inSpace = false }
            guard let match = value.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                  let name = Range(match.range(at: 1), in: line), let number = Range(match.range(at: 2), in: line),
                  inSpace || margins.contains(String(line[name])), !line.contains("sistema-base: ignora"),
                  let amount = Double(line[number]), !scale.contains(amount) else { continue }
            problems.append("Theme.swift:\(index + 1): \(line[name]) = \(line[number])")
        }
        // Lo que el revisor de la casa vigila de Theme son esos mismos nombres (sistema-base.json).
        let pattern = (json?["tokens"] as? [[String: Any]])?.first?["patron"] as? String ?? ""
        for name in margins + ["rowY", "rowGap", "buttonX", "gutter", "screenTop", "screenBottom"] where !pattern.contains(name) {
            problems.append("sistema-base.json no vigila \(name)")
        }
        // El libro (reader.js): márgenes, rellenos y huecos en px también en la escala.
        let css = try! NSRegularExpression(pattern: #"(?:margin|padding|gap)[a-z-]*:\s*([0-9.]+)px"#)
        for (index, line) in Self.readerScript.components(separatedBy: "\n").enumerated() {
            for match in css.matches(in: line, range: NSRange(line.startIndex..., in: line)) {
                guard let number = Range(match.range(at: 1), in: line), let amount = Double(line[number]),
                      !scale.contains(amount) else { continue }
                problems.append("reader.js:\(index + 1): \(line.trimmingCharacters(in: .whitespaces))")
            }
        }
        check(problems, "Espacio fuera de la escala común (SB-2): usa s, l, xl… y deja `heredado` en cero")
    }

    static let readerScript = (try? String(contentsOf: root.appendingPathComponent("App/Resources/Reader/reader.js"), encoding: .utf8)) ?? ""

    /// Regla 6, botón principal oscuro en los dos modos: verde fichero con letra clara;
    /// en oscuro era un bloque verde menta que gritaba más que el libro.
    func testMainActionIsDarkInBothModes() {
        let theme = Self.sources("App/Shared/Design").first { $0.path.hasSuffix("Theme.swift") }?.text ?? ""
        var problems: [String] = []
        // Desde el 26 nov 2026 la acción es el verde hondo en los dos modos: sale de `Theme.Green`.
        if !theme.contains("static let action = Color(light: Green.light, dark: Green.light)") {
            problems.append("Theme.action no es Green.light en los dos modos")
        }
        if let green = Self.greenPair(theme), Self.luminance(green.light) > 0.1 {
            problems.append("Theme.Green.light no es oscuro: la acción principal dejaría de leerse como bloque")
        }
        if !Self.piece("PrimaryButton").contains("Theme.action") { problems.append("PrimaryButton no usa Theme.action") }
        check(problems, "La acción principal va oscura en los dos modos")
    }

    static func greenPair(_ theme: String) -> (light: UInt32, dark: UInt32)? {
        let regex = try! NSRegularExpression(pattern: #"static let (light|dark): UInt32 = 0x([0-9A-F]{6})"#)
        var found: [String: UInt32] = [:]
        for match in regex.matches(in: theme, range: NSRange(theme.startIndex..., in: theme)) {
            if let key = Range(match.range(at: 1), in: theme), let hex = Range(match.range(at: 2), in: theme) {
                found[String(theme[key])] = UInt32(theme[hex], radix: 16)
            }
        }
        guard let light = found["light"], let dark = found["dark"] else { return nil }
        return (light, dark)
    }

    static func luminance(_ hex: UInt32) -> Double {
        func linear(_ value: UInt32) -> Double {
            let channel = Double(value & 0xFF) / 255
            return channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(hex >> 16) + 0.7152 * linear(hex >> 8) + 0.0722 * linear(hex)
    }

    /// Un color «se ve verde» si su tono cae entre el amarillo verdoso y el azul verdoso y
    /// no es casi gris (el `#24332B` de la marca vieja lo era: tono 128°, saturación 0,29).
    static func looksGreen(_ hex: UInt32) -> Bool {
        let (r, g, b) = (Double((hex >> 16) & 0xFF), Double((hex >> 8) & 0xFF), Double(hex & 0xFF))
        let top = max(r, g, b), span = top - min(r, g, b)
        guard top > 0, span / top > 0.2, g == top || (b == top && g > r) else { return false }
        let hue: Double = g == top ? 120 + 60 * (b - r) / span : 240 + 60 * (r - g) / span
        return (80...190).contains(hue)
    }

    /// Sistema base de la casa (D2-B, interoperabilidad): la negrita va solo en el título más
    /// grande y en cifras; lo demás, en seminegrita o media.
    func testBoldOnlyForTitlesAndFigures() {
        check(hits(#"\.bold\(\)|(weight|fontWeight)\(\.(bold|heavy|black)\)"#, in: Self.sources("App")),
              "Negrita fuera de un título o una cifra: usa .semibold o .medium (D2-B)")
    }

    /// Recetas: toda pantalla se arma con una receta (`.screen()`, `.pushedScreen()` o
    /// `.formScreen()`): así lo nuevo nace con el papel, el margen y la barra de la app.
    func testEveryScreenFollowsARecipe() {
        /// Piezas con estado que viven con las pantallas pero no son una.
        let notScreens = ["MiniPlayer.swift"]
        let problems = Self.sources("App/Shared/Screens")
            .filter { file in !notScreens.contains { file.path.hasSuffix($0) } }
            .filter { !$0.text.contains(".screen()") && !$0.text.contains(".pushedScreen(") && !$0.text.contains(".formScreen()") }
            .map(\.path)
        check(problems, "Pantalla sin receta: usa .screen(), .pushedScreen() o .formScreen() (ver «Recetas»)")
    }

    /// 26 nov 2026: después del cambio al verde botella, los subrayados, el marcador del libro,
    /// la barra de avance y las etapas seguían en el verde azulado de antes: cada uno escribía
    /// su propio verde. El verde se escribe una vez, en `Theme.Green`; todo lo demás apunta ahí
    /// (`Theme.accent`, `Theme.highlight`, `Theme.Green.css`). El libro (reader.js) no escribe colores.
    func testOneGreenForEverything() {
        let theme = Self.sources("App/Shared/Design").first { $0.path.hasSuffix("Theme.swift") }?.text ?? ""
        var problems = Self.greenPair(theme) == nil ? ["No encontré Theme.Green.light y .dark"] : []
        // Ningún color con tono verde se escribe fuera de `Theme.Green`, ni en Theme.swift
        // (26 nov 2026: la marca y la acción tenían otro verde, #24332B, y el color del sistema
        // salía de ahí; los acentos no se veían iguales).
        let hex = try! NSRegularExpression(pattern: #"0x([0-9A-Fa-f]{6})\b"#)
        for file in Self.sources("App") {
            var insideGreen = false
            for (index, line) in file.lines.enumerated() {
                if line.contains("enum Green {") { insideGreen = true }
                defer { if insideGreen, line.trimmingCharacters(in: .whitespaces) == "}" { insideGreen = false } }
                if insideGreen || line.contains("ds-exception:") { continue }
                for match in hex.matches(in: line, range: NSRange(line.startIndex..., in: line)) {
                    guard let range = Range(match.range(at: 1), in: line), let value = UInt32(line[range], radix: 16),
                          Self.looksGreen(value) else { continue }
                    problems.append("\(file.path):\(index + 1): #\(line[range]) \(line.trimmingCharacters(in: .whitespaces).prefix(100))")
                }
            }
        }
        // 27 nov 2026: lo elegido en la tabla y la barra lateral de la Mac salía en el azul del
        // sistema. El color del catálogo (`AccentColor`) lo vuelve verde, pero es otro lugar
        // donde se escribe un verde: se permite solo si es exactamente `Theme.Green`, claro y oscuro.
        problems += Self.catalogGreens(matching: Self.greenPair(theme))
        // El color del sistema (enlaces, «Listo», alertas) es el acento.
        let app = Self.sources("App/Shared").first { $0.path.hasSuffix("LectoraApp.swift") }?.text ?? ""
        if !app.contains(".tint(Theme.accent)") { problems.append("LectoraApp: el color del sistema no es Theme.accent") }
        let script = (try? String(contentsOf: Self.root.appendingPathComponent("App/Resources/Reader/reader.js"), encoding: .utf8)) ?? ""
        let css = try! NSRegularExpression(pattern: #"'#[0-9A-Fa-f]{6}'"#)
        if css.firstMatch(in: script, range: NSRange(script.startIndex..., in: script)) != nil {
            problems.append("reader.js escribe un color: el verde llega de la app (Theme.Green.css)")
        }
        check(problems, "Un verde escrito fuera de Theme.Green: apunta a Theme.accent, Theme.highlight o Theme.Green.css")
    }

    /// Los colores del catálogo de la app (`*.colorset`) que se ven verdes: solo vale
    /// `AccentColor`, y con los valores de `Theme.Green` (claro sin apariencia, oscuro con «dark»).
    static func catalogGreens(matching green: (light: UInt32, dark: UInt32)?) -> [String] {
        let base = root.appendingPathComponent("App/Resources")
        let sets = (FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil)?.compactMap { $0 as? URL } ?? [])
            .filter { $0.pathExtension == "colorset" }
        var problems: [String] = []
        for set in sets {
            let name = set.deletingPathExtension().lastPathComponent
            guard let data = try? Data(contentsOf: set.appendingPathComponent("Contents.json")),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let colors = json["colors"] as? [[String: Any]] else { problems.append("\(name): no pude leer sus colores"); continue }
            var values: [String: UInt32] = [:]
            for entry in colors {
                guard let components = (entry["color"] as? [String: Any])?["components"] as? [String: String] else { continue }
                func channel(_ key: String) -> UInt32 {
                    let text = components[key] ?? "0"
                    if text.hasPrefix("0x") { return UInt32(text.dropFirst(2), radix: 16) ?? 0 }
                    let number = Double(text) ?? 0
                    return UInt32((number <= 1 && text.contains(".") ? number * 255 : number).rounded())
                }
                let hex = channel("red") << 16 | channel("green") << 8 | channel("blue")
                let dark = (entry["appearances"] as? [[String: String]])?.contains { $0["value"] == "dark" } ?? false
                values[dark ? "dark" : "light"] = hex
            }
            let greens = values.filter { looksGreen($0.value) }
            guard !greens.isEmpty else { continue }
            if name != "AccentColor" {
                problems.append("App/Resources/…/\(name).colorset: otro verde en el catálogo")
            } else if let green, values["light"] != green.light || values["dark"] != green.dark {
                problems.append("AccentColor.colorset no es Theme.Green: " + values.map { "\($0.key) #\(String(format: "%06X", $0.value))" }.sorted().joined(separator: ", "))
            }
        }
        return problems
    }

    /// 26 nov 2026: la Mac decía «Renombrar en 1 libros». Una cifra y lo que cuenta salen de
    /// `counted`, que concuerda «1 libro» y «2 libros». SD-1: la prueba no veía
    /// `\(ReadingFormat.words(x)) palabras` (paréntesis dentro), ni «días», «resultados» o
    /// «estrellas», y dejaba pasar todo renglón con `== 1`: «1 días» salía en la Mesa.
    func testCountsAgreeWithTheirNumber() {
        let nouns = "libros?|notas?|subrayados?|citas?|sesion(?:es)?|sesión|portadas?|autor(?:es)?|series|etiquetas?|palabras?|"
            + "días?|resultados?|estrellas?|opcion(?:es)?|opción|archivos?|capítulos?|grupos?|encontrados?|minutos?|horas?|"
            + "páginas?|veces|vez|formatos?|marcadores?|búsquedas?|tomos?|idiomas?"
        let interpolation = #"\\\((?:[^()]|\((?:[^()]|\([^()]*\))*\))*\)"#
        check(hits(interpolation + #" (\#(nouns))\b(?![/a-z])"#, in: Self.sources("App")),
              "Cifra con su sustantivo armada a mano: usa n.counted(\"libro\", \"libros\")")
        // UX-4d: «\(días) de \(total.counted("día", "días"))» decía «1 días de 7». El sustantivo
        // concuerda con la primera cifra: «1 día de 7».
        check(hits(interpolation + #" de \\\([^()]*\.counted\("#, in: Self.sources("App")),
              "«x de y» con el sustantivo en la segunda cifra: va en la primera («1 día de 7»)")
        // Auditoría 3: con «Series» elegido la Biblioteca seguía enseñando «Por revisar 3», libros que no
        // eran los del filtro. Lo que cuenta toda la biblioteca solo va en «Todos».
        let library = Self.screens.first { $0.path.hasSuffix("Screens/LibraryScreen.swift") }?.text ?? ""
        //     Ronda 0 del Duo: los estantes («Cortázar 3») salían bajo «0 libros» con otro filtro.
        var whole = library.contains("if filter == .all, !model.library.reviews.isEmpty") ? [] : ["LibraryScreen: «Por revisar» con un filtro elegido"]
        if !library.contains("if filter == .all {\n                                ForEach(model.library.shelves)") { whole.append("LibraryScreen: estantes con un filtro elegido") }
        check(whole,
              "Un número de toda la biblioteca bajo un filtro: va solo en «Todos»")
    }

    // MARK: Las mismas palabras y la misma voz (SD-2 y SD-3, 26 nov 2026)

    /// Regla 7: un aviso dice qué pasó en primera persona («No pude abrir el libro») y su botón
    /// a dónde vuelves. Antes había «Aviso», «Nota», «Importación» y once «No se pudo».
    func testNoticesSayWhatHappened() {
        let app = Self.ui.filter { !$0.path.hasSuffix("Design/Components.swift") }
        // Un aviso de un botón sale de .errorAlert o .noticeAlert; .alert a mano solo si pide escribir.
        var handMade: [String] = []
        for file in app {
            for (index, line) in file.lines.enumerated() where line.contains(".alert(") {
                let next = file.lines[index..<min(index + 6, file.lines.count)].joined()
                if !next.contains("TextField") { handMade.append("\(file.path):\(index + 1): \(line.trimmingCharacters(in: .whitespaces))") }
            }
        }
        check(handMade, "Aviso armado a mano: usa .errorAlert o .noticeAlert")
        let titles = hits(#"(errorAlert|noticeAlert|\.alert|\.question|confirmationDialog)\("(Aviso|Nota|Error|Atención|Importación|[^" ]+|[^" ]+ [^" ]+)""#, in: Self.ui)
        check(titles, "Aviso cuyo título no dice qué pasó (tres palabras o más, nunca «Aviso» ni «Nota»)")
        // Auditoría de medios (27 nov 2026): «Se borra el archivo», «Se borra la llave», «Se copian
        // tus libros» seguían impersonales. Lo que hago lo digo yo: «Borro», «Copio», «La guardo».
        check(hits(#""[^"]*(No se pud|No se pued|Se guardó|Se juntó|Se completaron|[Ss]e borra|[Ss]e copia|[Ss]e guarda en|[Ss]e anota|[Ss]e aplica|[Ss]e busca|se trae|se modifica|se pintan|se pueden recuperar|se completan|se importa|se usa ese|no se toca)"#, in: Self.ui) +
              hits(#""[^"]*(No se pud|No se pued)"#, in: Self.sources("Packages/LectoraCore/Sources")),
              "Voz impersonal: di qué hice yo («No pude guardar», «Junté»)")
    }

    /// Regla 8 (UX-7 y UX-8b, 27 nov 2026): dos textos nunca se pegan. Lo que tecleabas al
    /// guardar un estante se pegaba a la búsqueda ya escrita («CorCortázar»), y en la hendidura
    /// el título del capítulo a su primera frase («Capítulo IEn un lugar…»).
    func testTextsNeverRunTogether() {
        // Dos datos seguidos sin nada en medio: «\(capítulo)\(página)».
        var problems = hits(#"\\\([\w.?!]+\)\\\("#, in: Self.ui)
        // Lo que propongo en el campo de un aviso va como pista y el campo empieza vacío: escrito
        // de antemano al abrirse el aviso (`onChange`), lo que tecleas se le pega.
        let bound = try! NSRegularExpression(pattern: #"TextField\([^\n]*text: \$(\w+)\)"#)
        for file in Self.ui {
            for (index, line) in file.lines.enumerated() where line.contains(".alert(") {
                let block = file.lines[index..<min(index + 6, file.lines.count)].joined(separator: "\n")
                let names = bound.matches(in: block, range: NSRange(block.startIndex..., in: block)).compactMap {
                    Range($0.range(at: 1), in: block).map { String(block[$0]) }
                }
                for name in names {
                    problems += hits(#"\.onChange\(of:.*\b\#(name) = (?!"")"#, in: [file])
                        .map { "\($0) — el campo «\(name)» se escribe solo al abrirse" }
                }
            }
        }
        // Auditoría de medios (27 nov 2026): renombrar un autor en la Mac abría con el nombre ya
        // escrito. Ninguna hoja escribe su campo al aparecer: el nombre de ahora va de pista.
        let anyField = try! NSRegularExpression(pattern: #"TextField\([^\n]*text: \$(\w+)"#)
        for file in Self.ui {
            let names = Set(anyField.matches(in: file.text, range: NSRange(file.text.startIndex..., in: file.text)).compactMap {
                Range($0.range(at: 1), in: file.text).map { String(file.text[$0]) }
            })
            for (index, line) in file.lines.enumerated() where line.contains(".onAppear") {
                let block = file.lines[index..<min(index + 4, file.lines.count)].joined(separator: "\n")
                for name in names where block.range(of: #"\b\#(name) = (?!"")"#, options: .regularExpression) != nil {
                    problems.append("\(file.path):\(index + 1): el campo «\(name)» se escribe solo al aparecer")
                }
            }
        }
        // La hendidura arma su texto bloque por bloque, con un salto entre el título y el párrafo.
        let reader = (try? String(contentsOf: Self.root.appendingPathComponent("App/Resources/Reader/reader.js"), encoding: .utf8)) ?? ""
        let slit = reader.components(separatedBy: "const slitFrom").dropFirst().first?.components(separatedBy: "\n}").first ?? ""
        if slit.isEmpty || slit.contains(".toString()") || !slit.contains("slitTextOf") {
            problems.append("reader.js: la hendidura toma el texto del rango tal cual y pega el título con su primera frase")
        }
        check(problems, "Dos textos pegados: sepáralos (un espacio, « · », un salto de renglón)")
    }

    /// Regla 8 (auditoría 8, 27 nov 2026): un título en hebreo o árabe revolvía su renglón
    /// («% de 31 % a 36 · שלום עליכם»). Un nombre que pones tú (título, autor, serie) junto a otras
    /// palabras o cifras («·», «…») va aislado (`.isolated`) y no se lleva lo de alrededor.
    func testNamesKeepTheirDirection() {
        let name = #"\\\((?:[\w?!]+\.)*(title|author|series|bookTitle|name)\)"#
        let problems = hits(#""[^"\n]*(·|«)[^"\n]*"# + name + #"|"# + name + #"[^"\n]*(·|»)"#, in: Self.ui)
            // Lo que va dentro de una nota (`[[Título]]`) se escribe tal cual; el nombre del aparato no es tuyo.
            .filter { !$0.contains("accessibilityLabel") && !$0.contains("[[") && !$0.contains("device.") }
        check(problems, "Un nombre junto a cifras o «·» sin aislar: usa .isolated")
    }

    /// Regla 8 (auditoría de medios, 27 nov 2026): a quien usa la app se le habla en palabras, no
    /// con lo que entiende la máquina. El estante decía «3 LIBROS · AUTOR:ASIMOV SERIE:FUNDACIÓN»,
    /// la nota «Notas/El silencio en Rulfo.md», el Cuaderno «EN NOTAS» y Buscar enseñaba
    /// «# Ideas sueltas…» del Markdown.
    func testPeopleReadWordsNotSyntax() {
        var problems = hits(#"\.query ?\?\? ?""\)"#, in: Self.screens)
            .filter { ($0.contains("Text(") || $0.contains("CountLine(") || $0.contains("message:")) && !$0.contains("describe(") }
        problems += hits(#"\\\(CabinetLocation\.notesFolder\)/|\.md"|Gabinete/Notas|· en \\\(CabinetLocation"#, in: Self.screens)
        // Lo que se enseña de una nota sale sin su marcado (`NoteMarkdown.plain`).
        problems += hits(#"Found\.excerpt\(note\.text"#, in: Self.ui)
        // El buscador de la Mac dice qué busca en palabras; los filtros están en su menú.
        problems += hits(#"prompt: "[^"]*\w+:[ "]"#, in: Self.ui)
        // Auditoría 3: la bienvenida decía «Notas (Markdown)» y el dibujo de Ajustes «Markdown».
        problems += hits(#""[^"]*\bMarkdown\b[^"]*""#, in: Self.ui)
        // Auditoría 8: el Cuaderno vacío decía «Enlaza libros con [[», Buscar «Con «autor:» o «serie:»»
        // y Calibre «la que tiene metadata.db». Ni sintaxis ni nombres de archivo en lo que lees.
        problems += hits(#""[^"]* (con \[\[|«\w+:»|metadata\.(db|opf))"#, in: Self.ui + Self.sources("Packages/LectoraCore/Sources"))
        check(problems, "Sintaxis a la vista: dilo en palabras (SavedShelf.describe, la fecha, NoteMarkdown.plain)")
    }

    /// Regla 7 y SB-1 de la casa: un botón dice qué hace. «Cancelar», «OK», «Listo», «Cerrar»
    /// o «Seguir» a secas no dicen qué pasa al tocarlos; tampoco una ✕ sin nombre.
    func testButtonsSayWhatTheyDo() {
        let vague = "Cancelar|OK|Aceptar|Listo|Hecho|Cerrar|Seguir|Continuar|Atrás|Abrir|Usar|Guardar|Buscar|Empezar|Está bien|Sí|No"
        check(hits(#"(Button|PrimaryButton\(title:|SecondaryButton\(title:|QuietButton\(title:|TextAction\(title:)\(?\s*"(\#(vague))""#, in: Self.ui)
              + hits(#"accessibilityLabel\("Cerrar"\)"#, in: Self.ui),
              "Botón que no dice qué hace: verbo y objeto («Guardar cambios», «Cerrar la consulta»)")
        check(hits(#"Image\(systemName: "xmark"\)"#, in: Self.screens),
              "✕ armada a mano: usa CloseButton, que se toca en 44 y dice qué cierra")
        // Auditoría de medios (27 nov 2026): borrar una nota y desconectar Readwise no traían su
        // botón para quedarse, y iOS ponía su «Cancelar». Toda pregunta lleva el suyo, con
        // `role: .cancel` y diciendo qué conservas («Conservar la nota», «Seguir conectado»).
        var noStay: [String] = []
        for file in Self.ui {
            for (index, line) in file.lines.enumerated() where line.contains(".question(") || line.contains(".alert(") {
                let rest = file.lines[(index + 1)...].prefix(14)
                let block = rest.prefix { !$0.contains("} message:") && !$0.contains(".question(") && !$0.contains(".alert(") }
                if !block.joined().contains("role: .cancel") {
                    noStay.append("\(file.path):\(index + 1): \(line.trimmingCharacters(in: .whitespaces).prefix(100))")
                }
            }
        }
        check(noStay, "Pregunta sin botón para quedarse: agrega Button(\"Conservar…\", role: .cancel)")
        // Auditoría 8: «¿Ordenar tu biblioteca como Calibre?» y «¿Mantener los datos de N libros?»
        // salían como globo (iOS 26 cuelga `confirmationDialog` de lo que la abre) y escondían el botón
        // para quedarse. Toda pregunta va con `.question`, un aviso al centro con sus dos botones.
        check(hits(#"\.confirmationDialog\("#, in: Self.ui),
              "Pregunta como globo: usa .question, que deja a la vista el botón para quedarse")
        if !(Self.sources("App/Shared/Design").first { $0.path.hasSuffix("Components.swift") }?.text ?? "")
            .contains("func question<A: View, M: View>(_ title: String, isPresented: Binding<Bool>,") {
            XCTFail("Falta .question en Components.swift")
        }
    }

    /// Regla 7: mientras algo tarda, digo qué estoy haciendo («Buscando portadas…»), no una
    /// ruedita sola. Las pantallas usan LoadingLine.
    func testWaitingSaysWhat() {
        check(hits(#"ProgressView\(\)"#, in: Self.screens), "Ruedita sola: usa LoadingLine(text: \"Buscando…\")")
        // Auditoría 4 (27 nov 2026): con tu biblioteca todavía en iCloud, la Mesa decía «Todavía no hay
        // libros» y ofrecía «Añadir libros» (la Biblioteca ya decía «Bajando tu biblioteca»): te llevaba
        // a importar dos veces. Todo vacío de la biblioteca sale de `LibraryEmptyKind`, que sigue a
        // iCloud: bajando no ofrece añadir; si dejé de esperar, ofrece añadir y volver a la bienvenida.
        var empty = hits(#"EmptyCopy\.(noBooks|stillDownloading)"#, in: Self.screens)
            .map { "\($0) — usa LibraryEmptyState o MacEmptyState(library:)" }
        empty += hits(#"actionTitle: LibraryAction\.addBooks"#, in: Self.screens).map { "\($0) — «Añadir libros» de un vacío sale de LibraryEmptyKind" }
        for name in ["MesaScreen.swift", "LibraryScreen.swift", "MacBookTable.swift"] {
            let text = Self.screens.first { $0.path.hasSuffix(name) }?.text ?? ""
            if !text.contains("LibraryEmptyKind(waitingForCloud:") || !text.contains("cloudGaveUp:") {
                empty.append("\(name): su vacío no sigue a iCloud")
            }
        }
        let kind = Self.piece("LibraryEmptyState")
        if !kind.contains("if kind.offersAdd") || !kind.contains("EmptyCopy.openWelcome") {
            empty.append("LibraryEmptyState: ofrece añadir mientras bajo tu biblioteca o no ofrece volver a la bienvenida")
        }
        let components = Self.sources("App/Shared/Design").first { $0.path.hasSuffix("Components.swift") }?.text ?? ""
        if !components.contains("var offersAdd: Bool { self != .downloading }") {
            empty.append("LibraryEmptyKind: bajando de iCloud ofrece añadir libros")
        }
        check(empty, "Un vacío de la biblioteca dice lo que pasa con iCloud (regla 7)")
    }

    /// Regla 8 (MX-B, 26 nov 2026): en la Mac cada cosa se nombra una vez. El nombre de la pantalla
    /// va en la barra de la ventana y no se repite en el contenido (la Mesa, el Cuaderno y Buscar
    /// lo decían dos veces); Ajustes se abre con ⌘, y va en pestañas, sin engrane dentro de una pantalla.
    func testMacSaysTheNameOnce() {
        var problems: [String] = []
        for name in ["ScreenHeading", "DeskHeader"] {
            let body = Self.piece(name)
            guard let mac = body.range(of: "#if os(macOS)") else { problems.append("\(name) repite el título en la Mac"); continue }
            let branch = body[mac.upperBound...]
            if name == "ScreenHeading", !(branch.components(separatedBy: "#else").first ?? "").contains(".navigationTitle(title)") {
                problems.append("ScreenHeading no pasa su título a la barra en la Mac")
            }
        }
        // El engrane de Ajustes solo en el iPhone: en la Mac es Gabinete › Ajustes… (⌘,).
        for file in Self.screens {
            var phoneOnly = 0
            for (index, line) in file.lines.enumerated() {
                let code = line.trimmingCharacters(in: .whitespaces)
                if code.hasPrefix("#if") { if phoneOnly > 0 || code == "#if os(iOS)" { phoneOnly += 1 }; continue }
                if code.hasPrefix("#endif"), phoneOnly > 0 { phoneOnly -= 1; continue }
                if phoneOnly == 0, line.contains("\"gearshape\"") { problems.append("\(file.path):\(index + 1): engrane también en la Mac") }
            }
        }
        // 27 nov 2026: con el Diario abierto desde la Mesa, la barra seguía diciendo «Mesa»: la ventana
        // le ponía el nombre por fuera a su navegación. Cada pantalla lo pone por dentro.
        problems += hits(#"(MesaScreen|NotebookScreen|SearchScreen)\(\)\s*\.navigationTitle"#, in: Self.screens)
            .map { "\($0) — el nombre por fuera tapa el de lo que se abre dentro" }
        let settings = Self.screens.first { $0.path.hasSuffix("SettingsScreen.swift") }?.text ?? ""
        if !settings.contains("TabView(") { problems.append("SettingsScreen: en la Mac, Ajustes va en pestañas") }
        check(problems, "En la Mac el nombre va una vez, en la barra de la ventana (regla 8)")
    }

    /// Regla 8: lo mismo se llama igual en el iPhone y la Mac. Los nombres viven en
    /// LectoraCore (ReadingState, LibraryAction, SelectionAction, BookFields), no en cada pantalla.
    func testSameWordsOnBothPlatforms() {
        check(hits(#"(?<!back: )"(Seguir leyendo|Empezar a leer|Leer otra vez|Importar libros|Añadir libros?|Buscar datos|En curso|Sin empezar|Leídos|Por leer|Valores distintos|Varios|Sin título|Subrayar|Consultar|A una nota)…?""#, in: Self.ui),
              "Nombre escrito a mano: sale de ReadingState, LibraryAction, SelectionAction, BookFields o MetadataCleaner")
        let mac = Self.ui.filter { $0.path.hasPrefix("App/Shared/Mac/") }.map(\.text).joined()
        let phone = Self.ui.filter { $0.path.hasPrefix("App/Shared/Screens/") || $0.path.hasPrefix("App/Shared/Model/") }.map(\.text).joined()
        let reader = Self.ui.filter { $0.path.hasPrefix("App/Shared/Reader/") }
        var missing: [String] = []
        for name in ["ReadingState", "LibraryAction.addBooks", "LibraryAction.findData", "BookFields", "BookSection", "StatusPicker", "LanguagePicker",
                     "SearchWording.title", "Duplicates.title", "BookFields.languageName"] {
            if !mac.contains(name) { missing.append("La Mac no usa \(name)") }
            if !phone.contains(name) { missing.append("El iPhone no usa \(name)") }
        }
        for file in ["ReaderView.swift", "ReaderController.swift"] where !(reader.first { $0.path.hasSuffix(file) }?.text.contains("SelectionAction") ?? false) {
            missing.append("\(file) no usa SelectionAction")
        }
        check(missing, "Una plataforma nombra a su manera")
        // UX-3c y UX-4f (26 nov 2026): la ficha decía «es» en vez de «Español», y Buscar se llamaba
        // «Buscar», «Buscar en todo» y «Busca…» según dónde. Idiomas por BookFields.languageName;
        // Buscar por SearchWording; «Posibles duplicados» por Duplicates.
        check(hits(#"localizedString\(forLanguageCode|"(Buscar en todo|Buscar en el libro|Posibles duplicados|Posible duplicado)""#, in: Self.ui) +
              hits(#"navigationTitle\("Buscar"\)|Label\("Buscar","#, in: Self.ui),
              "Idioma, Buscar o duplicados nombrados a mano: usa BookFields.languageName, SearchWording o Duplicates")
        // Auditoría 2 (27 nov 2026): la bienvenida decía «Archivos › En mi iPhone» también en la Mac y
        // el iPad, y la carpeta local era «En este iPhone» en el iPad. El dispositivo sale de
        // DeviceKind (su nombre, su dibujo y dónde queda la carpeta); un texto que nombra el iPhone
        // a mano solo vale si habla de los dos («tu iPhone y tu Mac»).
        check(hits(#"systemImage: "(iphone|ipad|laptopcomputer|desktopcomputer)"|"[^"]*\b(este|mi) (iPhone|iPad)\b[^"]*"|"[^"]*esta Mac[^"]*""#, in: Self.ui) +
              hits(#""(?![^"]*Mac)[^"]*iPhone[^"]*""#, in: Self.ui),
              "Dispositivo nombrado a mano: usa DeviceKind.current (here, symbol, localFolder, files)")
        check(hits(#"\.day\(\)\.month\(\.abbreviated\)"#, in: Self.ui.filter { !$0.path.hasSuffix("Design/Components.swift") }),
              "Fecha corta armada a mano: usa fecha.esShort («3 oct 2024») o fecha.esDayMonth")
    }
}
