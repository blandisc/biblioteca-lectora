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
            .navigationDestination(for: ShelfRef.self) { SavedShelfScreen(ref: $0) }
            .navigationDestination(for: ReviewInboxRef.self) { _ in ReviewScreen() }
            .navigationDestination(for: CandidatesRef.self) { CandidatesScreen(bookID: $0.bookID, searchesFirst: $0.searchesFirst) }
            .navigationDestination(for: FilledRef.self) { FilledScreen(bookID: $0.bookID) }
            .navigationDestination(for: NoteRef.self) { NoteScreen(ref: $0) }
            .navigationDestination(for: DiaryRef.self) { _ in DiaryScreen() }
            .navigationDestination(for: SessionRef.self) { SessionScreen(ref: $0) }
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            // Todo lo que se abre desde aquí (sus barras, sus hojas) lleva sus acciones en tinta:
            // el «Editar» de la ficha y del estante salía en verde (regla 1). La pestaña elegida
            // sigue en verde: la pinta el dock, que está afuera.
            .tint(Theme.ink)
            .toggleStyle(AccentSwitchStyle())
    }

    /// Margen lateral de pantalla, igual a ambos lados.
    func gutter() -> some View {
        padding(.horizontal, Theme.Space.gutter)
    }

    /// DUO-1 · las barras en el iPhone Duo: en la pantalla de afuera iOS pone las pestañas y la
    /// hora en una franja al costado. Con DUO-1B (`Duo.barsBelow`, falta decidirlo) vuelven abajo
    /// y arriba, como en cualquier iPhone. iOS le pregunta a lo que se ve en cada presentación:
    /// cada pestaña (puesto en la `TabView` misma no lo lee), el lector, la bienvenida y cada hoja
    /// lo declaran. iOS 27.2 no lo respeta siempre: al abrir el libro regresa la franja y se queda
    /// (27 nov 2026). En los demás iPhone no hace nada.
    @ViewBuilder
    func duoBars() -> some View {
        #if os(iOS) && compiler(>=6.4)
        if Duo.barsBelow, #available(iOS 27.1, *) { toolbarVerticalBehavior(.disabled) } else { self }
        #else
        self // El Xcode de GitHub todavía no conoce el Duo: ahí no hay franja que quitar.
        #endif
    }

    /// En el iPhone, lo más ancho que crece algo (con su margen), centrado: en una pantalla
    /// ancha (el Duo abierto) el texto no cruza de orilla a orilla. `nil`, todo el ancho.
    /// En la Mac no cambia nada: ahí la ventana ya mide lo suyo.
    @ViewBuilder
    func measured(_ width: CGFloat?) -> some View {
        #if os(iOS)
        if let width {
            frame(maxWidth: width).frame(maxWidth: .infinity)
        } else {
            self
        }
        #else
        self
        #endif
    }

    /// Receta de formulario (Ajustes, Conexiones, Reglas, Editar datos): el mismo papel
    /// que el resto de la app, no el gris frío del sistema. Sus botones en tinta, como toda
    /// acción (regla 1: «Elegir de Fotos» y «Elegir archivo» salían en verde); los interruptores
    /// prendidos sí en verde, porque dicen lo tuyo (`AccentSwitchStyle`).
    func formScreen() -> some View {
        self
            // En la Mac, agrupado como la ficha: con el estilo de columnas, Reglas y las conexiones
            // se salían de la ventana de Ajustes y cortaban sus nombres (27 nov 2026).
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            // En el iPhone Duo abierto, los campos no cruzan toda la pantalla.
            .measured(Theme.Size.screenMeasure)
            .background(Theme.paper.ignoresSafeArea())
            .tint(Theme.ink)
            .toggleStyle(AccentSwitchStyle())
    }

    /// Receta de pantalla empujada u hoja (ficha, serie, nota, Lector › herramientas…):
    /// papel de fondo, título en línea y controles del contenido en tinta (los interruptores,
    /// en verde: `AccentSwitchStyle`). Los botones
    /// de la barra de vidrio («Listo», «Cancelar», «Editar») van en tinta, como en iOS 26;
    /// antes unas hojas los forzaban a verde y otras no (22 nov 2026).
    /// `sheet: true` en una hoja con dos botones de texto en la barra (ver `sheetTitle`).
    /// `bar: false` en una hoja que se cierra con la ✕ de su encabezado (Ajustes, UX-6b): sin
    /// barra, nada flota sobre el contenido al deslizar.
    @ViewBuilder
    func pushedScreen(_ title: String = "", sheet: Bool = false, bar: Bool = true) -> some View {
        let screen = self
            .background(Theme.paper.ignoresSafeArea())
            .barTitle(title, large: sheet)
            .tint(Theme.ink)
            .toggleStyle(AccentSwitchStyle())
        #if os(iOS)
        if bar { screen } else { screen.toolbar(.hidden, for: .navigationBar) }
        #else
        screen
        #endif
    }

    /// Título pequeño, centrado en la barra (pantallas empujadas, hojas y formularios).
    /// En la Mac, sin título no se pone uno vacío: el de `ScreenHeading` ya va en la barra (MX-B).
    func inlineTitle(_ title: String) -> some View { barTitle(title, large: false) }

    /// Título de una hoja con dos botones de texto en la barra («Dejar como está» y «Guardar
    /// cambios»): va debajo de ellos, en grande, porque en medio no cabe y iOS lo escondía
    /// (UX-3a, 26 nov 2026: «Editar datos» no se veía).
    func sheetTitle(_ title: String) -> some View { barTitle(title, large: true) }

    @ViewBuilder
    fileprivate func barTitle(_ title: String, large: Bool) -> some View {
        #if os(iOS)
        self
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(large ? .large : .inline)
        #else
        if title.isEmpty { self } else { self.navigationTitle(title) }
        #endif
    }

    /// El título de pantalla en serif, que crece con el tamaño de texto de iOS (antes fijo en 30).
    func screenTitleFont() -> some View {
        modifier(ScreenTitleFont())
    }

    /// Contenedor de una pantalla con scroll: margen, aire arriba y abajo.
    /// En una pantalla ancha del iPhone (el Duo abierto, un iPhone acostado) el texto no corre
    /// de orilla a orilla: la pantalla se queda en `Size.screenMeasure`, centrada, como el libro
    /// en la Mac. `wide: true` solo donde mandan las portadas (Mesa y Biblioteca): ahí la
    /// cuadrícula usa todo el ancho y pone más columnas. Ningún iPhone de pie llega a la medida.
    func screenContent(wide: Bool = false) -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(Theme.ink)
            .gutter()
            .measured(wide ? nil : Theme.Size.screenMeasure)
            .padding(.top, Theme.Space.screenTop)
            .padding(.bottom, Theme.Space.screenBottom)
    }
}

private struct ScreenTitleFont: ViewModifier {
    @ScaledMetric(relativeTo: .largeTitle) private var size = Theme.Letter.screenTitle

    func body(content: Content) -> some View {
        content.font(.screenTitle(size))
    }
}

/// Título de pantalla en serif, con acciones a la derecha y una línea finísima debajo:
/// la cabecera de una hoja de libreta (SD-3, 26 nov 2026).
struct ScreenHeading<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        #if os(macOS)
        // En la Mac el nombre de la pantalla va una sola vez, en la barra de la ventana, y sus
        // acciones suben a ella, como en toda app de Mac (MX-B, 26 nov 2026).
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: 0)
            .accessibilityHidden(true)
            .navigationTitle(title)
            .toolbar { ToolbarItemGroup(placement: .primaryAction) { trailing } }
        #else
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            // Con la letra más grande el título se queda con todo el ancho y las acciones bajan
            // a su renglón: antes se partía a media palabra («Bibliotec / a»).
            AdaptiveStack(rowAlignment: .center) {
                Text(title)
                    .screenTitleFont()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                // Cada acción ya mide 44 (`IconButton`, `AccentIconButton`): van juntas, sin aire de más.
                HStack(spacing: 0) { trailing }
                    .font(.icon)
                    .foregroundStyle(Theme.ink)
                    .buttonStyle(.plain)
            }
            Hairline()
        }
        #endif
    }
}

/// Lo que va lado a lado y se apila, uno bajo otro, con la letra de accesibilidad de iOS
/// (AX1 a AX5): títulos con sus acciones, un conteo y su orden, un nombre y su campo, las
/// opciones de una fila. Así nada se sale de la pantalla ni se corta a media palabra (SD-4).
/// Con el tamaño de siempre (y en la Mac) es un `HStack` igual al de antes.
struct AdaptiveStack<Content: View>: View {
    var rowAlignment: VerticalAlignment = .center
    var columnAlignment: HorizontalAlignment = .leading
    var spacing: CGFloat? = nil
    @ViewBuilder var content: Content
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: columnAlignment, spacing: spacing))
            : AnyLayout(HStackLayout(alignment: rowAlignment, spacing: spacing))
        layout { content }
    }
}

/// Dos o más botones de texto lado a lado, todos del mismo ancho y en un renglón; si alguno no
/// cabe entero en su parte, van uno bajo otro, a lo ancho. Con `AdaptiveStack` el más largo se
/// partía en dos renglones junto a uno de un renglón («Cerrar el / resumen», auditoría 3).
struct ButtonPair: Layout {
    var spacing: CGFloat = Theme.Space.s

    private func side(_ width: CGFloat, _ subviews: Subviews) -> CGFloat? {
        guard !subviews.isEmpty else { return nil }
        let part = (width - spacing * CGFloat(subviews.count - 1)) / CGFloat(subviews.count)
        return subviews.allSatisfy { $0.sizeThatFits(.unspecified).width <= part } ? part : nil
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? subviews.map { $0.sizeThatFits(.unspecified).width }.reduce(0, +)
        if let part = side(width, subviews) {
            let height = subviews.map { $0.sizeThatFits(ProposedViewSize(width: part, height: nil)).height }.max() ?? 0
            return CGSize(width: width, height: height)
        }
        let heights = subviews.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).height }
        return CGSize(width: width, height: heights.reduce(0, +) + spacing * CGFloat(max(subviews.count - 1, 0)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        if let part = side(bounds.width, subviews) {
            var x = bounds.minX
            for view in subviews {
                view.place(at: CGPoint(x: x, y: bounds.minY), proposal: ProposedViewSize(width: part, height: bounds.height))
                x += part + spacing
            }
            return
        }
        var y = bounds.minY
        for view in subviews {
            let size = ProposedViewSize(width: bounds.width, height: nil)
            view.place(at: CGPoint(x: bounds.minX, y: y), proposal: size)
            y += view.sizeThatFits(size).height + spacing
        }
    }
}

