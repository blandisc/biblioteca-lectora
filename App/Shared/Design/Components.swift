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

/// Título de pantalla en serif, con acciones a la derecha.
struct ScreenHeading<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
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
    var body: some View {
        Text("GABINETE")
            .font(.brandMark)
            .tracking(Theme.Tracking.brandMark)
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Rótulo de sección en mayúsculas romanas pequeñas («EN LA MESA»).
struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.sectionLabel)
            .tracking(Theme.Tracking.sectionLabel)
            .foregroundStyle(Theme.secondaryInk)
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
        VStack(spacing: Theme.Space.inline) {
            icon.frame(height: Theme.Space.xl)
            Text(title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(Theme.Emphasis.labelMinScale)
        }
        .foregroundStyle(prominent ? Theme.onInk : Theme.ink)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.m)
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

/// Una hoja chiquita que pasa con el estilo elegido, en bucle, como en el libro:
/// la de abajo es la página siguiente (otros renglones, empieza con párrafo).
/// Hoja: se dobla desde la orilla derecha y se ve el revés más oscuro.
/// Deslizar: se va de lado. Fundido: una se desvanece mientras aparece la otra.
/// Solo se mueve la elegida.
struct TurnPreview: View {
    let style: ReaderTurnStyle
    let active: Bool

