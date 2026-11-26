import Charts
import LectoraCore
import SwiftUI

// Componentes del sistema de diseño. Cada pantalla se arma solo con estos
// componentes y los tokens de `Theme`; ver «Recetas» en docs/sistema-diseno.md.

// MARK: - Pantalla

extension View {
    /// Receta de pantalla raíz: papel de fondo, margen lateral simétrico y sin
    /// barra de navegación (el título va en el contenido con `ScreenHeading`).
    func screen() -> some View {
        self
            .background(Theme.paper.ignoresSafeArea())
            .navigationDestination(for: ShelfBook.self) { BookDetailScreen(book: $0) }
            .navigationDestination(for: SeriesRef.self) { SeriesScreen(series: $0) }
            .navigationDestination(for: ReviewInboxRef.self) { _ in ReviewScreen() }
            .navigationDestination(for: CandidatesRef.self) { CandidatesScreen(bookID: $0.bookID, searchesFirst: $0.searchesFirst) }
            .navigationDestination(for: FilledRef.self) { FilledScreen(bookID: $0.bookID) }
            .navigationDestination(for: NoteRef.self) { NoteScreen(ref: $0) }
            .navigationDestination(for: DiaryRef.self) { _ in DiaryScreen() }
            .navigationDestination(for: SessionRef.self) { SessionScreen(ref: $0) }
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
    }

    /// Margen lateral de pantalla, igual a ambos lados.
    func gutter() -> some View {
        padding(.horizontal, Theme.Space.gutter)
    }

    /// Receta de formulario (Ajustes, Conexiones, Reglas, Editar datos): el mismo papel
    /// que el resto de la app, no el gris frío del sistema. Sus botones y interruptores
    /// en verde hoja: con la marca (casi negra en claro) parecían texto fijo.
    func formScreen() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Theme.paper.ignoresSafeArea())
            .tint(Theme.accent)
    }

    /// Receta de pantalla empujada u hoja (ficha, serie, nota, Lector › herramientas…):
    /// papel de fondo, título en línea y controles del contenido en `accent`. Los botones
    /// de la barra de vidrio («Listo», «Cancelar», «Editar») van en tinta, como en iOS 26;
    /// antes unas hojas los forzaban a verde y otras no (22 nov 2026).
    func pushedScreen(_ title: String = "") -> some View {
        self
            .background(Theme.paper.ignoresSafeArea())
            .inlineTitle(title)
            .tint(Theme.accent)
    }

    /// Título pequeño, centrado en la barra (pantallas empujadas, hojas y formularios).
    func inlineTitle(_ title: String) -> some View {
        self
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
    }

    /// Contenedor de una pantalla con scroll: margen, aire arriba y abajo.
    func screenContent() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(Theme.ink)
            .gutter()
            .padding(.top, Theme.Space.screenTop)
            .padding(.bottom, Theme.Space.screenBottom)
    }
}

/// Título de pantalla en serif, con acciones a la derecha y una línea finísima debajo:
/// la cabecera de una hoja de libreta (SD-3, 26 nov 2026).
struct ScreenHeading<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.screenTitle)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                HStack(spacing: Theme.Space.l) { trailing }
                    .font(.title3)
                    .foregroundStyle(Theme.ink)
                    .buttonStyle(.plain)
            }
            Hairline()
        }
    }
}

extension ScreenHeading where Trailing == EmptyView {
    init(title: String) {
        self.init(title: title) { EmptyView() }
    }
}

// MARK: - Marca

/// «GABINETE» en mayúsculas romanas, centrado arriba de la Mesa.
struct BrandMark: View {
    var alignment: Alignment = .center

    var body: some View {
        Text("GABINETE")
            .font(.brandMark)
            .tracking(Theme.Tracking.brandMark)
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, alignment: alignment)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Encabezado de la Mesa (MT-F, 25 nov 2026): el nombre a la izquierda, la fecha de hoy
/// a la derecha y, debajo, una línea finísima que acaba en un trazo verde. El encabezado
/// de una libreta fina, vuelto pantalla.
struct DeskHeader: View {
    var date = Date()

    /// «MIÉ · 25 NOV».
    private var dateLine: String {
        let day = date.es(.dateTime.weekday(.abbreviated))
        let month = date.es(.dateTime.day().month(.abbreviated))
        return "\(day) · \(month)".replacingOccurrences(of: ".", with: "").uppercased()
    }

    var body: some View {
        VStack(spacing: Theme.Space.s) {
            HStack(alignment: .firstTextBaseline) {
                BrandMark(alignment: .leading)
                CapsText(text: dateLine)
                    .fixedSize()
            }
            Hairline()
                .overlay(alignment: .trailing) {
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: Theme.Size.deskMark.width, height: Theme.Size.deskMark.height)
                }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Rótulo de sección en mayúsculas romanas pequeñas («EN LA MESA»).
struct SectionLabel: View {
    let text: String
    /// Sobre el vidrio del lector va en tinta tenue; en las pantallas, el gris de siempre.
    var tone: Color = Theme.secondaryInk

    var body: some View {
        Text(text.uppercased())
            .font(.sectionLabel)
            .tracking(Theme.Tracking.sectionLabel)
            .foregroundStyle(tone)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Versalitas de interfaz: mayúsculas chicas, espaciadas, con cifras del mismo ancho
/// para que nada baile («32 LIBROS · 32 EN ESTE IPHONE», «MIÉ · 25 NOV»). Toda versalita
/// de la app sale de aquí.
struct CapsText: View {
    let text: String
    var tone: Color = Theme.secondaryInk
    /// Un conteo que puede crecer («Buscando datos en internet…») baja a otro renglón.
    var lines = 1

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.medium))
            .tracking(Theme.Tracking.caps)
            .monospacedDigit()
            .foregroundStyle(tone)
            .lineLimit(lines)
    }
}

/// Rótulo de una sección de libreta: versalitas y una línea finísima hasta la orilla
/// («DONDE LO DEJASTE», «APARIENCIA»). Separa sin cajas.
struct RuledLabel: View {
    let text: String

    var body: some View {
        HStack(spacing: Theme.Space.l) {
            CapsText(text: text)
                .fixedSize()
            Hairline()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Botones

/// Mosaico chico de una acción u opción: ícono arriba (todos del mismo alto) y
/// nombre abajo; elegido, con borde de tinta. Estilo de la hoja y acciones de un subrayado.
struct IconTile<Icon: View>: View {
    let title: String
    var selected = false
    /// La acción principal: en tinta, letras claras («Subrayar»).
    var prominent = false
    @ViewBuilder var icon: Icon

    var body: some View {
        VStack(spacing: Theme.Space.s) {
            icon.frame(height: Theme.Space.xl)
            Text(title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(Theme.Emphasis.labelMinScale)
        }
        .foregroundStyle(prominent ? Theme.onInk : Theme.ink)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.l)
        .background(prominent ? Theme.ink : Theme.field, in: RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous)
                .strokeBorder(selected ? Theme.ink : .clear, lineWidth: Theme.Size.quoteRule)
        }
    }
}

extension IconTile where Icon == AnyView {
    /// El mosaico con un símbolo de SF.
    init(symbol: String, title: String, selected: Bool = false, prominent: Bool = false) {
        self.init(title: title, selected: selected, prominent: prominent) { AnyView(Image(systemName: symbol).font(.body)) }
    }
}

/// Cómo se mueve una hoja que pasa: un resorte sin rebote (amortiguado justo). Sale
/// de quieta sin tirón y, si la soltaste con el dedo, sigue con tu misma velocidad.
/// Lo usan la hoja de verdad (`ReaderPagesController`) y su muestra en «Aa».
enum TurnMotion {
    /// Dónde va (0 → 1) a los `t` segundos, saliendo de quieta.
    static func position(at t: Double, stiffness: Double) -> Double {
        let (x, _) = step(offset: -1, velocity: 0, stiffness: stiffness, dt: t)
        return 1 + x
    }

    /// Un paso del resorte: `offset` es cuánto falta (con signo) y `velocity` en
    /// unidades por segundo. Exacto para cualquier `dt`: no se descompone si un cuadro tarda.
    static func step(offset: Double, velocity: Double, stiffness: Double, dt: Double) -> (Double, Double) {
        let w = stiffness, decay = exp(-w * dt), carry = velocity + w * offset
        return ((offset + carry * dt) * decay, (velocity - w * carry * dt) * decay)
    }

    /// Fundido como relevo: el texto de antes se va en la primera parte…
    static func fadeOut(_ p: Double) -> Double { smooth(p / Theme.Reader.fadeSpan) }
    /// …y el nuevo llega en la última, sin que se lean los dos a la vez.
    static func fadeIn(_ p: Double) -> Double { smooth(1 - (1 - p) / Theme.Reader.fadeSpan) }

    private static func smooth(_ x: Double) -> Double {
        let c = min(max(x, 0), 1)
        return c * c * (3 - 2 * c)
    }
}

/// La esquina de abajo a la derecha de una hoja, doblada por la recta x + y = `line`:
/// lo que queda de la hoja o, con `flap`, la parte doblada (en espejo sobre la recta).
private struct PageCorner: Shape {
    var line: CGFloat
    var flap = false

    func path(in rect: CGRect) -> Path {
        let corners = [CGPoint(x: 0, y: 0), CGPoint(x: rect.width, y: 0),
                       CGPoint(x: rect.width, y: rect.height), CGPoint(x: 0, y: rect.height)]
        // Qué tan adentro de la parte buscada está un punto (recorte de un polígono por una recta).
        func inside(_ point: CGPoint) -> CGFloat { (point.x + point.y - line) * (flap ? 1 : -1) }
        var kept: [CGPoint] = []
        for (index, a) in corners.enumerated() {
            let b = corners[(index + 1) % corners.count]
            let sa = inside(a), sb = inside(b)
            if sa >= 0 { kept.append(a) }
            if (sa >= 0) != (sb >= 0) {
                let t = sa / (sa - sb)
                kept.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
            }
        }
        if flap { kept = kept.map { CGPoint(x: line - $0.y, y: line - $0.x) } }
        var path = Path()
        guard kept.count > 2 else { return path }
        path.addLines(kept.map { CGPoint(x: $0.x + rect.minX, y: $0.y + rect.minY) })
        path.closeSubpath()
        return path
    }
}

/// Una hoja chiquita que pasa con el estilo elegido, en bucle, como en el libro y
/// con la misma curva que la hoja de verdad (`TurnMotion`): la de abajo es la
/// página siguiente (otros renglones, empieza con párrafo) y, al terminar, pasa a
/// ser la de arriba: el bucle nunca salta de regreso.
/// Hoja: la esquina se levanta y se dobla, con revés de papel y su sombra.
/// Deslizar: se va de lado, opaca, y la de abajo sale de la sombra. Fundido: relevo,
/// el texto se va y llega el otro. Solo se mueve la elegida, y empieza en cuanto la eliges.
struct TurnPreview: View {
    let style: ReaderTurnStyle
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let size = Theme.Size.turnPreview
        let moving = active && !reduceMotion
        TimelineView(.animation(paused: !moving)) { timeline in
            let (p, odd) = moving ? progress(at: timeline.date) : (0, false)
            ZStack {
                page(next: !odd, lines: style == .fade ? TurnMotion.fadeIn(p) : Theme.Emphasis.rest)
                    .overlay { if style == .slide { Theme.ink.opacity(Theme.Reader.slideDim * (Theme.Emphasis.rest - p)) } }
                turned(page(next: odd), p, width: size.width)
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.swatch, style: .continuous))
        }
        .frame(width: size.width, height: size.height)
        .accessibilityHidden(true)
    }