/// Ícono de acción en tinta que se toca en 44 aunque se dibuje chico (SB-4): las acciones de
/// `ScreenHeading` (el engrane del Cuaderno, lista o portadas en la Biblioteca). Antes solo
/// respondía el dibujo, de unos 20 pt, junto a un «+» que sí medía 44.
struct IconButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.icon)
                .foregroundStyle(Theme.ink)
                .dynamicTypeSize(...Theme.Letter.fixedShapeLargest)
                .sizeTarget()
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
    }
}

extension View {
    /// Lo que se ve chico pero se toca en 44 × 44 (SB-4): las «A» del tamaño de letra, la ✕ de buscar.
    func sizeTarget() -> some View {
        frame(minWidth: Theme.Size.tapTarget, minHeight: Theme.Size.tapTarget).contentShape(Rectangle())
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
            .spaced(Theme.Tracking.brandMark, "GABINETE")
            .foregroundStyle(Theme.ink)
            // La marca es una palabra: si no cabe se achica un poco, nunca se parte.
            .lineLimit(1)
            .minimumScaleFactor(Theme.Emphasis.labelMinScale)
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
        #if os(macOS)
        // En la Mac la Mesa ya se llama así en la barra de la ventana: sin encabezado repetido (MX-B).
        EmptyView()
        #else
        VStack(spacing: Theme.Space.s) {
            // Con la letra más grande, la fecha baja bajo el nombre (antes «GABI / NETE»).
            AdaptiveStack(rowAlignment: .firstTextBaseline, spacing: Theme.Space.s) {
                BrandMark(alignment: .leading)
                CapsText(text: dateLine)
                    .layoutPriority(1)
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
        #endif
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
            .spaced(Theme.Tracking.sectionLabel, text)
            .foregroundStyle(tone)
            // Un título largo (o la letra más grande) no se vuelve una columna de versalitas.
            .lineLimit(Theme.Size.labelLines)
            .accessibilityAddTraits(.isHeader)
    }
}

extension View {
    /// Letras espaciadas, solo si la escritura lo aguanta (`String.isSpaceable`). Todo
    /// espaciado de la app pasa por aquí: un título en árabe queda junto, como se escribe.
    func spaced(_ amount: CGFloat, _ text: String) -> some View {
        tracking(text.isSpaceable ? amount : 0)
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
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.medium))
            .spaced(Theme.Tracking.caps, text)
            .monospacedDigit()
            .foregroundStyle(tone)
            // Con la letra más grande baja de renglón en vez de cortarse.
            .lineLimit(typeSize.isAccessibilitySize ? nil : lines)
    }
}

/// Cómo se anuncia toda sección (regla 3): versalitas, una línea finísima hasta la orilla y,
/// si hace falta, lo que va a la derecha: una acción, una cifra o cerrar («NOTAS ——— Nota
/// nueva»). Separa sin cajas. Antes había tres maneras (Cinzel sin línea, versalitas con
/// línea y texto gris a mano) y en la misma Mesa se veían dos (SD-2, 26 nov 2026).
struct SectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing
    @Environment(\.dynamicTypeSize) private var typeSize

    /// La acción de la derecha no se parte en renglones: si no cabe junto al rótulo,
    /// baja a su propio renglón («Darlos por buenos» se partía en tres).
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Theme.Space.l) {
                heading
                trailing.fixedSize(horizontal: true, vertical: false)
            }
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                heading
                trailing
            }
        }
    }

    /// Con la letra más grande el rótulo ocupa dos renglones y la raya de al lado quedaba en un
    /// pedacito (auditoría 6): ahí va debajo, a todo lo ancho.
    @ViewBuilder
    private var heading: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                CapsText(text: title)
                    .accessibilityAddTraits(.isHeader)
                Hairline()
                    .accessibilityHidden(true)
            }
        } else {
            HStack(spacing: Theme.Space.l) {
                CapsText(text: title)
                    .layoutPriority(1)
                    .accessibilityAddTraits(.isHeader)
                Hairline()
                    .accessibilityHidden(true)
            }
        }
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: String) {
        self.init(title: title) { EmptyView() }
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
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // Con la letra más grande, el ícono va al lado de su nombre y el nombre crece
        // (antes se achicaba y se cortaba: «Su…», «Co…»).
        let large = typeSize.isAccessibilitySize
        let layout = large ? AnyLayout(HStackLayout(spacing: Theme.Space.l)) : AnyLayout(VStackLayout(spacing: Theme.Space.s))
        layout {
            icon.frame(height: Theme.Space.xl)
            Text(title)
                .font(.caption.weight(.medium))
                .lineLimit(large ? Theme.Size.labelLines : 1)
                .minimumScaleFactor(large ? Theme.Emphasis.rest : Theme.Emphasis.labelMinScale)
        }
        .foregroundStyle(prominent ? Theme.onInk : Theme.ink)
        .frame(maxWidth: .infinity, alignment: large ? .leading : .center)
        .padding(.horizontal, large ? Theme.Space.l : 0)
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
        // Con la letra más grande, una opción bajo otra («Pági / nas» ya no se parte).
        AdaptiveStack(spacing: 0) {
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
                // Mide 44: el dibujo crece hasta donde cabe en él.
                .dynamicTypeSize(...Theme.Letter.fixedShapeLargest)
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
                .font(.icon)
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

/// Lo que acabo de hacer en lote, con «Deshacer» a la derecha (UX-5): una línea en tinta
/// secundaria, su acción en tinta y una línea finísima debajo. Con la letra más grande,
/// «Deshacer» baja bajo el texto.
struct UndoNotice: View {
    let text: String
    let undo: () -> Void

    var body: some View {
        AdaptiveStack(spacing: Theme.Space.l) {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryInk)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextAction(title: "Deshacer", action: undo)
        }
        .overlay(alignment: .bottom) { Hairline() }
    }
}

// MARK: - Filtros y pestañas

/// El conteo de una lista en versalitas («32 LIBROS · 32 EN ESTE IPHONE») y, a la
/// derecha, cómo se ordena si se puede elegir.
struct CountLine<Trailing: View>: View {
    let text: String
    @ViewBuilder var trailing: Trailing
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // Con la letra más grande, el orden baja bajo el conteo («TÍT…» ya no se corta).
        AdaptiveStack(spacing: Theme.Space.l) {
            count.frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .frame(minHeight: Theme.Size.tapTarget)
        // Con la letra más grande el conteo es más alto que su renglón de 44 y quedaba pegado a
        // los filtros de arriba: lleva su propio aire.
        .padding(.top, typeSize.isAccessibilitySize ? Theme.Space.s : 0)
    }
}

extension CountLine {
    /// Cada cifra va pegada a su palabra («3 libros» nunca se parte) y, con la letra más grande, si
    /// el conteo no cabe en un renglón cada par baja al suyo, sin el «·» colgando al final
    /// («1 SERIE · / 3 LIBROS», auditoría 3).
    static func pairs(_ text: String) -> [String] {
        text.components(separatedBy: " · ").map {
            $0.replacingOccurrences(of: #"(\d) "#, with: "$1\u{00A0}", options: .regularExpression)
        }
    }

    @ViewBuilder fileprivate var count: some View {
        let pairs = Self.pairs(text)
        if typeSize.isAccessibilitySize, pairs.count > 1 {
            ViewThatFits(in: .horizontal) {
                CapsText(text: pairs.joined(separator: " · "))
                VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                    ForEach(pairs, id: \.self) { CapsText(text: $0) }
                }
            }
        } else {
            CapsText(text: pairs.joined(separator: " · "), lines: Theme.Size.countLines)
        }
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
/// Lo que no cabe baja entero al renglón de abajo: antes corría de lado y el último se
/// leía cortado en la orilla («Si…», UX-2b).
struct FilterBar<Item: Hashable & Identifiable>: View {
    let items: [Item]
    @Binding var selection: Item
    let title: (Item) -> String
    @Namespace private var mark

    var body: some View {
        WrapRows(spacing: Theme.Space.xl) {
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
    }
}

/// Acomoda en renglones, de izquierda a derecha: lo que no cabe pasa entero al siguiente, y
/// lo que es más ancho que un renglón entero parte su texto en vez de cortarse.
private struct WrapRows: Layout {
    let spacing: CGFloat

    private func rows(_ width: CGFloat, _ subviews: Subviews) -> [[(index: Int, size: CGSize)]] {
        var rows: [[(index: Int, size: CGSize)]] = [[]]
        var used: CGFloat = 0
        for (index, view) in subviews.enumerated() {
            // Lo que no cabe ni solo en un renglón recibe el ancho entero y parte su texto en
            // dos renglones o más: antes se cortaba en la orilla («Posibles duplicad», AX5).
            var size = view.sizeThatFits(.unspecified)
            if size.width > width { size = view.sizeThatFits(ProposedViewSize(width: width, height: nil)) }
            if !rows[rows.count - 1].isEmpty && used + spacing + size.width > width {
                rows.append([])
                used = 0
            }
            used += (rows[rows.count - 1].isEmpty ? 0 : spacing) + size.width
            rows[rows.count - 1].append((index, size))
        }
        return rows
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(proposal.width ?? .infinity, subviews)
        let width = rows.map { row in row.map(\.size.width).reduce(0, +) + spacing * CGFloat(max(row.count - 1, 0)) }.max() ?? 0
        let height = rows.map { $0.map(\.size.height).max() ?? 0 }.reduce(0, +)
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(bounds.width, subviews) {
            var x = bounds.minX
            let height = row.map(\.size.height).max() ?? 0
            for item in row {
                subviews[item.index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(item.size))
                x += item.size.width + spacing
            }
            y += height
        }
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
                        .font(.badge)
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
                    CoverView(title: "", author: "", style: book.cover).brightness(Theme.CoverArt.stackFar)
                        .offset(x: Theme.Space.s, y: -Theme.Space.s)
                    CoverView(title: "", author: "", style: book.cover).brightness(Theme.CoverArt.stackNear)
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
    @Environment(\.dynamicTypeSize) private var typeSize

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
                    .lineLimit(caption == nil ? (typeSize.isAccessibilitySize ? Theme.Size.coverCaptionLinesLarge : 2) : 1)
                    .multilineTextAlignment(.leading)
                if let count = book.seriesCount, count > 1 {
                    Text("Serie · \(count.counted("libro", "libros"))")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryInk)
                }
                if book.possibleDuplicate {
                    DuplicateMark()
                }
            }
        }
    }
}

/// «Posible duplicado», bajo un libro que parece estar dos veces (UX-2d): el mismo nombre
/// y el mismo ícono que la sección de la Mac (regla 8).
struct DuplicateMark: View {
    var body: some View {
        Label(Duplicates.one, systemImage: Duplicates.symbol)
            .font(.caption)
            .foregroundStyle(Theme.secondaryInk)
            .lineLimit(Theme.Size.labelLines)
    }
}

/// Cuadrícula de portadas con el espaciado del sistema.
struct CoverGrid<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.dynamicTypeSize) private var typeSize
    /// El ancho que tiene la cuadrícula: en una pantalla ancha caben más columnas.
    @State private var width: CGFloat = 0

    /// Con la letra más grande, dos columnas: en tres, los títulos se partían («Fic-cion…»).
    /// En una pantalla ancha (el iPhone Duo abierto), las que quepan sin que una portada pase
    /// de `Size.coverCellWidest` (`Size.gridColumns(fitting:large:)`).
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: Theme.Space.l, alignment: .top),
              count: Theme.Size.gridColumns(fitting: width, large: typeSize.isAccessibilitySize))
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: Theme.Space.xl) { content }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }
}

