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
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
    }

    /// Margen lateral de pantalla, igual a ambos lados.
    func gutter() -> some View {
        padding(.horizontal, Theme.Space.gutter)
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

// MARK: - Botones

/// Respuesta al toque: se hunde un poco, sin cambiar de color.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
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
            .foregroundStyle(Theme.onInk)
            .padding(.horizontal, Theme.Space.l + Theme.Space.xs)
            .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: Theme.Size.control)
            .background(Theme.ink, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
        }
        .buttonStyle(PressableStyle())
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
                            .padding(.vertical, Theme.Space.s - Theme.Space.xxs)
                            .background(selected ? Theme.field : .clear,
                                        in: RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            // El texto de la primera opción queda alineado con el margen.
            .padding(.horizontal, Theme.Space.gutter - Theme.Space.s)
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
        HStack(spacing: Theme.Space.m + Theme.Space.xxs) {
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
        .padding(.vertical, Theme.Space.s + Theme.Space.xxs)
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
                        .fill(Theme.ink)
                        .frame(width: proxy.size.width * min(max(value, 0), 1))
                }
            }
            .frame(height: height)
            .accessibilityElement()
            .accessibilityLabel("Progreso")
            .accessibilityValue(Text(value, format: .percent.precision(.fractionLength(0))))
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
                    .foregroundStyle(Theme.pencil)
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(.leading, Theme.Space.m + Theme.Space.xxs)
        .overlay(alignment: .leading) {
            Rectangle().fill(Theme.pencil).frame(width: Theme.Size.quoteRule)
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
        .padding(.vertical, Theme.Space.s + Theme.Space.xxs)
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
        VStack(spacing: Theme.Space.xxs / 2) {
            ForEach(letters, id: \.self) { letter in
                Button(letter) { onSelect(letter) }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.pencil)
                    .frame(width: Theme.Space.l + Theme.Space.xxs)
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

/// Fila que lleva a otra pantalla: título, valor y flecha. Con `marked`, un
/// punto de lápiz avisa que hay algo pendiente.
struct LinkRow: View {
    let title: String
    var value: String? = nil
    var marked = false

    var body: some View {
        HStack(spacing: Theme.Space.s) {
            if marked {
                Circle().fill(Theme.pencil).frame(width: Theme.Space.s, height: Theme.Space.s)
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
        HStack(alignment: .top, spacing: Theme.Space.m + Theme.Space.xxs) {
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
        .padding(.vertical, Theme.Space.s + Theme.Space.xxs)
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
        .frame(width: width, height: width * 3 / 2)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.cover, style: .continuous))
    }
}

/// Dato propuesto frente al que tienes: el nuevo a la derecha y, si cambia,
/// el tuyo debajo («Antes: …»). Para la vista previa de un candidato.
struct CompareRow: View {
    let label: String
    let new: String?
    let old: String?

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
                    Text("Nuevo").font(.caption).foregroundStyle(Theme.pencil)
                }
            }
        }
        .font(.subheadline)
        .padding(.vertical, Theme.Space.s + Theme.Space.xxs)
        .overlay(alignment: .bottom) { Hairline() }
    }
}