    /// La primera vuelta sale casi en cuanto la eliges: no hay que esperar la pausa.
    @State private var start = Date().addingTimeInterval(-Theme.Reader.previewLead)

    /// La vuelta en bucle: quieta, pasa y la de abajo queda arriba. `odd` dice qué
    /// página va arriba en esta vuelta (se turnan).
    private func progress(at date: Date) -> (Double, Bool) {
        let pause = Theme.Reader.previewPause, period = pause + Theme.Reader.previewTurn
        let elapsed = max(date.timeIntervalSince(start), 0)
        let odd = Int(elapsed / period) % 2 == 1
        let t = elapsed.truncatingRemainder(dividingBy: period) - pause
        guard t > 0 else { return (0, odd) }
        if style == .none { return (1, odd) }
        let stiffness = style == .fade ? Theme.Reader.fadeSpring : Theme.Reader.turnSpring
        return (TurnMotion.position(at: t, stiffness: stiffness * Theme.Reader.previewPace), odd)
    }

    @ViewBuilder
    private func turned(_ content: some View, _ p: Double, width: CGFloat) -> some View {
        switch style {
        case .matte:
            // La esquina de abajo se levanta y se dobla hacia el lomo, como al pasar
            // una hoja con el dedo: el revés es papel, más oscuro junto al doblez,
            // y deja su sombra sobre la página de abajo.
            let size = Theme.Size.turnPreview
            let line = (size.width + size.height) * (1 - p)
            let flap = PageCorner(line: line, flap: true)
            content
                .mask { PageCorner(line: line) }
                .overlay {
                    flap.fill(Theme.paper)
                        .overlay {
                            flap.fill(LinearGradient(colors: [.clear, Theme.ink.opacity(Theme.Reader.previewShadow)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                        }
                        .overlay { flap.stroke(Theme.secondaryInk, lineWidth: Theme.Size.hairline) }
                        .shadow(color: Theme.ink.opacity(Theme.Reader.previewShadow), radius: Theme.Size.hairline)
                }
        case .slide:
            // Opaca, como papel: nunca se leen dos textos encimados.
            content.offset(x: -p * width)
                .shadow(color: Theme.ink.opacity(Theme.Reader.previewShadow), radius: Theme.Size.hairline)
        case .fade:
            content.opacity(Theme.Emphasis.rest - TurnMotion.fadeOut(p))
        case .none:
            content.opacity(Theme.Emphasis.rest - p)
        }
    }

    /// Una página con renglones; la siguiente empieza con sangría y termina corta.
    /// `lines`: qué tanto se ven los renglones (en el fundido llegan después del papel).
    private func page(next: Bool, lines: Double = 1) -> some View {
        RoundedRectangle(cornerRadius: Theme.Radius.swatch, style: .continuous)
            .fill(Theme.paper)
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.swatch, style: .continuous)
                    .strokeBorder(Theme.secondaryInk, lineWidth: Theme.Size.hairline)
            }
            .overlay {
                VStack(alignment: .trailing, spacing: 0) {
                    ForEach(0..<Theme.Reader.previewLines, id: \.self) { line in
                        let short = next ? line == 0 : line == Theme.Reader.previewLastLine
                        Capsule().fill(Theme.secondaryInk.opacity(lines))
                            .frame(height: Theme.Size.hairline)
                            .padding(next && line == 0 ? .leading : .trailing, short ? Theme.Space.xs : 0)
                            .frame(maxHeight: .infinity)
                    }
                }
                .padding(Theme.Space.xxs)
            }
            .compositingGroup()
    }
}

/// Dos o más opciones lado a lado, una elegida (fondo de papel sobre el carril).
/// La marca se desliza de una a otra.
struct SegmentedChoice<Option: Hashable & Identifiable, Label: View>: View {
    let options: [Option]
    @Binding var selection: Option
    @ViewBuilder var label: (Option) -> Label
    @Namespace private var mark

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options) { option in
                Button { selection = option } label: {
                    label(option)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(option == selection ? Theme.ink : Theme.secondaryInk)
                        .frame(maxWidth: .infinity, minHeight: Theme.Size.tapTarget)
                        .background {
                            if option == selection {
                                RoundedRectangle(cornerRadius: Theme.Radius.segment, style: .continuous)
                                    .fill(Theme.paper)
                                    .matchedGeometryEffect(id: "marca", in: mark)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(option == selection ? .isSelected : [])
            }
        }
        .padding(Theme.Space.xxs)
        .background(Theme.field, in: RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
        .animation(Theme.Motion.standard, value: selection)
    }
}

/// Respuesta al toque: se hunde un poco, sin cambiar de color.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? Theme.Emphasis.pressedScale : Theme.Emphasis.rest)
            .opacity(configuration.isPressed ? Theme.Emphasis.pressed : Theme.Emphasis.rest)
            .animation(Theme.Motion.press, value: configuration.isPressed)
    }
}

/// Acción principal de una pantalla. Una sola por pantalla.
struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var fillsWidth = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let systemImage {
                    Label(title, systemImage: systemImage)
                } else {
                    Text(title)
                }
            }
            .font(.body.weight(.medium))
            .foregroundStyle(Theme.onAction)
            .padding(.horizontal, Theme.Space.buttonX)
            .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: Theme.Size.control)
            .background(Theme.action, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .strokeBorder(Theme.ink.opacity(Theme.Emphasis.actionEdge), lineWidth: Theme.Size.hairline)
            }
        }
        .buttonStyle(PressableStyle())
    }
}

/// Acento verde y escaso: un ícono de acción («+» de la Biblioteca) en verde, sin fondo. Uno por pantalla como mucho.
struct AccentIconButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: Theme.Size.accentButton, height: Theme.Size.accentButton)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
    }
}

/// Botón redondo secundario (audiolibro junto a «Seguir leyendo»).
struct RoundIconButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Theme.ink)
                .frame(width: Theme.Size.control, height: Theme.Size.control)
                .background(Theme.field, in: Circle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
    }
}

/// Acción de texto en tinta («Todo bien», «Ver los 12 subrayados», «Nota nueva»): las
/// acciones no van en verde (SD-1). Responde en 44 aunque se dibuje chica.
struct TextAction: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.ink)
                .frame(minHeight: Theme.Size.tapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Filtros y pestañas

/// El conteo de una lista en versalitas («32 LIBROS · 32 EN ESTE IPHONE») y, a la
/// derecha, cómo se ordena si se puede elegir.
struct CountLine<Trailing: View>: View {
    let text: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack {
            CapsText(text: text, lines: Theme.Size.countLines)
            Spacer(minLength: Theme.Space.l)
            trailing
        }
        .frame(minHeight: Theme.Size.tapTarget)
    }
}

extension CountLine where Trailing == EmptyView {
    init(text: String) {
        self.init(text: text) { EmptyView() }
    }
}

/// Menú para elegir el orden de una lista, en versalitas de tinta con su flecha.
struct SortMenu<Option: Hashable & Identifiable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String

    var body: some View {
        Menu {
            Picker("Ordenar por", selection: $selection) {
                ForEach(options) { Text(title($0)).tag($0) }
            }
        } label: {
            HStack(spacing: Theme.Space.xs) {
                CapsText(text: title(selection), tone: Theme.ink)
                Image(systemName: "arrow.up.arrow.down")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.ink)
            }
            .frame(minHeight: Theme.Size.tapTarget)
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .accessibilityLabel("Ordenar: \(title(selection))")
    }
}