/// Fila de libro: portada pequeña, título en serif, detalle y estado. Se usa en
/// la lista de la Biblioteca, en una serie, en Buscar y en el Cuaderno.
struct BookRow<Trailing: View>: View {
    let book: ShelfBook
    var detail: String? = nil
    @ViewBuilder var trailing: Trailing
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // Con la letra más grande, título y detalle en dos renglones («Don Quijo…» se cortaba).
        let lines = typeSize.isAccessibilitySize ? Theme.Size.labelLines : 1
        HStack(spacing: Theme.Space.rowGap) {
            CoverView(title: book.title, author: book.author, style: book.cover, image: book.coverImage)
                .frame(width: Theme.Size.coverRow)
            VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                Text(book.title)
                    .font(.rowTitle)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(lines)
                Text(detail ?? book.caption)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryInk)
                    .lineLimit(lines)
                if book.possibleDuplicate { DuplicateMark() }
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
                        .fill(Theme.accent)
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
                SectionHeader(label)
            }
            Text(Found.marked("\(text)»", match))
                .font(.quote)
                .lineSpacing(Theme.Space.xs)
                .foregroundStyle(Theme.ink)
                .overlay(alignment: .topLeading) {
                    Text("«")
                        .font(.quote)
                        .foregroundStyle(Theme.highlight)
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
                    .foregroundStyle(Theme.highlight)
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(.leading, Theme.Space.rowGap)
        .overlay(alignment: .leading) {
            Rectangle().fill(Theme.highlight).frame(width: Theme.Size.quoteRule)
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
    /// El símbolo de la acción, solo si dice lo mismo que ella («plus» para añadir; seguir leyendo no lleva).
    var systemImage: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            SectionHeader(title)
            Text(message)
                .font(.body)
                .foregroundStyle(Theme.secondaryInk)
            if let actionTitle, let action {
                PrimaryButton(title: actionTitle, systemImage: systemImage, action: action)
                    .padding(.top, Theme.Space.s)
            }
        }
        .foregroundStyle(Theme.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Theme.Space.xxxl)
    }
}

/// Índice A–Z al costado de una lista larga, como el de Contactos: la columna entera se
/// toca y se recorre con el dedo, en 44 de ancho (cada letra sola medía 18 × 13). En tinta:
/// es una acción, no el verde de «dónde estás» (regla 1). Cabe en el alto que le dejan: su
/// letra tiene tope y, si aun así no caben las 27, enseña una de cada dos o de cada tres
/// (el dedo sigue llegando a todas). Quien lo pone le deja libre su columna
/// (`Space.letterIndex`) y no lo enseña con la letra más grande (`shows`), donde tapaba las
/// filas de arriba abajo (auditoría 1, 27 nov 2026).
struct LetterIndex: View {
    let onSelect: (String) -> Void
    static let letters = "ABCDEFGHIJKLMNÑOPQRSTUVWXYZ".map(String.init)
    /// De cuántas en cuántas letras se enseña, de más a menos, hasta que quepa.
    private static let strides = [1, 2, 3]
    @State private var height: CGFloat = 0
    @State private var current: String?
    /// La letra en la que va VoiceOver.
    @State private var spoken: String?

    /// Con la letra más grande (AX1 a AX5) el índice no cabe sin tapar las filas.
    static func shows(at size: DynamicTypeSize) -> Bool { !size.isAccessibilitySize }

    var body: some View {
        let letters = Self.letters
        ViewThatFits(in: .vertical) {
            ForEach(Self.strides, id: \.self) { step in
                VStack(spacing: Theme.Space.hair) {
                    ForEach(Array(stride(from: 0, to: letters.count, by: step)), id: \.self) { index in
                        Text(letters[index])
                            .font(.caption2.weight(.semibold)) // ds-exception: índice A–Z
                            .foregroundStyle(Theme.ink)
                    }
                }
            }
        }
        .dynamicTypeSize(...Theme.Letter.fixedShapeLargest)
        .frame(width: Theme.Size.tapTarget)
        .contentShape(Rectangle())
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { touch in
                guard height > 0 else { return }
                let index = Int(touch.location.y / height * CGFloat(letters.count))
                let letter = letters[min(max(index, 0), letters.count - 1)]
                if letter != current { current = letter; onSelect(letter) }
            }
            .onEnded { _ in current = nil })
        .sensoryFeedback(.selection, trigger: current) { _, new in new != nil }
        // Para VoiceOver es un solo control que se ajusta letra por letra, las 27, aunque se
        // vea una de cada dos o tres: antes solo se alcanzaban las que se dibujaban.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Índice alfabético")
        .accessibilityValue(spoken ?? "")
        .accessibilityHint("Desliza hacia arriba o abajo para elegir una letra")
        .accessibilityAdjustableAction { direction in
            let at = spoken.flatMap(letters.firstIndex) ?? -1
            let next = direction == .increment ? at + 1 : at - 1
            guard letters.indices.contains(next) else { return }
            spoken = letters[next]
            onSelect(letters[next])
        }
    }
}

/// «Ir a la letra…»: con la letra más grande el índice A–Z no cabe a la orilla
/// (`LetterIndex.shows`); este menú junto al orden salta a cualquier letra con libros.
struct LetterJumpMenu: View {
    /// Las letras que tienen algo, en orden.
    let letters: [String]
    let onSelect: (String) -> Void

    var body: some View {
        Menu {
            ForEach(letters, id: \.self) { letter in
                Button(letter) { onSelect(letter) }
            }
        } label: {
            HStack(spacing: Theme.Space.xs) {
                // Corto y con la flecha del orden: «Ir a la letra…» se partía en dos renglones con la
                // letra más grande y su ícono de letras se dibujaba como un «Abc» enorme (auditoría 3).
                // «Letra», no «A–Z»: junto a «TÍTULO ⇅» se leía como otro orden (auditoría 4).
                CapsText(text: "Letra", tone: Theme.ink)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.ink)
            }
            .frame(minHeight: Theme.Size.tapTarget)
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .accessibilityLabel("Ir a la letra")
    }
}

extension String {
    /// ¿Se le pueden espaciar las letras? Solo a las latinas, griegas y cirílicas: el árabe, el
    /// hebreo y las escrituras que unen sus letras se rompen espaciadas («الـف لـيـلـة», UX-1c).
    var isSpaceable: Bool {
        range(of: #"[^\P{L}\p{Latin}\p{Greek}\p{Cyrillic}]"#, options: .regularExpression) == nil
    }

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

/// Lo que se queda fijo abajo de una lista mientras eliges («Mantener los datos de N libros»):
/// sobre el papel, con su línea finísima arriba. Al final de una lista larga no se veía.
struct BottomBar<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .gutter()
            .padding(.vertical, Theme.Space.s)
            .frame(maxWidth: .infinity)
            .background(Theme.paper.ignoresSafeArea(edges: .bottom))
            .overlay(alignment: .top) { Hairline() }
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
    @Environment(\.dynamicTypeSize) private var typeSize
    /// Una fila apagada se ve apagada (auditoría 5): en Ajustes «Mover…», «Traer de Calibre» y
    /// «Ordenar» seguían en tinta aunque no se podían tocar.
    @Environment(\.isEnabled) private var isEnabled
    @ScaledMetric(relativeTo: .body) private var markSize = Theme.Size.statusDot

    var body: some View {
        // El punto va a la altura del primer renglón del nombre: con la letra más grande, centrado
        // en la fila, caía abajo a la izquierda, entre el nombre y su valor.
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.s) {
            if marked {
                // Una «X» escondida da el alto del primer renglón: el punto va en su centro, no en
                // la línea de base, donde se leía como un punto final; y crece con la letra (auditoría 3).
                Text(verbatim: "X").hidden()
                    .frame(width: markSize)
                    .overlay { StatusDot(on: true, size: markSize) }
                    .accessibilityHidden(true)
            }
            // Con la letra más grande, el valor baja bajo el nombre (antes «Fuent / e  Open…»).
            AdaptiveStack(spacing: Theme.Space.s) {
                Text(title).foregroundStyle(isEnabled ? Theme.ink : Theme.secondaryInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: Theme.Space.s) {
                    if let status { StatusDot(on: status) }
                    if let value {
                        Text(value).foregroundStyle(Theme.secondaryInk).monospacedDigit()
                            .lineLimit(typeSize.isAccessibilitySize ? Theme.Size.labelLines : 1)
                    }
                    // Con un valor, la flecha va pegada a él: con la letra más grande el «3» de «Por
                    // revisar» bajaba a su renglón y la flecha se quedaba arriba, lejos (auditoría 4).
                    if chevron, value != nil || status != nil { chevronMark }
                }
            }
            if chevron, value == nil, status == nil { chevronMark }
        }
        .font(.body)
        .frame(minHeight: Theme.Size.row)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { Hairline() }
    }
}

extension LinkRow {
    fileprivate var chevronMark: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.tertiaryInk)
    }
}

/// Punto de estado: lleno en verde (conectado, pendiente) o hueco en gris.
struct StatusDot: View {
    let on: Bool
    var size = Theme.Size.statusDot

    var body: some View {
        Circle()
            .strokeBorder(on ? Theme.accent : Theme.secondaryInk, lineWidth: Theme.Size.statusDotLine)
            .background(Circle().fill(on ? Theme.accent : .clear))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}


/// Campo de texto en una fila de libreta: el nombre a la izquierda y lo escrito a la derecha.
struct FieldRow: View {
    let title: String
    let prompt: String
    @Binding var text: String
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // Con la letra más grande, el nombre arriba y el campo abajo (antes empujaba la hoja de lado).
        AdaptiveStack(spacing: Theme.Space.l) {
            Text(title).foregroundStyle(Theme.ink).layoutPriority(1)
            TextField(prompt, text: $text)
                .multilineTextAlignment(typeSize.isAccessibilitySize ? .leading : .trailing)
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

/// Un dato que se escribe en un formulario, con su nombre arriba aunque ya tenga valor
/// (UX-3a): en el iPhone el campo del sistema solo enseña la pista y, lleno, no decía qué era.
struct LabeledField: View {
    let label: String
    var prompt: String? = nil
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xxs) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.secondaryInk)
            TextField(label, text: $text, prompt: Text(prompt ?? label))
                .labelsHidden()
                #if os(macOS)
                // En la Mac un campo sin borde se leía como texto fijo (Reglas).
                .textFieldStyle(.roundedBorder)
                #endif
                .foregroundStyle(Theme.ink)
        }
        .padding(.vertical, Theme.Space.xxs)
    }
}

