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
    func testNoPromisesOfFutureFeatures() {
        check(hits(#"(?i)"[^"]*\b(pronto|próximamente|coming soon)\b[^"]*""#, in: Self.sources("App")),
              "Texto que promete algo que no hace: escóndelo hasta que funcione")
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

        // 2. Los títulos de pantalla crecen con la letra de iOS, y toda letra propia también.
        let theme = Self.sources("App/Shared/Design").first { $0.path.hasSuffix("Theme.swift") }!
        var titles = theme.lines.filter { $0.contains("Font.custom(") && !$0.contains("relativeTo:") }
        if !(pieces.first { $0.name == "ScreenTitleFont" }?.body.contains("@ScaledMetric") ?? false) { titles.append("ScreenTitleFont sin @ScaledMetric") }
        if !theme.text.contains("UIFontMetrics(forTextStyle: .largeTitle).scaledFont") { titles.append("UIFont.screenTitle no crece") }
        titles += hits(#"\.font\(\.screenTitle\("#, in: Self.ui).filter { !$0.contains("screenTitle(size)") }
        check(titles, "Letra que no crece con el tamaño de texto de iOS (relativeTo:, @ScaledMetric o .screenTitleFont())")

        // 3. Lo que va lado a lado se apila con la letra grande, y los nombres no se cortan en un renglón.
        let adaptive = ["ScreenHeading", "DeskHeader", "CountLine", "FieldRow", "LinkRow", "SegmentedChoice", "PageSwatchPicker"]
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
        //    AccentIconButton, y toda pieza con un botón usa una medida de 44 (o es grande de por sí).
        var touch: [String] = []
        for file in Self.screens {
            var depth = 0
            for (index, line) in file.lines.enumerated() {
                if depth == 0, line.contains("ScreenHeading(title:"), line.hasSuffix("{") { depth = 1; continue }
                guard depth > 0 else { continue }
                if line.contains("Button"), !line.contains("IconButton(") { touch.append("\(file.path):\(index + 1): \(line.trimmingCharacters(in: .whitespaces))") }
                depth += line.filter { $0 == "{" }.count - line.filter { $0 == "}" }.count
            }
        }
        let bigByNature: Set = ["PageSwatchPicker", "CoverChoiceCell", "SaveShelfAlert", "RenameShelfAlert", "DeleteShelfConfirmation"]
        let measure = #"tapTarget|sizeTarget|accentButton|scrubberReach|Size\.control|Size\.row|IconTile|PrimaryButton|TextAction|CloseButton|roundInGlass"#
        for piece in pieces where !bigByNature.contains(piece.name) {
            let touches = piece.body.range(of: #"Button\s*[({]|\.onTapGesture|\.gesture\(|Menu \{"#, options: .regularExpression) != nil
            if touches && piece.body.range(of: measure, options: .regularExpression) == nil { touch.append("\(piece.name): se toca sin medir 44") }
        }
        let index = pieces.first { $0.name == "LetterIndex" }?.body ?? ""
        if !index.contains("tapTarget") { touch.append("LetterIndex: cada letra se toca en menos de 44") }
        if index.contains("Theme.accent") { touch.append("LetterIndex en verde: es una acción, va en tinta (regla 1)") }
        check(touch, "Algo se toca en menos de 44 × 44 (SB-4)")

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

        // 9. UX-1a: el primer renglón del libro quedaba bajo los botones de arriba. El aire de
        //    arriba alcanza para el botón entero (`tapTarget` − `chromeLift`).
        let theme9 = Self.sources("App/Shared/Design").first { $0.path.hasSuffix("Theme.swift") }!.text
        func value(_ name: String) -> Double {
            guard let range = theme9.range(of: #"static let \#(name): CGFloat = [0-9.]+"#, options: .regularExpression) else { return 0 }
            return Double(theme9[range].split(separator: " ").last ?? "") ?? 0
        }
        XCTAssertGreaterThanOrEqual(value("pageMarginTop"), value("tapTarget") - value("chromeLift"),
                                    "Reader.pageMarginTop: los botones de arriba tapan el primer renglón")
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
        let margins = ["chromeInset", "chromeLift", "textMargin", "pageMarginTop", "pageMarginBottom", "folioFadeDrop", "topFade", "slitPadding"]
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
        let titles = hits(#"(errorAlert|noticeAlert|\.alert|confirmationDialog)\("(Aviso|Nota|Error|Atención|Importación|[^" ]+|[^" ]+ [^" ]+)""#, in: Self.ui)
        check(titles, "Aviso cuyo título no dice qué pasó (tres palabras o más, nunca «Aviso» ni «Nota»)")
        check(hits(#""[^"]*(No se pud|No se pued|Se guardó|Se juntó|Se completaron)"#, in: Self.ui) +
              hits(#""[^"]*(No se pud|No se pued)"#, in: Self.sources("Packages/LectoraCore/Sources")),
              "Voz impersonal: di qué hice yo («No pude guardar», «Junté»)")
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
    }

    /// Regla 7: mientras algo tarda, digo qué estoy haciendo («Buscando portadas…»), no una
    /// ruedita sola. Las pantallas usan LoadingLine.
    func testWaitingSaysWhat() {
        check(hits(#"ProgressView\(\)"#, in: Self.screens), "Ruedita sola: usa LoadingLine(text: \"Buscando…\")")
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
        check(hits(#"\.day\(\)\.month\(\.abbreviated\)"#, in: Self.ui.filter { !$0.path.hasSuffix("Design/Components.swift") }),
              "Fecha corta armada a mano: usa fecha.esShort («3 oct 2024») o fecha.esDayMonth")
    }
}