/// Filtros en texto (SD-3, 26 nov 2026): la elegida en tinta con un trazo verde debajo,
/// las demás en gris; sin píldoras. Filtros de la Biblioteca y partes del Cuaderno.
struct FilterBar<Item: Hashable & Identifiable>: View {
    let items: [Item]
    @Binding var selection: Item
    let title: (Item) -> String
    @Namespace private var mark

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Space.xl) {
                ForEach(items) { item in
                    let selected = item == selection
                    Button { withAnimation(Theme.Motion.select) { selection = item } } label: {
                        Text(title(item))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(selected ? Theme.ink : Theme.secondaryInk)
                            .frame(minHeight: Theme.Size.tapTarget)
                            .overlay(alignment: .bottomLeading) {
                                if selected {
                                    Capsule()
                                        .fill(Theme.accent)
                                        .frame(width: Theme.Size.tabMark.width, height: Theme.Size.tabMark.height)
                                        .matchedGeometryEffect(id: "trazo", in: mark)
                                }
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            // El texto de la primera opción queda en el margen.
            .padding(.horizontal, Theme.Space.gutter)
        }
        .padding(.horizontal, -Theme.Space.gutter)
    }
}

// MARK: - Libros

/// Portada del libro: imagen real o portada tipográfica, con nube si no está descargado.
struct ShelfCover: View {
    let book: ShelfBook
    var showsRibbon = false

    var body: some View {
        CoverView(title: book.title, author: book.author, style: book.cover, showsRibbon: showsRibbon, image: book.coverImage)
            .overlay(alignment: .bottomTrailing) {
                if book.inCloudOnly {
                    Image(systemName: "icloud")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .padding(Theme.Space.xs)
                        .background(.regularMaterial, in: Circle())
                        .padding(Theme.Space.xs)
                        .accessibilityLabel("En iCloud")
                }
            }
    }
}

/// Una serie se ve como una pila de portadas.
struct SeriesStack: View {
    let book: ShelfBook

    var body: some View {
        ShelfCover(book: book)
            .background {
                ZStack {
                    CoverView(title: "", author: "", style: book.cover).brightness(-0.1)
                        .offset(x: Theme.Space.s, y: -Theme.Space.s)
                    CoverView(title: "", author: "", style: book.cover).brightness(-0.05)
                        .offset(x: Theme.Space.xs, y: -Theme.Space.xs)
                }
                .accessibilityHidden(true)
            }
            .padding(.top, Theme.Space.s)
            .padding(.trailing, Theme.Space.s)
    }
}

/// Celda de la cuadrícula de portadas (o pila, si representa una serie).
struct CoverCell: View {
    let book: ShelfBook
    /// Texto bajo la portada; por omisión, el título.
    var caption: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            if let count = book.seriesCount, count > 1 {
                SeriesStack(book: book)
            } else {
                ShelfCover(book: book)
            }
            VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                Text(caption ?? (book.seriesCount != nil ? (book.series ?? book.title) : book.title))
                    .font(.caption)
                    .foregroundStyle(caption == nil ? Theme.ink : Theme.secondaryInk)
                    .lineLimit(caption == nil ? 2 : 1)
                    .multilineTextAlignment(.leading)
                if let count = book.seriesCount, count > 1 {
                    Text("Serie · \(count) libros")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryInk)
                }
            }
        }
    }
}

/// Cuadrícula de portadas con el espaciado del sistema.
struct CoverGrid<Content: View>: View {
    @ViewBuilder var content: Content
    private let columns = Array(repeating: GridItem(.flexible(), spacing: Theme.Space.l, alignment: .top),
                                count: Theme.Size.gridColumns)

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: Theme.Space.xl) { content }
    }
}

/// Fila de libro: portada pequeña, título en serif, detalle y estado. Se usa en
/// la lista de la Biblioteca, en una serie, en Buscar y en el Cuaderno.
struct BookRow<Trailing: View>: View {
    let book: ShelfBook
    var detail: String? = nil
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: Theme.Space.rowGap) {
            CoverView(title: book.title, author: book.author, style: book.cover, image: book.coverImage)
                .frame(width: Theme.Size.coverRow)
            VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                Text(book.title)
                    .font(.rowTitle)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(detail ?? book.caption)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryInk)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            trailing
                .font(.footnote)
                .foregroundStyle(Theme.secondaryInk)
        }
        .padding(.vertical, Theme.Space.rowY)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { Hairline() }
    }
}

extension BookRow where Trailing == EmptyView {
    init(book: ShelfBook, detail: String? = nil) {
        self.init(book: book, detail: detail) { EmptyView() }
    }
}

/// Barra de progreso fina.
struct ThinProgress: View {
    let value: Double
    var height: CGFloat = Theme.Size.progress

    var body: some View {
        Capsule()
            .fill(Theme.track)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(Theme.brand)
                        .frame(width: proxy.size.width * min(max(value, 0), 1))
                }
            }
            .frame(height: height)
            .accessibilityElement()
            .accessibilityLabel("Progreso")
            .accessibilityValue(Text((value).percentText))
    }
}

// MARK: - Texto

/// Cita con la raya de lápiz: «Donde lo dejaste» y los subrayados del Cuaderno.
struct QuoteBlock: View {
    var label: String? = nil
    let text: String
    var note: String? = nil
    var italic = false
    /// Lo que se buscó: va en verde y negritas dentro de la cita.
    var match: String? = nil
    /// Tipográfica (Mesa, ME-2): sin raya; el rótulo en versalitas con una línea fina
    /// hasta la orilla y la comilla de apertura colgada fuera del texto, en verde.
    var hanging = false

    var body: some View {
        if hanging { hangingBody } else { ruledBody }
    }

    private var hangingBody: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            if let label {
                RuledLabel(text: label)
            }
            Text(Found.marked("\(text)»", match))
                .font(.quote)
                .lineSpacing(Theme.Space.xs)
                .foregroundStyle(Theme.ink)
                .overlay(alignment: .topLeading) {
                    Text("«")
                        .font(.quote)
                        .foregroundStyle(Theme.accent)
                        .alignmentGuide(.leading) { $0[.trailing] }
                        .accessibilityHidden(true)
                }
        }
    }

    private var ruledBody: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            if let label {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryInk)
            }
            Text(Found.marked(italic ? "«\(text)»" : text, match))
                .font(italic ? .quote : .rowTitle)
                .lineSpacing(Theme.Space.xs)
            if let note {
                Label(note, systemImage: "pencil")
                    .font(.subheadline)
                    .foregroundStyle(Theme.accent)
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(.leading, Theme.Space.rowGap)
        .overlay(alignment: .leading) {
            Rectangle().fill(Theme.accent).frame(width: Theme.Size.quoteRule)
        }
    }
}

/// Dato del libro en una fila: etiqueta a la izquierda, valor a la derecha.
struct FactRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(Theme.secondaryInk)
            Spacer(minLength: Theme.Space.l)
            Text(value).multilineTextAlignment(.trailing).monospacedDigit()
        }
        .font(.subheadline)
        .foregroundStyle(Theme.ink)
        .padding(.vertical, Theme.Space.rowY)
        .overlay(alignment: .bottom) { Hairline() }
    }
}

/// Separador de medio punto.
struct Hairline: View {
    var body: some View {
        Rectangle().fill(Theme.track).frame(height: Theme.Size.hairline)
    }
}

/// Estado vacío: título, explicación y, si aplica, la acción para salir de él.
struct EmptyState: View {
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            RuledLabel(text: title)
            Text(message)
                .font(.body)
                .foregroundStyle(Theme.secondaryInk)
            if let actionTitle, let action {
                PrimaryButton(title: actionTitle, systemImage: "plus", action: action)
                    .padding(.top, Theme.Space.s)
            }
        }
        .foregroundStyle(Theme.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Theme.Space.xxxl)
    }
}

/// Índice A–Z al costado de una lista larga.
struct LetterIndex: View {
    let onSelect: (String) -> Void
    private let letters = "ABCDEFGHIJKLMNÑOPQRSTUVWXYZ".map(String.init)

    var body: some View {
        VStack(spacing: Theme.Space.hair) {
            ForEach(letters, id: \.self) { letter in
                Button(letter) { onSelect(letter) }
                    .font(.caption2.weight(.semibold)) // ds-exception: índice A–Z
                    .foregroundStyle(Theme.accent)
                    .frame(width: Theme.Size.letterIndex)
            }
        }
        .buttonStyle(.plain)
        .padding(.trailing, Theme.Space.xs)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Índice alfabético")
    }
}

extension String {
    /// Primera letra sin acentos, en mayúscula; la Ñ se respeta.
    var firstLetter: String {
        guard let first else { return "" }
        let letter = String(first).uppercased()
        return letter == "Ñ" ? letter : letter.folding(options: .diacriticInsensitive, locale: nil)
    }
}

// MARK: - Acciones secundarias y filas de navegación

/// Acción secundaria, a lo ancho, sobre `field`.
struct SecondaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let systemImage { Label(title, systemImage: systemImage) } else { Text(title) }
            }
            .font(.body.weight(.medium))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, minHeight: Theme.Size.control)
            .background(Theme.field, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }
}

/// Salida discreta: solo texto en tinta secundaria, centrado. Para «seguir sin
/// hacer nada» bajo opciones que sí importan, sin competir con ellas.
struct QuietButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryInk)
                .frame(maxWidth: .infinity, minHeight: Theme.Size.control)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }
}