extension View {
    /// Un renglón que, si no cabe, termina en «…» en vez de cortarse en seco: los campos y
    /// valores de la ficha de la Mac (regla 9, UX-3b).
    /// Lo escrito va en tinta: en la ficha de la Mac los datos y sus pistas («2016 o 2016-05-01»)
    /// salían del mismo gris y una pista se leía como un dato (auditoría 3); la pista es `.fieldPrompt`.
    func oneLine() -> some View {
        lineLimit(1).truncationMode(.tail).foregroundStyle(Theme.ink)
    }
}

extension Text {
    /// La pista de un campo, más callada que lo escrito (ver `oneLine`).
    static func fieldPrompt(_ text: String) -> Text {
        Text(text).foregroundStyle(Theme.tertiaryInk)
    }
}

/// Un botón de texto de la barra («Dejar como está», «Guardar cambios», «Volver al libro»), en
/// tinta: iOS los pintaba con el verde de la app aunque la pantalla fuera en tinta (regla 1).
struct BarButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(title, action: action).tint(Theme.ink)
    }
}

/// Una salida de texto de una hoja: lo que dice, si se puede tocar y qué hace.
struct SheetAction {
    let title: String
    var disabled = false
    let action: () -> Void
}

/// Las dos salidas de texto de una hoja («Dejar como está» y «Guardar cambios», «Volver al paso
/// anterior» e «Ir a la biblioteca»). Con la letra de siempre van en la barra; con la de
/// accesibilidad (AX1–AX5) iOS guardaba la segunda en su «•••» y la hoja quedaba sin cómo
/// guardar (auditoría 3): la de salir se queda arriba y la otra baja, entera, a `BottomBar`.
/// `quiet`: la segunda es saltar, no la acción principal (bienvenida): en tinta secundaria.
struct SheetActions: ViewModifier {
    let leave: SheetAction?
    let confirm: SheetAction?
    var quiet = false
    @Environment(\.dynamicTypeSize) private var typeSize

    func body(content: Content) -> some View {
        #if os(iOS)
        let below = typeSize.isAccessibilitySize
        content
            .toolbar {
                if let leave {
                    ToolbarItem(placement: .cancellationAction) { BarButton(leave.title, action: leave.action) }
                }
                if let confirm, !below {
                    ToolbarItem(placement: quiet ? .primaryAction : .confirmationAction) {
                        BarButton(confirm.title, action: confirm.action)
                            .foregroundStyle(quiet ? Theme.secondaryInk : Theme.ink)
                            .disabled(confirm.disabled)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let confirm, below {
                    BottomBar {
                        if quiet {
                            QuietButton(title: confirm.title, action: confirm.action)
                        } else {
                            PrimaryButton(title: confirm.title, fillsWidth: true, action: confirm.action)
                        }
                    }
                    .disabled(confirm.disabled)
                }
            }
        #else
        content
            .toolbar {
                if let leave {
                    ToolbarItem(placement: .cancellationAction) { BarButton(leave.title, action: leave.action) }
                }
                if let confirm {
                    ToolbarItem(placement: .confirmationAction) {
                        BarButton(confirm.title, action: confirm.action).disabled(confirm.disabled)
                    }
                }
            }
        #endif
    }
}

extension View {
    /// Las dos salidas de una hoja, a la vista con cualquier letra (ver `SheetActions`).
    func sheetActions(leave: SheetAction?, confirm: SheetAction?, quiet: Bool = false) -> some View {
        modifier(SheetActions(leave: leave, confirm: confirm, quiet: quiet))
    }
}

/// El menú de la barra de una pantalla («Editar»), en tinta como los demás botones de la barra:
/// iOS lo pintaba con el verde de la app (regla 1).
struct BarMenu<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        Menu {
            content
        } label: {
            Text(title).foregroundStyle(Theme.ink)
        }
        .tint(Theme.ink)
    }
}

/// Un interruptor prendido se ve en verde (lo tuyo) aunque la pantalla vaya en tinta: lo usan
/// `.formScreen()` y `.pushedScreen()`, así ningún interruptor elige su color a mano.
struct AccentSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Toggle(configuration).tint(Theme.accent)
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
            // A la izquierda, como las demás filas: en la Mac la casilla quedaba al centro.
            .frame(maxWidth: .infinity, minHeight: Theme.Size.row, alignment: .leading)
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
        // Con la letra más grande, una hojita bajo otra: lado a lado se salían de la tarjeta.
        AdaptiveStack(rowAlignment: .top, spacing: Theme.Space.l) {
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

// MARK: - Ajustes en tarjetas ilustradas (AJ-D)

/// Un grupo de Ajustes: su rótulo en versalitas, una tarjeta sobre el papel hondo
/// con el dibujo de lo que controla arriba y sus filas abajo, y la ayuda debajo.
struct SettingsCard<Art: View, Content: View>: View {
    let title: String
    var help: String? = nil
    var more: String? = nil
    @ViewBuilder var art: Art
    @ViewBuilder var content: Content

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous) }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            #if os(iOS)
            // En la Mac cada tarjeta es su pestaña y la pestaña ya la nombra (MX-B).
            CapsText(text: title)
                .padding(.horizontal, Theme.Space.l)
                .accessibilityAddTraits(.isHeader)
            #endif
            VStack(spacing: 0) {
                art
                VStack(spacing: 0) { content }
                    .padding(.horizontal, Theme.Space.l)
                    // La raya de la última fila no se asoma en la orilla de la tarjeta.
                    .padding(.bottom, -Theme.Size.hairline)
            }
            .background(Theme.card, in: shape)
            .clipShape(shape)
            .overlay { shape.strokeBorder(Theme.track, lineWidth: Theme.Size.hairline) }
            if let help {
                HelpText(text: help, more: more)
                    .padding(.horizontal, Theme.Space.l)
            }
        }
        .padding(.top, Theme.Space.xl)
    }
}

extension SettingsCard where Art == EmptyView {
    init(title: String, help: String? = nil, more: String? = nil, @ViewBuilder content: () -> Content) {
        self.init(title: title, help: help, more: more, art: { EmptyView() }, content: content)
    }
}

/// El lugar del dibujo: papel, su alto y una raya que lo separa de las filas.
struct SettingsArt<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            // Es un dibujo de medida fija: su letra crece hasta donde cabe en él (lo que dice
            // también está en las filas de abajo y en lo que lee VoiceOver).
            .dynamicTypeSize(...Theme.Letter.drawingLargest)
            .frame(maxWidth: .infinity)
            .frame(height: Theme.Size.settingsArt)
            .background(Theme.paper)
            .clipped()
            .overlay(alignment: .bottom) { Hairline() }
            .accessibilityHidden(true)
    }
}

/// Lectura: una hoja con renglones; abajo el contador de palabras y, al lado, la
/// tarjetita del resumen. Apagas uno y se va del dibujo (AJ-6).
struct ReadingArt: View {
    let counter: Bool
    let summary: Bool

    var body: some View {
        SettingsArt {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                ForEach(Array(Theme.Size.artLines.enumerated()), id: \.offset) { _, length in
                    GeometryReader { proxy in
                        Capsule().fill(Theme.ink.opacity(Theme.Emphasis.ghost))
                            .frame(width: proxy.size.width * length)
                    }
                    .frame(height: Theme.Size.ghostLine)
                }
                Spacer(minLength: 0)
                (Text("1 248").foregroundStyle(Theme.accent).fontWeight(.semibold) + Text(" palabras"))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Theme.secondaryInk)
                    .opacity(counter ? Theme.Emphasis.rest : 0)
            }
            .padding(Theme.Space.l)
            .frame(width: Theme.Size.artPage.width, height: Theme.Size.artPage.height, alignment: .topLeading)
            .background(Theme.card)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: Theme.Radius.control, topTrailingRadius: Theme.Radius.control))
            .overlay {
                UnevenRoundedRectangle(topLeadingRadius: Theme.Radius.control, topTrailingRadius: Theme.Radius.control)
                    .strokeBorder(Theme.track, lineWidth: Theme.Size.hairline)
            }
            .overlay(alignment: .bottomTrailing) {
                VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                    CapsText(text: "Esta sesión")
                    Text("24 min").font(.rowTitle)
                    HStack(spacing: Theme.Size.stageGap) {
                        ForEach([ReadingStage.skimming, .light, .immersed, .active], id: \.self) { stage in
                            Theme.stage(stage).frame(height: Theme.Size.stageBarThin)
                        }
                    }
                }
                .padding(Theme.Space.s)
                .frame(width: Theme.Size.artSummary, alignment: .leading)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        .strokeBorder(Theme.track, lineWidth: Theme.Size.hairline)
                }
                .offset(x: Theme.Space.xl, y: summary ? Theme.Space.s : Theme.Size.artPage.height)
                .opacity(summary ? Theme.Emphasis.rest : 0)
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .animation(Theme.Motion.select, value: counter)
        .animation(Theme.Motion.select, value: summary)
    }
}

/// Datos de los libros: un libro sin datos, la flecha de la fuente y el mismo
/// libro con portada y sinopsis.
struct BookDataArt: View {
    let source: String

    var body: some View {
        SettingsArt {
            HStack(spacing: Theme.Space.s) {
                // El libro tal como llega: solo su título, sin portada.
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Capsule().fill(Theme.ink.opacity(Theme.Emphasis.ghost)).frame(height: Theme.Size.ghostLine)
                    Capsule().fill(Theme.ink.opacity(Theme.Emphasis.ghost)).frame(height: Theme.Size.ghostLine)
                        .padding(.trailing, Theme.Space.l)
                }
                .padding(Theme.Space.s)
                .frame(width: Theme.Size.artBook.width, height: Theme.Size.artBook.height, alignment: .bottom)
                .background(Theme.field, in: RoundedRectangle(cornerRadius: Theme.Radius.cover))
                VStack(spacing: Theme.Space.xs) {
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(Theme.accent)
                    CapsText(text: source, lines: 2)
                        .multilineTextAlignment(.center)
                }
                .frame(width: Theme.Size.artArrow)
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Capsule().fill(Theme.onAccent.opacity(Theme.Emphasis.folioMuted)).frame(height: Theme.Size.ghostLine)
                    Capsule().fill(Theme.onAccent.opacity(Theme.Emphasis.folioMuted)).frame(height: Theme.Size.ghostLine)
                        .padding(.trailing, Theme.Space.l)
                }
                .padding(Theme.Space.s)
                .frame(width: Theme.Size.artBook.width, height: Theme.Size.artBook.height, alignment: .top)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.cover))
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    ForEach(Array(Theme.Size.swatchLines.enumerated()), id: \.offset) { _, length in
                        GeometryReader { proxy in
                            Capsule().fill(Theme.ink.opacity(Theme.Emphasis.ghost)).frame(width: proxy.size.width * length)
                        }
                        .frame(height: Theme.Size.ghostLine)
                    }
                    Text("Portada, sinopsis y año")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(width: Theme.Size.artSynopsis)
            }
        }
    }
}