    var body: some View {
        let size = Theme.Size.turnPreview
        ZStack {
            page(next: true)
            page(next: false)
                .phaseAnimator(active ? [0.0, 1.0] : [0.0]) { content, p in
                    turned(content, p, width: size.width)
                } animation: { p in
                    let pause = p == 0 ? Theme.Reader.previewPause : Theme.Reader.previewReturn
                    return style == .none ? Theme.Motion.instant.delay(pause) : Theme.Motion.pageTurn.delay(pause)
                }
        }
        .frame(width: size.width, height: size.height)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func turned(_ content: some View, _ p: Double, width: CGFloat) -> some View {
        switch style {
        case .matte:
            // Lo que queda de la hoja, y su revés doblado encima de la orilla.
            let left = width * (Theme.Emphasis.rest - p)
            let fold = min(left, width * p) * Theme.Reader.previewFold
            content
                .mask(alignment: .leading) { Rectangle().frame(width: max(left, 0)) }
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: Theme.Radius.swatch, style: .continuous)
                        .fill(Theme.secondaryInk)
                        .frame(width: fold)
                        .offset(x: max(left - fold, 0))
                        .shadow(color: Theme.ink.opacity(Theme.Reader.previewShadow), radius: Theme.Size.hairline)
                }
        case .slide:
            content.offset(x: -p * width * Theme.Reader.previewSlide)
                .shadow(color: Theme.ink.opacity(Theme.Reader.previewShadow), radius: Theme.Size.hairline)
        case .fade, .none:
            content.opacity(Theme.Emphasis.rest - p)
        }
    }

    /// Una página con renglones; la siguiente empieza con sangría y termina corta.
    private func page(next: Bool) -> some View {
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
                        Capsule().fill(Theme.secondaryInk)
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

/// Mosaico con un dato: ícono chico arriba, el valor en grande y su leyenda
/// («Página 10» · «de 842»). Lo usa el globo del pie del lector.
struct ValueTile: View {
    let symbol: String
    let value: String
    let caption: String
    var selected = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xxs) {
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(selected ? Theme.accent : Theme.secondaryInk)
                .padding(.bottom, Theme.Space.xxs)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(Theme.Emphasis.labelMinScale)
                .foregroundStyle(Theme.ink)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(Theme.secondaryInk)
                .lineLimit(2, reservesSpace: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.s)
        .background(Theme.field, in: RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous)
                .strokeBorder(selected ? Theme.ink : .clear, lineWidth: Theme.Size.quoteRule)
        }
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
            .foregroundStyle(Theme.onBrand)
            .padding(.horizontal, Theme.Space.buttonX)
            .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: Theme.Size.control)
            .background(Theme.brand, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
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

// MARK: - Filtros y pestañas

/// Fila de opciones en texto; la elegida lleva fondo suave. Se usa para los
/// filtros de la Biblioteca y las secciones del Cuaderno.
struct FilterBar<Item: Hashable & Identifiable>: View {
    let items: [Item]
    @Binding var selection: Item
    let title: (Item) -> String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Space.xs) {
                ForEach(items) { item in
                    let selected = item == selection
                    Button { withAnimation(Theme.Motion.standard) { selection = item } } label: {
                        Text(title(item))
                            .font(.subheadline.weight(selected ? .semibold : .regular))
                            .foregroundStyle(selected ? Theme.ink : Theme.secondaryInk)
                            .padding(.horizontal, Theme.Space.s)
                            .padding(.vertical, Theme.Space.inline)
                            .background(selected ? Theme.field : .clear,
                                        in: RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            // El texto de la primera opción queda alineado con el margen.
            .padding(.horizontal, Theme.Space.chipInset)
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
                        .font(.caption2)
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

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            if let label {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryInk)
            }
            Text(italic ? "«\(text)»" : text)
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
            Text(value).multilineTextAlignment(.trailing)
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
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text(title)
                .font(.bookTitle)
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
                    .font(.caption2.weight(.semibold))
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

/// Fila que lleva a otra pantalla: título, valor y flecha. Con `marked`, un
/// punto de lápiz avisa que hay algo pendiente.
struct LinkRow: View {
    let title: String
    var value: String? = nil
    var marked = false

    var body: some View {
        HStack(spacing: Theme.Space.s) {
            if marked {
                Circle().fill(Theme.accent).frame(width: Theme.Space.s, height: Theme.Space.s)
                    .accessibilityHidden(true)
            }
            Text(title).foregroundStyle(Theme.ink)
            Spacer()
            if let value { Text(value).foregroundStyle(Theme.secondaryInk).monospacedDigit() }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.tertiaryInk)
        }
        .font(.subheadline)
        .padding(.vertical, Theme.Space.m)
        .contentShape(Rectangle())
        .overlay(alignment: .top) { Hairline() }
        .overlay(alignment: .bottom) { Hairline() }
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
            HStack(alignment: .top, spacing: Theme.Space.m) {
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
                    .font(.caption2)
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

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xxs) {
            Text(note.title)
                .font(.rowTitle)
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            if !note.preview.isEmpty {
                Text(note.preview)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
                    .lineLimit(2)
            }
            meta
                .font(.footnote)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Theme.Space.m)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { Hairline() }
    }

    private var meta: Text {
        let date = Text(NoteRow.day(note.modifiedAt)).foregroundStyle(Theme.tertiaryInk)
        if let detail {
            return date + Text(" · \(detail)").foregroundStyle(Theme.tertiaryInk)
        }
        let links = note.bookLinks
        guard !links.isEmpty else { return date }
        return date + Text(" · ").foregroundStyle(Theme.tertiaryInk)
            + Text(links.joined(separator: " · ")).foregroundStyle(Theme.accent)
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

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(items) { item in
                VStack(spacing: Theme.Space.xxs) {
                    Text(item.value)
                        .font(.bookTitle)
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                    Text(item.label)
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryInk)
                }
                .frame(maxWidth: .infinity)
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
            HStack(spacing: Theme.Space.m) { content }
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
            HStack(spacing: Theme.Space.inline) {
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

/// Ícono y texto con poco aire entre ellos, el ícono en gris.
struct QuietIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Theme.Space.inline) {
            configuration.icon
                .foregroundStyle(Theme.secondaryInk)
                .font(.caption.weight(.semibold))
            configuration.title
        }
    }
}

/// La sesión en una línea dentro del panel; tocándola, su tarjeta.
struct SessionLine: View {
    @ObservedObject var tracker: SessionTracker
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.s) {
                Circle().fill(Theme.accent).frame(width: Theme.Size.legendSwatch, height: Theme.Size.legendSwatch)
                Text("Esta sesión · \(ReadingFormat.words(tracker.words)) palabras")
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(Theme.secondaryInk)
            .frame(minHeight: Theme.Size.tapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ver la sesión")
    }
}

/// La rayita de un panel que se sube con el dedo.
struct Grabber: View {
    var body: some View {
        Capsule()
            .fill(Theme.track)
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
                    .frame(width: Theme.Size.equalizerBar, height: Theme.Space.m * height)
                    .phaseAnimator([1.0, 0.4]) { bar, phase in
                        bar.scaleEffect(y: phase, anchor: .bottom)
                    } animation: { _ in Theme.Motion.equalizer(height) }
            }
        }
        .frame(height: Theme.Space.m, alignment: .bottom)
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
        VStack(spacing: Theme.Space.inline) {
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
                        .font(.caption2.weight(isToday ? .semibold : .regular))
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
            HStack(spacing: Theme.Space.inline) {
                Text("Menos")
                ForEach([ReadingStage.skimming, .light, .active, .immersed], id: \.self) { stage in
                    Circle().fill(Theme.stage(stage)).frame(width: Theme.Size.legendSwatch, height: Theme.Size.legendSwatch)
                }
                Text("Más tiempo")
            }
            .font(.caption2)
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
        VStack(spacing: Theme.Space.inline) {
            HStack(alignment: .bottom, spacing: Theme.Space.inline) {
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
            HStack(spacing: Theme.Space.inline) {
                ForEach(Array(Self.initials.enumerated()), id: \.offset) { index, letter in
                    Text(letter)
                        .font(.caption2.weight(index == current ? .semibold : .regular))
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
        HStack(alignment: .center, spacing: Theme.Space.m) {
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
            .padding(.top, Theme.Space.m)
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
    let chapter: String
    let before: String
    let match: String
    let after: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xxs) {
            if !chapter.isEmpty {
                Text(chapter)
                    .font(.caption)
                    .foregroundStyle(Theme.tertiaryInk)
                    .lineLimit(1)
            }
            (Text(Self.lead(before)) + Text(match).bold().foregroundStyle(Theme.accent) + Text(Self.tail(after)))
                .font(.prose)
                .foregroundStyle(Theme.ink)
                .lineLimit(3)
        }
        .padding(.vertical, Theme.Space.rowY)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { Hairline() }
    }

    /// Lo que se quita de los bordes de un pasaje cortado: espacios y puntos suspensivos.
    private static let cut = CharacterSet.whitespaces.union(CharacterSet(charactersIn: ".…"))

    /// El texto de foliate ya puede traer «...» o «…»: se quitan y se pone uno solo,
    /// y ninguno si el pasaje empieza o termina ahí.
    static func lead(_ text: String) -> String {
        let core = text.trimmingCharacters(in: Self.cut)
        return core.isEmpty ? "" : "…" + core + (text.last?.isWhitespace == true ? " " : "")
    }

    static func tail(_ text: String) -> String {
        let core = text.trimmingCharacters(in: Self.cut)
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
        .padding(.horizontal, Theme.Space.m)
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
        HStack(alignment: .top, spacing: Theme.Space.m) {
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