/// Fila que lleva a otra pantalla o hace algo: título, valor y flecha, con una línea
/// finísima debajo (SD, 26 nov 2026). Con `marked`, un punto verde avisa que hay algo
/// pendiente; con `status`, un punto dice si está conectado (lleno) o no (hueco).
struct LinkRow: View {
    let title: String
    var value: String? = nil
    var marked = false
    var status: Bool? = nil
    var chevron = true

    var body: some View {
        HStack(spacing: Theme.Space.s) {
            if marked {
                StatusDot(on: true)
            }
            Text(title).foregroundStyle(Theme.ink)
            Spacer(minLength: Theme.Space.l)
            if let status { StatusDot(on: status) }
            if let value { Text(value).foregroundStyle(Theme.secondaryInk).monospacedDigit().lineLimit(1) }
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.tertiaryInk)
            }
        }
        .font(.body)
        .frame(minHeight: Theme.Size.row)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { Hairline() }
    }
}

/// Punto de estado: lleno en verde (conectado, pendiente) o hueco en gris.
struct StatusDot: View {
    let on: Bool

    var body: some View {
        Circle()
            .strokeBorder(on ? Theme.accent : Theme.secondaryInk, lineWidth: Theme.Size.statusDotLine)
            .background(Circle().fill(on ? Theme.accent : .clear))
            .frame(width: Theme.Size.statusDot, height: Theme.Size.statusDot)
            .accessibilityHidden(true)
    }
}

/// Sección de una hoja de libreta (Ajustes, AJ-B): su rótulo con línea y, debajo, sus filas.
/// Sin tarjetas: separa el aire y la línea.
struct RuledSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RuledLabel(text: title)
                .padding(.bottom, Theme.Space.xs)
            content
        }
        .padding(.top, Theme.Space.xxl)
    }
}

/// Campo de texto en una fila de libreta: el nombre a la izquierda y lo escrito a la derecha.
struct FieldRow: View {
    let title: String
    let prompt: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: Theme.Space.l) {
            Text(title).foregroundStyle(Theme.ink).fixedSize()
            TextField(prompt, text: $text)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(Theme.secondaryInk)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
        }
        .font(.body)
        .frame(minHeight: Theme.Size.row)
        .overlay(alignment: .bottom) { Hairline() }
    }
}

/// Interruptor en una fila de libreta, con el verde del sistema.
struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(title, isOn: $isOn)
            .font(.body)
            .foregroundStyle(Theme.ink)
            .tint(Theme.accent)
            .frame(minHeight: Theme.Size.row)
            .overlay(alignment: .bottom) { Hairline() }
    }
}

/// Ayuda bajo una sección: una línea. Lo largo va detrás de «Más» (AJ-2).
struct HelpText: View {
    let text: String
    var more: String? = nil
    @State private var expanded = false

    var body: some View {
        Group {
            if let more {
                // «Más» va pegado al final de la línea; toda la ayuda se toca para abrirla.
                Button { withAnimation(Theme.Motion.standard) { expanded.toggle() } } label: {
                    (Text(expanded ? "\(text) \(more)" : text)
                        + Text(expanded ? "" : " Más").foregroundStyle(Theme.ink))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, minHeight: Theme.Size.tapTarget, alignment: .topLeading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(expanded ? "" : "Muestra más sobre esto")
            } else {
                Text(text)
            }
        }
        .font(.footnote)
        .foregroundStyle(Theme.secondaryInk)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Theme.Space.s)
    }
}

/// Elegir entre hojas de muestra que se ven como el resultado (Apariencia, AJ-1):
/// papel claro, papel oscuro o las dos mitades. La elegida lleva un filo verde.
struct PageSwatchPicker<Option: Hashable & Identifiable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String
    let tone: (Option) -> PageTone

    var body: some View {
        HStack(spacing: Theme.Space.l) {
            ForEach(options) { option in
                let selected = option == selection
                Button { withAnimation(Theme.Motion.select) { selection = option } } label: {
                    VStack(spacing: Theme.Space.s) {
                        page(tone(option))
                            .frame(height: Theme.Size.pageSwatch)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                                    .strokeBorder(selected ? Theme.accent : Theme.track,
                                                  lineWidth: selected ? Theme.Size.selection : Theme.Size.hairline)
                            }
                        Text(title(option))
                            .font(.subheadline.weight(selected ? .semibold : .regular))
                            .foregroundStyle(selected ? Theme.ink : Theme.secondaryInk)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(title(option))
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private func page(_ tone: PageTone) -> some View {
        ZStack {
            switch tone {
            case .light: PaperSample(dark: false)
            case .dark: PaperSample(dark: true)
            case .both:
                PaperSample(dark: false)
                PaperSample(dark: true).mask(DiagonalHalf())
            }
        }
    }
}

/// Qué papel enseña una hojita de muestra: el claro, el oscuro o las dos mitades.
enum PageTone { case light, dark, both }

/// Una hojita de papel con tres renglones, en el papel claro o el oscuro sin importar el modo.
private struct PaperSample: View {
    let dark: Bool

    var body: some View {
        let scheme: ColorScheme = dark ? .dark : .light
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            ForEach(Theme.Size.swatchLines, id: \.self) { length in
                GeometryReader { proxy in
                    Capsule().fill(Theme.secondaryInk).frame(width: proxy.size.width * length)
                }
                .frame(height: Theme.Size.swatchLine)
            }
        }
        .padding(.horizontal, Theme.Space.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.paper)
        .environment(\.colorScheme, scheme)
    }
}

/// La mitad de abajo a la derecha, partida en diagonal.
private struct DiagonalHalf: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

/// El colofón al final de Ajustes (AJ-3): la firma, una línea corta y la versión.
struct Colophon: View {
    let version: String

    var body: some View {
        VStack(spacing: Theme.Space.l) {
            BrandMark()
            Hairline().frame(width: Theme.Space.xxxl)
            VStack(spacing: Theme.Space.xs) {
                CapsText(text: "Versión \(version)")
                CapsText(text: "Tus libros viven en tu carpeta")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.xxxl)
        .accessibilityElement(children: .combine)
    }
}

/// La cinta del marcador colgando de la esquina de la hoja, en verde (lo tuyo).
struct BookmarkRibbon: View {
    var body: some View {
        Ribbon()
            .fill(Theme.accent)
            .frame(width: Theme.Size.ribbon.width, height: Theme.Size.ribbon.height)
    }
}

/// El ícono del marcador en su área de toque: relleno y en verde si la página está marcada.
struct BookmarkGlyph: View {
    let on: Bool

    var body: some View {
        Image(systemName: on ? "bookmark.fill" : "bookmark")
            .font(.body.weight(.semibold))
            .foregroundStyle(on ? Theme.accent : Theme.ink)
            .frame(width: Theme.Size.tapTarget, height: Theme.Size.tapTarget)
            .contentTransition(.symbolEffect(.replace))
    }
}

/// Estrellas de una valoración: lo tuyo, en verde. Tocar la misma estrella la quita.
struct RatingPicker: View {
    @Binding var rating: Double?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(1...5, id: \.self) { star in
                Button {
                    rating = rating == Double(star) ? nil : Double(star)
                } label: {
                    Image(systemName: Double(star) <= (rating ?? 0) ? "star.fill" : "star")
                        .foregroundStyle(Theme.accent)
                        .frame(width: Theme.Size.tapTarget, height: Theme.Size.tapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("\(star) estrellas")
            }
        }
    }
}

/// Un libro encontrado en internet: portada, título, autor, año y editorial,
/// y en palabras qué tan probable es que sea el tuyo y por qué.
struct CandidateRow: View {
    let candidate: MetadataCandidate

    private var verdictLine: Text {
        let sure = candidate.confidence >= MetadataMatcher.autoApplyThreshold
        let verdict = Text(candidate.verdict).foregroundStyle(sure ? Theme.ink : Theme.secondaryInk)
        guard !candidate.reasons.isEmpty else { return verdict }
        return verdict + Text(" · \(candidate.reasons)").foregroundStyle(Theme.tertiaryInk)
    }

    private var detail: String {
        [candidate.authors.first, candidate.published.map { String($0.prefix(4)) }, candidate.publisher]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Space.rowGap) {
            CandidateCover(candidate: candidate, width: Theme.Size.coverRow)
            VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                Text(candidate.title)
                    .font(.rowTitle)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                if !detail.isEmpty {
                    Text(detail).font(.footnote).foregroundStyle(Theme.secondaryInk).lineLimit(2)
                }
                verdictLine.font(.caption)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.tertiaryInk)
        }
        .padding(.vertical, Theme.Space.rowY)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { Hairline() }
        .accessibilityElement(children: .combine)
    }
}

/// Portada de un candidato (de internet) con la tipográfica mientras carga o si no hay.
struct CandidateCover: View {
    let candidate: MetadataCandidate
    let width: CGFloat

    var body: some View {
        AsyncImage(url: candidate.coverURL) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            CoverView(title: candidate.title, author: candidate.authors.first ?? "",
                      style: .generated(for: candidate.title))
        }
        .frame(width: width, height: width / Theme.Size.coverAspect)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.cover, style: .continuous))
    }
}

/// Dato propuesto frente al que tienes: el nuevo a la derecha y, si cambia,
/// el tuyo debajo («Antes: …»). Para la vista previa de un candidato.
struct CompareRow: View {
    let label: String
    let new: String?
    let old: String?
    /// Con acción, un botón «Deshacer» bajo el valor (revisión de lo completado).
    var undo: (() -> Void)? = nil