/// Conexiones: tu Gabinete al centro y un hilo a cada servicio; conectado, el hilo
/// se vuelve verde y su punto se llena.
struct ConnectionsArt: View {
    struct Service: Identifiable {
        let letter: String
        let name: String
        let connected: Bool
        var id: String { name }
    }
    let services: [Service]

    var body: some View {
        SettingsArt {
            HStack(spacing: 0) {
                ForEach(Array(services.enumerated()), id: \.element.id) { index, service in
                    if index == services.count / 2 { hub }
                    if index >= services.count / 2 { wire(service.connected) }
                    node(service)
                    if index < services.count / 2 { wire(service.connected) }
                }
                if services.count < 2 { hub }
            }
            .padding(.bottom, Theme.Space.l)
        }
        .animation(Theme.Motion.select, value: services.map(\.connected))
    }

    private var hub: some View {
        Text("G")
            .font(.hubLetter)
            .frame(width: Theme.Size.artHub, height: Theme.Size.artHub)
            .background(Theme.paper, in: Circle())
            .overlay { Circle().strokeBorder(Theme.ink, lineWidth: Theme.Size.hairline) }
    }

    private func wire(_ on: Bool) -> some View {
        Rectangle()
            .fill(on ? Theme.accent : Theme.secondaryInk.opacity(Theme.Emphasis.folioMuted))
            .frame(width: Theme.Size.artWire, height: Theme.Size.hairline)
    }

    private func node(_ service: Service) -> some View {
        Text(service.letter)
            .font(.rowTitle)
            .frame(width: Theme.Size.artNode, height: Theme.Size.artNode)
            .background(Theme.paper, in: Circle())
            .overlay { Circle().strokeBorder(Theme.track, lineWidth: Theme.Size.hairline) }
            .overlay(alignment: .topTrailing) { StatusDot(on: service.connected) }
            .overlay(alignment: .bottom) {
                Text(service.name)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize()
                    .offset(y: Theme.Space.xl)
            }
    }
}

extension DeviceKind {
    /// El dispositivo donde corre la app ahora.
    static var current: DeviceKind {
        #if os(macOS)
        .mac
        #else
        UIDevice.current.userInterfaceIdiom == .pad ? .iPad : .iPhone
        #endif
    }
}

/// Tu Gabinete (TG-1): la carpeta por dentro, como en el Finder. Arriba dónde vive;
/// adentro, Biblioteca (forma de Calibre) y Notas (Markdown), cada una con su cifra.
/// Cambia sola cuando la mueves a iCloud Drive o a otra carpeta.
struct CabinetArt: View {
    /// Dónde vive la carpeta.
    enum Place: Equatable {
        /// En el dispositivo: el iPhone, el iPad o la Mac.
        case device(DeviceKind)
        /// En iCloud Drive; `path` son las carpetas de en medio («Libros › Lectura»), si las hay.
        case iCloud(path: String?)
        /// En otra carpeta (un disco, Dropbox…): su nombre.
        case folder(String)

        var title: String {
            switch self {
            case .device(let kind): kind.here
            case .iCloud(let path): path.map { "iCloud Drive › \($0)" } ?? "iCloud Drive"
            case .folder(let name): "En «\(name)»"
            }
        }

        var symbol: String {
            switch self {
            case .device(let kind): kind.symbol
            case .iCloud: "icloud"
            case .folder: "externaldrive"
            }
        }
    }

    let place: Place
    /// El nombre de la carpeta del Gabinete («Gabinete» si no la renombraste).
    let folder: String
    let books: Int
    let notes: Int
    var moving = false

    var body: some View {
        SettingsArt {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                node(symbol: place.symbol, title: place.title, tint: Theme.ink, busy: moving)
                VStack(alignment: .leading, spacing: Theme.Space.s) {
                    node(symbol: "folder.fill", title: folder, tint: Theme.accent)
                    VStack(alignment: .leading, spacing: Theme.Space.s) {
                        node(symbol: "folder", title: "Biblioteca", note: "forma de Calibre", figure: books.counted("libro", "libros"))
                        node(symbol: "folder", title: "Notas", note: "también para Obsidian", figure: notes.counted("nota", "notas"))
                    }
                    .branch()
                }
                .branch()
            }
            .padding(.horizontal, Theme.Space.l)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tu Gabinete \(place.title.lowercased()): \(books.counted("libro", "libros")) y \(notes.counted("nota", "notas"))")
        .animation(Theme.Motion.select, value: place)
    }

    private func node(symbol: String, title: String, tint: Color = Theme.secondaryInk, note: String? = nil,
                      figure: String? = nil, busy: Bool = false) -> some View {
        HStack(spacing: Theme.Space.s) {
            Group {
                if busy { ProgressView().controlSize(.mini) } else { Image(systemName: symbol) }
            }
            .font(.footnote)
            .foregroundStyle(tint)
            .frame(width: Theme.Size.artTreeIcon)
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .truncationMode(.middle)
                .layoutPriority(1)
            // Si no cabe, lo primero que se corta es la nota, nunca el nombre ni la cifra.
            if let note {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryInk)
                    .lineLimit(1)
            }
            Spacer(minLength: Theme.Space.s)
            if let figure {
                Text(figure)
                    .font(.footnote.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                    .fixedSize()
            }
        }
    }
}

private extension View {
    /// Un nivel del árbol: un paso adentro y la guía fina que lo cuelga de su carpeta.
    func branch() -> some View {
        padding(.leading, Theme.Space.l)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Theme.track)
                    .frame(width: Theme.Size.hairline)
                    .padding(.leading, Theme.Size.artTreeGuide)
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
            .fill(Theme.highlight)
            .frame(width: Theme.Size.ribbon.width, height: Theme.Size.ribbon.height)
    }
}

/// El ícono del marcador en su área de toque: relleno y en verde si la página está marcada.
struct BookmarkGlyph: View {
    let on: Bool

    var body: some View {
        Image(systemName: on ? "bookmark.fill" : "bookmark")
            .font(.body.weight(.semibold))
            .foregroundStyle(on ? Theme.highlight : Theme.ink)
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
                .accessibilityLabel(star.counted("estrella", "estrellas"))
            }
        }
    }
}

/// El idioma de un libro por su nombre («Español», no «es»), igual en el iPhone y en la Mac.
/// `none` es la opción vacía: «Sin indicar», o «Sin cambiar» con varios libros elegidos.
struct LanguagePicker: View {
    @Binding var code: String
    var none = "Sin indicar"

    var body: some View {
        Picker("Idioma", selection: $code) {
            Text(none).tag("")
            ForEach(BookFields.languages, id: \.self) { Text(BookFields.languageName($0)).tag($0) }
            if !code.isEmpty, !BookFields.languages.contains(code) {
                Text(BookFields.languageName(code)).tag(code)
            }
        }
    }
}

/// El estado de un libro, con los nombres de `ReadingState`, igual en los dos formularios.
struct StatusPicker: View {
    @Binding var status: ReadingStatus?
    /// Con varios libros, la opción de no tocarlo.
    var keeps: String? = nil

    var body: some View {
        Picker("Estado", selection: $status) {
            if let keeps { Text(keeps).tag(ReadingStatus?.none) }
            ForEach(ReadingState.allCases, id: \.self) { Text($0.name).tag(Optional($0.status)) }
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
        [candidate.authors.first, candidate.year, candidate.publisher]
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

/// Una imagen de portada en su marco: entera, sin estirarse ni recortarse, sobre sí misma
/// desenfocada (UX-2e). Una cuadrada o apaisada se ve completa; una 2∶3 llena el marco igual
/// que antes. Toda portada que llega de fuera (internet, Fotos, un archivo) pasa por aquí.
struct FittedCover: View {
    let image: Image

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                image.resizable().scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .blur(radius: proxy.size.width * Theme.CoverArt.fitBlur, opaque: true)
                image.resizable().scaledToFit()
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .clipped()
    }
}

/// Portada de un candidato (de internet) con la tipográfica mientras carga o si no hay.
struct CandidateCover: View {
    let candidate: MetadataCandidate
    let width: CGFloat

    var body: some View {
        AsyncImage(url: candidate.coverURL) { image in
            FittedCover(image: image)
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
                FittedCover(image: Image(decorative: picture, scale: 1))
            } else {
                Theme.field
            }
        case .remote(let url):
            AsyncImage(url: url) { image in
                FittedCover(image: image)
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
    /// ¿Está ese libro en tu biblioteca? Los que no, se ven en gris (no son enlace).
    var isInLibrary: (String) -> Bool = { _ in true }
    @Environment(\.dynamicTypeSize) private var typeSize

    private var preview: String {
        guard let match, !Found.terms(match).contains(where: { note.title.localizedStandardContains($0) }) else { return note.preview }
        return Found.excerpt(plainText, around: match) ?? note.preview
    }

    /// La nota sin su marcado, renglón por renglón: el pasaje encontrado decía «# Ideas sueltas…».
    private var plainText: String {
        note.text.components(separatedBy: .newlines).map(NoteMarkdown.plain).joined(separator: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xxs) {
            // Con la letra más grande, el título y la fecha con sus libros en dos renglones.
            let lines = typeSize.isAccessibilitySize ? Theme.Size.labelLines : 1
            Text(Found.marked(note.title, match))
                .font(.rowTitle)
                .foregroundStyle(Theme.ink)
                .lineLimit(lines)
            if !preview.isEmpty {
                Text(Found.marked(preview, match))
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
                    .lineLimit(2)
            }
            meta
                .font(.caption.weight(.medium))
                .spaced(Theme.Tracking.caps, note.bookLinks.joined())
                .monospacedDigit()
                .lineLimit(lines)
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
        // En verde solo los libros que están en tu biblioteca: uno que no está no es enlace (RB-7b).
        return links.enumerated().reduce(date) { text, link in
            let found = isInLibrary(link.element)
            return text + Text(" · ").foregroundStyle(Theme.secondaryInk)
                + Text(link.element.uppercased()).foregroundStyle(found ? Theme.highlight : Theme.secondaryInk)
        }
    }

    /// «Hoy», «Ayer» o «3 nov».
    static func day(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Hoy" }
        if calendar.isDateInYesterday(date) { return "Ayer" }
        return date.esDayMonth
    }
}

/// Una nota leída: el título grande, párrafos en serif y citas con la raya
/// verde. Los `[[Libro]]` y «ir al pasaje» son enlaces (los abre `openURL`).
struct NoteBody: View {
    let text: String
    /// Si el título de un `[[Libro]]` está en tu biblioteca. Uno que no está se lee como texto
    /// normal, sin verde ni toque (RB-7b, 26 nov 2026: se veía como enlace y no hacía nada).
    var hasBook: (String) -> Bool = { _ in true }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            ForEach(Array(NoteMarkdown.blocks(text).enumerated()), id: \.offset) { index, block in
                switch block {
                case .heading(let title):
                    Text(title)
                        .font(index == 0 ? Font.bookTitle : Font.rowTitle.weight(.semibold))
                        .padding(.bottom, index == 0 ? Theme.Space.xs : 0)
                case .paragraph(let paragraph):
                    Text(inline(paragraph))
                        .font(.prose)
                        .lineSpacing(Theme.Space.xs)
                case .quote(let quote):
                    quoteView(quote)
                case .code(let code):
                    // Tal cual, renglón por renglón y sin enlaces: es tuyo (auditoría 6).
                    Text(verbatim: code)
                        .font(.code)
                        .padding(Theme.Space.s)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.field, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
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
            Text(inline(lines.joined(separator: "\n")))
                .font(.quote)
                .lineSpacing(Theme.Space.xs)
            if let source {
                Text(inline(String(source.dropFirst()).trimmingCharacters(in: .whitespaces)))
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryInk)
            }
        }
        .padding(.leading, Theme.Space.rowGap)
        .overlay(alignment: .leading) {
            Rectangle().fill(Theme.highlight).frame(width: Theme.Size.quoteRule)
        }
    }

    private func inline(_ markdown: String) -> AttributedString {
        Self.inline(markdown, hasBook: hasBook)
    }

    static func inline(_ markdown: String, hasBook: (String) -> Bool = { _ in true }) -> AttributedString {
        let resolved = NoteMarkdown.resolvingLinks(markdown)
        var text = (try? AttributedString(markdown: resolved, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(markdown)
        for run in text.runs {
            guard let url = run.link, case .book(let title) = NoteMarkdown.target(of: url), !hasBook(title) else { continue }
            text[run.range].link = nil
        }
        return text
    }
}

// MARK: - Piezas compartidas del iPhone y la Mac (SD-2, 26 nov 2026)

/// Algo que tarda, diciendo qué hace («Buscando portadas en internet…»): una carga siempre
/// dice qué carga (SB-1). Antes cada pantalla armaba su `ProgressView` con o sin texto.
struct LoadingLine: View {
    let text: String
    /// Sobre la página del libro, el color de su texto.
    var tone: Color = Theme.secondaryInk

    var body: some View {
        HStack(spacing: Theme.Space.s) {
            ProgressView()
            Text(text)
        }
        .font(.subheadline)
        .foregroundStyle(tone)
        .tint(tone)
        .accessibilityElement(children: .combine)
    }
}

/// La ✕ para cerrar algo, en 44 pt y diciendo qué cierra («Cerrar la consulta»): en una
/// tarjeta, gris y sin fondo; sobre la página, en su círculo de vidrio.
struct CloseButton: View {
    enum Style { case plain, glass }
    let label: String
    var style: Style = .plain
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if style == .glass {
                mark.font(.body.weight(.semibold)).foregroundStyle(Theme.ink).glassCircle()
            } else {
                mark.font(.footnote.weight(.semibold)).foregroundStyle(Theme.secondaryInk)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var mark: some View {
        Image(systemName: "xmark")
            .frame(width: Theme.Size.tapTarget, height: Theme.Size.tapTarget)
            .contentShape(Rectangle())
    }
}

/// Una fila como la de un libro (título serif y su detalle) para lo que no es un libro de tu
/// biblioteca: uno de Readwise, uno de Calibre, un duplicado en la Mac, una fuente del lector.
struct TitleDetailRow<Trailing: View>: View {
    let title: String
    var detail: String? = nil
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: Theme.Space.rowGap) {
            VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                Text(title)
                    .font(.rowTitle)
                    .foregroundStyle(Theme.ink)
                if let detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryInk)
                }
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

extension TitleDetailRow where Trailing == EmptyView {
    init(title: String, detail: String? = nil) {
        self.init(title: title, detail: detail) { EmptyView() }
    }
}

/// La marca de lo elegido entre varios (el que se queda de unos duplicados): verde y llena
/// la elegida, gris y hueca las demás.
struct ChoiceMark: View {
    let selected: Bool

    var body: some View {
        Image(systemName: selected ? "largecircle.fill.circle" : "circle")
            .foregroundStyle(selected ? Theme.accent : Theme.secondaryInk)
            .accessibilityHidden(true)
    }
}

/// Lo que dice un vacío que existe en las dos plataformas: las mismas palabras en el iPhone
/// (`EmptyState`) y en la Mac (`MacEmptyState`).
enum EmptyCopy {
    static let noBooks = (title: "Todavía no hay libros",
                          message: "Añade EPUB, PDF, MOBI o cómics. Leo sus datos, les busco portada y los guardo ordenados en una carpeta que Calibre también puede abrir.")
    /// El registro de tu biblioteca sigue en iCloud (p. ej. el primer arranque en un aparato nuevo):
    /// no es una biblioteca vacía (auditoría 3).
    static let stillDownloading = (title: "Bajando tu biblioteca",
                                   message: "Ya le pedí a iCloud tu biblioteca. Tus libros aparecen aquí en cuanto baje; deja la app abierta y con conexión.")
    /// Esperé a iCloud y tu biblioteca no llegó (auditoría 4): ya no digo que estoy bajando para
    /// siempre; te dejo añadir libros o volver a la bienvenida.
    static let cloudGaveUp = (title: "Tu biblioteca no ha bajado",
                              message: "Le pedí a iCloud tu biblioteca y todavía no llega. Si ya tenías libros en otro aparato, aparecen aquí en cuanto baje; si es tu primer Gabinete, añade libros o vuelve a la bienvenida.")
    /// Por qué no añado ni traigo libros mientras bajo la tuya (auditorías 5 y 6), por ningún lado:
    /// el «+», la bienvenida, Ajustes, Traer de Calibre, arrastrar y la biblioteca misma.
    static let addWhileDownloading = "Estoy bajando tu biblioteca de iCloud. Espera a que termine para añadir libros o traer los de Calibre."
    /// El título del aviso cuando tocaste algo que añade libros mientras bajo la tuya.
    static let addWhileDownloadingTitle = "Todavía no puedo añadir libros"
    /// Volver a la bienvenida desde una biblioteca que no bajó.
    static let openWelcome = "Volver a la bienvenida"
    static func noMatch(_ what: String) -> (title: String, message: String) {
        ("Ningún libro aquí", "Ningún libro coincide con «\(what)».")
    }
    /// La salida de un filtro que no deja nada: volver a todos los libros, sin buscar dónde.
    static let showAll = "Ver todos los libros"
    static let noDuplicates = (title: "Sin libros repetidos",
                               message: "No encontré dos libros con el mismo título y un autor parecido, ni con el mismo ISBN.")
    static let chooseBook = (title: "Elige un libro",
                             message: "Haz clic en uno de la tabla para ver y cambiar sus datos.")
}

/// Cómo está una biblioteca sin libros respecto de iCloud (auditoría 4): bajando, ya no la
/// espero, o de verdad vacía. Todo vacío de «no hay libros» sale de aquí, en el iPhone y la Mac.
enum LibraryEmptyKind: Equatable {
    /// Tu biblioteca sigue en iCloud: no es una vacía, y añadir libros los duplicaría.
    case downloading
    /// Esperé y no bajó: puedes añadir libros o volver a la bienvenida.
    case cloudGaveUp
    case noBooks

    init(waitingForCloud: Bool, cloudGaveUp: Bool) {
        self = waitingForCloud ? .downloading : cloudGaveUp ? .cloudGaveUp : .noBooks
    }

    var copy: (title: String, message: String) {
        switch self {
        case .downloading: EmptyCopy.stillDownloading
        case .cloudGaveUp: EmptyCopy.cloudGaveUp
        case .noBooks: EmptyCopy.noBooks
        }
    }

    /// Solo se ofrece añadir libros cuando no estoy bajando la tuya.
    var offersAdd: Bool { self != .downloading }
}

/// El vacío de una biblioteca sin libros en el iPhone: sigue a iCloud (`LibraryEmptyKind`). Mientras
/// bajo tu biblioteca no ofrece «Añadir libros» (la Mesa lo ofrecía y se importaba dos veces).
struct LibraryEmptyState: View {
    let kind: LibraryEmptyKind
    let add: () -> Void
    var welcome: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if kind.offersAdd {
                EmptyState(title: kind.copy.title, message: kind.copy.message,
                           actionTitle: LibraryAction.addBooks.title, systemImage: LibraryAction.addBooks.symbol, action: add)
            } else {
                EmptyState(title: kind.copy.title, message: kind.copy.message)
            }
            if kind == .cloudGaveUp {
                QuietButton(title: EmptyCopy.openWelcome, action: welcome)
                    .padding(.top, Theme.Space.s)
            }
        }
    }
}

#if os(macOS)
/// Una celda de la tabla de la Mac (MX-B): un renglón que se corta con «…» en vez de partirse
/// o salirse (regla 9). El título del libro en New York, lo demás en la letra de la interfaz;
/// en tinta o en secundario sobre el papel, y en la letra de la selección cuando la fila está elegida.
/// Sus cifras miden lo mismo (regla 4).
struct MacCell: View {
    enum Role { case title, plain, secondary }
    let text: String
    var role: Role = .plain
    @Environment(\.backgroundProminence) private var prominence

    var body: some View {
        Text(text)
            .font(role == .title ? .rowTitle : .body)
            .monospacedDigit()
            .lineLimit(1)
            .truncationMode(.tail)
            .foregroundStyle(prominence == .increased ? Theme.onSelection : role == .secondary ? Theme.secondaryInk : Theme.ink)
            .help(text)
    }
}
/// Un vacío en la Mac: la vista del sistema, con las mismas palabras que el iPhone (`EmptyCopy`).
struct MacEmptyState: View {
    let title: String
    let message: String
    var systemImage = "books.vertical"
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var secondaryTitle: String? = nil
    var secondaryAction: (() -> Void)? = nil

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
            }
            if let secondaryTitle, let secondaryAction {
                Button(secondaryTitle, action: secondaryAction)
            }
        }
    }
}

extension MacEmptyState {
    /// El vacío de la biblioteca en la Mac, con la misma regla que el iPhone (`LibraryEmptyKind`).
    init(library kind: LibraryEmptyKind, add: @escaping () -> Void, welcome: @escaping () -> Void) {
        self.init(title: kind.copy.title, message: kind.copy.message,
                  systemImage: kind == .downloading ? "icloud.and.arrow.down" : "books.vertical",
                  actionTitle: kind.offersAdd ? LibraryAction.addBooks.title : nil, action: kind.offersAdd ? add : nil,
                  secondaryTitle: kind == .cloudGaveUp ? EmptyCopy.openWelcome : nil,
                  secondaryAction: kind == .cloudGaveUp ? welcome : nil)
    }
}

extension View {
    /// La acción principal en la Mac: el botón del sistema en el verde hondo de la acción, el
    /// mismo de `PrimaryButton` en los dos modos (regla 6), una por ventana.
    /// Un control de la barra de la ventana en la Mac, en tinta (regla 1): el menú de filtros salía
    /// verde sin ningún filtro puesto. En verde solo cuando hay uno puesto: es «dónde estás» (auditoría 4).
    func macToolbarInk(active: Bool = false) -> some View {
        tint(active ? Theme.accent : Theme.ink)
            .foregroundStyle(active ? Theme.accent : Theme.ink)
    }