    private var shown: String {
        if let new, !new.isEmpty { return new }
        return old ?? "—"
    }

    private var changes: Bool {
        guard let new, !new.isEmpty else { return false }
        return new.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            != (old ?? "").folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(Theme.secondaryInk)
            Spacer(minLength: Theme.Space.l)
            VStack(alignment: .trailing, spacing: Theme.Space.xxs) {
                Text(shown)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(Theme.ink)
                if changes, let old, !old.isEmpty {
                    Text("Antes: \(old)")
                        .font(.caption)
                        .foregroundStyle(Theme.tertiaryInk)
                        .multilineTextAlignment(.trailing)
                } else if changes {
                    Text("Nuevo").font(.caption).foregroundStyle(Theme.accent)
                }
                if let undo {
                    Button("Deshacer", action: undo)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.accent)
                        .buttonStyle(.plain)
                        .frame(minHeight: Theme.Size.tapTarget)
                }
            }
        }
        .font(.subheadline)
        .padding(.vertical, Theme.Space.rowY)
        .overlay(alignment: .bottom) { Hairline() }
    }
}

/// Portadas para elegir, en una fila que se desliza: la actual (si hay) y las
/// de internet. La elegida lleva un borde de tinta.
struct CoverChoiceRow: View {
    enum Option: Hashable {
        case current(URL)
        case remote(URL)
    }

    let options: [Option]
    @Binding var selection: Option?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: Theme.Space.l) {
                ForEach(options, id: \.self) { option in
                    CoverChoiceCell(option: option, selection: $selection)
                }
            }
            .padding(.vertical, Theme.Space.xs)
        }
    }
}

/// Una portada para elegir (en `CoverChoiceRow` o en una `CoverGrid`).
struct CoverChoiceCell: View {
    let option: CoverChoiceRow.Option
    @Binding var selection: CoverChoiceRow.Option?
    var width: CGFloat = Theme.Size.coverEditor

    private var selected: Bool { selection == option }

    var body: some View {
        Button { selection = option } label: {
            VStack(spacing: Theme.Space.xs) {
                image
                    .frame(width: width, height: width / Theme.Size.coverAspect)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.cover, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.Radius.cover, style: .continuous)
                            .stroke(selected ? Theme.ink : .clear, lineWidth: Theme.Size.selection)
                    }
                Text(label)
                    .font(.caption)
                    .foregroundStyle(selected ? Theme.ink : Theme.tertiaryInk)
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder private var image: some View {
        switch option {
        case .current(let url):
            if let picture = CoverImaging.image(at: url) {
                Image(decorative: picture, scale: 1).resizable().scaledToFill()
            } else {
                Theme.field
            }
        case .remote(let url):
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Theme.field.overlay { ProgressView() }
            }
        }
    }

    private var label: String {
        if case .current = option { return "La actual" }
        return "Internet"
    }
}

// MARK: - Notas

/// Fila de nota en el Cuaderno y en la ficha: título en serif, las primeras
/// líneas y, abajo, la fecha y los libros que enlaza (en verde).
struct NoteRow: View {
    let note: Note
    /// Detalle en lugar de los libros enlazados («1 cita»).
    var detail: String? = nil
    /// Al buscar: el pasaje de la nota donde aparece, con lo buscado en verde.
    var match: String? = nil

    private var preview: String {
        guard let match, !note.title.localizedStandardContains(match) else { return note.preview }
        return Found.excerpt(note.text, around: match) ?? note.preview
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xxs) {
            Text(Found.marked(note.title, match))
                .font(.rowTitle)
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            if !preview.isEmpty {
                Text(Found.marked(preview, match))
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
                    .lineLimit(2)
            }
            meta
                .font(.caption.weight(.medium))
                .tracking(Theme.Tracking.caps)
                .monospacedDigit()
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Theme.Space.l)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { Hairline() }
    }

    private var meta: Text {
        let date = Text(NoteRow.day(note.modifiedAt).uppercased()).foregroundStyle(Theme.secondaryInk)
        if let detail {
            return date + Text(" · \(detail)".uppercased()).foregroundStyle(Theme.secondaryInk)
        }
        let links = note.bookLinks
        guard !links.isEmpty else { return date }
        return date + Text(" · ").foregroundStyle(Theme.secondaryInk)
            + Text(links.joined(separator: " · ").uppercased()).foregroundStyle(Theme.accent)
    }

    /// «Hoy», «Ayer» o «3 nov».
    static func day(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Hoy" }
        if calendar.isDateInYesterday(date) { return "Ayer" }
        return date.es(.dateTime.day().month(.abbreviated))
    }
}

/// Una nota leída: el título grande, párrafos en serif y citas con la raya
/// verde. Los `[[Libro]]` y «ir al pasaje» son enlaces (los abre `openURL`).
struct NoteBody: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            ForEach(Array(NoteMarkdown.blocks(text).enumerated()), id: \.offset) { index, block in
                switch block {
                case .heading(let title):
                    Text(title)
                        .font(index == 0 ? Font.bookTitle : Font.rowTitle.weight(.semibold))
                        .padding(.bottom, index == 0 ? Theme.Space.xs : 0)
                case .paragraph(let paragraph):
                    Text(Self.inline(paragraph))
                        .font(.prose)
                        .lineSpacing(Theme.Space.xs)
                case .quote(let quote):
                    quoteView(quote)
                }
            }
        }
        .foregroundStyle(Theme.ink)
        .tint(Theme.accent)
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    /// La cita y, si la última línea empieza con «—», su fuente en pequeño.
    private func quoteView(_ quote: String) -> some View {
        var lines = quote.components(separatedBy: "\n")
        let source = lines.last?.hasPrefix("—") == true ? lines.removeLast() : nil
        return VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(Self.inline(lines.joined(separator: "\n")))
                .font(.quote)
                .lineSpacing(Theme.Space.xs)
            if let source {
                Text(Self.inline(String(source.dropFirst()).trimmingCharacters(in: .whitespaces)))
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryInk)
            }
        }
        .padding(.leading, Theme.Space.rowGap)
        .overlay(alignment: .leading) {
            Rectangle().fill(Theme.accent).frame(width: Theme.Size.quoteRule)
        }
    }

    static func inline(_ markdown: String) -> AttributedString {
        let resolved = NoteMarkdown.resolvingLinks(markdown)
        return (try? AttributedString(markdown: resolved, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(markdown)
    }
}

// MARK: - Fechas y números en español

extension Locale {
    /// La app está en español, aunque el dispositivo esté en otro idioma.
    static let gabinete = Locale(identifier: "es_MX")
    /// Para cifras compactas: «17,8 mil» (con es_MX saldría «17.8 k»).
    static let gabineteNumbers = Locale(identifier: "es")
}

extension Date {
    /// Fecha en español: `fecha.es(.dateTime.day().month(.wide))` → «22 de noviembre».
    func es(_ style: Date.FormatStyle) -> String {
        formatted(style.locale(.gabinete))
    }
}

extension Double {
    /// 57 (de 0,57), redondeado igual en toda la app.
    var percentNumber: Int { Int((Swift.min(1, Swift.max(0, self)) * 100).rounded()) }

    /// «57 %»: con espacio (como en español) que no se parte, igual en toda la app.
    /// Antes la Mesa decía «2 %» y el lector «3%» del mismo libro.
    var percentText: String { "\(percentNumber)\u{00A0}%" }
}

// MARK: - Sesiones de lectura

/// Cómo se escriben los números de una sesión.
enum ReadingFormat {
    /// «840», «4,4 mil», «1,1 M».
    static func words(_ count: Int) -> String {
        count.formatted(.number.notation(.compactName).precision(.fractionLength(0...1)).locale(.gabineteNumbers))
    }

    /// «19:37» (minutos y segundos), para la sesión en curso.
    static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// El año en números romanos (MMXXVI), para el rótulo del diario.
    static func roman(_ number: Int) -> String {
        let table: [(Int, String)] = [(1000, "M"), (900, "CM"), (500, "D"), (400, "CD"), (100, "C"), (90, "XC"),
                                      (50, "L"), (40, "XL"), (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]
        var rest = number
        var text = ""
        for (value, letters) in table {
            while rest >= value { text += letters; rest -= value }
        }
        return text
    }

    /// «20 min», «1 h 21 min».
    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        if minutes < 60 { return "\(minutes) min" }
        return minutes % 60 == 0 ? "\(minutes / 60) h" : "\(minutes / 60) h \(minutes % 60) min"
    }
}

/// Tres números grandes en serif con su leyenda («4,4 mil · palabras»).
struct StatTrio: View {
    struct Item: Identifiable {
        let value: String
        let label: String
        var id: String { label }
    }

    let items: [Item]
    /// A la izquierda, como cifras de libreta (Ajustes › Tu Gabinete); centradas en el diario.
    var leading = false

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(items) { item in
                VStack(alignment: leading ? .leading : .center, spacing: Theme.Space.xs) {
                    Text(item.value)
                        .font(.bookTitle)
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(Theme.Emphasis.labelMinScale)
                    CapsText(text: item.label)
                }
                .frame(maxWidth: .infinity, alignment: leading ? .leading : .center)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// La sesión como una barra partida en sus etapas.
struct StageBar: View {
    let segments: [StageSegment]
    var height = Theme.Size.stageBar

    var body: some View {
        GeometryReader { geometry in
            let total = max(segments.reduce(0) { $0 + $1.duration }, 1)
            HStack(spacing: Theme.Size.stageGap) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    Rectangle()
                        .fill(Theme.stage(segment.stage))
                        .frame(width: max(geometry.size.width * segment.duration / total - Theme.Size.stageGap, Theme.Size.stageGap))
                }
            }
        }
        .frame(height: height)
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }
}

/// Leyenda de las etapas con su tiempo («Inmersa 8 min»).
struct StageLegend: View {
    let seconds: (ReadingStage) -> TimeInterval

    var body: some View {
        FlowRow {
            ForEach(ReadingStage.allCases.reversed(), id: \.self) { stage in
                let time = seconds(stage)
                if time >= 30 {
                    HStack(spacing: Theme.Space.xs) {
                        RoundedRectangle(cornerRadius: Theme.Radius.swatch)
                            .fill(Theme.stage(stage))
                            .frame(width: Theme.Size.legendSwatch, height: Theme.Size.legendSwatch)
                        Text("\(stage.title) \(ReadingFormat.duration(time))")
                    }
                }
            }
        }
        .font(.caption)
        .foregroundStyle(Theme.secondaryInk)
    }
}

/// Fila que pasa a la siguiente línea cuando no cabe.
struct FlowRow<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Theme.Space.l) { content }
            VStack(alignment: .leading, spacing: Theme.Space.xs) { content }
        }
    }
}

/// Las etapas en el tiempo: una fila por etapa, de interrumpida (arriba) a inmersa.
struct StageChart: View {
    let segments: [StageSegment]
    /// Una fila por etapa y una más para las horas.
    private let chartRows = ReadingStage.allCases.count + 1

    var body: some View {
        Chart(Array(segments.enumerated()), id: \.offset) { _, segment in
            RectangleMark(
                xStart: .value("Inicio", segment.start),
                xEnd: .value("Fin", segment.end),
                y: .value("Etapa", segment.stage.title),
                height: .fixed(Theme.Size.stageMark)
            )
            .foregroundStyle(Theme.stage(segment.stage))
            .cornerRadius(Theme.Radius.cover)
        }
        .chartYScale(domain: ReadingStage.allCases.map(\.title))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisValueLabel(format: .dateTime.hour().minute().locale(.gabinete))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in AxisValueLabel() }
        }
        .chartPlotStyle { $0.background(Theme.paper) }
        .frame(height: Theme.Size.stageRow * CGFloat(chartRows))
        .accessibilityLabel("Etapas de la sesión en el tiempo")
    }
}

/// El contador de palabras del lector: discreto, en verde hoja, abajo a la izquierda.
struct WordCounter: View {
    let words: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.s) {
                Circle().fill(Theme.accent).frame(width: Theme.Size.legendSwatch, height: Theme.Size.legendSwatch)
                Text(ReadingFormat.words(words))
                    .monospacedDigit()
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, Theme.Space.rowY)
            .frame(minHeight: Theme.Size.tapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(words) palabras en esta sesión. Ver la sesión")
    }
}

// MARK: - Lector y audio

/// La sesión en una línea dentro del panel; tocándola, su tarjeta.
struct SessionLine: View {
    @ObservedObject var tracker: SessionTracker
    /// En la fila del capítulo: solo las palabras y la flecha.
    var compact = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.s) {
                // Sin punto: el verde solo en el dato, las palabras de esta sesión.
                // En la tarjeta del lector, en gris como la página; en la hoja de la sesión, el dato en verde.
                (Text(compact ? "" : "Esta sesión · ")
                 + Text("\(ReadingFormat.words(tracker.words)) palabras").foregroundStyle(compact ? Theme.ink.opacity(Theme.Emphasis.glassText) : Theme.accent))
                    .monospacedDigit()
                    .lineLimit(1)
                if !compact { Spacer(minLength: 0) }
                Image(systemName: "chevron.right").font(.caption.weight(.medium))
            }
            .font(compact ? .footnote : .footnote.weight(.medium))
            .foregroundStyle(Theme.ink.opacity(Theme.Emphasis.glassText))
            .frame(minHeight: Theme.Size.tapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ver la sesión")
    }
}

/// Muestra del pie: la parte de abajo de una página, con el papel y la tinta del
/// libro, tres renglones insinuados (el último, fin de párrafo) y el pie tal como
/// se leerá, con su misma letra. Debajo, su nombre. La elegida lleva filo de tinta
/// y palomita: no solo el color dice cuál es.
struct FooterPreview: View {
    let name: String
    let text: String
    let paper: Color
    let ink: Color
    var available = true
    var selected = false

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: Theme.Radius.inset, style: .continuous) }

    var body: some View {
        VStack(spacing: Theme.Space.xs) {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    ghost
                    ghost
                    ghost.padding(.trailing, Theme.Space.xxl)
                }
                Spacer(minLength: 0)
                Text(text)
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(Theme.Emphasis.labelMinScale)
                    .foregroundStyle(ink.opacity(available ? Theme.Emphasis.folio : Theme.Emphasis.folioMuted))
                    .contentTransition(.numericText())
            }
            .padding(Theme.Space.s)
            .frame(maxWidth: .infinity)
            // Crece con el tamaño de texto de iOS: el pie nunca se corta.
            .frame(minHeight: Theme.Size.footerPreview)
            .background(paper, in: shape)
            .overlay {
                shape.strokeBorder(selected ? ink : ink.opacity(Theme.Emphasis.ghost),
                                   lineWidth: selected ? Theme.Size.selection : Theme.Size.hairline)
            }
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(ink)
                        .background(Circle().fill(paper))
                        .padding(Theme.Space.xs)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            Text(name)
                .font(.caption)
                .foregroundStyle(Theme.ink.opacity(selected ? Theme.Emphasis.rest : Theme.Emphasis.glassText))
                .lineLimit(1)
        }
        // Al elegir: el filo y la palomita llegan con un resorte corto. Al presionar,
        // se hunde (PressableStyle); todas miden siempre lo mismo.
        .animation(Theme.Motion.select, value: selected)
    }

    private var ghost: some View {
        Capsule().fill(ink.opacity(Theme.Emphasis.ghost)).frame(height: Theme.Size.ghostLine)
    }
}

/// Barra de avance del lector: un riel fino, lo leído en tinta y una perilla
/// chica. Se arrastra o se toca en cualquier punto; el área de toque es alta.
struct ScrubberBar: View {
    let value: Double
    var enabled = true
    let onChange: (Double) -> Void
    let onEnd: () -> Void
    @State private var dragging = false
    @State private var vertical = false

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let clamped = min(max(value, 0), 1)
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.ink.opacity(Theme.Emphasis.scrubberTrack)).frame(height: Theme.Size.stageBarThin)
                Capsule().fill(Theme.ink).frame(width: max(width * clamped, Theme.Size.stageBarThin), height: Theme.Size.stageBarThin)
                Circle().fill(Theme.ink)
                    .frame(width: Theme.Size.scrubberKnob, height: Theme.Size.scrubberKnob)
                    .scaleEffect(dragging ? Theme.Emphasis.knobGrow : Theme.Emphasis.rest)
                    .offset(x: (width - Theme.Size.scrubberKnob) * clamped)
                    .animation(Theme.Motion.select, value: dragging)
            }
            .frame(maxHeight: .infinity)
            // Se toca en 44 pt de alto aunque se vea fina: el área crece fuera de su lugar.
            .contentShape(Rectangle().inset(by: -Theme.Size.scrubberReach))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        guard enabled, width > 0, !vertical else { return }
                        let dx = abs(drag.translation.width), dy = abs(drag.translation.height)
                        if !dragging {
                            // Hasta saber hacia dónde va el dedo no se mueve nada: subir
                            // el panel por encima de la barra ya no la arrastra.
                            guard max(dx, dy) > Theme.Size.dragSlop else { return }
                            guard dx >= dy else { vertical = true; return }
                            dragging = true
                        }
                        onChange(min(max(drag.location.x / width, 0), 1))
                    }
                    .onEnded { drag in
                        defer { dragging = false; vertical = false }
                        guard enabled, width > 0, !vertical else { return }
                        if !dragging { onChange(min(max(drag.location.x / width, 0), 1)) }
                        onEnd()
                    }
            )
        }
        .frame(height: Theme.Size.scrubberHeight)
        .opacity(enabled ? Theme.Emphasis.rest : Theme.Emphasis.pressed)
        .accessibilityElement()
        .accessibilityAdjustableAction { direction in
            let step = 0.01
            onChange(min(max(value + (direction == .increment ? step : -step), 0), 1))
            onEnd()
        }
    }
}

/// La rayita de un panel que se sube con el dedo.
struct Grabber: View {
    var body: some View {
        Capsule()
            .fill(Theme.secondaryInk.opacity(Theme.Emphasis.folioMuted))
            .frame(width: Theme.Size.grabber.width, height: Theme.Size.grabber.height)
    }
}


/// Botón en cápsula del panel del lector («Guiada», «Escuchar»). El destacado va en tinta.
struct ReaderPillButton: View {
    let title: String
    let systemImage: String
    var prominent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .foregroundStyle(prominent ? Theme.onInk : Theme.ink)
                .frame(maxWidth: .infinity, minHeight: Theme.Size.tapTarget)
                .background(prominent ? Theme.ink : Theme.field, in: Capsule())
        }
        .font(.subheadline.weight(.medium))
        .buttonStyle(.plain)
    }
}