    func macMainAction() -> some View {
        buttonStyle(.borderedProminent).tint(Theme.action)
    }

    /// Una tabla o una lista de la Mac sobre el papel de Gabinete (MX-B): sin el blanco ni las
    /// franjas del sistema; los controles siguen siendo los de macOS.
    func macPaper() -> some View {
        scrollContentBackground(.hidden)
            .alternatingRowBackgrounds(.disabled)
            .background(Theme.paper)
    }

    /// La barra lateral de la Mac: el papel hondo (`sunken`), un poco más oscuro que el de la
    /// tabla, como el de Ajustes; así se separa sin una caja.
    func macSidebarPaper() -> some View {
        scrollContentBackground(.hidden)
            .background(Theme.sunken)
    }

    /// La barra de una ventana de la Mac en papel: el título y la búsqueda sobre el mismo
    /// papel que el contenido, en claro y en oscuro.
    func macWindowPaper() -> some View {
        toolbarBackground(Theme.paper, for: .windowToolbar)
            .toolbarBackground(.visible, for: .windowToolbar)
    }
}

#endif

// MARK: - Avisos (B3, 26 nov 2026: la misma alerta estaba copiada 13 veces)

extension View {
    /// Algo salió mal: el título dice qué («No pude guardar la nota»), el mensaje por qué y
    /// cómo seguir, y un solo botón que dice a dónde vuelves («Volver a la ficha»).
    func errorAlert(_ title: String, message: Binding<String?>, back: String, onBack: @escaping () -> Void = {}) -> some View {
        oneButtonAlert(title, message: message, back: back, onBack: onBack)
    }

    /// Algo que conviene saber (salió bien, o salió a medias): título que dice qué pasó
    /// («Tu nota quedó guardada»), nunca «Aviso» ni «Nota».
    func noticeAlert(_ title: String, message: Binding<String?>, back: String, onBack: @escaping () -> Void = {}) -> some View {
        oneButtonAlert(title, message: message, back: back, onBack: onBack)
    }

    private func oneButtonAlert(_ title: String, message: Binding<String?>, back: String, onBack: @escaping () -> Void) -> some View {
        alert(title, isPresented: Binding(get: { message.wrappedValue != nil }, set: { if !$0 { message.wrappedValue = nil } })) {
            Button(back, role: .cancel, action: onBack)
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}

// MARK: - Estantes (CB-1): guardar, renombrar y borrar, iguales en el iPhone y la Mac

/// «Guardar como estante»: pide el nombre, con uno propuesto a partir de la búsqueda.
/// El campo empieza vacío y propone el nombre como pista (UX-7, 27 nov 2026): con el nombre
/// ya escrito, lo que tecleabas se pegaba a la búsqueda («CorCortázar»). Vacío, se guarda
/// con lo propuesto.
struct SaveShelfAlert: ViewModifier {
    @Binding var query: String?
    let save: (SavedShelf) -> Void
    @State private var name = ""

    func body(content: Content) -> some View {
        let suggested = SavedShelf.suggestedName(for: query ?? "")
        content
            .alert("Guardar como estante", isPresented: Binding(
                get: { query != nil }, set: { if !$0 { query = nil } }
            )) {
                TextField(suggested, text: $name)
                Button("Guardar estante") {
                    let clean = name.trimmingCharacters(in: .whitespaces)
                    if let query, !(clean.isEmpty ? suggested : clean).isEmpty {
                        save(SavedShelf(name: clean.isEmpty ? suggested : clean, query: query))
                    }
                    query = nil
                }
                Button("Dejar sin guardar", role: .cancel) { query = nil }
            } message: {
                // Corto: en un iPhone chico, con la búsqueda entera y el nombre, no cabía.
                Text("Se llena solo con esta búsqueda. Vacío, lo llamo «\(suggested)».")
            }
            .onChange(of: query) { _, _ in name = "" }
    }
}

/// «Renombrar estante»: el nombre de ahora como pista y el campo vacío, para que lo nuevo
/// no se pegue a lo de antes (UX-7). Vacío, se queda como está.
struct RenameShelfAlert: ViewModifier {
    @Binding var shelf: SavedShelf?
    let save: (SavedShelf) -> Void
    @State private var name = ""

    func body(content: Content) -> some View {
        content
            .alert("Renombrar el estante", isPresented: Binding(
                get: { shelf != nil }, set: { if !$0 { shelf = nil } }
            )) {
                TextField(shelf?.name ?? "", text: $name)
                Button("Guardar nombre") {
                    let clean = name.trimmingCharacters(in: .whitespaces)
                    if var renamed = shelf, !clean.isEmpty {
                        renamed.name = clean
                        save(renamed)
                    }
                    shelf = nil
                }
                Button("Dejar como está", role: .cancel) { shelf = nil }
            }
            .onChange(of: shelf) { _, _ in name = "" }
    }
}

/// Borrar un estante se confirma, y dice que los libros se quedan.
struct DeleteShelfConfirmation: ViewModifier {
    @Binding var shelf: SavedShelf?
    let delete: (SavedShelf) -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog("¿Borrar el estante «\(shelf?.name ?? "")»?", isPresented: Binding(
                get: { shelf != nil }, set: { if !$0 { shelf = nil } }
            ), titleVisibility: .visible) {
                Button("Borrar el estante", role: .destructive) {
                    if let shelf { delete(shelf) }
                    shelf = nil
                }
                Button("Conservar el estante", role: .cancel) { shelf = nil }
            } message: {
                Text("Tus libros se quedan donde están; solo se va el estante.")
            }
    }
}

extension View {
    func saveShelfAlert(query: Binding<String?>, save: @escaping (SavedShelf) -> Void) -> some View {
        modifier(SaveShelfAlert(query: query, save: save))
    }

    func renameShelfAlert(_ shelf: Binding<SavedShelf?>, save: @escaping (SavedShelf) -> Void) -> some View {
        modifier(RenameShelfAlert(shelf: shelf, save: save))
    }

    func deleteShelfConfirmation(_ shelf: Binding<SavedShelf?>, delete: @escaping (SavedShelf) -> Void) -> some View {
        modifier(DeleteShelfConfirmation(shelf: shelf, delete: delete))
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

    /// La fecha corta, igual en toda la app: «3 oct 2024».
    var esShort: String { es(.dateTime.day().month(.abbreviated).year()) }
    /// Día y mes: «12 nov».
    var esDayMonth: String { es(.dateTime.day().month(.abbreviated)) }
}

extension Double {
    /// El entero más cercano, o nada si no es finito o se sale de ±1e9: `Int(inf)` o
    /// `Int(1e20)` cierran la app (C5, 26 nov 2026: un tomo «inf» la cerraba en cada arranque).
    var safeInt: Int? {
        guard isFinite, Swift.abs(self) < 1e9 else { return nil }
        return Int(rounded())
    }

    /// 57 (de 0,57), redondeado igual en toda la app.
    var percentNumber: Int { Int((Swift.min(1, Swift.max(0, self)) * 100).rounded()) }

    /// «57 %»: con espacio (como en español) que no se parte, igual en toda la app.
    /// Antes la Mesa decía «2 %» y el lector «3%» del mismo libro.
    var percentText: String { "\(percentNumber)\u{00A0}%" }

    /// Segundos en milisegundos, para las esperas que se mandan al lector web.
    var milliseconds: Int { Int((self * 1000).rounded()) }
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
        let total = Swift.max(0, seconds.safeInt ?? 0)
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
        let minutes = Swift.max(0, (seconds / 60).safeInt ?? 0)
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
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // Con la letra más grande, una cifra bajo otra: en un tercio de pantalla «6,5 mil» se
        // cortaba en «6,5…» y «PALABRAS» se partía a media palabra (auditoría 2).
        let stacked = typeSize.isAccessibilitySize
        AdaptiveStack(rowAlignment: .top, spacing: stacked ? Theme.Space.l : 0) {
            ForEach(items) { item in
                VStack(alignment: stacked ? .leading : .center, spacing: Theme.Space.xs) {
                    Text(item.value)
                        .font(.bookTitle)
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(Theme.Emphasis.labelMinScale)
                    // En un tercio de pantalla, la leyenda larga baja a otro renglón: antes
                    // «LIBROS TERMI…» se cortaba (UX-4c).
                    CapsText(text: item.label, lines: Theme.Size.labelLines)
                        .multilineTextAlignment(stacked ? .leading : .center)
                }
                .frame(maxWidth: .infinity, alignment: stacked ? .leading : .center)
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
        .frame(height: Theme.Size.stageChart(rows: chartRows))
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
        .accessibilityLabel("\(words.counted("palabra", "palabras")) en esta sesión. Ver la sesión")
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
        // En la tarjeta del lector, nada hasta la primera palabra: «0 palabras ›» al abrir el
        // libro parecía un error.
        if compact && tracker.words == 0 { EmptyView() } else { line }
    }

    private var line: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.s) {
                // Sin punto: el verde solo en el dato, las palabras de esta sesión.
                // En la tarjeta del lector, en gris como la página; en la hoja de la sesión, el dato en verde.
                (Text(compact ? "" : "Esta sesión · ")
                 + Text(tracker.words.counted("palabra", "palabras", shown: ReadingFormat.words(tracker.words))).foregroundStyle(compact ? Theme.ink.opacity(Theme.Emphasis.glassText) : Theme.accent))
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

/// Muestra del pie: un recorte chico de la parte de abajo de la página, con el
/// papel y la tinta del libro, dos renglones insinuados y el pie tal como se
/// leerá. Sin tarjeta ni nombre debajo: el recorte ya dice cómo se verá (el
/// nombre lo lee VoiceOver). La elegida lleva filo de tinta y palomita: no solo
/// el color dice cuál es.
struct FooterPreview: View {
    let name: String
    let text: String
    let paper: Color
    let ink: Color
    var available = true
    var selected = false

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: Theme.Radius.inset, style: .continuous) }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            // El primero deja sitio a la palomita; el segundo cierra el párrafo.
            ghost.padding(.trailing, Theme.Space.l)
            ghost.padding(.trailing, Theme.Space.xxl)
            Spacer(minLength: 0)
            Text(text)
                .font(.caption.weight(.medium))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(Theme.Emphasis.labelMinScale)
                .foregroundStyle(ink.opacity(available ? Theme.Emphasis.folio : Theme.Emphasis.folioMuted))
                .frame(maxWidth: .infinity)
                .contentTransition(.numericText())
        }
        .padding(Theme.Space.s)
        // Crece con el tamaño de texto de iOS: el pie nunca se corta.
        .frame(maxWidth: .infinity, minHeight: Theme.Size.footerPreview)
        .background(paper, in: shape)
        .overlay {
            shape.strokeBorder(selected ? ink : ink.opacity(Theme.Emphasis.ghost),
                               lineWidth: selected ? Theme.Size.selection : Theme.Size.hairline)
        }
        .overlay(alignment: .topTrailing) {
            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.badge)
                    .foregroundStyle(ink)
                    .background(Circle().fill(paper))
                    .padding(Theme.Space.xs)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityValue(text)
        // Al elegir: el filo y la palomita llegan con un resorte corto. Al presionar,
        // se hunde (PressableStyle); todas miden siempre lo mismo.
        .animation(Theme.Motion.select, value: selected)
    }