/// Reproducir o pausar, con el avance del capítulo en un anillo verde.
struct PlayRingButton: View {
    let playing: Bool
    let progress: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().stroke(Theme.track, lineWidth: Theme.Size.quoteRule)
                Circle().trim(from: 0, to: progress)
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: Theme.Size.quoteRule, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: playing ? "pause.fill" : "play.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .frame(width: Theme.Size.playRing, height: Theme.Size.playRing)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(playing ? "Pausa" : "Reproducir")
    }
}

/// Tres barras que se mueven: hay audio sonando.
struct EqualizerBars: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: Theme.Space.xxs) {
            ForEach([0.5, 1.0, 0.7], id: \.self) { height in
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: Theme.Size.equalizerBar, height: Theme.Size.equalizerHeight * height)
                    .phaseAnimator([1.0, 0.4]) { bar, phase in
                        bar.scaleEffect(y: phase, anchor: .bottom)
                    } animation: { _ in Theme.Motion.equalizer(height) }
            }
        }
        .frame(height: Theme.Size.equalizerHeight, alignment: .bottom)
        .accessibilityHidden(true)
    }
}

extension View {
    /// Esquinas de portada para una imagen que hace de portada.
    func coverShape() -> some View {
        clipShape(RoundedRectangle(cornerRadius: Theme.Radius.cover))
    }
}

/// «Recientes ⇅»: texto primero, icono después.
struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Theme.Space.xs) {
            configuration.title
            configuration.icon.font(.caption2.weight(.semibold))
        }
    }
}

// MARK: - Diario de lectura

extension ReadingDay {
    /// Intensidad del día en el calendario: nada, poco… mucho (como las etapas).
    var level: ReadingStage? {
        switch seconds {
        case ..<60: nil
        case ..<(20 * 60): .skimming
        case ..<(40 * 60): .light
        case ..<(55 * 60): .active
        default: .immersed
        }
    }
}

/// Una barra por día (lunes a domingo), partida en etapas; hoy, en tinta.
struct WeekBars: View {
    let days: [ReadingDay]
    var today = Date()

    private var most: TimeInterval { max(days.map(\.seconds).max() ?? 0, 1) }
    private let stacked: [ReadingStage] = [.skimming, .light, .active, .immersed]

    var body: some View {
        VStack(spacing: Theme.Space.s) {
            HStack(alignment: .bottom, spacing: Theme.Space.s) {
                ForEach(days) { day in
                    VStack(spacing: 0) {
                        if day.seconds < 60 {
                            Rectangle().fill(Theme.track).frame(height: Theme.Size.progress)
                        } else {
                            ForEach(stacked, id: \.self) { stage in
                                Rectangle()
                                    .fill(Theme.stage(stage))
                                    .frame(height: Theme.Size.weekChart * day.seconds(in: stage) / most)
                            }
                        }
                    }
                    .frame(width: Theme.Size.weekBar)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.cover))
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: Theme.Size.weekChart, alignment: .bottom)
            .overlay(alignment: .bottom) { Hairline() }
            HStack(spacing: Theme.Space.s) {
                ForEach(days) { day in
                    let isToday = Calendar.current.isDate(day.date, inSameDayAs: today)
                    Text(day.date.es(.dateTime.weekday(.narrow)).uppercased())
                        .font(.caption.weight(isToday ? .semibold : .regular))
                        .foregroundStyle(isToday ? Theme.ink : Theme.tertiaryInk)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(days.map { "\($0.date.es(.dateTime.weekday(.wide))): \(ReadingFormat.duration($0.seconds))" }.joined(separator: ", "))
    }
}

/// El mes como calendario: cada día, un círculo más oscuro cuanto más leíste; hoy con anillo.
struct MonthCalendar: View {
    let days: [ReadingDay]
    var today = Date()

    private var leadingBlanks: Int {
        guard let first = days.first else { return 0 }
        let weekday = Calendar.current.component(.weekday, from: first.date)
        return (weekday + 5) % 7 // lunes primero
    }

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        VStack(spacing: Theme.Space.s) {
            LazyVGrid(columns: columns, spacing: Theme.Space.s) {
                ForEach(0..<leadingBlanks, id: \.self) { _ in Color.clear.frame(height: Theme.Size.dayCell) }
                ForEach(days) { day in
                    let future = day.date > today
                    let isToday = Calendar.current.isDate(day.date, inSameDayAs: today)
                    Text(day.date.es(.dateTime.day()))
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(future ? Theme.track : (day.level.map { $0 == .active || $0 == .immersed } == true ? Theme.paper : Theme.ink))
                        .frame(width: Theme.Size.dayCell, height: Theme.Size.dayCell)
                        .background(day.level.map(Theme.stage) ?? Color.clear, in: Circle())
                        .overlay { if isToday { Circle().stroke(Theme.ink, lineWidth: Theme.Size.selection) } }
                        .accessibilityLabel("\(day.date.es(.dateTime.day().month(.wide))): \(ReadingFormat.duration(day.seconds))")
                }
            }
            HStack(spacing: Theme.Space.s) {
                Text("Menos")
                ForEach([ReadingStage.skimming, .light, .active, .immersed], id: \.self) { stage in
                    Circle().fill(Theme.stage(stage)).frame(width: Theme.Size.legendSwatch, height: Theme.Size.legendSwatch)
                }
                Text("Más tiempo")
            }
            .font(.caption)
            .foregroundStyle(Theme.secondaryInk)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// El año: una barra por mes; el actual, en verde hoja.
struct YearBars: View {
    let months: [TimeInterval]
    var current: Int

    private static let initials = ["E", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]

    var body: some View {
        let most = max(months.max() ?? 0, 1)
        VStack(spacing: Theme.Space.s) {
            HStack(alignment: .bottom, spacing: Theme.Space.s) {
                ForEach(Array(months.enumerated()), id: \.offset) { index, seconds in
                    Rectangle()
                        .fill(index == current ? Theme.accent : (seconds > 0 ? Theme.stage(.light) : Theme.track))
                        .frame(height: seconds > 0 ? Theme.Size.yearChart * seconds / most : Theme.Size.progress)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.cover))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: Theme.Size.yearChart, alignment: .bottom)
            .overlay(alignment: .bottom) { Hairline() }
            HStack(spacing: Theme.Space.s) {
                ForEach(Array(Self.initials.enumerated()), id: \.offset) { index, letter in
                    Text(letter)
                        .font(.caption.weight(index == current ? .semibold : .regular))
                        .foregroundStyle(index == current ? Theme.ink : Theme.tertiaryInk)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tiempo leyendo por mes")
    }
}

/// Una sesión en una lista: cuándo, palabras y avance, y su duración.
struct SessionRow: View {
    let session: ReadingSession
    /// El libro, si la lista mezcla libros.
    var bookTitle: String? = nil

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Space.l) {
            VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                HStack(spacing: Theme.Space.xs) {
                    Text(session.start.es(.dateTime.weekday(.abbreviated).day().hour().minute()))
                    if let bookTitle {
                        Text("· \(bookTitle)").font(.rowTitle).lineLimit(1)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
                Text("\(ReadingFormat.words(session.words)) palabras · \(session.fromFraction.percentNumber) → \(session.toFraction.percentText)")
                    .font(.footnote)
                    .foregroundStyle(Theme.tertiaryInk)
            }
            Spacer(minLength: 0)
            Text(ReadingFormat.duration(session.readingSeconds))
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(Theme.secondaryInk)
        }
        .padding(.vertical, Theme.Space.rowY)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { Hairline() }
    }
}

/// Tarjeta para compartir una sesión: verde fichero, la marca, el libro, una cita opcional,
/// las etapas y los números. Se manda como imagen.
struct ShareCard: View {
    let session: ReadingSession
    let title: String
    let author: String
    var quote: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("GABINETE")
                .font(.sectionLabel)
                .tracking(Theme.Tracking.sectionLabel)
            VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                Text(title).font(.rowTitle.weight(.medium))
                Text(author).font(.footnote).opacity(Theme.Emphasis.secondary)
            }
            .padding(.top, Theme.Space.xl)
            if let quote {
                Text("«\(quote)»")
                    .font(.quote)
                    .lineLimit(4)
                    .padding(.top, Theme.Space.l)
            }
            Spacer(minLength: Theme.Space.l)
            StageBar(segments: session.segments)
            HStack(alignment: .firstTextBaseline) {
                cardNumber(ReadingFormat.duration(session.readingSeconds), "")
                Spacer()
                cardNumber(ReadingFormat.words(session.words), "palabras")
                Spacer()
                cardNumber(ReadingFormat.duration(session.seconds(in: .immersed)), "inmersa")
            }
            .padding(.top, Theme.Space.l)
        }
        .foregroundStyle(Theme.onBrand)
        .padding(Theme.Space.xl)
        .frame(width: Theme.Size.shareCard.width, height: Theme.Size.shareCard.height, alignment: .topLeading)
        .background(Theme.brand, in: RoundedRectangle(cornerRadius: Theme.Radius.tile))
    }

    private func cardNumber(_ value: String, _ label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.xs) {
            Text(value).font(.rowTitle.weight(.medium)).monospacedDigit()
            if !label.isEmpty { Text(label).font(.caption).opacity(Theme.Emphasis.secondary) }
        }
    }

    /// La tarjeta como imagen, para compartirla.
    @MainActor
    func image(scale: CGFloat = 3) -> Image? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = scale
        #if os(iOS)
        return renderer.uiImage.map(Image.init(uiImage:))
        #else
        return renderer.nsImage.map(Image.init(nsImage:))
        #endif
    }
}

/// Compartir una sesión como imagen.
struct ShareSessionButton: View {
    let card: ShareCard

    var body: some View {
        if let image = card.image() {
            ShareLink(item: image, preview: SharePreview("Sesión de lectura", image: image)) {
                Image(systemName: "square.and.arrow.up")
            }
            .accessibilityLabel("Compartir la sesión")
        }
    }
}

// MARK: - Herramientas del lector

/// Una entrada del índice del libro: sangría por nivel y, si es donde vas, un punto verde.
struct ContentsRow: View {
    let label: String
    var depth = 0
    var isCurrent = false

    var body: some View {
        HStack(spacing: Theme.Space.s) {
            Text(label)
                .font(depth == 0 ? .rowTitle : .subheadline)
                .foregroundStyle(depth == 0 ? Theme.ink : Theme.secondaryInk)
                .multilineTextAlignment(.leading)
            Spacer(minLength: Theme.Space.s)
            if isCurrent {
                Circle().fill(Theme.accent).frame(width: Theme.Size.legendSwatch, height: Theme.Size.legendSwatch)
                    .accessibilityLabel("Aquí vas")
            }
        }
        .padding(.leading, Theme.Space.l * CGFloat(min(depth, Theme.Size.indentLevels)))
        .padding(.vertical, Theme.Space.rowY)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { Hairline() }
    }
}

/// Un resultado de buscar en el libro: el capítulo y el texto alrededor, con lo buscado resaltado.
struct SearchResultRow: View {
    let before: String
    let match: String
    let after: String
    /// «pág. 22» a la derecha (o el porcentaje si el libro no trae páginas).
    let place: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.l) {
            // Lo encontrado en verde y en negritas: no depende solo del color.
            (Text(Self.lead(before)) + Text(match).bold().foregroundStyle(Theme.accent) + Text(Self.tail(after))) // ds-exception: lo buscado
                .font(.prose)
                .foregroundStyle(Theme.ink)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(place)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(Theme.secondaryInk)
        }
        .padding(.vertical, Theme.Space.rowY)
        .frame(maxWidth: .infinity, minHeight: Theme.Size.tapTarget, alignment: .leading)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { Hairline() }
    }

    /// Lo que se quita de los bordes de un pasaje cortado: espacios y puntos suspensivos.
    private static let cut = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".…"))

    /// Un pasaje es un solo renglón corrido: los saltos de línea del libro se vuelven espacios.
    private static func flat(_ text: String) -> String {
        text.split(whereSeparator: \.isNewline).joined(separator: " ")
    }

    /// El texto de foliate ya puede traer «...» o «…»: se quitan y se pone uno solo,
    /// y ninguno si el pasaje empieza o termina ahí.
    static func lead(_ text: String) -> String {
        let core = flat(text).trimmingCharacters(in: Self.cut)
        return core.isEmpty ? "" : "…" + core + (text.last?.isWhitespace == true ? " " : "")
    }

    static func tail(_ text: String) -> String {
        let core = flat(text).trimmingCharacters(in: Self.cut)
        return core.isEmpty ? "" : (text.first?.isWhitespace == true ? " " : "") + core + "…"
    }
}

/// Campo de búsqueda sobre `field`, con lupa y botón para borrar.
struct SearchField: View {
    let prompt: String
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    let onSubmit: () -> Void
    var onClear: () -> Void = {}

    var body: some View {
        HStack(spacing: Theme.Space.s) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.tertiaryInk)
            TextField(prompt, text: $text)
                .focused(focused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .onSubmit(onSubmit)
            if !text.isEmpty {
                Button { text = ""; onClear() } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.tertiaryInk)
                    .accessibilityLabel("Borrar la búsqueda")
            }
        }
        .padding(.horizontal, Theme.Space.l)
        .frame(minHeight: Theme.Size.control)
        .background(Theme.field, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
    }
}

// MARK: - Bienvenida

/// Una opción para elegir entre varias: ícono, título, explicación y, si es la
/// elegida, el borde y la marca verdes.
struct OptionRow: View {
    let systemImage: String
    let title: String
    let detail: String
    var selected = false

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Space.l) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(selected ? Theme.accent : Theme.secondaryInk)
                .frame(width: Theme.Size.tapTarget)
            VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                Text(title).font(.rowTitle).foregroundStyle(Theme.ink)
                Text(detail).font(.subheadline).foregroundStyle(Theme.secondaryInk)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            if selected {
                Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundStyle(Theme.accent)
            }
        }
        .padding(Theme.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.field, in: RoundedRectangle(cornerRadius: Theme.Radius.tile))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.tile)
                .stroke(selected ? Theme.accent : Color.clear, lineWidth: Theme.Size.selection)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Encabezado de un capítulo en los resultados de buscar: su nombre y cuántas veces
/// aparece ahí.
struct SearchChapterHeading: View {
    let title: String
    let count: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.l) {
            Text(title.isEmpty ? "Sección sin título" : title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(count)")
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(Theme.secondaryInk)
        }
        .padding(.top, Theme.Space.l)
        .padding(.bottom, Theme.Space.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(count == 1 ? "1 resultado" : "\(count) resultados")")
        .accessibilityAddTraits(.isHeader)
    }
}

/// Raya verde «Aquí vas · pág. 18» entre resultados: lo de arriba ya lo leíste.
struct HereMark: View {
    let text: String

    var body: some View {
        HStack(spacing: Theme.Space.s) {
            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.accent)
                .fixedSize()
            Capsule().fill(Theme.accent).frame(height: Theme.Size.quoteRule)
        }
        .padding(.vertical, Theme.Space.s)
        .accessibilityElement(children: .combine)
    }
}

/// Una búsqueda reciente: tocarla la repite. A la derecha, cuántos resultados tuvo.
struct RecentSearchRow: View {
    let text: String
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.l) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryInk)
                Text(text)
                    .font(.body)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("\(count)")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(Theme.secondaryInk)
            }
            .frame(minHeight: Theme.Size.tapTarget)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) { Hairline() }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Buscar otra vez «\(text)», \(count) resultados")
    }
}

/// Barrita de vidrio sobre la página tras ir a un resultado: anterior y siguiente sin
/// volver a abrir la lista; tocar el centro la reabre y la ✕ termina la búsqueda.
struct SearchStepper: View {
    let position: String
    let query: String
    let canGoBack: Bool
    let canGoForward: Bool
    let onBack: () -> Void
    let onForward: () -> Void
    let onList: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            arrow("chevron.left", "Resultado anterior", enabled: canGoBack, action: onBack)
            Button(action: onList) {
                VStack(spacing: 0) {
                    Text("\(position) · «\(query)»")
                        .font(.subheadline.weight(.medium))
                        .monospacedDigit()
                        .lineLimit(1)
                    Text("Toca para ver la lista")
                        .font(.caption)
                        .foregroundStyle(Theme.ink.opacity(Theme.Emphasis.glassText))
                }
                .frame(maxWidth: .infinity, minHeight: Theme.Size.tapTarget)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("\(position), «\(query)». Ver la lista")
            arrow("chevron.right", "Resultado siguiente", enabled: canGoForward, action: onForward)
            arrow("xmark", "Terminar la búsqueda", enabled: true, action: onClose)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, Theme.Space.xs)
        .glassPanel(cornerRadius: Theme.Radius.panel)
    }

    private func arrow(_ symbol: String, _ label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.medium))
                .frame(width: Theme.Size.tapTarget, height: Theme.Size.tapTarget)
                .contentShape(Rectangle())
        }
        .disabled(!enabled)
        .opacity(enabled ? Theme.Emphasis.rest : Theme.Emphasis.folioMuted)
        .accessibilityLabel(label)
    }
}

/// Lo encontrado al buscar: marcarlo en un texto y recortar el pasaje donde aparece.
/// Sin distinguir mayúsculas ni acentos, como el buscador del libro.
enum Found {
    private static let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

    /// El texto con cada vez que aparece `match` en verde y negritas (no solo color).
    static func marked(_ text: String, _ match: String?) -> AttributedString {
        var result = AttributedString(text)
        guard let match = match?.trimmingCharacters(in: .whitespaces), !match.isEmpty else { return result }
        var from = text.startIndex
        while let range = text.range(of: match, options: options, range: from..<text.endIndex) {
            if let lower = AttributedString.Index(range.lowerBound, within: result),
               let upper = AttributedString.Index(range.upperBound, within: result) {
                result[lower..<upper].foregroundColor = Theme.accent
                result[lower..<upper].inlinePresentationIntent = .stronglyEmphasized
            }
            from = range.upperBound
        }
        return result
    }

    /// Unas palabras antes y después de la primera vez que aparece `match`, en un renglón.
    static func excerpt(_ text: String, around match: String) -> String? {
        let flat = text.split(whereSeparator: \.isNewline).joined(separator: " ")
        guard let range = flat.range(of: match, options: options) else { return nil }
        let start = flat.index(range.lowerBound, offsetBy: -Theme.Size.excerptReach, limitedBy: flat.startIndex) ?? flat.startIndex
        let end = flat.index(range.upperBound, offsetBy: Theme.Size.excerptReach, limitedBy: flat.endIndex) ?? flat.endIndex
        return (start > flat.startIndex ? "…" : "") + flat[start..<end].trimmingCharacters(in: .whitespaces)
            + (end < flat.endIndex ? "…" : "")
    }
}