    private var ghost: some View {
        Capsule().fill(ink.opacity(Theme.Emphasis.ghost)).frame(height: Theme.Size.ghostLine)
    }
}

/// Lectura guiada (LG-B): todo menos el renglón que lees queda en penumbra,
/// con el papel del libro encima. La guía viaja con un resorte corto.
struct GuideShade: View {
    let band: ClosedRange<CGFloat>
    let paper: Color

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                paper.frame(height: max(0, band.lowerBound))
                Color.clear.frame(height: band.upperBound - band.lowerBound)
                paper.frame(height: max(0, proxy.size.height - band.upperBound))
            }
            .opacity(Theme.Reader.guideShade)
        }
        .animation(Theme.Motion.select, value: band)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// La hendidura: el pedazo que se lee, grande, con la letra del libro. Palabra
/// por palabra (HE-A) lleva su letra de enfoque en verde, siempre en el mismo
/// lugar de la ranura para que el ojo no se mueva; por frase (HE-B), centrada.
struct SlitText: View {
    let text: String
    let focus: Int?
    let ink: Color

    var body: some View {
        if let focus, focus < text.count {
            let characters = Array(text)
            // La letra de enfoque queda al centro: lo de antes a la izquierda, lo demás a la derecha.
            HStack(spacing: 0) {
                Text(String(characters[..<focus]))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Text(String(characters[focus])).foregroundStyle(Theme.highlight)
                Text(String(characters[(focus + 1)...]))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.bookTitle)
            .foregroundStyle(ink)
            .lineLimit(1)
        } else {
            Text(text)
                .font(.bookTitle)
                .foregroundStyle(ink)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }
}

/// En continuo, bajo el pie: una rayita corta con la tinta del libro que se llena
/// con lo leído del capítulo. Quieta; en lugar de la barra de desplazamiento (SC-C).
struct ChapterLine: View {
    let done: Double
    let ink: Color

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(ink.opacity(Theme.Emphasis.ghost))
            Capsule().fill(ink)
                .frame(width: Theme.Reader.chapterLine * min(max(done, 0), 1))
        }
        .frame(width: Theme.Reader.chapterLine, height: Theme.Size.progress)
        .animation(Theme.Motion.standard, value: done)
        .accessibilityElement()
        .accessibilityLabel("Capítulo")
        .accessibilityValue(done.percentText)
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
            let step = Theme.Reader.scrubStep
            onChange(min(max(value + (direction == .increment ? step : -step), 0), 1))
            onEnd()
        }
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
                    .rotationEffect(Theme.Size.ringStart)
                Image(systemName: playing ? "pause.fill" : "play.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .frame(width: Theme.Size.playRing, height: Theme.Size.playRing)
            // El anillo mide 38; se toca en 44.
            .sizeTarget()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(playing ? "Pausa" : "Reproducir")
    }
}

/// Tres barras que se mueven: hay audio sonando.
struct EqualizerBars: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: Theme.Space.xxs) {
            ForEach(Theme.Size.equalizerBars, id: \.self) { height in
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: Theme.Size.equalizerBar, height: Theme.Size.equalizerHeight * height)
                    .phaseAnimator([Theme.Emphasis.rest, Theme.Emphasis.equalizerLow]) { bar, phase in
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
            configuration.icon.font(.badge)
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

    /// Los huecos, los días y el renglón de arriba, cada uno con su identidad (`MonthGrid`).
    private var grid: MonthGrid { MonthGrid(days: days.map(\.date)) }

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        let grid = self.grid
        VStack(spacing: Theme.Space.s) {
            // L M M J V S D, del lunes al domingo, como el renglón de la semana. En su propia
            // rejilla: en la de los días, el domingo 1 tenía la misma identidad que el día 1 y lo borraba.
            LazyVGrid(columns: columns, spacing: Theme.Space.s) {
                ForEach(grid.weekdays, id: \.self) { day in
                    Text(day.es(.dateTime.weekday(.narrow)).uppercased())
                        .font(.caption)
                        .foregroundStyle(Theme.tertiaryInk)
                        .accessibilityHidden(true)
                }
            }
            LazyVGrid(columns: columns, spacing: Theme.Space.s) {
                ForEach(grid.cells) { cell in
                    switch cell {
                    case .blank: Color.clear.frame(height: Theme.Size.dayCell)
                    case .day(let index): dayCell(days[index])
                    }
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

    private func dayCell(_ day: ReadingDay) -> some View {
        let future = day.date > today
        let isToday = Calendar.current.isDate(day.date, inSameDayAs: today)
        return Text(day.date.es(.dateTime.day()))
            .font(.footnote)
            .monospacedDigit()
            .foregroundStyle(future ? Theme.track : (day.level.map { $0 == .active || $0 == .immersed } == true ? Theme.paper : Theme.ink))
            .frame(width: Theme.Size.dayCell, height: Theme.Size.dayCell)
            .background(day.level.map(Theme.stage) ?? Color.clear, in: Circle())
            .overlay { if isToday { Circle().stroke(Theme.ink, lineWidth: Theme.Size.selection) } }
            .accessibilityLabel("\(day.date.es(.dateTime.day().month(.wide))): \(ReadingFormat.duration(day.seconds))")
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
                Text("\(session.words.counted("palabra", "palabras", shown: ReadingFormat.words(session.words))) · \(session.fromFraction.percentNumber) → \(session.toFraction.percentText)")
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
                .spaced(Theme.Tracking.sectionLabel, "GABINETE")
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
        .foregroundStyle(Theme.onAccent)
        .padding(Theme.Space.xl)
        .frame(width: Theme.Size.shareCard.width, height: Theme.Size.shareCard.height, alignment: .topLeading)
        .background(Theme.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.tile))
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
        .padding(.leading, Theme.Space.indent(depth))
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
            // Lo encontrado en verde y en negritas, como en la Biblioteca (`Found`).
            Text(Found.marked(Self.lead(before) + match + Self.tail(after), match))
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
    /// Con la letra más grande, la pista corta («Buscar»): la larga no cabía y el campo la achicaba
    /// mientras la lupa crecía.
    var shortPrompt: String? = nil
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    let onSubmit: () -> Void
    var onClear: () -> Void = {}
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(spacing: Theme.Space.s) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.tertiaryInk)
            TextField(typeSize.isAccessibilitySize ? shortPrompt ?? prompt : prompt, text: $text)
                .focused(focused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .onSubmit(onSubmit)
            if !text.isEmpty {
                Button { text = ""; onClear() } label: { Image(systemName: "xmark.circle.fill").sizeTarget() }
                    .buttonStyle(.plain)
                    // Se toca en 44; el dibujo queda en su lugar, junto a la orilla del campo.
                    .padding(.trailing, -Theme.Size.tapBleed)
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
    /// Apagada se ve apagada, como `LinkRow` (auditoría 5).
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Space.l) {
            Image(systemName: systemImage)
                .font(.icon)
                .foregroundStyle(selected ? Theme.accent : Theme.secondaryInk)
                .frame(width: Theme.Size.tapTarget)
            VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                Text(title).font(.rowTitle).foregroundStyle(isEnabled ? Theme.ink : Theme.secondaryInk)
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
        .accessibilityLabel("\(title), \(count.counted("resultado", "resultados"))")
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
                .layoutPriority(1)
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
        .accessibilityLabel("Buscar otra vez «\(text)», \(count.counted("resultado", "resultados"))")
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

    /// Lo que se marca de una búsqueda: cada palabra por separado (o la frase entre comillas),
    /// sin los filtros como `autor:`.
    static func terms(_ match: String?) -> [String] {
        guard let match = match?.trimmingCharacters(in: .whitespaces), !match.isEmpty else { return [] }
        return LibraryQuery(match).words
    }

    /// El texto con cada vez que aparece cada palabra de `match` en verde y negritas (no solo color).
    static func marked(_ text: String, _ match: String?) -> AttributedString {
        var result = AttributedString(text)
        for term in terms(match) {
            var from = text.startIndex
            while let range = text.range(of: term, options: options, range: from..<text.endIndex) {
                if let lower = AttributedString.Index(range.lowerBound, within: result),
                   let upper = AttributedString.Index(range.upperBound, within: result) {
                    result[lower..<upper].foregroundColor = Theme.accent
                    result[lower..<upper].inlinePresentationIntent = .stronglyEmphasized
                }
                from = range.upperBound
            }
        }
        return result
    }

    /// Unas palabras antes y después de la primera vez que aparece alguna palabra de `match`, en un renglón.
    static func excerpt(_ text: String, around match: String) -> String? {
        let flat = text.split(whereSeparator: \.isNewline).joined(separator: " ")
        guard let range = terms(match).lazy.compactMap({ flat.range(of: $0, options: options) }).first else { return nil }
        let start = flat.index(range.lowerBound, offsetBy: -Theme.Size.excerptReach, limitedBy: flat.startIndex) ?? flat.startIndex
        let end = flat.index(range.upperBound, offsetBy: Theme.Size.excerptReach, limitedBy: flat.endIndex) ?? flat.endIndex
        return (start > flat.startIndex ? "…" : "") + flat[start..<end].trimmingCharacters(in: .whitespaces)
            + (end < flat.endIndex ? "…" : "")
    }
}
